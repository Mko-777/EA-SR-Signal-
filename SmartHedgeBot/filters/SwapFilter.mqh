#ifndef __SMART_HEDGE_BOT_SWAP_FILTER_MQH__
#define __SMART_HEDGE_BOT_SWAP_FILTER_MQH__

void CheckSwapFilter()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != MAGIC_NUMBER) continue;

      double swap = MathAbs(PositionGetDouble(POSITION_SWAP));
      datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      double age_hours = (double)(TimeCurrent() - open_time) / 3600.0;
      double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);

      if(age_hours > MAX_ORDER_AGE_HOURS && swap > MAX_SWAP_PER_ORDER && profit >= 0.0)
         ClosePositionByTicket(ticket);
   }
}

#endif
