import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { AchievementEventProcessorService } from './achievement-event-processor.service';
import { AchievementEventsService } from './achievement-events.service';
import { AchievementFamilyCollaborationService } from './achievement-family-collaboration.service';
import { AchievementFamilyMilestoneService } from './achievement-family-milestone.service';
import { AchievementHiddenService } from './achievement-hidden.service';
import { AchievementLifecycleService } from './achievement-lifecycle.service';
import { AchievementJourneyService } from './achievement-journey.service';
import { AchievementMasteryService } from './achievement-mastery.service';
import { AchievementMaintenanceService } from './achievement-maintenance.service';
import { AchievementOutboxModule } from './achievement-outbox.module';
import { AchievementRewardsService } from './achievement-rewards.service';
import { AchievementPairService } from './achievement-pair.service';
import { AchievementReactionService } from './achievement-reaction.service';
import { AchievementRuleRegistry } from './achievement-rule-registry';
import { AchievementWorkerService } from './achievement-worker.service';
import { AchievementsController } from './achievements.controller';
import { AchievementArchiveController } from './achievement-archive.controller';
import { AchievementsQueryService } from './achievements-query.service';

@Module({
  imports: [AuthModule, AchievementOutboxModule],
  controllers: [AchievementsController, AchievementArchiveController],
  providers: [
    AchievementRuleRegistry,
    AchievementJourneyService,
    AchievementMasteryService,
    AchievementReactionService,
    AchievementFamilyCollaborationService,
    AchievementFamilyMilestoneService,
    AchievementHiddenService,
    AchievementLifecycleService,
    AchievementMaintenanceService,
    AchievementPairService,
    AchievementRewardsService,
    AchievementEventProcessorService,
    AchievementWorkerService,
    AchievementEventsService,
    AchievementsQueryService,
  ],
  exports: [AchievementWorkerService, AchievementRewardsService],
})
export class AchievementsModule {}
