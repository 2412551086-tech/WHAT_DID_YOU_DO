import { INestApplication, ValidationPipe } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import {
  AchievementEventSourceType,
  AchievementOwnerType,
  AchievementRuleType,
  AchievementTier,
  AchievementTrack,
  AchievementWindowType,
  AuthProvider,
} from "@prisma/client";
import request = require("supertest");
import { AchievementWorkerService } from "../src/achievements/achievement-worker.service";
import { AppModule } from "../src/app.module";
import { AuthIdentityService } from "../src/auth/auth-identity.service";
import { getDayRangeForTimeZone, getMonthRangeForTimeZone, getWeekRangeForTimeZone } from "../src/common/timezone-ranges";
import { PrismaService } from "../src/prisma/prisma.service";

describe("MVP API (e2e)", () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let choreId: string;
  const previousAchievementMaxRetries = process.env.ACHIEVEMENT_MAX_RETRIES;

  beforeAll(async () => {
    process.env.ACHIEVEMENT_MAX_RETRIES = "5";
    const moduleFixture = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(
      new ValidationPipe({
        transform: true,
        whitelist: true,
        forbidNonWhitelisted: true,
      }),
    );
    await app.init();

    prisma = app.get(PrismaService);
    const chore = await prisma.chore.upsert({
      where: { catalogKey: "e2e-actual-minutes" },
      update: {
        name: "E2E actual minutes chore",
        category: "清洁",
        standardMinutes: 15,
        difficultyMultiplier: 1,
        defaultPoints: 20,
        icon: "checkmark.circle",
        isFreeCore: false,
        sortOrder: 999,
      },
      create: {
        catalogKey: "e2e-actual-minutes",
        name: "E2E actual minutes chore",
        category: "清洁",
        standardMinutes: 15,
        difficultyMultiplier: 1,
        defaultPoints: 20,
        icon: "checkmark.circle",
        isFreeCore: false,
        sortOrder: 999,
      },
    });

    choreId = chore.id;
  });

  afterAll(async () => {
    await app.close();
    if (previousAchievementMaxRetries === undefined) {
      delete process.env.ACHIEVEMENT_MAX_RETRIES;
    } else {
      process.env.ACHIEVEMENT_MAX_RETRIES = previousAchievementMaxRetries;
    }
  });

  async function login(displayName: string) {
    const response = await request(app.getHttpServer())
      .post("/auth/mock-login")
      .send({ displayName })
      .expect(201);

    return {
      token: response.body.accessToken as string,
      refreshToken: response.body.refreshToken as string,
      userId: response.body.user.id as string,
    };
  }

  async function loginWithPhone(phoneNumber: string) {
    const response = await request(app.getHttpServer())
      .post("/auth/mock-login")
      .send({ phoneNumber })
      .expect(201);

    return {
      token: response.body.accessToken as string,
      refreshToken: response.body.refreshToken as string,
      userId: response.body.user.id as string,
      phoneNumber: response.body.user.phoneNumber as string,
    };
  }

  it("returns 404 for the empty application root", () => {
    return request(app.getHttpServer()).get("/").expect(404);
  });

  it("returns the four themed system chore catalogs as free and unlocked", async () => {
    const response = await request(app.getHttpServer()).get("/chores").expect(200);
    expect(response.body).toHaveLength(46);
    expect(response.body.every((chore: { name: string }) => [...chore.name].length <= 5)).toBe(true);
    expect(new Set(response.body.map((chore: { themeKey: string }) => chore.themeKey))).toEqual(
      new Set(["daily", "love", "childcare", "pet"]),
    );
    expect(response.body).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ name: "换床单", category: "洗护", requiredPlan: "free", isLocked: false }),
        expect.objectContaining({ name: "清理灶台", category: "清洁", isLocked: false }),
        expect.objectContaining({ name: "搬重物", icon: "chore_catalog_heavy_lifting", isLocked: false }),
        expect.objectContaining({ name: "清理猫砂", icon: "chore_catalog_clean_litter", isLocked: false }),
        expect.objectContaining({ name: "陪写作业", icon: "chore_catalog_homework_help", isLocked: false }),
        expect.objectContaining({ name: "预约维修", icon: "chore_catalog_repair_booking", isLocked: false }),
        expect.objectContaining({ name: "喂奶", icon: "chore_catalog_feed_baby", points: 38, isLocked: false }),
        expect.objectContaining({ name: "遛娃", icon: "chore_catalog_walk_child", points: 63, isLocked: false }),
        expect.objectContaining({ name: "接送孩子", icon: "chore_catalog_school_run", points: 56, isLocked: false }),
        expect.objectContaining({ name: "擦窗玻璃", themeKey: "daily", icon: "chore_custom_window" }),
        expect.objectContaining({ name: "浇花养护", themeKey: "daily", icon: "chore_custom_plant" }),
        expect.objectContaining({ name: "陪伴孩子", themeKey: "childcare", icon: "chore_custom_childcare" }),
        expect.objectContaining({ name: "宠物照料", themeKey: "pet", icon: "chore_custom_pet" }),
      ]),
    );
  });

  it("keeps test premium redemption while system chores remain free", async () => {
    const premiumUser = await loginWithPhone(`e2e-premium-${Date.now()}`);
    const familyResponse = await request(app.getHttpServer())
      .post("/families")
      .set("Authorization", `Bearer ${premiumUser.token}`)
      .send({ name: "E2E premium family" })
      .expect(201);

    await request(app.getHttpServer())
      .post("/chore-records")
      .set("Authorization", `Bearer ${premiumUser.token}`)
      .send({
        familyId: familyResponse.body.id,
        choreId: "premium-change-bedding",
        actualMinutes: 30,
        pointsMultiplier: 2,
      })
      .expect(403);

    await request(app.getHttpServer())
      .post("/auth/redeem-premium")
      .set("Authorization", `Bearer ${premiumUser.token}`)
      .send({ code: "000000" })
      .expect(400);

    const redemptionResponse = await request(app.getHttpServer())
      .post("/auth/redeem-premium")
      .set("Authorization", `Bearer ${premiumUser.token}`)
      .send({ code: "241255" })
      .expect(201);

    expect(redemptionResponse.body).toMatchObject({ plan: "premium" });

    const recordResponse = await request(app.getHttpServer())
      .post("/chore-records")
      .set("Authorization", `Bearer ${premiumUser.token}`)
      .send({
        familyId: familyResponse.body.id,
        choreId: "premium-change-bedding",
        actualMinutes: 30,
        pointsMultiplier: 2,
      })
      .expect(201);

    expect(recordResponse.body).toMatchObject({
      choreName: "换床单",
      actualMinutes: 30,
      points: 60,
      pointsMultiplier: 2,
      canEdit: true,
    });

    const editedRecordResponse = await request(app.getHttpServer())
      .patch(`/chore-records/${recordResponse.body.id}`)
      .set("Authorization", `Bearer ${premiumUser.token}`)
      .send({ actualMinutes: 40, pointsMultiplier: 1.5 })
      .expect(200);

    expect(editedRecordResponse.body).toMatchObject({
      id: recordResponse.body.id,
      actualMinutes: 40,
      points: 60,
      pointsMultiplier: 1.5,
      canEdit: true,
    });

    await request(app.getHttpServer())
      .post("/chore-records")
      .set("Authorization", `Bearer ${premiumUser.token}`)
      .send({
        familyId: familyResponse.body.id,
        choreId: "premium-change-bedding",
        actualMinutes: 30,
        pointsMultiplier: 2.1,
      })
      .expect(400);
  });

  it("reuses the same development account for repeated phone login", async () => {
    const phoneNumber = `e2e-${Date.now()}`;
    const firstLogin = await loginWithPhone(phoneNumber);
    const secondLogin = await loginWithPhone(phoneNumber);

    expect(firstLogin.phoneNumber).toBe(phoneNumber);
    expect(secondLogin.userId).toBe(firstLogin.userId);
    expect(secondLogin.token).not.toBe(firstLogin.token);
    expect(secondLogin.refreshToken).not.toBe(firstLogin.refreshToken);

    const renamedLogin = await request(app.getHttpServer())
      .post("/auth/mock-login")
      .send({ phoneNumber, displayName: "E2E 可编辑昵称" })
      .expect(201);
    expect(renamedLogin.body.user).toMatchObject({
      id: firstLogin.userId,
      phoneNumber,
      displayName: "E2E 可编辑昵称",
    });

    const currentUserResponse = await request(app.getHttpServer())
      .get("/auth/me")
      .set("Authorization", `Bearer ${renamedLogin.body.accessToken}`)
      .expect(200);

    expect(currentUserResponse.body).toMatchObject({
      id: firstLogin.userId,
      phoneNumber,
      displayName: "E2E 可编辑昵称",
    });

    const profileRenameResponse = await request(app.getHttpServer())
      .patch("/auth/me")
      .set("Authorization", `Bearer ${renamedLogin.body.accessToken}`)
      .send({ displayName: "E2E 个人页昵称" })
      .expect(200);

    expect(profileRenameResponse.body).toMatchObject({
      id: firstLogin.userId,
      phoneNumber,
      displayName: "E2E 个人页昵称",
    });
  });

  it("rotates refresh tokens and revokes the session when an old token is reused", async () => {
    const loginResponse = await request(app.getHttpServer())
      .post("/auth/mock-login")
      .send({ phoneNumber: `rotation-${Date.now()}`, deviceName: "Rotation iPhone", platform: "iOS" })
      .expect(201);

    expect(loginResponse.body).toEqual(expect.objectContaining({
      accessToken: expect.any(String),
      refreshToken: expect.any(String),
      accessTokenExpiresAt: expect.any(String),
      refreshTokenExpiresAt: expect.any(String),
    }));
    const accessPayload = JSON.parse(
      Buffer.from((loginResponse.body.accessToken as string).split('.')[1], 'base64url').toString('utf8'),
    ) as { exp: number; iat: number; sid: string };
    expect(accessPayload.exp - accessPayload.iat).toBe(15 * 60);

    const initialSession = await prisma.authSession.findUniqueOrThrow({
      where: { id: accessPayload.sid },
    });
    expect(initialSession.idleExpiresAt.getTime() - initialSession.createdAt.getTime()).toBeGreaterThan(
      29 * 24 * 60 * 60 * 1000,
    );
    expect(initialSession.absoluteExpiresAt.getTime() - initialSession.createdAt.getTime()).toBeGreaterThan(
      89 * 24 * 60 * 60 * 1000,
    );

    const refreshResponse = await request(app.getHttpServer())
      .post("/auth/refresh")
      .send({ refreshToken: loginResponse.body.refreshToken })
      .expect(201);

    expect(refreshResponse.body.accessToken).not.toBe(loginResponse.body.accessToken);
    expect(refreshResponse.body.refreshToken).not.toBe(loginResponse.body.refreshToken);
    const rotatedSession = await prisma.authSession.findUniqueOrThrow({
      where: { id: accessPayload.sid },
    });
    expect(rotatedSession.idleExpiresAt.getTime()).toBeGreaterThanOrEqual(initialSession.idleExpiresAt.getTime());
    expect(rotatedSession.idleExpiresAt.getTime()).toBeLessThanOrEqual(rotatedSession.absoluteExpiresAt.getTime());

    await request(app.getHttpServer())
      .post("/auth/refresh")
      .send({ refreshToken: loginResponse.body.refreshToken })
      .expect(401);

    await request(app.getHttpServer())
      .get("/auth/me")
      .set("Authorization", `Bearer ${refreshResponse.body.accessToken}`)
      .expect(401);
    await request(app.getHttpServer())
      .post("/auth/refresh")
      .send({ refreshToken: refreshResponse.body.refreshToken })
      .expect(401);

    await expect(prisma.authSession.findFirstOrThrow({
      where: { userId: loginResponse.body.user.id },
      orderBy: { createdAt: "desc" },
    })).resolves.toMatchObject({ revokedReason: "refresh_token_reuse" });
  });

  it("treats concurrent refresh attempts as token reuse and revokes the session", async () => {
    const loginResponse = await request(app.getHttpServer())
      .post("/auth/mock-login")
      .send({ phoneNumber: `concurrent-refresh-${Date.now()}` })
      .expect(201);

    const responses = await Promise.all([
      request(app.getHttpServer())
        .post("/auth/refresh")
        .send({ refreshToken: loginResponse.body.refreshToken }),
      request(app.getHttpServer())
        .post("/auth/refresh")
        .send({ refreshToken: loginResponse.body.refreshToken }),
    ]);

    expect(responses.map((response) => response.status).sort()).toEqual([201, 401]);
    await request(app.getHttpServer())
      .get("/auth/me")
      .set("Authorization", `Bearer ${loginResponse.body.accessToken}`)
      .expect(401);
  });

  it("keeps device sessions independent and can revoke every device", async () => {
    const phoneNumber = `multi-device-${Date.now()}`;
    const first = await request(app.getHttpServer())
      .post("/auth/mock-login")
      .send({ phoneNumber, deviceName: "小狼的 iPhone", platform: "iOS", appVersion: "1.0" })
      .expect(201);
    const second = await request(app.getHttpServer())
      .post("/auth/mock-login")
      .send({ phoneNumber, deviceName: "大力水手的 iPhone", platform: "iOS", appVersion: "1.0" })
      .expect(201);

    const sessions = await request(app.getHttpServer())
      .get("/auth/sessions")
      .set("Authorization", `Bearer ${second.body.accessToken}`)
      .expect(200);
    expect(sessions.body).toEqual(expect.arrayContaining([
      expect.objectContaining({ deviceName: "小狼的 iPhone", isCurrent: false }),
      expect.objectContaining({ deviceName: "大力水手的 iPhone", isCurrent: true }),
    ]));

    await request(app.getHttpServer())
      .post("/auth/logout")
      .set("Authorization", `Bearer ${first.body.accessToken}`)
      .expect(201);
    await request(app.getHttpServer())
      .get("/auth/me")
      .set("Authorization", `Bearer ${first.body.accessToken}`)
      .expect(401);
    await request(app.getHttpServer())
      .get("/auth/me")
      .set("Authorization", `Bearer ${second.body.accessToken}`)
      .expect(200);

    await request(app.getHttpServer())
      .post("/auth/logout-all")
      .set("Authorization", `Bearer ${second.body.accessToken}`)
      .expect(201)
      .expect(({ body }) => expect(body.revokedSessions).toBeGreaterThanOrEqual(1));
    await request(app.getHttpServer())
      .get("/auth/me")
      .set("Authorization", `Bearer ${second.body.accessToken}`)
      .expect(401);
  });

  it("rejects pre-session legacy bearer tokens", async () => {
    await request(app.getHttpServer())
      .get("/auth/me")
      .set("Authorization", "Bearer eyJzdWIiOiJsZWdhY3kifQ.fake-signature")
      .expect(401);
  });

  it("normalizes mainland phone aliases to one stable user identity", async () => {
    const phoneNumber = `139${String(Date.now()).slice(-8)}`;
    const firstResponse = await request(app.getHttpServer())
      .post("/auth/mock-login")
      .send({ phoneNumber, displayName: "保留这个昵称" })
      .expect(201);
    const firstLogin = {
      userId: firstResponse.body.user.id as string,
      phoneNumber: firstResponse.body.user.phoneNumber as string,
    };
    const secondResponse = await request(app.getHttpServer())
      .post("/auth/mock-login")
      .send({ phoneNumber: `+86 ${phoneNumber.slice(0, 3)} ${phoneNumber.slice(3, 7)} ${phoneNumber.slice(7)}` })
      .expect(201);

    expect(secondResponse.body.user.id).toBe(firstLogin.userId);
    expect(secondResponse.body.user.displayName).toBe("保留这个昵称");
    expect(firstLogin.phoneNumber).toBe(`+86${phoneNumber}`);
    await expect(prisma.authIdentity.findMany({ where: { userId: firstLogin.userId } })).resolves.toEqual([
      expect.objectContaining({
        provider: AuthProvider.PHONE,
        providerSubject: `+86${phoneNumber}`,
      }),
    ]);
  });

  it("attaches a migrated identity without replacing the legacy user id", async () => {
    const legacyPhoneNumber = `legacy-auth-${Date.now()}`;
    const legacyUser = await prisma.user.create({
      data: { phoneNumber: legacyPhoneNumber, displayName: "Legacy identity user" },
    });

    const loginResponse = await loginWithPhone(legacyPhoneNumber);

    expect(loginResponse.userId).toBe(legacyUser.id);
    await expect(prisma.authIdentity.findUnique({
      where: {
        provider_providerSubject: {
          provider: AuthProvider.DEV,
          providerSubject: legacyPhoneNumber,
        },
      },
    })).resolves.toMatchObject({ userId: legacyUser.id });
  });

  it("binds multiple verified providers without silently merging conflicting accounts", async () => {
    const suffix = Date.now();
    const first = await loginWithPhone(`identity-owner-${suffix}`);
    const second = await loginWithPhone(`identity-other-${suffix}`);
    const identities = app.get(AuthIdentityService);
    const appleSubject = `apple-${suffix}`;

    await identities.bindIdentity(first.userId, AuthProvider.APPLE, appleSubject);
    await identities.bindIdentity(first.userId, AuthProvider.WECHAT, `wechat-${suffix}`);
    await expect(
      identities.bindIdentity(second.userId, AuthProvider.APPLE, appleSubject),
    ).rejects.toMatchObject({ status: 409 });

    const boundIdentities = await identities.listIdentities(first.userId);
    expect(boundIdentities).toHaveLength(3);
    expect(boundIdentities).toEqual(expect.arrayContaining([
      expect.objectContaining({ provider: AuthProvider.DEV }),
      expect.objectContaining({ provider: AuthProvider.APPLE }),
      expect.objectContaining({ provider: AuthProvider.WECHAT }),
    ]));

    await identities.unbindIdentity(first.userId, AuthProvider.APPLE);
    await identities.unbindIdentity(first.userId, AuthProvider.WECHAT);
    await expect(
      identities.unbindIdentity(first.userId, AuthProvider.DEV),
    ).rejects.toMatchObject({ status: 400 });

    const socialUser = await identities.loginOrCreateIdentity({
      provider: AuthProvider.APPLE,
      providerSubject: `apple-phone-binding-${suffix}`,
      displayName: "Social identity user",
      verifiedAt: new Date(),
    });
    const boundPhone = `138${String(suffix).slice(-8)}`;
    await identities.bindIdentity(socialUser.id, AuthProvider.PHONE, boundPhone);
    await expect(prisma.user.findUniqueOrThrow({ where: { id: socialUser.id } })).resolves.toMatchObject({
      phoneNumber: `+86${boundPhone}`,
    });
  });

  it("keeps the legacy create-family request compatible", async () => {
    const legacyUser = await login("E2E legacy family user");
    const response = await request(app.getHttpServer())
      .post("/families")
      .set("Authorization", `Bearer ${legacyUser.token}`)
      .send({ name: "E2E legacy family", requirePhotoProof: false })
      .expect(201);

    expect(response.body.members[0]).toMatchObject({
      identityLabel: "家庭成员",
      memberRole: "OWNER",
      status: "ACTIVE",
      role: "owner",
    });
    expect(response.body.requirePhotoProof).toBe(false);
    expect(response.body.timezone).toBe("Asia/Shanghai");
  });

  it("shares premium access with every active family member", async () => {
    const owner = await login("E2E chore layout owner");
    const familyResponse = await request(app.getHttpServer())
      .post("/families")
      .set("Authorization", `Bearer ${owner.token}`)
      .send({ name: "E2E chore layout family" })
      .expect(201);
    const familyId = familyResponse.body.id as string;

    const choresResponse = await request(app.getHttpServer()).get("/chores").expect(200);
    const choreIds = choresResponse.body.map((chore: { id: string }) => chore.id);

    await request(app.getHttpServer())
      .get(`/families/${familyId}/chore-layout`)
      .set("Authorization", `Bearer ${owner.token}`)
      .expect(200)
      .expect(({ body }) => {
        expect(body.choreIds).toEqual([]);
        expect(body.isConfigured).toBe(false);
      });

    const freeSelection = choreIds.slice(0, 6);
    await request(app.getHttpServer())
      .patch(`/families/${familyId}/chore-layout`)
      .set("Authorization", `Bearer ${owner.token}`)
      .send({ choreIds: freeSelection, pinnedChoreIds: [freeSelection[2], freeSelection[0]] })
      .expect(200)
      .expect(({ body }) => {
        expect(body.choreIds).toEqual(freeSelection);
        expect(body.pinnedChoreIds).toEqual([freeSelection[2], freeSelection[0]]);
        expect(body.isConfigured).toBe(true);
      });

    await request(app.getHttpServer())
      .patch(`/families/${familyId}/chore-layout`)
      .set("Authorization", `Bearer ${owner.token}`)
      .send({ choreIds: choreIds.slice(0, 7), pinnedChoreIds: [] })
      .expect(400);

    const member = await login(`layout-${Date.now()}`);
    const joinResponse = await request(app.getHttpServer())
      .post("/families/join-requests")
      .set("Authorization", `Bearer ${member.token}`)
      .send({
        inviteCode: familyResponse.body.inviteCode,
        identityLabel: "室友",
        avatarKey: "avatar_02",
      })
      .expect(201);

    await request(app.getHttpServer())
      .patch(`/families/${familyId}/join-requests/${joinResponse.body.id}`)
      .set("Authorization", `Bearer ${owner.token}`)
      .send({ action: "approve" })
      .expect(200);

    await request(app.getHttpServer())
      .get(`/families/${familyId}/chore-layout`)
      .set("Authorization", `Bearer ${member.token}`)
      .expect(200)
      .expect(({ body }) => {
        expect(body).toMatchObject({
          choreIds: freeSelection,
          scope: "family",
          canEdit: false,
          selectionLimit: 6,
          customChoreLimit: 2,
          isPersonalized: false,
        });
      });

    await request(app.getHttpServer())
      .patch(`/families/${familyId}/chore-layout`)
      .set("Authorization", `Bearer ${member.token}`)
      .send({ choreIds: choreIds.slice(0, 3), pinnedChoreIds: [] })
      .expect(403);

    await request(app.getHttpServer())
      .post(`/families/${familyId}/custom-chores`)
      .set("Authorization", `Bearer ${member.token}`)
      .send({
        name: "成员自定",
        iconKey: "chore_custom_generic_01",
        category: "清洁",
        standardMinutes: 10,
        difficultyMultiplier: 1,
      })
      .expect(403);

    await request(app.getHttpServer())
      .post("/auth/redeem-premium")
      .set("Authorization", `Bearer ${owner.token}`)
      .send({ code: "241255" })
      .expect(201);

    await request(app.getHttpServer())
      .get("/families/me")
      .set("Authorization", `Bearer ${member.token}`)
      .expect(200)
      .expect(({ body }) => {
        expect(body).toHaveLength(1);
        expect(body[0]).toMatchObject({
          id: familyId,
          hasPremiumAccess: true,
        });
      });

    const memberCustomResponse = await request(app.getHttpServer())
      .post(`/families/${familyId}/custom-chores`)
      .set("Authorization", `Bearer ${member.token}`)
      .send({
        name: "成员自定",
        iconKey: "chore_custom_dust",
        category: "清洁",
        standardMinutes: 10,
        difficultyMultiplier: 1,
      })
      .expect(201);

    for (const token of [owner.token, member.token]) {
      await request(app.getHttpServer())
        .get(`/families/${familyId}/custom-chores`)
        .set("Authorization", `Bearer ${token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body).toEqual(expect.arrayContaining([
            expect.objectContaining({ id: memberCustomResponse.body.id, name: "成员自定" }),
          ]));
        });
    }

    const premiumSelection = choreIds.slice(0, 12);
    await request(app.getHttpServer())
      .patch(`/families/${familyId}/chore-layout`)
      .set("Authorization", `Bearer ${member.token}`)
      .send({ choreIds: premiumSelection, pinnedChoreIds: [] })
      .expect(200)
      .expect(({ body }) => {
        expect(body.choreIds).toEqual(premiumSelection);
        expect(body).toMatchObject({
          scope: "member",
          canEdit: true,
          selectionLimit: null,
          customChoreLimit: 100,
          isPersonalized: true,
        });
      });

    await request(app.getHttpServer())
      .get(`/families/${familyId}/chore-layout`)
      .set("Authorization", `Bearer ${owner.token}`)
      .expect(200)
      .expect(({ body }) => expect(body.choreIds).toEqual(freeSelection));

    await request(app.getHttpServer())
      .get(`/families/${familyId}/chore-layout`)
      .set("Authorization", `Bearer ${member.token}`)
      .expect(200)
      .expect(({ body }) => expect(body.choreIds).toEqual(premiumSelection));

    await request(app.getHttpServer())
      .patch(`/families/${familyId}/chore-layout`)
      .set("Authorization", `Bearer ${member.token}`)
      .send({
        choreIds: premiumSelection,
        pinnedChoreIds: [],
        followFamilyLayout: true,
      })
      .expect(200)
      .expect(({ body }) => {
        expect(body).toMatchObject({
          choreIds: freeSelection,
          scope: "family",
          isPersonalized: false,
          followFamilyLayout: true,
        });
      });

    await request(app.getHttpServer())
      .get(`/families/${familyId}/chore-layout`)
      .set("Authorization", `Bearer ${member.token}`)
      .expect(200)
      .expect(({ body }) => {
        expect(body.choreIds).toEqual(freeSelection);
        expect(body.followFamilyLayout).toBe(true);
      });
  });

  it("manages two family-scoped free custom chores and records their calculated points", async () => {
    const owner = await login("E2E custom chore owner");
    const familyResponse = await request(app.getHttpServer())
      .post("/families")
      .set("Authorization", `Bearer ${owner.token}`)
      .send({ name: "E2E custom chore family" })
      .expect(201);
    const familyId = familyResponse.body.id as string;

    await request(app.getHttpServer())
      .get(`/families/${familyId}/custom-chores`)
      .set("Authorization", `Bearer ${owner.token}`)
      .expect(200, []);

    await request(app.getHttpServer())
      .post(`/families/${familyId}/custom-chores`)
      .set("Authorization", `Bearer ${owner.token}`)
      .send({
        name: "错误细分类",
        iconKey: "chore_custom_dust",
        category: "地面清洁",
        standardMinutes: 10,
        difficultyMultiplier: 1,
      })
      .expect(400);

    await request(app.getHttpServer())
      .post(`/families/${familyId}/custom-chores`)
      .set("Authorization", `Bearer ${owner.token}`)
      .send({
        name: "超过五个汉字",
        iconKey: "chore_custom_dust",
        category: "清洁",
        standardMinutes: 10,
        difficultyMultiplier: 1,
      })
      .expect(400);

    const firstResponse = await request(app.getHttpServer())
      .post(`/families/${familyId}/custom-chores`)
      .set("Authorization", `Bearer ${owner.token}`)
      .send({
        name: "擦餐桌",
        iconKey: "chore_custom_generic_01",
        category: "清洁",
        standardMinutes: 20,
        difficultyMultiplier: 1,
      })
      .expect(201);

    expect(firstResponse.body).toMatchObject({
      name: "擦餐桌",
      category: "清洁",
      minutes: 20,
      points: 20,
      icon: "chore_custom_generic_01",
      customSlot: 1,
      suggestedFrequency: null,
      isCustom: true,
      isLocked: false,
    });

    await request(app.getHttpServer())
      .post(`/families/${familyId}/custom-chores`)
      .set("Authorization", `Bearer ${owner.token}`)
      .send({
        name: "浇阳台花草",
        iconKey: "chore_custom_plant",
        category: "照顾",
        standardMinutes: 10,
        difficultyMultiplier: 0.8,
      })
      .expect(201)
      .expect(({ body }) => {
        expect(body).toMatchObject({ points: 8, customSlot: 2, isCustom: true });
      });

    await request(app.getHttpServer())
      .post(`/families/${familyId}/custom-chores`)
      .set("Authorization", `Bearer ${owner.token}`)
      .send({
        name: "擦窗三号",
        iconKey: "chore_custom_admin",
        category: "家庭事务",
        standardMinutes: 10,
        difficultyMultiplier: 1,
      })
      .expect(409);

    await request(app.getHttpServer())
      .post("/auth/redeem-premium")
      .set("Authorization", `Bearer ${owner.token}`)
      .send({ code: "241255" })
      .expect(201);

    await request(app.getHttpServer())
      .post(`/families/${familyId}/custom-chores`)
      .set("Authorization", `Bearer ${owner.token}`)
      .send({
        name: "擦窗三号",
        iconKey: "chore_custom_admin",
        category: "家庭事务",
        standardMinutes: 10,
        difficultyMultiplier: 1,
      })
      .expect(201)
      .expect(({ body }) => expect(body.customSlot).toBe(3));

    await request(app.getHttpServer())
      .post(`/families/${familyId}/custom-chores`)
      .set("Authorization", `Bearer ${owner.token}`)
      .send({
        name: "擦窗四号",
        iconKey: "chore_custom_window",
        category: "清洁",
        standardMinutes: 20,
        difficultyMultiplier: 1,
      })
      .expect(201)
      .expect(({ body }) => expect(body.customSlot).toBe(4));

    await request(app.getHttpServer())
      .post(`/families/${familyId}/custom-chores`)
      .set("Authorization", `Bearer ${owner.token}`)
      .send({
        name: "擦窗五号",
        iconKey: "chore_custom_car",
        category: "清洁",
        standardMinutes: 20,
        difficultyMultiplier: 1,
      })
      .expect(201)
      .expect(({ body }) => expect(body.customSlot).toBe(5));

    for (const slot of [6, 7, 8, 9, 10]) {
      await request(app.getHttpServer())
        .post(`/families/${familyId}/custom-chores`)
        .set("Authorization", `Bearer ${owner.token}`)
        .send({
          name: `自定${slot}`,
          iconKey: "chore_custom_car",
          category: "家庭事务",
          standardMinutes: 20,
          difficultyMultiplier: 1,
        })
        .expect(201)
        .expect(({ body }) => expect(body.customSlot).toBe(slot));
    }

    await request(app.getHttpServer())
      .post(`/families/${familyId}/custom-chores`)
      .set("Authorization", `Bearer ${owner.token}`)
      .send({
        name: "自定11",
        iconKey: "chore_custom_car",
        category: "家庭事务",
        standardMinutes: 20,
        difficultyMultiplier: 1,
      })
      .expect(201)
      .expect(({ body }) => expect(body.customSlot).toBe(11));

    await prisma.chore.createMany({
      data: Array.from({ length: 88 }, (_, index) => {
        const slot = index + 12;
        return {
          familyId,
          createdById: owner.userId,
          name: `保护${slot}`,
          themeKey: "custom",
          category: "家庭事务",
          standardMinutes: 10,
          difficultyMultiplier: 1,
          defaultPoints: 10,
          icon: "chore_custom_generic_01",
          isFreeCore: false,
          isCustom: true,
          customSlot: slot,
          sortOrder: slot,
        };
      }),
    });

    await request(app.getHttpServer())
      .post(`/families/${familyId}/custom-chores`)
      .set("Authorization", `Bearer ${owner.token}`)
      .send({
        name: "自定100",
        iconKey: "chore_custom_generic_02",
        category: "家庭事务",
        standardMinutes: 20,
        difficultyMultiplier: 1,
      })
      .expect(201)
      .expect(({ body }) => expect(body.customSlot).toBe(100));

    await request(app.getHttpServer())
      .post(`/families/${familyId}/custom-chores`)
      .set("Authorization", `Bearer ${owner.token}`)
      .send({
        name: "自定101",
        iconKey: "chore_custom_generic_03",
        category: "家庭事务",
        standardMinutes: 20,
        difficultyMultiplier: 1,
      })
      .expect(409);

    const updatedResponse = await request(app.getHttpServer())
      .patch(`/families/${familyId}/custom-chores/${firstResponse.body.id}`)
      .set("Authorization", `Bearer ${owner.token}`)
      .send({
        name: "深度擦桌",
        iconKey: "chore_custom_dust",
        category: "整理",
        standardMinutes: 30,
        difficultyMultiplier: 1.5,
      })
      .expect(200);

    expect(updatedResponse.body).toMatchObject({
      name: "深度擦桌",
      category: "整理",
      minutes: 30,
      difficultyMultiplier: 1.5,
      points: 45,
    });

    const recordResponse = await request(app.getHttpServer())
      .post("/chore-records")
      .set("Authorization", `Bearer ${owner.token}`)
      .send({ familyId, choreId: firstResponse.body.id, actualMinutes: 60 })
      .expect(201);
    expect(recordResponse.body).toMatchObject({ actualMinutes: 60, points: 90 });

    await request(app.getHttpServer())
      .delete(`/families/${familyId}/custom-chores/${firstResponse.body.id}`)
      .set("Authorization", `Bearer ${owner.token}`)
      .expect(200);

    const listResponse = await request(app.getHttpServer())
      .get(`/families/${familyId}/custom-chores`)
      .set("Authorization", `Bearer ${owner.token}`)
      .expect(200);
    expect(listResponse.body).toHaveLength(99);

    await request(app.getHttpServer())
      .post("/chore-records")
      .set("Authorization", `Bearer ${owner.token}`)
      .send({ familyId, choreId: firstResponse.body.id, actualMinutes: 30 })
      .expect(404);

    await request(app.getHttpServer())
      .post(`/families/${familyId}/custom-chores`)
      .set("Authorization", `Bearer ${owner.token}`)
      .send({
        name: "家庭账单",
        iconKey: "chore_custom_admin",
        category: "家庭事务",
        standardMinutes: 15,
        difficultyMultiplier: 1.2,
      })
      .expect(201)
      .expect(({ body }) => {
        expect(body).toMatchObject({ customSlot: 1, points: 18 });
      });
  });

  it("enforces membership review, record permissions, likes, and soft-delete aggregation", async () => {
    const owner = await login("E2E owner");
    const member = await login("E2E member");
    const rejectedUser = await login("E2E rejected member");

    const familyResponse = await request(app.getHttpServer())
      .post("/families")
      .set("Authorization", `Bearer ${owner.token}`)
      .send({
        name: "E2E interaction family",
        requirePhotoProof: false,
        timezone: "Asia/Shanghai",
        identityLabel: "老爸",
        avatarKey: "avatar_owner",
      })
      .expect(201);
    const familyId = familyResponse.body.id as string;
    const inviteCode = familyResponse.body.inviteCode as string;

    expect(familyResponse.body.requirePhotoProof).toBe(false);
    expect(familyResponse.body.timezone).toBe("Asia/Shanghai");
    expect(inviteCode).toMatch(/^[A-F0-9]{8}$/);

    expect(familyResponse.body.members[0]).toMatchObject({
      userId: owner.userId,
      identityLabel: "老爸",
      avatarKey: "avatar_owner",
      memberRole: "OWNER",
      status: "ACTIVE",
    });

    const invitePreviewResponse = await request(app.getHttpServer())
      .get(`/families/invitations/${inviteCode.toLowerCase()}`)
      .set("Authorization", `Bearer ${member.token}`)
      .expect(200);

    expect(invitePreviewResponse.body).toMatchObject({
      id: familyId,
      name: "E2E interaction family",
      inviteCode,
      memberCount: 1,
      currentStatus: null,
      owner: {
        displayName: "E2E owner",
        identityLabel: "老爸",
        avatarKey: "avatar_owner",
      },
    });

    await request(app.getHttpServer())
      .get("/families/invitations/NOTFOUND")
      .set("Authorization", `Bearer ${member.token}`)
      .expect(404);

    const joinResponse = await request(app.getHttpServer())
      .post("/families/join-requests")
      .set("Authorization", `Bearer ${member.token}`)
      .send({
        inviteCode: inviteCode.toLowerCase(),
        identityLabel: "室友",
        avatarKey: "avatar_member",
      })
      .expect(201);
    const memberId = joinResponse.body.id as string;

    expect(joinResponse.body).toMatchObject({
      userId: member.userId,
      memberRole: "MEMBER",
      status: "PENDING",
      identityLabel: "室友",
      avatarKey: "avatar_member",
    });

    const memberPendingStatusResponse = await request(app.getHttpServer())
      .get("/families/join-requests/me")
      .set("Authorization", `Bearer ${member.token}`)
      .expect(200);

    expect(memberPendingStatusResponse.body).toMatchObject({
      id: memberId,
      status: "PENDING",
      family: {
        id: familyId,
        name: "E2E interaction family",
        inviteCode,
        memberCount: 1,
      },
    });

    const repeatedJoinResponse = await request(app.getHttpServer())
      .post("/families/join-requests")
      .set("Authorization", `Bearer ${member.token}`)
      .send({
        inviteCode,
        identityLabel: "室友",
        avatarKey: "avatar_member",
      })
      .expect(201);

    expect(repeatedJoinResponse.body.id).toBe(memberId);
    await expect(
      prisma.familyMember.count({
        where: { familyId, userId: member.userId },
      }),
    ).resolves.toBe(1);

    const missingInviteResponse = await request(app.getHttpServer())
      .post("/families/join-requests")
      .set("Authorization", `Bearer ${member.token}`)
      .send({ inviteCode: "NOTFOUND", identityLabel: "室友" })
      .expect(404);

    expect(missingInviteResponse.body.message).toBe("Invite code not found");

    await request(app.getHttpServer())
      .get("/families/me")
      .set("Authorization", `Bearer ${member.token}`)
      .expect(200, []);

    await request(app.getHttpServer())
      .post("/chore-records")
      .set("Authorization", `Bearer ${member.token}`)
      .send({ familyId, choreId, actualMinutes: 20 })
      .expect(403);

    await request(app.getHttpServer())
      .get(`/families/${familyId}/join-requests`)
      .set("Authorization", `Bearer ${member.token}`)
      .expect(403);

    await request(app.getHttpServer())
      .patch(`/families/${familyId}/join-requests/${memberId}`)
      .set("Authorization", `Bearer ${member.token}`)
      .send({ action: "approve" })
      .expect(403);

    const pendingResponse = await request(app.getHttpServer())
      .get(`/families/${familyId}/join-requests`)
      .set("Authorization", `Bearer ${owner.token}`)
      .expect(200);

    expect(pendingResponse.body).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          id: memberId,
          status: "PENDING",
        }),
      ]),
    );

    const approveResponse = await request(app.getHttpServer())
      .patch(`/families/${familyId}/join-requests/${memberId}`)
      .set("Authorization", `Bearer ${owner.token}`)
      .send({ action: "approve" })
      .expect(200);

    expect(approveResponse.body).toMatchObject({
      status: "ACTIVE",
      memberRole: "MEMBER",
      approvedById: owner.userId,
    });

    const memberApprovedStatusResponse = await request(app.getHttpServer())
      .get("/families/join-requests/me")
      .set("Authorization", `Bearer ${member.token}`)
      .expect(200);

    expect(memberApprovedStatusResponse.body).toMatchObject({
      id: memberId,
      status: "ACTIVE",
      family: {
        id: familyId,
        memberCount: 2,
      },
    });

    const memberFamiliesResponse = await request(app.getHttpServer())
      .get("/families/me")
      .set("Authorization", `Bearer ${member.token}`)
      .expect(200);

    expect(memberFamiliesResponse.body[0]).toMatchObject({
      id: familyId,
      identityLabel: "室友",
      avatarKey: "avatar_member",
      memberRole: "MEMBER",
      status: "ACTIVE",
      myRole: "member",
    });

    await request(app.getHttpServer())
      .get(`/families/${familyId}/join-requests`)
      .set("Authorization", `Bearer ${member.token}`)
      .expect(403);

    const rejectedJoinResponse = await request(app.getHttpServer())
      .post(`/families/${familyId}/join-requests`)
      .set("Authorization", `Bearer ${rejectedUser.token}`)
      .send({
        identityLabel: "自定义",
        customIdentity: "临时观察员",
        avatarKey: "avatar_rejected",
      })
      .expect(201);

    const rejectResponse = await request(app.getHttpServer())
      .patch(`/families/${familyId}/join-requests/${rejectedJoinResponse.body.id}`)
      .set("Authorization", `Bearer ${owner.token}`)
      .send({ action: "reject" })
      .expect(200);

    expect(rejectResponse.body).toMatchObject({
      status: "REJECTED",
      memberRole: "MEMBER",
      approvedById: owner.userId,
    });

    const rejectedStatusResponse = await request(app.getHttpServer())
      .get("/families/join-requests/me")
      .set("Authorization", `Bearer ${rejectedUser.token}`)
      .expect(200);

    expect(rejectedStatusResponse.body).toMatchObject({
      id: rejectedJoinResponse.body.id,
      status: "REJECTED",
      family: {
        id: familyId,
        inviteCode,
      },
    });

    const resubmittedJoinResponse = await request(app.getHttpServer())
      .post("/families/join-requests")
      .set("Authorization", `Bearer ${rejectedUser.token}`)
      .send({
        inviteCode,
        identityLabel: "室友",
        avatarKey: "avatar_resubmitted",
      })
      .expect(201);

    expect(resubmittedJoinResponse.body).toMatchObject({
      id: rejectedJoinResponse.body.id,
      status: "PENDING",
      identityLabel: "室友",
      avatarKey: "avatar_resubmitted",
      approvedAt: null,
      approvedById: null,
    });

    await request(app.getHttpServer())
      .patch(`/families/${familyId}/join-requests/${rejectedJoinResponse.body.id}`)
      .set("Authorization", `Bearer ${owner.token}`)
      .send({ action: "reject" })
      .expect(200);

    await request(app.getHttpServer())
      .post("/chore-records")
      .set("Authorization", `Bearer ${rejectedUser.token}`)
      .send({ familyId, choreId, actualMinutes: 20 })
      .expect(403);

    const minimumDurationRecord = await request(app.getHttpServer())
      .post("/chore-records")
      .set("Authorization", `Bearer ${member.token}`)
      .send({ familyId, choreId, actualMinutes: 1, note: "minimum duration" })
      .expect(201);

    expect(minimumDurationRecord.body).toMatchObject({
      actualMinutes: 1,
      points: 1,
    });

    const maximumDurationRecord = await request(app.getHttpServer())
      .post("/chore-records")
      .set("Authorization", `Bearer ${member.token}`)
      .send({ familyId, choreId, actualMinutes: 180, note: "maximum duration" })
      .expect(201);

    expect(maximumDurationRecord.body).toMatchObject({
      actualMinutes: 180,
      points: 240,
    });

    await request(app.getHttpServer())
      .post("/chore-records")
      .set("Authorization", `Bearer ${member.token}`)
      .send({ familyId, choreId, actualMinutes: 0 })
      .expect(400);

    await request(app.getHttpServer())
      .post("/chore-records")
      .set("Authorization", `Bearer ${member.token}`)
      .send({ familyId, choreId, actualMinutes: 181 })
      .expect(400);

    await request(app.getHttpServer())
      .delete(`/chore-records/${minimumDurationRecord.body.id}`)
      .set("Authorization", `Bearer ${member.token}`)
      .expect(200);

    await request(app.getHttpServer())
      .delete(`/chore-records/${maximumDurationRecord.body.id}`)
      .set("Authorization", `Bearer ${member.token}`)
      .expect(200);

    const ownerRecordResponse = await request(app.getHttpServer())
      .post("/chore-records")
      .set("Authorization", `Bearer ${owner.token}`)
      .send({ familyId, choreId, actualMinutes: 15, note: "owner record" })
      .expect(201);
    const ownerRecordId = ownerRecordResponse.body.id as string;

    const historicalDate = new Date();
    historicalDate.setUTCMonth(historicalDate.getUTCMonth() - 2);
    const historicalRecord = await prisma.choreRecord.create({
      data: {
        familyId,
        userId: owner.userId,
        choreId,
        note: "historical record",
        imageUrls: [],
        minutes: 15,
        actualMinutes: 15,
        points: 20,
        creatorDisplayNameSnapshot: "E2E owner",
        creatorIdentityLabelSnapshot: "老爸",
        creatorAvatarKeySnapshot: "avatar_owner",
        createdAt: historicalDate,
      },
    });

    expect(ownerRecordResponse.body).toMatchObject({
      actualMinutes: 15,
      points: 20,
      likeCount: 0,
      likedByMe: false,
      canDelete: true,
      canEdit: true,
    });

    await request(app.getHttpServer())
      .patch(`/chore-records/${ownerRecordId}`)
      .set("Authorization", `Bearer ${member.token}`)
      .send({ actualMinutes: 18 })
      .expect(403);

    await request(app.getHttpServer())
      .patch(`/chore-records/${ownerRecordId}`)
      .set("Authorization", `Bearer ${owner.token}`)
      .send({ actualMinutes: 18 })
      .expect(200)
      .expect(({ body }) => {
        expect(body).toMatchObject({ actualMinutes: 18, points: 24, canEdit: true });
      });

    await request(app.getHttpServer())
      .patch(`/chore-records/${ownerRecordId}`)
      .set("Authorization", `Bearer ${owner.token}`)
      .send({ actualMinutes: 0 })
      .expect(400);

    await request(app.getHttpServer())
      .patch(`/chore-records/${ownerRecordId}`)
      .set("Authorization", `Bearer ${owner.token}`)
      .send({ actualMinutes: 15 })
      .expect(200);

    await request(app.getHttpServer())
      .delete(`/chore-records/${ownerRecordId}`)
      .set("Authorization", `Bearer ${member.token}`)
      .expect(403);

    const likeResponse = await request(app.getHttpServer())
      .post(`/chore-records/${ownerRecordId}/like`)
      .set("Authorization", `Bearer ${member.token}`)
      .expect(201);

    expect(likeResponse.body).toEqual({
      recordId: ownerRecordId,
      likeCount: 1,
      likedByMe: true,
      myReaction: "like",
      reactionCounts: {
        like: 1,
        high_five: 0,
        moon_face: 0,
        laugh_cry: 0,
        tease: 0,
      },
    });

    await request(app.getHttpServer())
      .post(`/chore-records/${ownerRecordId}/like`)
      .set("Authorization", `Bearer ${member.token}`)
      .expect(201, {
        recordId: ownerRecordId,
        likeCount: 1,
        likedByMe: true,
        myReaction: "like",
        reactionCounts: {
          like: 1,
          high_five: 0,
          moon_face: 0,
          laugh_cry: 0,
          tease: 0,
        },
      });

    await request(app.getHttpServer())
      .post(`/chore-records/${ownerRecordId}/like`)
      .set("Authorization", `Bearer ${member.token}`)
      .send({ reactionKey: "high_five" })
      .expect(201, {
        recordId: ownerRecordId,
        likeCount: 1,
        likedByMe: true,
        myReaction: "high_five",
        reactionCounts: {
          like: 0,
          high_five: 1,
          moon_face: 0,
          laugh_cry: 0,
          tease: 0,
        },
      });

    await request(app.getHttpServer())
      .post(`/chore-records/${ownerRecordId}/like`)
      .set("Authorization", `Bearer ${member.token}`)
      .send({ reactionKey: "not-a-reaction" })
      .expect(400);

    const memberActivityResponse = await request(app.getHttpServer())
      .get(`/families/${familyId}/activity`)
      .set("Authorization", `Bearer ${member.token}`)
      .expect(200);

    expect(memberActivityResponse.body[0]).toMatchObject({
      id: ownerRecordId,
      recordId: ownerRecordId,
      choreName: "E2E actual minutes chore",
      actualMinutes: 15,
      points: 20,
      createdBy: {
        id: owner.userId,
        identityLabel: "老爸",
        avatarKey: "avatar_owner",
      },
      likeCount: 1,
      likedByMe: true,
      myReaction: "high_five",
      reactionCounts: expect.objectContaining({ high_five: 1 }),
      canDelete: false,
      canEdit: false,
    });
    expect(memberActivityResponse.body[0].likedBy).toEqual([
      expect.objectContaining({
        id: member.userId,
        identityLabel: "室友",
        avatarKey: "avatar_member",
        reactionKey: "high_five",
      }),
    ]);

    const ownerActivityResponse = await request(app.getHttpServer())
      .get(`/families/${familyId}/activity`)
      .set("Authorization", `Bearer ${owner.token}`)
      .expect(200);

    expect(ownerActivityResponse.body[0]).toMatchObject({
      recordId: ownerRecordId,
      likedByMe: false,
      canDelete: true,
      canEdit: true,
    });

    const unlikeResponse = await request(app.getHttpServer())
      .delete(`/chore-records/${ownerRecordId}/like`)
      .set("Authorization", `Bearer ${member.token}`)
      .expect(200);

    expect(unlikeResponse.body).toEqual({
      recordId: ownerRecordId,
      likeCount: 0,
      likedByMe: false,
      myReaction: null,
      reactionCounts: {
        like: 0,
        high_five: 0,
        moon_face: 0,
        laugh_cry: 0,
        tease: 0,
      },
    });

    await request(app.getHttpServer())
      .delete(`/chore-records/${ownerRecordId}/like`)
      .set("Authorization", `Bearer ${member.token}`)
      .expect(200, {
        recordId: ownerRecordId,
        likeCount: 0,
        likedByMe: false,
        myReaction: null,
        reactionCounts: {
          like: 0,
          high_five: 0,
          moon_face: 0,
          laugh_cry: 0,
          tease: 0,
        },
      });

    const memberOwnRecordResponse = await request(app.getHttpServer())
      .post("/chore-records")
      .set("Authorization", `Bearer ${member.token}`)
      .send({ familyId, choreId, actualMinutes: 20, note: "member own record" })
      .expect(201);
    const memberOwnRecordId = memberOwnRecordResponse.body.id as string;

    await request(app.getHttpServer())
      .delete(`/chore-records/${memberOwnRecordId}`)
      .set("Authorization", `Bearer ${member.token}`)
      .expect(200);

    const ownDeletedRecord = await prisma.choreRecord.findUniqueOrThrow({
      where: { id: memberOwnRecordId },
    });
    expect(ownDeletedRecord.deletedAt).toBeInstanceOf(Date);
    expect(ownDeletedRecord.deletedById).toBe(member.userId);

    const memberRecordForOwnerResponse = await request(app.getHttpServer())
      .post("/chore-records")
      .set("Authorization", `Bearer ${member.token}`)
      .send({ familyId, choreId, actualMinutes: 30, note: "owner deletes this" })
      .expect(201);
    const memberRecordForOwnerId = memberRecordForOwnerResponse.body.id as string;

    await request(app.getHttpServer())
      .delete(`/chore-records/${memberRecordForOwnerId}`)
      .set("Authorization", `Bearer ${owner.token}`)
      .expect(200);

    const ownerDeletedRecord = await prisma.choreRecord.findUniqueOrThrow({
      where: { id: memberRecordForOwnerId },
    });
    expect(ownerDeletedRecord.deletedAt).toBeInstanceOf(Date);
    expect(ownerDeletedRecord.deletedById).toBe(owner.userId);

    await request(app.getHttpServer())
      .post(`/chore-records/${memberRecordForOwnerId}/restore`)
      .set("Authorization", `Bearer ${owner.token}`)
      .expect(201, { recordId: memberRecordForOwnerId, restored: true });

    const ownerRestoredRecord = await prisma.choreRecord.findUniqueOrThrow({
      where: { id: memberRecordForOwnerId },
    });
    expect(ownerRestoredRecord.deletedAt).toBeNull();
    expect(ownerRestoredRecord.deletedById).toBeNull();

    await request(app.getHttpServer())
      .delete(`/chore-records/${memberRecordForOwnerId}`)
      .set("Authorization", `Bearer ${owner.token}`)
      .expect(200);

    const todayActivityResponse = await request(app.getHttpServer())
      .get(`/families/${familyId}/activity?range=day`)
      .set("Authorization", `Bearer ${owner.token}`)
      .expect(200);

    expect(todayActivityResponse.body).toHaveLength(1);
    expect(todayActivityResponse.body[0].recordId).toBe(ownerRecordId);

    const recentActivityResponse = await request(app.getHttpServer())
      .get(`/families/${familyId}/activity?range=recent`)
      .set("Authorization", `Bearer ${owner.token}`)
      .expect(200);

    expect(recentActivityResponse.body.map((record: { recordId: string }) => record.recordId)).toEqual(
      expect.arrayContaining([ownerRecordId, historicalRecord.id]),
    );
    expect(recentActivityResponse.body).toHaveLength(2);

    const defaultActivityResponse = await request(app.getHttpServer())
      .get(`/families/${familyId}/activity`)
      .set("Authorization", `Bearer ${owner.token}`)
      .expect(200);

    expect(defaultActivityResponse.body).toHaveLength(2);

    const leaderboardResponse = await request(app.getHttpServer())
      .get(`/families/${familyId}/leaderboard?range=month`)
      .set("Authorization", `Bearer ${owner.token}`)
      .expect(200);

    expect(leaderboardResponse.body).toEqual([
      expect.objectContaining({
        userId: owner.userId,
        points: 20,
        recordCount: 1,
      }),
    ]);

    const month = monthTextForTimeZone("Asia/Shanghai");
    const reportResponse = await request(app.getHttpServer())
      .get(`/families/${familyId}/monthly-report?month=${month}`)
      .set("Authorization", `Bearer ${owner.token}`)
      .expect(200);

    expect(reportResponse.body).toMatchObject({
      familyId,
      totalPoints: 20,
      totalRecords: 1,
      totalMinutes: 15,
      memberContributions: [
        expect.objectContaining({
          userId: owner.userId,
          points: 20,
          recordCount: 1,
          totalMinutes: 15,
        }),
      ],
    });
    expect(reportResponse.body.comparison).toEqual(
      expect.objectContaining({
        totalPoints: expect.any(Number),
        totalRecords: expect.any(Number),
        totalMinutes: expect.any(Number),
      }),
    );
    expect(reportResponse.body.monthlyTrend).toHaveLength(6);
    expect(reportResponse.body.monthlyTrend.at(-1)).toEqual(
      expect.objectContaining({
        month,
        points: 20,
        recordCount: 1,
        totalMinutes: 15,
      }),
    );
    expect(reportResponse.body.weeklyTrend.reduce(
      (sum: number, week: { points: number }) => sum + week.points,
      0,
    )).toBe(20);
    expect(reportResponse.body.weeklyTrend.reduce(
      (sum: number, week: { recordCount: number }) => sum + week.recordCount,
      0,
    )).toBe(1);
    expect(reportResponse.body.weeklyTrend.reduce(
      (sum: number, week: { totalMinutes: number }) => sum + week.totalMinutes,
      0,
    )).toBe(15);
    expect(reportResponse.body.categoryStats).toEqual([
      expect.objectContaining({
        points: 20,
        recordCount: 1,
        memberContributions: [
          expect.objectContaining({
            userId: owner.userId,
            points: 20,
            recordCount: 1,
            totalMinutes: 15,
          }),
        ],
      }),
    ]);
    expect(reportResponse.body.recentRecords).toEqual([
      expect.objectContaining({
        id: ownerRecordId,
        points: 20,
        actualMinutes: 15,
      }),
    ]);
  });

  it("uses family timezone for day activity and monthly report boundaries", async () => {
    const owner = await login("E2E timezone owner");
    const timezone = "Asia/Shanghai";

    const familyResponse = await request(app.getHttpServer())
      .post("/families")
      .set("Authorization", `Bearer ${owner.token}`)
      .send({
        name: "E2E timezone family",
        requirePhotoProof: false,
        timezone,
      })
      .expect(201);

    const familyId = familyResponse.body.id as string;
    expect(familyResponse.body.timezone).toBe(timezone);

    const dayRange = getDayRangeForTimeZone(timezone);
    const currentMonth = monthTextForTimeZone(timezone);
    const monthRange = getMonthRangeForTimeZone(currentMonth, timezone);
    const weekRange = getWeekRangeForTimeZone(timezone);

    const localEarlyToday = new Date(dayRange.start.getTime() + 30 * 60 * 1000);
    const localLateToday = new Date(dayRange.end.getTime() - 30 * 60 * 1000);
    const beforeLocalToday = new Date(dayRange.start.getTime() - 30 * 60 * 1000);
    const localMonthStart = new Date(monthRange.start.getTime() + 30 * 60 * 1000);

    const earlyTodayRecord = await createRecordAt({
      familyId,
      userId: owner.userId,
      choreId,
      points: 20,
      createdAt: localEarlyToday,
      note: "timezone early today",
    });
    const lateTodayRecord = await createRecordAt({
      familyId,
      userId: owner.userId,
      choreId,
      points: 30,
      createdAt: localLateToday,
      note: "timezone late today",
    });
    const yesterdayRecord = await createRecordAt({
      familyId,
      userId: owner.userId,
      choreId,
      points: 40,
      createdAt: beforeLocalToday,
      note: "timezone yesterday",
    });
    const monthBoundaryRecord = await createRecordAt({
      familyId,
      userId: owner.userId,
      choreId,
      points: 50,
      createdAt: localMonthStart,
      note: "timezone month boundary",
    });
    const deletedTodayRecord = await createRecordAt({
      familyId,
      userId: owner.userId,
      choreId,
      points: 60,
      createdAt: localEarlyToday,
      note: "timezone deleted today",
    });
    const insideWeekRecord = await createRecordAt({
      familyId,
      userId: owner.userId,
      choreId,
      points: 70,
      createdAt: new Date(weekRange.start.getTime() + 12 * 60 * 60 * 1000),
      note: "timezone inside week",
    });
    const beforeWeekRecord = await createRecordAt({
      familyId,
      userId: owner.userId,
      choreId,
      points: 80,
      createdAt: new Date(weekRange.start.getTime() - 60 * 1000),
      note: "timezone before week",
    });

    await prisma.choreRecord.update({
      where: { id: deletedTodayRecord.id },
      data: {
        deletedAt: new Date(),
        deletedById: owner.userId,
      },
    });

    const dayActivityResponse = await request(app.getHttpServer())
      .get(`/families/${familyId}/activity?range=day`)
      .set("Authorization", `Bearer ${owner.token}`)
      .expect(200);

    const dayRecordIds = dayActivityResponse.body.map((record: { recordId: string }) => record.recordId);
    expect(dayRecordIds).toEqual(expect.arrayContaining([earlyTodayRecord.id, lateTodayRecord.id]));
    expect(dayRecordIds).not.toContain(yesterdayRecord.id);
    expect(dayRecordIds).not.toContain(deletedTodayRecord.id);

    const weekActivityResponse = await request(app.getHttpServer())
      .get(`/families/${familyId}/activity?range=week`)
      .set("Authorization", `Bearer ${owner.token}`)
      .expect(200);

    const weekRecordIds = weekActivityResponse.body.map((record: { recordId: string }) => record.recordId);
    expect(weekRecordIds).toContain(insideWeekRecord.id);
    expect(weekRecordIds).not.toContain(beforeWeekRecord.id);
    expect(weekRecordIds).not.toContain(deletedTodayRecord.id);

    const expectedWeeklyRecords = [
      earlyTodayRecord,
      lateTodayRecord,
      yesterdayRecord,
      monthBoundaryRecord,
      insideWeekRecord,
      beforeWeekRecord,
    ].filter((record) => record.createdAt >= weekRange.start && record.createdAt < weekRange.end);
    const weekLeaderboardResponse = await request(app.getHttpServer())
      .get(`/families/${familyId}/leaderboard?range=week`)
      .set("Authorization", `Bearer ${owner.token}`)
      .expect(200);

    expect(weekLeaderboardResponse.body).toEqual([
      expect.objectContaining({
        userId: owner.userId,
        points: expectedWeeklyRecords.reduce((sum, record) => sum + record.points, 0),
        recordCount: expectedWeeklyRecords.length,
      }),
    ]);

    const reportResponse = await request(app.getHttpServer())
      .get(`/families/${familyId}/monthly-report?month=${currentMonth}`)
      .set("Authorization", `Bearer ${owner.token}`)
      .expect(200);

    const expectedMonthlyRecords = [
      earlyTodayRecord,
      lateTodayRecord,
      yesterdayRecord,
      monthBoundaryRecord,
      insideWeekRecord,
      beforeWeekRecord,
    ].filter((record) => record.createdAt >= monthRange.start && record.createdAt < monthRange.end);
    const expectedMonthlyPoints = expectedMonthlyRecords.reduce((sum, record) => sum + record.points, 0);
    const expectedMonthlyMinutes = expectedMonthlyRecords.length * 15;

    expect(reportResponse.body).toMatchObject({
      familyId,
      month: currentMonth,
      totalPoints: expectedMonthlyPoints,
      totalRecords: expectedMonthlyRecords.length,
      totalMinutes: expectedMonthlyMinutes,
      themeStats: [
        {
          themeKey: "daily",
          points: expectedMonthlyPoints,
          recordCount: expectedMonthlyRecords.length,
        },
      ],
    });
    expect(reportResponse.body.recentRecords.map((record: { id: string }) => record.id)).toEqual(
      expect.arrayContaining(expectedMonthlyRecords.map((record) => record.id)),
    );
    expect(reportResponse.body.recentRecords.map((record: { id: string }) => record.id)).not.toContain(
      deletedTodayRecord.id,
    );
  });

  it("transfers family ownership to an active member atomically", async () => {
    const owner = await login("E2E transfer owner");
    const member = await login("E2E transfer member");

    const familyResponse = await request(app.getHttpServer())
      .post("/families")
      .set("Authorization", `Bearer ${owner.token}`)
      .send({ name: "E2E transfer family", identityLabel: "老爸" })
      .expect(201);
    const familyId = familyResponse.body.id as string;
    const inviteCode = familyResponse.body.inviteCode as string;

    const joinResponse = await request(app.getHttpServer())
      .post("/families/join-requests")
      .set("Authorization", `Bearer ${member.token}`)
      .send({ inviteCode, identityLabel: "室友", avatarKey: "avatar_02" })
      .expect(201);
    const memberId = joinResponse.body.id as string;

    await request(app.getHttpServer())
      .patch(`/families/${familyId}/join-requests/${memberId}`)
      .set("Authorization", `Bearer ${owner.token}`)
      .send({ action: "approve" })
      .expect(200);

    await request(app.getHttpServer())
      .patch(`/families/${familyId}/owner`)
      .set("Authorization", `Bearer ${member.token}`)
      .send({ memberId })
      .expect(403);

    const transferResponse = await request(app.getHttpServer())
      .patch(`/families/${familyId}/owner`)
      .set("Authorization", `Bearer ${owner.token}`)
      .send({ memberId })
      .expect(200);

    expect(transferResponse.body).toMatchObject({
      familyId,
      previousOwner: {
        userId: owner.userId,
        memberRole: "MEMBER",
      },
      newOwner: {
        id: memberId,
        userId: member.userId,
        memberRole: "OWNER",
      },
    });

    const oldOwnerFamilies = await request(app.getHttpServer())
      .get("/families/me")
      .set("Authorization", `Bearer ${owner.token}`)
      .expect(200);
    const newOwnerFamilies = await request(app.getHttpServer())
      .get("/families/me")
      .set("Authorization", `Bearer ${member.token}`)
      .expect(200);

    expect(oldOwnerFamilies.body[0].memberRole).toBe("MEMBER");
    expect(newOwnerFamilies.body[0].memberRole).toBe("OWNER");

    await request(app.getHttpServer())
      .get(`/families/${familyId}/join-requests`)
      .set("Authorization", `Bearer ${owner.token}`)
      .expect(403);
    await request(app.getHttpServer())
      .get(`/families/${familyId}/join-requests`)
      .set("Authorization", `Bearer ${member.token}`)
      .expect(200);

    await request(app.getHttpServer())
      .delete(`/families/${familyId}/members/me`)
      .set("Authorization", `Bearer ${member.token}`)
      .expect(400);

    const leaveResponse = await request(app.getHttpServer())
      .delete(`/families/${familyId}/members/me`)
      .set("Authorization", `Bearer ${owner.token}`)
      .expect(200);

    expect(leaveResponse.body).toEqual({ familyId, left: true });

    const formerOwnerFamilies = await request(app.getHttpServer())
      .get("/families/me")
      .set("Authorization", `Bearer ${owner.token}`)
      .expect(200);

    expect(formerOwnerFamilies.body).toEqual([]);
  });

  it("preserves membership and record history when a member leaves and rejoins", async () => {
    const suffix = Date.now();
    const originalMemberName = `returning-member-${suffix}`;
    const renamedMemberName = `renamed-member-${suffix}`;
    const owner = await login(`returning-owner-${suffix}`);
    const member = await login(originalMemberName);

    const familyResponse = await request(app.getHttpServer())
      .post("/families")
      .set("Authorization", `Bearer ${owner.token}`)
      .send({ name: "E2E returning family", identityLabel: "老爸", avatarKey: "avatar_01" })
      .expect(201);
    const familyId = familyResponse.body.id as string;
    const inviteCode = familyResponse.body.inviteCode as string;

    const firstJoinResponse = await request(app.getHttpServer())
      .post("/families/join-requests")
      .set("Authorization", `Bearer ${member.token}`)
      .send({ inviteCode, identityLabel: "室友", avatarKey: "avatar_02" })
      .expect(201);
    const membershipId = firstJoinResponse.body.id as string;

    await request(app.getHttpServer())
      .patch(`/families/${familyId}/join-requests/${membershipId}`)
      .set("Authorization", `Bearer ${owner.token}`)
      .send({ action: "approve" })
      .expect(200);

    const recordResponse = await request(app.getHttpServer())
      .post("/chore-records")
      .set("Authorization", `Bearer ${member.token}`)
      .send({ familyId, choreId, actualMinutes: 15, note: "before leaving" })
      .expect(201);

    await request(app.getHttpServer())
      .patch("/auth/me")
      .set("Authorization", `Bearer ${member.token}`)
      .send({ displayName: renamedMemberName })
      .expect(200);

    await request(app.getHttpServer())
      .delete(`/families/${familyId}/members/me`)
      .set("Authorization", `Bearer ${member.token}`)
      .expect(200);

    const leftMembership = await prisma.familyMember.findUniqueOrThrow({
      where: { id: membershipId },
    });
    expect(leftMembership).toMatchObject({
      id: membershipId,
      status: "LEFT",
      memberRole: "MEMBER",
    });
    expect(leftMembership.leftAt).toBeInstanceOf(Date);

    const memberFamiliesWhileLeft = await request(app.getHttpServer())
      .get("/families/me")
      .set("Authorization", `Bearer ${member.token}`)
      .expect(200);
    expect(memberFamiliesWhileLeft.body).toEqual([]);

    const activityWhileLeft = await request(app.getHttpServer())
      .get(`/families/${familyId}/activity?range=recent`)
      .set("Authorization", `Bearer ${owner.token}`)
      .expect(200);
    expect(activityWhileLeft.body).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          recordId: recordResponse.body.recordId,
          createdBy: expect.objectContaining({
            id: member.userId,
            displayName: originalMemberName,
            identityLabel: "室友",
            avatarKey: "avatar_02",
          }),
        }),
      ]),
    );

    const invitePreview = await request(app.getHttpServer())
      .get(`/families/invitations/${inviteCode}`)
      .set("Authorization", `Bearer ${member.token}`)
      .expect(200);
    expect(invitePreview.body.currentStatus).toBeNull();

    const rejoinResponse = await request(app.getHttpServer())
      .post("/families/join-requests")
      .set("Authorization", `Bearer ${member.token}`)
      .send({ inviteCode, identityLabel: "哥哥", avatarKey: "avatar_13" })
      .expect(201);
    expect(rejoinResponse.body).toMatchObject({
      id: membershipId,
      userId: member.userId,
      status: "PENDING",
      identityLabel: "哥哥",
      avatarKey: "avatar_13",
      leftAt: null,
    });

    await request(app.getHttpServer())
      .patch(`/families/${familyId}/join-requests/${membershipId}`)
      .set("Authorization", `Bearer ${owner.token}`)
      .send({ action: "approve" })
      .expect(200);

    const memberFamiliesAfterRejoin = await request(app.getHttpServer())
      .get("/families/me")
      .set("Authorization", `Bearer ${member.token}`)
      .expect(200);
    expect(memberFamiliesAfterRejoin.body[0].myMembership).toMatchObject({
      id: membershipId,
      identityLabel: "哥哥",
      avatarKey: "avatar_13",
      status: "ACTIVE",
    });

    const activityAfterRejoin = await request(app.getHttpServer())
      .get(`/families/${familyId}/activity?range=recent`)
      .set("Authorization", `Bearer ${member.token}`)
      .expect(200);
    expect(activityAfterRejoin.body).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          recordId: recordResponse.body.recordId,
          createdBy: expect.objectContaining({
            displayName: originalMemberName,
            identityLabel: "室友",
            avatarKey: "avatar_13",
          }),
        }),
      ]),
    );

    const leaderboardResponse = await request(app.getHttpServer())
      .get(`/families/${familyId}/leaderboard?range=month`)
      .set("Authorization", `Bearer ${member.token}`)
      .expect(200);
    expect(leaderboardResponse.body).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ userId: member.userId, points: recordResponse.body.points }),
      ]),
    );
  });

  it("lets the owner rename a family and returns one member's recent activity", async () => {
    const suffix = Date.now();
    const ownerName = `profile-owner-${suffix}`;
    const memberName = `profile-member-${suffix}`;
    const owner = await login(ownerName);
    const member = await login(memberName);

    const familyResponse = await request(app.getHttpServer())
      .post("/families")
      .set("Authorization", `Bearer ${owner.token}`)
      .send({ name: "E2E old profile family", identityLabel: "老爸" })
      .expect(201);
    const familyId = familyResponse.body.id as string;

    const renamedFamily = await request(app.getHttpServer())
      .patch(`/families/${familyId}`)
      .set("Authorization", `Bearer ${owner.token}`)
      .send({ name: "E2E new profile family" })
      .expect(200);
    expect(renamedFamily.body.name).toBe("E2E new profile family");

    const joinResponse = await request(app.getHttpServer())
      .post("/families/join-requests")
      .set("Authorization", `Bearer ${member.token}`)
      .send({
        inviteCode: familyResponse.body.inviteCode,
        identityLabel: "室友",
        avatarKey: "avatar_02",
      })
      .expect(201);
    const memberId = joinResponse.body.id as string;

    await request(app.getHttpServer())
      .patch(`/families/${familyId}/join-requests/${memberId}`)
      .set("Authorization", `Bearer ${owner.token}`)
      .send({ action: "approve" })
      .expect(200);

    await request(app.getHttpServer())
      .patch(`/families/${familyId}`)
      .set("Authorization", `Bearer ${member.token}`)
      .send({ name: "Member cannot rename" })
      .expect(403);

    const visibleRecord = await request(app.getHttpServer())
      .post("/chore-records")
      .set("Authorization", `Bearer ${member.token}`)
      .send({ familyId, choreId, actualMinutes: 20, note: "visible member activity" })
      .expect(201);

    const oldDate = new Date();
    oldDate.setUTCDate(oldDate.getUTCDate() - 31);
    const oldRecord = await prisma.choreRecord.create({
      data: {
        familyId,
        userId: member.userId,
        choreId,
        note: "older than thirty days",
        imageUrls: [],
        minutes: 15,
        actualMinutes: 15,
        points: 20,
        creatorDisplayNameSnapshot: memberName,
        creatorIdentityLabelSnapshot: "室友",
        creatorAvatarKeySnapshot: "avatar_02",
        createdAt: oldDate,
      },
    });
    const deletedRecord = await prisma.choreRecord.create({
      data: {
        familyId,
        userId: member.userId,
        choreId,
        note: "deleted member activity",
        imageUrls: [],
        minutes: 15,
        actualMinutes: 15,
        points: 20,
        creatorDisplayNameSnapshot: memberName,
        creatorIdentityLabelSnapshot: "室友",
        creatorAvatarKeySnapshot: "avatar_02",
        deletedAt: new Date(),
        deletedById: owner.userId,
      },
    });
    const ownerRecord = await request(app.getHttpServer())
      .post("/chore-records")
      .set("Authorization", `Bearer ${owner.token}`)
      .send({ familyId, choreId, actualMinutes: 15, note: "owner activity" })
      .expect(201);

    const memberActivity = await request(app.getHttpServer())
      .get(`/families/${familyId}/members/${memberId}/activity`)
      .set("Authorization", `Bearer ${owner.token}`)
      .expect(200);

    const recordIds = memberActivity.body.map((record: { recordId: string }) => record.recordId);
    expect(recordIds).toContain(visibleRecord.body.id);
    expect(recordIds).not.toContain(oldRecord.id);
    expect(recordIds).not.toContain(deletedRecord.id);
    expect(recordIds).not.toContain(ownerRecord.body.id);
    expect(memberActivity.body[0]).toMatchObject({
      recordId: visibleRecord.body.id,
      actualMinutes: 20,
      createdBy: {
        id: member.userId,
        displayName: memberName,
        identityLabel: "室友",
        avatarKey: "avatar_02",
      },
      canDelete: true,
    });

    const memberFamilies = await request(app.getHttpServer())
      .get("/families/me")
      .set("Authorization", `Bearer ${member.token}`)
      .expect(200);
    expect(memberFamilies.body[0].name).toBe("E2E new profile family");
  });

  it("updates the active member appearance across historical activity", async () => {
    const user = await login("E2E appearance member");
    const familyResponse = await request(app.getHttpServer())
      .post("/families")
      .set("Authorization", `Bearer ${user.token}`)
      .send({
        name: "E2E appearance family",
        identityLabel: "室友",
        avatarKey: "avatar_01",
      })
      .expect(201);
    const familyId = familyResponse.body.id as string;

    const recordResponse = await request(app.getHttpServer())
      .post("/chore-records")
      .set("Authorization", `Bearer ${user.token}`)
      .send({ familyId, choreId, actualMinutes: 15 })
      .expect(201);

    const appearanceResponse = await request(app.getHttpServer())
      .patch(`/families/${familyId}/members/me/appearance`)
      .set("Authorization", `Bearer ${user.token}`)
      .send({ avatarKey: "avatar_13" })
      .expect(200);

    expect(appearanceResponse.body).toMatchObject({
      userId: user.userId,
      familyId,
      avatarKey: "avatar_13",
      status: "ACTIVE",
    });

    const familiesResponse = await request(app.getHttpServer())
      .get("/families/me")
      .set("Authorization", `Bearer ${user.token}`)
      .expect(200);
    expect(familiesResponse.body[0].myMembership.avatarKey).toBe("avatar_13");

    await prisma.choreRecord.update({
      where: { id: recordResponse.body.recordId },
      data: { creatorAvatarKeySnapshot: "avatar_01" },
    });

    const activityResponse = await request(app.getHttpServer())
      .get(`/families/${familyId}/activity?range=recent`)
      .set("Authorization", `Bearer ${user.token}`)
      .expect(200);
    expect(activityResponse.body).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          recordId: recordResponse.body.recordId,
          createdBy: expect.objectContaining({ avatarKey: "avatar_13" }),
        }),
      ]),
    );

    await request(app.getHttpServer())
      .patch(`/families/${familyId}/members/me/appearance`)
      .set("Authorization", `Bearer ${user.token}`)
      .send({ avatarKey: "avatar_99" })
      .expect(400);
  });

  it("uses server occurrence time and only restores a soft deletion within ten seconds", async () => {
    const user = await loginWithPhone(`e2e-achievement-foundation-${Date.now()}`);
    const familyResponse = await request(app.getHttpServer())
      .post("/families")
      .set("Authorization", `Bearer ${user.token}`)
      .send({
        name: "Achievement foundation family",
        identityLabel: "一家之主",
        avatarKey: "avatar_01",
      })
      .expect(201);
    const familyId = familyResponse.body.id as string;

    await request(app.getHttpServer())
      .post("/chore-records")
      .set("Authorization", `Bearer ${user.token}`)
      .send({
        familyId,
        choreId,
        actualMinutes: 15,
        occurredAt: "2020-01-01T00:00:00.000Z",
      })
      .expect(400);

    const createResponse = await request(app.getHttpServer())
      .post("/chore-records")
      .set("Authorization", `Bearer ${user.token}`)
      .send({ familyId, choreId, actualMinutes: 15, note: "undo foundation" })
      .expect(201);
    const recordId = createResponse.body.recordId as string;
    const occurredAt = new Date(createResponse.body.occurredAt as string);
    const createdAt = new Date(createResponse.body.createdAt as string);

    expect(Number.isNaN(occurredAt.getTime())).toBe(false);
    expect(Math.abs(occurredAt.getTime() - createdAt.getTime())).toBeLessThan(2_000);

    const deleteResponse = await request(app.getHttpServer())
      .delete(`/chore-records/${recordId}`)
      .set("Authorization", `Bearer ${user.token}`)
      .expect(200);

    expect(new Date(deleteResponse.body.undoExpiresAt as string).getTime()).toBeGreaterThan(
      new Date(deleteResponse.body.deletedAt as string).getTime(),
    );

    await request(app.getHttpServer())
      .post(`/chore-records/${recordId}/restore`)
      .set("Authorization", `Bearer ${user.token}`)
      .expect(201, { recordId, restored: true });

    const restoredRecord = await prisma.choreRecord.findUniqueOrThrow({ where: { id: recordId } });
    expect(restoredRecord.deletedAt).toBeNull();
    expect(restoredRecord.deletedById).toBeNull();

    await request(app.getHttpServer())
      .delete(`/chore-records/${recordId}`)
      .set("Authorization", `Bearer ${user.token}`)
      .expect(200);

    await prisma.choreRecord.update({
      where: { id: recordId },
      data: { deletedAt: new Date(Date.now() - 11_000) },
    });

    await request(app.getHttpServer())
      .post(`/chore-records/${recordId}/restore`)
      .set("Authorization", `Bearer ${user.token}`)
      .expect(409);
  });

  it("enforces achievement definition and event idempotency constraints in the database", async () => {
    const user = await loginWithPhone(`e2e-achievement-constraints-${Date.now()}`);
    const familyResponse = await request(app.getHttpServer())
      .post("/families")
      .set("Authorization", `Bearer ${user.token}`)
      .send({ name: "Achievement constraints family", identityLabel: "一家之主" })
      .expect(201);
    const familyId = familyResponse.body.id as string;
    const uniqueSuffix = `${Date.now()}-${Math.random()}`;
    const definitionKey = `E2E_DEFINITION_${uniqueSuffix}`;

    const definition = await prisma.achievementDefinition.create({
      data: {
        key: definitionKey,
        nameKey: "e2e.name",
        descriptionKey: "e2e.description",
        unlockCopyKey: "e2e.unlock",
        ownerType: AchievementOwnerType.MEMBER,
        track: AchievementTrack.JOURNEY,
        tier: AchievementTier.NONE,
        ruleType: AchievementRuleType.FIRST_EVENT,
        ruleConfigJson: { eventType: "E2E" },
        targetValue: 1,
        windowType: AchievementWindowType.LIFETIME,
      },
    });

    await expect(
      prisma.achievementDefinition.create({
        data: {
          key: definitionKey,
          nameKey: "duplicate.name",
          descriptionKey: "duplicate.description",
          unlockCopyKey: "duplicate.unlock",
          ownerType: AchievementOwnerType.MEMBER,
          track: AchievementTrack.JOURNEY,
          tier: AchievementTier.NONE,
          ruleType: AchievementRuleType.FIRST_EVENT,
          ruleConfigJson: { eventType: "E2E_DUPLICATE" },
          targetValue: 1,
          windowType: AchievementWindowType.LIFETIME,
        },
      }),
    ).rejects.toMatchObject({ code: "P2002" });

    const sourceId = `e2e-source-${uniqueSuffix}`;
    const idempotencyKey = `e2e-idempotency-${uniqueSuffix}`;
    const event = await prisma.achievementEvent.create({
      data: {
        familyId,
        actorUserId: user.userId,
        eventType: "E2E_EVENT",
        sourceType: AchievementEventSourceType.CHORE,
        sourceId,
        sourceVersion: 1,
        idempotencyKey,
        occurredAt: new Date(),
        familyTimezoneSnapshot: "Asia/Shanghai",
        payloadJson: {},
      },
    });

    await expect(
      prisma.achievementEvent.create({
        data: {
          familyId,
          eventType: "E2E_EVENT_DIFFERENT_SOURCE",
          sourceType: AchievementEventSourceType.CHORE,
          sourceId: `${sourceId}-different`,
          sourceVersion: 1,
          idempotencyKey,
          occurredAt: new Date(),
          familyTimezoneSnapshot: "Asia/Shanghai",
          payloadJson: {},
        },
      }),
    ).rejects.toMatchObject({ code: "P2002" });

    await expect(
      prisma.achievementEvent.create({
        data: {
          familyId,
          eventType: "E2E_EVENT",
          sourceType: AchievementEventSourceType.CHORE,
          sourceId,
          sourceVersion: 1,
          idempotencyKey: `${idempotencyKey}-different`,
          occurredAt: new Date(),
          familyTimezoneSnapshot: "Asia/Shanghai",
          payloadJson: {},
        },
      }),
    ).rejects.toMatchObject({ code: "P2002" });

    await prisma.achievementEvent.delete({ where: { id: event.id } });
    await prisma.achievementDefinition.delete({ where: { id: definition.id } });
  });

  it("writes, deduplicates, processes, retries and replays achievement outbox events", async () => {
    const previousFlag = process.env.ACHIEVEMENTS_ENABLED;
    process.env.ACHIEVEMENTS_ENABLED = "true";

    try {
      const owner = await loginWithPhone(`e2e-achievement-pipeline-${Date.now()}`);
      const familyResponse = await request(app.getHttpServer())
        .post("/families")
        .set("Authorization", `Bearer ${owner.token}`)
        .send({ name: "Achievement pipeline family", identityLabel: "一家之主" })
        .expect(201);
      const familyId = familyResponse.body.id as string;
      expect(familyResponse.body.achievementEvaluation).toMatchObject({ state: "PENDING" });

      const requestKey = `e2e-record-${Date.now()}`;
      const responses = await Promise.all(
        Array.from({ length: 10 }, () =>
          request(app.getHttpServer())
            .post("/chore-records")
            .set("Authorization", `Bearer ${owner.token}`)
            .set("Idempotency-Key", requestKey)
            .send({ familyId, choreId, actualMinutes: 17, note: "idempotent achievement event" }),
        ),
      );
      expect(responses.every((response) => response.status === 201)).toBe(true);
      expect(new Set(responses.map((response) => response.body.recordId)).size).toBe(1);
      expect(
        new Set(responses.map((response) => response.body.achievementEvaluation.eventId)).size,
      ).toBe(1);

      await request(app.getHttpServer())
        .post("/chore-records")
        .set("Authorization", `Bearer ${owner.token}`)
        .set("Idempotency-Key", requestKey)
        .send({ familyId, choreId, actualMinutes: 18, note: "different request body" })
        .expect(409);

      const recordId = responses[0].body.recordId as string;
      const eventId = responses[0].body.achievementEvaluation.eventId as string;
      await expect(
        prisma.choreRecord.count({ where: { familyId, userId: owner.userId, clientRequestId: requestKey } }),
      ).resolves.toBe(1);
      await expect(
        prisma.achievementEvent.count({
          where: {
            eventType: "CHORE_CREATED",
            sourceType: AchievementEventSourceType.CHORE,
            sourceId: recordId,
          },
        }),
      ).resolves.toBe(1);

      await request(app.getHttpServer())
        .get(`/families/${familyId}/achievement-sync/${eventId}`)
        .set("Authorization", `Bearer ${owner.token}`)
        .expect(200)
        .expect(({ body }) => expect(body).toMatchObject({ eventId, state: "PENDING" }));

      const worker = app.get(AchievementWorkerService);
      for (let attempt = 0; attempt < 5; attempt += 1) {
        await worker.drainAvailable(100);
      }

      await request(app.getHttpServer())
        .get(`/families/${familyId}/achievement-sync/${eventId}`)
        .set("Authorization", `Bearer ${owner.token}`)
        .expect(200)
        .expect(({ body }) => expect(body).toMatchObject({ eventId, state: "SUCCEEDED" }));

      const updateResponse = await request(app.getHttpServer())
        .patch(`/chore-records/${recordId}`)
        .set("Authorization", `Bearer ${owner.token}`)
        .send({ actualMinutes: 23 })
        .expect(200);
      expect(updateResponse.body).toMatchObject({ actualMinutes: 23, points: 31, canEdit: true });
      expect(updateResponse.body.achievementEvaluation).toMatchObject({ state: "PENDING" });
      await expect(
        prisma.achievementEvent.count({
          where: {
            eventType: "CHORE_UPDATED",
            sourceType: AchievementEventSourceType.CHORE,
            sourceId: recordId,
          },
        }),
      ).resolves.toBe(1);

      await Promise.all(Array.from({ length: 10 }, () => worker.drainAvailable(100)));
      await expect(
        prisma.achievementAuditLog.count({
          where: { entityId: eventId, actionType: "EVENT_DISPATCHED" },
        }),
      ).resolves.toBe(1);

      const member = await loginWithPhone(`e2e-achievement-member-${Date.now()}`);
      const joinResponse = await request(app.getHttpServer())
        .post("/families/join-requests")
        .set("Authorization", `Bearer ${member.token}`)
        .send({
          inviteCode: familyResponse.body.inviteCode,
          identityLabel: "室友",
          avatarKey: "avatar_02",
        })
        .expect(201);
      await request(app.getHttpServer())
        .patch(`/families/${familyId}/join-requests/${joinResponse.body.id}`)
        .set("Authorization", `Bearer ${owner.token}`)
        .send({ action: "approve" })
        .expect(200)
        .expect(({ body }) => expect(body.achievementEvaluation).toMatchObject({ state: "PENDING" }));

      await request(app.getHttpServer())
        .post(`/chore-records/${recordId}/like`)
        .set("Authorization", `Bearer ${member.token}`)
        .send({ reactionKey: "like" })
        .expect(201);
      await request(app.getHttpServer())
        .post(`/chore-records/${recordId}/like`)
        .set("Authorization", `Bearer ${member.token}`)
        .send({ reactionKey: "like" })
        .expect(201)
        .expect(({ body }) => expect(body.achievementEvaluation).toBeUndefined());
      await request(app.getHttpServer())
        .post(`/chore-records/${recordId}/like`)
        .set("Authorization", `Bearer ${member.token}`)
        .send({ reactionKey: "high_five" })
        .expect(201);
      await request(app.getHttpServer())
        .delete(`/chore-records/${recordId}/like`)
        .set("Authorization", `Bearer ${member.token}`)
        .expect(200);

      await request(app.getHttpServer())
        .delete(`/chore-records/${recordId}`)
        .set("Authorization", `Bearer ${owner.token}`)
        .expect(200);
      await request(app.getHttpServer())
        .post(`/chore-records/${recordId}/restore`)
        .set("Authorization", `Bearer ${owner.token}`)
        .expect(201);
      await request(app.getHttpServer())
        .post("/auth/redeem-premium")
        .set("Authorization", `Bearer ${owner.token}`)
        .send({ code: "241255" })
        .expect(201);
      await request(app.getHttpServer())
        .delete(`/families/${familyId}/members/me`)
        .set("Authorization", `Bearer ${member.token}`)
        .expect(200);

      const familyEvents = await prisma.achievementEvent.findMany({
        where: { familyId },
        orderBy: [{ sourceId: "asc" }, { sourceVersion: "asc" }],
      });
      expect(familyEvents.map((event) => event.eventType)).toEqual(
        expect.arrayContaining([
          "MEMBER_JOINED",
          "CHORE_CREATED",
          "REACTION_CREATED",
          "REACTION_CHANGED",
          "REACTION_DELETED",
          "CHORE_DELETED",
          "CHORE_RESTORED",
          "PLAN_CHANGED",
          "MEMBER_LEFT",
        ]),
      );
      const reactionEvents = familyEvents.filter((event) =>
        event.eventType.startsWith("REACTION_"),
      );
      expect(reactionEvents.map((event) => event.sourceVersion)).toEqual([1, 2, 3]);
      await worker.drainAvailable(100);

      const unsupportedEvent = await prisma.achievementEvent.create({
        data: {
          familyId,
          actorUserId: owner.userId,
          eventType: "E2E_UNSUPPORTED_EVENT",
          sourceType: AchievementEventSourceType.FAMILY,
          sourceId: `unsupported-${Date.now()}`,
          sourceVersion: 1,
          idempotencyKey: `unsupported-${Date.now()}-${Math.random()}`,
          occurredAt: new Date(),
          familyTimezoneSnapshot: "Asia/Shanghai",
          payloadJson: {},
        },
      });

      for (let attempt = 0; attempt < 5; attempt += 1) {
        await prisma.achievementEvent.update({
          where: { id: unsupportedEvent.id },
          data: { nextAttemptAt: new Date(0) },
        });
        await worker.drainAvailable(1);
      }

      await request(app.getHttpServer())
        .get(`/families/${familyId}/achievement-events/failed`)
        .set("Authorization", `Bearer ${owner.token}`)
        .expect(200)
        .expect(({ body }) =>
          expect(body).toEqual(
            expect.arrayContaining([
              expect.objectContaining({ eventId: unsupportedEvent.id, isDeadLetter: true }),
            ]),
          ),
        );

      await request(app.getHttpServer())
        .post(`/families/${familyId}/achievement-events/${unsupportedEvent.id}/replay`)
        .set("Authorization", `Bearer ${owner.token}`)
        .expect(201)
        .expect(({ body }) =>
          expect(body).toMatchObject({
            eventId: unsupportedEvent.id,
            state: "PENDING",
            retryCount: 0,
            isDeadLetter: false,
          }),
        );
      await prisma.achievementEvent.delete({ where: { id: unsupportedEvent.id } });
    } finally {
      if (previousFlag === undefined) {
        delete process.env.ACHIEVEMENTS_ENABLED;
      } else {
        process.env.ACHIEVEMENTS_ENABLED = previousFlag;
      }
    }
  }, 30_000);

  it("closes the stage-three journey, reward, visibility and deletion loop", async () => {
    const previousFlag = process.env.ACHIEVEMENTS_ENABLED;
    process.env.ACHIEVEMENTS_ENABLED = "true";

    try {
      const owner = await loginWithPhone(`e2e-stage-three-owner-${Date.now()}`);
      const familyResponse = await request(app.getHttpServer())
        .post("/families")
        .set("Authorization", `Bearer ${owner.token}`)
        .send({
          name: "Stage three achievement family",
          identityLabel: "一家之主",
          timezone: "Asia/Shanghai",
        })
        .expect(201);
      const familyId = familyResponse.body.id as string;
      const worker = app.get(AchievementWorkerService);
      const anchor = new Date();

      const ownerRecordIds: string[] = [];
      for (let offset = 24; offset >= 0; offset -= 1) {
        ownerRecordIds.push(
          await createJourneyRecordAndEvent({
            familyId,
            userId: owner.userId,
            occurredAt: new Date(anchor.getTime() - offset * 86_400_000),
            suffix: `owner-${offset}`,
          }),
        );
      }

      for (let attempt = 0; attempt < 5; attempt += 1) {
        await worker.drainAvailable(100);
      }

      const ownerJourney = await request(app.getHttpServer())
        .get(`/families/${familyId}/achievements/me`)
        .set("Authorization", `Bearer ${owner.token}`)
        .expect(200);
      expect(ownerJourney.body.achievements).toHaveLength(35);
      expect(
        ownerJourney.body.achievements
          .filter((item: { track: string }) => item.track === "JOURNEY")
          .every((item: { isUnlocked: boolean }) => item.isUnlocked),
      ).toBe(true);
      expect(ownerJourney.body.capacity).toEqual({
        common: { base: 6, earned: 2, limit: 8 },
        custom: { base: 2, earned: 1, limit: 3 },
      });

      await request(app.getHttpServer())
        .get(`/families/${familyId}/achievements/summary`)
        .set("Authorization", `Bearer ${owner.token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body).toMatchObject({ unlockedCount: 7, totalCount: 35 });
          expect(body.nextAchievement).not.toBeNull();
          expect(body.recentUnlocks).toHaveLength(3);
        });

      const firstRecordAchievement = ownerJourney.body.achievements.find(
        (item: { key: string }) => item.key === "FIRST_RECORD",
      );
      await request(app.getHttpServer())
        .get(`/families/${familyId}/achievements/FIRST_RECORD`)
        .set("Authorization", `Bearer ${owner.token}`)
        .expect(200)
        .expect(({ body }) => expect(body).toMatchObject({ key: "FIRST_RECORD", isUnlocked: true }));
      await request(app.getHttpServer())
        .patch(`/families/${familyId}/achievements/visibility`)
        .set("Authorization", `Bearer ${owner.token}`)
        .send({ showToFamily: false })
        .expect(200)
        .expect(({ body }) => expect(body).toMatchObject({ showToFamily: false }));

      await request(app.getHttpServer())
        .get(`/families/${familyId}/achievements/me`)
        .set("Authorization", `Bearer ${owner.token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body.showAchievementsToFamily).toBe(false);
          expect(body.achievements
            .filter((item: { memberAchievementId: string | null }) => item.memberAchievementId)
            .every((item: { visibility: string }) => item.visibility === "PRIVATE"))
            .toBe(true);
        });

      await request(app.getHttpServer())
        .get(`/families/${familyId}/chore-layout`)
        .set("Authorization", `Bearer ${owner.token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body).toMatchObject({ selectionLimit: 8, customChoreLimit: 3 });
        });

      const member = await loginWithPhone(`e2e-stage-three-member-${Date.now()}`);
      const joinResponse = await request(app.getHttpServer())
        .post("/families/join-requests")
        .set("Authorization", `Bearer ${member.token}`)
        .send({
          inviteCode: familyResponse.body.inviteCode,
          identityLabel: "室友",
          avatarKey: "avatar_02",
        })
        .expect(201);
      await request(app.getHttpServer())
        .patch(`/families/${familyId}/join-requests/${joinResponse.body.id}`)
        .set("Authorization", `Bearer ${owner.token}`)
        .send({ action: "approve" })
        .expect(200);

      const memberRecordIds: string[] = [];
      for (let offset = 6; offset >= 0; offset -= 1) {
        memberRecordIds.push(
          await createJourneyRecordAndEvent({
            familyId,
            userId: member.userId,
            occurredAt: new Date(anchor.getTime() - offset * 86_400_000),
            suffix: `member-${offset}`,
          }),
        );
      }
      await worker.drainAvailable(100);

      await expect(
        prisma.memberAchievement.count({
          where: { familyId, achievementKey: "ACTIVE_DAYS_3" },
        }),
      ).resolves.toBe(2);
      await expect(prisma.familyRewardGrant.count({ where: { familyId } })).resolves.toBe(3);

      const deletedAt = new Date();
      const deletedRecordId = memberRecordIds[3];
      await prisma.choreRecord.update({
        where: { id: deletedRecordId },
        data: { deletedAt, deletedById: owner.userId },
      });
      await prisma.achievementEvent.create({
        data: {
          familyId,
          actorUserId: owner.userId,
          eventType: "CHORE_DELETED",
          sourceType: AchievementEventSourceType.CHORE,
          sourceId: deletedRecordId,
          sourceVersion: 2,
          idempotencyKey: `CHORE:${deletedRecordId}:v2:CHORE_DELETED`,
          occurredAt: deletedAt,
          familyTimezoneSnapshot: "Asia/Shanghai",
          payloadJson: { recordId: deletedRecordId, recordUserId: member.userId },
        },
      });
      await worker.drainAvailable(100);

      const activeSevenProgress = await prisma.achievementProgress.findFirstOrThrow({
        where: {
          familyId,
          ownerKey: `${familyId}:${member.userId}`,
          achievementKey: "ACTIVE_DAYS_7",
        },
      });
      expect(activeSevenProgress.rawCurrentValue).toBe(6);
      expect(activeSevenProgress.displayCurrentValue).toBe(7);
      expect(activeSevenProgress.progressStatus).toBe("COMPLETED");
      await expect(prisma.familyRewardGrant.count({ where: { familyId } })).resolves.toBe(3);
    } finally {
      if (previousFlag === undefined) {
        delete process.env.ACHIEVEMENTS_ENABLED;
      } else {
        process.env.ACHIEVEMENTS_ENABLED = previousFlag;
      }
    }
  }, 30_000);

  it("calculates stage-five mastery with daily caps, theme eligibility and delete/restore rebuilds", async () => {
    const previousFlag = process.env.ACHIEVEMENTS_ENABLED;
    process.env.ACHIEVEMENTS_ENABLED = "true";

    try {
      const owner = await loginWithPhone(`e2e-stage-five-owner-${Date.now()}`);
      const familyResponse = await request(app.getHttpServer())
        .post("/families")
        .set("Authorization", `Bearer ${owner.token}`)
        .send({ name: "Stage five mastery family", identityLabel: "一家之主", timezone: "Asia/Shanghai" })
        .expect(201);
      const familyId = familyResponse.body.id as string;
      const dishes = await prisma.chore.findUniqueOrThrow({ where: { catalogKey: "core-dishes-cleanup" } });
      const pet = await prisma.chore.findUniqueOrThrow({ where: { catalogKey: "pet-feeding" } });
      await prisma.family.update({
        where: { id: familyId },
        data: { choreOrder: [dishes.id], choreSetupCompleted: true },
      });

      await request(app.getHttpServer())
        .get(`/families/${familyId}/achievements/me`)
        .set("Authorization", `Bearer ${owner.token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body.achievements.filter((item: { key: string }) => item.key === "MASTERY_PET")).toHaveLength(0);
          expect(body.achievements.filter((item: { key: string }) => item.key === "MASTERY_DISHES")).toHaveLength(3);
        });

      const anchor = new Date();
      const records: Array<Awaited<ReturnType<typeof prisma.choreRecord.create>>> = [];
      const dailyCounts = [4, ...Array.from({ length: 32 }, () => 3), 1];
      for (const [dayOffset, count] of dailyCounts.entries()) {
        for (let index = 0; index < count; index += 1) {
          const occurredAt = new Date(anchor.getTime() - dayOffset * 86_400_000 + index * 1_000);
          records.push(await prisma.choreRecord.create({
            data: {
              familyId,
              userId: owner.userId,
              choreId: dishes.id,
              note: `mastery-${dayOffset}-${index}`,
              imageUrls: [],
              minutes: dishes.standardMinutes,
              actualMinutes: dishes.standardMinutes,
              points: dishes.defaultPoints,
              creatorDisplayNameSnapshot: "Mastery owner",
              creatorIdentityLabelSnapshot: "一家之主",
              occurredAt,
              createdAt: occurredAt,
            },
          }));
        }
      }
      const triggerRecord = records.at(-1)!;
      const createEvent = await prisma.achievementEvent.create({
        data: {
          familyId,
          actorUserId: owner.userId,
          eventType: "CHORE_CREATED",
          sourceType: AchievementEventSourceType.CHORE,
          sourceId: triggerRecord.id,
          sourceVersion: 1,
          idempotencyKey: `CHORE:${triggerRecord.id}:v1:CHORE_CREATED`,
          occurredAt: anchor,
          familyTimezoneSnapshot: "Asia/Shanghai",
          payloadJson: { recordId: triggerRecord.id, userId: owner.userId },
        },
      });
      const worker = app.get(AchievementWorkerService);
      await worker.drainAvailable(100);

      const masteryUnlocks = await prisma.memberAchievement.findMany({
        where: { familyId, userId: owner.userId, achievementKey: "MASTERY_DISHES" },
      });
      expect(masteryUnlocks).toHaveLength(3);
      expect(new Set(masteryUnlocks.map((unlock) => unlock.unlockBatchId)).size).toBe(1);
      const masteryProgress = await prisma.achievementProgress.findMany({
        where: { familyId, ownerKey: `${familyId}:${owner.userId}`, achievementKey: "MASTERY_DISHES" },
      });
      expect(masteryProgress.every((progress) => progress.rawCurrentValue === 100)).toBe(true);
      const batch = await prisma.achievementUnlockBatch.findUniqueOrThrow({
        where: { triggerEventId: createEvent.id },
      });
      expect(batch.unlockCount).toBeGreaterThanOrEqual(3);

      await prisma.family.update({ where: { id: familyId }, data: { choreOrder: [dishes.id, pet.id] } });
      await request(app.getHttpServer())
        .get(`/families/${familyId}/achievements/me`)
        .set("Authorization", `Bearer ${owner.token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body.achievements.filter((item: { key: string }) => item.key === "MASTERY_PET")).toHaveLength(3);
        });

      await prisma.choreRecord.update({
        where: { id: triggerRecord.id },
        data: { deletedAt: new Date(), deletedById: owner.userId },
      });
      await prisma.achievementEvent.create({
        data: {
          familyId,
          actorUserId: owner.userId,
          eventType: "CHORE_DELETED",
          sourceType: AchievementEventSourceType.CHORE,
          sourceId: triggerRecord.id,
          sourceVersion: 2,
          idempotencyKey: `CHORE:${triggerRecord.id}:v2:CHORE_DELETED`,
          occurredAt: new Date(),
          familyTimezoneSnapshot: "Asia/Shanghai",
          payloadJson: { recordId: triggerRecord.id, recordUserId: owner.userId },
        },
      });
      await worker.drainAvailable(100);
      await expect(prisma.achievementProgress.findFirstOrThrow({
        where: { familyId, ownerKey: `${familyId}:${owner.userId}`, achievementKey: "MASTERY_DISHES", tier: "GOLD" },
      })).resolves.toMatchObject({ rawCurrentValue: 99, displayCurrentValue: 100, progressStatus: "COMPLETED" });

      await prisma.choreRecord.update({ where: { id: triggerRecord.id }, data: { deletedAt: null, deletedById: null } });
      await prisma.achievementEvent.create({
        data: {
          familyId,
          actorUserId: owner.userId,
          eventType: "CHORE_RESTORED",
          sourceType: AchievementEventSourceType.CHORE,
          sourceId: triggerRecord.id,
          sourceVersion: 3,
          idempotencyKey: `CHORE:${triggerRecord.id}:v3:CHORE_RESTORED`,
          occurredAt: new Date(),
          familyTimezoneSnapshot: "Asia/Shanghai",
          payloadJson: { recordId: triggerRecord.id, recordUserId: owner.userId },
        },
      });
      await worker.drainAvailable(100);
      await expect(prisma.achievementProgress.findFirstOrThrow({
        where: { familyId, ownerKey: `${familyId}:${owner.userId}`, achievementKey: "MASTERY_DISHES", tier: "GOLD" },
      })).resolves.toMatchObject({ rawCurrentValue: 100, displayCurrentValue: 100 });

      await request(app.getHttpServer())
        .post("/chore-records")
        .set("Authorization", `Bearer ${owner.token}`)
        .send({ familyId, choreId: dishes.id, actualMinutes: 15, occurredAt: anchor.toISOString() })
        .expect(400);
    } finally {
      if (previousFlag === undefined) delete process.env.ACHIEVEMENTS_ENABLED;
      else process.env.ACHIEVEMENTS_ENABLED = previousFlag;
    }
  }, 30_000);

  it("processes stage-six reactions, family collaboration and normalized pair achievements", async () => {
    const previousFlag = process.env.ACHIEVEMENTS_ENABLED;
    process.env.ACHIEVEMENTS_ENABLED = "true";

    try {
      const owner = await loginWithPhone(`e2e-stage-six-owner-${Date.now()}`);
      const familyResponse = await request(app.getHttpServer())
        .post("/families")
        .set("Authorization", `Bearer ${owner.token}`)
        .send({ name: "Stage six family", identityLabel: "一家之主", timezone: "Asia/Shanghai" })
        .expect(201);
      const familyId = familyResponse.body.id as string;
      const worker = app.get(AchievementWorkerService);

      await request(app.getHttpServer())
        .get(`/families/${familyId}/achievements/me`)
        .set("Authorization", `Bearer ${owner.token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body.achievements.some((item: { key: string }) => [
            "REACTION_FIRST",
            "REACTION_GIVEN_20",
            "REACTION_RECEIVED_10",
            "FAMILY_FORMED",
            "FAMILY_ALL_IN",
            "FAMILY_RELAY",
            "FAMILY_VISIBLE_4W",
            "FAMILY_FULL_SERVICE",
            "FAMILY_CATEGORY_COVERAGE",
            "PAIR_COOK_AND_CLEAN",
          ].includes(item.key))).toBe(false);
        });

      const member = await loginWithPhone(`e2e-stage-six-member-${Date.now()}`);
      const joinResponse = await request(app.getHttpServer())
        .post("/families/join-requests")
        .set("Authorization", `Bearer ${member.token}`)
        .send({
          inviteCode: familyResponse.body.inviteCode,
          identityLabel: "室友",
          avatarKey: "avatar_02",
        })
        .expect(201);
      await request(app.getHttpServer())
        .patch(`/families/${familyId}/join-requests/${joinResponse.body.id}`)
        .set("Authorization", `Bearer ${owner.token}`)
        .send({ action: "approve" })
        .expect(200);
      await worker.drainAvailable(100);

      await expect(prisma.familyAchievement.count({
        where: { familyId, achievementKey: "FAMILY_FORMED" },
      })).resolves.toBe(1);

      const cooking = await prisma.chore.findUniqueOrThrow({ where: { catalogKey: "core-cook-prepare" } });
      const dishes = await prisma.chore.findUniqueOrThrow({ where: { catalogKey: "core-dishes-cleanup" } });
      const floor = await prisma.chore.findUniqueOrThrow({ where: { catalogKey: "core-mop-floor" } });
      const createRecord = async (token: string, chore: typeof cooking) => {
        const response = await request(app.getHttpServer())
          .post("/chore-records")
          .set("Authorization", `Bearer ${token}`)
          .set("Idempotency-Key", `stage-six-${Date.now()}-${Math.random()}`)
          .send({ familyId, choreId: chore.id, actualMinutes: chore.standardMinutes })
          .expect(201);
        return response.body.id as string;
      };

      const ownerCookingRecordId = await createRecord(owner.token, cooking);
      await createRecord(member.token, dishes);
      await createRecord(owner.token, floor);
      const ownerDishesRecordId = await createRecord(owner.token, dishes);
      await createRecord(member.token, cooking);

      const reactionTargets = [ownerCookingRecordId, ownerDishesRecordId];
      for (let index = 0; index < 2; index += 1) {
        reactionTargets.push(await createRecord(owner.token, floor));
      }
      for (const recordId of reactionTargets) {
        await request(app.getHttpServer())
          .post(`/chore-records/${recordId}/like`)
          .set("Authorization", `Bearer ${member.token}`)
          .send({ reactionKey: "like" })
          .expect(201);
      }
      await request(app.getHttpServer())
        .post(`/chore-records/${ownerCookingRecordId}/like`)
        .set("Authorization", `Bearer ${member.token}`)
        .send({ reactionKey: "high_five" })
        .expect(201);
      await request(app.getHttpServer())
        .post(`/chore-records/${ownerCookingRecordId}/like`)
        .set("Authorization", `Bearer ${owner.token}`)
        .send({ reactionKey: "like" })
        .expect(201);

      await worker.drainAvailable(200);

      await expect(prisma.pairAchievement.count({
        where: { familyId, achievementKey: "PAIR_COOK_AND_CLEAN" },
      })).resolves.toBe(1);
      await expect(prisma.familyAchievement.count({
        where: { familyId, achievementKey: { in: ["FAMILY_ALL_IN", "FAMILY_FULL_SERVICE"] } },
      })).resolves.toBe(2);
      await expect(prisma.memberAchievement.count({
        where: { familyId, userId: member.userId, achievementKey: "REACTION_FIRST" },
      })).resolves.toBe(1);
      await expect(prisma.achievementProgress.findFirstOrThrow({
        where: {
          familyId,
          ownerKey: `${familyId}:${member.userId}`,
          achievementKey: "REACTION_GIVEN_20",
        },
      })).resolves.toMatchObject({ rawCurrentValue: 3 });

      await request(app.getHttpServer())
        .get(`/families/${familyId}/achievements/me`)
        .set("Authorization", `Bearer ${member.token}`)
        .expect(200)
        .expect(({ body }) => {
          const bondItems = body.achievements.filter((item: { track: string }) => item.track === "BOND");
          expect(bondItems).toHaveLength(17);
          expect(bondItems.find((item: { key: string }) => item.key === "PAIR_COOK_AND_CLEAN")).toMatchObject({
            ownerType: "PAIR",
            isUnlocked: true,
          });
          expect(bondItems.find((item: { key: string }) => item.key === "FAMILY_FORMED")).toMatchObject({
            ownerType: "FAMILY",
            isUnlocked: true,
          });
        });

      const snapshotBeforeJoin = await prisma.achievementEligibilitySnapshot.findFirstOrThrow({
        where: { familyId, periodType: "WEEK" },
      });
      const eligibleBeforeJoin = snapshotBeforeJoin.eligibleMemberIdsJson as string[];
      expect(eligibleBeforeJoin).toHaveLength(2);

      const lateMember = await loginWithPhone(`e2e-stage-six-late-${Date.now()}`);
      const lateJoin = await request(app.getHttpServer())
        .post("/families/join-requests")
        .set("Authorization", `Bearer ${lateMember.token}`)
        .send({ inviteCode: familyResponse.body.inviteCode, identityLabel: "朋友" })
        .expect(201);
      await request(app.getHttpServer())
        .patch(`/families/${familyId}/join-requests/${lateJoin.body.id}`)
        .set("Authorization", `Bearer ${owner.token}`)
        .send({ action: "approve" })
        .expect(200);
      await worker.drainAvailable(100);

      const snapshotAfterJoin = await prisma.achievementEligibilitySnapshot.findUniqueOrThrow({
        where: { id: snapshotBeforeJoin.id },
      });
      expect(snapshotAfterJoin.eligibleMemberIdsJson).toEqual(eligibleBeforeJoin);

      await createRecord(lateMember.token, floor);

      const coverageChores = await Promise.all([
        prisma.chore.findUniqueOrThrow({ where: { catalogKey: "core-laundry" } }),
        prisma.chore.findUniqueOrThrow({ where: { catalogKey: "core-organize-storage" } }),
        prisma.chore.findUniqueOrThrow({ where: { catalogKey: "core-trash-recycling" } }),
        prisma.chore.findFirstOrThrow({ where: { themeKey: "pet", archivedAt: null } }),
        prisma.chore.findFirstOrThrow({ where: { themeKey: "childcare", archivedAt: null } }),
      ]);
      for (const [index, chore] of coverageChores.entries()) {
        await createRecord(index % 2 === 0 ? owner.token : member.token, chore);
      }

      const timezone = "Asia/Shanghai";
      const anchor = new Date();
      for (const offset of [-1, -2, -3]) {
        const range = getWeekRangeForTimeZone(timezone, anchor, offset);
        await prisma.achievementEligibilitySnapshot.create({
          data: {
            familyId,
            periodType: "WEEK",
            periodStart: range.start,
            periodEnd: range.end,
            timezone,
            eligibleMemberIdsJson: [owner.userId, member.userId],
          },
        });
        for (const [index, userId] of [owner.userId, member.userId].entries()) {
          await prisma.choreRecord.create({
            data: {
              familyId,
              userId,
              choreId: floor.id,
              note: `stage-six-week-${offset}-${index}`,
              imageUrls: [],
              minutes: floor.standardMinutes,
              actualMinutes: floor.standardMinutes,
              points: floor.defaultPoints,
              creatorDisplayNameSnapshot: "Stage six participant",
              creatorIdentityLabelSnapshot: "家庭成员",
              occurredAt: new Date(range.start.getTime() + 86_400_000 + index * 1_000),
              createdAt: new Date(range.start.getTime() + 86_400_000 + index * 1_000),
            },
          });
        }
      }
      await createRecord(owner.token, floor);
      await worker.drainAvailable(300);

      await expect(prisma.familyAchievement.count({
        where: { familyId, achievementKey: { in: [
          "FAMILY_FORMED",
          "FAMILY_ALL_IN",
          "FAMILY_RELAY",
          "FAMILY_VISIBLE_4W",
          "FAMILY_FULL_SERVICE",
          "FAMILY_CATEGORY_COVERAGE",
        ] } },
      })).resolves.toBe(6);
    } finally {
      if (previousFlag === undefined) delete process.env.ACHIEVEMENTS_ENABLED;
      else process.env.ACHIEVEMENTS_ENABLED = previousFlag;
    }
  }, 30_000);

  it("completes stage-seven milestones, hidden discoveries, lifecycle archives and reconciliation", async () => {
    const previousFlag = process.env.ACHIEVEMENTS_ENABLED;
    process.env.ACHIEVEMENTS_ENABLED = "true";
    try {
      const owner = await loginWithPhone(`e2e-stage-seven-owner-${Date.now()}`);
      const familyResponse = await request(app.getHttpServer())
        .post("/families")
        .set("Authorization", `Bearer ${owner.token}`)
        .send({ name: "Stage seven family", identityLabel: "一家之主", timezone: "Asia/Shanghai" })
        .expect(201);
      const familyId = familyResponse.body.id as string;
      const worker = app.get(AchievementWorkerService);
      await prisma.family.update({
        where: { id: familyId },
        data: { createdAt: new Date(Date.now() - 366 * 86_400_000) },
      });

      await request(app.getHttpServer())
        .get(`/families/${familyId}/achievements/me`)
        .set("Authorization", `Bearer ${owner.token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body.achievements.filter((item: { track: string }) => item.track === "HIDDEN")).toHaveLength(0);
          expect(body.achievements.filter((item: { key: string }) => item.key === "FAMILY_ACTIVE_DAYS")).toHaveLength(3);
        });

      const chores = await Promise.all([
        prisma.chore.findUniqueOrThrow({ where: { catalogKey: "core-dishes-cleanup" } }),
        prisma.chore.findUniqueOrThrow({ where: { catalogKey: "core-sweep-vacuum" } }),
        prisma.chore.findUniqueOrThrow({ where: { catalogKey: "core-mop-floor" } }),
        prisma.chore.findUniqueOrThrow({ where: { catalogKey: "core-cook-prepare" } }),
        prisma.chore.findUniqueOrThrow({ where: { catalogKey: "core-laundry" } }),
        prisma.chore.findUniqueOrThrow({ where: { catalogKey: "core-organize-storage" } }),
        prisma.chore.findFirstOrThrow({ where: { themeKey: "childcare", archivedAt: null } }),
      ]);
      const anchor = new Date();
      const dayRange = getDayRangeForTimeZone("Asia/Shanghai", anchor);
      const specialTimes = [
        ...Array.from({ length: 7 }, (_, index) => new Date(dayRange.start.getTime() + (8 + index) * 3_600_000)),
        new Date(dayRange.start.getTime() + 2 * 3_600_000),
      ];
      const records = [];
      const openingChoreIndexes = [0, 0, 0, 1, 2, 3, 6, 5];
      for (let index = 0; index < 100; index += 1) {
        const chore = chores[index < openingChoreIndexes.length ? openingChoreIndexes[index] : index % chores.length];
        const occurredAt = index < specialTimes.length
          ? specialTimes[index]
          : new Date(dayRange.start.getTime() - (index % 30) * 86_400_000 + (index % 12) * 60_000);
        records.push(await prisma.choreRecord.create({
          data: {
            familyId,
            userId: owner.userId,
            choreId: chore.id,
            note: `stage-seven-${index}`,
            imageUrls: [],
            minutes: chore.standardMinutes,
            actualMinutes: index === 7 ? 130 : chore.standardMinutes,
            points: chore.defaultPoints,
            creatorDisplayNameSnapshot: "Stage seven owner",
            creatorIdentityLabelSnapshot: "一家之主",
            occurredAt,
            createdAt: occurredAt,
          },
        }));
      }
      const triggerRecord = records[7];
      for (const sourceRecord of records.slice(0, 8)) {
        await prisma.achievementEvent.create({
          data: {
            familyId,
            actorUserId: owner.userId,
            eventType: "CHORE_CREATED",
            sourceType: AchievementEventSourceType.CHORE,
            sourceId: sourceRecord.id,
            sourceVersion: 1,
            idempotencyKey: `CHORE:${sourceRecord.id}:v1:CHORE_CREATED`,
            occurredAt: sourceRecord.occurredAt,
            familyTimezoneSnapshot: "Asia/Shanghai",
            payloadJson: { recordId: sourceRecord.id, userId: owner.userId },
          },
        });
      }
      await worker.drainAvailable(300);

      await expect(prisma.familyAchievement.count({
        where: { familyId, achievementKey: { in: ["FAMILY_ACTIVE_DAYS", "FAMILY_RECORD_COUNT", "FAMILY_ANNIVERSARY"] } },
      })).resolves.toBe(3);
      await expect(prisma.memberAchievement.count({
        where: { familyId, userId: owner.userId, achievementKey: { startsWith: "HIDDEN_" } },
      })).resolves.toBe(5);
      await request(app.getHttpServer())
        .get(`/families/${familyId}/achievements/me`)
        .set("Authorization", `Bearer ${owner.token}`)
        .expect(200)
        .expect(({ body }) => {
          const hidden = body.achievements.filter((item: { track: string }) => item.track === "HIDDEN");
          expect(hidden).toHaveLength(5);
          expect(hidden.every((item: { isUnlocked: boolean; visibility: string }) => item.isUnlocked && item.visibility === "PRIVATE")).toBe(true);
        });

      await request(app.getHttpServer())
        .patch(`/families/${familyId}/achievements/visibility`)
        .set("Authorization", `Bearer ${owner.token}`)
        .send({ showToFamily: false })
        .expect(200);
      await request(app.getHttpServer())
        .patch(`/families/${familyId}/achievements/visibility`)
        .set("Authorization", `Bearer ${owner.token}`)
        .send({ showToFamily: true })
        .expect(200);
      await request(app.getHttpServer())
        .get(`/families/${familyId}/achievements/me`)
        .set("Authorization", `Bearer ${owner.token}`)
        .expect(200)
        .expect(({ body }) => {
          const hidden = body.achievements.filter((item: { track: string }) => item.track === "HIDDEN");
          expect(hidden.every((item: { visibility: string }) => item.visibility === "PRIVATE")).toBe(true);
        });

      const activeReward = await prisma.familyRewardGrant.findFirstOrThrow({
        where: { familyId, achievementKey: "ACTIVE_DAYS_3" },
      });
      const batch = await prisma.achievementUnlockBatch.findFirstOrThrow({ where: { familyId } });
      const dirtyProgress = await prisma.achievementProgress.findFirstOrThrow({
        where: { familyId, ownerKey: `${familyId}:${owner.userId}`, achievementKey: "ACTIVE_DAYS_3" },
      });
      await prisma.$transaction([
        prisma.familyRewardGrant.delete({ where: { id: activeReward.id } }),
        prisma.achievementUnlockBatch.update({ where: { id: batch.id }, data: { unlockCount: 999 } }),
        prisma.achievementProgress.update({ where: { id: dirtyProgress.id }, data: { progressStatus: "DIRTY" } }),
      ]);
      await request(app.getHttpServer())
        .get(`/families/${familyId}/achievement-maintenance/health`)
        .set("Authorization", `Bearer ${owner.token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body.progress.dirty).toBeGreaterThan(0);
          expect(body.consistency.unlockBatchMismatches).toBeGreaterThan(0);
        });
      await request(app.getHttpServer())
        .post(`/families/${familyId}/achievement-maintenance/reconcile`)
        .set("Authorization", `Bearer ${owner.token}`)
        .expect(201)
        .expect(({ body }) => {
          expect(body.after.progress.dirty).toBe(0);
          expect(body.after.consistency.unlockBatchMismatches).toBe(0);
        });
      await expect(prisma.familyRewardGrant.count({
        where: { familyId, achievementKey: "ACTIVE_DAYS_3" },
      })).resolves.toBe(1);

      const member = await loginWithPhone(`e2e-stage-seven-member-${Date.now()}`);
      const join = await request(app.getHttpServer())
        .post("/families/join-requests")
        .set("Authorization", `Bearer ${member.token}`)
        .send({ inviteCode: familyResponse.body.inviteCode, identityLabel: "室友" })
        .expect(201);
      await request(app.getHttpServer())
        .patch(`/families/${familyId}/join-requests/${join.body.id}`)
        .set("Authorization", `Bearer ${owner.token}`)
        .send({ action: "approve" })
        .expect(200);
      await request(app.getHttpServer())
        .post("/chore-records")
        .set("Authorization", `Bearer ${member.token}`)
        .set("Idempotency-Key", `stage-seven-pair-${Date.now()}`)
        .send({ familyId, choreId: chores[0].id, actualMinutes: chores[0].standardMinutes })
        .expect(201);
      await worker.drainAvailable(100);
      await expect(prisma.pairAchievement.findFirstOrThrow({
        where: { familyId, achievementKey: "PAIR_COOK_AND_CLEAN", OR: [{ memberAId: member.userId }, { memberBId: member.userId }] },
      })).resolves.toMatchObject({ archiveStatus: "ACTIVE" });
      const personalUnlockCount = await prisma.memberAchievement.count({ where: { familyId, userId: member.userId } });
      await request(app.getHttpServer())
        .delete(`/families/${familyId}/members/me`)
        .set("Authorization", `Bearer ${member.token}`)
        .expect(200);
      await worker.drainAvailable(100);
      await expect(prisma.familyAchievementParticipant.count({
        where: { userId: member.userId, displayRole: "FORMER" },
      })).resolves.toBeGreaterThan(0);
      await expect(prisma.pairAchievement.findFirstOrThrow({
        where: { familyId, achievementKey: "PAIR_COOK_AND_CLEAN", OR: [{ memberAId: member.userId }, { memberBId: member.userId }] },
      })).resolves.toMatchObject({ archiveStatus: "HISTORICAL" });
      await request(app.getHttpServer())
        .get("/achievements/archive")
        .set("Authorization", `Bearer ${member.token}`)
        .expect(200);

      const rejoin = await request(app.getHttpServer())
        .post("/families/join-requests")
        .set("Authorization", `Bearer ${member.token}`)
        .send({ inviteCode: familyResponse.body.inviteCode, identityLabel: "室友" })
        .expect(201);
      expect(rejoin.body.id).toBe(join.body.id);
      await request(app.getHttpServer())
        .patch(`/families/${familyId}/join-requests/${rejoin.body.id}`)
        .set("Authorization", `Bearer ${owner.token}`)
        .send({ action: "approve" })
        .expect(200);
      await worker.drainAvailable(100);
      await expect(prisma.memberAchievement.count({ where: { familyId, userId: member.userId } })).resolves.toBe(personalUnlockCount);
      await expect(prisma.familyAchievementParticipant.count({
        where: { userId: member.userId, displayRole: "ACTIVE" },
      })).resolves.toBeGreaterThan(0);
      await expect(prisma.pairAchievement.findFirstOrThrow({
        where: { familyId, achievementKey: "PAIR_COOK_AND_CLEAN", OR: [{ memberAId: member.userId }, { memberBId: member.userId }] },
      })).resolves.toMatchObject({ archiveStatus: "ACTIVE" });

      await request(app.getHttpServer())
        .delete(`/families/${familyId}`)
        .set("Authorization", `Bearer ${owner.token}`)
        .expect(200)
        .expect(({ body }) => expect(body.archivedAt).toBeTruthy());
      await request(app.getHttpServer())
        .get("/families/me")
        .set("Authorization", `Bearer ${owner.token}`)
        .expect(200)
        .expect(({ body }) => expect(body).toHaveLength(0));
      await request(app.getHttpServer())
        .get("/achievements/archive")
        .set("Authorization", `Bearer ${owner.token}`)
        .expect(200)
        .expect(({ body }) => expect(body.familyHonors.length).toBeGreaterThan(0));
    } finally {
      if (previousFlag === undefined) delete process.env.ACHIEVEMENTS_ENABLED;
      else process.env.ACHIEVEMENTS_ENABLED = previousFlag;
    }
  }, 60_000);

  it("permanently deletes an account and its single-member family", async () => {
    const user = await loginWithPhone(`e2e-account-delete-${Date.now()}`);
    const family = await request(app.getHttpServer())
      .post("/families")
      .set("Authorization", `Bearer ${user.token}`)
      .send({ name: "Account deletion family", identityLabel: "一家之主" })
      .expect(201);
    await request(app.getHttpServer())
      .post("/chore-records")
      .set("Authorization", `Bearer ${user.token}`)
      .send({ familyId: family.body.id, choreId, actualMinutes: 15 })
      .expect(201);
    await request(app.getHttpServer())
      .delete("/auth/me")
      .set("Authorization", `Bearer ${user.token}`)
      .expect(200)
      .expect(({ body }) => {
        expect(body.deleted).toBe(true);
        expect(body.deletedAt).toBeTruthy();
      });
    await expect(prisma.user.findUnique({ where: { id: user.userId } })).resolves.toBeNull();
    await expect(prisma.family.findUnique({ where: { id: family.body.id } })).resolves.toBeNull();
    await expect(prisma.choreRecord.count({ where: { userId: user.userId } })).resolves.toBe(0);
    await expect(prisma.familyMember.count({ where: { userId: user.userId } })).resolves.toBe(0);
    await expect(prisma.authIdentity.count({ where: { userId: user.userId } })).resolves.toBe(0);
    await request(app.getHttpServer())
      .get("/auth/me")
      .set("Authorization", `Bearer ${user.token}`)
      .expect(401);
  });

  it("transfers ownership and removes personal data when deleting an account in a shared family", async () => {
    const suffix = Date.now();
    const owner = await loginWithPhone(`e2e-delete-owner-${suffix}`);
    const member = await loginWithPhone(`e2e-delete-member-${suffix}`);
    const familyResponse = await request(app.getHttpServer())
      .post("/families")
      .set("Authorization", `Bearer ${owner.token}`)
      .send({ name: "Shared account deletion family", identityLabel: "一家之主" })
      .expect(201);
    const familyId = familyResponse.body.id as string;
    const join = await request(app.getHttpServer())
      .post("/families/join-requests")
      .set("Authorization", `Bearer ${member.token}`)
      .send({ inviteCode: familyResponse.body.inviteCode, identityLabel: "室友" })
      .expect(201);
    await request(app.getHttpServer())
      .patch(`/families/${familyId}/join-requests/${join.body.id}`)
      .set("Authorization", `Bearer ${owner.token}`)
      .send({ action: "approve" })
      .expect(200);
    await request(app.getHttpServer())
      .post("/chore-records")
      .set("Authorization", `Bearer ${owner.token}`)
      .send({ familyId, choreId, actualMinutes: 15 })
      .expect(201);
    await request(app.getHttpServer())
      .post("/chore-records")
      .set("Authorization", `Bearer ${member.token}`)
      .send({ familyId, choreId, actualMinutes: 15 })
      .expect(201);

    await request(app.getHttpServer())
      .delete("/auth/me")
      .set("Authorization", `Bearer ${owner.token}`)
      .expect(200);

    await expect(prisma.user.findUnique({ where: { id: owner.userId } })).resolves.toBeNull();
    await expect(prisma.family.findUnique({ where: { id: familyId } })).resolves.not.toBeNull();
    await expect(prisma.choreRecord.count({ where: { familyId, userId: owner.userId } })).resolves.toBe(0);
    await expect(prisma.choreRecord.count({ where: { familyId, userId: member.userId } })).resolves.toBe(1);
    await expect(prisma.familyMember.findUniqueOrThrow({
      where: { userId_familyId: { userId: member.userId, familyId } },
    })).resolves.toMatchObject({
      memberRole: "OWNER",
      status: "ACTIVE",
    });
    await request(app.getHttpServer())
      .get("/families/me")
      .set("Authorization", `Bearer ${member.token}`)
      .expect(200)
      .expect(({ body }) => expect(body[0].memberRole).toBe("OWNER"));
  });

  async function createJourneyRecordAndEvent(input: {
    familyId: string;
    userId: string;
    occurredAt: Date;
    suffix: string;
  }) {
    const record = await prisma.choreRecord.create({
      data: {
        familyId: input.familyId,
        userId: input.userId,
        choreId,
        note: `stage-three-${input.suffix}`,
        imageUrls: [],
        minutes: 15,
        actualMinutes: 15,
        points: 20,
        creatorDisplayNameSnapshot: "Stage three member",
        creatorIdentityLabelSnapshot: "家庭成员",
        occurredAt: input.occurredAt,
        createdAt: input.occurredAt,
      },
    });
    await prisma.achievementEvent.create({
      data: {
        familyId: input.familyId,
        actorUserId: input.userId,
        eventType: "CHORE_CREATED",
        sourceType: AchievementEventSourceType.CHORE,
        sourceId: record.id,
        sourceVersion: 1,
        idempotencyKey: `CHORE:${record.id}:v1:CHORE_CREATED`,
        occurredAt: input.occurredAt,
        familyTimezoneSnapshot: "Asia/Shanghai",
        payloadJson: { recordId: record.id, userId: input.userId },
      },
    });
    return record.id;
  }

  async function createRecordAt(input: {
    familyId: string;
    userId: string;
    choreId: string;
    points: number;
    createdAt: Date;
    note: string;
  }) {
    return prisma.choreRecord.create({
      data: {
        familyId: input.familyId,
        userId: input.userId,
        choreId: input.choreId,
        note: input.note,
        imageUrls: [],
        minutes: 15,
        actualMinutes: 15,
        points: input.points,
        creatorDisplayNameSnapshot: "历史成员",
        creatorIdentityLabelSnapshot: "家庭成员",
        createdAt: input.createdAt,
      },
    });
  }

  function monthTextForTimeZone(timezone: string) {
    const parts = new Intl.DateTimeFormat("en-CA", {
      timeZone: timezone,
      year: "numeric",
      month: "2-digit",
    }).formatToParts(new Date());
    const year = parts.find((part) => part.type === "year")?.value;
    const month = parts.find((part) => part.type === "month")?.value;
    return `${year}-${month}`;
  }
});
