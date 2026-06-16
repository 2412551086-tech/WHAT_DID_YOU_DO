import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { DevAuthGuard } from '../auth/guards/dev-auth.guard';
import { AuthUser } from '../auth/auth-user';
import { CreateFamilyDto } from './dto/create-family.dto';
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
}
