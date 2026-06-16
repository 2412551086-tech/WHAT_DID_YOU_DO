import { prisma } from "./client";

const coreChores = [
  { name: "洗碗", category: "厨房类", standardMinutes: 15, difficultyMultiplier: 1.0, defaultPoints: 15, icon: "fork.knife" },
  { name: "做饭", category: "厨房类", standardMinutes: 45, difficultyMultiplier: 1.3, defaultPoints: 59, icon: "flame.fill" },
  { name: "倒垃圾", category: "清洁类", standardMinutes: 5, difficultyMultiplier: 1.0, defaultPoints: 5, icon: "trash.fill" },
  { name: "扫地", category: "清洁类", standardMinutes: 15, difficultyMultiplier: 1.0, defaultPoints: 15, icon: "sparkles" },
  { name: "拖地", category: "清洁类", standardMinutes: 20, difficultyMultiplier: 1.1, defaultPoints: 22, icon: "drop.fill" },
  { name: "洗衣服", category: "洗护类", standardMinutes: 10, difficultyMultiplier: 1.0, defaultPoints: 10, icon: "washer.fill" },
  { name: "晾衣服", category: "洗护类", standardMinutes: 10, difficultyMultiplier: 1.0, defaultPoints: 10, icon: "wind" },
  { name: "叠衣服", category: "洗护类", standardMinutes: 20, difficultyMultiplier: 1.1, defaultPoints: 22, icon: "square.stack.3d.up.fill" },
  { name: "清理卫生间", category: "清洁类", standardMinutes: 30, difficultyMultiplier: 1.5, defaultPoints: 45, icon: "shower.fill" },
  { name: "浇花", category: "照顾类", standardMinutes: 8, difficultyMultiplier: 1.0, defaultPoints: 8, icon: "leaf.fill" },
];

async function main() {
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
