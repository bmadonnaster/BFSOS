# BFSOS RC1 / Smoke Test Tracker — 2026-09-20 (r6)

## Current milestone
Target: BFSOS 0.9.0-rc1 release candidate after successful bare-metal install and reboot.

Current state:
- Bare-metal live ISO boots via Ventoy
- Installer completed successfully from `scripts/install-bfs-menu-current.sh`
- Installed BFSOS boots from disk through GRUB
- Existing RAID10 + LVM `/home` is preserved, assembles, activates, and mounts successfully
- Networking and normal user login work
- Plasma is installed and starts on the bare-metal system
- MSI X870E GODLIKE optical audio is fixed through UCM + PipeWire packaging and survives relog
- Runtime installer selection has been consolidated in source to `install-bfs-menu-current.sh`; fresh-ISO validation remains
- Project release marker has been promoted to `0.9.0-rc1`; fresh ISO + installed release-file validation remains

---

## RC1 VERSION PROMOTION — r299

### Status
- [x] `VERSION` changed to `0.9.0-rc1`
- [x] Active bootstrap fallbacks changed to `0.9.0-rc1`
- [x] ISO builder fallback changed to `0.9.0-rc1`
- [x] ISO label generation sanitizes the RC suffix as `BFSOS_0_9_0_rc1_x86_64`
- [x] `aaa_filesystem` release bumped to 16 with `bfs_version=0.9.0-rc1`
- [ ] Rebuild/install `aaa_filesystem` and verify installed release files
- [ ] Build fresh RC1 ISO and verify filename/label
- [ ] Fresh-ISO VM optical + USB + bare-metal smoke test

Expected installed release identity after rebuilding `aaa_filesystem`:

```text
PRETTY_NAME="BFS Linux 0.9.0-rc1"
VERSION="0.9.0-rc1"
VERSION_ID="0.9.0-rc1"
```

Expected ISO naming pattern:

```text
BFSOS-0.9.0-rc1-x86_64-<date>-<commit>.iso
BFSOS_0_9_0_rc1_x86_64
```

## HIGH PRIORITY: Consolidate installer source and remove stale installer copies

### Problem
`install-bfs-menu-current.sh` is currently a regular file:

```text
-rwxr-xr-x ... install-bfs-menu-current.sh
regular file -> 'install-bfs-menu-current.sh'
```

It is NOT a symlink.

Historically, `current` was intended to point at the newest known-good installer version. That relationship was lost.

The live menu/bootstrap launched:

```text
/home/bfs/BFSOS/scripts/install-bfs-menu-v50-r74-pre-rc-source-fixes.sh
```

That versioned installer repeatedly failed at the MD metadata compatibility stage.

Launching:

```text
scripts/install-bfs-menu-current.sh
```

directly succeeded and completed the install.

### Why this matters
Keeping multiple independently changing installer scripts caused fixes to diverge.

The same nominal MD fix existed in both `current` and r74, but runtime behavior differed. Continuing to carry many historical installers creates unnecessary ambiguity over which one:
- bootstrap launches
- live ISO launches
- developer patches
- release media contains

Deleting stale files from an already-built ISO does not help. The source tree and ISO build selection logic must be fixed before the next ISO build.

### Required cleanup
Move to one authoritative installer script.

Recommended direction:

```text
scripts/install-bfs-menu.sh
```

or retain:

```text
scripts/install-bfs-menu-current.sh
```

as the single authoritative file.

Then:
1. Determine which current script contains the full newest/working feature set.
2. Preserve the known-good working installer.
3. Compare any unique needed code from the newest versioned installer before deleting anything.
4. Update bootstrap/live-menu/ISO-builder references to launch the authoritative installer only.
5. Remove old `install-bfs-menu-v50-rXX-*.sh` snapshots from release/source packaging once confirmed unnecessary.
6. Keep history in Git instead of keeping dozens of old installer copies in the project tree.
7. Add a build-time sanity check that only one installer entry point is selected.

### Verification commands
Before cleanup:

```bash
cd ~/BFSOS

ls -lh scripts/install-bfs-menu*.sh
grep -RFn 'install-bfs-menu-' scripts     --exclude='install-bfs-menu-current.sh'
```

Find all launcher references:

```bash
grep -RFn   -e 'install-bfs-menu-current.sh'   -e 'install-bfs-menu-v50-'   scripts . 2>/dev/null
```

Compare working `current` to the previously selected r74 copy:

```bash
diff -u   scripts/install-bfs-menu-v50-r74-pre-rc-source-fixes.sh   scripts/install-bfs-menu-current.sh   > /tmp/installer-current-vs-r74.diff
```

Do NOT delete either one until required differences are reviewed.

### Desired final state
Prefer:

```text
scripts/install-bfs-menu.sh
```

as the only runtime installer source.

If `current` naming is retained:

```text
scripts/install-bfs-menu-current.sh
```

should be the only runtime installer entry point, not an independent copy alongside many competing versioned launch targets.

Git should provide historical versions.

### Status
- [x] Confirmed `install-bfs-menu-current.sh` is a regular file, not a symlink
- [x] Confirmed live/bootstrap path selected r74
- [x] Confirmed r74 failed
- [x] Confirmed `current` completed install successfully
- [x] Review diff between r74 and current — only required `od -v` MD-probe behavior differs
- [x] Decide authoritative installer filename — `scripts/install-bfs-menu-current.sh`
- [x] Update bootstrap launcher — authoritative `current` only
- [x] Update live-menu launcher — already uses authoritative `current`
- [x] Update ISO builder runtime installer handoff — already uses authoritative `current`
- [ ] Update documentation/scripts referring to versioned installer
- [ ] Remove stale installer snapshots after review
- [ ] Verify next ISO contains/launches one installer only

---

## FIXED / CONFIRMED: Console font privilege handling

### Symptom
The live-menu console font option failed with:

```text
WARNING: Unable to apply console font /usr/share/consolefonts/latarcyrheb-sun32.psfu.gz; keeping current font.
```

Direct testing as user `bfs` showed:

```text
setfont: ERROR kdfontop.c:270 put_font_kdfontop: ioctl(KDFONTOP): Operation not permitted
```

### Verified
Font files exist:

```text
/usr/share/consolefonts/latarcyrheb-sun16.psfu.gz
/usr/share/consolefonts/latarcyrheb-sun32.psfu.gz
```

Kernel VT support is enabled:

```text
CONFIG_VT=y
CONFIG_VT_CONSOLE=y
CONFIG_VT_HW_CONSOLE_BINDING=y
```

### Root cause
The live menu attempts to run `setfont` as the unprivileged `bfs` user.

SSH/PuTTY sessions use `/dev/pts/N`; console font changes do not apply there.

### Confirmed privileged test
Both succeeded:

```bash
sudo setfont -C /dev/tty1 /usr/share/consolefonts/latarcyrheb-sun32.psfu.gz
sudo setfont -C /dev/tty1 /usr/share/consolefonts/latarcyrheb-sun16.psfu.gz
```

### Required source change
Use local-VT detection and `sudo setfont`.

Recommended helper:

```bash
set_console_font() {
    local font="$1"
    local current_tty

    current_tty="$(tty 2>/dev/null || true)"

    if [[ "$current_tty" != /dev/tty[0-9]* ]]; then
        printf 'Console font changes only apply to a local Linux virtual console.\n'
        return 0
    fi

    if sudo setfont -C "$current_tty" "$font"; then
        printf 'Console font changed successfully.\n'
    else
        printf 'WARNING: Unable to apply console font %s; keeping current font.\n' "$font"
    fi
}
```

### Status
- [x] Root cause identified
- [x] Local privileged test successful
- [x] Patch authoritative live-menu source
- [ ] Rebuild ISO
- [ ] Retest local VT
- [ ] Confirm SSH receives informational message only

---

## MD metadata 1.2 / Linux 6.18 compatibility probe

### Original symptom
Installer aborted with:

```text
MD compatibility probe could not validate the v1.2 superblock on /dev/sda1.
MD compatibility safety probe was inconclusive for required array /dev/md127;
refusing to enable the 6.18 bypass automatically.
```

### Existing RAID state
Existing `/home` storage:

```text
/dev/sda1
/dev/sdb1
/dev/sdc1
/dev/sdd1
    -> /dev/md127 RAID10
       -> vg_storage
          -> lv_home
             -> /home
```

Verified healthy:

```text
Version : 1.2
Raid Level : raid10
State : clean
Active Devices : 4
Working Devices : 4
Failed Devices : 0
Array State : AAAA
[UUUU]
```

Array name:

```text
PrismLinux:0
```

### Raw superblock test
Unprivileged read failed:

```text
dd: failed to open '/dev/sda1': Permission denied
rc=1
```

Privileged read succeeded:

```text
fc 4e 2b a9
rc=0
```

Reserved metadata bytes were all zero:

```text
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00
```

Therefore this array:
- is valid metadata 1.2
- does not have the non-zero reserved-padding condition
- should not require the 6.18 compatibility bypass

### Patch present
The installer currently contains:

```bash
magic="$(sudo dd if="$member" bs=1 skip=4096 count=4 status=none 2>/dev/null | ...)
```

```bash
sudo dd if="$member" bs=1 skip=$((4096 + 12)) count=4 status=none
sudo dd if="$member" bs=1 skip=$((4096 + 224)) count=32 status=none
```

and:

```bash
sector_size="$(sudo blockdev --getss "$member" 2>/dev/null || true)"
```

### Important discovery
Both `current` and r74 contain the apparent raw-device privilege patch, yet:
- r74 continued to fail
- `current` completed successfully

Therefore do NOT assume the MD issue is simply the visible sudo lines. The remaining difference may be elsewhere in installer execution flow or helper code.

This is another reason to consolidate to one authoritative installer.

### Status
- [x] Existing RAID healthy
- [x] Metadata 1.2 verified
- [x] Reserved padding all zero
- [x] Raw metadata readable with privilege
- [x] `current` installer passed and completed
- [ ] Review current-vs-r74 diff for actual behavioral difference
- [ ] Retest authoritative installer after source consolidation
- [ ] Confirm no unnecessary 6.18 bypass is generated
- [ ] Confirm final GRUB config is correct

---

## STORAGE / INSTALLER OBSERVATIONS

### Existing RAID/LVM auto-activation
The installer automatically reassembled/activated the existing storage stack after it had been manually deactivated.

Observed:

```text
/dev/md127 RAID10
    -> vg_storage
       -> lv_home
          -> /home
```

Auto-discovery is acceptable as long as it remains non-destructive.

### Existing `/home` performance concern
User creation appeared unusually slow while the existing populated `/home` was mounted.

Audit for:

```bash
chown -R user:group /home/user
```

or recursive chmod/find operations.

Preferred behavior:
- existing populated home: preserve contents and avoid recursive ownership walks
- new empty home: normal ownership initialization

### Status
- [x] Existing RAID discovered
- [x] Existing LVM discovered
- [x] Existing `/home` preserved during install
- [ ] Audit recursive chown/chmod logic
- [ ] Confirm existing `/home` mounts correctly after reboot

---


## INSTALLER UX: Swap omitted from summary

### Observation
The installer successfully configured the 256 GB swap device in `/etc/fstab`, and swap activated automatically after boot.

Functional status:
- swap entry present in `/etc/fstab`
- 256 GB swap active after boot
- no swap configuration failure

### Issue
The installer summary did not mention the configured swap device, which made the storage summary appear incomplete even though the final configuration was correct.

### Required change
Update the installer summary screen to include:
- swap device or LV
- configured size
- whether it will be enabled at boot

Example summary line:

```text
Swap: /dev/<device>  256 GiB  enabled at boot
```

### Status
- [x] Swap configured correctly
- [x] Swap activates automatically at boot
- [ ] Add swap device to installer summary
- [ ] Add swap size to installer summary
- [ ] Retest summary on next installer run

---

## CURRENT BARE-METAL STORAGE LAYOUT

### NVMe system storage
Current install uses:
- EFI partition -> `/boot/efi`
- boot partition -> `/boot`
- 256 GB swap
- large LVM using available NVMe space
- root LV using about 50% of VG capacity
- remaining VG space intentionally left free

Potential future use:
- grow root
- `/var`
- VM storage
- test/root LVs
- snapshots

### Existing home storage
4x16 TB RAID10:

```text
/dev/sda1
/dev/sdb1
/dev/sdc1
/dev/sdd1
    -> /dev/md127
       -> vg_storage
          -> lv_home
             -> /home
```

Filesystem:
- XFS

---

## ISO SIZE / RELEASE MEDIA WORK

### Goal
Do not ship a 7+ GB base system inside the ISO.

The ISO should contain only the live/install/bootstrap environment.

### Planned model
```text
BFSOS ISO
├─ kernel/initramfs
├─ live environment
├─ installer
├─ bootstrap
├─ networking
├─ storage tools
└─ download/local-source support

BFSOS base archive
├─ downloaded automatically
├─ or supplied manually
└─ verified before extraction
```

### ISO cleanup before squashfs
Remove unnecessary build/install artifacts before ISO creation:

```text
/var/cache/pkg/packages/*
/var/cache/pkg/build-work/*
/var/cache/pkg/sources/*
```

### X.Org/live dependency audit
Audit why X11 libraries are present in the live image.

Possible dependency sources to inspect:
- NetworkManager
- links/elinks
- other live packages

Do not strip X libraries blindly.

### Status
- [ ] Add cache cleanup stage before `mksquashfs`
- [ ] Audit live-root X11 libraries
- [ ] Identify exact dependency pull-ins
- [ ] Remove unnecessary GUI/X11 runtime pieces
- [ ] Externalize base system archive
- [ ] Add local base archive option
- [ ] Add checksum/signature verification
- [ ] Rebuild and compare ISO size

---

## BFSOS MAINTENANCE / UPDATER UI

### Goal
Create a dialog/ncurses maintenance interface for day-to-day BFSOS port maintenance.

Proposed menu:

```text
BFSOS Maintenance

1. Update ports tree
2. Check maintained ports for upstream versions
3. Show outdated packages
4. Review failed version checks
5. Build selected updates
6. Install selected updates
7. Run package integrity checks
8. Generate maintenance report
9. Exit
```

Result categories should distinguish:
- current
- upstream newer
- broken source URL
- unexpected checksum change
- version detection failure
- manual review required

### Status
- [ ] Add dialog/ncurses UI
- [ ] Reuse maintained-port/version-audit logic
- [ ] Add selectable actions
- [ ] Add readable failure categories
- [ ] Add report generation

---

## DOCUMENTATION

Initial RC1 documentation:
- [ ] Installation guide
- [ ] Bootstrap guide
- [ ] Storage / RAID / LVM guide
- [ ] Ports/package-maintainer guide
- [ ] Live ISO troubleshooting
- [ ] Release notes
- [ ] Checksum/signature verification
- [ ] First-boot/recovery notes

---

## WEBSITE / DOMAIN / DOWNLOAD HOSTING

Desired structure:

```text
project domain
    -> project site + documentation

Codeberg
    -> source + ports + development

downloads.<domain>
    -> ISO/base archives/mirrors
```

DreamHost remains a possible host because of:
- prior familiarity
- SSH
- rsync
- storage

### Status
- [ ] Research available BFSOS-related domains
- [ ] Prefer sustainable renewal pricing
- [ ] Set up project site
- [ ] Set up documentation
- [ ] Set up download host
- [ ] Add checksums/signatures

---

## DISTROWATCH / PUBLIC RELEASE READINESS

Before submission:
- [ ] Stable public project page/domain
- [ ] Public ISO
- [ ] Public base archive
- [ ] Checksums/signatures
- [ ] Installation docs
- [ ] Screenshots
- [ ] Release notes
- [ ] Clear project description
- [ ] Demonstrated active maintenance

Project identity:
- independent x86_64 Linux distribution
- CRUX-inspired ports/package workflow
- custom bootstrap
- custom installer
- custom live ISO
- independently maintained ports tree

---

## RC1 GATE

BFSOS 0.9.0 RC1 is reached when the bare-metal install:

- [x] installer completes successfully
- [x] boots from installed disk
- [x] GRUB works
- [x] initramfs handles required storage correctly
- [x] root mounts correctly
- [x] RAID10 assembles correctly
- [x] `vg_storage` activates correctly
- [x] `lv_home` mounts as `/home`
- [x] existing home data is intact
- [x] networking works
- [x] user login works
- [x] desktop starts (Plasma)
- [ ] no critical installer regression remains

---

## Next session plan — from installed BFSOS desktop

1. Boot installed BFSOS and validate storage/network/desktop.
2. Review `current` vs r74 installer diff.
3. Select one authoritative installer source.
4. Update bootstrap/live-menu/ISO-builder to launch only that installer.
5. Remove stale installer snapshots after review.
6. Patch console-font handling.
7. Audit existing-home ownership handling.
8. Slim ISO and externalize base payload.
9. Start maintenance/updater dialog UI.
10. Continue RC1 documentation and domain/hosting work.

---

## HIGH PRIORITY: KF6 dynamic linker configuration

### Problem
KF6 libraries are installed under `/opt/kf6/lib`, but that path is not automatically registered with the system dynamic linker. On the current install, `/etc/ld.so.conf.d/qt6.conf` exists for `/opt/qt6/lib`, but there was no corresponding KF6 entry.

This caused `kdoctools` to compile `meinproc6` successfully and then fail when executing it during the build because `libKF6Archive.so.6` could not be found, even though the library existed under `/opt/kf6/lib`.

### Required fix
- [ ] Ensure `/opt/kf6/lib` is automatically registered on fresh BFSOS installs.
- [ ] Install `/etc/ld.so.conf.d/kf6.conf` containing:

```text
/opt/kf6/lib
```

- [ ] Run `ldconfig` after KF6 libraries are installed or updated.
- [ ] Verify `ldconfig -p` resolves `libKF6Archive.so.6` and representative KF6 libraries from `/opt/kf6/lib`.
- [ ] Keep KF6 handling consistent with the existing `/etc/ld.so.conf.d/qt6.conf` entry for `/opt/qt6/lib`.
- [ ] Decide the permanent implementation point: KF6 base/framework package or a common BFSOS package post-install hook.
- [ ] Do not use per-package `LD_LIBRARY_PATH` hacks as the permanent solution.
- [ ] Re-test `kdoctools` after the loader-path fix.
- [ ] Treat this as an RC1 blocker because Plasma/KF6 builds and runtime executables can fail despite the libraries being installed correctly.

---


## GNOME 51 update

- [ ] Update the BFSOS GNOME stack to GNOME 51.
- [ ] Audit all GNOME ports for version alignment so the desktop stack is not left on mixed major releases.
- [ ] Update GNOME libraries, core desktop components, applications, and meta packages together where required.
- [ ] Verify dependency changes and renamed/removed GNOME components before bulk updating ports.
- [ ] Rebuild and test the GNOME session after the update.
- [ ] Verify GDM/session startup, Wayland, X11 fallback where applicable, PipeWire/WirePlumber integration, and basic desktop launch.
- [ ] Confirm the GNOME meta package installs cleanly on a fresh BFSOS system.
- [ ] Treat GNOME 51 as a post-Plasma desktop-stack maintenance item unless it blocks RC1.



---

## r5 update — 2026-09-20 bare-metal audio and source reconciliation

### FIXED / VERIFIED: MSI X870E GODLIKE optical audio

- [x] Add/maintain `alsa-ucm-conf` as a BFSOS port.
- [x] Backport MSI USB ID `0db0:e5c3` into the ALC408x UCM matcher while retaining the tested 1.2.15.3 base.
- [x] Make PipeWire depend on `alsa-ucm-conf` and `alsa-lib`.
- [x] Activate PipeWire ALSA configuration with `/etc/alsa/conf.d/50-pipewire.conf`.
- [x] Activate PipeWire as ALSA default with `/etc/alsa/conf.d/99-pipewire-default.conf`.
- [x] Verify UCM exposes `HiFi` profiles and a named `S/PDIF Output` instead of depending on generic `Pro 3`.
- [x] Verify optical playback through the raw ALSA endpoint and through PipeWire/default ALSA compatibility.
- [x] Verify Plasma audio settings remain stable.
- [x] Verify the S/PDIF default survives relog.
- [ ] Verify the same dependency/configuration path on the next fresh ISO/install.

### SOURCE FIXED / RETEST REQUIRED: authoritative installer

`install-bfs-menu-current.sh` is now the sole runtime installer entry point used by maintained launchers. The successful current installer differs from r74 only in the MD probe's use of `od -v`, which prevents repeated zero lines from being collapsed during reserved-byte validation.

- [x] Review current vs r74 diff.
- [x] Keep `scripts/install-bfs-menu-current.sh` as authoritative runtime installer.
- [x] Make Bootstrap validate/launch `current` directly instead of selecting versioned snapshots by mtime.
- [x] Confirm the ISO live menu launches `current`.
- [x] Update release static audit away from the stale r74-symlink assumption.
- [x] Release static audit passes after source changes.
- [ ] Rebuild ISO and verify both installer launch paths on fresh media.
- [ ] Remove historical installer snapshots from release packaging after the fresh-media test; Git remains the history mechanism.

### SOURCE FIXED / RETEST REQUIRED: console font privilege

- [x] Local-VT detection is implemented in the generated live helper.
- [x] Root sessions use `setfont -C <tty>` directly.
- [x] Non-root local VT sessions use `sudo setfont -C <tty>`.
- [x] SSH/PTS sessions receive an informational message rather than attempting the VT ioctl.
- [ ] Rebuild ISO and retest font selection on the local console.
- [ ] Retest the font-menu path from SSH/PTS.

### KERNEL AUDIT — 2026-09-20

No kernel package update is required:

```text
linux             7.2.6
linux-headers     7.2.6
linux-api-headers 7.2.6
linux-lts         6.18.52
```

7.2.6 remains the released stable kernel and 6.18.52 remains the released longterm 6.18 kernel. 6.18.53 is only in stable-review, so it is intentionally not packaged.

### Remaining notable maintenance

- [ ] GNOME 51 coordinated stack migration remains open; current GNOME meta/core ports are still in the GNOME 50 family.
- [ ] Fresh ISO validation for the installer/font/audio dependency changes.
- [ ] Historical installer snapshot cleanup after fresh-media validation.
- [ ] Continue updater UI, documentation, website/download hosting, and public-release preparation.
