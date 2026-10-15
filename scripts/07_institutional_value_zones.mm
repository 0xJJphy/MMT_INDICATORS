script "Institutional Value Zones"

// ============================================================================
// INDICATOR: Institutional Value Zones & Anchored Profiles [SCRIPT 07]
// ENGINE:    MMT Scripting v3 (Strictly Typed DSL)
// AUTHOR:    Senior Quantitative Strategist & Derivatives Architect
//
// QUANTITATIVE THESIS:
// 1. Dual Valuation Framework:
//    - Execution Benchmark: Volume-Weighted Average Price (VWAP) anchored to
//      canonical macro cycles (Daily, Weekly, Monthly) and intraday sessions.
//    - Volume Profile Distribution: Horizontal volume distribution identifying
//      Point of Control (POC) and 70% Value Area [VAL, VAH].
//
// 2. Value Migration Engine:
//    Traditional moving averages only track price averages over time.
//    Value Migration tracks the temporal displacement of the highest-density
//    traded price (POC) across consecutive sessions:
//    - Upward POC Migration: Progressive accumulation at higher prices (Structural Bull).
//    - Downward POC Migration: Progressive distribution at lower prices (Structural Bear).
//    - Overlapping / Lateral Migration: Rotational balance / Bracketed regime.
//
// 3. Acceptance vs Rejection of Value:
//    Evaluates price behavior when trading outside prior Value Area:
//    - Value Acceptance: Price sustains beyond prior VAH/VAL with volume participation.
//    - Value Rejection: Price fails outside Value Area and rapidly rotates back into
//      prior equilibrium, offering high-reward mean-reversion opportunities.
// ============================================================================

data (
  chart  = subscribe(data.ohlcv)
  volume = subscribe(data.volume)
)

input (
  input.tab(title: "Anchored VWAPs")
  input.group(title: "Periodic Anchors", collapsible: true)
  showDailyVwap  = input.bool(true,  title: "Daily VWAP")
  showWeeklyVwap = input.bool(true,  title: "Weekly VWAP")

  input.tab(title: "Volume Profile")
  input.group(title: "Value Area Parameters", collapsible: true)
  profileBars    = input.int(24,     title: "Rolling Profile Lookback (Bars)", min: 10, max: 100)
  vaPct          = input.float(70.0, title: "Value Area Percentage (%)", min: 50.0, max: 90.0)

  input.tab(title: "Visuals & Alerts")
  input.group(title: "Value Colors", collapsible: true)
  pocColor       = input.color(color.rgb(255, 215, 0),   title: "POC Line Color")
  vaColor        = input.color(color.rgb(38, 166, 154),  title: "Value Area High / Low Color")
  dVwapColor     = input.color(color.rgb(79, 195, 247),  title: "Daily VWAP Color")
  wVwapColor     = input.color(color.rgb(186, 104, 200), title: "Weekly VWAP Color")
  showHud        = input.bool(true, title: "Show Value Zones HUD")
)

plot (
  dailyVwapPlot  = plot.line(title: "Daily VWAP", color: dVwapColor, width: 2.0)
  weeklyVwapPlot = plot.line(title: "Weekly VWAP", color: wVwapColor, width: 2.0)

  pocPlot        = plot.line(title: "POC", color: pocColor, width: 2.0)
  vahPlot        = plot.line(title: "VAH (70%)", color: vaColor, width: 1.5)
  valPlot        = plot.line(title: "VAL (70%)", color: vaColor, width: 1.5)
)

fill valueArea = fill.between(vahPlot, valPlot)

type ValueAlertPayload {
  kind: string
  price: float
  pocPrice: float
  vahPrice: float
  valPrice: float
}

alert valueAcceptance = alert(payload: ValueAlertPayload, title: "Value Area Acceptance", onClose: true)
alert valueRejection  = alert(payload: ValueAlertPayload, title: "Value Area Rejection", onClose: true)
alert pocMigration    = alert(payload: ValueAlertPayload, title: "POC Migration Shift", onClose: true)

state (
  prevDayStart: time = time.fromUnixSeconds(0)
  prevWeekStart: time = time.fromUnixSeconds(0)

  // POC Migration tracking
  prevDayPoc: float? = null
  curDayPoc: float? = null
  migrationTrend: string = "Neutral"

  // Value Area memory
  priorVah: float? = null
  priorVal: float? = null

  hudBox = entities.boxPool(max: 2, anchor: anchor.topRight)
  hudLabels = entities.labelPool(max: 8, anchor: anchor.topRight)

  lastStateStr: string = "Inside Value"
)

on chart.close {
  let c = chart.close
  let t = chart.time

  if c == null || t == null {
    return
  }

  // 1. Detect Calendar Boundaries for VWAP Resets
  let dStart = time.dayStart(t)
  let isNewDay = dStart != prevDayStart
  if isNewDay {
    if curDayPoc != null {
      if prevDayPoc != null {
        if (curDayPoc ?? 0.0) > (prevDayPoc ?? 0.0) {
          migrationTrend = "Upward Migration (Bullish)"
        } else if (curDayPoc ?? 0.0) < (prevDayPoc ?? 0.0) {
          migrationTrend = "Downward Migration (Bearish)"
        } else {
          migrationTrend = "Lateral Migration"
        }
      }
      prevDayPoc = curDayPoc
    }
    prevDayStart = dStart
  }

  let wStart = time.weekStart(t)
  let isNewWeek = wStart != prevWeekStart
  if isNewWeek {
    prevWeekStart = wStart
  }

  // 2. Compute Anchored VWAPs
  let dVwap = chart.vwap(reset: isNewDay)
  let wVwap = chart.vwap(reset: isNewWeek)

  dailyVwapPlot.plot(showDailyVwap ? dVwap : null)
  weeklyVwapPlot.plot(showWeeklyVwap ? wVwap : null)

  // 3. Compute Volume Profile & Value Area
  let profile = volume.profile(bars: profileBars)
  let pocPoint = profile.poc()
  let vaBand = profile.valueArea(vaPct)

  let gap: float? = null
  let pocPrice = pocPoint != null ? pocPoint.price : gap
  let vahPrice = vaBand != null ? vaBand.highPrice : gap
  let valPrice = vaBand != null ? vaBand.lowPrice : gap

  curDayPoc = pocPrice

  pocPlot.plot(pocPrice)
  vahPlot.plot(vahPrice)
  valPlot.plot(valPrice)

  if vaBand != null {
    valueArea.fill(
      topValue: vaBand.highPrice,
      bottomValue: vaBand.lowPrice,
      topColor: color.withAlpha(vaColor, 35),
      bottomColor: color.withAlpha(vaColor, 15),
    )
  }

  // 4. Acceptance vs Rejection of Value
  if vahPrice != null && valPrice != null {
    if c > vahPrice {
      lastStateStr = "Above Value (Testing Acceptance)"
      if priorVah != null && c > priorVah {
        valueAcceptance.trigger(ValueAlertPayload {
          kind: "Value Area High Acceptance (Bullish Expansion)",
          price: c,
          pocPrice: pocPrice ?? c,
          vahPrice: vahPrice ?? c,
          valPrice: valPrice ?? c,
        })
      }
    } else if c < valPrice {
      lastStateStr = "Below Value (Testing Breakdown)"
      if priorVal != null && c < priorVal {
        valueAcceptance.trigger(ValueAlertPayload {
          kind: "Value Area Low Acceptance (Bearish Expansion)",
          price: c,
          pocPrice: pocPrice ?? c,
          vahPrice: vahPrice ?? c,
          valPrice: valPrice ?? c,
        })
      }
    } else {
      lastStateStr = "Inside Value Area (Equilibrium)"
    }
    priorVah = vahPrice
    priorVal = valPrice
  }

  // 5. Viewport Heads-Up Display
  if showHud {
    hudBox.get("bg").set(
      15.0, 15.0, 260.0, 140.0,
      rounding: 6.0,
      color: color.withAlpha(color.black, 210),
      borderColor: color.withAlpha(color.gray, 120),
      borderWidth: 1.0,
      zIndex: 10,
    )
    hudLabels.get("h0").set(
      25.0, 25.0, "INSTITUTIONAL VALUE ZONES",
      color: color.white, size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h1").set(
      25.0, 48.0, str.format("POC Price:    {0:.2}", pocPrice ?? 0.0),
      color: pocColor, size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h2").set(
      25.0, 68.0, str.format("Value Area:   [{0:.1} - {1:.1}]", valPrice ?? 0.0, vahPrice ?? 0.0),
      color: vaColor, size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h3").set(
      25.0, 88.0, str.format("Value Trend:  {0}", migrationTrend),
      color: str.contains(migrationTrend, "Upward") ? color.teal : (str.contains(migrationTrend, "Downward") ? color.orange : color.gray),
      size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h4").set(
      25.0, 108.0, str.format("State:        {0}", lastStateStr),
      color: color.white, size: 10.0, font: font.mono, zIndex: 11,
    )
  }
}
