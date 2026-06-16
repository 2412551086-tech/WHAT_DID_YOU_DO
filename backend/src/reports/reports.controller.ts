import { Controller, Get, Param, Query, UseGuards } from '@nestjs/common';
import { AuthUser } from '../auth/auth-user';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { DevAuthGuard } from '../auth/guards/dev-auth.guard';
import { MonthlyReportQueryDto } from './dto/monthly-report-query.dto';
import { ReportsService } from './reports.service';

@UseGuards(DevAuthGuard)
@Controller('families/:familyId')
export class ReportsController {
  constructor(private readonly reportsService: ReportsService) {}

  @Get('monthly-report')
  getMonthlyReport(
    @CurrentUser() user: AuthUser,
    @Param('familyId') familyId: string,
    @Query() query: MonthlyReportQueryDto,
  ) {
    return this.reportsService.getMonthlyReport(user, familyId, query.month);
  }
}
