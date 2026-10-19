import os, pathlib, requests, json, sys

token = pathlib.Path('.m5_token').read_text().strip()

def check_file(filepath):
    code_str = pathlib.Path(filepath).read_text(encoding='utf-8')
    payload = {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'tools/call',
        'params': {
            'name': 'script_check',
            'arguments': {
                'code': code_str
            }
        }
    }
    resp = requests.post('https://app.mmt.gg/api/mcp', json=payload, headers={'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json'})
    return resp.json()

if __name__ == '__main__':
    target = sys.argv[1] if len(sys.argv) > 1 else 'scripts/quant_levels_engine.mm'
    res = check_file(target)
    print(json.dumps(res, indent=2))
