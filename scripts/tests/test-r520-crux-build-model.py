#!/usr/bin/env python3
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=(ROOT/'ports/core/prt-get/prt-get.conf').read_text()
assert 'makecommand      sudo -H -u pkgmk /usr/bin/fakeroot /usr/bin/pkgmk' in p
assert 'addcommand       sudo /usr/bin/pkgadd' in p
u=(ROOT/'scripts/bfs-port-updater.py').read_text()
start=u.index('def pkgmk_build_command('); end=u.index('def run_build_streaming(',start)
assert '"fakeroot", "pkgmk"' in u[start:end]
assert 'bfs-pkgmk' not in u[start:end]
h=(ROOT/'ports/core/prt-get/bfs-pkg-permissions').read_text()
assert '/var/cache/pkg/build-work-disk' in h and '/var/cache/pkg/build-work' in h
assert 'chown -R' not in h
assert '-L "$p"' in h
assert 'bfs-pkg-permissions' in (ROOT/'ports/core/prt-get/post-install').read_text()
assert 'bfs-pkg-permissions' in (ROOT/'ports/core/prt-get/Pkgfile').read_text()
assert 'pkgmk --help' in (ROOT/'scripts/bfs-build-iso.sh').read_text()
print('r520 CRUX build integration static tests PASS')
