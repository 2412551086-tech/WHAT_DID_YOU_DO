import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { FamiliesModule } from '../families/families.module';
import { ChoreRecordsController } from './chore-records.controller';
import { ChoreRecordsService } from './chore-records.service';

@Module({
  imports: [AuthModule, FamiliesModule],
  controllers: [ChoreRecordsController],
  providers: [ChoreRecordsService],
  exports: [ChoreRecordsService],
})
export class ChoreRecordsModule {}
