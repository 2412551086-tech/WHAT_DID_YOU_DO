import { INestApplication, ValidationPipe } from "@nestjs/common";
import { Test } from "@nestjs/testing";
import request = require("supertest");
import { AppModule } from "../src/app.module";
import { PrismaService } from "../src/prisma/prisma.service";

describe("AppController (e2e)", () => {
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

  it("creates chore records with selected actual minutes and calculated points", async () => {
    const loginResponse = await request(app.getHttpServer())
      .post("/auth/mock-login")
      .send({ displayName: "E2E 实际耗时用户" })
      .expect(201);
    const token = loginResponse.body.accessToken;

    const familyResponse = await request(app.getHttpServer())
      .post("/families")
      .set("Authorization", `Bearer ${token}`)
      .send({ name: "E2E actual minutes family", requirePhotoProof: false })
      .expect(201);
    const familyId = familyResponse.body.id;

    const actualRecordResponse = await request(app.getHttpServer())
      .post("/chore-records")
      .set("Authorization", `Bearer ${token}`)
      .send({
        familyId,
        choreId,
        actualMinutes: 20,
        note: "selected by e2e",
      })
      .expect(201);

    expect(actualRecordResponse.body).toMatchObject({
      familyId,
      minutes: 15,
      actualMinutes: 20,
      points: 27,
      note: "selected by e2e",
    });

    const defaultRecordResponse = await request(app.getHttpServer())
      .post("/chore-records")
      .set("Authorization", `Bearer ${token}`)
      .send({
        familyId,
        choreId,
      })
      .expect(201);

    expect(defaultRecordResponse.body).toMatchObject({
      familyId,
      minutes: 15,
      actualMinutes: 15,
      points: 20,
    });

    await request(app.getHttpServer())
      .post("/chore-records")
      .set("Authorization", `Bearer ${token}`)
      .send({
        familyId,
        choreId,
        actualMinutes: 181,
      })
      .expect(400);

    const activityResponse = await request(app.getHttpServer())
      .get(`/families/${familyId}/activity`)
      .set("Authorization", `Bearer ${token}`)
      .expect(200);

    expect(activityResponse.body).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          actualMinutes: 20,
          points: 27,
        }),
        expect.objectContaining({
          actualMinutes: 15,
          points: 20,
        }),
      ]),
    );

    const leaderboardResponse = await request(app.getHttpServer())
      .get(`/families/${familyId}/leaderboard?range=month`)
      .set("Authorization", `Bearer ${token}`)
      .expect(200);

    expect(leaderboardResponse.body[0]).toMatchObject({
      points: 47,
      recordCount: 2,
    });

    const month = new Date().toISOString().slice(0, 7);
    const reportResponse = await request(app.getHttpServer())
      .get(`/families/${familyId}/monthly-report?month=${month}`)
      .set("Authorization", `Bearer ${token}`)
      .expect(200);

    expect(reportResponse.body).toMatchObject({
      familyId,
      totalPoints: 47,
      totalRecords: 2,
    });
    expect(reportResponse.body.recentRecords).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          actualMinutes: 20,
          points: 27,
        }),
      ]),
    );
  });
});
