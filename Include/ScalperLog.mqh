//+------------------------------------------------------------------+
//| ScalperLog.mqh — CSV logging + helpers                           |
//| Part of XAUUSD_Scalper EA (MetaTrader 5)                         |
//+------------------------------------------------------------------+
#ifndef SCALPER_LOG_MQH
#define SCALPER_LOG_MQH

#include "ScalperGlobals.mqh"

//+------------------------------------------------------------------+
//| Append one raw line to the CSV log                               |
//+------------------------------------------------------------------+
void WriteLog(string line)
{
   int h = FileOpen(LOG_FILE, FILE_READ | FILE_WRITE | FILE_ANSI | FILE_SHARED_READ);
   if(h == INVALID_HANDLE)
      return;
   FileSeek(h, 0, SEEK_END);
   FileWriteString(h, line + "\r\n");
   FileClose(h);
}

//+------------------------------------------------------------------+
//| Create the log file and write the header if it is new            |
//+------------------------------------------------------------------+
void LogInit()
{
   int h = FileOpen(LOG_FILE, FILE_READ | FILE_WRITE | FILE_ANSI | FILE_SHARED_READ);
   if(h == INVALID_HANDLE)
      return;
   if(FileSize(h) <= 0)
      FileWriteString(h, "time,event,ticket,net,r,balance,equity,spread,care,note\r\n");
   FileClose(h);
}

//+------------------------------------------------------------------+
//| Write one structured row                                         |
//+------------------------------------------------------------------+
void LogRow(string event, ulong ticket, double netProfit, double r, string note)
{
   string line = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS) + "," +
                 event + "," +
                 IntegerToString((long)ticket) + "," +
                 DoubleToString(netProfit, 2) + "," +
                 DoubleToString(r, 2) + "," +
                 DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + "," +
                 DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + "," +
                 IntegerToString(SpreadPoints()) + "," +
                 IntegerToString(g_careMode ? 1 : 0) + "," +
                 note;
   WriteLog(line);
}

//+------------------------------------------------------------------+
//| Generic event                                                    |
//+------------------------------------------------------------------+
void LogEvent(string note)
{
   LogRow("event", 0, 0.0, 0.0, note);
}

//+------------------------------------------------------------------+
//| Trade-related event (open / close / be / trail / time-stop)      |
//+------------------------------------------------------------------+
void LogTrade(string event, ulong ticket, double netProfit, double r, string note)
{
   LogRow(event, ticket, netProfit, r, note);
}

#endif // SCALPER_LOG_MQH
