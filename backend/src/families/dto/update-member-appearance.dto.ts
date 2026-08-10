import { IsString, Matches } from 'class-validator';

export class UpdateMemberAppearanceDto {
  @IsString()
  @Matches(/^avatar_(0[1-9]|1[0-3])$/, {
    message: 'avatarKey must be one of avatar_01 through avatar_13',
  })
  avatarKey!: string;
}
