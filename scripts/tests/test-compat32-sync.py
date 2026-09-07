#!/usr/bin/env python3
from pathlib import Path
import re
import subprocess

ROOT=Path(__file__).resolve().parents[2]
compat=ROOT/'ports'/'compat-32'
pkgfiles=sorted(compat.glob('*/Pkgfile'))
assert len(pkgfiles)==170, len(pkgfiles)
assert all((p.parent/'.32bit').is_file() for p in pkgfiles)
for p in pkgfiles:
    s=p.read_text(errors='replace')
    assert not re.search(r'(?m)^build\s*\(\)\s*\{', s), p
    assert re.search(r'(?m)^pkg_build\s*\(\)\s*\{', s), p
    assert '-m32' not in s, p
    assert 'gnux32' not in s, p
    cp=subprocess.run(['bash','-n',str(p)],capture_output=True,text=True)
    assert cp.returncode==0,(p,cp.stderr)

conf=(ROOT/'ports/core/pkgutils/pkgmk.conf').read_text()
assert 'BFS_MULTILIB_HOST="i686-pc-linux-gnu"' in conf
assert 'PKG_CONFIG_LIBDIR="/usr/lib32/pkgconfig:/usr/share/pkgconfig"' in conf
assert 'export CFLAGS="-O2 -march=i686 -pipe -m32"' in conf

cp=subprocess.run([str(ROOT/'scripts/multilibvercheck.sh')],capture_output=True,text=True)
assert cp.returncode==0, cp.stdout+cp.stderr
assert 'matched=151 special=19 drift=0 unexplained=0' in cp.stdout, cp.stdout
print('compat-32 synchronization regression: PASS (170 ports; 151 paired; 19 special)')
