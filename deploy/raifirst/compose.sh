#!/bin/bash
set -euo pipefail
cd /opt/raifirst-ai/source
if [ -z "${RAIFIRST_RELEASE:-}" ] && [ -f /etc/raifirst-ai/current-release ]; then
    export RAIFIRST_RELEASE=$(cat /etc/raifirst-ai/current-release)
fi
exec docker compose --env-file /etc/raifirst-ai/runtime.env -f deploy/raifirst/compose.yaml "$@"
