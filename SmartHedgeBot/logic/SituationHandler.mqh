#ifndef __SMART_HEDGE_BOT_SITUATION_HANDLER_MQH__
#define __SMART_HEDGE_BOT_SITUATION_HANDLER_MQH__

bool g_new_orders_allowed = true;
datetime g_pause_until = 0;

void AllowNewOrders(bool allowed)
{
   g_new_orders_allowed = allowed;
}

bool IsNewOrderAllowed()
{
   if(TimeCurrent() < g_pause_until)
      return false;
   return g_new_orders_allowed;
}

void SetPause(int minutes)
{
   g_pause_until = TimeCurrent() + minutes * 60;
}

void HandleSituation(double danger_score)
{
   if(danger_score < SCORE_CAUTION)
   {
      AllowNewOrders(true);
   }
   else if(danger_score < SCORE_DANGER)
   {
      AllowNewOrders(false);
   }
   else if(danger_score < SCORE_CRITICAL)
   {
      AllowNewOrders(false);
      CloseWorstPosition();
      OpenCompensatingOrder();
   }
   else if(danger_score < SCORE_EMERGENCY)
   {
      AllowNewOrders(false);
      if(GetTotalPnL() >= 0.0)
         CloseAllPositions();
   }
   else
   {
      AllowNewOrders(false);
      CloseAllPositions();
      SetPause(120);
   }
}

#endif
