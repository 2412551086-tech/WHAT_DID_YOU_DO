import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { FamiliesModule } from '../families/families.module';
import { ChoreLayoutController } from './chore-layout.controller';
import { ChoresController } from './chores.controller';
import { ChoresService } from './chores.service';
import { CustomChoresController } from './custom-chores.controller';

@Module({
  imports: [AuthModule, FamiliesModule],
  controllers: [ChoresController, CustomChoresController, ChoreLayoutController],
  providers: [ChoresService],
  exports: [ChoresService],
})
export class ChoresModule {}
