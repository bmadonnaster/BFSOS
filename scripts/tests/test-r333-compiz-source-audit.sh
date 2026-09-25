#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
fail(){ echo "FAIL: $*" >&2; exit 1; }

for p in "$ROOT"/ports/compiz/*/Pkgfile; do
    bash -n "$p" || fail "syntax: ${p#$ROOT/}"
done

fusion="$ROOT/ports/compiz/fusion-icon/Pkgfile"
for dep in python3-pyqt5 mesa-demos xorg-apps compiz compizconfig-python ccsm emerald; do
    grep -Eq "^# Depends on:.*(^|[[:space:]])${dep}([[:space:]]|$)" "$fusion" || \
        grep -Fq "$dep" "$fusion" || fail "fusion-icon dependency missing: $dep"
done

for p in python3-sip python3-pyqt-builder python3-pyqt5; do
    test -f "$ROOT/ports/opt/$p/Pkgfile" || fail "missing PyQt support port: $p"
    bash -n "$ROOT/ports/opt/$p/Pkgfile" || fail "syntax: ports/opt/$p/Pkgfile"
done

if grep -Rni '/usr/local' "$ROOT/ports/compiz" --include=Pkgfile --include='*.py' --include='*.desktop' >/tmp/bfs-r333-compiz-local.$$ 2>/dev/null; then
    cat /tmp/bfs-r333-compiz-local.$$
    rm -f /tmp/bfs-r333-compiz-local.$$
    fail "unexpected /usr/local reference in Compiz suite"
fi
rm -f /tmp/bfs-r333-compiz-local.$$

grep -Fq '/usr/share/bfsos/' "$ROOT/ports/compiz/compiz-meta/Pkgfile" || fail "compiz-meta payload marker is not in /usr/share/bfsos"
! grep -Fq '/usr/share/doc' "$ROOT/ports/compiz/compiz-meta/Pkgfile" || fail "compiz-meta still uses stripped /usr/share/doc payload"

echo "PASS: r333 Compiz source/dependency audit"
