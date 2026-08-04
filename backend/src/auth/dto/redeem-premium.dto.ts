import { IsString, Length } from 'class-validator';

export class RedeemPremiumDto {
  @IsString()
  @Length(6, 32)
  code!: string;
}
