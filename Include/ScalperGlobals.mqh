//+------------------------------------------------------------------+
//| ScalperGlobals.mqh — global state + function prototypes          |
//| Part of XAUUSD_Scalper EA (MetaTrader 5)                         |
//+------------------------------------------------------------------+
#ifndef SCALPER_GLOBALS_MQH
#define SCALPER_GLOBALS_MQH

#include "ScalperDefines.mqh"

//--- indicator handles
int g_maFast = INVALID_HANDLE;
int g_maSlow = INVALID_HANDLE;
int g_atr    = INVALID_HANDLE;
int g_rsi    = INVALID_HANDLE;
int g_bb     = INVALID_HANDLE;
int g_adx    = INVALID_HANDLE;

//--- bar / day / week tracking
datetime g_lastBarTime = 0;
int      g_dayKey      = -1;
int      g_weekKey     = -1;

//--- session counters
int    g_tradesToday  = 0;
int    g_winsToday    = 0;
int    g_lossesToday  = 0;
int    g_consecLosses = 0;
double g_dayStartBalance  = 0.0;
double g_weekStartBalance = 0.0;

//--- cooldown / pause / care state
datetime g_pauseUntil     = 0;
datetime g_lastTradeTime  = 0;
bool     g_careMode       = false;
string   g_lastSkipReason = "";
double   g_riskDist       = 0.0; // original SL distance (price) for R-base

//--- function prototypes (definitions live in the modules below)
bool  EvaluateSignal(SSignal &sig);
bool  CanOpenNewTrade(string &why);
bool  OpenTrade(int dir, double slPoints, double tpPoints);
void  ManagePosition(ulong ticket);
ulong GetPositionTicket();
bool  PositionOpen();
int   SpreadPoints();
double GetATRPoints();
bool  IsCareMode();
bool  ConsecPaused();
void  CheckRollover();
void  UpdateCareMode();
void  LogInit();
void  LogEvent(string note);
void  LogTrade(string event, ulong ticket, double netProfit, double r, string note);
void  UpdatePanel();

#endif // SCALPER_GLOBALS_MQH
