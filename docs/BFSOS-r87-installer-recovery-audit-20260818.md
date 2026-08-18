# BFSOS r87 Installer Recovery Audit — 2026-08-18

## Scope

This pass targets the regressions exposed by the interrupted `linux-firmware` install and the LVM sizing test immediately before it.

## Implemented

- New installer: `scripts/install-bfs-menu-v50-r48-recovery-lvm-download-fixes.sh`.
- Same-process Install / Retry now validates the live target mount plan and reuses it when it already matches the selected root/boot/EFI/home/extra filesystems. It no longer deliberately tears down a valid mounted target just to retry a package transaction.
- Package checkpoint behavior remains in place: already-installed optional packages are checked with `prt-get isinst`, and completed package/system/bootloader state markers remain authoritative.
- pkgutils release bumped to 11.
- Default third-party flat distfile mirror removed. This avoids a mirror 404 being printed before a healthy Pkgfile source and mistaken for a broken upstream URL.
- Curl policy now includes partial continuation, low-speed stall detection, bounded retries, and retry-all-errors so truncated transfers such as curl error 18 can be retried/resumed.
- Bootstrap Stage 2/3 generated `pkgmk.conf` now receives the same downloader policy as the installed system.
- LVM bare percentage shorthand is rejected. `%FREE` and `%VG` must be explicit.
- Percentage LV requests are converted to concrete extents, checked against free extents, and never silently clamped.
- The effective LV allocation is shown before creation and requires confirmation.

## Important diagnosis correction

The installer log showed an initial HTTP 404 before `linux-firmware`, `wpa_supplicant`, and `rdfind`. The project configuration also had a global flat `PKGMK_SOURCE_MIRRORS` entry. CRUX pkgmk checks those mirrors before the Pkgfile source, so a mirror miss can be displayed immediately before the real source succeeds. The Pkgfile URLs were therefore not rewritten solely on the basis of those first 404 lines. The flat mirror was removed instead.

## Static validation

- `bash -n bootstrap.sh`: PASS
- `bash -n scripts/install-bfs-menu-v50-r48-recovery-lvm-download-fixes.sh`: PASS
- `bash -n ports/core/pkgutils/Pkgfile`: PASS
- `git diff --check`: PASS
- No reintroduction of the previous malformed `;;;` pkgmk case syntax.

## Runtime tests still required

1. Interrupt a large source download after substantial progress and verify a retry continues from the partial file rather than restarting from zero.
2. During the same installer process, select Continue -> Install / Retry and verify the already-mounted target is reused without `umount: target is busy` or storage teardown.
3. Confirm packages installed before the failure are reported as already installed and are not rebuilt unnecessarily.
4. Verify a clean source build no longer emits the misleading first-attempt flat-mirror 404.
5. LVM: verify bare `50%` is rejected, `50%FREE` and `50%VG` previews are correct, and an over-allocation is rejected instead of clamped.
6. Relaunch-after-process-exit remains a separate test, particularly for encrypted/LVM stacks that require passphrase-driven reactivation.
7. Path-preserving automatic GNU host fallback remains pending; CRUX `PKGMK_SOURCE_MIRRORS` is a flat filename cache and is not suitable for mirroring the hierarchical GNU tree by itself.
