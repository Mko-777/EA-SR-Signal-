#ifndef __SMART_HEDGE_BOT_SETTINGS_MQH__
#define __SMART_HEDGE_BOT_SETTINGS_MQH__

input group "=== ТРЕНД ==="
input bool   USE_TREND_FILTER    = true;
input int    EMA_SLOW            = 200;
input int    EMA_FAST            = 50;
input ENUM_TIMEFRAMES TF_TREND   = PERIOD_H4;

input group "=== СИГНАЛ ВХОДА ==="
input bool   USE_SIGNAL_FILTER   = true;
input int    EMA_SIGNAL_FAST     = 8;
input int    EMA_SIGNAL_SLOW     = 18;
input ENUM_TIMEFRAMES TF_SIGNAL  = PERIOD_M15;

input group "=== ATR ==="
input bool   USE_ATR             = true;
input int    ATR_PERIOD          = 14;
input double ATR_MULTIPLIER      = 1.5;

input group "=== DANGER SCORE ==="
input bool   USE_DANGER_SCORE    = true;
input double WEIGHT_DRAWDOWN     = 40.0;
input double WEIGHT_IMBALANCE    = 20.0;
input double WEIGHT_ATR          = 15.0;
input double WEIGHT_AGE          = 15.0;
input double WEIGHT_SWAP         = 10.0;
input int    SCORE_CAUTION       = 30;
input int    SCORE_DANGER        = 50;
input int    SCORE_CRITICAL      = 70;
input int    SCORE_EMERGENCY     = 85;

input group "=== РИСК ==="
input double RISK_PERCENT        = 1.0;
input double MAX_DRAWDOWN        = 3.0;
input int    MAX_POSITIONS_SIDE  = 3;
input double LOT_SIZE            = 0.01;
input int    STOP_LOSS_PIPS      = 150;

input group "=== СВОП ==="
input bool   USE_SWAP_FILTER     = true;
input int    MAX_ORDER_AGE_HOURS = 48;
input double MAX_SWAP_PER_ORDER  = 10.0;

input group "=== НОВОСТИ ==="
input bool   USE_NEWS_FILTER     = true;
input int    NEWS_PAUSE_BEFORE   = 30;
input int    NEWS_PAUSE_AFTER    = 15;

input group "=== СИСТЕМА ==="
input ulong  MAGIC_NUMBER        = 770077;
input bool   SHOW_DEBUG_LOGS      = true;

#endif
