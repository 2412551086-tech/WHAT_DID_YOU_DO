import { IsOptional, IsString, MinLength } from 'class-validator';

export class MockLoginDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  displayName?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  phoneNumber?: string;
}
