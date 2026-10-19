script "Test MTF Indices"

data (
  chart = subscribe(data.ohlcv)
  tf1D  = subscribe(data.ohlcv, timeframe: 1D)
  tf1W  = subscribe(data.ohlcv, timeframe: 1W)
)

state (
  lines = entities.linePool(max: 100)
)

on chart.update {
  let ts = chart.time ?? time.fromUnixSeconds(0)
  if chart.isLast {
    let dStart = time.floor(ts, 1D)
    let dHigh  = tf1D.high ?? 0.0
    let dLow   = tf1D.low  ?? 0.0
    let dClose = tf1D.close ?? 0.0

    // Active Day Pivot line
    let pp = (dHigh + dLow + dClose) / 3.0
    lines.get("D_PP").set(
      x1: dStart,
      y1: pp,
      x2: time.shiftBars(dStart, 1),
      y2: pp,
      color: color.yellow,
      width: 1.5,
      style: linestyle.solid,
      extend: extend.right,
    )

    // Historical Day 1 (Yesterday)
    let yStart = tf1D.time[0] ?? dStart
    let yEnd   = dStart
    let yHigh  = tf1D.high[1] ?? 0.0
    let yLow   = tf1D.low[1]  ?? 0.0
    let yClose = tf1D.close[1] ?? 0.0
    let yPp    = (yHigh + yLow + yClose) / 3.0
    lines.get("D_PP_1").set(
      x1: yStart,
      y1: yPp,
      x2: yEnd,
      y2: yPp,
      color: color.withAlpha(color.yellow, 100),
      width: 1.0,
      style: linestyle.dotted,
      extend: extend.none,
    )
  }
}
