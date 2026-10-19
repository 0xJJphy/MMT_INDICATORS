script "Test Clear On Last"

data chart = subscribe(data.ohlcv)

state (
  lines = entities.linePool(max: 100)
)

on chart.update {
  if chart.isLast {
    let _ = lines.clear("")
    let ts = chart.time ?? time.fromUnixSeconds(0)
    lines.get("test").set(
      x1: ts,
      y1: chart.close ?? 0.0,
      x2: time.shiftBars(ts, 1),
      y2: chart.close ?? 0.0,
      color: color.teal,
      width: 2.0,
      style: linestyle.solid,
      extend: extend.right,
    )
  }
}
