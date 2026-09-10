# XAUUSD_Scalper — Setup Guide

Step-by-step: put the EA on your VPS, compile it, backtest it, then go live.

---

## 0. Before anything: set expectations

This is software, not a money printer. The plan's targets (60% win rate,
PF ≈ 3, fast growth) are what we *optimize toward*. On a **$100 account** the
minimum lot is **0.01 (1 oz)**, so every $1.00 gold move = $1.00 P/L. A run of
a few bad trades can and will draw the account down — that's why the EA has
hard daily-loss, weekly-loss, and consecutive-loss breakers. **Run demo for at
least a week before funding a live $100.**

---

## 1. VPS + MT5

1. Your VPS must stay **on 24/5** (the EA only trades while MT5 is running).
2. Install **MetaTrader 5** from Markets4you (their download / personal area).
3. Log in to your **Classic Standard** account.
4. Confirm the terminal clock: you said **GMT+1** — check the time shown in the
   Market Watch header against a GMT clock and note the offset.

## 2. Enable auto-trading (two switches, both required)

1. **Tools → Options → Expert Advisors** → tick **Allow algorithmic trading**.
2. On the toolbar, make sure the **"Algo Trading"** button is pressed/green.
3. When you attach the EA, tick **"Allow Algo Trading"** in the attach dialog.

## 3. Copy the files into MT5

Open MT5 → **File → Open Data Folder** → go to `MQL5\` and copy:

| From this repo        | To (inside the MT5 data folder)      |
|-----------------------|--------------------------------------|
| `Experts/XAUUSD_Scalper.mq5` | `MQL5\Experts\XAUUSD_Scalper.mq5` |
| `Include\*.mqh` (6 files)    | `MQL5\Include\*.mqh`            |
| `Presets\*.set` (2 files)    | `MQL5\Presets\*.set`            |

## 4. Compile

1. In MT5 open **MetaEditor** (F4).
2. Open `Experts\XAUUSD_Scalper.mq5`.
3. Press **F7 (Compile)**.
4. **Zero errors, zero warnings** is the goal. If you get any compile errors,
   copy them here and I'll fix them.

## 5. Quick contract-spec check (important)

Attach the EA once to an **XAUUSD M1** chart. It prints (in the "Experts" tab)
its live contract facts, and writes them to `MQL5\Files\XAUUSD_Scalper_Log.csv`:

- **spread** (points) during London/NY and during a news event
- **tickValue** (should be ~1.0 for 0.01 price move per 1.0 lot)
- **minLot** (should be 0.01)
- **stopsLevel** (minimum SL distance in points)

If spread is often above ~70 points on your account, raise `MaxSpreadPoints`
(and `CareSpreadCeil`) in the inputs — but understand that wider spread eats a
bigger share of a small SL.

## 6. Attach & configure

1. Drag the EA onto **XAUUSD M1** (or M3 — the EA uses the chart timeframe).
2. Tick **Allow Algo Trading**.
3. **Inputs tab** → **Load** → pick `Aggressive.set` (or `Conservative.set`).
   - If MT5 complains about an unknown input when loading a preset, set the two
     dropdowns (`EntryMode`, `TrendMode`) manually and press OK.
4. Set a unique `Magic` if you run other EAs on the same account.
5. Press **OK**. The chart comment shows live status (spread, ATR, trades today,
   day P/L, care mode, open position).

## 7. Backtest (do this before demo)

1. **View → Strategy Tester** (Ctrl+R).
2. Expert: `XAUUSD_Scalper`; Symbol: **XAUUSD**; Period: **M1** (also try M3).
3. Model: **"Every tick based on real ticks"**.
   - If you don't have real ticks: **Tools → History Center → XAUUSD → M1 →
     Download** (M3 if used), or download from your broker.
4. Date range: **12+ months**. Deposit: **100**, leverage: your real one
   (e.g. 1:4000).
5. **Start**. When done, open **Graph / Report / Journal**.
6. Findings go in `MQL5\Files\XAUUSD_Scalper_Log.csv`.

**What good looks like** (targets, not promises): win rate ≥ 55%, PF ≥ 1.8,
20–40 trades/day average, controlled drawdown, and — crucially — the same
shape of result **out-of-sample** (re-run on a different 3–6 months) and with
spread widened ~50% (right-click the report → use a higher spread) .

## 8. Forward test on demo

Run 1–2 weeks on a **demo** account, live VPS, exactly as you would live. Check:
- trades open/close per the rules (see the log)
- daily-loss / consecutive-loss breakers actually fire
- care mode turns on during news and risk halves

## 9. Go live ($100, Aggressive)

1. Same setup on the live Classic Standard account.
2. Start with the **Aggressive** preset (defaults), which is already
   risk-capped: 1% risk/trade (≈ 0.01 lot on $100), 5% daily / 10% weekly loss
   limits, 4-loss pause, care-mode risk halving.
3. Review daily. After a week, we look at the log + report together and only
   then consider any input changes.

## 10. Reading the log

`MQL5\Files\XAUUSD_Scalper_Log.csv` — one row per event:

```
time,event,ticket,net,r,balance,equity,spread,care,note
```

- `open` / `close` / `be` / `trail` / `time-stop` = trade lifecycle
- `gate:` rows = why a new trade was blocked
- `care mode ON/OFF` = spread-spike (news) detection
- `net` = realized P/L including commission & swap; `r` = trade progress in R

## 11. Common issues

| Symptom | Fix |
|---|---|
| "algo trading disabled" in log | Enable the two switches in section 2 |
| "EA trading disabled (account)" | Ask broker / check account settings |
| "spread too wide" constantly | Raise `MaxSpreadPoints` / `CareSpreadCeil` |
| "ATR too low/high" | Adjust `MinATRPoints` / `MaxATRPoints` |
| No trades in tester | Use "real ticks"; extend date range; check gates in log |
| "attach to XAUUSD" message | Set `AnySymbol=true` or attach to XAUUSD |
| Compile errors | Paste them here — I'll fix |

## 12. Safety reminders

- **Never** raise `RiskPercent` above ~1.5% on a $100 account.
- **Never** disable the daily/weekly loss limits.
- There is **no martingale/grid** here on purpose — don't add one.
- The VPS is part of the system: if it reboots, MT5 must auto-start and the EA
  must re-attach (set MT5 to launch at Windows startup and enable auto-trading).
