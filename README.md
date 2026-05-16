# SmartHedgeBot (MQL5 / MT5)

This repository now contains a Smart Hedge Bot implementation based on the technical specification from the issue.

## Structure

- `/SmartHedgeBot/SmartHedgeBot.mq5` — EA entry point
- `/SmartHedgeBot/inputs/Settings.mqh` — grouped input parameters
- `/SmartHedgeBot/core/MarketAnalyzer.mqh` — market analysis data/functions (M1-M10)
- `/SmartHedgeBot/core/PositionManager.mqh` — position analysis data/functions (G1-G8)
- `/SmartHedgeBot/core/DangerScore.mqh` — weighted danger score calculation
- `/SmartHedgeBot/logic/OrderOpen.mqh` — order-open conditions and execution
- `/SmartHedgeBot/logic/OrderClose.mqh` — close priority and close routines
- `/SmartHedgeBot/logic/SituationHandler.mqh` — action plan by score ranges
- `/SmartHedgeBot/filters/SwapFilter.mqh` — swap-based close protection
- `/SmartHedgeBot/filters/NewsFilter.mqh` — high-impact news pause filter
