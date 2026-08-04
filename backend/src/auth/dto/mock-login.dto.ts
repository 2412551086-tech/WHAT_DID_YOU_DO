import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class MockLoginDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(30)
  displayName?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  phoneNumber?: string;
}
