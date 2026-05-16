#ifndef __SMART_HEDGE_BOT_DANGER_SCORE_MQH__
#define __SMART_HEDGE_BOT_DANGER_SCORE_MQH__

double CalculateDangerScore()
{
   if(!USE_DANGER_SCORE)
      return 0.0;

   double score = 0.0;

   double drawdown_normalized = MathMin(G7_drawdown_percent / MathMax(MAX_DRAWDOWN, 0.0001), 1.0);
   score += drawdown_normalized * WEIGHT_DRAWDOWN;

   double imbalance_normalized = G4_imbalance_percent / 100.0;
   score += imbalance_normalized * WEIGHT_IMBALANCE;

   double atr_normalized = MathMin(M7_atr_ratio / 3.0, 1.0);
   score += atr_normalized * WEIGHT_ATR;

   double age_normalized = MathMin(G5_oldest_order_age_hours / MathMax(MAX_ORDER_AGE_HOURS, 1), 1.0);
   score += age_normalized * WEIGHT_AGE;

   double swap_normalized = MathMin(MathAbs(G8_total_swap) / 50.0, 1.0);
   score += swap_normalized * WEIGHT_SWAP;

   return MathMin(score, 100.0);
}

#endif
