# BFSOS r513 — pkgutils archive and footprint transaction audit

Date: 2026-10-23. Target: core/pkgutils 5.40.12-50. **Source-only partial repair; not live-validated.**

## Confirmed failures addressed

- `bfs-pkgmk -f -uf -kw` in the UEFI VM attempted `touch "$TARGET"` after replacing `.footprint`; a preexisting root:root 0644 package could not be touched by the `pkgmk` account. The command still returned zero and copied back metadata.
- The root-launched wrapper deleted all matching archived packages after a failed build, potentially destroying a previously valid artifact.
- The wrapper synchronized `.md5sum` and `.footprint` to the original port *before* checking that the archive was valid.

## Changes

- `pkgutils/Pkgfile` release 49 -> 50. The staged pkgmk's metadata-only footprint refresh no longer changes the package archive's mtime. It must still generate and move a nonempty footprint. This avoids the root-owned archive `touch` collision without weakening filesystem failure checks.
- On explicit `bfs-pkgmk -f` (not `-uf`), the root wrapper moves the exact preexisting zstd target aside before running as `pkgmk`. The previous artifact is retained until archive and metadata checks succeed. On failure or interrupt, the wrapper restores it. No recursive cache chmod/chown, and symlinked output paths are refused.
- Removed wildcard deletion of old archives on a failed wrapper invocation. Metadata copy-back is performed after basic archive validation, not before.
- Updated r505 source regression to accept release 50; introduced `test-r513-pkgutils-archive-transaction.py` with source invariants and a mock footprint function transformer test.
- Recalculated the local `bfs-pkgmk` checksum in the port's `.md5sum`.

## Incomplete and release blockers

- Multi-file `.md5sum`/`.footprint` rollback is **not yet fully transactional**; success of one rename does not atomically commit the other. Further validation and failpoint tests are needed.
- Backup of existing packages covers the standard `.pkg.tar.zst` pathname under `/var/cache/pkg/packages` for forced builds. Other configured package directories/compression modes and concurrent same-port builds require separate locked transaction support before calling this universal.
- r511 scoped `fakeroot make install` remains incompletely validated for sudo. Non-make installation targets and other classic recipes are not universally covered. The `cpio` SysV IPC hang must be re-tested in the actual VM.
- No actual package compile, VM chroot test, `prt-get` install, installer run, or reboot was executed in this offline pass. **Do not deploy to the release ISO or production host based on these checks.**

## Offline results

- `python3 scripts/tests/test-r505-pkgmk-universal.py`: PASS
- `python3 scripts/tests/test-r511-pkgutils-stage-safety.py`: PASS
- `python3 scripts/tests/test-r513-pkgutils-archive-transaction.py`: PASS
- `bash -n ports/core/pkgutils/Pkgfile` and `sh -n ports/core/pkgutils/bfs-pkgmk`: PASS

## Next VM acceptance

1. Build pkgutils-50 using an existing known-good direct pkgmk path, inspect `usr/bin/{pkgmk,bfs-pkgmk}` and clean `.footprint`, install only in VM with recovery access.
2. Preserve a `root:root` 0644 package; run `bfs-pkgmk -f -uf -kw`. Require zero genuine errors, a valid updated footprint, and the same archive checksum.
3. Test a deliberate failed `-f` build; require nonzero, previous archive checksum preserved, and metadata unchanged.
4. Build sudo-2 under root-launched wrapper **without installing**, assert complete archive, root ownership and sudo mode 4755, visudo, sudoers, PAM and plugin files, and absence of fakeroot hangs.
5. Audit cpio and rsync, then try the complete UEFI installer and verify working administrative access before publishing.
