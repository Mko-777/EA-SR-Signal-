//+------------------------------------------------------------------+
//|          EA S-R Signal v3 - SmartTP + ДЕАКТИВАЦИЯ СЕТОК ПОСЛЕ TP|
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "3.00"

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
input bool EnableSimpleTP = true;
input double TargetProfit = 50.0;
input bool ShowDebugInfo = false;

//+------------------------------------------------------------------+
//| === Smart Take Profit (SmartTP) ===                              |
//+------------------------------------------------------------------+
input group "=== Smart Take Profit (SmartTP) ==="
input bool   EnableSmartTP     = true;    // true=SmartTP, false=SimpleTP
input double SmartTP_Threshold = 50.0;   // Threshold $ for opposite positions profit
input bool   ShowSmartTPDebug  = true;   // Show SmartTP debug info

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
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

int buy_grids_count  = 0;
int sell_grids_count = 0;
int next_signal_id   = 1;

// SmartTP tracking variable
double last_opposite_profit = 0.0;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("EA SR Signal v3 - SmartTP + GRID DEACTIVATION initialized!");
   Print("   Simple TP: ", EnableSimpleTP ? "ON (Target: $" + DoubleToString(TargetProfit, 2) + ")" : "OFF");
   Print("   SmartTP: ", EnableSmartTP ? "ON (Threshold: $" + DoubleToString(SmartTP_Threshold, 2) + ")" : "OFF");
   Print("   Stochastic Filter: ", EnableStochasticFilter ? "ON" : "OFF");
   Print("   Volume Increase System: ", EnableVolumeIncrease ? "ON" : "OFF");
   Print("   FIXED MULTIPLE GRIDS SYSTEM: ", EnableGrid ? "ON" : "OFF");

   if(EnableGrid)
   {
      grid_step_points = GridStepPips * _Point;
      if(_Digits == 5 || _Digits == 3)
         grid_step_points = GridStepPips * _Point * 10;
      Print("   Grid Step: ", GridStepPips, " pips (", DoubleToString(grid_step_points, _Digits), ");");
   }

   effective_max_lot_size = MaxLotSize;
   if(effective_max_lot_size < LotSize)
   {
      Print("WARNING: MaxLotSize < LotSize! Setting effective MaxLotSize = LotSize");
      effective_max_lot_size = LotSize;
   }

   Print("   Current TF: ", EnumToString(_Period));
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

   trade.SetExpertMagicNumber(123456);
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
   Print("EA SR Signal v3 deinitialized. Reason: ", reason);
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
      if(PositionGetInteger(POSITION_MAGIC) != 123456) continue;
      if(trade.PositionClose(ticket))
         Print("Closed position #", ticket);
      else
         Print("Failed to close #", ticket, " Error: ", trade.ResultRetcode());
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
   string last_signal_name;
   string opposite_name;

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
      // Both true: find most recent position
      datetime latest_time = 0;
      ENUM_POSITION_TYPE latest_type = POSITION_TYPE_BUY;
      for(int i = 0; i < PositionsTotal(); i++)
      {
         if(PositionGetTicket(i) == 0) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC) != 123456) continue;
         datetime pos_time = (datetime)PositionGetInteger(POSITION_TIME);
         if(pos_time > latest_time)
         {
            latest_time = pos_time;
            latest_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         }
      }
      if(latest_type == POSITION_TYPE_BUY)
      {
         opposite_type    = POSITION_TYPE_SELL;
         last_signal_name = "BUY";
         opposite_name    = "SELL";
      }
      else
      {
         opposite_type    = POSITION_TYPE_BUY;
         last_signal_name = "SELL";
         opposite_name    = "BUY";
      }
   }

   double opposite_profit = 0.0;
   int    opposite_count  = 0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetTicket(i) == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != 123456) continue;
      ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == opposite_type)
      {
         opposite_profit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         opposite_count++;
      }
   }

   last_opposite_profit = opposite_profit;

   if(ShowSmartTPDebug)
   {
      Print("SmartTP Check:");
      Print("   Last Signal Direction : ", last_signal_name);
      Print("   Opposite Direction    : ", opposite_name);
      Print("   Opposite Positions    : ", opposite_count);
      Print("   Opposite Profit       : $", DoubleToString(opposite_profit, 2),
            " / $", DoubleToString(SmartTP_Threshold, 2), " (threshold)");
      Print("   Status                : ", (opposite_count > 0 && opposite_profit >= SmartTP_Threshold) ? "TRIGGERED" : "WAITING");
   }

   if(opposite_count > 0 && opposite_profit >= SmartTP_Threshold)
   {
      Print("SmartTP TRIGGERED! Opposite Profit: $", DoubleToString(opposite_profit, 2));
      Print("Closing ALL positions...");

      CloseAllPositions();

      if(EnableVolumeIncrease)
      {
         signal_count = 0;
         Print("Signal counter reset after SmartTP");
      }

      if(EnableGrid) DeactivateAllGridsAfterTP();

      last_opposite_profit = 0.0;

      Print("SmartTP completed. Waiting for new signal.");
   }
}

//+------------------------------------------------------------------+
//| CheckSimpleTakeProfit - RESERVE mode (EnableSmartTP=false)      |
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
      if(EnableVolumeIncrease) { signal_count = 0; }
      DeactivateAllGridsAfterTP();
      CloseAllPositions();
      Print("SIMPLE TP COMPLETED!");
   }
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
//| CalculateNextVolume                                              |
//+------------------------------------------------------------------+
double CalculateNextVolume()
{
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
   datetime current_time = TimeCurrent();
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

   if(in_upper)       { buy_allowed = false; sell_allowed = true;  }
   else if(in_lower)  { buy_allowed = true;  sell_allowed = false; }
   else               { buy_allowed = false; sell_allowed = false; }

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

   double mid         = (z1h + z1l) / 2.0;
   bool price_above   = htf_close[0] > mid;

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
      if(htf_bullish && !htf_bearish)   final_sell = false;
      else if(htf_bearish && !htf_bullish) final_buy = false;
   }
   if(EnableStochasticFilter)
   {
      if(!stoch_buy)  final_buy  = false;
      if(!stoch_sell) final_sell = false;
   }

   buySignal  = final_buy  && !prev_buy_setup;
   sellSignal = final_sell && !prev_sell_setup;

   if(ShowDebugInfo && (buySignal || sellSignal))
   {
      Print("SIGNAL: BUY=", buySignal, " SELL=", sellSignal,
            " htf_bull=", htf_bullish, " htf_bear=", htf_bearish,
            " stoch_buy=", stoch_buy, " stoch_sell=", stoch_sell);
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
      bool found = false;
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
      bool found = false;
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
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl  = (StopLoss > 0) ? ask - StopLoss * _Point : 0;
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
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl  = (StopLoss > 0) ? bid + StopLoss * _Point : 0;
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
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl  = (StopLoss > 0) ? ask - StopLoss * _Point : 0;
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
      if(EnableVolumeIncrease) signal_count--;
   }
}

//+------------------------------------------------------------------+
//| OpenSell                                                         |
//+------------------------------------------------------------------+
void OpenSell()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl  = (StopLoss > 0) ? bid + StopLoss * _Point : 0;
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
      if(EnableVolumeIncrease) signal_count--;
   }
}

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
{
   CheckResetSignalCounter();

   bool buySignal = false, sellSignal = false;
   if(GetSignals(buySignal, sellSignal))
   {
      if(buySignal)  { Print("BUY SIGNAL! Opening BUY and creating new grid."); OpenBuy();  }
      if(sellSignal) { Print("SELL SIGNAL! Opening SELL and creating new grid."); OpenSell(); }
   }

   UpdateAllBuyGridsLevels();
   UpdateAllSellGridsLevels();
   ProcessAllBuyGrids();
   ProcessAllSellGrids();

   // TP: SmartTP or SimpleTP based on flag
   if(EnableSmartTP)
      CheckSmartTakeProfit();
   else
      CheckSimpleTakeProfit();

   // Chart comment
   double total_profit = 0.0;
   int    total_pos    = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetTicket(i) > 0 && PositionGetString(POSITION_SYMBOL) == _Symbol)
      {
         total_profit += PositionGetDouble(POSITION_PROFIT);
         total_pos++;
      }
   }

   string cmt = "EA SR Signal v3 - SmartTP\n";
   cmt += StringFormat("Stochastic: %s", EnableStochasticFilter ? "ON" : "OFF");
   if(EnableStochasticFilter)
      cmt += StringFormat(" | >=%.0f=SELL | <=%.0f=BUY\n", Stochastic_UpperLevel, Stochastic_LowerLevel);
   else
      cmt += "\n";

   cmt += StringFormat("Grid: %s", EnableGrid ? "ON" : "OFF");
   if(EnableGrid)
      cmt += StringFormat(" | BUY: %d | SELL: %d\n", buy_grids_count, sell_grids_count);
   else
      cmt += "\n";

   cmt += StringFormat("Volume: %s", EnableVolumeIncrease ? "ON" : "OFF");
   if(EnableVolumeIncrease)
      cmt += StringFormat(" | Signal: %d/%d\n", signal_count, MaxSignalCount);
   else
      cmt += "\n";

   if(EnableSmartTP)
   {
      cmt += StringFormat("SmartTP: ON | Threshold: $%.2f\n", SmartTP_Threshold);
      cmt += StringFormat("Opposite Profit: $%.2f", last_opposite_profit);
      if(SmartTP_Threshold > 0)
         cmt += StringFormat(" (%.1f%%)", last_opposite_profit / SmartTP_Threshold * 100.0);
      cmt += "\n";
   }
   else
   {
      cmt += StringFormat("SimpleTP: %s | Target: $%.2f\n", EnableSimpleTP ? "ON" : "OFF", TargetProfit);
   }

   cmt += StringFormat("Positions: %d", total_pos);
   if(total_pos > 0)
      cmt += StringFormat(" | Total Profit: $%.2f", total_profit);

   Comment(cmt);
}
//+------------------------------------------------------------------+
