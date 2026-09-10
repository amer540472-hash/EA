//+------------------------------------------------------------------+
//| ScalperSignals.mqh — entry signal engine                         |
//| Part of XAUUSD_Scalper EA (MetaTrader 5)                         |
//+------------------------------------------------------------------+
#ifndef SCALPER_SIGNALS_MQH
#define SCALPER_SIGNALS_MQH

#include "ScalperGlobals.mqh"

//+------------------------------------------------------------------+
//| M15 EMA trend: +1 up, -1 down, 0 flat/unknown                    |
//+------------------------------------------------------------------+
int GetTrendDir()
{
   double f[], s[];
   ArraySetAsSeries(f, true);
   ArraySetAsSeries(s, true);
   if(CopyBuffer(g_maFast, 0, 1, 3, f) < 3) return 0;
   if(CopyBuffer(g_maSlow, 0, 1, 3, s) < 3) return 0;

   double f1 = f[1], s1 = s[1];
   double f2 = f[2], s2 = s[2];
   int dir = 0;
   if(f1 > s1 && f2 >= s2)      dir = 1;
   else if(f1 < s1 && f2 <= s2) dir = -1;

   if(dir != 0 && UseADX)
   {
      double adx[];
      ArraySetAsSeries(adx, true);
      if(CopyBuffer(g_adx, 0, 1, 1, adx) < 1) return 0;
      if(adx[0] < MinADX) return 0;
   }
   return dir;
}

//+------------------------------------------------------------------+
//| ATR of the current chart timeframe, in points                    |
//+------------------------------------------------------------------+
double GetATRPoints()
{
   double a[];
   ArraySetAsSeries(a, true);
   if(CopyBuffer(g_atr, 0, 1, 1, a) < 1) return 0;
   return a[0] / _Point;
}

//+------------------------------------------------------------------+
//| RSI value at a given closed-bar shift                            |
//+------------------------------------------------------------------+
double GetRSI(int shift)
{
   double r[];
   ArraySetAsSeries(r, true);
   if(CopyBuffer(g_rsi, 0, shift, 1, r) < 1) return 50.0;
   return r[0];
}

//+------------------------------------------------------------------+
//| Bollinger squeeze → expansion breakout (+1/-1/0)                 |
//+------------------------------------------------------------------+
int BBSqueezeSignal()
{
   double base[], up[], lo[];
   ArraySetAsSeries(base, true);
   ArraySetAsSeries(up, true);
   ArraySetAsSeries(lo, true);

   int need = BBLookback + 3;
   if(need < 5) need = 5;
   if(CopyBuffer(g_bb, 0, 1, need, base) < need) return 0;
   if(CopyBuffer(g_bb, 1, 1, need, up)   < need) return 0;
   if(CopyBuffer(g_bb, 2, 1, need, lo)   < need) return 0;

   int k = BBLookback + 1;
   double bwNow  = (base[1] > 0) ? (up[1] - lo[1]) / base[1] : 0.0;
   double bwThen = (base[k] > 0) ? (up[k] - lo[k]) / base[k] : 0.0;
   if(bwThen <= 0) return 0;

   double close = iClose(_Symbol, _Period, 1);
   if(bwNow >= bwThen * BBExpandFactor)
   {
      if(close > up[1]) return 1;
      if(close < lo[1]) return -1;
   }
   return 0;
}

//+------------------------------------------------------------------+
//| N-bar range breakout (+1/-1/0)                                   |
//+------------------------------------------------------------------+
int RangeBreakSignal()
{
   int n = RangeBars;
   if(n < 2) n = 2;

   int hiIdx = iHighest(_Symbol, _Period, MODE_HIGH, n, 1);
   int loIdx = iLowest(_Symbol, _Period, MODE_LOW, n, 1);
   if(hiIdx < 0 || loIdx < 0) return 0;
   double hi = iHigh(_Symbol, _Period, hiIdx);
   double lo = iLow(_Symbol, _Period, loIdx);
   double close = iClose(_Symbol, _Period, 1);

   if(close > hi) return 1;
   if(close < lo) return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| RSI momentum confirmation                                        |
//+------------------------------------------------------------------+
bool RsiConfirm(int dir)
{
   double r = GetRSI(1);
   if(dir > 0) return (r >= RSIBuyLevel);
   if(dir < 0) return (r <= RSISellLevel);
   return false;
}

//+------------------------------------------------------------------+
//| Full signal evaluation                                           |
//+------------------------------------------------------------------+
bool EvaluateSignal(SSignal &sig)
{
   sig.dir = 0;
   sig.slPoints = 0;
   sig.tpPoints = 0;
   sig.reason = "";

   double atrPts = GetATRPoints();
   if(atrPts < MinATRPoints) { sig.reason = "ATR too low";  return false; }
   if(atrPts > MaxATRPoints) { sig.reason = "ATR too high"; return false; }

   int rawDir = 0;
   if(EntryMode == ENTRY_BB_SQUEEZE)  rawDir = BBSqueezeSignal();
   else                               rawDir = RangeBreakSignal();
   if(rawDir == 0) { sig.reason = "no trigger"; return false; }

   if(TrendMode == TREND_MODE_WITH)
   {
      int trend = GetTrendDir();
      if(trend == 0)      { sig.reason = "no clear trend"; return false; }
      if(trend != rawDir) { sig.reason = "against trend";  return false; }
   }

   if(!RsiConfirm(rawDir)) { sig.reason = "RSI filter"; return false; }

   double sl = atrPts * SL_ATRMult;
   if(sl < MinSLPoints) sl = MinSLPoints;
   if(sl > MaxSLPoints) sl = MaxSLPoints;

   sig.dir      = rawDir;
   sig.slPoints = sl;
   sig.tpPoints = sl * RR;
   sig.reason   = "signal";
   return true;
}

#endif // SCALPER_SIGNALS_MQH
