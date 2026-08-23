# BFSOS `ports/core` audit — r138 full-tree static pass

Date: 2026-08-22

## Scope and result

- Real core ports with a `Pkgfile`: **198**.
- `bash -n` syntax failures: **0**.
- Missing required `name`, `version`, or `release` metadata: **0**.
- Directory/package-name mismatches: **0**.
- Python package naming scan: no remaining `python`/Python-2-style package names; Python modules use the BFSOS `python3-*` convention.
- Existing live MLFS-development mapping: **78/78 directly mapped packages match the MLFS development versions** from the prior r106 audit; the current MLFS development package list was rechecked for the major toolchain/base versions.
- This is a **static/source-tree audit**, not a claim that 198 packages were all rebuilt and runtime-tested. Build/footprint/service behavior remains regression-pending where noted.

## Changes made in this pass

- `linux-lts`: 6.12.101 -> **6.18.45**, upstream longterm line; removed the 6.12-only MD diagnostic patch and obsolete GCC compatibility patch from the active port.
- `pkgutils`: release **14**; packaged source/package/work cache settings are active and the work directory is per-package.
- `python3-numpy`: removed stale duplicate `meson-python` dependency alias; retained actual `python3-meson_python`.
- Installer r61: dual console order corrected to serial first and `tty0` last.
- Bootstrap r62: keeps newest-installer-by-mtime selection and renders verification PASS in bold white.

## Items requiring live or deeper upstream review

- `python3-pyyaml` declares `libyaml` and `python3-cython`, neither of which currently exists in the supplied ports tree under those names. Verify whether these are required build dependencies, optional acceleration dependencies, or stale metadata before adding/removing ports.
- Source URL availability and newest-security-release checks for BFSOS-only packages should be periodically re-run against authoritative upstreams; version equality with MLFS is not sufficient for those packages.
- Run clean Bootstrap 1/2/3/4, package/footprint verification, fresh install, and boot tests before closing tracker item 104.

## Package-by-package static inventory

| Port | Version | Release | Bash syntax | Audit note |
|---|---:|---:|---|---|
| `aaa_filesystem` | 1 | 6 | PASS | static metadata/syntax OK |
| `acl` | 2.4.0 | 2 | PASS | static metadata/syntax OK |
| `attr` | 2.6.0 | 1 | PASS | static metadata/syntax OK |
| `autoconf` | 2.73 | 1 | PASS | static metadata/syntax OK |
| `automake` | 1.18.1 | 1 | PASS | static metadata/syntax OK |
| `bash` | 5.3 | 1 | PASS | static metadata/syntax OK |
| `bc` | 7.0.3 | 1 | PASS | static metadata/syntax OK |
| `binutils` | 2.47 | 1 | PASS | static metadata/syntax OK |
| `bison` | 3.8.2 | 1 | PASS | static metadata/syntax OK |
| `btrfs-progs` | 7.1 | 1 | PASS | static metadata/syntax OK |
| `bzip2` | 1.0.8 | 1 | PASS | static metadata/syntax OK |
| `ca-certificates` | 20260716 | 3 | PASS | static metadata/syntax OK |
| `ccache` | 4.13.6 | 1 | PASS | static metadata/syntax OK |
| `check` | 0.15.2 | 1 | PASS | static metadata/syntax OK |
| `cmake` | 4.4.2 | 1 | PASS | static metadata/syntax OK |
| `coreutils` | 9.11 | 1 | PASS | static metadata/syntax OK |
| `cracklib` | 2.9.11 | 1 | PASS | static metadata/syntax OK |
| `curl` | 8.21.0 | 1 | PASS | static metadata/syntax OK |
| `dash` | 0.5.13 | 1 | PASS | static metadata/syntax OK |
| `dbus` | 1.16.2 | 2 | PASS | static metadata/syntax OK |
| `dialog` | 1.3-20260107 | 1 | PASS | static metadata/syntax OK |
| `diffutils` | 3.12 | 1 | PASS | static metadata/syntax OK |
| `dosfstools` | 4.2 | 1 | PASS | static metadata/syntax OK |
| `dracut` | 111 | 3 | PASS | static metadata/syntax OK |
| `e2fsprogs` | 1.47.4 | 2 | PASS | static metadata/syntax OK |
| `efibootmgr` | 18 | 2 | PASS | static metadata/syntax OK |
| `efivar` | 39 | 2 | PASS | static metadata/syntax OK |
| `elfutils` | 0.195 | 2 | PASS | static metadata/syntax OK |
| `exfatprogs` | 1.4.2 | 1 | PASS | static metadata/syntax OK |
| `expat` | 2.8.3 | 1 | PASS | static metadata/syntax OK |
| `f2fs-tools` | 1.16.0 | 1 | PASS | static metadata/syntax OK |
| `fakeroot` | 1.37.1.1 | 1 | PASS | static metadata/syntax OK |
| `file` | 5.48 | 1 | PASS | static metadata/syntax OK |
| `findutils` | 4.11.0 | 1 | PASS | static metadata/syntax OK |
| `flex` | 2.6.4 | 1 | PASS | static metadata/syntax OK |
| `fmt` | 12.2.0 | 1 | PASS | static metadata/syntax OK |
| `freetype` | 2.14.3 | 1 | PASS | static metadata/syntax OK |
| `fuse` | 3.18.2 | 1 | PASS | static metadata/syntax OK |
| `gawk` | 5.4.1 | 1 | PASS | static metadata/syntax OK |
| `gcc` | 16.2.0 | 2 | PASS | static metadata/syntax OK |
| `gdbm` | 1.26 | 1 | PASS | static metadata/syntax OK |
| `genfstab` | 1.0 | 1 | PASS | static metadata/syntax OK |
| `gettext` | 1.0 | 1 | PASS | static metadata/syntax OK |
| `glibc` | 2.44 | 1 | PASS | static metadata/syntax OK |
| `gmp` | 6.3.0 | 1 | PASS | static metadata/syntax OK |
| `gperf` | 3.3 | 1 | PASS | static metadata/syntax OK |
| `gptfdisk` | 1.0.10 | 1 | PASS | static metadata/syntax OK |
| `grep` | 3.12 | 1 | PASS | static metadata/syntax OK |
| `groff` | 1.24.1 | 1 | PASS | static metadata/syntax OK |
| `grub` | 2.14 | 2 | PASS | static metadata/syntax OK |
| `grub-efi` | 2.14 | 1 | PASS | static metadata/syntax OK |
| `gzip` | 1.14 | 1 | PASS | static metadata/syntax OK |
| `httpup` | 0.5.1 | 1 | PASS | static metadata/syntax OK |
| `iana-etc` | 20260805 | 1 | PASS | static metadata/syntax OK |
| `inetutils` | 2.8 | 1 | PASS | static metadata/syntax OK |
| `inih` | 62 | 1 | PASS | static metadata/syntax OK |
| `intltool` | 0.51.0 | 1 | PASS | static metadata/syntax OK |
| `iproute2` | 7.1.0 | 1 | PASS | static metadata/syntax OK |
| `iptables` | 1.8.13 | 1 | PASS | static metadata/syntax OK |
| `kbd` | 2.10.0 | 1 | PASS | static metadata/syntax OK |
| `kmod` | 34.2 | 1 | PASS | static metadata/syntax OK |
| `less` | 704 | 1 | PASS | static metadata/syntax OK |
| `libaio` | 0.3.113 | 2 | PASS | static metadata/syntax OK |
| `libarchive` | 3.8.8 | 1 | PASS | static metadata/syntax OK |
| `libcap` | 2.78 | 1 | PASS | static metadata/syntax OK |
| `libevent` | 2.1.12 | 1 | PASS | static metadata/syntax OK |
| `libffi` | 3.8.0 | 1 | PASS | static metadata/syntax OK |
| `libmnl` | 1.0.5 | 1 | PASS | static metadata/syntax OK |
| `libnftnl` | 1.3.1 | 1 | PASS | static metadata/syntax OK |
| `libnl` | 3.11.0 | 1 | PASS | static metadata/syntax OK |
| `libnsl` | 2.0.1 | 1 | PASS | static metadata/syntax OK |
| `libpipeline` | 1.5.8 | 1 | PASS | static metadata/syntax OK |
| `libpng` | 1.6.58 | 1 | PASS | static metadata/syntax OK |
| `libtirpc` | 1.3.7 | 1 | PASS | static metadata/syntax OK |
| `libtool` | 2.6.2 | 1 | PASS | static metadata/syntax OK |
| `liburcu` | 0.15.6 | 1 | PASS | static metadata/syntax OK |
| `libuv` | 1.51.0 | 1 | PASS | static metadata/syntax OK |
| `libxcrypt` | 4.5.2 | 1 | PASS | static metadata/syntax OK |
| `linux` | 7.1.8 | 4 | PASS | static metadata/syntax OK |
| `linux-api-headers` | 7.1.8 | 1 | PASS | static metadata/syntax OK |
| `linux-firmware` | 20260622 | 1 | PASS | static metadata/syntax OK |
| `linux-headers` | 7.1.8 | 1 | PASS | static metadata/syntax OK |
| `linux-lts` | 6.18.45 | 7 | PASS | updated to 6.18.45; build/boot regression pending |
| `linux-pam` | 1.7.2 | 2 | PASS | static metadata/syntax OK |
| `lvm2` | 2.03.41 | 1 | PASS | static metadata/syntax OK |
| `lz4` | 1.10.0 | 1 | PASS | static metadata/syntax OK |
| `lzo` | 2.10 | 1 | PASS | static metadata/syntax OK |
| `m4` | 1.4.21 | 1 | PASS | static metadata/syntax OK |
| `make` | 4.4.1 | 1 | PASS | static metadata/syntax OK |
| `make-ca` | 1.16.1 | 4 | PASS | static metadata/syntax OK |
| `man-db` | 2.13.1 | 1 | PASS | static metadata/syntax OK |
| `man-pages` | 6.18 | 1 | PASS | static metadata/syntax OK |
| `mandoc` | 1.14.6 | 1 | PASS | static metadata/syntax OK |
| `mdadm` | 4.4 | 1 | PASS | static metadata/syntax OK |
| `meson` | 1.12.0 | 1 | PASS | static metadata/syntax OK |
| `mpc` | 1.4.1 | 1 | PASS | static metadata/syntax OK |
| `mpdecimal` | 4.0.1 | 1 | PASS | static metadata/syntax OK |
| `mpfr` | 4.2.2 | 1 | PASS | static metadata/syntax OK |
| `mtools` | 4.0.49 | 1 | PASS | static metadata/syntax OK |
| `nano` | 9.1 | 1 | PASS | static metadata/syntax OK |
| `nasm` | 3.02 | 1 | PASS | static metadata/syntax OK |
| `ncurses` | 6.6 | 1 | PASS | static metadata/syntax OK |
| `nftables` | 1.1.6 | 1 | PASS | static metadata/syntax OK |
| `ninja` | 1.13.2 | 1 | PASS | static metadata/syntax OK |
| `openssh` | 10.4p1 | 1 | PASS | static metadata/syntax OK |
| `openssl` | 4.0.1 | 1 | PASS | static metadata/syntax OK |
| `patch` | 2.8 | 1 | PASS | static metadata/syntax OK |
| `pciutils` | 3.15.0 | 1 | PASS | static metadata/syntax OK |
| `pcre2` | 10.47 | 1 | PASS | static metadata/syntax OK |
| `perl` | 5.44.0 | 1 | PASS | static metadata/syntax OK |
| `perl-xml-parser` | 2.47 | 1 | PASS | static metadata/syntax OK |
| `pkgconf` | 3.0.5 | 1 | PASS | static metadata/syntax OK |
| `pkgutils` | 5.40.12 | 14 | PASS | release 14; per-package workdir defaults |
| `popt` | 1.19 | 1 | PASS | static metadata/syntax OK |
| `ports` | 1.6 | 2 | PASS | static metadata/syntax OK |
| `procps-ng` | 4.0.7 | 1 | PASS | static metadata/syntax OK |
| `prt-get` | 5.19.9 | 3 | PASS | static metadata/syntax OK |
| `prt-utils` | 1.3.7 | 3 | PASS | static metadata/syntax OK |
| `psmisc` | 23.7 | 1 | PASS | static metadata/syntax OK |
| `python3` | 3.14.7 | 1 | PASS | static metadata/syntax OK |
| `python3-attrs` | 24.3.0 | 1 | PASS | static metadata/syntax OK |
| `python3-babel` | 2.18.0 | 1 | PASS | static metadata/syntax OK |
| `python3-build` | 1.5.0 | 1 | PASS | static metadata/syntax OK |
| `python3-cairo` | 1.27.0 | 2 | PASS | static metadata/syntax OK |
| `python3-calver` | 2022.6.26 | 1 | PASS | static metadata/syntax OK |
| `python3-certifi` | 2024.12.14 | 1 | PASS | static metadata/syntax OK |
| `python3-chardet` | 5.1.0 | 1 | PASS | static metadata/syntax OK |
| `python3-charset-normalizer` | 3.0.1 | 1 | PASS | static metadata/syntax OK |
| `python3-docutils` | 0.21.2 | 1 | PASS | static metadata/syntax OK |
| `python3-doxypypy` | 0.8.8.7 | 1 | PASS | static metadata/syntax OK |
| `python3-doxyqml` | 0.5.3 | 1 | PASS | static metadata/syntax OK |
| `python3-editables` | 0.5 | 1 | PASS | static metadata/syntax OK |
| `python3-flit-core` | 4.0.2 | 1 | PASS | static metadata/syntax OK |
| `python3-gi_docgen` | 2024.1 | 1 | PASS | static metadata/syntax OK |
| `python3-gobject` | 3.50.0 | 1 | PASS | static metadata/syntax OK |
| `python3-hatch-fancy-pypi-readme` | 24.1.0 | 1 | PASS | static metadata/syntax OK |
| `python3-hatch-vcs` | 0.4.0 | 1 | PASS | static metadata/syntax OK |
| `python3-hatchling` | 1.27.0 | 1 | PASS | static metadata/syntax OK |
| `python3-html5lib` | 1.1 | 1 | PASS | static metadata/syntax OK |
| `python3-idna` | 3.10 | 1 | PASS | static metadata/syntax OK |
| `python3-installer` | 1.0.1 | 1 | PASS | static metadata/syntax OK |
| `python3-jinja2` | 3.1.6 | 1 | PASS | static metadata/syntax OK |
| `python3-lxml` | 5.3.0 | 1 | PASS | static metadata/syntax OK |
| `python3-mako` | 1.3.6 | 1 | PASS | static metadata/syntax OK |
| `python3-markdown` | 3.4.1 | 1 | PASS | static metadata/syntax OK |
| `python3-markupsafe` | 3.0.3 | 1 | PASS | static metadata/syntax OK |
| `python3-meson_python` | 0.17.0 | 1 | PASS | static metadata/syntax OK |
| `python3-numpy` | 2.2.2 | 1 | PASS | dependency alias cleaned; uses python3-meson_python |
| `python3-packaging` | 26.3 | 1 | PASS | static metadata/syntax OK |
| `python3-pathspec` | 0.12.1 | 1 | PASS | static metadata/syntax OK |
| `python3-pip` | 26.1.2 | 1 | PASS | static metadata/syntax OK |
| `python3-pluggy` | 1.5.0 | 1 | PASS | static metadata/syntax OK |
| `python3-ply` | 3.11 | 1 | PASS | static metadata/syntax OK |
| `python3-psutil` | 5.9.8 | 1 | PASS | static metadata/syntax OK |
| `python3-pycparser` | 2.22 | 1 | PASS | static metadata/syntax OK |
| `python3-pygdbmi` | 0.11.0.0 | 1 | PASS | static metadata/syntax OK |
| `python3-pygments` | 2.18.0 | 1 | PASS | static metadata/syntax OK |
| `python3-pyproject-hooks` | 1.2.0 | 1 | PASS | static metadata/syntax OK |
| `python3-pyproject_metadata` | 0.8.0 | 1 | PASS | static metadata/syntax OK |
| `python3-python-dbusmock` | 0.31.1 | 1 | PASS | static metadata/syntax OK |
| `python3-pytz` | 2026.2 | 1 | PASS | static metadata/syntax OK |
| `python3-pyxdg` | 0.28 | 1 | PASS | static metadata/syntax OK |
| `python3-pyyaml` | 6.0.2 | 1 | PASS | declares libyaml/python3-cython; not present in current ports tree — dependency review needed |
| `python3-requests` | 2.32.2 | 1 | PASS | static metadata/syntax OK |
| `python3-setuptools` | 84.0.0 | 1 | PASS | static metadata/syntax OK |
| `python3-setuptools-scm` | 8.2.1 | 1 | PASS | static metadata/syntax OK |
| `python3-six` | 1.16.0 | 2 | PASS | static metadata/syntax OK |
| `python3-tomli` | 2.4.1 | 1 | PASS | static metadata/syntax OK |
| `python3-trove-classifiers` | 2024.4.10 | 1 | PASS | static metadata/syntax OK |
| `python3-typing_extensions` | 4.12.2 | 1 | PASS | static metadata/syntax OK |
| `python3-typogrify` | 2.0.7 | 1 | PASS | static metadata/syntax OK |
| `python3-urllib3` | 2.2.3 | 1 | PASS | static metadata/syntax OK |
| `python3-webencodings` | 0.5.1 | 1 | PASS | static metadata/syntax OK |
| `python3-wheel` | 0.48.0 | 1 | PASS | static metadata/syntax OK |
| `rdfind` | 1.8.0 | 1 | PASS | static metadata/syntax OK |
| `readline` | 8.3 | 1 | PASS | static metadata/syntax OK |
| `rsync` | 3.4.4 | 1 | PASS | static metadata/syntax OK |
| `sed` | 4.10 | 1 | PASS | static metadata/syntax OK |
| `shadow` | 4.20.2 | 1 | PASS | static metadata/syntax OK |
| `signify` | 0.14 | 1 | PASS | static metadata/syntax OK |
| `sqlite` | 3.53.4 | 1 | PASS | static metadata/syntax OK |
| `squashfs-tools` | 4.7.5 | 1 | PASS | static metadata/syntax OK |
| `stripping` | 1.0 | 1 | PASS | static metadata/syntax OK |
| `sudo` | 1.9.17p2 | 1 | PASS | static metadata/syntax OK |
| `systemd` | 261.2 | 1 | PASS | static metadata/syntax OK |
| `tar` | 1.35 | 1 | PASS | static metadata/syntax OK |
| `texinfo` | 7.3 | 1 | PASS | static metadata/syntax OK |
| `tzdata` | 2026c | 2 | PASS | static metadata/syntax OK |
| `util-linux` | 2.42.2 | 2 | PASS | static metadata/syntax OK |
| `vim` | 9.2.0954 | 1 | PASS | static metadata/syntax OK |
| `which` | 2.25 | 1 | PASS | static metadata/syntax OK |
| `wireless_tools` | 30.pre9 | 4 | PASS | static metadata/syntax OK |
| `wpa_supplicant` | 2.11 | 3 | PASS | static metadata/syntax OK |
| `xfsprogs` | 7.1.1 | 1 | PASS | static metadata/syntax OK |
| `xxhash` | 0.8.3 | 1 | PASS | static metadata/syntax OK |
| `xz` | 5.8.3 | 1 | PASS | static metadata/syntax OK |
| `zlib` | 1.3.2 | 1 | PASS | static metadata/syntax OK |
| `zstd` | 1.5.7 | 1 | PASS | static metadata/syntax OK |
