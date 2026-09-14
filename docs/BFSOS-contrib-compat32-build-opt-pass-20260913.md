# BFSOS contrib + compat-32 build-option correction — 2026-09-13

## Implemented

- Reworked the compat-32 generic builder contract so Autotools, CMake, Meson,
  and ordinary Make builds select `/usr/lib32` centrally.
- Added a centralized Meson i686 cross description; ordinary ports no longer
  reference missing or stale per-port `lib32` cross files.
- Converted at least 125 of 170 compat recipes from unconditional custom
  `pkg_build()` implementations to the BFSOS generic builders with `build_opt`,
  `pre_build`, and `post_build` used only for package-specific behavior.
- Labeled every remaining nonstandard custom build and made it fail-fast in an
  isolated subshell.
- Converted ordinary contrib Autotools/Meson recipes to the generic builders
  and moved GCC/Wine/legacy partial-library configuration switches into
  `build_opt` where a custom build is still required.
- Corrected GStreamer option timing and replaced inherited CRUX package strings
  with BFSOS metadata.
- Replaced tests that incorrectly required all 170 compat ports to define
  `pkg_build()` with tests enforcing the new generic/custom split.

## Validation boundary

Static syntax, version synchronization, dependency-name, source-policy, and
contract tests are run in this source workspace. Real package compilation,
ELFCLASS32 inspection, native/compat footprint-coexistence checks, Wine launch,
and Steam launch still require the BFSOS VM/chroot.

## 2026-09-14 live-build correction

The first live system upgrade proved that changing the source-tree extension
without incrementing and installing `pkgutils` left the older runtime extension
active. Generic compat packages received `-m32` compiler flags but used native
`/usr/lib` installation paths. Conflicting packages were rejected by pkgadd;
the sole successful native-path payload, `xtrans-32`, was subsequently rebuilt
and verified under `/usr/lib32`.

The corrected source bumps pkgutils to release 35, exports extension API 2,
requires that API from all 125 generic compat recipes, and rejects compat
payload files under native `/usr/lib` or `/lib`. It also selects Autotools
explicitly for libxml2-32, CMake explicitly for flac-32, makes lcms2-32 cleanup
idempotent, and bumps libffi-32 so its missing 32-bit pkg-config metadata is
rebuilt before GLib and its dependents.
