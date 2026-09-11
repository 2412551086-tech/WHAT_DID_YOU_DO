import { Controller, Get, HttpCode, Param, Post, UseGuards } from '@nestjs/common';
import { AuthUser } from '../auth/auth-user';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { DevAuthGuard } from '../auth/guards/dev-auth.guard';
import { AchievementCharactersService } from './achievement-characters.service';

@Controller('users/me/achievement-characters')
@UseGuards(DevAuthGuard)
export class AchievementCharactersController {
  constructor(private readonly characters: AchievementCharactersService) {}

  @Get()
  list(@CurrentUser() user: AuthUser) { return this.characters.list(user.id); }

  @Post(':key/claim')
  @HttpCode(200)
  claim(@CurrentUser() user: AuthUser, @Param('key') key: string) { return this.characters.claim(user.id, key); }
}
