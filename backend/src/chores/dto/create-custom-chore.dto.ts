import { IsIn, IsInt, IsNumber, IsString, Max, MaxLength, Min, MinLength } from 'class-validator';
import { choreCategories, ChoreCategory } from '../chore-categories';

export const customChoreIconKeys = [
  'chore_custom_generic_01',
  'chore_custom_generic_02',
  'chore_custom_generic_03',
  'chore_custom_generic_04',
  // Legacy keys remain valid so existing custom chores can still be edited.
  'chore_custom_dust',
  'chore_custom_window',
  'chore_custom_bed',
  'chore_custom_plant',
  'chore_custom_pet',
  'chore_custom_car',
  'chore_custom_fridge',
  'chore_custom_repair',
  'chore_custom_childcare',
  'chore_custom_admin',
] as const;

export class CreateCustomChoreDto {
  @IsString()
  @MinLength(1)
  @MaxLength(5)
  name!: string;

  @IsString()
  @IsIn(customChoreIconKeys)
  iconKey!: (typeof customChoreIconKeys)[number];

  @IsString()
  @IsIn(choreCategories)
  category!: ChoreCategory;

  @IsInt()
  @Min(1)
  @Max(180)
  standardMinutes!: number;

  @IsNumber({ maxDecimalPlaces: 1 })
  @Min(0.5)
  @Max(2)
  difficultyMultiplier!: number;
}
