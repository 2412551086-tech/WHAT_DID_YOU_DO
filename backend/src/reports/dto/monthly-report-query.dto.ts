import { Matches } from 'class-validator';

export class MonthlyReportQueryDto {
  @Matches(/^\d{4}-\d{2}$/)
  month!: string;
}
