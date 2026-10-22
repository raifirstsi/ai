#!/bin/bash
# Consistent PostgreSQL dump plus application files, encrypted before leaving the host.
set -euo pipefail
umask 077
exec 8>/run/lock/raifirst-ai-backup.lock
flock -w 900 8 || { echo 'Another backup did not finish within 15 minutes.' >&2; exit 1; }
base=/opt/raifirst-ai
destination=/var/backups/raifirst-ai
work=$(mktemp -d "$destination/.working.XXXXXX")
trap 'rm -rf -- "$work"' EXIT
cd "$base/source"
deploy/raifirst/compose.sh exec -T postgres pg_dump -U raifirst -d raifirst -Fc > "$work/database.dump"
test -s "$work/database.dump"
install -m 600 /etc/raifirst-ai/runtime.env "$work/runtime.env"
git rev-parse HEAD > "$work/source-commit.txt"
date -u +%FT%TZ > "$work/created-at.txt"
# Preserve runtime packages/scripts; exclude only disposable download caches.
# tar exit 1 means a file changed during collection; retry once, then fail visibly.
archive_files() {
    tar --exclude=data/.runtime/pip-cache --exclude=data/.cache -cf "$work/files.tar" -C "$base/state" data workspace
}
archive_files || archive_files
stamp=$(date -u +%Y%m%dT%H%M%SZ)
file="$destination/$stamp.tar.age"
tar -C "$work" -cf - database.dump runtime.env source-commit.txt created-at.txt files.tar |
    age -r "$(cat /etc/raifirst-ai/backup-recipient.txt)" -o "$file"
test -s "$file"
# Publish only the latest encrypted snapshot on an independent, single-commit branch.
# Main retains full source history. Retention is bounded after successful upload.
mirror="$destination/github"
if [ ! -d "$mirror/.git" ]; then
    mkdir -p "$mirror"
    git -C "$mirror" init -b encrypted-backups
    git -C "$mirror" remote add origin git@github.com:raifirstsi/ai.git
    git -C "$mirror" config core.sshCommand /etc/raifirst-ai/git-ssh
    git -C "$mirror" config user.name 'RAIFIRST Encrypted Backup'
    git -C "$mirror" config user.email 'ai-backup@raifirst.si'
fi
cp "$file" "$mirror/latest.tar.age"
printf 'Encrypted RAIFIRST AI backup\nCreated: %s\nSource: %s\nRecover with the separately stored age identity. See main: deploy/raifirst/README.md.\n' \
    "$(cat "$work/created-at.txt")" "$(cat "$work/source-commit.txt")" > "$mirror/README.txt"
cd "$mirror"
# Split for GitHub's per-file size limit, without ever writing plaintext here.
find . -maxdepth 1 -type f -name 'latest.tar.age.part-*' -delete
if [ "$(stat -c %s latest.tar.age)" -ge 95000000 ]; then
    split -b 90M -d latest.tar.age latest.tar.age.part-
    rm latest.tar.age
fi
git add -A
tree=$(git write-tree)
commit=$(printf 'Encrypted backup %s\n' "$stamp" | git commit-tree "$tree")
old=$(git ls-remote origin refs/heads/encrypted-backups | cut -f1)
git push --force-with-lease="refs/heads/encrypted-backups:$old" origin "$commit:refs/heads/encrypted-backups"
git update-ref refs/heads/encrypted-backups "$commit"
git gc --prune=now --quiet
python3 /opt/raifirst-ai/source/deploy/raifirst/retain-backups.py
echo "Encrypted backup uploaded: $stamp"
