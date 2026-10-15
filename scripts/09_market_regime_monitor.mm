script "Market Regime Monitor"

// ============================================================================
// INDICATOR: Volatility & Liquidity Regime Monitor [SCRIPT 09]
// ENGINE:    MMT Scripting v3 (Strictly Typed DSL)
// AUTHOR:    Senior Quantitative Strategist & Derivatives Architect
//
// QUANTITATIVE THESIS:
// 1. Quantitative strategies cannot operate with static parameterizations across
//    radically different market regimes. A 4-quadrant state space is constructed
//    from Normalized Realized Volatility (ATR%) and Order Book Depth (L2 Liquidity):
//    - Regime 1: Low Volatility, High Liquidity (Mean-Reversion Paradise)
//      Tight spreads, minimal slippage, optimal for statistical arbitrage and market making.
//    - Regime 2: High Volatility, High Liquidity (Institutional Trend Expansion)
//      Heavy capacity, high institutional participation, strong momentum follow-through.
//    - Regime 3: Low Volatility, Low Liquidity (Illiquid Drift / Quiet Accumulation)
//      Thin volume, bracketed consolidation, low participation.
//    - Regime 4: High Volatility, Low Liquidity (Fragile / Liquidation Danger Zone)
//      Severe slippage risk, wide spreads, explosive gap hazard, liquidation cascade risk.
//
// 2. Adaptive Risk & Sizing Parameterization:
//    - R1: Risk Multiplier 1.00x (Standard allocation)
//    - R2: Risk Multiplier 1.25x (Trend capture sizing)
//    - R3: Risk Multiplier 0.75x (Reduced sizing due to thin liquidity)
//    - R4: Risk Multiplier 0.50x (Defensive / Capital preservation mode)
// ============================================================================

data (
  chart = subscribe(data.ohlcv)
  book  = subscribe(data.book)
)

input (
  input.tab(title: "Regime Parameters")
  input.group(title: "Volatility & Liquidity Baselines", collapsible: true)
  volLookback    = input.int(20,    title: "Volatility Baseline Period", min: 10, max: 100)
  depthBandPct   = input.float(0.5, title: "Order Book Depth Band (%)", min: 0.1, max: 2.0)
  depthLookback  = input.int(30,    title: "Depth Baseline Period", min: 10, max: 100)

  input.tab(title: "Visuals & Alerts")
  input.group(title: "Regime Colors", collapsible: true)
  colorRegime1   = input.color(color.rgb(76, 175, 80),   title: "R1: Low Vol / High Liq (Green)")
  colorRegime2   = input.color(color.rgb(33, 150, 243),  title: "R2: High Vol / High Liq (Blue)")
  colorRegime3   = input.color(color.rgb(255, 152, 0),   title: "R3: Low Vol / Low Liq (Orange)")
  colorRegime4   = input.color(color.rgb(244, 67, 54),   title: "R4: High Vol / Low Liq (Red)")
  showHud        = input.bool(true, title: "Show Regime HUD")
)

pane regimePane = pane(title: "Market Regime State (1 to 4)", height: 0.25)
pane metricsPane= pane(title: "Volatility vs Liquidity Z-Scores", height: 0.25)

plot (
  regimeState = plot.histogram(title: "Regime", on: regimePane)
  volZPlot    = plot.line(title: "Vol Z-Score", color: color.rgb(255, 183, 77), width: 1.5, on: metricsPane)
  liqZPlot    = plot.line(title: "Liq Depth Z-Score", color: color.rgb(79, 195, 247), width: 1.5, on: metricsPane)
  zeroLine    = plot.line(title: "Zero", color: color.gray, width: 1.0, on: metricsPane)
)

type RegimeAlertPayload {
  regimeNumber: int
  regimeName: string
  volatilityZ: float
  liquidityZ: float
  riskMultiplier: float
}

alert regimeShift = alert(payload: RegimeAlertPayload, title: "Market Regime Shift", onClose: true)

state (
  depthBuffer = rolling<float>(30)
  prevRegime: int = 0
  currentRegimeStr: string = "Initializing"
  currentRiskMult: float = 1.0

  hudBox = entities.boxPool(max: 2, anchor: anchor.topRight)
  hudLabels = entities.labelPool(max: 8, anchor: anchor.topRight)
)

on chart.close {
  zeroLine.plot(0.0)

  let c = chart.close
  let h = chart.high
  let l = chart.low

  if c == null || h == null || l == null {
    return
  }

  // 1. Normalized Volatility Metric: ATR% relative to its rolling baseline
  let atr = chart.atr(volLookback) ?? (h - l)
  let atrPct = c > 0.0 ? (atr / c) * 100.0 : 0.0
  let meanAtrPct = ta.sma(atrPct, volLookback) ?? atrPct
  let stdAtrPct  = ta.stdev(atrPct, volLookback) ?? 0.01
  let volZ = stdAtrPct > 0.0001 ? (atrPct - meanAtrPct) / stdAtrPct : 0.0
  volZPlot.plot(volZ)

  // 2. Order Book Liquidity Metric: Available depth within depthBandPct
  let depth = book.depth(depthBandPct)
  let curDepth = depth != null ? depth.totalValue : 0.0
  if curDepth > 0.0 {
    depthBuffer.push(curDepth)
  }

  let avgDepth = depthBuffer.avg() ?? (curDepth > 0.0 ? curDepth : 1.0)
  let countD = depthBuffer.len
  let varD = 0.0
  for i in 0..30 {
    if i < countD {
      let di = depthBuffer[i] ?? 0.0
      let diff = di - avgDepth
      varD += diff * diff
    }
  }
  let stdDepth = math.sqrt(varD / (countD > 1 ? float(countD - 1) : 1.0)) ?? 1.0
  let liqZ = stdDepth > 0.0001 ? (curDepth - avgDepth) / stdDepth : 0.0
  liqZPlot.plot(liqZ)

  // 3. Four-Quadrant Classification:
  let isVolHigh = volZ >= 0.0
  let isLiqHigh = liqZ >= 0.0

  let regimeNum = 1
  let regimeCol = colorRegime1
  let regimeName = "R1: Low Vol, High Liq"
  let riskMult = 1.0

  if !isVolHigh && isLiqHigh {
    regimeNum = 1
    regimeCol = colorRegime1
    regimeName = "R1: Low Vol, High Liq (Mean-Rev)"
    riskMult = 1.0
  } else if isVolHigh && isLiqHigh {
    regimeNum = 2
    regimeCol = colorRegime2
    regimeName = "R2: High Vol, High Liq (Trend Exp)"
    riskMult = 1.25
  } else if !isVolHigh && !isLiqHigh {
    regimeNum = 3
    regimeCol = colorRegime3
    regimeName = "R3: Low Vol, Low Liq (Illiquid Drift)"
    riskMult = 0.75
  } else {
    regimeNum = 4
    regimeCol = colorRegime4
    regimeName = "R4: High Vol, Low Liq (Fragile/Risk)"
    riskMult = 0.50
  }

  regimeState.plot(float(regimeNum), color: regimeCol)
  currentRegimeStr = regimeName
  currentRiskMult = riskMult

  if prevRegime != 0 && regimeNum != prevRegime {
    regimeShift.trigger(RegimeAlertPayload {
      regimeNumber: regimeNum,
      regimeName: regimeName,
      volatilityZ: volZ,
      liquidityZ: liqZ,
      riskMultiplier: riskMult,
    })
  }
  prevRegime = regimeNum

  // 4. Viewport HUD
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
      25.0, 25.0, "MARKET REGIME MONITOR",
      color: color.white, size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h1").set(
      25.0, 48.0, str.format("State:      {0}", currentRegimeStr),
      color: regimeCol, size: 9.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h2").set(
      25.0, 68.0, str.format("Vol Z:      {0:+.2}s", volZ),
      color: isVolHigh ? color.orange : color.teal, size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h3").set(
      25.0, 88.0, str.format("Depth Liq Z:{0:+.2}s", liqZ),
      color: isLiqHigh ? color.teal : color.red, size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h4").set(
      25.0, 108.0, str.format("Risk Multi: {0:.2}x", currentRiskMult),
      color: currentRiskMult >= 1.0 ? color.teal : color.orange, size: 10.0, font: font.mono, zIndex: 11,
    )
  }
}
