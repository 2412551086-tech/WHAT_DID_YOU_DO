import { Controller, Get, Param } from '@nestjs/common';
import { FamiliesService } from './families.service';

@Controller('family-invitations')
export class FamilyInvitationsController {
  constructor(private readonly familiesService: FamiliesService) {}

  @Get(':inviteCode')
  getPublicPreview(@Param('inviteCode') inviteCode: string) {
    return this.familiesService.getPublicInvitePreview(inviteCode);
  }
}
