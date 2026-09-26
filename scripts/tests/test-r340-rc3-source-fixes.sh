#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"

fail(){ echo "FAIL: $*" >&2; exit 1; }
pass(){ echo "PASS: $*"; }

[[ $(tr -d '[:space:]' < VERSION) == 0.9.0-rc3 ]] || fail 'VERSION is not RC3'
grep -q 'bfs_version=0.9.0-rc3' ports/core/aaa_filesystem/Pkgfile || fail 'aaa_filesystem RC3 identity missing'
pass 'RC3 authoritative version and filesystem identity'

for f in bootstrap.sh bootstrap-clean-start.sh scripts/bfs-build-iso.sh scripts/install-bfs-menu-current.sh scripts/bfs-publish-sourceforge-v4.sh; do
  bash -n "$f" || fail "$f syntax"
done
pass 'bootstrap/ISO/installer/publisher shell syntax'

[[ ! -e ports/opt/glib/.footprint ]] || fail 'generated final GLib footprint must not be committed for bootstrap pass'
grep -q '# Depends on: glib' ports/opt/gobject-introspection/Pkgfile || fail 'GI must depend on glib'
grep -q '# Depends on:.*gobject-introspection' ports/opt/polkit/Pkgfile || fail 'polkit must depend on GI'
line_func=$(grep -n '^ensure_glib_introspection_ready()' scripts/install-bfs-menu-current.sh | cut -d: -f1)
line_sysup=$(grep -n 'mandatory package upgrade (prt-get sysup)' scripts/install-bfs-menu-current.sh | cut -d: -f1)
(( line_func < line_sysup )) || fail 'GI preflight must be defined before mandatory sysup'
grep -q 'rm -f "$glib_footprint"' scripts/install-bfs-menu-current.sh || fail 'bootstrap GLib footprint cleanup missing'
pass 'GLib/GI/Polkit bootstrap ordering source policy'

grep -q 'No usable partitions found; returning to the previous storage menu' scripts/install-bfs-menu-current.sh || fail 'blank-disk recovery missing'
grep -q 'mount -t btrfs "$device" "$temp_mount"' scripts/install-bfs-menu-current.sh || fail 'explicit Btrfs mount missing'
grep -q 'for mount_attempt in 1 2 3 4 5' scripts/install-bfs-menu-current.sh || fail 'Btrfs retry loop missing'
pass 'blank-disk and Btrfs recovery source fixes'

grep -q 'BFSOS-base-${release}-x86_64.tar.zst' scripts/install-bfs-menu-current.sh || fail 'installer versioned base default missing'
grep -q 'BFSOS-base-${VERSION}-${ARCH}.tar.zst' scripts/bfs-build-iso.sh || fail 'ISO versioned base default missing'
grep -q 'BFSOS-base-${base_release}-${ARCH}.tar.zst' scripts/bfs-publish-sourceforge-v4.sh || fail 'publisher versioned base name missing'
grep -q 'checkout -B "$GIT_REF" "origin/$GIT_REF"' scripts/bfs-build-iso.sh || fail 'ISO tracking-branch checkout missing'
pass 'versioned base identity and live branch checkout source fixes'

grep -q "bfs-toolchain-\${BFS_VERSION}-\${BUILD_DATE}.tar.zst" bootstrap.sh || fail 'versioned zstd toolchain archive missing'
grep -q "bfs-rootfs-\${BFS_VERSION}-\${BUILD_DATE}.tar.zst" bootstrap.sh || fail 'versioned zstd base archive missing'
grep -q '_prefetch_bootstrap_sources /tmp/bootstrap.conf' bootstrap.sh || fail 'bootstrap source prefetch call missing'
pass 'bootstrap prefetch and zstd artifact source fixes'

./scripts/bfs-xorg-audit.py >/tmp/bfs-r340-xorg-audit.out || { cat /tmp/bfs-r340-xorg-audit.out; fail 'X.Org static audit'; }
grep -q '^version=26.2.3$' ports/xorg/mesa/Pkgfile || fail 'Mesa 26.2.3 update missing'
grep -q '^version=1.0.6$' ports/xorg/xorg-font-alias/Pkgfile || fail 'font-alias 1.0.6 update missing'
pass '180-port X.Org static audit and verified updates'

echo 'r340 source regression checks passed.'
