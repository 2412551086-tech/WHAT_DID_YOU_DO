import { IsString, Matches } from 'class-validator';

export class UpdateMemberAppearanceDto {
  @IsString()
  @Matches(/^avatar_(0[1-9]|1[0-3]|v2_(recycler|chef|trainer|dad))$/, {
    message: 'avatarKey must be an existing avatar or achievement character',
  })
  avatarKey!: string;
}
