#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
for p in office/libreoffice office/libreoffice-bin contrib/brother-hll8250cdn-lpr contrib/brother-hll8250cdn-cupswrapper; do
  [ -f "$ROOT/ports/$p/Pkgfile" ]
  bash -n "$ROOT/ports/$p/Pkgfile"
done
grep -q '^prtdir /usr/ports/office$' "$ROOT/ports/core/prt-get/prt-get.conf"
# Native office recipes use the same pkgutils extension as every other
# non-compat-32 collection; no separate pkgutils tree enumeration is needed.
grep -Fq '*/compat-32/*)' "$ROOT/ports/core/pkgutils/bfs-pkgmk"
grep -q 'install -m 644 "\$SRC"/prt-get.{conf,aliases}' "$ROOT/ports/core/prt-get/Pkgfile"
grep -q 'office:ports/office' "$ROOT/scripts/install-bfs-menu-current.sh"
grep -q 'ports/office' "$ROOT/scripts/bfs-ports-static-audit.sh"
for p in "$ROOT"/ports/contrib/brother-hll8250cdn-*/Pkgfile; do
  grep -q 'return 1' "$p"
done
printf '%s\n' 'PASS: r436 office/printer metadata and fail-closed scaffolds'
