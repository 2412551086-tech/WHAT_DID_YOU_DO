import { Body, Controller, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { DevAuthGuard } from '../auth/guards/dev-auth.guard';
import { AuthUser } from '../auth/auth-user';
import { CreateFamilyDto } from './dto/create-family.dto';
import { CreateJoinRequestDto } from './dto/create-join-request.dto';
import { ReviewJoinRequestDto } from './dto/review-join-request.dto';
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
}
