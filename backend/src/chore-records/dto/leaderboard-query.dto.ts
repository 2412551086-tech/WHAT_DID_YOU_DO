import { IsIn, IsOptional } from 'class-validator';

export class LeaderboardQueryDto {
  @IsOptional()
  @IsIn(['day', 'week', 'month'])
  range?: 'day' | 'week' | 'month';
}
