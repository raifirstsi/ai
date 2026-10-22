#!/bin/bash
# One-way synchronization of this project's source; never reset remote commits.
set -euo pipefail
exec 9>/run/lock/raifirst-ai-source.lock
flock -n 9 || exit 0
cd /opt/raifirst-ai/source
git fetch origin main
git merge-base --is-ancestor origin/main HEAD || {
    echo 'GitHub has changes. Run deploy/raifirst/deploy.sh to reconcile and deploy.' >&2
    exit 1
}
git add -A
python3 deploy/raifirst/check-secrets.py
if ! git diff --cached --quiet; then
    git commit -m "Backup server source $(date -u +%FT%TZ)"
fi
git push origin HEAD:main
