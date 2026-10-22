"""Keep recovery points without allowing this project to fill the shared disk."""
from datetime import datetime, timezone
from pathlib import Path

root = Path('/var/backups/raifirst-ai')
files = sorted(root.glob('*.tar.age'), reverse=True)
now = datetime.now(timezone.utc).timestamp()
keep = set(files[:4])
days = set()
for file in files:
    if now - file.stat().st_mtime > 7 * 86400:
        continue
    day = file.name[:8]
    if day not in days:
        keep.add(file)
        days.add(day)
total = 0
for file in files:
    size = file.stat().st_size
    # Preserve the newest snapshot, then enforce an 8 GiB archive budget.
    if file in keep and (file == files[0] or total + size <= 8 * 1024**3):
        total += size
    else:
        file.unlink()
