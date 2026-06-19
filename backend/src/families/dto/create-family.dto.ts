import { IsBoolean, IsOptional, IsString, MaxLength, MinLength, ValidateIf } from 'class-validator';

export class CreateFamilyDto {
  @IsString()
  @MinLength(1)
  name!: string;

  @IsOptional()
  @IsBoolean()
  requirePhotoProof?: boolean;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(30)
  identityLabel?: string;

  @ValidateIf((dto: CreateFamilyDto) => dto.identityLabel === '自定义' || dto.customIdentity !== undefined)
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
