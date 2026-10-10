#!/usr/bin/env python3
"""Offline regressions for r435 updater repairs."""
import importlib.util
import pathlib
import os
import sys
from unittest.mock import patch
root = pathlib.Path(__file__).resolve().parents[2]
def load(name, file):
    spec=importlib.util.spec_from_file_location(name, str(root/'scripts'/file))
    m=importlib.util.module_from_spec(spec)
    sys.modules[name]=m
    spec.loader.exec_module(m)
    return m
check=load('bfs_r435_check','checkupdate.py')
up=load('bfs_r435_up','bfs-port-updater.py')
class FakeHttp:
    def get(self,url):
        assert url=='https://www.sqlite.org/download.html'
        return '<a href="sqlite-autoconf-3540000.tar.gz">sqlite-autoconf-3540000.tar.gz</a>'
    def exists(self,url):
        return (url.endswith('sqlite-autoconf-3530400.tar.gz'), '')
for rel in ('core/sqlite','compat-32/sqlite3-32'):
    port=check.Port(root/'ports'/rel/'Pkgfile',rel,rel.split('/')[-1], '3.53.4', ['https://www.sqlite.org/2026/sqlite-autoconf-3530400.tar.gz'])
    assert check.sqlite_release_page(port,FakeHttp())[0]=='3.54.0'
    class NotFound(FakeHttp):
        def exists(self,url): return (False,'404')
    assert check.sqlite_release_page(port,NotFound())[0] is None
for rel in ('opt/lcms2','compat-32/lcms2-32'):
    raw=(root/'ports'/rel/'Pkgfile').read_text()
    assert 'lcms${version}' in raw
    version='2.19.1'
    assert raw.split('source=(',1)[1].split(')',1)[0].replace('${version}',version).replace('$version',version)=='https://github.com/mm2/Little-CMS/releases/download/lcms2.19.1/lcms2-2.19.1.tar.gz'
for target,series in [('6.30.1','6.30'),('6.31.0','6.31'),('6.32.0','6.32')]:
    meta=up.PortMeta.__new__(up.PortMeta)
    meta.rel='plasma/attica';meta.name='attica';meta.version='6.30.0'
    meta.sources=['https://download.kde.org/stable/frameworks/6.30/attica-6.30.0.tar.xz']
    assert up.candidate_source_url(meta,target)==f'https://download.kde.org/stable/frameworks/{series}/attica-{target}.tar.xz'
print('PASS r435 source/worker regression')
