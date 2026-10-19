# MMT Indicators

Custom indicators for the **M5** charting platform ([app.mmt.gg](https://app.mmt.gg)), written in M5 scripting v3 (`.mm`), plus a few legacy v2 (`.js`) scripts and the helpers used to deploy them.

## Scripts

| File | Indicator |
|---|---|
| `scripts/vwap_suite_v3.mm` | **VWAP Suite v3**: periodic VWAPs (4H → yearly) with σ bands and projections, session VWAPs, month/week/day high-low AVWAPs, date-anchored AVWAP, naked VWAPs with scores, rolling VWAPs, HUD and layout presets (Daily · Weekly · Monthly · Q-Yearly) |
| `scripts/vwap_indicator_v3.mm` | VWAP Suite (previous version) |
| `scripts/vwap_distance_v3.mm` | VWAP Distance & Z-Score |
| `scripts/quant_levels_engine.mm` | Quant Levels Engine |
| `scripts/fvg_ob_detector_v3.mm` | FVG & Order Block Detector |
| `scripts/11_quant_basket_correlation_matrix.mm` | **Quant Basket Correlation & Dispersion Engine**: dynamic cross-basket narrative correlation matrix (Top Alts, Memes, RWA, AI, L1s, DeFi), 2D heatmap, symmetric table, beta sensitivities & dispersion oscillator |
| `scripts/02_…` → `10_…` | Order-flow / market-structure suite: absorption, liquidity sweeps, liquidity dynamics, CVD divergence, derivatives positioning, value zones, market structure, regime monitor, event analyzer |
| `scripts/*.js` | Legacy scripting v2 versions |
| `scripts/sync_db_to_mmt.py` | Pushes on-chain MVRV data from a local PostgreSQL DB into an M5 script |

## Setup

1. **M5 MCP key.** Create a file named `.m5_token` in the project root containing your key (one line), or set the `M5_MCP_TOKEN` environment variable. The file is git-ignored; the MCP config files (`mcp.json`, `.vscode/mcp.json`, `.agents/`, `.codex/`) read `M5_MCP_TOKEN`.
2. **Git hooks** (once per clone) — they block any commit or push that contains the key:
   ```bash
   git config core.hooksPath .githooks
   ```
3. `sync_db_to_mmt.py` reads its database settings from `GLI_DB_HOST`, `GLI_DB_PORT`, `GLI_DB_USER`, `GLI_DB_PASSWORD` and `GLI_DB_NAME`.

## Deploy flow

M5 rejects code above 128 KB, so large scripts are minified (comments and indentation stripped) before checking and saving:

```bash
python scratch/minify_mm.py scripts/vwap_suite_v3.mm min.mm
python scratch/check_code.py min.mm
python scratch/update_script.py <script-id> <base-revision> min.mm
```

`min.mm` is git-ignored.

## Notes on M5 v3 limits

- Max **16 drawing groups** (entity pools) per script; exceeding it stops the layer ("exceed drawing limits").
- 256 plots, 64 fills, 2000 entities per pool.
- A stopped layer does not rerun after a save until the page is reloaded.

## Security

Never commit keys or passwords. Secrets live in `.m5_token` / environment variables only; `.gitignore` and the hooks in `.githooks/` enforce it.

## License

MIT — see [LICENSE](LICENSE).
