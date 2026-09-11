import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';
import { SessionDeviceDto } from './session-device.dto';

export class MockLoginDto extends SessionDeviceDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(30)
  displayName?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  devIdentifier?: string;
}
