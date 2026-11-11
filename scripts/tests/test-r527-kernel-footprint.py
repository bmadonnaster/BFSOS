#!/usr/bin/env python3
"""Offline regressions for versioned BFSOS kernel footprint transitions."""
import importlib.util
import inspect
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("bfs_updater_r527", root / "scripts/bfs-port-updater.py")
updater = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = updater
spec.loader.exec_module(updater)


def mismatch(*rows):
    return "=======> ERROR: Footprint mismatch found:\n" + "\n".join(rows) + "\n=======> ERROR: Building failed\n"


old, new = "6.18.60-BFSOS-LTS", "6.18.63-BFSOS-LTS"
entries = [
    f"MISSING -rw-r--r-- root/root boot/{part}-{old}"
    for part in ("vmlinuz", "config", "System.map")
] + [
    f"NEW -rw-r--r-- root/root boot/{part}-{new}"
    for part in ("vmlinuz", "config", "System.map")
] + [
    f"MISSING lrwxrwxrwx root/root boot/vmlinuz-lts -> vmlinuz-{old}",
    f"NEW lrwxrwxrwx root/root boot/vmlinuz-lts -> vmlinuz-{new}",
    "MISSING drwxr-xr-x root/root lib/modules/<kernel-version>/",
    f"NEW drwxr-xr-x root/root lib/modules/{new}/",
    "MISSING -rw-r--r-- root/root lib/modules/<kernel-version>/kernel/example.ko.zst",
    f"NEW -rw-r--r-- root/root lib/modules/{new}/kernel/example.ko.zst",
    f"MISSING lrwxrwxrwx root/root lib/modules/<kernel-version>/build -> /usr/src/linux-{old}",
    f"NEW lrwxrwxrwx root/root lib/modules/{new}/build -> /usr/src/linux-{new}",
    f"MISSING drwxrwxr-x root/root usr/src/linux-{old}/",
    f"NEW drwxrwxr-x root/root usr/src/linux-{new}/",
    f"NEW -rw-r--r-- root/root usr/src/linux-{new}/generated-header.h",
]
ok, _, why = updater.safe_kernel_version_footprint_change(mismatch(*entries), "6.18.60", "6.18.63")
assert ok, why

# A separately generated footprint may keep its entire module subtree under
# <kernel-version>, resulting in no module changes in the mismatch at all.
boot_only = [row for row in entries if "lib/modules/" not in row and "usr/src/" not in row]
assert updater.safe_kernel_version_footprint_change(mismatch(*boot_only), "6.18.60", "6.18.63")[0]

for bad in (
    f"NEW -rw-r--r-- root/root etc/shadow",
    f"NEW -rwsr-xr-x root/root usr/src/linux-{new}/suid",
    f"NEW lrwxrwxrwx root/root boot/vmlinuz-lts -> vmlinuz-{old}",
    f"MISSING -rw-r--r-- root/root lib/modules/<kernel-version>/kernel/unmatched.ko.zst",
):
    assert not updater.safe_kernel_version_footprint_change(
        mismatch(*(entries + [bad])), "6.18.60", "6.18.63"
    )[0], bad

ml_old, ml_new = "7.3.0-BFSOS-Mainline", "7.3.4-BFSOS-Mainline"
ml_entries = [
    row.replace(old, ml_old).replace(new, ml_new)
    for row in entries[:6]
] + [
    f"MISSING drwxr-xr-x root/root lib/modules/{ml_old}/",
    f"NEW drwxr-xr-x root/root lib/modules/{ml_new}/",
]
assert updater.safe_kernel_version_footprint_change(
    mismatch(*ml_entries), "7.3", "7.3.4", "Mainline"
)[0]

# Installation goes through pkgadd, which owns package install hooks. The
# updater must not mistake a build-only run for an installed package.
source = inspect.getsource(updater.build_selected)
assert 'if install:' in source
assert 'install_cmd = ["sudo", "pkgadd"] + (["-u"] if already_installed else [])' in source
assert "DEFERRED: prerequisite LTS kernel package build not validated" in source

print("r527 kernel footprint regressions: PASS")
