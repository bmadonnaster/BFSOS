#!/usr/bin/env python3
"""r505 source regression: global unprivileged classic build / short fakeroot packaging."""
from pathlib import Path
import subprocess, tempfile
root=Path(__file__).resolve().parents[2]
p=root/'ports/core/pkgutils'
w=(p/'bfs-pkgmk').read_text()
s=(p/'Pkgfile').read_text()
patch=(p/'bfs-pkgmk-universal-build.patch.txt').read_text()
assert 'BFS_PKG_UNIVERSAL_BUILD=yes pkgmk "$@" &' in w
assert 'CCACHE_DIR=/var/cache/ccache fakeroot -- pkgmk "$@" &' not in w
assert 'BFS_PKG_UNIVERSAL_BUILD:-no' in patch
assert 'BFS_PKG_ARCHIVE_ONLY=yes fakeroot --' in patch
assert 'chown -hR 0:0 "$PKG"' in patch
assert 'bfs-pkgmk-universal-build.patch.txt' in s
assert 'release=50' in s
subprocess.run(['bash','-n',str(p/'bfs-pkgmk')],check=True)
subprocess.run(['bash','-n',str(p/'Pkgfile')],check=True)
print('r505 global pkgmk privilege boundary: source checks PASS')
