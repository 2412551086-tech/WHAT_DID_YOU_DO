import { prisma } from "./client";

const coreChores = [
  { name: "做饭 / 备餐", category: "厨房类", standardMinutes: 45, difficultyMultiplier: 1.5, defaultPoints: 68, icon: "flame.fill" },
  { name: "饭后收拾 / 洗碗", category: "厨房类", standardMinutes: 15, difficultyMultiplier: 1.4, defaultPoints: 21, icon: "fork.knife" },
  { name: "洗衣服", category: "洗护类", standardMinutes: 10, difficultyMultiplier: 1.3, defaultPoints: 13, icon: "washer.fill" },
  { name: "收衣 / 叠衣", category: "洗护类", standardMinutes: 15, difficultyMultiplier: 1.2, defaultPoints: 18, icon: "square.stack.3d.up.fill" },
  { name: "扫地 / 吸尘", category: "清洁类", standardMinutes: 20, difficultyMultiplier: 1.3, defaultPoints: 26, icon: "sparkles" },
  { name: "拖地 / 地面湿清洁", category: "清洁类", standardMinutes: 25, difficultyMultiplier: 1.6, defaultPoints: 40, icon: "drop.fill" },
  { name: "整理收纳", category: "收纳类", standardMinutes: 20, difficultyMultiplier: 1.3, defaultPoints: 26, icon: "shippingbox.fill" },
  { name: "卫生间清洁", category: "清洁类", standardMinutes: 20, difficultyMultiplier: 1.5, defaultPoints: 30, icon: "shower.fill" },
  { name: "倒垃圾 / 垃圾分类", category: "清洁类", standardMinutes: 10, difficultyMultiplier: 1.0, defaultPoints: 10, icon: "trash.fill" },
  { name: "采购补货 / 家庭物资管理", category: "采购类", standardMinutes: 30, difficultyMultiplier: 1.2, defaultPoints: 36, icon: "cart.fill" },
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
    await prisma.chore.upsert({
      where: { name: chore.name },
      update: {
        ...chore,
        isFreeCore: true,
        sortOrder: index + 1,
      },
      create: {
        ...chore,
        isFreeCore: true,
        sortOrder: index + 1,
      },
    });
  }

  console.log(`Seeded ${coreChores.length} core chores.`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
