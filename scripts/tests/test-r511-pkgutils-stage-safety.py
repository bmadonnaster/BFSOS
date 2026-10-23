#!/usr/bin/env python3
"""r511 guard tests: patched pkgmk, install privilege boundary and failure control."""
from pathlib import Path
import subprocess,tempfile,os
ROOT=Path(__file__).resolve().parents[2]
PORT=ROOT/'ports/core/pkgutils'
SUDO=ROOT/'ports/core/sudo/Pkgfile'
with tempfile.TemporaryDirectory() as td:
    d=Path(td)
    upstream=Path(os.environ.get('BFS_PKGUTILS_SRC', ''))
    # Source supplied by maintainer separately; fall back to patch static check.
    files=['bfs-pkgmk-split-phases.patch.txt','bfs-pkgmk-universal-build.patch.txt','bfs-pkgmk-stage-safety.patch.txt']
    assert all((PORT/x).is_file() for x in files)
    patch=(PORT/files[-1]).read_text()
    assert 'make() { _bfs_universal_make "$@"; }' in patch
    assert 'timeout --signal=TERM' in patch
    assert 'fakeroot -- make "$@"' in patch
    assert 'local bfs_build_rc=$?' in patch
    assert 'if ! (set -e -x; build)' in patch  # removed by new patch
    assert 'BFSOS sudo mandatory payload' in patch
    assert 'BFSOS rsync mandatory executable missing' in patch
    assert './configure "${build_opt[@]}" || return 1' in SUDO.read_text()
    for f in [PORT/'Pkgfile',PORT/'bfs-pkgmk',SUDO]:
        subprocess.run(['bash','-n',str(f)],check=True)
    # Dynamic Bash errexit regression. Invoking a function as condition of !
    # suppresses errexit; running it as a plain command in a subshell catches it.
    script='''
    build() { false; echo SHOULD_NOT_APPEAR; }
    (set -e; build)
    code=$?
    [ "$code" -ne 0 ] || exit 19
    '''
    r=subprocess.run(['bash','-c',script],capture_output=True,text=True)
    assert r.returncode==0, r.stderr
    assert 'SHOULD_NOT_APPEAR' not in r.stdout
print('r511 staging safety source and Bash error-propagation checks: PASS')
