script "Quant Levels Engine"

// ============================================================================
// INDICATOR: Quant Levels Engine (Multi-Timeframe Institutional Levels)
// SUITE:     MMT Quantitative Indicator Suite — SCRIPT 01
// ENGINE:    MMT Scripting v3 (Strictly Typed DSL)
//
// DESCRIPTION:
// Institutional-grade calculated levels engine combining 13 methodology families
// across 9 timeframes and customizable intraday sessions.
// ============================================================================

// ----------------------------------------------------------------------------
// DATA SUBSCRIPTIONS
// ----------------------------------------------------------------------------
data (
  chart     = subscribe(data.ohlcv)
  tf15m     = subscribe(data.ohlcv, timeframe: 15m)
  tf30m     = subscribe(data.ohlcv, timeframe: 30m)
  tf1h      = subscribe(data.ohlcv, timeframe: 1h)
  tf4h      = subscribe(data.ohlcv, timeframe: 4h)
  tf1D      = subscribe(data.ohlcv, timeframe: 1D)
  tf1W      = subscribe(data.ohlcv, timeframe: 1W)
  tf1M      = subscribe(data.ohlcv, timeframe: 1M)
  tf1Q      = subscribe(data.ohlcv, timeframe: 3M)
  tf1Y      = subscribe(data.ohlcv, timeframe: 1Y)
  chartVol  = subscribe(data.volume)
  chartVd   = subscribe(data.vd)
  chartCvd  = subscribe(data.cvd)
  chartOi   = subscribe(data.oi)
  chartBook = subscribe(data.book)
)

// ----------------------------------------------------------------------------
// USER INPUTS
// ----------------------------------------------------------------------------
input (
  // ==========================================================================
  // TAB 1: OPERATING MODE & HUD
  // ==========================================================================
  input.tab(title: "Modo y HUD")
  input.group(title: "Modo de Operación General", collapsible: false)
  engineMode       = input.select("Clean Mode", title: "Modo del Indicador", options: ["Clean Mode", "Advanced Mode", "Order Flow Mode"])
  refPeriodMode    = input.select("Mode A: Confirmed Previous (Default)", title: "Período de Referencia", options: ["Mode A: Confirmed Previous (Default)", "Mode B: Developing Current", "Both: Confirmed & Developing"])
  showActivePeriod = input.bool(true,  title: "Mostrar Período Activo Vigente")
  showDevLevels    = input.bool(false, title: "Mostrar Niveles en Formación (Modo B)")
  devLineStyle     = input.select("Dashed", title: "Estilo Niveles en Formación", options: ["Dashed", "Dotted", "Solid"])
  devOpacity       = input.int(70, title: "Opacidad Niveles en Formación %", min: 10, max: 100)

  input.group(title: "Heads-Up Display (HUD Dashboard)", collapsible: false)
  showHud          = input.bool(true, title: "Mostrar Panel HUD en Pantalla")
  hudAnchorPos     = input.select("Top Right", title: "Posición del HUD", options: ["Top Right", "Top Left"])
  hudShowDetails   = input.bool(true, title: "Mostrar Telemetría en HUD")

  // ==========================================================================
  // TAB 2: MATRIZ DE TEMPORALIDADES Y METODOLOGÍAS
  // ==========================================================================
  input.tab(title: "Temporalidades")
  
  // Daily Timeframe (1D)
  input.group(title: "Temporalidad Diaria (1D)", collapsible: true)
  enableD          = input.bool(true, title: "Activar Niveles Diarios")
  methodD          = input.select("Camarilla", title: "Metodología Principal 1D", options: ["Camarilla", "Fibonacci", "Classic / Floor", "CPR", "Woodie", "DeMark", "Previous Period", "ATR Levels", "VWAP", "Donchian", "Volume Profile", "Statistical", "Off"])
  colorD           = input.color(color.rgb(245, 166, 35), title: "Color Base 1D")
  showPrevD        = input.bool(true,  title: "Añadir Previous Day High / Low / Close")
  showCprD         = input.bool(false, title: "Añadir Daily CPR Range")
  showVwapD        = input.bool(false, title: "Añadir Daily VWAP & Bandas")

  // Weekly Timeframe (1W)
  input.group(title: "Temporalidad Semanal (1W)", collapsible: true)
  enableW          = input.bool(true, title: "Activar Niveles Semanales")
  methodW          = input.select("Camarilla", title: "Metodología Principal 1W", options: ["Camarilla", "Fibonacci", "Classic / Floor", "CPR", "Woodie", "DeMark", "Previous Period", "ATR Levels", "VWAP", "Donchian", "Volume Profile", "Statistical", "Off"])
  colorW           = input.color(color.rgb(78, 205, 196), title: "Color Base 1W")
  showPrevW        = input.bool(true,  title: "Añadir Previous Week High / Low / Close")
  showCprW         = input.bool(true,  title: "Añadir Weekly CPR Range")
  showVwapW        = input.bool(false, title: "Añadir Weekly VWAP & Bandas")

  // Monthly Timeframe (1M)
  input.group(title: "Temporalidad Mensual (1M)", collapsible: true)
  enableM          = input.bool(true, title: "Activar Niveles Mensuales")
  methodM          = input.select("CPR", title: "Metodología Principal 1M", options: ["CPR", "Camarilla", "Fibonacci", "Classic / Floor", "Woodie", "DeMark", "Previous Period", "ATR Levels", "VWAP", "Donchian", "Volume Profile", "Statistical", "Off"])
  colorM           = input.color(color.rgb(176, 132, 204), title: "Color Base 1M")
  showPrevM        = input.bool(true,  title: "Añadir Previous Month High / Low / Close")
  showCprM         = input.bool(true,  title: "Añadir Monthly CPR Range")
  showVwapM        = input.bool(false, title: "Añadir Monthly VWAP & Bandas")

  // 4-Hour Timeframe (4H)
  input.group(title: "Temporalidad 4 Horas (4H)", collapsible: true)
  enable4H         = input.bool(false, title: "Activar Niveles 4H")
  method4H         = input.select("Fibonacci", title: "Metodología 4H", options: ["Fibonacci", "Camarilla", "Classic / Floor", "CPR", "Woodie", "Previous Period", "ATR Levels", "VWAP", "Volume Profile", "Off"])
  color4H          = input.color(color.rgb(100, 181, 246), title: "Color 4H")

  // 1-Hour Timeframe (1H)
  input.group(title: "Temporalidad 1 Hora (1H)", collapsible: true)
  enable1H         = input.bool(false, title: "Activar Niveles 1H")
  method1H         = input.select("Classic / Floor", title: "Metodología 1H", options: ["Classic / Floor", "Fibonacci", "Camarilla", "CPR", "Previous Period", "ATR Levels", "VWAP", "Off"])
  color1H          = input.color(color.rgb(129, 199, 132), title: "Color 1H")

  // 30m & 15m Timeframes
  input.group(title: "Temporalidades Intradía Cortas (30m & 15m)", collapsible: true)
  enable30m        = input.bool(false, title: "Activar Niveles 30m")
  method30m        = input.select("Previous Period", title: "Metodología 30m", options: ["Previous Period", "Classic / Floor", "Fibonacci", "Camarilla", "CPR", "Off"])
  color30m         = input.color(color.rgb(255, 213, 79), title: "Color 30m")
  enable15m        = input.bool(false, title: "Activar Niveles 15m")
  method15m        = input.select("Previous Period", title: "Metodología 15m", options: ["Previous Period", "Classic / Floor", "Fibonacci", "Camarilla", "CPR", "Off"])
  color15m         = input.color(color.rgb(255, 138, 101), title: "Color 15m")

  // Macro Timeframes (Quarterly & Yearly)
  input.group(title: "Macro Temporalidades (Trimestral & Anual)", collapsible: true)
  enableQ          = input.bool(false, title: "Activar Niveles Trimestrales (3M)")
  methodQ          = input.select("Previous Period", title: "Metodología Trimestral", options: ["Previous Period", "Classic / Floor", "Fibonacci", "CPR", "VWAP", "Off"])
  colorQ           = input.color(color.rgb(220, 110, 170), title: "Color Trimestral")
  enableY          = input.bool(false, title: "Activar Niveles Anuales (1Y)")
  methodY          = input.select("Previous Period", title: "Metodología Anual", options: ["Previous Period", "Classic / Floor", "Fibonacci", "CPR", "VWAP", "Off"])
  colorY           = input.color(color.rgb(239, 83, 80), title: "Color Anual")

  // Opening Range & Custom Sessions
  input.group(title: "Opening Range & Sesiones Personalizadas", collapsible: true)
  enableOR         = input.bool(true,  title: "Activar Opening Range (OR)")
  orSessionType    = input.select("US Regular Cash (13:30 - 20:00 UTC)", title: "Sesión de Referencia", options: ["US Regular Cash (13:30 - 20:00 UTC)", "London Cash (07:00 - 15:30 UTC)", "Asia Open (00:00 - 08:00 UTC)", "Full UTC Day (00:00 UTC)"])
  orDurationMin    = input.select("30m", title: "Duración Opening Range", options: ["15m", "30m", "60m"])
  colorOR          = input.color(color.rgb(186, 104, 200), title: "Color Opening Range")
  showOrMid        = input.bool(true, title: "Mostrar Midline 50% del OR")

  // ==========================================================================
  // TAB 3: VISUALIZACIÓN, ETIQUETAS Y EXTENSIONES
  // ==========================================================================
  input.tab(title: "Etiquetas y Visual")
  input.group(title: "Control de Etiquetas (Anti-Colisión)", collapsible: false)
  labelAlign           = input.select("Right Edge (Clean & Modern)", title: "Posición de Etiquetas", options: ["Right Edge (Clean & Modern)", "Left Start (Classic)", "Off (Solo Líneas)"])
  labelFormat          = input.select("Name & Price (Cam H3 · 83703)", title: "Formato de Texto", options: ["Name & Price (Cam H3 · 83703)", "Compact (H3 · 83.7k)", "Name Only", "Price Only"])
  preventLabelOverlap  = input.bool(true, title: "Anti-Colisión Inteligente (Smart Stagger)")
  hideLabelsInConfluence = input.bool(true, title: "Consolidar Etiquetas en Confluencias")
  showHistoricalLabels = input.bool(false, title: "Mostrar Etiquetas en Histórico (D-2, D-3)")

  input.group(title: "Filtro Metodológico Camarilla", collapsible: false)
  camLevelFilter       = input.select("Core Levels (H3/H4/H5 & L3/L4/L5)", title: "Niveles Camarilla Activos", options: ["Core Levels (H3/H4/H5 & L3/L4/L5)", "Key Breakout & Reversal (H3/H4 & L3/L4)", "All Levels (H1 - H6)"])

  input.group(title: "Control de Períodos Históricos", collapsible: false)
  showHistorical       = input.bool(true, title: "Mostrar Líneas Históricas Anteriores")
  historicalPeriods    = input.int(3, title: "Número de Períodos Históricos", min: 1, max: 10)
  histAlpha            = input.int(35, title: "Opacidad de Líneas Históricas %", min: 10, max: 100)

  input.group(title: "Extensión Independiente de Niveles", collapsible: false)
  extendPrevLevels     = input.bool(true, title: "Extender Niveles Históricos a la Derecha")
  extensionMode        = input.select("Until Broken", title: "Modo de Extensión", options: ["Until First Touch", "Until Broken", "Until Mitigated", "Indefinite", "None"])
  extendStyle          = input.select("Dotted", title: "Estilo de la Prolongación", options: ["Dotted", "Dashed", "Solid"])
  baseLineWidth        = input.float(1.5, title: "Grosor de Líneas", min: 0.5, max: 5.0)

  // ==========================================================================
  // TAB 4: MITIGACIÓN Y ESTADOS DE NIVELES
  // ==========================================================================
  input.tab(title: "Mitigación")
  input.group(title: "Criterios de Interacción y Ruptura", collapsible: false)
  breakCriteria        = input.select("Close", title: "Criterio de Ruptura (Broken)", options: ["Wick", "Close", "2 Consecutive Closes", "ATR Buffer", "Volume / Delta Confirmation"])
  atrBufferMult        = input.float(0.5, title: "Multiplicador ATR de Ruptura / Rechazo", min: 0.1, max: 3.0)
  acceptMinBars        = input.int(3, title: "Barras para Aceptación (Accepted)", min: 1, max: 10)
  hideMitigated        = input.bool(false, title: "Ocultar Niveles Completamente Mitigados")
  showStatusBadge      = input.bool(true, title: "Mostrar Estado en la Etiqueta (ej. · U)")

  input.group(title: "Colores de Estados de Nivel", collapsible: true)
  colUntested          = input.color(color.rgb(76, 175, 80),   title: "Untested (Intacto)")
  colTouched           = input.color(color.rgb(255, 193, 7),   title: "Touched (Tocado)")
  colRejected          = input.color(color.rgb(33, 150, 243),  title: "Rejected (Rechazado)")
  colBroken            = input.color(color.rgb(244, 67, 54),   title: "Broken (Roto)")
  colReclaimed         = input.color(color.rgb(156, 39, 176),  title: "Reclaimed (Recuperado)")

  // ==========================================================================
  // TAB 5: CONFLUENCIAS AUTOMÁTICAS
  // ==========================================================================
  input.tab(title: "Confluencias")
  input.group(title: "Detección y Agrupamiento Automático", collapsible: false)
  enableConfluence     = input.bool(true, title: "Activar Detección de Zonas de Confluencia")
  confToleranceAtr     = input.float(0.5, title: "Tolerancia: Multiplicador ATR (k)", min: 0.1, max: 3.0)
  confTolerancePct     = input.float(0.12, title: "Tolerancia: Porcentaje de Precio % (p)", min: 0.01, max: 1.0)
  minConfLevels        = input.int(3, title: "Mínimo de Niveles Agrupados", min: 2, max: 8)
  minConfFamilies      = input.int(2, title: "Mínimo de Familias Distintas (Diversity)", min: 1, max: 6)
  htfWeightBonus       = input.bool(true, title: "Mayor Peso Visual a Temporalidades Superiores")
  confFillColor        = input.color(color.rgb(103, 58, 183), title: "Color de Zona de Confluencia")
  confAlpha            = input.int(22, title: "Opacidad del Relleno de Zona %", min: 5, max: 80)

  // ==========================================================================
  // TAB 6: INTEGRACIÓN ORDER FLOW
  // ==========================================================================
  input.tab(title: "Order Flow")
  input.group(title: "Métricas de Flujo en Zonas y Niveles", collapsible: false)
  enableOrderFlow      = input.bool(true, title: "Activar Detección de Order Flow")
  detectAbsorption     = input.bool(true, title: "Detectar Absorción Institucional")
  volSurgeMult         = input.float(1.8, title: "Multiplicador de Volumen Anormal (Surge)", min: 1.2, max: 5.0)
  imbalanceRatio       = input.float(1.4, title: "Umbral Desequilibrio Libro (Imbalance)", min: 1.1, max: 4.0)
  colAbsorbBull        = input.color(color.rgb(0, 230, 118), title: "Color Absorción Alcista (Buy)")
  colAbsorbBear        = input.color(color.rgb(255, 82, 82), title: "Color Absorción Bajista (Sell)")
)

// ----------------------------------------------------------------------------
// SETUP BLOCK
// ----------------------------------------------------------------------------
setup (
  histA = int(math.round(float(histAlpha) * 2.55)) ?? 89
  devA  = int(math.round(float(devOpacity) * 2.55)) ?? 178
  confA = int(math.round(float(confAlpha) * 2.55)) ?? 56

  // Session time constructors
  sessAsia   = time.session("00:00", "08:00")
  sessLondon = time.session("07:00", "15:30")
  sessNY     = time.session("13:30", "20:00")
  sessDay    = time.session("00:00", "24:00")

  devLineSt = devLineStyle == "Solid" ? linestyle.solid : (devLineStyle == "Dotted" ? linestyle.dotted : linestyle.dashed)
  extLineSt = extendStyle == "Solid" ? linestyle.solid : (extendStyle == "Dashed" ? linestyle.dashed : linestyle.dotted)
)

// ----------------------------------------------------------------------------
// USER DEFINED TYPES
// ----------------------------------------------------------------------------
type LevelItem {
  id: string
  label: string
  shortLabel: string
  family: string
  tf: string
  price: float
  startTs: time
  endTs: time
  isDev: bool
  isHist: bool
  isRes: bool
  isHtf: bool
  statusCode: int   // 0: Untested, 1: Touched, 2: Rejected, 3: Broken, 4: Reclaimed, 5: Accepted
  touches: int
}

type ConfluenceCluster {
  top: float
  bot: float
  levelCount: int
  famCount: int
  hasHtf: bool
  desc: string
}

// ----------------------------------------------------------------------------
// PLOTS (ORDER FLOW MARKERS)
// ----------------------------------------------------------------------------
plot (
  pAbsorbBull = plot.marker(title: "Bullish Absorption Marker", shape: shape.up, color: color.green, size: 2.0)
  pAbsorbBear = plot.marker(title: "Bearish Absorption Marker", shape: shape.down, color: color.red, size: 2.0)
)

// ----------------------------------------------------------------------------
// STATE DECLARATION
// ----------------------------------------------------------------------------
state (
  levelLines   = entities.linePool(max: 256)
  extendLines  = entities.linePool(max: 128)
  zoneBoxes    = entities.boxPool(max: 16)
  levelLabels  = entities.labelPool(max: 128)
  hudPanels    = entities.boxPool(max: 8, anchor: anchor.topRight)
  hudLabels    = entities.labelPool(max: 24, anchor: anchor.topRight)

  activeLevels = LevelItem[](96)
  clusters     = ConfluenceCluster[](16)

  // Opening range state
  orActive: bool = false
  orStartTs: time = time.fromUnixSeconds(0)
  orHigh: float = 0.0
  orLow: float = 0.0
  orMid: float = 0.0
  orFinalized: bool = false
)

// ----------------------------------------------------------------------------
// FORMATTING HELPERS
// ----------------------------------------------------------------------------
fn formatPrice(px: float) -> string {
  if px >= 1000.0 {
    return str.format("{0:.0}", px)
  } else if px >= 1.0 {
    return str.format("{0:.2}", px)
  } else {
    return str.format("{0:.4}", px)
  }
}

fn formatCompactPrice(px: float) -> string {
  if px >= 1000.0 {
    return str.format("{0:.1}k", px / 1000.0)
  } else if px >= 1.0 {
    return str.format("{0:.1}", px)
  } else {
    return str.format("{0:.3}", px)
  }
}

// ----------------------------------------------------------------------------
// CALCULATION FUNCTIONS (13 FAMILIES)
// ----------------------------------------------------------------------------
fn registerLevel(id: string, lbl: string, shortLbl: string, fam: string, tfStr: string, px: float, sTs: time, eTs: time, dev: bool, hist: bool, res: bool, htf: bool) {
  if px > 0.0 && activeLevels.len < activeLevels.capacity {
    let _ = activeLevels.push(LevelItem {
      id: id,
      label: lbl,
      shortLabel: shortLbl,
      family: fam,
      tf: tfStr,
      price: px,
      startTs: sTs,
      endTs: eTs,
      isDev: dev,
      isHist: hist,
      isRes: res,
      isHtf: htf,
      statusCode: 0,
      touches: 0,
    })
  }
}

fn addClassicPivots(tfStr: string, prefix: string, o: float, h: float, l: float, c: float, sTs: time, eTs: time, dev: bool, hist: bool, htf: bool) {
  let pp = (h + l + c) / 3.0
  let r1 = 2.0 * pp - l
  let s1 = 2.0 * pp - h
  let r2 = pp + (h - l)
  let s2 = pp - (h - l)
  let r3 = h + 2.0 * (pp - l)
  let s3 = l - 2.0 * (h - pp)
  let fam = "Classic"

  registerLevel(str.format("{0}_PP", prefix), str.format("{0} PP", tfStr), "PP", fam, tfStr, pp, sTs, eTs, dev, hist, false, htf)
  registerLevel(str.format("{0}_R1", prefix), str.format("{0} R1", tfStr), "R1", fam, tfStr, r1, sTs, eTs, dev, hist, true,  htf)
  registerLevel(str.format("{0}_S1", prefix), str.format("{0} S1", tfStr), "S1", fam, tfStr, s1, sTs, eTs, dev, hist, false, htf)
  registerLevel(str.format("{0}_R2", prefix), str.format("{0} R2", tfStr), "R2", fam, tfStr, r2, sTs, eTs, dev, hist, true,  htf)
  registerLevel(str.format("{0}_S2", prefix), str.format("{0} S2", tfStr), "S2", fam, tfStr, s2, sTs, eTs, dev, hist, false, htf)
  registerLevel(str.format("{0}_R3", prefix), str.format("{0} R3", tfStr), "R3", fam, tfStr, r3, sTs, eTs, dev, hist, true,  htf)
  registerLevel(str.format("{0}_S3", prefix), str.format("{0} S3", tfStr), "S3", fam, tfStr, s3, sTs, eTs, dev, hist, false, htf)
}

fn addFibonacciPivots(tfStr: string, prefix: string, o: float, h: float, l: float, c: float, sTs: time, eTs: time, dev: bool, hist: bool, htf: bool) {
  let rng = h - l
  let pp = (h + l + c) / 3.0
  let r1 = pp + 0.382 * rng
  let s1 = pp - 0.382 * rng
  let r2 = pp + 0.618 * rng
  let s2 = pp - 0.618 * rng
  let r3 = pp + 1.000 * rng
  let s3 = pp - 1.000 * rng
  let r4 = pp + 1.618 * rng
  let s4 = pp - 1.618 * rng
  let fam = "Fibonacci"

  registerLevel(str.format("{0}_F_PP", prefix), str.format("{0} Fib PP", tfStr), "Fib PP", fam, tfStr, pp, sTs, eTs, dev, hist, false, htf)
  registerLevel(str.format("{0}_F_R1", prefix), str.format("{0} Fib R1", tfStr), "Fib R1", fam, tfStr, r1, sTs, eTs, dev, hist, true,  htf)
  registerLevel(str.format("{0}_F_S1", prefix), str.format("{0} Fib S1", tfStr), "Fib S1", fam, tfStr, s1, sTs, eTs, dev, hist, false, htf)
  registerLevel(str.format("{0}_F_R2", prefix), str.format("{0} Fib R2", tfStr), "Fib R2", fam, tfStr, r2, sTs, eTs, dev, hist, true,  htf)
  registerLevel(str.format("{0}_F_S2", prefix), str.format("{0} Fib S2", tfStr), "Fib S2", fam, tfStr, s2, sTs, eTs, dev, hist, false, htf)
  registerLevel(str.format("{0}_F_R3", prefix), str.format("{0} Fib R3", tfStr), "Fib R3", fam, tfStr, r3, sTs, eTs, dev, hist, true,  htf)
  registerLevel(str.format("{0}_F_S3", prefix), str.format("{0} Fib S3", tfStr), "Fib S3", fam, tfStr, s3, sTs, eTs, dev, hist, false, htf)
  registerLevel(str.format("{0}_F_R4", prefix), str.format("{0} Fib R4", tfStr), "Fib R4", fam, tfStr, r4, sTs, eTs, dev, hist, true,  htf)
  registerLevel(str.format("{0}_F_S4", prefix), str.format("{0} Fib S4", tfStr), "Fib S4", fam, tfStr, s4, sTs, eTs, dev, hist, false, htf)
}

fn addCamarillaPivots(tfStr: string, prefix: string, o: float, h: float, l: float, c: float, sTs: time, eTs: time, dev: bool, hist: bool, htf: bool) {
  let rng = h - l
  let h1 = c + 1.1 * rng / 12.0
  let l1 = c - 1.1 * rng / 12.0
  let h2 = c + 1.1 * rng / 6.0
  let l2 = c - 1.1 * rng / 6.0
  let h3 = c + 1.1 * rng / 4.0
  let l3 = c - 1.1 * rng / 4.0
  let h4 = c + 1.1 * rng / 2.0
  let l4 = c - 1.1 * rng / 2.0
  let h5 = l > 0.0 ? (h / l) * c : c + 1.168 * rng
  let l5 = c - (h5 - c)
  let h6 = h5 + 1.168 * (h5 - h4)
  let l6 = c - (h6 - c)
  let fam = "Camarilla"

  // Always register Core Reversal (H3, L3) and Breakout (H4, L4)
  registerLevel(str.format("{0}_Cam_H3", prefix), str.format("{0} Cam H3", tfStr), "Cam H3", fam, tfStr, h3, sTs, eTs, dev, hist, true,  htf)
  registerLevel(str.format("{0}_Cam_L3", prefix), str.format("{0} Cam L3", tfStr), "Cam L3", fam, tfStr, l3, sTs, eTs, dev, hist, false, htf)
  registerLevel(str.format("{0}_Cam_H4", prefix), str.format("{0} Cam H4", tfStr), "Cam H4", fam, tfStr, h4, sTs, eTs, dev, hist, true,  htf)
  registerLevel(str.format("{0}_Cam_L4", prefix), str.format("{0} Cam L4", tfStr), "Cam L4", fam, tfStr, l4, sTs, eTs, dev, hist, false, htf)

  if camLevelFilter != "Key Breakout & Reversal (H3/H4 & L3/L4)" {
    registerLevel(str.format("{0}_Cam_H5", prefix), str.format("{0} Cam H5", tfStr), "Cam H5", fam, tfStr, h5, sTs, eTs, dev, hist, true,  htf)
    registerLevel(str.format("{0}_Cam_L5", prefix), str.format("{0} Cam L5", tfStr), "Cam L5", fam, tfStr, l5, sTs, eTs, dev, hist, false, htf)
  }

  if camLevelFilter == "All Levels (H1 - H6)" {
    registerLevel(str.format("{0}_Cam_H6", prefix), str.format("{0} Cam H6", tfStr), "Cam H6", fam, tfStr, h6, sTs, eTs, dev, hist, true,  htf)
    registerLevel(str.format("{0}_Cam_L6", prefix), str.format("{0} Cam L6", tfStr), "Cam L6", fam, tfStr, l6, sTs, eTs, dev, hist, false, htf)
    registerLevel(str.format("{0}_Cam_H2", prefix), str.format("{0} Cam H2", tfStr), "Cam H2", fam, tfStr, h2, sTs, eTs, dev, hist, true,  htf)
    registerLevel(str.format("{0}_Cam_L2", prefix), str.format("{0} Cam L2", tfStr), "Cam L2", fam, tfStr, l2, sTs, eTs, dev, hist, false, htf)
    registerLevel(str.format("{0}_Cam_H1", prefix), str.format("{0} Cam H1", tfStr), "Cam H1", fam, tfStr, h1, sTs, eTs, dev, hist, true,  htf)
    registerLevel(str.format("{0}_Cam_L1", prefix), str.format("{0} Cam L1", tfStr), "Cam L1", fam, tfStr, l1, sTs, eTs, dev, hist, false, htf)
  }
}

fn addWoodiePivots(tfStr: string, prefix: string, o: float, h: float, l: float, c: float, sTs: time, eTs: time, dev: bool, hist: bool, htf: bool) {
  let pp = (h + l + 2.0 * o) / 4.0
  let r1 = 2.0 * pp - l
  let s1 = 2.0 * pp - h
  let r2 = pp + (h - l)
  let s2 = pp - (h - l)
  let r3 = h + 2.0 * (pp - l)
  let s3 = l - 2.0 * (h - pp)
  let fam = "Woodie"

  registerLevel(str.format("{0}_W_PP", prefix), str.format("{0} Woodie PP", tfStr), "W-PP", fam, tfStr, pp, sTs, eTs, dev, hist, false, htf)
  registerLevel(str.format("{0}_W_R1", prefix), str.format("{0} Woodie R1", tfStr), "W-R1", fam, tfStr, r1, sTs, eTs, dev, hist, true,  htf)
  registerLevel(str.format("{0}_W_S1", prefix), str.format("{0} Woodie S1", tfStr), "W-S1", fam, tfStr, s1, sTs, eTs, dev, hist, false, htf)
  registerLevel(str.format("{0}_W_R2", prefix), str.format("{0} Woodie R2", tfStr), "W-R2", fam, tfStr, r2, sTs, eTs, dev, hist, true,  htf)
  registerLevel(str.format("{0}_W_S2", prefix), str.format("{0} Woodie S2", tfStr), "W-S2", fam, tfStr, s2, sTs, eTs, dev, hist, false, htf)
  registerLevel(str.format("{0}_W_R3", prefix), str.format("{0} Woodie R3", tfStr), "W-R3", fam, tfStr, r3, sTs, eTs, dev, hist, true,  htf)
  registerLevel(str.format("{0}_W_S3", prefix), str.format("{0} Woodie S3", tfStr), "W-S3", fam, tfStr, s3, sTs, eTs, dev, hist, false, htf)
}

fn addDeMarkPivots(tfStr: string, prefix: string, o: float, h: float, l: float, c: float, sTs: time, eTs: time, dev: bool, hist: bool, htf: bool) {
  let x = c < o ? (h + 2.0 * l + c) : (c > o ? (2.0 * h + l + c) : (h + l + 2.0 * c))
  let pp = x / 4.0
  let r1 = x / 2.0 - l
  let s1 = x / 2.0 - h
  let fam = "DeMark"

  registerLevel(str.format("{0}_DM_PP", prefix), str.format("{0} DeMark PP", tfStr), "DM-PP", fam, tfStr, pp, sTs, eTs, dev, hist, false, htf)
  registerLevel(str.format("{0}_DM_R1", prefix), str.format("{0} DeMark R1", tfStr), "DM-R1", fam, tfStr, r1, sTs, eTs, dev, hist, true,  htf)
  registerLevel(str.format("{0}_DM_S1", prefix), str.format("{0} DeMark S1", tfStr), "DM-S1", fam, tfStr, s1, sTs, eTs, dev, hist, false, htf)
}

fn addCprLevels(tfStr: string, prefix: string, o: float, h: float, l: float, c: float, sTs: time, eTs: time, dev: bool, hist: bool, htf: bool) {
  let pp = (h + l + c) / 3.0
  let bc = (h + l) / 2.0
  let tc = 2.0 * pp - bc
  let cprTop = math.max(tc, bc)
  let cprBot = math.min(tc, bc)
  let fam = "CPR"

  registerLevel(str.format("{0}_CPR_TC", prefix), str.format("{0} CPR Top", tfStr), "CPR TC", fam, tfStr, cprTop, sTs, eTs, dev, hist, true,  htf)
  registerLevel(str.format("{0}_CPR_P",  prefix), str.format("{0} CPR Pivot", tfStr), "CPR P", fam, tfStr, pp,     sTs, eTs, dev, hist, false, htf)
  registerLevel(str.format("{0}_CPR_BC", prefix), str.format("{0} CPR Bot", tfStr), "CPR BC", fam, tfStr, cprBot, sTs, eTs, dev, hist, false, htf)
}

fn addPrevPeriodExtremes(tfStr: string, prefix: string, o: float, h: float, l: float, c: float, sTs: time, eTs: time, dev: bool, hist: bool, htf: bool) {
  let mid = (h + l) / 2.0
  let fam = "PrevPeriod"
  let shortPfx = tfStr == "D" ? "PD" : (tfStr == "W" ? "PW" : (tfStr == "M" ? "PM" : str.format("P{0}", tfStr)))

  registerLevel(str.format("{0}_PH", prefix), str.format("P.{0} High", tfStr),  str.format("{0}H", shortPfx), fam, tfStr, h,   sTs, eTs, dev, hist, true,  htf)
  registerLevel(str.format("{0}_PL", prefix), str.format("P.{0} Low", tfStr),   str.format("{0}L", shortPfx), fam, tfStr, l,   sTs, eTs, dev, hist, false, htf)
  registerLevel(str.format("{0}_PC", prefix), str.format("P.{0} Close", tfStr), str.format("{0}C", shortPfx), fam, tfStr, c,  sTs, eTs, dev, hist, false, htf)
  registerLevel(str.format("{0}_PO", prefix), str.format("P.{0} Open", tfStr),  str.format("{0}O", shortPfx), fam, tfStr, o,  sTs, eTs, dev, hist, false, htf)
  registerLevel(str.format("{0}_PM", prefix), str.format("P.{0} Mid", tfStr),   str.format("{0}M", shortPfx), fam, tfStr, mid, sTs, eTs, dev, hist, false, htf)
}

fn addAtrLevels(tfStr: string, prefix: string, o: float, atrVal: float, sTs: time, eTs: time, dev: bool, hist: bool, htf: bool) {
  let fam = "ATR"
  registerLevel(str.format("{0}_ATR_U1", prefix), str.format("{0} ATR +1", tfStr), "ATR +1", fam, tfStr, o + 1.0 * atrVal, sTs, eTs, dev, hist, true,  htf)
  registerLevel(str.format("{0}_ATR_L1", prefix), str.format("{0} ATR -1", tfStr), "ATR -1", fam, tfStr, o - 1.0 * atrVal, sTs, eTs, dev, hist, false, htf)
  registerLevel(str.format("{0}_ATR_U2", prefix), str.format("{0} ATR +2", tfStr), "ATR +2", fam, tfStr, o + 2.0 * atrVal, sTs, eTs, dev, hist, true,  htf)
  registerLevel(str.format("{0}_ATR_L2", prefix), str.format("{0} ATR -2", tfStr), "ATR -2", fam, tfStr, o - 2.0 * atrVal, sTs, eTs, dev, hist, false, htf)
  registerLevel(str.format("{0}_ATR_U3", prefix), str.format("{0} ATR +3", tfStr), "ATR +3", fam, tfStr, o + 3.0 * atrVal, sTs, eTs, dev, hist, true,  htf)
  registerLevel(str.format("{0}_ATR_L3", prefix), str.format("{0} ATR -3", tfStr), "ATR -3", fam, tfStr, o - 3.0 * atrVal, sTs, eTs, dev, hist, false, htf)
}

fn addDonchianLevels(tfStr: string, prefix: string, h: float, l: float, sTs: time, eTs: time, dev: bool, hist: bool, htf: bool) {
  let fam = "Donchian"
  let mid = (h + l) / 2.0
  registerLevel(str.format("{0}_DON_H", prefix), str.format("{0} Donchian High", tfStr), "Don-H", fam, tfStr, h,   sTs, eTs, dev, hist, true,  htf)
  registerLevel(str.format("{0}_DON_L", prefix), str.format("{0} Donchian Low", tfStr),  "Don-L", fam, tfStr, l,   sTs, eTs, dev, hist, false, htf)
  registerLevel(str.format("{0}_DON_M", prefix), str.format("{0} Donchian Mid", tfStr),  "Don-M", fam, tfStr, mid, sTs, eTs, dev, hist, false, htf)
}

fn addStatisticalLevels(tfStr: string, prefix: string, h: float, l: float, c: float, sTs: time, eTs: time, dev: bool, hist: bool, htf: bool) {
  let fam = "Statistical"
  let mean = (h + l + c) / 3.0
  let approxStd = (h - l) / 3.29
  let median = (h + l) / 2.0
  registerLevel(str.format("{0}_STAT_U2", prefix), str.format("{0} Stat +2σ", tfStr), "Stat +2σ", fam, tfStr, mean + 2.0 * approxStd, sTs, eTs, dev, hist, true,  htf)
  registerLevel(str.format("{0}_STAT_U1", prefix), str.format("{0} Stat +1σ", tfStr), "Stat +1σ", fam, tfStr, mean + 1.0 * approxStd, sTs, eTs, dev, hist, true,  htf)
  registerLevel(str.format("{0}_STAT_MED", prefix), str.format("{0} Stat Med", tfStr), "Stat Med", fam, tfStr, median,             sTs, eTs, dev, hist, false, htf)
  registerLevel(str.format("{0}_STAT_L1", prefix), str.format("{0} Stat -1σ", tfStr), "Stat -1σ", fam, tfStr, mean - 1.0 * approxStd, sTs, eTs, dev, hist, false, htf)
  registerLevel(str.format("{0}_STAT_L2", prefix), str.format("{0} Stat -2σ", tfStr), "Stat -2σ", fam, tfStr, mean - 2.0 * approxStd, sTs, eTs, dev, hist, false, htf)
}

fn addVwapLevels(tfStr: string, prefix: string, vwapVal: float, devVal: float, sTs: time, eTs: time, dev: bool, hist: bool, htf: bool) {
  if vwapVal > 0.0 {
    let fam = "VWAP"
    registerLevel(str.format("{0}_VWAP", prefix),     str.format("{0} VWAP", tfStr),     "VWAP",     fam, tfStr, vwapVal,                sTs, eTs, dev, hist, false, htf)
    registerLevel(str.format("{0}_VWAP_U1", prefix),  str.format("{0} VWAP +1σ", tfStr), "VWAP +1σ", fam, tfStr, vwapVal + 1.0 * devVal, sTs, eTs, dev, hist, true,  htf)
    registerLevel(str.format("{0}_VWAP_L1", prefix),  str.format("{0} VWAP -1σ", tfStr), "VWAP -1σ", fam, tfStr, vwapVal - 1.0 * devVal, sTs, eTs, dev, hist, false, htf)
    registerLevel(str.format("{0}_VWAP_U2", prefix),  str.format("{0} VWAP +2σ", tfStr), "VWAP +2σ", fam, tfStr, vwapVal + 2.0 * devVal, sTs, eTs, dev, hist, true,  htf)
    registerLevel(str.format("{0}_VWAP_L2", prefix),  str.format("{0} VWAP -2σ", tfStr), "VWAP -2σ", fam, tfStr, vwapVal - 2.0 * devVal, sTs, eTs, dev, hist, false, htf)
  }
}

fn dispatchMethodology(method: string, tfStr: string, prefix: string, o: float, h: float, l: float, c: float, atrVal: float, sTs: time, eTs: time, dev: bool, hist: bool, htf: bool) {
  if method == "Camarilla" {
    addCamarillaPivots(tfStr, prefix, o, h, l, c, sTs, eTs, dev, hist, htf)
  } else if method == "Fibonacci" {
    addFibonacciPivots(tfStr, prefix, o, h, l, c, sTs, eTs, dev, hist, htf)
  } else if method == "Classic / Floor" {
    addClassicPivots(tfStr, prefix, o, h, l, c, sTs, eTs, dev, hist, htf)
  } else if method == "CPR" {
    addCprLevels(tfStr, prefix, o, h, l, c, sTs, eTs, dev, hist, htf)
  } else if method == "Woodie" {
    addWoodiePivots(tfStr, prefix, o, h, l, c, sTs, eTs, dev, hist, htf)
  } else if method == "DeMark" {
    addDeMarkPivots(tfStr, prefix, o, h, l, c, sTs, eTs, dev, hist, htf)
  } else if method == "Previous Period" {
    addPrevPeriodExtremes(tfStr, prefix, o, h, l, c, sTs, eTs, dev, hist, htf)
  } else if method == "ATR Levels" {
    addAtrLevels(tfStr, prefix, o, atrVal, sTs, eTs, dev, hist, htf)
  } else if method == "Donchian" {
    addDonchianLevels(tfStr, prefix, h, l, sTs, eTs, dev, hist, htf)
  } else if method == "Statistical" {
    addStatisticalLevels(tfStr, prefix, h, l, c, sTs, eTs, dev, hist, htf)
  }
}

fn isInConfluence(px: float, tol: float) -> bool {
  for k in 0..clusters.len {
    let cl = clusters.get(k)
    if cl != null {
      if px >= (cl.bot - tol * 0.5) && px <= (cl.top + tol * 0.5) {
        return true
      }
    }
  }
  return false
}

fn addOrMergeCluster(cTop: float, cBot: float, cCnt: int, cFams: int, cHtf: bool, tol: float) {
  let merged = false
  for k in 0..clusters.len {
    let ex = clusters.get(k)
    if ex != null {
      let overlaps = (cBot <= ex.top + tol) && (cTop >= ex.bot - tol)
      if overlaps {
        let nTop = math.max(ex.top, cTop)
        let nBot = math.min(ex.bot, cBot)
        let nCnt = math.max(ex.levelCount, cCnt)
        let nFams = math.max(ex.famCount, cFams)
        let nHtf = ex.hasHtf || cHtf
        let nDesc = str.format("CONFLUENCE [{0} Lvls | {1} Fams]", nCnt, nFams)
        clusters.set(k, ConfluenceCluster {
          top: nTop,
          bot: nBot,
          levelCount: nCnt,
          famCount: nFams,
          hasHtf: nHtf,
          desc: nDesc,
        })
        merged = true
      }
    }
  }
  if !merged && clusters.len < clusters.capacity {
    let desc = str.format("CONFLUENCE [{0} Lvls | {1} Fams]", cCnt, cFams)
    let _ = clusters.push(ConfluenceCluster {
      top: cTop,
      bot: cBot,
      levelCount: cCnt,
      famCount: cFams,
      hasHtf: cHtf,
      desc: desc,
    })
  }
}

// ----------------------------------------------------------------------------
// MAIN UPDATE HANDLER
// ----------------------------------------------------------------------------
on chart.update {
  let ts     = chart.time ?? time.fromUnixSeconds(0)
  let prevTs = chart.time[1]
  let closeP = chart.close ?? 0.0
  let openP  = chart.open  ?? closeP
  let highP  = chart.high  ?? closeP
  let lowP   = chart.low   ?? closeP
  let volP   = chart.volume ?? 0.0
  let atr14  = chart.atr(14) ?? (highP - lowP)

  let vdVal  = chartVd.close ?? 0.0
  let cvdVal = chartCvd.close ?? 0.0
  let oiVal  = chartOi.close ?? 0.0
  let bkImb  = chartBook.imbalance(outerPct: 1.0) ?? 1.0

  let isCleanMode = engineMode == "Clean Mode"
  let isOfMode    = engineMode == "Order Flow Mode"

  // Multi-period transitions for periodic VWAP
  let isNewD = time.isNewPeriod(ts, prevTs, 1D)
  let isNewW = time.isNewPeriod(ts, prevTs, 1W)
  let isNewM = time.isNewPeriod(ts, prevTs, 1M)

  let vD   = chart.vwap(reset: isNewD) ?? closeP
  let devD = chart.vwapDev(reset: isNewD) ?? 0.0
  let vW   = chart.vwap(reset: isNewW) ?? closeP
  let devW = chart.vwapDev(reset: isNewW) ?? 0.0
  let vM   = chart.vwap(reset: isNewM) ?? closeP
  let devM = chart.vwapDev(reset: isNewM) ?? 0.0

  // Clear buffers
  activeLevels.clear()

  // 1. DAILY LEVELS (1D)
  if enableD {
    let dOpen  = tf1D.open[1]  ?? openP
    let dHigh  = tf1D.high[1]  ?? highP
    let dLow   = tf1D.low[1]   ?? lowP
    let dClose = tf1D.close[1] ?? closeP
    let dStart = time.dayStart(ts)
    let dEnd   = dStart + time.days(1)
    let dAtr   = dHigh - dLow

    if refPeriodMode != "Mode B: Developing Current" {
      dispatchMethodology(methodD, "D", "d1_conf", dOpen, dHigh, dLow, dClose, dAtr, dStart, dEnd, false, false, false)
      if methodD == "VWAP" || showVwapD {
        addVwapLevels("D", "d1_vwap", vD, devD, dStart, dEnd, false, false, false)
      }
      if showPrevD {
        addPrevPeriodExtremes("D", "d1_prev", dOpen, dHigh, dLow, dClose, dStart, dEnd, false, false, false)
      }
      if showCprD {
        addCprLevels("D", "d1_cpr", dOpen, dHigh, dLow, dClose, dStart, dEnd, false, false, false)
      }

      // Historical Days
      if showHistorical {
        for k in 2..(historicalPeriods + 1) {
          let hD_open  = tf1D.open[k]
          let hD_high  = tf1D.high[k]
          let hD_low   = tf1D.low[k]
          let hD_close = tf1D.close[k]
          let hD_start = tf1D.time[k]
          let hD_end   = tf1D.time[k - 1]
          if hD_open != null && hD_high != null && hD_low != null && hD_close != null && hD_start != null && hD_end != null {
            let pref = str.format("d_hist_{0}", k)
            dispatchMethodology(methodD, str.format("D-{0}", k - 1), pref, hD_open ?? openP, hD_high ?? highP, hD_low ?? lowP, hD_close ?? closeP, (hD_high ?? highP) - (hD_low ?? lowP), hD_start ?? dStart, hD_end ?? dEnd, false, true, false)
          }
        }
      }
    }

    if showDevLevels || refPeriodMode == "Mode B: Developing Current" || refPeriodMode == "Both: Confirmed & Developing" {
      let curDOpen  = tf1D.forming.open  ?? openP
      let curDHigh  = tf1D.forming.high  ?? highP
      let curDLow   = tf1D.forming.low   ?? lowP
      let curDClose = tf1D.forming.close ?? closeP
      dispatchMethodology(methodD, "D-Dev", "d1_dev", curDOpen, curDHigh, curDLow, curDClose, curDHigh - curDLow, dStart, ts, true, false, false)
    }
  }

  // 2. WEEKLY LEVELS (1W)
  if enableW {
    let wOpen  = tf1W.open[1]  ?? openP
    let wHigh  = tf1W.high[1]  ?? highP
    let wLow   = tf1W.low[1]   ?? lowP
    let wClose = tf1W.close[1] ?? closeP
    let wStart = time.weekStart(ts)
    let wEnd   = wStart + time.days(7)
    let wAtr   = wHigh - wLow

    if refPeriodMode != "Mode B: Developing Current" {
      dispatchMethodology(methodW, "W", "w1_conf", wOpen, wHigh, wLow, wClose, wAtr, wStart, wEnd, false, false, true)
      if methodW == "VWAP" || showVwapW {
        addVwapLevels("W", "w1_vwap", vW, devW, wStart, wEnd, false, false, true)
      }
      if showPrevW {
        addPrevPeriodExtremes("W", "w1_prev", wOpen, wHigh, wLow, wClose, wStart, wEnd, false, false, true)
      }
      if showCprW {
        addCprLevels("W", "w1_cpr", wOpen, wHigh, wLow, wClose, wStart, wEnd, false, false, true)
      }

      // Historical Weeks
      if showHistorical {
        for k in 2..(historicalPeriods + 1) {
          let hW_open  = tf1W.open[k]
          let hW_high  = tf1W.high[k]
          let hW_low   = tf1W.low[k]
          let hW_close = tf1W.close[k]
          let hW_start = tf1W.time[k]
          let hW_end   = tf1W.time[k - 1]
          if hW_open != null && hW_high != null && hW_low != null && hW_close != null && hW_start != null && hW_end != null {
            let pref = str.format("w_hist_{0}", k)
            dispatchMethodology(methodW, str.format("W-{0}", k - 1), pref, hW_open ?? openP, hW_high ?? highP, hW_low ?? lowP, hW_close ?? closeP, (hW_high ?? highP) - (hW_low ?? lowP), hW_start ?? wStart, hW_end ?? wEnd, false, true, true)
          }
        }
      }
    }

    if showDevLevels || refPeriodMode == "Mode B: Developing Current" || refPeriodMode == "Both: Confirmed & Developing" {
      let curWOpen  = tf1W.forming.open  ?? openP
      let curWHigh  = tf1W.forming.high  ?? highP
      let curWLow   = tf1W.forming.low   ?? lowP
      let curWClose = tf1W.forming.close ?? closeP
      dispatchMethodology(methodW, "W-Dev", "w1_dev", curWOpen, curWHigh, curWLow, curWClose, curWHigh - curWLow, wStart, ts, true, false, true)
    }
  }

  // 3. MONTHLY LEVELS (1M)
  if enableM {
    let mOpen  = tf1M.open[1]  ?? openP
    let mHigh  = tf1M.high[1]  ?? highP
    let mLow   = tf1M.low[1]   ?? lowP
    let mClose = tf1M.close[1] ?? closeP
    let mStart = time.monthStart(ts)
    let mEnd   = mStart + time.days(30)
    let mAtr   = mHigh - mLow

    if refPeriodMode != "Mode B: Developing Current" {
      dispatchMethodology(methodM, "M", "m1_conf", mOpen, mHigh, mLow, mClose, mAtr, mStart, mEnd, false, false, true)
      if methodM == "VWAP" || showVwapM {
        addVwapLevels("M", "m1_vwap", vM, devM, mStart, mEnd, false, false, true)
      }
      if showPrevM {
        addPrevPeriodExtremes("M", "m1_prev", mOpen, mHigh, mLow, mClose, mStart, mEnd, false, false, true)
      }
      if showCprM {
        addCprLevels("M", "m1_cpr", mOpen, mHigh, mLow, mClose, mStart, mEnd, false, false, true)
      }

      // Historical Months
      if showHistorical {
        for k in 2..(historicalPeriods + 1) {
          let hM_open  = tf1M.open[k]
          let hM_high  = tf1M.high[k]
          let hM_low   = tf1M.low[k]
          let hM_close = tf1M.close[k]
          let hM_start = tf1M.time[k]
          let hM_end   = tf1M.time[k - 1]
          if hM_open != null && hM_high != null && hM_low != null && hM_close != null && hM_start != null && hM_end != null {
            let pref = str.format("m_hist_{0}", k)
            dispatchMethodology(methodM, str.format("M-{0}", k - 1), pref, hM_open ?? openP, hM_high ?? highP, hM_low ?? lowP, hM_close ?? closeP, (hM_high ?? highP) - (hM_low ?? lowP), hM_start ?? mStart, hM_end ?? mEnd, false, true, true)
          }
        }
      }
    }

    if showDevLevels || refPeriodMode == "Mode B: Developing Current" || refPeriodMode == "Both: Confirmed & Developing" {
      let curMOpen  = tf1M.forming.open  ?? openP
      let curMHigh  = tf1M.forming.high  ?? highP
      let curMLow   = tf1M.forming.low   ?? lowP
      let curMClose = tf1M.forming.close ?? closeP
      dispatchMethodology(methodM, "M-Dev", "m1_dev", curMOpen, curMHigh, curMLow, curMClose, curMHigh - curMLow, mStart, ts, true, false, true)
    }
  }

  // 4. 4-HOUR LEVELS (4H)
  if enable4H {
    let h4Open  = tf4h.open[1]  ?? openP
    let h4High  = tf4h.high[1]  ?? highP
    let h4Low   = tf4h.low[1]   ?? lowP
    let h4Close = tf4h.close[1] ?? closeP
    let h4Start = ts - time.hours(4)
    let h4End   = ts + time.hours(4)
    dispatchMethodology(method4H, "4H", "h4_conf", h4Open, h4High, h4Low, h4Close, h4High - h4Low, h4Start, h4End, false, false, false)
  }

  // 5. 1-HOUR LEVELS (1H)
  if enable1H {
    let h1Open  = tf1h.open[1]  ?? openP
    let h1High  = tf1h.high[1]  ?? highP
    let h1Low   = tf1h.low[1]   ?? lowP
    let h1Close = tf1h.close[1] ?? closeP
    let h1Start = ts - time.hours(1)
    let h1End   = ts + time.hours(1)
    dispatchMethodology(method1H, "1H", "h1_conf", h1Open, h1High, h1Low, h1Close, h1High - h1Low, h1Start, h1End, false, false, false)
  }

  // 6. 30-MINUTE & 15-MINUTE LEVELS
  if enable30m {
    let m30Open  = tf30m.open[1]  ?? openP
    let m30High  = tf30m.high[1]  ?? highP
    let m30Low   = tf30m.low[1]   ?? lowP
    let m30Close = tf30m.close[1] ?? closeP
    dispatchMethodology(method30m, "30m", "m30_conf", m30Open, m30High, m30Low, m30Close, m30High - m30Low, ts - time.minutes(30), ts + time.minutes(30), false, false, false)
  }
  if enable15m {
    let m15Open  = tf15m.open[1]  ?? openP
    let m15High  = tf15m.high[1]  ?? highP
    let m15Low   = tf15m.low[1]   ?? lowP
    let m15Close = tf15m.close[1] ?? closeP
    dispatchMethodology(method15m, "15m", "m15_conf", m15Open, m15High, m15Low, m15Close, m15High - m15Low, ts - time.minutes(15), ts + time.minutes(15), false, false, false)
  }

  // 7. MACRO LEVELS (QUARTERLY & YEARLY)
  if enableQ {
    let qOpen  = tf1Q.open[1]  ?? openP
    let qHigh  = tf1Q.high[1]  ?? highP
    let qLow   = tf1Q.low[1]   ?? lowP
    let qClose = tf1Q.close[1] ?? closeP
    let qStart = time.monthStart(ts)
    let qEnd   = qStart + time.days(90)
    dispatchMethodology(methodQ, "3M", "q_conf", qOpen, qHigh, qLow, qClose, qHigh - qLow, qStart, qEnd, false, false, true)
  }
  if enableY {
    let yOpen  = tf1Y.open[1]  ?? openP
    let yHigh  = tf1Y.high[1]  ?? highP
    let yLow   = tf1Y.low[1]   ?? lowP
    let yClose = tf1Y.close[1] ?? closeP
    let yStart = time.yearStart(ts)
    let yEnd   = yStart + time.days(365)
    dispatchMethodology(methodY, "1Y", "y_conf", yOpen, yHigh, yLow, yClose, yHigh - yLow, yStart, yEnd, false, false, true)
  }

  // 8. VOLUME PROFILE STRUCTURAL ANCHORS
  let prof = chartVol.profile(bars: 50)
  let vpPoc = prof.poc()
  let vpVa  = prof.valueArea(70.0)
  if vpPoc != null && (methodD == "Volume Profile" || methodW == "Volume Profile" || isOfMode) {
    registerLevel("vp_poc", "VP POC", "POC", "VolumeProfile", "Profile", vpPoc.price, ts - time.hours(12), ts + time.hours(4), false, false, false, false)
  }
  if vpVa != null && (methodD == "Volume Profile" || methodW == "Volume Profile" || isOfMode) {
    registerLevel("vp_vah", "VP VAH", "VAH", "VolumeProfile", "Profile", vpVa.highPrice, ts - time.hours(12), ts + time.hours(4), false, false, true,  false)
    registerLevel("vp_val", "VP VAL", "VAL", "VolumeProfile", "Profile", vpVa.lowPrice,  ts - time.hours(12), ts + time.hours(4), false, false, false, false)
  }

  // 9. OPENING RANGE (OR) EVALUATION
  if enableOR {
    let inOrSess = (orSessionType == "US Regular Cash (13:30 - 20:00 UTC)" ? sessNY.contains(ts) :
                   (orSessionType == "London Cash (07:00 - 15:30 UTC)" ? sessLondon.contains(ts) :
                   (orSessionType == "Asia Open (00:00 - 08:00 UTC)" ? sessAsia.contains(ts) : sessDay.contains(ts))))

    let prevInOrSess = chart.time[1] != null ?
      (orSessionType == "US Regular Cash (13:30 - 20:00 UTC)" ? sessNY.contains(chart.time[1] ?? ts) :
      (orSessionType == "London Cash (07:00 - 15:30 UTC)" ? sessLondon.contains(chart.time[1] ?? ts) :
      (orSessionType == "Asia Open (00:00 - 08:00 UTC)" ? sessAsia.contains(chart.time[1] ?? ts) : sessDay.contains(chart.time[1] ?? ts)))) : false

    let isOrStart = inOrSess && !prevInOrSess
    if isOrStart {
      orActive = true
      orStartTs = ts
      orHigh = highP
      orLow = lowP
      orMid = (highP + lowP) / 2.0
      orFinalized = false
    } else if orActive {
      orHigh = math.max(orHigh, highP)
      orLow  = math.min(orLow, lowP)
      orMid  = (orHigh + orLow) / 2.0

      let orDurationSeconds = orDurationMin == "15m" ? 900 : (orDurationMin == "60m" ? 3600 : 1800)
      if ts >= orStartTs + time.seconds(orDurationSeconds) {
        orFinalized = true
      }
    }

    if (orActive || orFinalized) && orHigh > 0.0 {
      let orEndTs = orStartTs + time.hours(8)
      registerLevel("or_high", "OR High", "OR-H", "OR", "Session", orHigh, orStartTs, orEndTs, !orFinalized, false, true,  false)
      registerLevel("or_low",  "OR Low",  "OR-L", "OR", "Session", orLow,  orStartTs, orEndTs, !orFinalized, false, false, false)
      if showOrMid {
        registerLevel("or_mid", "OR Mid", "OR-M", "OR", "Session", orMid, orStartTs, orEndTs, !orFinalized, false, false, false)
      }
    }
  }

  // 10. AUTOMATIC CONFLUENCE CLUSTERING (CALCULATED FIRST WITH 1D MERGING)
  let tolerance = math.max(confToleranceAtr * atr14, math.max(confTolerancePct * 0.01 * closeP, float(context.tickSize) * 2.0))
  clusters.clear()
  let _ = zoneBoxes.clear("")

  if enableConfluence && activeLevels.len >= 2 {
    let numL = activeLevels.len
    for i in 0..numL {
      let l_i = activeLevels.get(i)
      if l_i != null {
        let c_top = l_i.price
        let c_bot = l_i.price
        let c_cnt = 1
        let c_fams = 1
        let c_htf = l_i.isHtf
        let famA = l_i.family

        for j in (i + 1)..numL {
          let l_j = activeLevels.get(j)
          if l_j != null {
            let mid = (c_top + c_bot) / 2.0
            if math.abs(l_j.price - mid) <= tolerance {
              c_top = math.max(c_top, l_j.price)
              c_bot = math.min(c_bot, l_j.price)
              c_cnt += 1
              if l_j.isHtf {
                c_htf = true
              }
              if l_j.family != famA {
                c_fams += 1
              }
            }
          }
        }

        if c_cnt >= minConfLevels && c_fams >= minConfFamilies {
          addOrMergeCluster(c_top, c_bot, c_cnt, c_fams, c_htf, tolerance)
        }
      }
    }

    // Render non-overlapping confluence shaded boxes with embedded clean text
    for k in 0..clusters.len {
      let cl = clusters.get(k)
      if cl != null {
        let zKey = str.format("zone_{0}", k)
        let borderW = (cl.hasHtf && htfWeightBonus) ? 2.0 : 1.0
        let boxCol = color.withAlpha(confFillColor, confA)

        // Extend zone across active window into leading margin
        let bX1 = ts - time.bars(24)
        let bX2 = ts + time.bars(6)

        zoneBoxes.get(zKey).set(
          x1: bX1,
          y1: cl.top,
          x2: bX2,
          y2: cl.bot,
          rounding: 4.0,
          color: boxCol,
          borderColor: confFillColor,
          borderWidth: borderW,
          text: cl.desc,
          textColor: color.white,
          textSize: 10.0,
          font: font.mono,
          textHAlign: "left",
          textVAlign: "top",
        )
      }
    }
  }

  // 11. SORT ACTIVE LEVELS DESCENDING BY PRICE FOR COLLISION MANAGEMENT
  let numLevels = activeLevels.len
  if numLevels > 1 {
    for i in 0..numLevels {
      for j in (i + 1)..numLevels {
        let li = activeLevels.get(i)
        let lj = activeLevels.get(j)
        if li != null && lj != null {
          if lj.price > li.price {
            activeLevels.set(i, lj)
            activeLevels.set(j, li)
          }
        }
      }
    }
  }

  // 12. LEVEL MITIGATION STATE MACHINE & DRAWING WITH SMART ANTI-COLLISION
  let nearestSuppPx = 0.0
  let nearestResPx  = 9999999.0
  let nearestSuppDesc = "None"
  let nearestResDesc  = "None"

  let minLabelGap = math.max(atr14 * 0.22, float(context.tickSize) * 20.0)
  let lastLabeledPx = 999999999.0
  let mutStagger = 0

  // Clear previous labels to prevent stale slot overlap
  let _ = levelLabels.clear("")

  for i in 0..numLevels {
    let lvl = activeLevels.get(i)
    if lvl != null {
      let px = lvl.price
      let isRes = lvl.isRes

      // Nearest Support / Resistance tracking
      if px < closeP && px > nearestSuppPx {
        nearestSuppPx = px
        nearestSuppDesc = lvl.shortLabel
      }
      if px > closeP && px < nearestResPx {
        nearestResPx = px
        nearestResDesc = lvl.shortLabel
      }

      // Interaction check
      let dist = math.abs(closeP - px)
      let touched = (lowP <= px + tolerance) && (highP >= px - tolerance)
      let broken = isRes ? (breakCriteria == "Wick" ? highP > px : closeP > px) : (breakCriteria == "Wick" ? lowP < px : closeP < px)

      let updatedStatus = lvl.statusCode

      if touched {
        if updatedStatus == 0 {
          updatedStatus = 1 // Touched
        }
      }

      if broken {
        updatedStatus = 3 // Broken
      } else if updatedStatus == 1 && dist >= atr14 * atrBufferMult {
        updatedStatus = 2 // Rejected
      }

      // Mitigation filter
      let skipDraw = hideMitigated && updatedStatus == 3

      if !skipDraw {
        // Color coding by status or timeframe
        let baseCol = lvl.tf == "D" ? colorD : (lvl.tf == "W" ? colorW : (lvl.tf == "M" ? colorM : color.gray))
        let drawCol = isCleanMode ? baseCol : (
          updatedStatus == 0 ? colUntested :
          (updatedStatus == 1 ? colTouched :
          (updatedStatus == 2 ? colRejected :
          (updatedStatus == 3 ? colBroken : colReclaimed)))
        )

        let lStyle = lvl.isDev ? devLineSt : linestyle.solid
        let lWidth = lvl.isHtf ? baseLineWidth + 1.0 : baseLineWidth

        // 1. DRAW BOUNDED PERIOD LINE
        if showActivePeriod {
          levelLines.get(lvl.id).set(
            x1: lvl.startTs,
            y1: px,
            x2: lvl.endTs,
            y2: px,
            color: lvl.isDev ? color.withAlpha(drawCol, devA) : (lvl.isHist ? color.withAlpha(drawCol, histA) : drawCol),
            width: lWidth,
            style: lStyle,
          )
        }

        // 2. EXTENSION RAY
        let isExtended = false
        if extendPrevLevels && ts > lvl.endTs {
          let stopExt = (extensionMode == "Until First Touch" && updatedStatus >= 1) || (extensionMode == "Until Broken" && updatedStatus == 3)
          if !stopExt {
            isExtended = true
            let extKey = str.format("{0}_ext", lvl.id)
            extendLines.get(extKey).set(
              x1: lvl.endTs,
              y1: px,
              x2: ts,
              y2: px,
              color: color.withAlpha(drawCol, histA),
              width: baseLineWidth,
              style: extLineSt,
            )
          }
        }

        // 3. DRAW LABEL (WITH SMART COLLISION RESOLUTION)
        let inConf = hideLabelsInConfluence && isInConfluence(px, tolerance)
        let isHistPeriod = lvl.isHist
        let skipLabel = (isHistPeriod && !showHistoricalLabels) ||
                        (labelAlign == "Off (Solo Líneas)") ||
                        inConf

        if !skipLabel {
          let distFromPrev = lastLabeledPx - px
          let isCollision = distFromPrev < minLabelGap

          let labelX = lvl.startTs
          if labelAlign == "Right Edge (Clean & Modern)" {
            let baseAnchorTs = isExtended ? ts : lvl.endTs
            if preventLabelOverlap && isCollision {
              mutStagger = mutStagger >= 2 ? 0 : mutStagger + 1
              if mutStagger == 1 {
                labelX = baseAnchorTs - time.bars(10)
              } else if mutStagger == 2 {
                labelX = baseAnchorTs - time.bars(20)
              } else {
                labelX = baseAnchorTs + time.bars(2)
              }
            } else {
              labelX = baseAnchorTs + time.bars(2)
              mutStagger = 0
            }
          } else if labelAlign == "Left Start (Classic)" {
            if preventLabelOverlap && isCollision {
              mutStagger = mutStagger >= 2 ? 0 : mutStagger + 1
              labelX = lvl.startTs + time.bars(mutStagger * 8)
            } else {
              labelX = lvl.startTs
              mutStagger = 0
            }
          }

          let pxStr = labelFormat == "Compact (H3 · 83.7k)" ? formatCompactPrice(px) : formatPrice(px)
          let nameStr = (labelFormat == "Compact (H3 · 83.7k)" || isCleanMode) ? lvl.shortLabel : lvl.label

          let badge = showStatusBadge && !isCleanMode ? (
            updatedStatus == 0 ? " · U" :
            (updatedStatus == 1 ? " · T" :
            (updatedStatus == 2 ? " · R" : " · B"))
          ) : ""

          let labelText = labelFormat == "Price Only" ? pxStr :
            (labelFormat == "Name Only" ? nameStr : str.format("{0} · {1}{2}", nameStr, pxStr, badge))

          levelLabels.get(lvl.id).set(
            x: labelX,
            y: px,
            text: labelText,
            color: drawCol,
            size: 9.5,
            font: font.mono,
          )

          lastLabeledPx = px
        }
      }
    }
  }

  // 13. ORDER FLOW INTEGRATION & ABSORPTION DETECTION
  let volSma20 = ta.sma(chart.volume, 20) ?? volP
  let isVolSurge = volSma20 > 0.0 && volP >= volSurgeMult * volSma20

  let isNearSupp = nearestSuppPx > 0.0 && math.abs(lowP - nearestSuppPx) <= tolerance * 1.5
  let isNearRes  = nearestResPx < 9000000.0 && math.abs(highP - nearestResPx) <= tolerance * 1.5

  let bullAbsorb = detectAbsorption && isNearSupp && isVolSurge && vdVal < 0.0 && closeP > (lowP + (highP - lowP) * 0.4)
  let bearAbsorb = detectAbsorption && isNearRes && isVolSurge && vdVal > 0.0 && closeP < (highP - (highP - lowP) * 0.4)

  let noPlotPx: float? = null
  let bullPlotVal: float? = (isOfMode && bullAbsorb) ? lowP : noPlotPx
  let bearPlotVal: float? = (isOfMode && bearAbsorb) ? highP : noPlotPx
  pAbsorbBull.plot(bullPlotVal, color: colAbsorbBull)
  pAbsorbBear.plot(bearPlotVal, color: colAbsorbBear)

  // 14. HEADS-UP DISPLAY (HUD) PANEL
  if showHud {
    let hudX1 = hudAnchorPos == "Top Right" ? 18.0 : 18.0
    let hudY1 = 45.0
    let hudX2 = hudAnchorPos == "Top Right" ? 310.0 : 310.0
    let hudY2 = hudShowDetails ? 245.0 : 135.0

    hudPanels.get("card").set(
      x1: hudX1,
      y1: hudY1,
      x2: hudX2,
      y2: hudY2,
      rounding: 8.0,
      color: color.withAlpha(color.black, 235),
      borderColor: color.withAlpha(color.teal, 180),
      borderWidth: 1.0,
      zIndex: 10,
    )

    hudLabels.get("title").set(
      x: hudX1 + 14.0, y: hudY1 + 16.0,
      text: str.format("QUANT LEVELS ENGINE · {0}", engineMode),
      color: color.teal, size: 12.0, font: font.mono, zIndex: 12,
    )

    hudLabels.get("supp").set(
      x: hudX1 + 14.0, y: hudY1 + 40.0,
      text: str.format("Nearest S: {0} ({1})", nearestSuppDesc, formatPrice(nearestSuppPx)),
      color: colUntested, size: 11.0, font: font.mono, zIndex: 12,
    )

    hudLabels.get("res").set(
      x: hudX1 + 14.0, y: hudY1 + 62.0,
      text: str.format("Nearest R: {0} ({1})", nearestResDesc, formatPrice(nearestResPx)),
      color: colBroken, size: 11.0, font: font.mono, zIndex: 12,
    )

    if hudShowDetails {
      hudLabels.get("conf").set(
        x: hudX1 + 14.0, y: hudY1 + 86.0,
        text: str.format("Confluences: {0} active zones", clusters.len),
        color: confFillColor, size: 11.0, font: font.mono, zIndex: 12,
      )

      let ofStatus = bullAbsorb ? "BULL ABSORPTION DETECTED" : (bearAbsorb ? "BEAR ABSORPTION DETECTED" : "Neutral / Testing")
      let ofCol = bullAbsorb ? colAbsorbBull : (bearAbsorb ? colAbsorbBear : color.gray)

      hudLabels.get("of_stat").set(
        x: hudX1 + 14.0, y: hudY1 + 110.0,
        text: str.format("Flow: {0}", ofStatus),
        color: ofCol, size: 11.0, font: font.mono, zIndex: 12,
      )

      hudLabels.get("telemetry").set(
        x: hudX1 + 14.0, y: hudY1 + 134.0,
        text: str.format("VD: {0:.0} | Imb: {1:.2}x | OI: {2:.0}", vdVal, bkImb, oiVal),
        color: color.silver, size: 10.0, font: font.mono, zIndex: 12,
      )

      hudLabels.get("cvd").set(
        x: hudX1 + 14.0, y: hudY1 + 156.0,
        text: str.format("CVD: {0:.0} | ATR(14): {1:.2}", cvdVal, atr14),
        color: color.silver, size: 10.0, font: font.mono, zIndex: 12,
      )
    }
  }
}
