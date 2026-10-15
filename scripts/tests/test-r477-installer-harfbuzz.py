#!/usr/bin/env python3
"""Static source regressions for r477; VM integration tests remain mandatory."""
from pathlib import Path
import re
root = Path(__file__).resolve().parents[2]
s = (root / 'scripts/install-bfs-menu-current.sh').read_text()
assert 'INSTALL_PARTED="${BFS_INSTALL_PARTED:-no}"' in s
assert 'INSTALL_LINKS INSTALL_PARTED INSTALL_NETWORKMANAGER' in s
assert 'INSTALL_LINKS|INSTALL_PARTED|INSTALL_NETWORKMANAGER' in s
assert 'parted "Parted disk partitioning utility"' in s
assert 'INSTALL_PARTED=no' in s
assert 'INSTALL_PARTED=yes' in s
assert '7) toggle_setting INSTALL_PARTED' in s
assert '8) PACKAGES_CONFIGURED=yes' in s
assert '[[ "$INSTALL_PARTED" == yes ]] && packages+=(parted)' in s
assert (root / 'ports/opt/parted/Pkgfile').exists()
h = (root / 'ports/opt/harfbuzz/Pkgfile').read_text()
h32 = (root / 'ports/compat-32/harfbuzz-32/Pkgfile').read_text()
f = (root / 'ports/opt/harfbuzz/.footprint').read_text()
assert re.search(r'^release=2$',h,re.M)
assert '-Ddocs=disabled' in h and '-Ddocs=disabled' in h32
assert 'usr/share/gtk-doc' not in f
assert 'usr/lib/libharfbuzz' in f
assert 'scripts/config --set-str LOCALVERSION "-BFS-Linux"' in (root/'ports/core/linux/Pkgfile').read_text(), 'non-LTS suffix change remains deferred'
print('r477 installer/harfbuzz static regressions: PASS')
