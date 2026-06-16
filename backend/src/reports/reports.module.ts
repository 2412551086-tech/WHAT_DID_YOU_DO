import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { FamiliesModule } from '../families/families.module';
import { ReportsController } from './reports.controller';
import { ReportsService } from './reports.service';

@Module({
  imports: [AuthModule, FamiliesModule],
  controllers: [ReportsController],
  providers: [ReportsService],
})
export class ReportsModule {}
