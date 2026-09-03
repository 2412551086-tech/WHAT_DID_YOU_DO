import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { FamiliesController } from './families.controller';
import { FamilyInvitationsController } from './family-invitations.controller';
import { FamiliesService } from './families.service';

@Module({
  imports: [AuthModule],
  controllers: [FamiliesController, FamilyInvitationsController],
  providers: [FamiliesService],
  exports: [FamiliesService],
})
export class FamiliesModule {}
