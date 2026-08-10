import { Body, Controller, Get, Param, Patch, UseGuards } from '@nestjs/common';
import { AuthUser } from '../auth/auth-user';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { DevAuthGuard } from '../auth/guards/dev-auth.guard';
import { ChoresService } from './chores.service';
import { UpdateChoreLayoutDto } from './dto/update-chore-layout.dto';

@UseGuards(DevAuthGuard)
@Controller('families/:familyId/chore-layout')
export class ChoreLayoutController {
  constructor(private readonly choresService: ChoresService) {}

  @Get()
  getLayout(@CurrentUser() user: AuthUser, @Param('familyId') familyId: string) {
    return this.choresService.getChoreLayout(user, familyId);
  }

  @Patch()
  updateLayout(
    @CurrentUser() user: AuthUser,
    @Param('familyId') familyId: string,
    @Body() dto: UpdateChoreLayoutDto,
  ) {
    return this.choresService.updateChoreLayout(user, familyId, dto);
  }
}
