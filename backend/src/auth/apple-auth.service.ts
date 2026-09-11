import { HttpException, Injectable, ServiceUnavailableException, UnauthorizedException } from '@nestjs/common';
import { AuthProvider } from '@prisma/client';
import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { createRemoteJWKSet, importPKCS8, jwtVerify, SignJWT } from 'jose';
import { PrismaService } from '../prisma/prisma.service';
import { AuthIdentityService } from './auth-identity.service';
import { AuthSessionService } from './auth-session.service';
import { AppleLoginDto } from './dto/apple-login.dto';

const issuer = 'https://appleid.apple.com';

@Injectable()
export class AppleAuthService {
  private readonly keys = createRemoteJWKSet(new URL(`${issuer}/auth/keys`), { timeoutDuration: 8000 });

  constructor(
    private readonly prisma: PrismaService,
    private readonly identities: AuthIdentityService,
    private readonly sessions: AuthSessionService,
  ) {}

  private configuration() {
    const clientId = process.env.APPLE_CLIENT_ID;
    const teamId = process.env.APPLE_TEAM_ID;
    const keyId = process.env.APPLE_KEY_ID;
    const keyPath = process.env.APPLE_PRIVATE_KEY_PATH;
    const encryptionKey = process.env.APPLE_TOKEN_ENCRYPTION_KEY;
    if (!clientId || !teamId || !keyId || !keyPath || !encryptionKey?.match(/^[a-f0-9]{64}$/i)) {
      throw new ServiceUnavailableException('Apple 登录尚未配置完成');
    }
    return { clientId, teamId, keyId, keyPath, encryptionKey: Buffer.from(encryptionKey, 'hex') };
  }

  async challenge() {
    this.configuration();
    const now = new Date();
    await this.prisma.appleAuthChallenge.deleteMany({ where: { expiresAt: { lte: now } } });
    if (await this.prisma.appleAuthChallenge.count() >= 10000) {
      throw new HttpException('登录请求较多，请稍后重试', 429);
    }
    const challenge = await this.prisma.appleAuthChallenge.create({ data: {
      nonce: randomBytes(32).toString('hex'),
      expiresAt: new Date(now.getTime() + 5 * 60 * 1000),
    } });
    return { challengeId: challenge.id, nonce: challenge.nonce, expiresAt: challenge.expiresAt };
  }

  async verifyIdentityToken(token: string, nonce: string) {
    try {
      const { payload } = await jwtVerify(token, this.keys, {
        issuer, audience: this.configuration().clientId, algorithms: ['RS256'],
        requiredClaims: ['sub', 'iat', 'exp', 'nonce'], maxTokenAge: '10m',
      });
      if (payload.nonce !== nonce || !payload.sub || payload.sub.length > 255) {
        throw new Error('Invalid claims');
      }
      return payload.sub;
    } catch (error) {
      if (error instanceof ServiceUnavailableException) throw error;
      throw new UnauthorizedException('Apple 身份验证失败，请重新授权');
    }
  }

  private async clientSecret() {
    const config = this.configuration();
    try {
      const key = await importPKCS8(readFileSync(config.keyPath, 'utf8'), 'ES256');
      return await new SignJWT({})
        .setProtectedHeader({ alg: 'ES256', kid: config.keyId })
        .setIssuer(config.teamId).setSubject(config.clientId).setAudience(issuer)
        .setIssuedAt().setExpirationTime('5m').sign(key);
    } catch {
      throw new ServiceUnavailableException('Apple 登录服务配置异常');
    }
  }

  private async appleRequest(path: 'token' | 'revoke', values: Record<string, string>) {
    const body = new URLSearchParams({
      client_id: this.configuration().clientId, client_secret: await this.clientSecret(), ...values,
    });
    let response: Response;
    try {
      response = await fetch(`${issuer}/auth/${path}`, {
        method: 'POST', body, signal: AbortSignal.timeout(12000), redirect: 'error',
      });
    } catch {
      throw new ServiceUnavailableException('暂时无法连接 Apple，请稍后重试');
    }
    if (!response.ok) {
      if (path === 'token' && response.status === 400) {
        const result = await response.json().catch(() => ({})) as { error?: string };
        if (result.error === 'invalid_grant') {
          throw new UnauthorizedException('Apple 授权已过期，请重新登录');
        }
      }
      throw new ServiceUnavailableException('Apple 授权服务暂不可用，请稍后重试');
    }
    return response;
  }

  encryptToken(token: string, subject: string) {
    const iv = randomBytes(12);
    const cipher = createCipheriv('aes-256-gcm', this.configuration().encryptionKey, iv);
    cipher.setAAD(Buffer.from(subject));
    const encrypted = Buffer.concat([cipher.update(token, 'utf8'), cipher.final()]);
    return [iv, cipher.getAuthTag(), encrypted].map(value => value.toString('base64url')).join('.');
  }

  private decryptToken(value: string, subject: string) {
    const [iv, tag, encrypted] = value.split('.').map(part => Buffer.from(part, 'base64url'));
    const decipher = createDecipheriv('aes-256-gcm', this.configuration().encryptionKey, iv);
    decipher.setAAD(Buffer.from(subject));
    decipher.setAuthTag(tag);
    return Buffer.concat([decipher.update(encrypted), decipher.final()]).toString('utf8');
  }

  async login(dto: AppleLoginDto) {
    this.configuration();
    const challenge = await this.prisma.appleAuthChallenge.findUnique({ where: { id: dto.challengeId } });
    if (!challenge || challenge.usedAt || challenge.expiresAt <= new Date()) {
      throw new UnauthorizedException('Apple 登录请求已失效，请重新开始');
    }
    const subject = await this.verifyIdentityToken(dto.identityToken, challenge.nonce);
    // Consume before exchanging the single-use code to reject concurrent replay.
    const consumed = await this.prisma.appleAuthChallenge.updateMany({
      where: { id: challenge.id, usedAt: null, expiresAt: { gt: new Date() } }, data: { usedAt: new Date() },
    });
    if (consumed.count !== 1) throw new UnauthorizedException('Apple 登录请求已使用');
    const response = await this.appleRequest('token', {
      grant_type: 'authorization_code', code: dto.authorizationCode,
    });
    const tokens = await response.json() as { id_token?: string; refresh_token?: string };
    if (!tokens.id_token || !tokens.refresh_token) {
      throw new ServiceUnavailableException('Apple 返回的授权信息不完整');
    }
    if (await this.verifyIdentityToken(tokens.id_token, challenge.nonce) !== subject) {
      throw new UnauthorizedException('Apple 授权身份不一致');
    }
    const encrypted = this.encryptToken(tokens.refresh_token, subject);
    const user = await this.identities.loginOrCreateIdentity({
      provider: AuthProvider.APPLE, providerSubject: subject,
      displayName: '家庭成员', updateDisplayName: false, verifiedAt: new Date(),
    });
    await this.prisma.authIdentity.update({
      where: { provider_providerSubject: { provider: AuthProvider.APPLE, providerSubject: subject } },
      data: { appleRefreshTokenEncrypted: encrypted },
    });
    return { user, ...await this.sessions.createSession(user.id, dto) };
  }

  async revokeForUser(userId: string) {
    const identity = await this.prisma.authIdentity.findUnique({
      where: { userId_provider: { userId, provider: AuthProvider.APPLE } },
    });
    if (!identity) return;
    if (!identity.appleRefreshTokenEncrypted) {
      throw new ServiceUnavailableException('请先使用 Apple 重新登录，再注销账户');
    }
    let token: string;
    try {
      token = this.decryptToken(identity.appleRefreshTokenEncrypted, identity.providerSubject);
    } catch {
      throw new ServiceUnavailableException('Apple 授权撤销暂不可用，请稍后重试');
    }
    await this.appleRequest('revoke', { token, token_type_hint: 'refresh_token' });
  }
}
