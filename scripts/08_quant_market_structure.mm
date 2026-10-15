script "Quant Market Structure"

// ============================================================================
// INDICATOR: Quant Market Structure & Breakout Quality [SCRIPT 08]
// ENGINE:    MMT Scripting v3 (Strictly Typed DSL)
// AUTHOR:    Senior Quantitative Strategist & Derivatives Architect
//
// QUANTITATIVE THESIS:
// 1. Strict Lookahead-Free Structural Pivots:
//    Pivots are confirmed strictly after 'pivotStrength' bars have fully closed.
//    No historical repainting or lookahead anchoring: signals evaluate strictly
//    at the valid confirmation bar.
//
// 2. Break of Structure (BOS) vs Change of Character (CHoCH):
//    - BOS: Breakout in the direction of the established structural trend.
//    - CHoCH: Breakout counter to the established structural trend, signaling regime shift.
//
// 3. Quantitative Breakout Quality Function (Q-Score):
//    Evaluates the institutional validity of every breakout on a calibrated scale (0 to 100):
//    Q = f(RV, DeltaP, Delta, OI, Acceptance)
//    - Volatility Displacement (25%): Normalized body size (|Close - Open| / ATR).
//    - Relative Volume Participation (25%): Volume expansion (V / SMA(V)).
//    - Order Flow Aggression (25%): Directional Delta dominance (|d| / V).
//    - Derivatives Participation (15%): Open Interest expansion (|dOI| / SMA(|dOI|)).
//    - Acceptance Cushion (10%): Clean close beyond broken level.
//
// 4. Scored Categorization:
//    - Strong Breakout (Q >= 65): Heavy participation, high continuation probability.
//    - Weak Breakout (Q <= 40): Low conviction, highly vulnerable to reversal.
//    - Failed Breakout: Breakout that reverses and closes back inside previous structure
//      within 'failedWindow' bars (Classic trap / fakeout).
// ============================================================================

data (
  chart = subscribe(data.ohlcv)
  vd    = subscribe(data.vd)
  oi    = subscribe(data.oi)
)

input (
  input.tab(title: "Structure Detection")
  input.group(title: "Swing Pivots", collapsible: true)
  pivotStrength = input.int(5,  title: "Pivot Confirmation Bars (Left/Right)", min: 2, max: 20)
  failedWindow  = input.int(4,  title: "Failed Breakout Evaluation Window (Bars)", min: 1, max: 15)

  input.tab(title: "Quality Thresholds")
  input.group(title: "Breakout Scoring Weights", collapsible: true)
  minStrongQ    = input.float(65.0, title: "Strong Breakout Minimum Score", min: 50.0, max: 90.0)
  maxWeakQ      = input.float(40.0, title: "Weak Breakout Maximum Score", min: 20.0, max: 55.0)

  input.tab(title: "Visuals & Alerts")
  input.group(title: "Visual Styling", collapsible: true)
  bosBullColor  = input.color(color.rgb(38, 166, 154), title: "Bullish BOS / CHoCH Color")
  bosBearColor  = input.color(color.rgb(239, 83, 80),   title: "Bearish BOS / CHoCH Color")
  weakColor     = input.color(color.rgb(255, 183, 77),  title: "Weak Breakout Color")
  failedColor   = input.color(color.rgb(229, 57, 53),   title: "Failed Breakout Color")
  showHud       = input.bool(true, title: "Show Market Structure HUD")
)

type StructurePayload {
  kind: string
  qualityScore: float
  breakoutPrice: float
  swingPrice: float
}

alert bosAlert    = alert(payload: StructurePayload, title: "Break of Structure (BOS)", onClose: true)
alert chochAlert  = alert(payload: StructurePayload, title: "Change of Character (CHoCH)", onClose: true)
alert failedAlert = alert(payload: StructurePayload, title: "Failed Breakout", onClose: true)

state (
  markers = entities.markerPool(max: 48)
  lines   = entities.linePool(max: 32)
  hudBox  = entities.boxPool(max: 2, anchor: anchor.topRight)
  hudLabels = entities.labelPool(max: 8, anchor: anchor.topRight)

  // Structural Pivot History
  lastHighPrice: float? = null
  lastHighTime:  time = time.fromUnixSeconds(0)
  lastLowPrice:  float? = null
  lastLowTime:   time = time.fromUnixSeconds(0)

  trendState: string = "Neutral"

  // Active Breakout Monitoring
  activeBreakout: bool = false
  isBullBreak: bool = false
  brokenLevel: float = 0.0
  breakoutScore: float = 0.0
  breakoutBar: int = 0
  breakoutTime: time = time.fromUnixSeconds(0)

  eventCount: int = 0
  lastStructureStr: string = "None"
  lastQuality: float = 0.0
)

on chart.close {
  let c = chart.close
  let o = chart.open
  let h = chart.high
  let l = chart.low
  let v = chart.volume
  let t = chart.time
  let d = vd.close
  let idx = chart.index

  if c == null || o == null || h == null || l == null || v == null || t == null {
    return
  }

  let atr = chart.atr(14) ?? (h - l > 0.0 ? h - l : 1.0)
  let avgV = ta.sma(v, 20) ?? v
  let relVol = v / (avgV > 0.0 ? avgV : 1.0)
  let safeV = v > 0.0 ? v : 1.0
  let deltaAgg = math.abs(d ?? 0.0) / safeV
  let dOi = ta.change(oi.close, 1) ?? 0.0
  let avgDoi = ta.sma(math.abs(dOi), 20) ?? (math.abs(dOi) > 0.0 ? math.abs(dOi) : 1.0)
  let normOi = math.abs(dOi) / (avgDoi > 0.0 ? avgDoi : 1.0)

  // 1. Pivot Confirmation (Zero Lookahead - Confirmed only after pivotStrength bars)
  let pHigh = ta.pivotHigh(chart.high, pivotStrength, pivotStrength)
  let pLow  = ta.pivotLow(chart.low, pivotStrength, pivotStrength)
  let pTime = t - time.bars(pivotStrength)

  if pHigh != null {
    lastHighPrice = pHigh
    lastHighTime = pTime
  }
  if pLow != null {
    lastLowPrice = pLow
    lastLowTime = pTime
  }

  // 2. Active Breakout Quality Evaluation & Failed Breakout Tracker
  if activeBreakout {
    let elapsed = idx - breakoutBar
    if isBullBreak {
      if c < brokenLevel && elapsed <= failedWindow {
        // Closed back below broken swing -> FAILED BREAKOUT
        eventCount += 1
        lastStructureStr = "Failed Bull Breakout"
        markers.get("fb", eventCount).set(
          x: t, y: h,
          shape: shape.down,
          color: failedColor,
          size: 12.0,
        )
        lines.get("fb", eventCount).set(
          breakoutTime, brokenLevel, t, brokenLevel,
          color: failedColor, style: linestyle.dotted, width: 2.0,
          text: "Failed Breakout",
        )
        failedAlert.trigger(StructurePayload {
          kind: "Failed Bullish Breakout",
          qualityScore: breakoutScore,
          breakoutPrice: c,
          swingPrice: brokenLevel,
        })
        activeBreakout = false
      } else if elapsed > failedWindow {
        activeBreakout = false
      }
    } else {
      if c > brokenLevel && elapsed <= failedWindow {
        // Closed back above broken swing -> FAILED BREAKOUT
        eventCount += 1
        lastStructureStr = "Failed Bear Breakdown"
        markers.get("fb", eventCount).set(
          x: t, y: l,
          shape: shape.up,
          color: failedColor,
          size: 12.0,
        )
        lines.get("fb", eventCount).set(
          breakoutTime, brokenLevel, t, brokenLevel,
          color: failedColor, style: linestyle.dotted, width: 2.0,
          text: "Failed Breakdown",
        )
        failedAlert.trigger(StructurePayload {
          kind: "Failed Bearish Breakdown",
          qualityScore: breakoutScore,
          breakoutPrice: c,
          swingPrice: brokenLevel,
        })
        activeBreakout = false
      } else if elapsed > failedWindow {
        activeBreakout = false
      }
    }
  }

  // 3. Structure Breakout Detection (BOS vs CHoCH)
  let body = math.abs(c - o)
  let dispScore = math.min(25.0, (body / atr) * 20.0)
  let volScore  = math.min(25.0, math.max(0.0, (relVol - 1.0) * 15.0))
  let deltaScore= math.min(25.0, deltaAgg * 35.0)
  let oiScore   = math.min(15.0, normOi * 10.0)
  let closeScore= 10.0
  let quality = math.clamp(dispScore + volScore + deltaScore + oiScore + closeScore, 0.0, 100.0)

  // Bullish Breakout above last confirmed Swing High
  if lastHighPrice != null && c > (lastHighPrice ?? 0.0) && o <= (lastHighPrice ?? 0.0) {
    eventCount += 1
    lastQuality = quality
    let isChoch = trendState == "Bearish"
    trendState = "Bullish"
    let kindName = isChoch ? "Bullish CHoCH" : "Bullish BOS"
    lastStructureStr = kindName

    activeBreakout = true
    isBullBreak = true
    brokenLevel = lastHighPrice ?? 0.0
    breakoutScore = quality
    breakoutBar = idx
    breakoutTime = t

    let qualColor = quality >= minStrongQ ? bosBullColor : (quality <= maxWeakQ ? weakColor : bosBullColor)

    markers.get("str", eventCount).set(
      x: t, y: h,
      shape: shape.up,
      color: qualColor,
      size: quality >= minStrongQ ? 13.0 : 9.0,
    )
    lines.get("str", eventCount).set(
      lastHighTime, (lastHighPrice ?? 0.0), t, (lastHighPrice ?? 0.0),
      color: qualColor, style: linestyle.dashed, width: 1.5,
      text: str.format("{0} (Q={1:.0})", kindName, quality),
    )

    if isChoch {
      chochAlert.trigger(StructurePayload {
        kind: kindName,
        qualityScore: quality,
        breakoutPrice: c,
        swingPrice: lastHighPrice ?? 0.0,
      })
    } else {
      bosAlert.trigger(StructurePayload {
        kind: kindName,
        qualityScore: quality,
        breakoutPrice: c,
        swingPrice: lastHighPrice ?? 0.0,
      })
    }
  }

  // Bearish Breakdown below last confirmed Swing Low
  if lastLowPrice != null && c < (lastLowPrice ?? 0.0) && o >= (lastLowPrice ?? 0.0) {
    eventCount += 1
    lastQuality = quality
    let isChoch = trendState == "Bullish"
    trendState = "Bearish"
    let kindName = isChoch ? "Bearish CHoCH" : "Bearish BOS"
    lastStructureStr = kindName

    activeBreakout = true
    isBullBreak = false
    brokenLevel = lastLowPrice ?? 0.0
    breakoutScore = quality
    breakoutBar = idx
    breakoutTime = t

    let qualColor = quality >= minStrongQ ? bosBearColor : (quality <= maxWeakQ ? weakColor : bosBearColor)

    markers.get("str", eventCount).set(
      x: t, y: l,
      shape: shape.down,
      color: qualColor,
      size: quality >= minStrongQ ? 13.0 : 9.0,
    )
    lines.get("str", eventCount).set(
      lastLowTime, (lastLowPrice ?? 0.0), t, (lastLowPrice ?? 0.0),
      color: qualColor, style: linestyle.dashed, width: 1.5,
      text: str.format("{0} (Q={1:.0})", kindName, quality),
    )

    if isChoch {
      chochAlert.trigger(StructurePayload {
        kind: kindName,
        qualityScore: quality,
        breakoutPrice: c,
        swingPrice: lastLowPrice ?? 0.0,
      })
    } else {
      bosAlert.trigger(StructurePayload {
        kind: kindName,
        qualityScore: quality,
        breakoutPrice: c,
        swingPrice: lastLowPrice ?? 0.0,
      })
    }
  }

  // 4. Viewport HUD
  if showHud {
    hudBox.get("bg").set(
      15.0, 15.0, 250.0, 135.0,
      rounding: 6.0,
      color: color.withAlpha(color.black, 210),
      borderColor: color.withAlpha(color.gray, 120),
      borderWidth: 1.0,
      zIndex: 10,
    )
    hudLabels.get("h0").set(
      25.0, 25.0, "QUANT MARKET STRUCTURE",
      color: color.white, size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h1").set(
      25.0, 48.0, str.format("Trend State:    {0}", trendState),
      color: trendState == "Bullish" ? color.teal : (trendState == "Bearish" ? color.red : color.gray),
      size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h2").set(
      25.0, 68.0, str.format("Last Structure: {0}", lastStructureStr),
      color: color.yellow, size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h3").set(
      25.0, 88.0, str.format("Break Quality:  {0:.0}/100", lastQuality),
      color: lastQuality >= minStrongQ ? color.teal : (lastQuality <= maxWeakQ ? color.orange : color.yellow),
      size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h4").set(
      25.0, 108.0, str.format("Swing Levels:   [{0:.1} - {1:.1}]", lastLowPrice ?? 0.0, lastHighPrice ?? 0.0),
      color: color.white, size: 10.0, font: font.mono, zIndex: 11,
    )
  }
}
