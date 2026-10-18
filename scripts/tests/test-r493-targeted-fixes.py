#!/usr/bin/env python3
"""Offline regression checks for r493 changes; no root, package installs or network."""
from pathlib import Path
import importlib.util
import subprocess
root=Path(__file__).resolve().parents[2]
maint=root/'scripts/bfs-maintained-port-updater.py'
spec=importlib.util.spec_from_file_location('bfs_maintained_port_updater', maint)
mod=importlib.util.module_from_spec(spec)
import sys
sys.modules[spec.name]=mod
spec.loader.exec_module(mod)
original='name=test\nversion=1.2.3\nrelease=7\n'
assert 'release=1\n' in mod.rewrite_version_release(original,'1.2.3','1.2.4','7')
assert 'release=1\n' in mod.rewrite_version_release(original,'1.2.3','1.2.4')
assert 'release=7\n' in mod.rewrite_version_release(original,'1.2.3','1.2.3')
assert 'release=8\n' in mod.rewrite_version_release(original,'1.2.3','1.2.3','8')
for p in ['ports/office/libreoffice-bin/Pkgfile','ports/opt/fastfetch/Pkgfile','ports/core/bash/Pkgfile','ports/core/pkgutils/Pkgfile','ports/core/pkgutils/bfs-pkgmk']:
    subprocess.run(['bash','-n',str(root/p)],check=True)
lib=(root/'ports/office/libreoffice-bin/Pkgfile').read_text()
assert 'command -v bsdtar' in lib
assert 'libarchive' in lib.splitlines()[3]
assert 'bsdtar -tf "$rpm" >/dev/null || return 1' in lib
assert 'bsdtar -xf "$rpm" -C "$PKG"' in lib
ff=(root/'ports/opt/fastfetch/Pkgfile').read_text()
assert '-DENABLE_IMAGE_LOGO=ON' in ff
assert '--enable-system-bashrc=/etc/bashrc' in (root/'ports/core/bash/Pkgfile').read_text()
assert 'bfsos-fastfetch.sh' in (root/'ports/core/aaa_filesystem/bashrc').read_text()
wrapper=(root/'ports/core/pkgutils/bfs-pkgmk').read_text()
assert '[ ! -L "$bfs_cache_dir" ]' in wrapper and 'chown pkgmk:pkgmk "$bfs_cache_dir"' in wrapper
print('r493 targeted offline tests: PASS')
