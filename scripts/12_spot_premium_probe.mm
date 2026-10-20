script "Spot Premium Probe · Binance vs Coinbase"

// ============================================================================
// INDICATOR: Spot Premium Probe [SCRIPT 12 - v3 research]
// SUITE:     MMT Quantitative Indicator Suite
// ENGINE:    MMT Scripting v3
//
// QUESTION
// - Does the spot price gap of a basket between two venues (default Binance
//   spot vs Coinbase spot) carry information, or is it just quote noise?
//
// METHOD
// - Premium per asset (bps) = (close B / close A - 1) * 10000, only on bars
//   where both venues printed the same timestamp as the BTC bar.
// - Coinbase quotes USD, Binance USDT: every asset premium contains the same
//   USDT/USD basis. Subtracting the BTC premium removes it, leaving the
//   basket's EXCESS premium (venue-specific demand for the narrative).
// - Excess premium z-score over a rolling window.
// - Test: information coefficient = rolling corr(z[t-H], basket-minus-BTC
//   log return from t-H to t). |IC| persistently above ~0.05 with a stable
//   sign is the minimum bar before adding it to Script 11.
// - The availability table shows which symbols each venue lists, since
//   Coinbase carries far fewer alts than Binance.
// ============================================================================

setup basketOptions = ["Majors", "Memes", "DeFi", "AI", "L1s"]

input (
  input.tab(title: "Probe")
  input.group(title: "Venues", collapsible: false)
  exA = input.exchange("binance", title: "Venue A (reference)")
  quoteA = input.select("usd", title: "Venue A quote", options: ["usd", "usdt", "usdc"], sameLine: true)
  exB = input.exchange("coinbase", title: "Venue B (premium side)")
  quoteB = input.select("usd", title: "Venue B quote", options: ["usd", "usdt", "usdc"], sameLine: true)
  basket = input.select("Majors", title: "Basket", options: basketOptions)
  input.group(title: "Test", collapsible: false)
  zLen = input.int(240, title: "Premium z window (bars)", min: 30, max: 2000)
  horizon = input.int(12, title: "Forward horizon H (bars)", min: 1, max: 200)
  icLen = input.int(500, title: "IC window (bars)", min: 50, max: 2000)
)

setup (
  catalog = {
    "Majors": ["ETH", "SOL", "XRP", "ADA", "LINK"],
    "Memes": ["DOGE", "SHIB", "PEPE", "BONK", "WIF"],
    "DeFi": ["UNI", "AAVE", "CRV", "LDO", "COMP"],
    "AI": ["FET", "RENDER", "TAO", "NEAR", "GRT"],
    "L1s": ["AVAX", "DOT", "SUI", "APT", "SEI"],
  }
  idx = [0, 1, 2, 3, 4]
  names = for i in idx { (catalog.get(basket) ?? ["ETH", "SOL", "XRP", "ADA", "LINK"])[i] ?? "ETH" }
  // Symbol availability is only known at run time (shown in the table), so
  // the quote currency of each venue is an input.
  idx10 = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
  syms = for k in idx10 { str.concat(str.lower(names.get(k < 5 ? k : k - 5) ?? "eth"), "/", k < 5 ? quoteA : quoteB) }
  btcSymA = str.concat("btc/", quoteA)
  btcSymB = str.concat("btc/", quoteB)
  CAP = 2000
)

data (
  btcA = subscribe(data.ohlcv, exchange: exA, symbol: btcSymA)
  btcB = subscribe(data.ohlcv, exchange: exB, symbol: btcSymB)
)
// Feeds 0-4 are the basket on venue A, 5-9 the same assets on venue B.
setup feeds = for k in idx10 { subscribe(data.ohlcv, exchange: k < 5 ? exA : exB, symbol: syms.get(k) ?? "eth/usd") }

window probeWin = window(title: "Spot Premium Probe") {
  availTbl: table.new([
    table.col(title: "Asset", width: 0.8),
    table.col(title: "Venue A", width: 1.0),
    table.col(title: "Venue B", width: 1.0),
    table.col(title: "Prem bps", align: align.right, width: 0.8),
    table.col(title: "Excess bps", align: align.right, width: 0.8),
    table.col(title: "Aligned %", align: align.right, width: 0.8),
  ], title: "Availability & current premium", capacity: 8),
}

pane premPane = pane(title: "Basket excess premium (bps, B vs A, net of BTC)", height: 0.3)
pane testPane = pane(title: "Premium z and forward IC", height: 0.3)

plot (
  btcPrem = plot.line(title: "BTC premium bps", color: color.rgb(148, 163, 184), width: 1.0, on: premPane)
  excessPrem = plot.line(title: "Basket excess premium bps", color: color.rgb(56, 189, 248), width: 1.6, on: premPane)
  zLine = plot.line(title: "Excess premium z", color: color.rgb(245, 158, 11), width: 1.4, on: testPane)
  icLine = plot.line(title: "IC x10 (z vs fwd rel. return)", color: color.rgb(167, 139, 250), width: 2.0, on: testPane)
  icZero = plot.line(title: "Zero", color: color.rgb(71, 85, 105), width: 1.0, style: linestyle.dotted, on: testPane)
)

state (
  exHist: rolling<float> = rolling<float>(CAP)
  zHist: rolling<float> = rolling<float>(CAP)
  relLvl: rolling<float> = rolling<float>(CAP)
  icX: rolling<float> = rolling<float>(CAP)
  icY: rolling<float> = rolling<float>(CAP)
  hits: float[] = float[](5)
  lastPrem: float[] = float[](5)
  px: float[] = float[](10)
  prevPx: float[] = float[](5)
  relCum: float = 0.0
  bars: int = 0
)

fn premBps(a: float?, b: float?, ta: time?, tb: time?, t0: time?) -> float? {
  let none: float? = null
  if ta == null || tb == null || t0 == null || ta != t0 || tb != t0 {
    return none
  }
  let pa = a ?? 0.0
  let pb = b ?? 0.0
  if pa <= 0.0 || pb <= 0.0 {
    return none
  }
  return (pb / pa - 1.0) * 10000.0
}

// rolling.get(0) is the oldest element; back(xs, k) reads k bars before the newest.
fn back(xs: rolling<float>, k: int) -> float? {
  return xs.get(xs.len - 1 - k)
}

fn rollZ(xs: rolling<float>, len: int) -> float? {
  let none: float? = null
  let n = math.min(len, xs.len)
  let cnt = 0.0
  let sm = 0.0
  let sq = 0.0
  for k in 0..n {
    let v = back(xs, k)
    if v != null {
      cnt += 1.0
      sm += v ?? 0.0
      sq += (v ?? 0.0) * (v ?? 0.0)
    }
  }
  let last = back(xs, 0)
  if cnt < 30.0 || last == null {
    return none
  }
  let mu = sm / cnt
  let sd = math.sqrt(math.max(sq / cnt - mu * mu, 0.0)) ?? 0.0
  if sd <= 0.000000001 {
    return none
  }
  return ((last ?? mu) - mu) / sd
}

fn rollCorr(xs: rolling<float>, ys: rolling<float>, len: int) -> float? {
  let none: float? = null
  let n = math.min(len, math.min(xs.len, ys.len))
  let c = 0.0
  let sx = 0.0
  let sy = 0.0
  let sxx = 0.0
  let syy = 0.0
  let sxy = 0.0
  for k in 0..n {
    let x = back(xs, k)
    let y = back(ys, k)
    if x != null && y != null {
      c += 1.0
      sx += x ?? 0.0
      sy += y ?? 0.0
      sxx += (x ?? 0.0) * (x ?? 0.0)
      syy += (y ?? 0.0) * (y ?? 0.0)
      sxy += (x ?? 0.0) * (y ?? 0.0)
    }
  }
  if c < 30.0 {
    return none
  }
  let den = math.sqrt(math.max((sxx - sx * sx / c) * (syy - sy * sy / c), 0.0)) ?? 0.0
  if den <= 0.000000001 {
    return none
  }
  return (sxy - sx * sy / c) / den
}

fn listedText(ex: string, sym: string) -> string {
  if !markets.hasExchange(ex) {
    return str.concat(ex, "? unknown venue")
  }
  return markets.hasSymbol(ex, sym) ? sym : str.concat(sym, " not listed")
}

fn listedColor(ex: string, sym: string) -> color {
  return markets.hasExchange(ex) && markets.hasSymbol(ex, sym) ? color.rgb(148, 163, 184) : color.rgb(239, 68, 68)
}

on btcA.close {
  if hits.len == 0 {
    for i in 0..5 {
      hits.push(0.0)
      lastPrem.push(null)
    }
    for k in 0..10 { px.push(null) }
    for i in 0..5 { prevPx.push(null) }
  }
  bars += 1
  let t0 = btcA.time
  let pBtc = premBps(btcA.close, btcB.close, btcA.time, btcB.time, t0)

  // Basket premium and basket-minus-BTC log level on venue A.
  let ps = 0.0
  let pc = 0.0
  let rs = 0.0
  let rc = 0.0
  // Closes of bars aligned with the BTC bar; null otherwise.
  for k, f in feeds {
    px.set(k, f.time == t0 ? f.close : null)
  }
  for i in 0..5 {
    let p = premBps(px.get(i), px.get(i + 5), t0, t0, t0)
    lastPrem.set(i, p)
    if p != null {
      ps += p ?? 0.0
      pc += 1.0
      hits.set(i, (hits.get(i) ?? 0.0) + 1.0)
    }
    let ca = px.get(i) ?? 0.0
    let cp = prevPx.get(i) ?? 0.0
    if ca > 0.0 && cp > 0.0 {
      rs += math.log(ca / cp) ?? 0.0
      rc += 1.0
    }
    prevPx.set(i, ca > 0.0 ? ca : null)
  }
  let excess: float? = pc >= 1.0 && pBtc != null ? ps / pc - (pBtc ?? 0.0) : null
  let bc = btcA.close ?? 0.0
  let bp = btcA.close[1] ?? 0.0
  let relRet: float? = rc >= 3.0 && bc > 0.0 && bp > 0.0 ? rs / rc - (math.log(bc / bp) ?? 0.0) : null
  relCum += relRet ?? 0.0
  let rel: float? = relRet != null ? relCum : null

  exHist.push(excess)
  let z = excess != null ? rollZ(exHist, zLen) : null
  zHist.push(z)
  relLvl.push(rel)

  // Pair the z known H bars ago with the relative return realised since.
  let zPast = back(zHist, horizon)
  let r0 = back(relLvl, 0)
  let rH = back(relLvl, horizon)
  let fwd: float? = r0 != null && rH != null ? (r0 ?? 0.0) - (rH ?? 0.0) : null
  icX.push(zPast)
  icY.push(fwd)
  let ic = rollCorr(icX, icY, icLen)

  btcPrem.plot(pBtc)
  excessPrem.plot(excess)
  zLine.plot(z)
  icLine.plot(ic != null ? (ic ?? 0.0) * 10.0 : null)
  icZero.plot(0.0)

  if btcA.isRealtime || bars - (int(math.floor(float(bars) / 20.0)) ?? 0) * 20 == 0 {
    for i in 0..5 {
      let p = lastPrem.get(i)
      let ex: float? = p != null && pBtc != null ? (p ?? 0.0) - (pBtc ?? 0.0) : null
      let sync = (hits.get(i) ?? 0.0) / float(bars) * 100.0
      probeWin.availTbl.row(names.get(i) ?? "",
        names.get(i) ?? "",
        table.cell(listedText(exA, syms.get(i) ?? ""), fg: listedColor(exA, syms.get(i) ?? "")),
        table.cell(listedText(exB, syms.get(i + 5) ?? ""), fg: listedColor(exB, syms.get(i + 5) ?? "")),
        p != null ? math.round(p ?? 0.0, 1) : null,
        ex != null ? math.round(ex ?? 0.0, 1) : null,
        table.cell(math.round(sync, 0), fg: sync < 90.0 ? color.rgb(239, 68, 68) : color.rgb(148, 163, 184)))
    }
    probeWin.availTbl.row("BTC", "BTC",
      table.cell(listedText(exA, btcSymA), fg: listedColor(exA, btcSymA)),
      table.cell(listedText(exB, btcSymB), fg: listedColor(exB, btcSymB)),
      pBtc != null ? math.round(pBtc ?? 0.0, 1) : null,
      "-",
      "")
    probeWin.availTbl.row("IC", "IC",
      str.format("H = {0} bars", horizon),
      str.format("n = {0}", icLen),
      ic != null ? math.round(ic ?? 0.0, 3) : null,
      z != null ? math.round(z ?? 0.0, 2) : null,
      "")
  }
}
