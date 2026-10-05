#!/usr/bin/env python3
from __future__ import annotations

import csv
import hashlib
from pathlib import Path
import runpy
import tempfile

ROOT = Path(__file__).resolve().parents[2]
front = runpy.run_path(str(ROOT / "scripts/bfs-port-updater.py"), run_name="r377_front_test")
maint = runpy.run_path(str(ROOT / "scripts/bfs-maintained-port-updater.py"), run_name="r377_maint_test")

# Coordinated Gucharmap Unicode data follows the package/Unicode release.
g = """name=gucharmap\nversion=17.0.0\nsource=(https://www.unicode.org/Public/17.0.0/ucd/UCD.zip\nhttps://www.unicode.org/Public/17.0.0/ucd/Unihan.zip)\n"""
g2 = maint["rewrite_coordinated_sources"]("gnome/gucharmap", g, "17.0.0", "18.0.0")
assert "/Public/18.0.0/ucd/UCD.zip" in g2
assert "/Public/18.0.0/ucd/Unihan.zip" in g2
assert "/Public/17.0.0/" not in g2

# gnome-backgrounds uses the GNOME major directory, not ${version%.*}.
b = "source=(https://download.gnome.org/sources/$name/${version%.*}/$name-$version.tar.xz)\n"
b2 = maint["rewrite_coordinated_sources"]("gnome/gnome-backgrounds", b, "51.0", "51.0.1")
assert "${version%%.*}" in b2 and "${version%.*}" not in b2

# A changed source filename invalidates stale generated checksums.
Meta = maint["Meta"]
with tempfile.TemporaryDirectory() as td:
    d = Path(td)
    (d / ".md5sum").write_text("old  old.tar.xz\n")
    before = Meta("x", "1", "1", "-p1", False, True, ["https://e/x-1.tar.xz"])
    after = Meta("x", "2", "1", "-p1", False, True, ["https://e/x-2.tar.xz"])
    removed = maint["invalidate_generated_checksums"](d, before, after)
    assert removed == [".md5sum"] and not (d / ".md5sum").exists()

# Unmapped ports must fall through CRUX even if generic upstream did not first
# produce UPDATE. This is the core omission regression.
PortMeta = front["PortMeta"]
with tempfile.TemporaryDirectory() as td:
    root = Path(td)
    pd = root / "core" / "not-in-lfs"
    pd.mkdir(parents=True)
    (pd / "Pkgfile").write_text("name=not-in-lfs\nversion=1.0\nrelease=1\n")
    meta = PortMeta("core/not-in-lfs", pd, "not-in-lfs", "1.0", "1", [])
    front["crux_reference_version"].__globals__["crux_reference_version"] = lambda _m, _t=10: "1.2"
    front["arch_reference_version"].__globals__["arch_reference_version"] = lambda _m, _t=10: ""
    diagnostics = []
    c = front["make_candidates"]([meta], {k:{} for k,_,_ in front["BOOKS"]}, [], {}, 1, diagnostics)
    assert len(c) == 1 and c[0].new == "1.2" and c[0].source_label == "CRUX reference"
    assert any("not MLFS-authoritative; checking CRUX" in x for x in diagnostics)

# New retry logs use a fingerprint, so a manual Pkgfile edit invalidates a
# recorded failure even when version/release remain unchanged.
with tempfile.TemporaryDirectory() as td:
    root = Path(td) / "ports"
    pd = root / "opt" / "retry-me"
    pd.mkdir(parents=True)
    pkg = pd / "Pkgfile"
    pkg.write_text("name=retry-me\nversion=1.2\nrelease=1\n")
    fp = hashlib.sha256(pkg.read_bytes()).hexdigest()
    row = {"port":"opt/retry-me", "new_version":"1.2", "new_release":"1", "pkgfile_sha256":fp}
    assert front["_port_matches_logged_target"](root, row)
    pkg.write_text("# manual fix\nname=retry-me\nversion=1.2\nrelease=1\n")
    assert not front["_port_matches_logged_target"](root, row)

# A newer successful actionable result retires an older failure; a newer scan
# row with an empty result does not.
with tempfile.TemporaryDirectory() as td:
    base = Path(td)
    root = base / "ports"
    logs = base / "logs"
    pd = root / "opt" / "retry-state"
    pd.mkdir(parents=True)
    logs.mkdir()
    pkg = pd / "Pkgfile"
    pkg.write_text("name=retry-state\nversion=2.0\nrelease=1\n")
    fp = hashlib.sha256(pkg.read_bytes()).hexdigest()
    header = "port\told_version\tnew_version\told_release\tnew_release\tpolicy\tsource\tstatus\tselected\tresult\treason\tpkgfile_sha256\n"
    (logs / "scan-20261005-010000.tsv").write_text(header + f"opt/retry-state\t1.0\t2.0\t1\t1\treview\tupstream\tREVIEW\tyes\tBUILD FAILED (1)\ttest\t{fp}\n")
    (logs / "scan-20261005-020000.tsv").write_text(header + f"opt/retry-state\t2.0\t2.0\t1\t1\treview\tupstream\tREVIEW\tno\t\trescan only\t{fp}\n")
    front["find_retryable_failures"].__globals__["LOG_ROOT"] = logs
    _log, rows = front["find_retryable_failures"](root)
    assert len(rows) == 1
    (logs / "scan-20261005-030000.tsv").write_text(header + f"opt/retry-state\t1.0\t2.0\t1\t1\tretry\t\tRETRY\tyes\tBUILT ON RETRY\ttest\t{fp}\n")
    _log, rows = front["find_retryable_failures"](root)
    assert rows == []

# Guard GTK2 compat port against a GTK3 family jump.
with tempfile.TemporaryDirectory() as td:
    root = Path(td)
    pd = root / "compat-32" / "gtk-32"
    pd.mkdir(parents=True)
    gtk = PortMeta("compat-32/gtk-32", pd, "gtk-32", "2.24.33", "1", [])
    assert front["family_allows"](gtk, "2.24.34")
    assert not front["family_allows"](gtk, "3.24.52")

print("r377 port updater regression: PASS")
