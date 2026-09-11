import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { AchievementEventSourceType, AchievementTier } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import request = require('supertest');
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { AchievementWorkerService } from '../src/achievements/achievement-worker.service';
import { AchievementOutboxService } from '../src/achievements/achievement-outbox.service';
import { SCENE_RULES } from '../src/achievements/achievement-scene.rules';

type Actor = { id: string; token: string };
describe('Achievement V2 (e2e, seeded local database)', () => {
  let app: INestApplication;
  let db: PrismaService;
  let worker: AchievementWorkerService;
  const previousFlag = process.env.ACHIEVEMENTS_ENABLED;

  beforeAll(async () => {
    process.env.ACHIEVEMENTS_ENABLED = 'false';
    const module = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = module.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ transform: true, whitelist: true, forbidNonWhitelisted: true }));
    await app.init();
    db = app.get(PrismaService);
    worker = app.get(AchievementWorkerService);
    process.env.ACHIEVEMENTS_ENABLED = 'true';
  });

  afterAll(async () => {
    await app?.close();
    if (previousFlag === undefined) delete process.env.ACHIEVEMENTS_ENABLED;
    else process.env.ACHIEVEMENTS_ENABLED = previousFlag;
  });

  async function actor(): Promise<Actor> {
    const { body } = await request(app.getHttpServer()).post('/auth/mock-login')
      .send({ devIdentifier: `achievement-v2-${randomUUID()}` }).expect(201);
    return { id: body.user.id, token: body.accessToken };
  }
  const auth = (actor: Actor) => `Bearer ${actor.token}`;
  async function family(owner: Actor, others: Actor[] = []) {
    const { body } = await request(app.getHttpServer()).post('/families').set('Authorization', auth(owner))
      .send({ name: 'V2 test family', timezone: 'Asia/Shanghai', avatarKey: 'avatar_01' }).expect(201);
    for (const member of others) await db.familyMember.create({ data: { userId: member.id, familyId: body.id, identityLabel: 'Member', status: 'ACTIVE', approvedAt: new Date() } });
    const catalog = await db.chore.findMany({ where: { catalogKey: { in: SCENE_RULES.flatMap((rule) => rule.groups.flat()) } } });
    await db.family.update({ where: { id: body.id }, data: { choreOrder: catalog.map((chore) => chore.id) } });
    return body.id as string;
  }
  async function record(familyId: string, member: Actor, key: string, time = '2026-09-07T23:30:00Z', deleted = false) {
    const chore = await db.chore.findUniqueOrThrow({ where: { catalogKey: key } });
    const record = await db.choreRecord.create({ data: {
      familyId, userId: member.id, choreId: chore.id, occurredAt: new Date(time),
      minutes: 10, actualMinutes: 10, points: 10, imageUrls: [],
      creatorDisplayNameSnapshot: 'Member', creatorIdentityLabelSnapshot: 'Member', deletedAt: deleted ? new Date() : null,
      deletedById: deleted ? member.id : null,
    } });
    const event = await app.get(AchievementOutboxService).enqueue(db, {
      familyId, actorUserId: member.id, eventType: 'CHORE_CREATED', sourceType: AchievementEventSourceType.CHORE,
      sourceId: record.id, occurredAt: record.occurredAt, familyTimezone: 'Asia/Shanghai', payload: { userId: member.id },
    });
    return { record, event: event! };
  }
  async function drain(familyId: string) {
    await worker.drainAvailable(500);
    expect(await db.achievementEvent.count({ where: { familyId, processStatus: { not: 'SUCCEEDED' } } })).toBe(0);
  }
  async function mine(member: Actor, familyId: string) {
    return (await request(app.getHttpServer()).get(`/families/${familyId}/achievements/me`).set('Authorization', auth(member)).expect(200)).body;
  }

  it('evaluates all six scenes from real records, credits only participants and retains owned honors when unreachable', async () => {
    const a = await actor(), b = await actor(), spectator = await actor();
    const id = await family(a, [b, spectator]);
    for (const key of ['premium-clean-litter', 'pet-general-care', 'child-quality-time', 'child-food-prep', 'love-date-plan', 'love-cook-meal']) await record(id, a, key);
    for (const key of ['pet-general-care', 'child-food-prep', 'love-cook-meal']) await record(id, b, key, '2026-09-08T02:00:00Z');
    for (const time of ['2026-09-06T03:00:00Z', '2026-09-06T04:00:00Z', '2026-09-05T03:00:00Z']) await record(id, a, 'pet-general-care', time);
    await drain(id);
    const scenes = (await mine(a, id)).achievements.filter((item: { key: string }) => item.key.startsWith('SCENE_'));
    expect(scenes).toHaveLength(6);
    expect(scenes.every((item: { isUnlocked: boolean; ownerType: string }) => item.isUnlocked && item.ownerType === 'MEMBER')).toBe(true);
    expect(await db.memberAchievement.count({ where: { familyId: id, userId: b.id, achievementKey: { startsWith: 'SCENE_' } } })).toBe(3);
    expect(await db.memberAchievement.count({ where: { familyId: id, userId: spectator.id } })).toBe(0);
    await db.familyMember.updateMany({ where: { familyId: id, userId: { not: a.id } }, data: { status: 'LEFT' } });
    await db.family.update({ where: { id }, data: { choreOrder: [] } });
    const retained = await mine(a, id);
    expect(retained.achievements.filter((item: { key: string }) => item.key.startsWith('SCENE_'))).toHaveLength(6);
    expect(retained.achievements.some((item: { key: string }) => item.key === 'FAMILY_RELAY')).toBe(false);
    expect(retained.achievements.filter((item: { key: string }) => item.key === 'MASTERY_PET')).toEqual([
      expect.objectContaining({ tier: 'BRONZE', isUnlocked: true }),
    ]);
  }, 30000);

  it('protects hidden detail/sharing, counts only active undiscovered definitions and rebuilds on delete/restore using timezone snapshots', async () => {
    const a = await actor(), b = await actor();
    const id = await family(a, [b]);
    const initial = await mine(a, id);
    expect(initial.undiscoveredHiddenCount).toBe(7);
    expect(JSON.stringify(initial.achievements)).not.toContain('HIDDEN_');
    const hiddenDefinition = await db.achievementDefinition.findFirstOrThrow({ where: { key: 'HIDDEN_FRESH_START' } });
    for (const key of ['HIDDEN_FRESH_START', hiddenDefinition.id]) await request(app.getHttpServer())
      .get(`/families/${id}/achievements/${key}`).set('Authorization', auth(a)).expect(404);
    const summary = await request(app.getHttpServer()).get(`/families/${id}/achievements/summary`).set('Authorization', auth(a)).expect(200);
    expect(summary.body).not.toHaveProperty('undiscoveredHiddenCount');

    await record(id, a, 'premium-change-bedding');
    const laundry = await record(id, a, 'core-laundry', '2026-09-08T02:00:00Z', true);
    await drain(id);
    expect((await mine(a, id)).undiscoveredHiddenCount).toBe(7);
    // Family timezone changes do not rewrite the original per-record local dates.
    await db.family.update({ where: { id }, data: { timezone: 'UTC' } });
    await db.choreRecord.update({ where: { id: laundry.record.id }, data: { deletedAt: new Date(), deletedById: a.id } });
    const restore = await request(app.getHttpServer()).post(`/chore-records/${laundry.record.id}/restore`).set('Authorization', auth(a)).expect(201);
    await drain(id);
    const discovered = await mine(a, id);
    expect(discovered.undiscoveredHiddenCount).toBe(6);
    const hidden = discovered.achievements.find((item: { key: string }) => item.key === 'HIDDEN_FRESH_START');
    expect(hidden).toMatchObject({ isUnlocked: true, isHidden: true, visibility: 'PRIVATE' });
    await request(app.getHttpServer()).patch(`/families/${id}/achievements/${hidden.memberAchievementId}/visibility`)
      .set('Authorization', auth(a)).send({ visibility: 'FAMILY' }).expect(403);
    await request(app.getHttpServer()).patch(`/families/${id}/achievements/visibility`)
      .set('Authorization', auth(a)).send({ showToFamily: true }).expect(200);
    expect((await mine(a, id)).achievements.find((item: { key: string }) => item.key === hidden.key).visibility).toBe('PRIVATE');
    expect(JSON.stringify((await mine(b, id)).achievements)).not.toContain('HIDDEN_FRESH_START');
    await request(app.getHttpServer()).get(`/families/${id}/achievements/${hidden.definitionId}`).set('Authorization', auth(b)).expect(404);
    const sync = await request(app.getHttpServer()).get(`/families/${id}/achievement-sync/${restore.body.achievementEvaluation.eventId}`).set('Authorization', auth(b)).expect(200);
    expect(JSON.stringify(sync.body)).not.toContain(hidden.memberAchievementId);
    expect(JSON.stringify(sync.body)).not.toContain('HIDDEN_FRESH_START');
    await request(app.getHttpServer()).delete(`/chore-records/${laundry.record.id}`).set('Authorization', auth(a)).expect(200);
    await drain(id);
    expect(await db.achievementProgress.findFirst({ where: { familyId: id, ownerKey: `${id}:${a.id}`, achievementKey: hidden.key } })).toMatchObject({ rawCurrentValue: 0, displayCurrentValue: 1, progressStatus: 'COMPLETED' });
    const inactive = await db.achievementDefinition.create({ data: { ...hiddenDefinition, ruleConfigJson: {}, rewardConfigJson: undefined, id: randomUUID(), key: `INACTIVE_${randomUUID()}`, isActive: false } });
    expect((await mine(a, id)).undiscoveredHiddenCount).toBe(6);
    await db.achievementDefinition.delete({ where: { id: inactive.id } });
  }, 30000);

  it('requires personal silver/gold plus premium, claims concurrently once and keeps ownership across expiry and families', async () => {
    const a = await actor(), sponsor = await actor(), outsider = await actor();
    const id = await family(a, [sponsor]);
    const path = '/users/me/achievement-characters';
    const claim = `${path}/avatar_v2_recycler/claim`;
    await request(app.getHttpServer()).get(path).expect(401);
    await request(app.getHttpServer()).post(claim).expect(401);
    await request(app.getHttpServer()).post(`${path}/avatar_v2_unknown/claim`).set('Authorization', auth(a)).expect(404);
    const first = (await request(app.getHttpServer()).get(path).set('Authorization', auth(a)).expect(200)).body.characters;
    expect(first).toHaveLength(4);
    expect(first[0]).toMatchObject({ isOwned: false, achievementUnlocked: false, hasPremium: false, canClaim: false, requiredTier: 'SILVER', claimedAt: null });
    await db.user.update({ where: { id: sponsor.id }, data: { plan: 'premium' } });
    async function award(userId: string, tier: AchievementTier, key = 'MASTERY_TRASH') {
      const definition = await db.achievementDefinition.findFirstOrThrow({ where: { key, tier } });
      const event = await db.achievementEvent.create({ data: { familyId: id, actorUserId: userId, eventType: 'CHORE_CREATED', sourceType: 'CHORE', sourceId: randomUUID(), idempotencyKey: randomUUID(), occurredAt: new Date(), familyTimezoneSnapshot: 'Asia/Shanghai', payloadJson: {}, processStatus: 'SUCCEEDED' } });
      const batch = await db.achievementUnlockBatch.create({ data: { familyId: id, triggerEventId: event.id } });
      return db.memberAchievement.create({ data: { userId, familyId: id, definitionId: definition.id, achievementKey: key, tier, definitionVersion: 1, unlockBatchId: batch.id, triggerEventId: event.id } });
    }
    await award(sponsor.id, 'SILVER');
    await award(a.id, 'BRONZE');
    await request(app.getHttpServer()).post(claim).set('Authorization', auth(a)).expect(403);
    await award(a.id, 'SILVER');
    await db.familyMember.updateMany({ where: { familyId: id, userId: sponsor.id }, data: { status: 'LEFT' } });
    await request(app.getHttpServer()).post(claim).set('Authorization', auth(a)).expect(403);
    await db.familyMember.updateMany({ where: { familyId: id, userId: sponsor.id }, data: { status: 'ACTIVE' } });
    await db.familyMember.updateMany({ where: { familyId: id, userId: a.id }, data: { status: 'LEFT' } });
    await request(app.getHttpServer()).post(claim).set('Authorization', auth(a)).expect(403);
    await db.familyMember.updateMany({ where: { familyId: id, userId: a.id }, data: { status: 'ACTIVE' } });
    await db.user.update({ where: { id: sponsor.id }, data: { plan: 'free' } });
    await request(app.getHttpServer()).post(claim).set('Authorization', auth(a)).expect(403);
    await db.user.update({ where: { id: sponsor.id }, data: { plan: 'premium' } });
    const responses = await Promise.all(Array.from({ length: 5 }, () => request(app.getHttpServer()).post(claim).set('Authorization', auth(a)).expect(200)));
    expect(new Set(responses.map((response) => response.body.claimedAt)).size).toBe(1);
    expect(responses[0].body).toMatchObject({ key: 'avatar_v2_recycler', isOwned: true, canClaim: false });
    expect(await db.achievementCharacter.count({ where: { userId: a.id } })).toBe(1);
    expect(await db.familyMember.findUnique({ where: { userId_familyId: { userId: a.id, familyId: id } } })).toMatchObject({ avatarKey: 'avatar_01' });
    await award(a.id, 'GOLD', 'MASTERY_COOKING');
    await request(app.getHttpServer()).post(`${path}/avatar_v2_chef/claim`).set('Authorization', auth(a)).expect(200);
    for (const [key, achievementKey] of [['avatar_v2_trainer', 'MASTERY_PET'], ['avatar_v2_dad', 'MASTERY_CHILDCARE']]) {
      await award(a.id, 'SILVER', achievementKey);
      await request(app.getHttpServer()).post(`${path}/${key}/claim`).set('Authorization', auth(a)).expect(200);
    }
    expect(await db.achievementCharacter.count({ where: { userId: a.id } })).toBe(4);
    await db.user.update({ where: { id: sponsor.id }, data: { plan: 'free' } });
    const expired = await request(app.getHttpServer()).post(claim).set('Authorization', auth(a)).expect(200);
    expect(expired.body).toMatchObject({ isOwned: true, hasPremium: false });
    await request(app.getHttpServer()).post(claim).set('Authorization', auth(outsider)).expect(403);
    await request(app.getHttpServer()).patch(`/families/${id}/members/me/appearance`).set('Authorization', auth(a)).send({ avatarKey: 'avatar_v2_recycler' }).expect(200);
    const newFamily = await request(app.getHttpServer()).post('/families').set('Authorization', auth(a)).send({ name: 'New family', avatarKey: 'avatar_v2_recycler' }).expect(201);
    await request(app.getHttpServer()).patch(`/families/${newFamily.body.id}/members/me/appearance`).set('Authorization', auth(outsider)).send({ avatarKey: 'avatar_v2_recycler' }).expect(403);
  }, 30000);

  it('rejects unowned V2 avatars on creation, join, resubmission, local import and profile writes', async () => {
    const a = await actor(), b = await actor();
    const id = await family(a);
    await request(app.getHttpServer()).post('/families').set('Authorization', auth(b)).send({ name: 'Forged', avatarKey: ' avatar_v2_chef ' }).expect(403);
    await request(app.getHttpServer()).post(`/families/${id}/join-requests`).set('Authorization', auth(b)).send({ identityLabel: 'Member', avatarKey: 'avatar_v2_chef' }).expect(403);
    await db.familyMember.create({ data: { familyId: id, userId: b.id, identityLabel: 'Member', status: 'LEFT' } });
    await request(app.getHttpServer()).post(`/families/${id}/join-requests`).set('Authorization', auth(b)).send({ identityLabel: 'Member', avatarKey: 'avatar_v2_chef' }).expect(403);
    await request(app.getHttpServer()).patch(`/families/${id}/members/me/appearance`).set('Authorization', auth(a)).send({ avatarKey: 'avatar_v2_chef' }).expect(403);
    await request(app.getHttpServer()).post('/families/claim-local-draft').set('Authorization', auth(b)).send({ draftId: randomUUID(), draftCreatedAt: new Date().toISOString(), familyName: 'Local', avatarKey: 'avatar_v2_chef', chores: [], records: [] }).expect(403);
  });
});
