# BFSOS r505 — Universal pkgmk classic-build isolation (offline source change)

The `bfs-pkgmk` root dispatcher no longer invokes `fakeroot -- pkgmk` for traditional ports. It uses `runuser -u pkgmk` with `BFS_PKG_UNIVERSAL_BUILD=yes` for ordinary recipes; split-phase opt-in remains supported for the one migrated port. The installed `pkgmk` engine is patched to run the ordinary `build` function only once outside fakeroot, then re-enter the existing engine for a short `fakeroot` archive-only pass using the prepared staging tree. Inside that pass virtual `chown -hR 0:0 "$PKG"` normalizes staged payload ownership (not underlying on-disk ownership); archive creation, footprint handling and cleanup use the existing package engine. No per-port migration is required.

## Validation completed in this environment

- `bash -n` on the modified wrapper and Pkgfile, both PASS.
- New unified diff applied to the supplied installed `pkgmk` with `patch --dry-run`, PASS.
- Local fakeroot ownership experiment with an unprivileged staged executable archived as uid/gid 0/0, PASS. The experiment used GNU tar; actual BFSOS libarchive `bsdtar` and package checks are NOT verified here.
- `scripts/tests/test-r505-pkgmk-universal.py`: source check PASS.

## Mandatory live tests before treating as a release fix

1. Rebuild `pkgutils` version 5.40.12 release 48 through a verified package path. Confirm its `.md5sum`, `.footprint`, permissions and installed `/usr/bin/pkgmk` and `/usr/bin/bfs-pkgmk` match new code. Update the footprint through a real package build if necessary.
2. For a classic `pkg_build()` recipe, inspect `ps` to verify `./configure`, compiler and `make` run as `pkgmk` and **not inside fakeroot**; check a short `faked` process occurs only for archiving.
3. Inspect the resulting `.pkg.tar.zst` with `bsdtar -tvf` and metadata, including executables, symlinks, hardlinks, special ownership requirements, setuid files and `.footprint` validity. The virtual owner normalization may not preserve packages deliberately installing non-root-owned files; those require explicit policy/testing.
4. Build/reinstall `cpio`, `wget2`, `rsync`, ordinary and split recipe, and representative complex/RPM packages; test failure propagation and `-kw` work retention.
5. Verify the ISO builder installs new pkgutils **in the running live root and installer target**, not just updated Pkgfiles. Rebuild ISO and complete full UEFI installation followed by disk boot.

**Status: IMPLEMENTED IN SOURCE / NOT LIVE-VERIFIED.** Do not mark r503 fully closed or publish 1.0 until full VM tests pass. Security caution: the port build itself still runs an untrusted recipe as uid pkgmk, never as root; staging contents are built without fakeroot and virtualized archive ownership needs comprehensive package-owner tests.
