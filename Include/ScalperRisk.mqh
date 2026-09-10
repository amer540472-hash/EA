//+------------------------------------------------------------------+
//| ScalperRisk.mqh — gates, circuit breakers, position sizing       |
//| Part of XAUUSD_Scalper EA (MetaTrader 5)                         |
//+------------------------------------------------------------------+
#ifndef SCALPER_RISK_MQH
#define SCALPER_RISK_MQH

#include "ScalperGlobals.mqh"

//+------------------------------------------------------------------+
//| Current spread in points                                         |
//+------------------------------------------------------------------+
int SpreadPoints()
{
   return (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
}

//+------------------------------------------------------------------+
//| Care-mode flag (news / low liquidity detected via spread spike)  |
//+------------------------------------------------------------------+
bool IsCareMode()
{
   return g_careMode;
}

//+------------------------------------------------------------------+
//| Average spread over the last N bars (0 if not enough data)       |
//+------------------------------------------------------------------+
double AvgSpreadBars(int n)
{
   if(n < 2) n = 2;
   int s[];
   ArraySetAsSeries(s, true);
   int got = CopySpread(_Symbol, _Period, 1, n, s);
   if(got < 3) return 0.0;
   double sum = 0.0;
   for(int i = 0; i < got; i++)
      sum += (double)s[i];
   return sum / (double)got;
}

//+------------------------------------------------------------------+
//| Detect spread spikes => enter/exit care mode                     |
//+------------------------------------------------------------------+
void UpdateCareMode()
{
   double spread = (double)SpreadPoints();
   if(spread >= CareAbsTrigger)
   {
      double base = AvgSpreadBars(SpreadBaselineBars);
      if(base > 0 && spread >= base * CareSpreadFactor)
      {
         if(!g_careMode)
            LogEvent("care mode ON spread=" + IntegerToString((int)spread) + " baseline=" + DoubleToString(base, 1));
         g_careMode = true;
         return;
      }
   }
   if(g_careMode)
   {
      double base = AvgSpreadBars(SpreadBaselineBars);
      if(base <= 0 || spread < base * 1.5 || spread < CareAbsTrigger)
      {
         g_careMode = false;
         LogEvent("care mode OFF spread=" + IntegerToString((int)spread));
      }
   }
}

//+------------------------------------------------------------------+
//| Date keys for daily / weekly rollover                            |
//+------------------------------------------------------------------+
int DayKey()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.year * 1000 + dt.day_of_year;
}

int WeekKey()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int sundayDow = dt.day_of_year - dt.day_of_week; // day-of-year of this week's Sunday
   return dt.year * 1000 + (sundayDow / 7);
}

//+------------------------------------------------------------------+
//| Reset daily/weekly counters on rollover                          |
//+------------------------------------------------------------------+
void CheckRollover()
{
   int dk = DayKey();
   if(dk != g_dayKey)
   {
      g_dayKey = dk;
      g_tradesToday  = 0;
      g_winsToday    = 0;
      g_lossesToday  = 0;
      g_consecLosses = 0;
      g_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   }
   int wk = WeekKey();
   if(wk != g_weekKey)
   {
      g_weekKey = wk;
      g_weekStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   }
}

//+------------------------------------------------------------------+
//| Circuit breakers                                                 |
//+------------------------------------------------------------------+
bool DailyLossHit()
{
   if(DailyLossPct <= 0) return false;
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(g_dayStartBalance <= 0) return false;
   return ((g_dayStartBalance - bal) >= g_dayStartBalance * DailyLossPct / 100.0);
}

bool WeeklyLossHit()
{
   if(WeeklyLossPct <= 0) return false;
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(g_weekStartBalance <= 0) return false;
   return ((g_weekStartBalance - bal) >= g_weekStartBalance * WeeklyLossPct / 100.0);
}

bool DailyProfitHit()
{
   if(DailyProfitPct <= 0) return false;
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(g_dayStartBalance <= 0) return false;
   return ((bal - g_dayStartBalance) >= g_dayStartBalance * DailyProfitPct / 100.0);
}

bool ConsecPaused()
{
   return (g_pauseUntil != 0 && TimeCurrent() < g_pauseUntil);
}

bool CooldownActive()
{
   if(g_lastTradeTime == 0) return false;
   if(CooldownBars <= 0) return false;
   int bs = iBarShift(_Symbol, _Period, g_lastTradeTime, false);
   if(bs < 0) bs = 1000000;
   return (bs < CooldownBars);
}

//+------------------------------------------------------------------+
//| Session / news window helpers (all times are broker server time) |
//+------------------------------------------------------------------+
bool IsSessionActive()
{
   if(!UseSessionFilter) return true;
   string now = TimeToString(TimeCurrent(), TIME_MINUTES);
   bool in1 = (now >= Session1Start && now <= Session1End);
   bool in2 = (now >= Session2Start && now <= Session2End);
   return (in1 || in2);
}

bool IsNewsBlockWindow()
{
   if(NewsBlockStart == "" || NewsBlockEnd == "") return false;
   string now = TimeToString(TimeCurrent(), TIME_MINUTES);
   if(NewsBlockStart <= NewsBlockEnd)
      return (now >= NewsBlockStart && now <= NewsBlockEnd);
   else // window wraps midnight
      return (now >= NewsBlockStart || now <= NewsBlockEnd);
}

//+------------------------------------------------------------------+
//| Volume / price normalization                                     |
//+------------------------------------------------------------------+
double NormalizeVolume(double vol)
{
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double min  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step <= 0) step = 0.01;
   vol = MathFloor(vol / step + 0.0000001) * step;
   vol = NormalizeDouble(vol, 2);
   if(vol < min) vol = min;
   if(vol > max) vol = max;
   return vol;
}

double NormalizePrice(double price)
{
   return NormalizeDouble(price, _Digits);
}

//+------------------------------------------------------------------+
//| Fixed-fractional lot sizing from SL distance (clamped to min)    |
//+------------------------------------------------------------------+
double ComputeLots(double riskPct, double slPoints, double &riskMoney)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   riskMoney = 0.0;
   if(balance <= 0) return minLot;

   riskMoney = balance * riskPct / 100.0;

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickValue <= 0 || tickSize <= 0) return minLot;

   double priceDist = slPoints * _Point;
   double ticks     = priceDist / tickSize;
   if(ticks <= 0) return minLot;

   double lossPerLot = ticks * tickValue;
   if(lossPerLot <= 0) return minLot;

   return NormalizeVolume(riskMoney / lossPerLot);
}

//+------------------------------------------------------------------+
//| Master gate: can we open a new trade right now?                  |
//+------------------------------------------------------------------+
bool CanOpenNewTrade(string &why)
{
   why = "";
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))           { why = "algo trading disabled";        return false; }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) { why = "terminal trading disabled";    return false; }
   if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT))    { why = "EA trading disabled (account)"; return false; }
   if(PositionOpen())                               { why = "position already open";        return false; }
   if(!IsSessionActive())                           { why = "outside session";              return false; }
   if(IsNewsBlockWindow())                          { why = "manual news block";            return false; }

   int spread = SpreadPoints();
   double maxSpread = IsCareMode() ? CareSpreadCeil : MaxSpreadPoints;
   if(spread > maxSpread)                           { why = "spread too wide";              return false; }

   if(DailyLossHit())                               { why = "daily loss limit";             return false; }
   if(WeeklyLossHit())                              { why = "weekly loss limit";            return false; }
   if(DailyProfitHit())                             { why = "daily profit target";          return false; }
   if(ConsecPaused())                               { why = "consecutive-loss pause";       return false; }
   if(g_tradesToday >= MaxTradesPerDay)             { why = "max trades today";              return false; }
   if(CooldownActive())                             { why = "cooldown";                      return false; }
   return true;
}

#endif // SCALPER_RISK_MQH
