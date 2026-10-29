"""Package a tested Web export for the Pages release workflow (stdlib only)."""
from pathlib import Path
import gzip
import hashlib
import json
import tarfile

root = Path(__file__).resolve().parents[2]
web = root / 'build' / 'web'
required = ['index.html', 'index.js', 'index.pck', 'index.wasm', 'index.wasm.gz', 'loading-ui.woff2', 'leaderboard.js', 'leaderboard.css']
for name in required:
    if not (web / name).is_file():
        raise SystemExit('Missing export: ' + name)
# Do not publish a stale compressed engine left over from a previous export.
assert gzip.decompress((web / 'index.wasm.gz').read_bytes()) == (web / 'index.wasm').read_bytes()
files = [p for p in sorted(web.iterdir()) if p.is_file() and (not p.name.endswith('.gz') or p.name == 'index.wasm.gz')]
with tarfile.open(root / 'build' / 'site.tar.gz', 'w:gz', compresslevel=6) as archive:
    for item in files:
        archive.add(item, arcname=item.name)
report = {p.name: {'bytes': p.stat().st_size, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in files}
(root / 'build' / 'web-release-manifest.json').write_text(json.dumps(report, indent=2), encoding='utf8')
first_load = sum(p.stat().st_size for p in files if p.name != 'index.wasm')
print(f'First-load files: {first_load:,} bytes; package: build/site.tar.gz')
