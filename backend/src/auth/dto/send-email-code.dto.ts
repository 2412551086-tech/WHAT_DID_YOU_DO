import { IsEmail, IsString, MaxLength } from 'class-validator';

export class SendEmailCodeDto {
  @IsString()
  @IsEmail()
  @MaxLength(254)
  email!: string;
}
