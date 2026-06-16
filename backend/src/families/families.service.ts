import { Injectable, NotFoundException } from '@nestjs/common';
import { randomBytes } from 'node:crypto';
import { AuthUser } from '../auth/auth-user';
import { PrismaService } from '../prisma/prisma.service';
import { CreateFamilyDto } from './dto/create-family.dto';

@Injectable()
export class FamiliesService {
  constructor(private readonly prisma: PrismaService) {}

  async createFamily(user: AuthUser, dto: CreateFamilyDto) {
    return this.prisma.family.create({
      data: {
        name: dto.name.trim(),
        requirePhotoProof: dto.requirePhotoProof ?? false,
        inviteCode: this.createInviteCode(),
        members: {
          create: {
            userId: user.id,
            role: 'owner',
          },
        },
      },
      include: {
        members: {
          include: {
            user: true,
          },
        },
      },
    });
  }

  async getMyFamilies(user: AuthUser) {
    const memberships = await this.prisma.familyMember.findMany({
      where: { userId: user.id },
      include: {
        family: {
          include: {
            members: {
              include: {
                user: true,
              },
            },
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    return memberships.map((membership) => ({
      ...membership.family,
      myRole: membership.role,
    }));
  }

  async assertMember(familyId: string, userId: string) {
    const membership = await this.prisma.familyMember.findUnique({
      where: {
        userId_familyId: {
          userId,
          familyId,
        },
      },
    });

    if (!membership) {
      throw new NotFoundException('Family not found');
    }

    return membership;
  }

  private createInviteCode(): string {
    return randomBytes(4).toString('hex').toUpperCase();
  }
}
