import { Module } from '@nestjs/common';
import { AchievementsModule } from './achievements/achievements.module';
import { AchievementOutboxModule } from './achievements/achievement-outbox.module';
import { AuthModule } from './auth/auth.module';
import { ChoreRecordsModule } from './chore-records/chore-records.module';
import { ChoresModule } from './chores/chores.module';
import { FamiliesModule } from './families/families.module';
import { PrismaModule } from './prisma/prisma.module';
import { ReportsModule } from './reports/reports.module';

@Module({
  imports: [
    PrismaModule,
    AchievementOutboxModule,
    AuthModule,
    AchievementsModule,
    FamiliesModule,
    ChoresModule,
    ChoreRecordsModule,
    ReportsModule,
  ],
})
export class AppModule {}
