script "Quant Basket Correlation & Rotation Engine"

// ============================================================================
// INDICATOR: Quant Basket Correlation & Rotation Engine [SCRIPT 11 - v3.2]
// SUITE:     MMT Quantitative Indicator Suite
// ENGINE:    MMT Scripting v3
//
// UNIVERSE vs ACTIVE FEEDS
// - The catalog below holds 20 narrative baskets x 5 Binance USDT-M perps
//   (100 symbols, every one verified with markets.hasSymbol on MMT binancef). Only the 5 selected slots are subscribed: 25 assets plus
//   the BTC and ETH factors = 27 feeds (26 when ETH is also a basket member),
//   under the 30-subscription budget. Unselected baskets cost nothing.
//
// MODEL
// - Returns: close-to-close log returns, accepted only when the asset bar is
//   time-aligned with the BTC bar (missing/late bars are null, never 0).
// - Robustness: returns winsorized at k * EWMA sigma (lambda 0.94, prior bar).
// - Baskets: equal or inverse-volatility weights from the prior bar's sigma.
// - Moments: pairwise-complete rolling or EWMA sums for 32 series
//   (BTC, ETH, 25 assets, 5 baskets), O(N^2) per bar independent of window.
// - Residual / partial correlation vs BTC (or BTC + ETH) isolates narrative
//   rotation from the common market factor.
// - Fisher-z confidence intervals gate regime labels.
// - Absorption ratio (power iteration on the 27x27 correlation matrix),
//   cross-sectional dispersion, RRG-style rotation, lead-lag profile,
//   up/down beta, Jensen alpha, implied intra-basket correlation, and
//   Engle-Granger style spreads between baskets.
// ============================================================================

setup basketOptions = [
  "Majors", "Memes", "Political & Launchpads", "AI & Compute",
  "DePIN & Storage", "New L1s", "Alt L1s", "Legacy L1s", "Privacy & PoW",
  "L2 & Scaling", "Cosmos & Asia L1s", "DeFi Blue-Chips", "Perp DEX",
  "DEX & AMM", "Restaking & Yield", "RWA & Tokenization",
  "Payments & Wallets", "Oracles & Data", "Gaming & Metaverse",
  "Enterprise & BTCFi",
]

input (
  input.tab(title: "Baskets")
  input.group(title: "Active Slots (5 baskets x 5 assets)", collapsible: false)
  basket1 = input.select("Majors", title: "Slot 1", options: basketOptions)
  basket2 = input.select("Memes", title: "Slot 2", options: basketOptions)
  basket3 = input.select("AI & Compute", title: "Slot 3", options: basketOptions)
  basket4 = input.select("New L1s", title: "Slot 4", options: basketOptions)
  basket5 = input.select("DeFi Blue-Chips", title: "Slot 5", options: basketOptions)
  input.group(title: "Basket Construction", collapsible: true)
  weighting = input.select("Inverse Vol", title: "Weighting", options: ["Inverse Vol", "Equal"])
  winsorK = input.float(4.0, title: "Winsorize at k x sigma (0 = off)", min: 0.0, max: 10.0)

  input.tab(title: "Model")
  input.group(title: "Estimation", collapsible: false)
  estimator = input.select("Rolling", title: "Estimator", options: ["Rolling", "EWMA"])
  corrLen = input.int(72, title: "Window (bars)", min: 20, max: 300)
  halfLife = input.int(36, title: "EWMA half-life (bars)", min: 5, max: 300)
  fastLen = input.int(18, title: "Fast window for breakdowns (bars)", min: 6, max: 100)
  factorModel = input.select("BTC", title: "Residual factor model", options: ["BTC", "BTC + ETH"])
  confLevel = input.select("95%", title: "Confidence level", options: ["90%", "95%", "99%"])
  input.group(title: "Systemic Risk", collapsible: true)
  eigenK = input.int(1, title: "Absorption eigenvectors", min: 1, max: 5)
  histLen = input.int(500, title: "Percentile lookback (bars)", min: 50, max: 1000)
  input.group(title: "Rotation & Lead-Lag", collapsible: true)
  momLag = input.int(5, title: "RS-Momentum lag (bars)", min: 1, max: 30)
  trailLen = input.int(6, title: "RRG trail length", min: 1, max: 10)
  maxLag = input.int(4, title: "Lead-lag max lag (bars)", min: 1, max: 8)
  input.group(title: "Pairs", collapsible: true)
  spreadLen = input.int(150, title: "Spread window (bars)", min: 30, max: 300)
  pairA = input.select("Slot 1", title: "Plotted pair: leg A", options: ["Slot 1", "Slot 2", "Slot 3", "Slot 4", "Slot 5"])
  pairB = input.select("Slot 2", title: "Plotted pair: leg B", options: ["Slot 1", "Slot 2", "Slot 3", "Slot 4", "Slot 5"])

  input.tab(title: "Signals")
  input.group(title: "Regimes", collapsible: false)
  syncThreshold = input.float(0.70, title: "Coupled threshold (rho)", min: 0.40, max: 0.95)
  decoupleThreshold = input.float(0.35, title: "Decoupled threshold (rho)", min: 0.0, max: 0.60)
  breakThreshold = input.float(0.30, title: "Breakdown: fast - slow rho", min: 0.05, max: 1.0)
  spreadEntry = input.float(2.0, title: "Spread |z| signal", min: 1.0, max: 4.0)
  adfCritical = input.float(-3.34, title: "ADF critical t (EG 5% = -3.34)", min: -5.0, max: -1.5)

  input.tab(title: "Display")
  input.group(title: "Chart Panes", collapsible: false)
  showCorrPane = input.bool(true, title: "Basket rho vs BTC")
  showAvgCorr = input.bool(true, title: "Average pairwise rho")
  showRotationPane = input.bool(true, title: "RS-Ratio rotation lines")
)

// ----------------------------------------------------------------------------
// CATALOG (20 baskets x 5 symbols, all present in MMT binancef metadata)
// ----------------------------------------------------------------------------
setup (
  catalog = {
    "Majors": ["ETH", "SOL", "XRP", "BNB", "ADA"],
    "Memes": ["DOGE", "1000PEPE", "WIF", "1000BONK", "PENGU"],
    "Political & Launchpads": ["TRUMP", "WLFI", "PUMP", "SPX", "M"],
    "AI & Compute": ["TAO", "FET", "RENDER", "WLD", "VIRTUAL"],
    "DePIN & Storage": ["FIL", "AR", "THETA", "ATH", "2Z"],
    "New L1s": ["SUI", "APT", "SEI", "S", "XPL"],
    "Alt L1s": ["AVAX", "NEAR", "DOT", "ICP", "HBAR"],
    "Legacy L1s": ["LTC", "BCH", "ETC", "BSV", "NEO"],
    "Privacy & PoW": ["ZEC", "XMR", "DASH", "ZEN", "KAS"],
    "L2 & Scaling": ["ARB", "OP", "STRK", "POL", "ZK"],
    "Cosmos & Asia L1s": ["ATOM", "TIA", "INJ", "CFX", "KAIA"],
    "DeFi Blue-Chips": ["UNI", "AAVE", "CRV", "LDO", "MORPHO"],
    "Perp DEX": ["HYPE", "ASTER", "MYX", "LIT", "JUP"],
    "DEX & AMM": ["CAKE", "AERO", "DEXE", "SUN", "JST"],
    "Restaking & Yield": ["ENA", "PENDLE", "ETHFI", "EIGEN", "SKY"],
    "RWA & Tokenization": ["ONDO", "SYRUP", "PAXG", "QNT", "IOTA"],
    "Payments & Wallets": ["XLM", "TRX", "TWT", "BAT", "A"],
    "Oracles & Data": ["LINK", "PYTH", "GRT", "ENS", "JASMY"],
    "Gaming & Metaverse": ["SAND", "GALA", "MANA", "IMX", "FLOW"],
    "Enterprise & BTCFi": ["ALGO", "VET", "XTZ", "STX", "MERL"],
  }
  fallbackBasket = ["ETH", "SOL", "XRP", "BNB", "ADA"]
  slotNames = [basket1, basket2, basket3, basket4, basket5]
  slotIdx = [0, 1, 2, 3, 4]
  assetIdx = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24]
  slotOf = [0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4]
  posOf = [0, 1, 2, 3, 4, 0, 1, 2, 3, 4, 0, 1, 2, 3, 4, 0, 1, 2, 3, 4, 0, 1, 2, 3, 4]
  assetLabels = for i in assetIdx { (catalog.get(slotNames[slotOf[i] ?? 0] ?? "Majors") ?? fallbackBasket)[posOf[i] ?? 0] ?? "ETH" }
  slotLabels = for b in slotIdx { str.concat(b + 1, " · ", slotNames[b] ?? "") }
  shortNames = {
    "Majors": "Majors",
    "Memes": "Memes",
    "Political & Launchpads": "Political",
    "AI & Compute": "AI",
    "DePIN & Storage": "DePIN",
    "New L1s": "New L1",
    "Alt L1s": "Alt L1",
    "Legacy L1s": "Legacy",
    "Privacy & PoW": "Privacy",
    "L2 & Scaling": "L2",
    "Cosmos & Asia L1s": "Cosmos",
    "DeFi Blue-Chips": "DeFi",
    "Perp DEX": "Perps",
    "DEX & AMM": "DEX",
    "Restaking & Yield": "Yield",
    "RWA & Tokenization": "RWA",
    "Payments & Wallets": "Payments",
    "Oracles & Data": "Oracles",
    "Gaming & Metaverse": "Gaming",
    "Enterprise & BTCFi": "Enterprise",
  }
  // Compact axis keys: heatmap and bar axes overlap with the long names.
  slotShort = for b in slotIdx { str.concat(b + 1, " ", shortNames.get(slotNames[b] ?? "") ?? (slotNames[b] ?? "")) }
  universeIdx = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26]
  universeKeys = for u in universeIdx { u == 0 ? "BTC" : (u == 1 ? "ETH" : ((assetLabels.get(u - 2) ?? "") == "ETH" ? "ETH (basket)" : (assetLabels.get(u - 2) ?? ""))) }
  slotColors = [color.rgb(59, 130, 246), color.rgb(236, 72, 153), color.rgb(16, 185, 129), color.rgb(245, 158, 11), color.rgb(167, 139, 250)]
  rhoScale = color.scale(at: [0.0, 0.5, 1.0], colors: [color.rgb(239, 68, 68), color.rgb(234, 179, 8), color.rgb(34, 197, 94)])

  // Series layout of the return ring and moment matrices.
  NS = 32
  NU = 27
  IA = 2
  IB = 27
  CAP = 320
  HCAP = 1000
  EPS = 0.00000000000001
  WIN_LAMBDA = 0.94
)

// ----------------------------------------------------------------------------
// DATA (27 feeds max: BTC, ETH factor, 5 x 5 basket assets)
// ----------------------------------------------------------------------------
data (
  btc = subscribe(data.ohlcv, exchange: "binancef", symbol: "btc/usd")
  eth = subscribe(data.ohlcv, exchange: "binancef", symbol: "eth/usd")
)
setup feeds = for i in assetIdx { subscribe(data.ohlcv, exchange: "binancef", symbol: str.concat(str.lower(assetLabels.get(i) ?? "ETH"), "/usd")) }

// ----------------------------------------------------------------------------
// SURFACES
// ----------------------------------------------------------------------------
window matrixWin = window(title: "Correlation & Rotation") {
  rawHm: heatmap.new(title: "Return correlation (BTC, ETH, baskets)", x: axis.category, y: axis.category, capacity: 49, palette: [color.rgb(220, 38, 38), color.rgb(51, 65, 85), color.rgb(34, 197, 94)]),
  residHm: heatmap.new(title: "Residual correlation (factor-neutral rotation)", x: axis.category, y: axis.category, capacity: 25, min: -1.0, max: 1.0, palette: [color.rgb(220, 38, 38), color.rgb(51, 65, 85), color.rgb(34, 197, 94)]),
  basketTbl: table.new([
    table.col(title: "Slot", width: 0.5),
    table.col(title: "Basket", width: 1.6),
    table.col(title: "rho BTC", align: align.right, width: 0.8),
    table.col(title: "CI", align: align.center, width: 1.2),
    table.col(title: "rho pctl", align: align.right, width: 0.8),
    table.col(title: "beta", align: align.right, width: 0.7),
    table.col(title: "beta up", align: align.right, width: 0.8),
    table.col(title: "beta dn", align: align.right, width: 0.8),
    table.col(title: "alpha %", align: align.right, width: 0.8),
    table.col(title: "intra rho", align: align.right, width: 0.8),
    table.col(title: "resid rho", align: align.right, width: 0.8),
    table.col(title: "Lead/Lag", align: align.center, width: 1.1),
    table.col(title: "RRG", align: align.center, width: 1.0),
    table.col(title: "d rho fast", align: align.right, width: 0.8),
    table.col(title: "Regime", align: align.center, width: 1.2),
  ], title: "Basket screener", capacity: 6),
  rotationMap: chart.panel(axis: axis.index, title: "Rotation map  x: RS-Ratio z x100  y: RS-Momentum z"),
  alphaByBasket: chart.panel(axis: axis.category, title: "Jensen alpha over window (%)"),
  leadLagProfile: chart.panel(axis: axis.index, title: "Lead-lag profile rho(basket_t, BTC_t-k)  k>0: BTC leads"),
}



window riskWin = window(title: "Assets, Risk & Pairs") {
  assetTbl: table.new([
    table.col(title: "Asset", width: 0.9),
    table.col(title: "Basket", width: 1.4),
    table.col(title: "Weight %", align: align.right, width: 0.8),
    table.col(title: "rho BTC", align: align.right, width: 0.8),
    table.col(title: "beta BTC", align: align.right, width: 0.8),
    table.col(title: "rho basket", align: align.right, width: 0.8),
    table.col(title: "Idio var %", align: align.right, width: 0.8),
    table.col(title: "Ret %", align: align.right, width: 0.8),
    table.col(title: "alpha %", align: align.right, width: 0.8),
    table.col(title: "Rel z", align: align.right, width: 0.7),
    table.col(title: "Sync %", align: align.right, width: 0.7),
    table.col(title: "Regime", align: align.center, width: 1.1),
  ], title: "Constituents", capacity: 30),
  assetHm: heatmap.new(title: "Full correlation matrix (27 x 27)", x: axis.category, y: axis.category, capacity: 729, palette: [color.rgb(220, 38, 38), color.rgb(51, 65, 85), color.rgb(34, 197, 94)]),
  rhoByAsset: chart.panel(axis: axis.category, title: "BTC beta-driven vs narrative-driven (rho)"),
  systemicRisk: chart.panel(sub: btc, title: "Absorption ratio & average correlation"),
  pairsTbl: table.new([
    table.col(title: "Pair", width: 2.2),
    table.col(title: "rho", align: align.right, width: 0.7),
    table.col(title: "resid rho", align: align.right, width: 0.8),
    table.col(title: "Hedge", align: align.right, width: 0.7),
    table.col(title: "Spread z", align: align.right, width: 0.8),
    table.col(title: "Half-life", align: align.right, width: 0.8),
    table.col(title: "ADF t", align: align.right, width: 0.7),
    table.col(title: "Signal", align: align.center, width: 1.8),
  ], title: "Basket pairs (Engle-Granger on log index levels)", capacity: 12),
}

pane corrPane = pane(title: "Basket rho vs BTC", height: 0.3)
pane rotPane = pane(title: "RS-Ratio z (rotation vs BTC)", height: 0.25)
pane dispPane = pane(title: "Cross-sectional dispersion z", height: 0.4, on: riskWin.systemicRisk)
pane spreadPane = pane(title: "Pair spread z", height: 0.4, on: riskWin.systemicRisk)

plot (
  syncLine = plot.line(title: "Coupled", color: color.rgb(100, 116, 139), width: 1.0, style: linestyle.dashed, on: corrPane)
  decoLine = plot.line(title: "Decoupled", color: color.rgb(100, 116, 139), width: 1.0, style: linestyle.dashed, on: corrPane)
  avgCorrLine = plot.line(title: "Avg pairwise rho", color: color.rgb(226, 232, 240), width: 2.2, on: corrPane)
  rotZero = plot.line(title: "Zero", color: color.rgb(71, 85, 105), width: 1.0, style: linestyle.dotted, on: rotPane)
  arLine = plot.line(title: "Absorption ratio", color: color.rgb(245, 158, 11), width: 2.0, on: riskWin.systemicRisk)
  avgCorrRisk = plot.line(title: "Avg pairwise rho (system)", color: color.rgb(148, 163, 184), width: 1.2, on: riskWin.systemicRisk)
  stressBg = plot.bg(title: "Absorption stress (z > 1.28)", on: riskWin.systemicRisk)
  dispHist = plot.histogram(title: "Dispersion z", on: dispPane)
  spreadZ = plot.line(title: "Spread z", color: color.rgb(56, 189, 248), width: 1.8, on: spreadPane)
  spreadUp = plot.line(title: "+entry", color: color.rgb(100, 116, 139), width: 1.0, style: linestyle.dashed, on: spreadPane)
  spreadDn = plot.line(title: "-entry", color: color.rgb(100, 116, 139), width: 1.0, style: linestyle.dashed, on: spreadPane)
  rrgZeroLine = plot.line(title: "Momentum zero", color: color.rgb(71, 85, 105), width: 1.0, style: linestyle.dotted, on: matrixWin.rotationMap)
  alphaBars = plot.histogram(title: "alpha %", horizontal: true, on: matrixWin.alphaByBasket)
  rhoBtcBars = plot.histogram(title: "rho BTC", horizontal: true, color: color.rgb(245, 158, 11), on: riskWin.rhoByAsset)
  rhoBasketBars = plot.histogram(title: "rho basket", horizontal: true, color: color.rgb(59, 130, 246), on: riskWin.rhoByAsset)
)

setup (
  corrLines = for b in slotIdx { plot.line(title: slotLabels.get(b) ?? "", color: slotColors[b] ?? color.gray, width: 1.5, on: corrPane) }
  rotLines = for b in slotIdx { plot.line(title: slotLabels.get(b) ?? "", color: slotColors[b] ?? color.gray, width: 1.5, on: rotPane) }
  rrgPoints = for b in slotIdx { plot.point(title: slotLabels.get(b) ?? "", color: slotColors[b] ?? color.gray, size: 8.0, capacity: 64, on: matrixWin.rotationMap) }
  lagBars = for b in slotIdx { plot.histogram(title: slotLabels.get(b) ?? "", color: slotColors[b] ?? color.gray, capacity: 32, on: matrixWin.leadLagProfile) }
)

type BreakdownEvent {
  basket: string
  fastRho: float
  slowRho: float
}

type SpreadEvent {
  pair: string
  z: float
  adf: float
}

alert breakdownAlert = alert(title: "Basket correlation breakdown", description: "Fast rho vs BTC diverged from the slow estimate by more than the breakdown threshold.", payload: BreakdownEvent, onClose: true)
alert systemicAlert = alert(title: "Systemic coupling", description: "Absorption ratio z-score crossed above 1.28 (about its 90th percentile).", onClose: true)
alert spreadAlert = alert(title: "Basket spread stretched", description: "The plotted basket pair spread crossed the |z| entry with cointegration support.", payload: SpreadEvent, onClose: true)

// ----------------------------------------------------------------------------
// STATE
// ----------------------------------------------------------------------------
state (
  ret: float[] = float[](10240)
  lvl: float[] = float[](1920)
  rsr: float[] = float[](1600)
  rsm: float[] = float[](1600)
  accN: float[] = float[](1024)
  accS1: float[] = float[](1024)
  accS2: float[] = float[](1024)
  accP: float[] = float[](1024)
  accQ: float[] = float[](1024)
  rawR: float[] = float[](27)
  varE: float[] = float[](32)
  varCnt: float[] = float[](32)
  weights: float[] = float[](25)
  cum: float[] = float[](6)
  syncHits: float[] = float[](25)
  corrM: float[] = float[](729)
  eigV: float[] = float[](135)
  eigL: float[] = float[](5)
  eigTmp: float[] = float[](27)
  rhoHist: float[] = float[](6000)
  arHist: float[] = float[](1000)
  prevGap: float[] = float[](5)
  drawnKeys: float[] = float[](50)
  head: int = 319
  bars: int = 0
  hHead: int = 999
  hCount: int = 0
  prevArZ: float = 0.0
  arTick: int = 0
  dashTick: int = 0
  lastAbsorption: float? = null
  lastAvgRho: float? = null
  arMu: float = 0.0
  arVar: float = 0.0
  arN: float = 0.0
  dispMu: float = 0.0
  dispVar: float = 0.0
  dispN: float = 0.0
  prevSpreadZ: float = 0.0
  prevZeroKeys: float[] = float[](2)
)

// ----------------------------------------------------------------------------
// NUMERICAL ENGINE
// ----------------------------------------------------------------------------
fn wrapRow(r: int, cap: int) -> int {
  if r < 0 {
    return r + cap
  }
  if r >= cap {
    return r - cap
  }
  return r
}

fn atanh(x: float) -> float {
  let c = math.clamp(x, -0.999999, 0.999999)
  return 0.5 * (math.log((1.0 + c) / (1.0 - c)) ?? 0.0)
}

fn fisherBand(rho: float, n: float, z: float) -> (float, float) {
  if n <= 4.0 {
    return -1.0, 1.0
  }
  let f = atanh(rho)
  let se = 1.0 / (math.sqrt(n - 3.0) ?? 1.0)
  return math.tanh(f - z * se), math.tanh(f + z * se)
}

fn partialCorr(rij: float, rik: float, rjk: float) -> float {
  let den = math.sqrt(math.max((1.0 - rik * rik) * (1.0 - rjk * rjk), 0.0)) ?? 0.0
  if den < 0.000001 {
    return 0.0
  }
  return math.clamp((rij - rik * rjk) / den, -1.0, 1.0)
}

fn impliedCorr(basketVar: float, sumW2Var: float, sumWSigma: float) -> float? {
  let den = sumWSigma * sumWSigma - sumW2Var
  if den <= 0.0 {
    let none: float? = null
    return none
  }
  return math.clamp((basketVar - sumW2Var) / den, -1.0, 1.0)
}

fn halfLifeOf(slope: float) -> float? {
  if slope >= 0.0 || slope <= -1.0 {
    let none: float? = null
    return none
  }
  return -0.6931471805599453 / (math.log(1.0 + slope) ?? -1.0)
}

fn pctRank(xs: float[], cap: int, newest: int, count: int, len: int, x: float) -> float {
  let n = math.min(count, len)
  let below = 0.0
  let seen = 0.0
  for back in 0..n {
    let v = xs.get(wrapRow(newest - back, cap))
    if v != null {
      seen += 1.0
      if v < x {
        below += 1.0
      }
    }
  }
  return seen > 0.0 ? below / seen * 100.0 : 50.0
}

fn pctRankStrided(xs: float[], stride: int, off: int, cap: int, newest: int, count: int, len: int, x: float) -> float {
  let n = math.min(count, len)
  let below = 0.0
  let seen = 0.0
  for back in 0..n {
    let v = xs.get(wrapRow(newest - back, cap) * stride + off)
    if v != null {
      seen += 1.0
      if v < x {
        below += 1.0
      }
    }
  }
  return seen > 0.0 ? below / seen * 100.0 : 50.0
}

// Pairwise-complete moment sums. lam = 1 with an eviction row is a rolling
// window; lam < 1 without eviction is EWMA (accQ tracks sum of squared weights).
fn updateMoments(xs: float[], ns: int, row: int, evict: int, lam: float, nN: float[], s1: float[], s2: float[], sp: float[], sq: float[]) {
  let base = row * ns
  let old = evict * ns
  let lam2 = lam * lam
  for i in 0..ns {
    let xi = xs.get(base + i)
    let oi = evict >= 0 ? xs.get(old + i) : null
    for j in i..ns {
      let k = i * ns + j
      let m = j * ns + i
      let xj = xs.get(base + j)
      let oj = evict >= 0 ? xs.get(old + j) : null
      let n = (nN.get(k) ?? 0.0) * lam
      let q = (sq.get(k) ?? 0.0) * lam2
      let ai = (s1.get(k) ?? 0.0) * lam
      let aj = (s1.get(m) ?? 0.0) * lam
      let bi = (s2.get(k) ?? 0.0) * lam
      let bj = (s2.get(m) ?? 0.0) * lam
      let p = (sp.get(k) ?? 0.0) * lam
      if xi != null && xj != null {
        n += 1.0
        q += 1.0
        ai += xi
        aj += xj
        bi += xi * xi
        bj += xj * xj
        p += xi * xj
      }
      if oi != null && oj != null {
        n -= 1.0
        q -= 1.0
        ai -= oi
        aj -= oj
        bi -= oi * oi
        bj -= oj * oj
        p -= oi * oj
      }
      nN.set(k, n)
      sq.set(k, q)
      s1.set(k, ai)
      s1.set(m, aj)
      s2.set(k, bi)
      s2.set(m, bj)
      sp.set(k, p)
    }
  }
}

// rho(i, j), beta of j on i, effective sample size, mean i, mean j.
fn pairStats(nN: float[], s1: float[], s2: float[], sp: float[], sq: float[], ns: int, i: int, j: int, ewma: bool) -> (float?, float?, float, float, float) {
  let a = math.min(i, j)
  let c = math.max(i, j)
  let k = a * ns + c
  let n = nN.get(k) ?? 0.0
  if n < 3.0 {
    let none: float? = null
    return none, none, 0.0, 0.0, 0.0
  }
  let ki = i * ns + j
  let kj = j * ns + i
  let mi = (s1.get(ki) ?? 0.0) / n
  let mj = (s1.get(kj) ?? 0.0) / n
  let vi = math.max((s2.get(ki) ?? 0.0) / n - mi * mi, 0.0)
  let vj = math.max((s2.get(kj) ?? 0.0) / n - mj * mj, 0.0)
  let cv = (sp.get(k) ?? 0.0) / n - mi * mj
  let q = sq.get(k) ?? 0.0
  let nEff = ewma ? (q > 0.0 ? n * n / q : 0.0) : n
  let den = math.sqrt(vi * vj) ?? 0.0
  let rho: float? = den > 0.00000000000001 ? math.clamp(cv / den, -1.0, 1.0) : null
  let beta: float? = vi > 0.00000000000001 ? cv / vi : null
  return rho, beta, nEff, mi, mj
}

fn seriesVar(nN: float[], s1: float[], s2: float[], ns: int, i: int) -> float {
  let k = i * ns + i
  let n = nN.get(k) ?? 0.0
  if n < 3.0 {
    return 0.0
  }
  let m = (s1.get(k) ?? 0.0) / n
  return math.max((s2.get(k) ?? 0.0) / n - m * m, 0.0)
}

// Pearson rho(y_t, x_t-lag) over the newest len rows of the return ring.
fn lagCorr(xs: float[], ns: int, cap: int, newest: int, avail: int, ix: int, iy: int, lag: int, len: int) -> float? {
  let n = 0.0
  let sx = 0.0
  let sy = 0.0
  let sxx = 0.0
  let syy = 0.0
  let sxy = 0.0
  for back in 0..len {
    let bx = back + lag
    if back < avail && bx >= 0 && bx < avail {
      let y = xs.get(wrapRow(newest - back, cap) * ns + iy)
      let x = xs.get(wrapRow(newest - bx, cap) * ns + ix)
      if x != null && y != null {
        n += 1.0
        sx += x
        sy += y
        sxx += x * x
        syy += y * y
        sxy += x * y
      }
    }
  }
  if n < 8.0 {
    let none: float? = null
    return none
  }
  let vx = sxx - sx * sx / n
  let vy = syy - sy * sy / n
  let den = math.sqrt(math.max(vx * vy, 0.0)) ?? 0.0
  if den <= 0.00000000000001 {
    let none: float? = null
    return none
  }
  return math.clamp((sxy - sx * sy / n) / den, -1.0, 1.0)
}

// Asymmetric betas conditional on the factor being above / below its mean.
fn condBetas(xs: float[], ns: int, cap: int, newest: int, avail: int, ix: int, iy: int, len: int) -> (float?, float?) {
  let n = math.min(len, avail)
  let total = 0.0
  let cnt = 0.0
  for back in 0..n {
    let r = wrapRow(newest - back, cap) * ns
    let x = xs.get(r + ix)
    let y = xs.get(r + iy)
    if x != null && y != null {
      total += x
      cnt += 1.0
    }
  }
  let none: float? = null
  if cnt < 10.0 {
    return none, none
  }
  let mx = total / cnt
  let nu = 0.0
  let sxu = 0.0
  let syu = 0.0
  let sxxu = 0.0
  let sxyu = 0.0
  let nd = 0.0
  let sxd = 0.0
  let syd = 0.0
  let sxxd = 0.0
  let sxyd = 0.0
  for back in 0..n {
    let r = wrapRow(newest - back, cap) * ns
    let x = xs.get(r + ix)
    let y = xs.get(r + iy)
    if x != null && y != null {
      if x >= mx {
        nu += 1.0
        sxu += x
        syu += y
        sxxu += x * x
        sxyu += x * y
      } else {
        nd += 1.0
        sxd += x
        syd += y
        sxxd += x * x
        sxyd += x * y
      }
    }
  }
  let vu = nu > 4.0 ? sxxu - sxu * sxu / nu : 0.0
  let vd = nd > 4.0 ? sxxd - sxd * sxd / nd : 0.0
  let bu: float? = vu > 0.00000000000001 ? (sxyu - sxu * syu / nu) / vu : null
  let bd: float? = vd > 0.00000000000001 ? (sxyd - sxd * syd / nd) / vd : null
  return bu, bd
}

// z-score of the newest value of (a - b) against the window, from a strided ring.
fn diffZ(xs: float[], stride: int, offA: int, offB: int, cap: int, newest: int, avail: int, len: int) -> float? {
  let n = math.min(len, avail)
  let cnt = 0.0
  let sm = 0.0
  let sq = 0.0
  let last: float? = null
  for back in 0..n {
    let r = wrapRow(newest - back, cap) * stride
    let a = xs.get(r + offA)
    let b = offB >= 0 ? xs.get(r + offB) : 0.0
    if a != null && b != null {
      let v = a - b
      if back == 0 {
        last = v
      }
      cnt += 1.0
      sm += v
      sq += v * v
    }
  }
  let none: float? = null
  if cnt < 10.0 || last == null {
    return none
  }
  let mu = sm / cnt
  let sd = math.sqrt(math.max(sq / cnt - mu * mu, 0.0)) ?? 0.0
  if sd <= 0.00000000000001 {
    return none
  }
  return ((last ?? mu) - mu) / sd
}

// z-score of the newest m-bar change of a strided series.
fn changeZ(xs: float[], stride: int, off: int, cap: int, newest: int, avail: int, len: int, lag: int) -> float? {
  let n = math.min(len, avail - lag)
  let cnt = 0.0
  let sm = 0.0
  let sq = 0.0
  let last: float? = null
  for back in 0..n {
    let a = xs.get(wrapRow(newest - back, cap) * stride + off)
    let b = xs.get(wrapRow(newest - back - lag, cap) * stride + off)
    if a != null && b != null {
      let v = a - b
      if back == 0 {
        last = v
      }
      cnt += 1.0
      sm += v
      sq += v * v
    }
  }
  let none: float? = null
  if cnt < 10.0 || last == null {
    return none
  }
  let mu = sm / cnt
  let sd = math.sqrt(math.max(sq / cnt - mu * mu, 0.0)) ?? 0.0
  if sd <= 0.00000000000001 {
    return none
  }
  return ((last ?? mu) - mu) / sd
}

// Engle-Granger: OLS of level A on level B, residual z, AR(1) half-life, ADF t.
fn spreadStats(xs: float[], stride: int, offA: int, offB: int, cap: int, newest: int, avail: int, len: int) -> (float?, float?, float?, float?) {
  let none: float? = null
  let n = math.min(len, avail)
  if n < 30 {
    return none, none, none, none
  }
  let cnt = 0.0
  let sa = 0.0
  let sb = 0.0
  let sbb = 0.0
  let sab = 0.0
  for back in 0..n {
    let r = wrapRow(newest - back, cap) * stride
    let a = xs.get(r + offA)
    let b = xs.get(r + offB)
    if a != null && b != null {
      cnt += 1.0
      sa += a
      sb += b
      sbb += b * b
      sab += a * b
    }
  }
  if cnt < 30.0 {
    return none, none, none, none
  }
  let vb = sbb - sb * sb / cnt
  if vb <= 0.00000000000001 {
    return none, none, none, none
  }
  let hedge = (sab - sa * sb / cnt) / vb
  let icpt = sa / cnt - hedge * sb / cnt
  let em = 0.0
  let ess = 0.0
  let ec = 0.0
  let lastE = 0.0
  let prevE: float? = null
  let m = 0.0
  let sx = 0.0
  let sy = 0.0
  let sxx = 0.0
  let syy = 0.0
  let sxy = 0.0
  for s in 0..n {
    let r = wrapRow(newest - (n - 1 - s), cap) * stride
    let a = xs.get(r + offA)
    let b = xs.get(r + offB)
    if a != null && b != null {
      let e = a - icpt - hedge * b
      ec += 1.0
      em += e
      ess += e * e
      lastE = e
      if prevE != null {
        let pe = prevE ?? 0.0
        let de = e - pe
        m += 1.0
        sx += pe
        sy += de
        sxx += pe * pe
        syy += de * de
        sxy += pe * de
      }
      prevE = e
    }
  }
  let mu = em / ec
  let sd = math.sqrt(math.max(ess / ec - mu * mu, 0.0)) ?? 0.0
  let z: float? = sd > 0.00000000000001 ? (lastE - mu) / sd : null
  if m < 20.0 {
    return z, hedge, none, none
  }
  let cxx = sxx - sx * sx / m
  let cxy = sxy - sx * sy / m
  let cyy = syy - sy * sy / m
  if cxx <= 0.00000000000001 {
    return z, hedge, none, none
  }
  let slope = cxy / cxx
  let s2 = math.max((cyy - slope * cxy) / (m - 2.0), 0.0)
  let se = math.sqrt(s2 / cxx) ?? 0.0
  let tstat: float? = se > 0.00000000000001 ? slope / se : null
  return z, hedge, halfLifeOf(slope), tstat
}

// Sum of the top-k eigenvalues of a symmetric matrix by deflated power
// iteration, warm-started from the previous bar's eigenvectors.
fn topEigenSum(mat: float[], n: int, vecs: float[], vals: float[], tmp: float[], k: int, iters: int) -> float {
  let total = 0.0
  let seed = 1.0 / (math.sqrt(float(n)) ?? 1.0)
  for e in 0..k {
    let off = e * n
    let norm0 = 0.0
    for i in 0..n {
      let v = vecs.get(off + i) ?? 0.0
      norm0 += v * v
    }
    if norm0 < 0.000001 {
      for i in 0..n {
        vecs.set(off + i, seed * (1.0 + 0.01 * float(i + e)))
      }
    }
    let lam = 0.0
    for it in 0..iters {
      for i in 0..n {
        let acc = 0.0
        for j in 0..n {
          acc += (mat.get(i * n + j) ?? 0.0) * (vecs.get(off + j) ?? 0.0)
        }
        tmp.set(i, acc)
      }
      for p in 0..e {
        let dot = 0.0
        for j in 0..n {
          dot += (vecs.get(p * n + j) ?? 0.0) * (vecs.get(off + j) ?? 0.0)
        }
        let lp = vals.get(p) ?? 0.0
        for i in 0..n {
          tmp.set(i, (tmp.get(i) ?? 0.0) - lp * dot * (vecs.get(p * n + i) ?? 0.0))
        }
      }
      let ray = 0.0
      let nrm = 0.0
      for i in 0..n {
        let t = tmp.get(i) ?? 0.0
        ray += t * (vecs.get(off + i) ?? 0.0)
        nrm += t * t
      }
      lam = ray
      let len = math.sqrt(nrm) ?? 0.0
      if len > 0.000000001 {
        for i in 0..n {
          vecs.set(off + i, (tmp.get(i) ?? 0.0) / len)
        }
      }
    }
    vals.set(e, lam)
    total += math.max(lam, 0.0)
  }
  return total
}

fn quadrantOf(x: float?, y: float?) -> string {
  if x == null || y == null {
    return "-"
  }
  let xv = x ?? 0.0
  let yv = y ?? 0.0
  if xv >= 0.0 && yv >= 0.0 {
    return "Leading"
  }
  if xv >= 0.0 {
    return "Weakening"
  }
  if yv < 0.0 {
    return "Lagging"
  }
  return "Improving"
}

fn quadrantColor(q: string) -> color {
  return match q {
    "Leading" => color.rgb(34, 197, 94)
    "Weakening" => color.rgb(234, 179, 8)
    "Lagging" => color.rgb(239, 68, 68)
    "Improving" => color.rgb(56, 189, 248)
    _ => color.rgb(100, 116, 139)
  }
}

// Regime from the confidence band, so noise alone cannot flip the label.
fn regimeOf(rho: float?, lo: float, hi: float, sync: float, deco: float) -> string {
  if rho == null {
    return "Warming up"
  }
  let r = rho ?? 0.0
  if lo >= sync {
    return "Coupled"
  }
  if hi <= deco {
    return "Decoupled"
  }
  if r >= sync {
    return "Coupled?"
  }
  if r <= deco {
    return "Decoupled?"
  }
  return "Neutral"
}

fn regimeColor(label: string) -> color {
  return match label {
    "Coupled" => color.rgb(34, 197, 94)
    "Coupled?" => color.rgb(134, 239, 172)
    "Decoupled" => color.rgb(239, 68, 68)
    "Decoupled?" => color.rgb(252, 165, 165)
    "Neutral" => color.rgb(234, 179, 8)
    _ => color.rgb(100, 116, 139)
  }
}

fn signColor(v: float?) -> color {
  if v == null {
    return color.rgb(100, 116, 139)
  }
  return (v ?? 0.0) >= 0.0 ? color.rgb(34, 197, 94) : color.rgb(239, 68, 68)
}

fn r2(v: float?) -> float? {
  if v == null {
    return v
  }
  return math.round(v ?? 0.0, 2)
}

fn slotIndexOf(name: string) -> int {
  return match name {
    "Slot 2" => 1
    "Slot 3" => 2
    "Slot 4" => 3
    "Slot 5" => 4
    _ => 0
  }
}

fn alignedReturn(close: float?, prevClose: float?, t: time?, tPrev: time?, bt: time?, btPrev: time?) -> float? {
  let none: float? = null
  if t == null || bt == null || t != bt {
    return none
  }
  if tPrev == null || btPrev == null || tPrev != btPrev {
    return none
  }
  let c = close ?? 0.0
  let p = prevClose ?? 0.0
  if c <= 0.0 || p <= 0.0 {
    return none
  }
  return math.log(c / p)
}

// ----------------------------------------------------------------------------
// EVENT LOOP
// ----------------------------------------------------------------------------
on btc.close {
  if ret.len == 0 {
    for i in 0..(NS * CAP) { ret.push(null) }
    for i in 0..(6 * CAP) { lvl.push(null) }
    for i in 0..(5 * CAP) { rsr.push(null) }
    for i in 0..(5 * CAP) { rsm.push(null) }
    for i in 0..(NS * NS) {
      accN.push(0.0)
      accS1.push(0.0)
      accS2.push(0.0)
      accP.push(0.0)
      accQ.push(0.0)
    }
    for i in 0..NU { rawR.push(null) }
    for i in 0..NS {
      varE.push(0.0)
      varCnt.push(0.0)
    }
    for i in 0..25 {
      weights.push(0.0)
      syncHits.push(0.0)
    }
    for i in 0..6 { cum.push(0.0) }
    for i in 0..(NU * NU) { corrM.push(0.0) }
    for i in 0..(5 * NU) { eigV.push(0.0) }
    for i in 0..5 {
      eigL.push(0.0)
      prevGap.push(0.0)
    }
    for i in 0..NU { eigTmp.push(0.0) }
    for i in 0..(6 * HCAP) { rhoHist.push(null) }
    for i in 0..HCAP {
      arHist.push(null)
    }
    for i in 0..50 { drawnKeys.push(null) }
    prevZeroKeys.push(null)
    prevZeroKeys.push(null)
  }

  let ewma = estimator == "EWMA"
  let lam = ewma ? (math.pow(0.5, 1.0 / float(halfLife)) ?? 0.97) : 1.0
  let zCrit = confLevel == "90%" ? 1.645 : (confLevel == "99%" ? 2.576 : 1.96)
  let twoFactor = factorModel == "BTC + ETH"

  head = wrapRow(head + 1, CAP)
  bars += 1
  let avail = math.min(bars, CAP)
  let row = head * NS

  // 1. Time-aligned raw returns (null when a feed is missing or late).
  rawR.set(0, alignedReturn(btc.close, btc.close[1], btc.time, btc.time[1], btc.time, btc.time[1]))
  rawR.set(1, alignedReturn(eth.close, eth.close[1], eth.time, eth.time[1], btc.time, btc.time[1]))
  for i, f in feeds {
    let r = alignedReturn(f.close, f.close[1], f.time, f.time[1], btc.time, btc.time[1])
    rawR.set(IA + i, r)
    if r != null {
      syncHits.set(i, (syncHits.get(i) ?? 0.0) + 1.0)
    }
  }

  // 2. Basket weights from the prior bar's sigma (no look-ahead).
  for b in 0..5 {
    let wsum = 0.0
    for a in 0..5 {
      let i = b * 5 + a
      let sig = math.sqrt(varE.get(IA + i) ?? 0.0) ?? 0.0
      let ready = (varCnt.get(IA + i) ?? 0.0) >= 20.0 && sig > 0.0
      let w = weighting == "Equal" || !ready ? 1.0 : 1.0 / sig
      let live = rawR.get(IA + i) != null
      weights.set(i, live ? w : 0.0)
      wsum += live ? w : 0.0
    }
    for a in 0..5 {
      let i = b * 5 + a
      weights.set(i, wsum > 0.0 ? (weights.get(i) ?? 0.0) / wsum : 0.0)
    }
  }

  // 3. Winsorize, update EWMA sigma, store the ring row.
  for s in 0..NU {
    let r = rawR.get(s)
    let sig = math.sqrt(varE.get(s) ?? 0.0) ?? 0.0
    let ready = (varCnt.get(s) ?? 0.0) >= 20.0 && sig > 0.0
    let lim = winsorK * sig
    let rc: float? = r != null && ready && winsorK > 0.0 ? math.clamp(r ?? 0.0, -lim, lim) : r
    if rc != null {
      let v = rc ?? 0.0
      let prior = varE.get(s) ?? 0.0
      let cnt = varCnt.get(s) ?? 0.0
      varE.set(s, cnt < 1.0 ? v * v : WIN_LAMBDA * prior + (1.0 - WIN_LAMBDA) * v * v)
      varCnt.set(s, cnt + 1.0)
    }
    ret.set(row + s, rc)
  }

  // 4. Basket returns and log index levels.
  let rb0 = ret.get(row) ?? 0.0
  cum.set(0, (cum.get(0) ?? 0.0) + rb0)
  lvl.set(head * 6, cum.get(0))
  let anyAsset = false
  for b in 0..5 {
    let acc = 0.0
    let live = false
    for a in 0..5 {
      let i = b * 5 + a
      let x = ret.get(row + IA + i)
      if x != null {
        acc += (weights.get(i) ?? 0.0) * (x ?? 0.0)
        live = true
      }
    }
    let rb: float? = live ? acc : null
    ret.set(row + IB + b, rb)
    cum.set(b + 1, (cum.get(b + 1) ?? 0.0) + (rb ?? 0.0))
    lvl.set(head * 6 + b + 1, cum.get(b + 1))
    if live {
      anyAsset = true
    }
  }

  // 5. Moments (rolling with eviction, or EWMA decay).
  let evict = !ewma && bars > corrLen ? wrapRow(head - corrLen, CAP) : -1
  updateMoments(ret, NS, head, evict, lam, accN, accS1, accS2, accP, accQ)

  let minObs = ewma ? 10.0 : math.max(10.0, float(corrLen) * 0.5)

  // 6-7. Correlation matrix of BTC, ETH and the 25 assets, average pairwise rho
  // and absorption ratio. The O(N^2) pass runs every 3rd bar while replaying
  // history (the warm-started eigenvector keeps converging across calls) and
  // on every bar live, keeping replay inside the engine's calculation budget.
  let doMatrix = !btc.isHistory || arTick == 0
  arTick = arTick >= 2 ? 0 : arTick + 1
  if doMatrix {
    let rhoSum = 0.0
    let rhoCnt = 0.0
    let validN = 0.0
    for i in 0..NU {
      let okI = (accN.get(i * NS + i) ?? 0.0) >= minObs && seriesVar(accN, accS1, accS2, NS, i) > EPS
      corrM.set(i * NU + i, okI ? 1.0 : 0.0)
      if okI {
        validN += 1.0
      }
    }
    for i in 0..NU {
      let okI = (corrM.get(i * NU + i) ?? 0.0) > 0.0
      for j in (i + 1)..NU {
        let rho, _, nEff, _, _ = pairStats(accN, accS1, accS2, accP, accQ, NS, i, j, ewma)
        let ok = okI && (corrM.get(j * NU + j) ?? 0.0) > 0.0 && rho != null && nEff >= 8.0
        let v = ok ? (rho ?? 0.0) : 0.0
        corrM.set(i * NU + j, v)
        corrM.set(j * NU + i, v)
        if ok {
          rhoSum += v
          rhoCnt += 1.0
        }
      }
    }
    lastAvgRho = rhoCnt > 0.0 ? rhoSum / rhoCnt : null

    // 7. Absorption ratio (share of variance in the top eigenvectors).
    let eigSum = validN >= 5.0 ? topEigenSum(corrM, NU, eigV, eigL, eigTmp, eigenK, 4) : 0.0
    lastAbsorption = validN >= 5.0 ? eigSum / validN : null
  }
  let avgRho = lastAvgRho
  let absorption = lastAbsorption

  // 8. Cross-sectional dispersion of asset returns.
  let cs = 0.0
  let cs2 = 0.0
  let cn = 0.0
  for i in 0..25 {
    let x = ret.get(row + IA + i)
    if x != null {
      cs += x ?? 0.0
      cs2 += (x ?? 0.0) * (x ?? 0.0)
      cn += 1.0
    }
  }
  let disp: float? = cn >= 5.0 ? (math.sqrt(math.max(cs2 / cn - (cs / cn) * (cs / cn), 0.0)) ?? 0.0) : null

  // 9. Basket rho vs BTC, percentiles and breakdowns.
  hHead = wrapRow(hHead + 1, HCAP)
  hCount = math.min(hCount + 1, HCAP)
  for b in 0..5 {
    let rho, _, nEff, _, _ = pairStats(accN, accS1, accS2, accP, accQ, NS, 0, IB + b, ewma)
    let usable: float? = rho != null && nEff >= minObs ? rho : null
    rhoHist.set(hHead * 6 + b, usable)
  }
  rhoHist.set(hHead * 6 + 5, avgRho)
  arHist.set(hHead, absorption)

  // O(1) EWMA z-scores for the per-bar stress signals; exact percentiles are
  // only computed when the dashboards render.
  let zAlpha = 2.0 / (float(histLen) + 1.0)
  let arZ: float? = null
  if absorption != null {
    let x = absorption ?? 0.0
    arZ = arN >= 30.0 && arVar > EPS ? (x - arMu) / (math.sqrt(arVar) ?? 1.0) : null
    let d = x - arMu
    arMu = arN < 1.0 ? x : arMu + zAlpha * d
    arVar = arN < 1.0 ? 0.0 : (1.0 - zAlpha) * (arVar + zAlpha * d * d)
    arN += 1.0
  }
  let dispZ: float? = null
  if disp != null {
    let x = disp ?? 0.0
    dispZ = dispN >= 30.0 && dispVar > EPS ? (x - dispMu) / (math.sqrt(dispVar) ?? 1.0) : null
    let d = x - dispMu
    dispMu = dispN < 1.0 ? x : dispMu + zAlpha * d
    dispVar = dispN < 1.0 ? 0.0 : (1.0 - zAlpha) * (dispVar + zAlpha * d * d)
    dispN += 1.0
  }
  let stressed = (arZ ?? 0.0) >= 1.2816

  // 10. RS-Ratio (relative-strength line z) and RS-Momentum per basket.
  for b in 0..5 {
    rsr.set(head * 5 + b, diffZ(lvl, 6, b + 1, 0, CAP, head, avail, corrLen))
  }
  for b in 0..5 {
    rsm.set(head * 5 + b, changeZ(rsr, 5, b, CAP, head, avail, corrLen, momLag))
  }

  // ---------------------------------------------------------------- plots
  let warm = bars > corrLen
  syncLine.plot(showCorrPane ? syncThreshold : null)
  decoLine.plot(showCorrPane ? decoupleThreshold : null)
  avgCorrLine.plot(showCorrPane && showAvgCorr && warm ? avgRho : null)
  rotZero.plot(showRotationPane ? 0.0 : null)
  for b, ln in corrLines {
    let v = rhoHist.get(hHead * 6 + b)
    ln.plot(showCorrPane && warm ? v : null)
  }
  for b, ln in rotLines {
    ln.plot(showRotationPane && warm ? rsr.get(head * 5 + b) : null)
  }
  arLine.plot(warm ? absorption : null)
  avgCorrRisk.plot(warm ? avgRho : null)
  stressBg.plot(color: warm && stressed ? color.rgb(245, 158, 11, 40) : null)
  dispHist.plot(warm ? dispZ : null, color: (dispZ ?? 0.0) >= 0.0 ? color.rgb(56, 189, 248) : color.rgb(148, 163, 184))

  let ia = slotIndexOf(pairA)
  let ib = slotIndexOf(pairB)
  let pz, _, _, padf = spreadStats(lvl, 6, ia + 1, ib + 1, CAP, head, avail, spreadLen)
  let pairOk = ia != ib
  spreadZ.plot(pairOk ? pz : null)
  spreadUp.plot(pairOk ? spreadEntry : null)
  spreadDn.plot(pairOk ? -spreadEntry : null)

  // ---------------------------------------------------------------- alerts
  if warm {
    for b in 0..5 {
      let fast = lagCorr(ret, NS, CAP, head, avail, 0, IB + b, 0, fastLen)
      let slow = rhoHist.get(hHead * 6 + b)
      let gap = fast != null && slow != null ? (fast ?? 0.0) - (slow ?? 0.0) : 0.0
      let prior = prevGap.get(b) ?? 0.0
      if gap <= -breakThreshold && prior > -breakThreshold {
        breakdownAlert.trigger(BreakdownEvent { basket: slotLabels.get(b) ?? "", fastRho: fast ?? 0.0, slowRho: slow ?? 0.0 })
      }
      prevGap.set(b, gap)
    }
    if stressed && prevArZ < 1.2816 {
      systemicAlert.trigger()
    }
    let zNow = pz ?? 0.0
    let coint = padf != null && (padf ?? 0.0) <= adfCritical
    if pairOk && coint && math.abs(zNow) >= spreadEntry && math.abs(prevSpreadZ) < spreadEntry {
      spreadAlert.trigger(SpreadEvent { pair: str.concat(slotLabels.get(ia) ?? "", " / ", slotLabels.get(ib) ?? ""), z: zNow, adf: padf ?? 0.0 })
    }
    prevSpreadZ = zNow
  }
  prevArZ = arZ ?? 0.0

  if !warm || !anyAsset {
    return
  }

  // Dashboards only describe the latest bar: refresh every 6th bar during
  // replay and on every close live.
  let doDash = !btc.isHistory || dashTick == 0
  dashTick = dashTick >= 5 ? 0 : dashTick + 1
  if !doDash {
    return
  }
  let arPct = absorption != null ? pctRank(arHist, HCAP, hHead, hCount, histLen, absorption ?? 0.0) : 50.0

  // ---------------------------------------------------------------- 7x7 basket matrix
  let keys7 = ["BTC", "ETH", slotShort.get(0) ?? "1", slotShort.get(1) ?? "2", slotShort.get(2) ?? "3", slotShort.get(3) ?? "4", slotShort.get(4) ?? "5"]
  let ser7 = [0, 1, IB, IB + 1, IB + 2, IB + 3, IB + 4]
  for i in 0..7 {
    for j in 0..7 {
      let si = ser7[i] ?? 0
      let sj = ser7[j] ?? 0
      let rho, _, _, _, _ = pairStats(accN, accS1, accS2, accP, accQ, NS, si, sj, ewma)
      let v: float? = i == j ? 1.0 : rho
      matrixWin.rawHm.set(keys7[i] ?? "", keys7[j] ?? "", r2(v))
    }
  }

  // Residual (partial) correlations between baskets, net of BTC [and ETH].
  let rBE, _, _, _, _ = pairStats(accN, accS1, accS2, accP, accQ, NS, 0, 1, ewma)
  let residAvg: float[] = float[](5)
  for b in 0..5 {
    residAvg.push(0.0)
  }
  for i in 0..5 {
    for j in 0..5 {
      if i == j {
        matrixWin.residHm.set(slotShort.get(i) ?? "", slotShort.get(j) ?? "", 1.0)
      } else {
        let rij, _, _, _, _ = pairStats(accN, accS1, accS2, accP, accQ, NS, IB + i, IB + j, ewma)
        let rib, _, _, _, _ = pairStats(accN, accS1, accS2, accP, accQ, NS, 0, IB + i, ewma)
        let rjb, _, _, _, _ = pairStats(accN, accS1, accS2, accP, accQ, NS, 0, IB + j, ewma)
        let p1 = partialCorr(rij ?? 0.0, rib ?? 0.0, rjb ?? 0.0)
        let pr = p1
        if twoFactor {
          let rie, _, _, _, _ = pairStats(accN, accS1, accS2, accP, accQ, NS, 1, IB + i, ewma)
          let rje, _, _, _, _ = pairStats(accN, accS1, accS2, accP, accQ, NS, 1, IB + j, ewma)
          let pie = partialCorr(rie ?? 0.0, rib ?? 0.0, rBE ?? 0.0)
          let pje = partialCorr(rje ?? 0.0, rjb ?? 0.0, rBE ?? 0.0)
          pr = partialCorr(p1, pie, pje)
        }
        let valid = rij != null && rib != null && rjb != null
        matrixWin.residHm.set(slotShort.get(i) ?? "", slotShort.get(j) ?? "", valid ? r2(pr) : null)
        residAvg.set(i, (residAvg.get(i) ?? 0.0) + (valid ? pr / 4.0 : 0.0))
      }
    }
  }

  // ---------------------------------------------------------------- RRG map
  let minKey = 1000000.0
  let maxKey = -1000000.0
  for b, pts in rrgPoints {
    for t in 0..10 {
      let old = drawnKeys.get(b * 10 + t)
      if old != null {
        pts.set(int(old ?? 0.0) ?? 0, null)
        drawnKeys.set(b * 10 + t, null)
      }
    }
    let steps = math.min(trailLen, avail)
    for t in 0..steps {
      let back = steps - 1 - t
      let r = wrapRow(head - back, CAP)
      let x = rsr.get(r * 5 + b)
      let y = rsm.get(r * 5 + b)
      if x != null && y != null {
        let key = math.round((x ?? 0.0) * 100.0)
        let fade = float(t + 1) / float(steps)
        pts.set(int(key) ?? 0, y, color: color.withAlpha(slotColors[b] ?? color.gray, int(60.0 + 195.0 * fade) ?? 255), size: 3.0 + 7.0 * fade)
        drawnKeys.set(b * 10 + t, key)
        minKey = math.min(minKey, key)
        maxKey = math.max(maxKey, key)
      }
    }
  }
  for t in 0..2 {
    let old = prevZeroKeys.get(t)
    if old != null {
      rrgZeroLine.set(int(old ?? 0.0) ?? 0, null)
    }
  }
  if maxKey >= minKey {
    rrgZeroLine.set(int(minKey - 25.0) ?? 0, 0.0)
    rrgZeroLine.set(int(maxKey + 25.0) ?? 0, 0.0)
    prevZeroKeys.set(0, minKey - 25.0)
    prevZeroKeys.set(1, maxKey + 25.0)
  }

  // ---------------------------------------------------------------- basket screener
  for b in 0..5 {
    let sb = IB + b
    let label = slotShort.get(b) ?? ""
    let rho, beta, nEff, mx, my = pairStats(accN, accS1, accS2, accP, accQ, NS, 0, sb, ewma)
    let lo, hi = fisherBand(rho ?? 0.0, nEff, zCrit)
    let pctl = rho != null ? pctRankStrided(rhoHist, 6, b, HCAP, hHead, hCount, histLen, rho ?? 0.0) : 50.0
    let bu, bd = condBetas(ret, NS, CAP, head, avail, 0, sb, corrLen)
    let alpha: float? = beta != null ? (my - (beta ?? 0.0) * mx) * float(corrLen) * 100.0 : null

    let sw2 = 0.0
    let sws = 0.0
    for a in 0..5 {
      let i = b * 5 + a
      let w = weights.get(i) ?? 0.0
      let v = seriesVar(accN, accS1, accS2, NS, IA + i)
      sw2 += w * w * v
      sws += w * (math.sqrt(v) ?? 0.0)
    }
    let intra = impliedCorr(seriesVar(accN, accS1, accS2, NS, sb), sw2, sws)

    let best = 0
    let bestRho = -2.0
    let rho0 = 0.0
    for kk in 0..(2 * maxLag + 1) {
      let lag = kk - maxLag
      let lr = lagCorr(ret, NS, CAP, head, avail, 0, sb, lag, corrLen)
      if lr != null {
        if lag == 0 {
          rho0 = lr ?? 0.0
        }
        if (lr ?? 0.0) > bestRho {
          bestRho = lr ?? 0.0
          best = lag
        }
      }
      for pb, hb in lagBars {
        if pb == b {
          hb.set(lag, r2(lr))
        }
      }
    }
    let leadTxt = best == 0 || bestRho - rho0 < 0.05 ? "Sync" : (best > 0 ? str.format("BTC leads {0}", best) : str.format("Leads BTC {0}", -best))

    let quad = quadrantOf(rsr.get(head * 5 + b), rsm.get(head * 5 + b))
    let fast = lagCorr(ret, NS, CAP, head, avail, 0, sb, 0, fastLen)
    let gap: float? = fast != null && rho != null ? (fast ?? 0.0) - (rho ?? 0.0) : null
    let regime = regimeOf(rho, lo, hi, syncThreshold, decoupleThreshold)
    let dup = false
    for o in 0..b {
      if (slotNames[o] ?? "") == (slotNames[b] ?? "") {
        dup = true
      }
    }

    matrixWin.basketTbl.row(str.format("{0}", b + 1),
      b + 1,
      table.cell(dup ? str.concat(slotNames[b] ?? "", " (duplicate)") : (slotNames[b] ?? ""), fg: slotColors[b] ?? color.gray),
      table.cell(r2(rho), fg: rhoScale.sample(rho ?? 0.0)),
      str.format("[{0:+.2}, {1:+.2}]", lo, hi),
      math.round(pctl, 0),
      r2(beta),
      r2(bu),
      r2(bd),
      table.cell(r2(alpha), fg: signColor(alpha)),
      table.cell(r2(intra), fg: rhoScale.sample(intra ?? 0.0)),
      table.cell(math.round(residAvg.get(b) ?? 0.0, 2), fg: rhoScale.sample(residAvg.get(b) ?? 0.0)),
      leadTxt,
      table.cell(quad, fg: quadrantColor(quad)),
      table.cell(r2(gap), fg: (gap ?? 0.0) <= -breakThreshold ? color.rgb(239, 68, 68) : color.rgb(148, 163, 184)),
      table.cell(regime, fg: regimeColor(regime)))
    alphaBars.set(label, r2(alpha), color: signColor(alpha))
  }
  let mLo, mHi = fisherBand(avgRho ?? 0.0, float(corrLen), zCrit)
  let mRegime = regimeOf(avgRho, mLo, mHi, syncThreshold, decoupleThreshold)
  matrixWin.basketTbl.row("M", "-",
    table.cell("System", fg: color.rgb(226, 232, 240)),
    table.cell(r2(avgRho), fg: rhoScale.sample(avgRho ?? 0.0)),
    str.format("AR {0:.0}%", (absorption ?? 0.0) * 100.0),
    math.round(pctRankStrided(rhoHist, 6, 5, HCAP, hHead, hCount, histLen, avgRho ?? 0.0), 0),
    "", "", "", "", "",
    "",
    str.format("Disp z {0:+.1}", dispZ ?? 0.0),
    str.format("AR pctl {0:.0}", arPct),
    "",
    table.cell(mRegime, fg: regimeColor(mRegime)))

  // ---------------------------------------------------------------- asset screener
  for b in 0..5 {
    let ms = 0.0
    let ms2 = 0.0
    let mc = 0.0
    for a in 0..5 {
      let i = b * 5 + a
      let r, beta, _, mx, my = pairStats(accN, accS1, accS2, accP, accQ, NS, 0, IA + i, ewma)
      if r != null && beta != null {
        let al = (my - (beta ?? 0.0) * mx) * float(corrLen) * 100.0
        ms += al
        ms2 += al * al
        mc += 1.0
      }
    }
    let mMean = mc > 0.0 ? ms / mc : 0.0
    let mSd = mc > 1.0 ? (math.sqrt(math.max(ms2 / mc - mMean * mMean, 0.0)) ?? 0.0) : 0.0
    for a in 0..5 {
      let i = b * 5 + a
      let s = IA + i
      let name = assetLabels.get(i) ?? ""
      let key = universeKeys.get(s) ?? name
      let rhoRaw, betaRaw, nEff, mx, my = pairStats(accN, accS1, accS2, accP, accQ, NS, 0, s, ewma)
      let enough = nEff >= minObs
      let rho: float? = enough ? rhoRaw : null
      let beta: float? = enough ? betaRaw : null
      let rhoBk, _, _, _, _ = pairStats(accN, accS1, accS2, accP, accQ, NS, IB + b, s, ewma)
      let lo, hi = fisherBand(rho ?? 0.0, nEff, zCrit)
      let alpha: float? = beta != null ? (my - (beta ?? 0.0) * mx) * float(corrLen) * 100.0 : null
      let retWin: float? = rho != null ? my * float(corrLen) * 100.0 : null
      let idio: float? = rho != null ? (1.0 - (rho ?? 0.0) * (rho ?? 0.0)) * 100.0 : null
      let relZ: float? = alpha != null && mSd > EPS ? ((alpha ?? 0.0) - mMean) / mSd : null
      let regime = regimeOf(rho, lo, hi, syncThreshold, decoupleThreshold)
      let sync = (syncHits.get(i) ?? 0.0) / float(bars) * 100.0
      riskWin.assetTbl.row(key,
        table.cell(name, fg: slotColors[b] ?? color.gray),
        slotLabels.get(b) ?? "",
        math.round((weights.get(i) ?? 0.0) * 100.0, 1),
        table.cell(r2(rho), fg: rhoScale.sample(rho ?? 0.0)),
        r2(beta),
        table.cell(r2(rhoBk), fg: rhoScale.sample(rhoBk ?? 0.0)),
        r2(idio),
        table.cell(r2(retWin), fg: signColor(retWin)),
        table.cell(r2(alpha), fg: signColor(alpha)),
        table.cell(r2(relZ), fg: signColor(relZ)),
        table.cell(math.round(sync, 0), fg: sync < 95.0 ? color.rgb(239, 68, 68) : color.rgb(148, 163, 184)),
        table.cell(regime, fg: regimeColor(regime)))
      rhoBtcBars.set(key, r2(rho))
      rhoBasketBars.set(key, r2(rhoBk))
    }
  }

  // Full 27 x 27 correlation heatmap, ordered BTC, ETH, then by slot.
  for i in 0..NU {
    let ki = universeKeys.get(i) ?? ""
    for j in 0..NU {
      let kj = universeKeys.get(j) ?? ""
      let ok = (corrM.get(i * NU + i) ?? 0.0) > 0.0 && (corrM.get(j * NU + j) ?? 0.0) > 0.0
      riskWin.assetHm.set(ki, kj, ok ? r2(corrM.get(i * NU + j)) : null)
    }
  }

  // ---------------------------------------------------------------- pairs table
  for i in 0..5 {
    for j in (i + 1)..5 {
      let key = str.format("{0}-{1}", i + 1, j + 1)
      let name = str.concat(slotLabels.get(i) ?? "", " / ", slotLabels.get(j) ?? "")
      let rij, _, _, _, _ = pairStats(accN, accS1, accS2, accP, accQ, NS, IB + i, IB + j, ewma)
      let rib, _, _, _, _ = pairStats(accN, accS1, accS2, accP, accQ, NS, 0, IB + i, ewma)
      let rjb, _, _, _, _ = pairStats(accN, accS1, accS2, accP, accQ, NS, 0, IB + j, ewma)
      let pr: float? = rij != null && rib != null && rjb != null ? partialCorr(rij ?? 0.0, rib ?? 0.0, rjb ?? 0.0) : null
      let z, hedge, hl, adf = spreadStats(lvl, 6, i + 1, j + 1, CAP, head, avail, spreadLen)
      let coint = adf != null && (adf ?? 0.0) <= adfCritical
      let zv = z ?? 0.0
      let signal = !coint ? (math.abs(zv) >= spreadEntry ? "Stretched (no coint)" : "-") :
        (zv >= spreadEntry ? str.concat("Short ", i + 1, " / Long ", j + 1) :
        (zv <= -spreadEntry ? str.concat("Long ", i + 1, " / Short ", j + 1) : "Cointegrated"))
      riskWin.pairsTbl.row(key,
        name,
        table.cell(r2(rij), fg: rhoScale.sample(rij ?? 0.0)),
        table.cell(r2(pr), fg: rhoScale.sample(pr ?? 0.0)),
        r2(hedge),
        table.cell(r2(z), fg: math.abs(zv) >= spreadEntry ? color.rgb(245, 158, 11) : color.rgb(148, 163, 184)),
        hl != null ? math.round(hl ?? 0.0, 1) : null,
        table.cell(r2(adf), fg: coint ? color.rgb(34, 197, 94) : color.rgb(148, 163, 184)),
        table.cell(signal, fg: coint && math.abs(zv) >= spreadEntry ? color.rgb(245, 158, 11) : color.rgb(148, 163, 184)))
    }
  }
}
