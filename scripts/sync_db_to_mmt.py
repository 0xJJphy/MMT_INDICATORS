import os as _os, pathlib as _pl
# MCP key: env M5_MCP_TOKEN or <project>/.m5_token (never commit/share it)
M5_TOKEN = _os.environ.get('M5_MCP_TOKEN') or (_pl.Path(__file__).resolve().parents[1] / '.m5_token').read_text().strip()
import os
import json
import datetime
import urllib.request
import psycopg2

def fetch_mvrv_data():
    conn = psycopg2.connect(
        host=os.environ.get('GLI_DB_HOST', 'localhost'),
        port=int(os.environ.get('GLI_DB_PORT', '5432')),
        user=os.environ.get('GLI_DB_USER', 'gli_user'),
        password=os.environ['GLI_DB_PASSWORD'],
        dbname=os.environ.get('GLI_DB_NAME', 'gli_dashboard')
    )
    cur = conn.cursor()
    # Fetch last 365 days (or all history needed)
    cur.execute("""
        SELECT 
            date, 
            mvrv_zscore, 
            sth_mvrv, 
            lth_mvrv
        FROM market_data.onchain_daily 
        WHERE date >= '2023-01-01' AND (mvrv_zscore IS NOT NULL OR sth_mvrv IS NOT NULL)
        ORDER BY date ASC;
    """)
    rows = cur.fetchall()
    cur.close()
    conn.close()
    
    # Map to unix timestamp (seconds at 00:00:00 UTC) -> values
    data_map = {}
    for r in rows:
        d = r[0]
        dt = datetime.datetime(d.year, d.month, d.day, 0, 0, 0, tzinfo=datetime.timezone.utc)
        ts = int(dt.timestamp())
        data_map[ts] = {
            "z": round(float(r[1]), 4) if r[1] is not None else None,
            "sth": round(float(r[2]), 4) if r[2] is not None else None,
            "lth": round(float(r[3]), 4) if r[3] is not None else None
        }
    return data_map

def generate_mmt_script(data_map):
    json_payload = json.dumps(data_map, separators=(',', ':'))
    
    script_code = f"""//@version=2
indicator("BTC On-Chain MVRV Suite (GLI-CLI Bridge)", false)

// Ingested directly from local Docker PostgreSQL (market_data.onchain_daily)
// Total data points: {len(data_map)} daily snapshots
const ONCHAIN_DATA = {json_payload};

const showZScore = input.bool("Show MVRV Z-Score", true, {{ key: "show_z" }})
const showSTH = input.bool("Show STH-MVRV", true, {{ key: "show_sth" }})
const showLTH = input.bool("Show LTH-MVRV", false, {{ key: "show_lth" }})

const colZ = input.color("Z-Score Color", "#FFA500", {{ key: "col_z" }})
const colSTH = input.color("STH Color", "#00E676", {{ key: "col_sth" }})
const colLTH = input.color("LTH Color", "#2979FF", {{ key: "col_lth" }})

const candles = subscribe(data.OHLCV)

function onBar() {{
    const barSec = candles.unix(0)
    // Align to 00:00:00 UTC day bucket
    const daySec = Math.floor(barSec / 86400) * 86400
    
    const entry = ONCHAIN_DATA[daySec]
    const zVal = entry && entry.z !== null ? entry.z : NaN
    const sthVal = entry && entry.sth !== null ? entry.sth : NaN
    const lthVal = entry && entry.lth !== null ? entry.lth : NaN
    
    if (showZScore) {{
        plot("MVRV Z-Score", zVal, {{ color: colZ, width: 2, showLabel: true, showValue: true }})
        // Benchmark extreme regimes
        plot("Overheated (Z=3.5)", 3.5, {{ color: color.red, width: 1, style: linestyle.dashed }})
        plot("Cycle Bottom (Z=0.1)", 0.1, {{ color: color.green, width: 1, style: linestyle.dashed }})
        plot("Zero Baseline", 0.0, {{ color: color.gray, width: 1, style: linestyle.dotted }})
    }}
    
    if (showSTH) {{
        plot("STH-MVRV (1.0 Baseline)", sthVal, {{ color: colSTH, width: 1.5, showLabel: true }})
        plot("STH Breakeven (1.0)", 1.0, {{ color: "#FFFFFF40", style: linestyle.dotted }})
    }}
    
    if (showLTH) {{
        plot("LTH-MVRV", lthVal, {{ color: colLTH, width: 1.5, showLabel: true }})
    }}
}}
"""
    return script_code

def save_and_push_mcp(script_code):
    # 1. Save local file
    local_path = os.path.join(os.path.dirname(__file__), 'btc_onchain_mvrv.js')
    with open(local_path, 'w', encoding='utf-8') as f:
        f.write(script_code)
    print(f"[OK] Generated local script: {local_path} ({len(script_code)} bytes)")
    
    # 2. Push to M5 MCP server
    payload = {
        "jsonrpc": "2.0",
        "id": 10,
        "method": "tools/call",
        "params": {
            "name": "script_create",
            "arguments": {
                "name": "BTC On-Chain MVRV Suite (GLI-CLI Bridge)",
                "code": script_code
            }
        }
    }
    
    req = urllib.request.Request(
        "https://app.mmt.gg/api/mcp",
        data=json.dumps(payload).encode('utf-8'),
        headers={
            "Authorization": 'Bearer ' + M5_TOKEN,
            "Content-Type": "application/json"
        }
    )
    
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            res = json.loads(resp.read().decode('utf-8'))
            print("[OK] Uploaded to MMT via MCP:")
            print(json.dumps(res, indent=2))
    except Exception as e:
        print(f"[NOTE] MCP upload notice: {e} (The local script is created and ready to paste if MMT is offline)")

def main():
    print("--- Fetching data from local Docker PostgreSQL (market_data.onchain_daily) ---")
    data = fetch_mvrv_data()
    print(f"[OK] Fetched {len(data)} daily on-chain records from 2023 to present.")
    code = generate_mmt_script(data)
    save_and_push_mcp(code)

if __name__ == '__main__':
    main()
