import { IsString, MaxLength, MinLength } from 'class-validator';

export class UpdateCurrentUserDto {
  @IsString()
  @MinLength(1)
  @MaxLength(30)
  displayName!: string;
}
