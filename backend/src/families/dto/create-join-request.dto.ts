import { IsOptional, IsString, MaxLength, MinLength, ValidateIf } from 'class-validator';

export class CreateJoinRequestDto {
  @IsString()
  @MinLength(1)
  @MaxLength(30)
  identityLabel!: string;

  @ValidateIf((dto: CreateJoinRequestDto) => dto.identityLabel === '自定义' || dto.customIdentity !== undefined)
  @IsString()
  @MinLength(1)
  @MaxLength(30)
  customIdentity?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  avatarKey?: string;
}
