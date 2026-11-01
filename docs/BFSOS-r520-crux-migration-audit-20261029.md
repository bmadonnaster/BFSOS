# BFSOS r520 CRUX build-path migration (offline, provisional)

This overlay replaces the `prt-get` build command and updater invocation with the documented CRUX fakeroot/pkgmk model. It does **not** establish that the old cpio fakeroot IPC hang is fixed. The original wrapper and patches remain on disk for comparison, but pkgutils no longer packages them. Do **not** remove a working installed wrapper until the standard toolchain passes full VM validation.

The `prt-get` post-install hook installs and runs `bfs-pkg-permissions`, which creates/manages the exact package cache roots (including build-work and build-work-disk) once per install/upgrade. It never recursively chowns or silently fixes per-port stale work.

**Outstanding blocker:** pkgutils package staging currently requires special ownership `pkgmk:pkgmk` for cache directories. The removed universal fakeroot archive hook formerly emulated those file owners. Before upgrading pkgutils-53, inspect the produced `.footprint` and ownership and ensure normal pkgmk/fakeroot can package it; fix the packaging recipe properly if not. No generated footprint, checksums or signature have been approved.

**Installer/ISO/bootstrap audit:** Existing scripts provision separate build caches themselves. These must be checked for root/target isolation and obsolete wrapper assumptions in VM. The bootstrap temp toolchain legitimately invokes temporary `pkgmk` directly. The ISO code still includes a legacy marker check and footprint bypass that require separate review.

**Do not declare release-ready:** Tests required: cpio IPC, sudo setuid and sudoers, rsync install, pkgutils ownership/metadata, `prt-get` install/update/sysup, updater MD5/footprint/signature transaction, bootstrap stages 1-5, ISO construction, UEFI/BIOS clean install, root/sudo access, multi-swap handling.
