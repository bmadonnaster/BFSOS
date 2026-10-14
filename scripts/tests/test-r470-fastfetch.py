#!/usr/bin/env python3
"""Offline integration checks for the BFSOS Fastfetch port and login policy."""
from pathlib import Path
import json
import subprocess
root = Path(__file__).resolve().parents[2]
fs = root / 'ports/core/aaa_filesystem'
port = root / 'ports/opt/fastfetch'
assert 'fastfetch' in (root / 'scripts/bfs-build-iso.sh').read_text().split('iso_packages=(')[1].split(')')[0]
assert (port / 'Pkgfile').exists()
assert 'fastfetch' in (fs / 'Pkgfile').read_text()
assert 'bfsos-fastfetch.sh' in (fs / 'bashrc').read_text()
assert 'bfsos-fastfetch.sh' in (fs / 'Pkgfile').read_text()
config = json.loads((port / 'bfsos-config.jsonc').read_text())
assert config['logo']['source'] == '/usr/share/fastfetch/bfsos/logo.txt'
# Guards must not produce stdout in noninteractive shell and explicit opt-out.
p = subprocess.run(['bash','-c',f'source "{fs / "bfsos-fastfetch.sh"}"'],capture_output=True,text=True)
assert p.returncode == 0 and p.stdout == '', p
p = subprocess.run(['bash','-c',f'BFSOS_NO_FETCH=1; source "{fs / "bfsos-fastfetch.sh"}"'],capture_output=True,text=True)
assert p.returncode == 0 and p.stdout == '', p
print('r470 Fastfetch offline integration checks: PASS')
