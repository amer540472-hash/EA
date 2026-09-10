//+------------------------------------------------------------------+
//| XAUUSD_Scalper.mq5                                               |
//| Native MQL5 scalping EA for XAUUSD (gold) on M1/M3.              |
//| Session-optional, trend-aligned, volatility-gated breakouts,     |
//| fixed-fractional sizing, strict circuit breakers, no martingale. |
//|                                                                  |
//| ⚠️ Targets (60% win rate, PF≈3, fast growth) are design goals,   |
//|    NOT guarantees. Demo first. Risk only what you can lose.      |
//+------------------------------------------------------------------+
#property copyright "EA project — arena session"
#property link      ""
#property version   "1.00"
#property description "XAUUSD scalping EA for MetaTrader 5."
#property description "M1/M3 breakouts, ATR stops, 2:1 RR, care-mode news handling,"
#property description "daily/weekly loss limits, consecutive-loss pause. No martingale."

#include "ScalperDefines.mqh"
#include "ScalperInputs.mqh"
#include "ScalperGlobals.mqh"
#include "ScalperLog.mqh"
#include "ScalperSignals.mqh"
#include "ScalperRisk.mqh"
#include "ScalperTrade.mqh"

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   if(!AnySymbol && _Symbol != "XAUUSD")
   {
      Print(EA_NAME, ": attach to XAUUSD (or set AnySymbol=true)");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) Print(EA_NAME, ": WARNING - terminal auto-trading is OFF");
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))            Print(EA_NAME, ": WARNING - algo trading is OFF for this EA");
   if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT))     Print(EA_NAME, ": WARNING - EA trading is disabled on this account");

   g_maFast = iMA(_Symbol, PERIOD_M15, MAFast, 0, MODE_EMA, PRICE_CLOSE);
   g_maSlow = iMA(_Symbol, PERIOD_M15, MASlow, 0, MODE_EMA, PRICE_CLOSE);
   g_atr    = iATR(_Symbol, _Period, ATRPeriod);
   g_rsi    = iRSI(_Symbol, _Period, RSIPeriod, PRICE_CLOSE);
   g_bb     = iBands(_Symbol, _Period, BBPeriod, 0, BBDev, PRICE_CLOSE);
   g_adx    = iADX(_Symbol, PERIOD_M15, 14);

   if(g_maFast == INVALID_HANDLE || g_maSlow == INVALID_HANDLE || g_atr == INVALID_HANDLE ||
      g_rsi    == INVALID_HANDLE || g_bb     == INVALID_HANDLE || g_adx == INVALID_HANDLE)
   {
      Print(EA_NAME, ": failed to create indicator handles");
      return INIT_FAILED;
   }

   g_lastBarTime = 0;
   g_dayKey      = -1;
   g_weekKey     = -1;
   g_tradesToday  = 0;
   g_winsToday    = 0;
   g_lossesToday  = 0;
   g_consecLosses = 0;
   g_pauseUntil    = 0;
   g_lastTradeTime = 0;
   g_careMode      = false;
   g_dayStartBalance  = AccountInfoDouble(ACCOUNT_BALANCE);
   g_weekStartBalance = g_dayStartBalance;
   g_lastSkipReason = "";

   CheckRollover();
   LogInit();

   LogEvent("init " + _Symbol + " " + EnumToString(_Period) +
            " mode=" + EnumToString(EntryMode) + " trend=" + EnumToString(TrendMode));
   Print(EA_NAME, " initialized | spread=", SpreadPoints(),
         " tickValue=", SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE),
         " minLot=", SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN),
         " stopsLevel=", SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL),
         " serverTime=", TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES));
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   LogEvent("deinit reason=" + IntegerToString(reason));
   if(g_maFast != INVALID_HANDLE) IndicatorRelease(g_maFast);
   if(g_maSlow != INVALID_HANDLE) IndicatorRelease(g_maSlow);
   if(g_atr    != INVALID_HANDLE) IndicatorRelease(g_atr);
   if(g_rsi    != INVALID_HANDLE) IndicatorRelease(g_rsi);
   if(g_bb     != INVALID_HANDLE) IndicatorRelease(g_bb);
   if(g_adx    != INVALID_HANDLE) IndicatorRelease(g_adx);
   Comment("");
}

//+------------------------------------------------------------------+
//| Track closes for win/loss counters + consecutive-loss pause      |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   ulong deal = trans.deal;
   if(deal == 0) return;
   if(!HistoryDealSelect(deal)) return;
   if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol) return;
   if(HistoryDealGetInteger(deal, DEAL_MAGIC) != Magic) return;

   long entry = HistoryDealGetInteger(deal, DEAL_ENTRY);
   if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT)
   {
      double profit = HistoryDealGetDouble(deal, DEAL_PROFIT);
      double comm   = HistoryDealGetDouble(deal, DEAL_COMMISSION);
      double sw     = HistoryDealGetDouble(deal, DEAL_SWAP);
      double net    = profit + comm + sw;

      if(net > 0) { g_winsToday++;    g_consecLosses = 0; }
      else        { g_lossesToday++;  g_consecLosses++; }

      if(g_consecLosses >= MaxConsecLosses)
      {
         g_pauseUntil = TimeCurrent() + ConsecLossPauseMin * 60;
         g_consecLosses = 0;
         LogEvent("consecutive-loss pause for " + IntegerToString(ConsecLossPauseMin) + " min");
      }
      LogTrade("close", deal, net, 0.0, "net=" + DoubleToString(net, 2));
   }
}

//+------------------------------------------------------------------+
//| Main loop: one pass per new bar                                  |
//+------------------------------------------------------------------+
void OnTick()
{
   CheckRollover();
   UpdateCareMode();

   datetime barTime = iTime(_Symbol, _Period, 0);
   if(barTime == g_lastBarTime)
   {
      UpdatePanel();
      return;
   }
   g_lastBarTime = barTime;

   //--- manage an existing position
   ulong ticket = GetPositionTicket();
   if(ticket != 0)
   {
      ManagePosition(ticket);
      UpdatePanel();
      return;
   }

   //--- no open position: clear the R-base before evaluating a new entry
   g_riskDist = 0.0;

   //--- try to open a new trade
   string why = "";
   if(!CanOpenNewTrade(why))
   {
      if(why != "" && why != g_lastSkipReason)
      {
         g_lastSkipReason = why;
         Print(EA_NAME, " skip: ", why);
         LogEvent("gate: " + why);
      }
      UpdatePanel();
      return;
   }
   g_lastSkipReason = "";

   SSignal sig;
   if(EvaluateSignal(sig))
   {
      if(OpenTrade(sig.dir, sig.slPoints, sig.tpPoints))
      {
         g_tradesToday++;
         g_lastTradeTime = TimeCurrent();
      }
   }
   UpdatePanel();
}

//+------------------------------------------------------------------+
//| On-chart status panel                                            |
//+------------------------------------------------------------------+
void UpdatePanel()
{
   string care = g_careMode ? ("CARE risk x" + DoubleToString(NewsRiskMult, 2)) : "normal";
   int    spread = SpreadPoints();
   double atr    = GetATRPoints();

   string s = EA_NAME + "  [" + _Symbol + " " + EnumToString(_Period) + "]";
   s += "\nEntry: " + EnumToString(EntryMode) + " | Trend: " + EnumToString(TrendMode) + " | " + care;
   s += "\nSpread: " + IntegerToString(spread) + " pts | ATR: " + DoubleToString(atr, 1) + " pts";
   s += "\nTrades today: " + IntegerToString(g_tradesToday) + "/" + IntegerToString(MaxTradesPerDay) +
        "   W:" + IntegerToString(g_winsToday) + "  L:" + IntegerToString(g_lossesToday);
   s += "\nConsec losses: " + IntegerToString(g_consecLosses) +
        " | Paused: " + (ConsecPaused() ? "YES" : "no");
   s += "\nBalance: " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) +
        "   Equity: " + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2);

   double dayPnL = (g_dayStartBalance > 0) ?
                   (AccountInfoDouble(ACCOUNT_BALANCE) - g_dayStartBalance) / g_dayStartBalance * 100.0 : 0.0;
   s += "\nDay P/L: " + DoubleToString(dayPnL, 2) + "%   (start " + DoubleToString(g_dayStartBalance, 2) + ")";

   if(PositionOpen())
   {
      ulong t = GetPositionTicket();
      if(t != 0)
      {
         double open = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl   = PositionGetDouble(POSITION_SL);
         double cur  = PositionGetDouble(POSITION_PRICE_CURRENT);
         double prof = PositionGetDouble(POSITION_PROFIT);
         long   ptype = PositionGetInteger(POSITION_TYPE);
         double rDist = MathAbs(open - sl);
         double r = (rDist > 0) ? ((ptype == POSITION_TYPE_BUY) ? (cur - open) / rDist
                                                                : (open - cur) / rDist) : 0.0;
         s += "\nPosition: " + ((ptype == POSITION_TYPE_BUY) ? "LONG" : "SHORT") +
              " " + DoubleToString(PositionGetDouble(POSITION_VOLUME), 2) + " lots" +
              "   P/L " + DoubleToString(prof, 2) + "   R " + DoubleToString(r, 2);
      }
   }
   Comment(s);
}

//+------------------------------------------------------------------+
//| Custom optimization fitness for the Strategy Tester              |
//+------------------------------------------------------------------+
double OnTester()
{
   double pf     = TesterStatistics(STAT_PROFIT_FACTOR);
   double trades = TesterStatistics(STAT_TRADES);
   double wins   = TesterStatistics(STAT_PROFIT_TRADES);
   double dd     = TesterStatistics(STAT_BALANCE_DD_RELATIVE) / 100.0;
   double wr     = (trades > 0) ? wins / trades : 0.0;

   double fitness = pf * (0.5 + wr) * (1.0 - dd);
   if(trades < 30) fitness *= trades / 30.0;   // penalize tiny samples
   return fitness;
}
