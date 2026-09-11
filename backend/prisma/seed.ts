import { prisma } from "./client";
import { achievementDefinitions } from "./achievement-definitions";
import { additionalChoreCatalog } from "../src/chores/premium-chore-catalog";
import { themedChoreCatalog } from "../src/chores/themed-chore-catalog";

const coreChores = [
  { catalogKey: "core-cook-prepare", themeKey: "daily", name: "做饭备餐", category: "烹饪", standardMinutes: 45, difficultyMultiplier: 1.5, defaultPoints: 68, icon: "flame.fill" },
  { catalogKey: "core-dishes-cleanup", themeKey: "daily", name: "洗碗收桌", category: "清洁", standardMinutes: 15, difficultyMultiplier: 1.4, defaultPoints: 21, icon: "fork.knife" },
  { catalogKey: "core-laundry", themeKey: "daily", name: "洗衣服", category: "洗护", standardMinutes: 10, difficultyMultiplier: 1.3, defaultPoints: 13, icon: "washer.fill" },
  { catalogKey: "core-fold-clothes", themeKey: "daily", name: "收叠衣物", category: "洗护", standardMinutes: 15, difficultyMultiplier: 1.2, defaultPoints: 18, icon: "square.stack.3d.up.fill" },
  { catalogKey: "core-sweep-vacuum", themeKey: "daily", name: "扫地吸尘", category: "清洁", standardMinutes: 20, difficultyMultiplier: 1.3, defaultPoints: 26, icon: "sparkles" },
  { catalogKey: "core-mop-floor", themeKey: "daily", name: "拖地清洁", category: "清洁", standardMinutes: 25, difficultyMultiplier: 1.6, defaultPoints: 40, icon: "drop.fill" },
  { catalogKey: "core-organize-storage", themeKey: "daily", name: "整理收纳", category: "整理", standardMinutes: 20, difficultyMultiplier: 1.3, defaultPoints: 26, icon: "shippingbox.fill" },
  { catalogKey: "core-bathroom-clean", themeKey: "daily", name: "卫生间清洁", category: "清洁", standardMinutes: 20, difficultyMultiplier: 1.5, defaultPoints: 30, icon: "shower.fill" },
  { catalogKey: "core-trash-recycling", themeKey: "daily", name: "倒垃圾", category: "清洁", standardMinutes: 10, difficultyMultiplier: 1.0, defaultPoints: 10, icon: "trash.fill" },
  { catalogKey: "core-shopping-supplies", themeKey: "daily", name: "采购补货", category: "家庭事务", standardMinutes: 30, difficultyMultiplier: 1.2, defaultPoints: 36, icon: "cart.fill" },
];

async function main() {
  await prisma.chore.updateMany({
    where: {
      isFreeCore: true,
      name: {
        notIn: coreChores.map((chore) => chore.name),
      },
    },
    data: {
      isFreeCore: false,
      sortOrder: 999,
    },
  });

  for (const [index, chore] of coreChores.entries()) {
    const catalogRecord = await prisma.chore.findUnique({
      where: { catalogKey: chore.catalogKey },
    });
    const existing = catalogRecord ?? await prisma.chore.findFirst({
      where: {
        name: chore.name,
        isCustom: false,
        familyId: null,
        catalogKey: null,
      },
    });

    if (existing) {
      await prisma.chore.update({
        where: { id: existing.id },
        data: {
          ...chore,
          isFreeCore: true,
          isCustom: false,
          familyId: null,
          createdById: null,
          customSlot: null,
          archivedAt: null,
          sortOrder: index + 1,
        },
      });

      await prisma.chore.updateMany({
        where: {
          id: { not: existing.id },
          name: chore.name,
          isCustom: false,
          familyId: null,
        },
        data: {
          isFreeCore: false,
          sortOrder: 999,
        },
      });
    } else {
      await prisma.chore.create({
        data: {
          ...chore,
          isFreeCore: true,
          isCustom: false,
          sortOrder: index + 1,
        },
      });
    }
  }

  for (const [index, chore] of additionalChoreCatalog.entries()) {
    await prisma.chore.upsert({
      where: { catalogKey: chore.id },
      update: {
        name: chore.name,
        themeKey: chore.themeKey,
        category: chore.category,
        standardMinutes: chore.standardMinutes,
        difficultyMultiplier: chore.difficultyMultiplier,
        defaultPoints: chore.defaultPoints,
        icon: chore.icon,
        isFreeCore: true,
        isCustom: false,
        familyId: null,
        createdById: null,
        customSlot: null,
        archivedAt: null,
        sortOrder: 101 + index,
      },
      create: {
        id: chore.id,
        catalogKey: chore.id,
        name: chore.name,
        themeKey: chore.themeKey,
        category: chore.category,
        standardMinutes: chore.standardMinutes,
        difficultyMultiplier: chore.difficultyMultiplier,
        defaultPoints: chore.defaultPoints,
        icon: chore.icon,
        isFreeCore: true,
        isCustom: false,
        sortOrder: 101 + index,
      },
    });
  }

  for (const [index, chore] of themedChoreCatalog.entries()) {
    await prisma.chore.upsert({
      where: { catalogKey: chore.id },
      update: {
        name: chore.name,
        themeKey: chore.themeKey,
        category: chore.category,
        standardMinutes: chore.standardMinutes,
        difficultyMultiplier: chore.difficultyMultiplier,
        defaultPoints: chore.defaultPoints,
        icon: chore.icon,
        isFreeCore: true,
        isCustom: false,
        familyId: null,
        createdById: null,
        customSlot: null,
        archivedAt: null,
        sortOrder: 201 + index,
      },
      create: {
        id: chore.id,
        catalogKey: chore.id,
        name: chore.name,
        themeKey: chore.themeKey,
        category: chore.category,
        standardMinutes: chore.standardMinutes,
        difficultyMultiplier: chore.difficultyMultiplier,
        defaultPoints: chore.defaultPoints,
        icon: chore.icon,
        isFreeCore: true,
        isCustom: false,
        sortOrder: 201 + index,
      },
    });
  }

  for (const definition of achievementDefinitions) {
    await prisma.achievementDefinition.upsert({
      where: {
        key_tier_definitionVersion: {
          key: definition.key,
          tier: definition.tier,
          definitionVersion: definition.definitionVersion,
        },
      },
      update: definition,
      create: definition,
    });
  }

  console.log(`Seeded ${coreChores.length + additionalChoreCatalog.length + themedChoreCatalog.length} themed system chores.`);
  console.log(`Seeded ${achievementDefinitions.length} achievement definitions.`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
