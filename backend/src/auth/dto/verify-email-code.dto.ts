import {
  IsEmail,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';
import { SessionDeviceDto } from './session-device.dto';

export class VerifyEmailCodeDto extends SessionDeviceDto {
  @IsString()
  @IsEmail()
  @MaxLength(254)
  email!: string;

  @IsUUID()
  challengeId!: string;

  @IsString()
  @Matches(/^\d{6}$/)
  code!: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(30)
  displayName?: string;
}
