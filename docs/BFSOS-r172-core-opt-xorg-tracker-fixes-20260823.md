# BFSOS r172 core/opt/xorg tracker-fix pass — 2026-08-23

This pass returns to the r149-r170 live findings and applies the concrete
package changes that were still missing from the supplied full project.

## Kernel/header synchronization

- linux: 7.1.8 -> 7.1.9, release bumped.
- linux-headers: 7.1.8 -> 7.1.9, release bumped.
- linux-api-headers: 7.1.8 -> 7.1.9, release bumped.
- Fixed linux-api-headers source path from the incorrect kernel/v6.x tree to kernel/v7.x.
- linux-lts remains 6.18.45 (current longterm point release during this pass).
- Added package-owned `/boot/vmlinuz-lts` symlink to the actual installed LTS kernel version.
- Enabled kernel/module Zstandard compression policy in both linux and linux-lts; Dracut was already configured for zstd.

## Dependency metadata / package chain fixes

- xorg meta now depends on wayland, wayland-protocols and xwayland.
- xorg-driver restores the now-live-tested xf86-video-openchrome and xf86-video-vboxvideo drivers.
- libnotify now declares gtk4 and uses a fail-fast Meson build.
- shared-mime-info now declares xmlto for its current build configuration and is fail-fast.
- Exact GTK4 -> Qt5 dependency path was `gtk4 -> highlight -> qt5`; removed highlight from GTK4 hard deps and classified it optional.
- Qt5 now declares python3-html5lib.
- Node.js now declares ICU as a hard dependency, uses the valid `--shared-nghttp2` configure switch, uses the new auto-patch opt-out, and fails fast.
- NSS now explicitly declares sqlite and zlib because the recipe uses system SQLite/Zlib.
- Firefox source port now explicitly declares libffi, libjpeg-turbo, libpng, pixman, wayland and zlib in addition to the dependencies discovered during the successful Firefox 154 build.
- libsndfile now declares the codec/audio baseline used by its intended BFSOS build: flac, libogg, libvorbis, opus, alsa-lib, lame and mpg123.
- Duplicate dependency tokens removed from gtkmm3, gst-plugins-ugly and xorg-libs.
- Corrected `ibjpeg-turbo` typo to `libjpeg-turbo` in libwebp optional metadata.

## Build/packaging fixes

- NASM xdoc URL now follows `$version`; recipe is fail-fast.
- libsndfile and Yasm retain GNU17/C23 compatibility and are now fail-fast.
- PulseAudio Debian fallback source retained; build/install now fail fast.
- xsetroot made fail-fast.
- Qt5 helper symlinks (`qmake-qt5`, `moc-qt5`, etc.) are now package-owned and point directly into `/opt/qt5/bin`; the stale post-install `$QT5BINDIR` logic that produced links such as `/usr/bin/qmake-qt5 -> /qmake` was removed.
- Qt5 profile and ld.so configuration remain package-owned; post-install now only refreshes ldconfig.
- Removed package-owned `qt5.sh`, `qt6.sh`, and `rustc.sh` duplicates from aaa_filesystem.
- libpng now relies on the new centralized compressed-patch support instead of manually applying its APNG `.patch.gz` a second time.
- firefox-bin source changed from HTTP ftp.mozilla.org to HTTPS archive.mozilla.org.

## Full-tree static dependency/syntax pass

All 761 Pkgfiles in core/opt/xorg were included in the dependency metadata
scan. Every declared hard dependency resolves to an existing BFSOS port and
there are no duplicate hard-dependency tokens after this pass.

All core/opt/xorg/plasma Pkgfiles (930 total) pass `bash -n` after the changes.

This static pass does not claim that all 761 upstream versions/source endpoints
have been network-fetched and runtime-built. The tracker still requires
per-package upstream version/source verification and clean build regressions;
packages should be marked UNVERIFIED rather than silently assumed current when
external verification has not been performed.
