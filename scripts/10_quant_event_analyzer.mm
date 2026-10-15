script "Quant Event Analyzer"

// ============================================================================
// INDICATOR: Quant Event Analyzer & Statistical Edge Engine [SCRIPT 10]
// ENGINE:    MMT Scripting v3 (Strictly Typed DSL)
// AUTHOR:    Senior Quantitative Strategist & Derivatives Architect
//
// QUANTITATIVE THESIS:
// 1. Classical technical analysis stops at signaling that an event occurred.
//    Institutional quantitative research demands:
//    "What is the empirical forward probability distribution following this event?"
//
// 2. Real-Time Forward Trajectory Tracking (Zero-Lookahead Evaluation):
//    When a compound market event triggers (e.g. Swing sweep + aggressive delta
//    absorption + Open Interest contraction), the indicator registers the event
//    and tracks the forward trajectory across the specified evaluation horizon:
//    - Realized Return: R_h = (Close(t+h) - Close(t)) / Close(t)
//    - Maximum Favorable Excursion (MFE): Peak unrealized profit during the trade.
//    - Maximum Adverse Excursion (MAE): Trough unrealized drawdown during the trade.
//    - Win Rate (WR): Percentage of observations closing in profit at horizon h.
//    - Profit Factor (PF): Gross Wins / Gross Losses across sample N.
//
// 3. Statistical Rigor Standards:
//    - Strictly forward-looking (no lookahead bias).
//    - Unbiased empirical accounting of winners, losers, and excursions.
//    - Embedded Viewport Quantitative Scorecard displaying live sample metrics.
// ============================================================================

data (
  chart = subscribe(data.ohlcv)
  vd    = subscribe(data.vd)
  oi    = subscribe(data.oi)
)

input (
  input.tab(title: "Event Definition")
  input.group(title: "Compound Setup Filter", collapsible: true)
  pivotLen       = input.int(5,      title: "Swing Pivot Strength", min: 2, max: 20)
  minRelVol      = input.float(1.1,  title: "Min Relative Volume", min: 0.5, max: 3.0)
  requireOiDrop  = input.bool(true,  title: "Require OI Contraction (De-risking)")
  requireDeltaAbs= input.bool(true,  title: "Require Delta Absorption Skew")

  input.tab(title: "Statistical Evaluation")
  input.group(title: "Horizon Parameters", collapsible: true)
  evalHorizon    = input.int(16,     title: "Forward Evaluation Horizon (Bars)", min: 4, max: 48)

  input.tab(title: "Visuals & Scorecard")
  input.group(title: "Styling", collapsible: true)
  eventColor     = input.color(color.rgb(255, 215, 0), title: "Event Marker Color")
  showHud        = input.bool(true, title: "Show Statistical Scorecard HUD")
)

type EventStatPayload {
  sampleN: int
  winRate: float
  profitFactor: float
  meanReturn: float
}

alert eventTriggered = alert(title: "Quant Event Triggered", onClose: true)
alert statMilestone  = alert(payload: EventStatPayload, title: "Statistical Milestone Reached", onClose: true)

type PendingEvent {
  entryPrice: float
  entryBar: int
  mfe: float
  mae: float
  isCompleted: bool
}

state (
  markers = entities.markerPool(max: 48)
  hudBox  = entities.boxPool(max: 2, anchor: anchor.topRight)
  hudLabels = entities.labelPool(max: 10, anchor: anchor.topRight)

  // Pending events memory
  p0 = PendingEvent { entryPrice: 0.0, entryBar: 0, mfe: 0.0, mae: 0.0, isCompleted: true }
  p1 = PendingEvent { entryPrice: 0.0, entryBar: 0, mfe: 0.0, mae: 0.0, isCompleted: true }
  p2 = PendingEvent { entryPrice: 0.0, entryBar: 0, mfe: 0.0, mae: 0.0, isCompleted: true }
  p3 = PendingEvent { entryPrice: 0.0, entryBar: 0, mfe: 0.0, mae: 0.0, isCompleted: true }

  // Statistical Aggregates
  sampleN: int = 0
  wins: int = 0
  losses: int = 0
  cumWins: float = 0.0
  cumLosses: float = 0.0
  totMfe: float = 0.0
  totMae: float = 0.0
  totReturn: float = 0.0

  recentReturns = rolling<float>(40)

  eventMarkerCount: int = 0
)

on chart.close {
  let c = chart.close
  let o = chart.open
  let h = chart.high
  let l = chart.low
  let v = chart.volume
  let t = chart.time
  let idx = chart.index
  let d = vd.close

  if c == null || o == null || h == null || l == null || v == null || t == null {
    return
  }

  // 1. Process Active Pending Event Trajectories
  if !p0.isCompleted {
    let diff = (h - p0.entryPrice) / p0.entryPrice * 100.0
    if diff > p0.mfe { p0.mfe = diff }
    let dip = (l - p0.entryPrice) / p0.entryPrice * 100.0
    if dip < p0.mae { p0.mae = dip }

    if idx - p0.entryBar >= evalHorizon {
      let finalRet = (c - p0.entryPrice) / p0.entryPrice * 100.0
      sampleN += 1
      totReturn += finalRet
      totMfe += p0.mfe
      totMae += p0.mae
      recentReturns.push(finalRet)

      if finalRet > 0.0 {
        wins += 1
        cumWins += finalRet
      } else {
        losses += 1
        cumLosses += math.abs(finalRet)
      }
      p0.isCompleted = true
    }
  }

  if !p1.isCompleted {
    let diff = (h - p1.entryPrice) / p1.entryPrice * 100.0
    if diff > p1.mfe { p1.mfe = diff }
    let dip = (l - p1.entryPrice) / p1.entryPrice * 100.0
    if dip < p1.mae { p1.mae = dip }

    if idx - p1.entryBar >= evalHorizon {
      let finalRet = (c - p1.entryPrice) / p1.entryPrice * 100.0
      sampleN += 1
      totReturn += finalRet
      totMfe += p1.mfe
      totMae += p1.mae
      recentReturns.push(finalRet)

      if finalRet > 0.0 {
        wins += 1
        cumWins += finalRet
      } else {
        losses += 1
        cumLosses += math.abs(finalRet)
      }
      p1.isCompleted = true
    }
  }

  if !p2.isCompleted {
    let diff = (h - p2.entryPrice) / p2.entryPrice * 100.0
    if diff > p2.mfe { p2.mfe = diff }
    let dip = (l - p2.entryPrice) / p2.entryPrice * 100.0
    if dip < p2.mae { p2.mae = dip }

    if idx - p2.entryBar >= evalHorizon {
      let finalRet = (c - p2.entryPrice) / p2.entryPrice * 100.0
      sampleN += 1
      totReturn += finalRet
      totMfe += p2.mfe
      totMae += p2.mae
      recentReturns.push(finalRet)

      if finalRet > 0.0 {
        wins += 1
        cumWins += finalRet
      } else {
        losses += 1
        cumLosses += math.abs(finalRet)
      }
      p2.isCompleted = true
    }
  }

  if !p3.isCompleted {
    let diff = (h - p3.entryPrice) / p3.entryPrice * 100.0
    if diff > p3.mfe { p3.mfe = diff }
    let dip = (l - p3.entryPrice) / p3.entryPrice * 100.0
    if dip < p3.mae { p3.mae = dip }

    if idx - p3.entryBar >= evalHorizon {
      let finalRet = (c - p3.entryPrice) / p3.entryPrice * 100.0
      sampleN += 1
      totReturn += finalRet
      totMfe += p3.mfe
      totMae += p3.mae
      recentReturns.push(finalRet)

      if finalRet > 0.0 {
        wins += 1
        cumWins += finalRet
      } else {
        losses += 1
        cumLosses += math.abs(finalRet)
      }
      p3.isCompleted = true
    }
  }

  // 2. Compound Event Definition:
  // - Swing low sweep / rejection: low dips below pivotLow, closes above open
  // - High relative volume
  // - OI contracted (dOi < 0)
  // - Delta skew indicates aggressive seller absorption
  let avgV = ta.sma(v, 20) ?? v
  let relVol = v / (avgV > 0.0 ? avgV : 1.0)
  let pLow = ta.lowest(chart.low, pivotLen) ?? l
  let sweptLow = l <= pLow && c >= o
  let dOi = ta.change(oi.close, 1) ?? 0.0
  let oiDropOk = !requireOiDrop || dOi < 0.0
  let deltaOk = !requireDeltaAbs || (d ?? 0.0) < 0.0 // Heavy aggressive selling absorbed

  let isEvent = sweptLow && relVol >= minRelVol && oiDropOk && deltaOk

  if isEvent {
    eventMarkerCount += 1
    markers.get("evt", eventMarkerCount).set(
      x: t, y: l,
      shape: shape.up,
      color: eventColor,
      size: 12.0,
    )
    eventTriggered.trigger()

    // Enqueue event to first available slot
    if p0.isCompleted {
      p0 = PendingEvent { entryPrice: c, entryBar: idx, mfe: 0.0, mae: 0.0, isCompleted: false }
    } else if p1.isCompleted {
      p1 = PendingEvent { entryPrice: c, entryBar: idx, mfe: 0.0, mae: 0.0, isCompleted: false }
    } else if p2.isCompleted {
      p2 = PendingEvent { entryPrice: c, entryBar: idx, mfe: 0.0, mae: 0.0, isCompleted: false }
    } else if p3.isCompleted {
      p3 = PendingEvent { entryPrice: c, entryBar: idx, mfe: 0.0, mae: 0.0, isCompleted: false }
    }
  }

  // 3. Quantitative Scorecard Metrics
  let safeN = sampleN > 0 ? float(sampleN) : 1.0
  let winRate = sampleN > 0 ? (float(wins) / safeN) * 100.0 : 0.0
  let profitFactor = cumLosses > 0.0001 ? (cumWins / cumLosses) : (cumWins > 0.0 ? 9.99 : 1.0)
  let meanReturn = sampleN > 0 ? totReturn / safeN : 0.0
  let avgMfe = sampleN > 0 ? totMfe / safeN : 0.0
  let avgMae = sampleN > 0 ? totMae / safeN : 0.0

  // 4. Viewport Statistical Scorecard
  if showHud {
    hudBox.get("bg").set(
      15.0, 15.0, 260.0, 160.0,
      rounding: 6.0,
      color: color.withAlpha(color.black, 215),
      borderColor: color.withAlpha(color.gray, 120),
      borderWidth: 1.0,
      zIndex: 10,
    )
    hudLabels.get("h0").set(
      25.0, 25.0, "QUANT EVENT ANALYZER",
      color: color.white, size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h1").set(
      25.0, 48.0, str.format("Sample Size (N): {0}", sampleN),
      color: sampleN >= 10 ? color.teal : color.yellow, size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h2").set(
      25.0, 68.0, str.format("Win Rate (W/L):  {0:.1}% ({1}/{2})", winRate, wins, losses),
      color: winRate >= 50.0 ? color.teal : color.orange, size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h3").set(
      25.0, 88.0, str.format("Profit Factor:   {0:.2}", profitFactor),
      color: profitFactor >= 1.5 ? color.teal : (profitFactor >= 1.0 ? color.yellow : color.red),
      size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h4").set(
      25.0, 108.0, str.format("Mean Ret ({0}b):  {1:+.2}%", evalHorizon, meanReturn),
      color: meanReturn > 0.0 ? color.teal : color.red, size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h5").set(
      25.0, 128.0, str.format("Avg MFE / MAE:   +{0:.2}% / {1:.2}%", avgMfe, avgMae),
      color: color.white, size: 10.0, font: font.mono, zIndex: 11,
    )
  }
}
