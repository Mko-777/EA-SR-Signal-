#ifndef __SMART_HEDGE_BOT_ORDER_OPEN_MQH__
#define __SMART_HEDGE_BOT_ORDER_OPEN_MQH__

bool IsNewsBlocked();

double CalculateRiskBasedLot(int sl_pips)
{
   if(sl_pips <= 0)
      return LOT_SIZE;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_money = balance * (RISK_PERCENT / 100.0);

   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double pip = ((_Digits == 3 || _Digits == 5) ? _Point * 10.0 : _Point);

   double pip_value = 0.0;
   if(tick_size > 0.0)
      pip_value = tick_value * (pip / tick_size);

   double lot = LOT_SIZE;
   if(pip_value > 0.0)
      lot = risk_money / (sl_pips * pip_value);

   double min_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lot = MathMax(lot, min_vol);
   lot = MathMin(lot, max_vol);
   lot = MathRound(lot / step) * step;
   return lot;
}

bool CheckAllConditions()
{
   double score = CalculateDangerScore();
   if(score >= SCORE_CAUTION)
   {
      if(SHOW_DEBUG_LOGS) Print("Order blocked: danger score >= caution threshold");
      return false;
   }

   int buys = GetPositionCount(POSITION_TYPE_BUY);
   int sells = GetPositionCount(POSITION_TYPE_SELL);
   if(MathMax(buys, sells) >= MAX_POSITIONS_SIDE)
   {
      if(SHOW_DEBUG_LOGS) Print("Order blocked: max positions per side reached");
      return false;
   }

   if(GetTotalDrawdownPercent() >= MAX_DRAWDOWN)
   {
      if(SHOW_DEBUG_LOGS) Print("Order blocked: drawdown limit reached");
      return false;
   }

   if(GetEntrySignal() == 0)
   {
      if(SHOW_DEBUG_LOGS) Print("Order blocked: no entry signal");
      return false;
   }

   if(!IsRecoveryLikely())
   {
      if(SHOW_DEBUG_LOGS) Print("Order blocked: recovery not likely");
      return false;
   }

   if(USE_NEWS_FILTER && IsNewsBlocked())
   {
      if(SHOW_DEBUG_LOGS) Print("Order blocked: news filter");
      return false;
   }

   return true;
}

bool OpenOrder(int signal)
{
   if(signal == 0)
      return false;

   double volume = CalculateRiskBasedLot(STOP_LOSS_PIPS);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double pip = ((_Digits == 3 || _Digits == 5) ? _Point * 10.0 : _Point);
   double sl_buy = ask - STOP_LOSS_PIPS * pip;
   double sl_sell = bid + STOP_LOSS_PIPS * pip;

   bool result = false;
   if(signal > 0)
      result = trade.Buy(volume, _Symbol, ask, sl_buy, 0, "SmartHedgeBot Buy");
   else if(signal < 0)
      result = trade.Sell(volume, _Symbol, bid, sl_sell, 0, "SmartHedgeBot Sell");

   if(!result && SHOW_DEBUG_LOGS)
      Print("OpenOrder failed, retcode=", trade.ResultRetcode());

   return result;
}

void OpenCompensatingOrder()
{
   int trend = GetTrendDirection();
   if(trend == 0)
      return;
   OpenOrder(trend);
}

#endif
