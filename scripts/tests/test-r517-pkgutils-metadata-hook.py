#!/usr/bin/env python3
"""r517 offline contract: pkgutils post-build metadata and fakeroot hook."""
from pathlib import Path
import re, subprocess, tempfile
p=Path(__file__).resolve().parents[2]/'ports/core/pkgutils'
s=(p/'Pkgfile').read_text()
patch=(p/'bfs-pkgmk-universal-build.patch.txt').read_text()
assert 'release=52' in s
assert 'bfs_archive_metadata() {' in s
assert 'bfs_archive_metadata || { error "Archive metadata hook failed"; exit 1; }' in patch
assert patch.index('chown -hR 0:0 "$PKG"') < patch.index('bfs_archive_metadata ||')
assert patch.index('bfs_archive_metadata ||') < patch.index('elif [ "${BFS_PKG_STAGE_ONLY:-no}" = yes ]')
post=s.split('post_build() {',1)[1].split('\n}',1)[0]
assert not re.search(r'install[^\n]*\s-o\s+(?:0|82)',post)
assert 'chmod 0755 "$PKG/var/cache"' in post
assert 'chmod 0775 "$PKG/var/cache/ccache"' in post
# Script-level simulation: chown calls target only the expected paths,
# missing or symlinked special paths fail nonzero before publication.
with tempfile.TemporaryDirectory() as d:
    r=Path(d)
    paths=['var/cache/ccache','var/cache/pkg/sources','var/cache/pkg/packages',
           'var/cache/pkg/build-work','var/cache/pkg/build-work-disk',
           'var/lib/pkgmk/build-times.log']
    for x in paths[:-1]: (r/x).mkdir(parents=True,exist_ok=True)
    (r/paths[-1]).parent.mkdir(parents=True, exist_ok=True)
    (r/paths[-1]).touch()
    bash='''source "$1"
PKG="$2"
export LOG="$3"
chown() { printf '%s\n' "$2" >> "$LOG"; }
bfs_archive_metadata
'''
    log=r/'result'; subprocess.run(['bash','-c',bash,'bash',str(p/'Pkgfile'),str(r),str(log)],check=True)
    assert log.read_text().splitlines()==[str(r/x) for x in paths]
    (r/paths[0]).rmdir(); (r/paths[0]).symlink_to('/tmp')
    result=subprocess.run(['bash','-c',bash,'bash',str(p/'Pkgfile'),str(r),str(log)])
    assert result.returncode!=0
subprocess.run(['bash','-n',str(p/'Pkgfile')],check=True)
print('r517 pkgutils metadata hook contract: PASS')
