# BFSOS r171 Plasma/pkgmk maintenance pass — 2026-08-23

## Verified BLFS development baseline

The audit baseline is the current BLFS systemd development book:

- KDE Frameworks: 6.26.0
- Plasma: 6.6.5
- KDE Gear / release-service applications: 26.04.1
- Extra-CMake-Modules: 6.26.0
- plasma-wayland-protocols: 1.21.0
- kirigami-addons: 1.12.1
- pulseaudio-qt: 1.8.1
- polkit-qt-1: 0.201.1

## Implemented in this pass

- Bulk-aligned the existing KF6 6.13.0 ports to 6.26.0.
- Bulk-aligned the existing Plasma 6.3.4/6.3.4.1 ports to 6.6.5.
- Bulk-aligned the existing KDE Gear 25.04.0 ports to 26.04.1.
- Updated the explicitly versioned supporting KDE packages listed above.
- Updated hard-coded version path components in affected KDE download URLs.
- All Plasma Pkgfiles pass `bash -n` after the edits.
- pkgmk automatic patch handling now supports plain, gzip, xz and bzip2 patch/diff sources.
- pkgmk now propagates automatic patch failure before entering pkg_build().
- Added explicit `PKGMK_AUTO_PATCH=no` opt-out while retaining the existing `skip_patch` compatibility behavior.
- Synchronized the extension changes into `files/pkgmk.bootstrap`.
- Bumped pkgutils release from 17 to 18.

## Kernel review

- `linux` is 7.1.8, matching the current LFS development kernel/API-header baseline used for BFSOS.
- `linux-lts` is 6.18.45, matching the current kernel.org 6.18 longterm release observed in this pass.
- No kernel version bump was made in r171. Kernel 7.2 is upstream mainline, but changing BFSOS away from the current LFS-aligned 7.1.8 baseline should be a deliberate policy decision rather than an automatic audit bump.

## firefox-bin/dbus-glib static check

The supplied project contains exactly one `firefox-bin`, one `firefox`, and one `dbus-glib` port. The current `firefox-bin` dependency line is clean ASCII and no longer lists `dbus-glib`; it lists `dbus` instead. The current `dbus-glib` port is 0.114 release 3 and uses the Debian source mirror. This makes a duplicate port/folder or malformed dependency line unlikely in the supplied tree; runtime prt-get state/caching and the timing of the dependency-line edit still need regression testing.

## Still pending

This is not a claim that every URL/dependency in all 169 Plasma ports is fully runtime-verified. The family/version alignment and static URL path updates are complete, but each changed source should still be fetched/checked and the dependency/build chain exercised on BFSOS. The broader core/opt/xorg package-by-package audit remains open where no concrete r171 edit is documented.
