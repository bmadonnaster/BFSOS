# BFSOS `ports/core` audit — r106 kickoff

Date: 2026-08-19

## Audit policy

- Primary multilib/toolchain/build-method reference: **current MLFS development**.
- Current package release/security/build requirements: **authoritative upstream project**.
- Additional distro/package-layout comparison: **current CRUX core/opt as applicable**.
- Ordinary LFS/BLFS development: secondary cross-check, not the primary BFSOS multilib authority.
- A version difference is not automatically a bug. Preserve deliberate BFSOS choices and record why.
- Kernel policy: tracking a newer upstream stable point release is acceptable; advancing API headers beyond the MLFS-tested set requires a clean Bootstrap/toolchain/base regression.

## Static tree checks

- `ports/core` Pkgfiles inspected: **198**.
- `bash -n` Pkgfile syntax failures: **0**.
- Missing `name=`, `version=`, `release=`, or `source=` metadata: **0**.
- Removed two accidental template-placeholder comment lines from **151** core Pkgfiles. This is comment-only cleanup.
- `aaa_filesystem/group` is clean in the supplied tree: the accidental duplicate `root`/`bin` records found during the preceding install test are no longer present.

## Live MLFS-development version cross-check — first pass

The first pass maps **78** BFSOS core packages directly to packages/versioned components on the live MLFS development package list. **All 78 mapped versions match exactly.** Version equality does not complete the audit; build flags, patches, multilib details, installed files, footprints, and dependencies still require review.

| BFSOS port | BFSOS | MLFS dev | Result |
|---|---:|---:|---|
| `acl` | 2.4.0 | 2.4.0 | MATCH |
| `attr` | 2.6.0 | 2.6.0 | MATCH |
| `autoconf` | 2.73 | 2.73 | MATCH |
| `automake` | 1.18.1 | 1.18.1 | MATCH |
| `bash` | 5.3 | 5.3 | MATCH |
| `bc` | 7.0.3 | 7.0.3 | MATCH |
| `binutils` | 2.47 | 2.47 | MATCH |
| `bison` | 3.8.2 | 3.8.2 | MATCH |
| `bzip2` | 1.0.8 | 1.0.8 | MATCH |
| `coreutils` | 9.11 | 9.11 | MATCH |
| `dbus` | 1.16.2 | 1.16.2 | MATCH |
| `diffutils` | 3.12 | 3.12 | MATCH |
| `e2fsprogs` | 1.47.4 | 1.47.4 | MATCH |
| `elfutils` | 0.195 | 0.195 | MATCH |
| `expat` | 2.8.3 | 2.8.3 | MATCH |
| `file` | 5.48 | 5.48 | MATCH |
| `findutils` | 4.11.0 | 4.11.0 | MATCH |
| `flex` | 2.6.4 | 2.6.4 | MATCH |
| `gawk` | 5.4.1 | 5.4.1 | MATCH |
| `gcc` | 16.2.0 | 16.2.0 | MATCH |
| `gdbm` | 1.26 | 1.26 | MATCH |
| `gettext` | 1.0 | 1.0 | MATCH |
| `glibc` | 2.44 | 2.44 | MATCH |
| `gmp` | 6.3.0 | 6.3.0 | MATCH |
| `gperf` | 3.3 | 3.3 | MATCH |
| `grep` | 3.12 | 3.12 | MATCH |
| `groff` | 1.24.1 | 1.24.1 | MATCH |
| `grub` | 2.14 | 2.14 | MATCH |
| `gzip` | 1.14 | 1.14 | MATCH |
| `iana-etc` | 20260805 | 20260805 | MATCH |
| `inetutils` | 2.8 | 2.8 | MATCH |
| `iproute2` | 7.1.0 | 7.1.0 | MATCH |
| `kbd` | 2.10.0 | 2.10.0 | MATCH |
| `kmod` | 34.2 | 34.2 | MATCH |
| `less` | 704 | 704 | MATCH |
| `libcap` | 2.78 | 2.78 | MATCH |
| `libffi` | 3.8.0 | 3.8.0 | MATCH |
| `libpipeline` | 1.5.8 | 1.5.8 | MATCH |
| `libtool` | 2.6.2 | 2.6.2 | MATCH |
| `libxcrypt` | 4.5.2 | 4.5.2 | MATCH |
| `linux` | 7.1.8 | 7.1.8 | MATCH |
| `linux-api-headers` | 7.1.8 | 7.1.8 | MATCH |
| `linux-headers` | 7.1.8 | 7.1.8 | MATCH |
| `lz4` | 1.10.0 | 1.10.0 | MATCH |
| `m4` | 1.4.21 | 1.4.21 | MATCH |
| `make` | 4.4.1 | 4.4.1 | MATCH |
| `man-db` | 2.13.1 | 2.13.1 | MATCH |
| `man-pages` | 6.18 | 6.18 | MATCH |
| `meson` | 1.12.0 | 1.12.0 | MATCH |
| `mpc` | 1.4.1 | 1.4.1 | MATCH |
| `mpdecimal` | 4.0.1 | 4.0.1 | MATCH |
| `mpfr` | 4.2.2 | 4.2.2 | MATCH |
| `ncurses` | 6.6 | 6.6 | MATCH |
| `ninja` | 1.13.2 | 1.13.2 | MATCH |
| `openssl` | 4.0.1 | 4.0.1 | MATCH |
| `patch` | 2.8 | 2.8 | MATCH |
| `pkgconf` | 3.0.5 | 3.0.5 | MATCH |
| `procps-ng` | 4.0.7 | 4.0.7 | MATCH |
| `psmisc` | 23.7 | 23.7 | MATCH |
| `python3` | 3.14.7 | 3.14.7 | MATCH |
| `python3-flit-core` | 4.0.2 | 4.0.2 | MATCH |
| `python3-markupsafe` | 3.0.3 | 3.0.3 | MATCH |
| `python3-packaging` | 26.3 | 26.3 | MATCH |
| `python3-setuptools` | 84.0.0 | 84.0.0 | MATCH |
| `python3-wheel` | 0.48.0 | 0.48.0 | MATCH |
| `readline` | 8.3 | 8.3 | MATCH |
| `sed` | 4.10 | 4.10 | MATCH |
| `shadow` | 4.20.2 | 4.20.2 | MATCH |
| `sqlite` | 3.53.4 | 3.53.4 | MATCH |
| `systemd` | 261.2 | 261.2 | MATCH |
| `tar` | 1.35 | 1.35 | MATCH |
| `texinfo` | 7.3 | 7.3 | MATCH |
| `tzdata` | 2026c | 2026c | MATCH |
| `util-linux` | 2.42.2 | 2.42.2 | MATCH |
| `vim` | 9.2.0954 | 9.2.0954 | MATCH |
| `xz` | 5.8.3 | 5.8.3 | MATCH |
| `zlib` | 1.3.2 | 1.3.2 | MATCH |
| `zstd` | 1.5.7 | 1.5.7 | MATCH |

## Current MLFS required-patch cross-check

Applicable current MLFS required patches were checked against BFSOS:

- **bzip2 1.0.8 install_docs** — BFSOS already vendors the patch; r106 changes the Pkgfile to use that local copy directly.
- **coreutils 9.11 i18n** — BFSOS already applies it; r106 changes the source URL to the current canonical LFS patches/downloads location.
- **glibc 2.44 upstream_fix + FHS** — both are already vendored and applied.
- **kbd 2.10.0 backspace** — already vendored and applied.
- **Python 3.14.7 OpenSSL 4** — already applied; r106 changes the source URL to the current canonical LFS patches/downloads location.
- **tar 1.35 ACL fix** — already vendored and applied.
- MLFS-required Expect/OpenRC patches are not applicable to the current BFSOS core package set.

## CRUX package-management sanity cross-check

- `prt-get`: BFSOS **5.19.9**, current CRUX **5.19.9**. BFSOS release differs because of local integration/package revisions.
- `pkgutils`: BFSOS **5.40.12**, current CRUX **5.40.12**. BFSOS release 13 intentionally carries local pkgmk/cache/locale/timing extensions.
- `prt-utils`: BFSOS **1.3.7**, current CRUX opt **1.3.7**. BFSOS intentionally vendors the known-good source tarball because the Git archive endpoint caused non-browser/package-fetch failures.
- `ports`: BFSOS **1.6**, current CRUX **1.6**. Release/config content differs by BFSOS repository/driver policy.
- CRUX Python is intentionally not a version authority for BFSOS: current CRUX 3.8 core remains on Python 3.12.x while BFSOS follows the current MLFS/upstream 3.14.x line.

## `prt-utils` 1.3.7 review

The vendored `CHANGES` file was reviewed. 1.3.7 contains maintenance/tooling changes (Markdown output in `portspage`, safer Pkgfile sourcing in `dllist`, repo labeling in `prtcheckperms`, Cargo templates in `prtcreate`, `prtverify` whitelist updates, and man-page consolidation). No additional runtime service/configuration dependency was identified. `/etc/revdep.d` remains expected and the BFSOS port creates it.

## Changes applied in this audit kickoff

- Installer r53 implements the newest System Settings/account/LVM/timing tracker work.
- `pkgutils` release bumped 12 -> 13 for human-readable `bfs-pkgmk` timing output.
- Canonicalized current LFS patch locations for coreutils/Python; bzip2 now uses its already-vendored patch.
- Removed placeholder comments from 151 core Pkgfiles.
- Removed accidental placeholder comments from the `prt-utils` Pkgfile.

## Still open before item 104 can be called complete

- Compare build instructions/flags for every MLFS-overlap package against the corresponding current MLFS chapter, not only version numbers.
- Review all BFSOS-only core packages against authoritative upstream and, where useful, CRUX/BLFS.
- Audit dependencies, services/config files, symlinks, permissions, and package footprints.
- Check current upstream security/maintenance releases for packages not governed by MLFS version selection.
- Run a clean Bootstrap stages 1/2/3, verification, base archive creation, fresh installer cycle, and boot regression after the controlled audit changes.

