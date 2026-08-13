import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { DevAuthGuard } from '../auth/guards/dev-auth.guard';
import { AuthUser } from '../auth/auth-user';
import { CreateFamilyDto } from './dto/create-family.dto';
import { CreateJoinRequestByInviteCodeDto } from './dto/create-join-request-by-invite-code.dto';
import { CreateJoinRequestDto } from './dto/create-join-request.dto';
import { ReviewJoinRequestDto } from './dto/review-join-request.dto';
import { TransferOwnershipDto } from './dto/transfer-ownership.dto';
import { UpdateFamilyDto } from './dto/update-family.dto';
import { UpdateMemberAppearanceDto } from './dto/update-member-appearance.dto';
import { FamiliesService } from './families.service';

@UseGuards(DevAuthGuard)
@Controller('families')
export class FamiliesController {
  constructor(private readonly familiesService: FamiliesService) {}

  @Post()
  createFamily(@CurrentUser() user: AuthUser, @Body() dto: CreateFamilyDto) {
    return this.familiesService.createFamily(user, dto);
  }

  @Get('me')
  getMyFamilies(@CurrentUser() user: AuthUser) {
    return this.familiesService.getMyFamilies(user);
  }

  @Patch(':familyId')
  updateFamily(
    @CurrentUser() user: AuthUser,
    @Param('familyId') familyId: string,
    @Body() dto: UpdateFamilyDto,
  ) {
    return this.familiesService.updateFamilyName(user, familyId, dto.name);
  }

  @Get('invitations/:inviteCode')
  getInvitePreview(@CurrentUser() user: AuthUser, @Param('inviteCode') inviteCode: string) {
    return this.familiesService.getInvitePreview(user, inviteCode);
  }

  @Get('join-requests/me')
  getMyJoinRequest(@CurrentUser() user: AuthUser) {
    return this.familiesService.getMyJoinRequest(user);
  }

  @Post('join-requests')
  createJoinRequestByInviteCode(
    @CurrentUser() user: AuthUser,
    @Body() dto: CreateJoinRequestByInviteCodeDto,
  ) {
    return this.familiesService.createJoinRequestByInviteCode(user, dto);
  }

  @Post(':familyId/join-requests')
  createJoinRequest(
    @CurrentUser() user: AuthUser,
    @Param('familyId') familyId: string,
    @Body() dto: CreateJoinRequestDto,
  ) {
    return this.familiesService.createJoinRequest(user, familyId, dto);
  }

  @Get(':familyId/join-requests')
  getJoinRequests(@CurrentUser() user: AuthUser, @Param('familyId') familyId: string) {
    return this.familiesService.getJoinRequests(user, familyId);
  }

  @Patch(':familyId/join-requests/:memberId')
  reviewJoinRequest(
    @CurrentUser() user: AuthUser,
    @Param('familyId') familyId: string,
    @Param('memberId') memberId: string,
    @Body() dto: ReviewJoinRequestDto,
  ) {
    return this.familiesService.reviewJoinRequest(user, familyId, memberId, dto);
  }

  @Patch(':familyId/owner')
  transferOwnership(
    @CurrentUser() user: AuthUser,
    @Param('familyId') familyId: string,
    @Body() dto: TransferOwnershipDto,
  ) {
    return this.familiesService.transferOwnership(user, familyId, dto.memberId);
  }

  @Delete(':familyId/members/me')
  leaveFamily(@CurrentUser() user: AuthUser, @Param('familyId') familyId: string) {
    return this.familiesService.leaveFamily(user, familyId);
  }

  @Delete(':familyId')
  dissolveFamily(@CurrentUser() user: AuthUser, @Param('familyId') familyId: string) {
    return this.familiesService.dissolveFamily(user, familyId);
  }

  @Patch(':familyId/members/me/appearance')
  updateMyAppearance(
    @CurrentUser() user: AuthUser,
    @Param('familyId') familyId: string,
    @Body() dto: UpdateMemberAppearanceDto,
  ) {
    return this.familiesService.updateMyAppearance(user, familyId, dto.avatarKey);
  }
}
