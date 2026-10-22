#!/bin/bash
# Run after editing server source, or to deploy reviewed changes from origin/main.
set -euo pipefail
cd /opt/raifirst-ai/source
exec 9>/run/lock/raifirst-ai-source.lock
flock -n 9 || { echo 'Source sync/deployment is already running.' >&2; exit 1; }
git add -A
python3 deploy/raifirst/check-secrets.py
if ! git diff --cached --quiet; then git commit -m "Prepare RAIFIRST deployment $(date -u +%FT%TZ)"; fi
git fetch origin main
if ! git merge-base --is-ancestor origin/main HEAD; then
    git merge --ff-only origin/main || { echo 'Resolve source divergence before deployment.' >&2; exit 1; }
fi
deploy/raifirst/backup.sh
export GOCLAW_COMMIT_SHA=$(git rev-parse --short HEAD)
export GOCLAW_VERSION="$(git describe --tags --abbrev=0)-raifirst"
previous=$(cat /etc/raifirst-ai/current-release 2>/dev/null || echo current)
export RAIFIRST_RELEASE="$(date -u +%Y%m%dT%H%M%SZ)-$GOCLAW_COMMIT_SHA"
deploy/raifirst/compose.sh build gateway
git push origin HEAD:main
started=false
if deploy/raifirst/compose.sh up -d --no-deps gateway; then started=true; fi
for attempt in $(seq 1 60); do
    if [ "$started" = true ] && python3 deploy/raifirst/probe.py; then
        printf '%s\n' "$RAIFIRST_RELEASE" > /etc/raifirst-ai/current-release
        echo "Deployed $GOCLAW_COMMIT_SHA and synchronized GitHub."
        exit 0
    fi
    [ "$started" = true ] || break
    sleep 2
done
RAIFIRST_RELEASE="$previous" deploy/raifirst/compose.sh up -d --no-deps gateway
echo 'Health check failed; previous image selected. Check migrations and the pre-deployment backup before retrying.' >&2
exit 1
