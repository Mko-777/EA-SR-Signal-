#property strict
#property version   "1.00"
#property description "Smart Hedge Bot"

#include <Trade/Trade.mqh>
CTrade trade;

#include "inputs/Settings.mqh"
#include "core/MarketAnalyzer.mqh"
#include "core/PositionManager.mqh"
#include "core/DangerScore.mqh"
#include "logic/OrderClose.mqh"
#include "logic/OrderOpen.mqh"
#include "filters/SwapFilter.mqh"
#include "filters/NewsFilter.mqh"
#include "logic/SituationHandler.mqh"

int OnInit()
{
   trade.SetExpertMagicNumber(MAGIC_NUMBER);
   trade.SetDeviationInPoints(20);
   return INIT_SUCCEEDED;
}

void DisplayDashboard(double score)
{
   string status = "НОРМА";
   if(score >= SCORE_EMERGENCY) status = "АВАРИЯ";
   else if(score >= SCORE_CRITICAL) status = "ОЧЕНЬ ОПАСНО";
   else if(score >= SCORE_DANGER) status = "ОПАСНО";
   else if(score >= SCORE_CAUTION) status = "ОСТОРОЖНО";

   int bar_fill = (int)MathRound(score / 10.0);
   bar_fill = (int)MathMax(0, MathMin(10, bar_fill));
   string bar = "";
   for(int i = 0; i < 10; i++)
      bar += (i < bar_fill ? "█" : "░");

   string trend_text = "НЕОПР";
   int trend = GetTrendDirection();
   if(trend > 0) trend_text = "ВВЕРХ ↑";
   if(trend < 0) trend_text = "ВНИЗ ↓";

   string cmt = "╔══════════════════════════════════╗\n";
   cmt += "║     SMART HEDGE BOT              ║\n";
   cmt += "╠══════════════════════════════════╣\n";
   cmt += StringFormat("║ Danger Score:  [%s] %2.0f   ║\n", bar, score);
   cmt += StringFormat("║ Статус:        %-16s║\n", status);
   cmt += "╠══════════════════════════════════╣\n";
   cmt += StringFormat("║ Позиции Buy:   %-18d║\n", G2_buy_count);
   cmt += StringFormat("║ Позиции Sell:  %-18d║\n", G3_sell_count);
   cmt += StringFormat("║ Перекос:       %-17.0f%%║\n", G4_imbalance_percent);
   cmt += StringFormat("║ Общий P&L:     %-17.2f║\n", G1_total_pnl);
   cmt += StringFormat("║ Просадка:      %-17.2f%%║\n", G7_drawdown_percent);
   cmt += "╠══════════════════════════════════╣\n";
   cmt += StringFormat("║ Тренд H4:      %-16s║\n", trend_text);
   cmt += StringFormat("║ ATR Ratio:     %-18.2f║\n", GetATRRatio());
   cmt += StringFormat("║ Восстановление: %-15s║\n", IsRecoveryLikely() ? "ВЕРОЯТНО" : "СЛАБОЕ");
   cmt += "╠══════════════════════════════════╣\n";
   cmt += StringFormat("║ Новые ордера:  %-16s║\n", IsNewOrderAllowed() ? "РАЗРЕШЕНЫ" : "ЗАПРЕЩЕНЫ");
   cmt += "╚══════════════════════════════════╝";

   Comment(cmt);
}

void OnTick()
{
   UpdateMarketData();
   UpdatePositionData();

   double score = CalculateDangerScore();
   HandleSituation(score);

   if(USE_SWAP_FILTER)
      CheckSwapFilter();

   if(IsNewOrderAllowed())
   {
      int signal = GetEntrySignal();
      if(signal != 0 && CheckAllConditions())
         OpenOrder(signal);
   }

   DisplayDashboard(score);
}
