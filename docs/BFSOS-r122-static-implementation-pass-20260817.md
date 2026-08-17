# BFSOS r122 static implementation pass — 2026-08-17

This pass uses the r121 project snapshot as the source baseline.

## Implemented for maintainer testing

- Installer r45 adds optional RAM-backed `pkgmk` build workspace support at `/var/cache/pkg/build-work`.
  - Default remains disabled.
  - `auto` tmpfs sizing uses conservative RAM tiers: <16 GiB -> 4G only if explicitly enabled; 16-31 GiB -> 8G; 32-63 -> 16G; 64-127 -> 32G; >=128 -> 64G.
  - The size is a tmpfs ceiling, not preallocated memory.
  - Source downloads, completed packages, and ccache remain persistent.
  - Persistent `/etc/fstab` entry uses `nosuid,nodev`, mode 0775 and pkgmk UID/GID 82.
  - Installer mounts/remounts the workspace during the current install so package builds immediately use it.
  - Portable/native optimization drops `-pipe` when the RAM workspace is enabled; disk-backed builds retain the existing `-pipe` policy.
  - Settings are saved in installer settings and reusable profiles.

- `bfs-pkgmk` now records per-package elapsed wall-clock timing and result.
  - Persistent history: `/var/lib/pkgmk/build-times.log`.
  - Package identity, status, UTC timestamp and elapsed seconds are recorded.
  - Timing/logging is best-effort and must not turn a successful build into a failure.
  - pkgutils release bumped to 9 and creates the history file owned by pkgmk.

- Installer package operations (`ports -u`, mandatory sysup/tooling, optional packages) record elapsed time in `/var/log/pkgbuild/build-times.log`.

## Tracker reconciliation

Items #123 and #130-#138 were already implemented in the r121 project tree and remain maintainer-regression pending rather than code-open.
Item #140 is already implemented by installer r44/r45 as an exclusive Current/LTS/none selector.
Item #141 is implemented in r45 and now needs real large-package/kernel/GCC testing.
Item #142 is partially implemented: individual normal package builds and installer package phases are timed; bootstrap phase/package timing remains to be completed after the clean build validates the wrapper path.
Item #143 has its static Current-kernel early-console safeguard implemented and remains boot-regression pending.
The post-1.0 hardware inventory item remains intentionally deferred.

## Linux 6.12 LTS status

Do not ship the diagnostic `md_mod.check_new_feature=0` bypass as a default. Testing proved that newer kernels write `logical_block_size` into a field that older MD code treated as reserved `pad3`; older 6.12 then rejects the array. The proper upstream feature spans MD metadata definition, validation/sync, queue limits and supported personalities, so a one-line bypass is not an acceptable production backport.

For the next full BFSOS install/storage test, use the normal Current kernel. Keep `linux-lts` diagnostic work separate until either:
1. the complete logical-block-size MD feature is safely backported and regression-tested, or
2. BFSOS advances the LTS branch later (for example to 6.18 under the maintainer's Debian-Stable adoption policy).

## Suggested next storage regression

Use RAID6 for the next clean install so the fresh bootstrap/install simultaneously exercises:
- alternate MD personality and parity path;
- RAID -> optional LUKS -> LVM -> Btrfs layering;
- fresh pkgutils/pkgmk build-user migration;
- ccache;
- optional RAM-backed build-work tmpfs;
- installer retry/checkpoint behavior;
- Dracut/GRUB generation;
- first boot on the Current kernel.
