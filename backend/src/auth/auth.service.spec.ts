import { ForbiddenException } from '@nestjs/common';
import { AuthProvider } from '@prisma/client';
import { AuthService } from './auth.service';

describe('AuthService premium redemption access', () => {
  const originalEnvironment = { ...process.env };

  afterEach(() => {
    process.env = { ...originalEnvironment };
    jest.restoreAllMocks();
  });

  function makeService(providerSubject: string | null) {
    const prisma = {
      authIdentity: {
        findFirst: jest.fn().mockResolvedValue(
          providerSubject ? { providerSubject } : null,
        ),
      },
    };
    const service = new AuthService(
      prisma as never,
      {} as never,
      {} as never,
      {} as never,
    );
    return { service, prisma };
  }

  it('rejects production redemption when the internal switch is off', async () => {
    process.env.NODE_ENV = 'production';
    process.env.TEST_PREMIUM_REDEMPTION_ENABLED = 'false';
    const { service, prisma } = makeService('tester@example.com');

    await expect(
      (service as any).assertPremiumRedemptionAllowed('user-1'),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(prisma.authIdentity.findFirst).not.toHaveBeenCalled();
  });

  it('allows only a verified email identity on the production allowlist', async () => {
    process.env.NODE_ENV = 'production';
    process.env.TEST_PREMIUM_REDEMPTION_ENABLED = 'true';
    process.env.TEST_PREMIUM_REDEMPTION_EMAILS = 'tester@example.com, second@example.com';
    const { service, prisma } = makeService('Tester@Example.com');

    await expect(
      (service as any).assertPremiumRedemptionAllowed('user-1'),
    ).resolves.toBeUndefined();
    expect(prisma.authIdentity.findFirst).toHaveBeenCalledWith({
      where: { userId: 'user-1', provider: AuthProvider.EMAIL },
      select: { providerSubject: true },
    });
  });

  it('rejects a production account outside the allowlist', async () => {
    process.env.NODE_ENV = 'production';
    process.env.TEST_PREMIUM_REDEMPTION_ENABLED = 'true';
    process.env.TEST_PREMIUM_REDEMPTION_EMAILS = 'tester@example.com';
    const { service } = makeService('someone-else@example.com');

    await expect(
      (service as any).assertPremiumRedemptionAllowed('user-2'),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });
});
