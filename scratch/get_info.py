import os, pathlib, json, urllib.request

token = os.environ.get('M5_MCP_TOKEN') or (pathlib.Path('.m5_token')).read_text().strip()

payload = {
    'jsonrpc': '2.0',
    'id': 1,
    'method': 'tools/call',
    'params': {
        'name': 'script_get',
        'arguments': {
            'scriptId': 'bf9bc32c-4992-433a-ba1e-4ca262d8edb0'
        }
    }
}

req = urllib.request.Request(
    'https://app.mmt.gg/api/mcp',
    data=json.dumps(payload).encode('utf-8'),
    headers={
        'Authorization': 'Bearer ' + token,
        'Content-Type': 'application/json'
    }
)

try:
    with urllib.request.urlopen(req, timeout=15) as resp:
        res = json.loads(resp.read().decode('utf-8'))
        script = json.loads(res['content'][0]['text'])['script']
        print(f"Name: {script.get('name')}, Revision: {script.get('revision')}")
except Exception as e:
    print("Error:", e)
