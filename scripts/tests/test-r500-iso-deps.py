#!/usr/bin/env python3
"""Offline dependency-closure regression for minimal BFSOS ISO package seeds."""
from pathlib import Path
import collections, re
root=Path(__file__).resolve().parents[2]
iso=(root/'scripts/bfs-build-iso.sh').read_text()
seeds=re.search(r'iso_packages=\((.*?)\)',iso,re.S).group(1).split()
seeds+=['gobject-introspection','linux']
deps={}
for p in (root/'ports').glob('*/**/Pkgfile'):
    m=re.search(r'^# Depends on:[ \t]*(.*)$',p.read_text(errors='replace'),re.M)
    deps[p.parent.name]=m.group(1).split() if m else []
parents={n:None for n in seeds}
queue=collections.deque(seeds)
while queue:
    u=queue.popleft()
    for v in deps.get(u,[]):
        if v not in parents:
            parents[v]=u
            queue.append(v)
for pkg in ('lame','ffmpeg','imagemagick'):
    assert pkg not in parents, f'unexpected mandatory dependency in minimal ISO: {pkg}'
assert 'fastfetch' in seeds
ff=(root/'ports/opt/fastfetch/Pkgfile').read_text()
assert '# Optional: imagemagick' in ff
assert '-DENABLE_IMAGE_LOGO="$image_logo"' in ff
print(f'r500 minimal ISO dependency closure: PASS ({len(parents)} port names reachable)')
