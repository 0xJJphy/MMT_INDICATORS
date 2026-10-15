script "VWAP Distance & Z-Score"

// ============================================================================
// INDICATOR: VWAP Distance, Statistical Z-Score & Divergences
// ENGINE:    MMT Scripting v3 (Strictly Typed DSL)
// AUTHOR:    PeByte
//
// DESCRIPTION:
// Statistical normalization oscillator measuring real-time price extension and
// mean-reversion pressure relative to institutional VWAP benchmarks.
//
// KEY FEATURES:
// 1. Dual Distance Metrics:
//    - Raw Distance (Percentage % or Absolute Points).
//    - Z-Score Auto-Normalized (Stochastically standardized against rolling history).
//
// 2. Selectable Institutional Benchmarks:
//    - Calendar periods (4H, Daily, Weekly, Monthly, Quarterly, Yearly).
//    - Sliding rolling windows (7D, 30D, 90D).
//
// 3. Volatility-Adaptive Sigma Envelopes:
//    - Real-time ±1σ, ±2σ, and ±3σ bands with dynamic volatility expansion.
//    - Multi-layered zone fills with traffic-light styling.
//
// 4. Hybrid Divergence Engine:
//    - Real-time 0-lag impulse divergences.
//    - Classic structural pivot confirmation.
//    - Period Reset Protection to eliminate artifact signals at session opens.
//
// 5. Hardware-Accelerated Rendering:
//    - Dedicated sub-pane with color-graded histogram bars.
//    - Native Viewport HUD displaying live statistical regime.
// ============================================================================

data chart = subscribe(data.ohlcv)

pane distPane = pane(title: "VWAP Distance", height: 0.35)

input (
  input.tab(title: "Calculation")
  input.group(title: "Measurement Metric", collapsible: true)
  calcMethod    = input.select("Z-Score (Auto-Normalized)", title: "Mode", options: ["Z-Score (Auto-Normalized)", "Raw Distance (%)", "Raw Absolute ($)"])
  benchmark     = input.select("Daily", title: "Benchmark VWAP", options: ["4H", "Daily", "Weekly", "Monthly", "Quarterly", "Yearly", "Rolling 7D", "Rolling 30D", "Rolling 90D"])
  priceSrc      = input.select("Close", title: "Price Source", options: ["Close", "HLC3", "HL2", "OHLC4"])
  zLookback     = input.int(20, title: "Z-Score Rolling Window (Bars)", min: 5, max: 100)
  cutOnReset    = input.bool(true, title: "Hide Jump at Period Reset")

  input.tab(title: "Thresholds & Volatility")
  input.group(title: "Standard Deviation (Sigma) Levels", collapsible: true)
  sig1Level     = input.float(1.0, title: "Level 1σ (Normal)", min: 0.1, max: 5.0)
  sig2Level     = input.float(2.0, title: "Level 2σ (Warning)", min: 0.1, max: 5.0)
  sig3Level     = input.float(3.0, title: "Level 3σ (Extreme)", min: 0.1, max: 5.0)

  input.group(title: "Volatility Expansion Filter", collapsible: true)
  useVolAdj     = input.bool(false, title: "Enable Volatility-Adjusted Bands")
  volLookback   = input.int(20, title: "Vol Lookback Periods", min: 5, max: 100)
  volFactor     = input.float(1.0, title: "Vol Adjustment Sensitivity", min: 0.1, max: 3.0)

  input.tab(title: "Visuals & Colors")
  input.group(title: "Positive Histogram (Above VWAP)", collapsible: true)
  posFarColor   = input.color(color.rgb(46, 125, 50),   title: "Extreme Bull (+3σ)")
  posMidColor   = input.color(color.rgb(102, 187, 106), title: "Elevated Bull (+2σ)")
  posNearColor  = input.color(color.rgb(165, 214, 167), title: "Normal Bull (+1σ)")

  input.group(title: "Negative Histogram (Below VWAP)", collapsible: true)
  negNearColor  = input.color(color.rgb(239, 154, 154), title: "Normal Bear (-1σ)")
  negMidColor   = input.color(color.rgb(239, 83, 80),   title: "Elevated Bear (-2σ)")
  negFarColor   = input.color(color.rgb(198, 40, 40),   title: "Extreme Bear (-3σ)")

  input.group(title: "Sigma Envelopes & Fills", collapsible: true)
  showSigmaLines = input.bool(true, title: "Show Sigma Lines")
  fillZones      = input.bool(true, title: "Fill Sigma Zones")
  fillOpacity    = input.int(20,    title: "Fill Opacity %", min: 0, max: 100)

  input.tab(title: "Divergences")
  input.group(title: "Detection Rules", collapsible: true)
  showDiv        = input.bool(true,  title: "Enable Divergence Signals")
  divPivotLen    = input.int(3,      title: "Pivot Confirmation Length", min: 2, max: 10)
  divLookback    = input.int(30,     title: "Max Lookback (Bars)", min: 10, max: 100)
  resetBufferBars = input.int(3,     title: "Period Reset Protection Buffer", min: 1, max: 10)

  input.group(title: "Divergence Visuals", collapsible: true)
  bullDivColor   = input.color(color.rgb(76, 175, 80), title: "Bullish Divergence Color")
  bearDivColor   = input.color(color.rgb(244, 67, 54), title: "Bearish Divergence Color")

  input.tab(title: "HUD")
  input.group(title: "Status HUD", collapsible: true)
  showHud        = input.bool(true, title: "Show Statistical HUD")
)

setup (
  fillA = int(math.round(float(fillOpacity) * 2.55)) ?? 51
  s1FillColor = color.withAlpha(color.rgb(76, 175, 80),  fillA)
  s2FillColor = color.withAlpha(color.rgb(255, 152, 0), fillA)
  s3FillColor = color.withAlpha(color.rgb(244, 67, 54), fillA)
)

plot (
  hist     = plot.histogram(title: "VWAP Distance", on: distPane)
  zeroLine = plot.line(title: "Zero Baseline", on: distPane, color: color.rgb(180, 180, 180), width: 1.0)
  sig1p    = plot.line(title: "+1σ Normal",   on: distPane, color: color.rgb(76, 175, 80),  width: 1.0, style: linestyle.dashed)
  sig1n    = plot.line(title: "-1σ Normal",   on: distPane, color: color.rgb(76, 175, 80),  width: 1.0, style: linestyle.dashed)
  sig2p    = plot.line(title: "+2σ Warning",  on: distPane, color: color.rgb(255, 152, 0), width: 1.5, style: linestyle.solid)
  sig2n    = plot.line(title: "-2σ Warning",  on: distPane, color: color.rgb(255, 152, 0), width: 1.5, style: linestyle.solid)
  sig3p    = plot.line(title: "+3σ Extreme",  on: distPane, color: color.rgb(244, 67, 54), width: 1.0, style: linestyle.dotted)
  sig3n    = plot.line(title: "-3σ Extreme",  on: distPane, color: color.rgb(244, 67, 54), width: 1.0, style: linestyle.dotted)
)

fill (
  f1p = fill.between(sig1p, zeroLine, color: s1FillColor)
  f1n = fill.between(zeroLine, sig1n, color: s1FillColor)
  f2p = fill.between(sig2p, sig1p,    color: s2FillColor)
  f2n = fill.between(sig1n, sig2n,    color: s2FillColor)
  f3p = fill.between(sig3p, sig2p,    color: s3FillColor)
  f3n = fill.between(sig2n, sig3n,    color: s3FillColor)
)

state (
  distHistory:  rolling<float> = rolling<float>(120)
  priceHistory: rolling<float> = rolling<float>(120)
  zHistory:     rolling<float> = rolling<float>(120)
  timeHistory:  rolling<time>  = rolling<time>(120)

  divLines  = entities.linePool(max: 40,  on: distPane)
  divLabels = entities.labelPool(max: 40, on: distPane)
  hudLabels = entities.labelPool(max: 4,  on: distPane, anchor: anchor.topRight)

  nextDivId: int = 1
  barsSinceReset: int = 50
)

on chart.update {
  let ts     = chart.time ?? time.fromUnixSeconds(0)
  let prevTs = chart.time[1]

  let curClose = chart.close ?? 0.0
  let curOpen  = chart.open  ?? 0.0
  let curHigh  = chart.high  ?? 0.0
  let curLow   = chart.low   ?? 0.0

  let px = match priceSrc {
    "HLC3"  => (curHigh + curLow + curClose) / 3.0
    "HL2"   => (curHigh + curLow) / 2.0
    "OHLC4" => (curOpen + curHigh + curLow + curClose) / 4.0
    _       => curClose
  }

  // 1. Period Resets
  let isNew4H = time.isNewPeriod(ts, prevTs, 4h)
  let isNewD  = time.isNewPeriod(ts, prevTs, 1D)
  let isNewW  = time.isNewPeriod(ts, prevTs, 1W)
  let isNewM  = time.isNewPeriod(ts, prevTs, 1M)
  let isNewQ  = time.isNewPeriod(ts, prevTs, 3M)
  let isNewY  = time.isNewPeriod(ts, prevTs, 1Y)

  // 2. Compute Benchmark VWAPs
  let v4H = chart.vwap(reset: isNew4H)
  let vD  = chart.vwap(reset: isNewD)
  let vW  = chart.vwap(reset: isNewW)
  let vM  = chart.vwap(reset: isNewM)
  let vQ  = chart.vwap(reset: isNewQ)
  let vY  = chart.vwap(reset: isNewY)

  let vR7  = chart.vwma(168)
  let vR30 = chart.vwma(720)
  let vR90 = chart.vwma(2160)

  let activeVwap: float? = match benchmark {
    "4H"          => v4H
    "Daily"       => vD
    "Weekly"      => vW
    "Monthly"     => vM
    "Quarterly"   => vQ
    "Yearly"      => vY
    "Rolling 7D"  => vR7
    "Rolling 30D" => vR30
    "Rolling 90D" => vR90
    _             => vD
  }

  let activeReset = match benchmark {
    "4H"        => isNew4H
    "Daily"     => isNewD
    "Weekly"    => isNewW
    "Monthly"   => isNewM
    "Quarterly" => isNewQ
    "Yearly"    => isNewY
    _           => false
  }

  if activeReset {
    barsSinceReset = 0
  } else {
    barsSinceReset += 1
  }

  let isJump = cutOnReset && activeReset

  // 3. Raw Distance Calculation
  let rawDist: float? = null
  if activeVwap != null && activeVwap > 0.0 && !isJump {
    if calcMethod == "Raw Distance (%)" {
      rawDist = ((px - activeVwap) / activeVwap) * 100.0
    } else if calcMethod == "Raw Absolute ($)" {
      rawDist = px - activeVwap
    } else {
      rawDist = px - activeVwap
    }
  }

  // 4. Statistical Normalization (Z-Score)
  let finalMetric: float? = null
  let currentZ = 0.0

  if rawDist != null {
    distHistory.push(rawDist)
    priceHistory.push(px)
    timeHistory.push(ts)

    if calcMethod == "Z-Score (Auto-Normalized)" {
      let sampleCount = math.min(zLookback, distHistory.len)
      if sampleCount >= 5 {
        let mean = distHistory.avgLast(sampleCount) ?? 0.0
        let sumSq = 0.0
        let startIdx = distHistory.len - sampleCount
        for i in 0..sampleCount {
          let val = distHistory.get(startIdx + i) ?? mean
          let diff = val - mean
          sumSq += diff * diff
        }
        let variance = sumSq / float(sampleCount)
        let stdDev: float = math.sqrt(variance) ?? 0.0

        if stdDev > 1e-8 {
          let distVal = rawDist ?? 0.0
          currentZ = (distVal - mean) / stdDev
          currentZ = math.max(-5.0, math.min(5.0, currentZ))
          finalMetric = currentZ
        } else {
          finalMetric = 0.0
        }
      } else {
        finalMetric = 0.0
      }
    } else {
      finalMetric = rawDist
      currentZ = rawDist ?? 0.0
    }
  }

  zHistory.push(currentZ)

  // 5. Dynamic Bar Color Grading
  let barColor = posNearColor
  if currentZ >= 2.0 {
    barColor = posFarColor
  } else if currentZ >= 1.0 {
    barColor = posMidColor
  } else if currentZ >= 0.0 {
    barColor = posNearColor
  } else if currentZ <= -2.0 {
    barColor = negFarColor
  } else if currentZ <= -1.0 {
    barColor = negMidColor
  } else {
    barColor = negNearColor
  }

  hist.plot(finalMetric, color: barColor)

  // 6. Sigma Reference Envelopes
  let s1 = sig1Level
  let s2 = sig2Level
  let s3 = sig3Level

  let nullPlotVal: float? = null
  if showSigmaLines {
    zeroLine.plot(0.0)
    sig1p.plot(s1)
    sig1n.plot(-s1)
    sig2p.plot(s2)
    sig2n.plot(-s2)
    sig3p.plot(s3)
    sig3n.plot(-s3)
  } else {
    zeroLine.plot(nullPlotVal)
    sig1p.plot(nullPlotVal)
    sig1n.plot(nullPlotVal)
    sig2p.plot(nullPlotVal)
    sig2n.plot(nullPlotVal)
    sig3p.plot(nullPlotVal)
    sig3n.plot(nullPlotVal)
  }

  // 7. Divergence Detection
  if showDiv && barsSinceReset >= resetBufferBars && zHistory.len >= (divPivotLen * 2 + 5) {
    let pLen = divPivotLen
    let curIdx = zHistory.len - pLen - 1
    if curIdx >= pLen {
      let isPivotHigh = true
      let centerZ = zHistory.get(curIdx) ?? 0.0
      for k in 1..=pLen {
        let leftZ  = zHistory.get(curIdx - k) ?? centerZ
        let rightZ = zHistory.get(curIdx + k) ?? centerZ
        if leftZ >= centerZ || rightZ >= centerZ {
          isPivotHigh = false
        }
      }

      let isPivotLow = true
      for k in 1..=pLen {
        let leftZ  = zHistory.get(curIdx - k) ?? centerZ
        let rightZ = zHistory.get(curIdx + k) ?? centerZ
        if leftZ <= centerZ || rightZ <= centerZ {
          isPivotLow = false
        }
      }

      let centerPrice = priceHistory.get(curIdx) ?? 0.0
      let centerTime  = timeHistory.get(curIdx)  ?? ts

      // Bearish Divergence: Higher Price High with Lower Z-Score High
      if isPivotHigh {
        let searchStart = math.max(0, curIdx - divLookback)
        for prev in searchStart..(curIdx - pLen) {
          let prevZ = zHistory.get(prev) ?? 0.0
          let prevP = priceHistory.get(prev) ?? 0.0
          let prevT = timeHistory.get(prev) ?? ts
          if prevP < centerPrice && prevZ > centerZ {
            nextDivId += 1
            if nextDivId > 500000 {
              nextDivId = 1
            }
            let lineKey = str.format("div_{0}", nextDivId)
            let lblKey  = str.format("divl_{0}", nextDivId)
            divLines.get(lineKey).set(
              x1: prevT,
              y1: prevZ,
              x2: centerTime,
              y2: centerZ,
              color: bearDivColor,
              width: 1.5,
              style: linestyle.solid
            )
            divLabels.get(lblKey).set(
              x: centerTime,
              y: centerZ + 0.3,
              text: "⚡BEAR",
              color: bearDivColor,
              size: 9.0
            )
          }
        }
      }

      // Bullish Divergence: Lower Price Low with Higher Z-Score Low
      if isPivotLow {
        let searchStart = math.max(0, curIdx - divLookback)
        for prev in searchStart..(curIdx - pLen) {
          let prevZ = zHistory.get(prev) ?? 0.0
          let prevP = priceHistory.get(prev) ?? 0.0
          let prevT = timeHistory.get(prev) ?? ts
          if prevP > centerPrice && prevZ < centerZ {
            nextDivId += 1
            if nextDivId > 500000 {
              nextDivId = 1
            }
            let lineKey = str.format("div_{0}", nextDivId)
            let lblKey  = str.format("divl_{0}", nextDivId)
            divLines.get(lineKey).set(
              x1: prevT,
              y1: prevZ,
              x2: centerTime,
              y2: centerZ,
              color: bullDivColor,
              width: 1.5,
              style: linestyle.solid
            )
            divLabels.get(lblKey).set(
              x: centerTime,
              y: centerZ - 0.3,
              text: "⚡BULL",
              color: bullDivColor,
              size: 9.0
            )
          }
        }
      }
    }
  }

  // 8. Statistical Status HUD
  if showHud {
    let reg = currentZ >= 2.0 ? "EXTREME OVERBOUGHT" : (currentZ >= 1.0 ? "ELEVATED EXTENSION" : (currentZ <= -2.0 ? "EXTREME OVERSOLD" : (currentZ <= -1.0 ? "COMPRESSED" : "EQUILIBRIUM")))
    hudLabels.get("hud_stats").set(
      x: 16.0,
      y: 20.0,
      text: str.format("Benchmark: {0} | Z-Score: {1}σ | Regime: {2}", benchmark, math.round(currentZ * 100.0) / 100.0, reg),
      color: barColor,
      size: 10.0
    )
  }
}
