#!/usr/bin/env python3
from __future__ import annotations
import importlib.util, os, sys, tempfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('bfs_port_updater_r404', ROOT/'scripts/bfs-port-updater.py')
u=importlib.util.module_from_spec(spec); sys.modules[spec.name]=u; spec.loader.exec_module(u)

# Large-build family classification covers native and compat-32.
with tempfile.TemporaryDirectory() as td:
    d=Path(td); (d/'Pkgfile').write_text('name=llvm-32\nversion=23.1.2\nrelease=1\n')
    assert u.is_known_large_build(d,'compat-32/llvm-32')
with tempfile.TemporaryDirectory() as td:
    d=Path(td); (d/'Pkgfile').write_text('name=mesa-32\nversion=26.2.4\nrelease=1\n')
    assert u.is_known_large_build(d,'compat-32/mesa-32')
with tempfile.TemporaryDirectory() as td:
    d=Path(td); (d/'Pkgfile').write_text('name=zlib-32\nversion=1.3\nrelease=1\n')
    assert not u.is_known_large_build(d,'compat-32/zlib-32')

# Backend selection: large -> disk; small healthy -> tmpfs; low tmpfs -> disk.
orig_pf=u.build_work_preflight
try:
    def fake_pf(backend, min_bytes=512*1024*1024):
        free=(64 if backend=='tmpfs' else 900)*1024**3
        return {'backend':backend,'root':Path('/tmp/'+backend),'probe':Path('/tmp'),
                'free_bytes':free,'free_inodes':100000,'fstype':'tmpfs' if backend=='tmpfs' else 'xfs',
                'disk_is_ram':False,'ok':True}
    u.build_work_preflight=fake_pf
    with tempfile.TemporaryDirectory() as td:
        d=Path(td); (d/'Pkgfile').write_text('name=llvm-32\nversion=1\nrelease=1\n')
        assert u.select_build_work_backend(d,'compat-32/llvm-32')[0]=='disk'
    with tempfile.TemporaryDirectory() as td:
        d=Path(td); (d/'Pkgfile').write_text('name=zlib-32\nversion=1\nrelease=1\n')
        assert u.select_build_work_backend(d,'compat-32/zlib-32')[0]=='tmpfs'
    def low_pf(backend, min_bytes=512*1024*1024):
        free=(5 if backend=='tmpfs' else 900)*1024**3
        return {'backend':backend,'root':Path('/tmp/'+backend),'probe':Path('/tmp'),
                'free_bytes':free,'free_inodes':100000,'fstype':'tmpfs' if backend=='tmpfs' else 'xfs',
                'disk_is_ram':False,'ok':True}
    u.build_work_preflight=low_pf
    with tempfile.TemporaryDirectory() as td:
        d=Path(td); (d/'Pkgfile').write_text('name=zlib-32\nversion=1\nrelease=1\n')
        assert u.select_build_work_backend(d,'compat-32/zlib-32')[0]=='disk'
finally:
    u.build_work_preflight=orig_pf

# Harfbuzz-style version-only SONAME payload changes are safe footprint refreshes.
fp='''=======> ERROR: Footprint mismatch found:\nMISSING   lrwxrwxrwx      root/root       usr/lib32/libharfbuzz.so.0 -> libharfbuzz.so.0.61450.0\nMISSING   -rwxr-xr-x      root/root       usr/lib32/libharfbuzz.so.0.61450.0\nNEW       lrwxrwxrwx      root/root       usr/lib32/libharfbuzz.so.0 -> libharfbuzz.so.0.61460.0\nNEW       -rwxr-xr-x      root/root       usr/lib32/libharfbuzz.so.0.61460.0\n=======> ERROR: Building failed\n'''
ok, lines=u.safe_versioned_library_footprint_change(fp)
assert ok and len(lines)==4
# Unexpected executable addition must stay review.
fp2='''=======> ERROR: Footprint mismatch found:\nNEW       -rwxr-xr-x      root/root       usr/bin/surprise\n=======> ERROR: Building failed\n'''
assert not u.safe_versioned_library_footprint_change(fp2)[0]

# Dependency ordering puts selected gstreamer-32 before gst-plugins-base-32.
C=u.Candidate
with tempfile.TemporaryDirectory() as td:
    pr=Path(td)
    (pr/'compat-32/gstreamer-32').mkdir(parents=True); (pr/'compat-32/gstreamer-32/Pkgfile').write_text('# Depends on: glib-32\nname=gstreamer-32\n')
    (pr/'compat-32/gst-plugins-base-32').mkdir(parents=True); (pr/'compat-32/gst-plugins-base-32/Pkgfile').write_text('# Depends on: gstreamer-32\nname=gst-plugins-base-32\n')
    a=C('compat-32/gst-plugins-base-32','gst-plugins-base-32','1','2','1','1','review','x','REVIEW','x',True)
    b=C('compat-32/gstreamer-32','gstreamer-32','1','2','1','1','review','x','REVIEW','x',True)
    ordered=u.order_candidates_for_build([a,b],{a.port,b.port},pr)
    assert [x.name for x in ordered[:2]]==['gstreamer-32','gst-plugins-base-32']

# Checker policy text includes compat-32 stable-line guards.
chk=(ROOT/'scripts/checkupdate.py').read_text()
assert '"compat-32/libva-32": 1' in chk
assert '"compat-32/pango-32": {"1.90.0"}' in chk
assert '"compat-32/gstreamer-32"' in chk

# checkupdate compat-32 guards reject the live false development/ABI candidates.
spec2=importlib.util.spec_from_file_location('checkupdate_r404', ROOT/'scripts/checkupdate.py')
cu=importlib.util.module_from_spec(spec2); sys.modules[spec2.name]=cu; spec2.loader.exec_module(cu)
def port(rel,name,version,source='https://example.invalid/x'):
    return cu.Port(Path('/tmp')/rel,rel,name,version,[source])
assert not cu.candidate_allowed('1.29.2','1.28.7',port('compat-32/gstreamer-32','gstreamer-32','1.28.7'),'directory')
assert not cu.candidate_allowed('4.1-video','2.24.1',port('compat-32/libva-32','libva-32','2.24.1'),'git-tags')
assert not cu.candidate_allowed('1.90.0','1.58.2',port('compat-32/pango-32','pango-32','1.58.2'),'gnome-cache')
assert not cu.candidate_allowed('4.7.2','3.9.7',port('compat-32/libtiff4-32','libtiff4-32','3.9.7'),'directory')

# GNOME compat target source derives the target series rather than retaining 1.58.
m=u.PortMeta(rel='compat-32/pango-32', path=Path('/tmp/p'), name='pango-32', version='1.58.2', release='3', sources=['https://download.gnome.org/sources/pango/1.58/pango-1.58.2.tar.xz'])
assert u.candidate_source_url(m,'1.60.0') == 'https://download.gnome.org/sources/pango/1.60/pango-1.60.0.tar.xz'

print('r404 updater regressions: PASS')
