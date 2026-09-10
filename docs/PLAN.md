# EA — XAUUSD MT5 Scalping Bot — Project Plan

> **Scope:** A native MQL5 Expert Advisor that scalps **XAUUSD (gold)** on the
> **M1 / M3** timeframes, runs inside a MetaTrader 5 terminal on a VPS, and is
> aimed at **20–40 trades/day** with a target of **60%+ win rate**, **profit
> factor ≈ 3**, and aggressive growth from a **$100 deposit**.

---

## 0. Honest framing (read this first)

These are **design targets**, not guarantees. No software can promise a win
rate, profit factor, or weekly return. The EA will be built and backtested
*toward* those numbers, but live gold markets (spread widening, slippage, news
spikes) will move them. Anyone — me included — who "guarantees" 100%/week is
selling something, not engineering something.

Two facts that shape the entire design:

1. **The math of PF ≈ 3 with 60% wins.**
   `PF = (winRate × avgWin) / (lossRate × avgLoss)`.
   With a 60% win rate, a PF of 3.0 requires **avgWin ≈ 2 × avgLoss**, i.e. a
   **2:1 reward:risk** per trade *and* holding the 60% win rate. So the EA's
   exits are built around a configurable, ATR-based **RR target of ~2.0**, and
   the entries are built to keep win rate high (trend-following, not
   counter-trend fading).

2. **The $100 account is the binding constraint, not the strategy.**
   Markets4you minimum is 0.01 lot = 1 oz of gold, where **$1.00 of gold move
   = $1.00 P&L**. With $100:
   - A 1% risk per trade = $1 = a $1.00 stop-loss distance. That's realistic
     on M1/M3 gold *only* in the liquid sessions — and it means we trade
     **fixed 0.01 lots** until the balance compounds higher (fractional sizing
     would compute below the 0.01 minimum and get clamped anyway).
   - 100%/week ($100 → $200) is a **stretch scenario**: it needs ~25 solid
     trades × ~$2 net each (or equivalent compounding), every week, without a
     losing streak. It is *possible* in good conditions and *not possible* to
     guarantee. Chasing it with oversized lots is how $100 accounts die.

**Consequence for the design:** the EA will *not* use martingale, grid, or
lot-multiplier "recovery" logic. Those are the standard way small accounts
blow up. Growth comes from compounding fixed-fractional sizing as balance
grows, plus strict daily/consecutive-loss circuit breakers.

---

## 1. Assumptions & environment

| Item | Assumption | To verify before go-live |
|---|---|---|
| Platform | MT5 terminal already installed & logged in on your VPS | VPS is always-on, MT5 "Algo Trading" enabled |
| Broker | Markets4you — **Classic Standard** account | Confirm XAUUSD contract size 100 oz/lot, tick size, tick value, min lot 0.01, stops level |
| Spread | Standard ≈ from 0.9 "pip" (~9 pts), widens at news | Read live `SYMBOL_SPREAD` during London/NY and at a news event |
| Server time | GMT+1 (per user) | Confirm terminal clock vs GMT; sessions/rollover run on server time |
| Leverage | Up to 1:4000 | Confirm actual leverage on your account |
| Account | Start on **Demo first**, then live $100 | Never skip the demo phase |

The EA reads all symbol/account facts at runtime
(`SYMBOL_TRADE_TICK_VALUE`, `SYMBOL_VOLUME_MIN/STEP/MAX`, `SYMBOL_SPREAD`,
`SYMBOL_TRADE_STOPS_LEVEL`, `AccountInfoDouble(ACCOUNT_BALANCE)`, etc.) so it
adapts to your real terminal rather than trusting constants.

---

## 2. Architecture

Single all-in-one MQL5 program (compiles to `XAUUSD_Scalper.ex5` via
MetaEditor), split into include modules for maintainability:

```
EA/
├── docs/
│   ├── PLAN.md                 ← this document
│   └── SETUP.md                ← install, compile, attach, go-live guide
├── Experts/
│   └── XAUUSD_Scalper.mq5      ← main EA (OnInit/OnTick/OnTradeTransaction)
├── Include/
│   ├── ScalperDefines.mqh      ← enums, constants, magic number, colors
│   ├── ScalperRisk.mqh         ← lot sizing, daily loss, circuit breakers
│   ├── ScalperSignals.mqh      ← entry/exit signal logic
│   ├── ScalperTrade.mqh        ← order open/modify/close, SL/TP, trailing
│   └── ScalperLog.mqh          ← CSV trade log + on-chart comments
├── Presets/
│   ├── Conservative.set        ← recommended defaults (demo first)
│   └── Aggressive.set          ← high-growth preset (only after demo passes)
└── README.md
```

Runtime responsibilities:

- **OnInit** — validate symbol/account, load presets, build trade objects,
  reject unsupported symbols (`_Symbol != "XAUUSD"` unless `InpAnySymbol`).
- **OnTick (new bar only)** — run gates → compute signal → manage open trade
  (trailing/breakeven/time-stop) → maybe open trade. One pass per bar (M1/M3),
  not per-tick chatter, which is what makes it "scalping-fast" but stable.
- **OnTradeTransaction** — track fills/slips and maintain the in-memory trade
  state even if the terminal restarts (rebuilt from history in `OnInit`).
- **Logging** — every decision written to `XAUUSD_Scalper.csv` + chart comment
  panel; later optional Telegram/webhook push.

---

## 3. Strategy design (I design; all inputs configurable)

A **session-filtered, trend-aligned, volatility-gated breakout/momentum
scalper**. Rationale: 60% win rate + 2:1 RR is far more achievable
*with* the intraday trend than against it.

1. **Session filter (default OFF — trade all sessions)** — optional London/NY
   windows are available via inputs, but the default is 24/5 trading. A
   configurable **Friday-late / Sunday-open** quiet filter remains available.
2. **Spread & volatility gate** — refuse to trade when live spread >
   `InpMaxSpreadPoints` (default 70 pts for Classic Standard) or when ATR is
   outside a sane band (dead hours = no moves = spread eats you).
3. **Trend filter (M15)** — EMA(21) vs EMA(50) direction, optionally gated by
   ADX(14) > `InpMinADX`. Longs only above, shorts only below
   (or "both" if configured).
4. **Entry trigger (M1/M3, selectable enum):**
   - *Bollinger squeeze breakout* — Bollinger(20,2) squeeze releases in the
     trend direction with RSI momentum confirm; or
   - *Range breakout* — break of the last N bars' high/low in the trend
     direction with a momentum/volume confirm.
   Both are classic, explainable, non-curve-fit scalping patterns.
5. **Exits (per trade):**
   - **SL** = ATR-based distance (e.g. 1.0–1.5 × ATR(14)) behind entry or
     recent swing, clamped to `InpMin/MaxSLPoints`.
   - **TP** = `InpRR` × SL (default **2.0** — the PF≈3 math).
   - **Breakeven** after +0.5R; **trailing stop** after +1R (optional).
   - **Time-stop**: close if the trade hasn't moved favorably after
     `InpMaxBarsInTrade` (no more "hope and hold").
6. **News = "care mode", not "block mode"** — the EA watches live spread vs a
   rolling baseline. When spread spikes (news/low liquidity), it switches to
   *care mode*: risk per trade × `InpNewsRiskMult` (default 0.5), a higher
   spread ceiling (`InpCareSpreadCeil`, default 160 pts), and it keeps the
   trend/RSI filters. Normal trading resumes when spread normalizes. An
   optional manual block window (`InpNewsBlockStart/End`) is available for
   scheduled events (e.g. NFP) if you ever want it.
7. **Hard filters** — max 1 concurrent position, cooldown between trades,
   `InpMaxTradesPerDay` (default 30, range 20–40).

---

## 4. Risk & money management (safety-first)

| Guardrail | Default | Purpose |
|---|---|---|
| Risk per trade | 1% of balance (clamped to 0.01 lot min) | Keeps SL ≈ $1.00 on $100 |
| Max daily loss | 5% | Flatten for the day |
| Max weekly loss | 10% | Flatten for the week |
| Max consecutive losses | 4 | Pause N minutes, then resume cautiously |
| Daily profit target | optional (e.g. 10%) | Lock in profit, stop for the day |
| Max trades/day | 30 | Matches the 20–40/day spec |
| Max spread | ~70 pts normal, ~160 pts care mode | Don't pay wide spreads |
| News mode | care (risk × 0.5, tighter gates) | Trade news carefully, don't block |
| Equity guard | hard stop below X% of day-start | Kill switch |
| Max slippage/deviation | configurable points | Reject bad fills |
| Sizing | Fixed-fractional, no martingale | No recovery doubling |

Sizing model: `lots = risk% × balance / (SL_distance_$ × tick_value)`.
On a $100 account this almost always computes < 0.01 and clamps to **0.01**,
so it behaves as fixed 0.01 lots and only scales up as the account compounds
past the point where fractional sizing becomes meaningful — exactly the
compounding path needed to make 100%/week *reachable* without instantly
risking ruin.

---

## 5. Milestones

### Phase 0 — Environment verification (you + me)
Confirm the Classic Standard XAUUSD specs (spread during London/NY and at a
news event, stops level, swap), GMT+1 server clock. Verify MT5 "Algo Trading"
is enabled and tick data can be downloaded for the Strategy Tester.
*Exit:* a filled-in spec sheet.

### Phase 1 — Skeleton EA
`OnInit` validation, gates, logging, on-chart status panel. **No trades.**
*Exit:* compiles clean, attaches to any chart, writes logs, zero errors.

### Phase 2 — Signal engine
Trend filter + session/volatility/spread gates + entry trigger, all behind
enums. Visual arrow/comment output for debugging.
*Exit:* signals fire on the right bars and are explainable on a chart.

### Phase 3 — Risk + order management
Lot sizing, SL/TP/RR, breakeven/trailing/time-stop, circuit breakers,
`OnTradeTransaction` state rebuild.
*Exit:* on demo, trades open/close exactly per the rules; risk checks hold.

### Phase 4 — Backtest & tune
MT5 Strategy Tester, "Every tick based on real ticks", 12+ months XAUUSD,
M1 and M3. Walk-forward: optimize on in-sample, verify out-of-sample.
Targets: win rate ≥ 55%, PF ≥ 1.8, 20–40 trades/day, controlled drawdown.
Robustness: re-run at +50% spread, and across separate months.
*Exit:* an honest backtest report (numbers, equity curve, drawdown) — I'll
interpret it with you rather than cherry-pick.

### Phase 5 — Forward test (demo, 1–2 weeks)
Run on the VPS demo account exactly as it would run live.
*Exit:* demo results roughly match backtest expectations; guardrails trigger
correctly.

### Phase 6 — Live ($100, Aggressive preset)
Live with the **Aggressive** preset, 0.01 lots until the balance compounds,
daily-loss and consecutive-loss breakers on, care-mode spread handling on.
Monitor daily.
*Exit:* a week of live trading reviewed together before any setting changes.

### Phase 7 — Optional monitoring (later, if you want it)
Telegram/webhook alerts and a simple stats dashboard. (Deferred — you said no
alerts for now.)

---

## 6. Locked decisions (from you)

1. **Sessions** — trade **all sessions** (24/5). The session filter is still
   in the EA but defaults to *Off*.
2. **News** — **trade through news, but with care**. No hard blackout. The EA
   detects news/low-liquidity via **spread spikes** and in "care mode" it
   reduces risk (`InpNewsRiskMult`), raises the allowed spread ceiling, and
   keeps normal trend/RSI filters. (A manual block window is still available
   if you ever want it.)
3. **Account** — **Classic Standard** (spread-only, no commission). So spread
   is the dominant cost; default max-spread gate is set wider (~70 pts) with
   care-mode ceiling ~160 pts.
4. **Alerts** — none for now. All events go to a CSV log + on-chart panel.
   (Telegram/webhook hook left for Phase 7.)
5. **Preset** — start **Aggressive** (the default inputs), Conservative
   available as a fallback.
6. **Broker time** — **GMT+1** (server time = GMT+1). Session/rollover logic
   runs on server time, so no offset math is needed; the GMT+1 fact is
   documented for when you review logs.

---

## 7. What I'll deliver in the repo

- `Experts/XAUUSD_Scalper.mq5` + `Include/*.mqh` (compilable MQL5 source)
- `Presets/Aggressive.set` (default) and `Presets/Conservative.set`
- `docs/SETUP.md` (VPS → MT5 → compile → attach → go-live, step by step)
- Backtest results report + walk-forward notes once Phase 4 runs

**Next step:** plan approved with your locked-in decisions. Starting Phase 1–3
now — building the skeleton EA, signal engine, and risk/order management as a
single compilable first version, plus `docs/SETUP.md`.
