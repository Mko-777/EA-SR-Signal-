#ifndef __SMART_HEDGE_BOT_ORDER_CLOSE_MQH__
#define __SMART_HEDGE_BOT_ORDER_CLOSE_MQH__

bool ClosePositionByTicket(ulong ticket)
{
   if(ticket == 0)
      return false;

   if(trade.PositionClose(ticket))
   {
      if(SHOW_DEBUG_LOGS) Print("Closed position #", ticket);
      return true;
   }

   if(SHOW_DEBUG_LOGS) Print("Failed to close #", ticket, " retcode=", trade.ResultRetcode());
   return false;
}

void CloseWorstPosition()
{
   ulong ticket = GetClosePriorityTicket();
   if(ticket > 0)
      ClosePositionByTicket(ticket);
}

void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != MAGIC_NUMBER) continue;
      ClosePositionByTicket(ticket);
   }
}

#endif
