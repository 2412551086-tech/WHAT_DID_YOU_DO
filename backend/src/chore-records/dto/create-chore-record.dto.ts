import { Type } from 'class-transformer';
import { IsArray, IsInt, IsOptional, IsString, Max, Min, MinLength } from 'class-validator';

export class CreateChoreRecordDto {
  @IsString()
  @MinLength(1)
  familyId!: string;

  @IsString()
  @MinLength(1)
  choreId!: string;

  @IsOptional()
  @IsString()
  note?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(180)
  actualMinutes?: number;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  imageUrls?: string[];
}
