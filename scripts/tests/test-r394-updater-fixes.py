#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


u = load("bfs_port_updater_r394", ROOT / "scripts" / "bfs-port-updater.py")
m = load("bfs_maintained_port_updater_r394", ROOT / "scripts" / "bfs-maintained-port-updater.py")


def meta(rel: str, name: str, version: str, source: str = ""):
    return u.PortMeta(rel, Path("/tmp") / rel, name, version, "1", [source] if source else [])


# Avahi: cosmetic RC separator must not create a false update.
avahi = meta("opt/avahi", "avahi", "0.9-rc5")
assert u.versions_equivalent_for_port(avahi, "0.9-rc5", "0.9rc5")
assert not u.newer_for_port(avahi, "0.9rc5", "0.9-rc5")

# Release-tracking libcupsfilters must reject Arch-style VCS snapshots, but a
# port already tracking snapshots remains eligible for them.
cups = meta(
    "opt/libcupsfilters", "libcupsfilters", "2.2.1",
    "https://github.com/OpenPrinting/libcupsfilters/releases/download/2.2.1/libcupsfilters-2.2.1.tar.xz",
)
assert u.reject_downstream_snapshot(cups, "2.2.1.r23.gdee3b387")
snap = meta(
    "opt/demo", "demo", "2.2.1.r10.gabcdef1",
    "https://github.com/example/demo/archive/commit/abcdef1.tar.gz",
)
assert not u.reject_downstream_snapshot(snap, "2.2.1.r11.gabcdef2")


# Candidate generation must actually suppress the verified Arch snapshot.
arch = u.ArchReference("2.2.1.r23.gdee3b387", "https://github.com/OpenPrinting/libcupsfilters", True, "same upstream")
diag = []
cands = u.make_candidates([cups], {k:{} for k,_,_ in u.BOOKS}, [], {}, 1, diag, {cups.rel:("", arch)})
assert cands == [], cands
assert any("downstream VCS snapshot" in x for x in diag), diag

# Firefox ESR must use Mozilla's ESR channel rather than rapid release.
old_fetch = u.fetch_text
try:
    u.fetch_text = lambda url, timeout: '{"LATEST_FIREFOX_VERSION":"157.0","FIREFOX_ESR":"153.3.0esr"}'
    esr = meta("opt/firefox-esr", "firefox-esr", "153.2.0esr")
    ver, provider, source = u.special_browser_reference(esr, 1)
    assert ver == "153.3.0esr"
    assert provider == "Mozilla ESR"
    assert "153.3.0esr" in source
    diag = []
    cands = u.make_candidates(
        [esr], {k:{} for k,_,_ in u.BOOKS}, [],
        {esr.rel:{"status":"UPDATE", "latest":"157.0", "provider":"generic-firefox"}},
        1, diag, {esr.rel:("", u.ArchReference())}
    )
    assert len(cands) == 1 and cands[0].new == "153.3.0esr", cands
    assert cands[0].source_label == "Mozilla ESR"
finally:
    u.fetch_text = old_fetch

# Maintained updater: target source handoff migrates the primary source while
# preserving useful shell templating and unrelated companion archives.
before = m.Meta(
    "glib-networking", "2.80.1", "2", "-p1", False, True,
    ["https://download.gnome.org/sources/glib-networking/2.80/glib-networking-2.80.1.tar.xz"],
)
text = """name=glib-networking
version=2.90.0
release=1
source=(https://download.gnome.org/sources/$name/2.80/$name-$version.tar.xz)
"""
rewritten = m.rewrite_primary_source_from_handoff(
    text, before, "2.90.0",
    "https://download.gnome.org/sources/glib-networking/2.90/glib-networking-2.90.0.tar.xz",
)
assert "sources/$name/2.90/$name-$version.tar.xz" in rewritten
assert "sources/$name/2.80/" not in rewritten

multi = """name=demo
version=2
release=1
source=(https://example.org/demo-$version.tar.xz
        https://data.example.org/unicode-data.zip
        local.patch)
"""
before_multi = m.Meta("demo", "1", "1", "-p1", False, True,
                      ["https://example.org/demo-1.tar.xz", "https://data.example.org/unicode-data.zip", "local.patch"])
rewritten_multi = m.rewrite_primary_source_from_handoff(
    multi, before_multi, "2", "https://mirror.example.org/demo-2.tar.xz"
)
assert "https://mirror.example.org/demo-$version.tar.xz" in rewritten_multi
assert "https://data.example.org/unicode-data.zip" in rewritten_multi
assert "local.patch" in rewritten_multi

# Ambiguous primary archives must be held rather than guessed.
ambiguous = """name=demo
version=2
release=1
source=(https://a.example.org/a.tar.xz https://b.example.org/b.tar.xz)
"""
try:
    m.rewrite_primary_source_from_handoff(
        ambiguous, before_multi, "2", "https://mirror.example.org/demo-2.tar.xz"
    )
except m.UpdateError as exc:
    assert "ambiguous primary" in str(exc)
else:
    raise AssertionError("ambiguous source handoff was not rejected")

# NVIDIA native + compat32 form an atomic pair and build native first. The
# fallback nvidia-fb-32 port is not part of the lock group.
assert u.VERSION_LOCK_GROUPS["nvidia-driver"] == {"opt/nvidia", "compat-32/nvidia-32"}
assert "compat-32/nvidia-fb-32" not in u.VERSION_LOCK_GROUPS["nvidia-driver"]
with tempfile.TemporaryDirectory() as td_s:
    ports = Path(td_s)
    metas = []
    for rel, name in (("opt/nvidia", "nvidia"), ("compat-32/nvidia-32", "nvidia-32")):
        d = ports / rel
        d.mkdir(parents=True)
        (d / "Pkgfile").write_text(f"name={name}\nversion=615.71.09\nrelease=1\nsource=()\n")
        metas.append(u.eval_pkgfile(d / "Pkgfile", ports))
    cands = [
        u.Candidate("opt/nvidia", "nvidia", "615.71.09", "620.1", "1", "1", "review", "test", "REVIEW"),
        u.Candidate("compat-32/nvidia-32", "nvidia-32", "615.71.09", "620.1", "1", "1", "review", "test", "REVIEW"),
    ]
    u.enforce_version_lock_groups(cands, metas)
    assert all(c.status == "UPDATE" and c.selected and c.policy == "nvidia-driver" for c in cands)
    assert u._build_rank("opt/nvidia") < u._build_rank("compat-32/nvidia-32")

    old_run = u.run
    try:
        class CP:
            returncode = 0
            stdout = ""
            stderr = ""
        calls = []
        def fake_run(cmd, **kwargs):
            calls.append((cmd, kwargs.get("cwd")))
            return CP()
        u.run = fake_run
        results = {c.port: "UPDATED" for c in cands}
        u.build_selected(cands, {c.port for c in cands}, ports, False, results)
        assert results["opt/nvidia"] == "BUILT"
        assert results["compat-32/nvidia-32"] == "BUILT"
        assert len(calls) == 2
    finally:
        u.run = old_run

# Primary updater must retain the helper's actual NEEDS-REVIEW reason.
with tempfile.TemporaryDirectory() as td_s:
    ports = Path(td_s)
    d = ports / "opt/demo"
    d.mkdir(parents=True)
    (d / "Pkgfile").write_text("name=demo\nversion=1\nrelease=1\nsource=(https://example.org/demo-1.tar.xz)\n")
    cand = u.Candidate("opt/demo", "demo", "1", "2", "1", "1", "review", "test", "REVIEW", selected=False)
    old_run = u.run
    try:
        class CP:
            returncode = 1
            stdout = ""
            stderr = "NEEDS-REVIEW opt/demo 1 -> 2: rewritten source URL is not reachable: test\n"
        u.run = lambda *args, **kwargs: CP()
        result = u.apply_selected([cand], {"opt/demo"}, ports, 1)
        assert result["opt/demo"] == "NEEDS REVIEW: rewritten source URL is not reachable: test"
    finally:
        u.run = old_run


# BLOCKED coordinated members remain retryable after their Pkgfiles have already
# advanced to the target, so the next scan does not make an interrupted group vanish.
with tempfile.TemporaryDirectory() as td_s:
    base = Path(td_s)
    ports = base / "ports"
    logs = base / "logs"
    pd = ports / "opt/spirv-tools"
    pd.mkdir(parents=True)
    logs.mkdir()
    pkg = pd / "Pkgfile"
    pkg.write_text("name=spirv-tools\nversion=1.4.400.0\nrelease=1\nsource=()\n")
    import hashlib
    fp = hashlib.sha256(pkg.read_bytes()).hexdigest()
    header = "port\told_version\tnew_version\told_release\tnew_release\tpolicy\tsource\tstatus\tselected\tresult\treason\tpkgfile_sha256\n"
    (logs / "scan-20261005-020000.tsv").write_text(
        header + f"opt/spirv-tools\t1.4.399.0\t1.4.400.0\t1\t1\tvulkan-sdk\ttest\tUPDATE\tyes\tBLOCKED: vulkan-sdk updated prerequisite built but not installed/staged\ttest\t{fp}\n"
    )
    old_log_root = u.LOG_ROOT
    try:
        u.LOG_ROOT = logs
        _log, rows = u.find_retryable_failures(ports)
        assert len(rows) == 1 and rows[0]["port"] == "opt/spirv-tools", rows
    finally:
        u.LOG_ROOT = old_log_root


# Version-locked apply is transactional across the whole group: if one member
# is rejected after another has been rewritten, every touched port directory is restored.
with tempfile.TemporaryDirectory() as td_s:
    ports = Path(td_s)
    for rel, name in (("opt/nvidia", "nvidia"), ("compat-32/nvidia-32", "nvidia-32")):
        d = ports / rel
        d.mkdir(parents=True)
        (d / "Pkgfile").write_text(f"name={name}\nversion=1\nrelease=1\nsource=()\n")
    c1 = u.Candidate("opt/nvidia", "nvidia", "1", "2", "1", "1", "nvidia-driver", "test", "UPDATE", selected=True)
    c2 = u.Candidate("compat-32/nvidia-32", "nvidia-32", "1", "2", "1", "1", "nvidia-driver", "test", "UPDATE", selected=True)
    old_run = u.run
    try:
        class CP:
            returncode = 1
            stdout = "UPDATED opt/nvidia 1 -> 2 release=1\n"
            stderr = "NEEDS-REVIEW compat-32/nvidia-32 1 -> 2: synthetic failure\n"
        def fake_apply(cmd, **kwargs):
            (ports / "opt/nvidia/Pkgfile").write_text("name=nvidia\nversion=2\nrelease=1\nsource=()\n")
            (ports / "compat-32/nvidia-32/Pkgfile").write_text("name=nvidia-32\nversion=2\nrelease=1\nsource=()\n")
            return CP()
        u.run = fake_apply
        result = u.apply_selected([c1, c2], {c1.port, c2.port}, ports, 1)
        assert "ROLLED BACK" in result[c1.port]
        assert "ROLLED BACK" in result[c2.port]
        assert "version=1" in (ports / "opt/nvidia/Pkgfile").read_text()
        assert "version=1" in (ports / "compat-32/nvidia-32/Pkgfile").read_text()
    finally:
        u.run = old_run

print("r394 updater regressions: PASS")
