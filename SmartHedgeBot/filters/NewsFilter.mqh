#ifndef __SMART_HEDGE_BOT_NEWS_FILTER_MQH__
#define __SMART_HEDGE_BOT_NEWS_FILTER_MQH__

bool IsNewsBlocked()
{
   if(!USE_NEWS_FILTER)
      return false;

#if defined(__MQL5__)
   MqlCalendarValue values[];
   datetime from_time = TimeCurrent() - (NEWS_PAUSE_AFTER * 60);
   datetime to_time = TimeCurrent() + (NEWS_PAUSE_BEFORE * 60);

   ResetLastError();
   int total = CalendarValueHistory(values, from_time, to_time, "", "");
   if(total <= 0)
      return false;

   for(int i = 0; i < total; i++)
   {
      datetime event_time = values[i].time;
      if(event_time >= from_time && event_time <= to_time)
         return true;
   }
#endif

   return false;
}

#endif
