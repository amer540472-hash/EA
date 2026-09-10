//+------------------------------------------------------------------+
//| ScalperTrade.mqh — order opening, SL/TP management, closing      |
//| Part of XAUUSD_Scalper EA (MetaTrader 5)                         |
//+------------------------------------------------------------------+
#ifndef SCALPER_TRADE_MQH
#define SCALPER_TRADE_MQH

#include "ScalperGlobals.mqh"

//+------------------------------------------------------------------+
//| Pick an allowed order-filling mode                               |
//+------------------------------------------------------------------+
int FillingMode()
{
   long fm = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((fm & SYMBOL_FILLING_FOK) != 0) return (int)ORDER_FILLING_FOK;
   if((fm & SYMBOL_FILLING_IOC) != 0) return (int)ORDER_FILLING_IOC;
   return (int)ORDER_FILLING_RETURN;
}

//+------------------------------------------------------------------+
//| Send an order with a short retry loop on requote/price changes   |
//+------------------------------------------------------------------+
bool SendOrder(MqlTradeRequest &req, MqlTradeResult &res, int attempts)
{
   for(int i = 0; i < attempts; i++)
   {
      res.retcode = 0;
      bool ok = OrderSend(req, res);
      if(ok && (res.retcode == TRADE_RETCODE_DONE ||
                res.retcode == TRADE_RETCODE_DONE_PARTIAL ||
                res.retcode == TRADE_RETCODE_PLACED))
         return true;
      if(res.retcode == TRADE_RETCODE_REQUOTE ||
         res.retcode == TRADE_RETCODE_PRICE_CHANGED ||
         res.retcode == TRADE_RETCODE_PRICE_OFF ||
         res.retcode == TRADE_RETCODE_TIMEOUT)
      {
         Sleep(50);
         continue;
      }
      return false;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Find our position (by symbol + magic) and return its ticket      |
//+------------------------------------------------------------------+
ulong GetPositionTicket()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != Magic) continue;
      return t;
   }
   return 0;
}

bool PositionOpen()
{
   return (GetPositionTicket() != 0);
}

//+------------------------------------------------------------------+
//| Open a market order with SL/TP                                   |
//+------------------------------------------------------------------+
bool OpenTrade(int dir, double slPoints, double tpPoints)
{
   double riskPct = RiskPercent;
   if(g_careMode) riskPct *= NewsRiskMult;

   double riskMoney = 0.0;
   double lots = ComputeLots(riskPct, slPoints, riskMoney);
   if(lots < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) return false;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double stopsLevel = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;

   double sl = 0.0, tp = 0.0;
   if(dir > 0)
   {
      sl = ask - slPoints * _Point;
      tp = ask + tpPoints * _Point;
      if(ask - sl < stopsLevel) sl = ask - stopsLevel;
      if(tp - ask < stopsLevel) tp = ask + stopsLevel;
   }
   else
   {
      sl = bid + slPoints * _Point;
      tp = bid - tpPoints * _Point;
      if(sl - bid < stopsLevel) sl = bid + stopsLevel;
      if(bid - tp < stopsLevel) tp = bid - stopsLevel;
   }
   sl = NormalizePrice(sl);
   tp = NormalizePrice(tp);

   g_riskDist = slPoints * _Point;   // remember the R-base for trailing/BE

   MqlTradeRequest req = {0};
   MqlTradeResult  res = {0};
   req.action       = TRADE_ACTION_DEAL;
   req.symbol       = _Symbol;
   req.volume       = lots;
   req.type         = (dir > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   req.price        = (dir > 0) ? ask : bid;
   req.sl           = sl;
   req.tp           = tp;
   req.deviation    = MaxDeviationPoints;
   req.magic        = Magic;
   req.comment      = EA_NAME;
   req.type_filling = (ENUM_ORDER_TYPE_FILLING)FillingMode();

   if(!SendOrder(req, res, 5))
   {
      LogEvent("open FAILED dir=" + IntegerToString(dir) + " lots=" + DoubleToString(lots, 2) +
               " retcode=" + IntegerToString(res.retcode));
      return false;
   }

   LogTrade("open", 0, 0.0, 0.0,
            "dir=" + IntegerToString(dir) + " lots=" + DoubleToString(lots, 2) +
            " sl=" + DoubleToString(sl, _Digits) + " tp=" + DoubleToString(tp, _Digits) +
            " risk$=" + DoubleToString(riskMoney, 2));
   Print(EA_NAME, " opened ", (dir > 0 ? "LONG" : "SHORT"), " ", lots, " lots");
   return true;
}

//+------------------------------------------------------------------+
//| Modify SL/TP on an open position                                 |
//+------------------------------------------------------------------+
bool ModifySLTP(ulong ticket, double sl, double tp)
{
   if(!PositionSelectByTicket(ticket)) return false;

   MqlTradeRequest req = {0};
   MqlTradeResult  res = {0};
   req.action   = TRADE_ACTION_SLTP;
   req.symbol   = _Symbol;
   req.position = ticket;
   req.sl       = NormalizePrice(sl);
   req.tp       = NormalizePrice(tp);
   req.magic    = Magic;

   return SendOrder(req, res, 3);
}

//+------------------------------------------------------------------+
//| Close an open position by ticket                                 |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket, string note)
{
   if(!PositionSelectByTicket(ticket)) return false;

   long   type = PositionGetInteger(POSITION_TYPE);
   double vol  = PositionGetDouble(POSITION_VOLUME);

   MqlTradeRequest req = {0};
   MqlTradeResult  res = {0};
   req.action       = TRADE_ACTION_DEAL;
   req.symbol       = _Symbol;
   req.volume       = vol;
   req.type         = (type == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   req.position     = ticket;
   req.price        = (req.type == ORDER_TYPE_SELL) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                                    : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   req.deviation    = MaxDeviationPoints;
   req.magic        = Magic;
   req.comment      = note;
   req.type_filling = (ENUM_ORDER_TYPE_FILLING)FillingMode();

   bool ok = SendOrder(req, res, 5);
   if(!ok)
      LogEvent("close FAILED retcode=" + IntegerToString(res.retcode));
   return ok;
}

//+------------------------------------------------------------------+
//| Manage an open position: time-stop, breakeven, trailing          |
//+------------------------------------------------------------------+
void ManagePosition(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return;

   long   type = PositionGetInteger(POSITION_TYPE);
   double open = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl   = PositionGetDouble(POSITION_SL);
   double tp   = PositionGetDouble(POSITION_TP);
   double cur  = PositionGetDouble(POSITION_PRICE_CURRENT);

   //--- R-base: use the remembered original SL distance, falling back to
   //    |open - SL| (or an ATR estimate) after an EA restart mid-trade.
   double rDist = g_riskDist;
   if(rDist <= 0)
   {
      rDist = MathAbs(open - sl);
      if(rDist <= 0)
      {
         rDist = GetATRPoints() * SL_ATRMult * _Point;
         if(rDist < MinSLPoints * _Point) rDist = MinSLPoints * _Point;
         if(rDist > MaxSLPoints * _Point) rDist = MaxSLPoints * _Point;
      }
      g_riskDist = rDist;
   }
   double r = (type == POSITION_TYPE_BUY) ? (cur - open) / rDist
                                          : (open - cur) / rDist;

   //--- time-stop: close if flat/losing after N bars
   if(MaxBarsInTrade > 0)
   {
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      int barsIn = iBarShift(_Symbol, _Period, openTime, false);
      if(barsIn < 0) barsIn = 1000000;
      if(barsIn >= MaxBarsInTrade && r <= 0)
      {
         double prof = PositionGetDouble(POSITION_PROFIT);
         ClosePosition(ticket, "time-stop");
         LogTrade("close", ticket, prof, r, "time-stop");
         return;
      }
   }

   //--- breakeven: lock SL at entry once +BreakevenR is reached
   if(BreakevenR > 0 && r >= BreakevenR)
   {
      if(type == POSITION_TYPE_BUY)
      {
         if(sl < open && ModifySLTP(ticket, open, tp))
            LogTrade("be", ticket, 0.0, r, "SL to breakeven");
      }
      else
      {
         if(sl > open && ModifySLTP(ticket, open, tp))
            LogTrade("be", ticket, 0.0, r, "SL to breakeven");
      }
   }

   //--- trailing stop once +TrailR is reached
   if(TrailR > 0 && r >= TrailR)
   {
      double trailDist = rDist * TrailDistR;
      double newSl = (type == POSITION_TYPE_BUY) ? (cur - trailDist) : (cur + trailDist);
      if(type == POSITION_TYPE_BUY)
      {
         if(newSl > sl + _Point && ModifySLTP(ticket, newSl, tp))
            LogTrade("trail", ticket, 0.0, r, "SL " + DoubleToString(newSl, _Digits));
      }
      else
      {
         if(newSl < sl - _Point && ModifySLTP(ticket, newSl, tp))
            LogTrade("trail", ticket, 0.0, r, "SL " + DoubleToString(newSl, _Digits));
      }
   }
}

#endif // SCALPER_TRADE_MQH
