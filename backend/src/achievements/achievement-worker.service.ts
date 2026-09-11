import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { AchievementEvent, AchievementEventStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { achievementWorkerConfig, isAchievementsEnabled } from './achievement-config';
import { AchievementEventProcessorService } from './achievement-event-processor.service';

@Injectable()
export class AchievementWorkerService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(AchievementWorkerService.name);
  private readonly config = achievementWorkerConfig();
  private timer?: NodeJS.Timeout;
  private activeDrain?: Promise<number>;
  private processedCount = 0;
  private failedCount = 0;
  private readonly durationSamples: number[] = [];
  private readonly queueDelaySamples: number[] = [];

  constructor(
    private readonly prisma: PrismaService,
    private readonly processor: AchievementEventProcessorService,
  ) {}

  onModuleInit() {
    if (!isAchievementsEnabled()) {
      return;
    }

    this.timer = setInterval(() => void this.drainAvailable(), this.config.pollIntervalMs);
    this.timer.unref();
    void this.drainAvailable();
  }

  onModuleDestroy() {
    if (this.timer) {
      clearInterval(this.timer);
    }
  }

  async drainAvailable(limit = this.config.batchSize) {
    if (!isAchievementsEnabled()) {
      return 0;
    }
    if (this.activeDrain) {
      return this.activeDrain;
    }
    this.activeDrain = this.performDrain(limit);
    try {
      return await this.activeDrain;
    } finally {
      this.activeDrain = undefined;
    }
  }

  getRuntimeMetrics() {
    return {
      processedCount: this.processedCount,
      failedCount: this.failedCount,
      failureRate: this.processedCount + this.failedCount > 0
        ? this.failedCount / (this.processedCount + this.failedCount)
        : 0,
      processingMs: this.percentiles(this.durationSamples),
      queueDelayMs: this.percentiles(this.queueDelaySamples),
      draining: Boolean(this.activeDrain),
    };
  }

  private async performDrain(limit: number) {
    let processed = 0;
    while (processed < limit) {
      const event = await this.claimNext();
      if (!event) {
        break;
      }

      await this.processClaimed(event);
      processed += 1;
    }
    return processed;
  }

  private async claimNext() {
    const now = new Date();
    const candidate = await this.prisma.achievementEvent.findFirst({
      where: {
        nextAttemptAt: { lte: now },
        OR: [
          { processStatus: AchievementEventStatus.PENDING },
          {
            processStatus: AchievementEventStatus.FAILED,
            retryCount: { lt: this.config.maxRetries },
          },
          { processStatus: AchievementEventStatus.PROCESSING },
        ],
      },
      orderBy: [{ nextAttemptAt: 'asc' }, { receivedAt: 'asc' }],
    });

    if (!candidate) {
      return null;
    }

    const claimed = await this.prisma.achievementEvent.updateMany({
      where: {
        id: candidate.id,
        processStatus: candidate.processStatus,
        nextAttemptAt: { lte: now },
      },
      data: {
        processStatus: AchievementEventStatus.PROCESSING,
        nextAttemptAt: new Date(now.getTime() + this.config.leaseMs),
      },
    });

    if (claimed.count !== 1) {
      return null;
    }

    return this.prisma.achievementEvent.findUnique({ where: { id: candidate.id } });
  }

  private async processClaimed(event: AchievementEvent) {
    const startedAt = Date.now();
    try {
      const processedAt = new Date();

      await this.prisma.$transaction(async (transaction) => {
        const result = await this.processor.process(transaction, event);
        await transaction.achievementAuditLog.create({
          data: {
            familyId: event.familyId,
            actorUserId: event.actorUserId,
            actionType: 'EVENT_DISPATCHED',
            entityType: 'AchievementEvent',
            entityId: event.id,
            afterJson: result.auditAfter,
          },
        });
        await transaction.achievementEvent.update({
          where: { id: event.id },
          data: {
            processStatus: AchievementEventStatus.SUCCEEDED,
            processedAt,
            nextAttemptAt: processedAt,
            lastErrorCode: null,
          },
        });
      });
      this.processedCount += 1;
      this.remember(this.durationSamples, Date.now() - startedAt);
      this.remember(this.queueDelaySamples, startedAt - event.receivedAt.getTime());
    } catch (error) {
      const retryCount = event.retryCount + 1;
      const retryDelay = Math.min(
        this.config.retryBaseMs * 2 ** Math.max(0, retryCount - 1),
        this.config.retryMaxMs,
      );
      const errorCode = this.errorCode(error);

      await this.prisma.achievementEvent.update({
        where: { id: event.id },
        data: {
          processStatus: AchievementEventStatus.FAILED,
          retryCount,
          nextAttemptAt: new Date(Date.now() + retryDelay),
          lastErrorCode: errorCode,
        },
      });

      this.logger.warn(`Achievement event ${event.id} failed (${errorCode}), retry ${retryCount}`);
      this.failedCount += 1;
      this.remember(this.durationSamples, Date.now() - startedAt);
    }
  }

  private remember(samples: number[], value: number) {
    samples.push(Math.max(0, value));
    if (samples.length > 500) samples.shift();
  }

  private percentiles(samples: number[]) {
    if (samples.length === 0) return { p50: 0, p95: 0, p99: 0, sampleCount: 0 };
    const sorted = [...samples].sort((left, right) => left - right);
    const at = (percentile: number) => sorted[Math.min(sorted.length - 1, Math.floor((sorted.length - 1) * percentile))];
    return { p50: at(0.5), p95: at(0.95), p99: at(0.99), sampleCount: sorted.length };
  }

  private errorCode(error: unknown) {
    if (error instanceof Error) {
      return error.message.slice(0, 200);
    }
    return 'UNKNOWN_PROCESSING_ERROR';
  }
}
