# BFSOS r502 — Cpio/fakeroot installer correction (source only)

## Root cause identified in project source

`ports/core/pkgutils/bfs-pkgmk` explicitly uses `fakeroot -- pkgmk` for all ports **without** `bfs_build_phases=split`. The earlier generic split-phase infrastructure was already implemented, but no active cpio opt-in existed. Consequently the installer ran cpio Autoconf tests inside fakeroot and `conftest` blocked on System V `msgsnd` with pkgmk-owned full IPC queues.

## Changes

- `ports/opt/cpio/Pkgfile`: release 1 → 2; explicitly select the existing split-phase API. `pre_build` runs before `pkg_compile`, where configure and make now execute unprivileged without fakeroot; `pkg_stage` performs only `make DESTDIR=... install` inside short-lived fakeroot.
- `scripts/tests/test-r502-cpio-fakeroot.py`: validates active split mode, correct phase APIs, fail propagation and pkgutils refresh hooks in ISO and installer.
- This is a **targeted correction to the observed blocker**; other non-migrated ports still execute their full build under fakeroot. A general solution requires migrating safe recipes / redesigning packaging and testing ownership behavior. Do not mark the global fakeroot cleanup closed.

## Required live verification

1. Push updated Pkgfile and confirm current `pkgutils` is installed in ISO root and target chroot. The ISO builder attempts `prt-get update pkgutils`, and installer conditionally updates it if quickdiff sees a difference; verify actual binary contains split patch, not just file presence.
2. Build `opt/cpio` via `bfs-pkgmk -d -if -is -kw` (if needed) in test VM and inspect a process tree: `./configure` must have **no fakeroot ancestor**; only staging can have fakeroot ancestor.
3. Verify the package archive's root ownership, permissions, symlinks and footprint and successful `prt-get depinst cpio` without IPC stalls.
4. Perform a clean UEFI install and reboot without ISO. Repeat with an unrelated non-split port; the wider IPC problem remains open.

**Status:** Source implementation and offline contract test only. No BFSOS VM or installer end-to-end tests performed here.
