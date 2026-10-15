script "VWAP Suite"

// ============================================================================
// VWAP Suite v3.2 · PeByte · MMT Scripting v3
//
// Periodic VWAPs (4H/D/W/M/Q/Y) + σ bands · Projections of closed periods
// Intraday session VWAPs · σ bands + fills on every VWAP family
// Peak/Trough AVWAPs (D/W/M, current & previous) · Custom-date AVWAP
// Rolling VWAPs (days, auto-bucketed) · Naked VWAPs with volume score
// HUD dashboard (distance % and σ) · Alerts (cross / σ extension / naked)
//
// Performance notes:
// - One shared price source (HLC3 by default) for every VWAP family.
// - Accumulators are pure records stepped once per update (no duplication).
// - Naked VWAP entities are written only on state transitions (create /
//   touch), never per bar; alive lines use extend.right. Int keys only.
// - Rolling VWAPs use O(1) running sums over time buckets, so 90D works on
//   1m charts without hitting window limits.
// - HUD is drawn only at the live edge.
// ============================================================================

// Bars are evaluated from (visible range - warm-up); the default 750 bars
// often starts mid-month, so ask for more
data chart = subscribe(data.ohlcv, history: 3000)

input (
  // ==========================================================================
  // TAB 1 · GENERAL
  // ==========================================================================
  input.tab(title: "General")
  input.group(title: "Preset")
  pre           = input.select("Custom", title: "Layout  (overrides periodic · naked types · rolling R1)", options: ["Custom", "Daily", "Weekly", "Monthly", "Q-Yearly"])
  preStd2       = input.bool(false, title: "±2σ in preset", when: pre != "Custom")
  preKeep       = input.bool(false, title: "Keep my session / high-low AVWAPs in preset", when: pre != "Custom")
  input.group(title: "Calculation")
  srcMode       = input.select("HLC3", title: "Price source", options: ["HLC3", "OHLC4", "HL2", "Close"])
  cutOnReset    = input.bool(true, title: "Hide jump at period change")

  input.group(title: "Shared σ levels  (show · mult. · color · fill)", collapsible: true)
  showStd1      = input.bool(true, title: "±1σ")
  std1Mult      = input.float(1.0, title: "", min: 0.1, max: 5.0, sameLine: true)
  std1Color     = input.color(color.rgb(107, 139, 185), title: "", sameLine: true)
  fmodeStd1    = input.select("Fill", title: "", options: ["No fill", "Fill"], sameLine: true)

  uShowStd2      = input.bool(false, title: "±2σ")
  std2Mult      = input.float(2.0, title: "", min: 0.1, max: 5.0, sameLine: true)
  std2Color     = input.color(color.rgb(176, 132, 204), title: "", sameLine: true)
  fmodeStd2    = input.select("No fill", title: "", options: ["No fill", "Fill"], sameLine: true)

  uShowStd3      = input.bool(false, title: "±3σ (periodic only)")
  std3Mult      = input.float(3.0, title: "", min: 0.1, max: 5.0, sameLine: true)
  std3Color     = input.color(color.rgb(102, 175, 161), title: "", sameLine: true)
  fmodeStd3    = input.select("No fill", title: "", options: ["No fill", "Fill"], sameLine: true)

  fillOpacity   = input.int(18, title: "Fill opacity %", min: 0, max: 100)

  input.group(title: "HUD (distance to VWAPs)")
  showHud       = input.bool(true, title: "Show HUD")
  hudPos        = input.select("Bottom right", title: "Position", options: ["Top right", "Top left", "Bottom right", "Bottom left"], when: showHud)
  hudSize       = input.float(11.0, title: "Size", min: 8.0, max: 18.0, when: showHud)

  input.group(title: "Alerts", collapsible: true, collapsed: true)
  alertPeriod   = input.select("Daily", title: "Reference VWAP", options: ["4H", "Daily", "Weekly", "Monthly", "Quarterly", "Yearly"])
  alertSigma    = input.select("2σ", title: "Band extension", options: ["1σ", "2σ", "3σ"], sameLine: true)

  // ==========================================================================
  // TAB 2 · VWAPs PERIÓDICOS
  // ==========================================================================
  input.tab(title: "Periodic")
  input.group(title: "Periods  (enable · color · width · bands · projection)")
  uShow4H        = input.bool(false, title: "4H")
  color4H       = input.color(color.rgb(168, 181, 209), title: "", sameLine: true)
  width4H       = input.float(1.5, title: "", min: 0.5, max: 5.0, sameLine: true)
  mode4H = input.select("No σ", title: "", options: ["No σ", "σ", "σ + fill"], sameLine: true)
  uPmode4H = input.select("No projection", title: "", options: ["No projection", "Project"], sameLine: true)

  uShowDaily     = input.bool(true, title: "Daily")
  colorDaily    = input.color(color.rgb(227, 179, 65), title: "", sameLine: true)
  widthDaily    = input.float(2.0, title: "", min: 0.5, max: 5.0, sameLine: true)
  uModeDaily = input.select("σ + fill", title: "", options: ["No σ", "σ", "σ + fill"], sameLine: true)
  uPmodeDaily = input.select("No projection", title: "", options: ["No projection", "Project"], sameLine: true)

  uShowWeekly    = input.bool(true, title: "Weekly")
  colorWeekly   = input.color(color.rgb(110, 207, 122), title: "", sameLine: true)
  widthWeekly   = input.float(2.0, title: "", min: 0.5, max: 5.0, sameLine: true)
  uModeWeekly = input.select("No σ", title: "", options: ["No σ", "σ", "σ + fill"], sameLine: true)
  uPmodeWeekly = input.select("Project", title: "", options: ["No projection", "Project"], sameLine: true)

  uShowMonthly   = input.bool(false, title: "Monthly")
  colorMonthly  = input.color(color.rgb(78, 205, 196), title: "", sameLine: true)
  widthMonthly  = input.float(2.5, title: "", min: 0.5, max: 5.0, sameLine: true)
  uModeMonthly = input.select("No σ", title: "", options: ["No σ", "σ", "σ + fill"], sameLine: true)
  uPmodeMonthly = input.select("No projection", title: "", options: ["No projection", "Project"], sameLine: true)

  uShowQuarterly = input.bool(false, title: "Quarterly")
  colorQuarterly = input.color(color.rgb(176, 132, 204), title: "", sameLine: true)
  widthQuarterly = input.float(2.5, title: "", min: 0.5, max: 5.0, sameLine: true)
  uModeQuarterly = input.select("No σ", title: "", options: ["No σ", "σ", "σ + fill"], sameLine: true)
  uPmodeQuarterly = input.select("No projection", title: "", options: ["No projection", "Project"], sameLine: true)

  uShowYearly    = input.bool(false, title: "Yearly")
  colorYearly   = input.color(color.rgb(227, 110, 110), title: "", sameLine: true)
  widthYearly   = input.float(3.0, title: "", min: 0.5, max: 5.0, sameLine: true)
  uModeYearly = input.select("No σ", title: "", options: ["No σ", "σ", "σ + fill"], sameLine: true)
  uPmodeYearly = input.select("No projection", title: "", options: ["No projection", "Project"], sameLine: true)

  input.group(title: "Closed-period projections  (σ and fill follow each VWAP)", collapsible: true)
  projCount     = input.int(1, title: "Periods back", min: 1, max: 10)
  projHistory   = input.bool(true, title: "Show in history")
  projWidth     = input.float(1.0, title: "Width · color", min: 0.5, max: 4.0)
  projColor     = input.color(color.rgb(139, 144, 168), title: "", sameLine: true)

  // ==========================================================================
  // TAB 3 · SESIONES (horas UTC)
  // ==========================================================================
  input.tab(title: "Sessions")
  input.group(title: "Sessions  (enable · color · start · end UTC · bands)")
  uShowSessAsia   = input.bool(false, title: "Asia")
  colSessAsia    = input.color(color.rgb(255, 183, 77), title: "", sameLine: true)
  asiaStart      = input.float(0.0, title: "", min: 0.0, max: 24.0, sameLine: true)
  asiaEnd        = input.float(8.0, title: "", min: 0.0, max: 24.0, sameLine: true)
  modeAsia = input.select("No σ", title: "", options: ["No σ", "σ", "σ + fill"], sameLine: true)

  uShowSessLondon = input.bool(false, title: "London")
  colSessLondon  = input.color(color.rgb(79, 195, 247), title: "", sameLine: true)
  londonStart    = input.float(7.0, title: "", min: 0.0, max: 24.0, sameLine: true)
  londonEnd      = input.float(15.5, title: "", min: 0.0, max: 24.0, sameLine: true)
  modeLondon = input.select("No σ", title: "", options: ["No σ", "σ", "σ + fill"], sameLine: true)

  uShowSessNY     = input.bool(false, title: "New York")
  colSessNY      = input.color(color.rgb(186, 104, 200), title: "", sameLine: true)
  nyStart        = input.float(13.5, title: "", min: 0.0, max: 24.0, sameLine: true)
  nyEnd          = input.float(20.0, title: "", min: 0.0, max: 24.0, sameLine: true)
  modeNY = input.select("No σ", title: "", options: ["No σ", "σ", "σ + fill"], sameLine: true)

  uShowSessClose  = input.bool(false, title: "NY Close")
  colSessClose   = input.color(color.rgb(255, 138, 101), title: "", sameLine: true)
  closeStart     = input.float(20.0, title: "", min: 0.0, max: 24.0, sameLine: true)
  closeEnd       = input.float(24.0, title: "", min: 0.0, max: 24.0, sameLine: true)
  modeClose = input.select("No σ", title: "", options: ["No σ", "σ", "σ + fill"], sameLine: true)

  input.group(title: "Style")
  sessWidth      = input.float(1.5, title: "Width", min: 0.5, max: 5.0)
  extendSessVWAP = input.bool(true, title: "Extend previous session")

  // ==========================================================================
  // TAB 4 · ANCHORED VWAPs
  // ==========================================================================
  input.tab(title: "Anchored")
  input.group(title: "Peak / Trough  (enable · high color · low color · bands)")
  uEnableMonthAvwap     = input.bool(true, title: "Current month")
  colMonthHigh         = input.color(color.rgb(239, 83, 80), title: "", sameLine: true)
  colMonthLow          = input.color(color.rgb(102, 187, 106), title: "", sameLine: true)
  modeMonth = input.select("No σ", title: "", options: ["No σ", "σ", "σ + fill"], sameLine: true)
  uEnablePrevMonthAvwap = input.bool(true, title: "Previous month")
  colPrevMonthHigh     = input.color(color.rgb(255, 138, 128), title: "", sameLine: true)
  colPrevMonthLow      = input.color(color.rgb(185, 246, 202), title: "", sameLine: true)
  modePrevMonth = input.select("No σ", title: "", options: ["No σ", "σ", "σ + fill"], sameLine: true)

  uEnableWeekAvwap      = input.bool(false, title: "Current week")
  colWeekHigh          = input.color(color.rgb(244, 143, 177), title: "", sameLine: true)
  colWeekLow           = input.color(color.rgb(128, 203, 196), title: "", sameLine: true)
  modeWeek = input.select("No σ", title: "", options: ["No σ", "σ", "σ + fill"], sameLine: true)
  uEnablePrevWeekAvwap  = input.bool(false, title: "Previous week")
  colPrevWeekHigh      = input.color(color.rgb(248, 187, 208), title: "", sameLine: true)
  colPrevWeekLow       = input.color(color.rgb(178, 223, 219), title: "", sameLine: true)
  modePrevWeek = input.select("No σ", title: "", options: ["No σ", "σ", "σ + fill"], sameLine: true)

  uEnableDayAvwap       = input.bool(false, title: "Current day")
  colDayHigh           = input.color(color.rgb(255, 202, 40), title: "", sameLine: true)
  colDayLow            = input.color(color.rgb(141, 110, 99), title: "", sameLine: true)
  modeDay = input.select("No σ", title: "", options: ["No σ", "σ", "σ + fill"], sameLine: true)
  uEnablePrevDayAvwap   = input.bool(false, title: "Previous day")
  colPrevDayHigh       = input.color(color.rgb(255, 224, 130), title: "", sameLine: true)
  colPrevDayLow        = input.color(color.rgb(188, 170, 164), title: "", sameLine: true)
  modePrevDay = input.select("No σ", title: "", options: ["No σ", "σ", "σ + fill"], sameLine: true)

  input.group(title: "Options")
  ptPrevMode           = input.select("Until touched", title: "Previous AVWAP lives", options: ["Until touched", "Until new period"])
  ptHideOld            = input.bool(true, title: "Hide superseded high/low AVWAPs")
  ptPivotMode          = input.select("Wick (high / low)", title: "High / low detected by", options: ["Wick (high / low)", "Close"])

  input.group(title: "Date-anchored AVWAP (UTC)")
  enableCustomAvwap    = input.bool(false, title: "Enable")
  colCustomAvwap       = input.color(color.rgb(255, 215, 0), title: "", sameLine: true)
  customYear           = input.int(2026, title: "Year · month · day · hour", min: 2009, max: 2100, when: enableCustomAvwap)
  customMonth          = input.int(1, title: "Month", min: 1, max: 12, sameLine: true, when: enableCustomAvwap)
  customDay            = input.int(1, title: "Day", min: 1, max: 31, sameLine: true, when: enableCustomAvwap)
  customHour           = input.int(0, title: "Hour", min: 0, max: 23, sameLine: true, when: enableCustomAvwap)
  modeCustom           = input.select("No σ", title: "Bands", options: ["No σ", "σ", "σ + fill"], when: enableCustomAvwap)

  // ==========================================================================
  // TAB 5 · NAKED VWAPs
  // ==========================================================================
  input.tab(title: "Naked")
  input.group(title: "Detection")
  uShowNaked     = input.bool(true, title: "Enable Naked VWAPs")
  uNakedOnlyMode = input.bool(false, title: "Naked only (hide live VWAPs)", when: uShowNaked)
  uNk4H          = input.bool(false, title: "4H", when: uShowNaked)
  uNkD           = input.bool(true, title: "D", when: uShowNaked)
  uNkW           = input.bool(true, title: "W", when: uShowNaked)
  uNkM           = input.bool(true, title: "M", when: uShowNaked)
  uNkQ           = input.bool(false, title: "Q", when: uShowNaked)
  uNkY           = input.bool(false, title: "Y", when: uShowNaked)
  uNkAsia        = input.bool(false, title: "Asia session", when: uShowNaked)
  uNkLondon      = input.bool(false, title: "London session", when: uShowNaked)
  uNkNY          = input.bool(false, title: "New York session", when: uShowNaked)
  uNkClose       = input.bool(false, title: "NY Close session", when: uShowNaked)
  uNkAnchM       = input.bool(false, title: "Month high/low AVWAP", when: uShowNaked)
  uNkAnchW       = input.bool(false, title: "Week high/low AVWAP", when: uShowNaked)
  uNkAnchD       = input.bool(false, title: "Day high/low AVWAP", when: uShowNaked)
  nkSessMode    = input.select("Any touch", title: "Session nakeds invalidated by", options: ["Any touch", "Same session only"], when: uShowNaked)
  nakedTouch    = input.select("Wick", title: "Touch by", options: ["Wick", "Body"], when: uShowNaked)
  nakedTolBps   = input.float(2.0, title: "Tolerance (bps)", min: 0.0, max: 50.0, when: uShowNaked)
  nvMax         = input.int(60, title: "Max levels", min: 10, max: 200, when: uShowNaked)
  nvShowTouched = input.bool(true, title: "Show touched nakeds (birth → touch)", when: uShowNaked)
  nvHistMode    = input.select("By score", title: "Touched style", options: ["By score", "Gray"], when: uShowNaked && nvShowTouched)
  nvHistMax     = input.int(300, title: "Max touched in history", min: 10, max: 2000, when: uShowNaked && nvShowTouched)
  nvHistLabel   = input.bool(true, title: "Score at the touch point", when: uShowNaked && nvShowTouched)

  input.group(title: "Naked σ bands")
  nvStdMode     = input.select("Off", title: "Bands", options: ["Off", "±1σ", "±1σ ±2σ"], when: uShowNaked)
  nvStdExtend   = input.bool(true, title: "Extend naked σ right", when: uShowNaked && nvStdMode != "Off")

  input.group(title: "Style & labels", collapsible: true, collapsed: true)
  nvLineStyle   = input.select("Dotted", title: "Line · width", options: ["Dotted", "Dashed", "Solid"])
  nvLineWidth   = input.float(0.9, title: "", min: 0.5, max: 5.0, sameLine: true)
  nvExtend      = input.bool(true, title: "Extend naked VWAPs right")
  nvTagPos      = input.select("Axis", title: "Label · size", options: ["Axis", "Axis + Origin", "Right margin", "Origin", "None"])
  nvBadgeSize   = input.float(11.0, title: "", min: 8.0, max: 20.0, sameLine: true)
  nvAxisSlots   = input.int(2, title: "Nearest per type (axis · highlight)", min: 1, max: 3)
  nvDim         = input.bool(true, title: "Dim the non-nearest")
  nvDimPct      = input.int(25, title: "Dimmed opacity %", min: 0, max: 100, when: nvDim)
  showNvPrice   = input.bool(true, title: "Price")
  showScores    = input.bool(true, title: "Score")

  input.group(title: "Score  (R = volume + |Δ| · percentile vs. previous periods)", collapsible: true, collapsed: true)
  nvScoreMode   = input.select("R + V + Δ", title: "Display", options: ["R", "R + V", "R + V + Δ"])
  nvScoreN      = input.int(14, title: "Window (periods of the same type)", min: 5, max: 50)
  nvWVol        = input.float(0.7, title: "Volume weight · Δ weight", min: 0.0, max: 1.0)
  nvWDelta      = input.float(0.3, title: "", min: 0.0, max: 1.0, sameLine: true)
  nvScoreByDelta = input.bool(true, title: "Score color by Δ sign")
  nvOffsetBps   = input.float(8.0, title: "Label lift (bps)", min: 0.0, max: 50.0)
  nvCol4H       = input.color(color.rgb(247, 207, 207), title: "Colors 4H·D·W·M·Q·Y")
  nvColD        = input.color(color.rgb(243, 180, 180), title: "", sameLine: true)
  nvColW        = input.color(color.rgb(239, 141, 141), title: "", sameLine: true)
  nvColM        = input.color(color.rgb(234, 110, 110), title: "", sameLine: true)
  nvColQ        = input.color(color.rgb(224, 78, 78), title: "", sameLine: true)
  nvColY        = input.color(color.rgb(215, 52, 52), title: "", sameLine: true)

  // ==========================================================================
  // TAB 6 · ROLLING VWAPs (días)
  // ==========================================================================
  input.tab(title: "Rolling")
  input.group(title: "Rolling  (enable · days · color · bands · 1σ color · 2σ color)")
  uShowRoll1     = input.bool(false, title: "R1")
  uRollDays1     = input.float(7.0, title: "", min: 0.1, max: 365.0, sameLine: true)
  rollCol1      = input.color(color.rgb(255, 107, 107), title: "", sameLine: true)
  uModeRoll1 = input.select("No σ", title: "", options: ["No σ", "σ", "σ + fill"], sameLine: true)
  rollS1Col1    = input.color(color.rgb(255, 153, 153), title: "", sameLine: true)
  rollS2Col1    = input.color(color.rgb(255, 204, 204), title: "", sameLine: true)
  uShowRoll2     = input.bool(false, title: "R2")
  rollDays2     = input.float(30.0, title: "", min: 0.1, max: 365.0, sameLine: true)
  rollCol2      = input.color(color.rgb(78, 205, 196), title: "", sameLine: true)
  modeRoll2 = input.select("No σ", title: "", options: ["No σ", "σ", "σ + fill"], sameLine: true)
  rollS1Col2    = input.color(color.rgb(127, 217, 209), title: "", sameLine: true)
  rollS2Col2    = input.color(color.rgb(179, 230, 224), title: "", sameLine: true)
  uShowRoll3     = input.bool(false, title: "R3")
  rollDays3     = input.float(90.0, title: "", min: 0.1, max: 365.0, sameLine: true)
  rollCol3      = input.color(color.rgb(255, 217, 61), title: "", sameLine: true)
  modeRoll3 = input.select("No σ", title: "", options: ["No σ", "σ", "σ + fill"], sameLine: true)
  rollS1Col3    = input.color(color.rgb(255, 224, 102), title: "", sameLine: true)
  rollS2Col3    = input.color(color.rgb(255, 235, 153), title: "", sameLine: true)

  input.group(title: "Style")
  rollWidth     = input.float(1.5, title: "Width", min: 0.5, max: 5.0)
)

// ----------------------------------------------------------------------------
// Setup constants
// ----------------------------------------------------------------------------
setup (
  // Preset overrides (Custom = the individual inputs)
  preCustom = pre == "Custom"
  preOwn = preCustom || preKeep
  showStd2 = preCustom ? uShowStd2 : preStd2
  showStd3 = preCustom ? uShowStd3 : false
  show4H = preCustom ? uShow4H : false
  showDaily = preCustom ? uShowDaily : pre == "Daily" ? true : pre == "Weekly" ? false : pre == "Monthly" ? false : false
  showWeekly = preCustom ? uShowWeekly : pre == "Daily" ? false : pre == "Weekly" ? true : pre == "Monthly" ? false : false
  showMonthly = preCustom ? uShowMonthly : pre == "Daily" ? false : pre == "Weekly" ? false : pre == "Monthly" ? true : false
  showQuarterly = preCustom ? uShowQuarterly : pre == "Daily" ? false : pre == "Weekly" ? false : pre == "Monthly" ? false : true
  showYearly = preCustom ? uShowYearly : pre == "Daily" ? false : pre == "Weekly" ? false : pre == "Monthly" ? false : true
  modeDaily = preCustom ? uModeDaily : "σ + fill"
  modeWeekly = preCustom ? uModeWeekly : "σ"
  modeMonthly = preCustom ? uModeMonthly : "σ"
  modeQuarterly = preCustom ? uModeQuarterly : "σ"
  modeYearly = preCustom ? uModeYearly : "σ"
  pmode4H = preCustom ? uPmode4H : "No projection"
  pmodeDaily = preCustom ? uPmodeDaily : "No projection"
  pmodeWeekly = preCustom ? uPmodeWeekly : "No projection"
  pmodeMonthly = preCustom ? uPmodeMonthly : "No projection"
  pmodeQuarterly = preCustom ? uPmodeQuarterly : "No projection"
  pmodeYearly = preCustom ? uPmodeYearly : "No projection"
  showSessAsia = preOwn ? uShowSessAsia : false
  showSessLondon = preOwn ? uShowSessLondon : false
  showSessNY = preOwn ? uShowSessNY : false
  showSessClose = preOwn ? uShowSessClose : false
  enableMonthAvwap = preOwn ? uEnableMonthAvwap : false
  enablePrevMonthAvwap = preOwn ? uEnablePrevMonthAvwap : false
  enableWeekAvwap = preOwn ? uEnableWeekAvwap : false
  enablePrevWeekAvwap = preOwn ? uEnablePrevWeekAvwap : false
  enableDayAvwap = preOwn ? uEnableDayAvwap : false
  enablePrevDayAvwap = preOwn ? uEnablePrevDayAvwap : false
  showNaked = preCustom ? uShowNaked : true
  nakedOnlyMode = preCustom ? uNakedOnlyMode : false
  nk4H = preCustom ? uNk4H : false
  nkD = preCustom ? uNkD : pre == "Daily" ? true : pre == "Weekly" ? false : pre == "Monthly" ? false : false
  nkW = preCustom ? uNkW : pre == "Daily" ? false : pre == "Weekly" ? true : pre == "Monthly" ? false : false
  nkM = preCustom ? uNkM : pre == "Daily" ? false : pre == "Weekly" ? false : pre == "Monthly" ? true : false
  nkQ = preCustom ? uNkQ : pre == "Daily" ? false : pre == "Weekly" ? false : pre == "Monthly" ? true : true
  nkY = preCustom ? uNkY : pre == "Daily" ? false : pre == "Weekly" ? false : pre == "Monthly" ? false : true
  nkAsia = preCustom ? uNkAsia : false
  nkLondon = preCustom ? uNkLondon : false
  nkNY = preCustom ? uNkNY : false
  nkClose = preCustom ? uNkClose : false
  nkAnchM = preCustom ? uNkAnchM : false
  nkAnchW = preCustom ? uNkAnchW : false
  nkAnchD = preCustom ? uNkAnchD : false
  showRoll1 = preCustom ? uShowRoll1 : true
  showRoll2 = preCustom ? uShowRoll2 : false
  showRoll3 = preCustom ? uShowRoll3 : false
  rollDays1 = preCustom ? uRollDays1 : pre == "Daily" ? 7.0 : pre == "Weekly" ? 30.0 : pre == "Monthly" ? 90.0 : 365.0
  modeRoll1 = preCustom ? uModeRoll1 : pre == "Daily" ? "σ + fill" : pre == "Weekly" ? "σ" : pre == "Monthly" ? "No σ" : "No σ"

  // Band / fill / projection flags from the labelled selects
  bands4H = mode4H != "No σ"
  fill4H = mode4H == "σ + fill"
  bandsDaily = modeDaily != "No σ"
  fillDaily = modeDaily == "σ + fill"
  bandsWeekly = modeWeekly != "No σ"
  fillWeekly = modeWeekly == "σ + fill"
  bandsMonthly = modeMonthly != "No σ"
  fillMonthly = modeMonthly == "σ + fill"
  bandsQuarterly = modeQuarterly != "No σ"
  fillQuarterly = modeQuarterly == "σ + fill"
  bandsYearly = modeYearly != "No σ"
  fillYearly = modeYearly == "σ + fill"
  bandsAsia = modeAsia != "No σ"
  fillAsia = modeAsia == "σ + fill"
  bandsLondon = modeLondon != "No σ"
  fillLondon = modeLondon == "σ + fill"
  bandsNY = modeNY != "No σ"
  fillNY = modeNY == "σ + fill"
  bandsClose = modeClose != "No σ"
  fillClose = modeClose == "σ + fill"
  bandsMonth = modeMonth != "No σ"
  fillMonth = modeMonth == "σ + fill"
  bandsPrevMonth = modePrevMonth != "No σ"
  fillPrevMonth = modePrevMonth == "σ + fill"
  bandsWeek = modeWeek != "No σ"
  fillWeek = modeWeek == "σ + fill"
  bandsPrevWeek = modePrevWeek != "No σ"
  fillPrevWeek = modePrevWeek == "σ + fill"
  bandsDay = modeDay != "No σ"
  fillDay = modeDay == "σ + fill"
  bandsPrevDay = modePrevDay != "No σ"
  fillPrevDay = modePrevDay == "σ + fill"
  bandsRoll1 = modeRoll1 != "No σ"
  fillRoll1 = modeRoll1 == "σ + fill"
  bandsRoll2 = modeRoll2 != "No σ"
  fillRoll2 = modeRoll2 == "σ + fill"
  bandsRoll3 = modeRoll3 != "No σ"
  fillRoll3 = modeRoll3 == "σ + fill"
  customBands = modeCustom != "No σ"
  customFill = modeCustom == "σ + fill"
  proj4H = pmode4H == "Project"
  projDaily = pmodeDaily == "Project"
  projWeekly = pmodeWeekly == "Project"
  projMonthly = pmodeMonthly == "Project"
  projQuarterly = pmodeQuarterly == "Project"
  projYearly = pmodeYearly == "Project"
  fillStd1 = fmodeStd1 == "Fill"
  fillStd2 = fmodeStd2 == "Fill"
  fillStd3 = fmodeStd3 == "Fill"

  fillA = int(math.round(float(fillOpacity) * 2.55)) ?? 46
  std1FillColor = color.withAlpha(std1Color, fillA)
  std2FillColor = color.withAlpha(std2Color, fillA)
  std3FillColor = color.withAlpha(std3Color, fillA)
  deadColor     = color.withAlpha(color.gray, 90)
  hideDead      = !nvShowTouched
  histByScore   = nvHistMode == "By score"
  // #FFFFFF00: an all-zero #00000000 is ignored as a per-point override.
  invisible     = color.withAlpha(color.white, 0)
  fillA2        = int(math.round(float(fillA) * 0.6)) ?? 28

  ptKeepPrev    = ptPrevMode == "Until touched"
  ptByClose     = ptPivotMode == "Close"
  // Live high/low legs (ptHideOld): lines per segment (center + σ lines) and
  // samples per live leg, sized so live + kept legs stay under 2000 lines
  lvNP     = (enableMonthAvwap ? 1 : 0) + (enableWeekAvwap ? 1 : 0) + (enableDayAvwap ? 1 : 0)
  lvOn     = ptHideOld && lvNP > 0
  lvLpsM   = 1 + (bandsMonth ? ((showStd1 || (fillMonth && fillStd1)) ? 2 : 0) + (showStd2 ? 2 : 0) : 0)
  lvLpsW   = 1 + (bandsWeek ? ((showStd1 || (fillWeek && fillStd1)) ? 2 : 0) + (showStd2 ? 2 : 0) : 0)
  lvLpsD   = 1 + (bandsDay ? ((showStd1 || (fillDay && fillStd1)) ? 2 : 0) + (showStd2 ? 2 : 0) : 0)
  lvLpsMax = math.max(enableMonthAvwap ? lvLpsM : 1, math.max(enableWeekAvwap ? lvLpsW : 1, enableDayAvwap ? lvLpsD : 1))
  lvP      = math.min(200, math.max(24, int(math.floor(900.0 / float(2 * math.max(1, lvNP) * lvLpsMax))) ?? 24))
  lvCap    = lvP + 12
  nvExt         = nvExtend ? extend.right : extend.none
  nvBandExt     = nvStdExtend ? extend.right : extend.none

  srcId = srcMode == "HLC3" ? 0 : (srcMode == "OHLC4" ? 1 : (srcMode == "HL2" ? 2 : 3))

  // Configurable UTC sessions (hours -> minutes)
  sessAsia   = time.sessionMinutes(int(math.round(asiaStart * 60.0)) ?? 0, int(math.round(asiaEnd * 60.0)) ?? 480)
  sessLondon = time.sessionMinutes(int(math.round(londonStart * 60.0)) ?? 420, int(math.round(londonEnd * 60.0)) ?? 930)
  sessNY     = time.sessionMinutes(int(math.round(nyStart * 60.0)) ?? 810, int(math.round(nyEnd * 60.0)) ?? 1200)
  sessClose  = time.sessionMinutes(int(math.round(closeStart * 60.0)) ?? 1200, int(math.round(closeEnd * 60.0)) ?? 1440)

  // Rolling VWAPs: bucket size = chart TF, widened (as a TF multiple) when the
  // window would need more than 5000 buckets. Exact on >= ~30m charts.
  chartTfSec = math.max(1, time.tfSeconds(context.timeframe))
  rollNeed1  = math.max(1.0, rollDays1 * 86400.0 / float(chartTfSec))
  rollNeed2  = math.max(1.0, rollDays2 * 86400.0 / float(chartTfSec))
  rollNeed3  = math.max(1.0, rollDays3 * 86400.0 / float(chartTfSec))
  rollMul1   = math.max(1, int(math.ceil(rollNeed1 / 5000.0)) ?? 1)
  rollMul2   = math.max(1, int(math.ceil(rollNeed2 / 5000.0)) ?? 1)
  rollMul3   = math.max(1, int(math.ceil(rollNeed3 / 5000.0)) ?? 1)
  rollTf1    = time.tfFromSeconds(chartTfSec * rollMul1)
  rollTf2    = time.tfFromSeconds(chartTfSec * rollMul2)
  rollTf3    = time.tfFromSeconds(chartTfSec * rollMul3)
  rollCap1   = math.max(2, math.min(5000, int(math.round(rollNeed1 / float(rollMul1))) ?? 2))
  rollCap2   = math.max(2, math.min(5000, int(math.round(rollNeed2 / float(rollMul2))) ?? 2))
  rollCap3   = math.max(2, math.min(5000, int(math.round(rollNeed3 / float(rollMul3))) ?? 2))
  rollTitle1 = str.format("Rolling VWAP {0}D", rollDays1)
  rollTitle2 = str.format("Rolling VWAP {0}D", rollDays2)
  rollTitle3 = str.format("Rolling VWAP {0}D", rollDays3)

  // Custom AVWAP anchor as a sortable YYYYMMDDHH key
  customKey = customYear * 1000000 + customMonth * 10000 + customDay * 100 + customHour

  // Naked styling
  nvStyle   = nvLineStyle == "Solid" ? linestyle.solid : (nvLineStyle == "Dotted" ? linestyle.dotted : linestyle.dashed)
  nvAxis    = nvTagPos == "Axis" || nvTagPos == "Axis + Origin"
  nvMargin  = nvTagPos == "Right margin"
  nvOrigin  = nvTagPos == "Origin" || nvTagPos == "Axis + Origin"
  nvBadge   = nvAxis && showScores  // score badge beside the axis label
  touchBody = nakedTouch == "Body"
  tolFactor = nakedTolBps / 10000.0
  lblFactor = 1.0 + nvOffsetBps / 10000.0
  nvStd1On  = nvStdMode != "Off"
  nvStd2On  = nvStdMode == "±1σ ±2σ"
  // Some naked line ends at the live bar (not extended): redraw it each tick
  nvLive    = !nvExtend || (nvStd1On && !nvStdExtend)
  sameSess  = nkSessMode == "Same session only"
  nvDimA    = int(math.round(float(nvDimPct) * 2.55)) ?? 64

  // HUD layout
  hudRight  = hudPos == "Top right" || hudPos == "Bottom right"
  hudTop    = hudPos == "Top right" || hudPos == "Top left"
  hudAlign  = hudRight ? "right" : "left"
  hudLineH  = hudSize * 1.55

  // Alerts
  alertSigmaMult = alertSigma == "1σ" ? std1Mult : (alertSigma == "2σ" ? std2Mult : std3Mult)
)

// ----------------------------------------------------------------------------
// Plots
// ----------------------------------------------------------------------------
plot (
  // Periodic VWAPs & σ bands
  p4h      = plot.line(title: "4H VWAP", color: color4H, width: width4H)
  p4h_s1u  = plot.line(title: "4H +1σ", color: std1Color, width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  p4h_s1d  = plot.line(title: "4H -1σ", color: std1Color, width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  p4h_s2u  = plot.line(title: "4H +2σ", color: std2Color, width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  p4h_s2d  = plot.line(title: "4H -2σ", color: std2Color, width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  p4h_s3u  = plot.line(title: "4H +3σ", color: std3Color, width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  p4h_s3d  = plot.line(title: "4H -3σ", color: std3Color, width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)

  pd       = plot.line(title: "Daily VWAP", color: colorDaily, width: widthDaily)
  pd_s1u   = plot.line(title: "D +1σ", color: std1Color, width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pd_s1d   = plot.line(title: "D -1σ", color: std1Color, width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pd_s2u   = plot.line(title: "D +2σ", color: std2Color, width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pd_s2d   = plot.line(title: "D -2σ", color: std2Color, width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pd_s3u   = plot.line(title: "D +3σ", color: std3Color, width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  pd_s3d   = plot.line(title: "D -3σ", color: std3Color, width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)

  pw       = plot.line(title: "Weekly VWAP", color: colorWeekly, width: widthWeekly)
  pw_s1u   = plot.line(title: "W +1σ", color: std1Color, width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pw_s1d   = plot.line(title: "W -1σ", color: std1Color, width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pw_s2u   = plot.line(title: "W +2σ", color: std2Color, width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pw_s2d   = plot.line(title: "W -2σ", color: std2Color, width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pw_s3u   = plot.line(title: "W +3σ", color: std3Color, width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  pw_s3d   = plot.line(title: "W -3σ", color: std3Color, width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)

  pm       = plot.line(title: "Monthly VWAP", color: colorMonthly, width: widthMonthly)
  pm_s1u   = plot.line(title: "M +1σ", color: std1Color, width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pm_s1d   = plot.line(title: "M -1σ", color: std1Color, width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pm_s2u   = plot.line(title: "M +2σ", color: std2Color, width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pm_s2d   = plot.line(title: "M -2σ", color: std2Color, width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pm_s3u   = plot.line(title: "M +3σ", color: std3Color, width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  pm_s3d   = plot.line(title: "M -3σ", color: std3Color, width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)

  pq       = plot.line(title: "Quarterly VWAP", color: colorQuarterly, width: widthQuarterly)
  pq_s1u   = plot.line(title: "Q +1σ", color: std1Color, width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pq_s1d   = plot.line(title: "Q -1σ", color: std1Color, width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pq_s2u   = plot.line(title: "Q +2σ", color: std2Color, width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pq_s2d   = plot.line(title: "Q -2σ", color: std2Color, width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pq_s3u   = plot.line(title: "Q +3σ", color: std3Color, width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  pq_s3d   = plot.line(title: "Q -3σ", color: std3Color, width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)

  py       = plot.line(title: "Yearly VWAP", color: colorYearly, width: widthYearly)
  py_s1u   = plot.line(title: "Y +1σ", color: std1Color, width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  py_s1d   = plot.line(title: "Y -1σ", color: std1Color, width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  py_s2u   = plot.line(title: "Y +2σ", color: std2Color, width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  py_s2d   = plot.line(title: "Y -2σ", color: std2Color, width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  py_s3u   = plot.line(title: "Y +3σ", color: std3Color, width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  py_s3d   = plot.line(title: "Y -3σ", color: std3Color, width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)

  // Session VWAPs
  pSessAsia   = plot.line(title: "Asia VWAP", color: colSessAsia, width: sessWidth, showLabel: false)
  pSessLondon = plot.line(title: "London VWAP", color: colSessLondon, width: sessWidth, showLabel: false)
  pSessNY     = plot.line(title: "New York VWAP", color: colSessNY, width: sessWidth, showLabel: false)
  pSessClose  = plot.line(title: "NY Close VWAP", color: colSessClose, width: sessWidth, showLabel: false)

  // Peak / Trough AVWAPs
  pMHigh     = plot.line(title: "Month High AVWAP", color: colMonthHigh, width: 2.0)
  pMLow      = plot.line(title: "Month Low AVWAP", color: colMonthLow, width: 2.0)
  pPrevMHigh = plot.line(title: "Prev Month High AVWAP", color: colPrevMonthHigh, width: 2.0, style: linestyle.dashed, showLabel: false)
  pPrevMLow  = plot.line(title: "Prev Month Low AVWAP", color: colPrevMonthLow, width: 2.0, style: linestyle.dashed, showLabel: false)
  pWHigh     = plot.line(title: "Week High AVWAP", color: colWeekHigh, width: 1.5)
  pWLow      = plot.line(title: "Week Low AVWAP", color: colWeekLow, width: 1.5)
  pPrevWHigh = plot.line(title: "Prev Week High AVWAP", color: colPrevWeekHigh, width: 1.5, style: linestyle.dashed, showLabel: false)
  pPrevWLow  = plot.line(title: "Prev Week Low AVWAP", color: colPrevWeekLow, width: 1.5, style: linestyle.dashed, showLabel: false)
  pDHigh     = plot.line(title: "Day High AVWAP", color: colDayHigh, width: 1.5)
  pDLow      = plot.line(title: "Day Low AVWAP", color: colDayLow, width: 1.5)
  pPrevDHigh = plot.line(title: "Prev Day High AVWAP", color: colPrevDayHigh, width: 1.5, style: linestyle.dashed, showLabel: false)
  pPrevDLow  = plot.line(title: "Prev Day Low AVWAP", color: colPrevDayLow, width: 1.5, style: linestyle.dashed, showLabel: false)

  // Custom-date AVWAP (+ optional bands)
  pCustom    = plot.line(title: "Custom AVWAP", color: colCustomAvwap, width: 2.0)
  pCust_s1u  = plot.line(title: "Custom +1σ", color: color.withAlpha(colCustomAvwap, 150), width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pCust_s1d  = plot.line(title: "Custom -1σ", color: color.withAlpha(colCustomAvwap, 150), width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pCust_s2u  = plot.line(title: "Custom +2σ", color: color.withAlpha(colCustomAvwap, 110), width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  pCust_s2d  = plot.line(title: "Custom -2σ", color: color.withAlpha(colCustomAvwap, 110), width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)

  // Rolling VWAPs
  pr1 = plot.line(title: rollTitle1, color: rollCol1, width: rollWidth)
  pr2 = plot.line(title: rollTitle2, color: rollCol2, width: rollWidth)
  pr3 = plot.line(title: rollTitle3, color: rollCol3, width: rollWidth)

  // Naked VWAP price-axis labels (nearest levels per period, live bar only)
  nvAx4H_1 = plot.line(title: "NV 4H 1", color: nvCol4H, width: 1.0, showLabel: false)
  nvAx4H_2 = plot.line(title: "NV 4H 2", color: nvCol4H, width: 1.0, showLabel: false)
  nvAx4H_3 = plot.line(title: "NV 4H 3", color: nvCol4H, width: 1.0, showLabel: false)
  nvAxD_1 = plot.line(title: "NV D 1", color: nvColD, width: 1.0, showLabel: false)
  nvAxD_2 = plot.line(title: "NV D 2", color: nvColD, width: 1.0, showLabel: false)
  nvAxD_3 = plot.line(title: "NV D 3", color: nvColD, width: 1.0, showLabel: false)
  nvAxW_1 = plot.line(title: "NV W 1", color: nvColW, width: 1.0, showLabel: false)
  nvAxW_2 = plot.line(title: "NV W 2", color: nvColW, width: 1.0, showLabel: false)
  nvAxW_3 = plot.line(title: "NV W 3", color: nvColW, width: 1.0, showLabel: false)
  nvAxM_1 = plot.line(title: "NV M 1", color: nvColM, width: 1.0, showLabel: false)
  nvAxM_2 = plot.line(title: "NV M 2", color: nvColM, width: 1.0, showLabel: false)
  nvAxM_3 = plot.line(title: "NV M 3", color: nvColM, width: 1.0, showLabel: false)
  nvAxQ_1 = plot.line(title: "NV Q 1", color: nvColQ, width: 1.0, showLabel: false)
  nvAxQ_2 = plot.line(title: "NV Q 2", color: nvColQ, width: 1.0, showLabel: false)
  nvAxQ_3 = plot.line(title: "NV Q 3", color: nvColQ, width: 1.0, showLabel: false)
  nvAxY_1 = plot.line(title: "NV Y 1", color: nvColY, width: 1.0, showLabel: false)
  nvAxY_2 = plot.line(title: "NV Y 2", color: nvColY, width: 1.0, showLabel: false)
  nvAxY_3 = plot.line(title: "NV Y 3", color: nvColY, width: 1.0, showLabel: false)
  nvAxAS_1 = plot.line(title: "NV AS 1", color: colSessAsia, width: 1.0, showLabel: false)
  nvAxAS_2 = plot.line(title: "NV AS 2", color: colSessAsia, width: 1.0, showLabel: false)
  nvAxAS_3 = plot.line(title: "NV AS 3", color: colSessAsia, width: 1.0, showLabel: false)
  nvAxLN_1 = plot.line(title: "NV LN 1", color: colSessLondon, width: 1.0, showLabel: false)
  nvAxLN_2 = plot.line(title: "NV LN 2", color: colSessLondon, width: 1.0, showLabel: false)
  nvAxLN_3 = plot.line(title: "NV LN 3", color: colSessLondon, width: 1.0, showLabel: false)
  nvAxNY_1 = plot.line(title: "NV NY 1", color: colSessNY, width: 1.0, showLabel: false)
  nvAxNY_2 = plot.line(title: "NV NY 2", color: colSessNY, width: 1.0, showLabel: false)
  nvAxNY_3 = plot.line(title: "NV NY 3", color: colSessNY, width: 1.0, showLabel: false)
  nvAxNC_1 = plot.line(title: "NV NC 1", color: colSessClose, width: 1.0, showLabel: false)
  nvAxNC_2 = plot.line(title: "NV NC 2", color: colSessClose, width: 1.0, showLabel: false)
  nvAxMH_1 = plot.line(title: "NV MH 1", color: colPrevMonthHigh, width: 1.0, showLabel: false)
  nvAxMH_2 = plot.line(title: "NV MH 2", color: colPrevMonthHigh, width: 1.0, showLabel: false)
  nvAxMH_3 = plot.line(title: "NV MH 3", color: colPrevMonthHigh, width: 1.0, showLabel: false)
  nvAxML_1 = plot.line(title: "NV ML 1", color: colPrevMonthLow, width: 1.0, showLabel: false)
  nvAxML_2 = plot.line(title: "NV ML 2", color: colPrevMonthLow, width: 1.0, showLabel: false)
  nvAxML_3 = plot.line(title: "NV ML 3", color: colPrevMonthLow, width: 1.0, showLabel: false)
  nvAxWH_1 = plot.line(title: "NV WH 1", color: colPrevWeekHigh, width: 1.0, showLabel: false)
  nvAxWH_2 = plot.line(title: "NV WH 2", color: colPrevWeekHigh, width: 1.0, showLabel: false)
  nvAxWH_3 = plot.line(title: "NV WH 3", color: colPrevWeekHigh, width: 1.0, showLabel: false)
  nvAxWL_1 = plot.line(title: "NV WL 1", color: colPrevWeekLow, width: 1.0, showLabel: false)
  nvAxWL_2 = plot.line(title: "NV WL 2", color: colPrevWeekLow, width: 1.0, showLabel: false)
  nvAxWL_3 = plot.line(title: "NV WL 3", color: colPrevWeekLow, width: 1.0, showLabel: false)
  nvAxDH_1 = plot.line(title: "NV DH 1", color: colPrevDayHigh, width: 1.0, showLabel: false)
  nvAxDH_2 = plot.line(title: "NV DH 2", color: colPrevDayHigh, width: 1.0, showLabel: false)
  nvAxDH_3 = plot.line(title: "NV DH 3", color: colPrevDayHigh, width: 1.0, showLabel: false)
  nvAxDL_1 = plot.line(title: "NV DL 1", color: colPrevDayLow, width: 1.0, showLabel: false)
  nvAxDL_2 = plot.line(title: "NV DL 2", color: colPrevDayLow, width: 1.0, showLabel: false)
  nvAxDL_3 = plot.line(title: "NV DL 3", color: colPrevDayLow, width: 1.0, showLabel: false)
  nvAxNC_3 = plot.line(title: "NV NC 3", color: colSessClose, width: 1.0, showLabel: false)

  // σ bands of session / anchored / rolling VWAPs (line color, faded)
  pSessAsia_s1u = plot.line(title: "Asia +1σ", color: color.withAlpha(colSessAsia, 150), width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pSessAsia_s1d = plot.line(title: "Asia -1σ", color: color.withAlpha(colSessAsia, 150), width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pSessAsia_s2u = plot.line(title: "Asia +2σ", color: color.withAlpha(colSessAsia, 110), width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  pSessAsia_s2d = plot.line(title: "Asia -2σ", color: color.withAlpha(colSessAsia, 110), width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  pSessLondon_s1u = plot.line(title: "London +1σ", color: color.withAlpha(colSessLondon, 150), width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pSessLondon_s1d = plot.line(title: "London -1σ", color: color.withAlpha(colSessLondon, 150), width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pSessLondon_s2u = plot.line(title: "London +2σ", color: color.withAlpha(colSessLondon, 110), width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  pSessLondon_s2d = plot.line(title: "London -2σ", color: color.withAlpha(colSessLondon, 110), width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  pSessNY_s1u = plot.line(title: "NY +1σ", color: color.withAlpha(colSessNY, 150), width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pSessNY_s1d = plot.line(title: "NY -1σ", color: color.withAlpha(colSessNY, 150), width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pSessNY_s2u = plot.line(title: "NY +2σ", color: color.withAlpha(colSessNY, 110), width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  pSessNY_s2d = plot.line(title: "NY -2σ", color: color.withAlpha(colSessNY, 110), width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  pSessClose_s1u = plot.line(title: "NY Close +1σ", color: color.withAlpha(colSessClose, 150), width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pSessClose_s1d = plot.line(title: "NY Close -1σ", color: color.withAlpha(colSessClose, 150), width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pSessClose_s2u = plot.line(title: "NY Close +2σ", color: color.withAlpha(colSessClose, 110), width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  pSessClose_s2d = plot.line(title: "NY Close -2σ", color: color.withAlpha(colSessClose, 110), width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  pMHigh_s1u = plot.line(title: "M High +1σ", color: color.withAlpha(colMonthHigh, 150), width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pMHigh_s1d = plot.line(title: "M High -1σ", color: color.withAlpha(colMonthHigh, 150), width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pMHigh_s2u = plot.line(title: "M High +2σ", color: color.withAlpha(colMonthHigh, 110), width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  pMHigh_s2d = plot.line(title: "M High -2σ", color: color.withAlpha(colMonthHigh, 110), width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  pMLow_s1u = plot.line(title: "M Low +1σ", color: color.withAlpha(colMonthLow, 150), width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pMLow_s1d = plot.line(title: "M Low -1σ", color: color.withAlpha(colMonthLow, 150), width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pMLow_s2u = plot.line(title: "M Low +2σ", color: color.withAlpha(colMonthLow, 110), width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  pMLow_s2d = plot.line(title: "M Low -2σ", color: color.withAlpha(colMonthLow, 110), width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  pPrevMHigh_s1u = plot.line(title: "M-1 High +1σ", color: color.withAlpha(colPrevMonthHigh, 150), width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pPrevMHigh_s1d = plot.line(title: "M-1 High -1σ", color: color.withAlpha(colPrevMonthHigh, 150), width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pPrevMHigh_s2u = plot.line(title: "M-1 High +2σ", color: color.withAlpha(colPrevMonthHigh, 110), width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  pPrevMHigh_s2d = plot.line(title: "M-1 High -2σ", color: color.withAlpha(colPrevMonthHigh, 110), width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  pPrevMLow_s1u = plot.line(title: "M-1 Low +1σ", color: color.withAlpha(colPrevMonthLow, 150), width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pPrevMLow_s1d = plot.line(title: "M-1 Low -1σ", color: color.withAlpha(colPrevMonthLow, 150), width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pPrevMLow_s2u = plot.line(title: "M-1 Low +2σ", color: color.withAlpha(colPrevMonthLow, 110), width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  pPrevMLow_s2d = plot.line(title: "M-1 Low -2σ", color: color.withAlpha(colPrevMonthLow, 110), width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  pWHigh_s1u = plot.line(title: "W High +1σ", color: color.withAlpha(colWeekHigh, 150), width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pWHigh_s1d = plot.line(title: "W High -1σ", color: color.withAlpha(colWeekHigh, 150), width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pWHigh_s2u = plot.line(title: "W High +2σ", color: color.withAlpha(colWeekHigh, 110), width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  pWHigh_s2d = plot.line(title: "W High -2σ", color: color.withAlpha(colWeekHigh, 110), width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  pWLow_s1u = plot.line(title: "W Low +1σ", color: color.withAlpha(colWeekLow, 150), width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pWLow_s1d = plot.line(title: "W Low -1σ", color: color.withAlpha(colWeekLow, 150), width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pWLow_s2u = plot.line(title: "W Low +2σ", color: color.withAlpha(colWeekLow, 110), width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  pWLow_s2d = plot.line(title: "W Low -2σ", color: color.withAlpha(colWeekLow, 110), width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  pPrevWHigh_s1u = plot.line(title: "W-1 High +1σ", color: color.withAlpha(colPrevWeekHigh, 150), width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pPrevWHigh_s1d = plot.line(title: "W-1 High -1σ", color: color.withAlpha(colPrevWeekHigh, 150), width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pPrevWHigh_s2u = plot.line(title: "W-1 High +2σ", color: color.withAlpha(colPrevWeekHigh, 110), width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  pPrevWHigh_s2d = plot.line(title: "W-1 High -2σ", color: color.withAlpha(colPrevWeekHigh, 110), width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  pPrevWLow_s1u = plot.line(title: "W-1 Low +1σ", color: color.withAlpha(colPrevWeekLow, 150), width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pPrevWLow_s1d = plot.line(title: "W-1 Low -1σ", color: color.withAlpha(colPrevWeekLow, 150), width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pPrevWLow_s2u = plot.line(title: "W-1 Low +2σ", color: color.withAlpha(colPrevWeekLow, 110), width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  pPrevWLow_s2d = plot.line(title: "W-1 Low -2σ", color: color.withAlpha(colPrevWeekLow, 110), width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  pDHigh_s1u = plot.line(title: "D High +1σ", color: color.withAlpha(colDayHigh, 150), width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pDHigh_s1d = plot.line(title: "D High -1σ", color: color.withAlpha(colDayHigh, 150), width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pDHigh_s2u = plot.line(title: "D High +2σ", color: color.withAlpha(colDayHigh, 110), width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  pDHigh_s2d = plot.line(title: "D High -2σ", color: color.withAlpha(colDayHigh, 110), width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  pDLow_s1u = plot.line(title: "D Low +1σ", color: color.withAlpha(colDayLow, 150), width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pDLow_s1d = plot.line(title: "D Low -1σ", color: color.withAlpha(colDayLow, 150), width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pDLow_s2u = plot.line(title: "D Low +2σ", color: color.withAlpha(colDayLow, 110), width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  pDLow_s2d = plot.line(title: "D Low -2σ", color: color.withAlpha(colDayLow, 110), width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  pPrevDHigh_s1u = plot.line(title: "D-1 High +1σ", color: color.withAlpha(colPrevDayHigh, 150), width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pPrevDHigh_s1d = plot.line(title: "D-1 High -1σ", color: color.withAlpha(colPrevDayHigh, 150), width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pPrevDHigh_s2u = plot.line(title: "D-1 High +2σ", color: color.withAlpha(colPrevDayHigh, 110), width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  pPrevDHigh_s2d = plot.line(title: "D-1 High -2σ", color: color.withAlpha(colPrevDayHigh, 110), width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  pPrevDLow_s1u = plot.line(title: "D-1 Low +1σ", color: color.withAlpha(colPrevDayLow, 150), width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pPrevDLow_s1d = plot.line(title: "D-1 Low -1σ", color: color.withAlpha(colPrevDayLow, 150), width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pPrevDLow_s2u = plot.line(title: "D-1 Low +2σ", color: color.withAlpha(colPrevDayLow, 110), width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  pPrevDLow_s2d = plot.line(title: "D-1 Low -2σ", color: color.withAlpha(colPrevDayLow, 110), width: 1.0, style: linestyle.dotted, showValue: false, showLabel: false)
  pr1_s1u = plot.line(title: "R1 +1σ", color: rollS1Col1, width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pr1_s1d = plot.line(title: "R1 -1σ", color: rollS1Col1, width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pr1_s2u = plot.line(title: "R1 +2σ", color: rollS2Col1, width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pr1_s2d = plot.line(title: "R1 -2σ", color: rollS2Col1, width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pr2_s1u = plot.line(title: "R2 +1σ", color: rollS1Col2, width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pr2_s1d = plot.line(title: "R2 -1σ", color: rollS1Col2, width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pr2_s2u = plot.line(title: "R2 +2σ", color: rollS2Col2, width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pr2_s2d = plot.line(title: "R2 -2σ", color: rollS2Col2, width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pr3_s1u = plot.line(title: "R3 +1σ", color: rollS1Col3, width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pr3_s1d = plot.line(title: "R3 -1σ", color: rollS1Col3, width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pr3_s2u = plot.line(title: "R3 +2σ", color: rollS2Col3, width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
  pr3_s2d = plot.line(title: "R3 -2σ", color: rollS2Col3, width: 1.0, style: linestyle.dashed, showValue: false, showLabel: false)
)

fill (
  // Periodic: 1σ zone, 1σ→2σ rings, 3σ zone (original style)
  f4h_s1  = fill.between(p4h_s1u, p4h_s1d, color: std1FillColor)
  f4h_s2u = fill.between(p4h_s2u, p4h_s1u, color: std2FillColor)
  f4h_s2d = fill.between(p4h_s1d, p4h_s2d, color: std2FillColor)
  f4h_s3  = fill.between(p4h_s3u, p4h_s3d, color: std3FillColor)

  fd_s1  = fill.between(pd_s1u, pd_s1d, color: std1FillColor)
  fd_s2u = fill.between(pd_s2u, pd_s1u, color: std2FillColor)
  fd_s2d = fill.between(pd_s1d, pd_s2d, color: std2FillColor)
  fd_s3  = fill.between(pd_s3u, pd_s3d, color: std3FillColor)

  fw_s1  = fill.between(pw_s1u, pw_s1d, color: std1FillColor)
  fw_s2u = fill.between(pw_s2u, pw_s1u, color: std2FillColor)
  fw_s2d = fill.between(pw_s1d, pw_s2d, color: std2FillColor)
  fw_s3  = fill.between(pw_s3u, pw_s3d, color: std3FillColor)

  fm_s1  = fill.between(pm_s1u, pm_s1d, color: std1FillColor)
  fm_s2u = fill.between(pm_s2u, pm_s1u, color: std2FillColor)
  fm_s2d = fill.between(pm_s1d, pm_s2d, color: std2FillColor)
  fm_s3  = fill.between(pm_s3u, pm_s3d, color: std3FillColor)

  fq_s1  = fill.between(pq_s1u, pq_s1d, color: std1FillColor)
  fq_s2u = fill.between(pq_s2u, pq_s1u, color: std2FillColor)
  fq_s2d = fill.between(pq_s1d, pq_s2d, color: std2FillColor)
  fq_s3  = fill.between(pq_s3u, pq_s3d, color: std3FillColor)

  fy_s1  = fill.between(py_s1u, py_s1d, color: std1FillColor)
  fy_s2u = fill.between(py_s2u, py_s1u, color: std2FillColor)
  fy_s2d = fill.between(py_s1d, py_s2d, color: std2FillColor)
  fy_s3  = fill.between(py_s3u, py_s3d, color: std3FillColor)

  // Sessions / custom AVWAP: 1σ zone + 1σ→2σ rings in the line color
  pSessAsia_f1  = fill.between(pSessAsia_s1u, pSessAsia_s1d, color: color.withAlpha(colSessAsia, fillA))
  pSessAsia_f2u = fill.between(pSessAsia_s2u, pSessAsia_s1u, color: color.withAlpha(colSessAsia, fillA2))
  pSessAsia_f2d = fill.between(pSessAsia_s1d, pSessAsia_s2d, color: color.withAlpha(colSessAsia, fillA2))
  pSessLondon_f1  = fill.between(pSessLondon_s1u, pSessLondon_s1d, color: color.withAlpha(colSessLondon, fillA))
  pSessLondon_f2u = fill.between(pSessLondon_s2u, pSessLondon_s1u, color: color.withAlpha(colSessLondon, fillA2))
  pSessLondon_f2d = fill.between(pSessLondon_s1d, pSessLondon_s2d, color: color.withAlpha(colSessLondon, fillA2))
  pSessNY_f1  = fill.between(pSessNY_s1u, pSessNY_s1d, color: color.withAlpha(colSessNY, fillA))
  pSessNY_f2u = fill.between(pSessNY_s2u, pSessNY_s1u, color: color.withAlpha(colSessNY, fillA2))
  pSessNY_f2d = fill.between(pSessNY_s1d, pSessNY_s2d, color: color.withAlpha(colSessNY, fillA2))
  pSessClose_f1  = fill.between(pSessClose_s1u, pSessClose_s1d, color: color.withAlpha(colSessClose, fillA))
  pSessClose_f2u = fill.between(pSessClose_s2u, pSessClose_s1u, color: color.withAlpha(colSessClose, fillA2))
  pSessClose_f2d = fill.between(pSessClose_s1d, pSessClose_s2d, color: color.withAlpha(colSessClose, fillA2))
  pCust_f1  = fill.between(pCust_s1u, pCust_s1d, color: color.withAlpha(colCustomAvwap, fillA))
  pCust_f2u = fill.between(pCust_s2u, pCust_s1u, color: color.withAlpha(colCustomAvwap, fillA2))
  pCust_f2d = fill.between(pCust_s1d, pCust_s2d, color: color.withAlpha(colCustomAvwap, fillA2))

  // Rolling: σ colors, rings (original style)
  pr1_f1  = fill.between(pr1_s1u, pr1_s1d, color: color.withAlpha(rollS1Col1, fillA))
  pr1_f2u = fill.between(pr1_s2u, pr1_s1u, color: color.withAlpha(rollS2Col1, fillA))
  pr1_f2d = fill.between(pr1_s1d, pr1_s2d, color: color.withAlpha(rollS2Col1, fillA))
  pr2_f1  = fill.between(pr2_s1u, pr2_s1d, color: color.withAlpha(rollS1Col2, fillA))
  pr2_f2u = fill.between(pr2_s2u, pr2_s1u, color: color.withAlpha(rollS2Col2, fillA))
  pr2_f2d = fill.between(pr2_s1d, pr2_s2d, color: color.withAlpha(rollS2Col2, fillA))
  pr3_f1  = fill.between(pr3_s1u, pr3_s1d, color: color.withAlpha(rollS1Col3, fillA))
  pr3_f2u = fill.between(pr3_s2u, pr3_s1u, color: color.withAlpha(rollS2Col3, fillA))
  pr3_f2d = fill.between(pr3_s1d, pr3_s2d, color: color.withAlpha(rollS2Col3, fillA))

  // Peak / trough AVWAPs: 1σ zone only (64-fill script limit)
  pMHigh_f1  = fill.between(pMHigh_s1u, pMHigh_s1d, color: color.withAlpha(colMonthHigh, fillA))
  pMLow_f1  = fill.between(pMLow_s1u, pMLow_s1d, color: color.withAlpha(colMonthLow, fillA))
  pPrevMHigh_f1  = fill.between(pPrevMHigh_s1u, pPrevMHigh_s1d, color: color.withAlpha(colPrevMonthHigh, fillA))
  pPrevMLow_f1  = fill.between(pPrevMLow_s1u, pPrevMLow_s1d, color: color.withAlpha(colPrevMonthLow, fillA))
  pWHigh_f1  = fill.between(pWHigh_s1u, pWHigh_s1d, color: color.withAlpha(colWeekHigh, fillA))
  pWLow_f1  = fill.between(pWLow_s1u, pWLow_s1d, color: color.withAlpha(colWeekLow, fillA))
  pPrevWHigh_f1  = fill.between(pPrevWHigh_s1u, pPrevWHigh_s1d, color: color.withAlpha(colPrevWeekHigh, fillA))
  pPrevWLow_f1  = fill.between(pPrevWLow_s1u, pPrevWLow_s1d, color: color.withAlpha(colPrevWeekLow, fillA))
  pDHigh_f1  = fill.between(pDHigh_s1u, pDHigh_s1d, color: color.withAlpha(colDayHigh, fillA))
  pDLow_f1  = fill.between(pDLow_s1u, pDLow_s1d, color: color.withAlpha(colDayLow, fillA))
  pPrevDHigh_f1  = fill.between(pPrevDHigh_s1u, pPrevDHigh_s1d, color: color.withAlpha(colPrevDayHigh, fillA))
  pPrevDLow_f1  = fill.between(pPrevDLow_s1u, pPrevDLow_s1d, color: color.withAlpha(colPrevDayLow, fillA))
)

// ----------------------------------------------------------------------------
// Alerts
// ----------------------------------------------------------------------------
type VwapAlert {
  period: string
  price: float
  vwap: float
  message: string
}

type NakedAlert {
  period: string
  level: float
  score: int
  message: string
}

alert (
  vwapCrossUp   = alert(title: "VWAP bullish cross", description: "Close crosses above the reference VWAP", onClose: true, payload: VwapAlert)
  vwapCrossDown = alert(title: "VWAP bearish cross", description: "Close crosses below the reference VWAP", onClose: true, payload: VwapAlert)
  bandUpper     = alert(title: "Extension above σ band", description: "High reaches the upper σ band of the reference VWAP", onClose: true, payload: VwapAlert)
  bandLower     = alert(title: "Extension below σ band", description: "Low reaches the lower σ band of the reference VWAP", onClose: true, payload: VwapAlert)
  nakedTouched  = alert(title: "Naked VWAP touched", description: "Price mitigates a Naked VWAP", onClose: true, payload: NakedAlert)
)

// ----------------------------------------------------------------------------
// Records
// ----------------------------------------------------------------------------
type NakedLevel {
  id: int
  code: string
  level: float
  startTime: time
  touched: bool
  score: int   // R: weighted volume / |delta| percentile
  vS: int      // volume percentile 0-100
  dS: int      // |delta| percentile, signed by the delta direction
  dev: float   // σ of the closed period (naked σ bands)
  b1u: bool    // band touched flags: +1σ, -1σ, +2σ, -2σ
  b1d: bool
  b2u: bool
  b2d: bool
}

type NakedScore {
  r: int
  v: int
  d: int
}

// Peak / Trough anchored accumulator (current + previous period).
// PV = Σ src·vol, V = Σ vol, P2 = Σ src²·vol (for σ).
type PeakTrough {
  hi: float
  lo: float
  hiPV: float
  hiV: float
  hiP2: float
  loPV: float
  loV: float
  loP2: float
  pHiPV: float
  pHiV: float
  pHiP2: float
  pLoPV: float
  pLoV: float
  pLoP2: float
  hiD: float    // delta since anchor (naked AVWAP score)
  loD: float
  pHiD: float
  pLoD: float
  full: bool    // current period observed from its first bar
  hasPH: bool
  hasPL: bool
  usedPH: bool  // previous-high AVWAP touched since it was anchored
  usedPL: bool
  newHi: bool   // line re-anchors (jumps) on this bar
  newLo: bool
  newPH: bool
  newPL: bool
  pNewHi: bool  // same flags, previous bar
  pNewLo: bool
  pNewPH: bool
  pNewPL: bool

  // keep: a previous-period AVWAP not yet touched survives the period change.
  // eh / el: prices that set the period high / low (wick or close); h / l: touch test.
  fn step(isNew: bool, eh: float, el: float, h: float, l: float, pv: float, p2: float, vol: float, dlt: float, keep: bool) {
    self.pNewHi = self.newHi
    self.pNewLo = self.newLo
    self.pNewPH = self.newPH
    self.pNewPL = self.newPL
    if isNew {
      // The first period seen is partial (history starts mid-period): its
      // high/low are not the real ones, so it never becomes "previous"
      let roll = self.full && self.hiV > 0.0 && self.loV > 0.0
      self.full = true
      if roll {
        self.newPH = self.hasPH
        self.newPL = self.hasPL
        self.pHiPV = self.hiPV
        self.pHiV = self.hiV
        self.pHiP2 = self.hiP2
        self.pHiD = self.hiD
        self.hasPH = true
        self.usedPH = false
        self.pLoPV = self.loPV
        self.pLoV = self.loV
        self.pLoP2 = self.loP2
        self.pLoD = self.loD
        self.hasPL = true
        self.usedPL = false
      } else {
        self.newPH = false
        self.newPL = false
      }
      self.hi = eh
      self.lo = el
      self.hiPV = pv
      self.hiV = vol
      self.hiP2 = p2
      self.loPV = pv
      self.loV = vol
      self.loP2 = p2
      self.hiD = dlt
      self.loD = dlt
      self.newHi = true
      self.newLo = true
    } else {
      let nh = eh > self.hi
      let nl = el < self.lo
      if nh {
        self.hi = eh
        self.hiPV = pv
        self.hiV = vol
        self.hiP2 = p2
        self.hiD = dlt
      } else {
        self.hiPV += pv
        self.hiV += vol
        self.hiP2 += p2
        self.hiD += dlt
      }
      if nl {
        self.lo = el
        self.loPV = pv
        self.loV = vol
        self.loP2 = p2
        self.loD = dlt
      } else {
        self.loPV += pv
        self.loV += vol
        self.loP2 += p2
        self.loD += dlt
      }
      self.newHi = nh
      self.newLo = nl
      self.newPH = false
      self.newPL = false
    }
    self.pHiPV += pv
    self.pHiV += vol
    self.pHiP2 += p2
    self.pLoPV += pv
    self.pLoV += vol
    self.pLoP2 += p2
    self.pHiD += dlt
    self.pLoD += dlt
    if self.hasPH && self.pHiV > 0.0 {
      let v = self.pHiPV / self.pHiV
      if l <= v && h >= v {
        self.usedPH = true
      }
    }
    if self.hasPL && self.pLoV > 0.0 {
      let v = self.pLoPV / self.pLoV
      if l <= v && h >= v {
        self.usedPL = true
      }
    }
  }
}

// Session accumulator; outside the session the last value/σ are kept.
type Sess {
  pv: float
  v: float
  p2: float
  last: float?
  lastD: float?

  fn step(inS: bool, isStart: bool, wasIn: bool, pv: float, p2: float, vol: float) {
    if isStart {
      self.pv = pv
      self.v = vol
      self.p2 = p2
    } else if inS {
      self.pv += pv
      self.v += vol
      self.p2 += p2
    } else if wasIn && self.v > 0.0 {
      self.last = self.pv / self.v
      self.lastD = devOf(self.pv, self.v, self.p2, true)
    }
  }

  fn value(inS: bool) -> float? {
    return inS && self.v > 0.0 ? self.pv / self.v : self.last
  }

  fn dev(inS: bool) -> float? {
    return inS && self.v > 0.0 ? devOf(self.pv, self.v, self.p2, true) : self.lastD
  }
}

state (
  // Naked VWAPs
  nvLines   = entities.linePool(max: nvMax)
  nvMarginL = entities.labelPool(max: nvMax, anchor: anchor.right)
  nvOriginL = entities.labelPool(max: nvMax)
  // Touched levels (birth -> touch), kept apart from the live pools so the
  // visual history survives level recycling
  nvHistL   = entities.linePool(max: nvHistMax)
  nvHistT   = entities.labelPool(max: nvHistMax)
  levels    = NakedLevel[](nvMax)
  nextNvId: int = 1
  // Naked badges (keys 0-47) and line tags (keys 100+): one pool, M5 allows
  // at most 16 drawing groups per script
  nvBadgeL  = entities.labelPool(max: 70, anchor: anchor.right)
  // Live high/low AVWAP legs: keys (leg, generation, segment, part)
  liveL     = entities.linePool(max: lvOn ? 2000 : 1)
  liveF     = entities.lineFillPool(max: lvOn ? 1000 : 1)
  lvT       = time[](1536)
  lvV       = float[](1536)
  lvD       = float[](1536)
  lvLen     = int[](6)
  lvCnt     = int[](6)
  lvGen     = int[](6)
  lvTT      = time[](6)
  lvTV      = float[](6)
  lvTD      = float[](6)
  // Re-anchor joins: the first two bars of a re-anchored AVWAP (plotted
  // transparent to hide the jump) redrawn as segments from the anchor bar
  // One pool for anchor legs (keys 0-5: period*2 + side) and re-anchor joins
  // (keys 100+): M5 allows at most 16 drawing groups per script
  anchL     = entities.linePool(max: 2000)
  jCnt      = int[](12)
  jVal      = float[](24)
  jPh       = int[](12)
  jTm       = time[](2)   // [previous bar, current bar], set by the handler
  topIds    = int[](48)
  nvBandL   = entities.linePool(max: nvMax * 4)
  hudN: int = 1
  topSig: int = -1

  // HUD
  hudLabels = entities.labelPool(max: 16, anchor: hudTop ? (hudRight ? anchor.topRight : anchor.topLeft) : (hudRight ? anchor.bottomRight : anchor.bottomLeft))

  // Last value of every periodic VWAP (naked capture / alerts)
  last4H_V: float? = null
  lastD_V:  float? = null
  lastW_V:  float? = null
  lastM_V:  float? = null
  lastQ_V:  float? = null
  lastY_V:  float? = null
  last4H_D: float? = null
  lastD_D:  float? = null
  lastW_D:  float? = null
  lastM_D:  float? = null
  lastQ_D:  float? = null
  lastY_D:  float? = null
  prevRefV: float? = null

  // Period volume (naked volume score)
  vol4H: float = 0.0
  volD:  float = 0.0
  volW:  float = 0.0
  volM:  float = 0.0
  volQ:  float = 0.0
  volY:  float = 0.0
  hist4H  = rolling<float>(50)
  histDl4H = rolling<float>(50)
  dlt4H: float = 0.0
  seen4H: bool = false
  histD   = rolling<float>(50)
  histDlD  = rolling<float>(50)
  dltD : float = 0.0
  seenD : bool = false
  histW   = rolling<float>(50)
  histDlW  = rolling<float>(50)
  dltW : float = 0.0
  seenW : bool = false
  histM   = rolling<float>(50)
  histDlM  = rolling<float>(50)
  dltM : float = 0.0
  seenM : bool = false
  histQ   = rolling<float>(50)
  histDlQ  = rolling<float>(50)
  dltQ : float = 0.0
  seenQ : bool = false
  histY   = rolling<float>(50)
  histDlY  = rolling<float>(50)
  dltY : float = 0.0
  seenY : bool = false

  // Naked AVWAP score history (abandoned previous high/low AVWAPs)
  histAM  = rolling<float>(50)
  histDlAM = rolling<float>(50)
  histAW  = rolling<float>(50)
  histDlAW = rolling<float>(50)
  histAD  = rolling<float>(50)
  histDlAD = rolling<float>(50)
  // Session naked score history
  histAS  = rolling<float>(50)
  histDlAS = rolling<float>(50)
  dltAS: float = 0.0
  seenAS: bool = false
  histLN  = rolling<float>(50)
  histDlLN = rolling<float>(50)
  dltLN: float = 0.0
  seenLN: bool = false
  histNY  = rolling<float>(50)
  histDlNY = rolling<float>(50)
  dltNY: float = 0.0
  seenNY: bool = false
  histNC  = rolling<float>(50)
  histDlNC = rolling<float>(50)
  dltNC: float = 0.0
  seenNC: bool = false

  // Sessions
  sAsia:   Sess = Sess { pv: 0.0, v: 0.0, p2: 0.0, last: null, lastD: null }
  sLondon: Sess = Sess { pv: 0.0, v: 0.0, p2: 0.0, last: null, lastD: null }
  sNY:     Sess = Sess { pv: 0.0, v: 0.0, p2: 0.0, last: null, lastD: null }
  sClose:  Sess = Sess { pv: 0.0, v: 0.0, p2: 0.0, last: null, lastD: null }

  // Anchor legs: the stretch of a previous high/low AVWAP inside its own
  // period (anchor -> period end), drawn when the period closes
  legMHt = time[](256)
  legMHv = float[](256)
  legMHn: int = 0
  legMHlt: time? = null
  legMHlv: float = 0.0
  legMLt = time[](256)
  legMLv = float[](256)
  legMLn: int = 0
  legMLlt: time? = null
  legMLlv: float = 0.0
  legMIdx: int = 0
  legMJoin: bool = false
  legWHt = time[](256)
  legWHv = float[](256)
  legWHn: int = 0
  legWHlt: time? = null
  legWHlv: float = 0.0
  legWLt = time[](256)
  legWLv = float[](256)
  legWLn: int = 0
  legWLlt: time? = null
  legWLlv: float = 0.0
  legWIdx: int = 0
  legWJoin: bool = false
  legDHt = time[](256)
  legDHv = float[](256)
  legDHn: int = 0
  legDHlt: time? = null
  legDHlv: float = 0.0
  legDLt = time[](256)
  legDLv = float[](256)
  legDLn: int = 0
  legDLlt: time? = null
  legDLlv: float = 0.0
  legDIdx: int = 0
  legDJoin: bool = false

  // Peak / Trough
  ptM: PeakTrough = PeakTrough { hi: -1.0, lo: 1e18, hiPV: 0.0, hiV: 0.0, hiP2: 0.0, loPV: 0.0, loV: 0.0, loP2: 0.0, pHiPV: 0.0, pHiV: 0.0, pHiP2: 0.0, pLoPV: 0.0, pLoV: 0.0, pLoP2: 0.0, hiD: 0.0, loD: 0.0, pHiD: 0.0, pLoD: 0.0, full: false, hasPH: false, hasPL: false, usedPH: false, usedPL: false, newHi: false, newLo: false, newPH: false, newPL: false, pNewHi: false, pNewLo: false, pNewPH: false, pNewPL: false }
  ptW: PeakTrough = PeakTrough { hi: -1.0, lo: 1e18, hiPV: 0.0, hiV: 0.0, hiP2: 0.0, loPV: 0.0, loV: 0.0, loP2: 0.0, pHiPV: 0.0, pHiV: 0.0, pHiP2: 0.0, pLoPV: 0.0, pLoV: 0.0, pLoP2: 0.0, hiD: 0.0, loD: 0.0, pHiD: 0.0, pLoD: 0.0, full: false, hasPH: false, hasPL: false, usedPH: false, usedPL: false, newHi: false, newLo: false, newPH: false, newPL: false, pNewHi: false, pNewLo: false, pNewPH: false, pNewPL: false }
  ptD: PeakTrough = PeakTrough { hi: -1.0, lo: 1e18, hiPV: 0.0, hiV: 0.0, hiP2: 0.0, loPV: 0.0, loV: 0.0, loP2: 0.0, pHiPV: 0.0, pHiV: 0.0, pHiP2: 0.0, pLoPV: 0.0, pLoV: 0.0, pLoP2: 0.0, hiD: 0.0, loD: 0.0, pHiD: 0.0, pLoD: 0.0, full: false, hasPH: false, hasPL: false, usedPH: false, usedPL: false, newHi: false, newLo: false, newPH: false, newPL: false, pNewHi: false, pNewLo: false, pNewPH: false, pNewPL: false }

  // Custom AVWAP
  custAnchored: bool = false

  // Projections of closed periods (live set re-anchored on each reset;
  // finished sets go to the history pools)
  projLiveL = entities.linePool(max: 300)
  projLiveF = entities.lineFillPool(max: 300)
  projHistL = entities.linePool(max: 2000)
  projHistF = entities.lineFillPool(max: 2000)
  nextProjId: int = 1
  pjV4H = rolling<float>(10)
  pjS4H = rolling<float>(10)
  pjT4H: time? = null
  pjVD = rolling<float>(10)
  pjSD = rolling<float>(10)
  pjTD: time? = null
  pjVW = rolling<float>(10)
  pjSW = rolling<float>(10)
  pjTW: time? = null
  pjVM = rolling<float>(10)
  pjSM = rolling<float>(10)
  pjTM: time? = null
  pjVQ = rolling<float>(10)
  pjSQ = rolling<float>(10)
  pjTQ: time? = null
  pjVY = rolling<float>(10)
  pjSY = rolling<float>(10)
  pjTY: time? = null

  // Rolling VWAP running sums over time buckets
  r1PV = rolling<float>(rollCap1)
  r1V  = rolling<float>(rollCap1)
  r1SumPV: float = 0.0
  r1SumV:  float = 0.0
  r1CurPV: float = 0.0
  r1CurV:  float = 0.0
  r1P2 = rolling<float>(rollCap1)
  r1SumP2: float = 0.0
  r1CurP2: float = 0.0
  r2PV = rolling<float>(rollCap2)
  r2V  = rolling<float>(rollCap2)
  r2SumPV: float = 0.0
  r2SumV:  float = 0.0
  r2CurPV: float = 0.0
  r2CurV:  float = 0.0
  r2P2 = rolling<float>(rollCap2)
  r2SumP2: float = 0.0
  r2CurP2: float = 0.0
  r3PV = rolling<float>(rollCap3)
  r3V  = rolling<float>(rollCap3)
  r3SumPV: float = 0.0
  r3SumV:  float = 0.0
  r3CurPV: float = 0.0
  r3CurV:  float = 0.0
  r3P2 = rolling<float>(rollCap3)
  r3SumP2: float = 0.0
  r3CurP2: float = 0.0
)

// ----------------------------------------------------------------------------
// Pure helpers
// ----------------------------------------------------------------------------
fn devOf(pv: float, v: float, p2: float, ok: bool) -> float? {
  if !ok || v <= 0.0 {
    return null
  }
  let m = pv / v
  return math.sqrt(math.max(0.0, p2 / v - m * m))
}

// Jump-free reset: on the reset bar plot the OLD value invisible, on the
// next bar the NEW value invisible, so the jump segment never shows whichever
// endpoint the renderer colors it from. Nulls are bridged, and
// color.transparent (#00000000) is ignored as an override, hence `invisible`.
fn plotSeg(p: PlotLine, col: color, enabled: bool, hidden: bool, jNow: bool, jPrev: bool, oldV: float?, newV: float?) {
  let gap: float? = null
  if !enabled {
    p.plot(gap, color: invisible)
  } else if jNow {
    p.plot(oldV ?? newV, color: invisible)
  } else {
    p.plot(newV, color: hidden || jPrev ? invisible : col)
  }
}

fn alpha(a: float) -> int {
  return int(math.round(a)) ?? 0
}

fn ratio(pv: float, v: float, ok: bool) -> float? {
  return ok && v > 0.0 ? pv / v : null
}

// Percentile rank (0-100) of x among the last nvScoreN closed periods of the
// same type. Percentiles instead of the original normal-CDF z: period volume
// is heavily right-skewed, so a z-score overrates outliers.
fn pctRank(x: float, hist: rolling<float>, absMode: bool) -> int {
  let n = math.min(nvScoreN, hist.len)
  if n < 3 {
    return 50
  }
  let xv = absMode ? math.abs(x) : x
  let below = 0.0
  for k in 0..n {
    let hv = hist[hist.len - 1 - k] ?? 0.0
    let a = absMode ? math.abs(hv) : hv
    if a < xv {
      below += 1.0
    }
    if a == xv {
      below += 0.5
    }
  }
  return int(math.round(100.0 * below / float(n))) ?? 50
}

// R = weighted volume / |delta| percentile. Unlike the original, delta is
// ranked by magnitude, so a strong sell imbalance scores high (its sign is
// kept in dS and in the score color).
fn nakedScore(vol: float, dlt: float, hv: rolling<float>, hd: rolling<float>) -> NakedScore {
  let v = pctRank(vol, hv, false)
  let dm = pctRank(dlt, hd, true)
  let wv = math.max(0.0, nvWVol)
  let wd = math.max(0.0, nvWDelta)
  let r = int(math.round((wv * float(v) + wd * float(dm)) / math.max(0.000001, wv + wd))) ?? 50
  return NakedScore { r: r, v: v, d: dlt >= 0.0 ? dm : -dm }
}

fn fmtPx(x: float) -> string {
  if x >= 100.0 {
    return str.format("{0:.2}", x)
  }
  if x >= 1.0 {
    return str.format("{0:.4}", x)
  }
  return str.format("{0:.6}", x)
}

fn scoreText(lvl: NakedLevel) -> string {
  let ds = lvl.dS >= 0 ? str.format("+{0}", lvl.dS) : str.format("{0}", lvl.dS)
  if nvScoreMode == "R" {
    return str.format("R{0}", lvl.score)
  }
  if nvScoreMode == "R + V" {
    return str.format("R{0} · V{1}", lvl.score, lvl.vS)
  }
  return str.format("R{0} · V{1} · Δ{2}", lvl.score, lvl.vS, ds)
}

fn scoreColor(lvl: NakedLevel) -> color {
  if !nvScoreByDelta {
    return nakedColor(lvl.code)
  }
  return lvl.dS >= 0 ? color.rgb(102, 187, 106) : color.rgb(239, 83, 80)
}

fn isTop(id: int) -> bool {
  for k in 0..topIds.len {
    if topIds[k] == id {
      return true
    }
  }
  return false
}

fn periodColor(code: string) -> color {
  return match code {
    "4H" => color4H
    "D" => colorDaily
    "W" => colorWeekly
    "M" => colorMonthly
    "Q" => colorQuarterly
    _ => colorYearly
  }
}

fn nakedColor(code: string) -> color {
  return match code {
    "4H" => nvCol4H
    "D" => nvColD
    "W" => nvColW
    "M" => nvColM
    "Q" => nvColQ
    "Y" => nvColY
    "AS" => colSessAsia
    "LN" => colSessLondon
    "NY" => colSessNY
    "NC" => colSessClose
    "MH" => colPrevMonthHigh
    "ML" => colPrevMonthLow
    "WH" => colPrevWeekHigh
    "WL" => colPrevWeekLow
    "DH" => colPrevDayHigh
    _ => colPrevDayLow
  }
}

// Naked σ band j (0:+1σ 1:-1σ 2:+2σ 3:-2σ)
fn bandY(lvl: NakedLevel, j: int) -> float {
  return match j {
    0 => lvl.level + std1Mult * lvl.dev
    1 => lvl.level - std1Mult * lvl.dev
    2 => lvl.level + std2Mult * lvl.dev
    _ => lvl.level - std2Mult * lvl.dev
  }
}

fn bandOn(lvl: NakedLevel, j: int) -> bool {
  let done = match j {
    0 => lvl.b1u
    1 => lvl.b1d
    2 => lvl.b2u
    _ => lvl.b2d
  }
  return lvl.dev > 0.0 && !done && (j < 2 ? nvStd1On : nvStd2On)
}

fn withTouch(lvl: NakedLevel, t: bool, a: bool, b: bool, c2: bool, d: bool) -> NakedLevel {
  return NakedLevel { id: lvl.id, code: lvl.code, level: lvl.level, startTime: lvl.startTime, touched: t, score: lvl.score, vS: lvl.vS, dS: lvl.dS, dev: lvl.dev, b1u: a, b1d: b, b2u: c2, b2d: d }
}

fn hitRange(y: float, lo: float, hi: float, tol: float) -> bool {
  return lo <= y + tol && hi >= y - tol
}

fn nakedTag(lvl: NakedLevel) -> string {
  let base = str.format("NVWAP {0}", lvl.code)
  if showNvPrice && showScores {
    return str.format("{0} · {1} · {2}", base, fmtPx(lvl.level), scoreText(lvl))
  }
  if showNvPrice {
    return str.format("{0} · {1}", base, fmtPx(lvl.level))
  }
  if showScores {
    return str.format("{0} · {1}", base, scoreText(lvl))
  }
  return base
}

fn deleteNakedEntities(id: int) {
  let _ = nvLines.delete(id)
  let _ = nvMarginL.delete(id)
  let _ = nvOriginL.delete(id)
  for j in 0..4 {
    let _ = nvBandL.delete(id * 4 + j)
  }
}

fn nakedLine(lvl: NakedLevel, now: time) {
  let x2 = nvExtend ? time.shiftBars(lvl.startTime, 1) : now
  let x2b = nvStdExtend ? time.shiftBars(lvl.startTime, 1) : now
  nvLines.get(lvl.id).set(
    x1: lvl.startTime, y1: lvl.level, x2: x2, y2: lvl.level,
    color: nvDim && topSig >= 0 && !isTop(lvl.id) ? color.withAlpha(nakedColor(lvl.code), nvDimA) : nakedColor(lvl.code),
    width: nvLineWidth, style: nvStyle, extend: nvExt
  )
  if nvStd1On {
    let dim = nvDim && topSig >= 0 && !isTop(lvl.id)
    for j in 0..4 {
      if bandOn(lvl, j) {
        let bc = j < 2 ? std1Color : std2Color
        nvBandL.get(lvl.id * 4 + j).set(
          x1: lvl.startTime, y1: bandY(lvl, j), x2: x2b, y2: bandY(lvl, j),
          color: color.withAlpha(bc, dim ? alpha(float(nvDimA) * 0.5) : 150), width: 1.0, style: linestyle.dotted, extend: nvBandExt
        )
      }
    }
  }
}

fn drawNakedAlive(lvl: NakedLevel) {
  let col = nakedColor(lvl.code)
  nakedLine(lvl, chart.time ?? lvl.startTime)
  if nvMargin || nvOrigin {
    let tag = nakedTag(lvl)
    let y = lvl.level * lblFactor
    if nvMargin {
      nvMarginL.get(lvl.id).set(x: 8.0, y: y, text: tag, color: col, size: nvBadgeSize, textAlign: "right", zIndex: 40)
    }
    if nvOrigin {
      nvOriginL.get(lvl.id).set(x: lvl.startTime, y: y, text: tag, color: col, size: nvBadgeSize, zIndex: 40)
    }
  }
}

fn registerNakedLevel(code: string, lvl: float, dev: float, t: time, sc: NakedScore) {
  let newLvl = NakedLevel { id: nextNvId, code: code, level: lvl, startTime: t, touched: false, score: sc.r, vS: sc.v, dS: sc.d, dev: dev, b1u: false, b1d: false, b2u: false, b2d: false }
  nextNvId += 1
  if levels.len < levels.capacity {
    levels.push(newLvl)
  } else {
    // Replace the oldest touched level; if none, the oldest alive one.
    let repIdx = 0
    let bestTouched = false
    let bestId = 2147483647
    for k in 0..levels.len {
      let it = levels.get(k)
      if it != null {
        let better = (it.touched && !bestTouched) || (it.touched == bestTouched && it.id < bestId)
        if better {
          repIdx = k
          bestTouched = it.touched
          bestId = it.id
        }
      }
    }
    deleteNakedEntities(bestId)
    levels.set(repIdx, newLvl)
  }
  drawNakedAlive(newLvl)
}

// ±1σ/±2σ bands + fills of a non-periodic VWAP (same jump-free cut as
// plotSeg). Band lines needed only as fill edges are plotted invisible.
fn drawBands2(c1: color, c2: color, en: bool, hidden: bool, fillOk: bool, jNow: bool, jPrev: bool, ov: float?, od: float?, v: float?, d: float?, s1u: PlotLine, s1d: PlotLine, s2u: PlotLine, s2d: PlotLine, f1: Fill, f2u: Fill, f2d: Fill, ring: bool) {
  let bOn = en && v != null && d != null
  let wantF1 = fillOk && fillStd1
  let wantF2 = fillOk && fillStd2 && ring
  let need1 = bOn && (showStd1 || wantF1 || wantF2)
  let need2 = bOn && (showStd2 || wantF2)
  let vv = v ?? 0.0
  let dd = d ?? 0.0
  let oOk = ov != null && od != null
  let ovv = ov ?? 0.0
  let odd = od ?? 0.0
  plotSeg(s1u, c1, need1, hidden || !showStd1, jNow, jPrev, oOk ? ovv + std1Mult * odd : null, vv + std1Mult * dd)
  plotSeg(s1d, c1, need1, hidden || !showStd1, jNow, jPrev, oOk ? ovv - std1Mult * odd : null, vv - std1Mult * dd)
  plotSeg(s2u, c2, need2, hidden || !showStd2, jNow, jPrev, oOk ? ovv + std2Mult * odd : null, vv + std2Mult * dd)
  plotSeg(s2d, c2, need2, hidden || !showStd2, jNow, jPrev, oOk ? ovv - std2Mult * odd : null, vv - std2Mult * dd)
  if bOn && !hidden && !jNow && !jPrev {
    if wantF1 {
      f1.fill()
    }
    if wantF2 {
      f2u.fill()
      f2d.fill()
    }
  }
}

// Axis-side tag for a line that can be hidden (an invisible plot point would
// still draw its axis label as a white tag). key < 0: no tag.
fn lineTag(key: int, show: bool, v: float?, name: string, col: color) {
  if key >= 0 && chart.isLast {
    if show && v != null {
      nvBadgeL.get(100 + key).set(x: 8.0, y: v ?? 0.0, text: str.format("{0}  {1}", name, fmtPx(v ?? 0.0)), color: col, size: 11.0, textAlign: "right", zIndex: 35)
    } else {
      let _ = nvBadgeL.delete(100 + key)
    }
  }
}

// Join segments for anchored line jk: anchor bar -> +1 -> +2. vis = drawn.
// ap: anchor price (the high/low itself) so the line starts at the wick.
fn joinSeg(t0: time?, tn: time, jk: int, vis: bool, jn: bool, jp: bool, ap: float?, nv: float?, col: color, w: float, st: LineStyle) {
  // jPh: 0 idle, 1 anchor point stored, 2 second point stored (no nulls kept)
  if jPh.len == 0 {
    for i in 0..24 {
      jVal.push(0.0)
    }
    for i in 0..12 {
      jPh.push(0)
      jCnt.push(0)
    }
  }
  let ph = jPh.get(jk) ?? 0
  // Bar times come from the handler: series history is not available inside fn
  let y = nv ?? 0.0
  let ok = nv != null && t0 != null
  let n = jCnt.get(jk) ?? 0
  if jn {
    jCnt[jk] = n < 1000 ? n + 1 : 0
    let a = ap ?? y
    jVal[jk * 2] = a
    jPh[jk] = nv != null ? 1 : 0
  } else if jp {
    if ph == 1 && ok {
      if vis && t0 != null {
        anchL.get(100 + jk, n, 0).set(x1: t0, y1: jVal.get(jk * 2) ?? y, x2: tn, y2: y, color: col, width: w, style: st, extend: extend.none)
      }
      jVal[jk * 2 + 1] = y
      jPh[jk] = 2
    } else {
      jPh[jk] = 0
    }
  } else if ph == 2 {
    if ok && vis && t0 != null {
      anchL.get(100 + jk, n, 1).set(x1: t0, y1: jVal.get(jk * 2 + 1) ?? y, x2: tn, y2: y, color: col, width: w, style: st, extend: extend.none)
    }
    jPh[jk] = 0
  }
}

// Live high/low AVWAP legs. While ptHideOld is on, the current high/low
// AVWAPs are entities instead of plots so a superseded anchor can be erased;
// a finished period keeps its final leg, compacted to <= 16 segments.
// Leg ids: 0 MH, 1 ML, 2 WH, 3 WL, 4 DH, 5 DL. Segment 999 is the live tail.
fn lvDraw(id: int, gen: int, j: int, t1: time, v1: float, d1: float, t2: time, v2: float, d2: float, col: color, w: float, b1: bool, b2: bool, fl: bool) {
  liveL.get(id, gen, j, 0).set(x1: t1, y1: v1, x2: t2, y2: v2, color: col, width: w, style: linestyle.solid, extend: extend.none, zIndex: 5)
  if b1 || fl {
    let c1 = b1 ? color.withAlpha(col, 150) : invisible
    let u = liveL.get(id, gen, j, 1)
    u.set(x1: t1, y1: v1 + std1Mult * d1, x2: t2, y2: v2 + std1Mult * d2, color: c1, width: 1.0, style: linestyle.dashed, extend: extend.none)
    let dn = liveL.get(id, gen, j, 2)
    dn.set(x1: t1, y1: v1 - std1Mult * d1, x2: t2, y2: v2 - std1Mult * d2, color: c1, width: 1.0, style: linestyle.dashed, extend: extend.none)
    if fl {
      liveF.get(id, gen, j).set(lineA: u, lineB: dn, color: color.withAlpha(col, fillA))
    }
  }
  if b2 {
    let c2 = color.withAlpha(col, 110)
    liveL.get(id, gen, j, 3).set(x1: t1, y1: v1 + std2Mult * d1, x2: t2, y2: v2 + std2Mult * d2, color: c2, width: 1.0, style: linestyle.dashed, extend: extend.none)
    liveL.get(id, gen, j, 4).set(x1: t1, y1: v1 - std2Mult * d1, x2: t2, y2: v2 - std2Mult * d2, color: c2, width: 1.0, style: linestyle.dashed, extend: extend.none)
  }
}

// Redraw a finished leg with at most 16 segments, denser near the anchor
fn lvCompact(id: int, gen: int, len: int, col: color, w: float, b1: bool, b2: bool, fl: bool) {
  if len > 17 {
    let base = id * 256
    let _ = liveL.clear(id, gen)
    let _ = liveF.clear(id, gen)
    let pi = 0
    for s in 1..17 {
      let f = float(s) / 16.0
      let idx = int(math.round(f * f * float(len - 1))) ?? (len - 1)
      if idx > pi {
        let tA = lvT.get(base + pi)
        let tB = lvT.get(base + idx)
        if tA != null && tB != null {
          lvDraw(id, gen, s, tA, lvV.get(base + pi) ?? 0.0, lvD.get(base + pi) ?? 0.0, tB, lvV.get(base + idx) ?? 0.0, lvD.get(base + idx) ?? 0.0, col, w, b1, b2, fl)
        }
        pi = idx
      }
    }
    let tl = lvT.get(base + len - 1)
    let te = lvTT.get(id)
    if tl != null && te != null && time.diff(te, tl) > 0s {
      lvDraw(id, gen, 999, tl, lvV.get(base + len - 1) ?? 0.0, lvD.get(base + len - 1) ?? 0.0, te, lvTV.get(id) ?? 0.0, lvTD.get(id) ?? 0.0, col, w, b1, b2, fl)
    }
  }
}

// One bar of a live leg. roll: period change (finish + keep the old leg);
// newEx: new high/low inside the period (erase the superseded leg).
fn liveLeg(id: int, act: bool, roll: bool, newEx: bool, ts: time, ap: float, v: float?, d: float?, bars: float, keep: int, col: color, w: float, b1: bool, b2: bool, fl: bool, name: string) {
  if lvLen.len == 0 {
    for i in 0..1536 {
      lvT.push(ts)
      lvV.push(0.0)
      lvD.push(0.0)
    }
    for i in 0..6 {
      lvLen.push(0)
      lvCnt.push(0)
      lvGen.push(0)
      lvTT.push(ts)
      lvTV.push(0.0)
      lvTD.push(0.0)
    }
  }
  let base = id * 256
  let len = lvLen.get(id) ?? 0
  let gen = lvGen.get(id) ?? 0
  if roll {
    lvCompact(id, gen, len, col, w, b1, b2, fl)
    let _ = liveL.clear(id, gen - keep)
    let _ = liveF.clear(id, gen - keep)
    gen = gen + 1
    len = 0
  } else if newEx {
    let _ = liveL.clear(id, gen)
    let _ = liveF.clear(id, gen)
    len = 0
  }
  if act && v != null {
    let vv = v ?? 0.0
    let dd = d ?? 0.0
    let stride = math.max(1, int(math.floor(bars / float(lvP))) ?? 1)
    let n = (lvCnt.get(id) ?? 0) + 1
    let pushed = false
    if len == 0 {
      // Anchor sample at the high / low itself: the leg starts at the wick
      lvT[base] = ts
      lvV[base] = ap
      lvD[base] = 0.0
      len = 1
      lvCnt[id] = 0
      pushed = true
    } else if (n >= stride || len < 12) && len < lvCap {
      let tA = lvT.get(base + len - 1)
      if tA != null {
        lvDraw(id, gen, len - 1, tA, lvV.get(base + len - 1) ?? vv, lvD.get(base + len - 1) ?? 0.0, ts, vv, dd, col, w, b1, b2, fl)
      }
      lvT[base + len] = ts
      lvV[base + len] = vv
      lvD[base + len] = dd
      len = len + 1
      lvCnt[id] = 0
      pushed = true
    } else {
      lvCnt[id] = n
    }
    if pushed {
      let _ = liveL.clear(id, gen, 999)
      let _ = liveF.clear(id, gen, 999)
    } else {
      let tA = lvT.get(base + len - 1)
      if tA != null {
        lvDraw(id, gen, 999, tA, lvV.get(base + len - 1) ?? vv, lvD.get(base + len - 1) ?? 0.0, ts, vv, dd, col, w, b1, b2, fl)
      }
    }
    lvTT[id] = ts
    lvTV[id] = vv
    lvTD[id] = dd
    lineTag(10 + id, true, vv, name, col)
  } else {
    lineTag(10 + id, false, null, name, col)
  }
  lvLen[id] = len
  lvGen[id] = gen
}

// One anchored VWAP (PV/V/P2 sums) with its bands; o* = values before step.
fn drawAnch(jk: int, ap: float?, key: int, name: string, col: color, en: bool, hide: bool, bands: bool, fillOn: bool, jNow: bool, jPrev: bool, oPV: float, oV: float, oP2: float, oOk: bool, pv: float, v: float, p2: float, p: PlotLine, s1u: PlotLine, s1d: PlotLine, s2u: PlotLine, s2d: PlotLine, f1: Fill) {
  let jn = cutOnReset && jNow
  let jp = cutOnReset && jPrev
  let ov = ratio(oPV, oV, oOk)
  let nv = ratio(pv, v, true)
  plotSeg(p, col, en, hide, jn, jp, ov, nv)
  if cutOnReset {
    // M5 stops scripts whose fns take too many params: width/style derive from jk
    let jw = jk < 4 ? 2.0 : 1.5
    let isPrev = jk == 2 || jk == 3 || jk == 6 || jk == 7 || jk == 10 || jk == 11
    if jTm.len == 2 {
      joinSeg(jTm.get(0), jTm.get(1) ?? chart.time ?? jTm.get(0) ?? time.fromUnixSeconds(0), jk, en && !hide, jn, jp, ap, nv, col, jw, isPrev ? linestyle.dashed : linestyle.solid)
    }
  }
  lineTag(key, en && !hide, nv, name, col)
  drawBands2(color.withAlpha(col, 150), color.withAlpha(col, 110), en && bands, hide, fillOn, jn, jp, ov, devOf(oPV, oV, oP2, oOk), nv, devOf(pv, v, p2, true), s1u, s1d, s2u, s2d, f1, f1, f1, false)
}

// One session VWAP with its bands; o = accumulator before step.
fn drawSess(key: int, name: string, col: color, show: bool, bands: bool, fillOn: bool, inS: bool, wasIn: bool, wasIn2: bool, o: Sess, n: Sess, p: PlotLine, s1u: PlotLine, s1d: PlotLine, s2u: PlotLine, s2d: PlotLine, f1: Fill, f2u: Fill, f2d: Fill) {
  let hidden = !inS && !extendSessVWAP
  let jNow = cutOnReset && inS && !wasIn
  let jPrev = cutOnReset && wasIn && !wasIn2
  let ov = o.value(wasIn)
  let nv = n.value(inS)
  plotSeg(p, col, show, hidden, jNow, jPrev, ov, nv)
  lineTag(key, show && !hidden, nv, name, col)
  drawBands2(color.withAlpha(col, 150), color.withAlpha(col, 110), show && bands, hidden, fillOn, jNow, jPrev, ov, o.dev(wasIn), nv, n.dev(inS), s1u, s1d, s2u, s2d, f1, f2u, f2d, true)
}

// One set of projected closed-period levels (P-1..P-n, newest last in the
// buffers) as line entities. Keys: base + age*5 + line, base + age*3 + fill.
// Draws one sampled anchor leg as dashed segments, ending at (tEnd, vEnd).
fn drawLeg(pool: LinePool, side: int, idx: int, t: time[], v: float[], tEnd: time, vEnd: float, col: color, w: float) {
  let n = t.len
  for j in 0..n {
    let t1 = t.get(j)
    let v1 = v.get(j)
    let t2 = j + 1 < n ? t.get(j + 1) : tEnd
    let v2 = j + 1 < n ? v.get(j + 1) : vEnd
    if t1 != null && v1 != null && t2 != null && v2 != null {
      pool.get(side, idx, j).set(x1: t1, y1: v1, x2: t2, y2: v2, color: col, width: w, style: linestyle.dashed, extend: extend.none)
    }
  }
}

fn drawProjSet(lines: LinePool, fills: LineFillPool, base: int, x1: time, x2: time, ext: Extend, hv: rolling<float>, hd: rolling<float>, col: color, s1: bool, s2: bool, fl1: bool, fl2: bool) {
  let n = math.min(projCount, hv.len)
  for k in 0..n {
    let vN = hv[hv.len - 1 - k]
    if vN != null {
      let v = vN ?? 0.0
      let d = hd[hd.len - 1 - k] ?? 0.0
      // Original look: 70% transparent lines, 92% transparent fill, fading by age
      let a = math.max(10, 80 - k * 6)
      let fa = math.max(5, 22 - k * 2)
      let kb = base + k * 5
      let fb = base + k * 3
      lines.get(kb).set(x1: x1, y1: v, x2: x2, y2: v, width: projWidth, color: color.withAlpha(col, a), style: linestyle.dashed, extend: ext)
      let s1On = s1 && d > 0.0
      let s2On = s2 && d > 0.0
      if s1On {
        let u1 = lines.get(kb + 1)
        let l1 = lines.get(kb + 2)
        u1.set(x1: x1, y1: v + std1Mult * d, x2: x2, y2: v + std1Mult * d, width: 1.0, color: color.withAlpha(std1Color, a), style: linestyle.dashed, extend: ext)
        l1.set(x1: x1, y1: v - std1Mult * d, x2: x2, y2: v - std1Mult * d, width: 1.0, color: color.withAlpha(std1Color, a), style: linestyle.dashed, extend: ext)
        if fl1 {
          fills.get(fb).set(lineA: u1, lineB: l1, color: color.withAlpha(std1Color, fa))
        }
      }
      if s2On {
        let u2 = lines.get(kb + 3)
        let l2 = lines.get(kb + 4)
        u2.set(x1: x1, y1: v + std2Mult * d, x2: x2, y2: v + std2Mult * d, width: 1.0, color: color.withAlpha(std2Color, a), style: linestyle.dashed, extend: ext)
        l2.set(x1: x1, y1: v - std2Mult * d, x2: x2, y2: v - std2Mult * d, width: 1.0, color: color.withAlpha(std2Color, a), style: linestyle.dashed, extend: ext)
        if fl2 {
          let c2 = color.withAlpha(std2Color, fa)
          if s1On {
            fills.get(fb + 1).set(lineA: u2, lineB: lines.get(kb + 1), color: c2)
            fills.get(fb + 2).set(lineA: lines.get(kb + 2), lineB: l2, color: c2)
          } else {
            fills.get(fb + 1).set(lineA: u2, lineB: l2, color: c2)
          }
        }
      }
    }
  }
}

// Index of the nearest alive naked level of one period to price, skipping
// the ids ex1/ex2 (-1 = none).
fn nearestIdx(code: string, px: float, ex1: int, ex2: int) -> int {
  let best = -1
  let bestD = 1e18
  for i in 0..levels.len {
    let it = levels.get(i)
    if it != null && !it.touched && it.code == code && it.id != ex1 && it.id != ex2 {
      let dist = math.abs(it.level - px)
      if dist < bestD {
        bestD = dist
        best = i
      }
    }
  }
  return best
}

fn idAt(i: int) -> int {
  if i >= 0 {
    let it = levels.get(i)
    if it != null {
      return it.id
    }
  }
  return -1
}

// One axis slot: plot value, score badge beside the axis, top-set entry.
// Returns the slot's contribution to the top-set signature.
fn feedSlot(i: int, a: PlotLine, key: int, show: bool, name: string) -> int {
  let none: float? = null
  if i >= 0 {
    let it = levels.get(i)
    if it != null {
      topIds[key] = it.id
      if show {
        a.plot(it.level)
        // Tag beside the axis price: "NV W 1 · R62 · V70 · Δ+45"
        let tag = showScores ? str.format("{0} · {1}", name, scoreText(it)) : name
        nvBadgeL.get(key).set(x: 8.0, y: it.level * lblFactor, text: tag, color: nakedColor(it.code), size: nvBadgeSize, textAlign: "right", zIndex: 40)
      } else {
        let _ = nvBadgeL.delete(key)
      }
      return it.id * (key + 1)
    }
  }
  topIds[key] = -1
  if show {
    a.plot(none)
  }
  let _ = nvBadgeL.delete(key)
  return 0
}

// Nearest X alive levels of one period: axis labels + badges + top set.
fn axisSlots(code: string, base: int, px: float, show: bool, a1: PlotLine, a2: PlotLine, a3: PlotLine) -> int {
  let i1 = nearestIdx(code, px, -1, -1)
  let i2 = nvAxisSlots >= 2 && i1 >= 0 ? nearestIdx(code, px, idAt(i1), -1) : -1
  let i3 = nvAxisSlots >= 3 && i2 >= 0 ? nearestIdx(code, px, idAt(i1), idAt(i2)) : -1
  return feedSlot(i1, a1, base, show, str.format("NV {0} 1", code)) + feedSlot(i2, a2, base + 1, show, str.format("NV {0} 2", code)) + feedSlot(i3, a3, base + 2, show, str.format("NV {0} 3", code))
}

fn hudRow(row: int, text: string, col: color) {
  let vr = hudTop ? row : hudN - 1 - row
  hudLabels.get(row).set(
    x: 12.0, y: 12.0 + float(vr) * hudLineH, text: text, color: col,
    size: hudSize, font: font.mono, textAlign: hudAlign, zIndex: 60
  )
}

fn hudVwapRow(row: int, name: string, v: float?, d: float?, px: float, col: color) -> int {
  if v == null || v <= 0.0 {
    return row
  }
  let pct = (px - v) / v * 100.0
  let z = d != null && d > 0.0 ? (px - v) / d : 0.0
  hudRow(row, str.format("{0}  {1}  {2:+.2}%  {3:+.1}σ", name, math.round(v, 2), pct, z), col)
  return row + 1
}

// ----------------------------------------------------------------------------
// Main
// ----------------------------------------------------------------------------
on chart.update {
  let tsN = chart.time
  if tsN == null {
    return
  }
  let ts = tsN
  let prevTs = chart.time[1]
  let o = chart.open ?? 0.0
  let h = chart.high ?? 0.0
  let l = chart.low ?? 0.0
  let c = chart.close ?? 0.0
  let vol = chart.volume ?? 0.0
  let src = srcId == 0 ? (h + l + c) / 3.0 : (srcId == 1 ? (o + h + l + c) / 4.0 : (srcId == 2 ? (h + l) / 2.0 : c))
  let pv = src * vol
  let p2 = src * pv

  // --- 1. Period boundaries -------------------------------------------------
  let barSec = float(math.max(1, time.durationSeconds(time.bars(1))))
  let isNew4H = time.isNewPeriod(ts, prevTs, 4h)
  let isNewD  = time.isNewPeriod(ts, prevTs, 1D)
  let isNewW  = time.isNewPeriod(ts, prevTs, 1W)
  let isNewM  = time.isNewPeriod(ts, prevTs, 1M)
  let isNewQ  = time.isNewPeriod(ts, prevTs, 3M)
  let isNewY  = time.isNewPeriod(ts, prevTs, 1Y)
  let hideLive = showNaked && nakedOnlyMode

  // --- 2. Naked VWAP capture (completed periods, scored by relative volume)
  if showNaked && prevTs != null {
    if isNew4H && nk4H && last4H_V != null {
      registerNakedLevel("4H", last4H_V, last4H_D ?? 0.0, prevTs, nakedScore(vol4H, dlt4H, hist4H, histDl4H))
    }
    if isNewD && nkD && lastD_V != null {
      registerNakedLevel("D", lastD_V, lastD_D ?? 0.0, prevTs, nakedScore(volD, dltD, histD, histDlD))
    }
    if isNewW && nkW && lastW_V != null {
      registerNakedLevel("W", lastW_V, lastW_D ?? 0.0, prevTs, nakedScore(volW, dltW, histW, histDlW))
    }
    if isNewM && nkM && lastM_V != null {
      registerNakedLevel("M", lastM_V, lastM_D ?? 0.0, prevTs, nakedScore(volM, dltM, histM, histDlM))
    }
    if isNewQ && nkQ && lastQ_V != null {
      registerNakedLevel("Q", lastQ_V, lastQ_D ?? 0.0, prevTs, nakedScore(volQ, dltQ, histQ, histDlQ))
    }
    if isNewY && nkY && lastY_V != null {
      registerNakedLevel("Y", lastY_V, lastY_D ?? 0.0, prevTs, nakedScore(volY, dltY, histY, histDlY))
    }
  }

  // Period volume bookkeeping (after scoring the completed period)
  if isNew4H {
    // only complete periods feed the score history (the first is partial)
    if seen4H && vol4H > 0.0 {
      hist4H.push(vol4H)
      histDl4H.push(dlt4H)
    }
    seen4H = true
    vol4H = 0.0
    dlt4H = 0.0
  }
  if isNewD {
    // only complete periods feed the score history (the first is partial)
    if seenD && volD > 0.0 {
      histD.push(volD)
      histDlD.push(dltD)
    }
    seenD = true
    volD = 0.0
    dltD = 0.0
  }
  if isNewW {
    // only complete periods feed the score history (the first is partial)
    if seenW && volW > 0.0 {
      histW.push(volW)
      histDlW.push(dltW)
    }
    seenW = true
    volW = 0.0
    dltW = 0.0
  }
  if isNewM {
    // only complete periods feed the score history (the first is partial)
    if seenM && volM > 0.0 {
      histM.push(volM)
      histDlM.push(dltM)
    }
    seenM = true
    volM = 0.0
    dltM = 0.0
  }
  if isNewQ {
    // only complete periods feed the score history (the first is partial)
    if seenQ && volQ > 0.0 {
      histQ.push(volQ)
      histDlQ.push(dltQ)
    }
    seenQ = true
    volQ = 0.0
    dltQ = 0.0
  }
  if isNewY {
    // only complete periods feed the score history (the first is partial)
    if seenY && volY > 0.0 {
      histY.push(volY)
      histDlY.push(dltY)
    }
    seenY = true
    volY = 0.0
    dltY = 0.0
  }
  // Bar delta: exchange buy/sell volume, else a close-location estimate
  let bVol = chart.buyVolume
  let sVol = chart.sellVolume
  let dBar = bVol != null && sVol != null ? (bVol ?? 0.0) - (sVol ?? 0.0) : (h > l ? vol * (c - o) / (h - l) : 0.0)
  dlt4H += dBar
  dltD += dBar
  dltW += dBar
  dltM += dBar
  dltQ += dBar
  dltY += dBar
  vol4H += vol
  volD += vol
  volW += vol
  volM += vol
  volQ += vol
  volY += vol

  // --- 3. Periodic VWAPs (native, shared source) ---------------------------
  let v4H = chart.vwap(reset: isNew4H, source: src)
  let d4H = chart.vwapDev(reset: isNew4H, source: src)
  let vD  = chart.vwap(reset: isNewD, source: src)
  let dD  = chart.vwapDev(reset: isNewD, source: src)
  let vW  = chart.vwap(reset: isNewW, source: src)
  let dW  = chart.vwapDev(reset: isNewW, source: src)
  let vM  = chart.vwap(reset: isNewM, source: src)
  let dM  = chart.vwapDev(reset: isNewM, source: src)
  let vQ  = chart.vwap(reset: isNewQ, source: src)
  let dQ  = chart.vwapDev(reset: isNewQ, source: src)
  let vY  = chart.vwap(reset: isNewY, source: src)
  let dY  = chart.vwapDev(reset: isNewY, source: src)

  // Jump flags: reset on this bar (jX) or on the previous bar (jpX)
  let pp = chart.time[2]
  let hasPrev = prevTs != null
  let pTs = prevTs ?? ts
  let j4H = cutOnReset && isNew4H
  let jD  = cutOnReset && isNewD
  let jW  = cutOnReset && isNewW
  let jM  = cutOnReset && isNewM
  let jQ  = cutOnReset && isNewQ
  let jY  = cutOnReset && isNewY
  let jp4H = cutOnReset && hasPrev && time.isNewPeriod(pTs, pp, 4h)
  let jpD  = cutOnReset && hasPrev && time.isNewPeriod(pTs, pp, 1D)
  let jpW  = cutOnReset && hasPrev && time.isNewPeriod(pTs, pp, 1W)
  let jpM  = cutOnReset && hasPrev && time.isNewPeriod(pTs, pp, 1M)
  let jpQ  = cutOnReset && hasPrev && time.isNewPeriod(pTs, pp, 3M)
  let jpY  = cutOnReset && hasPrev && time.isNewPeriod(pTs, pp, 1Y)

  drawPeriod(color4H, show4H && !hideLive, bands4H, fill4H, v4H, d4H, last4H_V, last4H_D, j4H, jp4H,
    p4h, p4h_s1u, p4h_s1d, p4h_s2u, p4h_s2d, p4h_s3u, p4h_s3d,
    f4h_s1, f4h_s2u, f4h_s2d, f4h_s3)
  drawPeriod(colorDaily, showDaily && !hideLive, bandsDaily, fillDaily, vD, dD, lastD_V, lastD_D, jD, jpD,
    pd, pd_s1u, pd_s1d, pd_s2u, pd_s2d, pd_s3u, pd_s3d,
    fd_s1, fd_s2u, fd_s2d, fd_s3)
  drawPeriod(colorWeekly, showWeekly && !hideLive, bandsWeekly, fillWeekly, vW, dW, lastW_V, lastW_D, jW, jpW,
    pw, pw_s1u, pw_s1d, pw_s2u, pw_s2d, pw_s3u, pw_s3d,
    fw_s1, fw_s2u, fw_s2d, fw_s3)
  drawPeriod(colorMonthly, showMonthly && !hideLive, bandsMonthly, fillMonthly, vM, dM, lastM_V, lastM_D, jM, jpM,
    pm, pm_s1u, pm_s1d, pm_s2u, pm_s2d, pm_s3u, pm_s3d,
    fm_s1, fm_s2u, fm_s2d, fm_s3)
  drawPeriod(colorQuarterly, showQuarterly && !hideLive, bandsQuarterly, fillQuarterly, vQ, dQ, lastQ_V, lastQ_D, jQ, jpQ,
    pq, pq_s1u, pq_s1d, pq_s2u, pq_s2d, pq_s3u, pq_s3d,
    fq_s1, fq_s2u, fq_s2d, fq_s3)
  drawPeriod(colorYearly, showYearly && !hideLive, bandsYearly, fillYearly, vY, dY, lastY_V, lastY_D, jY, jpY,
    py, py_s1u, py_s1d, py_s2u, py_s2d, py_s3u, py_s3d,
    fy_s1, fy_s2u, fy_s2d, fy_s3)

  // Projections of closed periods (entities, written on resets only).
  // Archive the finished set into history, push the closed period, then
  // re-anchor the live set (extend.right) at the reset bar.
  if prevTs != null {
    let pt = prevTs ?? ts
    if isNew4H && last4H_V != null {
      let on4H = show4H && proj4H
      let st4H = pjT4H
      if on4H && projHistory && st4H != null {
        drawProjSet(projHistL, projHistF, nextProjId * 50, st4H ?? ts, pt, extend.none, pjV4H, pjS4H, projColor, bands4H && showStd1, bands4H && showStd2, fill4H && fillStd1, fill4H && fillStd2)
        nextProjId += 1
      }
      pjV4H.push(last4H_V)
      pjS4H.push(last4H_D)
      pjT4H = ts
      if on4H {
        drawProjSet(projLiveL, projLiveF, 0, ts, time.shiftBars(ts, 1), extend.right, pjV4H, pjS4H, projColor, bands4H && showStd1, bands4H && showStd2, fill4H && fillStd1, fill4H && fillStd2)
      }
    }
    if isNewD && lastD_V != null {
      let onD = showDaily && projDaily
      let stD = pjTD
      if onD && projHistory && stD != null {
        drawProjSet(projHistL, projHistF, nextProjId * 50, stD ?? ts, pt, extend.none, pjVD, pjSD, projColor, bandsDaily && showStd1, bandsDaily && showStd2, fillDaily && fillStd1, fillDaily && fillStd2)
        nextProjId += 1
      }
      pjVD.push(lastD_V)
      pjSD.push(lastD_D)
      pjTD = ts
      if onD {
        drawProjSet(projLiveL, projLiveF, 50, ts, time.shiftBars(ts, 1), extend.right, pjVD, pjSD, projColor, bandsDaily && showStd1, bandsDaily && showStd2, fillDaily && fillStd1, fillDaily && fillStd2)
      }
    }
    if isNewW && lastW_V != null {
      let onW = showWeekly && projWeekly
      let stW = pjTW
      if onW && projHistory && stW != null {
        drawProjSet(projHistL, projHistF, nextProjId * 50, stW ?? ts, pt, extend.none, pjVW, pjSW, projColor, bandsWeekly && showStd1, bandsWeekly && showStd2, fillWeekly && fillStd1, fillWeekly && fillStd2)
        nextProjId += 1
      }
      pjVW.push(lastW_V)
      pjSW.push(lastW_D)
      pjTW = ts
      if onW {
        drawProjSet(projLiveL, projLiveF, 100, ts, time.shiftBars(ts, 1), extend.right, pjVW, pjSW, projColor, bandsWeekly && showStd1, bandsWeekly && showStd2, fillWeekly && fillStd1, fillWeekly && fillStd2)
      }
    }
    if isNewM && lastM_V != null {
      let onM = showMonthly && projMonthly
      let stM = pjTM
      if onM && projHistory && stM != null {
        drawProjSet(projHistL, projHistF, nextProjId * 50, stM ?? ts, pt, extend.none, pjVM, pjSM, projColor, bandsMonthly && showStd1, bandsMonthly && showStd2, fillMonthly && fillStd1, fillMonthly && fillStd2)
        nextProjId += 1
      }
      pjVM.push(lastM_V)
      pjSM.push(lastM_D)
      pjTM = ts
      if onM {
        drawProjSet(projLiveL, projLiveF, 150, ts, time.shiftBars(ts, 1), extend.right, pjVM, pjSM, projColor, bandsMonthly && showStd1, bandsMonthly && showStd2, fillMonthly && fillStd1, fillMonthly && fillStd2)
      }
    }
    if isNewQ && lastQ_V != null {
      let onQ = showQuarterly && projQuarterly
      let stQ = pjTQ
      if onQ && projHistory && stQ != null {
        drawProjSet(projHistL, projHistF, nextProjId * 50, stQ ?? ts, pt, extend.none, pjVQ, pjSQ, projColor, bandsQuarterly && showStd1, bandsQuarterly && showStd2, fillQuarterly && fillStd1, fillQuarterly && fillStd2)
        nextProjId += 1
      }
      pjVQ.push(lastQ_V)
      pjSQ.push(lastQ_D)
      pjTQ = ts
      if onQ {
        drawProjSet(projLiveL, projLiveF, 200, ts, time.shiftBars(ts, 1), extend.right, pjVQ, pjSQ, projColor, bandsQuarterly && showStd1, bandsQuarterly && showStd2, fillQuarterly && fillStd1, fillQuarterly && fillStd2)
      }
    }
    if isNewY && lastY_V != null {
      let onY = showYearly && projYearly
      let stY = pjTY
      if onY && projHistory && stY != null {
        drawProjSet(projHistL, projHistF, nextProjId * 50, stY ?? ts, pt, extend.none, pjVY, pjSY, projColor, bandsYearly && showStd1, bandsYearly && showStd2, fillYearly && fillStd1, fillYearly && fillStd2)
        nextProjId += 1
      }
      pjVY.push(lastY_V)
      pjSY.push(lastY_D)
      pjTY = ts
      if onY {
        drawProjSet(projLiveL, projLiveF, 250, ts, time.shiftBars(ts, 1), extend.right, pjVY, pjSY, projColor, bandsYearly && showStd1, bandsYearly && showStd2, fillYearly && fillStd1, fillYearly && fillStd2)
      }
    }
  }

  // Line fills only span x1..x2 (extend.right does not widen them), so the
  // live set is stretched to the last bar on every realtime update.
  if chart.isLast {
    if show4H && proj4H && pjT4H != null {
      drawProjSet(projLiveL, projLiveF, 0, pjT4H ?? ts, ts, extend.right, pjV4H, pjS4H, projColor, bands4H && showStd1, bands4H && showStd2, fill4H && fillStd1, fill4H && fillStd2)
    }
    if showDaily && projDaily && pjTD != null {
      drawProjSet(projLiveL, projLiveF, 50, pjTD ?? ts, ts, extend.right, pjVD, pjSD, projColor, bandsDaily && showStd1, bandsDaily && showStd2, fillDaily && fillStd1, fillDaily && fillStd2)
    }
    if showWeekly && projWeekly && pjTW != null {
      drawProjSet(projLiveL, projLiveF, 100, pjTW ?? ts, ts, extend.right, pjVW, pjSW, projColor, bandsWeekly && showStd1, bandsWeekly && showStd2, fillWeekly && fillStd1, fillWeekly && fillStd2)
    }
    if showMonthly && projMonthly && pjTM != null {
      drawProjSet(projLiveL, projLiveF, 150, pjTM ?? ts, ts, extend.right, pjVM, pjSM, projColor, bandsMonthly && showStd1, bandsMonthly && showStd2, fillMonthly && fillStd1, fillMonthly && fillStd2)
    }
    if showQuarterly && projQuarterly && pjTQ != null {
      drawProjSet(projLiveL, projLiveF, 200, pjTQ ?? ts, ts, extend.right, pjVQ, pjSQ, projColor, bandsQuarterly && showStd1, bandsQuarterly && showStd2, fillQuarterly && fillStd1, fillQuarterly && fillStd2)
    }
    if showYearly && projYearly && pjTY != null {
      drawProjSet(projLiveL, projLiveF, 250, pjTY ?? ts, ts, extend.right, pjVY, pjSY, projColor, bandsYearly && showStd1, bandsYearly && showStd2, fillYearly && fillStd1, fillYearly && fillStd2)
    }
  }

  last4H_V = v4H
  lastD_V = vD
  lastW_V = vW
  lastM_V = vM
  lastQ_V = vQ
  lastY_V = vY
  last4H_D = d4H
  lastD_D = dD
  lastW_D = dW
  lastM_D = dM
  lastQ_D = dQ
  lastY_D = dY

  // --- 4. Session VWAPs ------------------------------------------------------
  // Outside the session the last value is kept (invisible when not
  // extended) so the renderer never bridges a gap into the next session.
  let ppTs = pp ?? pTs
  let hasPP = pp != null

  let inAsia = sessAsia.contains(ts)
  let wasAsia = hasPrev && sessAsia.contains(pTs)
  let wasAsia2 = hasPP && sessAsia.contains(ppTs)
  let oAsia = sAsia
  sAsia.step(inAsia, inAsia && !wasAsia, wasAsia, pv, p2, vol)
  if inAsia {
    if !wasAsia {
      seenAS = true
      dltAS = 0.0
    }
    dltAS += dBar
  }
  // Session closed: its final VWAP becomes a naked level
  if wasAsia && !inAsia && sAsia.v > 0.0 {
    if showNaked && nkAsia && sAsia.last != null {
      registerNakedLevel("AS", sAsia.last ?? 0.0, sAsia.lastD ?? 0.0, pTs, nakedScore(sAsia.v, dltAS, histAS, histDlAS))
    }
    if seenAS {
      histAS.push(sAsia.v)
      histDlAS.push(dltAS)
    }
  }
  drawSess(6, "Asia VWAP", colSessAsia, showSessAsia, bandsAsia, fillAsia, inAsia, wasAsia, wasAsia2, oAsia, sAsia, pSessAsia, pSessAsia_s1u, pSessAsia_s1d, pSessAsia_s2u, pSessAsia_s2d, pSessAsia_f1, pSessAsia_f2u, pSessAsia_f2d)

  let inLondon = sessLondon.contains(ts)
  let wasLondon = hasPrev && sessLondon.contains(pTs)
  let wasLondon2 = hasPP && sessLondon.contains(ppTs)
  let oLondon = sLondon
  sLondon.step(inLondon, inLondon && !wasLondon, wasLondon, pv, p2, vol)
  if inLondon {
    if !wasLondon {
      seenLN = true
      dltLN = 0.0
    }
    dltLN += dBar
  }
  // Session closed: its final VWAP becomes a naked level
  if wasLondon && !inLondon && sLondon.v > 0.0 {
    if showNaked && nkLondon && sLondon.last != null {
      registerNakedLevel("LN", sLondon.last ?? 0.0, sLondon.lastD ?? 0.0, pTs, nakedScore(sLondon.v, dltLN, histLN, histDlLN))
    }
    if seenLN {
      histLN.push(sLondon.v)
      histDlLN.push(dltLN)
    }
  }
  drawSess(7, "London VWAP", colSessLondon, showSessLondon, bandsLondon, fillLondon, inLondon, wasLondon, wasLondon2, oLondon, sLondon, pSessLondon, pSessLondon_s1u, pSessLondon_s1d, pSessLondon_s2u, pSessLondon_s2d, pSessLondon_f1, pSessLondon_f2u, pSessLondon_f2d)

  let inNY = sessNY.contains(ts)
  let wasNY = hasPrev && sessNY.contains(pTs)
  let wasNY2 = hasPP && sessNY.contains(ppTs)
  let oNY = sNY
  sNY.step(inNY, inNY && !wasNY, wasNY, pv, p2, vol)
  if inNY {
    if !wasNY {
      seenNY = true
      dltNY = 0.0
    }
    dltNY += dBar
  }
  // Session closed: its final VWAP becomes a naked level
  if wasNY && !inNY && sNY.v > 0.0 {
    if showNaked && nkNY && sNY.last != null {
      registerNakedLevel("NY", sNY.last ?? 0.0, sNY.lastD ?? 0.0, pTs, nakedScore(sNY.v, dltNY, histNY, histDlNY))
    }
    if seenNY {
      histNY.push(sNY.v)
      histDlNY.push(dltNY)
    }
  }
  drawSess(8, "New York VWAP", colSessNY, showSessNY, bandsNY, fillNY, inNY, wasNY, wasNY2, oNY, sNY, pSessNY, pSessNY_s1u, pSessNY_s1d, pSessNY_s2u, pSessNY_s2d, pSessNY_f1, pSessNY_f2u, pSessNY_f2d)

  let inClose = sessClose.contains(ts)
  let wasClose = hasPrev && sessClose.contains(pTs)
  let wasClose2 = hasPP && sessClose.contains(ppTs)
  let oClose = sClose
  sClose.step(inClose, inClose && !wasClose, wasClose, pv, p2, vol)
  if inClose {
    if !wasClose {
      seenNC = true
      dltNC = 0.0
    }
    dltNC += dBar
  }
  // Session closed: its final VWAP becomes a naked level
  if wasClose && !inClose && sClose.v > 0.0 {
    if showNaked && nkClose && sClose.last != null {
      registerNakedLevel("NC", sClose.last ?? 0.0, sClose.lastD ?? 0.0, pTs, nakedScore(sClose.v, dltNC, histNC, histDlNC))
    }
    if seenNC {
      histNC.push(sClose.v)
      histDlNC.push(dltNC)
    }
  }
  drawSess(9, "NY Close VWAP", colSessClose, showSessClose, bandsClose, fillClose, inClose, wasClose, wasClose2, oClose, sClose, pSessClose, pSessClose_s1u, pSessClose_s1d, pSessClose_s2u, pSessClose_s2d, pSessClose_f1, pSessClose_f2u, pSessClose_f2d)

  // --- 5. Peak / Trough AVWAPs ----------------------------------------------
  // Live-leg budget: live legs at full detail, finished legs kept (compacted)
  // while the total stays under 1900 of the 2000 lines
  let lvBarsM = 2592000.0 / barSec
  let lvBarsW = 604800.0 / barSec
  let lvBarsD = 86400.0 / barSec
  let lvSegM = math.min(lvCap, (int(math.floor(lvBarsM)) ?? 1) + 2)
  let lvSegW = math.min(lvCap, (int(math.floor(lvBarsW)) ?? 1) + 2)
  let lvSegD = math.min(lvCap, (int(math.floor(lvBarsD)) ?? 1) + 2)
  let lvLive = (enableMonthAvwap ? 2 * lvSegM * lvLpsM : 0) + (enableWeekAvwap ? 2 * lvSegW * lvLpsW : 0) + (enableDayAvwap ? 2 * lvSegD * lvLpsD : 0)
  let lvRoom = float(math.max(0, 1900 - lvLive)) / float(math.max(1, lvNP))
  let lvKeepM = math.min(48, math.max(1, int(math.floor(lvRoom / float(2 * math.min(17, lvSegM) * lvLpsM))) ?? 1))
  let lvKeepW = math.min(48, math.max(1, int(math.floor(lvRoom / float(2 * math.min(17, lvSegW) * lvLpsW))) ?? 1))
  let lvKeepD = math.min(48, math.max(1, int(math.floor(lvRoom / float(2 * math.min(17, lvSegD) * lvLpsD))) ?? 1))
  let oM = ptM
  // High / low detection price: full wick or close only
  let pkH = ptByClose ? c : h
  let pkL = ptByClose ? c : l
  ptM.step(isNewM, pkH, pkL, h, l, pv, p2, vol, dBar, ptKeepPrev)
  if enablePrevMonthAvwap && !enableMonthAvwap {
    let strideM = math.max(1, int(math.floor(2592000.0 / barSec / 200.0)) ?? 1)
    if legMJoin {
      // close the 1-bar gap between the leg and the plotted line
      let jt = legMHlt
      if jt != null && ptM.pHiV > 0.0 {
        anchL.get(0, legMIdx, 255).set(x1: jt, y1: legMHlv, x2: ts, y2: ptM.pHiPV / ptM.pHiV, color: colPrevMonthHigh, width: 2.0, style: linestyle.dashed, extend: extend.none)
      }
      let jt2 = legMLlt
      if jt2 != null && ptM.pLoV > 0.0 {
        anchL.get(1, legMIdx, 255).set(x1: jt2, y1: legMLlv, x2: ts, y2: ptM.pLoPV / ptM.pLoV, color: colPrevMonthLow, width: 2.0, style: linestyle.dashed, extend: extend.none)
      }
      legMJoin = false
    }
    if isNewM && oM.full && oM.hiV > 0.0 && oM.loV > 0.0 && ptM.pHiV > 0.0 && ptM.pLoV > 0.0 {
      // The closed period's high/low AVWAPs become "previous": draw their legs
      legMIdx += 1
      let eh = ptM.pHiPV / ptM.pHiV
      let el = ptM.pLoPV / ptM.pLoV
      drawLeg(anchL, 0, legMIdx, legMHt, legMHv, ts, eh, colPrevMonthHigh, 2.0)
      drawLeg(anchL, 1, legMIdx, legMLt, legMLv, ts, el, colPrevMonthLow, 2.0)
      legMHlt = ts
      legMHlv = eh
      legMLlt = ts
      legMLlv = el
      legMJoin = true
    }
    if ptM.newHi {
      legMHt.clear()
      legMHv.clear()
      legMHn = strideM
    }
    if ptM.newLo {
      legMLt.clear()
      legMLv.clear()
      legMLn = strideM
    }
    legMHn += 1
    legMLn += 1
    if (legMHn >= strideM || legMHt.len < 12) && legMHt.len < 250 && ptM.hiV > 0.0 {
      legMHt.push(ts)
      legMHv.push(ptM.hiPV / ptM.hiV)
      legMHn = 0
    }
    if (legMLn >= strideM || legMLt.len < 12) && legMLt.len < 250 && ptM.loV > 0.0 {
      legMLt.push(ts)
      legMLv.push(ptM.loPV / ptM.loV)
      legMLn = 0
    }
  }
  if lvOn && enableMonthAvwap {
    liveLeg(0, ptM.full, isNewM, ptM.newHi, ts, ptM.hi, ratio(ptM.hiPV, ptM.hiV, true), devOf(ptM.hiPV, ptM.hiV, ptM.hiP2, true), lvBarsM, lvKeepM, colMonthHigh, 2.0, bandsMonth && showStd1, bandsMonth && showStd2, bandsMonth && fillMonth && fillStd1, "Month High AVWAP")
    liveLeg(1, ptM.full, isNewM, ptM.newLo, ts, ptM.lo, ratio(ptM.loPV, ptM.loV, true), devOf(ptM.loPV, ptM.loV, ptM.loP2, true), lvBarsM, lvKeepM, colMonthLow, 2.0, bandsMonth && showStd1, bandsMonth && showStd2, bandsMonth && fillMonth && fillStd1, "Month Low AVWAP")
  }
  // A previous high/low AVWAP replaced untouched becomes a naked level
  if isNewM && oM.hiV > 0.0 && oM.loV > 0.0 {
    if oM.hasPH && !oM.usedPH && oM.pHiV > 0.0 {
      if showNaked && nkAnchM {
        registerNakedLevel("MH", oM.pHiPV / oM.pHiV, devOf(oM.pHiPV, oM.pHiV, oM.pHiP2, true) ?? 0.0, pTs, nakedScore(oM.pHiV, oM.pHiD, histAM, histDlAM))
      }
      histAM.push(oM.pHiV)
      histDlAM.push(oM.pHiD)
    }
    if oM.hasPL && !oM.usedPL && oM.pLoV > 0.0 {
      if showNaked && nkAnchM {
        registerNakedLevel("ML", oM.pLoPV / oM.pLoV, devOf(oM.pLoPV, oM.pLoV, oM.pLoP2, true) ?? 0.0, pTs, nakedScore(oM.pLoV, oM.pLoD, histAM, histDlAM))
      }
      histAM.push(oM.pLoV)
      histDlAM.push(oM.pLoD)
    }
  }
  jTm.clear()
  jTm.push(prevTs ?? ts)
  jTm.push(ts)
  drawAnch(0, ptM.hi, -1, "", colMonthHigh, enableMonthAvwap && ptM.full && !lvOn, false, bandsMonth, fillMonth, ptM.newHi, ptM.pNewHi, oM.hiPV, oM.hiV, oM.hiP2, true, ptM.hiPV, ptM.hiV, ptM.hiP2, pMHigh, pMHigh_s1u, pMHigh_s1d, pMHigh_s2u, pMHigh_s2d, pMHigh_f1)
  drawAnch(1, ptM.lo, -1, "", colMonthLow, enableMonthAvwap && ptM.full && !lvOn, false, bandsMonth, fillMonth, ptM.newLo, ptM.pNewLo, oM.loPV, oM.loV, oM.loP2, true, ptM.loPV, ptM.loV, ptM.loP2, pMLow, pMLow_s1u, pMLow_s1d, pMLow_s2u, pMLow_s2d, pMLow_f1)
  drawAnch(2, null, 0, "Prev Month High AVWAP", colPrevMonthHigh, enablePrevMonthAvwap && ptM.hasPH, ptKeepPrev && oM.usedPH && !ptM.newPH, bandsPrevMonth, fillPrevMonth, ptM.newPH, ptM.pNewPH, oM.pHiPV, oM.pHiV, oM.pHiP2, oM.hasPH, ptM.pHiPV, ptM.pHiV, ptM.pHiP2, pPrevMHigh, pPrevMHigh_s1u, pPrevMHigh_s1d, pPrevMHigh_s2u, pPrevMHigh_s2d, pPrevMHigh_f1)
  drawAnch(3, null, 1, "Prev Month Low AVWAP", colPrevMonthLow, enablePrevMonthAvwap && ptM.hasPL, ptKeepPrev && oM.usedPL && !ptM.newPL, bandsPrevMonth, fillPrevMonth, ptM.newPL, ptM.pNewPL, oM.pLoPV, oM.pLoV, oM.pLoP2, oM.hasPL, ptM.pLoPV, ptM.pLoV, ptM.pLoP2, pPrevMLow, pPrevMLow_s1u, pPrevMLow_s1d, pPrevMLow_s2u, pPrevMLow_s2d, pPrevMLow_f1)
  let oW = ptW
  ptW.step(isNewW, pkH, pkL, h, l, pv, p2, vol, dBar, ptKeepPrev)
  if enablePrevWeekAvwap && !enableWeekAvwap {
    let strideW = math.max(1, int(math.floor(604800.0 / barSec / 200.0)) ?? 1)
    if legWJoin {
      // close the 1-bar gap between the leg and the plotted line
      let jt = legWHlt
      if jt != null && ptW.pHiV > 0.0 {
        anchL.get(2, legWIdx, 255).set(x1: jt, y1: legWHlv, x2: ts, y2: ptW.pHiPV / ptW.pHiV, color: colPrevWeekHigh, width: 1.5, style: linestyle.dashed, extend: extend.none)
      }
      let jt2 = legWLlt
      if jt2 != null && ptW.pLoV > 0.0 {
        anchL.get(3, legWIdx, 255).set(x1: jt2, y1: legWLlv, x2: ts, y2: ptW.pLoPV / ptW.pLoV, color: colPrevWeekLow, width: 1.5, style: linestyle.dashed, extend: extend.none)
      }
      legWJoin = false
    }
    if isNewW && oW.full && oW.hiV > 0.0 && oW.loV > 0.0 && ptW.pHiV > 0.0 && ptW.pLoV > 0.0 {
      // The closed period's high/low AVWAPs become "previous": draw their legs
      legWIdx += 1
      let eh = ptW.pHiPV / ptW.pHiV
      let el = ptW.pLoPV / ptW.pLoV
      drawLeg(anchL, 2, legWIdx, legWHt, legWHv, ts, eh, colPrevWeekHigh, 1.5)
      drawLeg(anchL, 3, legWIdx, legWLt, legWLv, ts, el, colPrevWeekLow, 1.5)
      legWHlt = ts
      legWHlv = eh
      legWLlt = ts
      legWLlv = el
      legWJoin = true
    }
    if ptW.newHi {
      legWHt.clear()
      legWHv.clear()
      legWHn = strideW
    }
    if ptW.newLo {
      legWLt.clear()
      legWLv.clear()
      legWLn = strideW
    }
    legWHn += 1
    legWLn += 1
    if (legWHn >= strideW || legWHt.len < 12) && legWHt.len < 250 && ptW.hiV > 0.0 {
      legWHt.push(ts)
      legWHv.push(ptW.hiPV / ptW.hiV)
      legWHn = 0
    }
    if (legWLn >= strideW || legWLt.len < 12) && legWLt.len < 250 && ptW.loV > 0.0 {
      legWLt.push(ts)
      legWLv.push(ptW.loPV / ptW.loV)
      legWLn = 0
    }
  }
  if lvOn && enableWeekAvwap {
    liveLeg(2, ptW.full, isNewW, ptW.newHi, ts, ptW.hi, ratio(ptW.hiPV, ptW.hiV, true), devOf(ptW.hiPV, ptW.hiV, ptW.hiP2, true), lvBarsW, lvKeepW, colWeekHigh, 1.5, bandsWeek && showStd1, bandsWeek && showStd2, bandsWeek && fillWeek && fillStd1, "Week High AVWAP")
    liveLeg(3, ptW.full, isNewW, ptW.newLo, ts, ptW.lo, ratio(ptW.loPV, ptW.loV, true), devOf(ptW.loPV, ptW.loV, ptW.loP2, true), lvBarsW, lvKeepW, colWeekLow, 1.5, bandsWeek && showStd1, bandsWeek && showStd2, bandsWeek && fillWeek && fillStd1, "Week Low AVWAP")
  }
  // A previous high/low AVWAP replaced untouched becomes a naked level
  if isNewW && oW.hiV > 0.0 && oW.loV > 0.0 {
    if oW.hasPH && !oW.usedPH && oW.pHiV > 0.0 {
      if showNaked && nkAnchW {
        registerNakedLevel("WH", oW.pHiPV / oW.pHiV, devOf(oW.pHiPV, oW.pHiV, oW.pHiP2, true) ?? 0.0, pTs, nakedScore(oW.pHiV, oW.pHiD, histAW, histDlAW))
      }
      histAW.push(oW.pHiV)
      histDlAW.push(oW.pHiD)
    }
    if oW.hasPL && !oW.usedPL && oW.pLoV > 0.0 {
      if showNaked && nkAnchW {
        registerNakedLevel("WL", oW.pLoPV / oW.pLoV, devOf(oW.pLoPV, oW.pLoV, oW.pLoP2, true) ?? 0.0, pTs, nakedScore(oW.pLoV, oW.pLoD, histAW, histDlAW))
      }
      histAW.push(oW.pLoV)
      histDlAW.push(oW.pLoD)
    }
  }
  drawAnch(4, ptW.hi, -1, "", colWeekHigh, enableWeekAvwap && ptW.full && !lvOn, false, bandsWeek, fillWeek, ptW.newHi, ptW.pNewHi, oW.hiPV, oW.hiV, oW.hiP2, true, ptW.hiPV, ptW.hiV, ptW.hiP2, pWHigh, pWHigh_s1u, pWHigh_s1d, pWHigh_s2u, pWHigh_s2d, pWHigh_f1)
  drawAnch(5, ptW.lo, -1, "", colWeekLow, enableWeekAvwap && ptW.full && !lvOn, false, bandsWeek, fillWeek, ptW.newLo, ptW.pNewLo, oW.loPV, oW.loV, oW.loP2, true, ptW.loPV, ptW.loV, ptW.loP2, pWLow, pWLow_s1u, pWLow_s1d, pWLow_s2u, pWLow_s2d, pWLow_f1)
  drawAnch(6, null, 2, "Prev Week High AVWAP", colPrevWeekHigh, enablePrevWeekAvwap && ptW.hasPH, ptKeepPrev && oW.usedPH && !ptW.newPH, bandsPrevWeek, fillPrevWeek, ptW.newPH, ptW.pNewPH, oW.pHiPV, oW.pHiV, oW.pHiP2, oW.hasPH, ptW.pHiPV, ptW.pHiV, ptW.pHiP2, pPrevWHigh, pPrevWHigh_s1u, pPrevWHigh_s1d, pPrevWHigh_s2u, pPrevWHigh_s2d, pPrevWHigh_f1)
  drawAnch(7, null, 3, "Prev Week Low AVWAP", colPrevWeekLow, enablePrevWeekAvwap && ptW.hasPL, ptKeepPrev && oW.usedPL && !ptW.newPL, bandsPrevWeek, fillPrevWeek, ptW.newPL, ptW.pNewPL, oW.pLoPV, oW.pLoV, oW.pLoP2, oW.hasPL, ptW.pLoPV, ptW.pLoV, ptW.pLoP2, pPrevWLow, pPrevWLow_s1u, pPrevWLow_s1d, pPrevWLow_s2u, pPrevWLow_s2d, pPrevWLow_f1)
  let oD = ptD
  ptD.step(isNewD, pkH, pkL, h, l, pv, p2, vol, dBar, ptKeepPrev)
  if enablePrevDayAvwap && !enableDayAvwap {
    let strideD = math.max(1, int(math.floor(86400.0 / barSec / 200.0)) ?? 1)
    if legDJoin {
      // close the 1-bar gap between the leg and the plotted line
      let jt = legDHlt
      if jt != null && ptD.pHiV > 0.0 {
        anchL.get(4, legDIdx, 255).set(x1: jt, y1: legDHlv, x2: ts, y2: ptD.pHiPV / ptD.pHiV, color: colPrevDayHigh, width: 1.5, style: linestyle.dashed, extend: extend.none)
      }
      let jt2 = legDLlt
      if jt2 != null && ptD.pLoV > 0.0 {
        anchL.get(5, legDIdx, 255).set(x1: jt2, y1: legDLlv, x2: ts, y2: ptD.pLoPV / ptD.pLoV, color: colPrevDayLow, width: 1.5, style: linestyle.dashed, extend: extend.none)
      }
      legDJoin = false
    }
    if isNewD && oD.full && oD.hiV > 0.0 && oD.loV > 0.0 && ptD.pHiV > 0.0 && ptD.pLoV > 0.0 {
      // The closed period's high/low AVWAPs become "previous": draw their legs
      legDIdx += 1
      let eh = ptD.pHiPV / ptD.pHiV
      let el = ptD.pLoPV / ptD.pLoV
      drawLeg(anchL, 4, legDIdx, legDHt, legDHv, ts, eh, colPrevDayHigh, 1.5)
      drawLeg(anchL, 5, legDIdx, legDLt, legDLv, ts, el, colPrevDayLow, 1.5)
      legDHlt = ts
      legDHlv = eh
      legDLlt = ts
      legDLlv = el
      legDJoin = true
    }
    if ptD.newHi {
      legDHt.clear()
      legDHv.clear()
      legDHn = strideD
    }
    if ptD.newLo {
      legDLt.clear()
      legDLv.clear()
      legDLn = strideD
    }
    legDHn += 1
    legDLn += 1
    if (legDHn >= strideD || legDHt.len < 12) && legDHt.len < 250 && ptD.hiV > 0.0 {
      legDHt.push(ts)
      legDHv.push(ptD.hiPV / ptD.hiV)
      legDHn = 0
    }
    if (legDLn >= strideD || legDLt.len < 12) && legDLt.len < 250 && ptD.loV > 0.0 {
      legDLt.push(ts)
      legDLv.push(ptD.loPV / ptD.loV)
      legDLn = 0
    }
  }
  if lvOn && enableDayAvwap {
    liveLeg(4, ptD.full, isNewD, ptD.newHi, ts, ptD.hi, ratio(ptD.hiPV, ptD.hiV, true), devOf(ptD.hiPV, ptD.hiV, ptD.hiP2, true), lvBarsD, lvKeepD, colDayHigh, 1.5, bandsDay && showStd1, bandsDay && showStd2, bandsDay && fillDay && fillStd1, "Day High AVWAP")
    liveLeg(5, ptD.full, isNewD, ptD.newLo, ts, ptD.lo, ratio(ptD.loPV, ptD.loV, true), devOf(ptD.loPV, ptD.loV, ptD.loP2, true), lvBarsD, lvKeepD, colDayLow, 1.5, bandsDay && showStd1, bandsDay && showStd2, bandsDay && fillDay && fillStd1, "Day Low AVWAP")
  }
  // A previous high/low AVWAP replaced untouched becomes a naked level
  if isNewD && oD.hiV > 0.0 && oD.loV > 0.0 {
    if oD.hasPH && !oD.usedPH && oD.pHiV > 0.0 {
      if showNaked && nkAnchD {
        registerNakedLevel("DH", oD.pHiPV / oD.pHiV, devOf(oD.pHiPV, oD.pHiV, oD.pHiP2, true) ?? 0.0, pTs, nakedScore(oD.pHiV, oD.pHiD, histAD, histDlAD))
      }
      histAD.push(oD.pHiV)
      histDlAD.push(oD.pHiD)
    }
    if oD.hasPL && !oD.usedPL && oD.pLoV > 0.0 {
      if showNaked && nkAnchD {
        registerNakedLevel("DL", oD.pLoPV / oD.pLoV, devOf(oD.pLoPV, oD.pLoV, oD.pLoP2, true) ?? 0.0, pTs, nakedScore(oD.pLoV, oD.pLoD, histAD, histDlAD))
      }
      histAD.push(oD.pLoV)
      histDlAD.push(oD.pLoD)
    }
  }
  drawAnch(8, ptD.hi, -1, "", colDayHigh, enableDayAvwap && ptD.full && !lvOn, false, bandsDay, fillDay, ptD.newHi, ptD.pNewHi, oD.hiPV, oD.hiV, oD.hiP2, true, ptD.hiPV, ptD.hiV, ptD.hiP2, pDHigh, pDHigh_s1u, pDHigh_s1d, pDHigh_s2u, pDHigh_s2d, pDHigh_f1)
  drawAnch(9, ptD.lo, -1, "", colDayLow, enableDayAvwap && ptD.full && !lvOn, false, bandsDay, fillDay, ptD.newLo, ptD.pNewLo, oD.loPV, oD.loV, oD.loP2, true, ptD.loPV, ptD.loV, ptD.loP2, pDLow, pDLow_s1u, pDLow_s1d, pDLow_s2u, pDLow_s2d, pDLow_f1)
  drawAnch(10, null, 4, "Prev Day High AVWAP", colPrevDayHigh, enablePrevDayAvwap && ptD.hasPH, ptKeepPrev && oD.usedPH && !ptD.newPH, bandsPrevDay, fillPrevDay, ptD.newPH, ptD.pNewPH, oD.pHiPV, oD.pHiV, oD.pHiP2, oD.hasPH, ptD.pHiPV, ptD.pHiV, ptD.pHiP2, pPrevDHigh, pPrevDHigh_s1u, pPrevDHigh_s1d, pPrevDHigh_s2u, pPrevDHigh_s2d, pPrevDHigh_f1)
  drawAnch(11, null, 5, "Prev Day Low AVWAP", colPrevDayLow, enablePrevDayAvwap && ptD.hasPL, ptKeepPrev && oD.usedPL && !ptD.newPL, bandsPrevDay, fillPrevDay, ptD.newPL, ptD.pNewPL, oD.pLoPV, oD.pLoV, oD.pLoP2, oD.hasPL, ptD.pLoPV, ptD.pLoV, ptD.pLoP2, pPrevDLow, pPrevDLow_s1u, pPrevDLow_s1d, pPrevDLow_s2u, pPrevDLow_s2d, pPrevDLow_f1)

  // --- 6. Custom-date AVWAP --------------------------------------------------
  let barKey = time.year(ts) * 1000000 + time.month(ts) * 10000 + time.dayOfMonth(ts) * 100 + time.hour(ts)
  let custStart = enableCustomAvwap && !custAnchored && barKey >= customKey
  if custStart {
    custAnchored = true
  }
  let cv = chart.vwap(reset: custStart, source: src)
  let cd = chart.vwapDev(reset: custStart, source: src)
  let custOn = enableCustomAvwap && custAnchored && cv != null
  pCustom.plot(custOn ? cv : null)
  drawBands2(color.withAlpha(colCustomAvwap, 150), color.withAlpha(colCustomAvwap, 110), custOn && customBands, false, customFill, false, false, null, null, cv, cd, pCust_s1u, pCust_s1d, pCust_s2u, pCust_s2d, pCust_f1, pCust_f2u, pCust_f2d, true)

  // --- 7. Rolling VWAPs (O(1) running sums over time buckets) ---------------
  if showRoll1 {
    if time.isNewPeriod(ts, prevTs, rollTf1) && r1CurV > 0.0 {
      if r1PV.isFull {
        r1SumPV -= r1PV.first() ?? 0.0
        r1SumV -= r1V.first() ?? 0.0
        r1SumP2 -= r1P2.first() ?? 0.0
      }
      r1PV.push(r1CurPV)
      r1V.push(r1CurV)
      r1P2.push(r1CurP2)
      r1SumP2 += r1CurP2
      r1CurP2 = 0.0
      r1SumPV += r1CurPV
      r1SumV += r1CurV
      r1CurPV = 0.0
      r1CurV = 0.0
    }
    r1CurPV += pv
    r1CurV += vol
    r1CurP2 += p2
  }
  let r1Val = ratio(r1SumPV + r1CurPV, r1SumV + r1CurV, showRoll1)
  pr1.plot(r1Val)
  drawBands2(rollS1Col1, rollS2Col1, showRoll1 && bandsRoll1, false, fillRoll1, false, false, null, null, r1Val, devOf(r1SumPV + r1CurPV, r1SumV + r1CurV, r1SumP2 + r1CurP2, showRoll1), pr1_s1u, pr1_s1d, pr1_s2u, pr1_s2d, pr1_f1, pr1_f2u, pr1_f2d, true)

  if showRoll2 {
    if time.isNewPeriod(ts, prevTs, rollTf2) && r2CurV > 0.0 {
      if r2PV.isFull {
        r2SumPV -= r2PV.first() ?? 0.0
        r2SumV -= r2V.first() ?? 0.0
        r2SumP2 -= r2P2.first() ?? 0.0
      }
      r2PV.push(r2CurPV)
      r2V.push(r2CurV)
      r2P2.push(r2CurP2)
      r2SumP2 += r2CurP2
      r2CurP2 = 0.0
      r2SumPV += r2CurPV
      r2SumV += r2CurV
      r2CurPV = 0.0
      r2CurV = 0.0
    }
    r2CurPV += pv
    r2CurV += vol
    r2CurP2 += p2
  }
  let r2Val = ratio(r2SumPV + r2CurPV, r2SumV + r2CurV, showRoll2)
  pr2.plot(r2Val)
  drawBands2(rollS1Col2, rollS2Col2, showRoll2 && bandsRoll2, false, fillRoll2, false, false, null, null, r2Val, devOf(r2SumPV + r2CurPV, r2SumV + r2CurV, r2SumP2 + r2CurP2, showRoll2), pr2_s1u, pr2_s1d, pr2_s2u, pr2_s2d, pr2_f1, pr2_f2u, pr2_f2d, true)

  if showRoll3 {
    if time.isNewPeriod(ts, prevTs, rollTf3) && r3CurV > 0.0 {
      if r3PV.isFull {
        r3SumPV -= r3PV.first() ?? 0.0
        r3SumV -= r3V.first() ?? 0.0
        r3SumP2 -= r3P2.first() ?? 0.0
      }
      r3PV.push(r3CurPV)
      r3V.push(r3CurV)
      r3P2.push(r3CurP2)
      r3SumP2 += r3CurP2
      r3CurP2 = 0.0
      r3SumPV += r3CurPV
      r3SumV += r3CurV
      r3CurPV = 0.0
      r3CurV = 0.0
    }
    r3CurPV += pv
    r3CurV += vol
    r3CurP2 += p2
  }
  let r3Val = ratio(r3SumPV + r3CurPV, r3SumV + r3CurV, showRoll3)
  pr3.plot(r3Val)
  drawBands2(rollS1Col3, rollS2Col3, showRoll3 && bandsRoll3, false, fillRoll3, false, false, null, null, r3Val, devOf(r3SumPV + r3CurPV, r3SumV + r3CurV, r3SumP2 + r3CurP2, showRoll3), pr3_s1u, pr3_s1d, pr3_s2u, pr3_s2d, pr3_f1, pr3_f2u, pr3_f2d, true)

  // --- 8. Naked VWAP invalidation (entities touched only on transition) ----
  let nearUp: float? = null
  let nearDn: float? = null
  if showNaked {
    let testHi = touchBody ? math.max(o, c) : h
    let testLo = touchBody ? math.min(o, c) : l
    // A gap between the previous close and this open also crosses levels
    let pcN = chart.close[1]
    let pc = pcN ?? o
    let gapHi = math.max(pc, o)
    let gapLo = math.min(pc, o)
    let pT = prevTs ?? ts
    for i in 0..levels.len {
      let lv0 = levels.get(i)
      // "Same session only": a session naked is invalidated only by price
      // traded during a later occurrence of that same session
      let allowed = lv0 == null || !sameSess || match lv0.code {
        "AS" => inAsia
        "LN" => inLondon
        "NY" => inNY
        "NC" => inClose
        _ => true
      }
      let gapOk = pcN != null && lv0 != null && lv0.startTime < pT
      if lv0 != null && allowed && nvStd1On && lv0.dev > 0.0 {
        let tolB = lv0.level * tolFactor
        let h0 = bandOn(lv0, 0) && (hitRange(bandY(lv0, 0), testLo, testHi, tolB) || (gapOk && hitRange(bandY(lv0, 0), gapLo, gapHi, tolB)))
        let h1 = bandOn(lv0, 1) && (hitRange(bandY(lv0, 1), testLo, testHi, tolB) || (gapOk && hitRange(bandY(lv0, 1), gapLo, gapHi, tolB)))
        let h2 = bandOn(lv0, 2) && (hitRange(bandY(lv0, 2), testLo, testHi, tolB) || (gapOk && hitRange(bandY(lv0, 2), gapLo, gapHi, tolB)))
        let h3 = bandOn(lv0, 3) && (hitRange(bandY(lv0, 3), testLo, testHi, tolB) || (gapOk && hitRange(bandY(lv0, 3), gapLo, gapHi, tolB)))
        if h0 || h1 || h2 || h3 {
          let hits = [h0, h1, h2, h3]
          for j in 0..4 {
            if hits[j] ?? false {
              if hideDead {
                let _ = nvBandL.delete(lv0.id * 4 + j)
              } else {
                let bc = j < 2 ? std1Color : std2Color
                nvBandL.get(lv0.id * 4 + j).set(
                  x1: lv0.startTime, y1: bandY(lv0, j), x2: ts, y2: bandY(lv0, j),
                  color: color.withAlpha(bc, 70), width: 1.0, style: linestyle.dotted, extend: extend.none
                )
              }
            }
          }
          levels.set(i, withTouch(lv0, lv0.touched, lv0.b1u || h0, lv0.b1d || h1, lv0.b2u || h2, lv0.b2d || h3))
        }
      }
      let cur = levels.get(i)
      if cur != null && allowed && !cur.touched {
        let lvl = cur
        let tol = lvl.level * tolFactor
        let gapHit = gapOk && gapLo <= lvl.level + tol && gapHi >= lvl.level - tol
        if (testLo <= lvl.level + tol && testHi >= lvl.level - tol) || gapHit {
          levels.set(i, withTouch(lvl, true, lvl.b1u, lvl.b1d, lvl.b2u, lvl.b2d))
          let _ = nvMarginL.delete(lvl.id)
          let _ = nvOriginL.delete(lvl.id)
          let _ = nvLines.delete(lvl.id)
          if !hideDead {
            // Opacity and width grow with R, so strong levels stand out
            let hc = histByScore ? color.withAlpha(nakedColor(lvl.code), 50 + lvl.score * 2) : deadColor
            let hw = histByScore ? 0.8 + float(lvl.score) / 40.0 : 1.0
            nvHistL.get(lvl.id).set(
              x1: lvl.startTime, y1: lvl.level, x2: ts, y2: lvl.level,
              color: hc, width: hw, style: histByScore ? linestyle.solid : linestyle.dotted, extend: extend.none
            )
            if nvHistLabel {
              nvHistT.get(lvl.id).set(x: ts, y: lvl.level * lblFactor, text: scoreText(lvl), color: histByScore ? scoreColor(lvl) : deadColor, size: math.max(8.0, nvBadgeSize - 2.0), zIndex: 30)
            }
          }
          nakedTouched.trigger(NakedAlert {
            period: lvl.code,
            level: lvl.level,
            score: lvl.score,
            message: str.format("Naked VWAP {0} mitigated at {1} ({2})", lvl.code, fmtPx(lvl.level), scoreText(lvl)),
          })
        } else {
          if nvLive && chart.isLast {
            nakedLine(lvl, ts)
          }
          if lvl.level > c {
            nearUp = nearUp == null ? lvl.level : math.min(nearUp ?? lvl.level, lvl.level)
          } else {
            nearDn = nearDn == null ? lvl.level : math.max(nearDn ?? lvl.level, lvl.level)
          }
        }
      } else if cur != null && !cur.touched && nvLive && chart.isLast {
        nakedLine(cur, ts)
      }
    }
  }

  // Nearest-X naked levels (live bar only): axis labels, score badges and
  // the highlighted set; the other lines are re-dimmed only when it changes.
  if showNaked && (nvAxis || nvDim) && chart.isLast {
    if topIds.len == 0 {
      for k in 0..48 {
        topIds.push(-1)
      }
    }
    let sig = axisSlots("4H", 0, c, nvAxis, nvAx4H_1, nvAx4H_2, nvAx4H_3) + axisSlots("D", 3, c, nvAxis, nvAxD_1, nvAxD_2, nvAxD_3) + axisSlots("W", 6, c, nvAxis, nvAxW_1, nvAxW_2, nvAxW_3) + axisSlots("M", 9, c, nvAxis, nvAxM_1, nvAxM_2, nvAxM_3) + axisSlots("Q", 12, c, nvAxis, nvAxQ_1, nvAxQ_2, nvAxQ_3) + axisSlots("Y", 15, c, nvAxis, nvAxY_1, nvAxY_2, nvAxY_3) + axisSlots("AS", 18, c, nvAxis, nvAxAS_1, nvAxAS_2, nvAxAS_3) + axisSlots("LN", 21, c, nvAxis, nvAxLN_1, nvAxLN_2, nvAxLN_3) + axisSlots("NY", 24, c, nvAxis, nvAxNY_1, nvAxNY_2, nvAxNY_3) + axisSlots("NC", 27, c, nvAxis, nvAxNC_1, nvAxNC_2, nvAxNC_3) + axisSlots("MH", 30, c, nvAxis, nvAxMH_1, nvAxMH_2, nvAxMH_3) + axisSlots("ML", 33, c, nvAxis, nvAxML_1, nvAxML_2, nvAxML_3) + axisSlots("WH", 36, c, nvAxis, nvAxWH_1, nvAxWH_2, nvAxWH_3) + axisSlots("WL", 39, c, nvAxis, nvAxWL_1, nvAxWL_2, nvAxWL_3) + axisSlots("DH", 42, c, nvAxis, nvAxDH_1, nvAxDH_2, nvAxDH_3) + axisSlots("DL", 45, c, nvAxis, nvAxDL_1, nvAxDL_2, nvAxDL_3)
    if nvDim && sig != topSig {
      topSig = sig
      for i in 0..levels.len {
        let lvl = levels.get(i)
        if lvl != null && !lvl.touched {
          nakedLine(lvl, ts)
        }
      }
    }
  }

  // --- 9. Alerts on the reference VWAP --------------------------------------
  let refV: float? = match alertPeriod {
    "4H" => v4H
    "Daily" => vD
    "Weekly" => vW
    "Monthly" => vM
    "Quarterly" => vQ
    _ => vY
  }
  let refD: float? = match alertPeriod {
    "4H" => d4H
    "Daily" => dD
    "Weekly" => dW
    "Monthly" => dM
    "Quarterly" => dQ
    _ => dY
  }
  let prevC = chart.close[1]
  let pRef = prevRefV
  if refV != null && pRef != null && prevC != null {
    if prevC <= pRef && c > refV {
      vwapCrossUp.trigger(VwapAlert { period: alertPeriod, price: c, vwap: refV, message: str.format("Close {0} crosses above VWAP {1} ({2})", c, alertPeriod, math.round(refV, 2)) })
    }
    if prevC >= pRef && c < refV {
      vwapCrossDown.trigger(VwapAlert { period: alertPeriod, price: c, vwap: refV, message: str.format("Close {0} crosses below VWAP {1} ({2})", c, alertPeriod, math.round(refV, 2)) })
    }
  }
  if refV != null && refD != null && refD > 0.0 {
    let up = refV + alertSigmaMult * refD
    let dn = refV - alertSigmaMult * refD
    if h >= up {
      bandUpper.trigger(VwapAlert { period: alertPeriod, price: h, vwap: refV, message: str.format("High {0} reaches +{1} of VWAP {2}", h, alertSigma, alertPeriod) })
    }
    if l <= dn {
      bandLower.trigger(VwapAlert { period: alertPeriod, price: l, vwap: refV, message: str.format("Low {0} reaches -{1} of VWAP {2}", l, alertSigma, alertPeriod) })
    }
  }
  prevRefV = refV

  // --- 10. HUD (live edge only) ----------------------------------------------
  if showHud && chart.isLast {
    let one = 1
    hudN = 1 + (show4H && (v4H ?? 0.0) > 0.0 ? one : 0) + (showDaily && (vD ?? 0.0) > 0.0 ? one : 0) + (showWeekly && (vW ?? 0.0) > 0.0 ? one : 0) + (showMonthly && (vM ?? 0.0) > 0.0 ? one : 0) + (showQuarterly && (vQ ?? 0.0) > 0.0 ? one : 0) + (showYearly && (vY ?? 0.0) > 0.0 ? one : 0) + (enableCustomAvwap && custOn && (cv ?? 0.0) > 0.0 ? one : 0) + (showNaked && nearUp != null ? one : 0) + (showNaked && nearDn != null ? one : 0)
    hudRow(0, "VWAP      LEVEL     DIST     Z", color.gray)
    let r = 1
    if show4H {
      r = hudVwapRow(r, "4H", v4H, d4H, c, color4H)
    }
    if showDaily {
      r = hudVwapRow(r, "D ", vD, dD, c, colorDaily)
    }
    if showWeekly {
      r = hudVwapRow(r, "W ", vW, dW, c, colorWeekly)
    }
    if showMonthly {
      r = hudVwapRow(r, "M ", vM, dM, c, colorMonthly)
    }
    if showQuarterly {
      r = hudVwapRow(r, "Q ", vQ, dQ, c, colorQuarterly)
    }
    if showYearly {
      r = hudVwapRow(r, "Y ", vY, dY, c, colorYearly)
    }
    if enableCustomAvwap {
      r = hudVwapRow(r, "AV", custOn ? cv : null, cd, c, colCustomAvwap)
    }
    if showNaked {
      let up = nearUp
      let dn = nearDn
      if up != null {
        hudRow(r, str.format("NV ▲  {0}  {1:+.2}%", math.round(up, 2), (up - c) / c * 100.0), color.withAlpha(color.red, 220))
        r += 1
      }
      if dn != null {
        hudRow(r, str.format("NV ▼  {0}  {1:+.2}%", math.round(dn, 2), (dn - c) / c * 100.0), color.withAlpha(color.green, 220))
        r += 1
      }
    }
    for k in r..16 {
      let _ = hudLabels.delete(k)
    }
  }
}

// Draws one periodic VWAP with its σ bands and fills (jump-free resets).
// Band lines needed only as fill edges are plotted transparent.
fn drawPeriod(col: color, vis: bool, bands: bool, fillOn: bool, v: float?, d: float?, ov: float?, od: float?, jNow: bool, jPrev: bool, mid: PlotLine, s1u: PlotLine, s1d: PlotLine, s2u: PlotLine, s2d: PlotLine, s3u: PlotLine, s3d: PlotLine, f1: Fill, f2u: Fill, f2d: Fill, f3: Fill) {
  let live = vis && v != null
  plotSeg(mid, col, live, false, jNow, jPrev, ov, v)
  let bOn = live && bands && d != null
  let fl1 = fillOn && fillStd1
  let fl2 = fillOn && fillStd2
  let fl3 = fillOn && fillStd3
  let need1 = bOn && (showStd1 || fl1 || fl2)
  let need2 = bOn && (showStd2 || fl2)
  let need3 = bOn && (showStd3 || fl3)
  let vv = v ?? 0.0
  let dd = d ?? 0.0
  let oOk = ov != null && od != null
  let ovv = ov ?? 0.0
  let odd = od ?? 0.0
  plotSeg(s1u, std1Color, need1, !showStd1, jNow, jPrev, oOk ? ovv + std1Mult * odd : null, vv + std1Mult * dd)
  plotSeg(s1d, std1Color, need1, !showStd1, jNow, jPrev, oOk ? ovv - std1Mult * odd : null, vv - std1Mult * dd)
  plotSeg(s2u, std2Color, need2, !showStd2, jNow, jPrev, oOk ? ovv + std2Mult * odd : null, vv + std2Mult * dd)
  plotSeg(s2d, std2Color, need2, !showStd2, jNow, jPrev, oOk ? ovv - std2Mult * odd : null, vv - std2Mult * dd)
  plotSeg(s3u, std3Color, need3, !showStd3, jNow, jPrev, oOk ? ovv + std3Mult * odd : null, vv + std3Mult * dd)
  plotSeg(s3d, std3Color, need3, !showStd3, jNow, jPrev, oOk ? ovv - std3Mult * odd : null, vv - std3Mult * dd)
  if bOn && !jNow && !jPrev {
    if fl1 {
      f1.fill()
    }
    if fl2 {
      f2u.fill()
      f2d.fill()
    }
    if fl3 {
      f3.fill()
    }
  }
}
