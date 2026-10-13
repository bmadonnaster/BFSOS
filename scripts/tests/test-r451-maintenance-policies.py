#!/usr/bin/env python3
"""Offline regression checks for BFSOS r451 maintenance release planning."""
from pathlib import Path
import importlib.util
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('bfs_updater_r451', ROOT/'scripts/bfs-port-updater.py')
u = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = u
spec.loader.exec_module(u)

util = (ROOT/'ports/core/util-linux/Pkgfile').read_text()
assert '# Depends on: libcap-ng' in util
assert '--enable-runuser' in util and '--enable-setpriv' in util
base = (ROOT/'bootstrap.sh').read_text()
basepkg = base.split('basepkg="', 1)[1].split('"',1)[0].split()
assert basepkg.index('libcap-ng') < basepkg.index('util-linux')
assert 'libcap-ng' not in base.split('toolchainpkg="',1)[1].split('"',1)[0].split()

pam = (ROOT/'ports/core/linux-pam/Pkgfile').read_text()
assert 'release=3' in pam
assert 'system-session \\\n        runuser' in pam
for f in ('other','system-auth','system-account','system-password','system-session','runuser'):
    assert (ROOT/'ports/core/linux-pam'/f).is_file()

assert 'post_build' not in (ROOT/'ports/gnome/nautilus/Pkgfile').read_text()
assert 'glib-compile-schemas' in (ROOT/'ports/gnome/nautilus/post-install').read_text()
assert 'tar.gz/download' not in (ROOT/'ports/opt/fdk-aac/Pkgfile').read_text()

assert u.VERSION_LOCK_GROUPS['sqlite'] == {'core/sqlite','compat-32/sqlite3-32'}
assert len(u.VERSION_LOCK_GROUPS['gstreamer']) == 8
assert u._build_rank('opt/gstreamer') < u._build_rank('opt/gst-plugins-base') < u._build_rank('opt/gst-plugins-good')
assert u._build_rank('compat-32/gstreamer-32') < u._build_rank('compat-32/gst-plugins-base-32')

# A coordinated review cannot allow just one package of a release train.
with tempfile.TemporaryDirectory() as td:
    root = Path(td)
    for rel, ver in [('core/sqlite','3.53.4'),('compat-32/sqlite3-32','3.53.4')]:
        p = root/rel/'Pkgfile'
        p.parent.mkdir(parents=True)
        p.write_text(f'name={p.parent.name}\nversion={ver}\nrelease=1\n')
    rows = [u.Candidate('core/sqlite','sqlite','3.53.4','3.54.0','1','1','review','test','REVIEW','test',False),
            u.Candidate('compat-32/sqlite3-32','sqlite3-32','3.53.4','3.54.0','1','1','review','test','REVIEW','test',False)]
    assert 'partial selection refused' in u._selection_group_error(rows, {'core/sqlite'}, root)
    assert not u._selection_group_error(rows, {'core/sqlite','compat-32/sqlite3-32'}, root)

print('r451 maintenance dependency, PAM, source, and coordinated-selection policies: PASS')
