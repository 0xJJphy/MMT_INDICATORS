import os as _os, pathlib as _pl, sys, json, requests

M5_TOKEN = _os.environ.get('M5_MCP_TOKEN') or (_pl.Path(__file__).resolve().parents[1] / '.m5_token').read_text().strip()

if len(sys.argv) < 4:
    print("Usage: python update_script.py <script_id> <base_revision> <file.mm>")
    sys.exit(1)

script_id = sys.argv[1]
base_rev = int(sys.argv[2])
filepath = sys.argv[3]

with open(filepath, 'r', encoding='utf-8') as f:
    code = f.read()

payload = {
    'jsonrpc': '2.0',
    'id': 1,
    'method': 'tools/call',
    'params': {
        'name': 'script_update_code',
        'arguments': {
            'scriptId': script_id,
            'baseRevision': base_rev,
            'code': code
        }
    }
}

headers = {
    'Authorization': 'Bearer ' + M5_TOKEN,
    'Content-Type': 'application/json'
}

try:
    resp = requests.post('https://app.mmt.gg/api/mcp', json=payload, headers=headers, timeout=20)
    res = resp.json()
    print(json.dumps(res.get('result', {}), indent=2))
except Exception as e:
    print("Error:", e)
