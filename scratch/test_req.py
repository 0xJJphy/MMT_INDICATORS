import requests, pathlib, json

token = pathlib.Path('.m5_token').read_text().strip()
headers = {
    'Authorization': 'Bearer ' + token,
    'Content-Type': 'application/json'
}
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

r = requests.post('https://app.mmt.gg/api/mcp', json=payload, headers=headers, timeout=15)
res = r.json()
script = json.loads(res['result']['content'][0]['text'])['script']
print("Live Script Name:", script.get('name'))
print("Current Revision on MMT:", script.get('revision'))
