import { Body, Controller, Delete, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { AuthUser } from '../auth/auth-user';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { DevAuthGuard } from '../auth/guards/dev-auth.guard';
import { ChoreRecordsService } from './chore-records.service';
import { CreateChoreRecordDto } from './dto/create-chore-record.dto';
import { LeaderboardQueryDto } from './dto/leaderboard-query.dto';

@UseGuards(DevAuthGuard)
@Controller()
export class ChoreRecordsController {
  constructor(private readonly choreRecordsService: ChoreRecordsService) {}

  @Post('chore-records')
  createRecord(@CurrentUser() user: AuthUser, @Body() dto: CreateChoreRecordDto) {
    return this.choreRecordsService.createRecord(user, dto);
  }

  @Get('families/:familyId/activity')
  getActivity(@CurrentUser() user: AuthUser, @Param('familyId') familyId: string) {
    return this.choreRecordsService.getActivity(user, familyId);
  }

  @Get('families/:familyId/leaderboard')
  getLeaderboard(
    @CurrentUser() user: AuthUser,
    @Param('familyId') familyId: string,
    @Query() query: LeaderboardQueryDto,
  ) {
    return this.choreRecordsService.getLeaderboard(user, familyId, query.range ?? 'month');
  }

  @Delete('chore-records/:recordId')
  deleteRecord(@CurrentUser() user: AuthUser, @Param('recordId') recordId: string) {
    return this.choreRecordsService.deleteRecord(user, recordId);
  }

  @Post('chore-records/:recordId/like')
  likeRecord(@CurrentUser() user: AuthUser, @Param('recordId') recordId: string) {
    return this.choreRecordsService.likeRecord(user, recordId);
  }

  @Delete('chore-records/:recordId/like')
  unlikeRecord(@CurrentUser() user: AuthUser, @Param('recordId') recordId: string) {
    return this.choreRecordsService.unlikeRecord(user, recordId);
  }
}
