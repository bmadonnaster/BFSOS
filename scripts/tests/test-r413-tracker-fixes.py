#!/usr/bin/env python3
from __future__ import annotations

import csv
import importlib.util
from pathlib import Path
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


up = load("bfs_port_updater_r413", ROOT / "scripts/bfs-port-updater.py")
cu = load("checkupdate_r413", ROOT / "scripts/checkupdate.py")


def test_libvisual_sibling_release_family_rejected():
    port = cu.Port(Path("/tmp/libvisual-32"), "compat-32/libvisual-32", "libvisual-32", "0.4.2", [])

    class FakeHttp:
        def resolve(self, _url):
            return "https://github.com/Libvisual/libvisual/releases/tag/libvisual-plugins-0.4.2", ""

    latest, provider, reason = cu.github_published_release(
        port,
        "https://github.com/Libvisual/libvisual/releases/download/libvisual-0.4.2/libvisual-0.4.2.tar.bz2",
        FakeHttp(),
    )
    assert latest is None
    assert provider == "github-release"
    assert "different release family" in reason


def test_github_release_requires_exact_candidate_asset():
    port = cu.Port(Path("/tmp/expat"), "core/expat", "expat", "2.8.5", [])

    class FakeHttp:
        def resolve(self, _url):
            return "https://github.com/libexpat/libexpat/releases/tag/R_2_9_0", ""
        def exists(self, url):
            assert "R_2_9_0/expat-2.9.0.tar.xz" in url
            return False, "404"

    latest, provider, reason = cu.github_published_release(
        port,
        "https://github.com/libexpat/libexpat/releases/download/R_2_8_5/expat-2.8.5.tar.xz",
        FakeHttp(),
    )
    assert latest is None
    assert provider == "github-release"
    assert "no matching release asset" in reason


def test_xorg_server_is_blfs_authoritative():
    assert up.DEV_BOOK_AUTHORITIES["xorg/xorg-server"] == "blfs-dev"
    meta = up.PortMeta("xorg/xorg-server", Path("/tmp/xorg-server"), "xorg-server", "21.1.24", "3", [])
    got = up.lookup_explicit_dev_authority(meta, {"blfs-dev": {up.normalize_name("xorg-server"): "21.1.24"}})
    assert got == ("blfs-dev", "21.1.24")


def test_xorg_upstream_ahead_is_held_until_blfs_moves():
    meta = up.PortMeta(
        "xorg/xorg-server", Path("/tmp/xorg-server"), "xorg-server", "21.1.24", "3",
        ["https://xorg.freedesktop.org/archive/individual/xserver/xorg-server-21.1.24.tar.xz",
         "https://www.linuxfromscratch.org/patches/blfs/svn/xorg-server-21.1.24-tearfree_backport-2.patch"],
    )
    cands = up.make_candidates(
        [meta],
        {"mlfs-dev": {}, "lfs-dev": {}, "blfs-dev": {up.normalize_name("xorg-server"): "21.1.24"}, "glfs-dev": {}},
        [],
        {"xorg/xorg-server": {"status": "UPDATE", "latest": "21.1.25", "provider": "upstream", "source": ""}},
        1,
        [],
        {},
    )
    assert cands == []


def test_placeholder_versions_rejected():
    assert up.has_unresolved_version_placeholder("2.MP")
    assert up.has_unresolved_version_placeholder("1.MAJOR.0")
    assert not up.has_unresolved_version_placeholder("1.0.2")
    assert not up.has_unresolved_version_placeholder("153.4.0esr")


def test_problem_report_is_consolidated_and_header_only_when_clean():
    with tempfile.TemporaryDirectory() as td:
        p = Path(td) / "problems.tsv"
        u, f = up.write_problem_report(p, {
            "core/a": {"status": "UNVERIFIABLE", "current": "1", "provider": "x", "reason": "why", "source": "u"},
            "compat-32/a-32": {"status": "FETCH-ERROR", "current": "1", "provider": "y", "reason": "bad\nnet", "source": "v"},
            "opt/b": {"status": "CURRENT", "current": "2"},
        })
        assert (u, f) == (1, 1)
        rows = list(csv.DictReader(p.open(), delimiter="\t"))
        assert [r["tree"] for r in rows] == ["compat-32", "core"]
        assert all("\n" not in r["reason"] for r in rows)

        clean = Path(td) / "clean.tsv"
        assert up.write_problem_report(clean, {}) == (0, 0)
        assert clean.read_text().splitlines() == ["status\ttree\tport\tcurrent\tprovider\treason\tsource"]


def test_gpm_and_iso_resume_policy_are_explicit():
    installer = (ROOT / "scripts/install-bfs-menu-current.sh").read_text()
    fn = installer.index("offline_systemctl() {")
    preset = installer.index("offline_systemctl preset-all || true")
    gpm = installer.index('offline_systemctl enable gpm.service', preset)
    assert fn < preset < gpm

    iso = (ROOT / "scripts/bfs-build-iso.sh").read_text()
    assert "--resume-final|--finalize-existing" in iso
    assert "validate_resume_state" in iso
    assert "write_iso_state live-policy-installed" in iso
    assert "write_iso_state cleanup-complete" in iso
    assert "write_iso_state squashfs-complete" in iso
    assert "write_iso_state iso-tree-complete" in iso
    assert "write_iso_state iso-complete" in iso
    assert "gpm.service is installed but not enabled" in iso


if __name__ == "__main__":
    test_libvisual_sibling_release_family_rejected()
    test_github_release_requires_exact_candidate_asset()
    test_xorg_server_is_blfs_authoritative()
    test_xorg_upstream_ahead_is_held_until_blfs_moves()
    test_placeholder_versions_rejected()
    test_problem_report_is_consolidated_and_header_only_when_clean()
    test_gpm_and_iso_resume_policy_are_explicit()
    print("r413 tracker fixes: PASS")
