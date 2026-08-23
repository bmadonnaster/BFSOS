# BFSOS opt + Xorg Pre-1.0 Audit — r143 — 2026-08-22

## Scope and validation level

- Audited **379 `ports/opt` Pkgfiles** and **179 `ports/xorg` Pkgfiles** (558 total).
- Every Pkgfile was parsed with `bash -n`; **0 syntax failures** remain.
- Required dependency-name resolution against the complete BFSOS ports tree: **0 unresolved dependencies**.
- Xorg driver meta-package coverage: **23/23 input/video driver ports represented; 0 missing and 0 stale extra driver names**.
- Static audit is complete. Large/complex ports are explicitly marked for real build/install/runtime validation; static correctness is not treated as proof that a package builds.

## Reference policy used

- BLFS/LFS development is used for packages and build layouts it actively documents.
- Current CRUX plus upstream X.Org release information is the primary comparison for standalone Xorg video/input drivers that BLFS no longer installs as a complete driver set.
- BFSOS intentionally preserves LFS-style `/opt` placement for Qt5, Qt6, Rust, TeX Live, and other packages where isolation is useful.
- Firefox policy is normal rapid-release Firefox, not ESR.

## Major changes applied

- **LLVM:** replaced split LLVM/Clang/compiler-rt tarball extraction/rename gymnastics with one `llvm-project` monorepo build; LLVM + Clang + compiler-rt are built coherently from one release.
- **Mesa:** modernized to Mesa 26.1.7 and simplified driver selection around current Meson auto-selection rather than maintaining a growing hand-built driver string.
- **NetworkManager:** modernized to 1.58.0 and kept the core package deliberately GUI-light: no Qt dependency, PPP/modem/cloud/CLAT features disabled in the core build, with `nmtui` retained.
- **Rust:** modernized to 1.97.1, preserved under `/opt/rustc-<version>`, and fixed multilib bootstrap TOML so only one `[build]` table is emitted.
- **Qt5:** renamed `qt5-alternate` to `qt5`, moved permanently to `/opt/qt5`, updated to 5.15.19, and retained as a single compatibility-stack package. Current Debian QtBase/QtWebEngine compatibility patches are staged for OpenSSL 4/current compiler/glibc/Python/Ninja compatibility; this port is **build-test required**.
- **Qt6:** kept as one monolithic `/opt/qt6` port, updated to 6.11.2, and folded QtWebEngine responsibility into the Qt6 package instead of a separate BFSOS `qtwebengine` port. This is **build-test required** because of its very large dependency/build surface.
- **QCA:** corrected contradictory Qt5 dependency metadata; QCA 2.3.10 is now a Qt6 package with the OpenSSL 4 compatibility patch.
- **Firefox:** policy changed to normal Firefox rapid releases; port advanced to 154.0 and stale version-specific source surgery was removed. This is **build-test required** before acceptance.
- **wireless-regdb:** new port added; `wpa_supplicant` now requires it so Wi-Fi installs obtain `regulatory.db` and `regulatory.db.p7s` automatically.
- **Lynx + Links:** installer r62 adds independent optional choices for both text browsers and persists/installs them through normal dependency-aware package handling; the final audit corrected the text-mode menu numbering to Lynx=5, Links=6, Done=7.
- **TeX Live:** stale hidden 2023 downloads removed; 2025 sources are declared through `source=()` and remain under `/opt/texlive`.
- **shared-mime-info / Speex:** undeclared live `wget` source acquisition replaced with declared pkgmk sources.
- **FFmpeg:** updated to 9.0.1 and corrected packaging so installation writes to `$PKG`, not the build host.
- **Xorg:** updated key infrastructure packages including Xorg Server 21.1.24, Xwayland 24.1.13, xorgproto 2025.1, xkeyboard-config 2.48, xbitmaps 1.1.4, xinit 1.4.4, xterm 410, synaptics 1.10.0, and Wacom 1.2.4.
- **Xorg drivers:** removed the stray duplicate `ports/xorg/brian@192.168.68.66` Nouveau directory and restored `xf86-video-openchrome` to `xorg-driver`; meta coverage is now exact.
- **Dependency/name cleanup:** fixed numerous malformed names/case/typos (`pulseAudio`, `freetypoe`, `pinetry`, `v4l-utilss`, `ssdl2`, `liblibnghttp2`, old `xorg-lib*` aliases, Qt alternate aliases, and others). Required dependency resolution is now zero-unresolved.
- **Packaging safety:** corrected definite build-stage host writes in cdrdao, desktop-file-utils, FFmpeg and Subversion. Remaining absolute paths found by the heuristic are either source-side symlink targets or intentional post-install system configuration and require runtime package tests, not automatic rewriting.

## Selected updated package states

| Port | Package | Version | Release |
|---|---|---:|---:|
| `ports/opt/llvm/Pkgfile` | `llvm` | `22.1.8` | `2` |
| `ports/xorg/mesa/Pkgfile` | `mesa` | `26.1.7` | `2` |
| `ports/opt/networkmanager/Pkgfile` | `networkmanager` | `1.58.0` | `2` |
| `ports/opt/rustc/Pkgfile` | `rustc` | `1.97.1` | `2` |
| `ports/opt/qt5/Pkgfile` | `qt5` | `5.15.19` | `3` |
| `ports/opt/qt6/Pkgfile` | `qt6` | `6.11.2` | `2` |
| `ports/opt/firefox/Pkgfile` | `firefox` | `154.0` | `3` |
| `ports/opt/texlive/Pkgfile` | `texlive` | `20250308` | `3` |
| `ports/opt/wireless-regdb/Pkgfile` | `wireless-regdb` | `2026.05.30` | `1` |
| `ports/opt/qca/Pkgfile` | `qca` | `2.3.10` | `2` |
| `ports/xorg/xorg-server/Pkgfile` | `xorg-server` | `21.1.24` | `2` |
| `ports/xorg/xwayland/Pkgfile` | `xwayland` | `24.1.13` | `2` |
| `ports/xorg/xorgproto/Pkgfile` | `xorgproto` | `2025.1` | `2` |
| `ports/xorg/xkeyboard-config/Pkgfile` | `xkeyboard-config` | `2.48` | `2` |
| `ports/xorg/xorg-driver/Pkgfile` | `xorg-driver` | `7x` | `2` |

## Build/runtime validation still required

- Build `llvm`, then build `rustc` against the installed LLVM and verify both x86_64 and BFSOS multilib behavior.
- Build Mesa after LLVM/Rust-related dependencies are installed; verify X11, optional Wayland, Gallium and Vulkan runtime on QEMU and real AMD/Intel hardware where available.
- Build Qt5 completely, including its compatibility patch staging; test representative legacy Qt5 applications. Do not delete Qt5 before this succeeds.
- Build Qt6 including QtWebEngine; verify `/opt/qt6` environment, plugins, WebEngine sandbox/runtime, and representative Qt6 applications.
- Build Firefox 154.0 against the rebuilt LLVM/Rust/GTK/NSS stack and launch a clean profile; normal-release policy is implemented but the recipe is not runtime-proven yet.
- Build/install NetworkManager on a minimal BFSOS target and inspect `prt-get depinst` output to prove it does not drag in Qt/GTK/Xorg desktop stacks unexpectedly.
- Build/install `wireless-regdb` + `wpa_supplicant`; verify the previous kernel `regulatory.db failed with error -2` message disappears on a Wi-Fi-capable system.
- Build/install the updated Xorg server/libraries and every driver represented by the meta package; driver inclusion was statically reconciled, not hardware-tested.
- Build TeX Live, FFmpeg, ftjam/ArgyllCMS, shared-mime-info and Speex to validate the source/extraction cleanups.
- Run the normal BFSOS clean-build/install regression after these package builds before 1.0 sign-off.

## Complete port inventory / static audit

| Collection | Directory | Package | Version | Rel | Required deps | Unresolved | `source=()` | live wget/curl | manual tar |
|---|---|---|---:|---:|---:|---:|:---:|:---:|:---:|
| opt | `aalib` | `aalib` | `1.4rc5` | `1` | 0 | 0 | yes | no | no |
| opt | `abseil-cpp` | `abseil-cpp` | `20250512.0` | `1` | 1 | 0 | yes | no | no |
| opt | `accountsservice` | `accountsservice` | `23.13.9` | `1` | 5 | 0 | yes | no | no |
| opt | `alsa-lib` | `alsa-lib` | `1.2.14` | `1` | 0 | 0 | yes | no | no |
| opt | `alsa-plugins` | `alsa-plugins` | `1.2.7.1` | `1` | 1 | 0 | yes | no | no |
| opt | `alsa-tools` | `alsa-tools` | `1.2.5` | `1` | 3 | 0 | yes | no | no |
| opt | `alsa-utils` | `alsa-utils` | `1.2.13` | `1` | 2 | 0 | yes | no | no |
| opt | `appstream-glib` | `appstream-glib` | `0.8.3` | `1` | 3 | 0 | yes | no | no |
| opt | `apr-util` | `apr-util` | `1.6.3` | `1` | 1 | 0 | yes | no | no |
| opt | `argon2` | `argon2` | `20190702` | `1` | 0 | 0 | yes | no | no |
| opt | `argyllcms` | `argyllcms` | `3.5.0` | `2` | 6 | 0 | yes | no | no |
| opt | `aspell` | `aspell` | `0.60.8.1` | `1` | 1 | 0 | yes | no | no |
| opt | `aspell6-en` | `aspell6-en` | `2020.12.07-0` | `1` | 2 | 0 | yes | no | no |
| opt | `at-spi2-core` | `at-spi2-core` | `2.56.1` | `1` | 6 | 0 | yes | no | no |
| opt | `atkmm` | `atkmm` | `2.28.4` | `1` | 2 | 0 | yes | no | no |
| opt | `autoconf-archive` | `autoconf-archive` | `2024.10.16` | `1` | 0 | 0 | yes | no | no |
| opt | `avahi` | `avahi` | `0.8` | `1` | 7 | 0 | yes | no | no |
| opt | `bluez` | `bluez` | `5.83` | `1` | 3 | 0 | yes | no | no |
| opt | `bogofilter` | `bogofilter` | `1.2.5` | `1` | 3 | 0 | yes | no | no |
| opt | `boost` | `boost` | `1.91.0` | `1` | 2 | 0 | yes | no | no |
| opt | `brotli` | `brotli` | `1.1.0` | `1` | 1 | 0 | yes | no | no |
| opt | `bubblewrap` | `bubblewrap` | `0.11.0` | `1` | 0 | 0 | yes | no | no |
| opt | `c-ares` | `c-ares` | `1.34.4` | `1` | 0 | 0 | yes | no | no |
| opt | `cairo` | `cairo` | `1.18.2` | `1` | 7 | 0 | yes | no | no |
| opt | `cairomm` | `cairomm` | `1.18.0` | `1` | 2 | 0 | yes | no | no |
| opt | `cairomm-1.0` | `cairomm-1.0` | `1.14.5` | `1` | 2 | 0 | yes | no | no |
| opt | `cbindgen` | `cbindgen` | `0.29.0` | `1` | 1 | 0 | yes | no | no |
| opt | `cdparanoia` | `cdparanoia` | `10.2` | `1` | 0 | 0 | yes | no | no |
| opt | `cdrdao` | `cdrdao` | `1.2.4` | `1` | 4 | 0 | yes | no | no |
| opt | `cdrtools` | `cdrtools` | `3.02a09` | `2` | 0 | 0 | yes | no | no |
| opt | `chrpath` | `chrpath` | `0.18` | `1` | 0 | 0 | yes | no | no |
| opt | `colord` | `colord` | `1.4.7` | `1` | 10 | 0 | yes | no | no |
| opt | `colord-gtk` | `colord-gtk` | `0.3.1` | `1` | 6 | 0 | yes | no | no |
| opt | `consolekit` | `consolekit` | `1.2.6` | `1` | 4 | 0 | yes | no | no |
| opt | `cpio` | `cpio` | `2.15` | `1` | 0 | 0 | yes | no | no |
| opt | `cracklib-words` | `cracklib-words` | `2.9.11.xz` | `1` | 1 | 0 | yes | no | no |
| opt | `cryptsetup` | `cryptsetup` | `2.8.7` | `1` | 4 | 0 | yes | no | no |
| opt | `cups` | `cups` | `2.4.12` | `1` | 8 | 0 | yes | no | no |
| opt | `cups-filters` | `cups-filters` | `2.0.1` | `1` | 2 | 0 | yes | no | no |
| opt | `cyrus-sasl` | `cyrus-sasl` | `2.1.28` | `1` | 1 | 0 | yes | no | no |
| opt | `dbus-glib` | `dbus-glib` | `0.112` | `2` | 2 | 0 | yes | no | no |
| opt | `dbus-python` | `dbus-python` | `1.3.2` | `1` | 4 | 0 | yes | no | no |
| opt | `dconf-editor` | `dconf-editor` | `45.0.1` | `1` | 1 | 0 | yes | no | no |
| opt | `dejagnu` | `dejagnu` | `1.6.3` | `1` | 0 | 0 | yes | no | no |
| opt | `desktop-file-utils` | `desktop-file-utils` | `0.28` | `1` | 1 | 0 | yes | no | no |
| opt | `dhcpcd` | `dhcpcd` | `10.2.0` | `1` | 0 | 0 | yes | no | no |
| opt | `directx-headers` | `directx-headers` | `1.615.0` | `1` | 0 | 0 | yes | no | no |
| opt | `discord` | `discord` | `0.0.97` | `1` | 11 | 0 | yes | no | no |
| opt | `docbook-xml` | `docbook-xml` | `4.5` | `8` | 2 | 0 | yes | no | no |
| opt | `docbook-xsl-nons` | `docbook-xsl-nons` | `1.79.2` | `4` | 2 | 0 | yes | no | no |
| opt | `double-conversion` | `double-conversion` | `3.3.1` | `1` | 1 | 0 | yes | no | no |
| opt | `doxygen` | `doxygen` | `1.12.0` | `1` | 2 | 0 | yes | no | no |
| opt | `duktape` | `duktape` | `2.7.0` | `2` | 0 | 0 | yes | no | no |
| opt | `dvd+rw-tools` | `dvd+rw-tools` | `7.1` | `1` | 1 | 0 | yes | no | no |
| opt | `enchant` | `enchant` | `2.8.2` | `1` | 2 | 0 | yes | no | no |
| opt | `eudev` | `eudev` | `3.2.14` | `1` | 0 | 0 | yes | no | no |
| opt | `exempi` | `exempi` | `2.6.5` | `1` | 2 | 0 | yes | no | no |
| opt | `exiv2` | `exiv2` | `0.28.5` | `1` | 4 | 0 | yes | no | no |
| opt | `expect` | `expect` | `5.45.4` | `1` | 1 | 0 | yes | no | no |
| opt | `faad2` | `faad2` | `2.11.1` | `1` | 1 | 0 | yes | no | no |
| opt | `faudio` | `faudio` | `25.02` | `1` | 2 | 0 | yes | no | no |
| opt | `fdk-aac` | `fdk-aac` | `2.0.3` | `2` | 0 | 0 | yes | no | no |
| opt | `ffmpeg` | `ffmpeg` | `9.0.1` | `2` | 13 | 0 | yes | no | no |
| opt | `fftw` | `fftw` | `3.3.10` | `1` | 0 | 0 | yes | no | no |
| opt | `firefox` | `firefox` | `154.0` | `3` | 14 | 0 | yes | no | no |
| opt | `firefox-bin` | `firefox-bin` | `139.0.4` | `1` | 4 | 0 | yes | no | no |
| opt | `flac` | `flac` | `1.4.3` | `1` | 0 | 0 | yes | no | no |
| opt | `fltk` | `fltk` | `1.3.8` | `1` | 5 | 0 | yes | no | no |
| opt | `freeglut` | `freeglut` | `3.4.0` | `1` | 3 | 0 | yes | no | no |
| opt | `freerdp` | `freerdp` | `3.11.1` | `1` | 11 | 0 | yes | no | no |
| opt | `freetype2` | `freetype2` | `2.13.2` | `1` | 2 | 0 | yes | no | no |
| opt | `frei0r-plugins` | `frei0r-plugins` | `1.8.0` | `1` | 1 | 0 | yes | no | no |
| opt | `fribidi` | `fribidi` | `1.0.16` | `1` | 0 | 0 | yes | no | no |
| opt | `ftjam` | `ftjam` | `2.5.2` | `1` | 0 | 0 | yes | no | no |
| opt | `fuse2` | `fuse2` | `2.9.9` | `1` | 0 | 0 | yes | no | no |
| opt | `gavl` | `gavl` | `1.4.0` | `1` | 1 | 0 | yes | no | no |
| opt | `gdb` | `gdb` | `15.2` | `1` | 7 | 0 | yes | no | no |
| opt | `gdk-pixbuf` | `gdk-pixbuf` | `2.42.12` | `1` | 4 | 0 | yes | no | no |
| opt | `geoclue` | `geoclue` | `2.7.1` | `1` | 6 | 0 | yes | no | no |
| opt | `ghostscript` | `ghostscript` | `10.03.1` | `1` | 5 | 0 | yes | no | no |
| opt | `giflib` | `giflib` | `5.2.2` | `1` | 1 | 0 | yes | no | no |
| opt | `git` | `git` | `2.55.0` | `4` | 2 | 0 | yes | no | no |
| opt | `glib` | `glib` | `2.84.2` | `1` | 3 | 0 | yes | no | no |
| opt | `glib-networking` | `glib-networking` | `2.80.0` | `1` | 2 | 0 | yes | no | no |
| opt | `glibmm` | `glibmm` | `2.84.0` | `1` | 2 | 0 | yes | no | no |
| opt | `glibmm-2.68` | `glibmm-2.68` | `2.82.0` | `1` | 2 | 0 | yes | no | no |
| opt | `glslang` | `glslang` | `15.1.0` | `1` | 2 | 0 | yes | no | no |
| opt | `gnupg` | `gnupg` | `2.5.4` | `1` | 7 | 0 | yes | no | no |
| opt | `gnutls` | `gnutls` | `3.8.13` | `1` | 4 | 0 | yes | no | no |
| opt | `gobject-introspection` | `gobject-introspection` | `1.84.0` | `1` | 1 | 0 | yes | no | no |
| opt | `gparted` | `gparted` | `1.5.0` | `1` | 5 | 0 | yes | no | no |
| opt | `gpgme` | `gpgme` | `1.24.0` | `1` | 1 | 0 | yes | no | no |
| opt | `gpm` | `gpm` | `1.20.7` | `2` | 0 | 0 | yes | no | no |
| opt | `grantlee` | `grantlee` | `5.3.1` | `1` | 2 | 0 | yes | no | no |
| opt | `graphene` | `graphene` | `1.10.8` | `1` | 2 | 0 | yes | no | no |
| opt | `graphite2` | `graphite2` | `1.3.14` | `1` | 2 | 0 | yes | no | no |
| opt | `graphviz` | `graphviz` | `12.2.0` | `1` | 3 | 0 | yes | no | no |
| opt | `gsl` | `gsl` | `2.8` | `1` | 0 | 0 | yes | no | no |
| opt | `gspell` | `gspell` | `1.12.2` | `1` | 7 | 0 | yes | no | no |
| opt | `gst-libav` | `gst-libav` | `1.24.12` | `1` | 3 | 0 | yes | no | no |
| opt | `gst-plugins-bad` | `gst-plugins-bad` | `1.26.2` | `1` | 4 | 0 | yes | no | no |
| opt | `gst-plugins-base` | `gst-plugins-base` | `1.26.2` | `1` | 3 | 0 | yes | no | no |
| opt | `gst-plugins-good` | `gst-plugins-good` | `1.26.2` | `2` | 11 | 0 | yes | no | no |
| opt | `gst-plugins-ugly` | `gst-plugins-ugly` | `1.26.2` | `1` | 6 | 0 | yes | no | no |
| opt | `gstreamer` | `gstreamer` | `1.26.2` | `1` | 2 | 0 | yes | no | no |
| opt | `gtk` | `gtk` | `2.24.33` | `1` | 5 | 0 | yes | no | no |
| opt | `gtk-doc` | `gtk-doc` | `1.34.0` | `1` | 5 | 0 | yes | no | no |
| opt | `gtk-vnc` | `gtk-vnc` | `1.3.1` | `1` | 6 | 0 | yes | no | no |
| opt | `gtk3` | `gtk3` | `3.24.49` | `1` | 5 | 0 | yes | no | no |
| opt | `gtk4` | `gtk4` | `4.18.5` | `1` | 21 | 0 | yes | no | no |
| opt | `gtkmm` | `gtkmm` | `4.14.0` | `1` | 4 | 0 | yes | no | no |
| opt | `gtkmm3` | `gtkmm3` | `3.24.10` | `1` | 6 | 0 | yes | no | no |
| opt | `gtksourceview` | `gtksourceview` | `5.14.0` | `1` | 8 | 0 | yes | no | no |
| opt | `gutenprint` | `gutenprint` | `5.3.4` | `1` | 2 | 0 | yes | no | no |
| opt | `gvim` | `gvim` | `9.1.1055` | `1` | 3 | 0 | yes | no | no |
| opt | `harfbuzz` | `harfbuzz` | `11.0.0` | `1` | 3 | 0 | yes | no | no |
| opt | `hexchat` | `hexchat` | `2.16.2` | `1` | 5 | 0 | yes | no | no |
| opt | `hicolor-icon-theme` | `hicolor-icon-theme` | `0.18` | `1` | 0 | 0 | yes | no | no |
| opt | `highlight` | `highlight` | `4.12` | `1` | 3 | 0 | yes | no | no |
| opt | `highway` | `highway` | `1.1.0` | `1` | 1 | 0 | yes | no | no |
| opt | `hwdata` | `hwdata` | `0.382` | `1` | 0 | 0 | yes | no | no |
| opt | `hyphen` | `hyphen` | `2.8.8` | `1` | 0 | 0 | yes | no | no |
| opt | `ibus` | `ibus` | `1.5.32` | `1` | 8 | 0 | yes | no | no |
| opt | `icon-naming-utils` | `icon-naming-utils` | `0.8.90` | `1` | 1 | 0 | yes | no | no |
| opt | `icu` | `icu` | `77.1` | `1` | 0 | 0 | yes | no | no |
| opt | `imagemagick` | `imagemagick` | `47` | `1` | 22 | 0 | yes | no | no |
| opt | `imlib2` | `imlib2` | `1.12.4` | `1` | 9 | 0 | yes | no | no |
| opt | `iniparser` | `iniparser` | `4.1` | `1` | 1 | 0 | yes | no | no |
| opt | `isl` | `isl` | `0.27` | `1` | 0 | 0 | yes | no | no |
| opt | `iso-codes` | `iso-codes` | `4.16.0` | `1` | 2 | 0 | yes | no | no |
| opt | `itstool` | `itstool` | `2.0.7` | `3` | 1 | 0 | yes | no | no |
| opt | `jansson` | `jansson` | `2.14.1` | `1` | 0 | 0 | yes | no | no |
| opt | `jasper` | `jasper` | `4.2.5` | `1` | 2 | 0 | yes | no | no |
| opt | `jq` | `jq` | `1.7.1` | `1` | 1 | 0 | yes | no | no |
| opt | `json-c` | `json-c` | `0.19` | `1` | 0 | 0 | yes | no | no |
| opt | `json-glib` | `json-glib` | `1.10.6` | `1` | 1 | 0 | yes | no | no |
| opt | `kColorPicker` | `kColorPicker` | `0.3.1` | `1` | 2 | 0 | yes | no | no |
| opt | `kImageAnnotator` | `kImageAnnotator` | `0.6.1` | `1` | 1 | 0 | yes | no | no |
| opt | `kdsoap` | `kdsoap` | `2.1.1` | `1` | 1 | 0 | yes | no | no |
| opt | `kerberos` | `kerberos` | `1.21.3` | `1` | 0 | 0 | yes | no | no |
| opt | `keybinder-3.0` | `keybinder-3.0` | `0.3.2` | `1` | 3 | 0 | yes | no | no |
| opt | `keyutils` | `keyutils` | `1.6.3` | `1` | 0 | 0 | yes | no | no |
| opt | `lame` | `lame` | `3.100` | `1` | 0 | 0 | yes | no | no |
| opt | `lapack` | `lapack` | `3.12.0` | `1` | 2 | 0 | yes | no | no |
| opt | `lcms2` | `lcms2` | `2.17` | `1` | 1 | 0 | yes | no | no |
| opt | `liba52` | `liba52` | `0.8.0` | `1` | 0 | 0 | yes | no | no |
| opt | `libadwaita` | `libadwaita` | `1.6.4` | `1` | 3 | 0 | yes | no | no |
| opt | `libao` | `libao` | `1.2.2` | `1` | 0 | 0 | yes | no | no |
| opt | `libaom` | `libaom` | `3.9.1` | `1` | 2 | 0 | yes | no | no |
| opt | `libass` | `libass` | `0.17.3` | `1` | 4 | 0 | yes | no | no |
| opt | `libassuan` | `libassuan` | `3.0.2` | `1` | 1 | 0 | yes | no | no |
| opt | `libatasmart` | `libatasmart` | `0.19` | `1` | 0 | 0 | yes | no | no |
| opt | `libavif` | `libavif` | `1.1.1` | `1` | 2 | 0 | yes | no | no |
| opt | `libblockdev` | `libblockdev` | `3.2.1` | `1` | 11 | 0 | yes | no | no |
| opt | `libburn` | `libburn` | `1.5.6` | `1` | 1 | 0 | yes | no | no |
| opt | `libbytesize` | `libbytesize` | `2.9` | `1` | 2 | 0 | yes | no | no |
| opt | `libcanberra` | `libcanberra` | `0.30` | `1` | 5 | 0 | yes | no | no |
| opt | `libcddb` | `libcddb` | `1.3.2` | `1` | 0 | 0 | yes | no | no |
| opt | `libcdio` | `libcdio` | `2.1.0` | `1` | 1 | 0 | yes | no | no |
| opt | `libcdio-paranoia` | `libcdio-paranoia` | `10.2+2.0.1` | `1` | 1 | 0 | yes | no | no |
| opt | `libclc` | `libclc` | `20.1.1.src` | `1` | 1 | 0 | yes | no | no |
| opt | `libcloudproviders` | `libcloudproviders` | `0.3.6` | `1` | 3 | 0 | yes | no | no |
| opt | `libcupsfilters` | `libcupsfilters` | `2.1.1` | `1` | 11 | 0 | yes | no | no |
| opt | `libdaemon` | `libdaemon` | `0.14` | `1` | 0 | 0 | yes | no | no |
| opt | `libdecor` | `libdecor` | `0.2.2` | `1` | 3 | 0 | yes | no | no |
| opt | `libdisplay-info` | `libdisplay-info` | `0.2.0` | `1` | 1 | 0 | yes | no | no |
| opt | `libdv` | `libdv` | `1.0.0` | `1` | 2 | 0 | yes | no | no |
| opt | `libdvdcss` | `libdvdcss` | `1.4.3` | `1` | 0 | 0 | yes | no | no |
| opt | `libdvdnav` | `libdvdnav` | `6.1.1` | `1` | 1 | 0 | yes | no | no |
| opt | `libdvdread` | `libdvdread` | `6.1.3` | `1` | 1 | 0 | yes | no | no |
| opt | `libedit` | `libedit` | `20230828_3.1` | `1` | 0 | 0 | yes | no | no |
| opt | `libei` | `libei` | `1.3.0` | `1` | 1 | 0 | yes | no | no |
| opt | `libexif` | `libexif` | `0.6.25` | `1` | 0 | 0 | yes | no | no |
| opt | `libgcrypt` | `libgcrypt` | `1.11.2` | `1` | 1 | 0 | yes | no | no |
| opt | `libglade` | `libglade` | `2.6.4` | `1` | 2 | 0 | yes | no | no |
| opt | `libgpg-error` | `libgpg-error` | `1.56` | `2` | 0 | 0 | yes | no | no |
| opt | `libgsf` | `libgsf` | `1.14.52` | `1` | 3 | 0 | yes | no | no |
| opt | `libgudev` | `libgudev` | `238` | `1` | 2 | 0 | yes | no | no |
| opt | `libgusb` | `libgusb` | `0.4.9` | `1` | 10 | 0 | yes | no | no |
| opt | `libgxps` | `libgxps` | `0.3.2` | `1` | 6 | 0 | yes | no | no |
| opt | `libhandy` | `libhandy` | `1.8.3` | `1` | 2 | 0 | yes | no | no |
| opt | `libical` | `libical` | `3.0.20` | `1` | 3 | 0 | yes | no | no |
| opt | `libidn` | `libidn` | `1.43` | `1` | 0 | 0 | yes | no | no |
| opt | `libidn2` | `libidn2` | `2.3.7` | `1` | 1 | 0 | yes | no | no |
| opt | `libisoburn` | `libisoburn` | `1.5.6` | `1` | 2 | 0 | yes | no | no |
| opt | `libisofs` | `libisofs` | `1.5.6` | `1` | 0 | 0 | yes | no | no |
| opt | `libjpeg-turbo` | `libjpeg-turbo` | `3.1.1` | `1` | 2 | 0 | yes | no | no |
| opt | `libjxl` | `libjxl` | `0.11.1` | `1` | 8 | 0 | yes | no | no |
| opt | `libksba` | `libksba` | `1.6.7` | `1` | 1 | 0 | yes | no | no |
| opt | `libmad` | `libmad` | `0.15.1b` | `1` | 0 | 0 | yes | no | no |
| opt | `libmbim` | `libmbim` | `1.26.4` | `1` | 1 | 0 | yes | no | no |
| opt | `libmng` | `libmng` | `2.0.3` | `1` | 2 | 0 | yes | no | no |
| opt | `libmpeg2` | `libmpeg2` | `0.5.1` | `1` | 1 | 0 | yes | no | no |
| opt | `libmusicbrainz` | `libmusicbrainz` | `5.1.0` | `1` | 3 | 0 | yes | no | no |
| opt | `libmusicbrainz5` | `libmusicbrainz5` | `5.1.0` | `1` | 4 | 0 | yes | no | no |
| opt | `libndp` | `libndp` | `1.9` | `1` | 0 | 0 | yes | no | no |
| opt | `libnghttp2` | `libnghttp2` | `1.64.0` | `2` | 0 | 0 | yes | no | no |
| opt | `libnma` | `libnma` | `1.10.6` | `2` | 4 | 0 | yes | no | no |
| opt | `libnotify` | `libnotify` | `0.8.6` | `1` | 1 | 0 | yes | no | no |
| opt | `libnvme` | `libnvme` | `1.14` | `1` | 0 | 0 | yes | no | no |
| opt | `libogg` | `libogg` | `1.3.5` | `1` | 0 | 0 | yes | no | no |
| opt | `libpaper` | `libpaper` | `2.2.5` | `1` | 0 | 0 | yes | no | no |
| opt | `libpcap` | `libpcap` | `1.10.4` | `1` | 0 | 0 | yes | no | no |
| opt | `libportal` | `libportal` | `0.8.0` | `1` | 7 | 0 | yes | no | no |
| opt | `libppd` | `libppd` | `2.1.1` | `1` | 1 | 0 | yes | no | no |
| opt | `libpsl` | `libpsl` | `0.21.5` | `1` | 2 | 0 | yes | no | no |
| opt | `libpwquality` | `libpwquality` | `1.4.5` | `1` | 2 | 0 | yes | no | no |
| opt | `libqalculate` | `libqalculate` | `5.5.2` | `1` | 3 | 0 | yes | no | no |
| opt | `libqmi` | `libqmi` | `1.30.8` | `1` | 4 | 0 | yes | no | no |
| opt | `libraw` | `libraw` | `0.21.2` | `1` | 3 | 0 | yes | no | no |
| opt | `libsamplerate` | `libsamplerate` | `0.2.2` | `1` | 0 | 0 | yes | no | no |
| opt | `libsass` | `libsass` | `3.6.5` | `1` | 1 | 0 | yes | no | no |
| opt | `libsdl` | `libsdl` | `1.2.15` | `5` | 2 | 0 | yes | no | no |
| opt | `libseccomp` | `libseccomp` | `2.6.0` | `1` | 0 | 0 | yes | no | no |
| opt | `libsecret` | `libsecret` | `0.21.7` | `1` | 10 | 0 | yes | no | no |
| opt | `libsigc++` | `libsigc++` | `3.6.0` | `1` | 1 | 0 | yes | no | no |
| opt | `libsigc++2` | `libsigc++2` | `2.12.1` | `1` | 1 | 0 | yes | no | no |
| opt | `libsndfile` | `libsndfile` | `1.2.2` | `1` | 0 | 0 | yes | no | no |
| opt | `libsoup` | `libsoup` | `2.74.3` | `1` | 5 | 0 | yes | no | no |
| opt | `libsoup3` | `libsoup3` | `3.6.5` | `1` | 5 | 0 | yes | no | no |
| opt | `libssh2` | `libssh2` | `1.11.1` | `1` | 0 | 0 | yes | no | no |
| opt | `libstatgrab` | `libstatgrab` | `0.92.1` | `1` | 0 | 0 | yes | no | no |
| opt | `libtasn1` | `libtasn1` | `4.21.0` | `1` | 0 | 0 | yes | no | no |
| opt | `libtheora` | `libtheora` | `1.2.0` | `1` | 1 | 0 | yes | no | no |
| opt | `libtiff` | `libtiff` | `4.7.0` | `1` | 2 | 0 | yes | no | no |
| opt | `libtraceevent` | `libtraceevent` | `1.8.4` | `2` | 0 | 0 | yes | no | no |
| opt | `libtracefs` | `libtracefs` | `1.8.2` | `1` | 1 | 0 | yes | no | no |
| opt | `libunistring` | `libunistring` | `1.3` | `1` | 0 | 0 | yes | no | no |
| opt | `libusb` | `libusb` | `1.0.28` | `1` | 0 | 0 | yes | no | no |
| opt | `libvisual` | `libvisual` | `0.4.2` | `1` | 2 | 0 | yes | no | no |
| opt | `libvorbis` | `libvorbis` | `1.3.7` | `1` | 1 | 0 | yes | no | no |
| opt | `libvpx` | `libvpx` | `1.15.2` | `2` | 3 | 0 | yes | no | no |
| opt | `libwacom` | `libwacom` | `2.14.0` | `1` | 3 | 0 | yes | no | no |
| opt | `libwebp` | `libwebp` | `1.5.0` | `1` | 0 | 0 | yes | no | no |
| opt | `libxklavier` | `libxklavier` | `5.4` | `1` | 6 | 0 | yes | no | no |
| opt | `libxml2` | `libxml2` | `2.15.3` | `1` | 0 | 0 | yes | no | no |
| opt | `libxmlb` | `libxmlb` | `0.3.19` | `1` | 3 | 0 | yes | no | no |
| opt | `libxslt` | `libxslt` | `1.1.42` | `2` | 2 | 0 | yes | no | no |
| opt | `links` | `links` | `2.30` | `1` | 2 | 0 | yes | no | no |
| opt | `lld` | `lld` | `20.1.1` | `1` | 1 | 0 | yes | no | no |
| opt | `llvm` | `llvm` | `22.1.8` | `2` | 4 | 0 | yes | no | no |
| opt | `lm-sensors` | `lm-sensors` | `3-6-0` | `1` | 1 | 0 | yes | no | no |
| opt | `lmdb` | `lmdb` | `0.9.31` | `1` | 0 | 0 | yes | no | no |
| opt | `lua` | `lua` | `5.4.7` | `1` | 0 | 0 | yes | no | no |
| opt | `lua52` | `lua52` | `5.2.4` | `4` | 1 | 0 | yes | no | no |
| opt | `lynx` | `lynx` | `2.8.9rel.1` | `1` | 0 | 0 | yes | no | no |
| opt | `mingw-ccache-bindings` | `mingw-ccache-bindings` | `10.2.0` | `1` | 2 | 0 | yes | no | no |
| opt | `mingw-w64-binutils` | `mingw-w64-binutils` | `2.39` | `1` | 0 | 0 | yes | no | no |
| opt | `mingw-w64-crt` | `mingw-w64-crt` | `12.0.0` | `1` | 0 | 0 | yes | no | no |
| opt | `mingw-w64-gcc` | `mingw-w64-gcc` | `13.1.0` | `1` | 3 | 0 | yes | no | no |
| opt | `mingw-w64-headers` | `mingw-w64-headers` | `12.0.0` | `1` | 0 | 0 | yes | no | no |
| opt | `mlt` | `mlt` | `7.32.0` | `1` | 3 | 0 | yes | no | no |
| opt | `mm-common` | `mm-common` | `1.0.5` | `1` | 0 | 0 | yes | no | no |
| opt | `mobile-broadband-provider-info` | `mobile-broadband-provider-info` | `20230416` | `1` | 0 | 0 | yes | no | no |
| opt | `modemmanager` | `modemmanager` | `1.18.12` | `1` | 6 | 0 | yes | no | no |
| opt | `mpg123` | `mpg123` | `1.33.0` | `1` | 1 | 0 | yes | no | no |
| opt | `mupdf` | `mupdf` | `1.25.4` | `1` | 4 | 0 | yes | no | no |
| opt | `ndctl` | `ndctl` | `82` | `1` | 7 | 0 | yes | no | no |
| opt | `neon` | `neon` | `0.33.0` | `1` | 0 | 0 | yes | no | no |
| opt | `net-tools` | `net-tools` | `2.10` | `1` | 0 | 0 | yes | no | no |
| opt | `nettle` | `nettle` | `4.0` | `1` | 1 | 0 | yes | no | no |
| opt | `networkmanager` | `networkmanager` | `1.58.0` | `2` | 12 | 0 | yes | no | no |
| opt | `newt` | `newt` | `0.52.24` | `1` | 2 | 0 | yes | no | no |
| opt | `nodejs` | `nodejs` | `24.2.0` | `1` | 4 | 0 | yes | no | no |
| opt | `npth` | `npth` | `1.7` | `1` | 0 | 0 | yes | no | no |
| opt | `nspr` | `nspr` | `4.36` | `1` | 0 | 0 | yes | no | no |
| opt | `nss` | `nss` | `3.112` | `1` | 1 | 0 | yes | no | no |
| opt | `nvidia` | `nvidia` | `550.127.05` | `1` | 3 | 0 | yes | no | no |
| opt | `oniguruma` | `oniguruma` | `6.9.9` | `1` | 0 | 0 | yes | no | no |
| opt | `openal` | `openal` | `1.24.3` | `1` | 1 | 0 | yes | no | no |
| opt | `openbox` | `openbox` | `3.6.1` | `1` | 7 | 0 | yes | no | no |
| opt | `opencv` | `opencv` | `4.11.0` | `1` | 13 | 0 | yes | no | no |
| opt | `openjpeg2` | `openjpeg2` | `2.5.3` | `1` | 1 | 0 | yes | no | no |
| opt | `openldap` | `openldap` | `2.6.8` | `1` | 4 | 0 | yes | no | no |
| opt | `opentimelineio` | `opentimelineio` | `0.17.0` | `1` | 0 | 0 | yes | no | no |
| opt | `opus` | `opus` | `1.5.2` | `2` | 0 | 0 | yes | no | no |
| opt | `orc` | `orc` | `0.4.41` | `1` | 0 | 0 | yes | no | no |
| opt | `oxygen-icons5` | `oxygen-icons5` | `5.109.0` | `1` | 2 | 0 | yes | no | no |
| opt | `p11-kit` | `p11-kit` | `0.26.4` | `1` | 2 | 0 | yes | no | no |
| opt | `p5-uri` | `p5-uri` | `5.29` | `1` | 1 | 0 | yes | no | no |
| opt | `p7zip` | `p7zip` | `17.04` | `1` | 0 | 0 | yes | no | no |
| opt | `pango` | `pango` | `1.56.1` | `1` | 4 | 0 | yes | no | no |
| opt | `pangomm` | `pangomm` | `2.46.4` | `1` | 3 | 0 | yes | no | no |
| opt | `pangomm-2.48` | `pangomm-2.48` | `2.56.1` | `1` | 3 | 0 | yes | no | no |
| opt | `parted` | `parted` | `3.6` | `1` | 1 | 0 | yes | no | no |
| opt | `patchelf` | `patchelf` | `0.18.0` | `1` | 0 | 0 | yes | no | no |
| opt | `pavucontrol` | `pavucontrol` | `6.1` | `1` | 5 | 0 | yes | no | no |
| opt | `pcre` | `pcre` | `8.45` | `1` | 0 | 0 | yes | no | no |
| opt | `perl-parse-yapp` | `perl-parse-yapp` | `1.21` | `1` | 0 | 0 | yes | no | no |
| opt | `perl-xml-simple` | `perl-xml-simple` | `2.25` | `1` | 0 | 0 | yes | no | no |
| opt | `pinentry` | `pinentry` | `1.3.1` | `1` | 2 | 0 | yes | no | no |
| opt | `pipewire` | `pipewire` | `1.4.5` | `1` | 6 | 0 | yes | no | no |
| opt | `polkit` | `polkit` | `126` | `1` | 8 | 0 | yes | no | no |
| opt | `poppler` | `poppler` | `25.02.0` | `1` | 12 | 0 | yes | no | no |
| opt | `poppler-data` | `poppler-data` | `0.4.12` | `1` | 0 | 0 | yes | no | no |
| opt | `potrace` | `potrace` | `1.16` | `1` | 1 | 0 | yes | no | no |
| opt | `power-profiles-daemon` | `power-profiles-daemon` | `0.30` | `1` | 3 | 0 | yes | no | no |
| opt | `protobuf` | `protobuf` | `31.1` | `1` | 2 | 0 | yes | no | no |
| opt | `protobuf-c` | `protobuf-c` | `1.5.0` | `1` | 1 | 0 | yes | no | no |
| opt | `pth` | `pth` | `2.0.7` | `1` | 0 | 0 | yes | no | no |
| opt | `publicsuffix-list` | `publicsuffix-list` | `20230812.1829.5e6ac3a` | `1` | 0 | 0 | yes | no | no |
| opt | `pulseaudio` | `pulseaudio` | `17.0` | `1` | 1 | 0 | yes | no | no |
| opt | `qca` | `qca` | `2.3.10` | `2` | 3 | 0 | yes | no | no |
| opt | `qcoro` | `qcoro` | `0.10.0` | `1` | 0 | 0 | yes | no | no |
| opt | `qpdf` | `qpdf` | `11.10.1` | `1` | 3 | 0 | yes | no | no |
| opt | `qrencode` | `qrencode` | `4.1.1` | `1` | 1 | 0 | yes | no | no |
| opt | `qt5` | `qt5` | `5.15.19` | `3` | 26 | 0 | yes | no | yes |
| opt | `qt6` | `qt6` | `6.11.2` | `2` | 25 | 0 | yes | no | no |
| opt | `robin-hood-hashing` | `robin-hood-hashing` | `3.11.5` | `2` | 0 | 0 | yes | no | no |
| opt | `rpcsvc-proto` | `rpcsvc-proto` | `1.4.4` | `1` | 0 | 0 | yes | no | no |
| opt | `ruby` | `ruby` | `3.4.2` | `1` | 4 | 0 | yes | no | no |
| opt | `rust-bindgen` | `rust-bindgen` | `0.70.1` | `1` | 2 | 0 | yes | no | no |
| opt | `rustc` | `rustc` | `1.97.1` | `2` | 4 | 0 | yes | no | no |
| opt | `samba` | `samba` | `4.21.4` | `1` | 33 | 0 | yes | no | no |
| opt | `sassc` | `sassc` | `3.6.2` | `1` | 1 | 0 | yes | no | no |
| opt | `sbc` | `sbc` | `2.1` | `1` | 1 | 0 | yes | no | no |
| opt | `scons` | `scons` | `4.9.1` | `1` | 0 | 0 | yes | no | no |
| opt | `sdl` | `sdl` | `1.2.15` | `5` | 2 | 0 | yes | no | no |
| opt | `sdl12-compat` | `sdl12-compat` | `1.2.64` | `1` | 3 | 0 | yes | no | no |
| opt | `sdl2` | `sdl2` | `2.32.8` | `2` | 2 | 0 | yes | no | no |
| opt | `sentry_sdk` | `sentry_sdk` | `2.2.1` | `1` | 2 | 0 | yes | no | no |
| opt | `serf` | `serf` | `1.3.10` | `1` | 2 | 0 | yes | no | no |
| opt | `sgml-common` | `sgml-common` | `0.6.3` | `1` | 0 | 0 | yes | no | no |
| opt | `shaderc` | `shaderc` | `2024.1` | `1` | 1 | 0 | yes | no | no |
| opt | `shared-mime-info` | `shared-mime-info` | `2.4` | `2` | 2 | 0 | yes | no | no |
| opt | `slang` | `slang` | `2.3.3` | `1` | 0 | 0 | yes | no | no |
| opt | `smartmontools` | `smartmontools` | `7.4` | `1` | 0 | 0 | yes | no | no |
| opt | `smartypants` | `smartypants` | `2.0.1` | `1` | 0 | 0 | yes | no | no |
| opt | `snapper` | `snapper` | `0.13.1` | `1` | 7 | 0 | yes | no | no |
| opt | `socat` | `socat` | `1.8.0.2` | `1` | 2 | 0 | yes | no | no |
| opt | `soundtouch` | `soundtouch` | `2.3.3` | `1` | 0 | 0 | yes | no | no |
| opt | `speex` | `speex` | `1.2.1` | `3` | 1 | 0 | yes | no | no |
| opt | `spirv-headers` | `spirv-headers` | `1.4.309.0` | `1` | 1 | 0 | yes | no | no |
| opt | `spirv-llvm-translator` | `spirv-llvm-translator` | `20.1.0` | `1` | 3 | 0 | yes | no | no |
| opt | `spirv-tools` | `spirv-tools` | `1.4.304.1` | `1` | 2 | 0 | yes | no | no |
| opt | `startup-notification` | `startup-notification` | `0.12` | `1` | 2 | 0 | yes | no | no |
| opt | `subversion` | `subversion` | `1.14.5` | `1` | 4 | 0 | yes | no | no |
| opt | `swig` | `swig` | `4.3.0` | `1` | 1 | 0 | yes | no | no |
| opt | `sysklogd` | `sysklogd` | `2.7.2` | `1` | 0 | 0 | yes | no | no |
| opt | `syslinux` | `syslinux` | `6.03` | `1` | 1 | 0 | yes | no | no |
| opt | `taglib` | `taglib` | `2.0.2` | `1` | 2 | 0 | yes | no | no |
| opt | `tcl` | `tcl` | `8.6.18` | `1` | 0 | 0 | yes | no | no |
| opt | `texlive` | `texlive` | `20250308` | `3` | 8 | 0 | yes | no | yes |
| opt | `udisks` | `udisks` | `2.10.1` | `1` | 6 | 0 | yes | no | no |
| opt | `uhttpmock` | `uhttpmock` | `0.11.0` | `1` | 3 | 0 | yes | no | no |
| opt | `umockdev` | `umockdev` | `0.18.3` | `1` | 3 | 0 | yes | no | no |
| opt | `unicode-character-database` | `unicode-character-database` | `15.1.0` | `1` | 0 | 0 | yes | no | no |
| opt | `unifdef` | `unifdef` | `2.12` | `1` | 0 | 0 | yes | no | no |
| opt | `unrar` | `unrar` | `7.1.7` | `1` | 0 | 0 | yes | no | no |
| opt | `unzip` | `unzip` | `6.0` | `8` | 0 | 0 | yes | no | no |
| opt | `upower` | `upower` | `v1.90.8` | `1` | 3 | 0 | yes | no | no |
| opt | `utfcpp` | `utfcpp` | `4.0.5` | `1` | 1 | 0 | yes | no | no |
| opt | `v4l-utils` | `v4l-utils` | `1.30.1` | `2` | 5 | 0 | yes | no | no |
| opt | `vala` | `vala` | `0.56.18` | `1` | 2 | 0 | yes | no | no |
| opt | `valgrind` | `valgrind` | `3.24.0` | `1` | 0 | 0 | yes | no | no |
| opt | `vlc` | `vlc` | `3.0.21` | `1` | 48 | 0 | yes | no | no |
| opt | `volk` | `volk` | `1.3.296.0` | `1` | 1 | 0 | yes | no | no |
| opt | `vulkan-headers` | `vulkan-headers` | `1.4.304` | `1` | 1 | 0 | yes | no | no |
| opt | `vulkan-loader` | `vulkan-loader` | `1.4.304` | `1` | 4 | 0 | yes | no | no |
| opt | `vulkan-utility-libraries` | `vulkan-utility-libraries` | `1.4.304.1` | `1` | 1 | 0 | yes | no | no |
| opt | `vulkan-validation-layers` | `vulkan-validation-layers` | `1.4.304.1` | `1` | 4 | 0 | yes | no | no |
| opt | `webp-pixbuf-loader` | `webp-pixbuf-loader` | `0.2.7` | `1` | 2 | 0 | yes | no | no |
| opt | `wget` | `wget` | `2.2.1` | `1` | 6 | 0 | yes | no | no |
| opt | `wgetpaste` | `wgetpaste` | `2.33` | `1` | 1 | 0 | yes | no | no |
| opt | `wireless-regdb` | `wireless-regdb` | `2026.05.30` | `1` | 0 | 0 | yes | no | no |
| opt | `wireplumber` | `wireplumber` | `0.5.2` | `1` | 5 | 0 | yes | no | no |
| opt | `woff2` | `woff2` | `1.0.2` | `1` | 2 | 0 | yes | no | no |
| opt | `x264` | `x264` | `20250212` | `1` | 1 | 0 | yes | no | no |
| opt | `x265` | `x265` | `4.1` | `1` | 2 | 0 | yes | no | no |
| opt | `xapian` | `xapian` | `1.4.25` | `1` | 0 | 0 | yes | no | no |
| opt | `xdg-dbus-proxy` | `xdg-dbus-proxy` | `0.1.6` | `1` | 1 | 0 | yes | no | no |
| opt | `xdg-desktop-portal` | `xdg-desktop-portal` | `1.18.4` | `1` | 6 | 0 | yes | no | no |
| opt | `xdg-desktop-portal-gtk` | `xdg-desktop-portal-gtk` | `1.15.3` | `1` | 3 | 0 | yes | no | no |
| opt | `xdg-user-dirs` | `xdg-user-dirs` | `0.18` | `1` | 0 | 0 | yes | no | no |
| opt | `xdotool` | `xdotool` | `3.20211022.1` | `1` | 0 | 0 | yes | no | no |
| opt | `xmlto` | `xmlto` | `0.0.29` | `1` | 3 | 0 | yes | no | no |
| opt | `yaml` | `yaml` | `0.2.5` | `1` | 0 | 0 | yes | no | no |
| opt | `yasm` | `yasm` | `1.3.0` | `2` | 0 | 0 | yes | no | no |
| opt | `zip` | `zip` | `3.0` | `1` | 0 | 0 | yes | no | no |
| xorg | `bdftopcf` | `bdftopcf` | `1.1.1` | `1` | 1 | 0 | yes | no | no |
| xorg | `fontconfig` | `fontconfig` | `2.16.0` | `1` | 2 | 0 | yes | no | no |
| xorg | `glu` | `glu` | `9.0.3` | `1` | 1 | 0 | yes | no | no |
| xorg | `iceauth` | `iceauth` | `1.0.9` | `1` | 0 | 0 | yes | no | no |
| xorg | `libFS` | `libFS` | `1.0.9` | `1` | 2 | 0 | yes | no | no |
| xorg | `libICE` | `libICE` | `1.1.2` | `1` | 2 | 0 | yes | no | no |
| xorg | `libSM` | `libSM` | `1.2.5` | `1` | 2 | 0 | yes | no | no |
| xorg | `libX11` | `libX11` | `1.8.11` | `1` | 2 | 0 | yes | no | no |
| xorg | `libXScrnSaver` | `libXScrnSaver` | `1.2.4` | `1` | 1 | 0 | yes | no | no |
| xorg | `libXau` | `libXau` | `1.0.12` | `1` | 1 | 0 | yes | no | no |
| xorg | `libXaw` | `libXaw` | `1.0.16` | `1` | 2 | 0 | yes | no | no |
| xorg | `libXcomposite` | `libXcomposite` | `0.4.6` | `1` | 2 | 0 | yes | no | no |
| xorg | `libXcursor` | `libXcursor` | `1.2.3` | `1` | 2 | 0 | yes | no | no |
| xorg | `libXdamage` | `libXdamage` | `1.1.6` | `1` | 1 | 0 | yes | no | no |
| xorg | `libXdmcp` | `libXdmcp` | `1.1.5` | `1` | 1 | 0 | yes | no | no |
| xorg | `libXext` | `libXext` | `1.3.6` | `1` | 1 | 0 | yes | no | no |
| xorg | `libXfixes` | `libXfixes` | `6.0.1` | `1` | 1 | 0 | yes | no | no |
| xorg | `libXfont2` | `libXfont2` | `2.0.6` | `1` | 4 | 0 | yes | no | no |
| xorg | `libXft` | `libXft` | `2.3.8` | `1` | 2 | 0 | yes | no | no |
| xorg | `libXi` | `libXi` | `1.8.1` | `1` | 2 | 0 | yes | no | no |
| xorg | `libXinerama` | `libXinerama` | `1.1.5` | `1` | 1 | 0 | yes | no | no |
| xorg | `libXmu` | `libXmu` | `1.2.1` | `1` | 2 | 0 | yes | no | no |
| xorg | `libXpm` | `libXpm` | `3.5.17` | `1` | 2 | 0 | yes | no | no |
| xorg | `libXpresent` | `libXpresent` | `1.0.1` | `1` | 8 | 0 | yes | no | no |
| xorg | `libXrandr` | `libXrandr` | `1.5.4` | `1` | 2 | 0 | yes | no | no |
| xorg | `libXrender` | `libXrender` | `0.9.12` | `1` | 1 | 0 | yes | no | no |
| xorg | `libXres` | `libXres` | `1.2.2` | `1` | 1 | 0 | yes | no | no |
| xorg | `libXt` | `libXt` | `1.3.1` | `1` | 2 | 0 | yes | no | no |
| xorg | `libXtst` | `libXtst` | `1.2.4` | `1` | 1 | 0 | yes | no | no |
| xorg | `libXv` | `libXv` | `1.0.13` | `1` | 1 | 0 | yes | no | no |
| xorg | `libXvMC` | `libXvMC` | `1.0.14` | `2` | 1 | 0 | yes | no | no |
| xorg | `libXxf86dga` | `libXxf86dga` | `1.1.6` | `1` | 1 | 0 | yes | no | no |
| xorg | `libXxf86vm` | `libXxf86vm` | `1.1.6` | `1` | 1 | 0 | yes | no | no |
| xorg | `libdrm` | `libdrm` | `2.4.125` | `1` | 2 | 0 | yes | no | no |
| xorg | `libepoxy` | `libepoxy` | `1.5.10` | `1` | 1 | 0 | yes | no | no |
| xorg | `libevdev` | `libevdev` | `1.13.4` | `1` | 2 | 0 | yes | no | no |
| xorg | `libfontenc` | `libfontenc` | `1.1.8` | `1` | 2 | 0 | yes | no | no |
| xorg | `libglvnd` | `libglvnd` | `1.7.0` | `1` | 1 | 0 | yes | no | no |
| xorg | `libinput` | `libinput` | `1.28.1` | `1` | 3 | 0 | yes | no | no |
| xorg | `libpciaccess` | `libpciaccess` | `0.18.1` | `1` | 0 | 0 | yes | no | no |
| xorg | `libpthread-stubs` | `libpthread-stubs` | `0.5` | `1` | 0 | 0 | yes | no | no |
| xorg | `libunwind` | `libunwind` | `1.8.1` | `1` | 0 | 0 | yes | no | no |
| xorg | `libva` | `libva` | `2.22.0` | `1` | 3 | 0 | yes | no | no |
| xorg | `libvdpau` | `libvdpau` | `1.5` | `1` | 1 | 0 | yes | no | no |
| xorg | `libvdpau-va-gl` | `libvdpau-va-gl` | `0.4.2` | `1` | 4 | 0 | yes | no | no |
| xorg | `libxcb` | `libxcb` | `1.17.0` | `1` | 3 | 0 | yes | no | no |
| xorg | `libxcvt` | `libxcvt` | `0.1.3` | `1` | 2 | 0 | yes | no | no |
| xorg | `libxkbcommon` | `libxkbcommon` | `1.10.0` | `3` | 1 | 0 | yes | no | no |
| xorg | `libxkbfile` | `libxkbfile` | `1.1.3` | `1` | 1 | 0 | yes | no | no |
| xorg | `libxshmfence` | `libxshmfence` | `1.3.3` | `1` | 2 | 0 | yes | no | no |
| xorg | `luit` | `luit` | `20240910` | `1` | 0 | 0 | yes | no | no |
| xorg | `mesa` | `mesa` | `26.1.7` | `2` | 5 | 0 | yes | no | no |
| xorg | `mesa-demos` | `mesa-demos` | `9.0.0` | `1` | 2 | 0 | yes | no | no |
| xorg | `mkfontscale` | `mkfontscale` | `1.2.3` | `1` | 3 | 0 | yes | no | no |
| xorg | `mtdev` | `mtdev` | `1.1.7` | `1` | 0 | 0 | yes | no | no |
| xorg | `nvidia` | `nvidia` | `535.113.01` | `1` | 3 | 0 | yes | no | no |
| xorg | `pixman` | `pixman` | `0.46.2` | `1` | 0 | 0 | yes | no | no |
| xorg | `sessreg` | `sessreg` | `1.1.3` | `1` | 1 | 0 | yes | no | no |
| xorg | `setxkbmap` | `setxkbmap` | `1.3.4` | `1` | 1 | 0 | yes | no | no |
| xorg | `smproxy` | `smproxy` | `1.0.7` | `1` | 1 | 0 | yes | no | no |
| xorg | `twm` | `twm` | `1.0.12` | `1` | 1 | 0 | yes | no | no |
| xorg | `util-macros` | `util-macros` | `1.20.2` | `1` | 0 | 0 | yes | no | no |
| xorg | `wayland` | `wayland` | `1.23.1` | `1` | 1 | 0 | yes | no | no |
| xorg | `wayland-protocols` | `wayland-protocols` | `1.45` | `1` | 1 | 0 | yes | no | no |
| xorg | `x11perf` | `x11perf` | `1.6.2` | `1` | 2 | 0 | yes | no | no |
| xorg | `xauth` | `xauth` | `1.1.3` | `1` | 0 | 0 | yes | no | no |
| xorg | `xbacklight` | `xbacklight` | `1.2.4` | `1` | 1 | 0 | yes | no | no |
| xorg | `xbitmaps` | `xbitmaps` | `1.1.4` | `2` | 0 | 0 | yes | no | no |
| xorg | `xcb-proto` | `xcb-proto` | `1.17.0` | `1` | 1 | 0 | yes | no | no |
| xorg | `xcb-util` | `xcb-util` | `0.4.1` | `1` | 1 | 0 | yes | no | no |
| xorg | `xcb-util-cursor` | `xcb-util-cursor` | `0.1.4` | `1` | 2 | 0 | yes | no | no |
| xorg | `xcb-util-image` | `xcb-util-image` | `0.4.1` | `1` | 1 | 0 | yes | no | no |
| xorg | `xcb-util-keysyms` | `xcb-util-keysyms` | `0.4.1` | `1` | 1 | 0 | yes | no | no |
| xorg | `xcb-util-renderutil` | `xcb-util-renderutil` | `0.3.10` | `1` | 1 | 0 | yes | no | no |
| xorg | `xcb-util-wm` | `xcb-util-wm` | `0.4.2` | `1` | 1 | 0 | yes | no | no |
| xorg | `xclip` | `xclip` | `0.13` | `3` | 1 | 0 | yes | no | no |
| xorg | `xclock` | `xclock` | `1.1.1` | `1` | 2 | 0 | yes | no | no |
| xorg | `xcmsdb` | `xcmsdb` | `1.0.6` | `1` | 1 | 0 | yes | no | no |
| xorg | `xcursor-themes` | `xcursor-themes` | `1.0.7` | `1` | 3 | 0 | yes | no | no |
| xorg | `xcursorgen` | `xcursorgen` | `1.0.8` | `1` | 2 | 0 | yes | no | no |
| xorg | `xdg-utils` | `xdg-utils` | `v1.2.1` | `1` | 2 | 0 | yes | no | no |
| xorg | `xdpyinfo` | `xdpyinfo` | `1.3.4` | `1` | 5 | 0 | yes | no | no |
| xorg | `xdriinfo` | `xdriinfo` | `1.0.7` | `1` | 1 | 0 | yes | no | no |
| xorg | `xev` | `xev` | `1.2.6` | `1` | 1 | 0 | yes | no | no |
| xorg | `xf86-input-elographics` | `xf86-input-elographics` | `1.4.3` | `1` | 1 | 0 | yes | no | no |
| xorg | `xf86-input-evdev` | `xf86-input-evdev` | `2.11.0` | `1` | 3 | 0 | yes | no | no |
| xorg | `xf86-input-joystick` | `xf86-input-joystick` | `1.6.4` | `1` | 1 | 0 | yes | no | no |
| xorg | `xf86-input-libinput` | `xf86-input-libinput` | `1.5.0` | `1` | 2 | 0 | yes | no | no |
| xorg | `xf86-input-synaptics` | `xf86-input-synaptics` | `1.10.0` | `2` | 2 | 0 | yes | no | no |
| xorg | `xf86-input-vmmouse` | `xf86-input-vmmouse` | `13.2.0` | `1` | 1 | 0 | yes | no | no |
| xorg | `xf86-input-wacom` | `xf86-input-wacom` | `1.2.4` | `2` | 2 | 0 | yes | no | no |
| xorg | `xf86-video-amdgpu` | `xf86-video-amdgpu` | `23.0.0` | `1` | 1 | 0 | yes | no | no |
| xorg | `xf86-video-ast` | `xf86-video-ast` | `1.2.0` | `1` | 1 | 0 | yes | no | no |
| xorg | `xf86-video-ati` | `xf86-video-ati` | `22.0.0` | `1` | 1 | 0 | yes | no | no |
| xorg | `xf86-video-cirrus` | `xf86-video-cirrus` | `1.6.0` | `1` | 1 | 0 | yes | no | no |
| xorg | `xf86-video-dummy` | `xf86-video-dummy` | `0.4.1` | `1` | 1 | 0 | yes | no | no |
| xorg | `xf86-video-fbdev` | `xf86-video-fbdev` | `0.5.1` | `1` | 1 | 0 | yes | no | no |
| xorg | `xf86-video-intel` | `xf86-video-intel` | `2.99.917-931` | `1` | 2 | 0 | yes | no | no |
| xorg | `xf86-video-mga` | `xf86-video-mga` | `2.0.1` | `1` | 1 | 0 | yes | no | no |
| xorg | `xf86-video-neomagic` | `xf86-video-neomagic` | `1.3.1` | `1` | 1 | 0 | yes | no | no |
| xorg | `xf86-video-nouveau` | `xf86-video-nouveau` | `1.0.18` | `2` | 1 | 0 | yes | no | no |
| xorg | `xf86-video-openchrome` | `xf86-video-openchrome` | `0.6.0` | `2` | 1 | 0 | yes | no | no |
| xorg | `xf86-video-siliconmotion` | `xf86-video-siliconmotion` | `1.7.9` | `1` | 1 | 0 | yes | no | no |
| xorg | `xf86-video-sis` | `xf86-video-sis` | `0.12.0` | `1` | 1 | 0 | yes | no | no |
| xorg | `xf86-video-vboxvideo` | `xf86-video-vboxvideo` | `1.0.0` | `1` | 1 | 0 | yes | no | no |
| xorg | `xf86-video-vesa` | `xf86-video-vesa` | `2.6.0` | `1` | 1 | 0 | yes | no | no |
| xorg | `xf86-video-vmware` | `xf86-video-vmware` | `13.4.0` | `1` | 1 | 0 | yes | no | no |
| xorg | `xgamma` | `xgamma` | `1.0.7` | `1` | 1 | 0 | yes | no | no |
| xorg | `xhost` | `xhost` | `1.0.10` | `1` | 1 | 0 | yes | no | no |
| xorg | `xinit` | `xinit` | `1.4.4` | `2` | 2 | 0 | yes | no | no |
| xorg | `xinput` | `xinput` | `1.6.4` | `1` | 3 | 0 | yes | no | no |
| xorg | `xkbcomp` | `xkbcomp` | `1.4.7` | `1` | 1 | 0 | yes | no | no |
| xorg | `xkbevd` | `xkbevd` | `1.1.5` | `1` | 1 | 0 | yes | no | no |
| xorg | `xkbutils` | `xkbutils` | `1.0.6` | `1` | 1 | 0 | yes | no | no |
| xorg | `xkeyboard-config` | `xkeyboard-config` | `2.48` | `2` | 1 | 0 | yes | no | no |
| xorg | `xkill` | `xkill` | `1.0.6` | `1` | 1 | 0 | yes | no | no |
| xorg | `xlsatoms` | `xlsatoms` | `1.1.4` | `1` | 1 | 0 | yes | no | no |
| xorg | `xlsclients` | `xlsclients` | `1.1.5` | `1` | 1 | 0 | yes | no | no |
| xorg | `xmessage` | `xmessage` | `1.0.7` | `1` | 1 | 0 | yes | no | no |
| xorg | `xmodmap` | `xmodmap` | `1.0.11` | `1` | 1 | 0 | yes | no | no |
| xorg | `xorg-apps` | `xorg-apps` | `7x` | `1` | 42 | 0 | yes | no | no |
| xorg | `xorg-driver` | `xorg-driver` | `7x` | `2` | 24 | 0 | yes | no | no |
| xorg | `xorg-font-adobe-100dpi` | `xorg-font-adobe-100dpi` | `1.0.4` | `1` | 3 | 0 | yes | no | no |
| xorg | `xorg-font-adobe-75dpi` | `xorg-font-adobe-75dpi` | `1.0.4` | `1` | 3 | 0 | yes | no | no |
| xorg | `xorg-font-adobe-utopia-100dpi` | `xorg-font-adobe-utopia-100dpi` | `1.0.5` | `1` | 3 | 0 | yes | no | no |
| xorg | `xorg-font-adobe-utopia-75dpi` | `xorg-font-adobe-utopia-75dpi` | `1.0.5` | `1` | 3 | 0 | yes | no | no |
| xorg | `xorg-font-adobe-utopia-type1` | `xorg-font-adobe-utopia-type1` | `1.0.5` | `1` | 2 | 0 | yes | no | no |
| xorg | `xorg-font-alias` | `xorg-font-alias` | `1.0.4` | `1` | 0 | 0 | yes | no | no |
| xorg | `xorg-font-arabic-misc` | `xorg-font-arabic-misc` | `1.0.4` | `1` | 3 | 0 | yes | no | no |
| xorg | `xorg-font-bh-100dpi` | `xorg-font-bh-100dpi` | `1.0.4` | `1` | 3 | 0 | yes | no | no |
| xorg | `xorg-font-bh-75dpi` | `xorg-font-bh-75dpi` | `1.0.4` | `1` | 3 | 0 | yes | no | no |
| xorg | `xorg-font-bh-lucidatypewriter-100dpi` | `xorg-font-bh-lucidatypewriter-100dpi` | `1.0.4` | `1` | 3 | 0 | yes | no | no |
| xorg | `xorg-font-bh-lucidatypewriter-75dpi` | `xorg-font-bh-lucidatypewriter-75dpi` | `1.0.4` | `1` | 3 | 0 | yes | no | no |
| xorg | `xorg-font-bh-ttf` | `xorg-font-bh-ttf` | `1.0.3` | `2` | 2 | 0 | yes | no | no |
| xorg | `xorg-font-bh-type1` | `xorg-font-bh-type1` | `1.0.4` | `1` | 2 | 0 | yes | no | no |
| xorg | `xorg-font-bitstream-100dpi` | `xorg-font-bitstream-100dpi` | `1.0.4` | `1` | 2 | 0 | yes | no | no |
| xorg | `xorg-font-bitstream-75dpi` | `xorg-font-bitstream-75dpi` | `1.0.4` | `1` | 2 | 0 | yes | no | no |
| xorg | `xorg-font-bitstream-type1` | `xorg-font-bitstream-type1` | `1.0.4` | `1` | 2 | 0 | yes | no | no |
| xorg | `xorg-font-bitstream-vera` | `xorg-font-bitstream-vera` | `1.10` | `3` | 0 | 0 | yes | no | no |
| xorg | `xorg-font-cronyx-cyrillic` | `xorg-font-cronyx-cyrillic` | `1.0.4` | `1` | 3 | 0 | yes | no | no |
| xorg | `xorg-font-cursor-misc` | `xorg-font-cursor-misc` | `1.0.3` | `1` | 2 | 0 | yes | no | no |
| xorg | `xorg-font-daewoo-misc` | `xorg-font-daewoo-misc` | `1.0.3` | `1` | 3 | 0 | yes | no | no |
| xorg | `xorg-font-dec-misc` | `xorg-font-dec-misc` | `1.0.3` | `1` | 3 | 0 | yes | no | no |
| xorg | `xorg-font-dejavu-ttf` | `xorg-font-dejavu-ttf` | `2.37` | `1` | 2 | 0 | yes | no | no |
| xorg | `xorg-font-ibm-type1` | `xorg-font-ibm-type1` | `1.0.4` | `1` | 2 | 0 | yes | no | no |
| xorg | `xorg-font-isas-misc` | `xorg-font-isas-misc` | `1.0.4` | `1` | 3 | 0 | yes | no | no |
| xorg | `xorg-font-jis-misc` | `xorg-font-jis-misc` | `1.0.3` | `1` | 3 | 0 | yes | no | no |
| xorg | `xorg-font-micro-misc` | `xorg-font-micro-misc` | `1.0.4` | `1` | 3 | 0 | yes | no | no |
| xorg | `xorg-font-misc-cyrillic` | `xorg-font-misc-cyrillic` | `1.0.4` | `1` | 3 | 0 | yes | no | no |
| xorg | `xorg-font-misc-ethiopic` | `xorg-font-misc-ethiopic` | `1.0.5` | `1` | 2 | 0 | yes | no | no |
| xorg | `xorg-font-misc-meltho` | `xorg-font-misc-meltho` | `1.0.3` | `1` | 2 | 0 | yes | no | no |
| xorg | `xorg-font-misc-misc` | `xorg-font-misc-misc` | `1.1.2` | `1` | 3 | 0 | yes | no | no |
| xorg | `xorg-font-mutt-misc` | `xorg-font-mutt-misc` | `1.0.4` | `1` | 3 | 0 | yes | no | no |
| xorg | `xorg-font-schumacher-misc` | `xorg-font-schumacher-misc` | `1.1.2` | `1` | 3 | 0 | yes | no | no |
| xorg | `xorg-font-screen-cyrillic` | `xorg-font-screen-cyrillic` | `1.0.5` | `1` | 3 | 0 | yes | no | no |
| xorg | `xorg-font-sony-misc` | `xorg-font-sony-misc` | `1.0.3` | `1` | 3 | 0 | yes | no | no |
| xorg | `xorg-font-sun-misc` | `xorg-font-sun-misc` | `1.0.3` | `1` | 3 | 0 | yes | no | no |
| xorg | `xorg-font-util` | `xorg-font-util` | `1.4.1` | `1` | 0 | 0 | yes | no | no |
| xorg | `xorg-font-winitzki-cyrillic` | `xorg-font-winitzki-cyrillic` | `1.0.4` | `1` | 3 | 0 | yes | no | no |
| xorg | `xorg-font-xfree86-type1` | `xorg-font-xfree86-type1` | `1.0.5` | `1` | 2 | 0 | yes | no | no |
| xorg | `xorg-fonts` | `xorg-fonts` | `7x` | `1` | 39 | 0 | yes | no | no |
| xorg | `xorg-libs` | `xorg-libs` | `7x` | `1` | 33 | 0 | yes | no | no |
| xorg | `xorg-server` | `xorg-server` | `21.1.24` | `2` | 9 | 0 | yes | no | no |
| xorg | `xorgproto` | `xorgproto` | `2025.1` | `2` | 2 | 0 | yes | no | no |
| xorg | `xpr` | `xpr` | `1.2.0` | `1` | 1 | 0 | yes | no | no |
| xorg | `xprop` | `xprop` | `1.2.7` | `1` | 1 | 0 | yes | no | no |
| xorg | `xrandr` | `xrandr` | `1.5.2` | `1` | 1 | 0 | yes | no | no |
| xorg | `xrdb` | `xrdb` | `1.2.2` | `1` | 1 | 0 | yes | no | no |
| xorg | `xrefresh` | `xrefresh` | `1.1.0` | `1` | 1 | 0 | yes | no | no |
| xorg | `xscreensaver` | `xscreensaver` | `6.09` | `2` | 6 | 0 | yes | no | no |
| xorg | `xset` | `xset` | `1.2.5` | `1` | 1 | 0 | yes | no | no |
| xorg | `xsetroot` | `xsetroot` | `1.1.3` | `1` | 1 | 0 | yes | no | no |
| xorg | `xterm` | `xterm` | `410` | `2` | 2 | 0 | yes | no | no |
| xorg | `xtrans` | `xtrans` | `1.5.2` | `1` | 1 | 0 | yes | no | no |
| xorg | `xvinfo` | `xvinfo` | `1.1.5` | `1` | 1 | 0 | yes | no | no |
| xorg | `xwayland` | `xwayland` | `24.1.13` | `2` | 7 | 0 | yes | no | no |
| xorg | `xwd` | `xwd` | `1.0.9` | `1` | 1 | 0 | yes | no | no |
| xorg | `xwininfo` | `xwininfo` | `1.1.6` | `1` | 1 | 0 | yes | no | no |
| xorg | `xwud` | `xwud` | `1.0.6` | `1` | 1 | 0 | yes | no | no |
