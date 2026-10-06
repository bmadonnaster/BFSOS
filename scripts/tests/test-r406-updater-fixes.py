#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
from pathlib import Path
import shutil
import subprocess
import tempfile
import sys

ROOT = Path(__file__).resolve().parents[2]
UPDATER = ROOT / "scripts/bfs-port-updater.py"

spec = importlib.util.spec_from_file_location("bfs_port_updater_r406", UPDATER)
mod = importlib.util.module_from_spec(spec)
assert spec.loader
sys.modules[spec.name] = mod
spec.loader.exec_module(mod)


def test_root_owned_cleanup_uses_sudo_and_is_nonfatal():
    with tempfile.TemporaryDirectory() as td:
        base = Path(td) / "build-work"
        target = base / "pkgmk-openssh"
        target.mkdir(parents=True)
        old_roots = mod.build_work_roots
        old_run = mod.subprocess.run
        calls = []
        try:
            mod.build_work_roots = lambda: {"tmpfs": base, "disk": Path(td) / "disk"}
            def fake_run(cmd, **kwargs):
                calls.append(cmd)
                shutil.rmtree(target)
                return subprocess.CompletedProcess(cmd, 0, "", "")
            mod.subprocess.run = fake_run
            ok, detail = mod.cleanup_successful_build_work(base, "openssh")
            assert ok, detail
            assert calls == [["sudo", "rm", "-rf", "--", str(target.resolve())]]

            target.mkdir(parents=True)
            def fake_fail(cmd, **kwargs):
                return subprocess.CompletedProcess(cmd, 1, "", "permission denied")
            mod.subprocess.run = fake_fail
            ok, detail = mod.cleanup_successful_build_work(base, "openssh")
            assert not ok and "permission denied" in detail
        finally:
            mod.build_work_roots = old_roots
            mod.subprocess.run = old_run


def test_distro_version_updates_active_consumers():
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td) / "BFSOS"
        files = [
            "VERSION", "bootstrap.sh", "bootstrap-clean-start.sh", "README.md", "docs/INSTALL.md",
            "scripts/bfs-build-iso.sh", "scripts/install-bfs-menu-current.sh",
            "ports/core/aaa_filesystem/Pkgfile",
        ]
        for rel in files:
            src = ROOT / rel
            dst = tmp / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
        old_release = int(next(x.split("=",1)[1] for x in (tmp/"ports/core/aaa_filesystem/Pkgfile").read_text().splitlines() if x.startswith("release=")))
        changed = mod.apply_distro_version(tmp, "0.9.1-rc1")
        assert "VERSION" in changed
        assert (tmp/"VERSION").read_text().strip() == "0.9.1-rc1"
        aaa=(tmp/"ports/core/aaa_filesystem/Pkgfile").read_text()
        assert "bfs_version=0.9.1-rc1" in aaa
        assert f"release={old_release+1}" in aaa
        assert 'BFS_VERSION="0.9.1-rc1"' in (tmp/"bootstrap.sh").read_text()
        assert "printf '0.9.1-rc1'" in (tmp/"scripts/bfs-build-iso.sh").read_text()
        assert '${release:-0.9.1-rc1}' in (tmp/"scripts/install-bfs-menu-current.sh").read_text()
        assert "0.9.1-rc1" in (tmp/"README.md").read_text()
        assert mod.apply_distro_version(tmp, "0.9.1-rc1") == []
        try:
            mod.apply_distro_version(tmp, "../../bad")
        except ValueError:
            pass
        else:
            raise AssertionError("unsafe distro version accepted")


def test_gnu_core_sources_use_mirror_redirector():
    offenders=[]
    for pkg in (ROOT/"ports/core").glob("*/Pkgfile"):
        text=pkg.read_text(errors="replace")
        if "https://ftp.gnu.org/gnu/" in text:
            offenders.append(str(pkg.relative_to(ROOT)))
    assert not offenders, offenders


def test_ca_compatibility_links_recreated_after_make_ca():
    ca=(ROOT/"ports/core/ca-certificates/post-install").read_text()
    mk=(ROOT/"ports/core/make-ca/post-install").read_text()
    assert ca.rfind("/usr/sbin/make-ca -r") < ca.rfind("/etc/ssl/certs/ca-certificates.crt")
    assert mk.find("/usr/sbin/make-ca -r") < mk.find("/etc/ssl/certs/ca-certificates.crt")
    assert "ln -sfn ../cert.pem /etc/ssl/certs/ca-certificates.crt" in ca
    assert "ln -sfn ../cert.pem /etc/ssl/certs/ca-certificates.crt" in mk


if __name__ == "__main__":
    test_root_owned_cleanup_uses_sudo_and_is_nonfatal()
    test_distro_version_updates_active_consumers()
    test_gnu_core_sources_use_mirror_redirector()
    test_ca_compatibility_links_recreated_after_make_ca()
    print("r406 updater fixes passed")
