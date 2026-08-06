import { Body, Controller, Delete, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { AuthUser } from '../auth/auth-user';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { DevAuthGuard } from '../auth/guards/dev-auth.guard';
import { ChoreRecordsService } from './chore-records.service';
import { ActivityQueryDto } from './dto/activity-query.dto';
import { CreateChoreRecordDto } from './dto/create-chore-record.dto';
import { LeaderboardQueryDto } from './dto/leaderboard-query.dto';
import { ReactToChoreRecordDto } from './dto/react-to-chore-record.dto';

@UseGuards(DevAuthGuard)
@Controller()
export class ChoreRecordsController {
  constructor(private readonly choreRecordsService: ChoreRecordsService) {}

  @Post('chore-records')
  createRecord(@CurrentUser() user: AuthUser, @Body() dto: CreateChoreRecordDto) {
    return this.choreRecordsService.createRecord(user, dto);
  }

  @Get('families/:familyId/activity')
  getActivity(
    @CurrentUser() user: AuthUser,
    @Param('familyId') familyId: string,
    @Query() query: ActivityQueryDto,
  ) {
    return this.choreRecordsService.getActivity(
      user,
      familyId,
      query.range ?? 'recent',
      query.weekOffset ?? 0,
    );
  }

  @Get('families/:familyId/members/:memberId/activity')
  getMemberActivity(
    @CurrentUser() user: AuthUser,
    @Param('familyId') familyId: string,
    @Param('memberId') memberId: string,
  ) {
    return this.choreRecordsService.getMemberActivity(user, familyId, memberId);
  }

  @Get('families/:familyId/leaderboard')
  getLeaderboard(
    @CurrentUser() user: AuthUser,
    @Param('familyId') familyId: string,
    @Query() query: LeaderboardQueryDto,
  ) {
    return this.choreRecordsService.getLeaderboard(
      user,
      familyId,
      query.range ?? 'month',
      query.weekOffset ?? 0,
    );
  }

  @Delete('chore-records/:recordId')
  deleteRecord(@CurrentUser() user: AuthUser, @Param('recordId') recordId: string) {
    return this.choreRecordsService.deleteRecord(user, recordId);
  }

  @Post('chore-records/:recordId/like')
  likeRecord(
    @CurrentUser() user: AuthUser,
    @Param('recordId') recordId: string,
    @Body() dto: ReactToChoreRecordDto,
  ) {
    return this.choreRecordsService.likeRecord(user, recordId, dto.reactionKey ?? 'like');
  }

  @Delete('chore-records/:recordId/like')
  unlikeRecord(@CurrentUser() user: AuthUser, @Param('recordId') recordId: string) {
    return this.choreRecordsService.unlikeRecord(user, recordId);
  }
}
