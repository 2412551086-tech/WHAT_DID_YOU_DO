import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, Max, Min } from 'class-validator';

export class LeaderboardQueryDto {
  @IsOptional()
  @IsIn(['day', 'week', 'month'])
  range?: 'day' | 'week' | 'month';

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(-52)
  @Max(0)
  weekOffset?: number;
}
