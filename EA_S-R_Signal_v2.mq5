//+------------------------------------------------------------------+
//|          EA S-R Signal v2 - ДЕАКТИВАЦИЯ ТОЛЬКО СЕТОК ПОСЛЕ TP   |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "2.00"

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
input bool EnableStochasticFilter = true;    // Enable Stochastic Filter
input int Stochastic_Kperiod = 5;            // %K period
input int Stochastic_Dperiod = 3;            // %D period
input int Stochastic_Slowing = 3;            // Slowing
input ENUM_MA_METHOD Stochastic_Method = MODE_SMA;     // MA method
input ENUM_STO_PRICE Stochastic_Price = STO_LOWHIGH;   // Price field
input double Stochastic_UpperLevel = 70.0;   // Upper level (>=70 = SELL only)
input double Stochastic_LowerLevel = 30.0;   // Lower level (<=30 = BUY only)
input bool Stochastic_UseMainLine = true;    // Use Main line (%K) for signals
input bool Stochastic_UseSignalLine = false; // Use Signal line (%D) for signals
input bool Stochastic_CrossoverSignals = false; // Use %K/%D crossover signals
input bool ShowStochasticDebug = true;       // Show Stochastic debug info

//+------------------------------------------------------------------+
//| FIXED MULTIPLE GRIDS                                             |
//+------------------------------------------------------------------+
input group "=== FIXED MULTIPLE GRIDS ==="
input bool EnableGrid = true;              // Enable Multiple Grid System
input int GridStepPips = 50;               // Grid Step in Pips
input double GridLotSize = 0.01;           // Grid Lot Size
input bool ShowGridDebug = true;           // Show Grid Debug Info

//+------------------------------------------------------------------+
//| Trade Settings                                                   |
//+------------------------------------------------------------------+
input group "=== Trade Settings ==="
input double LotSize = 0.01;        // Base Lot Size (1st signal)
input int StopLoss = 50;            // Stop Loss (points)

//+------------------------------------------------------------------+
//| Volume Increase System with Lot Limit                           |
//+------------------------------------------------------------------+
input group "=== Volume Increase with Lot Limit ==="
input bool EnableVolumeIncrease = true;     // Enable Volume Increase
input double VolumeMultiplier = 2.0;        // Volume Multiplier (2.0 = double each signal)
input int MaxSignalCount = 5;               // Max signal count (then reset to 1st)
input double MaxLotSize = 0.1;              // Maximum Lot Size Limit
input bool ResetOnNewDay = true;            // Reset signal counter on new day
input bool ShowVolumeDebug = true;          // Show volume debug info

//+------------------------------------------------------------------+
//| Take Profit with Grid Deactivation Only                         |
//+------------------------------------------------------------------+
input group "=== Take Profit with Grid Deactivation Only ==="
input bool EnableSimpleTP = true;       // Enable Simple TP Calculator
input double TargetProfit = 50.0;       // Target Profit in $ to close ALL positions
input bool ShowDebugInfo = false;       // Show debug info

//+------------------------------------------------------------------+
//| Global Variables                                                 |
+... (file content truncated for brevity) + ...
//+------------------------------------------------------------------+

void OnTick()
{
   CheckResetSignalCounter();

   bool buySignal = false, sellSignal = false;
   if(GetSignals(buySignal, sellSignal))
   {
      if(buySignal) OpenBuy();
      if(sellSignal) OpenSell();
   }

   UpdateAllBuyGridsLevels();
   UpdateAllSellGridsLevels();
   ProcessAllBuyGrids();
   ProcessAllSellGrids();

   CheckSimpleTakeProfit();

   double total_profit = 0.0;
   int total_positions = 0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetTicket(i) > 0 && PositionGetString(POSITION_SYMBOL) == _Symbol)
      {
         total_profit += PositionGetDouble(POSITION_PROFIT);
         total_positions++;
      }
   }

   string chart_comment = "EA SR Signal v2\n";
   chart_comment += StringFormat("Stochastic Filter: %s\n", EnableStochasticFilter ? "ON" : "OFF");
   chart_comment += StringFormat("Grid System: %s\n", EnableGrid ? "ON" : "OFF");
   if(EnableGrid)
      chart_comment += StringFormat("Active BUY Grids: %d | Active SELL Grids: %d\n", buy_grids_count, sell_grids_count);
   chart_comment += StringFormat("Volume System: %s\n", EnableVolumeIncrease ? "ON" : "OFF");
   chart_comment += StringFormat("TP Calculator: %s\n", EnableSimpleTP ? "ON" : "OFF");
   chart_comment += StringFormat("Positions: %d\n", total_positions);
   if(total_positions > 0)
      chart_comment += StringFormat("Profit: $%.2f / $%.2f", total_profit, TargetProfit);

   Comment(chart_comment);
}