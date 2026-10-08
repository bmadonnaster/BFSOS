#!/usr/bin/env python3
"""BFSOS upstream version checker v11.

Design goals:
- never claim an update unless the current port version can be mapped back to the
  same upstream provider/index that produced the candidate;
- treat local/meta ports as SKIP rather than network failures;
- use provider-aware checks for Git tags, GNOME, KDE, PyPI and Xfce;
- use an exact current-filename template for generic directory indexes;
- report UNVERIFIABLE instead of guessing when a provider cannot be proven;
- never modify Pkgfiles automatically.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import dataclasses
import html
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import threading
import time
from typing import Iterable
from urllib.parse import quote, unquote, urlsplit, urlunsplit

SKIP_WORDS = ("alpha", "beta", "rc", "pre", "dev", "snapshot", "nightly", "preview")
BLOCKED_QUALIFIERS = (
    "alt", "cqp", "darwin", "dist", "extended", "init", "kernel", "linux",
    "headers", "macos", "sunos", "win32", "win64", "windows", "with-nspr", "xdoc",
    "x86_64", "aarch64",
)
# Compatibility/API branches that are intentionally maintained separately in BFSOS.
# The integer is the number of leading numeric components that must match current.
SERIES_LOCKS = {
    "core/linux-lts": 2,
    "gnome/gcr": 2,
    "gnome/libwnck2": 2,
    "gnome/libgweather": 1,
    "gnome/libpeas": 1,
    "opt/cairomm-1.0": 2,
    "opt/consolekit": 1,
    "opt/atkmm": 2,
    "opt/fuse2": 1,
    "opt/glibmm-2.4": 2,
    "opt/gtk": 2,
    "opt/gtk3": 2,
    "opt/gtkmm3": 2,
    "opt/libsigc++2": 1,
    "opt/libsoup": 2,
    "opt/lua": 2,
    "opt/lua52": 2,
    "opt/tcl": 2,
    "opt/pangomm": 2,
    "opt/spirv-llvm-translator": 1,
    "xorg/libva": 1,
    "compat-32/libva-32": 1,
    "compat-32/openssl11-32": 3,
    "compat-32/libpng12-32": 2,
    "compat-32/libjpeg6-turbo-32": 1,
    "compat-32/libtiff4-32": 1,
}
GSTREAMER_PORTS = {
    "opt/gstreamer", "opt/gst-libav", "opt/gst-plugins-bad",
    "opt/gst-plugins-base", "opt/gst-plugins-good", "opt/gst-plugins-ugly",
    "compat-32/gstreamer-32", "compat-32/gst-libav-32",
    "compat-32/gst-plugins-bad-32", "compat-32/gst-plugins-base-32",
    "compat-32/gst-plugins-good-32", "compat-32/gst-plugins-ugly-32",
}
WEBKIT_PORTS = {"gnome/webkitgtk", "gnome/webkitgtk-41"}
BLOCKED_PORT_VERSIONS = {
    # Historical/abandoned version lines whose numeric value sorts above the
    # actively maintained stable line.
    "opt/pango": {"1.90.0"},
    "compat-32/pango-32": {"1.90.0"},
    "opt/taglib": {"2.3.2"},
}
EVEN_MINOR_STABLE_PORTS = {
    "gnome/gnome-terminal",
    "opt/at-spi2-core", "opt/cairomm", "opt/cairomm-1.0", "opt/glib",
    "opt/glibmm", "opt/glibmm-2.4", "opt/glibmm-2.68",
    "opt/gobject-introspection", "opt/gtk4", "opt/gtkmm", "opt/gtkmm3",
    "opt/gtksourceview", "opt/libsoup3", "opt/pango", "opt/pangomm",
}
REMOTE_PREFIXES = ("http://", "https://", "ftp://")

# Stable upstream repositories used only for version discovery when the
# package tarball is hosted on a mirror/archive that does not expose a
# machine-readable directory index. These do not change package sources.
GIT_REPO_OVERRIDES = {
    "core/e2fsprogs": "https://git.kernel.org/pub/scm/fs/ext2/e2fsprogs.git",
    "core/dash": "https://github.com/herbertx/dash.git",
    "core/freetype": "https://gitlab.freedesktop.org/freetype/freetype.git",
    "core/libpng": "https://github.com/pnggroup/libpng.git",
    "core/squashfs-tools": "https://github.com/plougher/squashfs-tools.git",
    "opt/freeglut": "https://github.com/freeglut/freeglut.git",
    "opt/gparted": "https://gitlab.gnome.org/GNOME/gparted.git",
    "opt/libndp": "https://github.com/jpirko/libndp.git",
    "opt/smartmontools": "https://github.com/smartmontools/smartmontools.git",
    "opt/swig": "https://github.com/swig/swig.git",
    "opt/taglib": "https://github.com/taglib/taglib.git",
    "xorg/glew": "https://github.com/nigels-com/glew.git",
    "compat-32/glew-32": "https://github.com/nigels-com/glew.git",
    "compat-32/libndp-32": "https://github.com/jpirko/libndp.git",
    "compat-32/libwebp-32": "https://github.com/webmproject/libwebp.git",
    "opt/libwebp": "https://github.com/webmproject/libwebp.git",
    "opt/fdk-aac": "https://github.com/mstorsjo/fdk-aac.git",
    "opt/net-tools": "https://github.com/ecki/net-tools.git",
    "opt/mupdf": "https://github.com/ArtifexSoftware/mupdf-downloads.git",
    "opt/exempi": "https://gitlab.freedesktop.org/libopenraw/exempi.git",
    "opt/libstemmer": "https://github.com/snowballstem/snowball.git",
    "opt/openbox": "https://github.com/danakj/openbox.git",
    "opt/alsa-plugins": "https://github.com/alsa-project/alsa-plugins.git",
    "compat-32/alsa-plugins-32": "https://github.com/alsa-project/alsa-plugins.git",
    "opt/libburn": "https://dev.lovelyhq.com/libburnia/libburn.git",
    "opt/libisofs": "https://dev.lovelyhq.com/libburnia/libisofs.git",
    "opt/libisoburn": "https://dev.lovelyhq.com/libburnia/libisoburn.git",
    "xorg/mtdev": "http://bitmath.org/git/mtdev.git",
    "xorg/xorg-font-dejavu-ttf": "https://github.com/dejavu-fonts/dejavu-fonts.git",
    "compat-32/libpng12-32": "https://github.com/pnggroup/libpng.git",
    "compat-32/openssl11-32": "https://github.com/openssl/openssl.git",
    "core/procps-ng": "https://gitlab.com/procps-ng/procps.git",
    "core/psmisc": "https://gitlab.com/psmisc/psmisc.git",
    "lxqt/libfm-extra": "https://github.com/lxde/libfm.git",
    "lxqt/menu-cache": "https://github.com/lxde/menu-cache.git",
    "opt/cdrdao": "https://github.com/cdrdao/cdrdao.git",
    "opt/doxygen": "https://github.com/doxygen/doxygen.git",
    "opt/duktape": "https://github.com/svaarala/duktape.git",
    "opt/libraw": "https://github.com/LibRaw/LibRaw.git",
    "opt/poppler": "https://gitlab.freedesktop.org/poppler/poppler.git",
    "plasma/polkit-qt5": "https://invent.kde.org/libraries/polkit-qt-1.git",
}

# Ports whose BFSOS version is intentionally derived from a pinned commit,
# packaging date, or legacy downstream snapshot rather than a discoverable
# upstream release series.  Reporting these as UNVERIFIABLE is noise; they
# require a package-specific maintenance workflow instead.
DISCOVERY_POLICY_SKIPS = {
    "core/ca-certificates": "trust-bundle version is BFSOS packaging date; pinned NSS certdata is audited separately",
    "core/prt-utils": "BFSOS version is tied to an explicitly pinned CRUX commit",
    "opt/gn": "GN is pinned to the Chromium-compatible commit, not an independent release series",
    "opt/rapidjson": "BFSOS intentionally tracks a dated VCS snapshot/commit",
    "plasma/libdbusmenu-qt5": "legacy Ubuntu snapshot has no maintained upstream release series",
    "opt/libatasmart": "upstream is dormant at the final 0.19 release; source is mirrored for build reliability",
    "opt/openbox": "last formal upstream release is 3.6.1; current development tree contains unreleased 3.7 work",
    "opt/publicsuffix-list": "date-stamped data snapshot maintained by BFSOS; refresh uses the publicsuffix/list data-snapshot workflow rather than a release series",
}

PYPI_PROJECT_OVERRIDES = {
    "core/python3-docutils": "docutils",
    "opt/scons": "SCons",
}


@dataclasses.dataclass
class Port:
    path: Path
    rel: str
    name: str
    version: str
    sources: list[str]


@dataclasses.dataclass
class Result:
    port: Port
    status: str
    latest: str = ""
    provider: str = ""
    reason: str = ""
    source: str = ""


class FetchError(RuntimeError):
    pass


class HttpCache:
    def __init__(self, timeout: int):
        self.timeout = timeout
        self._lock = threading.Lock()
        self._cache: dict[str, tuple[bool, str]] = {}
        self._events: dict[str, threading.Event] = {}

    def get(self, url: str) -> str:
        with self._lock:
            if url in self._cache:
                ok, value = self._cache[url]
                if ok:
                    return value
                raise FetchError(value)
            if url in self._events:
                event = self._events[url]
                owner = False
            else:
                event = threading.Event()
                self._events[url] = event
                owner = True

        if not owner:
            event.wait()
            with self._lock:
                ok, value = self._cache[url]
            if ok:
                return value
            raise FetchError(value)

        try:
            cp = subprocess.run(
                [
                    "curl", "--fail", "--location", "--silent", "--show-error", "--retry", "2", "--retry-all-errors", "--retry-delay", "1",
                    "--compressed", "--connect-timeout", "8", "--max-time",
                    str(self.timeout), "--user-agent", "BFSOS-checkupdate/11", url,
                ],
                text=True,
                encoding="utf-8", errors="replace",
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=self.timeout + 12,
                env={**os.environ, "LC_ALL": "C"},
            )
            if cp.returncode != 0:
                msg = cp.stderr.strip() or f"curl exit {cp.returncode}"
                raise FetchError(msg)
            value = cp.stdout
            with self._lock:
                self._cache[url] = (True, value)
            return value
        except (subprocess.TimeoutExpired, FetchError) as exc:
            msg = "timeout" if isinstance(exc, subprocess.TimeoutExpired) else str(exc)
            with self._lock:
                self._cache[url] = (False, msg)
            raise FetchError(msg)
        finally:
            with self._lock:
                self._events.pop(url, None)
                event.set()

    def exists(self, url: str) -> tuple[bool, str]:
        common = [
            "curl", "--fail", "--location", "--silent", "--show-error", "--retry", "2", "--retry-all-errors", "--retry-delay", "1",
            "--connect-timeout", "8", "--max-time", str(self.timeout),
            "--user-agent", "BFSOS-checkupdate/11",
        ]
        errors: list[str] = []
        for extra in (["--head"], ["--range", "0-0", "--output", "/dev/null"]):
            try:
                cp = subprocess.run(
                    common + extra + [url],
                    text=True, encoding="utf-8", errors="replace",
                    stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
                    timeout=self.timeout + 12, env={**os.environ, "LC_ALL": "C"},
                )
                if cp.returncode == 0:
                    return True, ""
                err = cp.stderr.strip() or f"curl exit {cp.returncode}"
                # HTTP 416 from a 0-0 range probe proves the endpoint exists,
                # even though the server rejects the byte-range semantics.
                if "416" in err and "--range" in extra:
                    return True, "range probe returned HTTP 416"
                errors.append(err)
            except subprocess.TimeoutExpired:
                errors.append("timeout")
        return False, errors[-1] if errors else "source check failed"


    def resolve(self, url: str) -> tuple[str, str]:
        """Resolve redirects without keeping the response body."""
        cmd = [
            "curl", "--fail", "--location", "--silent", "--show-error", "--retry", "2", "--retry-all-errors", "--retry-delay", "1",
            "--connect-timeout", "8", "--max-time", str(self.timeout),
            "--user-agent", "BFSOS-checkupdate/11", "--range", "0-0",
            "--output", "/dev/null", "--write-out", "%{url_effective}", url,
        ]
        try:
            cp = subprocess.run(
                cmd, text=True, encoding="utf-8", errors="replace",
                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                timeout=self.timeout + 12, env={**os.environ, "LC_ALL": "C"},
            )
        except subprocess.TimeoutExpired as exc:
            raise FetchError("timeout") from exc
        if cp.returncode != 0:
            msg = cp.stderr.strip() or f"curl exit {cp.returncode}"
            head = cmd[:]
            range_i = head.index("--range")
            del head[range_i:range_i + 2]
            head.insert(range_i, "--head")
            cp = subprocess.run(
                head, text=True, encoding="utf-8", errors="replace",
                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                timeout=self.timeout + 12, env={**os.environ, "LC_ALL": "C"},
            )
            if cp.returncode != 0:
                raise FetchError(cp.stderr.strip() or msg)
        effective = cp.stdout.strip()
        if not effective:
            raise FetchError("redirect resolver returned no effective URL")
        return effective, ""


def gcc_release_directory(port: Port, http: HttpCache) -> tuple[str | None, str, str]:
    """Enumerate sibling gcc-X.Y.Z release directories, not one release dir."""
    index = "https://gcc.gnu.org/pub/gcc/releases/"
    text = http.get(index)
    vals = re.findall(r"(?:href=[\"']|>)(?:gcc-)([0-9][0-9A-Za-z._+~-]*)/?", text, re.I)
    vals = uniq_sorted_versions(vals, port.version, port, "gcc-releases")
    if port.version not in vals:
        return None, "gcc-releases", "current GCC release directory is not present in upstream release index"
    latest, reason = choose_verified(port.version, vals, port, "gcc-releases")
    return latest, "gcc-releases", reason


def nss_release_directory(port: Port, http: HttpCache) -> tuple[str | None, str, str]:
    """Enumerate NSS RTM release directories instead of one version-specific directory."""
    index = "https://archive.mozilla.org/pub/security/nss/releases/"
    text = http.get(index)
    vals = []
    for raw in re.findall(r"NSS_([0-9]+(?:_[0-9]+)+)_RTM/?", text, re.I):
        vals.append(raw.replace("_", "."))
    vals = uniq_sorted_versions(vals, port.version, port, "nss-releases")
    if port.version not in vals:
        return None, "nss-releases", "current NSS RTM directory is not present in upstream release index"
    latest, reason = choose_verified(port.version, vals, port, "nss-releases")
    return latest, "nss-releases", reason


def discord_stable(port: Port, http: HttpCache) -> tuple[str | None, str, str]:
    """Use Discord's stable Linux download redirect as the authoritative channel."""
    endpoint = "https://discord.com/api/download/stable?platform=linux&format=tar.gz"
    effective, _ = http.resolve(endpoint)
    m = re.search(r"/apps/linux/([^/]+)/discord-([^/]+)\.tar\.gz(?:$|[?#])", effective)
    if not m or m.group(1) != m.group(2):
        return None, "discord-stable", f"stable redirect did not resolve to a versioned Linux tarball: {effective}"
    latest = m.group(1)
    if not candidate_allowed(latest, port.version, port, "discord-stable"):
        return None, "discord-stable", f"resolved version rejected by stable-channel policy: {latest}"
    latest = only_if_newer(port.version, latest)
    return latest, "discord-stable", ""


def natural_key(v: str):
    # Comparable across ordinary upstream versions without depending on packaging.
    parts = re.split(r"([0-9]+)", v.lower().replace("~", "-").replace("_", "."))
    return tuple((0, int(p)) if p.isdigit() else (1, p) for p in parts if p != "")


def numeric_components(v: str) -> tuple[int, ...]:
    nums = re.findall(r"\d+", v)
    return tuple(int(x) for x in nums)


def is_prerelease(v: str, current: str = "") -> bool:
    low = v.lower()
    current_low = current.lower()
    for word in SKIP_WORDS:
        if word in low and word not in current_low:
            return True
    # PEP 440 / common upstream forms such as 3.3.0b1, 3.0.0a7, 2.1b1.
    if re.search(r"(?<=\d)(?:a|b|rc)\d+(?:$|[._+-])", low) and not re.search(
        r"(?<=\d)(?:a|b|rc)\d+(?:$|[._+-])", current_low
    ):
        return True
    if re.search(r"(?:^|[._+-])(?:a|b|rc)\d+(?:$|[._+-])", low) and not re.search(
        r"(?:^|[._+-])(?:a|b|rc)\d+(?:$|[._+-])", current_low
    ):
        return True
    # Common upstream development-version convention.
    if ".99." in low and ".99." not in current_low:
        return True
    return False


def candidate_allowed(v: str, current: str, port: Port | None = None, provider: str = "") -> bool:
    if v == current:
        return True
    # Preserve explicit release channels.  In particular, Mozilla ESR ports
    # must never be "updated" to a numerically newer rapid-release build.
    # The same rule protects explicit LTS-labelled packages/providers.
    current_low = current.lower()
    candidate_low = v.lower()
    for channel in ("esr", "lts"):
        if channel in current_low and channel not in candidate_low:
            return False
    # Never allow unresolved build/documentation template fragments to become
    # package versions.  This must live in the provider layer, not only in the
    # interactive updater, so junk such as OpenLDAP's LMDB_2.MP tag can never
    # reach comparison or picker generation.
    if re.search(r"(?:^|[._+~-])(?:MP|BP|MAJOR|MINOR|PATCH|VERSION)(?:$|[._+~-])", v):
        return False
    if any(tok in v for tok in ("${", "$version", "$name", "<version>", "@VERSION@")):
        return False
    if not re.search(r"\d", v) or is_prerelease(v, current):
        return False

    low = v.lower()
    cur_low = current.lower()
    for word in BLOCKED_QUALIFIERS:
        if word in low and word not in cur_low:
            return False

    cur_nums = numeric_components(current)
    cand_nums = numeric_components(v)
    # Semantic-version ports must not be hijacked by unrelated historical date tags.
    if cur_nums and cand_nums and cur_nums[0] < 100 and cand_nums[0] >= 1000:
        return False

    if port is not None:
        if v in BLOCKED_PORT_VERSIONS.get(port.rel, set()):
            return False
        lock = SERIES_LOCKS.get(port.rel)
        if lock and (len(cur_nums) < lock or len(cand_nums) < lock or cur_nums[:lock] != cand_nums[:lock]):
            return False

        # GNOME libraries traditionally use odd minor numbers for development
        # snapshots; keep those out when the installed line is an even stable line.
        if provider == "gnome-cache" and len(cand_nums) >= 2 and 1 <= cand_nums[0] <= 9:
            if len(cur_nums) >= 2 and cur_nums[1] % 2 == 0 and cand_nums[1] % 2 == 1:
                return False

        # GStreamer explicitly documents odd minor series as development snapshots.
        if port.rel in GSTREAMER_PORTS and len(cand_nums) >= 2 and cand_nums[1] % 2 == 1:
            return False

        # WebKitGTK odd minor series are development releases leading to the next even series.
        if port.rel in WEBKIT_PORTS and len(cand_nums) >= 2 and cand_nums[1] % 2 == 1:
            return False

        # Perl uses odd second components for development releases.
        if port.rel == "core/perl" and len(cand_nums) >= 2 and cand_nums[1] % 2 == 1:
            return False

        # Several GNOME-adjacent libraries use odd minor numbers for their
        # development series even when release tarballs are hosted elsewhere.
        if port.rel in EVEN_MINOR_STABLE_PORTS and len(cand_nums) >= 2:
            if len(cur_nums) >= 2 and cur_nums[1] % 2 == 0 and cand_nums[1] % 2 == 1:
                return False

        # SourceForge projects often expose snapshots and legacy artifact names
        # alongside formal releases.  Keep release-tracking ports on their
        # actual release lineage instead of comparing filename noise.
        if port.rel == "opt/gutenprint" and provider == "sourceforge":
            if not re.fullmatch(r"[0-9]+(?:\.[0-9]+)+", v):
                return False
        if port.rel == "opt/lame" and provider == "sourceforge":
            if not re.fullmatch(r"[0-9]+(?:\.[0-9]+)+", v):
                return False

    return True


def uniq_sorted_versions(values: Iterable[str], current: str, port: Port | None = None, provider: str = "") -> list[str]:
    clean: set[str] = set()
    for v in values:
        v = html.unescape(v).strip().strip("/\"'")
        v = re.sub(r"\.(?:tar\.(?:gz|bz2|xz|zst)|tgz|tbz2|zip)$", "", v)
        if v and candidate_allowed(v, current, port, provider):
            clean.add(v)
    return sorted(clean, key=natural_key)


def choose_verified(current: str, candidates: Iterable[str], port: Port | None = None, provider: str = "") -> tuple[str | None, str]:
    vals = uniq_sorted_versions(candidates, current, port, provider)
    if current not in vals:
        return None, "provider results do not contain the current version"
    return vals[-1], ""


def only_if_newer(current: str, candidate: str | None) -> str | None:
    """Reject cross-series/provider candidates that do not advance current."""
    if not candidate:
        return None
    if natural_key(candidate) <= natural_key(current):
        return current
    return candidate

def eval_pkgfile(pkgfile: Path) -> Port:
    script = r'''
set +u
source "$1" >/dev/null 2>&1 || exit 31
printf '%s\0%s\0' "${name-}" "${version-}"
if declare -p source >/dev/null 2>&1; then
  if declare -p source 2>/dev/null | grep -q '^declare -a'; then
    printf '%s\0' "${source[@]}"
  else
    printf '%s\0' "${source}"
  fi
fi
'''
    cp = subprocess.run(
        ["bash", "--noprofile", "--norc", "-c", script, "bfs-checkupdate", str(pkgfile)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=8,
    )
    if cp.returncode != 0:
        raise RuntimeError(f"Pkgfile evaluation failed ({cp.returncode})")
    fields = cp.stdout.decode("utf-8", "replace").split("\0")
    if fields and fields[-1] == "":
        fields.pop()
    if len(fields) < 2:
        raise RuntimeError("Pkgfile did not define name/version")
    name, version, *sources = fields
    root = pkgfile.parents[2]
    rel = str(pkgfile.parent.relative_to(root))
    return Port(pkgfile.parent, rel, name, version, sources)


def remote_sources(port: Port) -> list[str]:
    out: list[str] = []
    for src in port.sources:
        src = src.strip()
        if "::" in src:
            left, right = src.split("::", 1)
            if right.startswith(REMOTE_PREFIXES):
                src = right
        if src.startswith(REMOTE_PREFIXES):
            out.append(src)
    return out


def hrefs(text: str) -> list[str]:
    return [html.unescape(x) for x in re.findall(r'''href\s*=\s*["']([^"']+)["']''', text, re.I)]


def versions_from_filename_listing(text: str, basename: str, current: str) -> list[str]:
    if current not in basename:
        return []
    prefix, suffix = basename.split(current, 1)
    rx = re.compile(re.escape(prefix) + r"([0-9][0-9A-Za-z._+~:-]*)" + re.escape(suffix) + r"(?:$|[?#])")
    vals = []
    for h in hrefs(text) + re.findall(r"[^\s<>\"']+", text):
        b = h.rsplit("/", 1)[-1]
        m = rx.search(b)
        if m:
            vals.append(m.group(1))
    return vals


def generic_directory(port: Port, source: str, http: HttpCache) -> tuple[str | None, str, str]:
    u = urlsplit(source)
    path = u.path
    basename = path.rsplit("/", 1)[-1]

    variants: list[tuple[str, callable]] = [(port.version, lambda x: x)]
    if "." in port.version:
        variants.append((port.version.replace(".", "_"), lambda x: x.replace("_", ".")))
    if "_" in port.version:
        variants.append((port.version.replace("_", "-"), lambda x: x.replace("-", "_")))
    if ".pre" in port.version:
        variants.append((port.version.replace(".pre", "~pre"), lambda x: x.replace("~pre", ".pre")))

    token = ""
    transform = lambda x: x
    for candidate, fn in variants:
        if candidate and candidate in basename:
            token, transform = candidate, fn
            break
    if not token:
        return None, "directory", "current version is not present in source filename under a known encoding"

    parent = path.rsplit("/", 1)[0] + "/"
    index = urlunsplit((u.scheme, u.netloc, parent, "", ""))
    text = http.get(index)

    prefix, suffix = basename.split(token, 1)
    rx = re.compile(re.escape(prefix) + r"([0-9][0-9A-Za-z._+~:-]*)" + re.escape(suffix) + r"(?:$|[?#])")
    vals = []
    for h in hrefs(text) + re.findall(r"[^\\s<>\\\"']+", text):
        b = h.rsplit("/", 1)[-1]
        m = rx.search(b)
        if m:
            vals.append(transform(m.group(1)))
    latest, reason = choose_verified(port.version, vals, port, "directory")
    return latest, "directory", reason


def git_repo_from_source(source: str) -> str | None:
    u = urlsplit(source)
    host = u.netloc.lower()
    parts = [p for p in u.path.split("/") if p]
    if host == "github.com" and len(parts) >= 2:
        repo = parts[1]
        if repo.endswith(".git"):
            repo = repo[:-4]
        return f"https://github.com/{parts[0]}/{repo}.git"
    if host.startswith("gitlab.") or host == "gitlab.com" or "-/archive" in u.path:
        if "-" in parts:
            cut = parts.index("-")
            parts = parts[:cut]
        elif "archive" in parts:
            parts = parts[:parts.index("archive")]
        if parts:
            repo = "/".join(parts)
            if not repo.endswith(".git"):
                repo += ".git"
            return f"{u.scheme}://{u.netloc}/{repo}"
    if host == "codeberg.org" and len(parts) >= 2:
        repo = "/".join(parts[:2])
        return f"https://codeberg.org/{repo}.git"
    if host == "git.kernel.org":
        m = re.search(r"(.+?\.git)(?:/|$)", u.path)
        if m:
            return f"{u.scheme}://{u.netloc}{m.group(1)}"
    return None


def git_tag_versions(tags: list[str], current: str) -> tuple[list[str], str]:
    reps = [
        (current, lambda x: x),
        (current.replace(".", "_"), lambda x: x.replace("_", ".")),
        (current.replace(".", "-"), lambda x: x.replace("-", ".")),
    ]
    if current.startswith("v") and len(current) > 1:
        bare = current[1:]
        reps.extend([
            (bare, lambda x: "v" + x),
            (bare.replace(".", "_"), lambda x: "v" + x.replace("_", ".")),
            (bare.replace(".", "-"), lambda x: "v" + x.replace("-", ".")),
        ])
    best: list[str] = []
    for rep, transform in reps:
        if rep not in " ".join(tags):
            continue
        patterns: list[tuple[str, str]] = []
        for tag in tags:
            idx = tag.find(rep)
            if idx >= 0:
                patterns.append((tag[:idx], tag[idx + len(rep):]))
        for prefix, suffix in patterns:
            vals: list[str] = []
            for tag in tags:
                if not tag.startswith(prefix) or (suffix and not tag.endswith(suffix)):
                    continue
                end = len(tag) - len(suffix) if suffix else len(tag)
                middle = tag[len(prefix):end]
                v = transform(middle)
                if re.fullmatch(r"[0-9][0-9A-Za-z._+~-]*", v) or (
                    current.startswith("v") and re.fullmatch(r"v[0-9][0-9A-Za-z._+~-]*", v)
                ):
                    vals.append(v)
            if current in vals and len(vals) > len(best):
                best = vals
    if not best:
        return [], "could not derive a tag pattern that maps back to the current version"
    return best, ""


def git_tags(port: Port, source: str, timeout: int, repo_override: str | None = None) -> tuple[str | None, str, str]:
    repo = repo_override or git_repo_from_source(source)
    if not repo:
        return None, "git-tags", "could not infer repository URL"
    try:
        cp = subprocess.run(
            ["git", "ls-remote", "--tags", "--refs", repo],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout + 4,
            env={**os.environ, "GIT_TERMINAL_PROMPT": "0", "LC_ALL": "C"},
        )
    except subprocess.TimeoutExpired:
        raise FetchError(f"git tag query timed out: {repo}")
    if cp.returncode != 0:
        raise FetchError(cp.stderr.strip() or f"git ls-remote exit {cp.returncode}")
    tags = []
    for line in cp.stdout.splitlines():
        if "\trefs/tags/" in line:
            tags.append(line.split("\trefs/tags/", 1)[1])

    # OpenLDAP publishes many template/example tags in the same repository as
    # LMDB.  Only concrete LMDB_<numeric-version> tags belong to this port.
    if port.rel == "opt/lmdb":
        vals = [m.group(1) for tag in tags if (m := re.fullmatch(r"LMDB_([0-9]+(?:\.[0-9]+)+)", tag))]
        latest, reason = choose_verified(port.version, vals, port, "git-tags")
        return latest, "git-tags", reason

    vals, reason = git_tag_versions(tags, port.version)
    if reason:
        return None, "git-tags", reason
    latest, reason = choose_verified(port.version, vals, port, "git-tags")
    return latest, "git-tags", reason


def gnome(port: Port, source: str, http: HttpCache) -> tuple[str | None, str, str]:
    m = re.search(r"/(?:pub/(?:GNOME|gnome)/)?sources/([^/]+)/", unquote(urlsplit(source).path), re.I)
    if not m:
        return None, "gnome-cache", "could not infer GNOME module"
    module = m.group(1)
    url = f"https://download.gnome.org/sources/{module}/cache.json"
    text = http.get(url)
    # cache.json contains source paths; matching the module filename is resilient
    # across cache schema revisions.
    rx = re.compile(re.escape(module) + r"-([0-9][0-9A-Za-z._+~-]*)\.tar\.(?:xz|gz|bz2|zst)")
    vals = rx.findall(text)
    latest, reason = choose_verified(port.version, vals, port, "gnome-cache")
    return latest, "gnome-cache", reason


def pypi(port: Port, source: str, http: HttpCache) -> tuple[str | None, str, str]:
    basename = urlsplit(source).path.rsplit("/", 1)[-1]
    candidates: list[str] = []
    if port.version in basename:
        prefix = basename.split(port.version, 1)[0].rstrip("-_.")
        if prefix:
            candidates.append(prefix.replace("_", "-"))
    for x in (port.name, re.sub(r"^(?:python3?|py)-", "", port.name)):
        if x and x not in candidates:
            candidates.append(x)
    last = ""
    for project in candidates[:3]:
        try:
            text = http.get(f"https://pypi.org/pypi/{project}/json")
            data = json.loads(text)
        except (FetchError, json.JSONDecodeError) as exc:
            last = str(exc)
            continue
        releases = data.get("releases", {})
        if port.version not in releases:
            last = f"PyPI project {project!r} does not contain current version"
            continue
        vals = releases.keys()
        latest, reason = choose_verified(port.version, vals, port, f"pypi:{project}")
        return latest, f"pypi:{project}", reason
    if last.startswith("curl") or last == "timeout":
        raise FetchError(last)
    return None, "pypi", last or "could not map package name to PyPI project"


def numeric_dirs(text: str) -> list[str]:
    vals = []
    for h in hrefs(text):
        x = h.strip("/")
        if re.fullmatch(r"[0-9]+(?:\.[0-9]+){0,3}", x):
            vals.append(x)
    return vals


def kde(port: Port, source: str, http: HttpCache) -> tuple[str | None, str, str]:
    u = urlsplit(source)
    path = u.path
    base = f"{u.scheme}://{u.netloc}"
    basename = path.rsplit("/", 1)[-1]

    suite = None
    root = None
    child_suffix = ""
    same_major = False
    for marker, name, suffix, sm in (
        ("/stable/plasma/", "plasma", "", False),
        ("/stable/release-service/", "release-service", "/src", False),
        ("/stable/frameworks/", "frameworks", "", True),
    ):
        if marker in path:
            suite = name
            root = base + marker
            child_suffix = suffix
            same_major = sm
            break
    if not root:
        return generic_directory(port, source, http)

    top = http.get(root)
    dirs = uniq_sorted_versions(numeric_dirs(top), port.version)
    if same_major:
        major = port.version.split(".", 1)[0]
        dirs = [d for d in dirs if d.split(".", 1)[0] == major]
    if not dirs:
        return None, f"kde-{suite}", "no stable release directories found"
    release_dir = dirs[-1]
    child = f"{root}{release_dir}{child_suffix}/"
    listing = http.get(child)

    # Most KDE coordinated suites carry the release version in every tarball.
    # Frameworks uses X.Y directories while tarballs normally use X.Y.Z.
    vals = versions_from_filename_listing(listing, basename, port.version)
    latest, reason = choose_verified(port.version, vals, port, f"kde-{suite}")
    if latest:
        return latest, f"kde-{suite}", ""

    # If the current version lives in an older directory, inspect its listing as
    # well so current-version mapping can be established, then use the candidate
    # release directory only if the same package exists there.
    current_dir = None
    if suite == "frameworks":
        bits = port.version.split(".")
        current_dir = ".".join(bits[:2]) if len(bits) >= 2 else port.version
    else:
        current_dir = port.version
    current_child = f"{root}{current_dir}{child_suffix}/"
    try:
        current_listing = http.get(current_child)
    except FetchError:
        return None, f"kde-{suite}", reason
    current_vals = versions_from_filename_listing(current_listing, basename, port.version)
    if port.version not in current_vals:
        return None, f"kde-{suite}", "current package not present in KDE suite index"

    candidate_names = hrefs(listing)
    # Build a basename template from current and look for any versioned match.
    if port.version in basename:
        prefix, suffix = basename.split(port.version, 1)
        rx = re.compile(r"(?:^|/)" + re.escape(prefix) + r"([0-9][0-9A-Za-z._+~-]*)" + re.escape(suffix) + r"$")
        vals2 = [m.group(1) for h in candidate_names if (m := rx.search(h))]
        vals2 = uniq_sorted_versions(vals2, port.version, port, f"kde-{suite}")
        if vals2:
            return only_if_newer(port.version, vals2[-1]), f"kde-{suite}", ""
    return None, f"kde-{suite}", "package not found in newest compatible KDE release directory"


def xfce(port: Port, source: str, http: HttpCache) -> tuple[str | None, str, str]:
    u = urlsplit(source)
    m = re.search(r"(/src/[^/]+/[^/]+/)([0-9]+\.[0-9]+)/", u.path)
    if not m:
        return generic_directory(port, source, http)
    root = f"{u.scheme}://{u.netloc}{m.group(1)}"
    top = http.get(root)
    dirs = uniq_sorted_versions(numeric_dirs(top), port.version)
    # Xfce core 4.x uses odd minor series for development. 0.x plugin
    # series do not follow that convention (for example 0.5.x pulseaudio).
    dirs = [
        d for d in dirs
        if len(numeric_components(d)) < 2
        or numeric_components(d)[0] != 4
        or numeric_components(d)[1] % 2 == 0
    ]
    if not dirs:
        return None, "xfce-index", "no release-series directories found"
    series = dirs[-1]
    listing = http.get(root + series + "/")
    basename = u.path.rsplit("/", 1)[-1]
    vals = versions_from_filename_listing(listing, basename, port.version)
    if port.version in vals:
        latest, reason = choose_verified(port.version, vals, port, "xfce-index")
        return latest, "xfce-index", reason

    # Current may be in an older series. Prove it there, then find the package in
    # the newest series.
    old_series = m.group(2)
    old_listing = http.get(root + old_series + "/")
    old_vals = versions_from_filename_listing(old_listing, basename, port.version)
    if port.version not in old_vals:
        return None, "xfce-index", "current package not present in Xfce index"
    if port.version not in basename:
        return None, "xfce-index", "current version not literal in source filename"
    prefix, suffix = basename.split(port.version, 1)
    rx = re.compile(r"(?:^|/)" + re.escape(prefix) + r"([0-9][0-9A-Za-z._+~-]*)" + re.escape(suffix) + r"$")
    vals2 = [m.group(1) for h in hrefs(listing) if (m := rx.search(h))]
    vals2 = uniq_sorted_versions(vals2, port.version, port, "xfce-index")
    if vals2:
        return only_if_newer(port.version, vals2[-1]), "xfce-index", ""
    return None, "xfce-index", "package not found in newest Xfce release series"


def netfilter_release_page(port: Port, http: HttpCache) -> tuple[str | None, str, str]:
    module = port.name
    url = f"https://www.netfilter.org/projects/{module}/downloads.html"
    text = http.get(url)
    rx = re.compile(re.escape(module) + r"-([0-9][0-9A-Za-z._+~-]*)\.tar\.(?:xz|bz2|gz)")
    vals = rx.findall(text)
    latest, reason = choose_verified(port.version, vals, port, "netfilter")
    return latest, "netfilter", reason



def _github_tag_version(tag: str, current_tag: str, current: str) -> str | None:
    """Map TAG through the exact encoding/prefix used by CURRENT_TAG."""
    variants = [
        (current, lambda x: x),
        (current.replace('.', '_'), lambda x: x.replace('_', '.')),
        (current.replace('.', '-'), lambda x: x.replace('-', '.')),
        (current.replace('.', ''), None),
    ]
    for encoded, transform in variants:
        if not encoded or encoded not in current_tag:
            continue
        prefix, suffix = current_tag.split(encoded, 1)
        if not tag.startswith(prefix) or (suffix and not tag.endswith(suffix)):
            continue
        finish = len(tag) - len(suffix) if suffix else len(tag)
        middle = tag[len(prefix):finish]
        if transform is not None:
            value = transform(middle)
        else:
            # Condensed tags such as Ghostscript gs10080 map 10.08.0 -> 10080.
            components = re.findall(r"\d+", current)
            if not components or not middle.isdigit():
                continue
            widths = [len(x) for x in components]
            cur_digits = ''.join(components)
            if encoded != cur_digits or len(middle) != len(encoded):
                continue
            pos = 0
            parts = []
            for width in widths:
                parts.append(middle[pos:pos + width])
                pos += width
            value = '.'.join(parts)
        # Preserve the current release-family shape.  A numeric package version
        # must not be reinterpreted as a sibling component name such as
        # libvisual-plugins-0.4.2 merely because the repository prefix matches.
        if current[:1].isdigit() and value and not value[:1].isdigit():
            continue
        if value == current:
            return value
        if value and candidate_allowed(value, current):
            return value
    return None


def _github_expected_asset_name(source: str, current: str, candidate: str) -> str:
    basename = unquote(urlsplit(source).path.rsplit('/', 1)[-1])
    variants = [
        (current, candidate),
        (current.replace('.', '_'), candidate.replace('.', '_')),
        (current.replace('.', '-'), candidate.replace('.', '-')),
    ]
    for old, new in variants:
        if old and old in basename:
            return basename.replace(old, new, 1)
    return basename


def _github_release_url(owner: str, repo: str, tag: str, asset: str) -> str:
    return f"https://github.com/{owner}/{repo}/releases/download/{tag}/{asset}"


def _github_repo_tags(owner: str, repo: str, timeout: int) -> list[str]:
    """Read public GitHub tags without consuming the GitHub REST API quota."""
    url = f"https://github.com/{owner}/{repo}.git"
    try:
        cp = subprocess.run(
            ["git", "ls-remote", "--tags", "--refs", url],
            text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            timeout=timeout + 4,
            env={**os.environ, "GIT_TERMINAL_PROMPT": "0", "LC_ALL": "C"},
        )
    except subprocess.TimeoutExpired as exc:
        raise FetchError(f"GitHub tag fallback timed out for {owner}/{repo}") from exc
    if cp.returncode != 0:
        raise FetchError(cp.stderr.strip() or f"git ls-remote exit {cp.returncode}")
    return [
        line.split("\trefs/tags/", 1)[1]
        for line in cp.stdout.splitlines()
        if "\trefs/tags/" in line
    ]


def github_published_release(port: Port, source: str, http: HttpCache) -> tuple[str | None, str, str]:
    """Discover GitHub release assets without trusting tag names alone.

    The release API is preferred because it identifies drafts/prereleases, but
    public tag discovery is used when that API is rate-limited.  In both paths
    a candidate is accepted only when the exact source archive URL derived from
    the BFSOS port is reachable.  This simultaneously preserves sibling-family
    protection and avoids false UNVERIFIABLE results when GitHub metadata omits
    or prunes an otherwise reachable release asset.
    """
    u = urlsplit(source)
    path = unquote(u.path)
    parts = [x for x in path.split('/') if x]
    if len(parts) < 5 or parts[2:4] != ['releases', 'download']:
        return None, 'github-release', 'source is not a GitHub release asset'
    owner, repo = parts[0], parts[1]
    current_asset = parts[-1]
    marker = '/releases/download/'
    tail = path.split(marker, 1)[1]
    if not tail.endswith('/' + current_asset):
        return None, 'github-release', 'could not derive current GitHub release tag from source URL'
    current_tag = tail[:-(len(current_asset) + 1)]

    # Compatibility path for older synthetic tests which expose only resolve().
    if not hasattr(http, 'get'):
        effective, _ = http.resolve(f'https://github.com/{owner}/{repo}/releases/latest')
        m = re.search(r'/releases/tag/(.+?)(?:[?#]|$)', effective)
        if not m:
            return None, 'github-release', f'latest release did not resolve to a tag: {effective}'
        latest_tag = unquote(m.group(1))
        latest = _github_tag_version(latest_tag, current_tag, port.version)
        if latest is None:
            return None, 'github-release', f'published tag belongs to a different release family: {latest_tag}'
        expected = _github_expected_asset_name(source, port.version, latest)
        candidate_source = _github_release_url(owner, repo, latest_tag, expected)
        exists, why_exists = http.exists(candidate_source)
        if not exists:
            return None, 'github-release', f'published tag has no matching release asset: {candidate_source}: {why_exists}'
        return only_if_newer(port.version, latest), 'github-release', ''

    api = f'https://api.github.com/repos/{owner}/{repo}/releases?per_page=100'
    releases = None
    api_error = ''
    try:
        decoded = json.loads(http.get(api))
        if isinstance(decoded, list):
            releases = decoded
        else:
            api_error = 'GitHub releases API returned an unexpected payload'
    except (FetchError, json.JSONDecodeError) as exc:
        api_error = str(exc)

    tag_rows: list[tuple[str, set[str]]] = []
    provider = 'github-release'
    if releases is not None:
        for rel in releases:
            if rel.get('draft') or rel.get('prerelease'):
                continue
            tag = str(rel.get('tag_name', ''))
            if not tag:
                continue
            names = {str(a.get('name', '')) for a in (rel.get('assets') or [])}
            tag_rows.append((tag, names))
    else:
        # API 403/rate-limit failures are provider-infrastructure failures, not
        # package failures.  Fall back to public git tags and retain exact asset
        # existence checks before accepting any candidate.
        try:
            tags = _github_repo_tags(owner, repo, getattr(http, 'timeout', 12))
        except FetchError as exc:
            detail = f'GitHub releases API failed: {api_error}; git-tag fallback failed: {exc}'
            raise FetchError(detail) from exc
        tag_rows = [(tag, set()) for tag in tags]
        provider = 'github-release+git-tags'

    candidates: list[str] = []
    rejected_family: list[str] = []

    # The current source URL itself is the strongest proof for the current
    # release, even when GitHub has pruned/renamed release metadata assets.
    metadata_current = any(
        current_asset in names and _github_tag_version(tag, current_tag, port.version) == port.version
        for tag, names in tag_rows
    )
    if metadata_current:
        current_ok, current_why = True, ''
    elif hasattr(http, 'exists'):
        current_ok, current_why = http.exists(source)
    else:
        current_ok = False
        current_why = 'current asset absent from supplied release metadata'
    if current_ok:
        candidates.append(port.version)

    for tag, asset_names in tag_rows:
        version = _github_tag_version(tag, current_tag, port.version)
        if version is None:
            rejected_family.append(tag)
            continue
        if not candidate_allowed(version, port.version, port, 'github-release'):
            continue
        if version == port.version and current_ok:
            continue
        if version != port.version and natural_key(version) <= natural_key(port.version):
            continue
        expected = _github_expected_asset_name(source, port.version, version)
        candidate_source = _github_release_url(owner, repo, tag, expected)
        # Asset metadata is a fast positive signal, but direct URL validation is
        # authoritative for projects whose API metadata omits/prunes old assets.
        if expected not in asset_names:
            if not hasattr(http, 'exists'):
                continue
            exists, _why = http.exists(candidate_source)
            if not exists:
                continue
        candidates.append(version)

    latest, reason = choose_verified(port.version, candidates, port, 'github-release')
    if latest is None:
        if not current_ok:
            reason = f'{reason}; current release source not reachable: {current_why}'
        if rejected_family:
            reason += '; sibling/nonmatching release families ignored'
        if api_error and releases is None:
            reason += f'; API fallback used after: {api_error}'
        return None, provider, reason
    return latest, provider, ''

def sqlite_release_page(port: Port, http: HttpCache) -> tuple[str | None, str, str]:
    text = http.get('https://www.sqlite.org/download.html')
    ids = re.findall(r'(?:sqlite-(?:autoconf|src|amalgamation)-)(\d{7})', text)
    vals=[]
    for raw in ids:
        n=int(raw)
        major=n//1000000; minor=(n//10000)%100; patch=(n//100)%100; sub=n%100
        v=f'{major}.{minor}.{patch}' + (f'.{sub}' if sub else '')
        vals.append(v)
    latest, reason = choose_verified(port.version, vals, port, 'sqlite-download')
    return latest, 'sqlite-download', reason


def npm_registry(port: Port, source: str, http: HttpCache) -> tuple[str | None, str, str]:
    u=urlsplit(source)
    parts=[unquote(x) for x in u.path.split('/') if x]
    # npm tarballs are normally /PACKAGE/-/PACKAGE-VERSION.tgz; scoped packages
    # encode the slash in the first path component.
    if not parts:
        return None, 'npm', 'could not infer package name'
    pkg=parts[0]
    if pkg.startswith('@') and len(parts) > 1 and parts[1] != '-':
        pkg += '/' + parts[1]
    text=http.get('https://registry.npmjs.org/' + pkg.replace('/', '%2f'))
    data=json.loads(text)
    versions=(data.get('versions') or {}).keys()
    latest, reason=choose_verified(port.version, versions, port, f'npm:{pkg}')
    return latest, f'npm:{pkg}', reason


def sourceforge_files(port: Port, source: str, http: HttpCache) -> tuple[str | None, str, str]:
    """Discover SourceForge releases from the project file browser/RSS.

    Direct download hosts are redirectors, not directory indexes.  SourceForge's
    project RSS endpoint is the stable read-only interface for file activity and
    also avoids scraping unrelated numbers from the project summary page.
    """
    u = urlsplit(source)
    path = unquote(u.path)

    project = ""
    rest = ""
    m = re.search(r"/projects/([^/]+)/files/(.*)", path)
    if m:
        project, rest = m.group(1), m.group(2)
    elif u.netloc.lower() in {"downloads.sourceforge.net", "prdownloads.sourceforge.net"} or u.netloc.lower().endswith('.dl.sourceforge.net'):
        parts = [x for x in path.split("/") if x]
        if parts and parts[0] == 'project' and len(parts) >= 2:
            project = parts[1]
            rest = "/".join(parts[2:])
        elif parts:
            # Legacy download URLs use /sourceforge/PROJECT/FILE; the literal
            # "sourceforge" path component is not the project name.
            if parts[0].lower() == "sourceforge" and len(parts) >= 2:
                project = parts[1]
                rest = "/".join(parts[2:])
            else:
                project = parts[0]
                rest = "/".join(parts[1:])

    if not project or not rest:
        return None, "sourceforge", "could not infer SourceForge project/files path"
    if not re.fullmatch(r"[A-Za-z0-9._+-]+", project):
        return None, "sourceforge", "invalid SourceForge project identifier"

    rest = rest.removesuffix("/download").rstrip("/")
    basename = unquote(rest.rsplit("/", 1)[-1])
    parent = rest.rsplit("/", 1)[0] if "/" in rest else ""

    variants: list[tuple[str, callable]] = [(port.version, lambda x: x)]
    if "." in port.version:
        variants.append((port.version.replace(".", "_"), lambda x: x.replace("_", ".")))
        variants.append((port.version.replace(".", "-"), lambda x: x.replace("-", ".")))
        # Classic SourceForge projects such as Info-ZIP encode 6.0/3.0 as
        # unzip60/zip30.  This is a filename encoding only; normalize it back
        # to the same dotted component count before comparison.
        compact = port.version.replace(".", "")
        parts = port.version.split(".")
        if compact != port.version and all(x.isdigit() for x in parts):
            def _expand_compact(x: str, widths=tuple(len(v) for v in parts)) -> str:
                if not x.isdigit() or len(x) != sum(widths):
                    return x
                out=[]; pos=0
                for width in widths:
                    out.append(x[pos:pos+width]); pos += width
                return ".".join(out)
            variants.append((compact, _expand_compact))
    token = ""
    transform = lambda x: x
    for encoded, fn in variants:
        if encoded and encoded in basename:
            token, transform = encoded, fn
            break
    if not token:
        return None, "sourceforge", "current version is not encoded in SourceForge archive filename"

    pre, suf = basename.split(token, 1)
    rx = re.compile(r"^" + re.escape(pre) + r"([0-9][0-9A-Za-z._+~-]*)" + re.escape(suf) + r"$", re.I)

    vals: list[str] = []
    seen_urls: set[str] = set()

    # Inspect the exact folder, its parent (for version-directory layouts), and
    # finally the project root.  RSS is intentionally queried serially and only
    # for this one project/scan target.
    paths: list[str] = []
    for candidate in (parent, parent.rsplit('/', 1)[0] if '/' in parent else '', ''):
        candidate = candidate.strip('/')
        if candidate not in paths:
            paths.append(candidate)

    for sf_path in paths:
        rss = f"https://sourceforge.net/projects/{project}/rss?path=/" + quote(sf_path, safe='/')
        if rss in seen_urls:
            continue
        seen_urls.add(rss)
        try:
            text = http.get(rss)
        except FetchError:
            continue
        # RSS titles/links may contain either full filenames or nested paths.
        items = hrefs(text) + re.findall(r"<title>(.*?)</title>", text, re.I | re.S) + re.findall(r"<link>(.*?)</link>", text, re.I | re.S)
        for item in items:
            decoded = unquote(html.unescape(re.sub(r"<[^>]+>", "", item)))
            clean = decoded.split("?", 1)[0].split("#", 1)[0].rstrip("/")
            for name in [x for x in clean.split('/') if x]:
                match = rx.fullmatch(name)
                if match:
                    vals.append(transform(match.group(1)))
                    break
        if port.version in uniq_sorted_versions(vals, port.version, port, "sourceforge"):
            # Continue only one level above if current is all we have; a sibling
            # version directory may expose a newer archive in the parent feed.
            continue

    # HTML browser fallback is useful for old projects whose RSS feed is sparse.
    browser_paths = paths[:2] or ['']
    for sf_path in browser_paths:
        folder_url = f"https://sourceforge.net/projects/{project}/files/"
        if sf_path:
            folder_url += "/".join(quote(seg, safe="") for seg in sf_path.split("/")) + "/"
        try:
            text = http.get(folder_url)
        except FetchError:
            continue
        candidates = hrefs(text) + re.findall(r"[^\s<>\"']+", text)
        for item in candidates:
            decoded = unquote(html.unescape(item))
            clean = decoded.split("?", 1)[0].split("#", 1)[0].rstrip("/")
            for name in [x for x in clean.split('/') if x]:
                match = rx.fullmatch(name)
                if match:
                    vals.append(transform(match.group(1)))
                    break

    latest, reason = choose_verified(port.version, vals, port, "sourceforge")
    if latest is None and not reason:
        reason = "no matching SourceForge archive filenames found in project feeds"
    return latest, "sourceforge", reason


def rarlab_unrar_release(port: Port, http: HttpCache) -> tuple[str | None, str, str]:
    """Discover the formal UnRAR source release from RARLAB's addons page.

    Direct archive/index requests can return HTTP 403 while the human-facing
    addons page remains available.  Parse only the official unrarsrc archive
    link and let normal prerelease filtering reject beta-style names.
    """
    text = http.get("https://www.rarlab.com/rar_add.htm")
    vals = re.findall(r"(?:href=[\"'](?:[^\"']*/)?unrarsrc-)([0-9]+(?:\.[0-9]+)+)\.tar\.gz", text, re.I)
    latest, reason = choose_verified(port.version, vals, port, "rarlab-addons")
    return latest, "rarlab-addons", reason


def simple_release_page(port: Port, http: HttpCache, url: str, pattern: str, provider: str) -> tuple[str | None, str, str]:
    text = http.get(url)
    vals = re.findall(pattern, text, re.I)
    latest, reason = choose_verified(port.version, vals, port, provider)
    return latest, provider, reason


def chromium_stable(port: Port, http: HttpCache) -> tuple[str | None, str, str]:
    text = http.get('https://chromiumdash.appspot.com/fetch_releases?channel=Stable&platform=Linux&num=20')
    data = json.loads(text)
    vals = [str(x.get('version', '')) for x in data if isinstance(x, dict)]
    latest, reason = choose_verified(port.version, vals, port, 'chromium-dash')
    return latest, 'chromium-dash', reason


def unicode_ucd_releases(port: Port, http: HttpCache) -> tuple[str | None, str, str]:
    text = http.get('https://www.unicode.org/Public/')
    vals = re.findall(r'href=["\']([0-9]+\.[0-9]+\.[0-9]+)/["\']', text, re.I)
    latest, reason = choose_verified(port.version, vals, port, 'unicode-public')
    return latest, 'unicode-public', reason


def texlive_annual_source(port: Port, http: HttpCache) -> tuple[str | None, str, str]:
    text = http.get("https://tug.ctan.org/systems/texlive/Source/")
    vals = re.findall(r"texlive-([0-9]{8})-source\.tar\.xz", text, re.I)
    latest, reason = choose_verified(port.version, vals, port, "ctan-texlive-source")
    return latest, "ctan-texlive-source", reason


def rust_stable_channel(port: Port, http: HttpCache) -> tuple[str | None, str, str]:
    text = http.get('https://static.rust-lang.org/dist/channel-rust-stable.toml')
    # The manifest begins package entries with version = "X.Y.Z (...)".  Keep
    # unique semver triples and require the installed version to be present.
    vals = re.findall(r'^version\s*=\s*"([0-9]+\.[0-9]+\.[0-9]+)(?:\s|\")', text, re.M)
    latest, reason = choose_verified(port.version, vals, port, 'rust-stable')
    return latest, 'rust-stable', reason


def nvidia_unix_releases(port: Port, http: HttpCache) -> tuple[str | None, str, str]:
    text = http.get('https://www.nvidia.com/en-us/drivers/unix/')
    vals = re.findall(r'(?:Version:\s*|Version\s*</[^>]+>\s*)([0-9]+\.[0-9]+\.[0-9]+)', text, re.I)
    # The public page text also exposes branch versions without a literal
    # "Version:" label in some layouts.  Restrict fallback tokens to the same
    # driver major as the current BFSOS branch.
    major = port.version.split('.', 1)[0]
    vals += re.findall(r'\b(' + re.escape(major) + r'\.[0-9]+\.[0-9]+)\b', text)
    vals = list(dict.fromkeys(vals))
    if port.version not in vals:
        vals.append(port.version)  # current source URL remains the branch proof
    latest, reason = choose_verified(port.version, vals, port, 'nvidia-unix')
    return latest, 'nvidia-unix', reason

def provider_check(port: Port, source: str, http: HttpCache, timeout: int) -> tuple[str | None, str, str]:
    host = urlsplit(source).netloc.lower()
    path = urlsplit(source).path

    if port.rel == "compat-32/db-32":
        return port.version, "policy-pin", "pinned Berkeley DB 5.3 compatibility ABI"
    if port.rel in {"core/sqlite", "compat-32/sqlite3-32"}:
        return sqlite_release_page(port, http)

    # Explicit per-port providers are stronger than whatever host happens to carry
    # the current release tarball.  In particular, several BFSOS ports keep
    # SourceForge download URLs while version discovery intentionally comes from
    # PyPI or the canonical upstream Git repository.  Check these overrides before
    # generic host dispatch so SourceForge cannot shadow them.
    # Stable official pages/APIs for projects whose tarball URL is not itself
    # a browsable release index.
    if port.rel == "core/less":
        return simple_release_page(port, http, "https://www.greenwoodsoftware.com/less/", r"less-([0-9]+)", "less-home")
    if port.rel == "core/mpdecimal":
        return simple_release_page(port, http, "https://www.bytereef.org/mpdecimal/download.html", r"mpdecimal-([0-9]+(?:\.[0-9]+)+)\.tar\.gz", "mpdecimal-download")
    if port.rel == "opt/argyllcms":
        return simple_release_page(port, http, "https://www.argyllcms.com/downloadsrc.html", r"(?:Argyll_V|Version\s+)([0-9]+(?:\.[0-9]+)+)", "argyll-download")
    if port.rel == "opt/fftw":
        return simple_release_page(port, http, "https://fftw.org/download.html", r"fftw-([0-9]+(?:\.[0-9]+)+)\.tar\.gz", "fftw-download")
    if port.rel == "opt/unrar":
        return rarlab_unrar_release(port, http)
    if port.rel == "opt/chromium":
        return chromium_stable(port, http)
    if port.rel == "opt/unicode-character-database":
        return unicode_ucd_releases(port, http)
    if port.rel == "opt/texlive":
        return texlive_annual_source(port, http)
    if port.rel == "opt/rustc":
        return rust_stable_channel(port, http)
    if port.rel in {"opt/nvidia", "compat-32/nvidia-32", "compat-32/nvidia-fb-32"}:
        return nvidia_unix_releases(port, http)

    if port.rel in PYPI_PROJECT_OVERRIDES:
        project = PYPI_PROJECT_OVERRIDES[port.rel]
        text = http.get(f"https://pypi.org/pypi/{project}/json")
        data = json.loads(text)
        vals = data.get("releases", {}).keys()
        latest, reason = choose_verified(port.version, vals, port, f"pypi:{project}")
        return latest, f"pypi:{project}", reason
    if port.rel in GIT_REPO_OVERRIDES:
        return git_tags(port, source, timeout, GIT_REPO_OVERRIDES[port.rel])

    if host == "registry.npmjs.org":
        return npm_registry(port, source, http)
    if host in {"sourceforge.net", "downloads.sourceforge.net"} or host.endswith(".dl.sourceforge.net"):
        return sourceforge_files(port, source, http)
    if host == "github.com" and "/releases/download/" in path:
        return github_published_release(port, source, http)
    if port.rel in {"core/iptables", "core/libmnl"}:
        return netfilter_release_page(port, http)
    if port.rel == "opt/mingw-w64-gcc":
        return gcc_release_directory(port, http)
    if port.rel == "opt/discord":
        return discord_stable(port, http)
    if port.rel == "opt/nss":
        return nss_release_directory(port, http)

    if host in {"download.gnome.org", "ftp.gnome.org"}:
        return gnome(port, source, http)
    if host in {"pypi.org", "pypi.python.org", "files.pythonhosted.org", "pythonhosted.org", "pypi.io"}:
        return pypi(port, source, http)
    if host == "download.kde.org":
        return kde(port, source, http)
    if host == "archive.xfce.org":
        return xfce(port, source, http)
    if (
        host == "github.com" or host == "gitlab.com" or host.startswith("gitlab.")
        or host == "git.kernel.org" or host == "codeberg.org" or "/-/archive/" in path
    ):
        return git_tags(port, source, timeout)
    return generic_directory(port, source, http)


def check_port(port: Port, http: HttpCache, timeout: int) -> Result:
    sources = remote_sources(port)
    if not port.name or not port.version:
        return Result(port, "ERROR", reason="missing name/version")
    if port.rel == "compat-32/db-32":
        return Result(port, "SKIP", provider="policy-pin", reason="pinned Berkeley DB 5.3 compatibility ABI")
    if port.rel in DISCOVERY_POLICY_SKIPS:
        return Result(port, "SKIP", provider="policy-pin", reason=DISCOVERY_POLICY_SKIPS[port.rel])
    if not sources:
        return Result(port, "SKIP", reason="local/meta port: no remote source")
    source = sources[0]
    try:
        latest, provider, reason = provider_check(port, source, http, timeout)
    except FetchError as exc:
        # A provider/index failure is not evidence the package source is broken.
        ok, source_reason = http.exists(source)
        if ok:
            return Result(port, "UNVERIFIABLE", provider="source-ok", reason=f"provider fetch failed: {exc}", source=source)
        return Result(port, "FETCH-ERROR", provider="source", reason=source_reason or str(exc), source=source)
    except Exception as exc:
        return Result(port, "ERROR", reason=f"{type(exc).__name__}: {exc}", source=source)

    if latest is None:
        ok, source_reason = http.exists(source)
        extra = "current source reachable" if ok else f"current source check failed: {source_reason}"
        return Result(port, "UNVERIFIABLE", provider=provider, reason=f"{reason}; {extra}", source=source)
    status = "CURRENT" if latest == port.version else "UPDATE"
    return Result(port, status, latest=latest, provider=provider, source=source)


def discover(root: Path, args: list[str]) -> list[Path]:
    if args:
        out: list[Path] = []
        for item in args:
            p = Path(item).expanduser()
            if p.is_dir() and (p / "Pkgfile").is_file():
                out.append(p / "Pkgfile")
                continue
            if p.is_file() and p.name == "Pkgfile":
                out.append(p)
                continue
            matches = list((root / "ports").glob(f"*/{item}/Pkgfile"))
            if len(matches) == 1:
                out.append(matches[0])
            elif not matches:
                print(f"Port not found: {item}", file=sys.stderr)
            else:
                print(f"Ambiguous port name {item}: " + ", ".join(str(x.parent) for x in matches), file=sys.stderr)
        return sorted(set(out))

    repo = os.environ.get("REPO", "").strip()
    if repo:
        roots = [Path(x) for x in repo.split()]
    else:
        ports_root = root / "ports"
        roots = sorted(
            p for p in ports_root.iterdir()
            if p.is_dir() and not p.name.startswith(".") and p.name != "compat-32"
        )
    out = []
    for r in roots:
        out.extend(sorted(r.glob("*/Pkgfile")))
    return out


def tsv_escape(s: str) -> str:
    return s.replace("\t", " ").replace("\n", " ").replace("\r", " ")


def print_result(r: Result, verbose: bool = False):
    base = f"{r.status:<12} {r.port.rel:<42} {r.port.version}"
    if r.latest:
        base += f" -> {r.latest}"
    if r.provider:
        base += f"  [{r.provider}]"
    if r.reason and (r.status not in {"CURRENT"} or verbose):
        base += f"  {r.reason}"
    print(base)


def main() -> int:
    ap = argparse.ArgumentParser(description="BFSOS verified upstream version checker v11")
    ap.add_argument("ports", nargs="*", help="port path or unique package name")
    ap.add_argument("-v", "--verbose", action="store_true")
    ap.add_argument("-n", action="store_true", help="accepted for compatibility; update overrides are not used by v2")
    ap.add_argument("-u", "--update", action="store_true", help="disabled: v11 keeps auditing separate from updater writes")
    ap.add_argument("--jobs", type=int, default=10)
    ap.add_argument("--timeout", type=int, default=10)
    ap.add_argument("--tsv", help="write complete machine-readable results to this path")
    ns = ap.parse_args()
    if ns.update:
        print("ERROR: -u is intentionally disabled in checker v11. Use bfs-maintained-port-updater.py on reviewed UPDATE rows.", file=sys.stderr)
        return 2

    root = Path(__file__).resolve().parents[1]
    pkgfiles = discover(root, ns.ports)
    if not pkgfiles:
        print("No ports selected.", file=sys.stderr)
        return 2

    ports: list[Port] = []
    early: list[Result] = []
    for p in pkgfiles:
        try:
            ports.append(eval_pkgfile(p))
        except Exception as exc:
            fake = Port(p.parent, str(p.parent), p.parent.name, "?", [])
            early.append(Result(fake, "ERROR", reason=str(exc)))

    print(f"BFSOS verified upstream version checker v11")
    print(f"Ports: {len(pkgfiles)}   Jobs: {max(1, ns.jobs)}   Timeout: {ns.timeout}s")
    print("Policy: UPDATE is emitted only when the provider can map the current version back to the same release set.")
    print()

    http = HttpCache(max(3, ns.timeout))
    results: list[Result] = list(early)
    done = 0
    lock = threading.Lock()
    started = time.monotonic()
    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, ns.jobs)) as ex:
        futures = {ex.submit(check_port, p, http, ns.timeout): p for p in ports}
        for fut in concurrent.futures.as_completed(futures):
            results.append(fut.result())
            with lock:
                done += 1
                if done % 25 == 0 or done == len(ports):
                    print(f"... checked {done}/{len(ports)}", file=sys.stderr, flush=True)

    results.sort(key=lambda r: r.port.rel)
    for r in results:
        print_result(r, ns.verbose)

    counts: dict[str, int] = {}
    for r in results:
        counts[r.status] = counts.get(r.status, 0) + 1
    elapsed = time.monotonic() - started
    print("\nSummary:")
    for key in ("CURRENT", "UPDATE", "UNVERIFIABLE", "FETCH-ERROR", "SKIP", "ERROR"):
        print(f"  {key:<12} {counts.get(key, 0)}")
    print(f"  TOTAL        {len(results)}")
    print(f"  ELAPSED      {elapsed:.1f}s")

    if ns.tsv:
        out = Path(ns.tsv)
        with out.open("w", encoding="utf-8") as f:
            f.write("status\tport\tcurrent\tlatest\tprovider\treason\tsource\n")
            for r in results:
                f.write("\t".join(tsv_escape(x) for x in (
                    r.status, r.port.rel, r.port.version, r.latest, r.provider, r.reason, r.source
                )) + "\n")
        print(f"TSV: {out}")

    return 1 if counts.get("ERROR", 0) else 0


if __name__ == "__main__":
    raise SystemExit(main())
