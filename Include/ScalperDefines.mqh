//+------------------------------------------------------------------+
//| ScalperDefines.mqh — enums, structs, constants                   |
//| Part of XAUUSD_Scalper EA (MetaTrader 5)                         |
//+------------------------------------------------------------------+
#ifndef SCALPER_DEFINES_MQH
#define SCALPER_DEFINES_MQH

//--- trend filter mode
enum ENUM_TREND_MODE
{
   TREND_MODE_OFF  = 0, // Off — trade all setups
   TREND_MODE_WITH = 1, // Only with the M15 trend
   TREND_MODE_BOTH = 2  // Ignore trend (long & short freely)
};

//--- entry trigger
enum ENUM_ENTRY_MODE
{
   ENTRY_BB_SQUEEZE  = 0, // Bollinger squeeze breakout
   ENTRY_RANGE_BREAK = 1  // N-bar range breakout
};

//--- a candidate trade signal produced by the signal engine
struct SSignal
{
   int    dir;        // +1 = long, -1 = short, 0 = none
   double slPoints;   // stop-loss distance (points)
   double tpPoints;   // take-profit distance (points)
   string reason;     // human-readable result / reject reason
};

//--- constants
#define EA_NAME   "XAUUSD_Scalper"
#define LOG_FILE  "XAUUSD_Scalper_Log.csv"

#endif // SCALPER_DEFINES_MQH
