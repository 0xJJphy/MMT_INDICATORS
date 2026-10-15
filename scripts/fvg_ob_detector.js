// =====================================================
// FVG & OB (overlay) · Opposite-candle anchored OBs
// v4.3 — Anclaje VISUAL desde origen cuando el modo es BOS bar
//        (no cambia la lógica de detección/mitigación)
// =====================================================

indicator("FVG & OB · Opposite Candle Anchor · Progressive Fill · Debug", true)

/* ───────── Inputs ───────── */
input.section("═══ GENERAL ═══")
const detectFVG = input.bool("Detect FVG", true)
const detectOB = input.bool("Detect Order Blocks (OB)", true)
const lookbackBars = input.int("Lookback bars (detection window)", 100, {
    min: 20,
    max: 500
})
const onlyWhenRightClosed = input.bool(
    "Detect only when right bar is closed",
    true
)
const extendRight = input.int("Extend zones to right (bars)", 200, {
    min: 10,
    max: 2000
})

input.section("═══ MITIGATION LOGIC ═══")
const completionMode = input.select("Completed by", 0, {
    selectables: ["Touch (tocar zona)", "Close inside (cierre en zona)"]
})
const touchKind = input.select("Touch kind", 0, {
    selectables: ["Wick (mecha)", "Body (cuerpo)"]
})
const mitigatedDisplayMode = input.select("Mitigated zones display", 2, {
    selectables: [
        "Hide completely (ocultar)",
        "Fade (desvanecer)",
        "Keep visible until mitigation bar (mantener hasta vela de mitigación)"
    ]
})
const mitigatedAlphaKeepMode = input.int(
    "Mitigated opacity in Keep mode (0-100)",
    75,
    { min: 0, max: 100 }
)
const fvgFadeAlpha = input.int("FVG fade opacity (0-100)", 85, {
    min: 0,
    max: 100
})
const obFadeAlpha = input.int("OB fade opacity (0-100)", 70, {
    min: 0,
    max: 100
})

input.section("═══ FVG SETTINGS ═══")
const minFvgGap = input.float("Min FVG gap filter (0 = disabled)", 0.0, {
    min: 0.0,
    max: 99999.0
})
const progressiveTrim = input.bool(
    "Progressive trimming (recorte progresivo)",
    true
)
const fvgBullBase = input.color("FVG Bullish color", "#5A7D71")
const fvgBearBase = input.color("FVG Bearish color", "#B24A4A")
const fvgAlpha = input.int("FVG opacity (0–100)", 72, { min: 0, max: 100 })

input.section("═══ ORDER BLOCK SETTINGS ═══")
const bosLB = input.int("BOS lookback (bars)", 10, { min: 1, max: 50 })
const obZoneType = input.select("OB zone type", 1, {
    selectables: ["Body only (solo cuerpo)", "Full range (with wicks)"]
})
const obSearchBack = input.int("OB search-back (max bars)", 10, {
    min: 3,
    max: 200
})
const obAnchorMode = input.select("OB anchor point", 1, {
    selectables: ["Opposite candle (standard)", "BOS bar"]
})
const obBaseMode = input.select("OB base span", 0, {
    selectables: [
        "Last opposite only",
        "Opposite → BOS-1 (full base)",
        "Fixed N ending at BOS-1"
    ]
})
const obBaseN = input.int("Base N bars (if Fixed N)", 3, { min: 1, max: 50 })
const obMinBars = input.int(
    "OB protection bars (min age before mitigation)",
    3,
    { min: 0, max: 20 }
)
const obImpulsePct = input.float("OB impulse threshold (%)", 1.5, {
    min: 0.0,
    max: 100.0
})
const obClusterBars = input.int("OB cluster window (bars)", 3, {
    min: 1,
    max: 20
})
const hueBullOB = input.color("OB Bullish color", color.Teal)
const hueBearOB = input.color("OB Bearish color", color.Orange)
const obAlpha = input.int("OB opacity (0–100)", 46, { min: 0, max: 100 })

input.section("═══ DEBUG ═══")
const showDebug = input.bool("Show debug info", false)

/* ───────── Paleta procesada ───────── */
const ob_bullColor = transp(darken(hueBullOB, 8), obAlpha)
const ob_bearColor = transp(darken(hueBearOB, 8), obAlpha)
const fvg_bullColor = transp(fvgBullBase, fvgAlpha)
const fvg_bearColor = transp(fvgBearBase, fvgAlpha)

/* ───────── Data buffers ───────── */
const ohlc = subscribe(data.OHLCV)
const hs = [],
    ls = [],
    os = [],
    cs = [],
    ts = []
let globalBarIndex = 0
function pushBar(h, l, o, c, t) {
    hs.push(h)
    ls.push(l)
    os.push(o)
    cs.push(c)
    ts.push(t)
    globalBarIndex++
    if (hs.length > Math.max(lookbackBars + 10, extendRight + 10)) {
        hs.shift()
        ls.shift()
        os.shift()
        cs.shift()
        ts.shift()
    }
}
function updateBar(h, l, o, c, t) {
    if (hs.length === 0) {
        pushBar(h, l, o, c, t)
        return
    }
    hs[hs.length - 1] = h
    ls[hs.length - 1] = l
    os[hs.length - 1] = o
    cs[hs.length - 1] = c
    ts[hs.length - 1] = t
}
function idxValid(i) {
    return i >= 0 && i < hs.length
}
function isBull(i) {
    return cs[i] > os[i]
}
function isBear(i) {
    return cs[i] < os[i]
}
function barTime(i) {
    return ts[i]
}
function barSeconds() {
    return Math.max(unix(0) - unix(1), 1)
}
function barEnd(i) {
    return barTime(i) + barSeconds()
}
function clipEps() {
    const bs = barSeconds()
    return Math.max(Math.floor(bs * 0.02), 1)
}
function barClipEnd(i) {
    return barEnd(i) - clipEps()
}

/* ───────── Zone model ───────── */
function makeZone(kind, dir, x1, yTop, yBot, colorLive, colorFaded) {
    const bsec = barSeconds()
    return {
        kind,
        dir,
        x1,
        x2: x1 + extendRight * bsec,
        yTop,
        yBot,
        yTop0: yTop,
        yBot0: yBot,
        live: true,
        box: null,
        colorLive,
        colorFaded,
        validated: true,
        _pending: false,
        _cancelled: false,
        refPrice: null,
        extreme: null,
        _clusterHidden: false,
        mitigatedAtTime: null,
        _frozen: false,
        createdAtBarIndex: globalBarIndex,
        // inicio VISUAL opcional (solo se usa para pintar si modo = BOS bar)
        _xStart: null
    }
}
const zones = []

function zoneVisibleColor(z) {
    if (z._clusterHidden) return transp(z.colorLive, 100)
    if (z.live) return z.colorLive
    if (mitigatedDisplayMode === "Hide completely (ocultar)")
        return transp(z.colorLive, 100)
    if (mitigatedDisplayMode === "Fade (desvanecer)") {
        const a = z.kind === "FVG" ? fvgFadeAlpha : obFadeAlpha
        return transp(z.colorLive, a)
    }
    return transp(z.colorLive, mitigatedAlphaKeepMode)
}

function drawZone(z) {
    if (z.kind === "OB" && (!z.validated || z._cancelled)) return
    const col = zoneVisibleColor(z)
    const x2 = !z.live && z.mitigatedAtTime !== null ? z.mitigatedAtTime : z.x2
    // Si el modo es BOS bar y tenemos inicio visual, dibujar desde ahí
    const x1draw =
        obAnchorMode === "BOS bar" && z._xStart !== null ? z._xStart : z.x1
    if (!z.box)
        z.box = Box({
            x1: x1draw,
            y1: z.yBot,
            x2: x2,
            y2: z.yTop,
            color: col,
            rounding: 2
        })
    else z.box.set({ x1: x1draw, y1: z.yBot, x2: x2, y2: z.yTop, color: col })
}

/* ---------- upsert: no revivir ---------- */
function upsertZone(kind, dir, x1, yTop, yBot, colorLive, colorFaded) {
    const tol = Math.max(barSeconds() / 4, 1)
    const newTop = Math.max(yTop, yBot)
    const newBot = Math.min(yTop, yBot)
    for (let z of zones) {
        if (z.kind === kind && z.dir === dir && Math.abs(z.x1 - x1) <= tol) {
            // No tocamos flags/edad/mitigación; mantenemos funcionalidad
            return z
        }
    }
    const z = makeZone(kind, dir, x1, newTop, newBot, colorLive, colorFaded)
    zones.push(z)
    return z
}

/* ───────── Helpers ───────── */
function bodyHi(i) {
    return Math.max(os[i], cs[i])
}
function bodyLo(i) {
    return Math.min(os[i], cs[i])
}
function barHi(i) {
    return touchKind === "Body (cuerpo)" ? bodyHi(i) : hs[i]
}
function barLo(i) {
    return touchKind === "Body (cuerpo)" ? bodyLo(i) : ls[i]
}
function touched(dir, i, yTop, yBot) {
    const top = Math.max(yTop, yBot),
        bot = Math.min(yTop, yBot)
    const hi = barHi(i),
        lo = barLo(i)
    if (completionMode === "Touch (tocar zona)") return hi >= bot && lo <= top
    const c = cs[i]
    return c <= top && c >= bot
}

/* ───────── FVG: slices (relleno parcial) ───────── */
function createSliceFrom(z, top, bot, i) {
    if (!(isFinite(top) && isFinite(bot))) return
    if (top <= bot) return
    const s = makeZone("FVG", z.dir, z.x1, top, bot, z.colorLive, z.colorFaded)
    s.live = false
    s.mitigatedAtTime = barClipEnd(i)
    s._frozen = true
    s.x2 = s.mitigatedAtTime
    zones.push(s)
}
function trimFVG(z, i) {
    if (!progressiveTrim) return
    const hi = barHi(i),
        lo = barLo(i)
    const oldTop = z.yTop,
        oldBot = z.yBot
    if (z.dir > 0) {
        const newTop = Math.min(oldTop, Math.max(lo, oldBot))
        if (newTop < oldTop) createSliceFrom(z, oldTop, newTop, i)
        z.yTop = newTop
    } else {
        const newBot = Math.max(oldBot, Math.min(hi, oldTop))
        if (newBot > oldBot) createSliceFrom(z, newBot, oldBot, i)
        z.yBot = newBot
    }
    if (z.yTop <= z.yBot) {
        z.live = false
        if (z.mitigatedAtTime === null) z.mitigatedAtTime = barClipEnd(i)
        z._frozen = true
    }
}

/* ───────── OB impulso ───────── */
function initOBImpulseValidation(z, bosIndex) {
    if (obImpulsePct <= 0) {
        z.validated = true
        z._pending = false
        return
    }
    z.validated = false
    z._pending = true
    z._cancelled = false
    z.refPrice = cs[bosIndex]
    z.extreme = cs[bosIndex]
}
function updateOBImpulseValidation(z, i) {
    if (z.kind !== "OB" || z.validated || z._cancelled) return
    z.extreme =
        z.dir > 0 ? Math.max(z.extreme, hs[i]) : Math.min(z.extreme, ls[i])
    const thr = obImpulsePct / 100.0
    const passed =
        z.dir > 0
            ? z.extreme >= z.refPrice * (1 + thr)
            : z.extreme <= z.refPrice * (1 - thr)
    if (passed) {
        z.validated = true
        z._pending = false
        return
    }
    const top = Math.max(z.yTop, z.yBot),
        bot = Math.min(z.yTop, z.yBot)
    if (touched(z.dir, i, top, bot)) {
        z._cancelled = true
        z.live = false
        z.mitigatedAtTime = barClipEnd(i)
        z._frozen = true
    }
}

/* ───────── Mitigación ───────── */
function considerMitigated(z, i) {
    if (z._frozen || !z.live) return

    if (z.kind === "OB") {
        if (!z.validated) return
        const barsSince = globalBarIndex - z.createdAtBarIndex
        if (barsSince < obMinBars) return
    }

    if (z.kind === "FVG") {
        const top = Math.max(z.yTop, z.yBot),
            bot = Math.min(z.yTop, z.yBot)
        if (!touched(z.dir, i, top, bot)) return
        trimFVG(z, i)
        if (
            z.yTop <= z.yBot ||
            (!progressiveTrim && hs[i] >= top && ls[i] <= bot)
        ) {
            z.live = false
            if (z.mitigatedAtTime === null) z.mitigatedAtTime = barClipEnd(i)
            z._frozen = true
        }
        return
    }

    // OB
    const top = Math.max(z.yTop, z.yBot),
        bot = Math.min(z.yTop, z.yBot)
    const insideTouch = hs[i] >= bot && ls[i] <= top
    const insideClose = cs[i] <= top && cs[i] >= bot
    const inside =
        completionMode === "Close inside (cierre en zona)"
            ? insideClose
            : insideTouch
    if (!inside) return

    const mid = (top + bot) / 2
    const crossTouch = z.dir > 0 ? ls[i] <= mid : hs[i] >= mid
    const crossClose = z.dir > 0 ? cs[i] <= mid : cs[i] >= mid
    const hit50 =
        completionMode === "Close inside (cierre en zona)"
            ? crossClose
            : crossTouch

    if (hit50) {
        z.live = false
        if (z.mitigatedAtTime === null) z.mitigatedAtTime = barClipEnd(i)
        z._frozen = true
    }
}

/* ───────── Utils ───────── */
function highest(from, to) {
    let v = -Infinity
    for (let k = from; k <= to; k++) if (idxValid(k) && hs[k] > v) v = hs[k]
    return v
}
function lowest(from, to) {
    let v = Infinity
    for (let k = from; k <= to; k++) if (idxValid(k) && ls[k] < v) v = ls[k]
    return v
}
function bodyHi(i) {
    return Math.max(os[i], cs[i])
}
function bodyLo(i) {
    return Math.min(os[i], cs[i])
}

function lastOpposite(beforeIdx, dir, back) {
    const start = Math.max(0, beforeIdx - back)
    for (let k = beforeIdx; k >= start; k--) {
        if (!idxValid(k)) break
        if (dir > 0) {
            if (isBear(k)) return k
        } else {
            if (isBull(k)) return k
        }
    }
    return -1
}
function baseRange(i, opp) {
    if (obBaseMode === "Last opposite only") return [opp, opp]
    const end = i - 1
    if (obBaseMode === "Fixed N ending at BOS-1") {
        const start = Math.max(opp, i - obBaseN)
        return [Math.max(0, start), Math.max(0, Math.min(end, i - 1))]
    }
    return [opp, Math.max(0, i - 1)]
}
function baseHiLo(start, end) {
    let hi = -Infinity,
        lo = Infinity
    for (let k = start; k <= end; k++) {
        if (!idxValid(k)) continue
        const h = obZoneType === "Body only (solo cuerpo)" ? bodyHi(k) : hs[k]
        const l = obZoneType === "Body only (solo cuerpo)" ? bodyLo(k) : ls[k]
        if (h > hi) hi = h
        if (l < lo) lo = l
    }
    return [hi, lo]
}

/* ───────── Detección ───────── */
function detectFVGat(i) {
    if (!(idxValid(i) && idxValid(i - 1) && idxValid(i - 2))) return
    const hi2 = hs[i - 2],
        lo2 = ls[i - 2],
        hi = hs[i],
        lo = ls[i]
    const xMid = barTime(i - 1) // anclaje lógico (sin cambios)
    const xStart = barTime(i - 2) // inicio VISUAL (vela izquierda)
    if (hi2 < lo) {
        const gap = lo - hi2
        if (gap >= minFvgGap) {
            const z = upsertZone(
                "FVG",
                +1,
                xMid,
                lo,
                hi2,
                fvg_bullColor,
                fvg_bullColor
            )
            if (z._xStart === null) z._xStart = xStart // para pintar si modo BOS bar
            if (showDebug)
                Marker({
                    x: xMid,
                    y: (lo + hi2) / 2,
                    shape: marker.Diamond,
                    size: 6,
                    color: fvgBullBase
                })
        }
    }
    if (lo2 > hi) {
        const gap = lo2 - hi
        if (gap >= minFvgGap) {
            const z = upsertZone(
                "FVG",
                -1,
                xMid,
                lo2,
                hi,
                fvg_bearColor,
                fvg_bearColor
            )
            if (z._xStart === null) z._xStart = xStart
            if (showDebug)
                Marker({
                    x: xMid,
                    y: (lo2 + hi) / 2,
                    shape: marker.Diamond,
                    size: 6,
                    color: fvgBearBase
                })
        }
    }
}

function detectOBat(i) {
    if (!(idxValid(i) && idxValid(i - 1))) return

    // BOS-UP
    const hiPast = highest(Math.max(0, i - bosLB), i - 1)
    if (cs[i] > hiPast) {
        const opp = lastOpposite(i - 1, +1, obSearchBack)
        if (opp >= 0) {
            const [start, end] = baseRange(i, opp)
            let [hi, lo] = baseHiLo(start, end)
            if (start === opp && end === opp) {
                const oppHi =
                    obZoneType === "Body only (solo cuerpo)"
                        ? bodyHi(opp)
                        : hs[opp]
                const oppLo =
                    obZoneType === "Body only (solo cuerpo)"
                        ? bodyLo(opp)
                        : ls[opp]
                hi = oppHi
                lo = oppLo
            }
            if (isFinite(hi) && isFinite(lo) && hi > lo) {
                const xStart = barTime(start) // inicio VISUAL (base)
                const anchorIdx =
                    obAnchorMode === "Opposite candle (standard)" ? start : i
                const x1 = barTime(anchorIdx) // anclaje lógico (sin cambios)
                const z = upsertZone(
                    "OB",
                    +1,
                    x1,
                    hi,
                    lo,
                    ob_bullColor,
                    ob_bullColor
                )
                if (z._xStart === null) z._xStart = xStart
                initOBImpulseValidation(z, i)
                if (showDebug) {
                    Marker({
                        x: barTime(opp),
                        y: hi,
                        shape: marker.Circle,
                        size: 5,
                        color: hueBullOB
                    })
                    Marker({
                        x: barTime(opp),
                        y: lo,
                        shape: marker.Circle,
                        size: 5,
                        color: hueBullOB
                    })
                }
            }
        }
    }

    // BOS-DOWN
    const loPast = lowest(Math.max(0, i - bosLB), i - 1)
    if (cs[i] < loPast) {
        const opp = lastOpposite(i - 1, -1, obSearchBack)
        if (opp >= 0) {
            const [start, end] = baseRange(i, opp)
            let [hi, lo] = baseHiLo(start, end)
            if (start === opp && end === opp) {
                const oppHi =
                    obZoneType === "Body only (solo cuerpo)"
                        ? bodyHi(opp)
                        : hs[opp]
                const oppLo =
                    obZoneType === "Body only (solo cuerpo)"
                        ? bodyLo(opp)
                        : ls[opp]
                hi = oppHi
                lo = oppLo
            }
            if (isFinite(hi) && isFinite(lo) && hi > lo) {
                const xStart = barTime(start)
                const anchorIdx =
                    obAnchorMode === "Opposite candle (standard)" ? start : i
                const x1 = barTime(anchorIdx)
                const z = upsertZone(
                    "OB",
                    -1,
                    x1,
                    hi,
                    lo,
                    ob_bearColor,
                    ob_bearColor
                )
                if (z._xStart === null) z._xStart = xStart
                initOBImpulseValidation(z, i)
                if (showDebug) {
                    Marker({
                        x: barTime(opp),
                        y: hi,
                        shape: marker.Circle,
                        size: 5,
                        color: hueBearOB
                    })
                    Marker({
                        x: barTime(opp),
                        y: lo,
                        shape: marker.Circle,
                        size: 5,
                        color: hueBearOB
                    })
                }
            }
        }
    }
}

/* ───────── Consolidación OB ───────── */
function consolidateNearbyOBs() {
    for (let z of zones) if (z.kind === "OB") z._clusterHidden = false
    const win = obClusterBars * barSeconds()
    const obs = zones
        .filter((z) => z.kind === "OB" && z.validated && !z._cancelled)
        .sort((a, b) => a.x1 - b.x1)

    let i = 0
    while (i < obs.length) {
        const base = obs[i]
        const cluster = [base]
        let j = i + 1
        while (
            j < obs.length &&
            obs[j].dir === base.dir &&
            obs[j].x1 - base.x1 <= win
        ) {
            cluster.push(obs[j])
            j++
        }

        if (cluster.length > 1) {
            const tol = Math.max(barSeconds() / 4, 1)
            const allSameX1 = cluster.every(
                (c) => Math.abs(c.x1 - base.x1) <= tol
            )
            let chosen = cluster[0]
            if (allSameX1) {
                for (let k = 1; k < cluster.length; k++)
                    if (cluster[k].createdAtBarIndex > chosen.createdAtBarIndex)
                        chosen = cluster[k]
            } else {
                if (base.dir > 0) {
                    for (let k = 1; k < cluster.length; k++)
                        if (cluster[k].yBot < chosen.yBot) chosen = cluster[k]
                } else {
                    for (let k = 1; k < cluster.length; k++)
                        if (cluster[k].yTop > chosen.yTop) chosen = cluster[k]
                }
            }
            for (let c of cluster) if (c !== chosen) c._clusterHidden = true
        }
        i = j
    }
}

/* ───────── Main ───────── */
let dbgHdr = null
function onBar() {
    const h = ohlc.high(),
        l = ohlc.low(),
        o = ohlc.open(),
        c = ohlc.close(),
        t = unix(0)
    if (isNewBar()) pushBar(h, l, o, c, t)
    else updateBar(h, l, o, c, t)
    const n = hs.length
    if (n < 5) return
    const i = n - 1

    const canDetect = !onlyWhenRightClosed || isNewBar()
    if (canDetect) {
        if (detectFVG) detectFVGat(i)
        if (detectOB) detectOBat(i)
    }

    for (let z of zones)
        if (z.kind === "OB" && (!z.validated || z._pending) && !z._cancelled)
            updateOBImpulseValidation(z, i)

    consolidateNearbyOBs()

    for (let z of zones) {
        if (z.live && !z._frozen)
            z.x2 = Math.max(z.x2, t + extendRight * barSeconds())
        if (idxValid(i)) considerMitigated(z, i)
        drawZone(z)
    }

    if (showDebug) {
        const txt = `FVG:${detectFVG ? "ON" : "OFF"} · OB:${detectOB ? "ON" : "OFF"} · FVG vivos=${zones.filter((z) => z.kind === "FVG" && z.live).length} · OB vivos=${zones.filter((z) => z.kind === "OB" && z.live && !z._clusterHidden && z.validated && !z._cancelled).length}`
        const y = (hs[i] + ls[i]) / 2
        if (!dbgHdr)
            dbgHdr = Label({
                x: unix(0),
                y,
                text: txt,
                color: color.White,
                size: 12
            })
        else dbgHdr.set({ x: unix(0), y, text: txt })
    } else if (dbgHdr) dbgHdr.set({ text: "" })

    setDisplayName(
        `FVG/OB · FVG:${detectFVG ? "ON" : "OFF"} · OB:${detectOB ? "ON" : "OFF"} · FVG vivos=${zones.filter((z) => z.kind === "FVG" && z.live).length} · OB vivos=${zones.filter((z) => z.kind === "OB" && z.live && !z._clusterHidden && z.validated && !z._cancelled).length}`
    )
}
