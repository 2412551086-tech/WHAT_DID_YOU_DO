import { IsIn, IsOptional } from 'class-validator';

export class LeaderboardQueryDto {
  @IsOptional()
  @IsIn(['day', 'month'])
  range?: 'day' | 'month';
}
