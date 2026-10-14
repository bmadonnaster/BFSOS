#!/usr/bin/env python3
"""r457: generated build environments ignore intermediate package footprints."""
from pathlib import Path
r = Path(__file__).resolve().parents[2]
iso = (r / 'scripts/bfs-build-iso.sh').read_text()
installer = (r / 'scripts/install-bfs-menu-current.sh').read_text()
bootstrap = (r / 'bootstrap.sh').read_text()

assert 'set_iso_build_footprint_policy() {' in iso
pkgset = iso.split('build_iso_package_set() {', 1)[1].split('install_live_runtime() {', 1)[0]
assert pkgset.count('set_iso_build_footprint_policy "$root"') >= 3
assert pkgset.index('set_iso_build_footprint_policy "$root"') < pkgset.index('prt-get update pkgutils')
assert pkgset.index('prt-get update pkgutils') < pkgset.index('set_iso_build_footprint_policy "$root"',pkgset.index('prt-get update pkgutils')) < pkgset.index('prt-get sysup')
assert 'PKGMK_IGNORE_MD5SUM=' not in iso.split('set_iso_build_footprint_policy() {',1)[1].split('build_iso_package_set()',1)[0]
early = installer.split('configure_pkgmk_integrity_settings_early() {',1)[1].split('configure_pkgmk_integrity_settings_early\n',1)[0]
assert 'footprint_ignore=yes' in early
assert '[[ "$VERIFY_FOOTPRINT_VALUE" == yes ]] || footprint_ignore=yes' not in early
assert 'rm -f "$glib_footprint"' not in installer
assert installer.index('pkgutils upgrade before installer package builds') < installer.index('prt-get sysup')
assert 'configure_pkgmk_integrity_settings_early\nfi' in installer
assert installer.index('configure_pkgmk_integrity_settings\nconfigure_zram_swap') > installer.index('prt-get sysup')
assert '[[ "$VERIFY_FOOTPRINT_VALUE" == yes ]] || footprint_ignore=yes' in installer.split('configure_pkgmk_integrity_settings() {',1)[1]
assert 'PKGMK_IGNORE_SIGNATURE="yes"\nPKGMK_IGNORE_FOOTPRINT="yes"' in bootstrap
assert bootstrap.count('integrity_opts="-is -if"') == 2
assert 'PKGMK_IGNORE_FOOTPRINT="$([ "$BFS_VERIFY_FOOTPRINT" = yes ] && echo no || echo yes)"' in bootstrap
assert 'PKGMK_IGNORE_MD5SUM="$([ "$BFS_VERIFY_MD5" = yes ] && echo no || echo yes)"' in bootstrap
print('r457 construction footprint policy: PASS')
