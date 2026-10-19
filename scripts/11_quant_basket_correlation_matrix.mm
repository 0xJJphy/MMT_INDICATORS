//@version=3
script "Quant Basket Correlation & Dispersion Engine"

// ============================================================================
// INDICATOR: Quant Basket Correlation & Dispersion Engine [SCRIPT 11 - v3]
// SUITE:     MMT Quantitative Indicator Suite
// ENGINE:    MMT Scripting v3 (Strictly Typed DSL)
// AUTHOR:    Senior Quantitative Strategist & Derivatives Architect
//
// DYNAMIC NARRATIVE PRESET ARCHITECTURE (Zero Manual Picker Friction):
// - Allows instantaneous cross-basket rotation analysis across 6 major crypto
//   narratives (Top Alts, Memes, RWA, AI/DePIN, New L1s, DeFi Core).
// - Subscribes strictly to 10 active liquid data feeds (1 BTC + 3 per basket),
//   guaranteeing ultra-fast execution and compliance with MMT L006 rules.
// ============================================================================

// ----------------------------------------------------------------------------
// USER CONFIGURATION & PRESET SELECTION
// ----------------------------------------------------------------------------
input (
  input.tab(title: "Narrative Baskets")
  input.group(title: "Pre-Configured Basket Presets", collapsible: false)
  cesta1_type = input.select("Top Alts", title: "Cesta 1 (Base)", options: ["Top Alts", "Memes", "RWA & Yield", "AI & DePIN", "New L1s", "DeFi Core"])
  cesta2_type = input.select("Memes", title: "Cesta 2 (Speculative)", options: ["Memes", "Top Alts", "RWA & Yield", "AI & DePIN", "New L1s", "DeFi Core"])
  cesta3_type = input.select("RWA & Yield", title: "Cesta 3 (Thematic)", options: ["RWA & Yield", "Top Alts", "Memes", "AI & DePIN", "New L1s", "DeFi Core"])

  input.tab(title: "Statistical Parameters")
  input.group(title: "Rolling Window & Thresholds", collapsible: false)
  corrLen           = input.int(48, title: "Rolling Estimation Window (Bars)", min: 10, max: 120)
  syncThreshold     = input.float(0.75, title: "Coupled Regime Threshold (Rho)", min: 0.50, max: 0.95)
  decoupleThreshold = input.float(0.35, title: "Decoupled Regime Threshold (Rho)", min: 0.10, max: 0.50)

  input.group(title: "Sub-Pane Plot Visibility", collapsible: true)
  showB1VsBtc       = input.bool(true, title: "Plot Cesta 1 vs BTC")
  showB2VsBtc       = input.bool(true, title: "Plot Cesta 2 vs BTC")
  showB3VsBtc       = input.bool(true, title: "Plot Cesta 3 vs BTC")
  showAvgDispersion = input.bool(true, title: "Plot Avg Market Dispersion")
)

// ----------------------------------------------------------------------------
// SETUP RESOLUTION: DYNAMIC SYMBOL & LABEL MAPPING
// ----------------------------------------------------------------------------
// Cesta 1 Symbols & Labels
setup sym_b1_1 = (cesta1_type == "Memes") ? "doge/usd" : ((cesta1_type == "RWA & Yield") ? "ondo/usd" : ((cesta1_type == "AI & DePIN") ? "near/usd" : ((cesta1_type == "New L1s") ? "sui/usd" : ((cesta1_type == "DeFi Core") ? "link/usd" : "eth/usd"))))
setup sym_b1_2 = (cesta1_type == "Memes") ? "1000pepe/usd" : ((cesta1_type == "RWA & Yield") ? "pendle/usd" : ((cesta1_type == "AI & DePIN") ? "render/usd" : ((cesta1_type == "New L1s") ? "avax/usd" : ((cesta1_type == "DeFi Core") ? "uni/usd" : "sol/usd"))))
setup sym_b1_3 = (cesta1_type == "Memes") ? "wif/usd" : ((cesta1_type == "RWA & Yield") ? "aave/usd" : ((cesta1_type == "AI & DePIN") ? "fet/usd" : ((cesta1_type == "New L1s") ? "apt/usd" : ((cesta1_type == "DeFi Core") ? "aave/usd" : "bnb/usd"))))

setup lbl_b1_1 = (cesta1_type == "Memes") ? "DOGE" : ((cesta1_type == "RWA & Yield") ? "ONDO" : ((cesta1_type == "AI & DePIN") ? "NEAR" : ((cesta1_type == "New L1s") ? "SUI" : ((cesta1_type == "DeFi Core") ? "LINK" : "ETH"))))
setup lbl_b1_2 = (cesta1_type == "Memes") ? "PEPE" : ((cesta1_type == "RWA & Yield") ? "PENDLE" : ((cesta1_type == "AI & DePIN") ? "RENDER" : ((cesta1_type == "New L1s") ? "AVAX" : ((cesta1_type == "DeFi Core") ? "UNI" : "SOL"))))
setup lbl_b1_3 = (cesta1_type == "Memes") ? "WIF" : ((cesta1_type == "RWA & Yield") ? "AAVE" : ((cesta1_type == "AI & DePIN") ? "FET" : ((cesta1_type == "New L1s") ? "APT" : ((cesta1_type == "DeFi Core") ? "AAVE" : "BNB"))))

// Cesta 2 Symbols & Labels
setup sym_b2_1 = (cesta2_type == "Top Alts") ? "eth/usd" : ((cesta2_type == "RWA & Yield") ? "ondo/usd" : ((cesta2_type == "AI & DePIN") ? "near/usd" : ((cesta2_type == "New L1s") ? "sui/usd" : ((cesta2_type == "DeFi Core") ? "link/usd" : "doge/usd"))))
setup sym_b2_2 = (cesta2_type == "Top Alts") ? "sol/usd" : ((cesta2_type == "RWA & Yield") ? "pendle/usd" : ((cesta2_type == "AI & DePIN") ? "render/usd" : ((cesta2_type == "New L1s") ? "avax/usd" : ((cesta2_type == "DeFi Core") ? "uni/usd" : "1000pepe/usd"))))
setup sym_b2_3 = (cesta2_type == "Top Alts") ? "bnb/usd" : ((cesta2_type == "RWA & Yield") ? "aave/usd" : ((cesta2_type == "AI & DePIN") ? "fet/usd" : ((cesta2_type == "New L1s") ? "apt/usd" : ((cesta2_type == "DeFi Core") ? "aave/usd" : "wif/usd"))))

setup lbl_b2_1 = (cesta2_type == "Top Alts") ? "ETH" : ((cesta2_type == "RWA & Yield") ? "ONDO" : ((cesta2_type == "AI & DePIN") ? "NEAR" : ((cesta2_type == "New L1s") ? "SUI" : ((cesta2_type == "DeFi Core") ? "LINK" : "DOGE"))))
setup lbl_b2_2 = (cesta2_type == "Top Alts") ? "SOL" : ((cesta2_type == "RWA & Yield") ? "PENDLE" : ((cesta2_type == "AI & DePIN") ? "RENDER" : ((cesta2_type == "New L1s") ? "AVAX" : ((cesta2_type == "DeFi Core") ? "UNI" : "PEPE"))))
setup lbl_b2_3 = (cesta2_type == "Top Alts") ? "BNB" : ((cesta2_type == "RWA & Yield") ? "AAVE" : ((cesta2_type == "AI & DePIN") ? "FET" : ((cesta2_type == "New L1s") ? "APT" : ((cesta2_type == "DeFi Core") ? "AAVE" : "WIF"))))

// Cesta 3 Symbols & Labels
setup sym_b3_1 = (cesta3_type == "Top Alts") ? "eth/usd" : ((cesta3_type == "Memes") ? "doge/usd" : ((cesta3_type == "AI & DePIN") ? "near/usd" : ((cesta3_type == "New L1s") ? "sui/usd" : ((cesta3_type == "DeFi Core") ? "link/usd" : "ondo/usd"))))
setup sym_b3_2 = (cesta3_type == "Top Alts") ? "sol/usd" : ((cesta3_type == "Memes") ? "1000pepe/usd" : ((cesta3_type == "AI & DePIN") ? "render/usd" : ((cesta3_type == "New L1s") ? "avax/usd" : ((cesta3_type == "DeFi Core") ? "uni/usd" : "pendle/usd"))))
setup sym_b3_3 = (cesta3_type == "Top Alts") ? "bnb/usd" : ((cesta3_type == "Memes") ? "wif/usd" : ((cesta3_type == "AI & DePIN") ? "fet/usd" : ((cesta3_type == "New L1s") ? "apt/usd" : ((cesta3_type == "DeFi Core") ? "aave/usd" : "aave/usd"))))

setup lbl_b3_1 = (cesta3_type == "Top Alts") ? "ETH" : ((cesta3_type == "Memes") ? "DOGE" : ((cesta3_type == "AI & DePIN") ? "NEAR" : ((cesta3_type == "New L1s") ? "SUI" : ((cesta3_type == "DeFi Core") ? "LINK" : "ONDO"))))
setup lbl_b3_2 = (cesta3_type == "Top Alts") ? "SOL" : ((cesta3_type == "Memes") ? "PEPE" : ((cesta3_type == "AI & DePIN") ? "RENDER" : ((cesta3_type == "New L1s") ? "AVAX" : ((cesta3_type == "DeFi Core") ? "UNI" : "PENDLE"))))
setup lbl_b3_3 = (cesta3_type == "Top Alts") ? "BNB" : ((cesta3_type == "Memes") ? "WIF" : ((cesta3_type == "AI & DePIN") ? "FET" : ((cesta3_type == "New L1s") ? "APT" : ((cesta3_type == "DeFi Core") ? "AAVE" : "AAVE"))))

// ----------------------------------------------------------------------------
// DATA SUBSCRIPTIONS (Strictly 10 Dynamic Feeds)
// ----------------------------------------------------------------------------
data (
  btc = subscribe(data.ohlcv, exchange: "binancef", symbol: "btc/usd")

  // Cesta 1 Feeds
  b1_1 = subscribe(data.ohlcv, exchange: "binancef", symbol: sym_b1_1)
  b1_2 = subscribe(data.ohlcv, exchange: "binancef", symbol: sym_b1_2)
  b1_3 = subscribe(data.ohlcv, exchange: "binancef", symbol: sym_b1_3)

  // Cesta 2 Feeds
  b2_1 = subscribe(data.ohlcv, exchange: "binancef", symbol: sym_b2_1)
  b2_2 = subscribe(data.ohlcv, exchange: "binancef", symbol: sym_b2_2)
  b2_3 = subscribe(data.ohlcv, exchange: "binancef", symbol: sym_b2_3)

  // Cesta 3 Feeds
  b3_1 = subscribe(data.ohlcv, exchange: "binancef", symbol: sym_b3_1)
  b3_2 = subscribe(data.ohlcv, exchange: "binancef", symbol: sym_b3_2)
  b3_3 = subscribe(data.ohlcv, exchange: "binancef", symbol: sym_b3_3)
)

// ----------------------------------------------------------------------------
// STATE BUFFERS
// ----------------------------------------------------------------------------
state r_btc:  rolling<float> = rolling<float>(120)

state r_b1_1: rolling<float> = rolling<float>(120)
state r_b1_2: rolling<float> = rolling<float>(120)
state r_b1_3: rolling<float> = rolling<float>(120)

state r_b2_1: rolling<float> = rolling<float>(120)
state r_b2_2: rolling<float> = rolling<float>(120)
state r_b2_3: rolling<float> = rolling<float>(120)

state r_b3_1: rolling<float> = rolling<float>(120)
state r_b3_2: rolling<float> = rolling<float>(120)
state r_b3_3: rolling<float> = rolling<float>(120)

state r_b1:   rolling<float> = rolling<float>(120)
state r_b2:   rolling<float> = rolling<float>(120)
state r_b3:   rolling<float> = rolling<float>(120)

// ----------------------------------------------------------------------------
// SURFACE 1: DOCKABLE WINDOW (Multi-Panel Dashboard)
// ----------------------------------------------------------------------------
window matrixWin = window(title: "Quant Dynamic Basket Correlation Matrix") {
  // 1. Graphical 2D Heatmap
  hm: heatmap.new(
    title: "Dynamic Cross-Basket Heatmap",
    x: axis.category,
    y: axis.category,
    capacity: 25,
    min: -1.0,
    max: 1.0,
    palette: [color.rgb(220, 38, 38), color.rgb(51, 65, 85), color.rgb(34, 197, 94)]
  ),

  // 2. Symmetric 2D Cross-Basket Table
  matrixTbl: table.new([
    table.col(title: "Basket", width: 1.4),
    table.col(title: "BTC", align: align.center, width: 1.0),
    table.col(title: "Cesta 1", align: align.center, width: 1.0),
    table.col(title: "Cesta 2", align: align.center, width: 1.0),
    table.col(title: "Cesta 3", align: align.center, width: 1.0),
    table.col(title: "Beta (BTC)", align: align.right, width: 1.1),
    table.col(title: "Regime", align: align.center, width: 1.3)
  ], title: "Symmetric 2D Cross-Basket Matrix", capacity: 6),

  // 3. Component Tokens Granular Breakdown
  tokenTbl: table.new([
    table.col(title: "Asset", width: 1.1),
    table.col(title: "Basket", width: 1.3),
    table.col(title: "Corr (BTC)", align: align.right, width: 1.0),
    table.col(title: "Beta (BTC)", align: align.right, width: 1.0),
    table.col(title: "24h Ret", align: align.right, width: 1.1),
    table.col(title: "Regime", align: align.center, width: 1.3)
  ], title: "Active Underlying Asset Breakdown", capacity: 11),
}

// ----------------------------------------------------------------------------
// SURFACE 2: SUB-PANE (Historical Time-Series Oscillator)
// ----------------------------------------------------------------------------
pane corrPane = pane(title: "Dynamic Basket Correlations vs BTC", height: 0.3)

plot lineSync = plot.line(title: "Sync Threshold", color: color.rgb(100, 116, 139), width: 1.0, style: linestyle.dashed, on: corrPane)
plot lineZero = plot.line(title: "Zero Line", color: color.rgb(71, 85, 105), width: 1.0, style: linestyle.dotted, on: corrPane)
plot lineDeco = plot.line(title: "Decouple Threshold", color: color.rgb(100, 116, 139), width: 1.0, style: linestyle.dashed, on: corrPane)

plot plotB1   = plot.line(title: "Cesta 1 vs BTC", color: color.rgb(59, 130, 246), width: 1.5, on: corrPane)
plot plotB2   = plot.line(title: "Cesta 2 vs BTC", color: color.rgb(236, 72, 153), width: 1.5, on: corrPane)
plot plotB3   = plot.line(title: "Cesta 3 vs BTC", color: color.rgb(16, 185, 129), width: 1.5, on: corrPane)
plot plotDisp = plot.line(title: "Avg Market Correlation", color: color.rgb(245, 158, 11), width: 2.2, on: corrPane)

// ----------------------------------------------------------------------------
// MATHEMATICAL ENGINE FUNCTIONS
// ----------------------------------------------------------------------------
fn log_ret(curr: float?, prev: float?) -> float {
  let c = curr ?? 0.0
  let p = prev ?? 0.0
  if p <= 0.0 || c <= 0.0 {
    return 0.0
  }
  return math.log(c / p) ?? 0.0
}

fn calc_corr_beta(x: rolling<float>, y: rolling<float>, length: int) -> (float, float) {
  let sum_x = 0.0
  let sum_y = 0.0
  let n = float(length)
  for i in 0..length {
    sum_x += (x.get(i) ?? 0.0)
    sum_y += (y.get(i) ?? 0.0)
  }
  let mean_x = sum_x / n
  let mean_y = sum_y / n

  let cov = 0.0
  let var_x = 0.0
  let var_y = 0.0
  for i in 0..length {
    let dx = (x.get(i) ?? 0.0) - mean_x
    let dy = (y.get(i) ?? 0.0) - mean_y
    cov += dx * dy
    var_x += dx * dx
    var_y += dy * dy
  }

  let denom = (math.sqrt(var_x * var_y) ?? 0.0)
  let corr = (denom > 0.00000001) ? (cov / denom) : 0.0
  let beta = (var_x > 0.00000001) ? (cov / var_x) : 0.0
  return corr, beta
}

fn pct_ret(close: float?, open: float?) -> float {
  let c = close ?? 0.0
  let o = open ?? 0.0
  return (o > 0.0) ? ((c - o) / o * 100.0) : 0.0
}

fn rho_color(rho: float, sync: float, deco: float) -> color {
  if rho >= sync {
    return color.rgb(34, 197, 94)
  }
  if rho <= deco {
    return color.rgb(239, 68, 68)
  }
  return color.rgb(234, 179, 8)
}

fn reg_label(rho: float, sync: float, deco: float) -> string {
  if rho >= sync {
    return "Coupled (Sync)"
  }
  if rho <= deco {
    return "Decoupled (Rot)"
  }
  return "Neutral"
}

fn ret_color(p: float) -> color {
  if p >= 0.0 {
    return color.rgb(34, 197, 94)
  }
  return color.rgb(239, 68, 68)
}

// ----------------------------------------------------------------------------
// EVENT DISPATCHER
// ----------------------------------------------------------------------------
on btc.close {
  let ret_btc = log_ret(btc.close, btc.open)

  let r1_1 = log_ret(b1_1.close, b1_1.open)
  let r1_2 = log_ret(b1_2.close, b1_2.open)
  let r1_3 = log_ret(b1_3.close, b1_3.open)

  let r2_1 = log_ret(b2_1.close, b2_1.open)
  let r2_2 = log_ret(b2_2.close, b2_2.open)
  let r2_3 = log_ret(b2_3.close, b2_3.open)

  let r3_1 = log_ret(b3_1.close, b3_1.open)
  let r3_2 = log_ret(b3_2.close, b3_2.open)
  let r3_3 = log_ret(b3_3.close, b3_3.open)

  // Basket averages
  let ret_b1 = (r1_1 + r1_2 + r1_3) / 3.0
  let ret_b2 = (r2_1 + r2_2 + r2_3) / 3.0
  let ret_b3 = (r3_1 + r3_2 + r3_3) / 3.0

  r_btc.push(ret_btc)

  r_b1_1.push(r1_1)
  r_b1_2.push(r1_2)
  r_b1_3.push(r1_3)

  r_b2_1.push(r2_1)
  r_b2_2.push(r2_2)
  r_b2_3.push(r2_3)

  r_b3_1.push(r3_1)
  r_b3_2.push(r3_2)
  r_b3_3.push(r3_3)

  r_b1.push(ret_b1)
  r_b2.push(ret_b2)
  r_b3.push(ret_b3)

  if r_btc.len >= corrLen {
    let rho_b1_btc, beta_b1 = calc_corr_beta(r_btc, r_b1, corrLen)
    let rho_b2_btc, beta_b2 = calc_corr_beta(r_btc, r_b2, corrLen)
    let rho_b3_btc, beta_b3 = calc_corr_beta(r_btc, r_b3, corrLen)

    let rho_b1_b2, _ = calc_corr_beta(r_b1, r_b2, corrLen)
    let rho_b1_b3, _ = calc_corr_beta(r_b1, r_b3, corrLen)
    let rho_b2_b3, _ = calc_corr_beta(r_b2, r_b3, corrLen)

    let avg_corr = (rho_b1_btc + rho_b2_btc + rho_b3_btc + rho_b1_b2 + rho_b1_b3 + rho_b2_b3) / 6.0
    let avg_beta = (beta_b1 + beta_b2 + beta_b3) / 3.0

    // Sub-Pane Trajectories
    lineSync.plot(syncThreshold)
    lineZero.plot(0.00)
    lineDeco.plot(decoupleThreshold)

    if showB1VsBtc       { plotB1.plot(rho_b1_btc) }
    if showB2VsBtc       { plotB2.plot(rho_b2_btc) }
    if showB3VsBtc       { plotB3.plot(rho_b3_btc) }
    if showAvgDispersion { plotDisp.plot(avg_corr) }

    // Panel 1 - Heatmap 2D
    matrixWin.hm.set("BTC", "BTC", 1.00)
    matrixWin.hm.set("BTC", cesta1_type, rho_b1_btc)
    matrixWin.hm.set("BTC", cesta2_type, rho_b2_btc)
    matrixWin.hm.set("BTC", cesta3_type, rho_b3_btc)

    matrixWin.hm.set(cesta1_type, "BTC", rho_b1_btc)
    matrixWin.hm.set(cesta1_type, cesta1_type, 1.00)
    matrixWin.hm.set(cesta1_type, cesta2_type, rho_b1_b2)
    matrixWin.hm.set(cesta1_type, cesta3_type, rho_b1_b3)

    matrixWin.hm.set(cesta2_type, "BTC", rho_b2_btc)
    matrixWin.hm.set(cesta2_type, cesta1_type, rho_b1_b2)
    matrixWin.hm.set(cesta2_type, cesta2_type, 1.00)
    matrixWin.hm.set(cesta2_type, cesta3_type, rho_b2_b3)

    matrixWin.hm.set(cesta3_type, "BTC", rho_b3_btc)
    matrixWin.hm.set(cesta3_type, cesta1_type, rho_b1_b3)
    matrixWin.hm.set(cesta3_type, cesta2_type, rho_b2_b3)
    matrixWin.hm.set(cesta3_type, cesta3_type, 1.00)

    let col_base = color.rgb(148, 163, 184)
    let c1 = rho_color(rho_b1_btc, syncThreshold, decoupleThreshold)
    let c2 = rho_color(rho_b2_btc, syncThreshold, decoupleThreshold)
    let c3 = rho_color(rho_b3_btc, syncThreshold, decoupleThreshold)
    let c12 = rho_color(rho_b1_b2, syncThreshold, decoupleThreshold)
    let c13 = rho_color(rho_b1_b3, syncThreshold, decoupleThreshold)
    let c23 = rho_color(rho_b2_b3, syncThreshold, decoupleThreshold)
    let c_avg = rho_color(avg_corr, syncThreshold, decoupleThreshold)

    // Panel 2 - Symmetric Table Matrix
    matrixWin.matrixTbl.row("1", "BTC",
      table.cell("1.00", fg: col_base),
      table.cell(str.format("{0:+.2}", rho_b1_btc), fg: c1),
      table.cell(str.format("{0:+.2}", rho_b2_btc), fg: c2),
      table.cell(str.format("{0:+.2}", rho_b3_btc), fg: c3),
      "1.00",
      table.cell("Benchmark", fg: col_base))

    matrixWin.matrixTbl.row("2", cesta1_type,
      table.cell(str.format("{0:+.2}", rho_b1_btc), fg: c1),
      table.cell("1.00", fg: col_base),
      table.cell(str.format("{0:+.2}", rho_b1_b2), fg: c12),
      table.cell(str.format("{0:+.2}", rho_b1_b3), fg: c13),
      str.format("{0:.2}", beta_b1),
      table.cell(reg_label(rho_b1_btc, syncThreshold, decoupleThreshold), fg: c1))

    matrixWin.matrixTbl.row("3", cesta2_type,
      table.cell(str.format("{0:+.2}", rho_b2_btc), fg: c2),
      table.cell(str.format("{0:+.2}", rho_b1_b2), fg: c12),
      table.cell("1.00", fg: col_base),
      table.cell(str.format("{0:+.2}", rho_b2_b3), fg: c23),
      str.format("{0:.2}", beta_b2),
      table.cell(reg_label(rho_b2_btc, syncThreshold, decoupleThreshold), fg: c2))

    matrixWin.matrixTbl.row("4", cesta3_type,
      table.cell(str.format("{0:+.2}", rho_b3_btc), fg: c3),
      table.cell(str.format("{0:+.2}", rho_b1_b3), fg: c13),
      table.cell(str.format("{0:+.2}", rho_b2_b3), fg: c23),
      table.cell("1.00", fg: col_base),
      str.format("{0:.2}", beta_b3),
      table.cell(reg_label(rho_b3_btc, syncThreshold, decoupleThreshold), fg: c3))

    matrixWin.matrixTbl.row("5", "Avg Market",
      table.cell(str.format("{0:+.2}", avg_corr), fg: c_avg),
      table.cell(str.format("{0:+.2}", rho_b1_btc), fg: c1),
      table.cell(str.format("{0:+.2}", rho_b2_btc), fg: c2),
      table.cell(str.format("{0:+.2}", rho_b3_btc), fg: c3),
      str.format("{0:.2}", avg_beta),
      table.cell(reg_label(avg_corr, syncThreshold, decoupleThreshold), fg: c_avg))

    // Panel 3 - Individual Asset Breakdown
    let rho_b1_1, beta_b1_1 = calc_corr_beta(r_btc, r_b1_1, corrLen)
    let rho_b1_2, beta_b1_2 = calc_corr_beta(r_btc, r_b1_2, corrLen)
    let rho_b1_3, beta_b1_3 = calc_corr_beta(r_btc, r_b1_3, corrLen)

    let rho_b2_1, beta_b2_1 = calc_corr_beta(r_btc, r_b2_1, corrLen)
    let rho_b2_2, beta_b2_2 = calc_corr_beta(r_btc, r_b2_2, corrLen)
    let rho_b2_3, beta_b2_3 = calc_corr_beta(r_btc, r_b2_3, corrLen)

    let rho_b3_1, beta_b3_1 = calc_corr_beta(r_btc, r_b3_1, corrLen)
    let rho_b3_2, beta_b3_2 = calc_corr_beta(r_btc, r_b3_2, corrLen)
    let rho_b3_3, beta_b3_3 = calc_corr_beta(r_btc, r_b3_3, corrLen)

    // Cesta 1
    let c1_1 = rho_color(rho_b1_1, syncThreshold, decoupleThreshold)
    let p1_1 = pct_ret(b1_1.close, b1_1.open)
    matrixWin.tokenTbl.row("01", lbl_b1_1, cesta1_type, table.cell(str.format("{0:+.2}", rho_b1_1), fg: c1_1), str.format("{0:.2}", beta_b1_1), table.cell(str.format("{0:+.2}%", p1_1), fg: ret_color(p1_1)), table.cell(reg_label(rho_b1_1, syncThreshold, decoupleThreshold), fg: c1_1))

    let c1_2 = rho_color(rho_b1_2, syncThreshold, decoupleThreshold)
    let p1_2 = pct_ret(b1_2.close, b1_2.open)
    matrixWin.tokenTbl.row("02", lbl_b1_2, cesta1_type, table.cell(str.format("{0:+.2}", rho_b1_2), fg: c1_2), str.format("{0:.2}", beta_b1_2), table.cell(str.format("{0:+.2}%", p1_2), fg: ret_color(p1_2)), table.cell(reg_label(rho_b1_2, syncThreshold, decoupleThreshold), fg: c1_2))

    let c1_3 = rho_color(rho_b1_3, syncThreshold, decoupleThreshold)
    let p1_3 = pct_ret(b1_3.close, b1_3.open)
    matrixWin.tokenTbl.row("03", lbl_b1_3, cesta1_type, table.cell(str.format("{0:+.2}", rho_b1_3), fg: c1_3), str.format("{0:.2}", beta_b1_3), table.cell(str.format("{0:+.2}%", p1_3), fg: ret_color(p1_3)), table.cell(reg_label(rho_b1_3, syncThreshold, decoupleThreshold), fg: c1_3))

    // Cesta 2
    let c2_1 = rho_color(rho_b2_1, syncThreshold, decoupleThreshold)
    let p2_1 = pct_ret(b2_1.close, b2_1.open)
    matrixWin.tokenTbl.row("04", lbl_b2_1, cesta2_type, table.cell(str.format("{0:+.2}", rho_b2_1), fg: c2_1), str.format("{0:.2}", beta_b2_1), table.cell(str.format("{0:+.2}%", p2_1), fg: ret_color(p2_1)), table.cell(reg_label(rho_b2_1, syncThreshold, decoupleThreshold), fg: c2_1))

    let c2_2 = rho_color(rho_b2_2, syncThreshold, decoupleThreshold)
    let p2_2 = pct_ret(b2_2.close, b2_2.open)
    matrixWin.tokenTbl.row("05", lbl_b2_2, cesta2_type, table.cell(str.format("{0:+.2}", rho_b2_2), fg: c2_2), str.format("{0:.2}", beta_b2_2), table.cell(str.format("{0:+.2}%", p2_2), fg: ret_color(p2_2)), table.cell(reg_label(rho_b2_2, syncThreshold, decoupleThreshold), fg: c2_2))

    let c2_3 = rho_color(rho_b2_3, syncThreshold, decoupleThreshold)
    let p2_3 = pct_ret(b2_3.close, b2_3.open)
    matrixWin.tokenTbl.row("06", lbl_b2_3, cesta2_type, table.cell(str.format("{0:+.2}", rho_b2_3), fg: c2_3), str.format("{0:.2}", beta_b2_3), table.cell(str.format("{0:+.2}%", p2_3), fg: ret_color(p2_3)), table.cell(reg_label(rho_b2_3, syncThreshold, decoupleThreshold), fg: c2_3))

    // Cesta 3
    let c3_1 = rho_color(rho_b3_1, syncThreshold, decoupleThreshold)
    let p3_1 = pct_ret(b3_1.close, b3_1.open)
    matrixWin.tokenTbl.row("07", lbl_b3_1, cesta3_type, table.cell(str.format("{0:+.2}", rho_b3_1), fg: c3_1), str.format("{0:.2}", beta_b3_1), table.cell(str.format("{0:+.2}%", p3_1), fg: ret_color(p3_1)), table.cell(reg_label(rho_b3_1, syncThreshold, decoupleThreshold), fg: c3_1))

    let c3_2 = rho_color(rho_b3_2, syncThreshold, decoupleThreshold)
    let p3_2 = pct_ret(b3_2.close, b3_2.open)
    matrixWin.tokenTbl.row("08", lbl_b3_2, cesta3_type, table.cell(str.format("{0:+.2}", rho_b3_2), fg: c3_2), str.format("{0:.2}", beta_b3_2), table.cell(str.format("{0:+.2}%", p3_2), fg: ret_color(p3_2)), table.cell(reg_label(rho_b3_2, syncThreshold, decoupleThreshold), fg: c3_2))

    let c3_3 = rho_color(rho_b3_3, syncThreshold, decoupleThreshold)
    let p3_3 = pct_ret(b3_3.close, b3_3.open)
    matrixWin.tokenTbl.row("09", lbl_b3_3, cesta3_type, table.cell(str.format("{0:+.2}", rho_b3_3), fg: c3_3), str.format("{0:.2}", beta_b3_3), table.cell(str.format("{0:+.2}%", p3_3), fg: ret_color(p3_3)), table.cell(reg_label(rho_b3_3, syncThreshold, decoupleThreshold), fg: c3_3))
  }
}
