#!/usr/bin/env python3
"""Regression: fallback network pool honors CPU/job settings, not a 12-worker cap."""
from __future__ import annotations
import ast
from pathlib import Path
import concurrent.futures
from unittest.mock import patch
p = Path(__file__).resolve().parents[1] / 'bfs-port-updater.py'
src = p.read_text()
mod = ast.parse(src)
f = next(x for x in mod.body if isinstance(x, ast.FunctionDef) and x.name == 'prefetch_fallback_references')
# Test actual function without network by using fake dependencies and objects.
ns = {'__builtins__': __builtins__, 'concurrent': concurrent, 'KERNEL_PORTS': set(),
      'lookup_mlfs_authoritative': lambda m,i: None,
      'crux_reference_version': lambda m,t: '6.31.0',
      'arch_reference': lambda m,t: type('Arch', (), {'verified': True})(),
      'ArchReference': lambda **kwargs: None, 'sys': __import__('sys')}
exec(compile(ast.fix_missing_locations(ast.Module(body=[ast.ImportFrom(module="__future__", names=[ast.alias(name="annotations")], level=0), f], type_ignores=[])),str(p),'exec'),ns)
class Meta:
    def __init__(self,i): self.name=f'port{i}';self.rel=f'opt/port{i}'
metas=[Meta(i) for i in range(178)]
for requested,expected in ((32,32),(12,12),(2,2),(250,178)):
    actual=[]
    class TrackingExecutor(concurrent.futures.ThreadPoolExecutor):
        def __init__(self,*args,**kw):
            actual.append(kw.get('max_workers'))
            super().__init__(*args,**kw)
    with patch.object(concurrent.futures,'ThreadPoolExecutor',TrackingExecutor):
        data=ns['prefetch_fallback_references'](metas,{},5,requested,[])
    assert actual == [expected],(requested,actual)
    assert len(data)==178
print('r439 fallback worker cap regression: PASS')
