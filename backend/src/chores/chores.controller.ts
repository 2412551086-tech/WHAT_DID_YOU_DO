import { Controller, Get, Query } from '@nestjs/common';
import { ListChoresDto } from './dto/list-chores.dto';
import { ChoresService } from './chores.service';

@Controller('chores')
export class ChoresController {
  constructor(private readonly choresService: ChoresService) {}

  @Get()
  listChores(@Query() _query: ListChoresDto) {
    return this.choresService.listChores();
  }
}
