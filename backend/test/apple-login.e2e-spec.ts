import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request = require('supertest');
import { randomUUID } from 'node:crypto';
import { AppModule } from '../src/app.module';
import { AppleAuthService } from '../src/auth/apple-auth.service';
import { PrismaService } from '../src/prisma/prisma.service';

describe('Apple login HTTP and database integration', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let userId: string | undefined;
  const subject = `apple-e2e-${randomUUID()}`;
  const oldEnv = { ...process.env };
  beforeAll(async () => {
    process.env.APPLE_CLIENT_ID = 'com.example.test';
    process.env.APPLE_TEAM_ID = 'TEAM';
    process.env.APPLE_KEY_ID = 'KEY';
    process.env.APPLE_PRIVATE_KEY_PATH = '/unused';
    process.env.APPLE_TOKEN_ENCRYPTION_KEY = 'ab'.repeat(32);
    const module = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = module.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ transform: true, whitelist: true, forbidNonWhitelisted: true }));
    await app.init();
    prisma = app.get(PrismaService);
    const apple = app.get(AppleAuthService);
    jest.spyOn(apple, 'verifyIdentityToken').mockResolvedValue(subject);
    jest.spyOn(apple as any, 'appleRequest').mockResolvedValue({ json: async () => ({ id_token: 'apple-token', refresh_token: 'apple-refresh' }) });
  });
  afterAll(async () => {
    if (userId) await prisma.user.deleteMany({ where: { id: userId } });
    await app?.close();
    jest.restoreAllMocks();
    process.env = oldEnv;
  });

  it('creates a session, keeps the same User on repeat login, rejects replay and revokes on deletion', async () => {
    const challenge = await request(app.getHttpServer()).post('/auth/apple/challenge').send({}).expect(201);
    const body = { challengeId: challenge.body.challengeId, identityToken: 'token', authorizationCode: 'code', platform: 'iOS' };
    const login = await request(app.getHttpServer()).post('/auth/apple/login').send(body).expect(201);
    userId = login.body.user.id;
    expect(login.body.refreshToken).toBeTruthy();
    const identity = await prisma.authIdentity.findUnique({ where: { provider_providerSubject: { provider: 'APPLE', providerSubject: subject } } });
    expect(identity?.userId).toBe(userId);
    expect(identity?.appleRefreshTokenEncrypted).toBeTruthy();
    expect(identity?.appleRefreshTokenEncrypted).not.toContain('apple-refresh');
    await request(app.getHttpServer()).post('/auth/apple/login').send(body).expect(401);
    const next = await request(app.getHttpServer()).post('/auth/apple/challenge').send({}).expect(201);
    const repeated = await request(app.getHttpServer()).post('/auth/apple/login').send({ ...body, challengeId: next.body.challengeId }).expect(201);
    expect(repeated.body.user.id).toBe(userId);
    await request(app.getHttpServer()).get('/auth/me').set('Authorization', `Bearer ${repeated.body.accessToken}`).expect(200);
    await request(app.getHttpServer()).delete('/auth/me').set('Authorization', `Bearer ${repeated.body.accessToken}`).expect(200);
    await request(app.getHttpServer()).get('/auth/me').set('Authorization', `Bearer ${repeated.body.accessToken}`).expect(401);
    expect(await prisma.authIdentity.count({ where: { userId } })).toBe(0);
    expect(await prisma.authSession.count({ where: { userId } })).toBe(0);
  });

  it('rejects malformed input at the HTTP boundary', async () => {
    await request(app.getHttpServer()).post('/auth/apple/login').send({ identityToken: 'x', authorizationCode: '' }).expect(400);
  });
});
