import { Controller, Get, UseGuards } from '@nestjs/common';
import { AuthUser } from '../auth/auth-user';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { DevAuthGuard } from '../auth/guards/dev-auth.guard';
import { AchievementsQueryService } from './achievements-query.service';

@UseGuards(DevAuthGuard)
@Controller('achievements')
export class AchievementArchiveController {
  constructor(private readonly queryService: AchievementsQueryService) {}

  @Get('archive')
  getArchive(@CurrentUser() user: AuthUser) {
    return this.queryService.getArchive(user);
  }
}
