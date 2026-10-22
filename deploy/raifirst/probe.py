"""Check gateway and authenticated DB-backed API without credentials in argv/logs."""
from pathlib import Path
import json
import sys
from urllib.request import Request, urlopen

env = dict(line.split('=', 1) for line in Path('/etc/raifirst-ai/runtime.env').read_text().splitlines() if '=' in line)
try:
    with urlopen('http://127.0.0.1:18790/health', timeout=5) as response:
        assert json.load(response)['status'] == 'ok'
    request = Request('http://127.0.0.1:18790/v1/agents', headers={
        'Authorization': 'Bearer ' + env['GOCLAW_GATEWAY_TOKEN'],
        'X-GoClaw-User-Id': 'system',
    })
    with urlopen(request, timeout=10) as response:
        assert response.status == 200
        json.load(response)
except Exception as exc:
    print('Gateway/API probe failed:', type(exc).__name__, file=sys.stderr)
    sys.exit(1)
