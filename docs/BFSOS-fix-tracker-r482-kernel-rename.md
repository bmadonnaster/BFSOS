# r482 — Kernel naming migration tracker

- [x] Rename default LTS port to `core/linux`.
- [x] Rename optional mainline port to `core/linux-mainline`.
- [x] Update ISO, installer, kernel maintenance and updater kernel identifiers.
- [x] Keep LTS headers on kernel 6.18 series.
- [x] Add safety guards refusing unsafe in-place replacement of legacy kernel packages.
- [ ] VM build and boot both kernels; test GRUB, dracut, initramfs, RAID fallback and rollback.
- [ ] Validate real package-db migration from old `linux`/`linux-lts` to new names; do not update running host until tested.
- [ ] Refresh legacy regression tests to new package names.
- [ ] Lift kernel-update holds only after migration passes.
