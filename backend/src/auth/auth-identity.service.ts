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
  compatibilityPhoneNumber?: string;
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
    const identifier = rawIdentifier.trim();
    if (!identifier) {
      throw new BadRequestException('phoneNumber is required');
    }

    const normalizedPhone = this.tryNormalizeMainlandPhone(identifier);
    if (normalizedPhone) {
      return {
        provider: AuthProvider.PHONE,
        providerSubject: normalizedPhone,
        compatibilityPhoneNumber: normalizedPhone,
      };
    }

    return {
      provider: AuthProvider.DEV,
      providerSubject: this.normalizeProviderSubject(identifier),
      compatibilityPhoneNumber: identifier,
    };
  }

  normalizeMainlandPhone(rawPhoneNumber: string) {
    const normalized = this.tryNormalizeMainlandPhone(rawPhoneNumber);
    if (!normalized) {
      throw new BadRequestException('Only mainland China phone numbers are supported');
    }
    return normalized;
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
      return await this.prisma.$transaction(async (transaction) => {
        const legacyUser = input.compatibilityPhoneNumber
          ? await transaction.user.findFirst({
              where: {
                phoneNumber: {
                  in: this.compatibilityPhoneCandidates(input.compatibilityPhoneNumber, subject),
                },
              },
            })
          : null;

        if (legacyUser) {
          const existingProvider = await transaction.authIdentity.findUnique({
            where: {
              userId_provider: {
                userId: legacyUser.id,
                provider: input.provider,
              },
            },
          });
          if (existingProvider && existingProvider.providerSubject !== subject) {
            throw new ConflictException('User already has a different identity for this provider');
          }
          if (!existingProvider) {
            await transaction.authIdentity.create({
              data: {
                userId: legacyUser.id,
                provider: input.provider,
                providerSubject: subject,
                verifiedAt: input.verifiedAt ?? null,
                lastUsedAt: now,
              },
            });
          }
          return input.updateDisplayName === true && input.displayName !== legacyUser.displayName
            ? transaction.user.update({
                where: { id: legacyUser.id },
                data: { displayName: input.displayName },
              })
            : legacyUser;
        }

        return transaction.user.create({
          data: {
            displayName: input.displayName,
            phoneNumber: input.compatibilityPhoneNumber ?? null,
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
          if (provider === AuthProvider.PHONE && user.phoneNumber !== providerSubject) {
            await transaction.user.update({
              where: { id: userId },
              data: { phoneNumber: providerSubject },
            });
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

        if (provider === AuthProvider.PHONE && user.phoneNumber !== providerSubject) {
          await transaction.user.update({
            where: { id: userId },
            data: { phoneNumber: providerSubject },
          });
        }

        return transaction.authIdentity.create({
          data: {
            userId,
            provider,
            providerSubject,
            verifiedAt,
            lastUsedAt: new Date(),
          },
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
      if (provider === AuthProvider.PHONE) {
        await transaction.user.update({ where: { id: userId }, data: { phoneNumber: null } });
      }
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
    if (provider === AuthProvider.PHONE) {
      return this.normalizeMainlandPhone(rawProviderSubject);
    }
    return this.normalizeProviderSubject(rawProviderSubject);
  }

  private normalizeProviderSubject(rawProviderSubject: string) {
    const subject = rawProviderSubject.trim();
    if (!subject || subject.length > 255) {
      throw new BadRequestException('providerSubject must contain 1 to 255 characters');
    }
    return subject;
  }

  private tryNormalizeMainlandPhone(rawPhoneNumber: string) {
    const trimmed = rawPhoneNumber.trim();
    if (!/^[+0-9 ()-]+$/.test(trimmed)) {
      return null;
    }
    const digits = trimmed.replace(/\D/g, '');
    if (/^1[3-9]\d{9}$/.test(digits)) {
      return `+86${digits}`;
    }
    if (/^861[3-9]\d{9}$/.test(digits)) {
      return `+${digits}`;
    }
    return null;
  }

  private compatibilityPhoneCandidates(rawPhoneNumber: string, normalizedSubject: string) {
    return [...new Set([
      rawPhoneNumber.trim(),
      normalizedSubject,
      normalizedSubject.startsWith('+86') ? normalizedSubject.slice(3) : normalizedSubject,
    ])];
  }

  private isUniqueConstraintError(error: unknown) {
    return error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002';
  }
}
