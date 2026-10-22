#!/usr/bin/env python3
"""r504: audit global package-build privilege policy; fail if violated.

This intentionally does not pretend a whole-build fakeroot invocation is safe.
Exit 1 means the r503 release blocker is still present.
"""
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[2]
wrapper = (root / 'ports/core/pkgutils/bfs-pkgmk').read_text()
source = (root / 'ports/core/pkgutils/Pkgfile').read_text()
ports = list((root / 'ports').glob('*/*/Pkgfile'))
split = sum(bool(re.search(r'^\s*bfs_build_phases=split(?:\s|$)', p.read_text(errors='replace'), re.M)) for p in ports)
print(f'Ports: {len(ports)}; explicit split ports: {split}; ordinary ports: {len(ports)-split}')
checks = {
  'Dedicated unprivileged pkgmk account': 'runuser -u pkgmk' in wrapper,
  'No whole-build fakeroot fallback': not bool(re.search(r'fakeroot\s+--\s+pkgmk\s+"\$@"', wrapper)),
  'No per-port opt-in required': 'BFS_PKG_UNIVERSAL_BUILD=yes pkgmk' in wrapper,
}
for name, passed in checks.items():
    print(f'{"PASS" if passed else "OPEN"}: {name}')
print('INFO: r505 archiving patch uses supplied installed pkgmk; verify on BFSOS against upstream pkgmk.in.')
print('INFO: Validate archive uid/gid, modes, symlinks, and pkginfo footprints on BFSOS before enabling a global mode.')
sys.exit(0 if all(checks.values()) else 1)
