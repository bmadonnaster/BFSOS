# BFSOS r84 Static Regression Audit — 2026-08-18

## Passed static/code checks

- `bootstrap.sh` parses with `bash -n`.
- `scripts/install-bfs-menu-v50-r47-tracker-fixes.sh` parses with `bash -n`.
- Changed core Pkgfiles (`gcc`, `linux`, `linux-lts`, `pkgutils`, `glibc`) parse with `bash -n`.
- `git diff --check` reports no whitespace errors.
- No malformed `;;;` case terminators remain in `bootstrap.sh` or `ports/core/pkgutils/Pkgfile`.
- Kernel version helper was extracted and executed under `bash -u`; it returns current `linux` and `linux-lts` versions and safely returns `unknown` for missing/blank package requests.
- Temporary-toolchain locale archive generation/validation remains present in the glibc/bootstrap path.
- Target `C.UTF-8` generation/validation remains immediately after Stage-2 glibc installation.
- Stage-1 toolchain archive validation still checks for `tmp/lfs-tools/lib/locale/locale-archive`.
- Stage-3 ccache now has a preflight for `/usr/bin/ccache`, `/usr/lib/ccache/gcc`, and `/usr/lib/ccache/g++`; enabled Stage-3 builds prepend `/usr/lib/ccache` to PATH from the first package and print ccache stats before/after.
- The old unconditional post-create MD-array `wipefs -a "$array_device"` path is not present. Signature removal on a newly created MD array is now gated behind explicit user approval and LVM deactivation when needed.
- Final installation review includes ZRAM enabled/disabled state and configured size.
- Current storage-device view includes configured/active ZRAM information.
- ZRAM size menu marks the active size `[CURRENT]`.
- Partition editor records a before/after kernel-visible partition fingerprint and marks only changed disks `[MODIFIED THIS SESSION]`.
- GCC final build branding uses `--with-pkgversion="BFSOS"`; core normal/LTS kernel config compiler text was refreshed to BFSOS/GCC 16.2 metadata.

## Runtime regressions already observed as passed in the current test cycle

- Clean Stage 2 extracted GCC 16.2 without the prior `Pathname can't be converted from UTF-8 to current locale` failure.
- A six-member RAID6 array was successfully created and remained active without the old post-create `wipefs: Device or resource busy` abort.
- The r46 ZRAM state-aware screen showed the meaningful Disable action while ZRAM was enabled; r47 additionally marks the current size.

## Still requires live regression testing

- Installer failed-download pause/resume/relaunch workflow, including retry without destructive stages.
- Storage deactivation must stop LVM/dm-crypt/MD cleanly on a live complex topology.
- Back/Cancel navigation from package/base selection screens.
- New MD stale-signature Keep / Remove / Cancel flows, including an auto-reactivated old LVM VG.
- Partition modified markers after actual `cfdisk` writes vs open-and-exit with no write.
- Kernel-selection Dialog after r47 fix.
- Full Stage-3 ccache activity/hit/miss statistics and no build-work busy cleanup regression.
- Toolchain archive restore + temporary-locale validation.
- Final-system locale/bsdtar extraction verification after Stage 3.
- RAID levels other than the newly retested RAID6.
- Bare-metal console-font checks and release/post-1.0 roadmap items.
