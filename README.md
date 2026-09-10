# EA — XAUUSD MT5 Scalper

A native **MQL5 Expert Advisor** for MetaTrader 5 that scalps **XAUUSD (gold)**
on the **M1/M3** timeframes.

Built for:
- **Markets4you**, Classic Standard (spread) account
- Server time **GMT+1**
- **All sessions**, trading **through news with care** (spread-spike detection)
- **Aggressive** growth profile from a **$100** deposit

> ⚠️ **No guarantee of profit.** The 60% win-rate / PF≈3 / fast-growth figures
> are *design targets*, not promises. The EA uses fixed-fractional sizing with
> strict daily/weekly loss limits and a consecutive-loss pause — **no
> martingale, no grid**. Trade on **demo first** and only risk what you can
> afford to lose.

## Contents

```
Experts/XAUUSD_Scalper.mq5   main EA
Include/ScalperDefines.mqh   enums, structs, constants
Include/ScalperInputs.mqh    all user inputs
Include/ScalperGlobals.mqh   global state + prototypes
Include/ScalperLog.mqh       CSV logging
Include/ScalperSignals.mqh   entry signal engine
Include/ScalperRisk.mqh      gates, breakers, lot sizing
Include/ScalperTrade.mqh     order + SL/TP management
Presets/Aggressive.set       default profile
Presets/Conservative.set     lower-risk profile
docs/PLAN.md                 full plan & rationale
docs/SETUP.md                install → compile → backtest → go-live
```

## Quick start

See **[docs/SETUP.md](docs/SETUP.md)**.
