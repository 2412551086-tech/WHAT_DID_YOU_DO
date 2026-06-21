import { INestApplication, ValidationPipe } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import request = require("supertest");
import { AppModule } from "../src/app.module";
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
      where: { name: "E2E actual minutes chore" },
      update: {
        category: "测试类",
        standardMinutes: 15,
        difficultyMultiplier: 1,
        defaultPoints: 20,
        icon: "checkmark.circle",
        isFreeCore: true,
        sortOrder: 999,
      },
      create: {
        name: "E2E actual minutes chore",
        category: "测试类",
        standardMinutes: 15,
        difficultyMultiplier: 1,
        defaultPoints: 20,
        icon: "checkmark.circle",
        isFreeCore: true,
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

  it("returns the premium chore catalog as locked", async () => {
    const response = await request(app.getHttpServer()).get("/chores").expect(200);
    const premiumChores = response.body.filter((chore: { isLocked: boolean }) => chore.isLocked);

    expect(premiumChores).toHaveLength(10);
    expect(premiumChores).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ name: "换床单", requiredPlan: "premium", isLocked: true }),
        expect.objectContaining({ name: "喂奶", points: 38, isLocked: true }),
        expect.objectContaining({ name: "遛娃", points: 63, isLocked: true }),
        expect.objectContaining({ name: "接送孩子", points: 56, isLocked: true }),
      ]),
    );
  });

  it("reuses the same development account for repeated phone login", async () => {
    const phoneNumber = `e2e-${Date.now()}`;
    const firstLogin = await loginWithPhone(phoneNumber);
    const secondLogin = await loginWithPhone(phoneNumber);

    expect(firstLogin.phoneNumber).toBe(phoneNumber);
    expect(secondLogin.userId).toBe(firstLogin.userId);
    expect(secondLogin.token).toBe(firstLogin.token);
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
        identityLabel: "老爸",
        avatarKey: "avatar_owner",
      })
      .expect(201);
    const familyId = familyResponse.body.id as string;
    const inviteCode = familyResponse.body.inviteCode as string;

    expect(familyResponse.body.requirePhotoProof).toBe(false);
    expect(inviteCode).toMatch(/^[A-F0-9]{8}$/);

    expect(familyResponse.body.members[0]).toMatchObject({
      userId: owner.userId,
      identityLabel: "老爸",
      avatarKey: "avatar_owner",
      memberRole: "OWNER",
      status: "ACTIVE",
    });

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

    await request(app.getHttpServer())
      .post("/families/join-requests")
      .set("Authorization", `Bearer ${member.token}`)
      .send({ inviteCode: "NOTFOUND", identityLabel: "室友" })
      .expect(404);

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

    await request(app.getHttpServer())
      .post("/chore-records")
      .set("Authorization", `Bearer ${rejectedUser.token}`)
      .send({ familyId, choreId, actualMinutes: 20 })
      .expect(403);

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
    });

    await request(app.getHttpServer())
      .post(`/chore-records/${ownerRecordId}/like`)
      .set("Authorization", `Bearer ${member.token}`)
      .expect(201, {
        recordId: ownerRecordId,
        likeCount: 1,
        likedByMe: true,
      });

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
      canDelete: false,
    });
    expect(memberActivityResponse.body[0].likedBy).toEqual([
      expect.objectContaining({
        id: member.userId,
        identityLabel: "室友",
        avatarKey: "avatar_member",
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
    });

    await request(app.getHttpServer())
      .delete(`/chore-records/${ownerRecordId}/like`)
      .set("Authorization", `Bearer ${member.token}`)
      .expect(200, {
        recordId: ownerRecordId,
        likeCount: 0,
        likedByMe: false,
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
      .post("/chore-records")
      .set("Authorization", `Bearer ${member.token}`)
      .send({ familyId, choreId, actualMinutes: 181 })
      .expect(400);

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

    const month = new Date().toISOString().slice(0, 7);
    const reportResponse = await request(app.getHttpServer())
      .get(`/families/${familyId}/monthly-report?month=${month}`)
      .set("Authorization", `Bearer ${owner.token}`)
      .expect(200);

    expect(reportResponse.body).toMatchObject({
      familyId,
      totalPoints: 20,
      totalRecords: 1,
    });
    expect(reportResponse.body.recentRecords).toEqual([
      expect.objectContaining({
        id: ownerRecordId,
        points: 20,
        actualMinutes: 15,
      }),
    ]);
  });
});
