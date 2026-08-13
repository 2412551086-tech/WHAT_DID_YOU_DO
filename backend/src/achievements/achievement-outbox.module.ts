import { Global, Module } from '@nestjs/common';
import { AchievementOutboxService } from './achievement-outbox.service';

@Global()
@Module({
  providers: [AchievementOutboxService],
  exports: [AchievementOutboxService],
})
export class AchievementOutboxModule {}
