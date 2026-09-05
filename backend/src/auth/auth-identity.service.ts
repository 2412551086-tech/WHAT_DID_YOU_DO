import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { AuthIdentity, AuthProvider, Prisma, User } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

interface IdentityDescriptor {
  provider: AuthProvider;
  providerSubject: string;
}

interface LoginOrCreateIdentityInput extends IdentityDescriptor {
  displayName: string;
  updateDisplayName?: boolean;
  verifiedAt?: Date | null;
}

@Injectable()
export class AuthIdentityService {
  constructor(private readonly prisma: PrismaService) {}

  resolveDevelopmentIdentifier(rawIdentifier: string): IdentityDescriptor {
    return {
      provider: AuthProvider.DEV,
      providerSubject: this.normalizeProviderSubject(rawIdentifier),
    };
  }

  async loginOrCreateIdentity(input: LoginOrCreateIdentityInput): Promise<User> {
    const subject = this.normalizeSubject(input.provider, input.providerSubject);
    const now = new Date();
    const existing = await this.prisma.authIdentity.findUnique({
      where: {
        provider_providerSubject: {
          provider: input.provider,
          providerSubject: subject,
        },
      },
      include: { user: true },
    });

    if (existing) {
      return this.touchIdentity(existing, input.displayName, input.updateDisplayName === true, now);
    }

    try {
      return await this.prisma.user.create({
        data: {
          displayName: input.displayName,
          authIdentities: {
            create: {
              provider: input.provider,
              providerSubject: subject,
              verifiedAt: input.verifiedAt ?? null,
              lastUsedAt: now,
            },
          },
        },
      });
    } catch (error) {
      if (!this.isUniqueConstraintError(error)) {
        throw error;
      }
      const racedIdentity = await this.prisma.authIdentity.findUnique({
        where: {
          provider_providerSubject: {
            provider: input.provider,
            providerSubject: subject,
          },
        },
        include: { user: true },
      });
      if (!racedIdentity) {
        throw error;
      }
      return this.touchIdentity(
        racedIdentity,
        input.displayName,
        input.updateDisplayName === true,
        now,
      );
    }
  }

  async bindIdentity(
    userId: string,
    provider: AuthProvider,
    rawProviderSubject: string,
    verifiedAt = new Date(),
  ): Promise<AuthIdentity> {
    if (provider === AuthProvider.DEV) {
      throw new BadRequestException('Development identities cannot be bound');
    }
    const providerSubject = this.normalizeSubject(provider, rawProviderSubject);
    try {
      return await this.prisma.$transaction(async (transaction) => {
        const user = await transaction.user.findUnique({ where: { id: userId } });
        if (!user || user.anonymizedAt) {
          throw new NotFoundException('User not found');
        }

        const ownedIdentity = await transaction.authIdentity.findUnique({
          where: { userId_provider: { userId, provider } },
        });
        if (ownedIdentity) {
          if (ownedIdentity.providerSubject !== providerSubject) {
            throw new ConflictException('User already has a different identity for this provider');
          }
          return transaction.authIdentity.update({
            where: { id: ownedIdentity.id },
            data: { verifiedAt, lastUsedAt: new Date() },
          });
        }

        const claimedIdentity = await transaction.authIdentity.findUnique({
          where: { provider_providerSubject: { provider, providerSubject } },
        });
        if (claimedIdentity && claimedIdentity.userId !== userId) {
          throw new ConflictException('Identity is already bound to another user');
        }

        return transaction.authIdentity.create({
          data: { userId, provider, providerSubject, verifiedAt, lastUsedAt: new Date() },
        });
      });
    } catch (error) {
      if (this.isUniqueConstraintError(error)) {
        throw new ConflictException('Identity is already bound to another user');
      }
      throw error;
    }
  }

  async unbindIdentity(userId: string, provider: AuthProvider) {
    return this.prisma.$transaction(async (transaction) => {
      const identities = await transaction.authIdentity.findMany({ where: { userId } });
      const identity = identities.find((item) => item.provider === provider);
      if (!identity) {
        throw new NotFoundException('Identity not found');
      }
      if (identities.length <= 1) {
        throw new BadRequestException('At least one login identity must remain');
      }

      await transaction.authIdentity.delete({ where: { id: identity.id } });
      return { unbound: true, provider };
    });
  }

  listIdentities(userId: string) {
    return this.prisma.authIdentity.findMany({
      where: { userId },
      select: {
        id: true,
        provider: true,
        verifiedAt: true,
        lastUsedAt: true,
        createdAt: true,
      },
      orderBy: { createdAt: 'asc' },
    });
  }

  private async touchIdentity(
    identity: AuthIdentity & { user: User },
    displayName: string,
    updateDisplayName: boolean,
    lastUsedAt: Date,
  ) {
    const [, user] = await this.prisma.$transaction([
      this.prisma.authIdentity.update({
        where: { id: identity.id },
        data: { lastUsedAt },
      }),
      updateDisplayName && displayName !== identity.user.displayName
        ? this.prisma.user.update({
            where: { id: identity.userId },
            data: { displayName },
          })
        : this.prisma.user.findUniqueOrThrow({ where: { id: identity.userId } }),
    ]);
    return user;
  }

  private normalizeSubject(provider: AuthProvider, rawProviderSubject: string) {
    const subject = this.normalizeProviderSubject(rawProviderSubject);
    return provider === AuthProvider.EMAIL ? subject.toLowerCase() : subject;
  }

  private normalizeProviderSubject(rawProviderSubject: string) {
    const subject = rawProviderSubject.trim();
    if (!subject || subject.length > 255) {
      throw new BadRequestException('providerSubject must contain 1 to 255 characters');
    }
    return subject;
  }

  private isUniqueConstraintError(error: unknown) {
    return error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002';
  }
}
