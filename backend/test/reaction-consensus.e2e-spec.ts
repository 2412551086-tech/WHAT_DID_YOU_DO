import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request = require('supertest');
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';

describe('Chore reaction consensus (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let choreId: string;

  beforeAll(async () => {
    const moduleFixture = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ transform: true, whitelist: true, forbidNonWhitelisted: true }));
    await app.init();
    prisma = app.get(PrismaService);
    const chore = await prisma.chore.upsert({
      where: { catalogKey: 'e2e-reaction-consensus' },
      update: {},
      create: {
        catalogKey: 'e2e-reaction-consensus',
        name: 'E2E reaction consensus chore',
        category: '清洁',
        standardMinutes: 15,
        difficultyMultiplier: 1,
        defaultPoints: 10,
        icon: 'checkmark.circle',
        isFreeCore: false,
        sortOrder: 998,
      },
    });
    choreId = chore.id;
  });

  afterAll(() => app.close());

  async function login(identifier: string) {
    const response = await request(app.getHttpServer())
      .post('/auth/mock-login')
      .send({ devIdentifier: `reaction-consensus-${identifier}-${Date.now()}-${Math.random()}` })
      .expect(201);
    return { token: response.body.accessToken as string, userId: response.body.user.id as string };
  }

  async function addMember(ownerToken: string, inviteCode: string, memberToken: string) {
    const join = await request(app.getHttpServer())
      .post('/families/join-requests')
      .set('Authorization', `Bearer ${memberToken}`)
      .send({ inviteCode, identityLabel: '家庭成员' })
      .expect(201);
    await request(app.getHttpServer())
      .patch(`/families/${join.body.familyId}/join-requests/${join.body.id}`)
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ action: 'approve' })
      .expect(200);
    return join.body.id as string;
  }

  async function createFamily(ownerToken: string) {
    const response = await request(app.getHttpServer())
      .post('/families')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ name: `Reaction consensus ${Date.now()}` })
      .expect(201);
    return { id: response.body.id as string, inviteCode: response.body.inviteCode as string };
  }

  it('uses strict majority, supports doubt/switch/remove, and isolates outsiders', async () => {
    const owner = await login('two-owner');
    const member = await login('two-member');
    const outsider = await login('outsider');
    const family = await createFamily(owner.token);
    await addMember(owner.token, family.inviteCode, member.token);

    const record = await request(app.getHttpServer())
      .post('/chore-records')
      .set('Authorization', `Bearer ${owner.token}`)
      .send({ familyId: family.id, choreId, actualMinutes: 15 })
      .expect(201);

    const firstVote = await request(app.getHttpServer())
      .post(`/chore-records/${record.body.id}/like`)
      .set('Authorization', `Bearer ${member.token}`)
      .send({ reactionKey: 'like' })
      .expect(201);
    expect(firstVote.body.reactionConsensus).toEqual({
      eligibleMemberCount: 2,
      requiredCount: 2,
      likeCount: 1,
      doubtCount: 0,
      status: 'none',
    });

    const secondVote = await request(app.getHttpServer())
      .post(`/chore-records/${record.body.id}/like`)
      .set('Authorization', `Bearer ${owner.token}`)
      .send({ reactionKey: 'like' })
      .expect(201);
    expect(secondVote.body.reactionConsensus.status).toBe('appreciated');

    await request(app.getHttpServer())
      .post(`/chore-records/${record.body.id}/like`)
      .set('Authorization', `Bearer ${member.token}`)
      .send({ reactionKey: 'doubt' })
      .expect(201)
      .expect(({ body }) => expect(body.reactionConsensus.status).toBe('none'));
    await request(app.getHttpServer())
      .post(`/chore-records/${record.body.id}/like`)
      .set('Authorization', `Bearer ${owner.token}`)
      .send({ reactionKey: 'doubt' })
      .expect(201)
      .expect(({ body }) => expect(body.reactionConsensus.status).toBe('questioned'));
    await request(app.getHttpServer())
      .delete(`/chore-records/${record.body.id}/like`)
      .set('Authorization', `Bearer ${member.token}`)
      .expect(200)
      .expect(({ body }) => expect(body.reactionConsensus.status).toBe('none'));

    await request(app.getHttpServer())
      .post(`/chore-records/${record.body.id}/like`)
      .set('Authorization', `Bearer ${outsider.token}`)
      .send({ reactionKey: 'like' })
      .expect(404);
  });

  it('requires three of four and recalculates after a member leaves', async () => {
    const owner = await login('four-owner');
    const memberOne = await login('four-one');
    const memberTwo = await login('four-two');
    const memberThree = await login('four-three');
    const family = await createFamily(owner.token);
    await addMember(owner.token, family.inviteCode, memberOne.token);
    await addMember(owner.token, family.inviteCode, memberTwo.token);
    const memberThreeId = await addMember(owner.token, family.inviteCode, memberThree.token);

    const record = await request(app.getHttpServer())
      .post('/chore-records')
      .set('Authorization', `Bearer ${owner.token}`)
      .send({ familyId: family.id, choreId, actualMinutes: 15 })
      .expect(201);

    for (const token of [memberOne.token, memberTwo.token]) {
      await request(app.getHttpServer())
        .post(`/chore-records/${record.body.id}/like`)
        .set('Authorization', `Bearer ${token}`)
        .send({ reactionKey: 'like' })
        .expect(201);
    }
    const twoOfFour = await request(app.getHttpServer())
      .get(`/families/${family.id}/activity`)
      .set('Authorization', `Bearer ${owner.token}`)
      .expect(200);
    expect(twoOfFour.body[0].reactionConsensus).toMatchObject({
      eligibleMemberCount: 4,
      requiredCount: 3,
      likeCount: 2,
      status: 'none',
    });

    await request(app.getHttpServer())
      .post(`/chore-records/${record.body.id}/like`)
      .set('Authorization', `Bearer ${memberThree.token}`)
      .send({ reactionKey: 'like' })
      .expect(201)
      .expect(({ body }) => expect(body.reactionConsensus.status).toBe('appreciated'));

    const exitRecord = await request(app.getHttpServer())
      .post('/chore-records')
      .set('Authorization', `Bearer ${owner.token}`)
      .send({ familyId: family.id, choreId, actualMinutes: 15 })
      .expect(201);
    for (const token of [memberOne.token, memberTwo.token]) {
      await request(app.getHttpServer())
        .post(`/chore-records/${exitRecord.body.id}/like`)
        .set('Authorization', `Bearer ${token}`)
        .send({ reactionKey: 'like' })
        .expect(201);
    }

    await request(app.getHttpServer())
      .delete(`/families/${family.id}/members/me`)
      .set('Authorization', `Bearer ${memberThree.token}`)
      .expect(200);

    const afterLeave = await request(app.getHttpServer())
      .get(`/families/${family.id}/activity`)
      .set('Authorization', `Bearer ${owner.token}`)
      .expect(200);
    const afterLeaveRecord = afterLeave.body.find((item: { id: string }) => item.id === exitRecord.body.id);
    expect(afterLeaveRecord.reactionConsensus).toEqual({
      eligibleMemberCount: 3,
      requiredCount: 2,
      likeCount: 2,
      doubtCount: 0,
      status: 'appreciated',
    });

    await expect(
      prisma.familyMember.findUnique({ where: { id: memberThreeId }, select: { status: true } }),
    ).resolves.toMatchObject({ status: 'LEFT' });
  });
});
