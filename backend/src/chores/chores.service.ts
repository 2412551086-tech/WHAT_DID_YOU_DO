import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

const premiumLockedChores = [
  {
    id: 'premium-clean-litter',
    name: '清理猫砂',
    category: '宠物类',
    minutes: 8,
    points: 10,
    isCoreFree: false,
    requiredPlan: 'premium',
    isLocked: true,
  },
  {
    id: 'premium-walk-dog',
    name: '遛狗',
    category: '宠物类',
    minutes: 30,
    points: 36,
    isCoreFree: false,
    requiredPlan: 'premium',
    isLocked: true,
  },
  {
    id: 'premium-repair-booking',
    name: '预约维修',
    category: '管理类',
    minutes: 20,
    points: 26,
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
