#!/usr/bin/env python3
"""r502 offline contract: cpio must never configure inside fakeroot."""
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
cpio = ROOT / "ports/opt/cpio/Pkgfile"
wrapper = ROOT / "ports/core/pkgutils/bfs-pkgmk"
patch = ROOT / "ports/core/pkgutils/bfs-pkgmk-split-phases.patch.txt"
installer = ROOT / "scripts/install-bfs-menu-current.sh"
iso = ROOT / "scripts/bfs-build-iso.sh"
text = cpio.read_text()
w = wrapper.read_text()
p = patch.read_text()
assert re.search(r"(?m)^bfs_build_phases=split$", text)
assert re.search(r"(?m)^pkg_compile\(\)", text)
assert re.search(r"(?m)^pkg_stage\(\)", text)
assert "./configure" in text.split("pkg_compile() {", 1)[1].split("pkg_stage() {",1)[0]
assert "make DESTDIR=\"$PKG\" install || return 1" in text
assert "BFS_PKG_SPLIT_BUILD=yes pkgmk" in w
assert "fakeroot -- pkgmk" in w # expected fallback for unmigrated ports
assert "BFS_PKG_PHASE=compile" in p and "BFS_PKG_PHASE=stage" in p
assert "prt-get -if -is update pkgutils" in iso.read_text()
assert "prt-get -if -is update pkgutils" in installer.read_text()
for file in (cpio,wrapper):
    subprocess.run(["bash", "-n", str(file)],check=True)
print("r502 cpio split-build/static ISO propagation: PASS (VM install still required)")
