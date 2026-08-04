import { INestApplication, ValidationPipe } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import request = require("supertest");
import { AppModule } from "../src/app.module";
import { getDayRangeForTimeZone, getMonthRangeForTimeZone, getWeekRangeForTimeZone } from "../src/common/timezone-ranges";
import { PrismaService } from "../src/prisma/prisma.service";

describe("MVP API (e2e)", () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let choreId: string;

  beforeAll(async () => {
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
  });

  async function login(displayName: string) {
    const response = await request(app.getHttpServer())
      .post("/auth/mock-login")
      .send({ displayName })
      .expect(201);

    return {
      token: response.body.accessToken as string,
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
        expect.objectContaining({ name: "浇花养护", themeKey: "love", icon: "chore_custom_plant" }),
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
    expect(secondLogin.token).toBe(firstLogin.token);

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

    await request(app.getHttpServer())
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
          customChoreLimit: 10,
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
    expect(listResponse.body).toHaveLength(9);

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
        createdAt: historicalDate,
      },
    });

    expect(ownerRecordResponse.body).toMatchObject({
      actualMinutes: 15,
      points: 20,
      likeCount: 0,
      likedByMe: false,
      canDelete: true,
    });

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
    });
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

  it("updates the active member appearance and reflects it in family activity", async () => {
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
