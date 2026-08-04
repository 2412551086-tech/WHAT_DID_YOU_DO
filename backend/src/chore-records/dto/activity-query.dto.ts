import { IsIn, IsOptional } from 'class-validator';

export class ActivityQueryDto {
  @IsOptional()
  @IsIn(['day', 'week', 'recent'])
  range?: 'day' | 'week' | 'recent';
}
