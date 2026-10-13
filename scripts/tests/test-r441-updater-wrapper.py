#!/usr/bin/env python3
"""Offline smoke tests for r441 crash and metadata safety fixes."""
import ast
import importlib.util
import pathlib
import subprocess
from unittest.mock import patch

ROOT = pathlib.Path(__file__).resolve().parents[2]
UPDATER = ROOT / 'scripts/bfs-port-updater.py'
WRAPPER = ROOT / 'ports/core/pkgutils/bfs-pkgmk'
src = UPDATER.read_text()
assert src.count('installed = run(["pkginfo", "-i"], capture=True)') == 2
assert src.count('installed.stdout.splitlines()') == 2
ast.parse(src)
with patch('subprocess.run') as fake:
    fake.return_value = subprocess.CompletedProcess(['pkginfo', '-i'], 0, 'attica 6.30.0-1\n', '')
    spec = importlib.util.spec_from_file_location('bfs_updater_r441', UPDATER)
    mod = importlib.util.module_from_spec(spec)
    import sys
    sys.modules[spec.name] = mod
    spec.loader.exec_module(mod)
    out = mod.run(['pkginfo', '-i'], capture=True)
    assert any(line.split()[:1] == ['attica'] for line in out.stdout.splitlines())
    assert fake.call_args.kwargs['stdout'] == subprocess.PIPE
assert 'crash-{stamp}-{os.getpid()}.log' in src
w = WRAPPER.read_text()
assert 'bfs_sync_metadata' in w and 'bfs_stage' in w
assert 'chown -R pkgmk:pkgmk "$bfs_stage"' in w
assert 'for bfs_meta in .md5sum .footprint .signature' in w
assert 'if ! bfs_sync_metadata; then' in w
subprocess.run(['sh', '-n', str(WRAPPER)], check=True)
print('PASS: r441 updater capture, crash logging, wrapper staging and shell syntax')
