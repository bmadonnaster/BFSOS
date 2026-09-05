#!/bin/bash
# BFSOS maintained-tree upstream version audit.
# contrib and compat-32 are intentionally excluded.
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
STAMP=$(date +%Y%m%d-%H%M%S)
OUT=${1:-"$ROOT/bfs-maintained-port-version-audit-$STAMP.log"}

export REPO="$ROOT/ports/core $ROOT/ports/opt $ROOT/ports/xorg $ROOT/ports/plasma $ROOT/ports/gnome $ROOT/ports/lxqt $ROOT/ports/xfce $ROOT/ports/compiz"

echo "BFSOS maintained-port online version audit"
echo "Trees: core opt xorg plasma gnome lxqt xfce compiz"
echo "Excluded: contrib compat-32"
echo "Output: $OUT"
echo

set -o pipefail
"$ROOT/scripts/checkupdate.sh" 2>&1 | tee "$OUT"
status=${PIPESTATUS[0]}

echo
echo "Audit saved to: $OUT"
echo "Review every version result before using checkupdate.sh -u."
exit "$status"
