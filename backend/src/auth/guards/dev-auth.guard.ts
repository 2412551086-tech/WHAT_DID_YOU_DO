import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { AuthUser } from '../auth-user';
import { AuthService } from '../auth.service';

interface AuthenticatedRequest {
  headers: {
    authorization?: string;
  };
  user?: AuthUser;
}

@Injectable()
export class DevAuthGuard implements CanActivate {
  constructor(private readonly authService: AuthService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const authorization = request.headers.authorization;

    if (!authorization?.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing bearer token');
    }

    request.user = await this.authService.verifyBearerToken(authorization.slice('Bearer '.length));

    return true;
  }
}
