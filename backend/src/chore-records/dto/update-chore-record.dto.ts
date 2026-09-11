import { Type } from 'class-transformer';
import { IsInt, IsNumber, IsOptional, Max, Min } from 'class-validator';

export class UpdateChoreRecordDto {
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(180)
  actualMinutes!: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 1 })
  @Min(0.5)
  @Max(2)
  pointsMultiplier?: number;
}
