import { Body, Controller, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { AuthUser } from '../auth/auth-user';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { DevAuthGuard } from '../auth/guards/dev-auth.guard';
import { AchievementEventsService } from './achievement-events.service';
import { AchievementsQueryService } from './achievements-query.service';
import { AchievementMaintenanceService } from './achievement-maintenance.service';
import { UpdateAchievementVisibilityDto } from './dto/update-achievement-visibility.dto';
import { UpdateAchievementSharingDto } from './dto/update-achievement-sharing.dto';

@UseGuards(DevAuthGuard)
@Controller('families/:familyId')
export class AchievementsController {
  constructor(
    private readonly eventsService: AchievementEventsService,
    private readonly queryService: AchievementsQueryService,
    private readonly maintenanceService: AchievementMaintenanceService,
  ) {}

  @Get('achievements/summary')
  getSummary(@CurrentUser() user: AuthUser, @Param('familyId') familyId: string) {
    return this.queryService.getSummary(user, familyId);
  }

  @Get('achievements/me')
  getMine(@CurrentUser() user: AuthUser, @Param('familyId') familyId: string) {
    return this.queryService.getMine(user, familyId);
  }

  @Get('achievements/:definitionIdOrKey')
  getDetail(
    @CurrentUser() user: AuthUser,
    @Param('familyId') familyId: string,
    @Param('definitionIdOrKey') definitionIdOrKey: string,
  ) {
    return this.queryService.getDetail(user, familyId, definitionIdOrKey);
  }

  @Patch('achievements/:memberAchievementId/visibility')
  updateVisibility(
    @CurrentUser() user: AuthUser,
    @Param('familyId') familyId: string,
    @Param('memberAchievementId') memberAchievementId: string,
    @Body() dto: UpdateAchievementVisibilityDto,
  ) {
    return this.queryService.updateVisibility(
      user,
      familyId,
      memberAchievementId,
      dto.visibility,
    );
  }

  @Patch('achievements/visibility')
  updateSharingPreference(
    @CurrentUser() user: AuthUser,
    @Param('familyId') familyId: string,
    @Body() dto: UpdateAchievementSharingDto,
  ) {
    return this.queryService.updateSharingPreference(user, familyId, dto.showToFamily);
  }

  @Get('achievement-sync/:eventId')
  getSyncState(
    @CurrentUser() user: AuthUser,
    @Param('familyId') familyId: string,
    @Param('eventId') eventId: string,
  ) {
    return this.eventsService.getSyncState(user, familyId, eventId);
  }

  @Get('achievement-events/failed')
  getFailedEvents(@CurrentUser() user: AuthUser, @Param('familyId') familyId: string) {
    return this.eventsService.getFailedEvents(user, familyId);
  }

  @Post('achievement-events/:eventId/replay')
  replayFailedEvent(
    @CurrentUser() user: AuthUser,
    @Param('familyId') familyId: string,
    @Param('eventId') eventId: string,
  ) {
    return this.eventsService.replayFailedEvent(user, familyId, eventId);
  }

  @Get('achievement-maintenance/health')
  getMaintenanceHealth(@CurrentUser() user: AuthUser, @Param('familyId') familyId: string) {
    return this.maintenanceService.health(user, familyId);
  }

  @Post('achievement-maintenance/reconcile')
  reconcileAchievements(@CurrentUser() user: AuthUser, @Param('familyId') familyId: string) {
    return this.maintenanceService.reconcile(user, familyId);
  }
}
