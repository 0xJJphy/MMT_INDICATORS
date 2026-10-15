script "VWAP Suite"

// ============================================================================
// INDICATOR: VWAP Suite (Multi-Period, Sessions, Anchored, Rolling & Naked)
// ENGINE:    MMT Scripting v3 (Strictly Typed DSL)
// AUTHOR:    PeByte
//
// Institutional-grade Volume-Weighted Average Price execution suite.
// Migrated to MMT Scripting v3 with compiled O(1) arithmetic, zero-allocation
// time-boundary detection, native hardware-accelerated entity pooling, inter-sigma
// channel fills, institutional statistical volume scoring, intraday session VWAPs,
// swing-anchored AVWAPs, macro calendar open AVWAPs, and day-based rolling VWMA.
// ============================================================================

data chart = subscribe(data.ohlcv)

input (
  // ==========================================================================
  // TAB 1: VWAPs PERIODICOS Y BANDAS
  // ==========================================================================
  input.tab(title: "VWAPs Periódicos")
  input.group(title: "Selección de Períodos y Estilos", collapsible: false)
  show4H        = input.bool(false, title: "4 Horas VWAP")
  color4H       = input.color(color.rgb(168, 181, 209), title: "4H Color")
  width4H       = input.float(1.5,  title: "4H Width", min: 0.5, max: 5.0)

  showDaily     = input.bool(true,  title: "Daily VWAP")
  colorDaily    = input.color(color.rgb(227, 179, 65),  title: "Daily Color")
  widthDaily    = input.float(2.0,  title: "Daily Width", min: 0.5, max: 5.0)

  showWeekly    = input.bool(true,  title: "Weekly VWAP")
  colorWeekly   = input.color(color.rgb(110, 207, 122), title: "Weekly Color")
  widthWeekly   = input.float(2.0,  title: "Weekly Width", min: 0.5, max: 5.0)

  showMonthly   = input.bool(false, title: "Monthly VWAP")
  colorMonthly  = input.color(color.rgb(78, 205, 196),  title: "Monthly Color")
  widthMonthly  = input.float(2.5,  title: "Monthly Width", min: 0.5, max: 5.0)

  showQuarterly = input.bool(false, title: "Quarterly VWAP")
  colorQuarterly = input.color(color.rgb(176, 132, 204), title: "Quarterly Color")
  widthQuarterly = input.float(2.5, title: "Quarterly Width", min: 0.5, max: 5.0)

  showYearly    = input.bool(false, title: "Yearly VWAP")
  colorYearly   = input.color(color.rgb(227, 110, 110), title: "Yearly Color")
  widthYearly   = input.float(3.0,  title: "Yearly Width", min: 0.5, max: 5.0)

  input.group(title: "Corte de Período (Anti-Salto Vertical)", collapsible: false)
  cutOnReset    = input.bool(true, title: "Evitar Línea Vertical en Cambio de Período")

  input.group(title: "Bandas de Desviación Estándar y Rellenos", collapsible: false)
  showStd1      = input.bool(true,  title: "Mostrar Std 1 (±1σ)")
  std1Mult      = input.float(1.0,  title: "Std 1 Multiplier", min: 0.1, max: 5.0)
  std1Color     = input.color(color.rgb(107, 139, 185), title: "Std 1 Color")
  fillStd1      = input.bool(true,  title: "Rellenar Canal Central (±1σ)")

  showStd2      = input.bool(false, title: "Mostrar Std 2 (±2σ)")
  std2Mult      = input.float(2.0,  title: "Std 2 Multiplier", min: 0.1, max: 5.0)
  std2Color     = input.color(color.rgb(176, 132, 204), title: "Std 2 Color")
  fillStd2      = input.bool(false, title: "Rellenar Anillo (1σ → 2σ)")

  showStd3      = input.bool(false, title: "Mostrar Std 3 (±3σ)")
  std3Mult      = input.float(3.0,  title: "Std 3 Multiplier", min: 0.1, max: 5.0)
  std3Color     = input.color(color.rgb(102, 175, 161), title: "Std 3 Color")
  fillStd3      = input.bool(false, title: "Rellenar Anillo (2σ → 3σ)")

  fillOpacity   = input.int(22,     title: "Opacidad de Relleno %", min: 0, max: 100)

  // ==========================================================================
  // TAB 2: SESIONES INTRADIARIAS (SESSION VWAPs)
  // ==========================================================================
  input.tab(title: "Sesiones Intradiarias")
  input.group(title: "Configuración General de Sesiones", collapsible: false)
  extendSessVWAP = input.bool(true, title: "Extender Sesión Previa como Benchmark")

  input.group(title: "Sesión Asia (Tokyo / Sydney · 00:00 - 08:00 UTC)", collapsible: false)
  showSessAsia   = input.bool(false, title: "Activar Asia Session VWAP")
  colSessAsia    = input.color(color.rgb(255, 183, 77), title: "Color Asia")
  widthSessAsia  = input.float(1.5, title: "Grosor Asia", min: 0.5, max: 5.0)

  input.group(title: "Sesión Londres (Frankfurt / London · 07:00 - 15:30 UTC)", collapsible: false)
  showSessLondon = input.bool(false, title: "Activar London Session VWAP")
  colSessLondon  = input.color(color.rgb(79, 195, 247), title: "Color Londres")
  widthSessLondon = input.float(1.5, title: "Grosor Londres", min: 0.5, max: 5.0)

  input.group(title: "Sesión New York (US Regular Cash · 13:30 - 20:00 UTC)", collapsible: false)
  showSessNY     = input.bool(false, title: "Activar New York Session VWAP")
  colSessNY      = input.color(color.rgb(186, 104, 200), title: "Color New York")
  widthSessNY    = input.float(2.0, title: "Grosor New York", min: 0.5, max: 5.0)

  input.group(title: "Sesión NY Close / Settlement (20:00 - 24:00 UTC)", collapsible: false)
  showSessClose  = input.bool(false, title: "Activar NY Close / Settlement VWAP")
  colSessClose   = input.color(color.rgb(255, 138, 101), title: "Color NY Close")
  widthSessClose = input.float(1.5, title: "Grosor NY Close", min: 0.5, max: 5.0)

  // ==========================================================================
  // TAB 3: ANCHORED VWAPs (AVWAP MODES)
  // ==========================================================================
  input.tab(title: "Anchored VWAPs")
  input.group(title: "AVWAPs Mensuales (Peak & Trough)", collapsible: false)
  enableMonthAvwap     = input.bool(true,  title: "Mes Actual: High / Low AVWAPs")
  colMonthHigh         = input.color(color.rgb(239, 83, 80),   title: "Cur Month High AVWAP")
  colMonthLow          = input.color(color.rgb(102, 187, 106), title: "Cur Month Low AVWAP")

  enablePrevMonthAvwap = input.bool(true,  title: "Mes Previo: High / Low AVWAPs (Benchmark Fijo)")
  colPrevMonthHigh     = input.color(color.rgb(255, 138, 128), title: "Prev Month High AVWAP")
  colPrevMonthLow      = input.color(color.rgb(185, 246, 202), title: "Prev Month Low AVWAP")

  input.group(title: "AVWAPs Semanales (Peak & Trough)", collapsible: false)
  enableWeekAvwap      = input.bool(false, title: "Semana Actual: High / Low AVWAPs")
  colWeekHigh          = input.color(color.rgb(244, 143, 177), title: "Cur Week High AVWAP")
  colWeekLow           = input.color(color.rgb(128, 203, 196), title: "Cur Week Low AVWAP")

  enablePrevWeekAvwap  = input.bool(false, title: "Semana Previa: High / Low AVWAPs")
  colPrevWeekHigh      = input.color(color.rgb(248, 187, 208), title: "Prev Week High AVWAP")
  colPrevWeekLow       = input.color(color.rgb(178, 223, 219), title: "Prev Week Low AVWAP")

  input.group(title: "AVWAPs Diarios (Day Trading & Scalping)", collapsible: false)
  enableDayAvwap       = input.bool(false, title: "Día Actual: High / Low AVWAPs")
  colDayHigh           = input.color(color.rgb(255, 202, 40),  title: "Cur Day High AVWAP")
  colDayLow            = input.color(color.rgb(141, 110, 99),  title: "Cur Day Low AVWAP")

  enablePrevDayAvwap   = input.bool(false, title: "Día Previo: High / Low AVWAPs (Benchmark Intradía)")
  colPrevDayHigh       = input.color(color.rgb(255, 224, 130), title: "Prev Day High AVWAP")
  colPrevDayLow        = input.color(color.rgb(188, 170, 164), title: "Prev Day Low AVWAP")

  input.group(title: "AVWAPs Macro Calendar Open (Hedge Fund Benchmarks)", collapsible: false)
  enableYtdAvwap       = input.bool(false, title: "Year-to-Date (YTD) Open AVWAP")
  colYtdAvwap          = input.color(color.rgb(255, 215, 0),   title: "Color YTD Open")

  enableMtdAvwap       = input.bool(false, title: "Month-to-Date (MTD) Open AVWAP")
  colMtdAvwap          = input.color(color.rgb(0, 230, 118),   title: "Color MTD Open")

  // ==========================================================================
  // TAB 4: NAKED VWAPs
  // ==========================================================================
  input.tab(title: "Naked VWAPs")
  input.group(title: "Seguimiento y Detección de Niveles", collapsible: false)
  showNaked     = input.bool(true,  title: "Activar Naked VWAPs")
  nakedOnlyMode = input.bool(false, title: "Modo Solo Naked (Ocultar VWAPs vivos)")
  hideDead      = input.bool(false, title: "Ocultar Niveles Mitigados (Tocados)")
  nakedTouch    = input.select("Wick", title: "Criterio de Toque", options: ["Wick", "Body"])
  nakedTolBps   = input.float(2.0,  title: "Tolerancia de Toque (bps)", min: 0.0, max: 50.0)

  nk4H          = input.bool(false, title: "Incluir 4H")
  nkD           = input.bool(true,  title: "Incluir Diario")
  nkW           = input.bool(true,  title: "Incluir Semanal")
  nkM           = input.bool(true,  title: "Incluir Mensual")
  nkQ           = input.bool(false, title: "Incluir Trimestral")
  nkY           = input.bool(false, title: "Incluir Anual")

  input.group(title: "Etiquetas y Estilo de Naked VWAPs", collapsible: false)
  showScores    = input.bool(true,  title: "Mostrar Score en la Etiqueta (ej: [Score: 78])")
  showNvPrice   = input.bool(true,  title: "Mostrar Precio en la Etiqueta")
  nvTagPos      = input.select("Right Chart Margin (Inset)", title: "Ubicación de la Etiqueta", options: ["Right Chart Margin (Inset)", "At Level Origin (Start)", "At Current Price (Live Edge)", "Both (Origin & Margin)", "None (Solo Líneas)"])
  nvLineStyle   = input.select("Dashed", title: "Estilo de Línea Naked", options: ["Dashed", "Solid", "Dotted"])
  nvLineWidth   = input.float(1.5,  title: "Grosor de Línea", min: 0.5, max: 5.0)
  nvExtend      = input.bool(true,  title: "Extender Línea a la Derecha")
  nvOffsetBps   = input.float(12.0, title: "Elevación sobre Línea (bps)", min: 0.0, max: 50.0)
  nvBadgeSize   = input.float(11.0, title: "Tamaño de Fuente", min: 8.0, max: 20.0)

  // ==========================================================================
  // TAB 5: ROLLING VWAPs (EN DÍAS)
  // ==========================================================================
  input.tab(title: "Rolling VWAPs")
  input.group(title: "Configuración en Días (Adaptación Automática a Temporalidad)", collapsible: false)
  showRoll1     = input.bool(false, title: "Activar Rolling VWAP 1")
  rollDays1     = input.float(7.0,  title: "Período Rolling 1 (Días)", min: 0.1, max: 365.0)
  rollCol1      = input.color(color.rgb(255, 107, 107), title: "Color Rolling 1")

  showRoll2     = input.bool(false, title: "Activar Rolling VWAP 2")
  rollDays2     = input.float(30.0, title: "Período Rolling 2 (Días)", min: 0.5, max: 365.0)
  rollCol2      = input.color(color.rgb(78, 205, 196),  title: "Color Rolling 2")

  showRoll3     = input.bool(false, title: "Activar Rolling VWAP 3")
  rollDays3     = input.float(90.0, title: "Período Rolling 3 (Días)", min: 1.0, max: 365.0)
  rollCol3      = input.color(color.rgb(255, 217, 61),  title: "Color Rolling 3")
)

setup (
  fillA = int(math.round(float(fillOpacity) * 2.55)) ?? 56
  std1FillColor = color.withAlpha(std1Color, fillA)
  std2FillColor = color.withAlpha(std2Color, fillA)
  std3FillColor = color.withAlpha(std3Color, fillA)

  // Daily session definitions in UTC
  sessAsia   = time.session("00:00", "08:00")
  sessLondon = time.session("07:00", "15:30")
  sessNY     = time.session("13:30", "20:00")
  sessClose  = time.session("20:00", "24:00")

  // Automatic conversion of Rolling Days into exact bar lengths for the active timeframe
  chartTfSec = math.max(1, time.tfSeconds(context.timeframe))
  rollBars1  = math.max(2, math.min(10000, int(math.round(rollDays1 * 86400.0 / float(chartTfSec))) ?? 168))
  rollBars2  = math.max(2, math.min(10000, int(math.round(rollDays2 * 86400.0 / float(chartTfSec))) ?? 720))
  rollBars3  = math.max(2, math.min(10000, int(math.round(rollDays3 * 86400.0 / float(chartTfSec))) ?? 2160))
)

plot (
  // --------------------------------------------------------------------------
  // 1. Periodic VWAPs & StdDev Bands (42 plots)
  // --------------------------------------------------------------------------
  // 4H
  p4h      = plot.line(title: "4H VWAP", color: color4H, width: width4H)
  p4h_s1u  = plot.line(title: "4H +1σ",  color: std1Color, width: 1.0, style: linestyle.dashed)
  p4h_s1d  = plot.line(title: "4H -1σ",  color: std1Color, width: 1.0, style: linestyle.dashed)
  p4h_s2u  = plot.line(title: "4H +2σ",  color: std2Color, width: 1.0, style: linestyle.dotted)
  p4h_s2d  = plot.line(title: "4H -2σ",  color: std2Color, width: 1.0, style: linestyle.dotted)
  p4h_s3u  = plot.line(title: "4H +3σ",  color: std3Color, width: 1.0, style: linestyle.dotted)
  p4h_s3d  = plot.line(title: "4H -3σ",  color: std3Color, width: 1.0, style: linestyle.dotted)

  // Daily
  pd       = plot.line(title: "Daily VWAP", color: colorDaily, width: widthDaily)
  pd_s1u   = plot.line(title: "D +1σ",      color: std1Color, width: 1.0, style: linestyle.dashed)
  pd_s1d   = plot.line(title: "D -1σ",      color: std1Color, width: 1.0, style: linestyle.dashed)
  pd_s2u   = plot.line(title: "D +2σ",      color: std2Color, width: 1.0, style: linestyle.dotted)
  pd_s2d   = plot.line(title: "D -2σ",      color: std2Color, width: 1.0, style: linestyle.dotted)
  pd_s3u   = plot.line(title: "D +3σ",      color: std3Color, width: 1.0, style: linestyle.dotted)
  pd_s3d   = plot.line(title: "D -3σ",      color: std3Color, width: 1.0, style: linestyle.dotted)

  // Weekly
  pw       = plot.line(title: "Weekly VWAP", color: colorWeekly, width: widthWeekly)
  pw_s1u   = plot.line(title: "W +1σ",       color: std1Color, width: 1.0, style: linestyle.dashed)
  pw_s1d   = plot.line(title: "W -1σ",       color: std1Color, width: 1.0, style: linestyle.dashed)
  pw_s2u   = plot.line(title: "W +2σ",       color: std2Color, width: 1.0, style: linestyle.dotted)
  pw_s2d   = plot.line(title: "W -2σ",       color: std2Color, width: 1.0, style: linestyle.dotted)
  pw_s3u   = plot.line(title: "W +3σ",       color: std3Color, width: 1.0, style: linestyle.dotted)
  pw_s3d   = plot.line(title: "W -3σ",       color: std3Color, width: 1.0, style: linestyle.dotted)

  // Monthly
  pm       = plot.line(title: "Monthly VWAP", color: colorMonthly, width: widthMonthly)
  pm_s1u   = plot.line(title: "M +1σ",        color: std1Color, width: 1.0, style: linestyle.dashed)
  pm_s1d   = plot.line(title: "M -1σ",        color: std1Color, width: 1.0, style: linestyle.dashed)
  pm_s2u   = plot.line(title: "M +2σ",        color: std2Color, width: 1.0, style: linestyle.dotted)
  pm_s2d   = plot.line(title: "M -2σ",        color: std2Color, width: 1.0, style: linestyle.dotted)
  pm_s3u   = plot.line(title: "M +3σ",        color: std3Color, width: 1.0, style: linestyle.dotted)
  pm_s3d   = plot.line(title: "M -3σ",        color: std3Color, width: 1.0, style: linestyle.dotted)

  // Quarterly
  pq       = plot.line(title: "Quarterly VWAP", color: colorQuarterly, width: widthQuarterly)
  pq_s1u   = plot.line(title: "Q +1σ",          color: std1Color, width: 1.0, style: linestyle.dashed)
  pq_s1d   = plot.line(title: "Q -1σ",          color: std1Color, width: 1.0, style: linestyle.dashed)
  pq_s2u   = plot.line(title: "Q +2σ",          color: std2Color, width: 1.0, style: linestyle.dotted)
  pq_s2d   = plot.line(title: "Q -2σ",          color: std2Color, width: 1.0, style: linestyle.dotted)
  pq_s3u   = plot.line(title: "Q +3σ",          color: std3Color, width: 1.0, style: linestyle.dotted)
  pq_s3d   = plot.line(title: "Q -3σ",          color: std3Color, width: 1.0, style: linestyle.dotted)

  // Yearly
  py       = plot.line(title: "Yearly VWAP", color: colorYearly, width: widthYearly)
  py_s1u   = plot.line(title: "Y +1σ",       color: std1Color, width: 1.0, style: linestyle.dashed)
  py_s1d   = plot.line(title: "Y -1σ",       color: std1Color, width: 1.0, style: linestyle.dashed)
  py_s2u   = plot.line(title: "Y +2σ",       color: std2Color, width: 1.0, style: linestyle.dotted)
  py_s2d   = plot.line(title: "Y -2σ",       color: std2Color, width: 1.0, style: linestyle.dotted)
  py_s3u   = plot.line(title: "Y +3σ",       color: std3Color, width: 1.0, style: linestyle.dotted)
  py_s3d   = plot.line(title: "Y -3σ",       color: std3Color, width: 1.0, style: linestyle.dotted)

  // --------------------------------------------------------------------------
  // 2. Session VWAPs (4 plots)
  // --------------------------------------------------------------------------
  pSessAsia   = plot.line(title: "Asia Session VWAP",     color: colSessAsia,    width: widthSessAsia)
  pSessLondon = plot.line(title: "London Session VWAP",   color: colSessLondon,  width: widthSessLondon)
  pSessNY     = plot.line(title: "New York Session VWAP", color: colSessNY,      width: widthSessNY)
  pSessClose  = plot.line(title: "NY Close Session VWAP", color: colSessClose,   width: widthSessClose)

  // --------------------------------------------------------------------------
  // 3. Anchored VWAPs (14 plots)
  // --------------------------------------------------------------------------
  // Monthly Peak & Trough
  pMHigh     = plot.line(title: "Cur Month High AVWAP",   color: colMonthHigh,     width: 2.0, style: linestyle.solid)
  pMLow      = plot.line(title: "Cur Month Low AVWAP",    color: colMonthLow,      width: 2.0, style: linestyle.solid)
  pPrevMHigh = plot.line(title: "Prev Month High AVWAP",  color: colPrevMonthHigh, width: 2.0, style: linestyle.dashed)
  pPrevMLow  = plot.line(title: "Prev Month Low AVWAP",   color: colPrevMonthLow,  width: 2.0, style: linestyle.dashed)

  // Weekly Peak & Trough
  pWHigh     = plot.line(title: "Cur Week High AVWAP",    color: colWeekHigh,      width: 1.5, style: linestyle.solid)
  pWLow      = plot.line(title: "Cur Week Low AVWAP",     color: colWeekLow,       width: 1.5, style: linestyle.solid)
  pPrevWHigh = plot.line(title: "Prev Week High AVWAP",   color: colPrevWeekHigh,  width: 1.5, style: linestyle.dashed)
  pPrevWLow  = plot.line(title: "Prev Week Low AVWAP",    color: colPrevWeekLow,   width: 1.5, style: linestyle.dashed)

  // Daily Peak & Trough
  pDHigh     = plot.line(title: "Cur Day High AVWAP",     color: colDayHigh,       width: 1.5, style: linestyle.solid)
  pDLow      = plot.line(title: "Cur Day Low AVWAP",      color: colDayLow,        width: 1.5, style: linestyle.solid)
  pPrevDHigh = plot.line(title: "Prev Day High AVWAP",    color: colPrevDayHigh,   width: 1.5, style: linestyle.dashed)
  pPrevDLow  = plot.line(title: "Prev Day Low AVWAP",     color: colPrevDayLow,    width: 1.5, style: linestyle.dashed)

  // Macro Calendar Opens
  pYtdOpen   = plot.line(title: "YTD Open AVWAP",         color: colYtdAvwap,      width: 2.0, style: linestyle.solid)
  pMtdOpen   = plot.line(title: "MTD Open AVWAP",         color: colMtdAvwap,      width: 1.5, style: linestyle.solid)

  // --------------------------------------------------------------------------
  // 4. Rolling VWAPs (Days) (3 plots)
  // --------------------------------------------------------------------------
  pr1        = plot.line(title: "Rolling VWAP 1", color: rollCol1, width: 1.5)
  pr2        = plot.line(title: "Rolling VWAP 2", color: rollCol2, width: 1.5)
  pr3        = plot.line(title: "Rolling VWAP 3", color: rollCol3, width: 1.5)
)

fill (
  // 4H Fills
  f4h_s1  = fill.between(p4h_s1u, p4h_s1d, color: std1FillColor)
  f4h_s2u = fill.between(p4h_s2u, p4h_s1u, color: std2FillColor)
  f4h_s2d = fill.between(p4h_s1d, p4h_s2d, color: std2FillColor)
  f4h_s3u = fill.between(p4h_s3u, p4h_s2u, color: std3FillColor)
  f4h_s3d = fill.between(p4h_s2d, p4h_s3d, color: std3FillColor)

  // Daily Fills
  fd_s1   = fill.between(pd_s1u,  pd_s1d,  color: std1FillColor)
  fd_s2u  = fill.between(pd_s2u,  pd_s1u,  color: std2FillColor)
  fd_s2d  = fill.between(pd_s1d,  pd_s2d,  color: std2FillColor)
  fd_s3u  = fill.between(pd_s3u,  pd_s2u,  color: std3FillColor)
  fd_s3d  = fill.between(pd_s2d,  pd_s3d,  color: std3FillColor)

  // Weekly Fills
  fw_s1   = fill.between(pw_s1u,  pw_s1d,  color: std1FillColor)
  fw_s2u  = fill.between(pw_s2u,  pw_s1u,  color: std2FillColor)
  fw_s2d  = fill.between(pw_s1d,  pw_s2d,  color: std2FillColor)
  fw_s3u  = fill.between(pw_s3u,  pw_s2u,  color: std3FillColor)
  fw_s3d  = fill.between(pw_s2d,  pw_s3d,  color: std3FillColor)

  // Monthly Fills
  fm_s1   = fill.between(pm_s1u,  pm_s1d,  color: std1FillColor)
  fm_s2u  = fill.between(pm_s2u,  pm_s1u,  color: std2FillColor)
  fm_s2d  = fill.between(pm_s1d,  pm_s2d,  color: std2FillColor)
  fm_s3u  = fill.between(pm_s3u,  pm_s2u,  color: std3FillColor)
  fm_s3d  = fill.between(pm_s2d,  pm_s3d,  color: std3FillColor)

  // Quarterly Fills
  fq_s1   = fill.between(pq_s1u,  pq_s1d,  color: std1FillColor)
  fq_s2u  = fill.between(pq_s2u,  pq_s1u,  color: std2FillColor)
  fq_s2d  = fill.between(pq_s1d,  pq_s2d,  color: std2FillColor)
  fq_s3u  = fill.between(pq_s3u,  pq_s2u,  color: std3FillColor)
  fq_s3d  = fill.between(pq_s2d,  pq_s3d,  color: std3FillColor)

  // Yearly Fills
  fy_s1   = fill.between(py_s1u,  py_s1d,  color: std1FillColor)
  fy_s2u  = fill.between(py_s2u,  py_s1u,  color: std2FillColor)
  fy_s2d  = fill.between(py_s1d,  py_s2d,  color: std2FillColor)
  fy_s3u  = fill.between(py_s3u,  py_s2u,  color: std3FillColor)
  fy_s3d  = fill.between(py_s2d,  py_s3d,  color: std3FillColor)
)

type NakedLevel {
  id: int
  code: string
  level: float
  startTime: time
  touched: bool
  touchTime: time?
  scoreR: int
}

state (
  nvLines   = entities.linePool(max: 120)
  nvMargin  = entities.labelPool(max: 120, anchor: anchor.right)
  nvPills   = entities.labelPool(max: 120)
  levels    = NakedLevel[](120)
  nextNvId: int = 1

  // Period end tracking for NVWAP capture
  last4H_V: float? = null
  lastD_V:  float? = null
  lastW_V:  float? = null
  lastM_V:  float? = null
  lastQ_V:  float? = null
  lastY_V:  float? = null

  // Volume accumulation per period for institutional scoring
  curPeriodVol4H: float = 0.0
  histVols4H: rolling<float> = rolling<float>(30)

  curPeriodVolD: float = 0.0
  histVolsD: rolling<float> = rolling<float>(30)

  curPeriodVolW: float = 0.0
  histVolsW: rolling<float> = rolling<float>(20)

  curPeriodVolM: float = 0.0
  histVolsM: rolling<float> = rolling<float>(12)

  // Session VWAPs Accumulators
  asiaPV: float = 0.0
  asiaV:  float = 0.0
  lastAsiaVWAP: float? = null

  londonPV: float = 0.0
  londonV:  float = 0.0
  lastLondonVWAP: float? = null

  nyPV: float = 0.0
  nyV:  float = 0.0
  lastNyVWAP: float? = null

  closePV: float = 0.0
  closeV:  float = 0.0
  lastCloseVWAP: float? = null

  // Monthly AVWAPs State (Peak & Trough)
  curMonthHigh: float = -1.0
  curMonthLow:  float = 1e12
  mHiPV: float = 0.0
  mHiV:  float = 0.0
  mLoPV: float = 0.0
  mLoV:  float = 0.0
  prevMHiPV: float = 0.0
  prevMHiV:  float = 0.0
  prevMLoPV: float = 0.0
  prevMLoV:  float = 0.0
  hasPrevMonth: bool = false

  // Weekly AVWAPs State (Peak & Trough)
  curWeekHigh: float = -1.0
  curWeekLow:  float = 1e12
  wHiPV: float = 0.0
  wHiV:  float = 0.0
  wLoPV: float = 0.0
  wLoV:  float = 0.0
  prevWHiPV: float = 0.0
  prevWHiV:  float = 0.0
  prevWLoPV: float = 0.0
  prevWLoV:  float = 0.0
  hasPrevWeek: bool = false

  // Daily AVWAPs State (Peak & Trough)
  curDayHigh: float = -1.0
  curDayLow:  float = 1e12
  dHiPV: float = 0.0
  dHiV:  float = 0.0
  dLoPV: float = 0.0
  dLoV:  float = 0.0
  prevDHiPV: float = 0.0
  prevDHiV:  float = 0.0
  prevDLoPV: float = 0.0
  prevDLoV:  float = 0.0
  hasPrevDay: bool = false

  // Macro Calendar Opens (YTD, MTD)
  ytdPV: float = 0.0
  ytdV:  float = 0.0

  mtdPV: float = 0.0
  mtdV:  float = 0.0
)

fn registerNakedLevel(code: string, lvl: float, t: time, score: int) {
  let newLvl = NakedLevel {
    id: nextNvId,
    code: code,
    level: lvl,
    startTime: t,
    touched: false,
    touchTime: null,
    scoreR: score
  }

  if levels.len < levels.capacity {
    nextNvId += 1
    if nextNvId > 500000 {
      nextNvId = 1
    }
    let _ = levels.push(newLvl)
  } else {
    let repIdx: int = -1
    for k in 0..levels.len {
      if repIdx == -1 {
        let it = levels.get(k)
        if it != null && it.touched {
          repIdx = k
        }
      }
    }
    nextNvId += 1
    if nextNvId > 500000 {
      nextNvId = 1
    }
    if repIdx != -1 {
      let old = levels.get(repIdx)
      if old != null {
        let _ = nvLines.delete(str.format("nv_{0}", old.id))
        let _ = nvMargin.delete(str.format("nvm_{0}", old.id))
        let _ = nvPills.delete(str.format("nvp_{0}", old.id))
      }
      levels.set(repIdx, newLvl)
    } else {
      let old = levels.get(0)
      if old != null {
        let _ = nvLines.delete(str.format("nv_{0}", old.id))
        let _ = nvMargin.delete(str.format("nvm_{0}", old.id))
        let _ = nvPills.delete(str.format("nvp_{0}", old.id))
      }
      levels.set(0, newLvl)
    }
  }
}

on chart.update {
  let ts = chart.time ?? time.fromUnixSeconds(0)
  let prevTs = chart.time[1]
  let barClose = chart.close ?? 0.0
  let barOpen  = chart.open  ?? 0.0
  let barHigh  = chart.high  ?? 0.0
  let barLow   = chart.low   ?? 0.0
  let barVol   = chart.volume ?? 0.0
  let tp       = (barHigh + barLow + barClose) / 3.0
  let pv       = tp * barVol

  // 1. Period boundary checks
  let isNew4H = time.isNewPeriod(ts, prevTs, 4h)
  let isNewD  = time.isNewPeriod(ts, prevTs, 1D)
  let isNewW  = time.isNewPeriod(ts, prevTs, 1W)
  let isNewM  = time.isNewPeriod(ts, prevTs, 1M)
  let isNewQ  = time.isNewPeriod(ts, prevTs, 3M)
  let isNewY  = time.isNewPeriod(ts, prevTs, 1Y)

  // 2. Statistical Volume Scoring on Completed Periods (Prior to Reset)
  let score4H: int = 50
  if isNew4H {
    if curPeriodVol4H > 0.0 {
      let mean4H = histVols4H.len >= 3 ? (histVols4H.avg() ?? curPeriodVol4H) : curPeriodVol4H
      let ratio4H = mean4H > 0.0 ? (curPeriodVol4H / mean4H) : 1.0
      score4H = int(math.round(math.max(20.0, math.min(99.0, ratio4H * 50.0)))) ?? 50
      histVols4H.push(curPeriodVol4H)
    }
    curPeriodVol4H = barVol
  } else {
    curPeriodVol4H += barVol
  }

  let scoreD: int = 55
  if isNewD {
    if curPeriodVolD > 0.0 {
      let meanD = histVolsD.len >= 3 ? (histVolsD.avg() ?? curPeriodVolD) : curPeriodVolD
      let ratioD = meanD > 0.0 ? (curPeriodVolD / meanD) : 1.0
      scoreD = int(math.round(math.max(20.0, math.min(99.0, ratioD * 50.0)))) ?? 55
      histVolsD.push(curPeriodVolD)
    }
    curPeriodVolD = barVol
  } else {
    curPeriodVolD += barVol
  }

  let scoreW: int = 70
  if isNewW {
    if curPeriodVolW > 0.0 {
      let meanW = histVolsW.len >= 2 ? (histVolsW.avg() ?? curPeriodVolW) : curPeriodVolW
      let ratioW = meanW > 0.0 ? (curPeriodVolW / meanW) : 1.0
      scoreW = int(math.round(math.max(25.0, math.min(99.0, ratioW * 60.0)))) ?? 70
      histVolsW.push(curPeriodVolW)
    }
    curPeriodVolW = barVol
  } else {
    curPeriodVolW += barVol
  }

  let scoreM: int = 80
  if isNewM {
    if curPeriodVolM > 0.0 {
      let meanM = histVolsM.len >= 2 ? (histVolsM.avg() ?? curPeriodVolM) : curPeriodVolM
      let ratioM = meanM > 0.0 ? (curPeriodVolM / meanM) : 1.0
      scoreM = int(math.round(math.max(30.0, math.min(99.0, ratioM * 70.0)))) ?? 80
      histVolsM.push(curPeriodVolM)
    }
    curPeriodVolM = barVol
  } else {
    curPeriodVolM += barVol
  }

  // 3. Capture completed periods for Naked VWAPs with their institutional scores
  if showNaked && prevTs != null {
    if isNew4H && nk4H && last4H_V != null {
      registerNakedLevel("4H", last4H_V, prevTs, score4H)
    }
    if isNewD && nkD && lastD_V != null {
      registerNakedLevel("D", lastD_V, prevTs, scoreD)
    }
    if isNewW && nkW && lastW_V != null {
      registerNakedLevel("W", lastW_V, prevTs, scoreW)
    }
    if isNewM && nkM && lastM_V != null {
      registerNakedLevel("M", lastM_V, prevTs, scoreM)
    }
    if isNewQ && nkQ && lastQ_V != null {
      registerNakedLevel("Q", lastQ_V, prevTs, 90)
    }
    if isNewY && nkY && lastY_V != null {
      registerNakedLevel("Y", lastY_V, prevTs, 95)
    }
  }

  // 4. Native Multi-Period VWAP & VWAP Dev evaluation (Hardware Accelerated)
  let v4H = chart.vwap(reset: isNew4H)
  let d4H = chart.vwapDev(reset: isNew4H)
  last4H_V = v4H

  let vD = chart.vwap(reset: isNewD)
  let dD = chart.vwapDev(reset: isNewD)
  lastD_V = vD

  let vW = chart.vwap(reset: isNewW)
  let dW = chart.vwapDev(reset: isNewW)
  lastW_V = vW

  let vM = chart.vwap(reset: isNewM)
  let dM = chart.vwapDev(reset: isNewM)
  lastM_V = vM

  let vQ = chart.vwap(reset: isNewQ)
  let dQ = chart.vwapDev(reset: isNewQ)
  lastQ_V = vQ

  let vY = chart.vwap(reset: isNewY)
  let dY = chart.vwapDev(reset: isNewY)
  lastY_V = vY

  let hideLive = showNaked && nakedOnlyMode

  // 5. Intraday Session VWAPs Evaluation (Asia, London, New York, NY Close)
  // Asia (00:00 - 08:00 UTC)
  let inAsia = sessAsia.contains(ts)
  let wasInAsia = prevTs != null ? sessAsia.contains(prevTs) : false
  let isStartAsia = inAsia && !wasInAsia
  if isStartAsia {
    asiaPV = pv
    asiaV  = barVol
  } else if inAsia {
    asiaPV += pv
    asiaV  += barVol
  } else if wasInAsia && asiaV > 0.0 {
    lastAsiaVWAP = asiaPV / asiaV
  }
  let curAsiaVal: float? = inAsia && asiaV > 0.0 ? (asiaPV / asiaV) : (extendSessVWAP ? lastAsiaVWAP : null)
  let cutAsia = cutOnReset && isStartAsia
  pSessAsia.plot(showSessAsia && !cutAsia ? curAsiaVal : null, color: cutAsia ? color.transparent : colSessAsia)

  // London (07:00 - 15:30 UTC)
  let inLondon = sessLondon.contains(ts)
  let wasInLondon = prevTs != null ? sessLondon.contains(prevTs) : false
  let isStartLondon = inLondon && !wasInLondon
  if isStartLondon {
    londonPV = pv
    londonV  = barVol
  } else if inLondon {
    londonPV += pv
    londonV  += barVol
  } else if wasInLondon && londonV > 0.0 {
    lastLondonVWAP = londonPV / londonV
  }
  let curLondonVal: float? = inLondon && londonV > 0.0 ? (londonPV / londonV) : (extendSessVWAP ? lastLondonVWAP : null)
  let cutLondon = cutOnReset && isStartLondon
  pSessLondon.plot(showSessLondon && !cutLondon ? curLondonVal : null, color: cutLondon ? color.transparent : colSessLondon)

  // New York (13:30 - 20:00 UTC)
  let inNY = sessNY.contains(ts)
  let wasInNY = prevTs != null ? sessNY.contains(prevTs) : false
  let isStartNY = inNY && !wasInNY
  if isStartNY {
    nyPV = pv
    nyV  = barVol
  } else if inNY {
    nyPV += pv
    nyV  += barVol
  } else if wasInNY && nyV > 0.0 {
    lastNyVWAP = nyPV / nyV
  }
  let curNyVal: float? = inNY && nyV > 0.0 ? (nyPV / nyV) : (extendSessVWAP ? lastNyVWAP : null)
  let cutNY = cutOnReset && isStartNY
  pSessNY.plot(showSessNY && !cutNY ? curNyVal : null, color: cutNY ? color.transparent : colSessNY)

  // NY Close / Settlement (20:00 - 24:00 UTC)
  let inClose = sessClose.contains(ts)
  let wasInClose = prevTs != null ? sessClose.contains(prevTs) : false
  let isStartClose = inClose && !wasInClose
  if isStartClose {
    closePV = pv
    closeV  = barVol
  } else if inClose {
    closePV += pv
    closeV  += barVol
  } else if wasInClose && closeV > 0.0 {
    lastCloseVWAP = closePV / closeV
  }
  let curCloseVal: float? = inClose && closeV > 0.0 ? (closePV / closeV) : (extendSessVWAP ? lastCloseVWAP : null)
  let cutClose = cutOnReset && isStartClose
  pSessClose.plot(showSessClose && !cutClose ? curCloseVal : null, color: cutClose ? color.transparent : colSessClose)

  // 6. Anchored VWAPs (Peak & Trough Extremes + Macro Calendar Opens)
  // Monthly Peak & Trough
  let isNewMHi = !isNewM && (barHigh > curMonthHigh)
  let isNewMLo = !isNewM && (barLow < curMonthLow)

  if isNewM {
    if mHiV > 0.0 && mLoV > 0.0 {
      prevMHiPV = mHiPV
      prevMHiV  = mHiV
      prevMLoPV = mLoPV
      prevMLoV  = mLoV
      hasPrevMonth = true
    }
    curMonthHigh = barHigh
    curMonthLow  = barLow
    mHiPV = pv
    mHiV  = barVol
    mLoPV = pv
    mLoV  = barVol
  } else {
    if hasPrevMonth {
      prevMHiPV += pv
      prevMHiV  += barVol
      prevMLoPV += pv
      prevMLoV  += barVol
    }
    if barHigh > curMonthHigh {
      curMonthHigh = barHigh
      mHiPV = pv
      mHiV  = barVol
    } else {
      mHiPV += pv
      mHiV  += barVol
    }

    if barLow < curMonthLow {
      curMonthLow = barLow
      mLoPV = pv
      mLoV  = barVol
    } else {
      mLoPV += pv
      mLoV  += barVol
    }
  }

  let cAvwapM = cutOnReset && isNewM
  let curMHiPlot: float? = (enableMonthAvwap && !cAvwapM && !isNewMHi && mHiV > 0.0) ? (mHiPV / mHiV) : null
  let curMLoPlot: float? = (enableMonthAvwap && !cAvwapM && !isNewMLo && mLoV > 0.0) ? (mLoPV / mLoV) : null
  pMHigh.plot(curMHiPlot, color: cAvwapM ? color.transparent : colMonthHigh)
  pMLow.plot(curMLoPlot,   color: cAvwapM ? color.transparent : colMonthLow)

  let prevMHiPlot: float? = (enablePrevMonthAvwap && !cAvwapM && hasPrevMonth && prevMHiV > 0.0) ? (prevMHiPV / prevMHiV) : null
  let prevMLoPlot: float? = (enablePrevMonthAvwap && !cAvwapM && hasPrevMonth && prevMLoV > 0.0) ? (prevMLoPV / prevMLoV) : null
  pPrevMHigh.plot(prevMHiPlot, color: cAvwapM ? color.transparent : colPrevMonthHigh)
  pPrevMLow.plot(prevMLoPlot,   color: cAvwapM ? color.transparent : colPrevMonthLow)

  // Weekly Peak & Trough
  let isNewWHi = !isNewW && (barHigh > curWeekHigh)
  let isNewWLo = !isNewW && (barLow < curWeekLow)

  if isNewW {
    if wHiV > 0.0 && wLoV > 0.0 {
      prevWHiPV = wHiPV
      prevWHiV  = wHiV
      prevWLoPV = wLoPV
      prevWLoV  = wLoV
      hasPrevWeek = true
    }
    curWeekHigh = barHigh
    curWeekLow  = barLow
    wHiPV = pv
    wHiV  = barVol
    wLoPV = pv
    wLoV  = barVol
  } else {
    if hasPrevWeek {
      prevWHiPV += pv
      prevWHiV  += barVol
      prevWLoPV += pv
      prevWLoV  += barVol
    }
    if barHigh > curWeekHigh {
      curWeekHigh = barHigh
      wHiPV = pv
      wHiV  = barVol
    } else {
      wHiPV += pv
      wHiV  += barVol
    }

    if barLow < curWeekLow {
      curWeekLow = barLow
      wLoPV = pv
      wLoV  = barVol
    } else {
      wLoPV += pv
      wLoV  += barVol
    }
  }

  let cAvwapW = cutOnReset && isNewW
  let curWHiPlot: float? = (enableWeekAvwap && !cAvwapW && !isNewWHi && wHiV > 0.0) ? (wHiPV / wHiV) : null
  let curWLoPlot: float? = (enableWeekAvwap && !cAvwapW && !isNewWLo && wLoV > 0.0) ? (wLoPV / wLoV) : null
  pWHigh.plot(curWHiPlot, color: cAvwapW ? color.transparent : colWeekHigh)
  pWLow.plot(curWLoPlot,   color: cAvwapW ? color.transparent : colWeekLow)

  let prevWHiPlot: float? = (enablePrevWeekAvwap && !cAvwapW && hasPrevWeek && prevWHiV > 0.0) ? (prevWHiPV / prevWHiV) : null
  let prevWLoPlot: float? = (enablePrevWeekAvwap && !cAvwapW && hasPrevWeek && prevWLoV > 0.0) ? (prevWLoPV / prevWLoV) : null
  pPrevWHigh.plot(prevWHiPlot, color: cAvwapW ? color.transparent : colPrevWeekHigh)
  pPrevWLow.plot(prevWLoPlot,   color: cAvwapW ? color.transparent : colPrevWeekLow)

  // Daily Peak & Trough (Intraday Extreme Anchors)
  let isNewDHi = !isNewD && (barHigh > curDayHigh)
  let isNewDLo = !isNewD && (barLow < curDayLow)

  if isNewD {
    if dHiV > 0.0 && dLoV > 0.0 {
      prevDHiPV = dHiPV
      prevDHiV  = dHiV
      prevDLoPV = dLoPV
      prevDLoV  = dLoV
      hasPrevDay = true
    }
    curDayHigh = barHigh
    curDayLow  = barLow
    dHiPV = pv
    dHiV  = barVol
    dLoPV = pv
    dLoV  = barVol
  } else {
    if hasPrevDay {
      prevDHiPV += pv
      prevDHiV  += barVol
      prevDLoPV += pv
      prevDLoV  += barVol
    }
    if barHigh > curDayHigh {
      curDayHigh = barHigh
      dHiPV = pv
      dHiV  = barVol
    } else {
      dHiPV += pv
      dHiV  += barVol
    }

    if barLow < curDayLow {
      curDayLow = barLow
      dLoPV = pv
      dLoV  = barVol
    } else {
      dLoPV += pv
      dLoV  += barVol
    }
  }

  let cAvwapD = cutOnReset && isNewD
  let curDHiPlot: float? = (enableDayAvwap && !cAvwapD && !isNewDHi && dHiV > 0.0) ? (dHiPV / dHiV) : null
  let curDLoPlot: float? = (enableDayAvwap && !cAvwapD && !isNewDLo && dLoV > 0.0) ? (dLoPV / dLoV) : null
  pDHigh.plot(curDHiPlot, color: cAvwapD ? color.transparent : colDayHigh)
  pDLow.plot(curDLoPlot,   color: cAvwapD ? color.transparent : colDayLow)

  let prevDHiPlot: float? = (enablePrevDayAvwap && !cAvwapD && hasPrevDay && prevDHiV > 0.0) ? (prevDHiPV / prevDHiV) : null
  let prevDLoPlot: float? = (enablePrevDayAvwap && !cAvwapD && hasPrevDay && prevDLoV > 0.0) ? (prevDLoPV / prevDLoV) : null
  pPrevDHigh.plot(prevDHiPlot, color: cAvwapD ? color.transparent : colPrevDayHigh)
  pPrevDLow.plot(prevDLoPlot,   color: cAvwapD ? color.transparent : colPrevDayLow)

  // Macro Calendar Opens: YTD Open AVWAP
  if isNewY {
    ytdPV = pv
    ytdV  = barVol
  } else {
    ytdPV += pv
    ytdV  += barVol
  }
  let cYtd = cutOnReset && isNewY
  let ytdPlot: float? = (enableYtdAvwap && !cYtd && ytdV > 0.0) ? (ytdPV / ytdV) : null
  pYtdOpen.plot(ytdPlot, color: cYtd ? color.transparent : colYtdAvwap)

  // Macro Calendar Opens: MTD Open AVWAP
  if isNewM {
    mtdPV = pv
    mtdV  = barVol
  } else {
    mtdPV += pv
    mtdV  += barVol
  }
  let cMtd = cutOnReset && isNewM
  let mtdPlot: float? = (enableMtdAvwap && !cMtd && mtdV > 0.0) ? (mtdPV / mtdV) : null
  pMtdOpen.plot(mtdPlot, color: cMtd ? color.transparent : colMtdAvwap)

  // 7. Stream Line Plotting with CutOnReset & ACTIVE FILLS
  // 4H
  let show4HActive = show4H && !hideLive
  let c4H = cutOnReset && isNew4H
  let col4H_line = c4H ? color.transparent : color4H
  let col4H_s1   = c4H ? color.transparent : std1Color
  let col4H_s2   = c4H ? color.transparent : std2Color
  let col4H_s3   = c4H ? color.transparent : std3Color

  let plot4H: float? = (show4HActive && !c4H) ? v4H : null
  p4h.plot(plot4H, color: col4H_line)
  let p4h_s1u_v: float? = (show4HActive && !c4H && (showStd1 || fillStd1) && v4H != null && d4H != null) ? v4H + std1Mult * d4H : null
  let p4h_s1d_v: float? = (show4HActive && !c4H && (showStd1 || fillStd1) && v4H != null && d4H != null) ? v4H - std1Mult * d4H : null
  p4h_s1u.plot(p4h_s1u_v, color: col4H_s1)
  p4h_s1d.plot(p4h_s1d_v, color: col4H_s1)
  let p4h_s2u_v: float? = (show4HActive && !c4H && (showStd2 || fillStd2 || fillStd3) && v4H != null && d4H != null) ? v4H + std2Mult * d4H : null
  let p4h_s2d_v: float? = (show4HActive && !c4H && (showStd2 || fillStd2 || fillStd3) && v4H != null && d4H != null) ? v4H - std2Mult * d4H : null
  p4h_s2u.plot(p4h_s2u_v, color: col4H_s2)
  p4h_s2d.plot(p4h_s2d_v, color: col4H_s2)
  let p4h_s3u_v: float? = (show4HActive && !c4H && (showStd3 || fillStd3) && v4H != null && d4H != null) ? v4H + std3Mult * d4H : null
  let p4h_s3d_v: float? = (show4HActive && !c4H && (showStd3 || fillStd3) && v4H != null && d4H != null) ? v4H - std3Mult * d4H : null
  p4h_s3u.plot(p4h_s3u_v, color: col4H_s3)
  p4h_s3d.plot(p4h_s3d_v, color: col4H_s3)

  if show4HActive && !c4H {
    if fillStd1 {
      f4h_s1.fill()
    }
    if fillStd2 {
      f4h_s2u.fill()
      f4h_s2d.fill()
    }
    if fillStd3 {
      f4h_s3u.fill()
      f4h_s3d.fill()
    }
  }

  // Daily
  let showDActive = showDaily && !hideLive
  let cD = cutOnReset && isNewD
  let colD_line = cD ? color.transparent : colorDaily
  let colD_s1   = cD ? color.transparent : std1Color
  let colD_s2   = cD ? color.transparent : std2Color
  let colD_s3   = cD ? color.transparent : std3Color

  let plotD: float? = (showDActive && !cD) ? vD : null
  pd.plot(plotD, color: colD_line)
  let pd_s1u_v: float? = (showDActive && !cD && (showStd1 || fillStd1) && vD != null && dD != null) ? vD + std1Mult * dD : null
  let pd_s1d_v: float? = (showDActive && !cD && (showStd1 || fillStd1) && vD != null && dD != null) ? vD - std1Mult * dD : null
  pd_s1u.plot(pd_s1u_v, color: colD_s1)
  pd_s1d.plot(pd_s1d_v, color: colD_s1)
  let pd_s2u_v: float? = (showDActive && !cD && (showStd2 || fillStd2 || fillStd3) && vD != null && dD != null) ? vD + std2Mult * dD : null
  let pd_s2d_v: float? = (showDActive && !cD && (showStd2 || fillStd2 || fillStd3) && vD != null && dD != null) ? vD - std2Mult * dD : null
  pd_s2u.plot(pd_s2u_v, color: colD_s2)
  pd_s2d.plot(pd_s2d_v, color: colD_s2)
  let pd_s3u_v: float? = (showDActive && !cD && (showStd3 || fillStd3) && vD != null && dD != null) ? vD + std3Mult * dD : null
  let pd_s3d_v: float? = (showDActive && !cD && (showStd3 || fillStd3) && vD != null && dD != null) ? vD - std3Mult * dD : null
  pd_s3u.plot(pd_s3u_v, color: colD_s3)
  pd_s3d.plot(pd_s3d_v, color: colD_s3)

  if showDActive && !cD {
    if fillStd1 {
      fd_s1.fill()
    }
    if fillStd2 {
      fd_s2u.fill()
      fd_s2d.fill()
    }
    if fillStd3 {
      fd_s3u.fill()
      fd_s3d.fill()
    }
  }

  // Weekly
  let showWActive = showWeekly && !hideLive
  let cW = cutOnReset && isNewW
  let colW_line = cW ? color.transparent : colorWeekly
  let colW_s1   = cW ? color.transparent : std1Color
  let colW_s2   = cW ? color.transparent : std2Color
  let colW_s3   = cW ? color.transparent : std3Color

  let plotW: float? = (showWActive && !cW) ? vW : null
  pw.plot(plotW, color: colW_line)
  let pw_s1u_v: float? = (showWActive && !cW && (showStd1 || fillStd1) && vW != null && dW != null) ? vW + std1Mult * dW : null
  let pw_s1d_v: float? = (showWActive && !cW && (showStd1 || fillStd1) && vW != null && dW != null) ? vW - std1Mult * dW : null
  pw_s1u.plot(pw_s1u_v, color: colW_s1)
  pw_s1d.plot(pw_s1d_v, color: colW_s1)
  let pw_s2u_v: float? = (showWActive && !cW && (showStd2 || fillStd2 || fillStd3) && vW != null && dW != null) ? vW + std2Mult * dW : null
  let pw_s2d_v: float? = (showWActive && !cW && (showStd2 || fillStd2 || fillStd3) && vW != null && dW != null) ? vW - std2Mult * dW : null
  pw_s2u.plot(pw_s2u_v, color: colW_s2)
  pw_s2d.plot(pw_s2d_v, color: colW_s2)
  let pw_s3u_v: float? = (showWActive && !cW && (showStd3 || fillStd3) && vW != null && dW != null) ? vW + std3Mult * dW : null
  let pw_s3d_v: float? = (showWActive && !cW && (showStd3 || fillStd3) && vW != null && dW != null) ? vW - std3Mult * dW : null
  pw_s3u.plot(pw_s3u_v, color: colW_s3)
  pw_s3d.plot(pw_s3d_v, color: colW_s3)

  if showWActive && !cW {
    if fillStd1 {
      fw_s1.fill()
    }
    if fillStd2 {
      fw_s2u.fill()
      fw_s2d.fill()
    }
    if fillStd3 {
      fw_s3u.fill()
      fw_s3d.fill()
    }
  }

  // Monthly
  let showMActive = showMonthly && !hideLive
  let cM = cutOnReset && isNewM
  let colM_line = cM ? color.transparent : colorMonthly
  let colM_s1   = cM ? color.transparent : std1Color
  let colM_s2   = cM ? color.transparent : std2Color
  let colM_s3   = cM ? color.transparent : std3Color

  let plotM: float? = (showMActive && !cM) ? vM : null
  pm.plot(plotM, color: colM_line)
  let pm_s1u_v: float? = (showMActive && !cM && (showStd1 || fillStd1) && vM != null && dM != null) ? vM + std1Mult * dM : null
  let pm_s1d_v: float? = (showMActive && !cM && (showStd1 || fillStd1) && vM != null && dM != null) ? vM - std1Mult * dM : null
  pm_s1u.plot(pm_s1u_v, color: colM_s1)
  pm_s1d.plot(pm_s1d_v, color: colM_s1)
  let pm_s2u_v: float? = (showMActive && !cM && (showStd2 || fillStd2 || fillStd3) && vM != null && dM != null) ? vM + std2Mult * dM : null
  let pm_s2d_v: float? = (showMActive && !cM && (showStd2 || fillStd2 || fillStd3) && vM != null && dM != null) ? vM - std2Mult * dM : null
  pm_s2u.plot(pm_s2u_v, color: colM_s2)
  pm_s2d.plot(pm_s2d_v, color: colM_s2)
  let pm_s3u_v: float? = (showMActive && !cM && (showStd3 || fillStd3) && vM != null && dM != null) ? vM + std3Mult * dM : null
  let pm_s3d_v: float? = (showMActive && !cM && (showStd3 || fillStd3) && vM != null && dM != null) ? vM - std3Mult * dM : null
  pm_s3u.plot(pm_s3u_v, color: colM_s3)
  pm_s3d.plot(pm_s3d_v, color: colM_s3)

  if showMActive && !cM {
    if fillStd1 {
      fm_s1.fill()
    }
    if fillStd2 {
      fm_s2u.fill()
      fm_s2d.fill()
    }
    if fillStd3 {
      fm_s3u.fill()
      fm_s3d.fill()
    }
  }

  // Quarterly
  let showQActive = showQuarterly && !hideLive
  let cQ = cutOnReset && isNewQ
  let colQ_line = cQ ? color.transparent : colorQuarterly
  let colQ_s1   = cQ ? color.transparent : std1Color
  let colQ_s2   = cQ ? color.transparent : std2Color
  let colQ_s3   = cQ ? color.transparent : std3Color

  let plotQ: float? = (showQActive && !cQ) ? vQ : null
  pq.plot(plotQ, color: colQ_line)
  let pq_s1u_v: float? = (showQActive && !cQ && (showStd1 || fillStd1) && vQ != null && dQ != null) ? vQ + std1Mult * dQ : null
  let pq_s1d_v: float? = (showQActive && !cQ && (showStd1 || fillStd1) && vQ != null && dQ != null) ? vQ - std1Mult * dQ : null
  pq_s1u.plot(pq_s1u_v, color: colQ_s1)
  pq_s1d.plot(pq_s1d_v, color: colQ_s1)
  let pq_s2u_v: float? = (showQActive && !cQ && (showStd2 || fillStd2 || fillStd3) && vQ != null && dQ != null) ? vQ + std2Mult * dQ : null
  let pq_s2d_v: float? = (showQActive && !cQ && (showStd2 || fillStd2 || fillStd3) && vQ != null && dQ != null) ? vQ - std2Mult * dQ : null
  pq_s2u.plot(pq_s2u_v, color: colQ_s2)
  pq_s2d.plot(pq_s2d_v, color: colQ_s2)
  let pq_s3u_v: float? = (showQActive && !cQ && (showStd3 || fillStd3) && vQ != null && dQ != null) ? vQ + std3Mult * dQ : null
  let pq_s3d_v: float? = (showQActive && !cQ && (showStd3 || fillStd3) && vQ != null && dQ != null) ? vQ - std3Mult * dQ : null
  pq_s3u.plot(pq_s3u_v, color: colQ_s3)
  pq_s3d.plot(pq_s3d_v, color: colQ_s3)

  if showQActive && !cQ {
    if fillStd1 {
      fq_s1.fill()
    }
    if fillStd2 {
      fq_s2u.fill()
      fq_s2d.fill()
    }
    if fillStd3 {
      fq_s3u.fill()
      fq_s3d.fill()
    }
  }

  // Yearly
  let showYActive = showYearly && !hideLive
  let cY = cutOnReset && isNewY
  let colY_line = cY ? color.transparent : colorYearly
  let colY_s1   = cY ? color.transparent : std1Color
  let colY_s2   = cY ? color.transparent : std2Color
  let colY_s3   = cY ? color.transparent : std3Color

  let plotY: float? = (showYActive && !cY) ? vY : null
  py.plot(plotY, color: colY_line)
  let py_s1u_v: float? = (showYActive && !cY && (showStd1 || fillStd1) && vY != null && dY != null) ? vY + std1Mult * dY : null
  let py_s1d_v: float? = (showYActive && !cY && (showStd1 || fillStd1) && vY != null && dY != null) ? vY - std1Mult * dY : null
  py_s1u.plot(py_s1u_v, color: colY_s1)
  py_s1d.plot(py_s1d_v, color: colY_s1)
  let py_s2u_v: float? = (showYActive && !cY && (showStd2 || fillStd2 || fillStd3) && vY != null && dY != null) ? vY + std2Mult * dY : null
  let py_s2d_v: float? = (showYActive && !cY && (showStd2 || fillStd2 || fillStd3) && vY != null && dY != null) ? vY - std2Mult * dY : null
  py_s2u.plot(py_s2u_v, color: colY_s2)
  py_s2d.plot(py_s2d_v, color: colY_s2)
  let py_s3u_v: float? = (showYActive && !cY && (showStd3 || fillStd3) && vY != null && dY != null) ? vY + std3Mult * dY : null
  let py_s3d_v: float? = (showYActive && !cY && (showStd3 || fillStd3) && vY != null && dY != null) ? vY - std3Mult * dY : null
  py_s3u.plot(py_s3u_v, color: colY_s3)
  py_s3d.plot(py_s3d_v, color: colY_s3)

  if showYActive && !cY {
    if fillStd1 {
      fy_s1.fill()
    }
    if fillStd2 {
      fy_s2u.fill()
      fy_s2d.fill()
    }
    if fillStd3 {
      fy_s3u.fill()
      fy_s3d.fill()
    }
  }

  // 8. Rolling VWAPs (Days to Bar Adaptive VWMA)
  let r1Val: float? = showRoll1 ? chart.vwma(rollBars1) : null
  pr1.plot(r1Val)
  let r2Val: float? = showRoll2 ? chart.vwma(rollBars2) : null
  pr2.plot(r2Val)
  let r3Val: float? = showRoll3 ? chart.vwma(rollBars3) : null
  pr3.plot(r3Val)

  // 9. Naked VWAPs Invalidation & High-Aesthetic Labeling
  if showNaked {
    let testHi = nakedTouch == "Body" ? math.max(barOpen, barClose) : barHigh
    let testLo = nakedTouch == "Body" ? math.min(barOpen, barClose) : barLow

    for i in 0..levels.len {
      let lvl = levels.get(i)
      if lvl != null {
        let tol = lvl.level * (nakedTolBps / 10000.0)
        let isTouched = lvl.touched
        let touchT = lvl.touchTime

        if !isTouched && testLo <= (lvl.level + tol) && testHi >= (lvl.level - tol) {
          isTouched = true
          touchT = ts
          levels.set(i, NakedLevel {
            id: lvl.id,
            code: lvl.code,
            level: lvl.level,
            startTime: lvl.startTime,
            touched: true,
            touchTime: ts,
            scoreR: lvl.scoreR
          })
        }

        let lineKey   = str.format("nv_{0}", lvl.id)
        let marginKey = str.format("nvm_{0}", lvl.id)
        let pillKey   = str.format("nvp_{0}", lvl.id)

        if isTouched {
          if hideDead {
            let _ = nvLines.delete(lineKey)
            let _ = nvMargin.delete(marginKey)
            let _ = nvPills.delete(pillKey)
          } else {
            let endT = touchT ?? ts
            nvLines.get(lineKey).set(
              x1: lvl.startTime,
              y1: lvl.level,
              x2: endT,
              y2: lvl.level,
              color: color.withAlpha(color.gray, 50),
              width: 1.0,
              style: linestyle.dotted,
              extend: extend.none
            )
            let _ = nvMargin.delete(marginKey)
            let _ = nvPills.delete(pillKey)
          }
        } else {
          let lvlCol = lvl.code == "4H" ? color4H : (lvl.code == "D" ? colorDaily : (lvl.code == "W" ? colorWeekly : (lvl.code == "M" ? colorMonthly : (lvl.code == "Q" ? colorQuarterly : colorYearly))))
          let ls = nvLineStyle == "Solid" ? linestyle.solid : (nvLineStyle == "Dotted" ? linestyle.dotted : linestyle.dashed)
          let ext = nvExtend ? extend.right : extend.none

          nvLines.get(lineKey).set(
            x1: lvl.startTime,
            y1: lvl.level,
            x2: ts,
            y2: lvl.level,
            color: lvlCol,
            width: nvLineWidth,
            style: ls,
            extend: ext
          )

          // Institutional tag text formatted according to user preferences
          let baseTag = str.format("NVWAP {0}", lvl.code)
          let tagText = baseTag
          if showNvPrice && showScores {
            tagText = str.format("{0} · {1:.2} [Score: {2}]", baseTag, lvl.level, lvl.scoreR)
          } else if showNvPrice && !showScores {
            tagText = str.format("{0} · {1:.2}", baseTag, lvl.level)
          } else if !showNvPrice && showScores {
            tagText = str.format("{0} [Score: {1}]", baseTag, lvl.scoreR)
          }

          let yOffset = lvl.level * (nvOffsetBps / 10000.0)
          let yLabel = lvl.level + yOffset

          if nvTagPos == "Right Chart Margin (Inset)" || nvTagPos == "Both (Origin & Margin)" {
            nvMargin.get(marginKey).set(
              x: 140.0,
              y: yLabel,
              text: tagText,
              color: lvlCol,
              size: nvBadgeSize,
              textAlign: "right",
              zIndex: 40
            )
          } else {
            let _ = nvMargin.delete(marginKey)
          }

          if nvTagPos == "At Current Price (Live Edge)" {
            nvPills.get(pillKey).set(
              x: ts,
              y: yLabel,
              text: tagText,
              color: lvlCol,
              size: nvBadgeSize,
              zIndex: 40
            )
          } else if nvTagPos == "At Level Origin (Start)" || nvTagPos == "Both (Origin & Margin)" {
            nvPills.get(pillKey).set(
              x: lvl.startTime,
              y: yLabel,
              text: tagText,
              color: lvlCol,
              size: nvBadgeSize,
              zIndex: 40
            )
          } else {
            let _ = nvPills.delete(pillKey)
          }
        }
      }
    }
  }
}
