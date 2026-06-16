import { IsBooleanString, IsOptional } from 'class-validator';

export class ListChoresDto {
  @IsOptional()
  @IsBooleanString()
  includePremium?: string;
}
