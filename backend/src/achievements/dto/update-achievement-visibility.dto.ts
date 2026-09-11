import { AchievementVisibility } from '@prisma/client';
import { IsEnum } from 'class-validator';

export class UpdateAchievementVisibilityDto {
  @IsEnum(AchievementVisibility)
  visibility!: AchievementVisibility;
}
