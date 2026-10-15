script "CVD Divergence Engine"

// ============================================================================
// INDICATOR: CVD & Price Divergence Engine [SCRIPT 05]
// ENGINE:    MMT Scripting v3 (Strictly Typed DSL)
// AUTHOR:    Senior Quantitative Strategist & Derivatives Architect
//
// QUANTITATIVE THESIS:
// 1. Classical Structural Divergence:
//    - Bearish Divergence: Price prints Higher High (HH) while Cumulative Volume
//      Delta (CVD) prints Lower High (LH). Aggressive buyers are exhausting.
//    - Bullish Divergence: Price prints Lower Low (LL) while CVD prints Higher Low (HL).
//      Aggressive sellers are exhausting.
//    - Absorption Divergence: Price is flat/consolidating while CVD expands aggressively
//      (Extreme delta without price progress -> Passive limit absorption).
//    - Trend Confirmation: HH in Price + HH in CVD (Bullish confirmation) or
//      LL in Price + LL in CVD (Bearish confirmation).
//
// 2. Statistical Divergence (Rolling OLS Linear Regression):
//    Models the instantaneous price impact function:
//    Delta P_t = alpha + beta * Delta CVD_t + epsilon_t
//    The estimated residual epsilon_t = Delta P_t - (alpha_hat + beta_hat * Delta CVD_t)
//    represents the price displacement unexplained by aggressive flow.
//    Standardized studentized residuals (|Z_eps| >= 2.0 sigma) flag severe
//    anomalies: either liquidity vacuums (huge price move on tiny flow) or
//    massive absorption (huge flow with zero price move).
// ============================================================================

data (
  chart = subscribe(data.ohlcv)
  cvd   = subscribe(data.cvd)
)

input (
  input.tab(title: "Structural Divergence")
  input.group(title: "Pivot Strength", collapsible: true)
  pivotLen       = input.int(7,     title: "Pivot Confirmation Length (Bars)", min: 2, max: 25)
  maxLookback    = input.int(35,    title: "Max Bars Between Pivots", min: 10, max: 80)

  input.tab(title: "Statistical Divergence")
  input.group(title: "Rolling OLS Model", collapsible: true)
  enableOls      = input.bool(true, title: "Enable OLS Residual Engine")
  olsWindow      = input.int(30,    title: "OLS Rolling Lookback (Bars)", min: 10, max: 60)
  residualZLimit = input.float(2.0, title: "Residual Anomaly Threshold (Sigma)", min: 1.0, max: 4.0)

  input.tab(title: "Visuals & Alerts")
  input.group(title: "Color Palette", collapsible: true)
  bullColor      = input.color(color.rgb(38, 166, 154), title: "Bullish Divergence Color")
  bearColor      = input.color(color.rgb(239, 83, 80),   title: "Bearish Divergence Color")
  statColor      = input.color(color.rgb(255, 202, 40),  title: "Statistical Anomaly Color")
  showHud        = input.bool(true, title: "Show Viewport Statistics HUD")
)

pane cvdPane = pane(title: "Cumulative Volume Delta (CVD)", height: 0.28)

plot (
  cvdLine = plot.line(title: "CVD", color: color.rgb(0, 188, 212), width: 1.5, on: cvdPane)
  zeroCvd = plot.line(title: "Baseline", color: color.gray, width: 1.0, on: cvdPane)
)

type DivAlertPayload {
  kind: string
  price: float
  cvdVal: float
  zScore: float
}

alert structuralDiv  = alert(payload: DivAlertPayload, title: "Structural CVD Divergence", onClose: true)
alert statisticalDiv = alert(payload: DivAlertPayload, title: "Statistical CVD Anomaly", onClose: true)

state (
  markers = entities.markerPool(max: 48)
  lines   = entities.linePool(max: 24)
  hudBox  = entities.boxPool(max: 2, anchor: anchor.topRight)
  hudLabels = entities.labelPool(max: 8, anchor: anchor.topRight)

  // Structural pivots memory
  prevHighPrice: float? = null
  prevHighCvd:   float? = null
  prevHighTime:  time = time.fromUnixSeconds(0)

  prevLowPrice:  float? = null
  prevLowCvd:    float? = null
  prevLowTime:   time = time.fromUnixSeconds(0)

  // OLS Rolling Buffers
  xs = rolling<float>(30)
  ys = rolling<float>(30)
  resids = rolling<float>(30)

  eventCount: int = 0
  lastEventStr: string = "None"
  lastZScore: float = 0.0
  lastBeta: float = 0.0
)

on chart.close {
  zeroCvd.plot(0.0)

  let c = chart.close
  let o = chart.open
  let h = chart.high
  let l = chart.low
  let t = chart.time
  let cvdNow = cvd.close

  if c == null || o == null || h == null || l == null || t == null || cvdNow == null {
    return
  }

  cvdLine.plot(cvdNow)

  let dP = c - (chart.close[1] ?? o)
  let dCvd = cvdNow - (cvd.close[1] ?? cvdNow)

  xs.push(dCvd)
  ys.push(dP)

  // 1. Rolling OLS: dP = alpha + beta * dCvd + eps
  let count = xs.len
  let zResidual = 0.0
  if count >= 10 {
    let meanX = xs.avg() ?? 0.0
    let meanY = ys.avg() ?? 0.0

    let varX = 0.0
    let covXY = 0.0
    for i in 0..30 {
      if i < count {
        let xi = xs[i] ?? 0.0
        let yi = ys[i] ?? 0.0
        let dx = xi - meanX
        let dy = yi - meanY
        varX += dx * dx
        covXY += dx * dy
      }
    }
    let beta = varX > 0.00000001 ? covXY / varX : 0.0
    let alpha = meanY - beta * meanX
    lastBeta = beta

    let expectedDp = alpha + beta * dCvd
    let residual = dP - expectedDp
    resids.push(residual)

    let rCount = resids.len
    let rMean = resids.avg() ?? 0.0
    let rVar = 0.0
    for i in 0..30 {
      if i < rCount {
        let ri = resids[i] ?? 0.0
        let dr = ri - rMean
        rVar += dr * dr
      }
    }
    let rStd = math.sqrt(rVar / (rCount > 1 ? float(rCount - 1) : 1.0)) ?? 1.0
    zResidual = rStd > 0.000001 ? (residual - rMean) / rStd : 0.0

    // Statistical Anomaly Trigger
    if enableOls && math.abs(zResidual) >= residualZLimit {
      eventCount += 1
      lastEventStr = zResidual > 0.0 ? "Stat +Resid (Flow Vacuum)" : "Stat -Resid (Flow Absorption)"
      lastZScore = zResidual

      markers.get("stat", eventCount).set(
        x: t, y: zResidual > 0.0 ? h : l,
        shape: shape.circle,
        color: statColor,
        size: 9.0,
      )
      statisticalDiv.trigger(DivAlertPayload {
        kind: lastEventStr,
        price: c,
        cvdVal: cvdNow,
        zScore: zResidual,
      })
    }
  }

  // 2. Structural Divergence Engine
  let pivotHigh = ta.pivotHigh(chart.high, pivotLen, pivotLen)
  let pivotLow  = ta.pivotLow(chart.low, pivotLen, pivotLen)
  let pivotTime = t - time.bars(pivotLen)

  if pivotHigh != null {
    let cvdAtHigh = cvd.close[pivotLen]
    if prevHighPrice != null && prevHighCvd != null && cvdAtHigh != null {
      let isHigherHighPrice = (pivotHigh ?? 0.0) > (prevHighPrice ?? 0.0)
      let isLowerHighCvd    = (cvdAtHigh ?? 0.0) < (prevHighCvd ?? 0.0)

      if isHigherHighPrice && isLowerHighCvd {
        eventCount += 1
        lastEventStr = "Bearish Structural Div"
        lastZScore = -2.0

        markers.get("div", eventCount).set(
          x: pivotTime, y: (pivotHigh ?? 0.0),
          shape: shape.down,
          color: bearColor,
          size: 12.0,
        )
        lines.get("div", eventCount).set(
          prevHighTime, (prevHighPrice ?? 0.0), pivotTime, (pivotHigh ?? 0.0),
          color: bearColor, style: linestyle.dashed, width: 1.5,
          text: "Bear CVD Div",
        )
        structuralDiv.trigger(DivAlertPayload {
          kind: "Bearish Structural Divergence",
          price: pivotHigh ?? 0.0,
          cvdVal: cvdAtHigh ?? 0.0,
          zScore: -2.0,
        })
      }
    }
    prevHighPrice = pivotHigh
    prevHighCvd = cvdAtHigh
    prevHighTime = pivotTime
  }

  if pivotLow != null {
    let cvdAtLow = cvd.close[pivotLen]
    if prevLowPrice != null && prevLowCvd != null && cvdAtLow != null {
      let isLowerLowPrice = (pivotLow ?? 0.0) < (prevLowPrice ?? 0.0)
      let isHigherLowCvd  = (cvdAtLow ?? 0.0) > (prevLowCvd ?? 0.0)

      if isLowerLowPrice && isHigherLowCvd {
        eventCount += 1
        lastEventStr = "Bullish Structural Div"
        lastZScore = 2.0

        markers.get("div", eventCount).set(
          x: pivotTime, y: (pivotLow ?? 0.0),
          shape: shape.up,
          color: bullColor,
          size: 12.0,
        )
        lines.get("div", eventCount).set(
          prevLowTime, (prevLowPrice ?? 0.0), pivotTime, (pivotLow ?? 0.0),
          color: bullColor, style: linestyle.dashed, width: 1.5,
          text: "Bull CVD Div",
        )
        structuralDiv.trigger(DivAlertPayload {
          kind: "Bullish Structural Divergence",
          price: pivotLow ?? 0.0,
          cvdVal: cvdAtLow ?? 0.0,
          zScore: 2.0,
        })
      }
    }
    prevLowPrice = pivotLow
    prevLowCvd = cvdAtLow
    prevLowTime = pivotTime
  }

  // 3. Viewport HUD
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
      25.0, 25.0, "CVD DIVERGENCE ENGINE",
      color: color.white, size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h1").set(
      25.0, 48.0, str.format("OLS Beta (Slope): {0:.4}", lastBeta),
      color: lastBeta > 0.0 ? color.teal : color.orange, size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h2").set(
      25.0, 68.0, str.format("Residual Z-Score: {0:+.2}", zResidual),
      color: math.abs(zResidual) >= residualZLimit ? color.yellow : color.gray, size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h3").set(
      25.0, 88.0, str.format("CVD Value:        {0:.0}", cvdNow),
      color: cvdNow >= 0.0 ? color.teal : color.red, size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h4").set(
      25.0, 108.0, str.format("Last: {0} ({1:+.1}s)", lastEventStr, lastZScore),
      color: color.white, size: 10.0, font: font.mono, zIndex: 11,
    )
  }
}
