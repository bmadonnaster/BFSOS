#!/usr/bin/env python3
from __future__ import annotations
import importlib.util, os, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('bfs_port_updater_r400', ROOT/'scripts/bfs-port-updater.py')
u = importlib.util.module_from_spec(spec); sys.modules[spec.name] = u; spec.loader.exec_module(u)

# Default follows all available logical CPUs.
with tempfile.TemporaryDirectory() as td:
    d=Path(td); (d/'Pkgfile').write_text('name=x\nversion=1\nrelease=1\n')
    old1,old2=os.environ.pop('BFS_BUILD_JOBS',None),os.environ.pop('JOBS',None)
    try:
        assert u.read_build_jobs(d, 32) == (32,'default-all-cpus')
    finally:
        if old1 is not None: os.environ['BFS_BUILD_JOBS']=old1
        if old2 is not None: os.environ['JOBS']=old2

# Explicit user setting is preserved.
with tempfile.TemporaryDirectory() as td:
    d=Path(td); (d/'Pkgfile').write_text('name=x\nversion=1\nrelease=1\n')
    old=os.environ.get('BFS_BUILD_JOBS'); os.environ['BFS_BUILD_JOBS']='12'
    try: assert u.read_build_jobs(d,32)==(12,'user-override')
    finally:
        if old is None: os.environ.pop('BFS_BUILD_JOBS',None)
        else: os.environ['BFS_BUILD_JOBS']=old

# Port cap beats the global/default job count.
with tempfile.TemporaryDirectory() as td:
    d=Path(td); (d/'Pkgfile').write_text('name=x\nversion=1\nrelease=1\nbuild_jobs=8\n')
    old=os.environ.get('BFS_BUILD_JOBS'); os.environ['BFS_BUILD_JOBS']='32'
    try: assert u.read_build_jobs(d,32)==(8,'port-override')
    finally:
        if old is None: os.environ.pop('BFS_BUILD_JOBS',None)
        else: os.environ['BFS_BUILD_JOBS']=old

# sudo env launch carries the resolved policy explicitly.
old_which=u.shutil.which
try:
    u.shutil.which=lambda name:'/usr/bin/bfs-pkgmk' if name=='bfs-pkgmk' else None
    cmd=u.pkgmk_build_command('disk',32)
    assert cmd[:2]==['sudo','env']
    assert 'BFS_PKG_BUILD_WORK=disk' in cmd
    assert 'BFS_PKG_BUILD_JOBS=32' in cmd
    assert 'JOBS=32' in cmd
    assert 'MAKEFLAGS=-j32' in cmd
    assert 'CMAKE_BUILD_PARALLEL_LEVEL=32' in cmd
finally: u.shutil.which=old_which

# MLFS Chapter 3 package inventory parser handles the canonical heading shape.
inv=u.parse_package_inventory('<h4>Acl (2.4.0) - 400 KB:</h4><h4>Systemd (261.3) - 15 MB:</h4>')
assert inv['acl']=='2.4.0' and inv['systemd']=='261.3', inv

# Curated authority: systemd is MLFS-managed; an arbitrary overlap is not.
def meta(rel,name):
    return u.PortMeta(rel=rel,path=Path('/tmp')/rel,name=name,version='1',release='1',sources=[])
idx={'mlfs-dev': {'systemd':'261.3','dejagnu':'1.6.3'}, 'blfs-dev': {'rustc':'1.90.0'}}
assert u.lookup_mlfs_authoritative(meta('core/systemd','systemd'),idx)==('mlfs-dev','261.3')
assert u.lookup_mlfs_authoritative(meta('opt/dejagnu','dejagnu'),idx) is None
assert u.lookup_explicit_dev_authority(meta('opt/rustc','rustc'),idx)==('blfs-dev','1.90.0')

# Chromium custom build must pass JOBS explicitly to Ninja.
chromium=(ROOT/'ports/opt/chromium/Pkgfile').read_text()
assert 'ninja -j"${JOBS:-1}" -C out/Release' in chromium
print('r400 updater regressions: PASS')
