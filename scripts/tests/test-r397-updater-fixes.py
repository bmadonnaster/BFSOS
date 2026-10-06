#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import sys
import tempfile
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


u = load('bfs_port_updater_r397', ROOT/'scripts/bfs-port-updater.py')


def cand(port: str, name: str):
    return u.Candidate(
        port=port, name=name, old='1', new='2', old_release='1', new_release='1',
        policy='review', source_label='test', status='REVIEW'
    )


# Port metadata must select the generic BFSOS backend, never a Chromium-specific path.
with tempfile.TemporaryDirectory() as td:
    d = Path(td)
    (d/'Pkgfile').write_text('name=demo\nversion=1\nrelease=1\nbuild_work=disk\n')
    assert u.read_build_work_backend(d) == 'disk'
    (d/'Pkgfile').write_text('name=demo\nversion=1\nrelease=1\n')
    assert u.read_build_work_backend(d) == 'tmpfs'
    (d/'Pkgfile').write_text('name=demo\nversion=1\nrelease=1\nbuild_work="disk"\n')
    assert u.read_build_work_backend(d) == 'disk'


# Build invocation honors build_work=disk and uses bfs-pkgmk when available.
with tempfile.TemporaryDirectory() as td:
    ports = Path(td)/'ports'
    d = ports/'opt'/'demo'
    d.mkdir(parents=True)
    (d/'Pkgfile').write_text('name=demo\nversion=2\nrelease=1\nbuild_work=disk\n')
    calls = []
    old_run = u.run_build_streaming
    old_preflight = u.build_work_preflight
    old_which = u.shutil.which
    old_log_root = u.LOG_ROOT
    try:
        u.LOG_ROOT = Path(td)/'logs'
        u.build_work_preflight = lambda backend: {
            'backend': backend, 'root': Path('/var/cache/pkg/build-work-disk'),
            'probe': Path('/var/cache/pkg'), 'free_bytes': 10*1024**3,
            'free_inodes': 100000, 'ok': True,
        }
        u.shutil.which = lambda name: '/usr/bin/bfs-pkgmk' if name == 'bfs-pkgmk' else None
        def fake_run(cmd, **kwargs):
            calls.append(cmd)
            return SimpleNamespace(returncode=0, stdout='ok\n', stderr='')
        u.run_build_streaming = lambda cmd, cwd, log_path, header: fake_run(cmd, cwd=cwd)
        results = {'opt/demo': 'UPDATED'}
        u.build_selected([cand('opt/demo','demo')], {'opt/demo'}, ports, False, results)
        assert results['opt/demo'] == 'BUILT'
        assert calls, calls
        assert 'BFS_PKG_BUILD_WORK=disk' in calls[0], calls[0]
        assert '/usr/bin/bfs-pkgmk' in calls[0], calls[0]
    finally:
        u.run_build_streaming = old_run
        u.build_work_preflight = old_preflight
        u.shutil.which = old_which
        u.LOG_ROOT = old_log_root


# Missing metadata keeps the existing tmpfs default.
with tempfile.TemporaryDirectory() as td:
    ports = Path(td)/'ports'
    d = ports/'opt'/'plain'
    d.mkdir(parents=True)
    (d/'Pkgfile').write_text('name=plain\nversion=2\nrelease=1\n')
    calls = []
    old_run = u.run_build_streaming
    old_preflight = u.build_work_preflight
    old_which = u.shutil.which
    old_log_root = u.LOG_ROOT
    try:
        u.LOG_ROOT = Path(td)/'logs'
        u.build_work_preflight = lambda backend: {
            'backend': backend, 'root': Path('/var/cache/pkg/build-work'),
            'probe': Path('/var/cache/pkg/build-work'), 'free_bytes': 10*1024**3,
            'free_inodes': 100000, 'ok': True,
        }
        u.shutil.which = lambda name: '/usr/bin/bfs-pkgmk'
        def fake_run(cmd, **kwargs):
            calls.append(cmd)
            return SimpleNamespace(returncode=0, stdout='', stderr='')
        u.run_build_streaming = lambda cmd, cwd, log_path, header: fake_run(cmd, cwd=cwd)
        results = {'opt/plain': 'UPDATED'}
        u.build_selected([cand('opt/plain','plain')], {'opt/plain'}, ports, False, results)
        assert 'BFS_PKG_BUILD_WORK=tmpfs' in calls[0], calls[0]
    finally:
        u.run_build_streaming = old_run
        u.build_work_preflight = old_preflight
        u.shutil.which = old_which
        u.LOG_ROOT = old_log_root


# ENOSPC is infrastructure failure and aborts every not-yet-attempted build.
with tempfile.TemporaryDirectory() as td:
    ports = Path(td)/'ports'
    for name in ('a','b','c'):
        d = ports/'opt'/name
        d.mkdir(parents=True)
        (d/'Pkgfile').write_text(f'name={name}\nversion=2\nrelease=1\n')
    calls = []
    old_run = u.run_build_streaming
    old_preflight = u.build_work_preflight
    old_which = u.shutil.which
    old_log_root = u.LOG_ROOT
    try:
        u.LOG_ROOT = Path(td)/'logs'
        u.build_work_preflight = lambda backend: {
            'backend': backend, 'root': Path('/var/cache/pkg/build-work'),
            'probe': Path('/var/cache/pkg/build-work'), 'free_bytes': 10*1024**3,
            'free_inodes': 100000, 'ok': True,
        }
        u.shutil.which = lambda name: '/usr/bin/bfs-pkgmk'
        def fake_run(cmd, **kwargs):
            calls.append(cmd)
            return SimpleNamespace(returncode=1, stdout='tar: Write failed: No space left on device\n', stderr='')
        u.run_build_streaming = lambda cmd, cwd, log_path, header: fake_run(cmd, cwd=cwd)
        cs = [cand(f'opt/{x}',x) for x in ('a','b','c')]
        results = {c.port:'UPDATED' for c in cs}
        u.build_selected(cs, set(results), ports, False, results)
        assert len(calls) == 1, calls
        assert results['opt/a'].startswith('INFRASTRUCTURE FAILED:'), results
        assert results['opt/b'].startswith('BLOCKED: build workspace out of space'), results
        assert results['opt/c'].startswith('BLOCKED: build workspace out of space'), results
    finally:
        u.run_build_streaming = old_run
        u.build_work_preflight = old_preflight
        u.shutil.which = old_which
        u.LOG_ROOT = old_log_root


# Preflight-full workspaces never launch pkgmk.
with tempfile.TemporaryDirectory() as td:
    ports = Path(td)/'ports'
    d = ports/'opt'/'full'
    d.mkdir(parents=True)
    (d/'Pkgfile').write_text('name=full\nversion=2\nrelease=1\n')
    old_run = u.run_build_streaming
    old_preflight = u.build_work_preflight
    try:
        u.build_work_preflight = lambda backend: {
            'backend': backend, 'root': Path('/var/cache/pkg/build-work'),
            'probe': Path('/var/cache/pkg/build-work'), 'free_bytes': 156*1024,
            'free_inodes': 100000, 'ok': False,
        }
        u.run_build_streaming = lambda *a, **k: (_ for _ in ()).throw(AssertionError('pkgmk must not run'))
        results = {'opt/full':'UPDATED'}
        u.build_selected([cand('opt/full','full')], {'opt/full'}, ports, False, results)
        assert results['opt/full'].startswith('BLOCKED: build workspace preflight failed')
    finally:
        u.run_build_streaming = old_run
        u.build_work_preflight = old_preflight

print('r397 updater regressions: PASS')
