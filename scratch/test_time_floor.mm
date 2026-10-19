script "Test Time Floor"

data (
  chart = subscribe(data.ohlcv)
  tf4h  = subscribe(data.ohlcv, timeframe: 4h)
  tf1D  = subscribe(data.ohlcv, timeframe: 1D)
  tf1W  = subscribe(data.ohlcv, timeframe: 1W)
  tf1M  = subscribe(data.ohlcv, timeframe: 1M)
  tf1Q  = subscribe(data.ohlcv, timeframe: 3M)
  tf1Y  = subscribe(data.ohlcv, timeframe: 1Y)
)

on chart.update {
  let ts = chart.time ?? time.fromUnixSeconds(0)
  let t4 = time.floor(ts, 4h)
  let tD = time.floor(ts, 1D)
  let tW = time.floor(ts, 1W)
  let tM = time.floor(ts, 1M)
  let tQ = time.floor(ts, 3M)
  let tY = time.floor(ts, 1Y)
}
