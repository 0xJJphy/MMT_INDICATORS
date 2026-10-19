script "Test State In Fn"

data chart = subscribe(data.ohlcv)

state (
  lines = entities.linePool(max: 100)
)

fn drawLine(id: string, sTs: time, px: float) {
  lines.get(id).set(
    x1: sTs,
    y1: px,
    x2: time.shiftBars(sTs, 1),
    y2: px,
    color: color.teal,
    width: 1.5,
    style: linestyle.solid,
    extend: extend.right,
  )
}

on chart.update {
  if chart.isLast {
    let ts = chart.time ?? time.fromUnixSeconds(0)
    drawLine("test", ts, chart.close ?? 0.0)
  }
}
