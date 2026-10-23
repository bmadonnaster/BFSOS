#!/usr/bin/env python3
"""r513: tests packaging glue without touching live /var/cache/pkg."""
import re
import subprocess
import tempfile
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
PORT = ROOT / 'ports/core/pkgutils'
WRAP = (PORT / 'bfs-pkgmk').read_text()
PKGFILE = (PORT / 'Pkgfile').read_text()
assert 'release=51' in PKGFILE
assert 'fix_pkgmk_footprint_touch "$PKG/usr/bin/pkgmk"' in PKGFILE
assert 'bfs_saved_archive=' in WRAP
assert 'mv -- "$bfs_out" "$bfs_saved_archive"' in WRAP
assert 'mv -- "$bfs_saved_archive" "$bfs_previous_archive"' in WRAP
assert 'if [ "$status" -eq 0 ]; then\n    if ! bfs_sync_metadata;' in WRAP
assert 'cleanup_failed_archives' not in WRAP
assert 'if [ "$bfs_force_build" = yes ]' in WRAP
assert '[ "$bfs_metadata_only" != yes ]' in WRAP
subprocess.run(['sh','-n',str(PORT/'bfs-pkgmk')],check=True)
subprocess.run(['bash','-n',str(PORT/'Pkgfile')],check=True)
# Execute the actual footprint-fix function on a synthetic pkgmk.
match = re.search(r'(?ms)^fix_pkgmk_footprint_touch\(\) \{.*?^\}', PKGFILE)
assert match
with tempfile.TemporaryDirectory() as td:
    pkgmk = Path(td) / 'pkgmk'
    pkgmk.write_text('''update_footprint() {
    make_footprint > "$FOOTPRINT_TMP"
    mv "$FOOTPRINT_TMP" "$PKGMK_FOOTPRINT"
\ttouch "$TARGET"
\tinfo "Footprint updated."
}
''')
    subprocess.run(['bash','-c',match.group()+'\nfix_pkgmk_footprint_touch "$1"','bash',str(pkgmk)],check=True)
    result=pkgmk.read_text()
    assert 'touch "$TARGET"' not in result
    assert 'info "Footprint updated."' in result
    # A second invocation should fail instead of silently hiding drift.
    proc=subprocess.run(['bash','-c',match.group()+'\nfix_pkgmk_footprint_touch "$1"','bash',str(pkgmk)],capture_output=True)
    assert proc.returncode != 0
print('r513 archive/metadata safety source and footprint transformer: PASS')
