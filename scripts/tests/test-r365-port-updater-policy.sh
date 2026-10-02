#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)

python3 -m py_compile \
  "$ROOT/scripts/bfs-port-updater.py" \
  "$ROOT/scripts/bfs-maintained-port-updater.py" \
  "$ROOT/scripts/checkupdate.py"

# Dynamic tree discovery must reflect real folders, including non-historical
# collections such as iso, rather than a fixed tuple in the checker/front-end.
"$ROOT/scripts/bfs-port-updater.py" --list-trees | grep -q $'^iso\t'
! grep -q '^TREES = ' "$ROOT/scripts/checkupdate.py"

grep -q 'MLFS_PATCH_PAGE' "$ROOT/scripts/bfs-port-updater.py"
grep -q 'kernel-bfsos-lts' "$ROOT/scripts/bfs-port-updater.py"
grep -q 'Dependent glibc release bump' "$ROOT/scripts/bfs-port-updater.py"
grep -q 'sudo","pkgmk","-d","-kw' "$ROOT/scripts/bfs-port-updater.py"

grep -q 'full --force \[--iso\] \[--refresh-sources\]' "$ROOT/bootstrap.sh"
grep -q './bootstrap.sh full --force --iso' "$ROOT/docs/COMMAND-LINE.md"

if grep -RFn --exclude='BFSOS-fix-tracker-*.md' 'pkgmk -dkw' "$ROOT/docs" "$ROOT/README.md" "$ROOT/website" >/tmp/bfs-r365-bad-pkgmk.$$ 2>/dev/null; then
  cat /tmp/bfs-r365-bad-pkgmk.$$ >&2
  rm -f /tmp/bfs-r365-bad-pkgmk.$$
  echo 'r365 updater regression: FAIL: invalid pkgmk -dkw documentation remains' >&2
  exit 1
fi
rm -f /tmp/bfs-r365-bad-pkgmk.$$ 2>/dev/null || true

python3 - "$ROOT" <<'PY'
import runpy, sys
from pathlib import Path
root=Path(sys.argv[1])
mod=runpy.run_path(str(root/'scripts/bfs-maintained-port-updater.py'), run_name='r365_test')
text=(root/'ports/core/glibc/Pkgfile').read_text()
new=mod['rewrite_source_patch_entries'](
    text,
    [{'filename':'glibc-fhs-1.patch'},{'filename':'glibc-2.44-upstream_fixes-2.patch'}],
    ['glibc-2.44-upstream_fix-1.patch'],
)
assert 'glibc-2.44-upstream_fixes-2.patch' in new
assert 'glibc-2.44-upstream_fix-1.patch' not in new
assert 'glibc-fhs-1.patch' in new
same=mod['rewrite_version_release'](text,'2.44','2.44','5')
assert 'version=2.44' in same and 'release=5' in same
PY

echo 'r365 port-updater/bootstrap/docs regression: PASS'
