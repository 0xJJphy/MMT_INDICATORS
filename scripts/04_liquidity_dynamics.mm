script "Liquidity Dynamics"

// ============================================================================
// INDICATOR: Order Book Liquidity Dynamics [SCRIPT 04]
// ENGINE:    MMT Scripting v3 (Strictly Typed DSL)
// AUTHOR:    Senior Quantitative Strategist & Derivatives Architect
//
// QUANTITATIVE THESIS:
// 1. Static Level 2 snapshot views fail to capture market microstructure evolution.
//    Order Book Imbalance (OBI) must be tracked across multiple depth horizons:
//    - Micro-depth: Top 5 levels, Top 10 levels, and ±0.1% band (Immediate queue pressure).
//    - Macro-depth: ±0.5% and ±1.0% bands (Institutional structural backing).
//    OBI = (V_bid - V_ask) / (V_bid + V_ask) in range [-1.0, +1.0].
//
// 2. Liquidity Addition / Removal:
//    Measures delta in visible liquidity across consecutive order book snapshots:
//    Delta V_bid = V_bid(t) - V_bid(t-1), Delta V_ask = V_ask(t) - V_ask(t-1).
//    Net Liquidity Delta = Delta V_bid - Delta V_ask.
//
// 3. Liquidity Persistence & Fleeting Liquidity Patterns:
//    Distinguishes stable resting liquidity from ephemeral/fleeting orders.
//    When an anomalous concentration of liquidity appears (Z-score >= threshold)
//    and is rapidly pulled on subsequent snapshots without execution, it is flagged
//    objectively as "Fleeting Liquidity Withdrawn" (avoiding unprovable manipulation labels).
// ============================================================================

data (
  chart = subscribe(data.ohlcv)
  book  = subscribe(data.book)
)

input (
  input.tab(title: "Order Book Settings")
  input.group(title: "Imbalance Depths", collapsible: true)
  showBands     = input.bool(true, title: "Calculate ±0.1%, ±0.5%, ±1.0% Bands")

  input.group(title: "Fleeting Liquidity Filter", collapsible: true)
  fleetingZThreshold = input.float(1.8, title: "Fleeting Liquidity Spike Z-Score", min: 1.0, max: 4.0)

  input.tab(title: "Visuals & Panels")
  input.group(title: "Sub-Pane Layout", collapsible: true)
  obiColor01 = input.color(color.rgb(79, 195, 247),  title: "OBI ±0.1% Color")
  obiColor05 = input.color(color.rgb(255, 183, 77),  title: "OBI ±0.5% Color")
  obiColor10 = input.color(color.rgb(186, 104, 200), title: "OBI ±1.0% Color")
  showHud    = input.bool(true, title: "Show Viewport Order Book HUD")
)

pane obiPane   = pane(title: "Order Book Imbalance (OBI)", height: 0.25)
pane deltaPane = pane(title: "Net Book Liquidity Delta", height: 0.25)

plot (
  obi01Plot  = plot.line(title: "OBI ±0.1%", color: obiColor01, width: 1.5, on: obiPane)
  obi05Plot  = plot.line(title: "OBI ±0.5%", color: obiColor05, width: 1.5, on: obiPane)
  obi10Plot  = plot.line(title: "OBI ±1.0%", color: obiColor10, width: 2.0, on: obiPane)
  zeroObi    = plot.line(title: "Zero Line", color: color.gray, width: 1.0, on: obiPane)

  deltaHist  = plot.histogram(title: "Net Liquidity Delta", on: deltaPane)
)

type BookAlertPayload {
  kind: string
  obi10: float
  netDelta: float
  totalDepth: float
}

alert heavyImbalance = alert(payload: BookAlertPayload, title: "Heavy Order Book Imbalance", onClose: false)
alert fleetingAlert  = alert(payload: BookAlertPayload, title: "Fleeting Liquidity Detected", onClose: false)

state (
  prevBidVal: float = 0.0
  prevAskVal: float = 0.0
  hasPrev: bool = false

  // Rolling buffer for net liquidity delta baseline
  recentDeltas = rolling<float>(30)

  // Fleeting tracking
  lastAddedSide: string = "None"
  lastAddedVal: float = 0.0

  hudBox = entities.boxPool(max: 2, anchor: anchor.topRight)
  hudLabels = entities.labelPool(max: 10, anchor: anchor.topRight)

  fleetingCount: int = 0
  lastFleetingEvent: string = "None"
)

on chart.update {
  zeroObi.plot(0.0)

  // 1. Calculate Imbalance at Percentage Bands
  let d01 = book.depth(0.1)
  let d05 = book.depth(0.5)
  let d10 = book.depth(1.0)

  let obi01 = d01 != null ? d01.ratioValue : null
  let obi05 = d05 != null ? d05.ratioValue : null
  let obi10 = d10 != null ? d10.ratioValue : null

  obi01Plot.plot(showBands ? obi01 : null)
  obi05Plot.plot(showBands ? obi05 : null)
  obi10Plot.plot(showBands ? obi10 : null)

  // 2. Calculate Top 5 and Top 10 Levels Imbalance
  let top5BidsVal = 0.0
  let top5AsksVal = 0.0
  let top10BidsVal = 0.0
  let top10AsksVal = 0.0

  let bidsView = book.bids(0)
  let asksView = book.asks(0)

  if bidsView != null {
    let maxB = bidsView.len
    for i in 0..10 {
      if i < maxB {
        let level = bidsView[i]
        if level != null {
          let val = level.value
          if i < 5 {
            top5BidsVal += val
          }
          top10BidsVal += val
        }
      }
    }
  }

  if asksView != null {
    let maxA = asksView.len
    for i in 0..10 {
      if i < maxA {
        let level = asksView[i]
        if level != null {
          let val = level.value
          if i < 5 {
            top5AsksVal += val
          }
          top10AsksVal += val
        }
      }
    }
  }

  let top5Tot = top5BidsVal + top5AsksVal
  let obiTop5 = top5Tot > 0.0 ? (top5BidsVal - top5AsksVal) / top5Tot : 0.0

  let top10Tot = top10BidsVal + top10AsksVal
  let obiTop10 = top10Tot > 0.0 ? (top10BidsVal - top10AsksVal) / top10Tot : 0.0

  // 3. Liquidity Addition / Removal Dynamics (Snapshot changes)
  let curBidVal = d10 != null ? d10.bidValue : 0.0
  let curAskVal = d10 != null ? d10.askValue : 0.0
  let curTotVal = curBidVal + curAskVal

  let deltaBid = hasPrev ? curBidVal - prevBidVal : 0.0
  let deltaAsk = hasPrev ? curAskVal - prevAskVal : 0.0
  let netLiqDelta = deltaBid - deltaAsk

  if hasPrev {
    deltaHist.plot(netLiqDelta, color: netLiqDelta >= 0.0 ? color.teal : color.red)
    recentDeltas.push(math.abs(netLiqDelta))
  }

  // 4. Persistence & Fleeting Liquidity Detection
  let avgDelta = recentDeltas.avg() ?? (math.abs(netLiqDelta) > 0.0 ? math.abs(netLiqDelta) : 1.0)
  let zDelta = avgDelta > 0.0001 ? math.abs(netLiqDelta) / avgDelta : 0.0

  // Fleeting detection: Large addition last step followed by rapid removal this step
  if hasPrev && lastAddedSide == "Bid" && deltaBid < -lastAddedVal * 0.7 {
    fleetingCount += 1
    lastFleetingEvent = "Fleeting Bid Pulled"
    fleetingAlert.trigger(BookAlertPayload {
      kind: "Fleeting Bid Withdrawn",
      obi10: obi10 ?? 0.0,
      netDelta: netLiqDelta,
      totalDepth: curTotVal,
    })
  } else if hasPrev && lastAddedSide == "Ask" && deltaAsk < -lastAddedVal * 0.7 {
    fleetingCount += 1
    lastFleetingEvent = "Fleeting Ask Pulled"
    fleetingAlert.trigger(BookAlertPayload {
      kind: "Fleeting Ask Withdrawn",
      obi10: obi10 ?? 0.0,
      netDelta: netLiqDelta,
      totalDepth: curTotVal,
    })
  }

  // Record large additions for fleeting check on next bar
  if zDelta >= fleetingZThreshold {
    if deltaBid > deltaAsk && deltaBid > avgDelta * 1.5 {
      lastAddedSide = "Bid"
      lastAddedVal = deltaBid
    } else if deltaAsk > deltaBid && deltaAsk > avgDelta * 1.5 {
      lastAddedSide = "Ask"
      lastAddedVal = deltaAsk
    } else {
      lastAddedSide = "None"
      lastAddedVal = 0.0
    }
  } else {
    lastAddedSide = "None"
    lastAddedVal = 0.0
  }

  // Heavy imbalance alert
  if obi10 != null && math.abs(obi10 ?? 0.0) >= 0.60 {
    heavyImbalance.trigger(BookAlertPayload {
      kind: (obi10 ?? 0.0) > 0.0 ? "Heavy Bid Imbalance" : "Heavy Ask Imbalance",
      obi10: obi10 ?? 0.0,
      netDelta: netLiqDelta,
      totalDepth: curTotVal,
    })
  }

  prevBidVal = curBidVal
  prevAskVal = curAskVal
  hasPrev = true

  // 5. Viewport Heads-Up Display
  if showHud {
    hudBox.get("bg").set(
      15.0, 15.0, 260.0, 175.0,
      rounding: 6.0,
      color: color.withAlpha(color.black, 215),
      borderColor: color.withAlpha(color.gray, 120),
      borderWidth: 1.0,
      zIndex: 10,
    )
    hudLabels.get("h0").set(
      25.0, 25.0, "ORDER BOOK DYNAMICS",
      color: color.white, size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h1").set(
      25.0, 48.0, str.format("OBI Top 5:   {0:+.2}", obiTop5),
      color: obiTop5 > 0.0 ? color.teal : color.orange, size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h2").set(
      25.0, 68.0, str.format("OBI Top 10:  {0:+.2}", obiTop10),
      color: obiTop10 > 0.0 ? color.teal : color.orange, size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h3").set(
      25.0, 88.0, str.format("OBI (0.1%):  {0:+.2}", obi01 ?? 0.0),
      color: (obi01 ?? 0.0) > 0.0 ? color.teal : color.orange, size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h4").set(
      25.0, 108.0, str.format("OBI (1.0%):  {0:+.2}", obi10 ?? 0.0),
      color: (obi10 ?? 0.0) > 0.0 ? color.teal : color.orange, size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h5").set(
      25.0, 128.0, str.format("Net Delta:   {0:.0}", netLiqDelta),
      color: netLiqDelta > 0.0 ? color.teal : color.red, size: 10.0, font: font.mono, zIndex: 11,
    )
    hudLabels.get("h6").set(
      25.0, 148.0, str.format("Fleeting:    {0}", lastFleetingEvent),
      color: fleetingCount > 0 ? color.yellow : color.gray, size: 10.0, font: font.mono, zIndex: 11,
    )
  }
}
