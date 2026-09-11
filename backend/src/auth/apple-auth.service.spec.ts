import { createLocalJWKSet, exportJWK, generateKeyPair, SignJWT } from 'jose';
import { AppleAuthService } from './apple-auth.service';
import { PrismaService } from '../prisma/prisma.service';
import { AuthIdentityService } from './auth-identity.service';
import { AuthSessionService } from './auth-session.service';

describe('AppleAuthService', () => {
  let service: AppleAuthService;
  let signingKey: Awaited<ReturnType<typeof generateKeyPair>>['privateKey'];
  const prisma = {
    appleAuthChallenge: { findUnique: jest.fn(), updateMany: jest.fn(), deleteMany: jest.fn(), count: jest.fn(), create: jest.fn() },
    authIdentity: { update: jest.fn(), findUnique: jest.fn() },
  };
  const identities = { loginOrCreateIdentity: jest.fn() };
  const sessions = { createSession: jest.fn() };
  const environment = { ...process.env };
  const dto = { challengeId: 'challenge', identityToken: 'token', authorizationCode: 'code' };

  beforeAll(async () => {
    const pair = await generateKeyPair('RS256');
    signingKey = pair.privateKey;
    const jwk = await exportJWK(pair.publicKey);
    process.env.APPLE_CLIENT_ID = 'com.example.test';
    process.env.APPLE_TEAM_ID = 'TEAM';
    process.env.APPLE_KEY_ID = 'KEY';
    process.env.APPLE_PRIVATE_KEY_PATH = '/unused-test-key';
    process.env.APPLE_TOKEN_ENCRYPTION_KEY = 'ab'.repeat(32);
    service = new AppleAuthService(prisma as unknown as PrismaService,
      identities as unknown as AuthIdentityService, sessions as unknown as AuthSessionService);
    Object.defineProperty(service, 'keys', { value: createLocalJWKSet({ keys: [jwk] }) });
  });
  afterAll(() => { process.env = environment; });
  beforeEach(() => {
    jest.restoreAllMocks();
    jest.clearAllMocks();
    prisma.appleAuthChallenge.findUnique.mockResolvedValue({ id: 'challenge', nonce: 'nonce', expiresAt: new Date(Date.now() + 60000), usedAt: null });
    prisma.appleAuthChallenge.updateMany.mockResolvedValue({ count: 1 });
    identities.loginOrCreateIdentity.mockResolvedValue({ id: 'user' });
    sessions.createSession.mockResolvedValue({ accessToken: 'session' });
  });

  async function token(overrides: Record<string, unknown> = {}) {
    return new SignJWT({ nonce: 'nonce', ...overrides }).setProtectedHeader({ alg: 'RS256' })
      .setIssuer(String(overrides.iss ?? 'https://appleid.apple.com'))
      .setAudience(String(overrides.aud ?? 'com.example.test')).setSubject('apple-sub')
      .setIssuedAt().setExpirationTime(overrides.exp as number ?? Math.floor(Date.now() / 1000) + 300)
      .sign(signingKey);
  }

  it('verifies an Apple signature and stable subject', async () => {
    expect(await service.verifyIdentityToken(await token(), 'nonce')).toBe('apple-sub');
  });
  it.each([{ iss: 'https://evil.example' }, { aud: 'another-app' }, { nonce: 'wrong' }, { exp: 1 }])(
    'rejects invalid identity claims %j', async overrides => {
      await expect(service.verifyIdentityToken(await token(overrides), 'nonce')).rejects.toThrow();
    },
  );
  it('rejects tampered JWT signatures', async () => {
    const jwt = await token();
    const parts = jwt.split('.');
    parts[2] = `${parts[2][0] === 'a' ? 'b' : 'a'}${parts[2].slice(1)}`;
    await expect(service.verifyIdentityToken(parts.join('.'), 'nonce')).rejects.toThrow();
  });
  it('rejects expired and consumed challenges before any identity lookup', async () => {
    prisma.appleAuthChallenge.findUnique.mockResolvedValue({ usedAt: new Date() });
    await expect(service.login(dto)).rejects.toThrow();
    prisma.appleAuthChallenge.findUnique.mockResolvedValue({ expiresAt: new Date(1) });
    await expect(service.login(dto)).rejects.toThrow();
    expect(identities.loginOrCreateIdentity).not.toHaveBeenCalled();
  });
  it('atomically rejects concurrent challenge replay', async () => {
    jest.spyOn(service, 'verifyIdentityToken').mockResolvedValue('apple-sub');
    prisma.appleAuthChallenge.updateMany.mockResolvedValue({ count: 0 });
    await expect(service.login(dto)).rejects.toThrow('已使用');
    expect(identities.loginOrCreateIdentity).not.toHaveBeenCalled();
  });
  it('rejects a mismatching authorization-code subject', async () => {
    jest.spyOn(service, 'verifyIdentityToken').mockResolvedValueOnce('one').mockResolvedValueOnce('two');
    jest.spyOn(service as any, 'appleRequest').mockResolvedValue({ json: async () => ({ id_token: 'exchanged', refresh_token: 'secret' }) });
    await expect(service.login(dto)).rejects.toThrow('不一致');
    expect(identities.loginOrCreateIdentity).not.toHaveBeenCalled();
  });
  it('uses APPLE sub, encrypts credentials and reuses standard sessions', async () => {
    jest.spyOn(service, 'verifyIdentityToken').mockResolvedValue('apple-sub');
    jest.spyOn(service as any, 'appleRequest').mockResolvedValue({ json: async () => ({ id_token: 'exchanged', refresh_token: 'secret' }) });
    expect(await service.login(dto)).toEqual({ user: { id: 'user' }, accessToken: 'session' });
    expect(identities.loginOrCreateIdentity).toHaveBeenCalledWith(expect.objectContaining({ provider: 'APPLE', providerSubject: 'apple-sub', updateDisplayName: false }));
    expect(prisma.authIdentity.update.mock.calls[0][0].data.appleRefreshTokenEncrypted).not.toContain('secret');
  });
  it('does not create a user when Apple is unavailable', async () => {
    jest.spyOn(service, 'verifyIdentityToken').mockResolvedValue('apple-sub');
    jest.spyOn(service as any, 'appleRequest').mockRejectedValue(new Error('unavailable'));
    await expect(service.login(dto)).rejects.toThrow();
    expect(identities.loginOrCreateIdentity).not.toHaveBeenCalled();
  });
  it('revokes the decrypted token before deletion', async () => {
    prisma.authIdentity.findUnique.mockResolvedValue({ providerSubject: 'apple-sub', appleRefreshTokenEncrypted: service.encryptToken('refresh-secret', 'apple-sub') });
    const revoke = jest.spyOn(service as any, 'appleRequest').mockResolvedValue({});
    await service.revokeForUser('user');
    expect(revoke).toHaveBeenCalledWith('revoke', { token: 'refresh-secret', token_type_hint: 'refresh_token' });
  });
  it('detects credential substitution across identities', async () => {
    prisma.authIdentity.findUnique.mockResolvedValue({ providerSubject: 'other', appleRefreshTokenEncrypted: service.encryptToken('secret', 'apple-sub') });
    await expect(service.revokeForUser('user')).rejects.toThrow();
  });
  it('leaves email-only account deletion unchanged', async () => {
    prisma.authIdentity.findUnique.mockResolvedValue(null);
    await expect(service.revokeForUser('user')).resolves.toBeUndefined();
  });
});
