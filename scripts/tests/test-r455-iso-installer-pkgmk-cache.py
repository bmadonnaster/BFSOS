#!/usr/bin/env python3
"""Source contract: pkgmk caches exist before any package build in ISO and installer."""
from pathlib import Path
root = Path(__file__).resolve().parents[2]
iso = (root / 'scripts/bfs-build-iso.sh').read_text()
installer = (root / 'scripts/install-bfs-menu-current.sh').read_text()
assert 'prepare_iso_pkgmk_cache() {' in iso
iso_phase = iso[iso.index('build_iso_package_set() {'):iso.index('install_live_runtime() {')]
assert iso_phase.index('prepare_iso_pkgmk_cache "$root"') < iso_phase.index('prt-get update pkgutils')
assert iso_phase.index('prepare_iso_pkgmk_cache "$root"') < iso_phase.index('prt-get sysup')
assert 'declare -f log die mount_chroot_fs umount_chroot_fs prepare_iso_pkgmk_cache' in iso
prepare = iso[iso.index('prepare_iso_pkgmk_cache() {'):iso.index('build_iso_package_set() {')]
assert 'chroot "$root" /usr/bin/id -u pkgmk' in prepare
assert 'chroot "$root" /usr/bin/id -g pkgmk' in prepare
assert '"$root/var/cache/pkg/$rel"' in prepare
assert 'chroot "$root" /usr/bin/runuser -u pkgmk -- test -w "$path"' in prepare
assert 'chown -R "$root/var/cache/pkg' not in prepare
assert 'chown -R "$uid:$gid" "$root/var/cache/pkg/sources/pkgutils"' in prepare
assert 'chown -R pkgmk:pkgmk /var/cache/pkg' not in iso
assert installer.index('ensure_pkgmk_build_ownership || exit 1') < installer.index('prt-get depinst git')
assert installer.index('ensure_pkgmk_build_ownership || exit 1') < installer.index('prt-get sysup')
assert installer.count('ensure_pkgmk_build_ownership || exit 1') == 1
ownership = installer[installer.index('ensure_pkgmk_build_ownership() {'):installer.index('if [[ ! -f "$STATE_DIR/packages_complete" ]]')]
assert 'chown -R pkgmk:pkgmk "$path"' not in ownership
assert 'runuser -u pkgmk -- test -w "$path_check"' in ownership
print('r455 ISO/installer pkgmk cache source policy: PASS')
