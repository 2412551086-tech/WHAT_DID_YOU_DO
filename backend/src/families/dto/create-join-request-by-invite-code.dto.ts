import { IsString, MaxLength, MinLength } from 'class-validator';
import { CreateJoinRequestDto } from './create-join-request.dto';

export class CreateJoinRequestByInviteCodeDto extends CreateJoinRequestDto {
  @IsString()
  @MinLength(1)
  @MaxLength(32)
  inviteCode!: string;
}
