#!/usr/bin/env python3
"""Offline regression for ISO gettext preservation and Xorg port metadata."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
iso = root / 'scripts/bfs-build-iso.sh'
script = iso.read_text()
assert 'rm -f "$root/usr/share/gettext/archive.dir.tar.xz"' not in script
assert '! -path "$root/usr/share/gettext/archive.dir.tar.xz"' in script
assert '"$root/var/cache/ccache"' in script

# Extract only the audited function; do not execute builder's top-level workflow.
start = script.index('audit_live_root() {')
end = script.index('\nwrite_build_info() {', start)
function = script[start:end]
with tempfile.TemporaryDirectory() as d:
    base = Path(d)
    gettext = base / 'usr/share/gettext/archive.dir.tar.xz'
    gettext.parent.mkdir(parents=True)
    gettext.write_bytes(b'legitimate gettext payload')
    def run_audit():
        return subprocess.run(['bash', '-c',
            "log() { :; }; die() { echo \"$*\" >&2; exit 99; }; " +
            function + '\naudit_live_root "$1"', 'bash', str(base)],
            capture_output=True, text=True)
    assert run_audit().returncode == 0, 'legitimate gettext package data rejected'
    garbage = base / 'cache.tar.gz'
    garbage.write_bytes(b'unwanted tar archive')
    result = run_audit()
    assert result.returncode != 0 and 'cache.tar.gz' in result.stderr
    garbage.unlink()
    gettext.unlink()
    assert run_audit().returncode != 0, 'missing gettext infrastructure ignored'

mtdev = (root / 'ports/xorg/mtdev/Pkgfile').read_text()
assert 'bitmath.org/code/mtdev' in mtdev
assert '::' not in mtdev
assert 'make || return 1' in mtdev
libxkb = (root / 'ports/xorg/libxkbcommon/Pkgfile').read_text()
assert '# Depends on: xkeyboard-config libxcb' in libxkb
assert '-Denable-x11=true' in libxkb
assert '|| return 1' in libxkb
vera = (root / 'ports/xorg/xorg-font-bitstream-vera/Pkgfile').read_text()
assert 'distfiles-cdn.gentoo.org/distfiles/b4/' in vera

spec = importlib.util.spec_from_file_location('bfs_alias', root / 'scripts/bfs-audit-source-aliases.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
findings = list(module.scan(root))
assert len(findings) >= 7
assert any(str(p) == 'ports/opt/xdotool/Pkgfile' for p, *_ in findings)
print('r469 gettext/ISO/Xorg source checks: PASS')
