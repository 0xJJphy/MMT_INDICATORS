script "Liquidity Sweep Detector"

// ============================================================================
// INDICATOR: Liquidity Sweep Detector & Failed Breakouts [SCRIPT 03]
// ENGINE:    MMT Scripting v3 (Strictly Typed DSL)
// AUTHOR:    Senior Quantitative Strategist & Derivatives Architect
//
// QUANTITATIVE THESIS:
// 1. A Liquidity Sweep occurs when price pierces a key structural reference
//    level (PDH/PDL, PWH/PWL, Swing Highs/Lows) where resting stop-loss liquidity
//    and breakout orders are clustered, followed by an immediate directional failure.
//
// 2. Strict 3-Way Classification:
//    - Sweep + Rejection:
//      Price breaches level past minimum penetration threshold, then reclaims
//      back inside the prior range within 'Max Reclaim Bars' with opposing
//      flow or candle rejection (Classic Failed Breakout).
//    - Sweep + Absorption:
//      Heavy aggressive participation (Volume Delta & Volume spike) occurs
//      during the breach, yet price stalls and fails to expand, absorbed by
//      large counterparty passive interest.
//    - Sweep + Acceptance:
//      Price penetrates and holds outside the reference level beyond the
//      reclaim window, establishing value outside the range (Confirmed Breakout).
//
// 3. Quantitative Integrity & Clean Visuals:
//    Avoids visual label stacking by mitigating swept benchmarks per session,
//    enforcing structural pivot detection (ta.pivotHigh/Low), sweep cooldown,
//    and compact institutional ray labeling.
// ============================================================================

data (
  chart  = subscribe(data.ohlcv)
  daily  = subscribe(data.ohlcv, timeframe: 1D)
  weekly = subscribe(data.ohlcv, timeframe: 1W)
  vd     = subscribe(data.vd)
  oi     = subscribe(data.oi)
)

input (
  input.tab(title: "Reference Levels")
  input.group(title: "Active Benchmarks", collapsible: true)
  usePdhPdl     = input.bool(true,  title: "Previous Day High / Low (PDH / PDL)")
  usePwhPwl     = input.bool(true,  title: "Previous Week High / Low (PWH / PWL)")
  useSwingPiv   = input.bool(true,  title: "Confirmed Swing High / Low Pivots")
  swingPivotLen = input.int(10,     title: "Swing Pivot Strength (Bars)", min: 3, max: 50)

  input.tab(title: "Sweep Mechanics")
  input.group(title: "Penetration & Reclaim", collapsible: true)
  minPenetrationAtr = input.float(0.10, title: "Minimum Penetration (x ATR)", min: 0.01, max: 2.0)
  maxReclaimBars    = input.int(3,      title: "Maximum Reclaim Time (Bars)", min: 1, max: 10)
  minDeltaRatio     = input.float(0.15, title: "Min Delta Imbalance During Sweep", min: 0.0, max: 0.8)
  minRelVol         = input.float(1.10, title: "Minimum Relative Volume (x Avg)", min: 0.5, max: 4.0)

  input.group(title: "Derivatives Confirmation", collapsible: true)
  useOiConfirm      = input.bool(true,  title: "Enable Open Interest Analysis")
  requireOiDrop     = input.bool(false, title: "Require OI Liquidation Drop for Sweeps")

  input.tab(title: "Visuals & Alerts")
  input.group(title: "Visual Style", collapsible: true)
  rejectionColor    = input.color(color.rgb(239, 83, 80),   title: "Sweep + Rejection Color")
  absorptionColor   = input.color(color.rgb(171, 71, 188), title: "Sweep + Absorption Color")
  acceptanceColor   = input.color(color.rgb(38, 166, 154),  title: "Sweep + Acceptance Color")
  showLevelRays     = input.bool(true,  title: "Draw Swept Level Rays")
  rayLengthBars     = input.int(8,      title: "Ray Length (Bars)", min: 2, max: 50)
  labelStyle        = input.select("Level Only", title: "Level Ray Label Style", options: ["Level Only", "Compact", "Clean", "Full"])
  markerSize        = input.float(7.5,  title: "Signal Marker Size", min: 4.0, max: 16.0)
  showHud           = input.bool(true,  title: "Show Viewport Statistics HUD")

  input.group(title: "Signal Filtering & Anti-Clutter", collapsible: true)
  sweepCooldownBars   = input.int(5,     title: "Minimum Bars Between Sweeps", min: 1, max: 30)
  singleSweepPerLevel = input.bool(true, title: "Mitigate Level After Confirmed Sweep")
  minClusterDistAtr   = input.float(0.3, title: "Min Cluster Separation (x ATR)", min: 0.0, max: 2.0)
)

type SweepEvent {
  kind: string
  levelName: string
  levelPrice: float
  penetrationPrice: float
  reclaimPrice: float
  delta: float
  oiChange: float
}

alert sweepRejection  = alert(payload: SweepEvent, title: "Sweep + Rejection", onClose: true)
alert sweepAbsorption = alert(payload: SweepEvent, title: "Sweep + Absorption", onClose: true)
alert sweepAcceptance = alert(payload: SweepEvent, title: "Sweep + Acceptance", onClose: true)

state (
  markers = entities.markerPool(max: 48)
  lines   = entities.linePool(max: 24)
  hudBox  = entities.boxPool(max: 2, anchor: anchor.topRight)
  hudLabels = entities.labelPool(max: 8, anchor: anchor.topRight)

  // Breach tracking
  highBreached: bool = false
  highLevelName: string = ""
  highLevelPrice: float = 0.0
  highSweepPeak: float = 0.0
  highBreachBar: int = 0
  highBreachTime: time = time.fromUnixSeconds(0)

  lowBreached: bool = false
  lowLevelName: string = ""
  lowLevelPrice: float = 0.0
  lowSweepTrough: float = 0.0
  lowBreachBar: int = 0
  lowBreachTime: time = time.fromUnixSeconds(0)

  // Level rollover & mitigation tracking
  lastPdhPrice: float = 0.0
  lastPdlPrice: float = 0.0
  lastPwhPrice: float = 0.0
  lastPwlPrice: float = 0.0
  pdhSwept: bool = false
  pdlSwept: bool = false
  pwhSwept: bool = false
  pwlSwept: bool = false

  // Swing pivot tracking
  activeSwingH: float? = null
  activeSwingL: float? = null
  swingHSwept: bool = false
  swingLSwept: bool = false

  // Cooldown tracking
  lastHighSweepBar: int = -999
  lastLowSweepBar: int = -999
  lastHighSweepPrice: float = 0.0
  lastLowSweepPrice: float = 0.0

  eventCount: int = 0
  lastEventKind: string = "None"
  lastLevelStr: string = "None"
)

on chart.close {
  let c = chart.close
  let o = chart.open
  let h = chart.high
  let l = chart.low
  let v = chart.volume
  let d = vd.close
  let t = chart.time
  let idx = chart.index

  if c == null || o == null || h == null || l == null || v == null || d == null || t == null {
    return
  }

  let atr = chart.atr(14) ?? (h - l > 0.0 ? h - l : 1.0)
  let minPen = atr * minPenetrationAtr
  let avgV = ta.sma(v, 20) ?? v
  let relVol = v / (avgV > 0.0 ? avgV : 1.0)
  let deltaRatio = d / (v > 0.0 ? v : 1.0)
  let dOi = ta.change(oi.close, 1) ?? 0.0

  let pdh = daily.high
  let pdl = daily.low
  let pwh = weekly.high
  let pwl = weekly.low

  // Daily benchmark rollover
  if pdh != null && pdh != lastPdhPrice {
    lastPdhPrice = pdh
    pdhSwept = false
  }
  if pdl != null && pdl != lastPdlPrice {
    lastPdlPrice = pdl
    pdlSwept = false
  }

  // Weekly benchmark rollover
  if pwh != null && pwh != lastPwhPrice {
    lastPwhPrice = pwh
    pwhSwept = false
  }
  if pwl != null && pwl != lastPwlPrice {
    lastPwlPrice = pwl
    pwlSwept = false
  }

  // Confirmed Swing Pivots
  let ph = ta.pivotHigh(chart.high, swingPivotLen, swingPivotLen)
  let pl = ta.pivotLow(chart.low, swingPivotLen, swingPivotLen)
  if ph != null {
    activeSwingH = ph
    swingHSwept = false
  }
  if pl != null {
    activeSwingL = pl
    swingLSwept = false
  }

  let swingH = activeSwingH
  let swingL = activeSwingL

  let canHighSweep = idx - lastHighSweepBar >= sweepCooldownBars
  let canLowSweep  = idx - lastLowSweepBar >= sweepCooldownBars

  // 1. Check for Pending High Breaches
  if highBreached {
    if h > highSweepPeak {
      highSweepPeak = h
    }
    let elapsed = idx - highBreachBar

    // Scenario A: Sweep Reclaimed back below level within allowed bars
    if c < highLevelPrice && elapsed <= maxReclaimBars {
      eventCount += 1
      let isAbsorbed = relVol >= minRelVol * 1.3 && math.abs(deltaRatio) >= minDeltaRatio
      let oiLiquidated = dOi < 0.0
      let validOi = !useOiConfirm || (!requireOiDrop || oiLiquidated)

      if validOi {
        let shortHighName = highLevelName == "Swing High" ? "SW-H" : highLevelName
        let lineText = match labelStyle {
          "Level Only" => shortHighName
          "Compact"    => str.format("{0} {1}", shortHighName, isAbsorbed ? "Abs" : "Rej")
          "Clean"      => ""
          "Full"       => str.format("{0} Swept & {1}", highLevelName, isAbsorbed ? "Absorbed" : "Rejected")
          _            => shortHighName
        }

        if isAbsorbed {
          lastEventKind = "High Sweep+Absorp"
          lastLevelStr = highLevelName
          markers.get("swp", eventCount).set(
            x: t, y: highSweepPeak,
            shape: shape.down,
            color: absorptionColor,
            size: markerSize * 1.1,
          )
          if showLevelRays {
            lines.get("lvl", eventCount).set(
              highBreachTime, highLevelPrice, t + time.bars(rayLengthBars), highLevelPrice,
              color: absorptionColor, style: linestyle.dashed, width: 1.5,
              text: lineText,
            )
          }
          sweepAbsorption.trigger(SweepEvent {
            kind: "Sweep + Absorption (Bearish)",
            levelName: highLevelName,
            levelPrice: highLevelPrice,
            penetrationPrice: highSweepPeak,
            reclaimPrice: c,
            delta: d,
            oiChange: dOi,
          })
        } else {
          lastEventKind = "High Sweep+Reject"
          lastLevelStr = highLevelName
          markers.get("swp", eventCount).set(
            x: t, y: highSweepPeak,
            shape: shape.down,
            color: rejectionColor,
            size: markerSize,
          )
          if showLevelRays {
            lines.get("lvl", eventCount).set(
              highBreachTime, highLevelPrice, t + time.bars(rayLengthBars), highLevelPrice,
              color: rejectionColor, style: linestyle.dashed, width: 1.5,
              text: lineText,
            )
          }
          sweepRejection.trigger(SweepEvent {
            kind: "Sweep + Rejection (Bearish)",
            levelName: highLevelName,
            levelPrice: highLevelPrice,
            penetrationPrice: highSweepPeak,
            reclaimPrice: c,
            delta: d,
            oiChange: dOi,
          })
        }

        // Mark level as mitigated
        if highLevelName == "PWH" {
          pwhSwept = true
        } else if highLevelName == "PDH" {
          pdhSwept = true
        } else if highLevelName == "Swing High" {
          swingHSwept = true
        }
        lastHighSweepBar = idx
        lastHighSweepPrice = highLevelPrice
      }
      highBreached = false
    } else if elapsed > maxReclaimBars {
      // Scenario B: Price maintained above level -> Sweep + Acceptance (Breakout)
      if c > highLevelPrice {
        eventCount += 1
        lastEventKind = "High Sweep+Accept"
        lastLevelStr = highLevelName
        markers.get("swp", eventCount).set(
          x: t, y: c,
          shape: shape.up,
          color: acceptanceColor,
          size: markerSize * 0.9,
        )
        sweepAcceptance.trigger(SweepEvent {
          kind: "Sweep + Acceptance (Bullish Breakout)",
          levelName: highLevelName,
          levelPrice: highLevelPrice,
          penetrationPrice: highSweepPeak,
          reclaimPrice: c,
          delta: d,
          oiChange: dOi,
        })

        if highLevelName == "PWH" {
          pwhSwept = true
        } else if highLevelName == "PDH" {
          pdhSwept = true
        } else if highLevelName == "Swing High" {
          swingHSwept = true
        }
        lastHighSweepBar = idx
        lastHighSweepPrice = highLevelPrice
      }
      highBreached = false
    }
  }

  // 2. Check for Pending Low Breaches
  if lowBreached {
    if l < lowSweepTrough {
      lowSweepTrough = l
    }
    let elapsed = idx - lowBreachBar

    // Scenario A: Sweep Reclaimed back below level within allowed bars
    if c > lowLevelPrice && elapsed <= maxReclaimBars {
      eventCount += 1
      let isAbsorbed = relVol >= minRelVol * 1.3 && math.abs(deltaRatio) >= minDeltaRatio
      let oiLiquidated = dOi < 0.0
      let validOi = !useOiConfirm || (!requireOiDrop || oiLiquidated)

      if validOi {
        let shortLowName = lowLevelName == "Swing Low" ? "SW-L" : lowLevelName
        let lineText = match labelStyle {
          "Level Only" => shortLowName
          "Compact"    => str.format("{0} {1}", shortLowName, isAbsorbed ? "Abs" : "Rej")
          "Clean"      => ""
          "Full"       => str.format("{0} Swept & {1}", lowLevelName, isAbsorbed ? "Absorbed" : "Rejected")
          _            => shortLowName
        }

        if isAbsorbed {
          lastEventKind = "Low Sweep+Absorp"
          lastLevelStr = lowLevelName
          markers.get("swp", eventCount).set(
            x: t, y: lowSweepTrough,
            shape: shape.up,
            color: absorptionColor,
            size: markerSize * 1.1,
          )
          if showLevelRays {
            lines.get("lvl", eventCount).set(
              lowBreachTime, lowLevelPrice, t + time.bars(rayLengthBars), lowLevelPrice,
              color: absorptionColor, style: linestyle.dashed, width: 1.5,
              text: lineText,
            )
          }
          sweepAbsorption.trigger(SweepEvent {
            kind: "Sweep + Absorption (Bullish)",
            levelName: lowLevelName,
            levelPrice: lowLevelPrice,
            penetrationPrice: lowSweepTrough,
            reclaimPrice: c,
            delta: d,
            oiChange: dOi,
          })
        } else {
          lastEventKind = "Low Sweep+Reject"
          lastLevelStr = lowLevelName
          markers.get("swp", eventCount).set(
            x: t, y: lowSweepTrough,
            shape: shape.up,
            color: rejectionColor,
            size: markerSize,
          )
          if showLevelRays {
            lines.get("lvl", eventCount).set(
              lowBreachTime, lowLevelPrice, t + time.bars(rayLengthBars), lowLevelPrice,
              color: rejectionColor, style: linestyle.dashed, width: 1.5,
              text: lineText,
            )
          }
          sweepRejection.trigger(SweepEvent {
            kind: "Sweep + Rejection (Bullish)",
            levelName: lowLevelName,
            levelPrice: lowLevelPrice,
            penetrationPrice: lowSweepTrough,
            reclaimPrice: c,
            delta: d,
            oiChange: dOi,
          })
        }

        // Mark level as mitigated
        if lowLevelName == "PWL" {
          pwlSwept = true
        } else if lowLevelName == "PDL" {
          pdlSwept = true
        } else if lowLevelName == "Swing Low" {
          swingLSwept = true
        }
        lastLowSweepBar = idx
        lastLowSweepPrice = lowLevelPrice
      }
      lowBreached = false
    } else if elapsed > maxReclaimBars {
      // Scenario B: Price maintained below level -> Sweep + Acceptance (Breakdown)
      if c < lowLevelPrice {
        eventCount += 1
        lastEventKind = "Low Sweep+Accept"
        lastLevelStr = lowLevelName
        markers.get("swp", eventCount).set(
          x: t, y: c,
          shape: shape.down,
          color: acceptanceColor,
          size: markerSize * 0.9,
        )
        sweepAcceptance.trigger(SweepEvent {
          kind: "Sweep + Acceptance (Bearish Breakdown)",
          levelName: lowLevelName,
          levelPrice: lowLevelPrice,
          penetrationPrice: lowSweepTrough,
          reclaimPrice: c,
          delta: d,
          oiChange: dOi,
        })

        if lowLevelName == "PWL" {
          pwlSwept = true
        } else if lowLevelName == "PDL" {
          pdlSwept = true
        } else if lowLevelName == "Swing Low" {
          swingLSwept = true
        }
        lastLowSweepBar = idx
        lastLowSweepPrice = lowLevelPrice
      }
      lowBreached = false
    }
  }

  // 3. New Penetration Detection
  // Check High Level Breaches
  if !highBreached && canHighSweep {
    let pwhCluster = math.abs((pwh ?? 0.0) - lastHighSweepPrice) < atr * minClusterDistAtr && (idx - lastHighSweepBar < sweepCooldownBars * 2)
    let pdhCluster = math.abs((pdh ?? 0.0) - lastHighSweepPrice) < atr * minClusterDistAtr && (idx - lastHighSweepBar < sweepCooldownBars * 2)
    let swpCluster = math.abs((swingH ?? 0.0) - lastHighSweepPrice) < atr * minClusterDistAtr && (idx - lastHighSweepBar < sweepCooldownBars * 2)

    if usePwhPwl && pwh != null && (!singleSweepPerLevel || !pwhSwept) && !pwhCluster && h > pwh + minPen && o <= pwh {
      highBreached = true
      highLevelName = "PWH"
      highLevelPrice = pwh
      highSweepPeak = h
      highBreachBar = idx
      highBreachTime = t
    } else if usePdhPdl && pdh != null && (!singleSweepPerLevel || !pdhSwept) && !pdhCluster && h > pdh + minPen && o <= pdh {
      highBreached = true
      highLevelName = "PDH"
      highLevelPrice = pdh
      highSweepPeak = h
      highBreachBar = idx
      highBreachTime = t
    } else if useSwingPiv && swingH != null && (!singleSweepPerLevel || !swingHSwept) && !swpCluster && h > (swingH ?? 0.0) + minPen && o <= (swingH ?? 0.0) {
      highBreached = true
      highLevelName = "Swing High"
      highLevelPrice = swingH ?? 0.0
      highSweepPeak = h
      highBreachBar = idx
      highBreachTime = t
    }
  }

  // Check Low Level Breaches
  if !lowBreached && canLowSweep {
    let pwlCluster = math.abs((pwl ?? 0.0) - lastLowSweepPrice) < atr * minClusterDistAtr && (idx - lastLowSweepBar < sweepCooldownBars * 2)
    let pdlCluster = math.abs((pdl ?? 0.0) - lastLowSweepPrice) < atr * minClusterDistAtr && (idx - lastLowSweepBar < sweepCooldownBars * 2)
    let swpCluster = math.abs((swingL ?? 0.0) - lastLowSweepPrice) < atr * minClusterDistAtr && (idx - lastLowSweepBar < sweepCooldownBars * 2)

    if usePwhPwl && pwl != null && (!singleSweepPerLevel || !pwlSwept) && !pwlCluster && l < pwl - minPen && o >= pwl {
      lowBreached = true
      lowLevelName = "PWL"
      lowLevelPrice = pwl
      lowSweepTrough = l
      lowBreachBar = idx
      lowBreachTime = t
    } else if usePdhPdl && pdl != null && (!singleSweepPerLevel || !pdlSwept) && !pdlCluster && l < pdl - minPen && o >= pdl {
      lowBreached = true
      lowLevelName = "PDL"
      lowLevelPrice = pdl
      lowSweepTrough = l
      lowBreachBar = idx
      lowBreachTime = t
    } else if useSwingPiv && swingL != null && (!singleSweepPerLevel || !swingLSwept) && !swpCluster && l < (swingL ?? 0.0) - minPen && o >= (swingL ?? 0.0) {
      lowBreached = true
      lowLevelName = "Swing Low"
      lowLevelPrice = swingL ?? 0.0
      lowSweepTrough = l
      lowBreachBar = idx
      lowBreachTime = t
    }
  }

  // 4. Viewport HUD
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
      25.0, 25.0, "LIQUIDITY SWEEP DETECTOR",
      color: color.white, size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h1").set(
      25.0, 48.0, str.format("Last Event:   {0}", lastEventKind),
      color: color.yellow, size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h2").set(
      25.0, 68.0, str.format("Level Swept:  {0}", lastLevelStr),
      color: color.cyan, size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h3").set(
      25.0, 88.0, str.format("Rel Vol (RV): {0:.2}x", relVol),
      color: relVol >= minRelVol ? color.teal : color.gray, size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h4").set(
      25.0, 108.0, str.format("Delta Ratio:  {0:+.2}", deltaRatio),
      color: deltaRatio > 0.0 ? color.teal : color.orange, size: 10.0, font: font.mono, zIndex: 11,
    )
  }
}
