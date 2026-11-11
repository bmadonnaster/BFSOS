#!/usr/bin/env python3
"""Offline regression: kernel versioned footprints and deferred installs."""
import importlib.util
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("bfs_updater_r529", root / "scripts/bfs-port-updater.py")
updater = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = updater
spec.loader.exec_module(updater)


def diff(flavor="Mainline", extra=True):
    old = f"7.3.1-BFSOS-{flavor}"
    new = f"7.3.4-BFSOS-{flavor}"
    lines = ["ERROR: Footprint mismatch found:"]
    for kind, tag in (("MISSING", old), ("NEW", new)):
        for filename in ("vmlinuz", "config", "System.map"):
            lines.append(f"{kind} -rw-r--r-- root/root boot/{filename}-{tag}")
        lines.append(f"{kind} drwxr-xr-x root/root lib/modules/{tag}/")
        lines.append(f"{kind} lrwxrwxrwx root/root lib/modules/{tag}/build -> /usr/src/linux-{tag}")
        lines.append(f"{kind} -rw-r--r-- root/root lib/modules/{tag}/kernel/crypto/test.ko.zst")
        if kind == "NEW" and extra:
            lines.append(f"{kind} -rw-r--r-- root/root lib/modules/{tag}/kernel/crypto/new.ko.zst")
    return "\n".join(lines)


safe, _, reason = updater.safe_kernel_version_footprint_change(diff(), "7.3.1", "7.3.4", "Mainline")
assert safe, reason
safe, _, reason = updater.safe_kernel_version_footprint_change(diff().replace("root/root", "root/wheel", 1), "7.3.1", "7.3.4", "Mainline")
assert not safe
safe, _, reason = updater.safe_kernel_version_footprint_change(diff().replace("boot/config-7.3.4-BFSOS-Mainline", "etc/passwd"), "7.3.1", "7.3.4", "Mainline")
assert not safe
assert updater.defer_kernel_install("core/linux")
assert updater.defer_kernel_install("core/linux-mainline")
assert not updater.defer_kernel_install("core/linux-headers")
assert not updater.defer_kernel_install("opt/firefox")
print("PASS r529 kernel footprint and deferred install policy")
