import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { AchievementsModule } from '../achievements/achievements.module';
import { FamiliesModule } from '../families/families.module';
import { ChoreLayoutController } from './chore-layout.controller';
import { ChoresController } from './chores.controller';
import { ChoresService } from './chores.service';
import { CustomChoresController } from './custom-chores.controller';

@Module({
  imports: [AuthModule, FamiliesModule, AchievementsModule],
  controllers: [ChoresController, CustomChoresController, ChoreLayoutController],
  providers: [ChoresService],
  exports: [ChoresService],
})
export class ChoresModule {}
