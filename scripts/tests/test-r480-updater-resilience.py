#!/usr/bin/env python3
"""Offline regression for kernel protection, exact lookup, report retry and mirror mappings."""
import csv
import importlib.util
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
def load(name, file):
    spec=importlib.util.spec_from_file_location(name, ROOT/'scripts'/file)
    obj=importlib.util.module_from_spec(spec)
    sys.modules[name]=obj
    spec.loader.exec_module(obj)
    return obj
u=load('bfs_updater_r480','bfs-port-updater.py')
c=load('bfs_checker_r480','checkupdate.py')
with tempfile.TemporaryDirectory() as td:
    d=Path(td)
    for rel in ('core/linux', 'core/linux-lts', 'core/linux-headers', 'core/expat', 'compat-32/expat-32', 'opt/expat'):
        p=d/rel/'Pkgfile';p.parent.mkdir(parents=True,exist_ok=True);p.write_text('name='+p.parent.name+'\nversion=1\nrelease=1\n')
    assert u.find_named_ports(d,'core/expat')==['core/expat']
    assert u.find_named_ports(d,'expat')==['core/expat','opt/expat']
    assert u.find_named_ports(d,'expat-32')==['compat-32/expat-32']
    assert not u.find_named_ports(d,'missing')
    for rel in ('core/linux','core/linux-lts','core/linux-headers'):
        item=SimpleNamespace(port=rel, status='UPDATE',reason='normal',source_label='kernel.org',policy='kernel')
        assert not u.default_update_checked(item)
        u.protect_kernel_candidates([item]);assert item.status=='REVIEW' and not item.selected
    report=d/'problems.tsv'
    report.write_text('status\ttree\tport\nFETCH-ERROR\tcore\tcore/expat\nUNVERIFIABLE\tcompat-32\tcompat-32/expat-32\nFETCH-ERROR\topt\topt/none\n')
    assert u.failed_ports_from_report(report,d)==['core/expat']
    assert u.failed_ports_from_report(report,d,True)==['compat-32/expat-32','core/expat']
    conf=d/'pkgmk.conf'
    conf.write_text('''PKGMK_SOURCE_FALLBACKS=(\n "https://xorg.freedesktop.org/releases/|https://www.x.org/archive/"\n)\nPKGMK_SOURCE_FLAT_FALLBACKS=( "https://mirror.example/distfiles" )\n''')
    urls=c.source_mirror_candidates('https://xorg.freedesktop.org/releases/individual/lib/libX11.tar.xz',conf)
    assert urls==['https://www.x.org/archive/individual/lib/libX11.tar.xz','https://mirror.example/distfiles/libX11.tar.xz'],urls
    # No shell execution or environment expansion in mirror configuration.
    conf.write_text('PKGMK_SOURCE_FLAT_FALLBACKS=( "$(touch /tmp/bfs-r480-no-exec)" )\n')
    assert not c.source_mirror_candidates('https://example.org/a.tar.xz',conf)
print('PASS r480 updater kernel, port lookup, selective retry, and fallback mirrors')

# Host-specific TLS 1.2 fallback keeps certificate checks enabled.
from types import SimpleNamespace as Result
seen=[]
def fake_curl(args, **kwargs):
    seen.append(args)
    if '--tls-max' in args:
        return Result(returncode=0, stderr='', stdout='ok')
    return Result(returncode=35, stderr='TLS reset', stdout='')
with patch.object(c.subprocess, 'run', side_effect=fake_curl):
    cp=c.HttpCache(20)._fetch(['curl', '--fail', 'https://xorg.freedesktop.org/a'])
assert cp.returncode==0 and len(seen)==2
assert '--tlsv1.2' in seen[-1] and '--tls-max' in seen[-1]
assert '-k' not in seen[-1] and '--insecure' not in seen[-1]
print('PASS r480 TLS fallback remains certificate verified')
with tempfile.TemporaryDirectory() as td:
    d=Path(td)
    for rel in ('core/expat','compat-32/expat-32','opt/other'):
        pkg=d/rel/'Pkgfile';pkg.parent.mkdir(parents=True,exist_ok=True)
        pkg.write_text('name='+pkg.parent.name+'\nversion=2.8.5\nrelease=1\n')
    rows=[u.Candidate('compat-32/expat-32','expat-32','2.8.5','2.9.0','1','1','review','test','REVIEW','test',False),
          u.Candidate('opt/other','other','1','2','1','1','review','test','REVIEW','test',False)]
    allowed, blocked=u.isolate_blocked_update_groups(rows, {'compat-32/expat-32','opt/other'},d)
    assert allowed=={'opt/other'},(allowed,blocked)
    assert blocked['compat-32/expat-32'].startswith('BLOCKED:'),blocked
print('PASS r480 blocked expat-32 does not cancel independent updates')
