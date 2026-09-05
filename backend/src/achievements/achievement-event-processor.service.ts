import { Injectable } from '@nestjs/common';
import { AchievementEvent, Prisma } from '@prisma/client';
import { AchievementFamilyCollaborationService } from './achievement-family-collaboration.service';
import { AchievementFamilyMilestoneService } from './achievement-family-milestone.service';
import { AchievementHiddenService } from './achievement-hidden.service';
import { AchievementJourneyService } from './achievement-journey.service';
import { AchievementMasteryService } from './achievement-mastery.service';
import { AchievementPairService } from './achievement-pair.service';
import { AchievementReactionService } from './achievement-reaction.service';
import { AchievementLifecycleService } from './achievement-lifecycle.service';
import { AchievementRuleRegistry } from './achievement-rule-registry';

@Injectable()
export class AchievementEventProcessorService {
  constructor(
    private readonly ruleRegistry: AchievementRuleRegistry,
    private readonly journeyService: AchievementJourneyService,
    private readonly masteryService: AchievementMasteryService,
    private readonly reactionService: AchievementReactionService,
    private readonly familyCollaborationService: AchievementFamilyCollaborationService,
    private readonly pairService: AchievementPairService,
    private readonly familyMilestoneService: AchievementFamilyMilestoneService,
    private readonly hiddenService: AchievementHiddenService,
    private readonly lifecycleService: AchievementLifecycleService,
  ) {}

  async process(transaction: Prisma.TransactionClient, event: AchievementEvent) {
    if (!this.ruleRegistry.supports(event.eventType)) {
      throw new Error(`UNSUPPORTED_EVENT_TYPE:${event.eventType}`);
    }

    const ruleTypes = this.ruleRegistry.affectedRuleTypes(event.eventType);
    const definitions = ruleTypes.length
      ? await transaction.achievementDefinition.findMany({
          where: {
            isActive: true,
            ruleType: { in: [...ruleTypes] },
          },
          select: {
            id: true,
            key: true,
            tier: true,
            definitionVersion: true,
          },
        })
      : [];
    const journey = await this.journeyService.process(transaction, event);
    const mastery = await this.masteryService.process(transaction, event);
    const reaction = await this.reactionService.process(transaction, event);
    const familyCollaboration = await this.familyCollaborationService.process(transaction, event);
    const pair = await this.pairService.process(transaction, event);
    const familyMilestone = await this.familyMilestoneService.process(transaction, event);
    const hidden = await this.hiddenService.process(transaction, event);
    const lifecycle = await this.lifecycleService.process(transaction, event);
    await this.finalizeUnlockBatch(transaction, event.id);

    return {
      affectedDefinitions: definitions,
      auditAfter: {
        eventType: event.eventType,
        affectedDefinitionCount: definitions.length,
        affectedDefinitionKeys: [...new Set(definitions.map((definition) => definition.key))],
        journeyProgressUpdateCount: journey.progressUpdateCount,
        masteryProgressUpdateCount: mastery.progressUpdateCount,
        reactionProgressUpdateCount: reaction.progressUpdateCount,
        familyProgressUpdateCount: familyCollaboration.progressUpdateCount,
        pairProgressUpdateCount: pair.progressUpdateCount,
        familyMilestoneProgressUpdateCount: familyMilestone.progressUpdateCount,
        hiddenProgressUpdateCount: hidden.progressUpdateCount,
        lifecycleParticipantUpdateCount: lifecycle.participantUpdates,
        lifecyclePairArchiveUpdateCount: lifecycle.pairArchiveUpdates,
        unlockedKeys: [
          ...journey.unlockedKeys,
          ...mastery.unlockedKeys,
          ...reaction.unlockedKeys,
          ...familyCollaboration.unlockedKeys,
          ...pair.unlockedKeys,
          ...familyMilestone.unlockedKeys,
          ...hidden.unlockedKeys,
        ],
        grantedRewards: journey.grantedRewards,
      } satisfies Prisma.InputJsonValue,
    };
  }

  private async finalizeUnlockBatch(transaction: Prisma.TransactionClient, triggerEventId: string) {
    const batch = await transaction.achievementUnlockBatch.findUnique({
      where: { triggerEventId },
      include: {
        memberUnlocks: { orderBy: { unlockedAt: 'asc' }, select: { id: true } },
        familyUnlocks: { orderBy: { unlockedAt: 'asc' }, select: { id: true } },
        pairUnlocks: { orderBy: { unlockedAt: 'asc' }, select: { id: true } },
      },
    });
    if (!batch) {
      return;
    }
    const unlockIds = [
      ...batch.memberUnlocks.map((unlock) => unlock.id),
      ...batch.familyUnlocks.map((unlock) => unlock.id),
      ...batch.pairUnlocks.map((unlock) => unlock.id),
    ];
    if (unlockIds.length === 0) return;
    await transaction.achievementUnlockBatch.update({
      where: { id: batch.id },
      data: {
        primaryUnlockId: batch.primaryUnlockId ?? unlockIds[0],
        unlockCount: unlockIds.length,
      },
    });
  }
}
