//@version=2
indicator("VWAP Distance · Histogram & Divergences", false)

/* ═══════════════════════════════════════════════════════════
   DATA & STATE (Moved to top for v2 compatibility)
   ═══════════════════════════════════════════════════════════ */
const candles = subscribe(data.OHLCV)

// ── Fixed period incremental accumulators (O(1) per bar) ──
const FP_CODES = ["4H", "D", "W", "M", "Q", "Y"]
const FP_STATE = {}
for (const c of FP_CODES) {
    FP_STATE[c] = { lastStart: 0, sumPV: 0, sumV: 0, sumP: 0, count: 0 }
}

// ── Rolling VWAP sliding windows (O(1) amortized per bar) ──
const ROLL_STATE = {}
for (const code of ["R7D", "R14D", "R30D", "R60D", "R90D", "R120D", "R180D", "R365D"]) {
    ROLL_STATE[code] = { queue: [], sumPV: 0, sumV: 0, sumP: 0, maxBars: 0 }
}

const distanceHistoryBars = []
const distanceHistoryPeriods = []
const volatilityHistory = []
const maxHistoryLength = 200

const zScoreHistory = []
const priceHistory = []
const highHistory = []
const lowHistory = []
const timeHistory = []

let lastPeriodEndDistance = NaN
let lastPeriodKey = null

let lastPeriodStart = {
    "4H": null,
    "D": null,
    "W": null,
    "M": null,
    "Q": null,
    "Y": null
}

let currentStats = {
    zScore: 0,
    mean: 0,
    stdDev: 0,
    sampleCount: 0,
    percentile: 0,
    currentVolatility: 0,
    avgVolatility: 0,
    volRatio: 1.0
}

let statsLabel = null

// Real-time divergence tracking
let lastPriceHigh = -Infinity
let lastPriceLow = Infinity
let lastZScoreAtHigh = 0
let lastZScoreAtLow = 0
let lastHighTime = 0
let lastLowTime = 0

// 🛡️ Period Reset Protection (ONLY for Fixed Periods)
const periodResetTimestamps = []
const maxResetHistory = 50

/* ═══════════════════════════════════════════════════════════
   📊 STEP 1: CALCULATION METHOD
   ═══════════════════════════════════════════════════════════ */
input.section("📊 STEP 1: CALCULATION METHOD")
const calculationMethod = input.select("Distance Measurement", 1, {
    selectables: ["Raw Distance (% or Price)", "Z-Score (Auto-Normalized) ⭐"],
    description: "Z-Score = Statistical (recommended) | Raw = Manual thresholds"
})

/* ═══════════════════════════════════════════════════════════
   📅 STEP 2: PERIOD SELECTION
   ═══════════════════════════════════════════════════════════ */
input.section("📅 STEP 2A: Fixed Periods (Reset at Period Start)")
const show4H = input.bool("4H", false)
const showDaily = input.bool("Daily", false)
const showWeekly = input.bool("Weekly", false)
const showMonthly = input.bool("Monthly", false)
const showQuarterly = input.bool("Quarterly", false)
const showYearly = input.bool("Yearly", true)

input.section("📅 STEP 2B: Rolling Periods (Continuous N-Day Window)")
const showRolling7D = input.bool("7 Days", false)
const showRolling14D = input.bool("14 Days", false)
const showRolling30D = input.bool("30 Days", false)
const showRolling60D = input.bool("60 Days", false)
const showRolling90D = input.bool("90 Days", false)
const showRolling120D = input.bool("120 Days", false)
const showRolling180D = input.bool("180 Days", false)
const showRolling365D = input.bool("365 Days", false)

/* ═══════════════════════════════════════════════════════════
   ⚙️ METHOD SETTINGS
   ═══════════════════════════════════════════════════════════ */

input.section("⚙️ Raw Distance Settings (Only for Raw Distance Mode)")
const distanceType = input.select("Unit", 0, {
    selectables: ["Percentage (%)", "Absolute Price"],
    description: "Only used when Raw Distance is selected"
})

const thresholdMode = input.select("Threshold Type", 0, {
    selectables: [
        "ATR-Based ⭐",
        "Standard Deviation",
        "Percentile",
        "Fixed Value"
    ],
    description: "Auto-adaptive threshold (ignored in Z-Score mode)"
})

const atrPeriod = input.int("ATR Period", 14, { min: 5, max: 100 })
const atrMultiplier = input.float("ATR Multiplier", 2.0, {
    min: 0.1,
    max: 10.0
})
const stdDevPeriod = input.int("StdDev Lookback", 100, { min: 20, max: 500 })
const stdDevMultiplier = input.float("StdDev Multiplier", 1.5, {
    min: 0.1,
    max: 5.0
})
const percentilePeriod = input.int("Percentile Lookback", 100, {
    min: 20,
    max: 500
})
const percentileLevel = input.float("Percentile Level", 75, {
    min: 50,
    max: 99
})
const fixedThresholdValue = input.float("Fixed Threshold", 2.0, {
    min: 0.1,
    max: 100
})

input.section("📈 Z-Score Settings (Only for Z-Score Mode)")
const zScoreCalcMethod = input.select("Z-Score Calculation Method", 1, {
    selectables: ["Per Bar (Real-time) 🔄", "Per Period Close (Structural) ⭐"],
    description:
        "Period = cleaner, filters intrabar noise | Bar = more granular"
})

const zScorePeriodCount = input.int("Periods/Bars Lookback", 20, {
    min: 5,
    max: 100,
    description: "Number of VWAP periods or bars to calculate mean/std"
})

const zScoreLevel1 = input.float("Level 1σ (68% Normal)", 1.0, {
    min: 0.1,
    max: 5
})
const zScoreLevel2 = input.float("Level 2σ (95% Expected)", 2.0, {
    min: 0.1,
    max: 5
})
const zScoreLevel3 = input.float("Level 3σ (99.7% Extreme)", 3.0, {
    min: 0.1,
    max: 5
})

/* ═══════════════════════════════════════════════════════════
   🔧 ADVANCED SETTINGS
   ═══════════════════════════════════════════════════════════ */
input.section("🔧 Advanced Calculation Settings")
const calculationMode = input.select("Fixed Period Mode", 1, {
    selectables: ["Current Period Only", "Reset Each Period (Historical)"],
    description: "How to calculate fixed periods (doesn't affect rolling)"
})

const priceSource = input.select("Price Source", 0, {
    selectables: ["Close", "HL2 (High+Low)/2", "HLC3", "OHLC4"]
})

const vwapFallback = input.bool("Use TWAP if Volume = 0", true)
const hideOnPeriodChange = input.bool("Hide jump at period reset", true)

/* ═══════════════════════════════════════════════════════════
   🎨 VISUAL CUSTOMIZATION
   ═══════════════════════════════════════════════════════════ */
input.section("🎨 Visual Settings")
const showLabels = input.bool("Show Histogram Labels", true)
const showValues = input.bool("Show Scale Values", true, { sameLine: true })
const showYAxisLabels = input.bool("Show Y-Axis Labels", true)

input.section("🌈 Color Gradient")
const useGradient = input.bool("Enable Color Gradient", true)
const gradientSteps = input.int("Gradient Steps", 5, { min: 2, max: 10 })

input.section("Positive Colors (Above VWAP)")
const posColor1 = input.color("Very Close", "#E8F5E9", { key: "p_v_close" })
const posColor2 = input.color("Close", "#A5D6A7", { key: "pos_color_close", sameLine: true })
const posColor3 = input.color("Medium", "#66BB6A", { key: "pos_color_medium", sameLine: true })
const posColor4 = input.color("Far", "#43A047", { key: "pos_color_far", sameLine: true })
const posColor5 = input.color("Very Far", "#2E7D32", { key: "pos_color_vfar", sameLine: true })

input.section("Negative Colors (Below VWAP)")
const negColor1 = input.color("Very Close", "#FFEBEE", { key: "n_v_close" })
const negColor2 = input.color("Close", "#EF9A9A", { key: "neg_color_close", sameLine: true })
const negColor3 = input.color("Medium", "#EF5350", { key: "neg_color_medium", sameLine: true })
const negColor4 = input.color("Far", "#E53935", { key: "neg_color_far", sameLine: true })
const negColor5 = input.color("Very Far", "#C62828", { key: "neg_color_vfar", sameLine: true })

input.section("Reference Lines")
const showZero = input.bool("Show Zero Line", true)
const zeroColor = input.color("Zero Line Color", "#FFFFFF", { key: "zero_color", sameLine: true })
const zeroWidth = input.float("Width", 1.5, {
    key: "zero_width",
    min: 0.5,
    max: 5,
    sameLine: true
})

const showThresholdLines = input.bool("Show Threshold/Sigma Lines", true)
const thresholdStyle = input.select("Style", 1, {
    selectables: ["Solid", "Dashed", "Dotted"],
    sameLine: true
})

input.section("📊 Z-Score Visual Enhancement (Z-Score Mode Only)")
const zScoreVisualMode = input.select("Z-Score Visual Style", 1, {
    selectables: ["Single Color", "Traffic Light Colors ⭐", "Gradient Colors"],
    description: "How to display sigma levels"
})

const fillZoneSigma = input.bool("Fill Sigma Zones", true)
const singleSigmaColor = input.color("Single Sigma Color", "#FFD700")
const sigma1Color = input.color("±1σ Color (Normal)", "#4CAF50")
const sigma2Color = input.color("±2σ Color (Warning)", "#FF9800")
const sigma3Color = input.color("±3σ Color (Extreme)", "#F44336")
const fillSigma1Color = input.color("Fill ±1σ Zone", "#4CAF50")
const fillSigma2Color = input.color("Fill ±2σ Zone", "#FF9800")
const fillSigma3Color = input.color("Fill ±3σ Zone", "#F44336")
const fillAlphaSigma = input.int("Fill Transparency", 92, { min: 0, max: 98 })

input.section("Period Reset Lines (Fixed Periods)")
const showResetLines = input.bool("Show Reset Lines", true)
const resetLineColor = input.color("Color", "#FFFFFF", { key: "reset_color", sameLine: true })
const resetLineWidth = input.float("Width", 1.0, {
    key: "reset_width",
    min: 0.5,
    max: 3,
    sameLine: true
})
const resetLineAlpha = input.int("Transparency", 70, {
    min: 0,
    max: 95,
    sameLine: true
})

/* ═══════════════════════════════════════════════════════════
   🔥 VOLATILITY-ADJUSTED ZONES
   ═══════════════════════════════════════════════════════════ */
input.section("🔥 Volatility-Adjusted Zones (Z-Score Mode Only)")
const useVolatilityAdjustment = input.bool(
    "Enable Volatility Adjustment",
    false
)
const volLookbackPeriods = input.int("Volatility Lookback Periods", 20, {
    min: 5,
    max: 100
})
const volAdjustmentFactor = input.float("Adjustment Sensitivity", 1.0, {
    min: 0.1,
    max: 3.0
})
const showVolatilityInfo = input.bool("Show Volatility Regime", true)

/* ═══════════════════════════════════════════════════════════
   🔍 DIVERGENCE DETECTION - HYBRID SYSTEM
   ═══════════════════════════════════════════════════════════ */
input.section("🔍 Divergence Detection - Hybrid System")
const divergenceMode = input.select("Detection Mode", 2, {
    selectables: [
        "Classic (Pivot Confirmed) 📊",
        "Real-Time (No Confirmation) ⚡",
        "Hybrid (Both) ⭐"
    ],
    description: "Classic = 2-5 bar delay | Real-Time = 0 delay | Hybrid = both"
})

const showDivergences = input.bool("Show Divergences", true)

input.section("Classic Divergence Settings")
const divPivotLength = input.int("Pivot Length", 3, {
    min: 2,
    max: 10,
    description: "Lower = faster (2-3 recommended)"
})
const divLookback = input.int("Lookback Range", 30, {
    min: 10,
    max: 100,
    description: "Lower = faster detection"
})

input.section("Real-Time Divergence Settings")
const rtMinDistance = input.float("Min Price Move (%)", 0.5, {
    min: 0.1,
    max: 10,
    description: "Minimum price change to trigger signal"
})

const rtMinZScoreDiff = input.float("Min Z-Score Diff", 0.3, {
    min: 0.1,
    max: 3,
    description: "Minimum Z-Score divergence"
})

input.section("Divergence Visual Settings")
const showBullDiv = input.bool("Show Bullish Divergence", true)
const bullDivColor = input.color("Bull Color", "#4CAF50", { sameLine: true })

const showBearDiv = input.bool("Show Bearish Divergence", true)
const bearDivColor = input.color("Bear Color", "#F44336", { sameLine: true })

const divLineWidth = input.float("Line Width", 1.5, { min: 0.5, max: 3 })

input.section("Hybrid Mode Settings")
const preliminaryAlpha = input.int("Real-Time Signal Transparency", 60, {
    min: 30,
    max: 90,
    description: "For unconfirmed signals (Hybrid mode)"
})

const confirmedAlpha = input.int("Classic Signal Transparency", 0, {
    min: 0,
    max: 50,
    description: "For confirmed signals"
})

input.section("🔵 Divergence Markers & Labels")
const showDivMarkers = input.bool("Show Markers on Histogram", false)
const divMarkerSize = input.float("Marker Size", 8, { min: 4, max: 20 })
const showDivLabels = input.bool("Show Text Labels", true, {
    description: "Can be cluttered with many signals"
})

/* ═══════════════════════════════════════════════════════════
   🛡️ PERIOD RESET PROTECTION (Fixed Periods Only)
   ═══════════════════════════════════════════════════════════ */
input.section("🛡️ Divergence Protection (Fixed Periods Only)")
const enableResetProtection = input.bool(
    "Enable Period Reset Protection",
    true,
    {
        description:
            "Prevents false divergences at VWAP resets (Fixed periods only)"
    }
)
const resetBufferBars = input.int("Buffer Bars After Reset", 3, {
    min: 1,
    max: 10,
    description: "Minimum bars after reset before detecting divergences"
})

/* ═══════════════════════════════════════════════════════════
   📈 PERCENTILE RANKING
   ═══════════════════════════════════════════════════════════ */
input.section("📈 Percentile Ranking (Z-Score Mode Only)")
const showPercentileRank = input.bool("Show Percentile on Axis", true)
const percentileWindow = input.int("Percentile Window", 100, {
    min: 20,
    max: 500
})
const showPercentileZones = input.bool("Show Percentile Zones", false)

/* ═══════════════════════════════════════════════════════════
   📊 STATS TABLE
   ═══════════════════════════════════════════════════════════ */
input.section("📊 Statistical Information Table")
const showStatsTable = input.bool("Show Stats Table", true)
const statsPosition = input.select("Position", 0, {
    selectables: [
        "Right of Last Bar ⭐",
        "Top Right",
        "Top Left",
        "Bottom Right",
        "Bottom Left"
    ]
})
const statsTextSize = input.int("Text Size", 10, { min: 8, max: 16 })
const statsTextColor = input.color("Text Color", "#FFFFFF")
const showFallbackWarning = input.bool("Show Auto-Fallback Warning", true, {
    description: "Display warning when using Per Bar fallback for long periods"
})

/* ═══════════════════════════════════════════════════════════
   UTILITY FUNCTIONS
   ═══════════════════════════════════════════════════════════ */

function getPrice(offset = 0) {
    const o = candles.open(offset),
        h = candles.high(offset)
    const l = candles.low(offset),
        c = candles.close(offset)

    if (priceSource === "Close") return c
    if (priceSource === "HL2 (High+Low)/2") return (h + l) / 2
    if (priceSource === "HLC3") return (h + l + c) / 3
    if (priceSource === "OHLC4") return (o + h + l + c) / 4
    return c
}

function startOfPeriod(code, ts) {
    if (code === "4H") {
        const period = 4 * 3600
        return Math.floor(ts / period) * period
    }

    const d = new Date(ts * 1000)
    const year = d.getUTCFullYear()
    const month = d.getUTCMonth()
    const day = d.getUTCDate()

    if (code === "D") {
        return Math.floor(Date.UTC(year, month, day) / 1000)
    }

    if (code === "W") {
        const dayOfWeek = d.getUTCDay()
        const daysToMonday = (dayOfWeek + 6) % 7
        return Math.floor(Date.UTC(year, month, day - daysToMonday) / 1000)
    }

    if (code === "M") {
        return Math.floor(Date.UTC(year, month, 1) / 1000)
    }

    if (code === "Q") {
        const quarterMonth = Math.floor(month / 3) * 3
        return Math.floor(Date.UTC(year, quarterMonth, 1) / 1000)
    }

    if (code === "Y") {
        return Math.floor(Date.UTC(year, 0, 1, 0, 0, 0, 0) / 1000)
    }

    return ts
}

function periodChanged(code) {
    if (barCount() < 2) return false

    const currentPeriod = startOfPeriod(code, candles.unix(0))
    const previousPeriod = startOfPeriod(code, candles.unix(1))

    return currentPeriod !== previousPeriod
}

function getPeriodKey(code) {
    const periodStart = startOfPeriod(code, candles.unix(0))
    return `${code}_${periodStart}`
}

function getFixedPeriodVWAP(code) {
    const ts = candles.unix(0)
    const ps = FP_STATE[code]
    const periodStart = startOfPeriod(code, ts)

    if (periodStart !== ps.lastStart) {
        ps.sumPV = 0; ps.sumV = 0; ps.sumP = 0; ps.count = 0
        ps.lastStart = periodStart
    }

    const h = candles.high(0), l = candles.low(0), c = candles.close(0)
    const vol = candles.volume(0)
    const tp = (h + l + c) / 3

    if (vol > 0) { ps.sumPV += tp * vol; ps.sumV += vol }
    ps.sumP += tp
    ps.count++

    if (ps.sumV > 0) return ps.sumPV / ps.sumV
    if (vwapFallback && ps.count > 0) return ps.sumP / ps.count
    return NaN
}

function getRollingVWAP(code, days) {
    const rs = ROLL_STATE[code]
    if (rs.maxBars === 0) {
        rs.maxBars = Math.max(1, days * Math.max(1, Math.floor(86400 / context.timeframe)))
    }

    const h = candles.high(0), l = candles.low(0), c = candles.close(0)
    const vol = candles.volume(0)
    const tp = (h + l + c) / 3

    rs.queue.push({ pv: tp * vol, v: vol, p: tp })
    if (vol > 0) { rs.sumPV += tp * vol; rs.sumV += vol }
    rs.sumP += tp

    while (rs.queue.length > rs.maxBars) {
        const old = rs.queue.shift()
        if (old.v > 0) { rs.sumPV -= old.pv; rs.sumV -= old.v }
        rs.sumP -= old.p
    }

    if (rs.sumV > 0) return rs.sumPV / rs.sumV
    const n = rs.queue.length
    if (vwapFallback && n > 0) return rs.sumP / n
    return NaN
}

function getVolatilityAdjustment() {
    if (!useVolatilityAdjustment) return 1.0
    const lookback = Math.min(volLookbackPeriods, volatilityHistory.length)
    if (lookback < 10) return 1.0

    const recent = volatilityHistory.slice(-lookback)
    const avg = recent.reduce((a, b) => a + b, 0) / lookback
    if (avg === 0) return 1.0

    const current = recent[recent.length - 1]
    const ratio = current / avg

    currentStats.currentVolatility = current
    currentStats.avgVolatility = avg
    currentStats.volRatio = ratio

    return Math.pow(ratio, volAdjustmentFactor)
}

function getVolatilityRegime() {
    const r = currentStats.volRatio
    if (r > 1.5) return "🔥 HIGH"
    if (r > 1.2) return "📈 ELEVATED"
    if (r < 0.7) return "❄️ LOW"
    if (r < 0.8) return "📉 SUBDUED"
    return "⚖️ NORMAL"
}

function calculatePercentile(value, history) {
    if (history.length < 10) return 50
    const window = Math.min(percentileWindow, history.length)
    const data = history.slice(-window)
    let countBelow = 0
    for (let i = 0; i < data.length; i++) {
        if (data[i] < value) countBelow++
    }
    return (countBelow / data.length) * 100
}

function calculateZScoreByBars(currentPrice, currentVWAP) {
    const distance = currentPrice - currentVWAP
    const period = Math.min(zScorePeriodCount, distanceHistoryBars.length)
    if (period < 10) return 0

    const recent = distanceHistoryBars.slice(-period)
    const mean = recent.reduce((a, b) => a + b, 0) / period
    const variance =
        recent.reduce((sum, val) => sum + Math.pow(val - mean, 2), 0) / period
    const stdDev = Math.sqrt(variance)

    volatilityHistory.push(stdDev)
    if (volatilityHistory.length > maxHistoryLength) volatilityHistory.shift()

    if (stdDev < 1e-10) return 0

    const zScore = (distance - mean) / stdDev
    const finalZ = Math.max(-5, Math.min(5, zScore))

    currentStats.mean = mean
    currentStats.stdDev = stdDev
    currentStats.sampleCount = period
    currentStats.percentile = calculatePercentile(finalZ, zScoreHistory)

    return finalZ
}

function calculateZScoreByPeriods(currentPrice, currentVWAP) {
    const distance = currentPrice - currentVWAP

    const minPeriod = 3
    const period = Math.min(zScorePeriodCount, distanceHistoryPeriods.length)

    if (period < minPeriod) {
        return calculateZScoreByBars(currentPrice, currentVWAP)
    }

    const recent = distanceHistoryPeriods.slice(-period)
    const mean = recent.reduce((a, b) => a + b, 0) / period
    const variance =
        recent.reduce((sum, val) => sum + Math.pow(val - mean, 2), 0) / period
    const stdDev = Math.sqrt(variance)

    volatilityHistory.push(stdDev)
    if (volatilityHistory.length > maxHistoryLength) volatilityHistory.shift()

    if (stdDev < 1e-10) return 0

    const zScore = (distance - mean) / stdDev
    const finalZ = Math.max(-5, Math.min(5, zScore))

    currentStats.mean = mean
    currentStats.stdDev = stdDev
    currentStats.sampleCount = period
    currentStats.percentile = calculatePercentile(finalZ, zScoreHistory)

    return finalZ
}

function calculateDistance(price, vwap, periodCode) {
    if (isNaN(vwap) || vwap === 0) return NaN

    if (calculationMethod === "Z-Score (Auto-Normalized) ⭐") {
        const isLongPeriod = periodCode === "Y" || periodCode === "Q"
        const hasEnoughPeriods = distanceHistoryPeriods.length >= 5

        const usePerBar =
            zScoreCalcMethod === "Per Bar (Real-time) 🔄" ||
            (isLongPeriod && !hasEnoughPeriods)

        if (usePerBar) {
            return calculateZScoreByBars(price, vwap)
        } else {
            return calculateZScoreByPeriods(price, vwap)
        }
    } else {
        if (distanceType === "Percentage (%)") {
            return ((price - vwap) / vwap) * 100
        } else {
            return price - vwap
        }
    }
}

function calculateAdaptiveThreshold() {
    if (calculationMethod === "Z-Score (Auto-Normalized) ⭐")
        return zScoreLevel2
    if (thresholdMode === "Fixed Value") return fixedThresholdValue

    if (thresholdMode === "ATR-Based ⭐") {
        const atrValue = ta.atr(
            candles.high(),
            candles.low(),
            candles.close(),
            atrPeriod
        )
        if (isNaN(atrValue) || atrValue === 0) return fixedThresholdValue

        if (distanceType === "Percentage (%)") {
            return (atrValue / getPrice(0)) * 100 * atrMultiplier
        } else {
            return atrValue * atrMultiplier
        }
    }

    if (distanceHistoryBars.length < 20) return fixedThresholdValue

    if (thresholdMode === "Standard Deviation") {
        const period = Math.min(stdDevPeriod, distanceHistoryBars.length)
        const recent = distanceHistoryBars.slice(-period)
        const abs = recent.map((d) => Math.abs(d))
        const mean = abs.reduce((a, b) => a + b, 0) / abs.length
        const variance =
            abs.reduce((sum, val) => sum + Math.pow(val - mean, 2), 0) /
            abs.length
        return mean + Math.sqrt(variance) * stdDevMultiplier
    }

    if (thresholdMode === "Percentile") {
        const period = Math.min(percentilePeriod, distanceHistoryBars.length)
        const recent = distanceHistoryBars.slice(-period)
        const abs = recent.map((d) => Math.abs(d)).sort((a, b) => a - b)
        const index = Math.floor((percentileLevel / 100) * abs.length)
        return abs[Math.min(index, abs.length - 1)]
    }

    return fixedThresholdValue
}

/* ═══════════════════════════════════════════════════════════
   🛡️ PERIOD RESET PROTECTION (Fixed Periods Only)
   ═══════════════════════════════════════════════════════════ */

function trackPeriodReset(periodCode, currentTime) {
    const currentPeriodStart = startOfPeriod(periodCode, currentTime)

    if (
        lastPeriodStart[periodCode] !== null &&
        lastPeriodStart[periodCode] !== currentPeriodStart
    ) {
        periodResetTimestamps.push(currentTime)

        if (periodResetTimestamps.length > maxResetHistory) {
            periodResetTimestamps.shift()
        }
    }
}

function isNearPeriodReset(time1, time2, bufferBars = 3) {
    if (!enableResetProtection) return false

    const barSec = Math.max(candles.unix(0) - candles.unix(1), 1)
    const bufferSec = bufferBars * barSec

    for (const resetTime of periodResetTimestamps) {
        if (
            Math.abs(time1 - resetTime) <= bufferSec ||
            Math.abs(time2 - resetTime) <= bufferSec
        ) {
            return true
        }

        const minTime = Math.min(time1, time2)
        const maxTime = Math.max(time1, time2)
        if (resetTime > minTime && resetTime < maxTime) {
            return true
        }
    }

    return false
}

function getBarsSinceLastReset(currentTime) {
    if (!enableResetProtection) return Infinity
    if (periodResetTimestamps.length === 0) return Infinity

    const lastReset = periodResetTimestamps[periodResetTimestamps.length - 1]
    const barSec = Math.max(candles.unix(0) - candles.unix(1), 1)

    return Math.floor((currentTime - lastReset) / barSec)
}

/* ═══════════════════════════════════════════════════════════
   REAL-TIME DIVERGENCE DETECTION (0 DELAY)
   ═══════════════════════════════════════════════════════════ */

function detectRealTimeDivergences(
    currentPrice,
    currentZScore,
    currentHigh,
    currentLow,
    currentTime
) {
    if (priceHistory.length < 5) return

    const barsSinceReset = getBarsSinceLastReset(currentTime)
    const minBarsAfterReset = resetBufferBars

    if (barsSinceReset < minBarsAfterReset) {
        lastPriceHigh = -Infinity
        lastPriceLow = Infinity
        return
    }

    const priceChangePercent =
        Math.abs(
            (currentPrice - priceHistory[priceHistory.length - 2]) /
            priceHistory[priceHistory.length - 2]
        ) * 100

    if (currentPrice > lastPriceHigh) {
        lastPriceHigh = currentPrice
        lastZScoreAtHigh = currentZScore
        lastHighTime = currentTime
    }

    if (currentPrice < lastPriceLow) {
        lastPriceLow = currentPrice
        lastZScoreAtLow = currentZScore
        lastLowTime = currentTime
    }

    if (showBearDiv && currentPrice > lastPriceHigh * 0.999) {
        const zScoreDiff = lastZScoreAtHigh - currentZScore

        if (
            zScoreDiff > rtMinZScoreDiff &&
            priceChangePercent > rtMinDistance &&
            !isNearPeriodReset(currentTime, lastHighTime, 1)
        ) {
            const divColor = color.transp(bearDivColor, preliminaryAlpha)

            Line("rt_bear_" + currentTime, {
                x1: lastHighTime,
                y1: lastZScoreAtHigh,
                x2: currentTime,
                y2: currentZScore,
                color: divColor,
                width: divLineWidth * 0.8,
                style: linestyle.dashed
            })

            if (showDivMarkers) {
                Marker("rt_bear_m_" + currentTime, {
                    x: currentTime,
                    y: currentZScore,
                    shape: shape.circle,
                    size: divMarkerSize * 0.8,
                    color: divColor
                })
            }

            if (showDivLabels) {
                Label("rt_bear_l_" + currentTime, {
                    x: currentTime,
                    y: currentZScore,
                    text: "⚡BEAR",
                    color: divColor,
                    size: 9,
                    textAlign: text.align.center
                })
            }
        }
    }

    if (showBullDiv && currentPrice < lastPriceLow * 1.001) {
        const zScoreDiff = currentZScore - lastZScoreAtLow

        if (
            zScoreDiff > rtMinZScoreDiff &&
            priceChangePercent > rtMinDistance &&
            !isNearPeriodReset(currentTime, lastLowTime, 1)
        ) {
            const divColor = color.transp(bullDivColor, preliminaryAlpha)

            Line("rt_bull_" + currentTime, {
                x1: lastLowTime,
                y1: lastZScoreAtLow,
                x2: currentTime,
                y2: currentZScore,
                color: divColor,
                width: divLineWidth * 0.8,
                style: linestyle.dashed
            })

            if (showDivMarkers) {
                Marker("rt_bull_m_" + currentTime, {
                    x: currentTime,
                    y: currentZScore,
                    shape: shape.circle,
                    size: divMarkerSize * 0.8,
                    color: divColor
                })
            }

            if (showDivLabels) {
                Label("rt_bull_l_" + currentTime, {
                    x: currentTime,
                    y: currentZScore,
                    text: "⚡BULL",
                    color: divColor,
                    size: 9,
                    textAlign: text.align.center
                })
            }
        }
    }
}

/* ═══════════════════════════════════════════════════════════
   CLASSIC PIVOT-BASED DETECTION (CONFIRMED)
   ═══════════════════════════════════════════════════════════ */

function findPivotHigh(data, index, length) {
    if (index < length || index >= data.length - length) return false
    const center = data[index]
    for (let i = 1; i <= length; i++) {
        if (data[index - i] >= center || data[index + i] >= center) return false
    }
    return true
}

function findPivotLow(data, index, length) {
    if (index < length || index >= data.length - length) return false
    const center = data[index]
    for (let i = 1; i <= length; i++) {
        if (data[index - i] <= center || data[index + i] <= center) return false
    }
    return true
}

function detectClassicDivergences() {
    if (zScoreHistory.length < divPivotLength * 2 + divLookback) return

    const len = zScoreHistory.length
    const currentIdx = len - divPivotLength - 1
    if (currentIdx < 0) return

    const currentTime = timeHistory[currentIdx]

    const barsSinceReset = getBarsSinceLastReset(currentTime)
    const minBarsAfterReset = divPivotLength + resetBufferBars

    if (barsSinceReset < minBarsAfterReset) {
        return
    }

    const alpha = confirmedAlpha

    if (
        showBearDiv &&
        findPivotHigh(priceHistory, currentIdx, divPivotLength)
    ) {
        const priceHigh = priceHistory[currentIdx]
        const zScoreAtPriceHigh = zScoreHistory[currentIdx]

        for (
            let i = currentIdx - divPivotLength - 1;
            i >= Math.max(0, currentIdx - divLookback);
            i--
        ) {
            if (findPivotHigh(priceHistory, i, divPivotLength)) {
                const prevPriceHigh = priceHistory[i]
                const prevZScoreAtPriceHigh = zScoreHistory[i]

                if (
                    priceHigh > prevPriceHigh &&
                    zScoreAtPriceHigh < prevZScoreAtPriceHigh
                ) {
                    const prevTime = timeHistory[i]

                    if (
                        isNearPeriodReset(currentTime, prevTime, divPivotLength)
                    ) {
                        break
                    }

                    const divColor = color.transp(bearDivColor, alpha)

                    Line("cl_bear_" + currentTime, {
                        x1: prevTime,
                        y1: prevZScoreAtPriceHigh,
                        x2: currentTime,
                        y2: zScoreAtPriceHigh,
                        color: divColor,
                        width: divLineWidth,
                        style: linestyle.solid
                    })

                    if (showDivMarkers) {
                        Marker("cl_bear_m_" + currentTime, {
                            x: currentTime,
                            y: zScoreAtPriceHigh,
                            shape: shape.circle,
                            size: divMarkerSize,
                            color: divColor
                        })
                    }

                    if (showDivLabels) {
                        Label("cl_bear_l_" + currentTime, {
                            x: currentTime,
                            y: zScoreAtPriceHigh,
                            text: "✓BEAR",
                            color: divColor,
                            size: statsTextSize,
                            textAlign: text.align.center
                        })
                    }
                }
                break
            }
        }
    }

    if (showBullDiv && findPivotLow(priceHistory, currentIdx, divPivotLength)) {
        const priceLow = priceHistory[currentIdx]
        const zScoreAtPriceLow = zScoreHistory[currentIdx]

        for (
            let i = currentIdx - divPivotLength - 1;
            i >= Math.max(0, currentIdx - divLookback);
            i--
        ) {
            if (findPivotLow(priceHistory, i, divPivotLength)) {
                const prevPriceLow = priceHistory[i]
                const prevZScoreAtPriceLow = zScoreHistory[i]

                if (
                    priceLow < prevPriceLow &&
                    zScoreAtPriceLow > prevZScoreAtPriceLow
                ) {
                    const prevTime = timeHistory[i]

                    if (
                        isNearPeriodReset(currentTime, prevTime, divPivotLength)
                    ) {
                        break
                    }

                    const divColor = color.transp(bullDivColor, alpha)

                    Line("cl_bull_" + currentTime, {
                        x1: prevTime,
                        y1: prevZScoreAtPriceLow,
                        x2: currentTime,
                        y2: zScoreAtPriceLow,
                        color: divColor,
                        width: divLineWidth,
                        style: linestyle.solid
                    })

                    if (showDivMarkers) {
                        Marker("cl_bull_m_" + currentTime, {
                            x: currentTime,
                            y: zScoreAtPriceLow,
                            shape: shape.circle,
                            size: divMarkerSize,
                            color: divColor
                        })
                    }

                    if (showDivLabels) {
                        Label("cl_bull_l_" + currentTime, {
                            x: currentTime,
                            y: zScoreAtPriceLow,
                            text: "✓BULL",
                            color: divColor,
                            size: statsTextSize,
                            textAlign: text.align.center
                        })
                    }
                }
                break
            }
        }
    }
}

function interpolateColor(color1, color2, factor) {
    const c1 = parseInt(color1.replace("#", ""), 16)
    const c2 = parseInt(color2.replace("#", ""), 16)

    const r = Math.round(
        ((c1 >> 16) & 0xff) +
        factor * (((c2 >> 16) & 0xff) - ((c1 >> 16) & 0xff))
    )
    const g = Math.round(
        ((c1 >> 8) & 0xff) + factor * (((c2 >> 8) & 0xff) - ((c1 >> 8) & 0xff))
    )
    const b = Math.round((c1 & 0xff) + factor * ((c2 & 0xff) - (c1 & 0xff)))

    return "#" + ((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1)
}

function getMultiColorGradient(distance, threshold) {
    if (!useGradient) return distance >= 0 ? posColor3 : negColor3

    const absDist = Math.abs(distance)
    const isPositive = distance >= 0

    let normalized
    if (calculationMethod === "Z-Score (Auto-Normalized) ⭐") {
        normalized = Math.min(absDist / 3.0, 1.0)
    } else {
        normalized = Math.min(absDist / threshold, 2) / 2
    }

    const colors = isPositive
        ? [posColor1, posColor2, posColor3, posColor4, posColor5]
        : [negColor1, negColor2, negColor3, negColor4, negColor5]

    const numColors = Math.min(gradientSteps, 5)
    const segmentSize = 1.0 / (numColors - 1)
    const segment = Math.floor(normalized / segmentSize)
    const localFactor = (normalized - segment * segmentSize) / segmentSize
    const clampedSegment = Math.min(segment, numColors - 2)

    return interpolateColor(
        colors[clampedSegment],
        colors[clampedSegment + 1],
        localFactor
    )
}

function getPeriodLabel(code) {
    const labels = {
        "4H": "4H",
        "D": "Daily",
        "W": "Weekly",
        "M": "Monthly",
        "Q": "Quarterly",
        "Y": "Yearly",
        "R7D": "7D",
        "R14D": "14D",
        "R30D": "30D",
        "R60D": "60D",
        "R90D": "90D",
        "R120D": "120D",
        "R180D": "180D",
        "R365D": "365D"
    }
    return labels[code] || code
}

function getLineStyle(styleSelect) {
    if (styleSelect === "Solid") return linestyle.solid
    if (styleSelect === "Dashed") return linestyle.dashed
    if (styleSelect === "Dotted") return linestyle.dotted
    return linestyle.dashed
}

function drawResetLine(code, threshold) {
    if (!showResetLines) return
    const currentTime = candles.unix(0)
    const currentPeriodStart = startOfPeriod(code, currentTime)

    if (
        lastPeriodStart[code] !== null &&
        lastPeriodStart[code] !== currentPeriodStart
    ) {
        Line("reset_" + code, {
            x1: currentTime,
            y1: threshold * 1.5,
            x2: currentTime,
            y2: -threshold * 1.5,
            color: color.transp(resetLineColor, resetLineAlpha),
            width: resetLineWidth,
            style: linestyle.dashed
        })
    }
    lastPeriodStart[code] = currentPeriodStart
}

function getSigmaColor(level, visualMode) {
    if (visualMode === "Single Color") return singleSigmaColor
    if (visualMode === "Traffic Light Colors ⭐") {
        if (level === 1) return sigma1Color
        if (level === 2) return sigma2Color
        if (level === 3) return sigma3Color
    } else if (visualMode === "Gradient Colors") {
        if (level === 1) return sigma1Color
        if (level === 2) return interpolateColor(sigma1Color, sigma2Color, 0.5)
        if (level === 3) return sigma2Color
    }
    return singleSigmaColor
}

function drawZScoreLines() {
    const style = getLineStyle(thresholdStyle)
    const volAdj = getVolatilityAdjustment()

    const color1 = getSigmaColor(1, zScoreVisualMode)
    const color2 = getSigmaColor(2, zScoreVisualMode)
    const color3 = getSigmaColor(3, zScoreVisualMode)

    const level1 = zScoreLevel1 * volAdj
    const level2 = zScoreLevel2 * volAdj
    const level3 = zScoreLevel3 * volAdj

    const line3p = plot("3σ", level3, {
        color: color.transp(color3, 20),
        width: 0.8,
        style,
        showLabel: showYAxisLabels,
        showValue: showValues
    })
    const line3n = plot("-3σ", -level3, {
        color: color.transp(color3, 20),
        width: 0.8,
        style,
        showLabel: showYAxisLabels,
        showValue: showValues
    })
    const line2p = plot("2σ", level2, {
        color: color2,
        width: 2,
        style,
        showLabel: showYAxisLabels,
        showValue: showValues
    })
    const line2n = plot("-2σ", -level2, {
        color: color2,
        width: 2,
        style,
        showLabel: showYAxisLabels,
        showValue: showValues
    })
    const line1p = plot("1σ", level1, {
        color: color.transp(color1, 20),
        width: 1,
        style,
        showLabel: showYAxisLabels,
        showValue: showValues
    })
    const line1n = plot("-1σ", -level1, {
        color: color.transp(color1, 20),
        width: 1,
        style,
        showLabel: showYAxisLabels,
        showValue: showValues
    })

    if (fillZoneSigma) {
        fill(line3p, line2p, { color: color.transp(fillSigma3Color, fillAlphaSigma) })
        fill(line2n, line3n, { color: color.transp(fillSigma3Color, fillAlphaSigma) })
        fill(line2p, line1p, { color: color.transp(fillSigma2Color, fillAlphaSigma) })
        fill(line1n, line2n, { color: color.transp(fillSigma2Color, fillAlphaSigma) })
        const lineZero = plot("Zero_fill", 0, {
            color: color.transp(zeroColor, 100),
            width: 0.1,
            showLabel: false,
            showValue: false
        })
        fill(line1p, lineZero, {
            color: color.transp(fillSigma1Color, fillAlphaSigma)
        })
        fill(lineZero, line1n, {
            color: color.transp(fillSigma1Color, fillAlphaSigma)
        })
    }

    if (showPercentileZones) {
        plot("90th %ile", level2 * 1.3, {
            color: color.transp(color.orange, 80),
            width: 0.5,
            style: linestyle.dotted,
            showLabel: showYAxisLabels
        })
        plot("10th %ile", -level2 * 1.3, {
            color: color.transp(color.orange, 80),
            width: 0.5,
            style: linestyle.dotted,
            showLabel: showYAxisLabels
        })
    }
}

function drawStatsTable(currentZScore, threshold) {
    if (!showStatsTable) return
    const isZScore = calculationMethod === "Z-Score (Auto-Normalized) ⭐"
    if (!isZScore) return

    const z = currentZScore,
        pct = currentStats.percentile
    const vol = currentStats.volRatio,
        regime = getVolatilityRegime()

    let statsText = `━━━━━ STATS ━━━━━\n`
    statsText += `Z: ${z.toFixed(2)} (${pct.toFixed(0)}%ile)\n`
    statsText += `μ: ${currentStats.mean.toFixed(1)}\n`
    statsText += `σ: ${currentStats.stdDev.toFixed(1)}\n`
    statsText += `n: ${currentStats.sampleCount}\n`

    if (
        showFallbackWarning &&
        zScoreCalcMethod === "Per Period Close (Structural) ⭐" &&
        distanceHistoryPeriods.length < 5
    ) {
        statsText += `━━━━━━━━━━━━━━━\n`
        statsText += `⚠️ Auto-Fallback\n`
        statsText += `Períodos: ${distanceHistoryPeriods.length}/5`
    }

    if (useVolatilityAdjustment) {
        statsText += `\n━━━━━━━━━━━━━━━\n`
        statsText += `Vol: ${regime}\n`
        statsText += `Ratio: ${vol.toFixed(2)}x`
    }

    const currentTime = candles.unix(0)
    const barSec = Math.max(candles.unix(0) - candles.unix(1), 1)

    let xPos = currentTime,
        yPos = threshold * 0.6,
        alignValue

    if (statsPosition === "Right of Last Bar ⭐") {
        xPos = currentTime + barSec * 3
        yPos = threshold * 0.8
        alignValue = text.align.left
    } else if (statsPosition === "Top Right") {
        xPos = currentTime
        yPos = threshold * 1.4
        alignValue = text.align.right
    } else if (statsPosition === "Top Left") {
        xPos = candles.unix(Math.min(barCount() - 1, 100))
        yPos = threshold * 1.4
        alignValue = text.align.left
    } else if (statsPosition === "Bottom Right") {
        xPos = currentTime
        yPos = -threshold * 1.4
        alignValue = text.align.right
    } else if (statsPosition === "Bottom Left") {
        xPos = candles.unix(Math.min(barCount() - 1, 100))
        yPos = -threshold * 1.4
        alignValue = text.align.left
    } else {
        alignValue = text.align.left
    }

    if (!statsLabel) {
        statsLabel = Label("stats_table", {
            x: xPos,
            y: yPos,
            text: statsText,
            color: statsTextColor,
            size: statsTextSize,
            textAlign: alignValue
        })
    } else {
        statsLabel.set({
            x: xPos,
            y: yPos,
            text: statsText,
            color: statsTextColor,
            size: statsTextSize,
            textAlign: alignValue
        })
    }
}

function onBar(barIndex) {
    const currentPrice = getPrice(0)
    const currentHigh = candles.high(0)
    const currentLow = candles.low(0)
    const currentTime = candles.unix(0)

    const fixedPeriods = []
    const rollingPeriods = []

    if (show4H) fixedPeriods.push("4H")
    if (showDaily) fixedPeriods.push("D")
    if (showWeekly) fixedPeriods.push("W")
    if (showMonthly) fixedPeriods.push("M")
    if (showQuarterly) fixedPeriods.push("Q")
    if (showYearly) fixedPeriods.push("Y")

    if (showRolling7D) rollingPeriods.push({ code: "R7D", days: 7 })
    if (showRolling14D) rollingPeriods.push({ code: "R14D", days: 14 })
    if (showRolling30D) rollingPeriods.push({ code: "R30D", days: 30 })
    if (showRolling60D) rollingPeriods.push({ code: "R60D", days: 60 })
    if (showRolling90D) rollingPeriods.push({ code: "R90D", days: 90 })
    if (showRolling120D) rollingPeriods.push({ code: "R120D", days: 120 })
    if (showRolling180D) rollingPeriods.push({ code: "R180D", days: 180 })
    if (showRolling365D) rollingPeriods.push({ code: "R365D", days: 365 })

    const threshold = calculateAdaptiveThreshold()
    const isZScore = calculationMethod === "Z-Score (Auto-Normalized) ⭐"

    if (showZero) {
        plot("Zero", 0, {
            color: zeroColor,
            width: zeroWidth,
            style: linestyle.solid,
            showLabel: false,
            showValue: false
        })
    }

    if (showThresholdLines) {
        if (isZScore) {
            drawZScoreLines()
        } else {
            const style = getLineStyle(thresholdStyle)
            plot("Upper", threshold, {
                color: singleSigmaColor,
                width: 1.5,
                style,
                showLabel: showYAxisLabels,
                showValue: showValues
            })
            plot("Lower", -threshold, {
                color: singleSigmaColor,
                width: 1.5,
                style,
                showLabel: showYAxisLabels,
                showValue: showValues
            })
        }
    }

    let currentDistanceRaw = NaN,
        mainDistance = NaN,
        mainPeriodCode = null

    for (const period of fixedPeriods) {
        let vwap = NaN,
            distance = NaN,
            shouldHide = false

        vwap = getFixedPeriodVWAP(period)

        if (periodChanged(period)) {
            trackPeriodReset(period, currentTime)
            drawResetLine(period, threshold)
            if (hideOnPeriodChange) shouldHide = true
        }

        if (!isNaN(vwap)) {
            const rawDist = currentPrice - vwap
            if (isNaN(currentDistanceRaw)) {
                currentDistanceRaw = rawDist
                mainPeriodCode = period
            }
        }

        distance = calculateDistance(currentPrice, vwap, period)

        if (!isNaN(distance) && isNaN(mainDistance)) mainDistance = distance

        if (!isNaN(distance) && !shouldHide) {
            const finalColor = getMultiColorGradient(distance, threshold)
            plotHistogram(getPeriodLabel(period), distance, {
                color: finalColor,
                showLabel: showLabels,
                showValue: showValues
            })
        }
    }

    for (const rp of rollingPeriods) {
        const vwap = getRollingVWAP(rp.code, rp.days)

        if (!isNaN(vwap)) {
            const rawDist = currentPrice - vwap
            if (isNaN(currentDistanceRaw)) {
                currentDistanceRaw = rawDist
                mainPeriodCode = rp.code
            }
        }

        const distance = calculateDistance(currentPrice, vwap, rp.code)
        if (!isNaN(distance) && isNaN(mainDistance)) mainDistance = distance

        if (!isNaN(distance)) {
            const finalColor = getMultiColorGradient(distance, threshold)
            plotHistogram(getPeriodLabel(rp.code), distance, {
                color: finalColor,
                showLabel: showLabels,
                showValue: showValues
            })
        }
    }

    if (!isNaN(currentDistanceRaw)) {
        distanceHistoryBars.push(currentDistanceRaw)
        if (distanceHistoryBars.length > maxHistoryLength)
            distanceHistoryBars.shift()

        if (
            mainPeriodCode &&
            zScoreCalcMethod === "Per Period Close (Structural) ⭐"
        ) {
            const currentKey = getPeriodKey(mainPeriodCode)

            if (lastPeriodKey !== null && lastPeriodKey !== currentKey) {
                if (!isNaN(lastPeriodEndDistance)) {
                    distanceHistoryPeriods.push(lastPeriodEndDistance)
                    if (distanceHistoryPeriods.length > maxHistoryLength) {
                        distanceHistoryPeriods.shift()
                    }
                }
            }

            lastPeriodEndDistance = currentDistanceRaw
            lastPeriodKey = currentKey
        }
    }

    priceHistory.push(currentPrice)
    highHistory.push(currentHigh)
    lowHistory.push(currentLow)
    timeHistory.push(currentTime)

    if (priceHistory.length > maxHistoryLength) {
        priceHistory.shift()
        highHistory.shift()
        lowHistory.shift()
        timeHistory.shift()
    }

    if (!isNaN(mainDistance)) {
        currentStats.zScore = mainDistance
        zScoreHistory.push(mainDistance)
        if (zScoreHistory.length > maxHistoryLength) zScoreHistory.shift()
    }

    if (isZScore && showDivergences) {
        if (divergenceMode === "Real-Time (No Confirmation) ⚡") {
            detectRealTimeDivergences(
                currentPrice,
                mainDistance,
                currentHigh,
                currentLow,
                currentTime
            )
        } else if (divergenceMode === "Classic (Pivot Confirmed) 📊") {
            detectClassicDivergences()
        } else if (divergenceMode === "Hybrid (Both) ⭐") {
            detectRealTimeDivergences(
                currentPrice,
                mainDistance,
                currentHigh,
                currentLow,
                currentTime
            )
            detectClassicDivergences()
        }
    }

    drawStatsTable(mainDistance, threshold)

    const mode = isZScore ? "Z" : distanceType === "Percentage (%)" ? "%" : "$"

    let methodShort
    if (isZScore) {
        const mainIsLongPeriod =
            mainPeriodCode === "Y" || mainPeriodCode === "Q"
        const hasEnoughPeriods = distanceHistoryPeriods.length >= 5

        if (zScoreCalcMethod === "Per Bar (Real-time) 🔄") {
            methodShort = "σB"
        } else if (mainIsLongPeriod && !hasEnoughPeriods) {
            methodShort = "σB*"
        } else {
            methodShort = "σP"
        }
    } else {
        methodShort = thresholdMode.split(" ")[0]
    }

    let displayName = `VWAP ${mode} · ${methodShort} · ${fixedPeriods.length}F+${rollingPeriods.length}R`

    if (isZScore && useVolatilityAdjustment && showVolatilityInfo) {
        displayName += ` · ${getVolatilityRegime()}`
    }

    if (isZScore && showDivergences) {
        const divModeShort =
            divergenceMode === "Real-Time (No Confirmation) ⚡"
                ? "⚡RT"
                : divergenceMode === "Classic (Pivot Confirmed) 📊"
                    ? "📊P"
                    : "⭐HYB"
        displayName += ` · ${divModeShort}`
    }

    setDisplayName(displayName)
}
