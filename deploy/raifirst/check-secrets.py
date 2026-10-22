"""Reject staged credentials before the automatic public-repository push."""
import pathlib
import hashlib
import json
import re
import subprocess
import sys

values = []
for line in pathlib.Path("/etc/raifirst-ai/runtime.env").read_bytes().splitlines():
    if b"=" in line:
        value = line.split(b"=", 1)[1].strip()
        if len(value) >= 16:
            values.append(value)
patterns = [rb"gh[pousr]_[A-Za-z0-9]{30,}", rb"github_pat_[A-Za-z0-9_]{50,}",
            rb"-----BEGIN (?:OPENSSH |RSA |EC )?PRIVATE KEY-----[\r\n]+[A-Za-z0-9+/=]{20,}", rb"AGE-SECRET-KEY-[A-Z0-9]{40,}",
            rb"sk-(?:proj-|ant-api\d+-)?[A-Za-z0-9_-]{32,}", rb"AKIA[0-9A-Z]{16}"]
allowlist = json.loads(pathlib.Path('deploy/raifirst/secret-scan-allowlist.json').read_text())

def git(*args):
    return subprocess.check_output(['git', *args])

# Scan every indexed blob, including binary files and committed content.
blobs = {}
for entry in git('ls-files', '--stage', '-z').split(b'\0'):
    if not entry:
        continue
    metadata, path = entry.split(b'\t', 1)
    mode, oid, stage = metadata.split()
    if mode != b'160000':
        blobs[oid.decode()] = path.decode(errors='replace')

# Also inspect intermediate outgoing commits, so committing then deleting a key
# cannot publish it in history. The original upstream history is not ours.
commits = git('rev-list', 'origin/main..HEAD', '--not', 'upstream/main').decode().splitlines()
for commit in commits:
    for line in git('diff-tree', '--root', '-r', '--no-commit-id', '--raw', commit).splitlines():
        if not line.startswith(b':') or b'\t' not in line:
            continue
        metadata, path = line.split(b'\t', 1)
        fields = metadata.split()
        oid = fields[3].decode()
        if set(oid) != {'0'} and fields[1] != b'160000':
            blobs[oid] = path.decode(errors='replace')

bad = []
batch = subprocess.Popen(['git', 'cat-file', '--batch'], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
for oid, path in blobs.items():
    batch.stdin.write((oid + '\n').encode())
    batch.stdin.flush()
    header = batch.stdout.readline().split()
    content = batch.stdout.read(int(header[2]))
    batch.stdout.read(1)
    matches = [match.group() for pattern in patterns for match in re.finditer(pattern, content)]
    unexpected = any(hashlib.sha256(match).hexdigest() not in allowlist.get(path, []) for match in matches)
    if any(value in content for value in values) or unexpected:
        bad.append(path)
batch.stdin.close()
batch.wait()
if bad:
    sys.exit('Secret scan blocked push; inspect these paths (values withheld): ' + ', '.join(sorted(set(bad))))
print('Secret scan passed:', len(blobs), 'blobs checked.')
