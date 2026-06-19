import { IsIn } from 'class-validator';

export class ReviewJoinRequestDto {
  @IsIn(['approve', 'reject'])
  action!: 'approve' | 'reject';
}
