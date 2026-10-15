# BFSOS r484 — Legacy kernel package migration (VM validation required)

## Purpose

r483 standardized package identities (`linux` LTS and `linux-mainline` optional)
and kernel releases (`-BFSOS-LTS`, `-BFSOS-Mainline`). r484 supplies an explicit
**prepare-only** migration tool for installed systems with old package identities.
This is not an automatic or unattended package upgrade.

## Delivered

- `bfs-kernel-maintenance` bumped to `1.0-5`; ships
  `/usr/sbin/bfs-kernel-migrate` and `/usr/libexec/bfs-kernel-migrate.py`.
- `linux` pre-install recognizes a deliberately prepared `linux-lts` transition.
- `linux-mainline` pre-install keeps refusing legacy 7.x `linux` until it has
  been prepared into `linux-legacy-mainline`.
- The helper saves the original `/var/lib/pkg/db`, selected flavor and legacy
  kernel state under `/var/lib/bfsos/kernel-migrations/backups/` before changes.
- LTS preparation disowns only `boot/vmlinuz-lts` from the old `linux-lts`
  record; the old versioned boot image, module tree and source remain owned.
- Mainline preparation changes only the old 7.x pkgutils **package name**
  `linux` to `linux-legacy-mainline`, preserving its versioned file ownership;
  legacy kernel-state and rollback storage are moved under the archival name.
- Both prepare flows update selected flavor only when it matches the expected
  legacy or target flavor, and place a local marker for the pre-install hook.
- Old kernels are deliberately **not removed**; there is no unattended cleanup.

## Safety caveats

- Verify a powered-off QEMU disk backup and any separate OVMF variables.
- Stop all pkgadd/prt-get/updater transactions during preparation. The DB
  helper takes an advisory lock on the file it opens but pkgutils may not
  participate in that lock; **no concurrent package-manager writes**.
- `status` is read-only and inspects the old identity. After preparation it
  may report the legacy identity changed (mainline); use `pkginfo -i` and the
  printed backup directory for further inspection.
- Do NOT use `pkgrm` on a legacy kernel during these tests. This could
  remove the old fallback kernel or shared directory paths.
- The migration preparation is **not** a complete automated transaction
  covering pkgadd, GRUB, Dracut, reboot and cleanup. A failed install can be
  manually recovered from the backup, but automated rollback is not supplied.
- We do not assume version-number and module-directory matches imply a boot
  test. LTS and mainline must be built, installed and booted independently.
- Check `pkgadd` file-conflict policy before installing, and stop if it
  reports unexpected shared files; **do not force overwrite**.

## VM test procedure: old LTS (`linux-lts 6.18.56-1`)

1. Confirm the VM boots legacy `6.18.56-BFS-LTS`; keep the VM backup immutable.
2. Sync ports to r484. Install `bfs-kernel-maintenance 1.0-5` first, ensuring
   its new helper programs and footprint are installed correctly.
3. Build `linux 6.18.56-2` (r483 kernel release naming) or later matching
   6.18.x kernel with `pkgmk -kw`. Review `.footprint` and package integrity.
4. Check `pkginfo -i`, the current `uname -r`, `/boot`, and modules.
5. Run `sudo bfs-kernel-migrate status lts` and review expected identity.
6. Run `sudo bfs-kernel-migrate prepare lts --yes` only after taking backups.
7. Verify `pkginfo -i` still includes `linux-lts`; ownership of
   `boot/vmlinuz-lts` is no longer attributed to it. Verify legacy image,
   module directory and GRUB entry persist.
8. Install newly built `linux` with the standard pkgutils path. **Do not
   remove `linux-lts`**. Confirm new Dracut image, GRUB config, pending state.
9. Reboot into `6.18.56-BFSOS-LTS`, verify `uname -r`, root filesystem,
   networking, initramfs, RAID policy and kernel maintenance finalization.
10. Keep both kernels for now. Clean-up and rollback of legacy package records
    require separate tested tooling; not provided by r484.

## VM test procedure: legacy mainline (old `linux` 7.x)

On a VM that actually has the old 7.x `linux` package installed, boot that
legacy `-BFS-Linux` kernel. The `prepare mainline` command is intentionally
blocked on machines currently booted into an LTS kernel. First build the new
`linux-mainline` package, then prepare the old identity with
`sudo bfs-kernel-migrate prepare mainline --yes`, verify that `pkginfo` shows
`linux-legacy-mainline`, and install the newly named `linux-mainline` package.
The legacy module and boot trees remain until a successful independent boot
and a later explicit cleanup procedure.

## Validation performed off-machine

- Shell syntax validation of affected hooks.
- `scripts/tests/test-kernel-maintenance.sh`: PASS.
- `scripts/tests/test-kernel-migration-r484.py`: PASS with temporary fixture
  package databases and mocked legacy release names.
- No actual pkgadd, dracut, GRUB update or VM boot is performed in this
  archive-preparation environment. Do not describe this as VM validated.

## Remaining work

- Live pkgadd file-conflict and post-install tests for both flavors.
- Post-boot validation, initramfs and GRUB review.
- Tested cleanup and rollback paths for both legacy package identities.
- Confirm package database remains correct after next ordinary update.
- Only after these tests: consider guarded first-run migration in the BFSOS
  updater and installer; do not enable unattended kernel migrations now.
