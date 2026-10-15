//@version=2
// Multi-Period VWAP with StdDev Bands + Persistent Naked VWAPs + Rolling VWAPs
indicator("VWAP Multi-Period", true)

/* ═══════════════════════════════════════════
   ░ PERIOD VWAPS (Multiple Concurrent)
   ═══════════════════════════════════════════ */
input.section("═══ PERIOD VWAPs ═══")

input.section("Period Selection / Show projection / Show STD / Fill STD")
// 4H
const show4H = input.bool("Show 4 Hours VWAP", false, { key: "inp_show_4_hours_vwap" })
const project4H = input.bool("Project past", false, { key: "proj_4h", sameLine: true })
const stdShow4H = input.bool("σ", true, { key: "std_4h", sameLine: true })
const stdFill4H = input.bool("fill", true, { key: "fill_4h", sameLine: true })
// Daily
const showDaily = input.bool("Show Daily VWAP", false, { key: "inp_show_daily_vwap" })
const projectDaily = input.bool("d", false, { key: "proj_d", sameLine: true })
const stdShowD = input.bool("σd", true, { key: "std_d", sameLine: true })
const stdFillD = input.bool("filld", true, { key: "fill_d", sameLine: true })
// Weekly
const showWeekly = input.bool("Show Weekly VWAP", true, { key: "inp_show_weekly_vwap" })
const projectWeekly = input.bool("w", true, { key: "proj_w", sameLine: true })
const stdShowW = input.bool("σw", true, { key: "std_w", sameLine: true })
const stdFillW = input.bool("fillw", true, { key: "fill_w", sameLine: true })
// Monthly
const showMonthly = input.bool("Show Monthly VWAP", false, { key: "inp_show_monthly_vwap" })
const projectMonthly = input.bool("m", false, { key: "proj_m", sameLine: true })
const stdShowM = input.bool("σm", true, { key: "std_m", sameLine: true })
const stdFillM = input.bool("fillm", true, { key: "fill_m", sameLine: true })
// Quarterly
const showQuarterly = input.bool("Show Quarterly VWAP", false, { key: "inp_show_quarterly_vwap" })
const projectQuarterly = input.bool("q", false, { key: "proj_q", sameLine: true })
const stdShowQ = input.bool("σq", true, { key: "std_q", sameLine: true })
const stdFillQ = input.bool("fillq", true, { key: "fill_q", sameLine: true })
// Yearly
const showYearly = input.bool("Show Yearly VWAP", false, { key: "inp_show_yearly_vwap" })
const projectYearly = input.bool("y", false, { key: "proj_y", sameLine: true })
const stdShowY = input.bool("σy", true, { key: "std_y", sameLine: true })
const stdFillY = input.bool("filly", true, { key: "fill_y", sameLine: true })

input.section("Visual Settings · Period VWAPs")
const cutOnReset = input.bool("Hide jump at period change", true, { key: "inp_hide_jump_at_period_change" })
const vwapFallbackNoVol = input.bool("If V=0 → use TWAP (typical price mean)", true
, { key: "inp_if_v_0___use_twap__typical_price_mean" })

input.section("Period VWAP Colors & Widths")
const color4H = input.color("4H color", "#A8B5D1", { key: "inp_4h_color" })
const width4H = input.float("4H width", 1.5, { key: "inp_4h_width",
    min: 0.5,
    max: 5,
    sameLine: true
})

const colorDaily = input.color("Daily color", "#E3B341", { key: "vwap_color_daily" })
const widthDaily = input.float("Daily width", 2, { key: "inp_daily_width",
    min: 0.5,
    max: 5,
    sameLine: true
})

const colorWeekly = input.color("Weekly color", "#6ECF7A", { key: "vwap_color_weekly" })
const widthWeekly = input.float("Weekly width", 2, { key: "inp_weekly_width",
    min: 0.5,
    max: 5,
    sameLine: true
})

const colorMonthly = input.color("Monthly color", "#4ECDC4", { key: "vwap_color_monthly" })
const widthMonthly = input.float("Monthly width", 2.5, { key: "inp_monthly_width",
    min: 0.5,
    max: 5,
    sameLine: true
})

const colorQuarterly = input.color("Quarterly color", "#B084CC", { key: "vwap_color_quarterly" })
const widthQuarterly = input.float("Quarterly width", 2.5, { key: "inp_quarterly_width",
    min: 0.5,
    max: 5,
    sameLine: true
})

const colorYearly = input.color("Yearly color", "#E36E6E", { key: "vwap_color_yearly" })
const widthYearly = input.float("Yearly width", 3, { key: "inp_yearly_width",
    min: 0.5,
    max: 5,
    sameLine: true
})

/* ═══════════════════════════════════════════
   ░ STD BANDS · PERIOD VWAPS
   ═══════════════════════════════════════════ */
input.section("StdDev Bands · Period VWAPs")
const showStd1 = input.bool("Show Std 1 for all periods", true, { key: "inp_show_std_1_for_all_periods" })
const std1Mult = input.float("Std 1 · multiplier", 1.0, { key: "inp_std_1___multiplier",
    min: 0.1,
    max: 5,
    sameLine: true
})
const std1Color = input.color("Std 1 · color", "#6B8BB9", { key: "inp_std_1___color", sameLine: true })

const showStd2 = input.bool("Show Std 2 for all periods", false, { key: "inp_show_std_2_for_all_periods" })
const std2Mult = input.float("Std 2 · multiplier", 2.0, { key: "inp_std_2___multiplier",
    min: 0.1,
    max: 5,
    sameLine: true
})
const std2Color = input.color("Std 2 · color", "#B084CC", { key: "inp_std_2___color", sameLine: true })

const showStd3 = input.bool("Show Std 3 for all periods", false, { key: "inp_show_std_3_for_all_periods" })
const std3Mult = input.float("Std 3 · multiplier", 3.0, { key: "inp_std_3___multiplier",
    min: 0.1,
    max: 5,
    sameLine: true
})
const std3Color = input.color("Std 3 · color", "#66AFA1", { key: "inp_std_3___color", sameLine: true })

const showStdLabels = input.bool("Show Std band labels", false, { key: "inp_show_std_band_labels" })

/* ═══════════════════════════════════════════
   ░ FILLS · PERIOD VWAPS
   ═══════════════════════════════════════════ */
input.section("Band Fills · Period VWAPs")
const fillStd1Current = input.bool("Fill Std 1", true, { key: "inp_fill_std_1" })
const fillStd2Current = input.bool("Fill Std 2 ring (1σ→2σ)", false, { key: "inp_fill_std_2_ring__1__2" })
const fillStd3Current = input.bool("Fill Std 3", false, { key: "inp_fill_std_3" })
const fillAlphaCurrent = input.float("Fill transparency", 85, { key: "inp_fill_transparency",
    min: 0,
    max: 100
})

/* ═══════════════════════════════════════════
   ░ PAST PERIOD PROJECTIONS
   ═══════════════════════════════════════════ */
input.section("Past Period Projections · Settings")
const extendPrevVWAP = input.bool("Extend past VWAPs", true, { key: "inp_extend_past_vwaps" })
const extendPrevStd1 = input.bool("Extend past Std 1", true, { key: "inp_extend_past_std_1" })
const extendPrevStd2 = input.bool("Extend past Std 2", false, { key: "inp_extend_past_std_2" })
const extendPrevCount = input.int("# of past periods to project", 1, { key: "inp_of_past_periods_to_project",
    min: 0,
    max: 10
})
const extendColorBase = input.color("Projection base color", "#8B90A8", { key: "inp_projection_base_color" })
const extendWidth = input.float("Projected lines width", 1, { key: "inp_projected_lines_width", min: 1, max: 3 })
const ageExtraAlpha = input.int("Extra transparency per age (per period)", 2, { key: "inp_extra_transparency_per_age__per_period",
    min: 0,
    max: 30
})
const projSkipBarsAtStart = input.int("Projection: skip first N bars from start", 0, { key: "inp_projection__skip_first_n_bars_from_start", min: 0, max: 10 })

input.section("Band Fills · Projections")
const fillPrevStd1 = input.bool("Fill Std 1 (projected)", true, { key: "inp_fill_std_1__projected" })
const fillPrevStd2 = input.bool("Fill Std 2 ring (1σ→2σ, projected)", false, { key: "inp_fill_std_2_ring__1__2___projected" })
const fillAlphaProj = input.float("Fill transparency (projected)", 92, { key: "inp_fill_transparency__projected",
    min: 0,
    max: 100
})

/* ═══════════════════════════════════════════
   ░ ROLLING VWAPs (Independent)
   ═══════════════════════════════════════════ */
input.section("═══ ROLLING VWAPs ═══")

input.section("Rolling VWAP 7D")
const rvwap7dEnable = input.bool("Show 7D Rolling VWAP", false, { key: "inp_show_7d_rolling_vwap" })
const rvwap7dDays = input.int("Rolling window (days) · 7D", 7, { key: "inp_rolling_window__days____7d",
    min: 1,
    max: 720
})
const rvwap7dColor = input.color("7D VWAP color", "#FF6B6B", { key: "inp_7d_vwap_color", sameLine: true })
const rvwap7dWidth = input.float("7D VWAP width", 1.5, { key: "inp_7d_vwap_width", min: 0.5, max: 5 })
const rvwap7dStd1Enable = input.bool("Show 7D Std 1", false, { key: "inp_show_7d_std_1" })
const rvwap7dStd1Mult = input.float("7D Std 1 multiplier", 1.0, { key: "inp_7d_std_1_multiplier",
    min: 0.1,
    max: 5,
    sameLine: true
})
const rvwap7dStd1Color = input.color("7D Std 1 color", "#FF9999", { key: "inp_7d_std_1_color",
    sameLine: true
})
const rvwap7dStd2Enable = input.bool("Show 7D Std 2", false, { key: "inp_show_7d_std_2" })
const rvwap7dStd2Mult = input.float("7D Std 2 multiplier", 2.0, { key: "inp_7d_std_2_multiplier",
    min: 0.1,
    max: 5,
    sameLine: true
})
const rvwap7dStd2Color = input.color("7D Std 2 color", "#FFCCCC", { key: "inp_7d_std_2_color",
    sameLine: true
})
const rvwap7dFillStd1 = input.bool("Fill 7D Std 1", false, { key: "inp_fill_7d_std_1" })
const rvwap7dFillStd2 = input.bool("Fill 7D Std 2 ring", false, { key: "inp_fill_7d_std_2_ring",
    sameLine: true
})
const rvwap7dFillAlpha = input.float("7D Fill transparency", 90, { key: "inp_7d_fill_transparency",
    min: 0,
    max: 100
})

input.section("Rolling VWAP 30D")
const rvwap30dEnable = input.bool("Show 30D Rolling VWAP", false, { key: "inp_show_30d_rolling_vwap" })
const rvwap30dDays = input.int("Rolling window (days) · 30D", 30, { key: "inp_rolling_window__days____30d",
    min: 1,
    max: 720
})
const rvwap30dColor = input.color("30D VWAP color", "#4ECDC4", { key: "inp_30d_vwap_color",
    sameLine: true
})
const rvwap30dWidth = input.float("30D VWAP width", 1.5, { key: "inp_30d_vwap_width", min: 0.5, max: 5 })
const rvwap30dStd1Enable = input.bool("Show 30D Std 1", false, { key: "inp_show_30d_std_1" })
const rvwap30dStd1Mult = input.float("30D Std 1 multiplier", 1.0, { key: "inp_30d_std_1_multiplier",
    min: 0.1,
    max: 5,
    sameLine: true
})
const rvwap30dStd1Color = input.color("30D Std 1 color", "#7FD9D1", { key: "inp_30d_std_1_color",
    sameLine: true
})
const rvwap30dStd2Enable = input.bool("Show 30D Std 2", false, { key: "inp_show_30d_std_2" })
const rvwap30dStd2Mult = input.float("30D Std 2 multiplier", 2.0, { key: "inp_30d_std_2_multiplier",
    min: 0.1,
    max: 5,
    sameLine: true
})
const rvwap30dStd2Color = input.color("30D Std 2 color", "#B3E6E0", { key: "inp_30d_std_2_color",
    sameLine: true
})
const rvwap30dFillStd1 = input.bool("Fill 30D Std 1", false, { key: "inp_fill_30d_std_1" })
const rvwap30dFillStd2 = input.bool("Fill 30D Std 2 ring", false, { key: "inp_fill_30d_std_2_ring",
    sameLine: true
})
const rvwap30dFillAlpha = input.float("30D Fill transparency", 90, { key: "inp_30d_fill_transparency",
    min: 0,
    max: 100
})

input.section("Rolling VWAP 90D")
const rvwap90dEnable = input.bool("Show 90D Rolling VWAP", false, { key: "inp_show_90d_rolling_vwap" })
const rvwap90dDays = input.int("Rolling window (days) · 90D", 90, { key: "inp_rolling_window__days____90d",
    min: 1,
    max: 720
})
const rvwap90dColor = input.color("90D VWAP color", "#FFD93D", { key: "inp_90d_vwap_color",
    sameLine: true
})
const rvwap90dWidth = input.float("90D VWAP width", 1.5, { key: "inp_90d_vwap_width", min: 0.5, max: 5 })
const rvwap90dStd1Enable = input.bool("Show 90D Std 1", false, { key: "inp_show_90d_std_1" })
const rvwap90dStd1Mult = input.float("90D Std 1 multiplier", 1.0, { key: "inp_90d_std_1_multiplier",
    min: 0.1,
    max: 5,
    sameLine: true
})
const rvwap90dStd1Color = input.color("90D Std 1 color", "#FFE066", { key: "inp_90d_std_1_color",
    sameLine: true
})
const rvwap90dStd2Enable = input.bool("Show 90D Std 2", false, { key: "inp_show_90d_std_2" })
const rvwap90dStd2Mult = input.float("90D Std 2 multiplier", 2.0, { key: "inp_90d_std_2_multiplier",
    min: 0.1,
    max: 5,
    sameLine: true
})
const rvwap90dStd2Color = input.color("90D Std 2 color", "#FFEB99", { key: "inp_90d_std_2_color",
    sameLine: true
})
const rvwap90dFillStd1 = input.bool("Fill 90D Std 1", false, { key: "inp_fill_90d_std_1" })
const rvwap90dFillStd2 = input.bool("Fill 90D Std 2 ring", false, { key: "inp_fill_90d_std_2_ring",
    sameLine: true
})
const rvwap90dFillAlpha = input.float("90D Fill transparency", 90, { key: "inp_90d_fill_transparency",
    min: 0,
    max: 100
})

/* ═══════════════════════════════════════════
   ░ NAKED VWAPS (persistent)
   ═══════════════════════════════════════════ */
input.section("═══ NAKED VWAPs ═══")

input.section("Naked VWAPs · Enable")
const showNakedVWAP = input.bool("Show Naked VWAPs", false, { key: "inp_show_naked_vwaps" })
const nakedOnlyMode = input.bool("Only naked mode (hide period VWAPs, keep projections)", false
, { key: "inp_only_naked_mode__hide_period_vwaps__keep_projections" })
const hideDeadNVWAPs = input.bool("Hide dead/invalidated NVWAPs", false, { key: "inp_hide_dead_invalidated_nvwaps" })
const showNakedStdBands = input.bool("Show Naked Std bands", false, { key: "inp_show_naked_std_bands" })
const nakedStdAlpha = input.int("Naked Std transparency", 70, { key: "inp_naked_std_transparency",
    min: 0,
    max: 95
})
const showNakedStdText = input.bool("Show text for Naked Std bands", false, { key: "inp_show_text_for_naked_std_bands" })
const nakedStdAxisLabels = input.bool("Show Naked Std as axis labels", true, { key: "inp_show_naked_std_as_axis_labels" })
const nakedStdTextSize = input.int("Naked Std text size", 10, { key: "inp_naked_std_text_size",
    min: 8,
    max: 24
})
const scoringTextSize = input.int("Scoring text size (R/V/Δ, z)", 11, { key: "inp_scoring_text_size__r_v____z",
    min: 8,
    max: 24
})
const nvAxisIncludeScoring = input.bool("Include scoring next to NVWAP axis label", true
, { key: "inp_include_scoring_next_to_nvwap_axis_label" })

input.section("Naked VWAPs · Period Selection")
const nkInc4H = input.bool("Include 4H/1D/1W", false, { key: "inp_include_4h_1d_1w" })
const nkIncD = input.bool("Include Daily", false, { key: "inp_include_daily", sameLine: true })
const nkIncW = input.bool("Include Weekly", false, { key: "inp_include_weekly", sameLine: true })
const nkIncM = input.bool("Include 1M/1Q/1Y", true, { key: "inp_include_1m_1q_1y" })
const nkIncQ = input.bool("Include Quarterly", false, { key: "inp_include_quarterly", sameLine: true })
const nkIncY = input.bool("Include Yearly", false, { key: "inp_include_yearly", sameLine: true })

input.section("Naked VWAPs · Visual Settings")
const nvwLabelMode = input.select("NVWAP label mode", 0, { key: "inp_nvwap_label_mode",
    selectables: ["Axis label", "Floating text next to line"]
})
const onlyNakedProjMode = input.select("Only naked · Projection content", 0, { key: "inp_only_naked___projection_content",
    selectables: ["VWAP only", "VWAP + Std1", "VWAP + Std1 + Std2"]
})
const nakedLineStyle = input.select("NVWAP line style", 0, { key: "inp_nvwap_line_style",
    selectables: ["Dotted", "Solid"]
})
const nakedWidth = input.float("NVWAP line width", 0.9, { key: "inp_nvwap_line_width", min: 0.5, max: 4 })

input.section("Naked VWAPs · Colors")
const colD = input.color("Daily color", "#F3B4B4", { key: "naked_color_daily" })
const colW = input.color("Weekly color", "#EF8D8D", { key: "naked_color_weekly" })
const colM = input.color("Monthly color", "#EA6E6E", { key: "naked_color_monthly" })
const colQ = input.color("Quarterly color", "#E04E4E", { key: "naked_color_quarterly" })
const colY = input.color("Yearly color", "#D73434", { key: "naked_color_yearly" })

input.section("Naked VWAPs · Behavior")
const nakedLookback = input.int("Seed historical periods per type", 6, { key: "inp_seed_historical_periods_per_type",
    min: 0,
    max: 60
})
const nakedNearestPerType = input.int("Show only X closest per type (0=all)", 2, { key: "inp_show_only_x_closest_per_type__0_all", min: 0, max: 50 })
const nakedDimAlpha = input.int("Dim non-topX opacity (0-100)", 10, { key: "inp_dim_non_topx_opacity__0_100",
    min: 0,
    max: 100
})

input.section("Naked VWAPs · Touch Invalidation")
const nakedTouchKind = input.select("Touch invalidates", 0, { key: "inp_touch_invalidates",
    selectables: ["Wick", "Body"]
})
const nakedTolBps = input.float("Touch tolerance (bps)", 2.0, { key: "inp_touch_tolerance__bps",
    min: 0.0,
    max: 100.0
})
const nakedTolAbs = input.float("Minimum absolute tolerance", 0.0, { key: "inp_minimum_absolute_tolerance",
    min: 0.0,
    max: 1e9
})

/* ═══════════════════════════════════════════
   ░ SCORING & RANKING (NVWAP)
   ═══════════════════════════════════════════ */
input.section("═══ SCORING & RANKING ═══")
input.section("Scoring · Volume & Delta")
const scoreWindowN = input.int("Rolling window per type (N)", 14, { key: "inp_rolling_window_per_type__n",
    min: 3,
    max: 200
})
const nvVolScoreEnable = input.bool("Show Volume score (0–100)", false, { key: "inp_show_volume_score__0_100" })
const nvDeltaScoreEnable = input.bool("Enable Delta z-score (signed)", false, { key: "inp_enable_delta_z_score__signed" })

input.section("Scoring · Composite Ranking")
const nvCompositeEnable = input.bool("Enable Composite ranking (R)", true, { key: "inp_enable_composite_ranking__r" })
const nvCompositeDisplay = input.select("Composite display", 0, { key: "inp_composite_display",
    selectables: ["R only", "R + V", "R + V + Δ"]
})
const nvCompositeColorByDelta = input.bool("Color Composite by Δ sign (green + / red -)", true
, { key: "inp_color_composite_by___sign__green_____red" })
const nvCompWVol = input.float("Composite weight · Volume (0..1)", 0.7, { key: "inp_composite_weight___volume__0__1",
    min: 0,
    max: 1
})
const nvCompWDelta = input.float("Composite weight · Delta (0..1)", 0.3, { key: "inp_composite_weight___delta__0__1",
    min: 0,
    max: 1,
    sameLine: true
})

/* ═══════════════════════════════════════════
   ░ DEBUG / DIAGNOSTICS
   ═══════════════════════════════════════════ */
input.section("═══ DEBUG ═══")
const nvDebugEnable = input.bool("Enable NVWAP debug (raw V/Δ)", false, { key: "inp_enable_nvwap_debug__raw_v" })
const nvDebugMetrics = input.select("Debug metrics", 2, { key: "inp_debug_metrics",
    selectables: ["Volume", "Delta", "Volume + Delta"]
})
const nvDebugUnits = input.select("Debug units", 1, { key: "inp_debug_units",
    selectables: ["Raw", "K / M / B"]
})

/* ========== Data ========== */
const candles = subscribe(data.OHLCV)
/* ========== Time utilities ========== */
function startOfPeriodFor(code, ts) {
    if (code === "4H") {
        const s = 4 * 3600
        return Math.floor(ts / s) * s
    }
    const d = new Date(ts * 1000)
    if (code === "D") {
        d.setUTCHours(0, 0, 0, 0)
        return (d.getTime() / 1000) | 0
    }
    if (code === "W") {
        const dow = (d.getUTCDay() + 6) % 7
        d.setUTCDate(d.getUTCDate() - dow)
        d.setUTCHours(0, 0, 0, 0)
        return (d.getTime() / 1000) | 0
    }
    if (code === "M") {
        d.setUTCDate(1)
        d.setUTCHours(0, 0, 0, 0)
        return (d.getTime() / 1000) | 0
    }
    if (code === "Q") {
        const m = d.getUTCMonth(),
            q = Math.floor(m / 3) * 3
        d.setUTCMonth(q, 1)
        d.setUTCHours(0, 0, 0, 0)
        return (d.getTime() / 1000) | 0
    }
    if (code === "Y") {
        d.setUTCMonth(0, 1)
        d.setUTCHours(0, 0, 0, 0)
        return (d.getTime() / 1000) | 0
    }
    return ts
}
function prevStartFor(code, cur) {
    if (code === "4H") return cur - 4 * 3600
    const d = new Date(cur * 1000)
    if (code === "D") d.setUTCDate(d.getUTCDate() - 1)
    else if (code === "W") d.setUTCDate(d.getUTCDate() - 7)
    else if (code === "M") d.setUTCMonth(d.getUTCMonth() - 1)
    else if (code === "Q") d.setUTCMonth(d.getUTCMonth() - 3)
    else if (code === "Y") d.setUTCFullYear(d.getUTCFullYear() - 1)
    d.setUTCHours(0, 0, 0, 0)
    return (d.getTime() / 1000) | 0
}
// Incremental period VWAP state — O(1) per bar instead of O(period_bars)
const periodVWAPState = {}

/* ========== Period config helpers ========== */
function isPeriodEnabled(code) {
    if (code === "4H") return show4H
    if (code === "D") return showDaily
    if (code === "W") return showWeekly
    if (code === "M") return showMonthly
    if (code === "Q") return showQuarterly
    if (code === "Y") return showYearly
    return false
}
function isPeriodProjectionEnabled(code) {
    if (code === "4H") return project4H
    if (code === "D") return projectDaily
    if (code === "W") return projectWeekly
    if (code === "M") return projectMonthly
    if (code === "Q") return projectQuarterly
    if (code === "Y") return projectYearly
    return false
}
function getPeriodColor(code) {
    if (code === "4H") return color4H
    if (code === "D") return colorDaily
    if (code === "W") return colorWeekly
    if (code === "M") return colorMonthly
    if (code === "Q") return colorQuarterly
    if (code === "Y") return colorYearly
    return color.white
}
function getPeriodWidth(code) {
    if (code === "4H") return width4H
    if (code === "D") return widthDaily
    if (code === "W") return widthWeekly
    if (code === "M") return widthMonthly
    if (code === "Q") return widthQuarterly
    if (code === "Y") return widthYearly
    return 2
}
function getPeriodLabel(code) {
    if (code === "4H") return "VWAP 4H"
    if (code === "D") return "VWAP Daily"
    if (code === "W") return "VWAP Weekly"
    if (code === "M") return "VWAP Monthly"
    if (code === "Q") return "VWAP Quarterly"
    if (code === "Y") return "VWAP Yearly"
    return "VWAP"
}

// Per-period Std visibility/fill
function periodStdEnabledFor(code) {
    if (code === "4H") return stdShow4H
    if (code === "D") return stdShowD
    if (code === "W") return stdShowW
    if (code === "M") return stdShowM
    if (code === "Q") return stdShowQ
    if (code === "Y") return stdShowY
    return true
}
function periodStdFillEnabledFor(code) {
    if (code === "4H") return stdFill4H
    if (code === "D") return stdFillD
    if (code === "W") return stdFillW
    if (code === "M") return stdFillM
    if (code === "Q") return stdFillQ
    if (code === "Y") return stdFillY
    return true
}

/* ========== VWAP/STD calculations ========== */
function calcVWAPForPeriod(code) {
    const nowSec = candles.unix(0)
    const curStart = startOfPeriodFor(code, nowSec)
    let st = periodVWAPState[code]
    if (!st || st.periodStart !== curStart) {
        st = { periodStart: curStart, sumPV: 0, sumV: 0, sumP2V: 0, lastSec: -1 }
        periodVWAPState[code] = st
    }
    if (st.lastSec !== nowSec) {
        st.lastSec = nowSec
        const h = candles.high(0),
            l = candles.low(0),
            c = candles.close(0),
            vol = candles.volume(0)
        const p = (h + l + c) / 3
        if (vol > 0) {
            st.sumPV += p * vol
            st.sumV += vol
            st.sumP2V += p * p * vol
        }
    }
    if (st.sumV <= 0) return { vwap: NaN, stdev: NaN }
    const vwap = st.sumPV / st.sumV
    const variance = Math.max(0, st.sumP2V / st.sumV - vwap * vwap)
    return { vwap, stdev: Math.sqrt(variance) }
}

function statsBetween(startSec, endSec) {
    let pv = 0,
        v = 0,
        p2v = 0,
        tp = 0,
        cnt = 0,
        buy = 0,
        sell = 0
    for (let i = 0; i < barCount(); i++) {
        const t = candles.unix(i)
        if (t < startSec) break
        if (t >= endSec) continue
        const h = candles.high(i),
            l = candles.low(i),
            c = candles.close(i)
        const vol = candles.volume(i),
            bv = candles.buyVolume(i),
            sv = candles.sellVolume(i)
        const p = (h + l + c) / 3
        if (vol > 0) {
            pv += p * vol
            v += vol
            p2v += p * p * vol
        }
        if (isFinite(bv)) buy += bv
        if (isFinite(sv)) sell += sv
        tp += p
        cnt++
    }
    const delta = buy - sell
    if (v <= 0) {
        if (cnt === 0)
            return {
                vwap: NaN,
                stdev: NaN,
                vol: 0,
                buyVol: buy,
                sellVol: sell,
                delta
            }
        const twap = tp / Math.max(1, cnt)
        let s2 = 0
        for (let i = 0; i < barCount(); i++) {
            const t = candles.unix(i)
            if (t < startSec) break
            if (t >= endSec) continue
            const p = (candles.high(i) + candles.low(i) + candles.close(i)) / 3
            const d = p - twap
            s2 += d * d
        }
        return {
            vwap: twap,
            stdev: Math.sqrt(Math.max(0, s2 / Math.max(1, cnt))),
            vol: 0,
            buyVol: buy,
            sellVol: sell,
            delta
        }
    }
    const vwap = pv / v,
        variance = Math.max(0, p2v / v - vwap * vwap)
    return {
        vwap,
        stdev: Math.sqrt(variance),
        vol: v,
        buyVol: buy,
        sellVol: sell,
        delta
    }
}

function prevInfoFor(code, k) {
    const out = [],
        curStart = startOfPeriodFor(code, candles.unix(0))
    let end = curStart
    for (let i = 0; i < k; i++) {
        const start = prevStartFor(code, end)
        const st = statsBetween(start, end)
        if (isNaN(st.vwap)) break
        out.push({
            period: code,
            start,
            end,
            vwap: st.vwap,
            stdev: st.stdev,
            vol: st.vol,
            buyVol: st.buyVol,
            sellVol: st.sellVol,
            delta: st.delta
        })
        end = start
    }
    return out
}
const prevCache = {}
function getPrevInfoCached(code, needN) {
    const curStart = startOfPeriodFor(code, candles.unix(0))
    const N = Math.max(1, needN | 0)
    const rec = prevCache[code]
    if (!rec || rec.curStart !== curStart || rec.N < N)
        prevCache[code] = { curStart, N, arr: prevInfoFor(code, N) }
    return prevCache[code].arr
}

// Sliding window state for rolling VWAPs — O(1) amortized per bar
const rvwapWindowState = {}
function calcRollingVWAP(days) {
    const windowSec = days * 24 * 3600
    const nowSec = candles.unix(0)
    const startSec = nowSec - windowSec
    if (!rvwapWindowState[days]) {
        rvwapWindowState[days] = {
            entries: [], startIdx: 0,
            sumPV: 0, sumV: 0, sumP2V: 0,
            lastSec: -1
        }
    }
    const w = rvwapWindowState[days]
    if (w.lastSec !== nowSec) {
        w.lastSec = nowSec
        const h = candles.high(0),
            l = candles.low(0),
            c = candles.close(0),
            vol = candles.volume(0)
        const p = (h + l + c) / 3
        const pv = vol > 0 ? p * vol : 0,
            v = vol > 0 ? vol : 0,
            p2v = vol > 0 ? p * p * vol : 0
        w.entries.push({ t: nowSec, pv, v, p2v })
        w.sumPV += pv; w.sumV += v; w.sumP2V += p2v
        // Expire bars outside the window
        while (w.startIdx < w.entries.length && w.entries[w.startIdx].t < startSec) {
            const old = w.entries[w.startIdx++]
            w.sumPV -= old.pv; w.sumV -= old.v; w.sumP2V -= old.p2v
        }
        // Compact to prevent unbounded array growth
        if (w.startIdx > 500) {
            w.entries = w.entries.slice(w.startIdx)
            w.startIdx = 0
        }
    }
    if (w.sumV <= 0) return { vwap: NaN, stdev: NaN }
    const vwap = w.sumPV / w.sumV
    const variance = Math.max(0, w.sumP2V / w.sumV - vwap * vwap)
    return { vwap, stdev: Math.sqrt(variance) }
}

/* ===== Formatting & helpers ===== */
function ymd(sec) {
    const d = new Date(sec * 1000)
    const y = d.getUTCFullYear(),
        m = String(d.getUTCMonth() + 1).padStart(2, "0"),
        da = String(d.getUTCDate()).padStart(2, "0")
    return `${y}-${m}-${da}`
}
function periodShort(code) {
    return code === "4H" ? "4h" : code.toLowerCase()
}
function nvColorByPeriod(p) {
    return p === "D"
        ? colD
        : p === "W"
            ? colW
            : p === "M"
                ? colM
                : p === "Q"
                    ? colQ
                    : colY
}
function nvAxisText(p, endSec) {
    return `NVWAP ${p} ${ymd(endSec)}`
}
function nvAxisTextStd(p, endSec, tag) {
    return `[${periodShort(p)}] ${tag} ${ymd(endSec)}`
}
function bodyHi(i) {
    return Math.max(candles.open(i), candles.close(i))
}
function bodyLo(i) {
    return Math.min(candles.open(i), candles.close(i))
}
function periodEnabledForNaked(code) {
    return (
        (code === "4H" && nkInc4H) ||
        (code === "D" && nkIncD) ||
        (code === "W" && nkIncW) ||
        (code === "M" && nkIncM) ||
        (code === "Q" && nkIncQ) ||
        (code === "Y" && nkIncY)
    )
}

/* ===== Naked NVWAP store ===== */
const NV = {}
const nvAxisSlotByKey = {}  // key → slot number (1-based) within its period type
const visibleKeysByType = {
    "4H": new Set(),
    "D": new Set(),
    "W": new Set(),
    "M": new Set(),
    "Q": new Set(),
    "Y": new Set()
}

function refreshUniverseNVWAP() {
    if (!showNakedVWAP) return
    const active = []
    if (nkInc4H) active.push("4H")
    if (nkIncD) active.push("D")
    if (nkIncW) active.push("W")
    if (nkIncM) active.push("M")
    if (nkIncQ) active.push("Q")
    if (nkIncY) active.push("Y")
    const needN = Math.max(nakedLookback, scoreWindowN, extendPrevCount)
    for (const code of active) {
        const info = getPrevInfoCached(code, needN)
        for (let j = 0; j < Math.min(nakedLookback, info.length); j++) {
            const pi = info[j]
            if (!isFinite(pi.vwap)) continue
            const key = `${code}@${pi.end}`
            if (!NV[key]) {
                NV[key] = {
                    period: code,
                    endSec: pi.end,
                    fromSec: pi.end,
                    level: pi.vwap,
                    stdev: pi.stdev,
                    touched: false,
                    touchSec: null,
                    lastCheckedSec: pi.end - 1,
                    std1UpTouched: false,
                    std1UpTouchSec: null,
                    std1LoTouched: false,
                    std1LoTouchSec: null,
                    std2UpTouched: false,
                    std2UpTouchSec: null,
                    std2LoTouched: false,
                    std2LoTouchSec: null,
                    line: null,
                    lineS1U: null,
                    lineS1L: null,
                    lineS2U: null,
                    lineS2L: null,
                    label: null,
                    scoreLabel: null,
                    compLabel: null,
                    dbgLabel: null,
                    std1UpLabel: null,
                    std1LoLabel: null,
                    std2UpLabel: null,
                    std2LoLabel: null,
                    axisId: null,
                    scoreVol: NaN,
                    scoreDeltaSigned: NaN,
                    compR: NaN,
                    vol: pi.vol,
                    delta: pi.delta,
                    buyVol: pi.buyVol,
                    sellVol: pi.sellVol
                }
            } else {
                NV[key].level = pi.vwap
                NV[key].stdev = pi.stdev
                NV[key].vol = pi.vol
                NV[key].delta = pi.delta
                NV[key].buyVol = pi.buyVol
                NV[key].sellVol = pi.sellVol
            }
        }
    }
}

/* === Naked touches (VWAP y Std independientes) === */
function nvTouchCheckOne(o) {
    if (o.touched) return
    const useBody = nakedTouchKind === "Body"
    const tol = Math.max(
        Math.abs(o.level) * (nakedTolBps / 10000.0),
        nakedTolAbs
    )
    let prevC = NaN,
        prevT = NaN
    for (let i = barCount() - 1; i >= 0; i--) {
        const t = candles.unix(i)
        if (t < o.fromSec) continue
        if (t <= o.lastCheckedSec) continue
        const hi = useBody ? bodyHi(i) : candles.high(i),
            lo = useBody ? bodyLo(i) : candles.low(i)
        if (hi >= o.level - tol && lo <= o.level + tol) {
            o.touched = true
            o.touchSec = t
            o.lastCheckedSec = t
            return
        }
        const c = candles.close(i)
        if (isFinite(prevC) && prevT >= o.fromSec) {
            const a = c - o.level,
                b = prevC - o.level
            if (
                a === 0 ||
                b === 0 ||
                a > 0 !== b > 0 ||
                (c > o.level + tol && prevC < o.level - tol) ||
                (c < o.level - tol && prevC > o.level + tol)
            ) {
                o.touched = true
                o.touchSec = prevT
                o.lastCheckedSec = t
                return
            }
        }
        prevC = c
        prevT = t
        o.lastCheckedSec = t
    }
}
function nvStdTouchCheckOne(o) {
    if (!isFinite(o.stdev)) return
    const useBody = nakedTouchKind === "Body"
    const tol = Math.max(
        Math.abs(o.level) * (nakedTolBps / 10000.0),
        nakedTolAbs
    )
    const std1Up = o.level + o.stdev * std1Mult,
        std1Lo = o.level - o.stdev * std1Mult
    if (!o.std1UpTouched)
        for (let i = barCount() - 1; i >= 0; i--) {
            const t = candles.unix(i)
            if (t < o.fromSec) continue
            const hi = useBody ? bodyHi(i) : candles.high(i),
                lo = useBody ? bodyLo(i) : candles.low(i)
            if (hi >= std1Up - tol && lo <= std1Up + tol) {
                o.std1UpTouched = true
                o.std1UpTouchSec = t
                break
            }
        }
    if (!o.std1LoTouched)
        for (let i = barCount() - 1; i >= 0; i--) {
            const t = candles.unix(i)
            if (t < o.fromSec) continue
            const hi = useBody ? bodyHi(i) : candles.high(i),
                lo = useBody ? bodyLo(i) : candles.low(i)
            if (hi >= std1Lo - tol && lo <= std1Lo + tol) {
                o.std1LoTouched = true
                o.std1LoTouchSec = t
                break
            }
        }
    if (showStd2) {
        const std2Up = o.level + o.stdev * std2Mult,
            std2Lo = o.level - o.stdev * std2Mult
        if (!o.std2UpTouched)
            for (let i = barCount() - 1; i >= 0; i--) {
                const t = candles.unix(i)
                if (t < o.fromSec) continue
                const hi = useBody ? bodyHi(i) : candles.high(i),
                    lo = useBody ? bodyLo(i) : candles.low(i)
                if (hi >= std2Up - tol && lo <= std2Up + tol) {
                    o.std2UpTouched = true
                    o.std2UpTouchSec = t
                    break
                }
            }
        if (!o.std2LoTouched)
            for (let i = barCount() - 1; i >= 0; i--) {
                const t = candles.unix(i)
                if (t < o.fromSec) continue
                const hi = useBody ? bodyHi(i) : candles.high(i),
                    lo = useBody ? bodyLo(i) : candles.low(i)
                if (hi >= std2Lo - tol && lo <= std2Lo + tol) {
                    o.std2LoTouched = true
                    o.std2LoTouchSec = t
                    break
                }
            }
    }
}

/* === Top-X sobre vivas === */
function selectVisibleNVWAPs(px) {
    const by = { "4H": [], "D": [], "W": [], "M": [], "Q": [], "Y": [] }
    for (const key in NV) {
        const o = NV[key]
        if (!periodEnabledForNaked(o.period)) continue
        if (o.touched) continue
        by[o.period].push({ key, dist: Math.abs(o.level - px) })
    }
    for (const p of ["4H", "D", "W", "M", "Q", "Y"]) {
        const bucket = by[p] || []
        const keep =
            nakedNearestPerType > 0
                ? bucket
                    .sort((a, b) => a.dist - b.dist)
                    .slice(0, nakedNearestPerType)
                : bucket
        const s = visibleKeysByType[p]
        s.clear()
        for (const it of keep) s.add(it.key)
    }
    // Assign per-type slot numbers (1 = closest to price) for fixed axis label pool
    for (const key in nvAxisSlotByKey) delete nvAxisSlotByKey[key]
    for (const p of ["4H", "D", "W", "M", "Q", "Y"]) {
        let slot = 0
        for (const key of visibleKeysByType[p]) nvAxisSlotByKey[key] = ++slot
    }
}

/* === scoring === */
function erf(x) {
    const a1 = 0.254829592,
        a2 = -0.284496736,
        a3 = 1.421413741,
        a4 = -1.453152027,
        a5 = 1.061405429,
        p = 0.3275911
    const sign = x < 0 ? -1 : 1
    x = Math.abs(x)
    const t = 1 / (1 + p * x)
    const y =
        1 -
        ((((a5 * t + a4) * t + a3) * t + a2) * t + a1) * t * Math.exp(-x * x)
    return sign * y
}
function cdf01(z) {
    return 0.5 * (1 + erf(z / Math.SQRT2))
}

// R usa Volumen y Delta con pesos nvCompWVol / nvCompWDelta (normalizados)
function computeScores() {
    const needVol = nvVolScoreEnable || nvCompositeEnable
    const needDelta = nvDeltaScoreEnable || nvCompositeEnable
    if (!needVol && !needDelta) return

    const types = ["4H", "D", "W", "M", "Q", "Y"]
    const mapVol = {},
        mapDelta = {},
        mapComp = {}
    const needN = Math.max(scoreWindowN, nakedLookback)

    for (const code of types) {
        if (!periodEnabledForNaked(code)) continue
        const arr = getPrevInfoCached(code, needN)
        if (arr.length < 2) continue

        let sV = 0,
            sV2 = 0,
            sD = 0,
            sD2 = 0
        const take = Math.min(needN, arr.length)
        for (let i = 0; i < take; i++) {
            const it = arr[i]
            sV += it.vol
            sV2 += it.vol * it.vol
            sD += it.delta
            sD2 += it.delta * it.delta
        }
        const n = take,
            mV = sV / n,
            sdV = Math.sqrt(Math.max(1e-12, sV2 / n - mV * mV))
        const mD = sD / n,
            sdD = Math.sqrt(Math.max(1e-12, sD2 / n - mD * mD))

        for (let i = 0; i < take; i++) {
            const it = arr[i],
                key = `${code}@${it.end}`
            if (needVol) {
                const zV = sdV > 0 ? (it.vol - mV) / sdV : 0
                let vScore = Math.round(cdf01(zV) * 100)
                vScore = Math.max(0, Math.min(100, vScore))
                mapVol[key] = vScore
            }
            if (needDelta) {
                const zD = sdD > 0 ? (it.delta - mD) / sdD : 0
                let s = Math.round(cdf01(zD) * 100)
                s = Math.max(0, Math.min(100, s))
                mapDelta[key] = it.delta >= 0 ? +s : -s
            }
            if (nvCompositeEnable) {
                const wv = Math.max(0, nvCompWVol),
                    wd = Math.max(0, nvCompWDelta),
                    denom = Math.max(1e-9, wv + wd)
                const vTerm = mapVol[key] !== undefined ? mapVol[key] : 50
                const dTerm =
                    mapDelta[key] !== undefined ? Math.abs(mapDelta[key]) : 50
                let R = Math.round((wv * vTerm + wd * dTerm) / denom)
                R = Math.max(0, Math.min(100, R))
                mapComp[key] = R
            }
        }
    }
    for (const key in NV) {
        if (mapVol[key] !== undefined) NV[key].scoreVol = mapVol[key]
        if (mapDelta[key] !== undefined)
            NV[key].scoreDeltaSigned = mapDelta[key]
        if (mapComp[key] !== undefined) NV[key].compR = mapComp[key]
    }
}

function fmtSigned(n) {
    return (n > 0 ? "+" : "") + Math.round(n).toString()
}
function fmtUnits(n) {
    if (nvDebugUnits === "Raw") return Math.round(n).toString()
    const abs = Math.abs(n)
    if (abs >= 1e9) return (n / 1e9).toFixed(2) + "B"
    if (abs >= 1e6) return (n / 1e6).toFixed(2) + "M"
    if (abs >= 1e3) return (n / 1e3).toFixed(2) + "K"
    return Math.round(n).toString()
}

function hidePlotLine(id) {
    plot(id, NaN, { showLabel: false, showValue: false, width: 1 })
}
function clearNVWAPVisuals(o, nowSec) {
    if (o.line)
        o.line.set({
            x1: nowSec,
            x2: nowSec,
            y1: NaN,
            y2: NaN,
            color: color.transp(nvColorByPeriod(o.period), 100),
            width: 0.0001
        })
    if (o.lineS1U) o.lineS1U.set({ x1: nowSec, x2: nowSec, y1: NaN, y2: NaN })
    if (o.lineS1L) o.lineS1L.set({ x1: nowSec, x2: nowSec, y1: NaN, y2: NaN })
    if (o.lineS2U) o.lineS2U.set({ x1: nowSec, x2: nowSec, y1: NaN, y2: NaN })
    if (o.lineS2L) o.lineS2L.set({ x1: nowSec, x2: nowSec, y1: NaN, y2: NaN })
    if (o.label) o.label.set({ text: "" })
    if (o.scoreLabel) o.scoreLabel.set({ text: "" })
    if (o.compLabel) o.compLabel.set({ text: "" })
    if (o.dbgLabel) o.dbgLabel.set({ text: "" })
    if (o.std1UpLabel) o.std1UpLabel.set({ text: "" })
    if (o.std1LoLabel) o.std1LoLabel.set({ text: "" })
    if (o.std2UpLabel) o.std2UpLabel.set({ text: "" })
    if (o.std2LoLabel) o.std2LoLabel.set({ text: "" })
    // Pool-based axis slots are cleared by drawNVWAPs pre-clear loop — no dynamic labels here
    if (o.axisId) { hidePlotLine(o.axisId); o.axisId = null }
}
function scoringTextFor(o) {
    const parts = []
    if (nvCompositeEnable && isFinite(o.compR)) parts.push(`R:${o.compR}`)
    if (
        nvCompositeEnable &&
        (nvCompositeDisplay === "R + V" ||
            nvCompositeDisplay === "R + V + Δ") &&
        isFinite(o.scoreVol)
    )
        parts.push(`V:${o.scoreVol}`)
    if (
        nvCompositeEnable &&
        nvCompositeDisplay === "R + V + Δ" &&
        isFinite(o.scoreDeltaSigned)
    ) {
        const s = Math.abs(o.scoreDeltaSigned) | 0,
            sign = o.scoreDeltaSigned >= 0 ? "+" : "-"
        parts.push(`Δ:${sign}${s}`)
    }
    if (nvVolScoreEnable && isFinite(o.scoreVol)) parts.push(`z:${o.scoreVol}`)
    return parts.join(" · ")
}
/* === Draw Naked === */
function drawNVWAPs(nowSec) {
    const onAxis = nvwLabelMode === "Axis label"
    const style =
        nakedLineStyle === "Solid" ? linestyle.solid : linestyle.dotted

    // Pre-clear fixed axis-label pool each bar (prevents stale labels when visible set changes)
    if (onAxis) {
        for (const p of ["4H", "D", "W", "M", "Q", "Y"])
            for (let s = 1; s <= nakedNearestPerType; s++)
                plot(`NV ${p} ${s}`, NaN, { showLabel: false, showValue: false })
    }

    for (const key in NV) {
        const o = NV[key]
        if (!periodEnabledForNaked(o.period)) {
            clearNVWAPVisuals(o, nowSec)
            continue
        }

        const isTopX = visibleKeysByType[o.period].has(key)
        const isDead = o.touched
        const hideDead = isDead && hideDeadNVWAPs

        // Si se pide ocultar muertos, no pintamos nada (tampoco R)
        if (hideDead) {
            clearNVWAPVisuals(o, nowSec)
            continue
        }

        const baseAlive = nvColorByPeriod(o.period)
        const baseDead = color.transp(baseAlive, 20)
        const baseCol = isDead ? baseDead : baseAlive

        const x1 = o.fromSec,
            x2 = isDead ? o.touchSec : nowSec
        const col = !isDead
            ? isTopX
                ? baseCol
                : color.transp(baseCol, nakedDimAlpha)
            : baseCol

        if (!o.line) {
            o.line = Line(key + "-line", {
                x1,
                y1: o.level,
                x2,
                y2: o.level,
                color: col,
                width: nakedWidth,
                style
            })
        } else {
            o.line.set({
                x1,
                y1: o.level,
                x2,
                y2: o.level,
                color: col,
                width: nakedWidth,
                style
            })
        }

        // Naked STD lines (independientes y con corte al tocar)
        if (showNakedStdBands && isFinite(o.stdev)) {
            const s1Up = o.level + o.stdev * std1Mult,
                s1Lo = o.level - o.stdev * std1Mult
            const s2Up = o.level + o.stdev * std2Mult,
                s2Lo = o.level - o.stdev * std2Mult
            const colS1 = color.transp(baseAlive, nakedStdAlpha)
            const colS2 = color.transp(baseAlive, Math.min(nakedStdAlpha + 10, 95))

            if (!o.std1UpTouched) {
                const x2s = nowSec
                if (!o.lineS1U)
                    o.lineS1U = Line(key + "-s1u", {
                        x1: o.fromSec,
                        y1: s1Up,
                        x2: x2s,
                        y2: s1Up,
                        color: colS1,
                        width: 0.6,
                        style: linestyle.dotted
                    })
                else
                    o.lineS1U.set({
                        x1: o.fromSec,
                        y1: s1Up,
                        x2: x2s,
                        y2: s1Up,
                        color: colS1,
                        width: 0.6,
                        style: linestyle.dotted
                    })
            } else if (o.lineS1U) {
                // Cortar al toque
                o.lineS1U.set({
                    x1: o.fromSec,
                    y1: s1Up,
                    x2: o.std1UpTouchSec,
                    y2: s1Up,
                    color: colS1,
                    width: 0.6,
                    style: linestyle.dotted
                })
            }

            if (!o.std1LoTouched) {
                const x2s = nowSec
                if (!o.lineS1L)
                    o.lineS1L = Line(key + "-s1l", {
                        x1: o.fromSec,
                        y1: s1Lo,
                        x2: x2s,
                        y2: s1Lo,
                        color: colS1,
                        width: 0.6,
                        style: linestyle.dotted
                    })
                else
                    o.lineS1L.set({
                        x1: o.fromSec,
                        y1: s1Lo,
                        x2: x2s,
                        y2: s1Lo,
                        color: colS1,
                        width: 0.6,
                        style: linestyle.dotted
                    })
            } else if (o.lineS1L) {
                o.lineS1L.set({
                    x1: o.fromSec,
                    y1: s1Lo,
                    x2: o.std1LoTouchSec,
                    y2: s1Lo,
                    color: colS1,
                    width: 0.6,
                    style: linestyle.dotted
                })
            }

            if (showStd2) {
                if (!o.std2UpTouched) {
                    const x2s = nowSec
                    if (!o.lineS2U)
                        o.lineS2U = Line(key + "-s2u", {
                            x1: o.fromSec,
                            y1: s2Up,
                            x2: x2s,
                            y2: s2Up,
                            color: colS2,
                            width: 0.6,
                            style: linestyle.dotted
                        })
                    else
                        o.lineS2U.set({
                            x1: o.fromSec,
                            y1: s2Up,
                            x2: x2s,
                            y2: s2Up,
                            color: colS2,
                            width: 0.6,
                            style: linestyle.dotted
                        })
                } else if (o.lineS2U) {
                    o.lineS2U.set({
                        x1: o.fromSec,
                        y1: s2Up,
                        x2: o.std2UpTouchSec,
                        y2: s2Up,
                        color: colS2,
                        width: 0.6,
                        style: linestyle.dotted
                    })
                }
                if (!o.std2LoTouched) {
                    const x2s = nowSec
                    if (!o.lineS2L)
                        o.lineS2L = Line(key + "-s2l", {
                            x1: o.fromSec,
                            y1: s2Lo,
                            x2: x2s,
                            y2: s2Lo,
                            color: colS2,
                            width: 0.6,
                            style: linestyle.dotted
                        })
                    else
                        o.lineS2L.set({
                            x1: o.fromSec,
                            y1: s2Lo,
                            x2: x2s,
                            y2: s2Lo,
                            color: colS2,
                            width: 0.6,
                            style: linestyle.dotted
                        })
                } else if (o.lineS2L) {
                    o.lineS2L.set({
                        x1: o.fromSec,
                        y1: s2Lo,
                        x2: o.std2LoTouchSec,
                        y2: s2Lo,
                        color: colS2,
                        width: 0.6,
                        style: linestyle.dotted
                    })
                }
            }

        }

        // Etiqueta NVWAP (axis o flotante para vivos)
        if (onAxis) {
            const axisSlot = nvAxisSlotByKey[key]
            if (isTopX && !isDead && axisSlot) {
                plot(`NV ${o.period} ${axisSlot}`, o.level, {
                    color: color.transp(baseAlive, 100),
                    width: 1,
                    style: linestyle.solid,
                    showLabel: true,
                    showValue: true
                })
                // Scoring via floating Label (pool slot name is fixed, can't embed score in it)
                if (nvAxisIncludeScoring) {
                    const scoreTxt = scoringTextFor(o)
                    if (scoreTxt.length) {
                        if (!o.label)
                            o.label = Label(key + "-lbl", {
                                x: nowSec,
                                y: o.level,
                                text: scoreTxt,
                                color: baseAlive,
                                size: scoringTextSize,
                                textAlign: text.align.right
                            })
                        else
                            o.label.set({
                                x: nowSec,
                                y: o.level,
                                text: scoreTxt,
                                color: baseAlive,
                                size: scoringTextSize,
                                textAlign: text.align.right
                            })
                    } else if (o.label) o.label.set({ text: "" })
                } else if (o.label) o.label.set({ text: "" })
            } else {
                if (o.label) o.label.set({ text: "" })
            }
        } else {
            if (!isDead) {
                const txt = nvAxisText(o.period, o.endSec)
                if (!o.label)
                    o.label = Label(key + "-lbl", {
                        x: nowSec,
                        y: o.level,
                        text: txt,
                        color: baseAlive,
                        size: scoringTextSize,
                        textAlign: text.align.right
                    })
                else
                    o.label.set({
                        x: nowSec,
                        y: o.level,
                        text: txt,
                        color: baseAlive,
                        size: scoringTextSize,
                        textAlign: text.align.right
                    })
            } else if (o.label) o.label.set({ text: "" })
        }

        // Debug opcional
        if (nvDebugEnable) {
            let dbg = ""
            const showV = nvDebugMetrics !== "Delta",
                showD = nvDebugMetrics !== "Volume"
            if (showV) dbg += `V:${fmtUnits(o.vol)}`
            if (showD) dbg += (dbg ? " · " : "") + `Δ:${fmtSigned(o.delta)}`
            const posX = isDead ? (o.fromSec + o.touchSec) / 2 : nowSec
            const colDbg =
                o.delta > 0 ? "#6ECF7A" : o.delta < 0 ? "#E36E6E" : baseAlive
            if (!o.dbgLabel)
                o.dbgLabel = Label(key + "-dbg", {
                    x: posX,
                    y: o.level,
                    text: dbg,
                    color: colDbg,
                    size: 11,
                    textAlign: isDead ? text.align.center : text.align.right
                })
            else
                o.dbgLabel.set({
                    x: posX,
                    y: o.level,
                    text: dbg,
                    color: colDbg,
                    textAlign: isDead ? text.align.center : text.align.right
                })
        } else if (o.dbgLabel) o.dbgLabel.set({ text: "" })

        // Mostrar R para NVWAPs muertos solo si NO estamos ocultando muertos
        if (isDead && !hideDeadNVWAPs) {
            if (nvCompositeEnable && isFinite(o.compR)) {
                const posX = (o.fromSec + o.touchSec) / 2
                const compColor =
                    nvCompositeColorByDelta && isFinite(o.scoreDeltaSigned)
                        ? o.scoreDeltaSigned >= 0
                            ? "#6ECF7A"
                            : "#E36E6E"
                        : baseAlive
                const txt = `R:${o.compR}`
                if (!o.compLabel) {
                    o.compLabel = Label(key + "-comp", {
                        x: posX,
                        y: o.level,
                        text: txt,
                        color: compColor,
                        size: scoringTextSize,
                        textAlign: text.align.center
                    })
                } else {
                    o.compLabel.set({
                        x: posX,
                        y: o.level,
                        text: txt,
                        color: compColor,
                        size: scoringTextSize,
                        textAlign: text.align.center
                    })
                }
            } else if (o.compLabel) {
                o.compLabel.set({ text: "" })
            }
        } else {
            // En vivos (o si se ocultan muertos) no duplicamos el score flotante
            if (o.compLabel) o.compLabel.set({ text: "" })
        }
    }
}

/* === VWAPs de periodo === */
function drawPeriodVWAP(code, nowSec) {
    const lbl = getPeriodLabel(code)
    const { vwap, stdev } = calcVWAPForPeriod(code)
    if (isNaN(vwap)) return

    const boundary =
        cutOnReset &&
        startOfPeriodFor(code, candles.unix(0)) !==
        startOfPeriodFor(code, candles.unix(1))
    const hideNormal = showNakedVWAP && nakedOnlyMode
    if (hideNormal) {
        hidePlotLine(lbl)
        hidePlotLine(`${lbl} Std1+`)
        hidePlotLine(`${lbl} Std1-`)
        hidePlotLine(`${lbl} Std2+`)
        hidePlotLine(`${lbl} Std2-`)
        hidePlotLine(`${lbl} Std3+`)
        hidePlotLine(`${lbl} Std3-`)
        return
    }

    const vw = boundary ? NaN : vwap
    const up1 = boundary ? NaN : vwap + stdev * std1Mult,
        lo1 = boundary ? NaN : vwap - stdev * std1Mult
    const up2 = boundary ? NaN : vwap + stdev * std2Mult,
        lo2 = boundary ? NaN : vwap - stdev * std2Mult
    const up3 = boundary ? NaN : vwap + stdev * std3Mult,
        lo3 = boundary ? NaN : vwap - stdev * std3Mult

    const col = getPeriodColor(code),
        wid = getPeriodWidth(code)
    plot(lbl, vw, {
        color: col,
        width: wid,
        showLabel: true,
        showValue: true
    })

    if (!periodStdEnabledFor(code)) {
        hidePlotLine(`${lbl} Std1+`)
        hidePlotLine(`${lbl} Std1-`)
        hidePlotLine(`${lbl} Std2+`)
        hidePlotLine(`${lbl} Std2-`)
        hidePlotLine(`${lbl} Std3+`)
        hidePlotLine(`${lbl} Std3-`)
        return
    }

    let u1, l1, u2, l2, u3, l3
    const canFillThisPeriod = periodStdFillEnabledFor(code)

    if (showStd1) {
        u1 = plot(`${lbl} Std1+`, up1, {
            color: std1Color,
            width: 1,
            style: linestyle.dashed,
            showLabel: showStdLabels
        })
        l1 = plot(`${lbl} Std1-`, lo1, {
            color: std1Color,
            width: 1,
            style: linestyle.dashed,
            showLabel: showStdLabels
        })
        if (!boundary && fillStd1Current && canFillThisPeriod)
            fill(u1, l1, { color: color.transp(std1Color, fillAlphaCurrent) })
    } else {
        hidePlotLine(`${lbl} Std1+`)
        hidePlotLine(`${lbl} Std1-`)
    }

    if (showStd2) {
        u2 = plot(`${lbl} Std2+`, up2, {
            color: std2Color,
            width: 1,
            style: linestyle.dashed,
            showLabel: showStdLabels
        })
        l2 = plot(`${lbl} Std2-`, lo2, {
            color: std2Color,
            width: 1,
            style: linestyle.dashed,
            showLabel: showStdLabels
        })
        if (!boundary && fillStd2Current && canFillThisPeriod) {
            if (showStd1 && u1 && l1) {
                fill(u2, u1, { color: color.transp(std2Color, fillAlphaCurrent) })
                fill(l1, l2, { color: color.transp(std2Color, fillAlphaCurrent) })
            } else {
                fill(u2, l2, { color: color.transp(std2Color, fillAlphaCurrent) })
            }
        }
    } else {
        hidePlotLine(`${lbl} Std2+`)
        hidePlotLine(`${lbl} Std2-`)
    }

    if (showStd3) {
        u3 = plot(`${lbl} Std3+`, up3, {
            color: std3Color,
            width: 1,
            style: linestyle.dotted,
            showLabel: showStdLabels
        })
        l3 = plot(`${lbl} Std3-`, lo3, {
            color: std3Color,
            width: 1,
            style: linestyle.dotted,
            showLabel: showStdLabels
        })
        if (!boundary && fillStd3Current && canFillThisPeriod)
            fill(u3, l3, { color: color.transp(std3Color, fillAlphaCurrent) })
    } else {
        hidePlotLine(`${lbl} Std3+`)
        hidePlotLine(`${lbl} Std3-`)
    }
}

/* === Proyecciones de periodos pasados === */
function drawPeriodProjections(code, nowSec) {
    if (!isPeriodProjectionEnabled(code)) return
    const needN = Math.max(extendPrevCount, nakedLookback, scoreWindowN)
    const prevInfo = getPrevInfoCached(code, needN)
    const prevMain = prevInfo.slice(
        0,
        Math.min(extendPrevCount, prevInfo.length)
    )

    const barSec = Math.max(candles.unix(0) - candles.unix(1), 1),
        capSec = projSkipBarsAtStart * barSec
    const force = showNakedVWAP && nakedOnlyMode
    const useVWAP = force ? true : extendPrevVWAP
    const useS1 = force
        ? onlyNakedProjMode !== "VWAP only"
        : extendPrevStd1 && periodStdEnabledFor(code)
    const useS2 = force
        ? onlyNakedProjMode === "VWAP + Std1 + Std2"
        : extendPrevStd2 && periodStdEnabledFor(code)
    const canFillThisPeriod = periodStdFillEnabledFor(code)

    for (let i = 0; i < prevMain.length; i++) {
        const p = prevMain[i],
            afterCap = nowSec > p.end + capSec
        const lineAlpha = Math.min(70 + i * ageExtraAlpha, 97),
            baseCol = color.transp(extendColorBase, lineAlpha)

        if (useVWAP)
            plot(`Prev ${code} VWAP P-${i + 1}`, !afterCap ? NaN : p.vwap, {
                color: baseCol,
                width: extendWidth,
                style: linestyle.dashed
            })

        let us1, ls1, us2, ls2
        if (useS1) {
            const up = !afterCap ? NaN : p.vwap + p.stdev * std1Mult
            const lo = !afterCap ? NaN : p.vwap - p.stdev * std1Mult
            const c = color.transp(std1Color, lineAlpha)
            us1 = plot(`Prev ${code} Std1+ P-${i + 1}`, up, {
                color: c,
                width: 1,
                style: linestyle.dashed
            })
            ls1 = plot(`Prev ${code} Std1- P-${i + 1}`, lo, {
                color: c,
                width: 1,
                style: linestyle.dashed
            })
            if (afterCap && fillPrevStd1 && canFillThisPeriod)
                fill(us1, ls1, {
                    color: color.transp(
                        std1Color,
                        Math.min(fillAlphaProj + i * ageExtraAlpha, 98)
                    )
                })
        }
        if (useS2) {
            const up = !afterCap ? NaN : p.vwap + p.stdev * std2Mult
            const lo = !afterCap ? NaN : p.vwap - p.stdev * std2Mult
            const c = color.transp(std2Color, lineAlpha)
            us2 = plot(`Prev ${code} Std2+ P-${i + 1}`, up, {
                color: c,
                width: 1,
                style: linestyle.dashed
            })
            ls2 = plot(`Prev ${code} Std2- P-${i + 1}`, lo, {
                color: c,
                width: 1,
                style: linestyle.dashed
            })
            if (afterCap && fillPrevStd2 && canFillThisPeriod) {
                const colFill = color.transp(
                    std2Color,
                    Math.min(fillAlphaProj + i * ageExtraAlpha, 98)
                )
                if (useS1 && us1 && ls1) {
                    fill(us2, us1, { color: colFill })
                    fill(ls1, ls2, { color: colFill })
                } else {
                    fill(us2, ls2, { color: colFill })
                }
            }
        }
    }
}

/* === Orquestación === */
function onBar() {
    const nowSec = candles.unix(0)
    const periods = ["4H", "D", "W", "M", "Q", "Y"]
    for (const code of periods) {
        if (isPeriodEnabled(code)) {
            drawPeriodVWAP(code, nowSec)
            drawPeriodProjections(code, nowSec)
        }
    }

    if (rvwap7dEnable) {
        const rv7 = calcRollingVWAP(rvwap7dDays)
        const name7 = `RVWAP ${rvwap7dDays}D`
        if (!isNaN(rv7.vwap)) {
            plot(name7, rv7.vwap, {
                color: rvwap7dColor,
                width: rvwap7dWidth,
                showLabel: true,
                showValue: true
            })
            let r7u1, r7l1, r7u2, r7l2
            if (rvwap7dStd1Enable) {
                r7u1 = plot(
                    `${name7} Std1+`,
                    rv7.vwap + rv7.stdev * rvwap7dStd1Mult,
                    {
                        color: rvwap7dStd1Color,
                        width: 1,
                        style: linestyle.dashed,
                        showLabel: showStdLabels
                    }
                )
                r7l1 = plot(
                    `${name7} Std1-`,
                    rv7.vwap - rv7.stdev * rvwap7dStd1Mult,
                    {
                        color: rvwap7dStd1Color,
                        width: 1,
                        style: linestyle.dashed,
                        showLabel: showStdLabels
                    }
                )
                if (rvwap7dFillStd1)
                    fill(r7u1, r7l1, {
                        color: color.transp(rvwap7dStd1Color, rvwap7dFillAlpha)
                    })
            }
            if (rvwap7dStd2Enable) {
                r7u2 = plot(
                    `${name7} Std2+`,
                    rv7.vwap + rv7.stdev * rvwap7dStd2Mult,
                    {
                        color: rvwap7dStd2Color,
                        width: 1,
                        style: linestyle.dashed,
                        showLabel: showStdLabels
                    }
                )
                r7l2 = plot(
                    `${name7} Std2-`,
                    rv7.vwap - rv7.stdev * rvwap7dStd2Mult,
                    {
                        color: rvwap7dStd2Color,
                        width: 1,
                        style: linestyle.dashed,
                        showLabel: showStdLabels
                    }
                )
                if (rvwap7dFillStd2) {
                    if (rvwap7dStd1Enable && r7u1 && r7l1) {
                        fill(r7u2, r7u1, {
                            color: color.transp(rvwap7dStd2Color, rvwap7dFillAlpha)
                        })
                        fill(r7l1, r7l2, {
                            color: color.transp(rvwap7dStd2Color, rvwap7dFillAlpha)
                        })
                    } else {
                        fill(r7u2, r7l2, {
                            color: color.transp(rvwap7dStd2Color, rvwap7dFillAlpha)
                        })
                    }
                }
            }
        }
    }

    if (rvwap30dEnable) {
        const rv30 = calcRollingVWAP(rvwap30dDays)
        const name30 = `RVWAP ${rvwap30dDays}D`
        if (!isNaN(rv30.vwap)) {
            plot(name30, rv30.vwap, {
                color: rvwap30dColor,
                width: rvwap30dWidth,
                showLabel: true,
                showValue: true
            })
            let r30u1, r30l1, r30u2, r30l2
            if (rvwap30dStd1Enable) {
                r30u1 = plot(
                    `${name30} Std1+`,
                    rv30.vwap + rv30.stdev * rvwap30dStd1Mult,
                    {
                        color: rvwap30dStd1Color,
                        width: 1,
                        style: linestyle.dashed,
                        showLabel: showStdLabels
                    }
                )
                r30l1 = plot(
                    `${name30} Std1-`,
                    rv30.vwap - rv30.stdev * rvwap30dStd1Mult,
                    {
                        color: rvwap30dStd1Color,
                        width: 1,
                        style: linestyle.dashed,
                        showLabel: showStdLabels
                    }
                )
                if (rvwap30dFillStd1)
                    fill(r30u1, r30l1, {
                        color: color.transp(rvwap30dStd1Color, rvwap30dFillAlpha)
                    })
            }
            if (rvwap30dStd2Enable) {
                r30u2 = plot(
                    `${name30} Std2+`,
                    rv30.vwap + rv30.stdev * rvwap30dStd2Mult,
                    {
                        color: rvwap30dStd2Color,
                        width: 1,
                        style: linestyle.dashed,
                        showLabel: showStdLabels
                    }
                )
                r30l2 = plot(
                    `${name30} Std2-`,
                    rv30.vwap - rv30.stdev * rvwap30dStd2Mult,
                    {
                        color: rvwap30dStd2Color,
                        width: 1,
                        style: linestyle.dashed,
                        showLabel: showStdLabels
                    }
                )
                if (rvwap30dFillStd2) {
                    if (rvwap30dStd1Enable && r30u1 && r30l1) {
                        fill(r30u2, r30u1, {
                            color: color.transp(rvwap30dStd2Color, rvwap30dFillAlpha)
                        })
                        fill(r30l1, r30l2, {
                            color: color.transp(rvwap30dStd2Color, rvwap30dFillAlpha)
                        })
                    } else {
                        fill(r30u2, r30l2, {
                            color: color.transp(rvwap30dStd2Color, rvwap30dFillAlpha)
                        })
                    }
                }
            }
        }
    }

    if (rvwap90dEnable) {
        const rv90 = calcRollingVWAP(rvwap90dDays)
        const name90 = `RVWAP ${rvwap90dDays}D`
        if (!isNaN(rv90.vwap)) {
            plot(name90, rv90.vwap, {
                color: rvwap90dColor,
                width: rvwap90dWidth,
                showLabel: true,
                showValue: true
            })
            let r90u1, r90l1, r90u2, r90l2
            if (rvwap90dStd1Enable) {
                r90u1 = plot(
                    `${name90} Std1+`,
                    rv90.vwap + rv90.stdev * rvwap90dStd1Mult,
                    {
                        color: rvwap90dStd1Color,
                        width: 1,
                        style: linestyle.dashed,
                        showLabel: showStdLabels
                    }
                )
                r90l1 = plot(
                    `${name90} Std1-`,
                    rv90.vwap - rv90.stdev * rvwap90dStd1Mult,
                    {
                        color: rvwap90dStd1Color,
                        width: 1,
                        style: linestyle.dashed,
                        showLabel: showStdLabels
                    }
                )
                if (rvwap90dFillStd1)
                    fill(r90u1, r90l1, {
                        color: color.transp(rvwap90dStd1Color, rvwap90dFillAlpha)
                    })
            }
            if (rvwap90dStd2Enable) {
                r90u2 = plot(
                    `${name90} Std2+`,
                    rv90.vwap + rv90.stdev * rvwap90dStd2Mult,
                    {
                        color: rvwap90dStd2Color,
                        width: 1,
                        style: linestyle.dashed,
                        showLabel: showStdLabels
                    }
                )
                r90l2 = plot(
                    `${name90} Std2-`,
                    rv90.vwap - rv90.stdev * rvwap90dStd2Mult,
                    {
                        color: rvwap90dStd2Color,
                        width: 1,
                        style: linestyle.dashed,
                        showLabel: showStdLabels
                    }
                )
                if (rvwap90dFillStd2) {
                    if (rvwap90dStd1Enable && r90u1 && r90l1) {
                        fill(r90u2, r90u1, {
                            color: color.transp(rvwap90dStd2Color, rvwap90dFillAlpha)
                        })
                        fill(r90l1, r90l2, {
                            color: color.transp(rvwap90dStd2Color, rvwap90dFillAlpha)
                        })
                    } else {
                        fill(r90u2, r90l2, {
                            color: color.transp(rvwap90dStd2Color, rvwap90dFillAlpha)
                        })
                    }
                }
            }
        }
    }

    if (showNakedVWAP) {
        refreshUniverseNVWAP()
        for (const key in NV) nvTouchCheckOne(NV[key])
        if (showNakedStdBands) for (const key in NV) nvStdTouchCheckOne(NV[key])
        selectVisibleNVWAPs(candles.close(0))
        if (nvVolScoreEnable || nvDeltaScoreEnable || nvCompositeEnable)
            computeScores()
        drawNVWAPs(candles.unix(0))
    }
}
