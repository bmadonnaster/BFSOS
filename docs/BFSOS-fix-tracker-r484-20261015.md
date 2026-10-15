# BFSOS r484 Kernel Migration Tracker — 2026-10-15

## Implemented in r484 source

- [x] Add explicit migration preparation tool to kernel-maintenance package.
- [x] Backup pkgutils DB and legacy kernel metadata before any DB edit.
- [x] LTS pre-install supports migration only with preparation marker.
- [x] Mainline old `linux` 7.x identity safely relabelled as archival package.
- [x] Preserve old kernel images/modules/source and disallow silent removal.
- [x] Include offline mock pkgutils tests; existing kernel-maintenance tests pass.
- [x] Keep new BFSOS kernel release suffixes introduced by r483.

## Still to validate or implement

- [ ] Build/install `bfs-kernel-maintenance 1.0-5` in VM; reconcile `.footprint`.
- [ ] Verify LTS side-by-side install and pkgadd conflicts; boot BFSOS-LTS.
- [ ] Build/install mainline, including legacy 7.x VM migration and boot.
- [ ] Confirm Dracut, GRUB, RAID, LVM, rollback, and kernel flavor semantics.
- [ ] Implement robust post-validation cleanup of legacy package records.
- [ ] Implement tested automated rollback for interrupted migration.
- [ ] Validate next kernel upgrade after migration, then consider updater support.

**Safety:** Do not run `pkgrm linux-lts` or `pkgrm linux-legacy-mainline`
until explicit cleanup tooling and boot fallback tests are complete.
