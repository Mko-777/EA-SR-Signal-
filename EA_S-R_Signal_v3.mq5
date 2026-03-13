//+------------------------------------------------------------------+
//|          EA S-R Signal v3 - SmartTP FIXED v5                    |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "5.00"

#include <Trade\Trade.mqh>

CTrade trade;

//+------------------------------------------------------------------+
//| Настройки индикатора S-R Signal v1                               |
//+------------------------------------------------------------------+
input group "=== S-R Signal v1 Settings ==="
input int Zone1Length = 100;
input int Zone2Length = 60;
input int Zone3Length = 20;
input bool EnableHTFTrendFilter = true;
input ENUM_TIMEFRAMES HTFTimeframe = PERIOD_H1;

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
input bool   EnableSmartTP        = true;
input double SmartTP_Threshold    = 50.0;
input bool   ShowSmartTPDebug     = true;

//+------------------------------------------------------------------+
//| Global Variables                                                 |
+------------------------------------------------------------------+\nint    g_signal_count   = 0;
double g_current_lot    = 0.01;
datetime g_last_day     = 0;
string g_last_signal    = "";

bool   g_grid_active_buy  = false;
bool   g_grid_active_sell = false;
double g_last_grid_buy_price  = 0;
double g_last_grid_sell_price = 0;

int stoch_handle = INVALID_HANDLE;
int zone1_handle = INVALID_HANDLE;
int zone2_handle = INVALID_HANDLE;
int zone3_handle = INVALID_HANDLE;
int htf_zone1_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
  {
   stoch_handle = iStochastic(_Symbol, PERIOD_CURRENT,
                              Stochastic_Kperiod, Stochastic_Dperiod,
                              Stochastic_Slowing, Stochastic_Method,
                              Stochastic_Price);
   if(stoch_handle == INVALID_HANDLE)
     {
      Print("ERROR: Failed to create Stochastic indicator");
      return(INIT_FAILED);
     }

   trade.SetExpertMagicNumber(123456);

   Print("EA S-R Signal v5 initialized. SmartTP=", EnableSmartTP,
         " Threshold=$", SmartTP_Threshold);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(stoch_handle != INVALID_HANDLE) IndicatorRelease(stoch_handle);
  }

//+------------------------------------------------------------------+
//| Count positions by direction for this EA                        |
//+------------------------------------------------------------------+
int CountPositions(ENUM_POSITION_TYPE posType)
  {
   int count = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != 123456) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == posType)
         count++;
     }
   return count;
  }

//+------------------------------------------------------------------+
//| Get total profit of ALL positions (BUY + SELL) for this EA      |
+------------------------------------------------------------------+
double GetTotalProfit()
  {
   double total = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != 123456) continue;
      total += PositionGetDouble(POSITION_PROFIT);
      total += PositionGetDouble(POSITION_SWAP);
     }
   return total;
  }

//+------------------------------------------------------------------+
//| Get profit by direction                                         |
//+------------------------------------------------------------------+
double GetProfitByDirection(ENUM_POSITION_TYPE posType)
  {
   double total = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != 123456) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == posType)
        {
         total += PositionGetDouble(POSITION_PROFIT);
         total += PositionGetDouble(POSITION_SWAP);
        }
     }
   return total;
  }

//+------------------------------------------------------------------+
//| Close ALL positions for this EA                                 |
+------------------------------------------------------------------+
void CloseAllPositions(string reason)
  {
   Print("=== CLOSING ALL POSITIONS: ", reason, " ===");
   for(int i = PositionsTotal()-1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != 123456) continue;
      trade.PositionClose(ticket);
     }
   // Deactivate grids after closing
   g_grid_active_buy  = false;
   g_grid_active_sell = false;
   g_last_grid_buy_price  = 0;
   g_last_grid_sell_price = 0;
   g_last_signal = "";
  }

//+------------------------------------------------------------------+
//| SimpleTP: close all when total profit >= TargetProfit           |
+------------------------------------------------------------------+
void CheckSimpleTakeProfit()
  {
   if(!EnableSimpleTP) return;
   if(EnableSmartTP) return;  // SmartTP takes priority

   if(PositionsTotal() == 0) return;

   double totalProfit = GetTotalProfit();

   if(ShowDebugInfo)
      Print("SimpleTP Check: TotalProfit=$", DoubleToString(totalProfit,2),
            " / Target=$", DoubleToString(TargetProfit,2));

   if(totalProfit >= TargetProfit)
     {
      Print("SimpleTP TRIGGERED! Total=$", DoubleToString(totalProfit,2));
      CloseAllPositions("SimpleTP");
     }
  }

//+------------------------------------------------------------------+
//| SmartTP: FIXED - uses TOTAL profit (BUY+SELL), not just opposite|
//|                                                                  |
//| KEY FIX: The previous version checked only "opposite direction"  |
//| profit. Now we check TOTAL profit of ALL positions together.     |
//| This is the correct behavior: close everything when the NET      |
//| result of all open trades reaches the threshold.                 |
+------------------------------------------------------------------+
void CheckSmartTakeProfit()
  {
   if(!EnableSmartTP) return;

   int totalPositions = PositionsTotal();
   if(totalPositions == 0) return;

   int buyCount  = CountPositions(POSITION_TYPE_BUY);
   int sellCount = CountPositions(POSITION_TYPE_SELL);

   // SmartTP only makes sense when we have BOTH directions open (hedge situation)
   // OR just use total profit check if only one direction
   double totalProfit  = GetTotalProfit();
   double buyProfit    = GetProfitByDirection(POSITION_TYPE_BUY);
   double sellProfit   = GetProfitByDirection(POSITION_TYPE_SELL);

   if(ShowSmartTPDebug)
     {
      Print("SmartTP Check:");
      Print("   Last Signal Direction : ", g_last_signal);
      Print("   BUY  Positions        : ", buyCount,
            " | Profit: $", DoubleToString(buyProfit,2));
      Print("   SELL Positions        : ", sellCount,
            " | Profit: $", DoubleToString(sellProfit,2));
      Print("   TOTAL Profit          : $", DoubleToString(totalProfit,2),
            " / $", DoubleToString(SmartTP_Threshold,2), " (threshold)");
      Print("   Status                : ",
            (totalProfit >= SmartTP_Threshold) ? ">>> CLOSING ALL <<<" : "WAITING");
     }

   // FIXED: Check TOTAL profit, not just opposite direction
   if(totalProfit >= SmartTP_Threshold)
     {
      Print("SmartTP TRIGGERED! Total P&L = $", DoubleToString(totalProfit,2),
            " >= Threshold $", DoubleToString(SmartTP_Threshold,2));
      CloseAllPositions("SmartTP");
     }
  }

//+------------------------------------------------------------------+
//| Get stochastic value                                            |
+------------------------------------------------------------------+
bool GetStochasticSignal(bool &isBuySignal, bool &isSellSignal)
  {
   if(!EnableStochasticFilter)
     {
      isBuySignal  = true;
      isSellSignal = true;
      return true;
     }

   double mainLine[];
   double signalLine[];
   ArraySetAsSeries(mainLine,   true);
   ArraySetAsSeries(signalLine, true);

   if(CopyBuffer(stoch_handle, 0, 0, 3, mainLine)   < 3) return false;
   if(CopyBuffer(stoch_handle, 1, 0, 3, signalLine) < 3) return false;

   double stochVal = Stochastic_UseMainLine ? mainLine[1] : signalLine[1];

   isBuySignal  = (stochVal < Stochastic_LowerLevel);
   isSellSignal = (stochVal > Stochastic_UpperLevel);

   if(ShowStochasticDebug)
      Print("Stoch=", DoubleToString(stochVal,2),
            " Buy=", isBuySignal, " Sell=", isSellSignal);

   return true;
  }

//+------------------------------------------------------------------+
//| Simple S-R zone detection based on recent highs/lows            |
+------------------------------------------------------------------+
bool DetectSRSignal(bool &buySignal, bool &sellSignal)
  {
   buySignal  = false;
   sellSignal = false;

   double high[], low[], close[];
   ArraySetAsSeries(high,  true);
   ArraySetAsSeries(low,   true);
   ArraySetAsSeries(close, true);

   int barsNeeded = MathMax(Zone1Length, MathMax(Zone2Length, Zone3Length)) + 5;
   if(CopyHigh(_Symbol,  PERIOD_CURRENT, 0, barsNeeded, high)  < barsNeeded) return false;
   if(CopyLow(_Symbol,   PERIOD_CURRENT, 0, barsNeeded, low)   < barsNeeded) return false;
   if(CopyClose(_Symbol, PERIOD_CURRENT, 0, barsNeeded, close) < barsNeeded) return false;

   double zone3High = high[ArrayMaximum(high,  1, Zone3Length)];
   double zone3Low  = low[ArrayMinimum(low,    1, Zone3Length)];
   double zone2High = high[ArrayMaximum(high,  1, Zone2Length)];
   double zone2Low  = low[ArrayMinimum(low,    1, Zone2Length)];

   double currentPrice = close[1];
   double point = _Point * 10;

   // Buy signal: price near zone3 low bouncing from support
   if(currentPrice <= zone3Low + point * 5 &&
      currentPrice > zone3Low - point * 10)
      buySignal = true;

   // Sell signal: price near zone3 high at resistance
   if(currentPrice >= zone3High - point * 5 &&
      currentPrice < zone3High + point * 10)
      sellSignal = true;

   return true;
  }

//+------------------------------------------------------------------+
//| HTF Trend Filter                                                |
+------------------------------------------------------------------+
bool GetHTFTrend(bool &trendUp, bool &trendDown)
  {
   trendUp   = true;
   trendDown = true;

   if(!EnableHTFTrendFilter) return true;

   double htfClose[];
   ArraySetAsSeries(htfClose, true);
   if(CopyClose(_Symbol, HTFTimeframe, 0, Zone1Length + 5, htfClose) < Zone1Length + 5)
      return false;

   double htfHigh = htfClose[ArrayMaximum(htfClose, 1, Zone1Length)];
   double htfLow  = htfClose[ArrayMinimum(htfClose, 1, Zone1Length)];
   double current = htfClose[1];
   double midPoint = (htfHigh + htfLow) / 2.0;

   trendUp   = (current > midPoint);
   trendDown = (current < midPoint);

   return true;
  }

//+------------------------------------------------------------------+
//| Open a trade                                                    |
+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE orderType)
  {
   double lot = LotSize;
   if(EnableVolumeIncrease)
     {
      lot = g_current_lot;
      if(lot > MaxLotSize) lot = MaxLotSize;
     }

   double price = (orderType == ORDER_TYPE_BUY)
                  ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double sl = 0;
   if(StopLoss > 0)
     {
      double slDist = StopLoss * _Point * 10;
      sl = (orderType == ORDER_TYPE_BUY)
           ? price - slDist
           : price + slDist;
     }

   bool result = (orderType == ORDER_TYPE_BUY)
                 ? trade.Buy(lot, _Symbol, price, sl, 0)
                 : trade.Sell(lot, _Symbol, price, sl, 0);

   if(result)
     {
      g_last_signal = (orderType == ORDER_TYPE_BUY) ? "BUY" : "SELL";
      if(EnableGrid)
        {
         if(orderType == ORDER_TYPE_BUY)
           {
            g_grid_active_buy    = true;
            g_last_grid_buy_price = price;
           }
         else
           {
            g_grid_active_sell    = true;
            g_last_grid_sell_price = price;
           }
        }
      if(EnableVolumeIncrease)
        {
         g_signal_count++;
         if(g_signal_count < MaxSignalCount)
            g_current_lot = NormalizeDouble(LotSize * MathPow(VolumeMultiplier, g_signal_count), 2);
        }
      Print("Opened ", (orderType==ORDER_TYPE_BUY?"BUY":"SELL"),
            " lot=", DoubleToString(lot,2), " price=", DoubleToString(price,5));
     }
  }

//+------------------------------------------------------------------+
//| Grid management                                                 |
+------------------------------------------------------------------+
void ManageGrid()
  {
   if(!EnableGrid) return;

   double stepDist = GridStepPips * _Point * 10;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // BUY grid: add when price drops GridStep below last grid buy
   if(g_grid_active_buy && g_last_grid_buy_price > 0)
     {
      if(ask <= g_last_grid_buy_price - stepDist)
        {
         if(ShowGridDebug)
            Print("Grid BUY: price dropped ", GridStepPips, " pips. Adding BUY.");
         double sl = 0;
         if(StopLoss > 0) sl = ask - StopLoss * _Point * 10;
         if(trade.Buy(GridLotSize, _Symbol, ask, sl, 0))
            g_last_grid_buy_price = ask;
        }
     }

   // SELL grid: add when price rises GridStep above last grid sell
   if(g_grid_active_sell && g_last_grid_sell_price > 0)
     {
      if(bid >= g_last_grid_sell_price + stepDist)
        {
         if(ShowGridDebug)
            Print("Grid SELL: price rose ", GridStepPips, " pips. Adding SELL.");
         double sl = 0;
         if(StopLoss > 0) sl = bid + StopLoss * _Point * 10;
         if(trade.Sell(GridLotSize, _Symbol, bid, sl, 0))
            g_last_grid_sell_price = bid;
        }
     }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
+------------------------------------------------------------------+
void OnTick()
  {
   // Reset daily counters
   if(EnableVolumeIncrease && ResetOnNewDay)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      datetime today = StringToTime(IntegerToString(dt.year) + "." +
                                    IntegerToString(dt.mon)  + "." +
                                    IntegerToString(dt.day));
      if(today != g_last_day)
        {
         g_last_day     = today;
         g_signal_count = 0;
         g_current_lot  = LotSize;
         if(ShowVolumeDebug)
            Print("New day reset: lot=", DoubleToString(g_current_lot,2));
        }
     }

   // === TAKE PROFIT CHECKS (run every tick) ===
   CheckSmartTakeProfit();
   CheckSimpleTakeProfit();

   // === GRID MANAGEMENT ===
   ManageGrid();

   // === SIGNAL DETECTION (only on new bar) ===
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(currentBarTime == lastBarTime) return;
   lastBarTime = currentBarTime;

   // Get S-R signal
   bool srBuy = false, srSell = false;
   if(!DetectSRSignal(srBuy, srSell)) return;

   // Get HTF trend
   bool trendUp = true, trendDown = true;
   GetHTFTrend(trendUp, trendDown);

   // Get Stochastic confirmation
   bool stochBuy = false, stochSell = false;
   GetStochasticSignal(stochBuy, stochSell);

   // Open trades based on combined signals
   if(srBuy && trendUp && stochBuy)
      OpenTrade(ORDER_TYPE_BUY);
   else if(srSell && trendDown && stochSell)
      OpenTrade(ORDER_TYPE_SELL);
  }
//+------------------------------------------------------------------+