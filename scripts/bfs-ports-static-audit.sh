#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT"

fail=0

report() {
    printf 'AUDIT: %s\n' "$*" >&2
    fail=1
}

while IFS= read -r -d '' pkgfile; do
    if ! bash -n "$pkgfile"; then
        report "shell syntax failed: $pkgfile"
    fi

done < <(find ports -mindepth 3 -maxdepth 3 -type f -name Pkgfile -print0)

while IFS=: read -r file line text; do
    report "bad JOBS default expansion: $file:$line: $text"
done < <(grep -Rns --include=Pkgfile '\${JOBS-1}' ports || true)

# BFSOS pkgmk's extension enters the extracted source directory before pkg_build().
# These source-dir forms therefore point at a nonexistent nested directory.
python3 - "$ROOT" <<'PY' || fail=1
from pathlib import Path
import sys
root = Path(sys.argv[1])
issues = []
for p in root.glob('ports/*/*/Pkgfile'):
    lines = p.read_text(errors='replace').splitlines()
    inside = False
    depth = 0
    for n, line in enumerate(lines, 1):
        stripped = line.strip()
        if stripped.startswith('pkg_build()'):
            inside = True
            depth = line.count('{') - line.count('}')
            continue
        if not inside:
            continue
        depth += line.count('{') - line.count('}')
        suspicious = (
            ('meson setup' in line and any(tok in line.split() for tok in ('$name-$version', '${name}-${version}'))) or
            ('cmake -S ' in line and any(tok in line.split() for tok in ('$name-$version', '${name}-${version}'))) or
            ('meson setup ../libsigc++-$version' in line)
        )
        if suspicious:
            issues.append((p.relative_to(root), n, stripped))
        if depth <= 0:
            inside = False
if issues:
    for p, n, line in issues:
        print(f'AUDIT: nested source-dir assumption in pkg_build: {p}:{n}: {line}', file=sys.stderr)
    raise SystemExit(1)
PY

# X.Org recipes must not depend on the old ambient $docdir variable.
while IFS=: read -r file line text; do
    report "ambient X.Org docdir variable: $file:$line: $text"
done < <(grep -Rns --include=Pkgfile '\$docdir' ports/xorg || true)

if grep -Rqs --include=Pkgfile './configure --prefix= *\$XORG_CONFIG' ports/xorg; then
    grep -Rns --include=Pkgfile './configure --prefix= *\$XORG_CONFIG' ports/xorg >&2 || true
    report "malformed XORG_CONFIG prefix invocation found"
fi

if [ -e ports/xorg/util-macros/pre-install ]; then
    report "obsolete util-macros pre-install still exists (used to create /usr/X11R6/usr collisions)"
fi

# libX11 directly requires the protocol headers as well as libxcb/xtrans.
if ! grep -Eq '^# Depends on:.*(^|[[:space:]])xorgproto([[:space:]]|$)' ports/xorg/libX11/Pkgfile; then
    report "libX11 dependency metadata is missing xorgproto"
fi

if [ "$fail" -ne 0 ]; then
    printf 'BFSOS ports static audit: FAILED\n' >&2
    exit 1
fi

printf 'BFSOS ports static audit: PASSED\n'
