script "Quant Levels Engine"

// ============================================================================
// INDICATOR: Quant Levels Engine (Multi-Timeframe Level Viewer & Map)
// SUITE:     MMT Quantitative Indicator Suite — SCRIPT 01
// ENGINE:    MMT Scripting v3 (Strictly Typed DSL)
//
// DESCRIPTION:
// Unified Multi-Timeframe Level Viewer with period-anchored projection lines.
// Active period levels start strictly at the period opening timestamp and extend
// right. Past historical periods are bounded strictly within their timeframe cycle.
// ============================================================================

// ----------------------------------------------------------------------------
// DATA SUBSCRIPTIONS
// ----------------------------------------------------------------------------
data (
  chart = subscribe(data.ohlcv, history: 3000)
  tf4h  = subscribe(data.ohlcv, timeframe: 4h)
  tf1D  = subscribe(data.ohlcv, timeframe: 1D)
  tf1W  = subscribe(data.ohlcv, timeframe: 1W)
  tf1M  = subscribe(data.ohlcv, timeframe: 1M)
  tf1Q  = subscribe(data.ohlcv, timeframe: 3M)
  tf1Y  = subscribe(data.ohlcv, timeframe: 1Y)
)

// ----------------------------------------------------------------------------
// USER INPUTS
// ----------------------------------------------------------------------------
input (
  // ==========================================================================
  // TAB 1: CALCULATION & TIMEFRAMES
  // ==========================================================================
  input.tab(title: "Configuración")
  
  input.group(title: "Método de Cálculo (Modo Único)", collapsible: false)
  calcMethod        = input.select("Camarilla", title: "Metodología", options: ["Camarilla", "Classic / Floor", "Fibonacci", "CPR", "Woodie", "DeMark", "Previous Period Extremes"])
  camFilter         = input.select("Core Levels (H3/H4/H5 & L3/L4/L5)", title: "Filtro Camarilla", options: ["Core Levels (H3/H4/H5 & L3/L4/L5)", "Key Breakout & Reversal (H3/H4 & L3/L4)", "All Levels (H1 - H6)"], when: calcMethod == "Camarilla")
  showPrevExtremes  = input.bool(true, title: "Superponer High / Low / Mid previo", when: calcMethod != "Previous Period Extremes")

  input.group(title: "Temporalidades (Timeframes)", collapsible: false)
  enable4H          = input.bool(false, title: "4H (4 Horas)")
  col4H             = input.color(color.rgb(100, 181, 246), title: "", sameLine: true)
  width4H           = input.float(1.0, title: "", min: 0.5, max: 4.0, sameLine: true)

  enable1D          = input.bool(true,  title: "1D (Diario)")
  col1D             = input.color(color.rgb(245, 166, 35), title: "", sameLine: true)
  width1D           = input.float(1.5, title: "", min: 0.5, max: 4.0, sameLine: true)

  enable1W          = input.bool(true,  title: "1W (Semanal)")
  col1W             = input.color(color.rgb(78, 205, 196), title: "", sameLine: true)
  width1W           = input.float(2.0, title: "", min: 0.5, max: 4.0, sameLine: true)

  enable1M          = input.bool(true,  title: "1M (Mensual)")
  col1M             = input.color(color.rgb(176, 132, 204), title: "", sameLine: true)
  width1M           = input.float(2.0, title: "", min: 0.5, max: 4.0, sameLine: true)

  enable1Q          = input.bool(false, title: "1Q (Trimestral)")
  col1Q             = input.color(color.rgb(220, 110, 170), title: "", sameLine: true)
  width1Q           = input.float(2.5, title: "", min: 0.5, max: 4.0, sameLine: true)

  enable1Y          = input.bool(false, title: "1Y (Anual)")
  col1Y             = input.color(color.rgb(239, 83, 80), title: "", sameLine: true)
  width1Y           = input.float(3.0, title: "", min: 0.5, max: 4.0, sameLine: true)

  // ==========================================================================
  // TAB 2: ESTILO Y PERÍODOS HISTÓRICOS
  // ==========================================================================
  input.tab(title: "Visual y Períodos")
  
  input.group(title: "Líneas Activas (Período Vigente)", collapsible: false)
  activeLineStyle   = input.select("Solid", title: "Estilo Línea Activa", options: ["Solid", "Dashed", "Dotted"])

  input.group(title: "Períodos Históricos (Pasados)", collapsible: false)
  showHistorical    = input.bool(true, title: "Mostrar Períodos Pasados")
  historicalPeriods = input.int(3, title: "Períodos hacia atrás", min: 1, max: 10, when: showHistorical)
  histLineStyle     = input.select("Dotted", title: "Estilo Líneas Históricas", options: ["Dotted", "Dashed", "Solid"], when: showHistorical)
  histOpacityPct    = input.int(40, title: "Opacidad Histórica %", min: 10, max: 100, when: showHistorical)

  input.group(title: "Etiquetas y Tipografía (Naked Style)", collapsible: false)
  labelTagPos       = input.select("Right Margin", title: "Posición de Etiquetas", options: ["Right Margin", "Origin", "Right Margin + Origin", "None"])
  labelFormat       = input.select("Name & Price", title: "Formato de Texto", options: ["Name & Price", "Compact", "Name Only", "Price Only"])
  labelBadgeSize    = input.float(13.0, title: "Tamaño de Fuente (pt)", min: 9.0, max: 24.0)
  labelLiftBps      = input.float(6.0, title: "Elevación de Etiqueta (bps)", min: 0.0, max: 50.0)
  preventLabelOverlap = input.bool(true, title: "Anti-Colisión Vertical en Margen")

  input.group(title: "Telemetría HUD", collapsible: false)
  showHud           = input.bool(true, title: "Mostrar Panel HUD")
  hudAnchorPos      = input.select("Top Right", title: "Posición del HUD", options: ["Top Right", "Top Left", "Bottom Right", "Bottom Left"])
)

// ----------------------------------------------------------------------------
// SETUP BLOCK
// ----------------------------------------------------------------------------
setup (
  histA        = int(math.round(float(histOpacityPct) * 2.55)) ?? 102
  lblFactor    = 1.0 + labelLiftBps / 10000.0

  activeLineSt = activeLineStyle == "Solid" ? linestyle.solid : (activeLineStyle == "Dotted" ? linestyle.dotted : linestyle.dashed)
  histLineSt   = histLineStyle == "Solid" ? linestyle.solid : (histLineStyle == "Dashed" ? linestyle.dashed : linestyle.dotted)

  tagMargin    = labelTagPos == "Right Margin" || labelTagPos == "Right Margin + Origin"
  tagOrigin    = labelTagPos == "Origin" || labelTagPos == "Right Margin + Origin"
)

// ----------------------------------------------------------------------------
// USER DEFINED TYPES
// ----------------------------------------------------------------------------
type LevelItem {
  id: string
  label: string
  shortLabel: string
  tf: string
  price: float
  startTs: time
  color: color
  isRes: bool
}

// ----------------------------------------------------------------------------
// STATE DECLARATION
// ----------------------------------------------------------------------------
state (
  levelLines   = entities.linePool(max: 1024)
  levelMarginL = entities.labelPool(max: 128, anchor: anchor.right)
  levelOriginL = entities.labelPool(max: 128)
  hudPanels    = entities.boxPool(max: 4, anchor: anchor.topRight)
  hudLabels    = entities.labelPool(max: 16, anchor: anchor.topRight)

  activeLevels = LevelItem[](128)
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
// LEVEL REGISTRATION & LINE DRAWING
// ----------------------------------------------------------------------------
fn addLevel(id: string, lbl: string, shortLbl: string, tfStr: string, px: float, sTs: time, eTs: time, isHist: bool, col: color, w: float, isRes: bool) {
  if px <= 0.0 {
    return
  }
  if isHist {
    // Historical period: bounded strictly from start of that period to its end
    levelLines.get(id).set(
      x1: sTs,
      y1: px,
      x2: eTs,
      y2: px,
      color: color.withAlpha(col, histA),
      width: math.max(0.8, w - 0.5),
      style: histLineSt,
      extend: extend.none,
    )
  } else {
    // Current active period: starts at period start and extends right
    levelLines.get(id).set(
      x1: sTs,
      y1: px,
      x2: time.shiftBars(sTs, 1),
      y2: px,
      color: col,
      width: w,
      style: activeLineSt,
      extend: extend.right,
    )
    if activeLevels.len < activeLevels.capacity {
      let _ = activeLevels.push(LevelItem {
        id: id,
        label: lbl,
        shortLabel: shortLbl,
        tf: tfStr,
        price: px,
        startTs: sTs,
        color: col,
        isRes: isRes,
      })
    }
  }
}

// ----------------------------------------------------------------------------
// CALCULATION METHODOLOGY IMPLEMENTATIONS
// ----------------------------------------------------------------------------
fn addCamarillaPivots(tfStr: string, pfx: string, o: float, h: float, l: float, c: float, sTs: time, eTs: time, isHist: bool, col: color, w: float) {
  let rng = h - l
  let h3 = c + 1.1 * rng / 4.0
  let l3 = c - 1.1 * rng / 4.0
  let h4 = c + 1.1 * rng / 2.0
  let l4 = c - 1.1 * rng / 2.0
  let h5 = l > 0.0 ? (h / l) * c : c + 1.168 * rng
  let l5 = c - (h5 - c)

  addLevel(str.format("{0}_H3", pfx), str.format("{0} Cam H3", tfStr), str.format("{0} H3", tfStr), tfStr, h3, sTs, eTs, isHist, col, w, true)
  addLevel(str.format("{0}_L3", pfx), str.format("{0} Cam L3", tfStr), str.format("{0} L3", tfStr), tfStr, l3, sTs, eTs, isHist, col, w, false)
  addLevel(str.format("{0}_H4", pfx), str.format("{0} Cam H4", tfStr), str.format("{0} H4", tfStr), tfStr, h4, sTs, eTs, isHist, col, w, true)
  addLevel(str.format("{0}_L4", pfx), str.format("{0} Cam L4", tfStr), str.format("{0} L4", tfStr), tfStr, l4, sTs, eTs, isHist, col, w, false)

  if camFilter != "Key Breakout & Reversal (H3/H4 & L3/L4)" {
    addLevel(str.format("{0}_H5", pfx), str.format("{0} Cam H5", tfStr), str.format("{0} H5", tfStr), tfStr, h5, sTs, eTs, isHist, col, w, true)
    addLevel(str.format("{0}_L5", pfx), str.format("{0} Cam L5", tfStr), str.format("{0} L5", tfStr), tfStr, l5, sTs, eTs, isHist, col, w, false)
  }

  if camFilter == "All Levels (H1 - H6)" {
    let h1 = c + 1.1 * rng / 12.0
    let l1 = c - 1.1 * rng / 12.0
    let h2 = c + 1.1 * rng / 6.0
    let l2 = c - 1.1 * rng / 6.0
    let h6 = h5 + 1.168 * (h5 - h4)
    let l6 = c - (h6 - c)
    addLevel(str.format("{0}_H1", pfx), str.format("{0} Cam H1", tfStr), str.format("{0} H1", tfStr), tfStr, h1, sTs, eTs, isHist, col, w, true)
    addLevel(str.format("{0}_L1", pfx), str.format("{0} Cam L1", tfStr), str.format("{0} L1", tfStr), tfStr, l1, sTs, eTs, isHist, col, w, false)
    addLevel(str.format("{0}_H2", pfx), str.format("{0} Cam H2", tfStr), str.format("{0} H2", tfStr), tfStr, h2, sTs, eTs, isHist, col, w, true)
    addLevel(str.format("{0}_L2", pfx), str.format("{0} Cam L2", tfStr), str.format("{0} L2", tfStr), tfStr, l2, sTs, eTs, isHist, col, w, false)
    addLevel(str.format("{0}_H6", pfx), str.format("{0} Cam H6", tfStr), str.format("{0} H6", tfStr), tfStr, h6, sTs, eTs, isHist, col, w, true)
    addLevel(str.format("{0}_L6", pfx), str.format("{0} Cam L6", tfStr), str.format("{0} L6", tfStr), tfStr, l6, sTs, eTs, isHist, col, w, false)
  }
}

fn addClassicPivots(tfStr: string, pfx: string, o: float, h: float, l: float, c: float, sTs: time, eTs: time, isHist: bool, col: color, w: float) {
  let pp = (h + l + c) / 3.0
  let r1 = 2.0 * pp - l
  let s1 = 2.0 * pp - h
  let r2 = pp + (h - l)
  let s2 = pp - (h - l)
  let r3 = h + 2.0 * (pp - l)
  let s3 = l - 2.0 * (h - pp)
  let r4 = r3 + (h - l)
  let s4 = s3 - (h - l)

  addLevel(str.format("{0}_PP", pfx), str.format("{0} Pivot", tfStr), str.format("{0} PP", tfStr), tfStr, pp, sTs, eTs, isHist, col, w, false)
  addLevel(str.format("{0}_R1", pfx), str.format("{0} R1", tfStr),    str.format("{0} R1", tfStr), tfStr, r1, sTs, eTs, isHist, col, w, true)
  addLevel(str.format("{0}_S1", pfx), str.format("{0} S1", tfStr),    str.format("{0} S1", tfStr), tfStr, s1, sTs, eTs, isHist, col, w, false)
  addLevel(str.format("{0}_R2", pfx), str.format("{0} R2", tfStr),    str.format("{0} R2", tfStr), tfStr, r2, sTs, eTs, isHist, col, w, true)
  addLevel(str.format("{0}_S2", pfx), str.format("{0} S2", tfStr),    str.format("{0} S2", tfStr), tfStr, s2, sTs, eTs, isHist, col, w, false)
  addLevel(str.format("{0}_R3", pfx), str.format("{0} R3", tfStr),    str.format("{0} R3", tfStr), tfStr, r3, sTs, eTs, isHist, col, w, true)
  addLevel(str.format("{0}_S3", pfx), str.format("{0} S3", tfStr),    str.format("{0} S3", tfStr), tfStr, s3, sTs, eTs, isHist, col, w, false)
  addLevel(str.format("{0}_R4", pfx), str.format("{0} R4", tfStr),    str.format("{0} R4", tfStr), tfStr, r4, sTs, eTs, isHist, col, w, true)
  addLevel(str.format("{0}_S4", pfx), str.format("{0} S4", tfStr),    str.format("{0} S4", tfStr), tfStr, s4, sTs, eTs, isHist, col, w, false)
}

fn addFibonacciPivots(tfStr: string, pfx: string, o: float, h: float, l: float, c: float, sTs: time, eTs: time, isHist: bool, col: color, w: float) {
  let pp = (h + l + c) / 3.0
  let rng = h - l
  let r1 = pp + 0.382 * rng
  let s1 = pp - 0.382 * rng
  let r2 = pp + 0.618 * rng
  let s2 = pp - 0.618 * rng
  let r3 = pp + 1.000 * rng
  let s3 = pp - 1.000 * rng
  let r4 = pp + 1.618 * rng
  let s4 = pp - 1.618 * rng

  addLevel(str.format("{0}_F_PP", pfx), str.format("{0} Fib Pivot", tfStr), str.format("{0} Fib PP", tfStr), tfStr, pp, sTs, eTs, isHist, col, w, false)
  addLevel(str.format("{0}_F_R1", pfx), str.format("{0} Fib 38.2%", tfStr), str.format("{0} Fib R1", tfStr), tfStr, r1, sTs, eTs, isHist, col, w, true)
  addLevel(str.format("{0}_F_S1", pfx), str.format("{0} Fib 38.2%", tfStr), str.format("{0} Fib S1", tfStr), tfStr, s1, sTs, eTs, isHist, col, w, false)
  addLevel(str.format("{0}_F_R2", pfx), str.format("{0} Fib 61.8%", tfStr), str.format("{0} Fib R2", tfStr), tfStr, r2, sTs, eTs, isHist, col, w, true)
  addLevel(str.format("{0}_F_S2", pfx), str.format("{0} Fib 61.8%", tfStr), str.format("{0} Fib S2", tfStr), tfStr, s2, sTs, eTs, isHist, col, w, false)
  addLevel(str.format("{0}_F_R3", pfx), str.format("{0} Fib 100%", tfStr),  str.format("{0} Fib R3", tfStr), tfStr, r3, sTs, eTs, isHist, col, w, true)
  addLevel(str.format("{0}_F_S3", pfx), str.format("{0} Fib 100%", tfStr),  str.format("{0} Fib S3", tfStr), tfStr, s3, sTs, eTs, isHist, col, w, false)
  addLevel(str.format("{0}_F_R4", pfx), str.format("{0} Fib 161.8%", tfStr),str.format("{0} Fib R4", tfStr), tfStr, r4, sTs, eTs, isHist, col, w, true)
  addLevel(str.format("{0}_F_S4", pfx), str.format("{0} Fib 161.8%", tfStr),str.format("{0} Fib S4", tfStr), tfStr, s4, sTs, eTs, isHist, col, w, false)
}

fn addCprLevels(tfStr: string, pfx: string, o: float, h: float, l: float, c: float, sTs: time, eTs: time, isHist: bool, col: color, w: float) {
  let pp = (h + l + c) / 3.0
  let bc = (h + l) / 2.0
  let tc = 2.0 * pp - bc
  let cprTop = math.max(tc, bc)
  let cprBot = math.min(tc, bc)
  let r1 = 2.0 * pp - l
  let s1 = 2.0 * pp - h
  let r2 = pp + (h - l)
  let s2 = pp - (h - l)

  addLevel(str.format("{0}_CPR_TC", pfx), str.format("{0} CPR TC", tfStr), str.format("{0} TC", tfStr), tfStr, cprTop, sTs, eTs, isHist, col, w, true)
  addLevel(str.format("{0}_CPR_P",  pfx), str.format("{0} CPR Pivot", tfStr), str.format("{0} P", tfStr), tfStr, pp,     sTs, eTs, isHist, col, w, false)
  addLevel(str.format("{0}_CPR_BC", pfx), str.format("{0} CPR BC", tfStr), str.format("{0} BC", tfStr), tfStr, cprBot, sTs, eTs, isHist, col, w, false)
  addLevel(str.format("{0}_CPR_R1", pfx), str.format("{0} CPR R1", tfStr), str.format("{0} R1", tfStr), tfStr, r1,     sTs, eTs, isHist, col, w, true)
  addLevel(str.format("{0}_CPR_S1", pfx), str.format("{0} CPR S1", tfStr), str.format("{0} S1", tfStr), tfStr, s1,     sTs, eTs, isHist, col, w, false)
  addLevel(str.format("{0}_CPR_R2", pfx), str.format("{0} CPR R2", tfStr), str.format("{0} R2", tfStr), tfStr, r2,     sTs, eTs, isHist, col, w, true)
  addLevel(str.format("{0}_CPR_S2", pfx), str.format("{0} CPR S2", tfStr), str.format("{0} S2", tfStr), tfStr, s2,     sTs, eTs, isHist, col, w, false)
}

fn addWoodiePivots(tfStr: string, pfx: string, o: float, h: float, l: float, c: float, sTs: time, eTs: time, isHist: bool, col: color, w: float) {
  let pp = (h + l + 2.0 * o) / 4.0
  let r1 = 2.0 * pp - l
  let s1 = 2.0 * pp - h
  let r2 = pp + (h - l)
  let s2 = pp - (h - l)
  let r3 = h + 2.0 * (pp - l)
  let s3 = l - 2.0 * (h - pp)

  addLevel(str.format("{0}_W_PP", pfx), str.format("{0} Woodie PP", tfStr), str.format("{0} W-PP", tfStr), tfStr, pp, sTs, eTs, isHist, col, w, false)
  addLevel(str.format("{0}_W_R1", pfx), str.format("{0} Woodie R1", tfStr), str.format("{0} W-R1", tfStr), tfStr, r1, sTs, eTs, isHist, col, w, true)
  addLevel(str.format("{0}_W_S1", pfx), str.format("{0} Woodie S1", tfStr), str.format("{0} W-S1", tfStr), tfStr, s1, sTs, eTs, isHist, col, w, false)
  addLevel(str.format("{0}_W_R2", pfx), str.format("{0} Woodie R2", tfStr), str.format("{0} W-R2", tfStr), tfStr, r2, sTs, eTs, isHist, col, w, true)
  addLevel(str.format("{0}_W_S2", pfx), str.format("{0} Woodie S2", tfStr), str.format("{0} W-S2", tfStr), tfStr, s2, sTs, eTs, isHist, col, w, false)
  addLevel(str.format("{0}_W_R3", pfx), str.format("{0} Woodie R3", tfStr), str.format("{0} W-R3", tfStr), tfStr, r3, sTs, eTs, isHist, col, w, true)
  addLevel(str.format("{0}_W_S3", pfx), str.format("{0} Woodie S3", tfStr), str.format("{0} W-S3", tfStr), tfStr, s3, sTs, eTs, isHist, col, w, false)
}

fn addDeMarkPivots(tfStr: string, pfx: string, o: float, h: float, l: float, c: float, sTs: time, eTs: time, isHist: bool, col: color, w: float) {
  let x = c < o ? (h + 2.0 * l + c) : (c > o ? (2.0 * h + l + c) : (h + l + 2.0 * c))
  let pp = x / 4.0
  let r1 = x / 2.0 - l
  let s1 = x / 2.0 - h

  addLevel(str.format("{0}_DM_PP", pfx), str.format("{0} DeMark PP", tfStr), str.format("{0} DM-PP", tfStr), tfStr, pp, sTs, eTs, isHist, col, w, false)
  addLevel(str.format("{0}_DM_R1", pfx), str.format("{0} DeMark R1", tfStr), str.format("{0} DM-R1", tfStr), tfStr, r1, sTs, eTs, isHist, col, w, true)
  addLevel(str.format("{0}_DM_S1", pfx), str.format("{0} DeMark S1", tfStr), str.format("{0} DM-S1", tfStr), tfStr, s1, sTs, eTs, isHist, col, w, false)
}

fn addPrevPeriodExtremes(tfStr: string, pfx: string, o: float, h: float, l: float, c: float, sTs: time, eTs: time, isHist: bool, col: color, w: float) {
  let mid = (h + l) / 2.0
  let pfxTag = tfStr == "1D" ? "PD" : (tfStr == "1W" ? "PW" : (tfStr == "1M" ? "PM" : tfStr))

  addLevel(str.format("{0}_PH", pfx), str.format("{0} High", pfxTag), str.format("{0}H", pfxTag), tfStr, h,   sTs, eTs, isHist, col, w, true)
  addLevel(str.format("{0}_PL", pfx), str.format("{0} Low", pfxTag),  str.format("{0}L", pfxTag), tfStr, l,   sTs, eTs, isHist, col, w, false)
  addLevel(str.format("{0}_PC", pfx), str.format("{0} Close", pfxTag),str.format("{0}C", pfxTag), tfStr, c,  sTs, eTs, isHist, col, w, false)
  addLevel(str.format("{0}_PO", pfx), str.format("{0} Open", pfxTag), str.format("{0}O", pfxTag), tfStr, o,  sTs, eTs, isHist, col, w, false)
  addLevel(str.format("{0}_PM", pfx), str.format("{0} Mid (50%)", pfxTag), str.format("{0}M", pfxTag), tfStr, mid, sTs, eTs, isHist, col, w, false)
}

fn dispatchMethod(method: string, tfStr: string, pfx: string, o: float, h: float, l: float, c: float, sTs: time, eTs: time, isHist: bool, col: color, w: float) {
  if method == "Camarilla" {
    addCamarillaPivots(tfStr, pfx, o, h, l, c, sTs, eTs, isHist, col, w)
  } else if method == "Classic / Floor" {
    addClassicPivots(tfStr, pfx, o, h, l, c, sTs, eTs, isHist, col, w)
  } else if method == "Fibonacci" {
    addFibonacciPivots(tfStr, pfx, o, h, l, c, sTs, eTs, isHist, col, w)
  } else if method == "CPR" {
    addCprLevels(tfStr, pfx, o, h, l, c, sTs, eTs, isHist, col, w)
  } else if method == "Woodie" {
    addWoodiePivots(tfStr, pfx, o, h, l, c, sTs, eTs, isHist, col, w)
  } else if method == "DeMark" {
    addDeMarkPivots(tfStr, pfx, o, h, l, c, sTs, eTs, isHist, col, w)
  } else if method == "Previous Period Extremes" {
    addPrevPeriodExtremes(tfStr, pfx, o, h, l, c, sTs, eTs, isHist, col, w)
  }

  // Optional overlay of High / Low / Mid of previous period
  if showPrevExtremes && method != "Previous Period Extremes" {
    let mid = (h + l) / 2.0
    let pfxTag = tfStr == "1D" ? "PD" : (tfStr == "1W" ? "PW" : (tfStr == "1M" ? "PM" : tfStr))
    addLevel(str.format("{0}_PH", pfx), str.format("{0} High", pfxTag), str.format("{0}H", pfxTag), tfStr, h,   sTs, eTs, isHist, col, w, true)
    addLevel(str.format("{0}_PL", pfx), str.format("{0} Low", pfxTag),  str.format("{0}L", pfxTag), tfStr, l,   sTs, eTs, isHist, col, w, false)
    addLevel(str.format("{0}_PM", pfx), str.format("{0} Mid", pfxTag),  str.format("{0}M", pfxTag), tfStr, mid, sTs, eTs, isHist, col, w, false)
  }
}

// ----------------------------------------------------------------------------
// MAIN UPDATE HANDLER
// ----------------------------------------------------------------------------
on chart.update {
  let ts     = chart.time ?? time.fromUnixSeconds(0)
  let closeP = chart.close ?? 0.0
  let openP  = chart.open  ?? closeP
  let highP  = chart.high  ?? closeP
  let lowP   = chart.low   ?? closeP
  let atr14  = chart.atr(14) ?? (highP - lowP)

  if chart.isLast {
    let _ = levelLines.clear("")
    let _ = levelMarginL.clear("")
    let _ = levelOriginL.clear("")
    activeLevels.clear()

    // 1. 4-HOUR TIMEFRAME (4H)
    if enable4H {
      let actStart = time.floor(ts, 4h)
      let o0 = tf4h.open ?? openP
      let h0 = tf4h.high ?? highP
      let l0 = tf4h.low  ?? lowP
      let c0 = tf4h.close ?? closeP
      dispatchMethod(calcMethod, "4H", "act_4h", o0, h0, l0, c0, actStart, actStart, false, col4H, width4H)

      if showHistorical {
        for k in 1..(historicalPeriods + 1) {
          let sTs = tf4h.time[k - 1]
          let eTs = (k == 1) ? actStart : tf4h.time[k - 2]
          let oK  = tf4h.open[k]
          let hK  = tf4h.high[k]
          let lK  = tf4h.low[k]
          let cK  = tf4h.close[k]
          if sTs != null && eTs != null && hK != null && lK != null && cK != null {
            let pfx = str.format("hist_4h_{0}", k)
            dispatchMethod(calcMethod, "4H", pfx, oK ?? openP, hK ?? highP, lK ?? lowP, cK ?? closeP, sTs ?? actStart, eTs ?? actStart, true, col4H, width4H)
          }
        }
      }
    }

    // 2. DAILY TIMEFRAME (1D)
    if enable1D {
      let actStart = time.floor(ts, 1D)
      let o0 = tf1D.open ?? openP
      let h0 = tf1D.high ?? highP
      let l0 = tf1D.low  ?? lowP
      let c0 = tf1D.close ?? closeP
      dispatchMethod(calcMethod, "1D", "act_1d", o0, h0, l0, c0, actStart, actStart, false, col1D, width1D)

      if showHistorical {
        for k in 1..(historicalPeriods + 1) {
          let sTs = tf1D.time[k - 1]
          let eTs = (k == 1) ? actStart : tf1D.time[k - 2]
          let oK  = tf1D.open[k]
          let hK  = tf1D.high[k]
          let lK  = tf1D.low[k]
          let cK  = tf1D.close[k]
          if sTs != null && eTs != null && hK != null && lK != null && cK != null {
            let pfx = str.format("hist_1d_{0}", k)
            dispatchMethod(calcMethod, "1D", pfx, oK ?? openP, hK ?? highP, lK ?? lowP, cK ?? closeP, sTs ?? actStart, eTs ?? actStart, true, col1D, width1D)
          }
        }
      }
    }

    // 3. WEEKLY TIMEFRAME (1W)
    if enable1W {
      let actStart = time.floor(ts, 1W)
      let o0 = tf1W.open ?? openP
      let h0 = tf1W.high ?? highP
      let l0 = tf1W.low  ?? lowP
      let c0 = tf1W.close ?? closeP
      dispatchMethod(calcMethod, "1W", "act_1w", o0, h0, l0, c0, actStart, actStart, false, col1W, width1W)

      if showHistorical {
        for k in 1..(historicalPeriods + 1) {
          let sTs = tf1W.time[k - 1]
          let eTs = (k == 1) ? actStart : tf1W.time[k - 2]
          let oK  = tf1W.open[k]
          let hK  = tf1W.high[k]
          let lK  = tf1W.low[k]
          let cK  = tf1W.close[k]
          if sTs != null && eTs != null && hK != null && lK != null && cK != null {
            let pfx = str.format("hist_1w_{0}", k)
            dispatchMethod(calcMethod, "1W", pfx, oK ?? openP, hK ?? highP, lK ?? lowP, cK ?? closeP, sTs ?? actStart, eTs ?? actStart, true, col1W, width1W)
          }
        }
      }
    }

    // 4. MONTHLY TIMEFRAME (1M)
    if enable1M {
      let actStart = time.floor(ts, 1M)
      let o0 = tf1M.open ?? openP
      let h0 = tf1M.high ?? highP
      let l0 = tf1M.low  ?? lowP
      let c0 = tf1M.close ?? closeP
      dispatchMethod(calcMethod, "1M", "act_1m", o0, h0, l0, c0, actStart, actStart, false, col1M, width1M)

      if showHistorical {
        for k in 1..(historicalPeriods + 1) {
          let sTs = tf1M.time[k - 1]
          let eTs = (k == 1) ? actStart : tf1M.time[k - 2]
          let oK  = tf1M.open[k]
          let hK  = tf1M.high[k]
          let lK  = tf1M.low[k]
          let cK  = tf1M.close[k]
          if sTs != null && eTs != null && hK != null && lK != null && cK != null {
            let pfx = str.format("hist_1m_{0}", k)
            dispatchMethod(calcMethod, "1M", pfx, oK ?? openP, hK ?? highP, lK ?? lowP, cK ?? closeP, sTs ?? actStart, eTs ?? actStart, true, col1M, width1M)
          }
        }
      }
    }

    // 5. QUARTERLY TIMEFRAME (1Q)
    if enable1Q {
      let actStart = time.floor(ts, 3M)
      let o0 = tf1Q.open ?? openP
      let h0 = tf1Q.high ?? highP
      let l0 = tf1Q.low  ?? lowP
      let c0 = tf1Q.close ?? closeP
      dispatchMethod(calcMethod, "1Q", "act_1q", o0, h0, l0, c0, actStart, actStart, false, col1Q, width1Q)

      if showHistorical {
        for k in 1..(historicalPeriods + 1) {
          let sTs = tf1Q.time[k - 1]
          let eTs = (k == 1) ? actStart : tf1Q.time[k - 2]
          let oK  = tf1Q.open[k]
          let hK  = tf1Q.high[k]
          let lK  = tf1Q.low[k]
          let cK  = tf1Q.close[k]
          if sTs != null && eTs != null && hK != null && lK != null && cK != null {
            let pfx = str.format("hist_1q_{0}", k)
            dispatchMethod(calcMethod, "1Q", pfx, oK ?? openP, hK ?? highP, lK ?? lowP, cK ?? closeP, sTs ?? actStart, eTs ?? actStart, true, col1Q, width1Q)
          }
        }
      }
    }

    // 6. YEARLY TIMEFRAME (1Y)
    if enable1Y {
      let actStart = time.floor(ts, 1Y)
      let o0 = tf1Y.open ?? openP
      let h0 = tf1Y.high ?? highP
      let l0 = tf1Y.low  ?? lowP
      let c0 = tf1Y.close ?? closeP
      dispatchMethod(calcMethod, "1Y", "act_1y", o0, h0, l0, c0, actStart, actStart, false, col1Y, width1Y)

      if showHistorical {
        for k in 1..(historicalPeriods + 1) {
          let sTs = tf1Y.time[k - 1]
          let eTs = (k == 1) ? actStart : tf1Y.time[k - 2]
          let oK  = tf1Y.open[k]
          let hK  = tf1Y.high[k]
          let lK  = tf1Y.low[k]
          let cK  = tf1Y.close[k]
          if sTs != null && eTs != null && hK != null && lK != null && cK != null {
            let pfx = str.format("hist_1y_{0}", k)
            dispatchMethod(calcMethod, "1Y", pfx, oK ?? openP, hK ?? highP, lK ?? lowP, cK ?? closeP, sTs ?? actStart, eTs ?? actStart, true, col1Y, width1Y)
          }
        }
      }
    }

    // 7. SORT ACTIVE LEVELS DESCENDING BY PRICE FOR CLEAN MARGIN DISPLAY
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

    // 8. RENDER LABELS (RIGHT MARGIN & ORIGIN) WITH ANTI-COLLISION STAGGER
    let minLabelGap = math.max(atr14 * 0.9, math.max(closeP * 0.0018, float(context.tickSize) * 30.0))
    let lastLabeledPx = 999999999.0
    let staggerCol = 0

    let nearestSuppPx = 0.0
    let nearestResPx  = 99999999.0
    let nearestSuppDesc = "None"
    let nearestResDesc  = "None"

    for i in 0..numLevels {
      let lvl = activeLevels.get(i)
      if lvl != null {
        let px = lvl.price

        // Nearest Support & Resistance tracking
        if px < closeP && px > nearestSuppPx {
          nearestSuppPx = px
          nearestSuppDesc = str.format("{0} ({1})", lvl.shortLabel, formatPrice(px))
        }
        if px > closeP && px < nearestResPx {
          nearestResPx = px
          nearestResDesc = str.format("{0} ({1})", lvl.shortLabel, formatPrice(px))
        }

        if labelTagPos != "None" {
          let pxStr = labelFormat == "Compact" ? formatCompactPrice(px) : formatPrice(px)
          let nameStr = (labelFormat == "Compact") ? lvl.shortLabel : lvl.label
          let labelText = labelFormat == "Price Only" ? pxStr :
                          (labelFormat == "Name Only" ? nameStr : str.format("{0} · {1}", nameStr, pxStr))

          let distFromPrev = lastLabeledPx - px
          let isCollision = distFromPrev < minLabelGap
          let yLift = lblFactor
          if preventLabelOverlap && isCollision {
            staggerCol = (staggerCol >= 2) ? 0 : (staggerCol + 1)
            if staggerCol == 1 {
              yLift = 1.0 - (labelLiftBps / 10000.0) * 1.5
            } else if staggerCol == 2 {
              yLift = 1.0 + (labelLiftBps / 10000.0) * 2.2
            }
          } else {
            staggerCol = 0
            yLift = lblFactor
          }

          let yPos = px * yLift

          if tagMargin {
            levelMarginL.get(lvl.id).set(
              x: 8.0,
              y: yPos,
              text: labelText,
              color: lvl.color,
              size: labelBadgeSize,
              textAlign: "right",
              zIndex: 40,
            )
            lastLabeledPx = px
          }

          if tagOrigin {
            levelOriginL.get(lvl.id).set(
              x: lvl.startTs,
              y: yPos,
              text: labelText,
              color: lvl.color,
              size: labelBadgeSize,
              zIndex: 40,
            )
          }
        }
      }
    }

    // 9. TELEMETRY HEADS-UP DISPLAY (HUD)
    if showHud {
      let hudX1 = 18.0
      let hudY1 = 45.0
      let hudX2 = 360.0
      let hudY2 = 185.0

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
        x: hudX1 + 16.0, y: hudY1 + 16.0,
        text: str.format("QUANT LEVELS MAP · {0}", str.upper(calcMethod)),
        color: color.teal, size: 13.5, zIndex: 12,
      )

      let tfSummary = str.format("TFs: {0}{1}{2}{3}{4}{5}",
        enable4H ? "4H " : "",
        enable1D ? "1D " : "",
        enable1W ? "1W " : "",
        enable1M ? "1M " : "",
        enable1Q ? "1Q " : "",
        enable1Y ? "1Y " : ""
      )
      hudLabels.get("tfs").set(
        x: hudX1 + 16.0, y: hudY1 + 42.0,
        text: str.format("{0} | History: {1} periods", tfSummary, showHistorical ? str.format("{0}", historicalPeriods) : "Off"),
        color: color.silver, size: 11.5, zIndex: 12,
      )

      hudLabels.get("res").set(
        x: hudX1 + 16.0, y: hudY1 + 68.0,
        text: str.format("Nearest R: {0}", nearestResDesc),
        color: color.rgb(244, 67, 54), size: 12.5, zIndex: 12,
      )

      hudLabels.get("supp").set(
        x: hudX1 + 16.0, y: hudY1 + 94.0,
        text: str.format("Nearest S: {0}", nearestSuppDesc),
        color: color.rgb(76, 175, 80), size: 12.5, zIndex: 12,
      )
    }
  }
}
