script "Test Max Pool"

data chart = subscribe(data.ohlcv)

state (
  l = entities.linePool(max: 1024)
)

on chart.update {}
