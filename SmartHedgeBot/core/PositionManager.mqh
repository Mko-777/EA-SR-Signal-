#ifndef __SMART_HEDGE_BOT_POSITION_MANAGER_MQH__
#define __SMART_HEDGE_BOT_POSITION_MANAGER_MQH__

double G1_total_pnl = 0.0;
int    G2_buy_count = 0;
int    G3_sell_count = 0;
double G4_imbalance_percent = 0.0;
double G5_oldest_order_age_hours = 0.0;
double G6_worst_loss = 0.0;
double G7_drawdown_percent = 0.0;
double G8_total_swap = 0.0;

int GetPositionCount(ENUM_POSITION_TYPE type)
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetTicket(i) == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != MAGIC_NUMBER) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == type)
         count++;
   }
   return count;
}

double GetTotalPnL()
{
   return G1_total_pnl;
}

double GetImbalancePercent()
{
   return G4_imbalance_percent;
}

double GetOldestOrderAge()
{
   return G5_oldest_order_age_hours;
}

double GetTotalDrawdownPercent()
{
   return G7_drawdown_percent;
}

double GetTotalSwap()
{
   return G8_total_swap;
}

ulong GetWorstPositionTicket()
{
   ulong worst_ticket = 0;
   double worst_profit = 0.0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != MAGIC_NUMBER) continue;

      double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(worst_ticket == 0 || profit < worst_profit)
      {
         worst_ticket = ticket;
         worst_profit = profit;
      }
   }

   return worst_ticket;
}

void UpdatePositionData()
{
   G1_total_pnl = 0.0;
   G2_buy_count = 0;
   G3_sell_count = 0;
   G4_imbalance_percent = 0.0;
   G5_oldest_order_age_hours = 0.0;
   G6_worst_loss = 0.0;
   G7_drawdown_percent = 0.0;
   G8_total_swap = 0.0;

   datetime now = TimeCurrent();

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != MAGIC_NUMBER) continue;

      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY) G2_buy_count++;
      if(type == POSITION_TYPE_SELL) G3_sell_count++;

      double profit = PositionGetDouble(POSITION_PROFIT);
      double swap = PositionGetDouble(POSITION_SWAP);
      G1_total_pnl += (profit + swap);
      G8_total_swap += swap;

      if(i == 0 || profit < G6_worst_loss)
         G6_worst_loss = profit;

      datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      double age_hours = (double)(now - open_time) / 3600.0;
      if(age_hours > G5_oldest_order_age_hours)
         G5_oldest_order_age_hours = age_hours;
   }

   int total_positions = G2_buy_count + G3_sell_count;
   if(total_positions > 0)
      G4_imbalance_percent = (double)MathMax(G2_buy_count, G3_sell_count) / total_positions * 100.0;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(balance > 0.0)
      G7_drawdown_percent = MathMax((balance - equity) / balance * 100.0, 0.0);
}

ulong GetClosePriorityTicket()
{
   int trend = GetTrendDirection();
   ulong best_ticket = 0;
   int best_score = -1;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != MAGIC_NUMBER) continue;

      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double profit = PositionGetDouble(POSITION_PROFIT);
      double swap = MathAbs(PositionGetDouble(POSITION_SWAP));
      datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      double age_hours = (double)(TimeCurrent() - open_time) / 3600.0;

      int score = 0;
      if(age_hours > 24.0) score += 3;

      bool against_trend = (trend > 0 && type == POSITION_TYPE_SELL) || (trend < 0 && type == POSITION_TYPE_BUY);
      if(against_trend) score += 3;

      if(G6_worst_loss < 0.0 && profit <= (G6_worst_loss / 2.0)) score += 2;
      if(swap > MAX_SWAP_PER_ORDER) score += 1;

      if(score > best_score)
      {
         best_score = score;
         best_ticket = ticket;
      }
   }

   return best_ticket;
}

#endif
