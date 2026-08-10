import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { AuthUser } from '../auth/auth-user';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { DevAuthGuard } from '../auth/guards/dev-auth.guard';
import { ChoresService } from './chores.service';
import { CreateCustomChoreDto } from './dto/create-custom-chore.dto';
import { UpdateCustomChoreDto } from './dto/update-custom-chore.dto';

@UseGuards(DevAuthGuard)
@Controller('families/:familyId/custom-chores')
export class CustomChoresController {
  constructor(private readonly choresService: ChoresService) {}

  @Get()
  list(
    @CurrentUser() user: AuthUser,
    @Param('familyId') familyId: string,
  ) {
    return this.choresService.listCustomChores(user, familyId);
  }

  @Post()
  create(
    @CurrentUser() user: AuthUser,
    @Param('familyId') familyId: string,
    @Body() dto: CreateCustomChoreDto,
  ) {
    return this.choresService.createCustomChore(user, familyId, dto);
  }

  @Patch(':choreId')
  update(
    @CurrentUser() user: AuthUser,
    @Param('familyId') familyId: string,
    @Param('choreId') choreId: string,
    @Body() dto: UpdateCustomChoreDto,
  ) {
    return this.choresService.updateCustomChore(user, familyId, choreId, dto);
  }

  @Delete(':choreId')
  archive(
    @CurrentUser() user: AuthUser,
    @Param('familyId') familyId: string,
    @Param('choreId') choreId: string,
  ) {
    return this.choresService.archiveCustomChore(user, familyId, choreId);
  }
}
