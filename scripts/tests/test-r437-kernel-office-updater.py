#!/usr/bin/env python3
"""Source and collection regression guards (no network or builds required)."""
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parents[2]
updater = (root / 'scripts/bfs-port-updater.py').read_text()
maintained = (root / 'scripts/bfs-maintained-port-updater.py').read_text()
assert '"kernel.org current series", "UPDATE"' in updater
assert 'bump_glibc_after_validated_headers' in updater
assert 'cleanup_successful_build_work(root, c.name)' in updater
assert 'if row.port not in {"core/linux", "core/linux-lts", "core/linux-headers"}' in maintained
for name in ('linux', 'linux-lts', 'linux-headers'):
    pkg = root / 'ports/core' / name / 'Pkgfile'
    cp = subprocess.run(['bash', '-c', 'source "$1"; printf "%s\n" "$version" "${source[0]}"', 'test', str(pkg)], capture_output=True, text=True, check=True)
    ver, url = cp.stdout.splitlines()[:2]
    assert url.endswith(f'linux-{ver}.tar.xz'), (name, ver, url)
assert 'prtdir /usr/ports/office' in (root / 'ports/core/prt-get/prt-get.conf').read_text()
assert 'office:ports/office' in (root / 'scripts/install-bfs-menu-current.sh').read_text()
print('PASS kernel source alignment, update policy and office registration')
