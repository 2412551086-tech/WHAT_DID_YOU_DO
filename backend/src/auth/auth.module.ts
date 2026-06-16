import { Module } from '@nestjs/common';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { DevAuthGuard } from './guards/dev-auth.guard';

@Module({
  controllers: [AuthController],
  providers: [AuthService, DevAuthGuard],
  exports: [AuthService, DevAuthGuard],
})
export class AuthModule {}
