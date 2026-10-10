#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]


def load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


cu = load("checkupdate_r415", ROOT / "scripts/checkupdate.py")


class ReleaseHttp:
    def __init__(self, releases):
        self.releases = releases

    def get(self, url):
        if "api.github.com/repos/" in url and "/releases" in url:
            return json.dumps(self.releases)
        raise AssertionError(url)


def asset(name):
    return {"name": name}


def release(tag, *assets, draft=False, prerelease=False):
    return {
        "tag_name": tag,
        "draft": draft,
        "prerelease": prerelease,
        "assets": [asset(x) for x in assets],
    }


def test_lmdb_placeholder_is_rejected_in_provider_layer():
    assert not cu.candidate_allowed("2.MP", "1.0.2")
    assert not cu.candidate_allowed("2.MAJOR", "1.0.2")
    assert cu.candidate_allowed("1.0.3", "1.0.2")


def test_expat_unpublished_asset_never_becomes_candidate():
    port = cu.Port(Path("/tmp/expat"), "compat-32/expat-32", "expat-32", "2.8.5", [])
    source = "https://github.com/libexpat/libexpat/releases/download/R_2_8_5/expat-2.8.5.tar.xz"
    http = ReleaseHttp([
        release("R_2_9_0", "expat-win32bin-2.9.0.exe"),
        release("R_2_8_5", "expat-2.8.5.tar.xz"),
    ])
    latest, provider, reason = cu.github_published_release(port, source, http)
    assert provider == "github-release"
    assert latest == "2.8.5", (latest, reason)



def test_expat_later_published_asset_is_accepted_for_native_and_compat():
    source = "https://github.com/libexpat/libexpat/releases/download/R_2_8_5/expat-2.8.5.tar.xz"
    http = ReleaseHttp([
        release("R_2_8_6", "expat-2.8.6.tar.xz"),
        release("R_2_8_5", "expat-2.8.5.tar.xz"),
    ])
    for rel, name in (("core/expat", "expat"), ("compat-32/expat-32", "expat-32")):
        port = cu.Port(Path("/tmp") / name, rel, name, "2.8.5", [])
        latest, provider, reason = cu.github_published_release(port, source, http)
        assert provider == "github-release"
        assert latest == "2.8.6", (rel, latest, reason)

def test_libvisual_sibling_release_family_is_ignored():
    port = cu.Port(Path("/tmp/libvisual"), "compat-32/libvisual-32", "libvisual-32", "0.4.2", [])
    source = "https://github.com/Libvisual/libvisual/releases/download/libvisual-0.4.2/libvisual-0.4.2.tar.bz2"
    http = ReleaseHttp([
        release("libvisual-plugins-0.4.3", "libvisual-plugins-0.4.3.tar.bz2"),
        release("libvisual-0.4.2", "libvisual-0.4.2.tar.bz2"),
    ])
    latest, provider, reason = cu.github_published_release(port, source, http)
    assert provider == "github-release"
    assert latest == "0.4.2", (latest, reason)


def test_sourceforge_compact_infozip_version_maps_to_dotted_version():
    port = cu.Port(Path("/tmp/unzip"), "opt/unzip", "unzip", "6.0", [])
    source = "https://downloads.sourceforge.net/project/infozip/UnZip%206.x%20%28latest%29/UnZip%206.0/unzip60.tar.gz"

    class FakeHttp:
        def get(self, url):
            return '<a href="unzip60.tar.gz">unzip60.tar.gz</a> <a href="unzip61.tar.gz">unzip61.tar.gz</a>'

    latest, provider, reason = cu.sourceforge_files(port, source, FakeHttp())
    assert provider == "sourceforge"
    assert latest == "6.1", (latest, reason)


def test_policy_pins_are_not_reported_unverifiable():
    port = cu.Port(Path("/tmp/libatasmart"), "opt/libatasmart", "libatasmart", "0.19", ["https://example.invalid/libatasmart-0.19.tar.xz"])
    result = cu.check_port(port, object(), 1)
    assert result.status == "SKIP"
    assert result.provider == "policy-pin"


def test_texlive_annual_snapshot_provider_normalizes_source_suffix():
    port = cu.Port(Path("/tmp/texlive"), "opt/texlive", "texlive", "20260301", [])

    class FakeHttp:
        def get(self, url):
            assert url.endswith("/systems/texlive/Source/")
            return '<a href="texlive-20260301-source.tar.xz">texlive-20260301-source.tar.xz</a>'

    latest, provider, reason = cu.texlive_annual_source(port, FakeHttp())
    assert provider == "ctan-texlive-source"
    assert latest == "20260301", (latest, reason)


def test_repaired_source_templates_present():
    expected = {
        "ports/compat-32/icu-32/Pkgfile": "icu4c-${version}-sources.tgz",
        "ports/opt/lcms2/Pkgfile": "releases/download/lcms${version}/lcms2-$version.tar.gz",
        "ports/compat-32/lcms2-32/Pkgfile": "releases/download/lcms${version}/lcms2-$version.tar.gz",
        "ports/core/dash/Pkgfile": "cdn.netbsd.org/pub/pkgsrc/distfiles/dash-$version.tar.gz",
        "ports/opt/xdotool/Pkgfile": "archive/refs/tags/v${version}.tar.gz",
    }
    for rel, needle in expected.items():
        assert needle in (ROOT / rel).read_text(), rel


if __name__ == "__main__":
    test_lmdb_placeholder_is_rejected_in_provider_layer()
    test_expat_unpublished_asset_never_becomes_candidate()
    test_expat_later_published_asset_is_accepted_for_native_and_compat()
    test_libvisual_sibling_release_family_is_ignored()
    test_sourceforge_compact_infozip_version_maps_to_dotted_version()
    test_policy_pins_are_not_reported_unverifiable()
    test_texlive_annual_snapshot_provider_normalizes_source_suffix()
    test_repaired_source_templates_present()
    print("r415 updater fixes: PASS")
