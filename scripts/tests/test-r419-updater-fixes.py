#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]


def load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


cu = load("checkupdate_r419", ROOT / "scripts/checkupdate.py")
mu = load("maintained_r419", ROOT / "scripts/bfs-maintained-port-updater.py")
pu = load("primary_r419", ROOT / "scripts/bfs-port-updater.py")


def port(rel: str, name: str, version: str, sources=None):
    return cu.Port(Path("/tmp") / name, rel, name, version, sources or [])


def test_ftp_sources_are_real_remote_sources():
    p = port("opt/alsa-plugins", "alsa-plugins", "1.2.12", [
        "ftp://ftp.alsa-project.org/pub/plugins/alsa-plugins-1.2.12.tar.bz2"
    ])
    assert cu.remote_sources(p) == p.sources


def test_publicsuffix_and_openbox_have_explicit_policy_not_meta_skip():
    assert "opt/publicsuffix-list" in cu.DISCOVERY_POLICY_SKIPS
    assert "data snapshot" in cu.DISCOVERY_POLICY_SKIPS["opt/publicsuffix-list"]
    assert "opt/openbox" in cu.DISCOVERY_POLICY_SKIPS
    assert "3.6.1" in cu.DISCOVERY_POLICY_SKIPS["opt/openbox"]


def test_github_api_403_uses_git_tag_fallback_and_asset_validation():
    p = port("opt/example", "example", "1.0.0")
    source = "https://github.com/acme/example/releases/download/v1.0.0/example-1.0.0.tar.xz"

    class H:
        timeout = 2
        def get(self, url):
            raise cu.FetchError("curl: (22) HTTP 403")
        def exists(self, url):
            if url.endswith("/v1.0.0/example-1.0.0.tar.xz"):
                return True, ""
            if url.endswith("/v1.1.0/example-1.1.0.tar.xz"):
                return True, ""
            return False, "404"

    old = cu._github_repo_tags
    cu._github_repo_tags = lambda owner, repo, timeout: ["v1.0.0", "v1.1.0", "other-9.9.9"]
    try:
        latest, provider, reason = cu.github_published_release(p, source, H())
    finally:
        cu._github_repo_tags = old
    assert latest == "1.1.0", (latest, provider, reason)
    assert provider == "github-release+git-tags"


def test_github_reachable_assets_work_when_api_asset_list_is_incomplete():
    p = port("core/bc", "bc", "7.1.0")
    source = "https://github.com/gavinhoward/bc/releases/download/7.1.0/bc-7.1.0.tar.xz"

    class H:
        def get(self, url):
            return json.dumps([
                {"tag_name": "7.1.1", "draft": False, "prerelease": False, "assets": []},
                {"tag_name": "7.1.0", "draft": False, "prerelease": False, "assets": []},
            ])
        def exists(self, url):
            return (url.endswith("bc-7.1.0.tar.xz") or url.endswith("bc-7.1.1.tar.xz"), "")

    latest, provider, reason = cu.github_published_release(p, source, H())
    assert latest == "7.1.1", (latest, provider, reason)


def test_github_current_asset_fallback_covers_libpaper_and_kddockwidgets():
    cases = [
        ("opt/libpaper", "libpaper", "2.3.0", "v2.3.0", "libpaper-2.3.0.tar.gz"),
        ("plasma/kddockwidgets", "kddockwidgets", "2.4.1", "v2.4.1", "KDDockWidgets-2.4.1.tar.gz"),
    ]
    for rel, name, version, tag, asset in cases:
        p = port(rel, name, version)
        source = f"https://github.com/acme/repo/releases/download/{tag}/{asset}"
        class H:
            def get(self, url):
                return json.dumps([{"tag_name": tag, "draft": False, "prerelease": False, "assets": []}])
            def exists(self, url):
                return (url == source, "" if url == source else "404")
        latest, provider, reason = cu.github_published_release(p, source, H())
        assert latest == version, (rel, latest, provider, reason)


def test_ghostscript_condensed_tag_maps_to_dotted_version():
    assert cu._github_tag_version("gs10080", "gs10080", "10.08.0") == "10.08.0"
    assert cu._github_tag_version("gs10090", "gs10080", "10.08.0") == "10.09.0"


def test_infozip_legacy_sourceforge_path_and_compact_version():
    p = port("opt/unzip", "unzip", "6.0")
    source = "https://downloads.sourceforge.net/sourceforge/infozip/unzip60.tar.gz"

    class H:
        def get(self, url):
            assert "/projects/infozip/" in url, url
            return '<a href="unzip60.tar.gz">unzip60.tar.gz</a><a href="unzip61.tar.gz">unzip61.tar.gz</a>'

    latest, provider, reason = cu.sourceforge_files(p, source, H())
    assert latest == "6.1", (latest, provider, reason)


def test_sourceforge_snapshot_and_legacy_lame_tokens_are_rejected():
    gp = port("opt/gutenprint", "gutenprint", "5.3.5")
    lm = port("opt/lame", "lame", "4.0")
    assert not cu.candidate_allowed("5.3.6-2026-02-16T02-19-a019bf9c", "5.3.5", gp, "sourceforge")
    assert cu.candidate_allowed("5.3.6", "5.3.5", gp, "sourceforge")
    assert not cu.candidate_allowed("398-2", "4.0", lm, "sourceforge")
    assert cu.candidate_allowed("4.1", "4.0", lm, "sourceforge")


def test_lmdb_placeholder_and_tag_family_are_strict():
    assert not cu.candidate_allowed("2.BP", "1.0.2")
    p = port("opt/lmdb", "lmdb", "1.0.2")
    real_run = cu.subprocess.run

    class CP:
        returncode = 0
        stdout = "\n".join([
            "x\trefs/tags/LMDB_1.0.2",
            "x\trefs/tags/LMDB_1.0.3",
            "x\trefs/tags/LMDB_2.BP",
            "x\trefs/tags/OPENLDAP_REL_ENG_2_6_0",
        ])
        stderr = ""

    cu.subprocess.run = lambda *a, **kw: CP()
    try:
        latest, provider, reason = cu.git_tags(
            p,
            "https://git.openldap.org/openldap/openldap/-/archive/LMDB_1.0.2/openldap-LMDB_1.0.2.tar.bz2",
            2,
            "https://git.openldap.org/openldap/openldap.git",
        )
    finally:
        cu.subprocess.run = real_run
    assert latest == "1.0.3", (latest, provider, reason)


def test_tcl_is_locked_to_current_86_branch():
    p = port("opt/tcl", "tcl", "8.6.18")
    assert cu.candidate_allowed("8.6.19", "8.6.18", p, "sourceforge")
    assert not cu.candidate_allowed("9.1.0", "8.6.18", p, "sourceforge")


def test_rarlab_unrar_uses_official_source_link():
    p = port("opt/unrar", "unrar", "7.3.1")

    class H:
        def get(self, url):
            assert url.endswith("/rar_add.htm")
            return '<a href="rar/unrarsrc-7.3.1.tar.gz">UnRAR source</a>'

    latest, provider, reason = cu.rarlab_unrar_release(p, H())
    assert latest == "7.3.1", (latest, provider, reason)
    assert provider == "rarlab-addons"


def test_unicode_multi_source_dynamic_handoff_is_not_ambiguous():
    text = '''name=unicode-character-database\nversion=17.0.0\nrelease=1\nsource=(https://www.unicode.org/Public/$version/ucd/UCD.zip\n https://www.unicode.org/Public/$version/ucd/Unihan.zip)\nrenames=(UCD-$version.zip Unihan-$version.zip)\n'''
    before = mu.Meta(
        "unicode-character-database", "17.0.0", "1", "-p1", False, True,
        [
            "https://www.unicode.org/Public/17.0.0/ucd/UCD.zip",
            "https://www.unicode.org/Public/17.0.0/ucd/Unihan.zip",
        ],
    )
    bumped = mu.rewrite_version_release(text, "17.0.0", "18.0.0")
    out = mu.rewrite_primary_source_from_handoff(
        bumped, before, "18.0.0", "https://www.unicode.org/Public/18.0.0/ucd/UCD.zip"
    )
    assert "$version/ucd/UCD.zip" in out
    assert "$version/ucd/Unihan.zip" in out
    assert "renames=(UCD-$version.zip Unihan-$version.zip)" in out


def test_alsa_plugins_use_real_upstream_and_locked_native_compat_pair():
    assert cu.GIT_REPO_OVERRIDES["opt/alsa-plugins"].endswith("alsa-project/alsa-plugins.git")
    assert cu.GIT_REPO_OVERRIDES["compat-32/alsa-plugins-32"].endswith("alsa-project/alsa-plugins.git")
    assert pu.VERSION_LOCK_GROUPS["alsa-plugins"] == {"opt/alsa-plugins", "compat-32/alsa-plugins-32"}
    assert pu.GROUP_BUILD_ORDER["alsa-plugins"] == ["opt/alsa-plugins", "compat-32/alsa-plugins-32"]


def test_unicode_provider_positive_control_17_to_18():
    p = port("opt/unicode-character-database", "unicode-character-database", "17.0.0")
    class H:
        def get(self, url):
            return '<a href="17.0.0/">17.0.0</a><a href="18.0.0/">18.0.0</a>'
    latest, provider, reason = cu.unicode_ucd_releases(p, H())
    assert latest == "18.0.0", (latest, provider, reason)


def test_unicode_multi_source_validation_checks_every_changed_archive():
    before = mu.Meta("unicode-character-database", "17.0.0", "1", "-p1", False, True, [
        "https://www.unicode.org/Public/17.0.0/ucd/UCD.zip",
        "https://www.unicode.org/Public/17.0.0/ucd/Unihan.zip",
    ])
    proposed = mu.Meta("unicode-character-database", "18.0.0", "1", "-p1", False, True, [
        "https://www.unicode.org/Public/18.0.0/ucd/UCD.zip",
        "https://www.unicode.org/Public/18.0.0/ucd/Unihan.zip",
    ])
    seen=[]
    real = mu.remote_url_exists
    def fake(url, timeout):
        seen.append(url)
        return (not url.endswith("Unihan.zip"), "404" if url.endswith("Unihan.zip") else "")
    mu.remote_url_exists = fake
    try:
        try:
            mu.validate_changed_remote_archives(before, proposed, 2)
        except mu.UpdateError as exc:
            assert "Unihan.zip" in str(exc)
        else:
            raise AssertionError("expected coupled source validation failure")
    finally:
        mu.remote_url_exists = real
    assert any(x.endswith("UCD.zip") for x in seen) and any(x.endswith("Unihan.zip") for x in seen)


def test_unicode_multi_source_validation_succeeds_when_all_sources_exist():
    before = mu.Meta("unicode-character-database", "17.0.0", "1", "-p1", False, True, [
        "https://www.unicode.org/Public/17.0.0/ucd/UCD.zip",
        "https://www.unicode.org/Public/17.0.0/ucd/Unihan.zip",
    ])
    proposed = mu.Meta("unicode-character-database", "18.0.0", "1", "-p1", False, True, [
        "https://www.unicode.org/Public/18.0.0/ucd/UCD.zip",
        "https://www.unicode.org/Public/18.0.0/ucd/Unihan.zip",
    ])
    seen=[]
    real = mu.remote_url_exists
    mu.remote_url_exists = lambda url, timeout: (seen.append(url) or True, "")
    try:
        mu.validate_changed_remote_archives(before, proposed, 2)
    finally:
        mu.remote_url_exists = real
    assert len(seen) == 2


def test_unicode_dynamic_handoff_preserves_unrelated_local_companion():
    text = """name=unicode-character-database
version=17.0.0
release=1
source=(https://www.unicode.org/Public/$version/ucd/UCD.zip
 https://www.unicode.org/Public/$version/ucd/Unihan.zip local-fix.patch)
renames=(UCD-$version.zip Unihan-$version.zip local-fix.patch)
"""
    before = mu.Meta("unicode-character-database", "17.0.0", "1", "-p1", False, True, [
        "https://www.unicode.org/Public/17.0.0/ucd/UCD.zip",
        "https://www.unicode.org/Public/17.0.0/ucd/Unihan.zip",
        "local-fix.patch",
    ])
    bumped = mu.rewrite_version_release(text, "17.0.0", "18.0.0")
    out = mu.rewrite_primary_source_from_handoff(
        bumped, before, "18.0.0", "https://www.unicode.org/Public/18.0.0/ucd/UCD.zip"
    )
    assert "local-fix.patch" in out


def test_genuinely_ambiguous_independent_archives_still_refuse():
    text = """name=demo
version=1.0
release=1
source=(https://a.example/demo-1.0.tar.xz https://b.example/demo-1.0.zip)
"""
    before = mu.Meta("demo", "1.0", "1", "-p1", False, True, [
        "https://a.example/demo-1.0.tar.xz", "https://b.example/demo-1.0.zip"
    ])
    bumped = mu.rewrite_version_release(text, "1.0", "1.1")
    try:
        mu.rewrite_primary_source_from_handoff(bumped, before, "1.1", "https://c.example/new-1.1.tar.xz")
    except mu.UpdateError as exc:
        assert "ambiguous primary remote source" in str(exc)
    else:
        raise AssertionError("ambiguous independent archives must remain review-only")


if __name__ == "__main__":
    tests = [v for k, v in sorted(globals().items()) if k.startswith("test_") and callable(v)]
    for t in tests:
        t()
    print("r419 updater fixes: PASS")
