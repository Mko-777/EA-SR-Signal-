//+------------------------------------------------------------------+
//|       EA S-R Signal v4 - SmartTP + SmartLot + TrailingStop      |
//|              + DangerScore + SwapFilter + NewsFilter             |
//|                     Copyright 2024, MetaQuotes Ltd.             |
//|                          https://www.mql5.com                   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "4.00"

#include <Trade\Trade.mqh>
CTrade trade;

//+------------------------------------------------------------------+
//| Настройки индикатора S-R Signal v1                               |
//+------------------------------------------------------------------+
input group "=== S-R Signal v1 Settings ==="
input int Zone1Length = 100;        // Zone 1 Length (Trend)
input int Zone2Length = 60;         // Zone 2 Length (Impulse)
input int Zone3Length = 20;         // Zone 3 Length (Signal)
input bool EnableHTFTrendFilter = true;    // Enable HTF Trend Direction Filter
input ENUM_TIMEFRAMES HTFTimeframe = PERIOD_H1;  // HTF Trend Timeframe

//+------------------------------------------------------------------+
//| Stochastic Filter Settings                                       |
//+------------------------------------------------------------------+
input group "=== Stochastic Filter ==="
input bool EnableStochasticFilter = true;
input int Stochastic_Kperiod = 5;
input int Stochastic_Dperiod = 3;
input int Stochastic_Slowing = 3;
input ENUM_MA_METHOD Stochastic_Method = MODE_SMA;
input ENUM_STO_PRICE Stochastic_Price = STO_LOWHIGH;
input double Stochastic_UpperLevel = 70.0;
input double Stochastic_LowerLevel = 30.0;
input bool Stochastic_UseMainLine = true;
input bool Stochastic_UseSignalLine = false;
input bool Stochastic_CrossoverSignals = false;
input bool ShowStochasticDebug = true;

//+------------------------------------------------------------------+
//| FIXED MULTIPLE GRIDS                                             |
//+------------------------------------------------------------------+
input group "=== FIXED MULTIPLE GRIDS ==="
input bool EnableGrid = true;
input int GridStepPips = 50;
input double GridLotSize = 0.01;
input bool ShowGridDebug = true;

//+------------------------------------------------------------------+
//| Trade Settings                                                   |
//+------------------------------------------------------------------+
input group "=== Trade Settings ==="
input double LotSize = 0.01;
input int StopLoss = 50;

//+------------------------------------------------------------------+
//| Volume Increase with Lot Limit                                  |
//+------------------------------------------------------------------+
input group "=== Volume Increase with Lot Limit ==="
input bool EnableVolumeIncrease = true;
input double VolumeMultiplier = 2.0;
input int MaxSignalCount = 5;
input double MaxLotSize = 0.1;
input bool ResetOnNewDay = true;
input bool ShowVolumeDebug = true;

//+------------------------------------------------------------------+
//| Take Profit with Grid Deactivation Only                         |
//+------------------------------------------------------------------+
input group "=== Take Profit with Grid Deactivation Only ==="
input bool   EnableSimpleTP = true;
input double TargetProfit   = 50.0;
input bool   ShowDebugInfo  = false;

//+------------------------------------------------------------------+
//| === Smart Take Profit (SmartTP) ===                              |
//+------------------------------------------------------------------+
input group "=== Smart Take Profit (SmartTP) ==="
input bool   EnableSmartTP     = true;    // true=SmartTP, false=SimpleTP
input double SmartTP_Threshold = 50.0;   // Threshold $ for opposite positions profit
input bool   ShowSmartTPDebug  = true;   // Show SmartTP debug info

//+------------------------------------------------------------------+
//| Smart Lot Calculator (Risk-Based)                                |
//+------------------------------------------------------------------+
input group "=== Smart Lot Calculator ==="
input bool   EnableSmartLot  = true;    // Use risk-based lot instead of fixed
input double RiskPercent     = 1.0;     // Risk per trade % of balance
input int    MaxPositionsSide = 3;      // Max positions per direction

//+------------------------------------------------------------------+
//| Trailing Stop                                                    |
//+------------------------------------------------------------------+
input group "=== Trailing Stop ==="
input bool   EnableTrailingStop = true;   // Enable trailing stop
input int    TrailingStopPips   = 30;     // Trailing stop distance (pips)
input int    TrailingStepPips   = 10;     // Min step to move SL (pips)
input bool   ShowTrailingDebug  = false;  // Debug log for trailing stop

//+------------------------------------------------------------------+
//| ATR Filter                                                       |
//+------------------------------------------------------------------+
input group "=== ATR Filter ==="
input bool   UseATRFilter    = true;   // Block entries on extreme volatility
input int    ATRPeriod       = 14;     // ATR period
input double ATRMaxRatio     = 2.5;    // Block when current ATR / avg ATR > this

//+------------------------------------------------------------------+
//| Danger Score                                                     |
//+------------------------------------------------------------------+
input group "=== Danger Score ==="
input bool   UseDangerScore     = true;
input double MaxDrawdownPercent = 3.0;   // Max allowed drawdown %
input double WeightDrawdown     = 40.0;
input double WeightImbalance    = 20.0;
input double WeightATR          = 15.0;
input double WeightAge          = 15.0;
input double WeightSwap         = 10.0;
input int    ScoreCaution       = 30;    // Block new orders
input int    ScoreDanger        = 50;    // Close worst + open compensating
input int    ScoreCritical      = 70;    // Close all if P&L >= 0
input int    ScoreEmergency     = 85;    // Close all + pause 2 hrs

//+------------------------------------------------------------------+
//| Swap Filter                                                      |
//+------------------------------------------------------------------+
input group "=== Swap Filter ==="
input bool   UseSwapFilter      = true;
input int    MaxOrderAgeHours   = 48;
input double MaxSwapPerOrder    = 10.0;

//+------------------------------------------------------------------+
//| News Filter                                                      |
//+------------------------------------------------------------------+
input group "=== News Filter ==="
input bool   UseNewsFilter      = true;
input int    NewsPauseBefore    = 30;   // Minutes before news
input int    NewsPauseAfter     = 15;   // Minutes after news

//+------------------------------------------------------------------+
//| System                                                           |
//+------------------------------------------------------------------+
input group "=== System ==="
input bool   ShowDashboard      = true;

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
#define MAGIC 123456

bool prev_buy_setup  = false;
bool prev_sell_setup = false;

int stochastic_handle = INVALID_HANDLE;

int      signal_count    = 0;
datetime last_reset_date = 0;

double effective_max_lot_size;
double grid_step_points;

struct GridInfo
{
   double start_level;
   double current_level;
   bool   is_active;
   int    signal_id;
};

GridInfo buy_grids[100];
GridInfo sell_grids[100];

int  buy_grids_count  = 0;
int  sell_grids_count = 0;
int  next_signal_id   = 1;

double last_opposite_profit = 0.0;

// Position tracking (updated each tick)
double G1_total_pnl            = 0.0;
int    G2_buy_count            = 0;
int    G3_sell_count           = 0;
double G4_imbalance_percent    = 0.0;
double G5_oldest_order_age_hrs = 0.0;
double G6_worst_loss           = 0.0;
double G7_drawdown_percent     = 0.0;
double G8_total_swap           = 0.0;

// ATR tracking
double M5_atr_current = 0.0;
double M6_atr_average = 0.0;
double M7_atr_ratio   = 0.0;

// Danger score flow control
bool     g_new_orders_allowed = true;
datetime g_pause_until        = 0;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("EA SR Signal v4 - SmartTP + SmartLot + TrailingStop initialized!");
   Print("   SmartTP: ", EnableSmartTP ? "ON (Threshold: $" + DoubleToString(SmartTP_Threshold, 2) + ")" : "OFF");
   Print("   SmartLot: ", EnableSmartLot ? "ON (Risk: " + DoubleToString(RiskPercent, 2) + "%)" : "OFF (Fixed: " + DoubleToString(LotSize, 2) + ")");
   Print("   TrailingStop: ", EnableTrailingStop ? "ON (" + IntegerToString(TrailingStopPips) + " pips)" : "OFF");
   Print("   DangerScore: ", UseDangerScore ? "ON" : "OFF");
   Print("   Stochastic: ", EnableStochasticFilter ? "ON" : "OFF");
   Print("   Grid: ", EnableGrid ? "ON (Step: " + IntegerToString(GridStepPips) + " pips)" : "OFF");

   if(EnableGrid)
   {
      grid_step_points = GridStepPips * _Point;
      if(_Digits == 5 || _Digits == 3)
         grid_step_points = GridStepPips * _Point * 10;
   }

   effective_max_lot_size = MaxLotSize;
   if(effective_max_lot_size < LotSize)
   {
      Print("WARNING: MaxLotSize < LotSize! Setting effective MaxLotSize = LotSize");
      effective_max_lot_size = LotSize;
   }

   Print("   HTF Filter: ", EnableHTFTrendFilter ? "ON (" + EnumToString(HTFTimeframe) + ")" : "OFF");

   if(EnableStochasticFilter)
   {
      stochastic_handle = iStochastic(_Symbol, _Period, Stochastic_Kperiod, Stochastic_Dperiod,
                                      Stochastic_Slowing, Stochastic_Method, Stochastic_Price);
      if(stochastic_handle == INVALID_HANDLE)
      {
         Print("Failed to create Stochastic indicator!");
         return(INIT_FAILED);
      }
      Print("Stochastic indicator created. Handle: ", stochastic_handle);
   }

   signal_count         = 0;
   last_reset_date      = TimeCurrent();
   last_opposite_profit = 0.0;

   InitializeFixedMultipleGrids();

   trade.SetExpertMagicNumber(MAGIC);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(stochastic_handle != INVALID_HANDLE)
   {
      IndicatorRelease(stochastic_handle);
      Print("Stochastic indicator released");
   }
   Print("EA SR Signal v4 deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| InitializeFixedMultipleGrids                                     |
//+------------------------------------------------------------------+
void InitializeFixedMultipleGrids()
{
   if(!EnableGrid) return;
   for(int i = 0; i < 100; i++)
   {
      buy_grids[i].start_level   = 0.0;
      buy_grids[i].current_level = 0.0;
      buy_grids[i].is_active     = false;
      buy_grids[i].signal_id     = 0;

      sell_grids[i].start_level   = 0.0;
      sell_grids[i].current_level = 0.0;
      sell_grids[i].is_active     = false;
      sell_grids[i].signal_id     = 0;
   }
   buy_grids_count  = 0;
   sell_grids_count = 0;
   next_signal_id   = 1;
   if(ShowGridDebug) Print("Fixed Multiple Grids System Initialized");
}

//+------------------------------------------------------------------+
//| DeactivateAllGridsAfterTP                                        |
//+------------------------------------------------------------------+
void DeactivateAllGridsAfterTP()
{
   if(!EnableGrid) return;
   int db = 0, ds = 0;
   for(int i = 0; i < 100; i++)
   {
      if(buy_grids[i].is_active)
      {
         buy_grids[i].is_active     = false;
         buy_grids[i].start_level   = 0.0;
         buy_grids[i].current_level = 0.0;
         buy_grids[i].signal_id     = 0;
         db++;
      }
      if(sell_grids[i].is_active)
      {
         sell_grids[i].is_active     = false;
         sell_grids[i].start_level   = 0.0;
         sell_grids[i].current_level = 0.0;
         sell_grids[i].signal_id     = 0;
         ds++;
      }
   }
   buy_grids_count  = 0;
   sell_grids_count = 0;
   Print("ALL GRIDS DEACTIVATED. BUY: ", db, " SELL: ", ds);
}

//+------------------------------------------------------------------+
//| CloseAllPositions                                                |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MAGIC) continue;
      if(trade.PositionClose(ticket))
         Print("Closed position #", ticket);
      else
         Print("Failed to close #", ticket, " Error: ", trade.ResultRetcode());
   }
}

//+------------------------------------------------------------------+
//| UpdatePositionData (SmartCalculator)                             |
//+------------------------------------------------------------------+
void UpdatePositionData()
{
   G1_total_pnl            = 0.0;
   G2_buy_count            = 0;
   G3_sell_count           = 0;
   G4_imbalance_percent    = 0.0;
   G5_oldest_order_age_hrs = 0.0;
   G6_worst_loss           = 0.0;
   G7_drawdown_percent     = 0.0;
   G8_total_swap           = 0.0;

   datetime now = TimeCurrent();

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MAGIC) continue;

      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY)  G2_buy_count++;
      if(type == POSITION_TYPE_SELL) G3_sell_count++;

      double profit = PositionGetDouble(POSITION_PROFIT);
      double swap   = PositionGetDouble(POSITION_SWAP);
      G1_total_pnl  += (profit + swap);
      G8_total_swap += swap;

      if(G6_worst_loss == 0.0 || profit < G6_worst_loss)
         G6_worst_loss = profit;

      double age_hours = (double)(now - (datetime)PositionGetInteger(POSITION_TIME)) / 3600.0;
      if(age_hours > G5_oldest_order_age_hrs)
         G5_oldest_order_age_hrs = age_hours;
   }

   int total_pos = G2_buy_count + G3_sell_count;
   if(total_pos > 0)
      G4_imbalance_percent = (double)MathMax(G2_buy_count, G3_sell_count) / total_pos * 100.0;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   if(balance > 0.0)
      G7_drawdown_percent = MathMax((balance - equity) / balance * 100.0, 0.0);
}

//+------------------------------------------------------------------+
//| UpdateATRData                                                    |
//+------------------------------------------------------------------+
void UpdateATRData()
{
   int handle = iATR(_Symbol, _Period, ATRPeriod);
   if(handle == INVALID_HANDLE) return;

   double buf[];
   ArraySetAsSeries(buf, true);
   int copied = CopyBuffer(handle, 0, 0, ATRPeriod + 1, buf);
   IndicatorRelease(handle);

   if(copied < ATRPeriod + 1) return;

   M5_atr_current = buf[0];
   M6_atr_average = 0.0;
   for(int i = 1; i <= ATRPeriod; i++)
      M6_atr_average += buf[i];
   M6_atr_average /= ATRPeriod;
   M7_atr_ratio = (M6_atr_average > 0.0 ? M5_atr_current / M6_atr_average : 0.0);
}

//+------------------------------------------------------------------+
//| CalculateDangerScore                                             |
//+------------------------------------------------------------------+
double CalculateDangerScore()
{
   if(!UseDangerScore) return 0.0;

   double score = 0.0;

   double dd_norm = MathMin(G7_drawdown_percent / MathMax(MaxDrawdownPercent, 0.0001), 1.0);
   score += dd_norm * WeightDrawdown;

   double imb_norm = G4_imbalance_percent / 100.0;
   score += imb_norm * WeightImbalance;

   double atr_norm = MathMin(M7_atr_ratio / 3.0, 1.0);
   score += atr_norm * WeightATR;

   double age_norm = MathMin(G5_oldest_order_age_hrs / MathMax((double)MaxOrderAgeHours, 1.0), 1.0);
   score += age_norm * WeightAge;

   double swap_norm = MathMin(MathAbs(G8_total_swap) / 50.0, 1.0);
   score += swap_norm * WeightSwap;

   return MathMin(score, 100.0);
}

//+------------------------------------------------------------------+
//| GetWorstPositionTicket                                           |
//+------------------------------------------------------------------+
ulong GetWorstPositionTicket()
{
   ulong  worst_ticket = 0;
   double worst_profit = 0.0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MAGIC) continue;

      double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(worst_ticket == 0 || profit < worst_profit)
      {
         worst_ticket = ticket;
         worst_profit = profit;
      }
   }
   return worst_ticket;
}

//+------------------------------------------------------------------+
//| HandleDangerScore                                                |
//+------------------------------------------------------------------+
void HandleDangerScore(double score)
{
   if(!UseDangerScore) { g_new_orders_allowed = true; return; }

   if(score < ScoreCaution)
   {
      g_new_orders_allowed = true;
   }
   else if(score < ScoreDanger)
   {
      g_new_orders_allowed = false;
      if(ShowDebugInfo) Print("DangerScore CAUTION (", DoubleToString(score, 1), "): new orders blocked");
   }
   else if(score < ScoreCritical)
   {
      g_new_orders_allowed = false;
      Print("DangerScore DANGER (", DoubleToString(score, 1), "): closing worst position");
      ulong wt = GetWorstPositionTicket();
      if(wt > 0) trade.PositionClose(wt);
   }
   else if(score < ScoreEmergency)
   {
      g_new_orders_allowed = false;
      if(G1_total_pnl >= 0.0)
      {
         Print("DangerScore CRITICAL (", DoubleToString(score, 1), "): closing all positions");
         CloseAllPositions();
         if(EnableGrid) DeactivateAllGridsAfterTP();
      }
   }
   else
   {
      g_new_orders_allowed = false;
      Print("DangerScore EMERGENCY (", DoubleToString(score, 1), "): closing all + pause 2h");
      CloseAllPositions();
      if(EnableGrid) DeactivateAllGridsAfterTP();
      g_pause_until = TimeCurrent() + 120 * 60;
   }
}

//+------------------------------------------------------------------+
//| IsNewOrderAllowed                                                |
//+------------------------------------------------------------------+
bool IsNewOrderAllowed()
{
   if(TimeCurrent() < g_pause_until) return false;
   return g_new_orders_allowed;
}

//+------------------------------------------------------------------+
//| IsNewsBlocked                                                    |
//+------------------------------------------------------------------+
bool IsNewsBlocked()
{
   if(!UseNewsFilter) return false;

   MqlCalendarValue values[];
   datetime from_time = TimeCurrent() - (NewsPauseAfter  * 60);
   datetime to_time   = TimeCurrent() + (NewsPauseBefore * 60);

   int total = CalendarValueHistory(values, from_time, to_time, "", "");
   if(total <= 0) return false;

   for(int i = 0; i < total; i++)
   {
      if(values[i].time >= from_time && values[i].time <= to_time)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| CheckSwapFilter                                                  |
//+------------------------------------------------------------------+
void CheckSwapFilter()
{
   if(!UseSwapFilter) return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MAGIC) continue;

      double swap      = MathAbs(PositionGetDouble(POSITION_SWAP));
      double age_hours = (double)(TimeCurrent() - (datetime)PositionGetInteger(POSITION_TIME)) / 3600.0;
      double profit    = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);

      if(age_hours > MaxOrderAgeHours && swap > MaxSwapPerOrder && profit >= 0.0)
      {
         Print("SwapFilter: closing aged position #", ticket,
               " age=", DoubleToString(age_hours, 1), "h swap=", DoubleToString(swap, 2));
         trade.PositionClose(ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| CheckSmartTakeProfit                                             |
//+------------------------------------------------------------------+
void CheckSmartTakeProfit()
{
   if(!EnableSmartTP) return;
   if(PositionsTotal() == 0) return;
   if(!prev_buy_setup && !prev_sell_setup) return;

   ENUM_POSITION_TYPE opposite_type;
   string last_signal_name, opposite_name;

   if(prev_buy_setup && !prev_sell_setup)
   {
      opposite_type    = POSITION_TYPE_SELL;
      last_signal_name = "BUY";
      opposite_name    = "SELL";
   }
   else if(prev_sell_setup && !prev_buy_setup)
   {
      opposite_type    = POSITION_TYPE_BUY;
      last_signal_name = "SELL";
      opposite_name    = "BUY";
   }
   else
   {
      datetime latest_time = 0;
      ENUM_POSITION_TYPE latest_type = POSITION_TYPE_BUY;
      for(int i = 0; i < PositionsTotal(); i++)
      {
         if(PositionGetTicket(i) == 0) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC) != MAGIC) continue;
         datetime pos_time = (datetime)PositionGetInteger(POSITION_TIME);
         if(pos_time > latest_time)
         {
            latest_time = pos_time;
            latest_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         }
      }
      if(latest_type == POSITION_TYPE_BUY)
      { opposite_type = POSITION_TYPE_SELL; last_signal_name = "BUY";  opposite_name = "SELL"; }
      else
      { opposite_type = POSITION_TYPE_BUY;  last_signal_name = "SELL"; opposite_name = "BUY"; }
   }

   double opposite_profit = 0.0;
   int    opposite_count  = 0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetTicket(i) == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MAGIC) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == opposite_type)
      {
         opposite_profit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         opposite_count++;
      }
   }

   last_opposite_profit = opposite_profit;

   if(ShowSmartTPDebug)
   {
      Print("SmartTP | Last: ", last_signal_name, " | Opposite: ", opposite_name,
            " | Count: ", opposite_count,
            " | Profit: $", DoubleToString(opposite_profit, 2),
            " / $", DoubleToString(SmartTP_Threshold, 2));
   }

   if(opposite_count > 0 && opposite_profit >= SmartTP_Threshold)
   {
      Print("SmartTP TRIGGERED! Opposite Profit: $", DoubleToString(opposite_profit, 2));
      CloseAllPositions();
      if(EnableVolumeIncrease) signal_count = 0;
      if(EnableGrid) DeactivateAllGridsAfterTP();
      last_opposite_profit = 0.0;
      Print("SmartTP completed. Waiting for new signal.");
   }
}

//+------------------------------------------------------------------+
//| CheckSimpleTakeProfit                                            |
//+------------------------------------------------------------------+
void CheckSimpleTakeProfit()
{
   if(!EnableSimpleTP) return;
   double total_profit = 0.0;
   int    total_pos    = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetTicket(i) == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      total_profit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      total_pos++;
   }
   if(ShowDebugInfo && total_pos > 0)
      Print("SimpleTP: Pos=", total_pos, " Profit=$", DoubleToString(total_profit, 2),
            " Target=$", DoubleToString(TargetProfit, 2));

   if(total_pos > 0 && total_profit >= TargetProfit)
   {
      Print("SIMPLE TP TRIGGERED! Total Profit: $", DoubleToString(total_profit, 2));
      if(EnableVolumeIncrease) signal_count = 0;
      DeactivateAllGridsAfterTP();
      CloseAllPositions();
      Print("SIMPLE TP COMPLETED!");
   }
}

//+------------------------------------------------------------------+
//| ApplyTrailingStop                                                |
//+------------------------------------------------------------------+
void ApplyTrailingStop()
{
   if(!EnableTrailingStop) return;

   double pip          = ((_Digits == 3 || _Digits == 5) ? _Point * 10.0 : _Point);
   double trail_pts    = TrailingStopPips * pip;
   double step_pts     = TrailingStepPips * pip;
   bool   any_modified = false;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MAGIC) continue;

      ENUM_POSITION_TYPE pos_type   = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double             open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      double             current_sl = PositionGetDouble(POSITION_SL);
      double             current_tp = PositionGetDouble(POSITION_TP);

      if(pos_type == POSITION_TYPE_BUY)
      {
         double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double new_sl = NormalizeDouble(bid - trail_pts, _Digits);

         // Only trail if the new SL is above entry and sufficiently higher than current SL
         bool should_move = (new_sl > open_price) &&
                            (current_sl == 0.0 || new_sl >= current_sl + step_pts);

         if(should_move)
         {
            if(trade.PositionModify(ticket, new_sl, current_tp))
            {
               any_modified = true;
               if(ShowTrailingDebug)
                  Print("TrailingStop BUY #", ticket,
                        " SL: ", DoubleToString(current_sl, _Digits),
                        " -> ", DoubleToString(new_sl, _Digits));
            }
            else if(ShowTrailingDebug)
               Print("TrailingStop BUY #", ticket, " modify failed. Error: ", trade.ResultRetcode());
         }
      }
      else if(pos_type == POSITION_TYPE_SELL)
      {
         double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double new_sl = NormalizeDouble(ask + trail_pts, _Digits);

         // Only trail if the new SL is below entry and sufficiently lower than current SL
         bool should_move = (new_sl < open_price) &&
                            (current_sl == 0.0 || new_sl <= current_sl - step_pts);

         if(should_move)
         {
            if(trade.PositionModify(ticket, new_sl, current_tp))
            {
               any_modified = true;
               if(ShowTrailingDebug)
                  Print("TrailingStop SELL #", ticket,
                        " SL: ", DoubleToString(current_sl, _Digits),
                        " -> ", DoubleToString(new_sl, _Digits));
            }
            else if(ShowTrailingDebug)
               Print("TrailingStop SELL #", ticket, " modify failed. Error: ", trade.ResultRetcode());
         }
      }
   }
   if(any_modified && !ShowTrailingDebug)
      Print("TrailingStop: SL(s) updated");
}

//+------------------------------------------------------------------+
//| NormalizeVolume                                                  |
//+------------------------------------------------------------------+
double NormalizeVolume(double volume)
{
   double min_vol  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_vol  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double vol_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double norm     = MathRound(volume / vol_step) * vol_step;
   if(norm < min_vol) norm = min_vol;
   if(norm > max_vol) norm = max_vol;
   return norm;
}

//+------------------------------------------------------------------+
//| CalculateRiskBasedLot (SmartCalculator)                          |
//+------------------------------------------------------------------+
double CalculateRiskBasedLot(int sl_pips)
{
   if(sl_pips <= 0) return NormalizeVolume(LotSize);

   double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_money = balance * (RiskPercent / 100.0);

   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double pip        = ((_Digits == 3 || _Digits == 5) ? _Point * 10.0 : _Point);

   double pip_value = 0.0;
   if(tick_size > 0.0)
      pip_value = tick_value * (pip / tick_size);

   double lot = LotSize;
   if(pip_value > 0.0)
      lot = risk_money / (sl_pips * pip_value);

   return NormalizeVolume(MathMin(lot, effective_max_lot_size));
}

//+------------------------------------------------------------------+
//| CalculateNextVolume                                              |
//+------------------------------------------------------------------+
double CalculateNextVolume()
{
   if(EnableSmartLot)
      return CalculateRiskBasedLot(StopLoss > 0 ? StopLoss : 50);

   if(!EnableVolumeIncrease) return NormalizeVolume(LotSize);
   signal_count++;
   if(signal_count > MaxSignalCount) signal_count = 1;
   double calc_vol    = LotSize * MathPow(VolumeMultiplier, signal_count - 1);
   double limited_vol = MathMin(calc_vol, effective_max_lot_size);
   double norm_vol    = NormalizeVolume(limited_vol);
   if(ShowVolumeDebug)
      Print("Volume: Signal #", signal_count, " Calc=", DoubleToString(calc_vol, 3),
            " Limited=", DoubleToString(limited_vol, 3), " Final=", DoubleToString(norm_vol, 3));
   return norm_vol;
}

//+------------------------------------------------------------------+
//| CheckResetSignalCounter                                          |
//+------------------------------------------------------------------+
void CheckResetSignalCounter()
{
   if(!EnableVolumeIncrease || !ResetOnNewDay) return;
   datetime    current_time = TimeCurrent();
   MqlDateTime current_dt, last_dt;
   TimeToStruct(current_time, current_dt);
   TimeToStruct(last_reset_date, last_dt);
   if(current_dt.day != last_dt.day)
   {
      signal_count    = 0;
      last_reset_date = current_time;
      if(ShowVolumeDebug) Print("New day - Signal counter reset to 0");
   }
}

//+------------------------------------------------------------------+
//| AnalyzeStochasticDirectional                                     |
//+------------------------------------------------------------------+
bool AnalyzeStochasticDirectional(bool &buy_allowed, bool &sell_allowed)
{
   buy_allowed  = false;
   sell_allowed = false;
   if(!EnableStochasticFilter || stochastic_handle == INVALID_HANDLE)
   { buy_allowed = true; sell_allowed = true; return true; }

   double main_line[], signal_line[];
   ArraySetAsSeries(main_line,   true);
   ArraySetAsSeries(signal_line, true);
   int cm = CopyBuffer(stochastic_handle, 0, 0, 5, main_line);
   int cs = CopyBuffer(stochastic_handle, 1, 0, 5, signal_line);
   if(cm < 3 || cs < 3) { buy_allowed = true; sell_allowed = true; return true; }

   double current_main   = main_line[0];
   double current_signal = signal_line[0];
   double prev_main      = main_line[1];
   double prev_signal    = signal_line[1];

   double control_value = current_main;
   if(!Stochastic_UseMainLine && Stochastic_UseSignalLine)
      control_value = current_signal;
   else if(Stochastic_UseMainLine && Stochastic_UseSignalLine)
      control_value = (current_main + current_signal) / 2.0;

   bool in_upper = control_value >= Stochastic_UpperLevel;
   bool in_lower = control_value <= Stochastic_LowerLevel;

   if(in_upper)      { buy_allowed = false; sell_allowed = true;  }
   else if(in_lower) { buy_allowed = true;  sell_allowed = false; }
   else              { buy_allowed = false; sell_allowed = false; }

   if(Stochastic_CrossoverSignals)
   {
      bool k_above = (prev_main <= prev_signal) && (current_main > current_signal);
      bool k_below = (prev_main >= prev_signal) && (current_main < current_signal);
      if(in_upper && k_below) sell_allowed = true;
      if(in_lower && k_above) buy_allowed  = true;
   }

   if(ShowStochasticDebug)
      Print("Stochastic: %K=", DoubleToString(current_main, 2),
            " Control=", DoubleToString(control_value, 2),
            " BUY=", buy_allowed, " SELL=", sell_allowed);

   return true;
}

//+------------------------------------------------------------------+
//| GetHTFTrendDirection                                             |
//+------------------------------------------------------------------+
bool GetHTFTrendDirection(bool &htf_bullish, bool &htf_bearish)
{
   if(!EnableHTFTrendFilter) { htf_bullish = true; htf_bearish = true; return true; }
   if(PeriodSeconds(_Period) >= PeriodSeconds(HTFTimeframe)) { htf_bullish = true; htf_bearish = true; return true; }

   double htf_high[], htf_low[], htf_close[];
   ArraySetAsSeries(htf_high,  true);
   ArraySetAsSeries(htf_low,   true);
   ArraySetAsSeries(htf_close, true);

   int ch = CopyHigh (_Symbol, HTFTimeframe, 0, Zone1Length + 10, htf_high);
   int cl = CopyLow  (_Symbol, HTFTimeframe, 0, Zone1Length + 10, htf_low);
   int cc = CopyClose(_Symbol, HTFTimeframe, 0, Zone1Length + 10, htf_close);

   if(ch < Zone1Length + 2 || cl < Zone1Length + 2 || cc < Zone1Length + 2)
   { htf_bullish = true; htf_bearish = true; return false; }

   double z1h  = htf_high[ArrayMaximum(htf_high, 0, Zone1Length)];
   double z1l  = htf_low [ArrayMinimum(htf_low,  0, Zone1Length)];
   double z1ph = htf_high[ArrayMaximum(htf_high, 1, Zone1Length)];
   double z1pl = htf_low [ArrayMinimum(htf_low,  1, Zone1Length)];
   double z2h  = htf_high[ArrayMaximum(htf_high, 0, Zone2Length)];
   double z2l  = htf_low [ArrayMinimum(htf_low,  0, Zone2Length)];
   double z2ph = htf_high[ArrayMaximum(htf_high, 1, Zone2Length)];
   double z2pl = htf_low [ArrayMinimum(htf_low,  1, Zone2Length)];

   bool trend_up     = z1h  > z1ph;
   bool trend_down   = z1l  < z1pl;
   bool impulse_up   = z2h  > z2ph;
   bool impulse_down = z2l  < z2pl;

   double mid       = (z1h + z1l) / 2.0;
   bool price_above = htf_close[0] > mid;

   htf_bullish = trend_up   || impulse_up   || price_above;
   htf_bearish = trend_down || impulse_down || !price_above;
   return true;
}

//+------------------------------------------------------------------+
//| GetSignals                                                       |
//+------------------------------------------------------------------+
bool GetSignals(bool &buySignal, bool &sellSignal)
{
   double high[], low[], close[];
   ArraySetAsSeries(high,  true);
   ArraySetAsSeries(low,   true);
   ArraySetAsSeries(close, true);

   int ch = CopyHigh (_Symbol, _Period, 0, Zone1Length + 10, high);
   int cl = CopyLow  (_Symbol, _Period, 0, Zone1Length + 10, low);
   int cc = CopyClose(_Symbol, _Period, 0, Zone1Length + 10, close);
   if(ch <= Zone1Length || cl <= Zone1Length || cc <= Zone1Length) return false;

   double z1h  = high[ArrayMaximum(high, 0, Zone1Length)];
   double z1l  = low [ArrayMinimum(low,  0, Zone1Length)];
   double z1ph = high[ArrayMaximum(high, 1, Zone1Length)];
   double z1pl = low [ArrayMinimum(low,  1, Zone1Length)];
   double z2h  = high[ArrayMaximum(high, 0, Zone2Length)];
   double z2l  = low [ArrayMinimum(low,  0, Zone2Length)];
   double z2ph = high[ArrayMaximum(high, 1, Zone2Length)];
   double z2pl = low [ArrayMinimum(low,  1, Zone2Length)];

   bool trend_up        = z1h > z1ph;
   bool trend_down      = z1l < z1pl;
   bool z2_impulse_up   = z2h > z2ph;
   bool z2_impulse_down = z2l < z2pl;

   bool buy_setup  = trend_up   && z2_impulse_up;
   bool sell_setup = trend_down && z2_impulse_down;

   bool htf_bullish = true, htf_bearish = true;
   GetHTFTrendDirection(htf_bullish, htf_bearish);

   bool stoch_buy = true, stoch_sell = true;
   AnalyzeStochasticDirectional(stoch_buy, stoch_sell);

   bool final_buy  = buy_setup;
   bool final_sell = sell_setup;

   if(EnableHTFTrendFilter)
   {
      if(htf_bullish && !htf_bearish)       final_sell = false;
      else if(htf_bearish && !htf_bullish)  final_buy  = false;
   }
   if(EnableStochasticFilter)
   {
      if(!stoch_buy)  final_buy  = false;
      if(!stoch_sell) final_sell = false;
   }

   // ATR volatility filter
   if(UseATRFilter && M7_atr_ratio > ATRMaxRatio)
   {
      if(ShowDebugInfo)
         Print("ATR Filter: blocking entry. ATR ratio=", DoubleToString(M7_atr_ratio, 2),
               " > max=", DoubleToString(ATRMaxRatio, 2));
      final_buy  = false;
      final_sell = false;
   }

   buySignal  = final_buy  && !prev_buy_setup;
   sellSignal = final_sell && !prev_sell_setup;

   if(ShowDebugInfo && (buySignal || sellSignal))
   {
      Print("SIGNAL: BUY=", buySignal, " SELL=", sellSignal,
            " htf_bull=", htf_bullish, " htf_bear=", htf_bearish,
            " stoch_buy=", stoch_buy, " stoch_sell=", stoch_sell,
            " atr_ratio=", DoubleToString(M7_atr_ratio, 2));
   }

   prev_buy_setup  = buy_setup;
   prev_sell_setup = sell_setup;

   return true;
}

//+------------------------------------------------------------------+
//| HasOrderAtLevel                                                  |
//+------------------------------------------------------------------+
bool HasOrderAtLevel(double price, ENUM_POSITION_TYPE order_type)
{
   double tolerance = grid_step_points * 0.3;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetTicket(i) == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == order_type &&
         MathAbs(PositionGetDouble(POSITION_PRICE_OPEN) - price) <= tolerance)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| CreateNewBuyGrid                                                 |
//+------------------------------------------------------------------+
void CreateNewBuyGrid(double signal_price)
{
   if(!EnableGrid) return;
   int free_index = -1;
   for(int i = 0; i < 100; i++) { if(!buy_grids[i].is_active) { free_index = i; break; } }
   if(free_index == -1) { Print("Cannot create BUY grid - no free slots!"); return; }
   buy_grids[free_index].start_level   = signal_price;
   buy_grids[free_index].current_level = signal_price;
   buy_grids[free_index].is_active     = true;
   buy_grids[free_index].signal_id     = next_signal_id;
   buy_grids_count++;
   next_signal_id++;
   if(ShowGridDebug)
      Print("NEW BUY GRID: ID=", buy_grids[free_index].signal_id,
            " Level=", DoubleToString(signal_price, _Digits),
            " Total BUY Grids: ", buy_grids_count);
}

//+------------------------------------------------------------------+
//| CreateNewSellGrid                                                |
//+------------------------------------------------------------------+
void CreateNewSellGrid(double signal_price)
{
   if(!EnableGrid) return;
   int free_index = -1;
   for(int i = 0; i < 100; i++) { if(!sell_grids[i].is_active) { free_index = i; break; } }
   if(free_index == -1) { Print("Cannot create SELL grid - no free slots!"); return; }
   sell_grids[free_index].start_level   = signal_price;
   sell_grids[free_index].current_level = signal_price;
   sell_grids[free_index].is_active     = true;
   sell_grids[free_index].signal_id     = next_signal_id;
   sell_grids_count++;
   next_signal_id++;
   if(ShowGridDebug)
      Print("NEW SELL GRID: ID=", sell_grids[free_index].signal_id,
            " Level=", DoubleToString(signal_price, _Digits),
            " Total SELL Grids: ", sell_grids_count);
}

//+------------------------------------------------------------------+
//| UpdateAllBuyGridsLevels                                          |
//+------------------------------------------------------------------+
void UpdateAllBuyGridsLevels()
{
   if(!EnableGrid || buy_grids_count == 0) return;
   for(int grid_index = 0; grid_index < 100; grid_index++)
   {
      if(!buy_grids[grid_index].is_active) continue;
      double highest = buy_grids[grid_index].start_level;
      bool   found   = false;
      string search_comment = "GRID BUY ID:" + IntegerToString(buy_grids[grid_index].signal_id);
      for(int i = 0; i < PositionsTotal(); i++)
      {
         if(PositionGetTicket(i) == 0) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY &&
            StringFind(PositionGetString(POSITION_COMMENT), search_comment) >= 0)
         {
            found = true;
            double pp = PositionGetDouble(POSITION_PRICE_OPEN);
            if(pp > highest) highest = pp;
         }
      }
      if(found && highest > buy_grids[grid_index].current_level)
         buy_grids[grid_index].current_level = highest;
   }
}

//+------------------------------------------------------------------+
//| UpdateAllSellGridsLevels                                         |
//+------------------------------------------------------------------+
void UpdateAllSellGridsLevels()
{
   if(!EnableGrid || sell_grids_count == 0) return;
   for(int grid_index = 0; grid_index < 100; grid_index++)
   {
      if(!sell_grids[grid_index].is_active) continue;
      double lowest = sell_grids[grid_index].start_level;
      bool   found  = false;
      string search_comment = "GRID SELL ID:" + IntegerToString(sell_grids[grid_index].signal_id);
      for(int i = 0; i < PositionsTotal(); i++)
      {
         if(PositionGetTicket(i) == 0) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL &&
            StringFind(PositionGetString(POSITION_COMMENT), search_comment) >= 0)
         {
            found = true;
            double pp = PositionGetDouble(POSITION_PRICE_OPEN);
            if(pp < lowest) lowest = pp;
         }
      }
      if(found && lowest < sell_grids[grid_index].current_level)
         sell_grids[grid_index].current_level = lowest;
   }
}

//+------------------------------------------------------------------+
//| ProcessAllBuyGrids                                               |
//+------------------------------------------------------------------+
void ProcessAllBuyGrids()
{
   if(!EnableGrid || buy_grids_count == 0) return;
   double current_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   for(int grid_index = 0; grid_index < 100; grid_index++)
   {
      if(!buy_grids[grid_index].is_active) continue;
      double next_level = buy_grids[grid_index].current_level + grid_step_points;
      if(current_ask >= next_level)
      {
         if(!HasOrderAtLevel(next_level, POSITION_TYPE_BUY))
         {
            string comment = "GRID BUY ID:" + IntegerToString(buy_grids[grid_index].signal_id);
            OpenFixedMultipleGridBuy(comment);
            buy_grids[grid_index].current_level = current_ask;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| ProcessAllSellGrids                                              |
//+------------------------------------------------------------------+
void ProcessAllSellGrids()
{
   if(!EnableGrid || sell_grids_count == 0) return;
   double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   for(int grid_index = 0; grid_index < 100; grid_index++)
   {
      if(!sell_grids[grid_index].is_active) continue;
      double next_level = sell_grids[grid_index].current_level - grid_step_points;
      if(current_bid <= next_level)
      {
         if(!HasOrderAtLevel(next_level, POSITION_TYPE_SELL))
         {
            string comment = "GRID SELL ID:" + IntegerToString(sell_grids[grid_index].signal_id);
            OpenFixedMultipleGridSell(comment);
            sell_grids[grid_index].current_level = current_bid;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| OpenFixedMultipleGridBuy                                         |
//+------------------------------------------------------------------+
void OpenFixedMultipleGridBuy(string comment)
{
   if(!EnableGrid) return;
   double pip = ((_Digits == 3 || _Digits == 5) ? _Point * 10.0 : _Point);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl  = (StopLoss > 0) ? ask - StopLoss * pip : 0;
   double vol = NormalizeVolume(GridLotSize);
   if(trade.Buy(vol, _Symbol, ask, sl, 0, comment))
      Print("GRID BUY: Ticket=", trade.ResultOrder(), " Vol=", vol, " Price=", DoubleToString(ask, _Digits));
   else
      Print("Failed GRID BUY. Error: ", trade.ResultRetcode());
}

//+------------------------------------------------------------------+
//| OpenFixedMultipleGridSell                                        |
//+------------------------------------------------------------------+
void OpenFixedMultipleGridSell(string comment)
{
   if(!EnableGrid) return;
   double pip = ((_Digits == 3 || _Digits == 5) ? _Point * 10.0 : _Point);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl  = (StopLoss > 0) ? bid + StopLoss * pip : 0;
   double vol = NormalizeVolume(GridLotSize);
   if(trade.Sell(vol, _Symbol, bid, sl, 0, comment))
      Print("GRID SELL: Ticket=", trade.ResultOrder(), " Vol=", vol, " Price=", DoubleToString(bid, _Digits));
   else
      Print("Failed GRID SELL. Error: ", trade.ResultRetcode());
}

//+------------------------------------------------------------------+
//| OpenBuy                                                          |
//+------------------------------------------------------------------+
void OpenBuy()
{
   double pip = ((_Digits == 3 || _Digits == 5) ? _Point * 10.0 : _Point);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl  = (StopLoss > 0) ? ask - StopLoss * pip : 0;
   double vol = CalculateNextVolume();
   if(trade.Buy(vol, _Symbol, ask, sl, 0, "SR Signal BUY"))
   {
      Print("BUY opened: Signal #", signal_count, " Ticket=", trade.ResultOrder(),
            " Volume=", vol, " Price=", DoubleToString(ask, _Digits));
      if(EnableGrid) CreateNewBuyGrid(ask);
   }
   else
   {
      Print("Failed to open BUY. Error: ", trade.ResultRetcode());
      if(EnableVolumeIncrease && !EnableSmartLot) signal_count--;
   }
}

//+------------------------------------------------------------------+
//| OpenSell                                                         |
//+------------------------------------------------------------------+
void OpenSell()
{
   double pip = ((_Digits == 3 || _Digits == 5) ? _Point * 10.0 : _Point);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl  = (StopLoss > 0) ? bid + StopLoss * pip : 0;
   double vol = CalculateNextVolume();
   if(trade.Sell(vol, _Symbol, bid, sl, 0, "SR Signal SELL"))
   {
      Print("SELL opened: Signal #", signal_count, " Ticket=", trade.ResultOrder(),
            " Volume=", vol, " Price=", DoubleToString(bid, _Digits));
      if(EnableGrid) CreateNewSellGrid(bid);
   }
   else
   {
      Print("Failed to open SELL. Error: ", trade.ResultRetcode());
      if(EnableVolumeIncrease && !EnableSmartLot) signal_count--;
   }
}

//+------------------------------------------------------------------+
//| DisplayDashboard                                                 |
//+------------------------------------------------------------------+
void DisplayDashboard(double danger_score)
{
   if(!ShowDashboard) return;

   string status = "НОРМА";
   if(danger_score >= ScoreEmergency)      status = "АВАРИЯ";
   else if(danger_score >= ScoreCritical)  status = "ОЧЕНЬ ОПАСНО";
   else if(danger_score >= ScoreDanger)    status = "ОПАСНО";
   else if(danger_score >= ScoreCaution)   status = "ОСТОРОЖНО";

   int    bar_fill = (int)MathMax(0, MathMin(10, (int)MathRound(danger_score / 10.0)));
   string bar = "";
   for(int i = 0; i < 10; i++) bar += (i < bar_fill ? "█" : "░");

   string tp_info;
   if(EnableSmartTP)
      tp_info = StringFormat("SmartTP: $%.2f / $%.2f", last_opposite_profit, SmartTP_Threshold);
   else
      tp_info = StringFormat("SimpleTP: $%.2f / $%.2f", G1_total_pnl, TargetProfit);

   string lot_info = EnableSmartLot
      ? StringFormat("SmartLot %.0f%%", RiskPercent)
      : StringFormat("FixedLot %.2f", LotSize);

   string cmt = "╔═══════════════════════════════════╗\n";
   cmt += "║      EA S-R Signal v4             ║\n";
   cmt += "╠═══════════════════════════════════╣\n";
   cmt += StringFormat("║ Danger [%s] %2.0f          ║\n", bar, danger_score);
   cmt += StringFormat("║ Статус: %-25s║\n", status);
   cmt += "╠═══════════════════════════════════╣\n";
   cmt += StringFormat("║ Buy: %-3d  Sell: %-3d  P&L: $%-8.2f║\n", G2_buy_count, G3_sell_count, G1_total_pnl);
   cmt += StringFormat("║ Просадка: %-24.2f%%║\n", G7_drawdown_percent);
   cmt += StringFormat("║ Перекос: %-25.0f%%║\n", G4_imbalance_percent);
   cmt += StringFormat("║ ATR ratio: %-23.2f║\n", M7_atr_ratio);
   cmt += "╠═══════════════════════════════════╣\n";
   cmt += StringFormat("║ %-34s║\n", tp_info);
   cmt += StringFormat("║ %-34s║\n", lot_info);
   cmt += StringFormat("║ Grid: BUY %-3d  SELL %-3d          ║\n", buy_grids_count, sell_grids_count);
   cmt += StringFormat("║ Trailing: %-24s║\n", EnableTrailingStop ? "ВКЛ" : "ВЫКЛ");
   cmt += StringFormat("║ Новые ордера: %-20s║\n", IsNewOrderAllowed() ? "РАЗРЕШЕНЫ" : "ЗАПРЕЩЕНЫ");
   cmt += "╚═══════════════════════════════════╝";

   Comment(cmt);
}

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1. Update position and market data for SmartCalculator
   UpdatePositionData();
   UpdateATRData();

   // 2. Danger score – may block orders or close positions
   double score = CalculateDangerScore();
   HandleDangerScore(score);

   // 3. Swap filter – auto-close aged positions with excess swap
   CheckSwapFilter();

   // 4. Trailing stop – adjust SL on all open positions
   ApplyTrailingStop();

   // 5. Signal detection and order opening (only if allowed)
   CheckResetSignalCounter();

   if(IsNewOrderAllowed())
   {
      // Block if near news
      bool news_ok = !(UseNewsFilter && IsNewsBlocked());

      // Block if too many positions per side
      bool pos_ok = (MathMax(G2_buy_count, G3_sell_count) < MaxPositionsSide);

      // Block on extreme drawdown
      bool dd_ok = (G7_drawdown_percent < MaxDrawdownPercent);

      if(news_ok && pos_ok && dd_ok)
      {
         bool buySignal = false, sellSignal = false;
         if(GetSignals(buySignal, sellSignal))
         {
            if(buySignal)  { Print("BUY SIGNAL!  Opening BUY and creating new grid."); OpenBuy();  }
            if(sellSignal) { Print("SELL SIGNAL! Opening SELL and creating new grid."); OpenSell(); }
         }
      }
      else if(ShowDebugInfo)
      {
         if(!news_ok) Print("Entry blocked: news filter");
         if(!pos_ok)  Print("Entry blocked: max positions side=", MaxPositionsSide);
         if(!dd_ok)   Print("Entry blocked: drawdown=", DoubleToString(G7_drawdown_percent, 2), "%");
      }
   }

   // 6. Grid processing
   UpdateAllBuyGridsLevels();
   UpdateAllSellGridsLevels();
   ProcessAllBuyGrids();
   ProcessAllSellGrids();

   // 7. Take profit
   if(EnableSmartTP)
      CheckSmartTakeProfit();
   else
      CheckSimpleTakeProfit();

   // 8. Dashboard
   DisplayDashboard(score);
}
//+------------------------------------------------------------------+
