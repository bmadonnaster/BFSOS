#!/usr/bin/env python3
"""Regression: ISO pkgmk preflight cannot require runuser in the base root."""
from pathlib import Path
root = Path(__file__).resolve().parents[2]
iso = (root / "scripts/bfs-build-iso.sh").read_text()
prepare = iso.split("prepare_iso_pkgmk_cache() {", 1)[1].split("build_iso_package_set() {", 1)[0]
assert 'chroot --userspec="$uid:$gid" "$root" /usr/bin/test -w "$path"' in prepare
assert '/usr/bin/runuser' not in prepare
assert 'install -d -m 0775 -o "$uid" -g "$gid"' in prepare
assert 'prepare_iso_pkgmk_cache "$root"' in iso
print("r456 ISO chroot without runuser: PASS")
