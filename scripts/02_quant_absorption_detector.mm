script "Quant Absorption Detector"

// ============================================================================
// INDICATOR: Quant Absorption & Exhaustion Detector [SCRIPT 02]
// ENGINE:    MMT Scripting v3 (Strictly Typed DSL)
// AUTHOR:    Senior Quantitative Strategist & Derivatives Architect
//
// QUANTITATIVE THESIS:
// 1. Absorption occurs when aggressive order flow (market orders) encounters
//    immense passive limit orders (resting depth) that completely absorbs the
//    directional momentum without proportional price displacement.
//    Metric: Flow Impact Efficiency (IE) = |Delta P| / (Aggressive Volume + eps).
//    Under absorption, aggressive volume spikes (Z_vol >= threshold) while
//    Impact Efficiency collapses (Z_IE <= -threshold).
//    - Bullish Absorption: Heavy negative volume delta absorbed at bar lows with
//      rejection wick or bullish close (Passive buyers absorbing aggressive selling).
//    - Bearish Absorption: Heavy positive volume delta absorbed at bar highs with
//      rejection wick or bearish close (Passive sellers absorbing aggressive buying).
//
// 2. Exhaustion occurs at structural extremes (new local highs/lows) when aggressive
//    participation evaporates (volume drops significantly below mean), range compresses,
//    signaling that momentum has run out of aggressive fuel.
//
// 3. Confluence Filter:
//    Optionally restricts absorption/exhaustion detection strictly to the vicinity
//    of institutional reference levels (Previous Day High/Low, Weekly levels).
// ============================================================================

data chart = subscribe(data.ohlcv)
data vd = subscribe(data.vd)
data daily = subscribe(data.ohlcv, timeframe: 1D)

input (
  input.tab(title: "Statistical Model")
  input.group(title: "Order Flow Normalization", collapsible: true)
  lookbackLen     = input.int(30, title: "Rolling Baseline Window (Bars)", min: 10, max: 100)
  minVolZ         = input.float(1.2, title: "Aggressive Volume Spike Z-Score", min: 0.5, max: 4.0)
  maxEffZ         = input.float(-0.7, title: "Max Efficiency Z-Score (Lower = More Absorbed)", min: -3.0, max: 0.0)
  minDeltaRatio   = input.float(0.25, title: "Minimum Delta Imbalance Ratio", min: 0.1, max: 0.8)
  minWickRatio    = input.float(0.25, title: "Minimum Rejection Wick Ratio", min: 0.0, max: 0.6)

  input.group(title: "Exhaustion Parameters", collapsible: true)
  enableExhaust   = input.bool(true, title: "Enable Exhaustion Detection")
  exhaustLookback = input.int(12, title: "Extreme Swing Lookback", min: 5, max: 50)
  exhaustVolMaxZ  = input.float(-0.5, title: "Max Volume Z-Score for Exhaustion", min: -2.0, max: 0.5)

  input.tab(title: "Reference Filter")
  input.group(title: "Level Confluence", collapsible: true)
  filterByLevels  = input.bool(false, title: "Only Near Institutional Levels")
  levelTolerance  = input.float(0.30, title: "Proximity Tolerance (x ATR)", min: 0.05, max: 1.0)

  input.tab(title: "Visualization & HUD")
  input.group(title: "On-Chart Zones", collapsible: true)
  zoneBars        = input.int(6, title: "Zone Duration (Bars Forward)", min: 1, max: 30)
  showLabels      = input.bool(true, title: "Show Text Labels on Zones")
  bullColor       = input.color(color.rgb(38, 166, 154), title: "Bullish Absorption (Green)")
  bearColor       = input.color(color.rgb(239, 83, 80),   title: "Bearish Absorption (Red)")
  exhaustColor    = input.color(color.rgb(255, 202, 40),  title: "Exhaustion (Yellow)")

  input.group(title: "Status HUD", collapsible: true)
  showHud         = input.bool(true, title: "Show Viewport Quantitative HUD")
)

type EventPayload {
  kind: string
  price: float
  delta: float
  zScore: float
}

alert absorptionAlert = alert(payload: EventPayload, title: "Order Flow Absorption", onClose: true)
alert exhaustionAlert = alert(payload: EventPayload, title: "Order Flow Exhaustion", onClose: true)

state (
  boxes = entities.boxPool(max: 48)
  markers = entities.markerPool(max: 48)
  hudBox = entities.boxPool(max: 2, anchor: anchor.topRight)
  hudLabels = entities.labelPool(max: 8, anchor: anchor.topRight)
  eventCount: int = 0
  lastEventStr: string = "None"
  lastZScore: float = 0.0
)

on chart.close {
  let c = chart.close
  let o = chart.open
  let h = chart.high
  let l = chart.low
  let v = chart.volume
  let d = vd.close
  let t = chart.time

  if c == null || o == null || h == null || l == null || v == null || d == null || t == null {
    return
  }

  let range = h - l
  let safeRange = range > 0.0 ? range : 1.0
  let atr = chart.atr(14) ?? safeRange
  let body = math.abs(c - o)
  let vNorm = v > 0.0 ? v : 1.0

  // 1. Mathematical Metric: Impact Efficiency = |Delta P| / (Aggressive Volume + eps)
  let ie = body / vNorm

  // 2. Rolling Historical Standardization (Z-Scores)
  let meanIe = ta.sma(ie, lookbackLen) ?? ie
  let stdIe  = ta.stdev(ie, lookbackLen) ?? 0.000001
  let zIe    = stdIe > 0.0000001 ? (ie - meanIe) / stdIe : 0.0

  let meanV  = ta.sma(v, lookbackLen) ?? v
  let stdV   = ta.stdev(v, lookbackLen) ?? 1.0
  let zV     = stdV > 0.0000001 ? (v - meanV) / stdV : 0.0

  let deltaRatio = d / vNorm

  // 3. Candle Geometry (Rejection wicks)
  let lowerWick = (c < o ? c : o) - l
  let upperWick = h - (c > o ? c : o)
  let lowerWickRatio = lowerWick / safeRange
  let upperWickRatio = upperWick / safeRange

  // 4. Reference Level Confluence (Script 01 alignment: PDH / PDL)
  let pdh = daily.high
  let pdl = daily.low
  let nearLevel = true
  if filterByLevels {
    let tol = atr * levelTolerance
    let nearPdh = pdh != null ? math.abs(c - pdh) <= tol : false
    let nearPdl = pdl != null ? math.abs(c - pdl) <= tol : false
    nearLevel = nearPdh || nearPdl
  }

  // 5. Detection Engine
  let isVolumeHeavy = zV >= minVolZ
  let isImpactLow   = zIe <= maxEffZ

  // Bullish Absorption: Heavy market selling (Delta << 0), price fails to break down, lower wick forms
  let isBullAbsorption = nearLevel && isVolumeHeavy && isImpactLow && (deltaRatio <= -minDeltaRatio) && (lowerWickRatio >= minWickRatio || c >= o)

  // Bearish Absorption: Heavy market buying (Delta >> 0), price fails to break up, upper wick forms
  let isBearAbsorption = nearLevel && isVolumeHeavy && isImpactLow && (deltaRatio >= minDeltaRatio) && (upperWickRatio >= minWickRatio || c <= o)

  // Exhaustion: New swing high/low with desiccated volume and stalled price action
  let highestHigh = ta.highest(chart.high, exhaustLookback) ?? h
  let lowestLow   = ta.lowest(chart.low, exhaustLookback) ?? l
  let atHigh = h >= highestHigh
  let atLow  = l <= lowestLow
  let isVolumeDry = zV <= exhaustVolMaxZ
  let isExhaustion = enableExhaust && nearLevel && (atHigh || atLow) && isVolumeDry && (body <= atr * 0.35)

  let forwardTime = t + time.bars(zoneBars)

  if isBullAbsorption {
    eventCount += 1
    lastEventStr = "Bull Absorption"
    lastZScore = zV
    let zAnomaly = math.min(3.5, math.max(1.0, zV - zIe))
    let alpha = int(math.clamp(zAnomaly * 20.0, 25.0, 80.0)) ?? 45
    let zoneCol = color.withAlpha(bullColor, alpha)

    boxes.get("abs", eventCount).set(
      t, h, forwardTime, l,
      color: zoneCol,
      borderWidth: 1.0,
      borderColor: bullColor,
      text: showLabels ? str.format("Absorp Buy (z={0:.1})", zV) : "",
      textColor: bullColor,
      textSize: 10.0,
    )
    markers.get("abs", eventCount).set(
      x: t, y: l,
      shape: shape.up,
      color: bullColor,
      size: 11.0,
    )
    absorptionAlert.trigger(EventPayload {
      kind: "Bullish Absorption",
      price: c,
      delta: d,
      zScore: zV,
    })
  }

  if isBearAbsorption {
    eventCount += 1
    lastEventStr = "Bear Absorption"
    lastZScore = zV
    let zAnomaly = math.min(3.5, math.max(1.0, zV - zIe))
    let alpha = int(math.clamp(zAnomaly * 20.0, 25.0, 80.0)) ?? 45
    let zoneCol = color.withAlpha(bearColor, alpha)

    boxes.get("abs", eventCount).set(
      t, h, forwardTime, l,
      color: zoneCol,
      borderWidth: 1.0,
      borderColor: bearColor,
      text: showLabels ? str.format("Absorp Sell (z={0:.1})", zV) : "",
      textColor: bearColor,
      textSize: 10.0,
    )
    markers.get("abs", eventCount).set(
      x: t, y: h,
      shape: shape.down,
      color: bearColor,
      size: 11.0,
    )
    absorptionAlert.trigger(EventPayload {
      kind: "Bearish Absorption",
      price: c,
      delta: d,
      zScore: zV,
    })
  }

  if isExhaustion && !isBullAbsorption && !isBearAbsorption {
    eventCount += 1
    let kindStr = atHigh ? "Exhaustion High" : "Exhaustion Low"
    lastEventStr = kindStr
    lastZScore = zV
    let zoneCol = color.withAlpha(exhaustColor, 35)

    boxes.get("exh", eventCount).set(
      t, h, forwardTime, l,
      color: zoneCol,
      borderWidth: 1.0,
      borderColor: exhaustColor,
      text: showLabels ? kindStr : "",
      textColor: exhaustColor,
      textSize: 10.0,
    )
    markers.get("exh", eventCount).set(
      x: t, y: atHigh ? h : l,
      shape: shape.circle,
      color: exhaustColor,
      size: 8.0,
    )
    exhaustionAlert.trigger(EventPayload {
      kind: kindStr,
      price: c,
      delta: d,
      zScore: zV,
    })
  }

  // 6. Viewport Heads-Up Display (HUD)
  if showHud {
    hudBox.get("bg").set(
      15.0, 15.0, 240.0, 130.0,
      rounding: 6.0,
      color: color.withAlpha(color.black, 210),
      borderColor: color.withAlpha(color.gray, 120),
      borderWidth: 1.0,
      zIndex: 10,
    )
    hudLabels.get("h0").set(
      25.0, 25.0, "ABSORPTION / EXHAUSTION",
      color: color.white, size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h1").set(
      25.0, 48.0, str.format("Volume Z-Score:  {0:+.2}", zV),
      color: zV >= minVolZ ? color.yellow : color.gray, size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h2").set(
      25.0, 68.0, str.format("Efficiency Z:    {0:+.2}", zIe),
      color: zIe <= maxEffZ ? color.cyan : color.gray, size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h3").set(
      25.0, 88.0, str.format("Delta Ratio:     {0:+.2}", deltaRatio),
      color: deltaRatio > 0.0 ? color.teal : color.orange, size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h4").set(
      25.0, 108.0, str.format("Last: {0} ({1:+.1}s)", lastEventStr, lastZScore),
      color: color.white, size: 10.0, font: font.mono, zIndex: 11,
    )
  }
}
