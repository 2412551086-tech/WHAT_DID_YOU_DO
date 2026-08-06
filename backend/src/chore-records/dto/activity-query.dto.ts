import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, Max, Min } from 'class-validator';

export class ActivityQueryDto {
  @IsOptional()
  @IsIn(['day', 'week', 'recent'])
  range?: 'day' | 'week' | 'recent';

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(-52)
  @Max(0)
  weekOffset?: number;
}
