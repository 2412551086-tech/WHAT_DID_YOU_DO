import { ArrayMinSize, ArrayUnique, IsArray, IsBoolean, IsOptional, IsString } from 'class-validator';

export class UpdateChoreLayoutDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayUnique()
  @IsString({ each: true })
  choreIds!: string[];

  @IsArray()
  @ArrayUnique()
  @IsString({ each: true })
  pinnedChoreIds!: string[];

  @IsOptional()
  @IsBoolean()
  followFamilyLayout?: boolean;
}
