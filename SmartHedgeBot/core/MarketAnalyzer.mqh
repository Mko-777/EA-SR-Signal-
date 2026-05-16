#ifndef __SMART_HEDGE_BOT_MARKET_ANALYZER_MQH__
#define __SMART_HEDGE_BOT_MARKET_ANALYZER_MQH__

double M1_price = 0.0;
double M2_ema50_h4 = 0.0;
double M3_ema200_h4 = 0.0;
double M4_dist_to_ema50_pips = 0.0;
double M5_atr_current = 0.0;
double M6_atr_average = 0.0;
double M7_atr_ratio = 0.0;
double M8_support_h1 = 0.0;
double M9_resistance_h1 = 0.0;
double M10_nearest_level_dist_pips = 0.0;

double ReadMAValue(ENUM_TIMEFRAMES tf, int period, int shift)
{
   int handle = iMA(_Symbol, tf, period, 0, MODE_EMA, PRICE_CLOSE);
   if(handle == INVALID_HANDLE)
      return 0.0;

   double buffer[];
   ArraySetAsSeries(buffer, true);
   if(CopyBuffer(handle, 0, shift, 1, buffer) <= 0)
   {
      IndicatorRelease(handle);
      return 0.0;
   }

   double value = buffer[0];
   IndicatorRelease(handle);
   return value;
}

double ReadATRValue(ENUM_TIMEFRAMES tf, int period, int shift)
{
   int handle = iATR(_Symbol, tf, period);
   if(handle == INVALID_HANDLE)
      return 0.0;

   double buffer[];
   ArraySetAsSeries(buffer, true);
   if(CopyBuffer(handle, 0, shift, 1, buffer) <= 0)
   {
      IndicatorRelease(handle);
      return 0.0;
   }

   double value = buffer[0];
   IndicatorRelease(handle);
   return value;
}

int GetTrendDirection()
{
   if(!USE_TREND_FILTER)
      return 0;

   if(M2_ema50_h4 > M3_ema200_h4)
      return 1;
   if(M2_ema50_h4 < M3_ema200_h4)
      return -1;
   return 0;
}

double GetATRRatio()
{
   return M7_atr_ratio;
}

bool IsRecoveryLikely()
{
   if(M4_dist_to_ema50_pips > 100.0)
      return false;
   if(M7_atr_ratio > 2.0)
      return false;
   if(M10_nearest_level_dist_pips > 10000.0)
      return false;

   return (M4_dist_to_ema50_pips < 50.0 && M7_atr_ratio < 1.5 && M10_nearest_level_dist_pips < 30.0);
}

int GetEntrySignal()
{
   double ema_fast_curr = ReadMAValue(TF_SIGNAL, EMA_SIGNAL_FAST, 0);
   double ema_fast_prev = ReadMAValue(TF_SIGNAL, EMA_SIGNAL_FAST, 1);
   double ema_slow_curr = ReadMAValue(TF_SIGNAL, EMA_SIGNAL_SLOW, 0);
   double ema_slow_prev = ReadMAValue(TF_SIGNAL, EMA_SIGNAL_SLOW, 1);

   int trend = GetTrendDirection();
   bool cross_up = (ema_fast_prev <= ema_slow_prev) && (ema_fast_curr > ema_slow_curr);
   bool cross_down = (ema_fast_prev >= ema_slow_prev) && (ema_fast_curr < ema_slow_curr);

   if(cross_up && trend > 0)
      return 1;
   if(cross_down && trend < 0)
      return -1;

   return 0;
}

void UpdateMarketData()
{
   M1_price = (SymbolInfoDouble(_Symbol, SYMBOL_BID) + SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2.0;

   M2_ema50_h4 = ReadMAValue(TF_TREND, EMA_FAST, 0);
   M3_ema200_h4 = ReadMAValue(TF_TREND, EMA_SLOW, 0);

   double pip = ((_Digits == 3 || _Digits == 5) ? _Point * 10.0 : _Point);
   M4_dist_to_ema50_pips = MathAbs(M1_price - M2_ema50_h4) / pip;

   M5_atr_current = ReadATRValue(PERIOD_M15, ATR_PERIOD, 0);
   M6_atr_average = 0.0;
   for(int i = 1; i <= ATR_PERIOD; i++)
      M6_atr_average += ReadATRValue(PERIOD_M15, ATR_PERIOD, i);
   M6_atr_average /= ATR_PERIOD;
   M7_atr_ratio = (M6_atr_average > 0.0 ? M5_atr_current / M6_atr_average : 0.0);

   int bars_for_levels = 20;
   M8_support_h1 = iLow(_Symbol, PERIOD_H1, iLowest(_Symbol, PERIOD_H1, MODE_LOW, bars_for_levels, 0));
   M9_resistance_h1 = iHigh(_Symbol, PERIOD_H1, iHighest(_Symbol, PERIOD_H1, MODE_HIGH, bars_for_levels, 0));

   double dist_support = MathAbs(M1_price - M8_support_h1) / pip;
   double dist_resistance = MathAbs(M9_resistance_h1 - M1_price) / pip;
   M10_nearest_level_dist_pips = MathMin(dist_support, dist_resistance);
}

#endif
