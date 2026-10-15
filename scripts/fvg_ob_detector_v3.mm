script "FVG & OB Detector"

// ============================================================================
// INDICATOR: Fair Value Gap (FVG) & Order Block (OB) Detector [PeByte]
// ENGINE:    MMT Scripting v3 (Strict Typed DSL)
// AUTHOR:    PeByte
//
// DESCRIPTION:
// High-performance institutional Smart Money Concepts (SMC) engine designed
// to detect, track, and mitigate Fair Value Gaps (FVG) and Order Blocks (OB).
//
// KEY FEATURES:
// 1. Fair Value Gaps (FVG):
//    - 3-bar structural imbalance detection (+FVG Bullish / -FVG Bearish).
//    - Real-time progressive trimming: dynamically shrinks the gap as price absorbs it.
//    - Touch or Close-inside full mitigation tracking.
//
// 2. Order Blocks (OB):
//    - Break of Structure (BOS) swing detection with search-back for origin candle.
//    - Full wick range or Body-only definition.
//    - Cluster filter to prevent duplicate OBs during consecutive impulse bars.
//    - Mitigation at 50% Equilibrium (ICT Mean Threshold) or Zone Edge.
//
// 3. Projection & UX:
//    - "Current bar only": Zones advance strictly with the live candle, leaving future space clean.
//    - "Future bars offset" & "Infinite ray" options available.
//    - State retention buffer prioritizes active structural levels over mitigated zones.
// ============================================================================

data chart = subscribe(data.ohlcv)

input (
  input.tab(title: "General")
  input.group(title: "Detection Modes", collapsible: true)
  detectFvg        = input.bool(true, title: "Enable Fair Value Gaps (FVG)")
  detectOb         = input.bool(true, title: "Enable Order Blocks (OB)")

  input.group(title: "Zone Projection & Display", collapsible: true)
  extendMode       = input.select("Current bar only", title: "Live Zones Extension", options: ["Current bar only", "Future bars offset", "Infinite ray"])
  extendOffsetBars = input.int(20, title: "Offset Bars (if Future bars offset)", min: 1, max: 500)
  showLabels       = input.bool(true, title: "Show Text Labels on Zones (+FVG, -OB)")

  input.tab(title: "Mitigation")
  input.group(title: "Mitigation Rules", collapsible: true)
  completionMode   = input.select("Touch", title: "Mitigated by", options: ["Touch", "Close inside"])
  touchKind        = input.select("Wick", title: "Price Source", options: ["Wick", "Body"])
  obMitigateLevel  = input.select("50% Equilibrium", title: "OB Mitigation Level", options: ["50% Equilibrium", "Touch Zone Edge"])

  input.group(title: "Mitigated Zones Appearance", collapsible: true)
  mitigatedDisplay = input.select("Fade", title: "Display Mode", options: ["Fade", "Keep", "Hide"])
  mitigatedAlpha   = input.int(20, title: "Fade Opacity %", min: 0, max: 100)

  input.tab(title: "Algorithm")
  input.group(title: "Fair Value Gap (FVG)", collapsible: true)
  minFvgGap        = input.float(0.0, title: "Min FVG Gap Filter ($ / pts, 0 = all)", min: 0.0)
  progressiveTrim  = input.bool(true, title: "Progressive Trimming")

  input.group(title: "Order Block (OB)", collapsible: true)
  bosLookback      = input.int(10, title: "BOS Lookback Period (bars)", min: 2, max: 50)
  obSearchBack     = input.int(10, title: "Max Search-Back for Opposite Candle", min: 2, max: 50)
  obZoneType       = input.select("Full range", title: "OB Zone Height", options: ["Full range", "Body only"])
  obMinBars        = input.int(2, title: "Protection Bars (min age before mitigation)", min: 0, max: 20)
  obImpulsePct     = input.float(0.0, title: "Min Impulse Filter % (0 = immediate valid)", min: 0.0, max: 20.0)
  obClusterFilter  = input.bool(true, title: "Cluster Filter (merge adjacent OBs)")
  obClusterBars    = input.int(3, title: "Cluster Window (bars)", min: 1, max: 20)

  input.tab(title: "Style & Colors")
  input.group(title: "Fair Value Gaps Colors", collapsible: true)
  fvgBullBase      = input.color(color.rgb(90, 125, 113), title: "Bullish FVG Color")
  fvgBearBase      = input.color(color.rgb(178, 74, 74), title: "Bearish FVG Color")
  fvgAlpha         = input.int(65, title: "FVG Fill Opacity %", min: 0, max: 100)

  input.group(title: "Order Blocks Colors", collapsible: true)
  obBullBase       = input.color(color.rgb(0, 150, 136), title: "Bullish OB Color")
  obBearBase       = input.color(color.rgb(230, 81, 0), title: "Bearish OB Color")
  obAlpha          = input.int(60, title: "OB Fill Opacity %", min: 0, max: 100)
)

setup (
  fvgA = int(math.round(float(fvgAlpha) * 2.55)) ?? 165
  obA  = int(math.round(float(obAlpha) * 2.55)) ?? 153
  mitA = int(math.round(float(mitigatedAlpha) * 2.55)) ?? 51
  fvgBullLive = color.withAlpha(fvgBullBase, fvgA)
  fvgBearLive = color.withAlpha(fvgBearBase, fvgA)
  fvgBullFade = color.withAlpha(fvgBullBase, mitA)
  fvgBearFade = color.withAlpha(fvgBearBase, mitA)
  obBullLive  = color.withAlpha(obBullBase, obA)
  obBearLive  = color.withAlpha(obBearBase, obA)
  obBullFade  = color.withAlpha(obBullBase, mitA)
  obBearFade  = color.withAlpha(obBearBase, mitA)
)

type Zone {
  id: int
  kind: string
  dir: int
  startTime: time
  yTop: float
  yBot: float
  live: bool
  validated: bool
  refPrice: float
  extreme: float
  createdAtBar: int
  mitigatedTime: time?
}

state (
  fvgBoxes = entities.boxPool(max: 128)
  obBoxes  = entities.boxPool(max: 128)
  fvgZones = Zone[](120)
  obZones  = Zone[](120)
  nextFvgId: int = 0
  nextObId:  int = 0
  lastBarProcessed: int = -1
)

fn insertFvg(newZ: Zone) {
  if fvgZones.len < fvgZones.capacity {
    let _ = fvgZones.push(newZ)
    return
  }
  let replaceIdx: int = -1
  for k in 0..fvgZones.len {
    if replaceIdx == -1 {
      let z = fvgZones.get(k)
      if z != null && !z.live {
        replaceIdx = k
      }
    }
  }
  if replaceIdx != -1 {
    let oldZ = fvgZones.get(replaceIdx)
    if oldZ != null {
      let _ = fvgBoxes.delete("fvg", oldZ.id)
    }
    fvgZones.set(replaceIdx, newZ)
  } else {
    let oldZ = fvgZones.get(0)
    if oldZ != null {
      let _ = fvgBoxes.delete("fvg", oldZ.id)
    }
    fvgZones.set(0, newZ)
  }
}

fn insertOb(newZ: Zone) {
  if obZones.len < obZones.capacity {
    let _ = obZones.push(newZ)
    return
  }
  let replaceIdx: int = -1
  for k in 0..obZones.len {
    if replaceIdx == -1 {
      let z = obZones.get(k)
      if z != null && (!z.live || !z.validated) {
        replaceIdx = k
      }
    }
  }
  if replaceIdx != -1 {
    let oldZ = obZones.get(replaceIdx)
    if oldZ != null {
      let _ = obBoxes.delete("ob", oldZ.id)
    }
    obZones.set(replaceIdx, newZ)
  } else {
    let oldZ = obZones.get(0)
    if oldZ != null {
      let _ = obBoxes.delete("ob", oldZ.id)
    }
    obZones.set(0, newZ)
  }
}

on chart.update {
  let barIdx = chart.index
  if barIdx < 15 {
    return
  }

  // 1. Detection at bar close boundaries
  if barIdx != lastBarProcessed {
    lastBarProcessed = barIdx

    let c1 = chart.close[1]
    let o1 = chart.open[1]
    let h1 = chart.high[1]
    let l1 = chart.low[1]
    let t2 = chart.time[2]
    let h3 = chart.high[3]
    let l3 = chart.low[3]

    if c1 != null && o1 != null && h1 != null && l1 != null && t2 != null && h3 != null && l3 != null {
      // FVG Detection (3-bar pattern: bar 3, bar 2, bar 1)
      if detectFvg {
        // Bullish FVG
        if l1 > h3 {
          let gap = l1 - h3
          if gap >= minFvgGap {
            nextFvgId += 1
            if nextFvgId > 500000 {
              nextFvgId = 1
            }
            insertFvg(Zone {
              id: nextFvgId,
              kind: "FVG",
              dir: 1,
              startTime: t2,
              yTop: l1,
              yBot: h3,
              live: true,
              validated: true,
              refPrice: 0.0,
              extreme: 0.0,
              createdAtBar: barIdx - 1,
              mitigatedTime: null
            })
          }
        }

        // Bearish FVG
        if h1 < l3 {
          let gap = l3 - h1
          if gap >= minFvgGap {
            nextFvgId += 1
            if nextFvgId > 500000 {
              nextFvgId = 1
            }
            insertFvg(Zone {
              id: nextFvgId,
              kind: "FVG",
              dir: -1,
              startTime: t2,
              yTop: l3,
              yBot: h1,
              live: true,
              validated: true,
              refPrice: 0.0,
              extreme: 0.0,
              createdAtBar: barIdx - 1,
              mitigatedTime: null
            })
          }
        }
      }

      // OB Detection
      if detectOb {
        let hiPast = ta.highest(chart.high[2], bosLookback)
        let loPast = ta.lowest(chart.low[2], bosLookback)

        // Bullish BOS
        if hiPast != null && c1 > hiPast {
          let oppIdx: int = -1
          let searchLimit = obSearchBack + 2
          for k in 2..searchLimit {
            if oppIdx == -1 {
              let ck = chart.close[k]
              let ok = chart.open[k]
              if ck != null && ok != null && ck < ok {
                oppIdx = k
              }
            }
          }
          if oppIdx != -1 {
            let oppClose = chart.close[oppIdx] ?? 0.0
            let oppOpen  = chart.open[oppIdx] ?? 0.0
            let oppHigh  = chart.high[oppIdx] ?? 0.0
            let oppLow   = chart.low[oppIdx] ?? 0.0
            let oppTime  = chart.time[oppIdx] ?? t2
            let top = obZoneType == "Body only" ? math.max(oppOpen, oppClose) : oppHigh
            let bot = obZoneType == "Body only" ? math.min(oppOpen, oppClose) : oppLow

            // Cluster filter
            let isClustered: bool = false
            if obClusterFilter {
              for k in 0..obZones.len {
                if !isClustered {
                  let existingZ = obZones.get(k)
                  if existingZ != null && existingZ.live && existingZ.dir == 1 {
                    let barDist = (barIdx - 1) - existingZ.createdAtBar
                    if barDist <= obClusterBars {
                      isClustered = true
                    }
                  }
                }
              }
            }

            if top > bot && !isClustered {
              nextObId += 1
              if nextObId > 500000 {
                nextObId = 1
              }
              let isInstantValid = obImpulsePct <= 0.0
              insertOb(Zone {
                id: nextObId,
                kind: "OB",
                dir: 1,
                startTime: oppTime,
                yTop: top,
                yBot: bot,
                live: true,
                validated: isInstantValid,
                refPrice: c1,
                extreme: c1,
                createdAtBar: barIdx - 1,
                mitigatedTime: null
              })
            }
          }
        }

        // Bearish BOS
        if loPast != null && c1 < loPast {
          let oppIdx: int = -1
          let searchLimit = obSearchBack + 2
          for k in 2..searchLimit {
            if oppIdx == -1 {
              let ck = chart.close[k]
              let ok = chart.open[k]
              if ck != null && ok != null && ck > ok {
                oppIdx = k
              }
            }
          }
          if oppIdx != -1 {
            let oppClose = chart.close[oppIdx] ?? 0.0
            let oppOpen  = chart.open[oppIdx] ?? 0.0
            let oppHigh  = chart.high[oppIdx] ?? 0.0
            let oppLow   = chart.low[oppIdx] ?? 0.0
            let oppTime  = chart.time[oppIdx] ?? t2
            let top = obZoneType == "Body only" ? math.max(oppOpen, oppClose) : oppHigh
            let bot = obZoneType == "Body only" ? math.min(oppOpen, oppClose) : oppLow

            // Cluster filter
            let isClustered: bool = false
            if obClusterFilter {
              for k in 0..obZones.len {
                if !isClustered {
                  let existingZ = obZones.get(k)
                  if existingZ != null && existingZ.live && existingZ.dir == -1 {
                    let barDist = (barIdx - 1) - existingZ.createdAtBar
                    if barDist <= obClusterBars {
                      isClustered = true
                    }
                  }
                }
              }
            }

            if top > bot && !isClustered {
              nextObId += 1
              if nextObId > 500000 {
                nextObId = 1
              }
              let isInstantValid = obImpulsePct <= 0.0
              insertOb(Zone {
                id: nextObId,
                kind: "OB",
                dir: -1,
                startTime: oppTime,
                yTop: top,
                yBot: bot,
                live: true,
                validated: isInstantValid,
                refPrice: c1,
                extreme: c1,
                createdAtBar: barIdx - 1,
                mitigatedTime: null
              })
            }
          }
        }
      }
    }
  }

  // 2. Real-time testing & progressive mitigation on forming bar
  let curHigh  = chart.high ?? 0.0
  let curLow   = chart.low ?? 0.0
  let curOpen  = chart.open ?? 0.0
  let curClose = chart.close ?? 0.0
  let curTime  = chart.time ?? time.fromUnixSeconds(0)
  let barHi    = touchKind == "Body" ? math.max(curOpen, curClose) : curHigh
  let barLo    = touchKind == "Body" ? math.min(curOpen, curClose) : curLow

  // Mitigation & trimming for FVGs
  for i in 0..fvgZones.len {
    let z = fvgZones.get(i)
    if z != null && z.live {
      let mutZ = z
      if z.dir == 1 {
        // Bullish FVG
        if barLo <= z.yTop {
          if progressiveTrim {
            let newTop = math.min(z.yTop, math.max(barLo, z.yBot))
            if newTop <= z.yBot {
              mutZ = Zone {
                id: z.id,
                kind: z.kind,
                dir: z.dir,
                startTime: z.startTime,
                yTop: z.yBot,
                yBot: z.yBot,
                live: false,
                validated: z.validated,
                refPrice: z.refPrice,
                extreme: z.extreme,
                createdAtBar: z.createdAtBar,
                mitigatedTime: curTime
              }
            } else {
              mutZ = Zone {
                id: z.id,
                kind: z.kind,
                dir: z.dir,
                startTime: z.startTime,
                yTop: newTop,
                yBot: z.yBot,
                live: true,
                validated: z.validated,
                refPrice: z.refPrice,
                extreme: z.extreme,
                createdAtBar: z.createdAtBar,
                mitigatedTime: null
              }
            }
          } else {
            let mid = (z.yTop + z.yBot) / 2.0
            let touched = completionMode == "Close inside" ? curClose <= mid : barLo <= mid
            if touched {
              mutZ = Zone {
                id: z.id,
                kind: z.kind,
                dir: z.dir,
                startTime: z.startTime,
                yTop: z.yTop,
                yBot: z.yBot,
                live: false,
                validated: z.validated,
                refPrice: z.refPrice,
                extreme: z.extreme,
                createdAtBar: z.createdAtBar,
                mitigatedTime: curTime
              }
            }
          }
        }
      } else {
        // Bearish FVG
        if barHi >= z.yBot {
          if progressiveTrim {
            let newBot = math.max(z.yBot, math.min(barHi, z.yTop))
            if newBot >= z.yTop {
              mutZ = Zone {
                id: z.id,
                kind: z.kind,
                dir: z.dir,
                startTime: z.startTime,
                yTop: z.yTop,
                yBot: z.yTop,
                live: false,
                validated: z.validated,
                refPrice: z.refPrice,
                extreme: z.extreme,
                createdAtBar: z.createdAtBar,
                mitigatedTime: curTime
              }
            } else {
              mutZ = Zone {
                id: z.id,
                kind: z.kind,
                dir: z.dir,
                startTime: z.startTime,
                yTop: z.yTop,
                yBot: newBot,
                live: true,
                validated: z.validated,
                refPrice: z.refPrice,
                extreme: z.extreme,
                createdAtBar: z.createdAtBar,
                mitigatedTime: null
              }
            }
          } else {
            let mid = (z.yTop + z.yBot) / 2.0
            let touched = completionMode == "Close inside" ? curClose >= mid : barHi >= mid
            if touched {
              mutZ = Zone {
                id: z.id,
                kind: z.kind,
                dir: z.dir,
                startTime: z.startTime,
                yTop: z.yTop,
                yBot: z.yBot,
                live: false,
                validated: z.validated,
                refPrice: z.refPrice,
                extreme: z.extreme,
                createdAtBar: z.createdAtBar,
                mitigatedTime: curTime
              }
            }
          }
        }
      }
      fvgZones.set(i, mutZ)
    }
  }

  // Mitigation & validation for OBs
  for i in 0..obZones.len {
    let z = obZones.get(i)
    if z != null && z.live {
      let mutZ = z
      // Impulse check
      if !z.validated {
        let ext = z.dir == 1 ? math.max(z.extreme, curHigh) : math.min(z.extreme, curLow)
        let thr = obImpulsePct / 100.0
        let passed = z.dir == 1 ? ext >= z.refPrice * (1.0 + thr) : ext <= z.refPrice * (1.0 - thr)
        if passed {
          mutZ = Zone {
            id: z.id,
            kind: z.kind,
            dir: z.dir,
            startTime: z.startTime,
            yTop: z.yTop,
            yBot: z.yBot,
            live: true,
            validated: true,
            refPrice: z.refPrice,
            extreme: ext,
            createdAtBar: z.createdAtBar,
            mitigatedTime: null
          }
        } else {
          let top = z.yTop
          let bot = z.yBot
          let touched = z.dir == 1 ? barLo <= top : barHi >= bot
          if touched {
            // Cancelled before validation
            mutZ = Zone {
              id: z.id,
              kind: z.kind,
              dir: z.dir,
              startTime: z.startTime,
              yTop: z.yTop,
              yBot: z.yBot,
              live: false,
              validated: false,
              refPrice: z.refPrice,
              extreme: ext,
              createdAtBar: z.createdAtBar,
              mitigatedTime: curTime
            }
          } else {
            mutZ = Zone {
              id: z.id,
              kind: z.kind,
              dir: z.dir,
              startTime: z.startTime,
              yTop: z.yTop,
              yBot: z.yBot,
              live: true,
              validated: false,
              refPrice: z.refPrice,
              extreme: ext,
              createdAtBar: z.createdAtBar,
              mitigatedTime: null
            }
          }
        }
      }

      // Mitigation check for validated OB
      if mutZ.validated && mutZ.live {
        let barAge = barIdx - mutZ.createdAtBar
        if barAge >= obMinBars {
          let mid = (mutZ.yTop + mutZ.yBot) / 2.0
          let targetLevel = obMitigateLevel == "50% Equilibrium" ? mid : (mutZ.dir == 1 ? mutZ.yTop : mutZ.yBot)
          let crossed = false
          if mutZ.dir == 1 {
            crossed = completionMode == "Close inside" ? curClose <= targetLevel : barLo <= targetLevel
          } else {
            crossed = completionMode == "Close inside" ? curClose >= targetLevel : barHi >= targetLevel
          }
          if crossed {
            mutZ = Zone {
              id: mutZ.id,
              kind: mutZ.kind,
              dir: mutZ.dir,
              startTime: mutZ.startTime,
              yTop: mutZ.yTop,
              yBot: mutZ.yBot,
              live: false,
              validated: true,
              refPrice: mutZ.refPrice,
              extreme: mutZ.extreme,
              createdAtBar: mutZ.createdAtBar,
              mitigatedTime: curTime
            }
          }
        }
      }
      obZones.set(i, mutZ)
    }
  }

  // 3. Render boxes
  let liveFvgCount: int = 0
  let liveObCount: int = 0
  let extMode = extendMode == "Infinite ray" ? extend.right : extend.none
  let x2LiveTarget = extendMode == "Future bars offset" ? (curTime + time.bars(1 + extendOffsetBars)) : (curTime + time.bars(1))

  for i in 0..fvgZones.len {
    let z = fvgZones.get(i)
    if z != null {
      if z.live {
        liveFvgCount += 1
        let col = z.dir == 1 ? fvgBullLive : fvgBearLive
        let border = z.dir == 1 ? fvgBullBase : fvgBearBase
        let lbl = showLabels ? (z.dir == 1 ? "+FVG" : "-FVG") : ""
        fvgBoxes.get("fvg", z.id).set(
          x1: z.startTime,
          y1: z.yTop,
          x2: x2LiveTarget,
          y2: z.yBot,
          rounding: 2.0,
          color: col,
          borderWidth: 1.0,
          borderColor: border,
          extend: extMode,
          text: lbl,
          textColor: color.white,
          textSize: 9.0,
          zIndex: 1
        )
      } else {
        if mitigatedDisplay == "Hide" {
          let _ = fvgBoxes.delete("fvg", z.id)
        } else {
          let col = mitigatedDisplay == "Fade" ? (z.dir == 1 ? fvgBullFade : fvgBearFade) : (z.dir == 1 ? fvgBullLive : fvgBearLive)
          let border = mitigatedDisplay == "Fade" ? (z.dir == 1 ? fvgBullFade : fvgBearFade) : (z.dir == 1 ? fvgBullBase : fvgBearBase)
          let x2End = z.mitigatedTime ?? curTime
          fvgBoxes.get("fvg", z.id).set(
            x1: z.startTime,
            y1: z.yTop,
            x2: x2End,
            y2: z.yBot,
            rounding: 2.0,
            color: col,
            borderWidth: 1.0,
            borderColor: border,
            extend: extend.none,
            text: "",
            zIndex: 0
          )
        }
      }
    }
  }

  for i in 0..obZones.len {
    let z = obZones.get(i)
    if z != null {
      if z.live && z.validated {
        liveObCount += 1
        let col = z.dir == 1 ? obBullLive : obBearLive
        let border = z.dir == 1 ? obBullBase : obBearBase
        let lbl = showLabels ? (z.dir == 1 ? "+OB" : "-OB") : ""
        obBoxes.get("ob", z.id).set(
          x1: z.startTime,
          y1: z.yTop,
          x2: x2LiveTarget,
          y2: z.yBot,
          rounding: 2.0,
          color: col,
          borderWidth: 1.5,
          borderColor: border,
          extend: extMode,
          text: lbl,
          textColor: color.white,
          textSize: 10.0,
          zIndex: 2
        )
      } else {
        if mitigatedDisplay == "Hide" || !z.validated {
          let _ = obBoxes.delete("ob", z.id)
        } else {
          let col = mitigatedDisplay == "Fade" ? (z.dir == 1 ? obBullFade : obBearFade) : (z.dir == 1 ? obBullLive : obBearLive)
          let border = mitigatedDisplay == "Fade" ? (z.dir == 1 ? obBullFade : obBearFade) : (z.dir == 1 ? obBullBase : obBearBase)
          let x2End = z.mitigatedTime ?? curTime
          obBoxes.get("ob", z.id).set(
            x1: z.startTime,
            y1: z.yTop,
            x2: x2End,
            y2: z.yBot,
            rounding: 2.0,
            color: col,
            borderWidth: 1.0,
            borderColor: border,
            extend: extend.none,
            text: "",
            zIndex: 0
          )
        }
      }
    }
  }

  script.setTitle(str.format("FVG & OB Detector (Live FVG: {0} | OB: {1})", liveFvgCount, liveObCount))
}
