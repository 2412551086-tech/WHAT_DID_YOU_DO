import { Module } from '@nestjs/common';
import { AuthController } from './auth.controller';
import { AuthIdentityService } from './auth-identity.service';
import { AuthSessionService } from './auth-session.service';
import { AuthService } from './auth.service';
import { DevAuthGuard } from './guards/dev-auth.guard';

@Module({
  controllers: [AuthController],
  providers: [AuthService, AuthIdentityService, AuthSessionService, DevAuthGuard],
  exports: [AuthService, AuthIdentityService, AuthSessionService, DevAuthGuard],
})
export class AuthModule {}
