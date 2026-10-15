import os as _os, pathlib as _pl
# MCP key: env M5_MCP_TOKEN or <project>/.m5_token (never commit/share it)
M5_TOKEN = _os.environ.get('M5_MCP_TOKEN') or (_pl.Path(__file__).resolve().parents[1] / '.m5_token').read_text().strip()
import sys
import json
import urllib.request

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

req = urllib.request.Request(
    'https://app.mmt.gg/api/mcp',
    data=json.dumps(payload).encode('utf-8'),
    headers={
        'Authorization': 'Bearer ' + M5_TOKEN,
        'Content-Type': 'application/json'
    }
)

try:
    with urllib.request.urlopen(req) as resp:
        res = json.loads(resp.read().decode('utf-8'))
        print(json.dumps(res.get('result', {}), indent=2))
except urllib.error.HTTPError as e:
    print("HTTPError:", e.code, e.read().decode('utf-8'))
