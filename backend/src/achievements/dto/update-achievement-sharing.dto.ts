import { IsBoolean } from 'class-validator';

export class UpdateAchievementSharingDto {
  @IsBoolean()
  showToFamily!: boolean;
}
