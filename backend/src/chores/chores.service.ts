import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

const premiumLockedChores = [
  {
    id: 'premium-change-bedding',
    name: '换床单',
    category: '洗护类',
    minutes: 20,
    difficultyMultiplier: 1.2,
    points: 24,
    isCoreFree: false,
    requiredPlan: 'premium',
    isLocked: true,
  },
  {
    id: 'premium-clean-stove',
    name: '清理灶台',
    category: '厨房类',
    minutes: 10,
    difficultyMultiplier: 1.1,
    points: 11,
    isCoreFree: false,
    requiredPlan: 'premium',
    isLocked: true,
  },
  {
    id: 'premium-heavy-lifting',
    name: '搬重物',
    category: '采购类',
    minutes: 20,
    difficultyMultiplier: 1.6,
    points: 32,
    isCoreFree: false,
    requiredPlan: 'premium',
    isLocked: true,
  },
  {
    id: 'premium-clean-litter',
    name: '清理猫砂',
    category: '照顾类',
    minutes: 10,
    difficultyMultiplier: 1.2,
    points: 12,
    isCoreFree: false,
    requiredPlan: 'premium',
    isLocked: true,
  },
  {
    id: 'premium-walk-dog',
    name: '遛狗',
    category: '照顾类',
    minutes: 30,
    difficultyMultiplier: 1.1,
    points: 33,
    isCoreFree: false,
    requiredPlan: 'premium',
    isLocked: true,
  },
  {
    id: 'premium-homework-help',
    name: '陪孩子写作业',
    category: '照顾类',
    minutes: 60,
    difficultyMultiplier: 1.5,
    points: 90,
    isCoreFree: false,
    requiredPlan: 'premium',
    isLocked: true,
  },
  {
    id: 'premium-repair-booking',
    name: '预约维修',
    category: '管理类',
    minutes: 15,
    difficultyMultiplier: 1.1,
    points: 17,
    isCoreFree: false,
    requiredPlan: 'premium',
    isLocked: true,
  },
  {
    id: 'premium-feed-baby',
    name: '喂奶',
    category: '照顾类',
    minutes: 25,
    difficultyMultiplier: 1.5,
    points: 38,
    isCoreFree: false,
    requiredPlan: 'premium',
    isLocked: true,
  },
  {
    id: 'premium-walk-child',
    name: '遛娃',
    category: '照顾类',
    minutes: 45,
    difficultyMultiplier: 1.4,
    points: 63,
    isCoreFree: false,
    requiredPlan: 'premium',
    isLocked: true,
  },
  {
    id: 'premium-school-run',
    name: '接送孩子',
    category: '照顾类',
    minutes: 40,
    difficultyMultiplier: 1.4,
    points: 56,
    isCoreFree: false,
    requiredPlan: 'premium',
    isLocked: true,
  },
];

@Injectable()
export class ChoresService {
  constructor(private readonly prisma: PrismaService) {}

  async listChores() {
    const coreChores = await this.prisma.chore.findMany({
      where: {
        isFreeCore: true,
      },
      orderBy: {
        sortOrder: 'asc',
      },
    });

    return [
      ...coreChores.map((chore) => ({
        id: chore.id,
        name: chore.name,
        category: chore.category,
        minutes: chore.standardMinutes,
        points: chore.defaultPoints,
        isCoreFree: chore.isFreeCore,
        requiredPlan: 'free',
        isLocked: false,
      })),
      ...premiumLockedChores,
    ];
  }
}
