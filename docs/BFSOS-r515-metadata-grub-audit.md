# BFSOS r515 targeted source pass

## Changed

- `bfs-pkgmk` copies back only metadata explicitly requested by `-uf`, `-um`, `-us` or `-rs`; ordinary builds do not replace metadata simply because staging copied it.
- Check-only and metadata-only invocations do not disturb existing package archives during forced operations.
- Privileged delegated signing is refused until a secure key-handling boundary exists; direct authorized non-root pkgmk signing remains available.
- `pkgutils` release 51; `bfs-pkgmk` checksum updated.
- BFSOS GRUB distributor branding in target installer config and kernel-maintenance missing-setting fallback; no firmware entry suppression or NVRAM policy change.

## Validated offline

- r515/r505/r511/r513/r441 source tests pass.
- `scripts/tests/test-kernel-maintenance.sh` passes; Bash syntax checks pass.

## Not yet established

- Real package/ISO builds, signature operations, booted UEFI/BIOS installation, multi-file transaction rollback, alternative build output locations, security of arbitrary Pkgfiles. Keep VM recovery and known-good base until live tests pass.
