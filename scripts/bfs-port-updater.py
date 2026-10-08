#!/usr/bin/env python3
"""Primary BFSOS maintainer port updater.

The tool is deliberately conservative: it scans first, shows an explicit
per-port selection, and only writes checked items.  Development LFS-family book
versions are consulted before generic upstream discovery.  MLFS development is
authoritative for packages it carries; BFSOS kernel packages are the explicit
exception and follow the BFSOS kernel policy.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import csv
import dataclasses
import datetime as dt
from html.parser import HTMLParser
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time
from urllib.parse import urljoin, urlsplit
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_PORTS_ROOT = Path(os.environ.get("BFSOS_PORTS_ROOT", str(ROOT / "ports"))).expanduser()
LOG_ROOT = ROOT / "logs" / "update"

DISTRO_VERSION_RX = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._+-]*$")

def project_distro_version(project_root: Path = ROOT) -> str:
    try:
        value = (project_root / "VERSION").read_text().strip()
    except OSError:
        return "0.9.0"
    return value or "0.9.0"

def _replace_once(text: str, pattern: str, repl: str, label: str) -> str:
    new, count = re.subn(pattern, repl, text, count=1, flags=re.M)
    if count != 1:
        raise RuntimeError(f"could not update {label}")
    return new

def apply_distro_version(project_root: Path, new_version: str) -> list[str]:
    """Update active BFSOS release consumers transactionally.

    VERSION is authoritative, but aaa_filesystem must embed the release into the
    installed system identity.  Active script fallbacks are kept in sync so a
    copied/standalone helper still reports the selected release when VERSION is
    unavailable.  aaa_filesystem's package release is bumped once whenever the
    distro release changes, ensuring sysup sees the identity change.
    """
    new_version = (new_version or "").strip()
    if not DISTRO_VERSION_RX.fullmatch(new_version):
        raise ValueError("version must use only letters, digits, '.', '-', '_', or '+' and may not contain spaces/slashes")
    project_root = project_root.resolve()
    version_path = project_root / "VERSION"
    old_version = version_path.read_text().strip() if version_path.is_file() else ""
    if old_version == new_version:
        return []

    edits: dict[Path, str] = {}
    edits[version_path] = new_version + "\n"

    aaa = project_root / "ports/core/aaa_filesystem/Pkgfile"
    aaa_text = aaa.read_text()
    aaa_text = _replace_once(aaa_text, r"^bfs_version=.*$", f"bfs_version={new_version}", "aaa_filesystem bfs_version")
    m = re.search(r"(?m)^release=(\d+)\s*$", aaa_text)
    if not m:
        raise RuntimeError("could not find aaa_filesystem release")
    next_release = int(m.group(1)) + 1
    aaa_text = _replace_once(aaa_text, r"^release=\d+\s*$", f"release={next_release}", "aaa_filesystem release")
    edits[aaa] = aaa_text

    replacements = [
        (project_root / "bootstrap.sh", r'BFS_VERSION="0\.9\.0"', f'BFS_VERSION="{new_version}"', "bootstrap fallback"),
        (project_root / "bootstrap-clean-start.sh", r'BFS_VERSION="0\.9\.0"', f'BFS_VERSION="{new_version}"', "clean-start fallback"),
        (project_root / "scripts/bfs-build-iso.sh", r"printf '0\.9\.0'", f"printf '{new_version}'", "ISO fallback"),
        (project_root / "scripts/install-bfs-menu-current.sh", r'\$\{release:-0\.9\.0\}', '${release:-' + new_version + '}', "installer fallback"),
    ]
    for path, pattern, repl, label in replacements:
        text = path.read_text()
        new, count = re.subn(pattern, repl, text)
        if count < 1:
            # Fall back to the previous authoritative VERSION value when this
            # feature is used again after the first release bump.
            old_pat = re.escape(old_version) if old_version else None
            if old_pat:
                if label == "bootstrap fallback" or label == "clean-start fallback":
                    new, count = re.subn(r'BFS_VERSION="' + old_pat + r'"', f'BFS_VERSION="{new_version}"', text)
                elif label == "ISO fallback":
                    new, count = re.subn(r"printf '" + old_pat + r"'", f"printf '{new_version}'", text)
                elif label == "installer fallback":
                    new, count = re.subn(r'\$\{release:-' + old_pat + r'\}', '${release:-' + new_version + '}', text)
        if count < 1:
            raise RuntimeError(f"could not update {label} in {path.relative_to(project_root)}")
        edits[path] = new

    # User-facing release documentation follows the authoritative marker.
    for rel in ("README.md", "docs/INSTALL.md"):
        path = project_root / rel
        if path.is_file() and old_version:
            text = path.read_text()
            if old_version in text:
                edits[path] = text.replace(old_version, new_version)

    # Commit only after every planned edit has been derived successfully.
    for path, text in edits.items():
        path.write_text(text)
    return [str(path.relative_to(project_root)) for path in edits]
MLFS_PACKAGES_PAGE = "https://www.linuxfromscratch.org/mlfs/view/dev/chapter03/packages.html"
BOOKS = (
    ("mlfs-dev", "MLFS DEV", MLFS_PACKAGES_PAGE),
    ("lfs-dev", "LFS DEV", "https://www.linuxfromscratch.org/lfs/view/systemd/longindex.html"),
    ("blfs-dev", "BLFS DEV", "https://www.linuxfromscratch.org/blfs/view/systemd/longindex.html"),
    ("glfs-dev", "GLFS DEV", "https://www.linuxfromscratch.org/glfs/view/dev/longindex.html"),
)
MLFS_PATCH_PAGE = "https://www.linuxfromscratch.org/mlfs/view/dev/chapter03/patches.html"
KERNEL_PORTS = {"linux", "linux-lts", "linux-headers"}
ALIASES = {
    "dbus": {"dbus", "d-bus"}, "pkgconf": {"pkgconf", "pkg-config"},
    "python3": {"python", "python3"}, "procps-ng": {"procps-ng", "procps"},
    "util-linux": {"util-linux", "utillinux"}, "iana-etc": {"iana-etc", "ianaetc"},
    "webkitgtk-41": {"webkitgtk"},
}
LOCAL_PATCH_MARKERS = ("bfs", "bfsos", "local", "custom")

# Packages whose compatibility/API generation must not be crossed by generic
# upstream discovery.  These guards complement checkupdate.py and keep the
# maintainer UI conservative even when a provider reports a newer family.
PACKAGE_FAMILY_MAJOR_LOCKS = {
    "compat-32/gtk-32": 2,
}

# Fast-moving security-sensitive projects where an upstream point release in
# the already-selected stable series may advance ahead of the LFS/BLFS book.
# This is intentionally narrow: it does not permit a series/ABI jump.
SAME_SERIES_UPSTREAM_OVERRIDES = {
    "gnome/webkitgtk",
    "gnome/webkitgtk-41",
}

# For these GNOME ports, a book candidate must also exist in GNOME's own
# cache. This prevents book/index parsing mistakes from inventing releases.
GNOME_CACHE_VALIDATED_BOOK_PORTS = {
    "gnome/gnome-backgrounds",
}

# Development-book authority is explicit per BFSOS port.  This preserves the
# historical r106 MLFS mapping instead of treating every package found in a
# development book as automatic authority.  Kernel packages remain governed by
# BFSOS's LTS policy and are intentionally excluded here.
MLFS_DEV_MANAGED_PORTS = {
    "core/acl", "core/attr", "core/autoconf", "core/automake", "core/bash",
    "core/bc", "core/binutils", "core/bison", "core/bzip2", "core/coreutils",
    "core/dbus", "core/diffutils", "core/e2fsprogs", "core/elfutils",
    "core/expat", "core/file", "core/findutils", "core/flex", "core/gawk",
    "core/gcc", "core/gdbm", "core/gettext", "core/glibc", "core/gmp",
    "core/gperf", "core/grep", "core/groff", "core/grub", "core/gzip",
    "core/iana-etc", "core/inetutils", "core/iproute2", "core/kbd",
    "core/kmod", "core/less", "core/libcap", "core/libffi",
    "core/libpipeline", "core/libtool", "core/libxcrypt", "core/lz4",
    "core/m4", "core/make", "core/man-db", "core/man-pages", "core/meson",
    "core/mpc", "core/mpdecimal", "core/mpfr", "core/ncurses", "core/ninja",
    "core/openssl", "core/patch", "core/pkgconf", "core/procps-ng",
    "core/psmisc", "core/python3", "core/python3-flit-core",
    "core/python3-markupsafe", "core/python3-packaging",
    "core/python3-setuptools", "core/python3-wheel", "core/readline",
    "core/sed", "core/shadow", "core/sqlite", "core/systemd", "core/tar",
    "core/texinfo", "core/tzdata", "core/util-linux", "core/vim",
    "core/xz", "core/zlib", "core/zstd",
}

# Package-specific development-book preferences may be added deliberately.
# They are not global policy for their respective books.
DEV_BOOK_AUTHORITIES = {
    "opt/rustc": "blfs-dev",
    # BFSOS intentionally follows the BLFS development-book xorg-server
    # recipe/patch cadence instead of racing generic upstream releases.
    "xorg/xorg-server": "blfs-dev",
}

REFERENCE_BOOK_POLICIES = {"lfs-dev", "blfs-dev", "glfs-dev"}

# Known source families where the canonical target URL can be derived safely.
SOURCE_TEMPLATE_PORTS = {
    "opt/cairo", "opt/glib-networking", "opt/libsecret", "opt/lmdb", "opt/nodejs",
}

# Coordinated package-family build order. Existing members not present in a BFSOS
# tree are ignored, but every existing member must resolve to one target before
# the group can become automatic.
VULKAN_BUILD_ORDER = [
    "opt/spirv-headers",
    "opt/spirv-tools",
    "compat-32/spirv-tools-32",
    "opt/vulkan-headers",
    "opt/vulkan-loader",
    "compat-32/vulkan-loader-32",
    "opt/vulkan-utility-libraries",
    "compat-32/vulkan-utility-libraries-32",
    "opt/volk",
    "compat-32/volk-32",
    "opt/vulkan-validation-layers",
    "compat-32/vulkan-validation-layers-32",
    "opt/vulkan-tools",
    "compat-32/vulkan-tools-32",
]

# Coordinated SDK families must move together.  A partial update is held for
# review until every existing member of the group has the same target version.
VERSION_LOCK_GROUPS = {
    "vulkan-sdk": {
        "opt/spirv-headers", "opt/spirv-tools", "compat-32/spirv-tools-32",
        "opt/vulkan-headers", "opt/vulkan-loader", "compat-32/vulkan-loader-32",
        "opt/vulkan-tools", "compat-32/vulkan-tools-32",
        "opt/vulkan-utility-libraries", "compat-32/vulkan-utility-libraries-32",
        "opt/volk", "compat-32/volk-32",
        "opt/vulkan-validation-layers", "compat-32/vulkan-validation-layers-32",
    },
    # NVIDIA's native and 32-bit userspace packages come from the same vendor
    # runfile and must never drift to different driver versions.  nvidia-fb-32
    # is a separate fallback branch and is intentionally not part of this pair.
    "nvidia-driver": {"opt/nvidia", "compat-32/nvidia-32"},
    "alsa-plugins": {"opt/alsa-plugins", "compat-32/alsa-plugins-32"},
}

GROUP_BUILD_ORDER = {
    "vulkan-sdk": VULKAN_BUILD_ORDER,
    "nvidia-driver": ["opt/nvidia", "compat-32/nvidia-32"],
    "alsa-plugins": ["opt/alsa-plugins", "compat-32/alsa-plugins-32"],
}

# Only Vulkan currently requires each freshly-built predecessor to be installed
# before a later member can be meaningfully validated. NVIDIA native/32-bit can
# both be built from the matching runfile without installing the first package.
GROUP_BUILD_REQUIRES_INSTALLED_PREREQ = {"vulkan-sdk"}

# Large package families should never rely on the RAM-backed build root merely
# because a port omitted build_work=disk.  These are conservative identities;
# per-port build_work metadata still remains supported.
LARGE_BUILD_PACKAGE_NAMES = {
    "llvm", "llvm-32", "clang", "clang-32", "mesa", "mesa-32",
    "rustc", "gcc", "chromium", "firefox", "firefox-esr",
}
LARGE_BUILD_PREFIXES = ("webkitgtk", "qtwebengine")
DEFAULT_TMPFS_HEADROOM_GIB = 16


@dataclasses.dataclass
class PortMeta:
    rel: str
    path: Path
    name: str
    version: str
    release: str
    sources: list[str]


@dataclasses.dataclass
class PatchSpec:
    url: str
    filename: str
    md5: str = ""


@dataclasses.dataclass
class ArchReference:
    version: str = ""
    upstream_url: str = ""
    verified: bool = False
    reason: str = ""


@dataclasses.dataclass
class Candidate:
    port: str
    name: str
    old: str
    new: str
    old_release: str
    new_release: str
    policy: str
    source_label: str
    status: str
    reason: str = ""
    selected: bool = False
    provider: str = ""
    source: str = ""
    patches: list[PatchSpec] = dataclasses.field(default_factory=list)
    obsolete_patches: list[str] = dataclasses.field(default_factory=list)


class LITextParser(HTMLParser):
    def __init__(self):
        super().__init__(); self.depth = 0; self.buf: list[str] = []; self.items: list[str] = []
    def handle_starttag(self, tag, attrs):
        if tag.lower() == "li":
            if self.depth == 0: self.buf = []
            self.depth += 1
    def handle_endtag(self, tag):
        if tag.lower() == "li" and self.depth:
            self.depth -= 1
            if self.depth == 0:
                value = " ".join("".join(self.buf).split())
                if value: self.items.append(value)
                self.buf = []
    def handle_data(self, data):
        if self.depth: self.buf.append(data)


class InventoryTextParser(HTMLParser):
    BLOCKS = {"p", "h3", "h4", "dt", "li"}
    def __init__(self):
        super().__init__(); self.depth = 0; self.buf: list[str] = []; self.items: list[str] = []
    def handle_starttag(self, tag, attrs):
        if tag in self.BLOCKS:
            if self.depth == 0: self.buf = []
            self.depth += 1
    def handle_endtag(self, tag):
        if tag in self.BLOCKS and self.depth:
            self.depth -= 1
            if self.depth == 0:
                value = " ".join("".join(self.buf).split())
                if value: self.items.append(value)
                self.buf = []
    def handle_data(self, data):
        if self.depth: self.buf.append(data)


def parse_package_inventory(raw: str) -> dict[str, str]:
    """Parse Chapter 3 package inventory rows such as ``Acl (2.4.0) - 400 KB``."""
    parser = InventoryTextParser(); parser.feed(raw)
    out: dict[str, str] = {}
    rx = re.compile(r"^(.+?)\s*\(([0-9][0-9A-Za-z._+~-]*)\)\s*-", re.I)
    for item in parser.items:
        m = rx.search(item)
        if not m:
            continue
        label = m.group(1).strip().rstrip(":")
        # Package headings are names, not prose.  Reject obviously descriptive
        # blocks so a nearby version in explanatory text cannot become policy.
        if len(label.split()) > 4 or any(ch in label for ch in ":;/"):
            continue
        name = normalize_name(label)
        version = m.group(2).rstrip(".,;:")
        if name == "sqlite": version = sqlite_archive_version(version)
        out.setdefault(name, version)
    return out


def die(msg: str, code: int = 1):
    print(f"ERROR: {msg}", file=sys.stderr); raise SystemExit(code)


def run(cmd: list[str], *, env=None, cwd: Path | None = None, capture=False):
    return subprocess.run(cmd, check=False, text=True, encoding="utf-8", errors="replace",
                          cwd=str(cwd) if cwd else None, env=env,
                          stdout=subprocess.PIPE if capture else None,
                          stderr=subprocess.PIPE if capture else None)


def normalize_name(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.lower().replace("c++", "cpp"))


def normalize_version(value: str) -> str:
    """Normalize cosmetic separators without changing the version lineage."""
    value = value.strip().lower().replace("~", ".")
    value = re.sub(r"[-_]+", ".", value)
    value = re.sub(r"\.+", ".", value).strip(".")
    return value


def version_key(value: str):
    value = normalize_version(value)
    return tuple((0, int(p)) if p.isdigit() else (1, p)
                 for p in re.split(r"([0-9]+)", value) if p and p != ".")


def versions_equivalent(a: str, b: str) -> bool:
    return normalize_version(a) == normalize_version(b)


def newer(candidate: str, current: str) -> bool:
    if versions_equivalent(candidate, current):
        return False
    return version_key(candidate) > version_key(current)


def comparison_version(meta: PortMeta, value: str) -> str:
    """Return a package-scoped comparable version without changing stored versions."""
    value = value.strip()
    # TeX Live source archives use a cosmetic "-source" suffix for the same
    # dated release. Keep this narrow: suffixes for unrelated packages retain
    # their normal version semantics.
    if meta.name == "texlive":
        value = re.sub(r"-source$", "", value, flags=re.I)
    # Upstreams/downstreams commonly spell release candidates both as 0.9-rc5
    # and 0.9rc5.  Treat only this known pre-release separator as cosmetic; do
    # not erase arbitrary punctuation from ordinary versions.
    value = re.sub(r"(?<=\d)[._-](?=rc\d)", "", value, flags=re.I)
    return value


def versions_equivalent_for_port(meta: PortMeta, a: str, b: str) -> bool:
    return versions_equivalent(comparison_version(meta, a), comparison_version(meta, b))


def newer_for_port(meta: PortMeta, candidate: str, current: str) -> bool:
    candidate_cmp = comparison_version(meta, candidate)
    current_cmp = comparison_version(meta, current)
    if versions_equivalent(candidate_cmp, current_cmp):
        return False
    return version_key(candidate_cmp) > version_key(current_cmp)


def has_unresolved_version_placeholder(value: str) -> bool:
    """Reject documentation/template tokens accidentally parsed as releases."""
    value = (value or "").strip()
    if not value:
        return True
    return bool(re.search(r"(?i)(?:^|[._+-])(?:major|minor|patch|mp)(?:$|[._+-])", value))


def versions_comparable(candidate: str, current: str) -> bool:
    """Reject obviously incompatible downstream version-numbering lineages.

    This is intentionally conservative.  A same-name package using a bare integer
    downstream generation (for example Arch signify 33) must not be compared to
    a dotted upstream release such as 0.14 without an explicit normalization rule.
    """
    ca = normalize_version(candidate)
    cu = normalize_version(current)
    if ca == cu:
        return True
    cnums = re.findall(r"\d+", ca)
    unums = re.findall(r"\d+", cu)
    if not cnums or not unums:
        return False
    c_bare = ca.isdigit()
    u_bare = cu.isdigit()
    if c_bare != u_bare and (len(cnums) == 1 or len(unums) == 1):
        return False
    return True


def same_series(a: str, b: str, components: int = 2) -> bool:
    def nums(v: str) -> list[int]:
        return [int(x) for x in re.findall(r"\d+", v)]
    aa, bb = nums(a), nums(b)
    return len(aa) >= components and len(bb) >= components and aa[:components] == bb[:components]


def major_component(value: str) -> str:
    m = re.search(r"\d+", value)
    return m.group(0) if m else ""


def family_allows(meta: PortMeta, target: str) -> bool:
    locked = PACKAGE_FAMILY_MAJOR_LOCKS.get(meta.rel)
    if locked is None:
        return True
    return major_component(meta.version) == str(locked) and major_component(target) == str(locked)


def is_vcs_snapshot_version(value: str) -> bool:
    low = value.lower()
    return bool(
        re.search(r"(?:^|[._-])r\d+(?:[._-]g[0-9a-f]{6,})?(?:$|[._-])", low)
        or re.search(r"(?:^|[._-])g[0-9a-f]{7,}(?:$|[._-])", low)
        or re.search(r"(?:^|[._-])git\d{6,}(?:$|[._-])", low)
    )


def port_tracks_vcs_snapshots(meta: PortMeta) -> bool:
    if is_vcs_snapshot_version(meta.version):
        return True
    for url in _remote_source_urls(meta):
        low = url.lower()
        if any(mark in low for mark in ("/commit/", "/commits/", "/snapshot/", "/snapshots/")):
            return True
    return False


def reject_downstream_snapshot(meta: PortMeta, candidate: str) -> bool:
    return is_vcs_snapshot_version(candidate) and not port_tracks_vcs_snapshots(meta)


def enforce_version_lock_groups(cands: list[Candidate], metas: list[PortMeta]) -> None:
    """Make coordinated SDK groups automatic only when the whole target is ready."""
    by_port = {c.port: c for c in cands}
    meta_by_port = {m.rel: m for m in metas}
    ports_root = metas[0].path.parent.parent if metas else DEFAULT_PORTS_ROOT
    existing = {rel for rel in set().union(*VERSION_LOCK_GROUPS.values()) if (ports_root / rel / "Pkgfile").is_file()}
    for group, members in VERSION_LOCK_GROUPS.items():
        present = sorted(existing & members)
        proposed = [by_port[p] for p in present if p in by_port and by_port[p].new != by_port[p].old]
        if not proposed:
            continue
        targets = {normalize_version(c.new) for c in proposed}
        if len(targets) != 1:
            detail = f"{group} held: mixed targets: " + ", ".join(sorted({c.new for c in proposed}))
            for c in proposed:
                c.status = "REVIEW"; c.selected = False; c.reason = f"{c.reason}; {detail}"
            continue
        target_norm = next(iter(targets))
        target_display = proposed[0].new
        missing = []
        for p in present:
            m = meta_by_port.get(p)
            c = by_port.get(p)
            if m and normalize_version(m.version) == target_norm:
                continue  # already at the coordinated target
            if c and normalize_version(c.new) == target_norm:
                continue
            missing.append(p)
        if missing:
            detail = f"{group} held: complete common target {target_display} unavailable; missing candidates: " + ", ".join(missing)
            for c in proposed:
                c.status = "REVIEW"; c.selected = False; c.reason = f"{c.reason}; {detail}"
            continue

        # Complete validated group: updater, not the maintainer, selects every
        # member that actually needs a version change. Members already at target
        # need no redundant rebuild merely to satisfy the transaction guard.
        for c in proposed:
            c.status = "UPDATE"
            c.selected = True
            c.policy = group
            c.reason = f"{c.reason}; complete {group} target {target_display} validated; coordinated automatic update"


def _selection_group_error(cands: list[Candidate], selected: set[str], ports_root: Path) -> str:
    by_port = {c.port: c for c in cands}
    for group, members in VERSION_LOCK_GROUPS.items():
        existing = {p for p in members if (ports_root / p / "Pkgfile").is_file()}
        touched = selected & existing
        if not touched:
            continue
        targets = {normalize_version(by_port[p].new) for p in touched if p in by_port}
        if len(targets) != 1:
            return f"{group} partial/mixed selection refused"
        target = next(iter(targets))
        required_updates = set()
        unresolved = []
        for p in existing:
            pkg = ports_root / p / "Pkgfile"
            try:
                m = eval_pkgfile(pkg, ports_root)
            except Exception:
                unresolved.append(p); continue
            if normalize_version(m.version) == target:
                continue
            c = by_port.get(p)
            if c and normalize_version(c.new) == target:
                required_updates.add(p)
            else:
                unresolved.append(p)
        if unresolved or touched != required_updates:
            return (f"{group} partial selection refused; target={target}; "
                    f"required-updates={','.join(sorted(required_updates))}; "
                    f"selected={','.join(sorted(touched))}; "
                    f"unresolved={','.join(sorted(unresolved))}")
    return ""


def _build_rank(port: str) -> tuple[int, str]:
    for group_index, group in enumerate(VERSION_LOCK_GROUPS):
        order = GROUP_BUILD_ORDER.get(group, [])
        if port in order:
            return group_index * 1000 + order.index(port), port
    return 10_000, port


def source_filename(src: str) -> str:
    src = src.strip()
    if "::" in src and src.split("::", 1)[1].startswith(("http://", "https://", "ftp://")):
        return src.split("::", 1)[0]
    if src.startswith(("http://", "https://", "ftp://")):
        return Path(urlsplit(src).path).name
    return Path(src).name


def eval_pkgfile(pkgfile: Path, ports_root: Path) -> PortMeta:
    script = r'''
set +u
source "$1" >/dev/null 2>&1 || exit 31
printf '%s\0%s\0%s\0' "${name-}" "${version-}" "${release-}"
if declare -p source >/dev/null 2>&1; then
  if declare -p source 2>/dev/null | grep -q '^declare -a'; then printf '%s\0' "${source[@]}"; else printf '%s\0' "${source}"; fi
fi
'''
    cp = subprocess.run(["bash", "--noprofile", "--norc", "-c", script, "bfs-port-updater", str(pkgfile)],
                        stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=10)
    if cp.returncode: raise RuntimeError(f"cannot evaluate {pkgfile}")
    fields = cp.stdout.decode("utf-8", "replace").split("\0")
    if fields and fields[-1] == "": fields.pop()
    if len(fields) < 3 or not fields[0] or not fields[1]: raise RuntimeError(f"missing metadata in {pkgfile}")
    return PortMeta(str(pkgfile.parent.relative_to(ports_root)), pkgfile.parent,
                    fields[0], fields[1], fields[2] or "1", fields[3:])


def discover_trees(ports_root: Path) -> list[Path]:
    if not ports_root.is_dir(): die(f"ports root does not exist: {ports_root}")
    return sorted(p for p in ports_root.iterdir() if p.is_dir() and not p.name.startswith(".") and any(p.glob("*/Pkgfile")))


def port_count(tree: Path) -> int: return sum(1 for _ in tree.glob("*/Pkgfile"))


def discover_ports(ports_root: Path, tree_names: list[str]) -> list[PortMeta]:
    out = []
    for tree in tree_names:
        for pkgfile in sorted((ports_root / tree).glob("*/Pkgfile")):
            try: out.append(eval_pkgfile(pkgfile, ports_root))
            except Exception as exc: print(f"WARN: {exc}", file=sys.stderr)
    return out


def fetch_text(url: str, timeout: int) -> str:
    req = Request(url, headers={"User-Agent": "BFSOS-port-updater/0.9.0"})
    with urlopen(req, timeout=timeout) as r: return r.read().decode("utf-8", "replace")


def sqlite_archive_version(value: str) -> str:
    """Convert SQLite's numeric archive token (for example 3530400) to 3.53.4."""
    if not value.isdigit() or len(value) < 7:
        return value
    n = int(value)
    major = n // 1_000_000
    minor = (n // 10_000) % 100
    patch = (n // 100) % 100
    subpatch = n % 100
    parts = [str(major), str(minor), str(patch)]
    if subpatch:
        parts.append(str(subpatch))
    return ".".join(parts)


def parse_book_index(raw: str) -> dict[str, str]:
    """Parse only real package entries from an LFS-family long index.

    The long index also contains executable/library description entries such as
    ``libnsl: Glibc-2.44 -- description`` and
    ``traceroute: Inetutils-2.8 -- description``. Those are not package
    versions for libnsl/traceroute. Require the package token on the right
    side to match the left-side package label before accepting a version.
    """
    parser = LITextParser(); parser.feed(raw); out = {}
    for item in parser.items:
        if ":" not in item:
            continue
        label, rest = item.split(":", 1)
        label_key = normalize_name(label)

        m = re.search(
            r"(?:^|\s)([A-Za-z0-9+_.-]+)-([0-9][0-9A-Za-z._+~-]*)(?:\s|$)",
            rest,
        )
        if not m:
            continue

        package_token = normalize_name(m.group(1))
        if package_token != label_key:
            continue

        version = m.group(2).rstrip(".,;:")
        if label_key == "sqlite":
            version = sqlite_archive_version(version)
        out.setdefault(label_key, version)
    return out


def parse_patch_page(raw: str, base_url: str) -> list[PatchSpec]:
    specs: list[PatchSpec] = []
    # LFS-family patch pages expose direct .patch links followed by an MD5 sum.
    rx = re.compile(r'href=["\']([^"\']+\.patch(?:\?[^"\']*)?)["\']', re.I)
    for m in rx.finditer(raw):
        url = urljoin(base_url, m.group(1))
        filename = Path(urlsplit(url).path).name
        tail = re.sub(r"<[^>]+>", " ", raw[m.end():m.end()+1200])
        md = re.search(r"MD5\s+sum\s*:\s*([0-9a-fA-F]{32})", tail, re.I)
        spec = PatchSpec(url, filename, md.group(1).lower() if md else "")
        if not any(x.filename == filename for x in specs): specs.append(spec)
    return specs


def book_keys(meta: PortMeta) -> list[str]:
    raw = {meta.name, meta.path.name} | ALIASES.get(meta.name, set())
    if meta.name.startswith("python3-"): raw.add(meta.name.removeprefix("python3-"))
    if meta.name.endswith("-32"): raw.add(meta.name[:-3])
    return [normalize_name(x) for x in raw if x]


def relevant_patches(meta: PortMeta, patches: list[PatchSpec]) -> list[PatchSpec]:
    keys = book_keys(meta)
    result = []
    for p in patches:
        pn = normalize_name(p.filename.split("-", 1)[0])
        # Also compare a longer prefix before the first numeric version.
        stem = re.split(r"-(?=\d)", p.filename, maxsplit=1)[0]
        if pn in keys or normalize_name(stem) in keys:
            result.append(p)
    return result


def local_patch_names(meta: PortMeta) -> list[str]:
    return [source_filename(s) for s in meta.sources if source_filename(s).lower().endswith((".patch", ".diff"))]


def likely_book_obsolete(meta: PortMeta, required: list[PatchSpec]) -> list[str]:
    required_names = {p.filename for p in required}
    keys = book_keys(meta)
    result = []
    for name in local_patch_names(meta):
        if name in required_names: continue
        low = name.lower()
        if any(mark in low for mark in LOCAL_PATCH_MARKERS): continue
        stem = re.split(r"-(?=\d)", name, maxsplit=1)[0]
        if normalize_name(stem) not in keys: continue
        # Only auto-classify as obsolete when the book has a replacement patch
        # for this same package.  Local patches remain untouched otherwise.
        if required: result.append(name)
    return result


def lookup_mlfs_authoritative(meta: PortMeta, indexes: dict[str, dict[str, str]]) -> tuple[str, str] | None:
    """Return MLFS DEV authority only for the curated BFSOS mapping."""
    if meta.name in KERNEL_PORTS or meta.rel not in MLFS_DEV_MANAGED_PORTS:
        return None
    idx = indexes.get("mlfs-dev", {})
    for key in book_keys(meta):
        if key in idx:
            return "mlfs-dev", idx[key]
    return None

def lookup_explicit_dev_authority(meta: PortMeta, indexes: dict[str, dict[str, str]]) -> tuple[str, str] | None:
    policy = DEV_BOOK_AUTHORITIES.get(meta.rel)
    if not policy:
        return None
    idx = indexes.get(policy, {})
    for key in book_keys(meta):
        if key in idx:
            return policy, idx[key]
    return None


def lookup_book_reference(meta: PortMeta, indexes: dict[str, dict[str, str]]) -> tuple[str, str] | None:
    """Return the first non-MLFS LFS-family reference for diagnostics/review."""
    if meta.name in KERNEL_PORTS:
        return None
    for policy, _label, _url in BOOKS:
        if policy not in REFERENCE_BOOK_POLICIES:
            continue
        idx = indexes.get(policy, {})
        for key in book_keys(meta):
            if key in idx:
                return policy, idx[key]
    return None


def lookup_book(meta: PortMeta, indexes: dict[str, dict[str, str]]) -> tuple[str, str] | None:
    """Compatibility helper: MLFS authority first, then reference-only books."""
    return lookup_mlfs_authoritative(meta, indexes) or lookup_book_reference(meta, indexes)


def gnome_series(version: str) -> str:
    nums = re.findall(r"\d+", version)
    if not nums:
        return ""
    major = int(nums[0])
    # GNOME platform releases use a single generation directory (e.g. 51),
    # while classic libraries use major.minor (2.90, 0.21).
    if major >= 40:
        return nums[0]
    return ".".join(nums[:2]) if len(nums) >= 2 else nums[0]


def candidate_source_url(meta: PortMeta, target: str) -> str:
    """Derive a conservative target source URL without editing the Pkgfile."""
    if meta.rel == "opt/cairo":
        return f"https://cairographics.org/releases/cairo-{target}.tar.xz"
    if meta.rel == "opt/glib-networking":
        return f"https://download.gnome.org/sources/glib-networking/{gnome_series(target)}/glib-networking-{target}.tar.xz"
    if meta.rel == "opt/libsecret":
        return f"https://download.gnome.org/sources/libsecret/{gnome_series(target)}/libsecret-{target}.tar.xz"
    if meta.rel == "opt/lmdb":
        # LMDB 1.x release archives are published from the canonical OpenLDAP
        # repository.  The GitHub LMDB mirror does not publish GitHub releases
        # and the old /archive/LMDB_$version form can 404 for valid releases.
        return f"https://git.openldap.org/openldap/openldap/-/archive/LMDB_{target}/openldap-LMDB_{target}.tar.bz2"
    if meta.rel == "opt/libcap-ng":
        # Upstream moved release distribution away from people.redhat.com in
        # the 0.9 series.  Keep the verified stevegrubb/libcap-ng identity.
        return f"https://github.com/stevegrubb/libcap-ng/archive/refs/tags/v{target}.tar.gz"
    if meta.rel == "opt/nodejs":
        return f"https://nodejs.org/dist/v{target}/node-v{target}.tar.xz"

    # GNOME-protected ports always use the official release service for exact
    # target validation rather than trusting whichever generic provider won.
    if meta.rel in GNOME_CACHE_VALIDATED_BOOK_PORTS:
        return f"https://download.gnome.org/sources/{meta.name}/{gnome_series(target)}/{meta.name}-{target}.tar.xz"

    # Generic GNOME source-template migration, including compat-32 ports such
    # as pango-32.  Never retain the old series directory across a series jump.
    for url in _remote_source_urls(meta):
        parsed = urlsplit(url)
        if parsed.netloc.lower() in {"download.gnome.org", "ftp.gnome.org"}:
            m = re.search(r"/sources/([^/]+)/[^/]+/([^/]+)$", parsed.path)
            if m and meta.version in m.group(2):
                module = m.group(1)
                filename = m.group(2).replace(meta.version, target)
                return f"https://download.gnome.org/sources/{module}/{gnome_series(target)}/{filename}"

    # Generic safe rewrite: only when the evaluated current version occurs in a
    # remote URL. This does not guess a new host/path layout.
    for url in _remote_source_urls(meta):
        if meta.version in url:
            return url.replace(meta.version, target)
    return ""


def remote_exists(url: str, timeout: int = 10) -> bool:
    if not url:
        return False
    # GET is used instead of HEAD because several upstream mirrors reject HEAD.
    try:
        req = Request(url, headers={"User-Agent": "BFSOS-port-updater/0.9.0", "Range": "bytes=0-0"})
        with urlopen(req, timeout=max(1, min(timeout, 10))) as r:
            return 200 <= getattr(r, "status", 200) < 400
    except Exception:
        return False


def validate_exact_target(meta: PortMeta, target: str, timeout: int) -> tuple[bool, str, str]:
    url = candidate_source_url(meta, target)
    if not url:
        return False, "no safe target source template", ""
    if not remote_exists(url, timeout):
        return False, f"target source does not exist: {url}", url
    return True, "exact target source verified", url


def special_browser_reference(meta: PortMeta, timeout: int) -> tuple[str, str, str]:
    """Direct browser version providers, including Mozilla's distinct ESR channel."""
    try:
        if meta.name in {"firefox", "firefox-esr"}:
            data = json.loads(fetch_text("https://product-details.mozilla.org/1.0/firefox_versions.json", timeout))
            if meta.name == "firefox-esr":
                # Mozilla publishes two ESR keys during overlap periods: the
                # older supported ESR in FIREFOX_ESR and the newer/current
                # train in FIREFOX_ESR_NEXT.  Prefer the newest comparable
                # ESR release rather than silently pinning BFSOS to the older
                # train merely because FIREFOX_ESR remains populated.
                esr_values = [
                    str(data.get("FIREFOX_ESR") or ""),
                    str(data.get("FIREFOX_ESR_NEXT") or ""),
                ]
                esr_values = [v for v in esr_values if v]
                ver = max(esr_values, key=version_key) if esr_values else ""
                provider = "Mozilla ESR"
            else:
                ver = str(data.get("LATEST_FIREFOX_VERSION") or "")
                provider = "Mozilla product-details"
            source = "" if not ver else f"https://archive.mozilla.org/pub/firefox/releases/{ver}/source/firefox-{ver}.source.tar.xz"
            return ver, provider, source
        if meta.name == "chromium":
            data = json.loads(fetch_text("https://chromiumdash.appspot.com/fetch_releases?channel=Stable&platform=Linux&num=1", timeout))
            if isinstance(data, list) and data:
                ver = str(data[0].get("version") or "")
                return ver, "Chromium Dash", ""
    except Exception:
        pass
    return "", "", ""


def _all_group_metas(ports_root: Path, members: set[str]) -> list[PortMeta]:
    out = []
    for rel in sorted(members):
        pkg = ports_root / rel / "Pkgfile"
        if pkg.is_file():
            try:
                out.append(eval_pkgfile(pkg, ports_root))
            except Exception as exc:
                print(f"WARN: cannot evaluate coordinated port {rel}: {exc}", file=sys.stderr)
    return out


def expand_coordinated_metas(ports_root: Path, metas: list[PortMeta]) -> tuple[list[PortMeta], list[PortMeta]]:
    """Pull every touched version-lock group into a scan across BFSOS trees."""
    rels = {m.rel for m in metas}
    extras: list[PortMeta] = []
    known = set(rels)
    for members in VERSION_LOCK_GROUPS.values():
        if not (rels & members):
            continue
        for m in _all_group_metas(ports_root, members):
            if m.rel not in known:
                extras.append(m)
                known.add(m.rel)
    return metas + extras, extras


def load_references(timeout: int):
    indexes = {}; failures = []
    for policy, label, url in BOOKS:
        try:
            raw = fetch_text(url, timeout)
            indexes[policy] = parse_package_inventory(raw) if policy == "mlfs-dev" else parse_book_index(raw)
            if not indexes[policy]: failures.append(f"{label}: parsed zero package versions")
        except Exception as exc:
            indexes[policy] = {}; failures.append(f"{label}: {exc}")
    mlfs_patches = []
    try: mlfs_patches = parse_patch_page(fetch_text(MLFS_PATCH_PAGE, timeout), MLFS_PATCH_PAGE)
    except Exception as exc: failures.append(f"MLFS patch index: {exc}")
    return indexes, mlfs_patches, failures


def read_audit_tsv(path: Path):
    if not path.exists(): return {}
    with path.open(newline="", encoding="utf-8") as f:
        return {r.get("port", ""): r for r in csv.DictReader(f, delimiter="\t") if r.get("port")}


def write_problem_report(path: Path, upstream: dict[str, dict[str, str]]) -> tuple[int, int]:
    """Write one concise diagnostic index for checker hard-problem rows."""
    path.parent.mkdir(parents=True, exist_ok=True)
    counts = {"UNVERIFIABLE": 0, "FETCH-ERROR": 0}
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, delimiter="\t", lineterminator="\n")
        w.writerow(["status", "tree", "port", "current", "provider", "reason", "source"])
        for rel in sorted(upstream):
            row = upstream[rel]
            status = row.get("status", "")
            if status not in counts:
                continue
            counts[status] += 1
            tree = rel.split("/", 1)[0] if "/" in rel else ""
            w.writerow([
                status, tree, rel, row.get("current", ""), row.get("provider", ""),
                (row.get("reason", "") or "").replace("\r", " ").replace("\n", " "),
                (row.get("source", "") or "").replace("\r", " ").replace("\n", " "),
            ])
    return counts["UNVERIFIABLE"], counts["FETCH-ERROR"]


def run_upstream_audit(ports_root: Path, trees: list[str], jobs: int, timeout: int, out: Path, ports: list[str] | None = None):
    env = dict(os.environ); env["REPO"] = " ".join(str(ports_root / t) for t in trees)
    cmd = [sys.executable, str(ROOT / "scripts/checkupdate.py"), "--jobs", str(jobs), "--timeout", str(timeout), "--tsv", str(out)]
    if ports:
        cmd.extend(ports)
    cp = run(cmd, env=env)
    if not out.exists(): raise RuntimeError(f"version checker produced no TSV (status {cp.returncode})")
    return read_audit_tsv(out)


def crux_reference_version(meta: PortMeta, timeout: int = 10) -> str:
    """Best-effort official CRUX reference with a strict per-port time budget.

    CRUX is only a secondary reference source. A slow or unreachable rsync
    endpoint must never make a BFSOS tree scan appear hung.
    """
    if not shutil.which("rsync"):
        return ""
    names = [meta.name, meta.path.name]
    if meta.name.startswith("python3-"):
        names.append(meta.name)
    collections = ("core", "opt", "xorg", "compat-32", "contrib")

    # Cap the entire CRUX lookup for one BFSOS port. The old implementation
    # could spend timeout * names * collections seconds here.
    budget = max(1.0, min(float(timeout), 5.0))
    deadline = time.monotonic() + budget
    with tempfile.TemporaryDirectory(prefix="bfs-crux-ref-") as td_s:
        dest = Path(td_s) / "Pkgfile"
        for name in dict.fromkeys(names):
            for collection in collections:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    return ""
                attempt = max(1, min(2, int(remaining + 0.999)))
                dest.unlink(missing_ok=True)
                try:
                    cp = subprocess.run(
                        ["rsync", "--contimeout", str(attempt), "--timeout", str(attempt), "-q",
                         f"rsync://crux.nu/ports/crux-3.8/{collection}/{name}/Pkgfile", str(dest)],
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                        timeout=min(remaining, attempt + 0.5),
                    )
                except (subprocess.TimeoutExpired, OSError):
                    continue
                if cp.returncode == 0 and dest.is_file():
                    m = re.search(r"(?m)^version=(?:['\"])?([^\s'\"]+)", dest.read_text(errors="replace"))
                    if m:
                        return m.group(1)
    return ""


def _remote_source_urls(meta: PortMeta) -> list[str]:
    urls = []
    for src in meta.sources:
        raw = src.split("::", 1)[-1] if "::" in src else src
        if raw.startswith(("http://", "https://", "ftp://")):
            urls.append(raw)
    return urls


def _project_identity(url: str) -> tuple[str, str]:
    """Return a conservative (host, project-path) identity for an upstream URL."""
    if not url:
        return "", ""
    try:
        u = urlsplit(url)
    except Exception:
        return "", ""
    host = (u.hostname or "").lower().removeprefix("www.")
    path = re.sub(r"/+", "/", u.path or "").strip("/")
    path = re.sub(r"\.(?:git|tar|tar\.gz|tar\.xz|tgz|zip)$", "", path, flags=re.I)

    # Repository hosts: owner/project is the stable identity.
    if host == "github.com":
        parts = path.split("/")
        return (host, "/".join(parts[:2]).lower()) if len(parts) >= 2 else (host, path.lower())
    if "gitlab" in host:
        path = path.split("/-/", 1)[0]
        parts = path.split("/")
        return (host, "/".join(parts[:2]).lower()) if len(parts) >= 2 else (host, path.lower())
    if host.endswith("kernel.org"):
        # kernel.org snapshot URLs and repository URLs share the .git path.
        m = re.search(r"(.+?\.git)(?:/|$)", u.path, re.I)
        return host, (m.group(1).strip("/").lower() if m else path.lower())

    return host, path.lower()


def arch_identity_matches(meta: PortMeta, arch_url: str) -> tuple[bool, str]:
    """Verify an Arch package's upstream URL against the BFSOS port sources."""
    ahost, aproj = _project_identity(arch_url)
    if not ahost:
        return False, "Arch package has no usable upstream URL"

    local = [_project_identity(u) for u in _remote_source_urls(meta)]
    local = [(h, p) for h, p in local if h]
    for lhost, lproj in local:
        if lhost != ahost:
            continue
        if lproj == aproj:
            return True, f"same upstream identity {ahost}/{aproj}"
        # For non-forge hosts, accept only when the package/project stem appears
        # in both paths on the same host. This handles release/archive subdirs
        # without reducing identity verification to package-name equality alone.
        stem = normalize_name(meta.name.removesuffix("-32"))
        if stem and stem in normalize_name(lproj) and stem in normalize_name(aproj):
            return True, f"same upstream host/project stem {ahost} ({meta.name})"
    return False, "Arch upstream does not match BFSOS source identity"


def arch_reference(meta: PortMeta, timeout: int = 10) -> ArchReference:
    """Best-effort Arch reference, accepted only after upstream identity checks."""
    import urllib.parse
    for name in dict.fromkeys([meta.name, meta.path.name]):
        try:
            url = "https://archlinux.org/packages/search/json/?name=" + urllib.parse.quote(name)
            data = json.loads(fetch_text(url, timeout))
        except Exception:
            continue
        for item in data.get("results", []):
            if item.get("pkgname") != name or not item.get("pkgver"):
                continue
            version = str(item["pkgver"])
            upstream_url = str(item.get("url") or "")
            verified, reason = arch_identity_matches(meta, upstream_url)
            if not verified:
                return ArchReference(version, upstream_url, False, reason)
            if not versions_comparable(version, meta.version):
                return ArchReference(
                    version, upstream_url, False,
                    f"incompatible version lineage {meta.version} vs {version}",
                )
            return ArchReference(version, upstream_url, True, reason)
    return ArchReference()


def arch_reference_version(meta: PortMeta, timeout: int = 10) -> str:
    """Compatibility wrapper for older callers/tests."""
    ref = arch_reference(meta, timeout)
    return ref.version if ref.verified else ""


def prefetch_fallback_references(
    metas: list[PortMeta],
    indexes: dict[str, dict[str, str]],
    timeout: int,
    jobs: int,
    diagnostics: list[str] | None = None,
) -> dict[str, tuple[str, ArchReference]]:
    """Resolve CRUX/Arch fallbacks concurrently for non-LFS-mapped ports.

    Candidate identity remains the full BFSOS port path.  The work is parallel,
    bounded, and progress is printed so a large Core scan never looks frozen.
    """
    diagnostics = diagnostics if diagnostics is not None else []
    targets = [
        m for m in metas
        if m.name not in KERNEL_PORTS and lookup_mlfs_authoritative(m, indexes) is None
    ]
    if not targets:
        return {}

    workers = max(1, min(int(jobs or 1), 12, len(targets)))
    crux_timeout = max(1, min(int(timeout), 5))
    arch_timeout = max(1, min(int(timeout), 5))
    results: dict[str, tuple[str, ArchReference]] = {}

    def one(meta: PortMeta) -> tuple[str, str, ArchReference]:
        crux_v = crux_reference_version(meta, crux_timeout)
        # Always check Arch too. A verified Arch release may be newer than CRUX;
        # exact-name alone is never enough because arch_reference() verifies
        # upstream identity and version lineage.
        arch_ref = arch_reference(meta, arch_timeout)
        return meta.rel, crux_v, arch_ref

    print(
        f"Fallback references: checking {len(targets)} non-LFS ports "
        f"with {workers} workers (CRUX/Arch max {crux_timeout}s each)...",
        file=sys.stderr,
        flush=True,
    )
    done = 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        future_map = {pool.submit(one, meta): meta for meta in targets}
        for fut in concurrent.futures.as_completed(future_map):
            meta = future_map[fut]
            try:
                rel, crux_v, arch_ref = fut.result()
            except Exception as exc:
                rel, crux_v, arch_ref = meta.rel, "", ArchReference(reason=f"lookup error: {exc}")
                diagnostics.append(f"{meta.rel}\tfallback lookup error\t{exc}")
            results[rel] = (crux_v, arch_ref)
            done += 1
            if done == 1 or done % 10 == 0 or done == len(targets):
                print(
                    f"... fallback checked {done}/{len(targets)}",
                    file=sys.stderr,
                    flush=True,
                )
    return results


def make_candidates(metas: list[PortMeta], indexes, mlfs_patches: list[PatchSpec], upstream, timeout: int,
                    diagnostics: list[str] | None = None,
                    fallback_refs: dict[str, tuple[str, ArchReference]] | None = None) -> list[Candidate]:
    out: list[Candidate] = []
    by_name = {m.name: m for m in metas}
    diagnostics = diagnostics if diagnostics is not None else []
    fallback_refs = fallback_refs or {}

    # Kernel candidates first so headers can track the proposed LTS point release.
    lts_target = by_name.get("linux-lts").version if by_name.get("linux-lts") else ""
    for meta in metas:
        row = upstream.get(meta.rel, {})
        if row.get("latest") and has_unresolved_version_placeholder(row.get("latest", "")):
            diagnostics.append(f"{meta.rel}\tupstream candidate rejected: unresolved version placeholder\t{row.get('latest','')}")
            row = dict(row)
            row["status"] = "UNVERIFIABLE"
            row["latest"] = ""
        if meta.name == "linux-lts" and row.get("status") == "UPDATE" and row.get("latest"):
            lts_target = row["latest"]
            out.append(Candidate(meta.rel, meta.name, meta.version, row["latest"], meta.release, "1",
                                 "kernel-bfsos-lts", "kernel.org LTS series", "UPDATE",
                                 "BFSOS 6.18 LTS point-release policy", True, row.get("provider", ""), row.get("source", "")))
        elif meta.name == "linux" and row.get("status") == "UPDATE" and row.get("latest"):
            out.append(Candidate(meta.rel, meta.name, meta.version, row["latest"], meta.release, "1",
                                 "kernel-bfsos-current", "kernel.org current series", "REVIEW",
                                 "optional current kernel; review separately from default LTS", False,
                                 row.get("provider", ""), row.get("source", "")))

    for meta in metas:
        if meta.name in {"linux", "linux-lts"}:
            continue
        if meta.name == "linux-headers":
            if lts_target and lts_target != meta.version:
                out.append(Candidate(meta.rel, meta.name, meta.version, lts_target, meta.release, "1",
                                     "kernel-bfsos-lts", "BFSOS LTS kernel", "UPDATE",
                                     "userspace kernel headers track linux-lts; glibc release bump required", True))
            continue

        # Development-book authority is explicit per BFSOS port.
        mlfs = lookup_mlfs_authoritative(meta, indexes)
        explicit_dev = lookup_explicit_dev_authority(meta, indexes)
        authoritative = mlfs or explicit_dev
        if authoritative:
            policy, target = authoritative
            source_label = "MLFS DEV" if policy == "mlfs-dev" else next(x[1] for x in BOOKS if x[0] == policy)
            if has_unresolved_version_placeholder(target):
                diagnostics.append(f"{meta.rel}\t{source_label} target rejected: unresolved version placeholder\t{target}")
                continue
            diagnostics.append(f"{meta.rel}\tdev-book-authoritative\t{source_label}\t{target}")
            row = upstream.get(meta.rel, {})
            if newer_for_port(meta, meta.version, target):
                diagnostics.append(f"{meta.rel}\t{source_label} {target} ignored: BFSOS {meta.version} is newer")
                continue

            if meta.rel in GNOME_CACHE_VALIDATED_BOOK_PORTS and target != meta.version:
                ok, why_exact, exact_url = validate_exact_target(meta, target, timeout)
                if not ok:
                    diagnostics.append(f"{meta.rel}\tMLFS target rejected\t{target}\t{why_exact}")
                    continue
            else:
                exact_url = ""

            if meta.rel in SAME_SERIES_UPSTREAM_OVERRIDES:
                upstream_latest = row.get("latest", "")
                if (row.get("status") == "UPDATE" and upstream_latest
                        and newer_for_port(meta, upstream_latest, meta.version)
                        and same_series(upstream_latest, meta.version)
                        and (target == meta.version or newer_for_port(meta, upstream_latest, target))):
                    diagnostics.append(f"{meta.rel}\tMLFS {target}; same-series upstream override {upstream_latest}")
                    target = upstream_latest
                    policy = "upstream-point-release"

            required = relevant_patches(meta, mlfs_patches) if policy == "mlfs-dev" else []
            obsolete = likely_book_obsolete(meta, required) if policy == "mlfs-dev" else []
            current_patches = set(local_patch_names(meta))
            required_names = {p.filename for p in required}
            patch_change = bool(required_names - current_patches or obsolete)
            if versions_equivalent_for_port(meta, target, meta.version) and not patch_change:
                continue
            if target != meta.version and not newer_for_port(meta, target, meta.version):
                continue
            if not family_allows(meta, target):
                diagnostics.append(f"{meta.rel}\tfamily-guard\t{meta.version}\t{target}")
                continue

            new_rel = "1" if target != meta.version else str(int(meta.release) + 1 if meta.release.isdigit() else meta.release)
            why = f"{source_label} explicit authoritative version"
            if policy == "upstream-point-release":
                why = "same-series upstream point release ahead of MLFS DEV"
            if patch_change and target == meta.version:
                why = "MLFS DEV patch set changed; packaging release bump"
            elif patch_change:
                why += "; MLFS DEV patch set also changed"

            old_version_patches = [n for n in local_patch_names(meta) if meta.version in n]
            status, selected = "UPDATE", True
            if target != meta.version and old_version_patches and not required:
                status, selected = "REVIEW", False
                why += "; version-specific local patch requires applicability/replacement review: " + ", ".join(old_version_patches)
            source = exact_url or candidate_source_url(meta, target)
            out.append(Candidate(meta.rel, meta.name, meta.version, target, meta.release, new_rel,
                                 policy, source_label, status, why, selected,
                                 source=source, patches=required, obsolete_patches=obsolete))
            continue

        # LFS/BLFS/GLFS are references only. Record the lead, then continue through
        # CRUX -> verified Arch -> direct upstream before falling back to the book.
        book_ref = lookup_book_reference(meta, indexes)
        if book_ref:
            bpolicy, btarget = book_ref
            blabel = next(x[1] for x in BOOKS if x[0] == bpolicy)
            diagnostics.append(f"{meta.rel}\tbook-reference-only\t{blabel}\t{btarget}")
        else:
            bpolicy = btarget = blabel = ""

        diagnostics.append(f"{meta.rel}\tnot MLFS-authoritative; checking CRUX")
        if meta.rel in fallback_refs:
            crux_v, arch_ref = fallback_refs[meta.rel]
        else:
            crux_v = crux_reference_version(meta, min(timeout, 5))
            arch_ref = ArchReference()
            if not (crux_v and newer_for_port(meta, crux_v, meta.version) and family_allows(meta, crux_v)):
                arch_ref = arch_reference(meta, min(timeout, 5))

        if crux_v:
            diagnostics.append(f"{meta.rel}\tCRUX\t{crux_v}")
        else:
            diagnostics.append(f"{meta.rel}\tnot found in CRUX; checking Arch")
        arch_v = arch_ref.version
        crux_newer = bool(crux_v and newer_for_port(meta, crux_v, meta.version) and family_allows(meta, crux_v))
        arch_newer = bool(arch_v and arch_ref.verified
                          and newer_for_port(meta, arch_v, meta.version)
                          and family_allows(meta, arch_v))
        # Prefer the newer verified reference. CRUX remains the first lookup, but
        # it does not artificially cap BFSOS when Arch is positively verified as
        # the same upstream project and carries a newer comparable release.
        if crux_newer and not (arch_newer and newer_for_port(meta, arch_v, crux_v)):
            if reject_downstream_snapshot(meta, crux_v):
                diagnostics.append(f"{meta.rel}\tCRUX {crux_v} rejected: downstream VCS snapshot; BFSOS port tracks releases")
            else:
                out.append(Candidate(meta.rel, meta.name, meta.version, crux_v, meta.release, "1",
                                     "review", "CRUX reference", "REVIEW",
                                     f"not MLFS-authoritative; CRUX carries {crux_v}", False,
                                     source=candidate_source_url(meta, crux_v)))
                continue

        if arch_v:
            if arch_ref.verified:
                diagnostics.append(f"{meta.rel}\tArch\t{arch_v}\tidentity verified: {arch_ref.reason}")
            else:
                diagnostics.append(f"{meta.rel}\tArch\t{arch_v}\trejected: {arch_ref.reason or 'identity not verified'}")
        else:
            diagnostics.append(f"{meta.rel}\tnot found in Arch; checking upstream")

        if (arch_v and arch_ref.verified
                and not versions_equivalent_for_port(meta, arch_v, meta.version)
                and newer_for_port(meta, arch_v, meta.version)
                and family_allows(meta, arch_v)):
            if reject_downstream_snapshot(meta, arch_v):
                diagnostics.append(f"{meta.rel}\tArch {arch_v} rejected: downstream VCS snapshot; BFSOS port tracks releases")
            else:
                out.append(Candidate(meta.rel, meta.name, meta.version, arch_v, meta.release, "1",
                                     "review", "Arch reference", "REVIEW",
                                     f"not MLFS-authoritative; verified same upstream; Arch carries {arch_v}", False,
                                     source=candidate_source_url(meta, arch_v)))
                continue

        # Explicit browser channels take precedence over generic discovery. In
        # particular, firefox-esr must never be compared against rapid-release
        # Firefox simply because a generic provider reports it.
        browser_v, browser_provider, browser_source = special_browser_reference(meta, timeout)
        if meta.name in {"firefox", "firefox-esr", "chromium"}:
            if browser_v:
                diagnostics.append(f"{meta.rel}\tbrowser-provider\t{browser_provider}\tcurrent={meta.version} latest={browser_v}")
                if newer_for_port(meta, browser_v, meta.version) and family_allows(meta, browser_v):
                    out.append(Candidate(meta.rel, meta.name, meta.version, browser_v, meta.release, "1",
                                         "review", browser_provider, "REVIEW",
                                         "explicit browser provider found newer release", False,
                                         browser_provider, browser_source or candidate_source_url(meta, browser_v)))
                    continue
            else:
                diagnostics.append(f"{meta.rel}\tbrowser-provider unavailable")
            if meta.name == "firefox-esr":
                # ESR has an explicit channel; never fall through to a generic
                # rapid-release Firefox result when that channel is unavailable.
                continue

        row = upstream.get(meta.rel, {})
        if row.get("status") == "UPDATE" and row.get("latest") and newer_for_port(meta, row["latest"], meta.version):
            if family_allows(meta, row["latest"]):
                diagnostics.append(f"{meta.rel}\tupstream\t{row['latest']}")
                out.append(Candidate(meta.rel, meta.name, meta.version, row["latest"], meta.release, "1",
                                     "review", row.get("provider") or "upstream", "REVIEW",
                                     row.get("reason") or "newer version found outside MLFS authority", False,
                                     row.get("provider", ""), candidate_source_url(meta, row["latest"]) or (row.get("source", "") if row["latest"] in row.get("source", "") else "")))
                continue
            diagnostics.append(f"{meta.rel}\tfamily-guard\t{meta.version}\t{row['latest']}")

        # A reference-book target is a final conservative lead, never automatic.
        if btarget and newer_for_port(meta, btarget, meta.version) and family_allows(meta, btarget):
            ok, why_exact, exact_url = validate_exact_target(meta, btarget, timeout)
            if meta.rel in GNOME_CACHE_VALIDATED_BOOK_PORTS and not ok:
                diagnostics.append(f"{meta.rel}\t{blabel} target rejected\t{btarget}\t{why_exact}")
                continue
            source = exact_url if ok else candidate_source_url(meta, btarget)
            reason = f"{blabel} reference only; not MLFS-authoritative"
            if ok:
                reason += "; exact target source verified"
            elif source:
                reason += "; source template derived but remote validation unavailable"
            out.append(Candidate(meta.rel, meta.name, meta.version, btarget, meta.release, "1",
                                 "book-reference", f"{blabel} reference", "REVIEW",
                                 reason, False, source=source))
            continue

        diagnostics.append(f"{meta.rel}\tno newer verified/reference version found")

    enforce_version_lock_groups(out, metas)
    return sorted(out, key=lambda c: c.port)


def slackware_dialogrc(path: Path):
    path.write_text('''aspect = 0\nseparate_widget = ""\ntab_len = 0\nvisit_items = OFF\nuse_scrollbar = OFF\nuse_shadow = ON\nuse_colors = ON\nscreen_color = (WHITE,BLUE,OFF)\nshadow_color = (WHITE,BLACK,OFF)\ndialog_color = (BLACK,CYAN,OFF)\ntitle_color = (YELLOW,CYAN,ON)\nborder_color = (CYAN,CYAN,ON)\nbutton_active_color = (WHITE,BLUE,ON)\nbutton_inactive_color = dialog_color\nbutton_key_active_color = button_active_color\nbutton_key_inactive_color = (RED,CYAN,OFF)\nbutton_label_active_color = button_active_color\nbutton_label_inactive_color = (BLACK,CYAN,ON)\ninputbox_color = (BLUE,WHITE,OFF)\ninputbox_border_color = border_color\nsearchbox_color = (YELLOW,WHITE,ON)\nsearchbox_title_color = (WHITE,WHITE,ON)\nsearchbox_border_color = (RED,WHITE,OFF)\nposition_indicator_color = button_key_inactive_color\nmenubox_color = dialog_color\nmenubox_border_color = border_color\nitem_color = dialog_color\nitem_selected_color = screen_color\ntag_color = title_color\ntag_selected_color = screen_color\ntag_key_color = button_key_inactive_color\ntag_key_selected_color = (RED,BLUE,ON)\ncheck_color = dialog_color\ncheck_selected_color = (WHITE,CYAN,ON)\nuarrow_color = (GREEN,CYAN,ON)\ndarrow_color = uarrow_color\nitemhelp_color = shadow_color\nform_active_text_color = inputbox_color\nform_text_color = (CYAN,BLUE,ON)\nform_item_readonly_color = (CYAN,WHITE,ON)\ngauge_color = (BLUE,WHITE,ON)\nborder2_color = dialog_color\ninputbox_border2_color = dialog_color\nsearchbox_border2_color = dialog_color\nmenubox_border2_color = dialog_color\n''')


def dialog_available(): return shutil.which("dialog") is not None and sys.stdin.isatty() and sys.stderr.isatty()
def dcall(args, env):
    cp = subprocess.run(["dialog", "--stdout", "--clear", "--backtitle", "BFSOS Port Updater", *args], text=True, stdout=subprocess.PIPE, env=env)
    return cp.returncode, cp.stdout.strip()


def choose_action_dialog(env, retry_count=0):
    items = [
        "1", "Check all discovered port trees",
        "2", "Select port trees to check",
        "3", "Kernel / kernel-headers maintenance",
        "4", f"Set BFSOS distro version (current: {project_distro_version()})",
    ]
    if retry_count:
        items += ["5", f"Retry failed updates ({retry_count})"]
        exit_tag = "6"
    else:
        exit_tag = "5"
    items += [exit_tag, "Exit"]
    code, out = dcall(["--title", "Maintainer updater", "--menu", "Choose an update task.",
                       "20", "88", "10", *items], env)
    return out if code == 0 else exit_tag

def choose_distro_version_dialog(env):
    current = project_distro_version()
    code, out = dcall(["--title", "BFSOS distro version", "--inputbox",
                       "Enter the BFSOS release version.\n\nThis updates VERSION, active release fallbacks, release documentation, and aaa_filesystem; aaa_filesystem release is bumped so sysup can install the new identity.",
                       "13", "92", current], env)
    return None if code else out.strip()


def choose_trees_dialog(trees, env):
    items = []
    # Nothing is preselected. "Check all discovered port trees" is the explicit
    # top-level action for scanning everything.
    for t in trees:
        items += [t.name, f"{port_count(t)} ports", "off"]
    code, out = dcall(["--title", "Select port trees", "--separate-output", "--checklist",
                       "Space toggles a tree. Enter accepts.", "24", "88", "16", *items], env)
    return None if code else [x.strip('"') for x in out.splitlines() if x.strip()]


def choose_updates_dialog(cands, env):
    items = []
    for c in cands:
        desc = f"{c.old} -> {c.new} r{c.old_release}->{c.new_release} [{c.source_label}; {c.status}]"
        # Only policy-approved UPDATE candidates may start checked.
        # REVIEW/held/unknown items always start unchecked.
        state = "on" if (c.status == "UPDATE" and c.selected) else "off"
        items += [c.port, desc, state]
    code, out = dcall(["--title", "Updates found", "--separate-output", "--checklist",
                       "ON = update. OFF = do not update. REVIEW items always start OFF.", "29", "125", "21", *items], env)
    return None if code else [x.strip('"') for x in out.splitlines() if x.strip()]



def pkgfile_fingerprint(pkgfile: Path) -> str:
    try:
        return hashlib.sha256(pkgfile.read_bytes()).hexdigest()
    except OSError:
        return ""


def _port_matches_logged_target(ports_root: Path, row: dict[str, str]) -> bool:
    """Only retry a failed build if the tree still contains the recorded target."""
    rel = row.get("port", "")
    pkgfile = ports_root / rel / "Pkgfile"
    if not rel or not pkgfile.is_file():
        return False
    try:
        meta = eval_pkgfile(pkgfile, ports_root)
    except Exception:
        return False
    if row.get("new_version") and meta.version != row["new_version"]:
        return False
    if row.get("new_release") and meta.release != row["new_release"]:
        return False
    # New logs record the exact Pkgfile that failed.  A manual fix outside the
    # updater invalidates that retry entry even when version/release stay equal.
    if row.get("pkgfile_sha256") and pkgfile_fingerprint(pkgfile) != row["pkgfile_sha256"]:
        return False
    return True


def _iter_scan_rows_newest_first():
    for log in sorted(LOG_ROOT.glob("scan-*.tsv"), reverse=True):
        try:
            with log.open(newline="", encoding="utf-8") as f:
                rows = list(csv.DictReader((line for line in f if not line.startswith("#")), delimiter="\t"))
        except (OSError, csv.Error):
            continue
        yield log, rows


def find_retryable_failures(ports_root: Path) -> tuple[Path | None, list[dict[str, str]]]:
    """Return only the latest active state for each failed port.

    Historical failures remain in their logs, but a newer successful build,
    retry, revert, version/release change, or Pkgfile edit makes the old failure
    non-active and removes it from the Retry menu.
    """
    if not LOG_ROOT.is_dir():
        return None, []
    seen: set[str] = set()
    retry_rows: list[dict[str, str]] = []
    source_log: Path | None = None
    for log, rows in _iter_scan_rows_newest_first():
        for row in rows:
            rel = row.get("port", "")
            result = row.get("result", "")
            # A scan/checklist row with no action result is historical context,
            # not a state transition, and must not clear an older real failure.
            if not rel or not result or rel in seen:
                continue
            # The newest actionable result for a port is its current updater
            # state.  Success clears older failures; a current failure remains.
            seen.add(rel)
            if not any(mark in result for mark in ("BUILD FAILED", "INSTALL FAILED", "RETRY FAILED", "BLOCKED:")):
                continue
            if _port_matches_logged_target(ports_root, row):
                retry_rows.append(row)
                source_log = source_log or log
    return source_log, sorted(retry_rows, key=lambda r: r.get("port", ""))

def choose_retry_dialog(rows, env):
    items = []
    for row in rows:
        desc = (
            f"{row.get('new_version','?')} r{row.get('new_release','?')} "
            f"[{row.get('result','FAILED')}]"
        )
        # Retrying is explicit; nothing is preselected.
        items += [row.get("port", ""), desc, "off"]
    code, out = dcall(
        ["--title", "Retry failed updates", "--separate-output", "--checklist",
         "Select failed ports to retry. Only failures whose applied version/release still matches the current tree are shown.",
         "24", "120", "16", *items],
        env,
    )
    return None if code else [x.strip('"') for x in out.splitlines() if x.strip()]


def retry_failed_updates(rows, selected, ports_root: Path):
    """Retry build (and prior install, when applicable) without reapplying versions."""
    results = {}
    by_port = {row.get("port", ""): row for row in rows}
    # Coordinated families retain their dependency order during retry. BLOCKED
    # rows remain visible even when a previous scan already advanced Pkgfiles to
    # the target version, so an interrupted SDK transaction does not disappear.
    for rel in sorted(selected, key=_build_rank):
        row = by_port.get(rel)
        if not row:
            continue
        port_dir = ports_root / rel
        if not _port_matches_logged_target(ports_root, row):
            results[rel] = "SKIPPED: tree changed since failed run"
            continue

        cp = run(["sudo", "pkgmk", "-d", "-kw"], cwd=port_dir)
        if cp.returncode:
            results[rel] = f"BUILD RETRY FAILED ({cp.returncode})"
            continue

        if "INSTALL FAILED" in row.get("result", ""):
            name = eval_pkgfile(port_dir / "Pkgfile", ports_root).name
            cp2 = run(["sudo", "prt-get", "-fr", "depinst", name])
            if cp2.returncode:
                results[rel] = f"BUILT; INSTALL RETRY FAILED ({cp2.returncode})"
                continue
            results[rel] = "BUILT+INSTALLED ON RETRY"
        else:
            results[rel] = "BUILT ON RETRY"
    return results


def detail_text(cands, selected):
    blocks = []
    for c in cands:
        patches = ""
        if c.patches: patches += "\n  patches: " + ", ".join(p.filename for p in c.patches)
        if c.obsolete_patches: patches += "\n  obsolete after successful build: " + ", ".join(c.obsolete_patches)
        blocks.append(f"[{'UPDATE' if c.port in selected else 'SKIP'}] {c.port}\n  {c.old} -> {c.new}; release {c.old_release} -> {c.new_release}\n  policy={c.policy}; source={c.source_label}; status={c.status}\n  {c.reason}{patches}")
    return "\n\n".join(blocks)


def write_scan_log(path, cands, selected, results, warnings, diagnostics=None, ports_root: Path | None = None):
    path.parent.mkdir(parents=True, exist_ok=True)
    ports_root = ports_root or DEFAULT_PORTS_ROOT
    with path.open("w", encoding="utf-8") as f:
        f.write("port\told_version\tnew_version\told_release\tnew_release\tpolicy\tsource\tstatus\tselected\tresult\treason\tpkgfile_sha256\n")
        for c in cands:
            fp = pkgfile_fingerprint(ports_root / c.port / "Pkgfile")
            vals = [c.port,c.old,c.new,c.old_release,c.new_release,c.policy,c.source_label,c.status,
                    "yes" if c.port in selected else "no", results.get(c.port,""),c.reason,fp]
            f.write("\t".join(x.replace("\t"," ").replace("\n"," ") for x in vals)+"\n")
        for w in warnings: f.write(f"# WARNING: {w}\n")
        for d in diagnostics or []: f.write(f"# TRACE: {d}\n")


def write_retry_state_log(rows, results, ports_root: Path):
    """Record retry outcomes so a successful retry retires the old failure."""
    if not results:
        return None
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    path = LOG_ROOT / f"scan-{stamp}-retry.tsv"
    by_port = {r.get("port", ""): r for r in rows}
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        f.write("port\told_version\tnew_version\told_release\tnew_release\tpolicy\tsource\tstatus\tselected\tresult\treason\tpkgfile_sha256\n")
        for rel, result in sorted(results.items()):
            row = by_port.get(rel, {})
            pkgfile = ports_root / rel / "Pkgfile"
            try:
                meta = eval_pkgfile(pkgfile, ports_root)
                ver, release = meta.version, meta.release
            except Exception:
                ver, release = row.get("new_version", ""), row.get("new_release", "")
            vals = [rel,row.get("old_version",ver),ver,row.get("old_release",release),release,
                    "retry",row.get("source",""),"RETRY","yes",result,"retry state",pkgfile_fingerprint(pkgfile)]
            f.write("\t".join(x.replace("\t"," ").replace("\n"," ") for x in vals)+"\n")
    return path

def apply_selected(cands, selected, ports_root: Path, timeout: int):
    # Interactive REVIEW items start OFF, but an explicitly checked REVIEW item
    # is a maintainer override and should be applied. Noninteractive --apply
    # remains conservative because main() only auto-selects UPDATE candidates.
    results = {}
    group_error = _selection_group_error(cands, set(selected), ports_root)
    if group_error:
        for c in cands:
            if c.port in selected and any(c.port in members for members in VERSION_LOCK_GROUPS.values()):
                results[c.port] = "BLOCKED: " + group_error
        return results
    chosen = [c for c in cands if c.port in selected and c.status in {"UPDATE", "REVIEW"}]
    chosen.sort(key=lambda c: _build_rank(c.port))
    if not chosen: return results
    with tempfile.TemporaryDirectory(prefix="bfs-selected-updates-") as td_s:
        td = Path(td_s)
        tsv = td/"selected.tsv"
        with tsv.open("w", encoding="utf-8", newline="") as f:
            w = csv.writer(f, delimiter="\t", lineterminator="\n")
            w.writerow(["status","port","current","latest","provider","reason","source","new_release","patches_json","obsolete_patches_json"])
            for c in chosen:
                w.writerow(["UPDATE",c.port,c.old,c.new,c.source_label,c.reason,c.source,c.new_release,
                            json.dumps([dataclasses.asdict(p) for p in c.patches]),json.dumps(c.obsolete_patches)])

        # Version-locked families are staged transactionally across port dirs.
        # The maintained updater commits one row at a time, so snapshot every
        # selected group member here and restore the whole family if any member
        # is rejected. This prevents a half-applied SDK/driver tree.
        backups: dict[str, Path] = {}
        chosen_ports = {c.port for c in chosen}
        for group, members in VERSION_LOCK_GROUPS.items():
            touched = chosen_ports & members
            if not touched:
                continue
            group_backup = td / ("backup-" + group)
            for rel in sorted(touched):
                src = ports_root / rel
                if src.is_dir():
                    dst = group_backup / rel
                    dst.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copytree(src, dst, symlinks=True)
            backups[group] = group_backup

        env = dict(os.environ); env["BFSOS_PORTS_ROOT"] = str(ports_root)
        cp = run([sys.executable,str(ROOT/"scripts"/"bfs-maintained-port-updater.py"),str(tsv),"--apply","--timeout",str(timeout)], env=env, capture=True)
        combined = (cp.stdout or "")+(cp.stderr or "")
        for c in chosen:
            if re.search(rf"^UPDATED {re.escape(c.port)} ", combined, re.M):
                results[c.port] = "UPDATED"
                continue
            review = re.search(
                rf"^NEEDS-REVIEW {re.escape(c.port)} .*?: (.+)$", combined, re.M
            )
            if review:
                results[c.port] = "NEEDS REVIEW: " + review.group(1).strip()
            else:
                results[c.port] = "FAILED/REVIEW"

        for group, members in VERSION_LOCK_GROUPS.items():
            touched = chosen_ports & members
            if not touched or not any(results.get(rel) != "UPDATED" for rel in touched):
                continue
            backup = backups.get(group)
            if backup:
                for rel in sorted(touched):
                    current = ports_root / rel
                    saved = backup / rel
                    if current.exists():
                        shutil.rmtree(current)
                    if saved.is_dir():
                        current.parent.mkdir(parents=True, exist_ok=True)
                        shutil.copytree(saved, current, symlinks=True)
            failed = [rel for rel in sorted(touched) if results.get(rel) != "UPDATED"]
            detail = f"{group} apply transaction rolled back; failed/review: {', '.join(failed)}"
            for rel in touched:
                prior = results.get(rel, "")
                results[rel] = f"ROLLED BACK: {detail}" + (f"; {prior}" if prior and prior != "UPDATED" else "")

        if cp.returncode: print(combined,file=sys.stderr)

    # Header changes require glibc to be rebuilt against the new userspace headers.
    if any(c.name == "linux-headers" and results.get(c.port)=="UPDATED" for c in chosen):
        gp = ports_root/"core"/"glibc"/"Pkgfile"
        if gp.exists():
            text = gp.read_text(); m = re.search(r"(?m)^release=(\d+)\s*$",text)
            if m:
                old=int(m.group(1)); tmp=gp.with_name("Pkgfile.bfs-update-tmp")
                tmp.write_text(text[:m.start()]+f"release={old+1}"+text[m.end():]); os.replace(tmp,gp)
                results["core/glibc"] = f"RELEASE BUMP {old}->{old+1} (linux-headers)"
            else: results["core/glibc"] = "NEEDS REVIEW: non-numeric release"
    return results


def snapshot_selected_ports(selected: set[str], ports_root: Path) -> Path | None:
    """Snapshot selected port directories before apply+build validation."""
    if not selected:
        return None
    root = Path(tempfile.mkdtemp(prefix="bfs-port-updater-build-backup-"))
    for rel in sorted(selected):
        src = ports_root / rel
        if src.is_dir():
            dst = root / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copytree(src, dst, symlinks=True)
    return root


def read_build_work_preference(port_dir: Path) -> str | None:
    """Read explicit BFSOS top-level build_work= metadata without sourcing Pkgfile."""
    pkgfile = port_dir / "Pkgfile"
    if not pkgfile.is_file():
        return None
    rx = re.compile(r"^\s*build_work\s*=\s*[\"']?([^\"'\s#]+)")
    for line in pkgfile.read_text(errors="replace").splitlines():
        m = rx.match(line)
        if not m:
            continue
        value = m.group(1).strip().lower()
        if value not in {"tmpfs", "disk"}:
            raise ValueError(f"invalid build_work={value}; expected tmpfs or disk")
        return value
    return None


def read_build_work_backend(port_dir: Path) -> str:
    """Compatibility helper returning the historical default backend."""
    return read_build_work_preference(port_dir) or "tmpfs"


def package_name_from_pkgfile(port_dir: Path) -> str:
    pkgfile = port_dir / "Pkgfile"
    if not pkgfile.is_file():
        return port_dir.name
    m = re.search(r"(?m)^\s*name\s*=\s*[\"']?([^\"'\s#]+)", pkgfile.read_text(errors="replace"))
    return m.group(1).strip() if m else port_dir.name


def is_known_large_build(port_dir: Path, port_rel: str = "") -> bool:
    name = package_name_from_pkgfile(port_dir)
    base = name[:-3] if name.endswith("-32") else name
    if name in LARGE_BUILD_PACKAGE_NAMES or base in LARGE_BUILD_PACKAGE_NAMES:
        return True
    if any(base.startswith(prefix) for prefix in LARGE_BUILD_PREFIXES):
        return True
    # Kernel compilation is large even though the package names vary.
    return port_rel in {"core/linux", "core/linux-lts"}


def _pkgmk_conf_path_value(var: str, fallback: str) -> str:
    """Read a simple BFSOS pkgmk.conf path assignment without sourcing shell."""
    conf = Path("/etc/pkgmk.conf")
    if conf.is_file():
        rx = re.compile(rf"^\s*{re.escape(var)}\s*=\s*[\"']?([^\"'\n]+)")
        for line in conf.read_text(errors="replace").splitlines():
            m = rx.match(line)
            if not m:
                continue
            raw = m.group(1).strip()
            # BFSOS uses ${VAR:-/default/path} for the disk root. Extract only
            # the literal default; never evaluate arbitrary shell syntax.
            default_m = re.fullmatch(r"\$\{[A-Za-z_][A-Za-z0-9_]*:-([^}]+)\}", raw)
            if default_m:
                return default_m.group(1)
            if raw.startswith("/"):
                return raw
    return fallback


def build_work_roots() -> dict[str, Path]:
    """Return the effective BFSOS work roots used by pkgmk.conf."""
    tmpfs_root = _pkgmk_conf_path_value("PKGMK_TMPFS_WORK_ROOT", "/var/cache/pkg/build-work")
    disk_default = _pkgmk_conf_path_value("PKGMK_DISK_WORK_ROOT", "/var/cache/pkg/build-work-disk")
    disk_root = os.environ.get("PKGMK_DISK_WORK_ROOT", disk_default)
    return {"tmpfs": Path(tmpfs_root), "disk": Path(disk_root)}


def _existing_fs_probe(path: Path) -> Path:
    """Find an existing path on the same prospective filesystem for statvfs."""
    probe = path
    while not probe.exists() and probe != probe.parent:
        probe = probe.parent
    return probe


def _mount_fstype(path: Path) -> str:
    """Return the filesystem type for the longest matching mount point."""
    probe = _existing_fs_probe(path).resolve()
    best_len = -1
    best_type = "unknown"
    try:
        for raw in Path("/proc/self/mountinfo").read_text(errors="replace").splitlines():
            left, sep, right = raw.partition(" - ")
            if not sep:
                continue
            fields = left.split()
            rfields = right.split()
            if len(fields) < 5 or not rfields:
                continue
            mount = fields[4].replace("\040", " ")
            mp = Path(mount)
            try:
                probe.relative_to(mp)
            except ValueError:
                continue
            if len(str(mp)) > best_len:
                best_len = len(str(mp))
                best_type = rfields[0]
    except OSError:
        pass
    return best_type


def build_work_preflight(backend: str, min_bytes: int = 512 * 1024 * 1024) -> dict[str, object]:
    """Inspect the actual filesystem that will hold pkgmk build work."""
    root = build_work_roots()[backend]
    probe = _existing_fs_probe(root)
    st = os.statvfs(probe)
    free_bytes = st.f_bavail * st.f_frsize
    free_inodes = st.f_favail
    min_inodes = 1024
    fstype = _mount_fstype(probe)
    disk_is_ram = backend == "disk" and fstype in {"tmpfs", "ramfs"}
    ok = free_bytes >= min_bytes and free_inodes >= min_inodes and not disk_is_ram
    return {
        "backend": backend, "root": root, "probe": probe,
        "free_bytes": free_bytes, "free_inodes": free_inodes,
        "fstype": fstype, "disk_is_ram": disk_is_ram, "ok": ok,
    }


def _tmpfs_headroom_bytes() -> int:
    raw = os.environ.get("BFS_TMPFS_MIN_FREE_GIB", str(DEFAULT_TMPFS_HEADROOM_GIB))
    try:
        gib = max(1, int(raw))
    except ValueError:
        gib = DEFAULT_TMPFS_HEADROOM_GIB
    return gib * 1024**3


def select_build_work_backend(port_dir: Path, port_rel: str = "") -> tuple[str, str, dict[str, object]]:
    """Choose a safe backend before launching pkgmk."""
    pref = read_build_work_preference(port_dir)
    tmp = build_work_preflight("tmpfs")
    disk = build_work_preflight("disk")
    headroom = _tmpfs_headroom_bytes()
    large = is_known_large_build(port_dir, port_rel)

    def require_disk(reason: str):
        if disk.get("disk_is_ram"):
            raise OSError(f"disk build root resolves to {disk.get('fstype')}, not persistent storage")
        if not disk.get("ok"):
            raise OSError(
                f"disk build root unavailable/too full: root={disk['root']} "
                f"free={format_bytes(int(disk['free_bytes']))} inodes={disk['free_inodes']}"
            )
        return "disk", reason, disk

    if pref == "disk":
        return require_disk("explicit build_work=disk")
    if large:
        return require_disk("known-large package")
    if not tmp.get("ok") or int(tmp["free_bytes"]) < headroom:
        reason = (
            f"tmpfs insufficient headroom ({format_bytes(int(tmp['free_bytes']))} free; "
            f"need {format_bytes(headroom)})"
        )
        return require_disk(reason)
    if pref == "tmpfs":
        return "tmpfs", "explicit build_work=tmpfs", tmp
    return "tmpfs", "default tmpfs with sufficient headroom", tmp


def format_bytes(value: int) -> str:
    n = float(max(0, value))
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if n < 1024 or unit == "TiB":
            return f"{n:.1f}{unit}" if unit != "B" else f"{int(n)}B"
        n /= 1024
    return f"{int(value)}B"


def logical_cpu_count() -> int:
    return max(1, os.cpu_count() or 1)


def read_build_jobs(port_dir: Path, logical_cpus: int | None = None) -> tuple[int, str]:
    """Resolve effective package parallelism without sourcing arbitrary Pkgfile code."""
    logical = logical_cpus or logical_cpu_count()
    explicit = os.environ.get("BFS_BUILD_JOBS") or os.environ.get("JOBS")
    jobs = logical
    source = "default-all-cpus"
    if explicit:
        try:
            jobs = max(1, int(explicit))
            source = "user-override"
        except ValueError:
            pass

    pkgfile = port_dir / "Pkgfile"
    if pkgfile.is_file():
        m = re.search(r"(?m)^\s*build_jobs\s*=\s*[\"']?([0-9]+)[\"']?\s*(?:#.*)?$", pkgfile.read_text(errors="replace"))
        if m:
            cap = max(1, int(m.group(1)))
            if cap < jobs:
                jobs = cap
                source = "port-override"
    return jobs, source


def pkgmk_build_command(backend: str, jobs: int) -> list[str]:
    """Use bfs-pkgmk and carry effective build policy across sudo's env reset."""
    wrapper = shutil.which("bfs-pkgmk")
    tool = wrapper if wrapper else "pkgmk"
    return [
        "sudo", "env",
        f"BFS_PKG_BUILD_WORK={backend}",
        f"BFS_PKG_BUILD_JOBS={jobs}",
        f"JOBS={jobs}",
        f"MAKEFLAGS=-j{jobs}",
        f"CMAKE_BUILD_PARALLEL_LEVEL={jobs}",
        tool, "-d", "-kw",
    ]


def run_build_streaming(cmd: list[str], cwd: Path, log_path: Path, header: str) -> subprocess.CompletedProcess:
    """Tee build output live to the terminal and persistent per-port log."""
    log_path.parent.mkdir(parents=True, exist_ok=True)
    chunks: list[str] = []
    with log_path.open("w", encoding="utf-8") as log:
        log.write(header)
        log.flush()
        proc = subprocess.Popen(
            cmd, cwd=str(cwd), text=True, encoding="utf-8", errors="replace",
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, bufsize=1,
        )
        assert proc.stdout is not None
        for line in proc.stdout:
            print(line, end="", flush=True)
            log.write(line)
            log.flush()
            chunks.append(line)
        rc = proc.wait()
    return subprocess.CompletedProcess(cmd, rc, "".join(chunks), "")


def is_enospc_output(text: str) -> bool:
    low = text.lower()
    return (
        "no space left on device" in low
        or "enospc" in low
        or "errno 28" in low
        or "error 28" in low
    )


def read_port_dependencies(port_dir: Path) -> set[str]:
    """Read simple # Depends on: metadata used by BFSOS ports."""
    pkgfile = port_dir / "Pkgfile"
    if not pkgfile.is_file():
        return set()
    deps: set[str] = set()
    for line in pkgfile.read_text(errors="replace").splitlines():
        m = re.match(r"^\s*#\s*Depends on:\s*(.*)$", line, re.I)
        if m:
            deps.update(x for x in m.group(1).split() if x and x != "-")
    return deps


def order_candidates_for_build(cands, selected: set[str], ports_root: Path):
    """Stable topological order using BFSOS # Depends on metadata."""
    chosen = [c for c in cands if c.port in selected]
    by_name = {c.name: c for c in chosen}
    deps = {c.port: {by_name[d].port for d in read_port_dependencies(ports_root/c.port) if d in by_name} for c in chosen}
    ordered = []
    remaining = {c.port: c for c in chosen}
    while remaining:
        ready = [c for rel,c in remaining.items() if not (deps.get(rel,set()) & remaining.keys())]
        if not ready:
            ready = list(remaining.values())
        ready.sort(key=lambda c: (_build_rank(c.port), c.port))
        for c in ready:
            if c.port not in remaining:
                continue
            ordered.append(c)
            remaining.pop(c.port, None)
    unselected = [c for c in cands if c.port not in selected]
    return ordered + sorted(unselected, key=lambda c: (_build_rank(c.port), c.port))


def footprint_mismatch_lines(text: str) -> list[str]:
    lines=[]
    active=False
    for line in text.splitlines():
        if "ERROR: Footprint mismatch found:" in line:
            active=True
            continue
        if active:
            if re.match(r"^(MISSING|NEW|CHANGED)\s+", line):
                lines.append(line.rstrip())
                continue
            if lines and (line.startswith("=======>") or not line.strip()):
                break
    return lines

def _footprint_normalized_signature(line: str) -> str:
    # Version-only library payload changes are safe to refresh automatically.
    line = re.sub(r"^(MISSING|NEW)\s+", "", line)
    line = re.sub(r"(?<=\.)[0-9]+(?:\.[0-9]+)+", "<VER>", line)
    line = re.sub(r"(?<=so\.)[0-9]+(?:\.[0-9]+)*", "<SONAMEVER>", line)
    return line

def safe_versioned_library_footprint_change(text: str) -> tuple[bool, list[str]]:
    lines = footprint_mismatch_lines(text)
    if not lines or any(l.startswith("CHANGED") for l in lines):
        return False, lines
    missing=[l for l in lines if l.startswith("MISSING")]
    new=[l for l in lines if l.startswith("NEW")]
    if not missing or len(missing) != len(new):
        return False, lines
    # Be intentionally conservative: only shared-library files/symlinks under
    # lib/lib32 qualify for unattended refresh.
    if any(" usr/lib/" not in l and " usr/lib32/" not in l and " lib/" not in l for l in lines):
        return False, lines
    return sorted(map(_footprint_normalized_signature, missing)) == sorted(map(_footprint_normalized_signature, new)), lines

def pkgmk_footprint_package_command(backend: str, jobs: int) -> list[str]:
    cmd = pkgmk_build_command(backend, jobs)
    # The initial build stopped at footprint verification, so no package archive
    # exists yet.  Create one while ignoring only the already-reviewed footprint.
    return cmd[:-2] + ["-d", "-if", "-kw"]


def pkgmk_footprint_update_command(backend: str, jobs: int) -> list[str]:
    cmd = pkgmk_build_command(backend, jobs)
    # Once the reviewed package exists, regenerate .footprint from that archive.
    return cmd[:-2] + ["-d", "-uf", "-kw"]


def cleanup_successful_build_work(root: str | Path, package_name: str) -> tuple[bool, str]:
    """Remove exactly one successful pkgmk workspace, including root-owned trees.

    Builds run through sudo, so their work directories are normally root-owned.
    Cleanup therefore crosses the same privilege boundary, but only after strict
    validation that the target is an immediate pkgmk-$name child of one of the
    configured build-work roots. Cleanup failure is non-fatal to the updater.
    """
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9+_.-]*", package_name or ""):
        return False, "unsafe package name"
    try:
        base = Path(root).resolve()
        allowed = {p.resolve() for p in build_work_roots().values()}
    except Exception as exc:
        return False, f"could not resolve build-work root: {exc}"
    if base not in allowed:
        return False, f"refusing cleanup outside configured build-work roots: {base}"
    target = (base / f"pkgmk-{package_name}").resolve()
    if target.parent != base or target.name != f"pkgmk-{package_name}":
        return False, "unsafe build-work path"
    if not target.exists():
        return True, str(target)
    try:
        cp = subprocess.run(["sudo", "rm", "-rf", "--", str(target)], text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    except OSError as exc:
        return False, f"cleanup command failed to start: {exc}"
    if cp.returncode != 0:
        detail = cp.stderr.strip() or cp.stdout.strip() or f"sudo rm exited {cp.returncode}"
        return False, detail
    return True, str(target)


def rollback_failed_build_ports(selected: set[str], ports_root: Path, results: dict[str, str], backup_root: Path | None) -> None:
    """Restore pre-apply port state when validation never produced a package.

    A failed build must not leave the tree claiming a version that was never
    successfully packaged. Successful builds (including later install failures)
    remain applied so they can be retried without discarding verified port work.
    Infrastructure failures and workspace-blocked ports are also restored.
    """
    if backup_root is None:
        return
    try:
        rollback_prefixes = (
            "BUILD FAILED",
            "INFRASTRUCTURE FAILED:",
            "BLOCKED: build workspace out of space",
            "BLOCKED: build workspace preflight failed",
            "FOOTPRINT REVIEW:",
        )
        for rel in sorted(selected):
            result = results.get(rel, "")
            if not result.startswith(rollback_prefixes):
                continue
            saved = backup_root / rel
            current = ports_root / rel
            if not saved.is_dir():
                continue
            failed = result
            if current.exists():
                shutil.rmtree(current)
            current.parent.mkdir(parents=True, exist_ok=True)
            shutil.copytree(saved, current, symlinks=True)
            results[rel] = f"ROLLED BACK: {failed}"
    finally:
        shutil.rmtree(backup_root, ignore_errors=True)


def build_selected(cands, selected, ports_root: Path, install: bool, results):
    ordered = order_candidates_for_build(cands, selected, ports_root)
    failed_groups: set[str] = set()
    unstaged_groups: set[str] = set()
    enospc_abort = False

    # Build-only mode deliberately does not alter the live package database.
    # For version-locked SDK groups that means a later member cannot safely be
    # validated after an earlier prerequisite was rebuilt unless that new
    # prerequisite is installed or staged. Stop at that boundary instead of
    # reporting a misleading BUILD FAILED against the old installed SDK.
    selected_group_members = {
        g: [c.port for c in ordered if c.port in selected and c.port in members and results.get(c.port) == "UPDATED"]
        for g, members in VERSION_LOCK_GROUPS.items()
    }

    selected_by_name = {c.name: c for c in ordered if c.port in selected}

    for c in ordered:
        if c.port not in selected or results.get(c.port) != "UPDATED":
            continue
        if enospc_abort:
            results[c.port] = "BLOCKED: build workspace out of space after prior ENOSPC infrastructure failure"
            continue

        group = next((g for g, members in VERSION_LOCK_GROUPS.items() if c.port in members), "")
        if group and group in failed_groups:
            results[c.port] = f"BLOCKED: {group} prior genuine build/install failure"
            continue
        if group and group in unstaged_groups:
            results[c.port] = f"BLOCKED: {group} updated prerequisite built but not installed/staged"
            continue

        port_dir = ports_root/c.port

        # In build-only mode, never test a dependent against an older installed
        # prerequisite when the selected newer prerequisite was just built.
        if not install:
            stale=[]
            for dep in read_port_dependencies(port_dir):
                dc = selected_by_name.get(dep)
                if dc and str(results.get(dc.port, "")).startswith(("BUILT", "FOOTPRINT UPDATED")):
                    stale.append(dep)
            if stale:
                results[c.port] = "BLOCKED: updated prerequisite built but not installed/staged: " + ", ".join(sorted(stale))
                continue

        try:
            backend, backend_reason, preflight = select_build_work_backend(port_dir, c.port)
        except (ValueError, OSError) as exc:
            results[c.port] = f"BLOCKED: build workspace preflight failed: {exc}"
            continue

        root = preflight["root"]
        free_b = int(preflight["free_bytes"])
        free_i = int(preflight["free_inodes"])
        diag = (
            f"backend={backend} root={root} reason={backend_reason} "
            f"free={format_bytes(free_b)} inodes={free_i} fstype={preflight.get('fstype','unknown')}"
        )
        print(f"BUILD-WORK {c.port}: {diag}")
        if not preflight["ok"]:
            results[c.port] = f"BLOCKED: build workspace preflight failed: effectively full; {diag}"
            continue

        logical = logical_cpu_count()
        jobs, jobs_source = read_build_jobs(port_dir, logical)
        cpu_diag = f"logical_cpus={logical} jobs={jobs} source={jobs_source}"
        print(f"BUILD-CPU {c.port}: {cpu_diag}", flush=True)
        print(f"BUILDING {c.port} ({c.name})", flush=True)

        # Use bfs-pkgmk when available so the updater follows the same ABI,
        # build-work, payload-validation, history, and parallel-build policy as
        # normal BFSOS package builds.  Tee output while the build runs so the
        # UI and the persistent log never go visually silent for long builds.
        log_stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
        safe_port = c.port.replace("/", "-")
        build_log = LOG_ROOT / f"build-{log_stamp}-{safe_port}.log"
        header = f"# BFSOS build-work: {diag}\n# BFSOS build-cpu: {cpu_diag}\n"
        cp = run_build_streaming(pkgmk_build_command(backend, jobs), port_dir, build_log, header)
        combined = cp.stdout or ""
        if cp.returncode and "ERROR: Footprint mismatch found:" in combined:
            safe_fp, fp_lines = safe_versioned_library_footprint_change(combined)
            print(f"FOOTPRINT CHANGED {c.port}: {len(fp_lines)} mismatch rows", flush=True)
            for line in fp_lines:
                print(f"  {line}", flush=True)
            if safe_fp:
                fp_log = LOG_ROOT / f"footprint-{log_stamp}-{safe_port}.log"
                fp_header = header + "# BFSOS maintainer footprint refresh: safe versioned-library change\n"
                pkg_cp = run_build_streaming(pkgmk_footprint_package_command(backend, jobs), port_dir, fp_log, fp_header)
                if pkg_cp.returncode != 0:
                    results[c.port] = f"FOOTPRINT REVIEW: reviewed package pass failed ({pkg_cp.returncode}); log={fp_log}"
                    if group:
                        failed_groups.add(group)
                    continue
                fp_cp = run_build_streaming(pkgmk_footprint_update_command(backend, jobs), port_dir, fp_log, fp_header)
                if fp_cp.returncode == 0:
                    combined = fp_cp.stdout or ""
                    cp = fp_cp
                    results[c.port] = "BUILT; FOOTPRINT UPDATED"
                else:
                    results[c.port] = f"FOOTPRINT REVIEW: automatic refresh failed ({fp_cp.returncode}); log={fp_log}"
                    if group:
                        failed_groups.add(group)
                    continue
            else:
                results[c.port] = f"FOOTPRINT REVIEW: payload changed beyond safe versioned-library refresh; log={build_log}"
                if group:
                    failed_groups.add(group)
                continue

        if cp.returncode:
            suffix = "; obsolete patches retained" if c.obsolete_patches else ""
            if is_enospc_output(combined):
                results[c.port] = (
                    f"INFRASTRUCTURE FAILED: build workspace out of space; "
                    f"{diag}; log={build_log}{suffix}"
                )
                enospc_abort = True
            else:
                results[c.port] = f"BUILD FAILED ({cp.returncode}); log={build_log}{suffix}"
                if group:
                    failed_groups.add(group)
            continue

        if not str(results.get(c.port, "")).startswith("BUILT; FOOTPRINT UPDATED"):
            results[c.port] = "BUILT"
        if install:
            cp2 = run(["sudo","prt-get","-fr","depinst",c.name])
            if cp2.returncode:
                suffix = "; obsolete patches retained" if c.obsolete_patches else ""
                results[c.port] = f"BUILT; INSTALL FAILED ({cp2.returncode}){suffix}"
                if group:
                    failed_groups.add(group)
                continue
            results[c.port] = "BUILT+INSTALLED" + ("; FOOTPRINT UPDATED" if "FOOTPRINT UPDATED" in str(results.get(c.port, "")) else "")
        elif group and group in GROUP_BUILD_REQUIRES_INSTALLED_PREREQ:
            members = selected_group_members.get(group, [])
            try:
                idx = members.index(c.port)
            except ValueError:
                idx = -1
            if idx >= 0 and idx < len(members) - 1:
                unstaged_groups.add(group)

        ok_cleanup, cleanup_detail = cleanup_successful_build_work(root, c.name)
        if ok_cleanup:
            print(f"BUILD-WORK CLEANUP {c.port}: {cleanup_detail}", flush=True)
        else:
            print(f"BUILD-WORK CLEANUP WARNING {c.port}: {cleanup_detail}", flush=True)

        for name in c.obsolete_patches:
            p = port_dir/name
            if p.is_file():
                p.unlink()
    return results


def print_report(cands):
    if not cands: print("No candidate updates found."); return
    print(f"{'PORT':36} {'OLD':14} {'NEW':14} {'REL':9} {'STATUS':10} POLICY/SOURCE")
    for c in cands:
        print(f"{c.port[:36]:36} {c.old[:14]:14} {c.new[:14]:14} {c.old_release+'>'+c.new_release:9} {c.status[:10]:10} {c.source_label}")
        print(f"  {c.reason}")
        if c.patches: print("  patches: "+", ".join(p.filename for p in c.patches))
        if c.obsolete_patches: print("  obsolete after verification: "+", ".join(c.obsolete_patches))


def scan(ports_root, trees, jobs, timeout, stamp):
    LOG_ROOT.mkdir(parents=True,exist_ok=True); audit=LOG_ROOT/f"upstream-{stamp}.tsv"
    base_metas=discover_ports(ports_root,trees)
    metas, extras = expand_coordinated_metas(ports_root, base_metas)
    indexes,patches,warnings=load_references(timeout)
    upstream=run_upstream_audit(ports_root,trees,jobs,timeout,audit)
    if extras:
        extra_trees=sorted({m.rel.split("/",1)[0] for m in extras})
        extra_audit=LOG_ROOT/f"upstream-{stamp}-coordinated.tsv"
        extra_rows=run_upstream_audit(ports_root,extra_trees,jobs,timeout,extra_audit,[m.name for m in extras])
        upstream.update(extra_rows)
    problem_report = LOG_ROOT / f"problems-{stamp}.tsv"
    unverifiable_count, fetch_error_count = write_problem_report(problem_report, upstream)
    print(f"Problem report: {problem_report} (UNVERIFIABLE={unverifiable_count} FETCH-ERROR={fetch_error_count})")
    diagnostics: list[str] = [
        f"problem-report\t{problem_report}\tUNVERIFIABLE={unverifiable_count}\tFETCH-ERROR={fetch_error_count}"
    ]
    if extras:
        diagnostics.append("coordinated scan expanded to: " + ", ".join(m.rel for m in extras))
    fallback_refs = prefetch_fallback_references(metas,indexes,timeout,jobs,diagnostics)
    cands = make_candidates(metas,indexes,patches,upstream,timeout,diagnostics,fallback_refs)
    return cands,warnings,diagnostics


def scan_kernel_only(ports_root, trees, jobs, timeout, stamp):
    """Fast BFSOS kernel-policy scan.

    Only linux/linux-lts are queried upstream. linux-headers is deliberately not
    passed to generic discovery: its target is derived exclusively from the
    selected BFSOS linux-lts target in make_candidates().
    """
    LOG_ROOT.mkdir(parents=True,exist_ok=True); audit=LOG_ROOT/f"upstream-{stamp}.tsv"
    metas=[m for m in discover_ports(ports_root,trees) if m.name in KERNEL_PORTS]
    upstream_names=[m.name for m in metas if m.name in {"linux", "linux-lts"}]
    upstream=run_upstream_audit(ports_root,trees,jobs,timeout,audit,upstream_names)
    problem_report = LOG_ROOT / f"problems-{stamp}.tsv"
    unverifiable_count, fetch_error_count = write_problem_report(problem_report, upstream)
    print(f"Problem report: {problem_report} (UNVERIFIABLE={unverifiable_count} FETCH-ERROR={fetch_error_count})")
    diagnostics=[f"problem-report\t{problem_report}\tUNVERIFIABLE={unverifiable_count}\tFETCH-ERROR={fetch_error_count}",
                 "kernel-only: generic upstream scan restricted to linux and linux-lts",
                 "kernel-only: linux-headers target follows linux-lts only"]
    cands=make_candidates(metas,{k:{} for k,_,_ in BOOKS},[],upstream,timeout,diagnostics)
    return cands,[],diagnostics

def main():
    ap=argparse.ArgumentParser(description="BFSOS Dialog-driven maintainer port updater")
    ap.add_argument("--ports-root",type=Path,default=DEFAULT_PORTS_ROOT)
    ap.add_argument("--trees",nargs="*",help="collections to scan")
    ap.add_argument("--list-trees",action="store_true")
    ap.add_argument("--kernel-only",action="store_true",help="scan only the tree containing BFSOS kernel ports, then show kernel candidates")
    ap.add_argument("--report-only",action="store_true")
    ap.add_argument("--apply",action="store_true",help="apply safe policy-approved candidates (noninteractive)")
    ap.add_argument("--build",action="store_true",help="with --apply, build selected ports using sudo pkgmk -d -kw")
    ap.add_argument("--install",action="store_true",help="with --apply --build, install through prt-get after build")
    ap.add_argument("--jobs",type=int,default=int(os.environ.get("BFS_AUDIT_JOBS","10")))
    ap.add_argument("--timeout",type=int,default=int(os.environ.get("BFS_AUDIT_TIMEOUT","15")))
    ap.add_argument("--set-distro-version", metavar="VERSION", help="set BFSOS distro release across active consumers and exit")
    ns=ap.parse_args()
    if ns.set_distro_version:
        try:
            changed = apply_distro_version(ROOT, ns.set_distro_version)
        except (OSError, RuntimeError, ValueError) as exc:
            die(f"distro version update failed: {exc}")
        if changed:
            print(f"BFSOS distro version set to {ns.set_distro_version}")
            for rel in changed:
                print(f"  updated: {rel}")
        else:
            print(f"BFSOS distro version already {ns.set_distro_version}")
        return 0
    ports_root=ns.ports_root.expanduser().resolve(); trees=discover_trees(ports_root)
    if ns.list_trees:
        for t in trees: print(f"{t.name}\t{port_count(t)}")
        return 0

    available={t.name for t in trees}
    interactive=not(ns.report_only or ns.apply or ns.trees or ns.kernel_only) and dialog_available()

    # Non-interactive path remains one-shot and script-friendly.
    if not interactive:
        chosen=ns.trees[:] if ns.trees else []
        if ns.kernel_only:
            chosen=[t.name for t in trees if any((t/p/"Pkgfile").is_file() for p in KERNEL_PORTS)]
        elif not chosen:
            chosen=sorted(available)
        bad=sorted(set(chosen)-available)
        if bad: die("unknown port tree(s): "+", ".join(bad))
        if not chosen: print("No port trees selected."); return 0
        stamp=dt.datetime.now().strftime("%Y%m%d-%H%M%S")
        if ns.kernel_only:
            cands,warnings,diagnostics=scan_kernel_only(ports_root,chosen,ns.jobs,ns.timeout,stamp)
        else:
            cands,warnings,diagnostics=scan(ports_root,chosen,ns.jobs,ns.timeout,stamp)
        for w in warnings: print(f"WARN: {w}",file=sys.stderr)
        print_report(cands)
        selected={c.port for c in cands if ns.apply and c.selected and c.status=="UPDATE"}
        build_backup = snapshot_selected_ports(selected, ports_root) if ns.apply and ns.build else None
        results=apply_selected(cands,selected,ports_root,ns.timeout) if ns.apply else {}
        if ns.apply and ns.build:
            build_selected(cands,selected,ports_root,ns.install,results)
            rollback_failed_build_ports(selected, ports_root, results, build_backup)
        log=LOG_ROOT/f"scan-{stamp}.tsv"
        write_scan_log(log,cands,selected,results,warnings,diagnostics,ports_root)
        print(f"Report: {log}")
        for k,v in sorted(results.items()): print(f"{k}: {v}")
        return 1 if any(any(mark in v for mark in ("FAILED", "NEEDS REVIEW", "BLOCKED:", "ROLLED BACK:")) for v in results.values()) else 0

    # Interactive mode is a persistent main menu.  Completing a scan, finding
    # zero updates, cancelling a sub-menu, or retrying failures all return here.
    with tempfile.TemporaryDirectory(prefix="bfs-port-updater-ui-") as td_s:
        env=dict(os.environ)
        rc=Path(td_s)/"dialogrc"; slackware_dialogrc(rc); env["DIALOGRC"]=str(rc)
        while True:
            retry_log,retry_rows=find_retryable_failures(ports_root)
            action=choose_action_dialog(env,len(retry_rows))
            exit_tag="6" if retry_rows else "5"
            if action==exit_tag:
                return 0

            chosen=[]
            kernel_only=False
            if action=="1":
                chosen=sorted(available)
            elif action=="2":
                picked=choose_trees_dialog(trees,env)
                if picked is None:
                    continue
                if not picked:
                    dcall(["--title","Select port trees","--msgbox",
                           "No port trees selected. Nothing was scanned.","8","58"],env)
                    continue
                chosen=picked
            elif action=="3":
                chosen=[t.name for t in trees if any((t/p/"Pkgfile").is_file() for p in KERNEL_PORTS)]
                kernel_only=True
            elif action=="4":
                requested=choose_distro_version_dialog(env)
                if requested is None:
                    continue
                try:
                    changed=apply_distro_version(ROOT,requested)
                except (OSError,RuntimeError,ValueError) as exc:
                    dcall(["--title","BFSOS distro version","--msgbox",f"Version update failed:\n\n{exc}","12","88"],env)
                    continue
                body=(f"BFSOS distro version is now {requested}.\n\n" +
                      ("Updated:\n" + "\n".join(changed) if changed else "No files changed; that version was already active."))
                dcall(["--title","BFSOS distro version","--msgbox",body,"24","100"],env)
                continue
            elif action=="5" and retry_rows:
                picked=choose_retry_dialog(retry_rows,env)
                if picked is None or not picked:
                    continue
                results=retry_failed_updates(retry_rows,set(picked),ports_root)
                retry_state=write_retry_state_log(retry_rows,results,ports_root)
                source=f"\n\nSource log: {retry_log}" if retry_log else ""
                state=f"\nRetry state: {retry_state}" if retry_state else ""
                body="\n".join(f"{k}: {v}" for k,v in sorted(results.items())) or "No retries run."
                dcall(["--title","Retry results","--msgbox",body+source+state,"29","110"],env)
                continue
            else:
                continue

            bad=sorted(set(chosen)-available)
            if bad:
                dcall(["--title","Port update scan","--msgbox",
                       "Unknown port tree(s): "+", ".join(bad),"9","70"],env)
                continue
            if not chosen:
                dcall(["--title","Port update scan","--msgbox","No port trees selected.","8","60"],env)
                continue

            stamp=dt.datetime.now().strftime("%Y%m%d-%H%M%S")
            if kernel_only:
                cands,warnings,diagnostics=scan_kernel_only(ports_root,chosen,ns.jobs,ns.timeout,stamp)
            else:
                cands,warnings,diagnostics=scan(ports_root,chosen,ns.jobs,ns.timeout,stamp)
            for w in warnings: print(f"WARN: {w}",file=sys.stderr)
            if not cands:
                # Critical UI rule: zero results is completion, not Exit.
                log=LOG_ROOT/f"scan-{stamp}.tsv"
                write_scan_log(log,[],set(),{},warnings,diagnostics,ports_root)
                dcall(["--title","Port update scan","--msgbox","No candidate updates were found.\n\nReturning to the main menu.","10","64"],env)
                continue

            picked=choose_updates_dialog(cands,env)
            if picked is None:
                continue
            selected=set(picked)
            dcall(["--title","Update plan","--msgbox",detail_text(cands,selected),"31","125"],env)
            headers=any(c.name=="linux-headers" and c.port in selected for c in cands)
            summary=f"Updates found: {len(cands)}\nSelected: {len(selected)}\nSkipped: {len(cands)-len(selected)}\nReview items: {sum(c.status=='REVIEW' for c in cands)}\nDependent glibc release bump: {'yes' if headers else 'no'}"
            code,mode=dcall(["--title","Apply mode","--menu",summary+"\n\nChoose how far to continue.","20","82","4",
                             "1","Update files only","2","Update + build selected","3","Update + build + install selected","4","Cancel"],env)
            if code or mode=="4":
                write_scan_log(LOG_ROOT/f"scan-{stamp}.tsv",cands,selected,{},warnings,diagnostics,ports_root)
                continue
            code,_=dcall(["--title","Final confirmation","--yes-label","Apply Selected","--no-label","Cancel","--defaultno","--yesno",
                          summary+"\n\nOnly checked items will be modified. Checked REVIEW items are explicit maintainer overrides. Continue?","17","88"],env)
            if code:
                continue
            build_backup = snapshot_selected_ports(selected, ports_root) if mode in {"2","3"} else None
            results=apply_selected(cands,selected,ports_root,ns.timeout)
            if mode in {"2","3"}:
                build_selected(cands,selected,ports_root,mode=="3",results)
                rollback_failed_build_ports(selected, ports_root, results, build_backup)
            log=LOG_ROOT/f"scan-{stamp}.tsv"
            write_scan_log(log,cands,selected,results,warnings,diagnostics,ports_root)
            text="\n".join(f"{k}: {v}" for k,v in sorted(results.items())) or "No updates applied."
            dcall(["--title","Update results","--msgbox",text+f"\n\nLog: {log}\n\nReturning to the main menu.","29","110"],env)

if __name__=="__main__": raise SystemExit(main())
