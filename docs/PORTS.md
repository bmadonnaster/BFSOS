# BFSOS ports and package maintenance

BFSOS uses a CRUX-style ports tree and the CRUX `pkgutils`/`prt-get` model, extended with BFSOS build conventions, multilib handling, source fallbacks, package-namespaced caches, and generic build-system detection.

The current BFSOS implementation is authoritative for BFSOS ports. CRUX documentation is useful background, and Emmett's `lfs-scripts` project is an important ancestor of the extended LFS/CRUX-style tooling from which BFSOS evolved.

Canonical source tree:

```text
https://github.com/bmadonnaster/BFSOS
```

SourceForge hosts release ISO/base artifacts; it is not the authoritative ports repository.

## Port layout

A port is a package directory beneath a collection:

```text
ports/<collection>/<package>/
```

Examples of maintained collections include `core`, `opt`, `contrib`, `compat-32`, `xorg`, `plasma`, `gnome`, `xfce`, `lxqt`, and `compiz`.

A typical port can contain:

```text
Pkgfile
.footprint          optional/reviewed package payload metadata
.signature          optional signed-port metadata when signing is in use
*.patch / *.diff    optional source patches
pre-install         optional package-install hook
post-install        optional package-install hook
other support files referenced by source=()
```

Do not create empty `.footprint` or `.signature` placeholders. An empty footprint is not equivalent to no footprint: pkgmk will compare the produced payload with the empty expected payload and report every installed path as `NEW`.

## Pkgfile headers and variables

BFSOS Pkgfiles normally start with factual metadata used by the ports tooling:

```bash
# Description: Short factual description
# URL: https://example.org/project/
# Maintainer: Brian Madonna <bmadonnaster@gmail.com>
# Depends on: dependency-one dependency-two
```

The normal package variables are:

```bash
name=example
version=1.2.3
release=1
source=(https://example.org/releases/$name-$version.tar.xz)
```

`source` is an array. Keep sources explicit: a build should not silently download undeclared dependencies or source archives during `pkg_build()`. BFSOS CMake builds use `-DFETCHCONTENT_FULLY_DISCONNECTED=ON` and Meson builds use `--wrap-mode=nodownload` by default for the same reason.

Use `$name` and `$version` in URLs where the upstream spelling permits it. Increment `version` for an upstream release change. Increment `release` when BFSOS changes packaging for the same upstream version.

## Generic BFSOS build handling

The BFSOS pkgutils extension automatically detects these source build layouts when a Pkgfile does not define a legacy `build()` function:

- `meson.build` -> Meson;
- `configure` -> Autotools/configure;
- `CMakeLists.txt` -> CMake + Ninja;
- `setup.py` -> Python 3;
- `Makefile.PL` -> Perl module;
- `Makefile` or `makefile` -> ordinary Make.

Prefer the generic path plus `build_opt` over a custom `pkg_build()` whenever practical. This keeps architecture, multilib, test, prefix, and installation policy centralized in pkgutils.

A minimal generic port can therefore be only metadata and sources:

```bash
# Description: Example library
# URL: https://example.org/example/
# Maintainer: Brian Madonna <bmadonnaster@gmail.com>
# Depends on: zlib

name=example
version=1.2.3
release=1
source=(https://example.org/releases/$name-$version.tar.xz)
```

For package-specific options, use an array:

```bash
build_opt=(
    -DENABLE_FEATURE=ON
    -DBUILD_EXAMPLES=OFF
)
```

BFSOS accepts historical scalar `build_opt` values too, but arrays are preferred because each argument remains unambiguous.

### Supported build hooks and controls

The current BFSOS extension supports:

- `pre_build()` — runs after source extraction/automatic patches and before the selected build path;
- `pkg_build()` — fully custom build/install orchestration; use only when the generic path cannot represent the build correctly;
- `post_build()` — runs after the generic/custom package build and before final payload cleanup/packaging;
- `build_type` — explicitly select a generic helper when automatic detection is unsuitable;
- `build_opt` — additional build-system options;
- `run_tests=yes` — request supported test execution in generic CMake/Meson paths;
- `configure_out_of_tree=yes` and `configure_build_dir=...` — request an out-of-tree configure build;
- `configure_build_tool=make|ninja` — choose the build tool for configure-based projects;
- `patch_opt` — change the automatic patch strip option (default `-p1`);
- `skip_patch` or `PKGMK_AUTO_PATCH=no` — disable automatic patch application;
- `keep_static`, `keep_libtool`, `keep_locale`, and `keep_doc` — retain payload classes that BFSOS normally removes.

BFSOS automatically applies source entries ending in `.patch`, `.diff`, and their supported compressed forms unless patching is disabled.

A custom `pkg_build()` should include a short comment explaining why the generic path is insufficient. Do not use a custom build merely to repeat the same configure/CMake/Meson defaults already provided by pkgutils.

## Creating a new port with `gentemplate.sh`

The canonical BFSOS starter-port generator is:

```text
scripts/gentemplate.sh
```

Run it from the collection where the new port should be created:

```bash
cd ~/BFSOS/ports/opt
../../scripts/gentemplate.sh https://example.org/releases/foo-1.2.3.tar.xz
```

It derives a package name and version from a normal `name-version.archive` filename, creates `foo/`, and writes a starter `foo/Pkgfile`.

An optional second argument overrides the generated BFSOS package name:

```bash
../../scripts/gentemplate.sh \
  https://files.pythonhosted.org/.../pyqt5_sip-12.19.0.tar.gz \
  pyqt5-sip
```

The generator refuses to overwrite an existing package directory. Its output is deliberately only a starting point: review the Description, upstream URL, dependency list, source naming, build options, patches, package payload, and runtime behavior before committing it.

See its built-in help:

```bash
scripts/gentemplate.sh --help
```

## Normal port workflow

A useful maintainer sequence is:

```text
upstream source URL
  -> gentemplate.sh
  -> review/edit Pkgfile
  -> download/build
  -> inspect package/build-work
  -> review/update footprint if maintained
  -> update/verify signature if signing is in use
  -> install through the repository path
  -> runtime test
  -> git commit/push
```

For development builds, `pkgmk -kw` is useful because BFSOS preserves the package build-work directory for inspection. Add `-d` when sources need to be downloaded, for example:

```bash
sudo pkgmk -dkw
```

A plain `pkgmk` build does **not** exercise a package's `pre-install`/`post-install` installation scripts. When a port has install hooks, test the built package through the normal repository/`prt-get` installation path before considering the port complete.

For dependency-aware installation:

```bash
sudo prt-get depinst <package>
```

After changing dependencies, verify both a clean build and the dependency path rather than relying on an already-populated development machine.

## `.footprint`

`.footprint` records the payload pkgmk expects the package to install. It is a regression check: if a later build adds, removes, changes type, or changes relevant metadata for package paths, pkgmk reports the mismatch rather than silently accepting it.

When no footprint exists, current pkgmk behavior creates an initial footprint from the built payload and skips the comparison for that first build. Review the generated result before deciding to maintain it in Git.

To intentionally update a maintained footprint after reviewing a legitimate package-content change:

```bash
pkgmk -uf
```

Do not blindly regenerate a footprint merely to make an error disappear. First identify why the package payload changed.

### BFSOS footprint policy

BFSOS treats footprints as **maintainer-controlled integrity metadata**, not disposable cleanup files:

- never commit an empty `.footprint`;
- do not delete a reviewed/tracked footprint from generic Git cleanup helpers;
- generated footprints from local experimentation are not automatically authoritative;
- release-critical or payload-sensitive ports should keep reviewed footprints when they provide useful regression coverage;
- when a maintained footprint changes, the port change should explain why.

The Git helper preserves footprint/signature files rather than deleting them. Maintainers should review any newly generated metadata before staging it.

## `.signature` and signed ports

CRUX pkgutils supports Ed25519 port signatures through `signify` and SHA-256 source checksums. BFSOS carries that signing-capable pkgutils base and enables signature verification in `pkgmk.conf` by default.

A `.signature` authenticates the port metadata and recorded source checksums. It complements `.footprint`: the signature establishes integrity/authenticity of the port files, while the footprint describes the expected installed payload.

### Create a collection signing key

Example for a collection named `opt`:

```bash
signify -G -n -c opt -p opt.pub -s opt.sec
```

The `.sec` key is private. **Never commit or publish it.** Public keys may be distributed through trusted project channels.

CRUX's normal model uses one key pair per collection/repository. pkgmk can derive the repository/collection name from the port's parent directory when selecting the key; `-sk` overrides that selection when an explicit secret key is required.

### Create/update a signature and source SHA-256 values

For an upstream version/source update where checksums must be recalculated:

```bash
pkgmk -us
```

`-us` updates the signature **including fresh SHA-256 checksums**.

### Refresh only the cryptographic signature

For a key rotation or metadata re-sign where the recorded source SHA-256 values should remain unchanged:

```bash
pkgmk -rs
```

`-rs` creates a new signature while retaining the existing SHA-256 checksums.

### Use an explicit secret key

```bash
pkgmk -sk /secure/path/opt.sec -us
```

or, when retaining existing checksums:

```bash
pkgmk -sk /secure/path/opt.sec -rs
```

### Verify a signed port

```bash
pkgmk -cs
```

Do this as part of signed-port review before publication.

### BFSOS signature policy

BFSOS currently supports the CRUX-style mechanism but does not claim that every maintained collection is already distributed as a fully signed repository. Until BFSOS publishes an official collection-key distribution/rotation policy, signatures are maintainer-controlled and must not be fabricated merely to satisfy a warning. Once official keys are published, the project can tighten this policy to require signatures collection-wide.

## Source verification and fallbacks

BFSOS stores sources under package-namespaced cache directories and supports both flat and path-preserving fallback mirrors from `pkgmk.conf`. The original `source=()` entry remains authoritative; mirror/fallback use does not bypass package checksum/signature verification.

If an upstream URL changes, update the Pkgfile to a healthy canonical source rather than depending permanently on an accidental third-party distfile cache.

## compat-32 ports

`compat-32` uses the centralized BFSOS multilib policy from pkgutils. Ordinary compat recipes should not reinvent `-m32`, host triplets, pkg-config search paths, or `/usr/lib32` selection. Native/32-bit synchronized versions are checked by:

```bash
scripts/multilibvercheck.sh
```

## Useful maintenance tools

```bash
scripts/checkupdate.sh                 # provider-aware upstream version audit
scripts/bfs-maintained-port-version-audit.sh
scripts/bfs-core-port-audit.py
scripts/bfs-ports-static-audit.sh
scripts/bfs-ports-tree-audit.sh
scripts/bfs-sync-compat32.py
scripts/multilibvercheck.sh
scripts/gentemplate.sh                 # create a starter port from a source URL
```

## Before committing a port

At minimum:

1. verify `bash -n Pkgfile` where applicable;
2. download/build from a clean or appropriately preserved build-work directory;
3. inspect the package payload;
4. review any footprint change;
5. update/check the signature when the collection is signed;
6. install through `prt-get` when package install hooks or dependency behavior need testing;
7. run the relevant application/library runtime checks;
8. run the BFSOS static/regression tests affected by the change;
9. make sure no credentials, private signing keys, build caches, or debug instrumentation are being committed.

## References and credit

BFSOS's package system is intentionally evolutionary rather than a verbatim copy of another distribution. Useful background:

- CRUX: <https://crux.nu/> — ports/pkgutils model, Pkgfile/footprint guidance, and signed-port workflow;
- CRUX Handbook 3.8: <https://crux.nu/Main/Handbook3-8>;
- CRUX Signed Ports: <https://crux.nu/Wiki/SignedPorts>;
- Emmett's `lfs-scripts`: <https://github.com/emmett1/lfs-scripts> — an important ancestor of the extended LFS/CRUX-style tooling used during BFSOS's evolution;
- Linux From Scratch: <https://www.linuxfromscratch.org/> — the bootstrap/build-system foundation that inspired BFSOS.
