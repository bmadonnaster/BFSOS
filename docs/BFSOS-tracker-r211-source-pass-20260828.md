# BFSOS Tracker r211 Source-Implementation Pass — 2026-08-28

This pass worked every tracker item that can be acted on safely from the supplied BFSOS source tree without pretending that VM, fresh-install, hardware, boot, desktop-session, upgrade, or long package-build regressions have been executed. Historical tracker entries remain useful as evidence; r211 supersedes their *source implementation* status where noted below.

## Implemented in source

### Package/build infrastructure

- Added a distro-owned `/opt` build environment to `ports/core/pkgutils/pkgmk.conf` for `/opt/rustc`, `/opt/qt6`, `/opt/kf6`, and `/opt/qt5`; exports `QT6DIR`, `QT5DIR`, `KF6_PREFIX`, `PATH`, `PKG_CONFIG_PATH`, and `CMAKE_PREFIX_PATH` as appropriate.
- Extended `aaa_filesystem/kf6.sudoers` to preserve the relevant Qt/KF/CMake/pkg-config variables through sudo where needed.
- Namespaced the pkgmk source cache by package (`/var/cache/pkg/sources/$name`) to prevent unrelated ports with the same source basename from poisoning one another.
- Generalized `bfs-pkgmk` failed-package cleanup to honor a configured `PKGMK_PACKAGE_DIR` rather than assuming only `/var/cache/pkg/packages`.
- Added a `prt-get` sysup wrapper/preflight so `pkgutils` is updated before the remainder of a real `sysup`, preventing new package recipes from being interpreted by stale pkgmk behavior.
- Migrated every remaining legacy `build()` recipe in maintained 64-bit collections (`core`, `opt`, `xorg`, `plasma`, `contrib`, `gnome`, `lxqt`, `xfce`, `compiz`) to `pkg_build()`. `compat-32` is intentionally excluded because the tracker calls for a separate architectural redesign rather than preserving the current duplicate-recipe model.
- Removed duplicate hard-dependency tokens found by the static audit.
- Modernized several touched recipes to fail immediately on configure/build/install errors, including SDDM, Extra CMake Modules, PulseAudio, wpa_supplicant, and the new QtWebEngine5 recipe.

### Qt / KDE / Plasma

- Split Qt5 WebEngine out of the base `qt5` package:
  - `qt5` explicitly skips `qtwebengine` and no longer carries WebEngine-only build dependencies.
  - Added `ports/opt/qtwebengine5` for Qt 5.15.19 with a current Debian compatibility patch bundle and `/opt/qt5` integration.
- Confirmed the supplied Qt6 packaging was already split (`qt6` plus `qt6-webengine`) and preserved that policy; `khelpcenter` remains a known Qt6 WebEngine consumer.
- `plasma-meta` now explicitly depends on `sddm`, retains exactly one `phonon-backend-vlc`, and retains the PipeWire/WirePlumber default-user-unit integration.
- Modernized the SDDM port and made its install hook enable `sddm.service` when systemd is available.
- Removed obsolete ConsoleKit-era hard dependency from `kscreenlocker`; dependency policy now targets the systemd/logind/PAM/Qt6/KF6 stack.
- Modernized remaining legacy Plasma recipes encountered in the supplied tree.
- Added/expanded `scripts/bfs-desktop-integration-check.sh` to check SDDM, screen-locker linkage, PipeWire/WirePlumber/Pulse compatibility, Qt6 Phonon-VLC, VLC Qt6 linkage, and RTKit status.

### Trust / TLS

- Corrected trust-stack dependency direction: `make-ca` depends on `p11-kit`; `p11-kit` no longer incorrectly depends on `make-ca`.
- `make-ca` now creates the expected PKI directories and ships a post-install hook that performs initial generation (`make-ca -g`) or refresh (`make-ca -r`), verifies the canonical bundle/trust view, and enables `update-pki.timer` where available.
- `ca-certificates` post-install refreshes make-ca state when the trust tooling is installed.
- Added `ca-certificates`, `libtasn1`, `p11-kit`, and `make-ca` to the Bootstrap final base package set alongside curl.
- Added `scripts/bfs-trust-check.sh` for installed-system PEM, p11-kit/NSS, curl/HTTPS, and certificate-count validation.

### Installer / storage / kernel

- Created `scripts/install-bfs-menu-v50-r71-lvm-equal-split.sh` and updated `install-bfs-menu-current.sh` to r71.
- The equal `/home` + `/var` preset now snapshots the original VG free extents once, divides that original total into two allocations differing by at most one PE, shows both calculated sizes before creation, and validates actual sizes after creation.
- Changed Linux LTS MD personality configuration to match the normal-kernel module policy (`CONFIG_MD=y`, personalities modular).
- Updated installer initramfs verification so built-in (`=y`) drivers are accepted without requiring `.ko` files, modular (`=m`) drivers require the module in the initramfs, and disabled personalities fail clearly.
- Removed the redundant successful Stage-1 Bootstrap acknowledgement dialog so successful completion returns directly to the main menu after archive validation.

### Networking / desktop dependency audit

- Added a `traceroute` 2.1.6 core port and included it in the final Bootstrap base package set for stock route diagnostics.
- Updated NetworkManager to 1.58.1 while retaining its current default-feature dependency policy. The large dependency closure previously attributed to Lynx is not caused by the Lynx port itself; NetworkManager's recommended/default integrations account for the broad closure.
- Updated xterm to 411.
- Reduced `libnotify` hard dependencies to `gdk-pixbuf` and disabled tests so GTK4 is not pulled merely for the test suite.

### Static release checks

- Expanded `scripts/bfs-ports-static-audit.sh` with checks for:
  - zero legacy `build()` in maintained 64-bit collections;
  - Qt5/QtWebEngine5 split;
  - Plasma SDDM/Phonon metadata;
  - `/opt` build-environment support;
  - trust-stack dependency direction.
- Added `scripts/bfs-release-static-audit.sh` to aggregate source-policy checks across ports, Bootstrap, current installer, trust, Qt WebEngine splits, Plasma defaults, MD policy, source-cache namespacing, sysup/pkgutils ordering, and duplicate dependency tokens.
- Both audits pass in the supplied project tree after this pass.

## Source items already present and reconciled

The supplied tree already contained many fixes that older tracker entries still showed as open or partially open: X.Org dependency/prefix work, GLib/GI footprint work, Mesa SPIR-V/LLVM metadata with LLVM `keep_static=1`, Python/PyYAML and Boost source fixes, package compression defaults, bash-completion ownership cleanup, current Plasma/KF/Gear version coordination, Qt6 WebEngine split, Firefox dav1d integration, several kernel/header updates, and the existing package-build wrapper/failure cleanup. r211 does not deliberately duplicate those implementations.

## Still OPEN because they require real runtime/build/install evidence

These are not safe to mark complete from a source archive alone:

- Clean Bootstrap/base build from an empty cache, including TLS/trust initialization and mirror fallback behavior.
- Full Qt5 + `qtwebengine5` clean build, install, ownership/upgrade migration, and actual Qt5 WebEngine consumer regression. The new recipe is source-ready but must be built before release.
- `prt-get sysup` runtime regression proving pkgutils-first behavior both when pkgutils is current and when it is part of the update set.
- Runtime regression of package-namespaced source caching and non-default package directories.
- Fresh installer matrix for LVM equal split, odd extent counts, pre-existing allocations, `%VG`, and explicit single-LV `%FREE` semantics.
- Fresh/cold MD/LUKS/LVM boot matrices for normal and LTS kernels, including built-in-versus-module initramfs verifier behavior.
- Fresh SDDM/Plasma login, repeated screen lock/unlock, X11/Wayland, PipeWire/WirePlumber, RTKit, Phonon/VLC, portal, and desktop integration checks.
- Fresh trust regressions: p11-kit anchors, NSS/Firefox, OpenSSL/curl, timer refresh, and representative package upgrade orders.
- X.Org/Wayland, XFCE, GNOME, LXQt, Compiz, VLC, and other desktop/application runtime matrices that require a running graphical VM.
- Installed-package inventory/ownership cleanup items that require the live VM package database and filesystem, including orphaned historical files from earlier package-layout migrations.
- Full package-by-package long-build regression for recipes touched by the legacy `build()` migration.
- `compat-32` redesign/per-port 32-bit support. The existing compat-32 tree intentionally remains outside the 64-bit `pkg_build()` migration because the tracker calls for replacing that architecture, not spending this pass entrenching it.
- First-class package lifecycle-hook architecture beyond the existing package-specific hooks. This is a pkgutils/pkgadd design change and should be implemented and regression-tested as a focused follow-up rather than introduced late in a broad source pass.
- Hardware-specific, suspend/resume, GPU, RAID failure/degraded-array, bare-metal, and ISO/boot-media scenarios that cannot be validated in the source container.

## Validation performed in this pass

```text
git diff --check: PASS
scripts/bfs-ports-static-audit.sh: PASS
scripts/bfs-release-static-audit.sh: PASS
bash -n / sh -n checks exercised by the audit: PASS
```

The runtime queue above is deliberate: source implementation and static validation are complete for the changes listed, but BFSOS should not call runtime-sensitive tracker items closed until the corresponding VM/bare-metal regressions pass.
