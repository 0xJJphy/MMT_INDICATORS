script "Derivatives Positioning Engine"

// ============================================================================
// INDICATOR: Derivatives Positioning & Open Interest Regimes [SCRIPT 06]
// ENGINE:    MMT Scripting v3 (Strictly Typed DSL)
// AUTHOR:    Senior Quantitative Strategist & Derivatives Architect
//
// QUANTITATIVE THESIS:
// 1. Price direction alone cannot differentiate whether a trend is driven by
//    new positioning capital or existing positioning de-risking/liquidating.
//    By combining Price displacement with Open Interest Delta (dOI), we establish
//    an objective 4-quadrant positioning taxonomy:
//    - Quadrant 1 (Price UP, OI UP):   Long Expansion (Aggressive buyers opening new longs).
//    - Quadrant 2 (Price UP, OI DOWN): Short Covering / Short Squeeze (Forced buy-backs).
//    - Quadrant 3 (Price DOWN, OI UP):   Short Expansion (Aggressive sellers opening new shorts).
//    - Quadrant 4 (Price DOWN, OI DOWN): Long Liquidation (Long de-risking / capitulation).
//
// 2. High-Probability Squeeze & Liquidation Cascade Engine:
//    Combines dOI contraction with Volume spikes, Volume Delta skew, and
//    Order Flow Liquidations / Funding Rates:
//    - Short Squeeze: Price surges + OI contracts sharply + positive Delta / buy liquidations.
//    - Long Cascade:  Price dumps + OI contracts sharply + negative Delta / sell liquidations.
//
// 3. Price-OI Lateral Divergence (Stealth Accumulation):
//    Detects extended consolidation (price compressed within tight band) while
//    OI expands dramatically, signaling institutional inventory build-up before expansion.
// ============================================================================

data (
  chart = subscribe(data.ohlcv)
  oi    = subscribe(data.oi)
  vd    = subscribe(data.vd)
  stat  = subscribe(data.stat)
)

input (
  input.tab(title: "Regime Classification")
  input.group(title: "Lookback & Thresholds", collapsible: true)
  oiChangeLen    = input.int(1,      title: "OI Change Lookback (Bars)", min: 1, max: 10)
  squeezeVolMult = input.float(1.5,  title: "Squeeze Volume Multiplier (x Avg)", min: 1.0, max: 5.0)
  minOiDropPct   = input.float(0.5,  title: "Min OI Drop for Squeeze (%)", min: 0.1, max: 5.0)

  input.group(title: "OI Divergence", collapsible: true)
  divergeLookback = input.int(24,    title: "OI Divergence Window (Bars)", min: 10, max: 60)
  maxPricePctMove = input.float(0.8, title: "Max Price Range for Flatness (%)", min: 0.1, max: 3.0)
  minOiExpansion  = input.float(2.0, title: "Min OI Expansion During Flat (%)", min: 0.5, max: 10.0)

  input.tab(title: "Visuals & Alerts")
  input.group(title: "Regime Colors", collapsible: true)
  colorLongBuild = input.color(color.rgb(38, 166, 154),  title: "Price UP + OI UP (Long Expansion)")
  colorCovering  = input.color(color.rgb(79, 195, 247),  title: "Price UP + OI DOWN (Short Covering)")
  colorShortBuild= input.color(color.rgb(239, 83, 80),   title: "Price DOWN + OI UP (Short Expansion)")
  colorUnwinding = input.color(color.rgb(255, 152, 0),   title: "Price DOWN + OI DOWN (Long Liquidation)")
  squeezeColor   = input.color(color.rgb(255, 215, 0),   title: "Short Squeeze Glow Color")
  showHud        = input.bool(true, title: "Show Positioning HUD")
)

pane oiChangePane = pane(title: "Open Interest Change & Regimes", height: 0.28)
pane oiLevelPane  = pane(title: "Open Interest Level", height: 0.22)

plot (
  oiChangeHist = plot.histogram(title: "OI Delta", on: oiChangePane)
  zeroLine     = plot.line(title: "Zero Baseline", color: color.gray, width: 1.0, on: oiChangePane)

  rawOiLine    = plot.line(title: "Open Interest", color: color.rgb(186, 104, 200), width: 1.5, on: oiLevelPane)
  oiSma        = plot.line(title: "OI SMA 20", color: color.rgb(120, 144, 156), width: 1.0, on: oiLevelPane)
)

type PosAlertPayload {
  kind: string
  price: float
  oiLevel: float
  dOi: float
  funding: float
}

alert squeezeAlert   = alert(payload: PosAlertPayload, title: "Short Squeeze Detected", onClose: true)
alert cascadeAlert   = alert(payload: PosAlertPayload, title: "Long Liquidation Cascade", onClose: true)
alert accumulateAlert= alert(payload: PosAlertPayload, title: "Silent OI Accumulation", onClose: true)

state (
  markers = entities.markerPool(max: 48)
  hudBox  = entities.boxPool(max: 2, anchor: anchor.topRight)
  hudLabels = entities.labelPool(max: 8, anchor: anchor.topRight)

  eventCount: int = 0
  lastRegimeStr: string = "None"
  lastSqueezeRisk: string = "Low"
)

on chart.close {
  zeroLine.plot(0.0)

  let c = chart.close
  let o = chart.open
  let h = chart.high
  let l = chart.low
  let v = chart.volume
  let t = chart.time
  let oiVal = oi.close
  let d = vd.close

  if c == null || o == null || h == null || l == null || v == null || t == null || oiVal == null {
    return
  }

  rawOiLine.plot(oiVal)
  oiSma.plot(ta.sma(oiVal, 20))

  let dOi = ta.change(oiVal, oiChangeLen)
  if dOi == null {
    return
  }
  let safeDoi = dOi ?? 0.0

  // 1. Four Objective Positioning Regimes
  let priceUp = c >= o
  let oiUp    = safeDoi >= 0.0

  let regimeColor = priceUp ? (oiUp ? colorLongBuild : colorCovering) : (oiUp ? colorShortBuild : colorUnwinding)
  oiChangeHist.plot(safeDoi, color: regimeColor)

  let regimeText = priceUp ? (oiUp ? "Long Expansion" : "Short Covering") : (oiUp ? "Short Expansion" : "Long Liquidation")
  lastRegimeStr = regimeText

  // 2. High-Probability Squeeze / Cascade Engine
  let avgV = ta.sma(v, 20) ?? v
  let isVolumeSurging = v >= avgV * squeezeVolMult
  let oiPctDrop = oiVal > 0.0 ? (math.abs(safeDoi) / oiVal) * 100.0 : 0.0
  let isSignificantOiDrop = safeDoi < 0.0 && oiPctDrop >= minOiDropPct

  let funding = stat.fundingRate ?? 0.0
  let buyLiq  = stat.buyLiq ?? 0.0
  let sellLiq = stat.sellLiq ?? 0.0

  // Short Squeeze: Price surges, OI plummets, aggressive delta positive, buy liquidations print
  let isShortSqueeze = priceUp && isSignificantOiDrop && isVolumeSurging && ((d ?? 0.0) > 0.0 || buyLiq > 0.0)

  // Long Liquidation Cascade: Price collapses, OI plummets, aggressive delta negative, sell liquidations print
  let isLongCascade  = !priceUp && isSignificantOiDrop && isVolumeSurging && ((d ?? 0.0) < 0.0 || sellLiq > 0.0)

  if isShortSqueeze {
    eventCount += 1
    lastSqueezeRisk = "SHORT SQUEEZE"
    markers.get("sqz", eventCount).set(
      x: t, y: h,
      shape: shape.up,
      color: squeezeColor,
      size: 13.0,
    )
    squeezeAlert.trigger(PosAlertPayload {
      kind: "Short Squeeze Detected",
      price: c,
      oiLevel: oiVal,
      dOi: safeDoi,
      funding: funding,
    })
  } else if isLongCascade {
    eventCount += 1
    lastSqueezeRisk = "LONG CASCADE"
    markers.get("sqz", eventCount).set(
      x: t, y: l,
      shape: shape.down,
      color: colorUnwinding,
      size: 13.0,
    )
    cascadeAlert.trigger(PosAlertPayload {
      kind: "Long Liquidation Cascade",
      price: c,
      oiLevel: oiVal,
      dOi: safeDoi,
      funding: funding,
    })
  } else {
    lastSqueezeRisk = "Normal"
  }

  // 3. Price & OI Divergence (Silent Accumulation during flat consolidation)
  let hiRange = ta.highest(chart.high, divergeLookback) ?? h
  let loRange = ta.lowest(chart.low, divergeLookback) ?? l
  let priceSpanPct = c > 0.0 ? ((hiRange - loRange) / c) * 100.0 : 0.0

  let pastOi = oi.close[divergeLookback] ?? oiVal
  let oiGrowthPct = pastOi > 0.0 ? ((oiVal - pastOi) / pastOi) * 100.0 : 0.0

  if priceSpanPct <= maxPricePctMove && oiGrowthPct >= minOiExpansion {
    // Silent position buildup during lateral consolidation
    accumulateAlert.trigger(PosAlertPayload {
      kind: "Silent OI Accumulation (Consolidation Divergence)",
      price: c,
      oiLevel: oiVal,
      dOi: safeDoi,
      funding: funding,
    })
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
      25.0, 25.0, "DERIVATIVES POSITIONING",
      color: color.white, size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h1").set(
      25.0, 48.0, str.format("Regime:       {0}", lastRegimeStr),
      color: regimeColor, size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h2").set(
      25.0, 68.0, str.format("OI Delta:     {0:+.0}", safeDoi),
      color: safeDoi >= 0.0 ? color.teal : color.orange, size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h3").set(
      25.0, 88.0, str.format("Funding Rate: {0:+.4}%", funding * 100.0),
      color: funding > 0.0 ? color.orange : color.teal, size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h4").set(
      25.0, 108.0, str.format("Squeeze State: {0}", lastSqueezeRisk),
      color: lastSqueezeRisk == "Normal" ? color.gray : color.yellow, size: 10.0, font: font.mono, zIndex: 11,
    )
  }
}
