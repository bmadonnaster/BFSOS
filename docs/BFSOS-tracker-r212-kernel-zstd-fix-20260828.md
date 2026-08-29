# BFSOS r212 kernel Zstd module-compression fix — 2026-08-28

The mainline and LTS kernel packaging paths now enforce Zstandard for the kernel image and for every installed loadable module.

Source changes:

- `linux` 7.2 release 2 and `linux-lts` 6.18.46 release 4 explicitly depend on `zstd`.
- Both recipes force `KERNEL_ZSTD`, `MODULE_COMPRESS`, `MODULE_COMPRESS_ZSTD`, and `MODULE_COMPRESS_ALL`, and explicitly disable kernel Gzip plus module Gzip/XZ.
- Both saved kernel configs carry the same policy rather than relying on a recipe-only override.
- After `modules_install`, packaging fails if raw `.ko`, `.ko.gz`, or `.ko.xz` files exist or if no `.ko.zst` files were generated.
- Static release/ports audits now guard the policy.

Validation performed in source:

- `bash -n` for both kernel Pkgfiles and both audit scripts: PASS
- `git diff --check` for the changed kernel/audit files: PASS
- `scripts/bfs-ports-static-audit.sh`: PASS
- `scripts/bfs-release-static-audit.sh`: PASS

Still requires a clean package build and cold-boot regression for both kernel flavors before the runtime portion can be closed.
