#!/usr/bin/env python3
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
COMPAT = ROOT / "ports" / "compat-32"
CONTRIB = ROOT / "ports" / "contrib"

pkgfiles = sorted(COMPAT.glob("*/Pkgfile"))
assert len(pkgfiles) == 170, len(pkgfiles)

# The pkgutils extension enters the one extracted source directory before
# pkg_build(). Recipes must not enter/name that root a second time.
for p in pkgfiles:
    s = p.read_text(errors="replace")
    assert "-march=x86-64" not in s, p
    assert "linux-x86_64" not in s, p
    assert not re.search(r"(?m)^\s*meson\s+build\s+", s), p
    cp = subprocess.run(["bash", "-n", str(p)], capture_output=True, text=True)
    assert cp.returncode == 0, (p, cp.stderr)

# Known source-root regressions from the pkgmk auto-source transition.
for p in pkgfiles:
    s = p.read_text(errors="replace")
    name = p.parent.name.removesuffix("-32")
    bad = [
        rf"(?m)^\s*cd\s+{re.escape(name)}-\$version\s*$",
        rf"(?m)^\s*cmake\s+-S\s*{re.escape(name)}-\$version(?:\s|$)",
        rf"(?m)^\s*meson\s+setup\s+(?:build\s+)?{re.escape(name)}-\$version(?:\s|$)",
    ]
    for pat in bad:
        assert not re.search(pat, s), (p, pat)

mpg = (COMPAT / "mpg123-32" / "Pkgfile").read_text()
assert re.search(r"(?m)^# Depends on:.*\bopenal-32\b", mpg)
assert mpg.count("--host=") == 1

openssl = (COMPAT / "openssl11-32" / "Pkgfile").read_text()
assert "linux-x86" in openssl and "linux-x86_64" not in openssl

pipewire = (COMPAT / "pipewire-32" / "Pkgfile").read_text()
assert "xorg-libxcb-32" not in pipewire
assert "libxcb-32" in pipewire

wine = (CONTRIB / "wine-staging" / "Pkgfile").read_text()
assert '"$SRC/wine-staging-$version/staging/patchinstall.py"' in wine
assert '"$SRC/wine-$version/configure"' in wine

steam = (CONTRIB / "steam" / "Pkgfile").read_text()
for dep in ("alsa-plugins-32", "fontconfig-32", "libX11-32", "libva-32", "vulkan-loader-32"):
    assert re.search(rf"(?m)^# Depends on:.*\b{re.escape(dep)}\b", steam), dep

print("compat-32 build-contract regression: PASS")
