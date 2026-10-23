#!/usr/bin/env python3
"""Offline r515 guardrails for explicit metadata and branded GRUB generation."""
from pathlib import Path
import subprocess
r=Path(__file__).resolve().parents[2]
w=(r/'ports/core/pkgutils/bfs-pkgmk').read_text()
p=(r/'ports/core/pkgutils/Pkgfile').read_text()
i=(r/'scripts/install-bfs-menu-current.sh').read_text()
k=(r/'ports/core/bfs-kernel-maintenance/bfs-kernel-maintenance').read_text()
assert 'release=52' in p
for opt in ('-uf|--update-footprint','-um|--update-md5sum','-us|--update-signature','-rs|--refresh-signature'):
    assert opt in w
for name, flag in (('.footprint','bfs_update_footprint'),('.md5sum','bfs_update_md5sum'),('.signature','bfs_update_signature')):
    assert f'{name}) [ "${flag}" = yes ] || continue' in w
assert 'cmp -s -- "$bfs_stage/$bfs_meta" "$bfs_port_dir/$bfs_meta"' in w
assert 'request one metadata update operation per invocation' in w
assert 'bfs_metadata_only=yes' in w
assert 'GRUB_DISTRIBUTOR="BFSOS"' in i
assert 'GRUB_DISTRIBUTOR="BFSOS"' in k
for path in ('ports/core/pkgutils/bfs-pkgmk','scripts/install-bfs-menu-current.sh','ports/core/bfs-kernel-maintenance/bfs-kernel-maintenance'):
    subprocess.run(['bash','-n',str(r/path)],check=True)
print('r515 explicit metadata and GRUB branding source checks: PASS')
