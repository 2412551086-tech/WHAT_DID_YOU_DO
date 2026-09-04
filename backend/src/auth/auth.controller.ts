import { Body, Controller, Delete, Get, Patch, Post, UseGuards } from '@nestjs/common';
import { CurrentUser } from './decorators/current-user.decorator';
import { DevAuthGuard } from './guards/dev-auth.guard';
import { AuthUser } from './auth-user';
import { AuthService } from './auth.service';
import { MockLoginDto } from './dto/mock-login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { RedeemPremiumDto } from './dto/redeem-premium.dto';
import { SendEmailCodeDto } from './dto/send-email-code.dto';
import { UpdateCurrentUserDto } from './dto/update-current-user.dto';
import { VerifyEmailCodeDto } from './dto/verify-email-code.dto';
import { EmailOtpService } from './email-otp.service';

@Controller('auth')
export class AuthController {
  constructor(
    private readonly authService: AuthService,
    private readonly emailOtp: EmailOtpService,
  ) {}

  @Get('config')
  getPublicConfiguration() {
    return this.authService.getPublicConfiguration();
  }

  @Post('mock-login')
  mockLogin(@Body() dto: MockLoginDto) {
    return this.authService.mockLogin(dto);
  }

  @Post('email/send-code')
  sendEmailCode(@Body() dto: SendEmailCodeDto) {
    return this.emailOtp.sendCode(dto);
  }

  @Post('email/verify-code')
  verifyEmailCode(@Body() dto: VerifyEmailCodeDto) {
    return this.emailOtp.verifyCode(dto);
  }

  @Post('refresh')
  refresh(@Body() dto: RefreshTokenDto) {
    return this.authService.refresh(dto.refreshToken);
  }

  @UseGuards(DevAuthGuard)
  @Post('logout')
  logout(@CurrentUser() user: AuthUser) {
    return this.authService.logout(user);
  }

  @UseGuards(DevAuthGuard)
  @Post('logout-all')
  logoutAll(@CurrentUser() user: AuthUser) {
    return this.authService.logoutAll(user);
  }

  @UseGuards(DevAuthGuard)
  @Get('sessions')
  listSessions(@CurrentUser() user: AuthUser) {
    return this.authService.listSessions(user);
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

  @UseGuards(DevAuthGuard)
  @Delete('me')
  deleteCurrentUser(@CurrentUser() user: AuthUser) {
    return this.authService.deleteCurrentUser(user);
  }
}
