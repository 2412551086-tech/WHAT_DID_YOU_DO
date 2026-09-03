import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsDateString,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';

export class LocalDraftChoreDto {
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  localId!: string;

  @IsIn(['CATALOG', 'CUSTOM'])
  source!: 'CATALOG' | 'CUSTOM';

  @IsOptional()
  @IsString()
  @MaxLength(100)
  catalogKey?: string;

  @IsString()
  @MinLength(1)
  @MaxLength(20)
  name!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(30)
  category!: string;

  @IsInt()
  @Min(1)
  @Max(180)
  standardMinutes!: number;

  @IsNumber()
  @Min(0.5)
  @Max(2)
  difficultyMultiplier!: number;

  @IsString()
  @MinLength(1)
  @MaxLength(100)
  icon!: string;
}

export class LocalDraftRecordDto {
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  id!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(100)
  choreLocalId!: string;

  @IsInt()
  @Min(1)
  @Max(180)
  actualMinutes!: number;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  note?: string;

  @IsDateString()
  occurredAt!: string;
}

export class ClaimLocalDraftDto {
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  draftId!: string;

  @IsDateString()
  draftCreatedAt!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(30)
  familyName!: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(30)
  identityLabel?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  avatarKey?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  timezone?: string;

  @IsArray()
  @ArrayMaxSize(6)
  @ValidateNested({ each: true })
  @Type(() => LocalDraftChoreDto)
  chores!: LocalDraftChoreDto[];

  @IsArray()
  @ArrayMaxSize(5000)
  @ValidateNested({ each: true })
  @Type(() => LocalDraftRecordDto)
  records!: LocalDraftRecordDto[];
}
