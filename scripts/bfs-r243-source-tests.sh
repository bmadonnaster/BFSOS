#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

echo "== maintained Pkgfile shell syntax =="
find ports/{core,opt,xorg,plasma,gnome,lxqt,xfce,compiz} -mindepth 2 -maxdepth 2 -name Pkgfile -print0 | xargs -0 -n1 bash -n

echo "== maintained tree static audit =="
./scripts/bfs-ports-static-audit.sh

echo "== release static audit =="
./scripts/bfs-release-static-audit.sh

echo "== kernel maintenance regression =="
./scripts/tests/test-kernel-maintenance.sh

echo "== prt-get regression =="
./scripts/tests/test-prt-get-no-new-deps.sh

echo "== installer build-work sizing regression =="
./scripts/tests/test-installer-build-work-sizing.sh

echo "== checkupdate v8 regression =="
python3 ./scripts/tests/test-checkupdate-v2.py

echo "== excluded trees unchanged relative to git =="
if [ -n "$(git status --short -- ports/contrib ports/compat-32)" ]; then
    git status --short -- ports/contrib ports/compat-32
    echo "excluded tree changed" >&2
    exit 1
fi

echo "BFSOS r243 source tests: PASS"
