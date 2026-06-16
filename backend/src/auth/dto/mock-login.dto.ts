import { IsString, MinLength } from 'class-validator';

export class MockLoginDto {
  @IsString()
  @MinLength(1)
  displayName!: string;
}
