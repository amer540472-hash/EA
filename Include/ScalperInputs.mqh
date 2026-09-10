//+------------------------------------------------------------------+
//| ScalperInputs.mqh — all user inputs (shown in the Inputs tab)    |
//| Part of XAUUSD_Scalper EA (MetaTrader 5)                         |
//+------------------------------------------------------------------+
#ifndef SCALPER_INPUTS_MQH
#define SCALPER_INPUTS_MQH

#include "ScalperDefines.mqh"

input group "=== General ==="
input long            Magic            = 20260910;       // Magic number
input bool            AnySymbol        = false;          // Allow any symbol (else XAUUSD only)
input ENUM_ENTRY_MODE EntryMode        = ENTRY_BB_SQUEEZE; // Entry trigger
input ENUM_TREND_MODE TrendMode        = TREND_MODE_BOTH;  // Trend filter
input bool            UseADX           = false;          // Use ADX trend filter
input int             MinADX           = 20;             // Min ADX (if UseADX)

input group "=== Risk & Money ==="
input double RiskPercent       = 1.0;   // Risk % per trade
input double NewsRiskMult      = 0.5;   // Risk multiplier in care mode (news)
input double RR                = 2.0;   // Reward:Risk (TP = RR x SL)
input double SL_ATRMult        = 1.5;   // SL = ATR x mult
input int    MinSLPoints       = 80;    // Min SL distance (points)
input int    MaxSLPoints       = 300;   // Max SL distance (points)
input int    MaxDeviationPoints= 30;    // Max slippage (points)

input group "=== Trade management ==="
input double BreakevenR      = 0.5;     // Move SL to breakeven at +R
input double TrailR          = 1.0;     // Start trailing at +R
input double TrailDistR      = 0.4;     // Trailing distance (x SL)
input int    MaxBarsInTrade  = 30;      // Time-stop: close loser after N bars (0 = off)

input group "=== Sessions ==="
input bool   UseSessionFilter = false;  // Limit sessions (off = trade all)
input string Session1Start    = "08:00"; // Session 1 start (server time)
input string Session1End      = "12:00"; // Session 1 end
input string Session2Start    = "13:30"; // Session 2 start
input string Session2End      = "17:00"; // Session 2 end

input group "=== Spread / news care ==="
input int    MaxSpreadPoints    = 70;   // Max spread normal (points)
input int    CareAbsTrigger     = 40;   // Spread level that can trigger care mode
input int    CareSpreadCeil     = 160;  // Max spread in care mode (points)
input double CareSpreadFactor   = 3.0;  // Baseline x factor => care mode
input int    SpreadBaselineBars = 30;   // Bars used for the spread baseline
input string NewsBlockStart     = "";   // Manual block start "HH:MM" (empty = off)
input string NewsBlockEnd       = "";   // Manual block end "HH:MM"

input group "=== Limits ==="
input int    MaxTradesPerDay    = 40;   // Max trades per day
input double DailyLossPct       = 5.0;  // Daily loss limit %
input double WeeklyLossPct      = 10.0; // Weekly loss limit %
input int    MaxConsecLosses    = 4;    // Max consecutive losses
input int    ConsecLossPauseMin = 60;   // Pause (minutes) after a losing streak
input double DailyProfitPct     = 15.0; // Daily profit target % (0 = off)
input int    CooldownBars       = 2;    // Min bars between entries

input group "=== Signal: ATR ==="
input int ATRPeriod    = 14;   // ATR period
input int MinATRPoints = 20;   // Dead-market floor (points)
input int MaxATRPoints = 600;  // Too-volatile ceiling (points)

input group "=== Signal: trend ==="
input int MAFast = 21;   // Fast EMA (M15)
input int MASlow = 50;   // Slow EMA (M15)

input group "=== Signal: entry ==="
input int    BBPeriod      = 20;   // Bollinger period
input double BBDev         = 2.0;  // Bollinger deviation
input double BBExpandFactor= 1.8;  // Bandwidth expansion factor
input int    BBLookback    = 10;   // Squeeze lookback bars
input int    RangeBars     = 12;   // Range breakout bars
input int    RSIPeriod     = 14;   // RSI period
input double RSIBuyLevel   = 55.0; // RSI long confirm
input double RSISellLevel  = 45.0; // RSI short confirm

#endif // SCALPER_INPUTS_MQH
