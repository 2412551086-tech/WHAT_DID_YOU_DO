import { IsIn, IsInt, IsNumber, IsOptional, IsString, Max, MaxLength, Min, MinLength } from 'class-validator';
import { choreCategories, ChoreCategory } from '../chore-categories';
import { customChoreIconKeys } from './create-custom-chore.dto';

export class UpdateCustomChoreDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(5)
  name?: string;

  @IsOptional()
  @IsString()
  @IsIn(customChoreIconKeys)
  iconKey?: (typeof customChoreIconKeys)[number];

  @IsOptional()
  @IsString()
  @IsIn(choreCategories)
  category?: ChoreCategory;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(180)
  standardMinutes?: number;

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 1 })
  @Min(0.5)
  @Max(2)
  difficultyMultiplier?: number;
}
