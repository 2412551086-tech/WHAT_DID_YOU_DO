import { IsString, IsUUID, MaxLength, MinLength } from 'class-validator';
import { SessionDeviceDto } from './session-device.dto';

export class AppleLoginDto extends SessionDeviceDto {
  @IsUUID()
  challengeId!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(16384)
  identityToken!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(4096)
  authorizationCode!: string;
}
