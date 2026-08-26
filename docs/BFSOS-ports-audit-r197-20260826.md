# BFSOS Ports Audit — r197 — 2026-08-26

## Scope

Static review of the supplied BFSOS project tree after the installer regression that exposed X.Org prefix/environment problems, a GLib/GObject-Introspection bootstrap cycle, Polkit retry problems, and several stale Pkgfile assumptions.

## Implemented in this pass

- Added installer r68 with a GLib/GObject-Introspection two-pass preflight.
- Fixed GLib so its detected introspection option is actually passed to Meson.
- Corrected and hardened the gobject-introspection Meson build.
- Made Polkit pre-install idempotent and added a clear Gio GIR prerequisite/fail-fast path.
- Added failed/empty package-archive rejection/removal to the BFSOS pkgmk wrapper.
- Removed the obsolete util-macros pre-install compatibility/environment hook.
- Replaced ambient X.Org `$docdir` usage with explicit documentation paths.
- Added `xorgproto` as a direct libX11 dependency.
- Corrected additional Meson/CMake source-directory assumptions caused by pkgmk already entering the extracted source directory.
- Corrected remaining `${JOBS-1}` defaults found by the audit.
- Decoupled LAPACK's upstream source filename from the BFSOS package release number.
- Added `scripts/bfs-ports-static-audit.sh`.

## Dependency attribution

The supplied metadata does not support Lynx as the source of the large GLib/X.Org/introspection chain. Lynx has only `brotli` and `openssl` as hard dependencies. NetworkManager currently directly declares `gobject-introspection`, `libpsl`, `polkit`, `python3-gobject`, and `vala`; its Python/GObject/Cairo dependency path reaches X.Org libraries. Optionalizing NetworkManager features remains an OPEN audit rather than an untested removal.

## Validation performed

- `bash -n bootstrap.sh`
- `bash -n` on installer r68
- `bash -n` on every Pkgfile in the tree
- `bash -n` on `bfs-pkgmk`
- `sh -n` on Polkit `pre-install`
- `scripts/bfs-ports-static-audit.sh` -> PASSED
- `install-bfs-menu-current.sh` -> r68

Runtime clean-build regression remains required; this pass does not mark those runtime items complete.
