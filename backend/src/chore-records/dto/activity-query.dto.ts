import { IsIn, IsOptional } from 'class-validator';

export class ActivityQueryDto {
  @IsOptional()
  @IsIn(['day', 'recent'])
  range?: 'day' | 'recent';
}
