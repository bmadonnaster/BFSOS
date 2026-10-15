# BFSOS r482 — Kernel package naming migration

**Status:** Source tree renamed; live migration pending manual verification. Do not install renamed kernel packages onto an existing installation until the package migration has been tested in a disposable VM.

- `core/linux` is now the default 6.18 LTS kernel, with the existing `-BFS-LTS` release suffix.
- `core/linux-mainline` is the optional 7.x kernel, preserving the `-BFS-Linux` suffix.
- `core/linux-headers` remains aligned with 6.18 LTS.
- ISO kernel selection, installer package selection, maintenance flavor mapping, and updater names were revised.

## Migration hazard

The old `linux` package represents the *mainline* kernel; the new `linux` package represents *LTS*. An ordinary `pkgadd -u linux` could replace the wrong kernel package and remove files while still booted from an old kernel. An older `linux-lts` package can remain registered even if the new `linux` is installed. Do **not** forcibly overwrite this conflict or manually remove working `/boot` images.

On existing installations: back up `/boot`, record `pkginfo -i | grep -E '^(linux|linux-lts|linux-mainline)[[:space:]]'`, `uname -r`, and `/etc/bfsos/kernel-flavor`, then test migration in a clone/VM first. Make sure both old and new boot entries remain bootable before uninstalling any legacy package.

## Required validation

1. Validate package manifests and `pkgmk` pre/post hooks for `linux` and `linux-mainline`; ensure package DB migration from both old names is transaction-safe.
2. Build a new ISO in a VM, install with default LTS and opt-in mainline, and verify GRUB default, Dracut, `/lib/modules`, `/usr/src/linux`, and rollback markers.
3. Test upgrade migration from an existing system with `linux` (old mainline) plus `linux-lts` installed.
4. Run complete kernel maintenance and ISO/installer regression tests.
5. Keep automatic kernel update selection disabled until migration is validated.

**No kernel versions were bumped in this rename.** Version changes should be evaluated separately after migration verification.
