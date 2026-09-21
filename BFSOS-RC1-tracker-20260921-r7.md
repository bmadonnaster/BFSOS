# BFSOS RC1 / Smoke Test Tracker — 2026-09-21 (r7)

## Milestone
Target: **BFSOS 0.9.0-rc1**

## Already proven on bare metal

- [x] Installed BFSOS boots through GRUB.
- [x] Root filesystem mounts.
- [x] Existing RAID10 assembles.
- [x] `vg_storage` activates and the existing XFS `/home` mounts intact.
- [x] Networking works.
- [x] Normal user login works.
- [x] Plasma installs and starts.
- [x] MSI X870E GODLIKE optical S/PDIF works through the maintained ALSA UCM + PipeWire packaging and survives relog.
- [x] `scripts/install-bfs-menu-current.sh` completed the successful install and is the authoritative runtime installer entry point.
- [x] Project release marker is `0.9.0-rc1`.

## r304 source state

### Release/ISO architecture

- [x] ISO builder source uses the SourceForge `BFSOS/base/latest/` base archive + matching SHA256.
- [x] ISO builder source clones/fetches the canonical Codeberg BFSOS tree and records the resolved commit.
- [x] `--refresh-base`, `--git-ref`, and `--local-base` source paths exist.
- [x] Source tarballs, binary package archives and pkgmk caches are forbidden from the final live root.
- [x] Old base-tarball and binary-package-cache ISO staging has been removed.
- [x] Stronger XZ/1MiB/x86-BCJ SquashFS policy is implemented.
- [x] ISO build provenance is emitted.
- [ ] Upload `BFSOS-base-x86_64.tar.zst` and matching `.sha256` to SourceForge `BFSOS/base/latest/`.
- [ ] Complete first remote-base RC1 ISO build.
- [ ] Record actual live-root/SquashFS/final-ISO sizes.
- [ ] Inspect final ISO and prove no `.tar*` or `.pkg.tar.*` payloads are present.

### Minimal live networking/browser/time sync

- [x] `ports/iso/networkmanager-iso` source added.
- [x] Ethernet + Wi-Fi + `nmcli` + `nmtui` are retained in the ISO recipe.
- [x] `wireless-regdb` remains in the live package set.
- [x] `ports/iso/lynx-iso` source added with terminal HTTPS support.
- [x] maintained `chrony 4.9` port added.
- [ ] Build/install `networkmanager-iso`.
- [ ] Test wired networking.
- [ ] Test Wi-Fi scanning/connection and regulatory-domain behavior.
- [ ] Test `nmcli`.
- [ ] Test `nmtui`.
- [ ] Build/test `lynx-iso` HTTPS access.
- [ ] Build/test chrony and verify automatic live sync with `chronyc tracking` / `chronyc sources`.

### Base/install utilities

- [x] `genfstab` confirmed already present in the base/bootstrap package list.
- [x] `genfstab` port moved to maintainable upstream `arch-install-scripts` v31 source.
- [ ] Rebuild/install genfstab and smoke-test against a mounted target.

### Plasma completeness

- [x] Spectacle source port added.
- [x] `kquickimageeditor`, Tesseract and Leptonica support ports added.
- [x] `plasma-meta` now depends on Spectacle.
- [ ] Build/install the Spectacle dependency chain.
- [ ] Verify Print Screen, Alt+Print Screen, rectangular-region capture, clipboard and save-to-file under Plasma Wayland.

### GNOME 51

- [x] Coordinated GNOME 51 source alignment completed rather than only changing the meta package.
- [x] GTK4/libadwaita/ministream foundation aligned.
- [x] Shell/Mutter/GDM/session/settings/control-center/schema/portal core aligned.
- [x] Nautilus and representative GNOME 51 applications/libraries aligned.
- [ ] Build dependency-resolved GNOME 51 stack on BFSOS.
- [ ] Start GDM.
- [ ] Log into GNOME Wayland.
- [ ] Smoke-test Shell/Mutter, Settings, Files, portals, PipeWire audio, icons and logout/login.
- [ ] Only after those tests mark GNOME 51 runtime complete.

### Accessibility / console policy

- [x] Live console font helper is privilege/TTY aware in source.
- [x] Authoritative installer has installed-console font selection.
- [x] Installer persists the selected font through `/etc/vconsole.conf`.
- [x] `consoleblank=1800` persistence exists in the installed GRUB/kernel configuration path.
- [ ] Fresh ISO local-VT font test.
- [ ] Fresh ISO SSH/PTS no-op/informational behavior test.
- [ ] Fresh install persistence test for console font.
- [ ] Re-run GRUB regeneration and verify `consoleblank=1800` survives.

## RC1 fresh-media gate

- [ ] SourceForge base archive + SHA uploaded.
- [ ] Fresh ISO built from a recorded Codeberg commit/ref.
- [ ] ISO filename/label report `0.9.0-rc1`.
- [ ] VM optical boot passes.
- [ ] VM USB-mass-storage boot passes.
- [ ] Bare-metal USB/Ventoy boot passes.
- [ ] Live writable overlay passes.
- [ ] SSH host-key generation/login passes.
- [ ] Bootstrap menu launches authoritative installer/bootstrap paths.
- [ ] Installer launches `install-bfs-menu-current.sh`.
- [ ] Complete install from the new media.
- [ ] Installed target boots.
- [ ] RAID/LVM safety behavior remains correct.
- [ ] Installed target reports `0.9.0-rc1`.
- [ ] No critical installer regression remains.

## Older high-risk items still open

These remain investigation/validation work and are not silently closed by r304:

- intermittent `pkgadd` upgrade/reinstall segfault;
- prt-get newly-added dependency + safe orphan-cleanup lifecycle;
- multi-target `prt-get depinst` state/ordering investigation;
- Poppler Qt6 deterministic feature/dependency policy;
- remaining distribution-wide pkgutils extension-compliance audit;
- KF6 dynamic-linker/default library-path integration;
- installed-system optional chrony/systemd-timesyncd/no-service selection;
- updater/dialog UI;
- stale historical installer/source cleanup after the fresh-media validation;
- documentation, release website/download presentation, and final SourceForge publishing.

## r304 source regression result

```text
BFSOS ports static audit:                    PASS
BFSOS release static audit:                  PASS
ISO builder source regression:               PASS
installer pre-RC policy regression:          PASS
r304 source policy regression:               PASS
```

**Current RC1 judgment:** the major requested source work is now represented in-tree, but public RC1 media still requires a fresh SourceForge-backed build plus VM/bare-metal acceptance before publication.
