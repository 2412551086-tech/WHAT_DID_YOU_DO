import { Body, Controller, Get, Patch, Post, UseGuards } from '@nestjs/common';
import { CurrentUser } from './decorators/current-user.decorator';
import { DevAuthGuard } from './guards/dev-auth.guard';
import { AuthUser } from './auth-user';
import { AuthService } from './auth.service';
import { MockLoginDto } from './dto/mock-login.dto';
import { RedeemPremiumDto } from './dto/redeem-premium.dto';
import { UpdateCurrentUserDto } from './dto/update-current-user.dto';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('mock-login')
  mockLogin(@Body() dto: MockLoginDto) {
    return this.authService.mockLogin(dto);
  }

  @UseGuards(DevAuthGuard)
  @Get('me')
  getCurrentUser(@CurrentUser() user: AuthUser) {
    return this.authService.getCurrentUser(user);
  }

  @UseGuards(DevAuthGuard)
  @Patch('me')
  updateCurrentUser(
    @CurrentUser() user: AuthUser,
    @Body() dto: UpdateCurrentUserDto,
  ) {
    return this.authService.updateCurrentUser(user, dto);
  }

  @UseGuards(DevAuthGuard)
  @Post('redeem-premium')
  redeemPremium(@CurrentUser() user: AuthUser, @Body() dto: RedeemPremiumDto) {
    return this.authService.redeemPremium(user, dto);
  }
}
