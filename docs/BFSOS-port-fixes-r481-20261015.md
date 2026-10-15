# BFSOS r481 — Port changes following updater sweep

## Changes made

- `ports/core/expat/Pkgfile`: 2.8.5 → **2.9.0**, release 1 (source URL remains tag-based).
- `ports/compat-32/expat-32/Pkgfile`: 2.8.5 → **2.9.0**, release 1; keep 64-bit/32-bit version lockstep.
- `ports/core/python3-pluggy/Pkgfile`: preserve already-updated 1.7.0, declare build/installer/wheel tools explicitly, and stop on wheel build/installation failures.
- `scripts/prepare-expat-2.9.0-sources.sh`: obtain the official release archive, verify upstream published SHA256 before writing consistent `.md5sum` files for both ports. The old `.md5sum` entries in the snapshot still target 2.8.5 until this script runs.

## Current snapshot: already updated; intentionally not rolled back

- `opt/chromium` 155.0.8059.79 with writable Go caches; compile still requires live verification.
- `opt/fdk-aac` 3.0.0-2, `gnome/gnome-shell` 51.1, `opt/networkmanager` 1.58.1-3 with GObject Introspection, `core/python3-markdown` 3.11.1, and `core/python3-pluggy` 1.7.0.
- `opt/glycin` and `compat-32/glycin-32` 2.2.3 have successful build/install records in the most recent updater TSV.
- Kernel versions intentionally unchanged pending the planned package naming/policy work.

## Required live checks before committing Expat packages

1. Run `bash scripts/prepare-expat-2.9.0-sources.sh` on a network-connected BFSOS system.
2. Inspect both `Pkgfile` and checksums, then build 64-bit Expat **first** using the normal `pkgmk -kw` workflow. Review any footprint additions/removals and refresh footprint only after validating the staging payload. The CMake metadata directories are versioned and expected to change, but contents have not been verified here.
3. Install the 64-bit Expat build through the usual repository/`prt-get` path, then build/install Expat-32; verify `libexpat` shared objects and both package versions.
4. Re-run the updater only for the Expat pair. Never bypass its architecture-pair coordination checks.

## Limitations / outstanding

- Archive inspection and bash syntax checks were performed offline. Neither a package build nor a live source download was possible in this environment.
- `.footprint` files remain at their previously verified 2.8.5 versions on purpose; we cannot safely manufacture the 2.9.0 payload contents.
- Do not treat UNVERIFIABLE/FETCH-ERROR entries in the scan as confirmed newer versions. Several are upstream-network failures, especially X.Org hosts.
- This is a **port-change revision**, not a claim that every upstream package version has been externally verified or built.
