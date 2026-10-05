#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod

u = load('bfs_port_updater_r396', ROOT/'scripts/bfs-port-updater.py')
m = load('bfs_maintained_port_updater_r396', ROOT/'scripts/bfs-maintained-port-updater.py')

# ESR overlap: FIREFOX_ESR can remain on the old supported train while
# FIREFOX_ESR_NEXT is the train BFSOS is already tracking.
esr = u.PortMeta('opt/firefox-esr', Path('/tmp/firefox-esr'), 'firefox-esr', '153.2.0esr', '4', [])
old_fetch = u.fetch_text
try:
    u.fetch_text = lambda url, timeout: '{"FIREFOX_ESR":"140.17.0esr","FIREFOX_ESR_NEXT":"153.4.0esr","LATEST_FIREFOX_VERSION":"157.0"}'
    ver, provider, source = u.special_browser_reference(esr, 1)
    assert ver == '153.4.0esr', (ver, provider, source)
    assert provider == 'Mozilla ESR'
    assert '153.4.0esr' in source
finally:
    u.fetch_text = old_fetch

# Source migrations with verified project identities.
lmdb = u.PortMeta('opt/lmdb', Path('/tmp/lmdb'), 'lmdb', '1.0.1', '3', ['https://github.com/LMDB/lmdb/archive/LMDB_1.0.1.tar.gz'])
assert u.candidate_source_url(lmdb, '1.0.2') == 'https://git.openldap.org/openldap/openldap/-/archive/LMDB_1.0.2/openldap-LMDB_1.0.2.tar.bz2'
cap = u.PortMeta('opt/libcap-ng', Path('/tmp/libcap-ng'), 'libcap-ng', '0.8.5', '1', ['https://people.redhat.com/sgrubb/libcap-ng/libcap-ng-0.8.5.tar.gz'])
assert u.candidate_source_url(cap, '0.9.4') == 'https://github.com/stevegrubb/libcap-ng/archive/refs/tags/v0.9.4.tar.gz'

# Never corrupt owner/host substrings while preserving $name templates.
mlt_before = m.Meta('mlt', '7.40.0', '7', '-p1', False, True, ['https://github.com/mltframework/mlt/releases/download/v7.40.0/mlt-7.40.0.tar.gz'])
mlt_text = '''name=mlt\nversion=7.42.0\nrelease=1\nsource=(https://github.com/mltframework/$name/releases/download/v$version/$name-$version.tar.gz)\n'''
rewritten = m.rewrite_primary_source_from_handoff(
    mlt_text, mlt_before, '7.42.0',
    'https://github.com/mltframework/mlt/releases/download/v7.42.0/mlt-7.42.0.tar.gz')
assert 'mltframework/$name' in rewritten
assert '$nameframework' not in rewritten

discord_before = m.Meta('discord', '1.0.160', '1', '-p1', False, True, ['https://dl.discordapp.net/apps/linux/1.0.160/discord-1.0.160.tar.gz'])
discord_text = '''name=discord\nversion=1.0.161\nrelease=1\nsource=(https://dl.discordapp.net/apps/linux/$version/$name-$version.tar.gz)\n'''
rewritten = m.rewrite_primary_source_from_handoff(
    discord_text, discord_before, '1.0.161',
    'https://dl.discordapp.net/apps/linux/1.0.161/discord-1.0.161.tar.gz')
assert 'dl.discordapp.net' in rewritten
assert 'dl.$nameapp.net' not in rewritten

# Version-specific secondary sources must block an automatic version bump.
proposed = m.Meta('mlt', '7.42.0', '1', '-p1', False, True, [
    'https://github.com/mltframework/mlt/releases/download/v7.42.0/mlt-7.42.0.tar.gz',
    'https://www.linuxfromscratch.org/patches/blfs/svn/mlt-7.40.0-ffmpeg-9.0.patch',
])
stale = m.stale_versioned_remote_companions(
    proposed,
    'https://github.com/mltframework/mlt/releases/download/v7.42.0/mlt-7.42.0.tar.gz',
    '7.40.0', '7.42.0')
assert stale == ['https://www.linuxfromscratch.org/patches/blfs/svn/mlt-7.40.0-ffmpeg-9.0.patch']


# Failed build validation restores the exact pre-apply port directory.
import tempfile
with tempfile.TemporaryDirectory() as td_s:
    ports = Path(td_s) / 'ports'
    d = ports / 'opt/demo'
    d.mkdir(parents=True)
    (d/'Pkgfile').write_text('name=demo\nversion=1\nrelease=1\n')
    backup = u.snapshot_selected_ports({'opt/demo'}, ports)
    (d/'Pkgfile').write_text('name=demo\nversion=2\nrelease=1\n')
    results = {'opt/demo': 'BUILD FAILED (1); log=/tmp/demo.log'}
    u.rollback_failed_build_ports({'opt/demo'}, ports, results, backup)
    assert 'version=1' in (d/'Pkgfile').read_text()
    assert results['opt/demo'].startswith('ROLLED BACK: BUILD FAILED')

print('r396 updater regressions: PASS')
