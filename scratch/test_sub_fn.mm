script "Test Pass Sub"

data (
  chart = subscribe(data.ohlcv)
  tf1D  = subscribe(data.ohlcv, timeframe: 1D)
)

fn readHigh(sub: OhlcvSub) -> float {
  return sub.high ?? 0.0
}

on chart.update {
  let h = readHigh(tf1D)
}
