# BFSOS Installer v50 Test / Fix Tracker

**Installer:** `install-bfs-menu-v50-luks-auto-cryptsetup.sh`\
**Test focus:** RAID + LUKS + LVM\
**Status:** Active testing

## Issues Found

### 1. RAID selection summary is plain text instead of Dialog

-   [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
-   **Area:** RAID creation / RAID type summary
-   **Current behavior:** After choosing a RAID type, the installer
    drops out of the Dialog UI and prints a text summary in the
    terminal.
-   **Observed output:**

``` text
# RAID selection summary

RAID type     : RAID 5
Minimum disks : 3
Layout        : Striping with distributed parity
Redundancy    : One drive may fail
Performance   : Fast reads; good general-purpose writes
Usable space  : Capacity of N-1 members

Press Enter to continue...
```

-   **Desired behavior:** Display this information in a Dialog
    `--msgbox` (or equivalent) and return cleanly to the Dialog
    workflow.
-   **Priority:** UI cleanup
-   **Regression test:** Select each supported RAID level and verify its
    summary appears inside Dialog without dropping back to the terminal.

### 4. RAID creation result/progress is plain text instead of Dialog
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
- **Area:** RAID creation / post-create status
- **Current behavior:** After `mdadm` starts the array, the installer drops to plain terminal output showing `/proc/mdstat`, recovery percentage, estimated completion time, and `Press Enter to continue...`.
- **Observed example:**

```text
mdadm: array /dev/md0 started.

Personalities : [raid4] [raid5] [raid6]
md0 : active raid5 ...
      [>....................]  recovery = 0.0% ...
      bitmap: 2/2 pages [8KB], 65536KB chunk

Press Enter to continue...
```

- **Desired behavior:** Keep the user in Dialog. Show array creation success and status in a Dialog `--msgbox`; optionally use a Dialog `--gauge` if the installer chooses to monitor initial RAID recovery/sync progress.
- **Priority:** UI cleanup
- **Regression test:** Create RAID5 and verify the post-create status never drops back to the terminal UI.

### 5. LUKS device selection is plain text and dumps full `lsblk` output
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
- **Area:** LUKS creation / encrypted-device selection
- **Current behavior:** Choosing "Create a new LUKS container" prints a full `lsblk -fp` style device tree to the terminal, including loop devices, optical media, whole disks, mounted build storage, RAID members, and the assembled MD array, then asks `Block device to encrypt:` as a raw text prompt.
- **Observed behavior:** The terminal shows `/dev/loop0`, `/dev/sr0`, `/dev/vda*`, `/dev/vdb1`-`/dev/vdf1`, `/dev/md0`, and `/dev/vdg`, followed by:

```text
Block device to encrypt:
```

- **Desired behavior:** Use a Dialog selection list for LUKS targets. Show only sensible encryptable block-device candidates, with device path, size, type, and current filesystem/signature. Exclude loop devices, optical media, mounted installer/build media, whole disks when a child partition is the intended unit, and RAID member partitions that are already claimed by an active MD array. The assembled `/dev/md0` should be selectable for the RAID -> LUKS -> LVM test.
- **Priority:** UI + safety cleanup
- **Regression test:** Enter the LUKS create flow with an active RAID array and verify `/dev/md0` is offered while `/dev/vdb1`-`/dev/vdf1`, `/dev/loop0`, `/dev/sr0`, and `/dev/vdg` are not offered as accidental targets.

### 6. `cryptsetup luksFormat` destructive confirmation is raw terminal input
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
- **Area:** LUKS creation / destructive confirmation
- **Current behavior:** `cryptsetup luksFormat` exposes its native terminal warning and requires the user to type the exact confirmation text:

```text
WARNING!
This will overwrite data on /dev/md0 irrevocably.

Are you sure? (Type 'yes' in capital letters):
```

- **Desired behavior:** The installer should present its own clear Dialog `--yesno` destructive-action warning before invoking `cryptsetup`. After explicit confirmation, invoke cryptsetup in a non-interactive/force-confirmed mode where supported so its native typed confirmation does not break the Dialog workflow. Password/passphrase entry should remain secure and must not be exposed on the command line.
- **Priority:** UI + safety cleanup
- **Regression test:** Create a LUKS container and verify the destructive confirmation occurs entirely through Dialog, Cancel/No safely returns without formatting, and no plaintext passphrase appears in process arguments or logs.

### 7. LUKS mapping-name prompt is plain text
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
- **Area:** LUKS creation / opening newly created container
- **Current behavior:** After creating a LUKS container, the installer asks `Mapping name to open now [leave blank to skip]:` using a raw terminal prompt.
- **Desired behavior:** Use a Dialog `--inputbox`, with clear guidance that this creates `/dev/mapper/<name>`, plus a Cancel/Skip path. Consider suggesting a sensible default based on intended use (for example `cryptroot` for `/` and `cryptraid` for an encrypted RAID device).
- **Priority:** UI cleanup
- **Regression test:** Create LUKS on a partition and on an MD array; verify mapping-name entry, skip, and cancel all remain in Dialog and produce the expected mapper device.

### 8. LUKS mapping name should be required
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
- **Area:** LUKS creation / mapper naming
- **Current behavior:** The mapping-name prompt allows a blank value to skip opening the newly created LUKS container.
- **Desired behavior:** Require a valid mapping name when creating a LUKS container through the installer. Do not allow an empty name. Re-prompt on blank or invalid input and explain that the resulting device will be `/dev/mapper/<name>`. Provide sensible suggested defaults such as `cryptroot` for an encrypted root partition and `cryptraid` for an encrypted RAID device.
- **Validation:** Reject whitespace, `/`, and names that would conflict with an existing `/dev/mapper` mapping. Keep an explicit Cancel/Back action separate from an empty mapping name.
- **Priority:** Workflow + UI cleanup
- **Regression test:** Verify blank and invalid names are rejected, existing mapper names cannot be reused accidentally, and a valid name opens the LUKS device successfully.

### 9. LUKS passphrase entry and post-open pause drop to plain terminal UI
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
- **Area:** LUKS creation/opening / passphrase and completion
- **Current behavior:** The LUKS passphrase is requested using the raw `cryptsetup` terminal prompt, and after the operation the installer uses a plain `Press Enter to continue...` pause.
- **Desired behavior:** Keep the workflow in Dialog. Use a secure Dialog password box for passphrase entry and confirmation, then feed the passphrase to `cryptsetup` without exposing it in command-line arguments, logs, shell tracing, or temporary plaintext files. Replace the terminal `Press Enter to continue...` with a Dialog success/status message.
- **Safety:** Never echo the passphrase. Ensure installer logging/xtrace cannot capture it. Clear shell variables containing the passphrase as soon as practical.
- **Priority:** UI + security cleanup
- **Regression test:** Create and open LUKS successfully from Dialog; verify passphrase is hidden, confirmation mismatch is handled cleanly, no passphrase appears in logs/process arguments, and completion returns through Dialog.

### 10. Newly created LUKS containers are not remaining open
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
- **Area:** LUKS creation / mapper activation
- **Current behavior:** After creating LUKS containers, `lsblk` correctly shows `crypto_LUKS` on `/dev/vda4` and `/dev/md0`, but the expected mapper devices are inactive (`cryptsetup status cryptraid` and `cryptsetup status luksroot` report inactive).
- **Desired behavior:** When the installer requires a mapping name during LUKS creation, successfully open the new container immediately and verify `/dev/mapper/<name>` exists before returning to the storage menu. If opening fails, show a Dialog error and remain in the LUKS workflow rather than silently continuing.
- **Validation:** After `cryptsetup open`, verify `cryptsetup status <name>` is active and `test -b /dev/mapper/<name>` succeeds.
- **Priority:** Functional LUKS workflow bug
- **Regression test:** Create LUKS on a normal partition and on an MD array; both mappings must remain active and be selectable by the filesystem/LVM setup screens until installer cleanup or an explicit Close action.

### 11. LVM physical-volume selection should be a Dialog device selector
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
- **Area:** LVM setup / physical-volume creation
- **Current behavior:** The installer asks the user to type a block-device path manually when creating an LVM physical volume.
- **Desired behavior:** Present eligible devices in a Dialog menu/checklist navigable with Up/Down and selectable with Space/Enter as appropriate. Show useful metadata such as device path, size, type, and current filesystem/signature.
- **Filtering/safety:** Include valid devices and active mapper devices such as `/dev/mapper/cryptraid`; exclude loop/optical devices, mounted installer media, active RAID member partitions, and devices already consumed by another storage layer unless explicitly appropriate.
- **Selection model:** Support selecting one or more PV devices if the installer supports multi-PV volume groups. Provide Back/Cancel without terminating the installer.
- **Priority:** UI + safety cleanup
- **Regression test:** With RAID -> LUKS active, verify `/dev/mapper/cryptraid` appears as an eligible PV and can be selected entirely through Dialog without manually typing its path.

### 12. LVM operation success messages use plain `Press Enter to continue...`
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
- **Area:** LVM setup / post-operation feedback
- **Current behavior:** After successful LVM operations, such as creating logical volume `var`, the installer drops to terminal text:

```text
Logical volume "var" created.

Press Enter to continue...
```

- **Desired behavior:** Replace terminal pauses after successful PV/VG/LV operations with Dialog `--msgbox` success messages and return directly to the appropriate LVM Dialog menu.
- **Priority:** UI cleanup
- **Regression test:** Create PVs, a VG, and multiple LVs and verify every success/failure result remains in Dialog with no raw `Press Enter to continue...` screens.

### 13. LVM status/summary output is plain terminal text
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
- **Area:** LVM setup / status summary
- **Current behavior:** The installer prints raw `pvs`, `vgs`, and `lvs` output to the terminal, followed by `Press Enter to continue...`.
- **Observed example:** PV `/dev/mapper/cryptraid`, VG `bfs-vg`, and LVs `home` and `var` are shown using the native LVM table output.
- **Desired behavior:** Render a concise LVM summary inside Dialog, ideally using a `--textbox`, `--msgbox`, or formatted menu/table-style screen. Show PV, VG, LV names, sizes, and free space while keeping the user inside the Dialog workflow.
- **Priority:** UI cleanup
- **Regression test:** Open the LVM status/review screen after creating PV/VG/LVs and verify no raw terminal table or `Press Enter to continue...` prompt appears.

### 14. Filesystem selector should hide LUKS backing devices when their decrypted layer is in use
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
- **Area:** Filesystem device selection / storage-layer filtering
- **Current behavior:** The filesystem selector still offers `/dev/md0` and `/dev/vda4` even though both contain active LUKS containers. Selecting or formatting either backing device would overwrite the encryption layer.
- **Desired behavior:** When a block device has a LUKS container and its decrypted mapper is active or consumed by another storage layer, hide the encrypted backing device from normal filesystem-format/mount selection. Show only the usable top-level devices, such as `/dev/mapper/luksroot` and LVs built on `/dev/mapper/cryptraid`.
- **Safety:** Do not allow accidental filesystem formatting of an active LUKS backing device. If an advanced workflow ever exposes it, mark it clearly as `LUKS backing device — do not format` and require an explicit destructive override.
- **Priority:** Safety + UI cleanup
- **Regression test:** With LUKS on `/dev/vda4` and `/dev/md0`, verify neither backing device appears as a normal filesystem target while their decrypted/derived devices are active.

### 15. Remove plain `Press Enter to continue...` after filesystem selection
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
- **Area:** Filesystem selection / transition to next installer stage
- **Current behavior:** After all filesystem targets and mount points have been selected, the installer drops to a raw `Press Enter to continue...` prompt.
- **Desired behavior:** Prefer no extra pause at all: once filesystem selection is complete and validated, proceed directly to the next installer stage. If user confirmation is needed before formatting/mounting, use a Dialog summary/confirmation screen instead of a terminal pause.
- **Priority:** UI/workflow cleanup
- **Regression test:** Complete filesystem assignments and verify the installer either advances directly or displays a meaningful Dialog confirmation; no raw Enter prompt should appear.

### 16. Remove plain pause after base archive stage
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
- **Area:** Base archive / transition to next installer stage
- **Current behavior:** After the base archive operation completes, the installer stops at a raw `Press Enter to continue...` prompt.
- **Desired behavior:** On successful completion, continue automatically to the next installer stage. Do not add a Dialog message merely to replace an unnecessary terminal pause. Use Dialog only when there is meaningful information, a warning, an error, or a decision the user needs to make.
- **Priority:** UI/workflow cleanup
- **Regression test:** Complete the base archive stage successfully and verify the installer advances automatically with no raw Enter prompt or redundant OK dialog.

### 17. Installation summary incorrectly reports no encrypted devices
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
- **Area:** Final installation review / LUKS summary
- **Current behavior:** The BFS Installation summary reports `LUKS Encryption: Enabled YES` but `Encrypted devices: no`, even though this test has LUKS containers on `/dev/vda4` (opened as `/dev/mapper/luksroot`) and `/dev/md0` (opened as `/dev/mapper/cryptraid`, then used by LVM).
- **Desired behavior:** Detect and list the actual encrypted backing devices and mapper names in the final review, including LUKS devices that are underneath LVM/RAID layers.
- **Expected example:** `/dev/vda4 -> luksroot` and `/dev/md0 -> cryptraid`.
- **Priority:** Functional review/reporting bug
- **Regression test:** Build RAID5 -> LUKS -> LVM plus a separate LUKS root and verify the final review reports both encrypted devices and their mappings rather than `no`.
### 18. Remove raw `Press Enter to continue...` before BFS Installation summary
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
- **Area:** Transition into final installation review
- **Current behavior:** A raw terminal `Press Enter to continue...` appears before the BFS Installation summary.
- **Desired behavior:** Continue directly into the Dialog review screen unless an actual user decision is required.
- **Priority:** UI/workflow cleanup

### 19. Fatal crypttab generation failure with existing/reopened LUKS mappings
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
- **Area:** LUKS detection / `/etc/crypttab` generation
- **Current behavior:** The installer correctly detects that encrypted storage is present, but `generate_crypttab()` produces zero records and aborts with:

```text
ERROR: Encrypted storage was detected, but no crypttab entries could be generated.
```

- **Test topology:** `/dev/vda4 -> luksroot -> /` and `/dev/md0 -> cryptraid -> LVM -> home/var`.
- **Likely failure point to verify:** `crypt_mapping_records()` discovers `crypt` nodes through `lsblk`, then relies on `lsblk ... PKNAME` to derive the encrypted backing device. Existing/reopened device-mapper stacks may not be represented the way this code expects.
- **Desired behavior:** Discover active LUKS mappings from the actual block-device topology regardless of whether they were created in the current installer process or opened before restarting the installer. Generate entries for both root and encrypted RAID mappings.
- **Expected crypttab mappings:** `luksroot` backed by the LUKS UUID of `/dev/vda4`; `cryptraid` backed by the LUKS UUID of `/dev/md0`.
- **Priority:** Critical functional blocker
- **Regression test:** Restart installer with pre-opened LUKS mappings, select filesystems on mapper/LVM descendants, and verify `/etc/crypttab` is generated correctly without relying on current-session LUKS state.


### 20. Base archive path prompt is not using Dialog
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r2.sh`
- **Area:** Base archive selection
- **Current behavior:** The installer asks for the base/rootfs archive path using a plain terminal prompt rather than Dialog.
- **Desired behavior:** Use a Dialog `--inputbox` (or a file/path selector if practical) with the detected/default base archive path pre-filled, so the user can accept or edit it without leaving the Dialog UI.
- **Priority:** UI cleanup
- **Regression test:** Reach base archive selection and verify the archive path is requested entirely through Dialog with the default path visible/editable.


### 21. Final installation review does not show configured RAID arrays
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r4.sh`
- **r4 correction:** The earlier `/proc/mdstat` parser checked the wrong field (`$2 ~ /^raid/`) for lines shaped like `md0 : active raid5 ...`, causing `RAID enabled: YES` but an array list of `none`. r4 parses the actual MD status line correctly and reports the live array.
- **Area:** Final installation review / RAID summary
- **Current behavior:** The final review omits the configured software RAID array(s), so the storage summary does not show the RAID layer even when `/dev/md0` is part of the installation topology.
- **Desired behavior:** Add a RAID section to the review showing each array device, RAID level, member devices, size, and current state. For this test topology it should show `/dev/md0`, RAID5, and members `/dev/vdb1 /dev/vdc1 /dev/vdd1 /dev/vde1 /dev/vdf1`.
- **Detection:** Derive the review from actual active MD state (`/proc/mdstat`/`mdadm --detail`) rather than only installer-session variables, so restarted/resumed installs are reported correctly.
- **Priority:** Review/reporting correctness
- **Regression test:** Restart the installer with an existing active RAID5 and verify the final review still lists the array, level, and members.

### 22. Filesystem and mount-point assignment needs a single multi-entry Dialog workflow
- [x] Partial workflow fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r2.sh`
- **Note:** Replaced the repeated `Add another?` prompt with a persistent selector and explicit `Done selecting filesystems` action. A fuller Add/Edit/Remove planner can still be refined later if desired.
- **Area:** Filesystem selection / mount-point assignment
- **Current behavior:** The installer configures one filesystem/mount point at a time and repeatedly asks whether the user wants to add another partition/filesystem.
- **Desired behavior:** Replace the repeated yes/no loop with a persistent Dialog assignment screen. The user should be able to move through eligible devices, add/edit/remove assignments, and see the complete filesystem plan before selecting `Done`.
- **Suggested workflow:** Show eligible top-level devices in one menu; selecting a device opens its filesystem/format/mount-point options; return to the same assignment screen with the configured value displayed. Provide `Add/Edit`, `Remove`, `Back`, and `Done` actions rather than repeatedly asking `Add another?`.
- **Safety:** Continue hiding consumed backing devices such as active LUKS parents and RAID member partitions. Clearly identify EFI, boot, swap, mapper devices, and LVs.
- **Validation on Done:** Require exactly one `/`, reject duplicate mount points, validate EFI/boot choices where applicable, and show a final filesystem plan before destructive formatting.
- **Priority:** Major UI/workflow improvement
- **Regression test:** Configure `/`, `/boot`, `/boot/efi`, swap, `/home`, and `/var` without answering a repeated yes/no prompt after each assignment.


### 23. make-ca package conflicts with ca-certificates ownership
- [x] Fix
- **Implemented in:** `Pkgfile-make-ca-release4-fixed`
- **Area:** Package installation / CA trust store
- **Current behavior:** `make-ca 1.16.1-3` tries to install `etc/ssl/certs/ca-certificates.crt`, but that path is already owned by the installed `ca-certificates` package, causing `pkgadd` to abort.
- **Confirmed owner:** `ca-certificates` owns `etc/ssl/certs/ca-certificates.crt`; current link is `/etc/ssl/certs/ca-certificates.crt -> /etc/ssl/cert.pem`.
- **Desired behavior:** Do not have `make-ca` package own a path already owned by `ca-certificates`. Remove the compatibility symlink from the make-ca package and ensure the CA trust-store packages provide a consistent chain that httpup can use.
- **Priority:** Critical packaging/install blocker
- **Regression test:** Fresh install with both ca-certificates and make-ca must complete without file-ownership conflicts, and `ports -u` must succeed afterward.


### 24. Add intelligent default mount points during filesystem assignment
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r3.sh`
- **Area:** Filesystem / mount-point assignment
- **Current behavior:** Mount points must be entered manually even when the selected device name or filesystem makes the intended mount point obvious.
- **Desired behavior:** Pre-fill a sensible mount-point suggestion while keeping it editable by the user.
- **Suggested defaults:**
  - LV named `home` -> `/home`
  - LV named `var` -> `/var`
  - LV named `root` -> `/`
  - dm-crypt mapping named `luksroot` -> `/`
  - `ext2` partition -> `/boot` when `/boot` is not already assigned
  - `vfat`/FAT32 partition -> `/boot/efi` when `/boot/efi` is not already assigned
  - swap -> `swap`
- **Safety:** Defaults are suggestions only. Do not overwrite an existing assignment or guess for generic Btrfs/ext4/XFS devices without a useful device/LV/mapping name.
- **Priority:** Filesystem workflow improvement
- **Regression test:** Selecting `bfs-vg/home`, `bfs-vg/var`, `/dev/vda2` ext2, `/dev/vda1` vfat, and `luksroot` should pre-fill `/home`, `/var`, `/boot`, `/boot/efi`, and `/` respectively.
### 25. Show complete filesystem plan in the final Yes/No confirmation
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r3.sh`
- **Area:** Filesystem assignment confirmation
- **Current behavior:** The final confirmation page presents only Yes/No, so the user cannot verify what was selected before continuing.
- **Desired behavior:** The confirmation Dialog must display the complete pending filesystem plan above the Yes/No choice.
- **Display for each assignment:** device, filesystem, mount point, and whether it will be formatted/reformatted. Include swap explicitly.
- **Example information:** `/dev/mapper/luksroot -> btrfs -> /`, `/dev/bfs-vg/home -> btrfs -> /home`, `/dev/bfs-vg/var -> btrfs -> /var`, `/dev/vda2 -> ext2 -> /boot`, `/dev/vda1 -> vfat -> /boot/efi`, `/dev/vda3 -> swap`.
- **Behavior:** `Yes` accepts the displayed plan; `No` returns to the filesystem assignment screen so selections can be corrected rather than discarding the whole workflow.
- **Priority:** Safety / usability
- **Regression test:** Configure multiple filesystems and verify the final Yes/No Dialog visibly lists every selected device, filesystem, mount point, format choice, and swap before the user commits.

### 26. Convert "Show Current Storage Devices" to Dialog and remove Enter pause
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r3.sh`
- **Area:** Storage menu / current-device display
- **Current behavior:** `Show Current Storage Devices` dumps storage information to the terminal and then uses a raw `Press Enter to continue...` pause.
- **Desired behavior:** Capture the storage-device output and display it in a scrollable Dialog window (`--textbox` or equivalent) with normal Dialog navigation such as OK/Back.
- **Required cleanup:** Remove the terminal `Press Enter to continue...` prompt entirely. Closing the Dialog should return directly to the storage menu.
- **Priority:** UI consistency
- **Regression test:** Open `Show Current Storage Devices`; verify no raw terminal output or Enter pause appears.
### 27. Preselect git and wget in Optional Software
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r3.sh`
- **Area:** Optional Software Dialog
- **Current behavior:** `git` and `wget` are not enabled by default.
- **Desired behavior:** Show both `git` and `wget` as selected/on by default while still allowing the user to deselect either package.
- **Priority:** Default-package usability
- **Regression test:** Open Optional Software on a fresh installer run and verify both `git` and `wget` are initially checked.

### 28. Add save/load support for complete installer configuration profiles
- [~] Partial implementation
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r3.sh` (profile save/load UI, non-secret core settings, filesystem assignments, device validation)
- **Remaining:** RAID/LUKS/LVM creation is currently imperative in v50, so a profile cannot yet safely recreate those layers from scratch. Finish this when storage setup is refactored into a declarative plan; never store LUKS passphrases.
- **Area:** Installer configuration / main menu
- **Goal:** Allow the user to save the current installer selections to a reusable configuration file and load a saved configuration on a later installer run.
- **Save:** Store non-secret installer choices including hostname, timezone, locale, network configuration, users/user options, storage topology selections, RAID configuration, LUKS device/mapping choices, LVM configuration, filesystem and mount-point assignments, Btrfs/Snapper choices, optional software, base archive choice, bootloader/GRUB choices, and normal/fallback EFI installation choices.
- **Load:** Populate installer state from the selected profile so the user does not need to answer every installer question again.
- **Secrets:** Never store user/root passwords, LUKS passphrases, private keys, or other authentication secrets in the profile. Prompt for those normally when required.
- **Validation:** Loading a profile must validate devices and other machine-specific values against the current system. Missing or changed devices must be clearly flagged and returned to the user for correction; never blindly perform destructive operations using stale device paths.
- **Review:** A loaded profile must still pass through the normal installer review/confirmation screens before destructive actions or installation begin.
- **UI:** Add Dialog options such as `Load configuration`, `Save current configuration`, and `Save configuration as...`.
- **Format:** Use a documented, human-readable configuration format that can be inspected and edited manually.
- **Portability:** Where practical, allow stable identifiers such as UUID/PARTUUID/LABEL in addition to `/dev/...` paths so profiles survive device-name changes.
- **Priority:** Major usability / repeat-install feature
- **Regression test:** Save a complete configuration, restart the installer, load it, verify all non-secret choices are restored, verify passwords/passphrases are still requested, and verify a deliberately missing storage device is detected before any destructive operation.

### 29. Returning from final chroot should go directly back to installer menu
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r3.sh`
- **Area:** Final chroot / installer navigation
- **Current behavior:** After exiting the BFS chroot, the installer prints:

```text
Returned from the BFS chroot.

Press Enter to continue...
```

- **Desired behavior:** Remove the terminal pause entirely. After the chroot exits successfully, return directly to the installer menu (or the appropriate post-install menu) without requiring an extra Enter key.
- **UI:** If a message is desired, show it briefly in Dialog or simply return to the menu; do not drop to raw terminal output.
- **Priority:** UI/workflow cleanup
- **Regression test:** Enter the final BFS chroot, exit it, and verify the installer immediately returns to the menu with no raw `Press Enter to continue...` prompt.


### 30. Encrypted storage is not activated automatically at boot
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r4.sh`
- **Area:** GRUB / Dracut kernel command line / encrypted-root boot
- **Severity:** Critical boot blocker
- **Observed first-boot behavior:** GRUB passed the Btrfs root filesystem UUID (`root=UUID=d342daa4-...`) but no `rd.luks.uuid=` parameter. Dracut waited for that Btrfs UUID for roughly 200 seconds, then dropped to the debug shell because `/dev/mapper/luksroot` had never been created.
- **Root LUKS proof:** `/dev/vda4` correctly reports `TYPE=crypto_LUKS` with UUID `d202ab19-7873-49cf-b625-53d4f8471d06`. Manually running `cryptsetup open /dev/vda4 luksroot` immediately exposed the expected Btrfs UUID `d342daa4-1c49-4616-bf94-bc6cd2690055`, after which exiting the Dracut shell allowed boot to continue.
- **Encrypted RAID proof:** The installed system then assembled `/dev/md0` RAID5 successfully with all 5/5 members, but `/dev/mapper/cryptraid` was absent. `/dev/md0` correctly reported `TYPE=crypto_LUKS` with UUID `e46a2023-298f-475e-8627-32847f93411b`. Manually running `cryptsetup open /dev/md0 cryptraid` followed by `vgchange -ay` exposed the `bfs-vg/home` and `bfs-vg/var` LVs and allowed boot to complete.
- **Current GRUB defaults:** `/etc/default/grub` contains only `GRUB_CMDLINE_LINUX_DEFAULT="consoleblank=1800"`.
- **Dracut detection proof:** `dracut --print-cmdline` detects at least the encrypted root and recommends `rd.luks.uuid=luks-d202ab19-7873-49cf-b625-53d4f8471d06`.
- **Desired behavior:** During bootloader/initramfs configuration, derive required Dracut arguments from the actual selected storage topology and add them to the GRUB kernel command line. At minimum include every LUKS container needed for the installed filesystem tree. For this topology that means the root LUKS UUID and the LUKS-on-MD UUID; also ensure the MD/LVM portions required to reach encrypted RAID-backed filesystems are not disabled in early boot.
- **Suggested arguments for this test topology:** `rd.luks.uuid=luks-d202ab19-7873-49cf-b625-53d4f8471d06`, `rd.luks.uuid=luks-e46a2023-298f-475e-8627-32847f93411b`, plus the LVM/MD activation arguments recommended by root-run `dracut --print-cmdline` for the active layout.
- **Installer validation:** Before declaring installation complete, compare the generated GRUB command line with `dracut --print-cmdline`/the detected storage topology and fail or warn if an encrypted root lacks an `rd.luks.uuid=` argument.
- **Regression test:** Rebuild initramfs and GRUB, cold boot with no mappings pre-opened, verify the boot process prompts for required LUKS passphrase(s), creates `luksroot` and `cryptraid` automatically, assembles `/dev/md0`, activates `bfs-vg`, mounts `/`, `/home`, and `/var`, and reaches the normal login without a Dracut/emergency-shell intervention.

- **Confirmed root cause / proof:** Explicit `rd.luks.uuid=` arguments fixed automatic encrypted-root activation. `rd.md=1` alone was not sufficient to assemble the MD array in early boot. Adding `rd.auto` caused `/dev/md0` to assemble automatically with all 5/5 members, after which Dracut found the LUKS container on `/dev/md0`, prompted for it, activated LVM, and booted normally.
- **Permanent implementation:** r4 derives storage arguments dynamically from `/etc/crypttab`, `/etc/fstab`, live LVM metadata, and the detected RAID requirement. It writes storage arguments to `GRUB_CMDLINE_LINUX` in `/etc/default/grub` so they persist across future kernel upgrades and also apply to recovery entries. `consoleblank=1800` remains in `GRUB_CMDLINE_LINUX_DEFAULT`.
- **Generated arguments:** MD RAID adds `rd.auto rd.md=1`; every required crypttab UUID adds `rd.luks.uuid=luks-<UUID>`; every selected filesystem backed by an LV adds `rd.lvm.lv=<VG>/<LV>`.
- **Validation:** After `grub-mkconfig`, r4 verifies that the generated Linux entries contain all required RAID/LUKS/LVM arguments and also checks recovery entries when present.



### 31. "Assemble existing arrays" aborts clean install when no arrays exist
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r6-classic-slackware.sh`
- **Area:** Software RAID / assemble-existing workflow / error handling
- **Observed behavior:** On a deliberately clean target with all previous MD signatures wiped, selecting "Assemble existing arrays" runs `mdadm --assemble --scan`. `mdadm` correctly returns non-zero with `No arrays found in config file or automatically`, but the installer's global ERR trap treats that expected result as fatal and aborts near line 1777.
- **Root cause:** The r5 function attempted to tolerate the command with `set +e`, but a bare failing command can still interact with the installer's ERR trap. The command must execute in a conditional context where failure is explicitly handled.
- **Desired behavior:** No existing arrays is a normal condition on a fresh install. Show a Dialog message explaining that no arrays were found and return to the RAID menu so the user can choose `Create a new array`.
- **Fix:** Run `mdadm --assemble --scan` inside an `if` condition, capture its status without triggering the fatal ERR path, and distinguish "no arrays exist" from a partial/real assembly failure.
- **Regression test:** Wipe all MD member signatures, enter Software RAID -> Assemble existing arrays, verify the installer shows a non-fatal "No existing RAID arrays were found" Dialog and returns to the RAID menu.


### 32. LUKS mapper name is lost after prompt
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r7-classic-slackware.sh`
- **Area:** LUKS create/open workflow / Bash variable scoping
- **Observed behavior:** LUKS2 formatting succeeds, but the installer reports `The new container was created, but /dev/mapper/ could not be opened.` The mapper name is blank, `/dev/md0` contains a valid LUKS2 header, and `/dev/mapper/cryptraid` remains inactive.
- **Root cause:** `ask_mapping_name()` declared a local variable named `mapping` while also receiving `mapping` as the caller's output-variable name. Because Bash local variables are dynamically scoped, `printf -v "$result_variable"` updated the helper's local `mapping`, leaving `luks_menu`'s `mapping` empty.
- **Fix:** Rename the helper-local value to `selected_mapping`, so `printf -v "$result_variable"` writes back to the caller's `mapping` variable.
- **Regression test:** Create a LUKS container on `/dev/md0`, accept the default mapper name `cryptraid`, verify `/dev/mapper/cryptraid` is created and active, then continue into LVM setup.


### 33. Active MD RAID array disappears from LUKS target selector
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r8-classic-slackware.sh`
- **Area:** LUKS target discovery / MD RAID integration
- **Observed behavior:** After creating `/dev/md0`, the RAID array was no longer offered as a target when creating a new LUKS container, even though `/proc/mdstat` showed the array active.
- **Root cause:** LUKS target discovery depended primarily on `lsblk TYPE` matching `raid*`. MD device TYPE reporting can vary with util-linux/array state, so a valid assembled `/dev/md*` device could be omitted.
- **Fix:** Enumerate active MD arrays directly from `/proc/mdstat` first, add them explicitly to the LUKS candidate list, deduplicate them against the later `lsblk` scan, and continue suppressing the individual member partitions.
- **Regression test:** Create `/dev/md0`, enter LUKS -> Create a new LUKS container, verify `/dev/md0` appears while its member partitions do not.



### 34. Existing LUKS selector duplicates an MD-backed LUKS container
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r21.sh`
- **Area:** LUKS reopen UI / device deduplication
- **Observed behavior:** A LUKS container on `/dev/md0` appeared once for every RAID member because recursive `lsblk` repeated the same MD path.
- **Fix:** Deduplicate LUKS candidates by canonical device path before building the Dialog menu.
- **Regression test:** Close an MD-backed LUKS mapping, choose Open existing LUKS, and verify `/dev/md0` appears exactly once.

### 35. LVM PV selector duplicates RAID/LUKS mapper paths
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r21.sh`
- **Area:** LVM physical-volume UI / device deduplication
- **Observed behavior:** `/dev/mapper/cryptraid` could appear multiple times because recursive `lsblk` repeated descendants beneath each MD member.
- **Fix:** Deduplicate LVM candidate devices by path before presenting the checklist.
- **Regression test:** With RAID -> LUKS active, verify `/dev/mapper/cryptraid` appears exactly once in the PV selector.

### 36. Volume-group creation should select from existing physical volumes
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r21.sh`
- **Area:** LVM UI / volume-group creation
- **Current behavior:** Creating a volume group asks for physical-volume device path(s) as free-form text.
- **Desired behavior:** Query actual initialized physical volumes with `pvs` and present them in a Dialog checklist. Allow selecting one or more PVs with Space, then create the requested VG from those selections.
- **Suggested flow:** `Create PV` -> device checklist -> `pvcreate`; `Create VG` -> deduplicated existing-PV checklist -> `vgcreate`; `Create LV` -> existing-VG selector -> LV name/size -> `lvcreate`.
- **Why:** Prevents typing mistakes, prevents selecting devices that are not initialized PVs, and makes the LVM workflow consistent with the rest of the storage UI.
- **Related cleanup:** Apply the same device-path deduplication rule used for Issues #34/#35 so RAID/LUKS-backed PVs appear only once.
- **Regression test:** Create a PV on `/dev/mapper/cryptraid`, choose Create volume group, verify the PV appears exactly once in the checklist, select it, create `bfs-vg`, and confirm `vgs`/`pvs` show the expected relationship.


### 37. Filesystem confirmation does not show the selected filesystem plan
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r21.sh`
- **Area:** Filesystem assignment / confirmation UI
- **Current behavior:** After selecting devices, filesystem actions, and mount points, the final Yes/No confirmation only asks `Use these filesystem and mount-point selections?` and does not display the actual selections.
- **Expected behavior:** The confirmation screen itself must show every selected device, its mount point, and whether it will be formatted or preserved before the user chooses Yes or No.
- **Required display:** For each selected target show at least `Device`, `Mount point`, and an unambiguous action such as `FORMAT as btrfs`, `FORMAT as ext2`, `FORMAT as vfat`, `FORMAT as swap`, or `KEEP existing filesystem / do not format`.
- **Implementation note:** The installer already builds `storage_selection_summary_text()`, but the current Dialog `--yesno` confirmation does not include that summary text. Embed the generated filesystem plan directly into the confirmation prompt (or use an equivalent confirmation Dialog that presents the full plan before Yes/No).
- **Regression test:** Assign `/`, `/boot`, `/boot/efi`, swap, `/home`, `/var`, etc.; select a mix of format and keep actions; choose Done; verify the very next confirmation visibly lists every device, mount point, and format/keep action before accepting Yes.


### 38. Final review does not show configured LVM volume groups or logical volumes
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r21.sh`
- **Area:** Final installation review / LVM summary
- **Observed behavior:** The Review selections screen reports `LVM Enabled: yes` but shows `Volume Group: none` and `Logical Volumes: none` even after the VG/LVs were created and are in use.
- **Expected behavior:** The final review must enumerate the actual active/selected LVM topology instead of only reporting that LVM is enabled.
- **Required display:** Show each VG name and each LV beneath it, including at least the LV path/name and size. Where possible, also show the backing PV(s) so the user can verify the complete `PV -> VG -> LV` chain before installation.
- **Suggested data source:** Query live LVM metadata with `pvs`, `vgs`, and `lvs` rather than relying only on installer state variables, because VGs/LVs may have been created or activated through multiple paths.
- **Example:** `Volume Group: bfs-vg`; `Logical Volumes: /dev/bfs-vg/home (500G), /dev/bfs-vg/var (500G)`; `Physical Volume: /dev/mapper/cryptraid`.
- **Regression test:** Create the RAID -> LUKS -> LVM layout, open Review selections, and verify the real VG and all LVs are listed instead of `none`.


### 39. Make the Classic Slackware theme more authentically nostalgic and make it the default
- [x] Enhancement
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r21.sh`
- **Area:** Dialog theme / visual styling in installer and `bootstrap.sh`
- **Current behavior:** The Classic Slackware theme captures the general cyan/blue/yellow palette, but the screen is too uniformly cyan and the normal text/border contrast feels flatter and more modern than the classic Slackware `setup` appearance. Both scripts currently default to another theme unless a saved setting or environment override selects Slackware.
- **Desired behavior:** Tune only the Classic Slackware theme to more closely resemble the nostalgic ncurses/Dialog Slackware installer look while leaving all other themes available, and make **Classic Slackware the default theme for both the installer and `bootstrap.sh`** on a fresh configuration.
- **Default-selection behavior:** Change the built-in fallback/default theme in both scripts to `slackware`. Existing users who already have a saved theme preference should keep that saved preference; explicit environment overrides such as `BFS_INSTALLER_THEME` / `BFS_BOOTSTRAP_THEME` should continue to take precedence.
- **Visual changes to investigate:** Use a black terminal/screen background with cyan dialog panels; use black/dark normal dialog text; bright yellow dialog titles; strong blue active-selection bars with bright white text; vivid red/blue menu tags or accelerator characters; yellow selected tags where appropriate; stronger gray/white border and scrollbar contrast; and enable the classic Dialog drop-shadow/raised-window effect for this theme.
- **Buttons:** Active buttons should have the high-contrast old Dialog appearance (blue background with bright white/yellow text); inactive buttons should remain clearly distinguishable against the cyan dialog.
- **Scope:** Apply the same Classic Slackware styling consistently to both the BFSOS installer and `bootstrap.sh`. Do not alter the other selectable themes.
- **Regression test:** Cycle through installer and bootstrap menus, yes/no prompts, checklists, password/input boxes, scrolling review dialogs, and storage menus using Classic Slackware. Verify readability, selection visibility, borders/shadows, and a consistent nostalgic Slackware `setup` appearance.


### 40. Add explicit support for separate `/usr` and general non-root mount ordering
- [x] Enhancement
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r21.sh`
- **Area:** Filesystem layout / mount ordering / Dracut early-boot dependencies
- **Current concern:** The installer supports additional mount points, but separate `/usr` needs stronger handling than ordinary mounts such as `/opt`, `/srv`, `/var`, or `/home`.
- **Required behavior for `/usr`:** Treat `/usr` as an early-boot-critical filesystem. Ensure the final initramfs can reach every storage layer required to mount it (plain block device, LUKS, MD RAID, LVM, etc.), generate the correct `/etc/fstab` entry, and include `/usr` in the same storage-dependency validation used for root.
- **Dracut module requirement:** When `/usr` is a separate filesystem, automatically add Dracut's `usrmount` module to the generated BFS storage config (for example `add_dracutmodules+=" usrmount "`). If `/usr` depends on LUKS, MD RAID, or LVM, also include the corresponding `crypt`, `mdraid`, and/or `lvm` modules based on the actual `/usr` ancestry.
- **Initramfs validation:** After rebuilding the initramfs, verify that the image contains `usrmount` whenever `/usr` is separate, plus every required supporting storage module. Fail or warn before reboot if the early-boot `/usr` dependency cannot be satisfied.
- **General mount-order rule:** Mount all selected filesystems before rootfs extraction and before chroot/package configuration so files destined for separate mount points such as `/usr`, `/opt`, `/var`, or `/home` are written to the correct filesystem instead of being placed underneath the future mount point on `/`.
- **Normal additional mounts:** `/opt`, `/srv`, `/var`, `/home`, `/tmp`, and other non-early-boot mount points can use the normal additional-filesystem path, but they still must be mounted before extraction/configuration when their content is part of the base system or installed packages.
- **Validation:** Before installation, detect duplicate/nested mount-point conflicts and establish parent-before-child mount order. Before first boot, verify `/usr` is reachable from the initramfs when it is separate.
- **Regression tests:** Test at least (1) separate plain `/usr`; (2) `/usr` on LVM; (3) `/usr` on LUKS/LVM or RAID-backed storage; and (4) separate `/opt` to confirm files are extracted onto the intended filesystem. For every separate-`/usr` case, inspect the final initramfs and confirm `usrmount` and the required storage modules are present before cold boot.


### 41. Add installer accessibility option for larger virtual-console font
- [x] Enhancement
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r21.sh`
- **Area:** Accessibility / installer settings / Linux virtual console
- **Motivation:** High-DPI and 4K displays can make the default Linux virtual-console font difficult to read. The installer should provide an easy large-font mode for users with low vision.
- **Installer setting:** Add a Settings option such as `Console font size` with at least `Default`, `16`, and `20` choices. Apply the selected font immediately to the live installer console so menus and text become easier to read during installation.
- **Runtime-only switch:** Add a command-line/environment switch that enables large-console mode when launching the installer from a terminal without permanently changing the selected installed-system console font. Example interfaces could be `--large-console`, `--console-font=16`, `--console-font=20`, or an environment variable such as `BFS_CONSOLE_FONT=20`.
- **Installed-system option:** Allow the user to choose whether the selected large font should also be written into the installed system's vconsole configuration so the same larger font is used at boot/login after installation.
- **Implementation direction:** Use `setfont` with an installed console font that is known to exist. Detect available PSF fonts before presenting sizes, and gracefully fall back to the current font if the requested font is unavailable.
- **Persistence:** Save the installer UI font preference alongside the existing installer settings, while keeping the runtime-only launch switch able to override it for the current run.
- **High-DPI behavior:** Do not assume a fixed screen resolution. The feature should be font-size based so it works on 1080p, 1440p, 4K, and VM consoles.
- **Regression tests:** Test the installer on a normal console and a 4K/high-DPI console; verify switching between Default/16/20 applies immediately; verify the launch-time switch works; verify the installed-system vconsole font is only changed when explicitly requested.

## Previously Identified / Fixed During This Test Cycle
### make-ca CA bundle compatibility

-   [x] Add `/etc/ssl/certs/ca-certificates.crt` compatibility symlink
    to the make-ca port.
-   [x] Correct make-ca description.
-   [x] Confirm make-ca 1.16.1.
-   [x] Remove circular `make-ca -> p11-kit -> make-ca` package
    dependency.
-   [x] `ports -u` works after CA fix.

### LUKS / cryptsetup

-   [x] cryptsetup 2.8.7 port installs successfully.
-   [x] Complete RAID + LUKS + LVM functional boot proof. Fresh r4 installer regression still recommended.
-   [x] Complete encrypted-root boot proof after adding the confirmed GRUB/Dracut arguments from Issue #30.

## New Issues During Testing

*Add each new issue below before continuing so it is not forgotten.*

### Issue

-   [ ] Fix
-   **Area:**
-   **Current behavior:**
-   **Desired behavior:**
-   **Priority:**
-   **Regression test:**

## Final v50 Cleanup Checklist

-   [x] Convert remaining text-mode submenus/prompts to Dialog where
    appropriate.
-   [ ] Verify Back/Cancel works from every storage submenu without
    terminating installer.
-   [ ] Verify RAID member selector only shows appropriate partitions.
-   [ ] Verify already-selected RAID members disappear from subsequent
    selection choices.
-   [ ] Verify RAID arrays are detected correctly even if Linux
    assembles them as `/dev/md127` instead of `/dev/md0`.
-   [x] Verify LUKS detection automatically installs cryptsetup.
-   [x] Verify `/etc/crypttab`.
-   [x] Verify Dracut includes required `crypt`, `mdraid`, and `lvm`
    support.
-   [x] Verify GRUB kernel command line for encrypted root.
-   [x] Verify RAID + LUKS + LVM survives reboot with the confirmed Issue #30 arguments.
-   [ ] Verify Snapper configs and initial snapshots.
-   [ ] Verify EFI GRUB installation and fallback
    `EFI/BOOT/BOOTX64.EFI`.


## v50 Tracker Fix Build

- **Generated:** 2026-08-09
- **Script:** `install-bfs-menu-v50-tracker-fixed-r3.sh`
- **Syntax check:** `bash -n` passed.
- **r2 additions:** Dialog base-archive path input, RAID review generated from live mdadm state, filesystem-selection loop now uses an explicit Done action, and make-ca release 4 removes the ca-certificates file conflict.
- **Critical crypttab change:** active dm-crypt mappings now obtain their backing device from `cryptsetup status` rather than `lsblk PKNAME`, which was blank for the reopened mappings in this test.
- **Test next:** reuse the existing RAID/LUKS/LVM topology, select the filesystems/mount points, and run through installation to verify crypttab, dracut, GRUB, and encrypted-root boot.


## r3 Remaining-Changes Build

- **Generated:** 2026-08-09
- **Script:** `install-bfs-menu-v50-tracker-fixed-r3.sh`
- **Syntax check:** `bash -n` passed.
- **Implemented:** intelligent mount-point defaults; filesystem plan embedded directly in the final Yes/No confirmation; Current Storage Devices moved to Dialog; git + wget default on; final chroot returns directly to the installer menu.
- **Profiles:** added Save, Save As, and Load under Installer Settings. Profiles exclude passwords/passphrases and validate saved block-device paths. Full RAID/LUKS/LVM recreation remains intentionally tracked as partial until those menus are converted from immediate destructive actions to a declarative storage plan.


## r4 Boot-Storage Fix Build

- **Generated:** 2026-08-09
- **Script:** `install-bfs-menu-v50-tracker-fixed-r4.sh`
- **Issue #30:** dynamically generates permanent GRUB/Dracut storage arguments and stores them in `/etc/default/grub`; RAID adds the confirmed `rd.auto rd.md=1`, LUKS UUIDs come from `/etc/crypttab`, and required LV arguments are derived from `/etc/fstab` plus LVM metadata.
- **Future kernels / recovery:** storage arguments are written to `GRUB_CMDLINE_LINUX`, not only the generated `grub.cfg`, so later `grub-mkconfig` runs and recovery entries retain the required storage topology.
- **Validation:** installer verifies generated normal/recovery GRUB entries contain required RAID/LUKS/LVM arguments.
- **Issue #21:** fixed the live `/proc/mdstat` parser that could report `RAID enabled: YES` while listing arrays as `none`.
- **Additional UI cleanup:** assembling existing RAID arrays and viewing RAID details now stay in Dialog instead of dropping to raw terminal output with `Press Enter to continue...`.
- **Still partial by design:** Issue #28 profile support does not recreate RAID/LUKS/LVM destructively from a profile until storage setup is refactored into a declarative plan.


## r21 Storage / UI / Accessibility Polish Build

- **Generated:** 2026-08-10
- **Installer:** `install-bfs-menu-v50-tracker-fixed-r21.sh`
- **Bootstrap:** `bootstrap-r21-classic-slackware-default.sh`
- **Syntax checks:** `bash -n` passed for both scripts.
- **Issues #34/#35:** deduplicate MD-backed LUKS and LVM device paths.
- **Issue #36:** VG creation now selects from real unassigned PVs; LV creation selects from real VGs.
- **Issue #37:** filesystem confirmation now embeds the full device/mount/FORMAT-or-KEEP plan before Yes/No.
- **Issue #38:** final review queries live `pvs`, `vgs`, and `lvs` metadata.
- **Issue #39:** Classic Slackware is the fresh-install default in installer and bootstrap, with black screen, cyan panels, stronger borders, blue selections, and Dialog shadow.
- **Issue #40:** non-root filesystems are mounted parent-before-child before extraction; separate `/usr` causes `usrmount` to be forced into the generated Dracut config and verified in the completed initramfs.
- **Issue #41:** installer Settings now provide Default/16/20 console-font choices, optional installed-system persistence, plus runtime-only `--large-console`, `--console-font SIZE`, and `BFS_CONSOLE_FONT` overrides.
- **Issue #28 remains intentionally partial:** profile replay does not yet recreate destructive RAID/LUKS/LVM topology; that still requires a declarative storage planner and must never store passphrases.

## r22 Follow-up Issues Found During VM Regression Testing

### 42. Add a destructive storage-reset helper for repeated installs and recovery
- [x] Fix / enhancement revalidated
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r27.sh`
- **r27 regression fix:** Expanded MD detection to report active arrays and inactive member metadata with `mdadm --examine`; the destructive checklist now retains RAID-member devices after array deactivation and labels them explicitly before zeroing superblocks/wiping selected metadata.
- **Area:** Installer Settings / storage maintenance / test workflow
- **Goal:** Add an explicit Settings action that detects old LVM, LUKS, and MD RAID state and can tear it down cleanly before a fresh installation.
- **UI:** Add a clearly destructive option such as `Reset existing storage metadata...`. Never run it automatically.
- **Detection:** Before confirmation, enumerate active and inactive MD arrays, LUKS mappings/containers, LVM PVs/VGs/LVs, swap devices, mounted target filesystems, and stale filesystem/signature metadata.
- **Preview:** Show exactly what will be affected before doing anything: mounts to unmount, swap to disable, VGs/LVs to deactivate/remove, LUKS mappings to close, MD arrays to stop, member devices whose MD superblocks will be removed, and devices on which `wipefs` will run.
- **Safety:** Require an explicit destructive confirmation. Exclude the live installer media, BFSOS source/build disk, and any device not selected/confirmed by the user. Never guess that an unrelated disk is safe to erase.
- **Order of operations:** Unmount target filesystems -> swapoff -> deactivate/remove LVs/VGs/PVs as requested -> close LUKS mappings -> stop MD arrays -> zero MD superblocks when requested -> run `wipefs` on confirmed backing devices/arrays -> `udevadm settle`.
- **Modes:** Ideally provide both `Deactivate only` and `Destroy metadata / fresh start` so normal recovery work does not require wiping anything.
- **Why:** Repeated VM installer testing currently requires many manual `vgchange`, `cryptsetup close`, `mdadm --stop/--zero-superblock`, and `wipefs` commands.
- **Regression test:** Build RAID -> LUKS -> LVM storage, leave it active, invoke the reset helper, confirm the preview is correct, perform a full reset, and verify `pvs`, `vgs`, `lvs`, `/dev/mapper`, `/proc/mdstat`, and `lsblk -f` show the expected clean state while the BFSOS build disk remains untouched.

### 43. Partition/filesystem Cancel must return to Storage setup, not abort installation
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r26.sh`
- **Area:** Storage assignment / Dialog navigation / error handling
- **Observed behavior:** Cancelling the partition/filesystem selection path can escape as a non-zero return and trigger `ERROR: Installation cancelled`, invoking fatal cleanup.
- **Desired behavior:** `Back` or Dialog Cancel returns to Storage setup. Only an explicit `Cancel installation`/Quit action may terminate the installer.
- **State preservation:** RAID/LUKS/LVM objects already created should remain available when returning to Storage setup unless the user explicitly removes them.
- **Regression test:** Create RAID/LUKS/LVM state, enter filesystem assignment, press Cancel, and verify the installer returns to Storage setup with storage state intact and no fatal cleanup.

### 44. Improve failure logging for navigation and generated/chroot failures
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r26.sh`
- **Area:** Logging / ERR trap
- **Current behavior:** Some failures produce only `ERROR: Installation cancelled` or `Installation stopped near line 1`, hiding the command/function that actually returned non-zero.
- **Desired behavior:** Log the failing command, source file, function stack, real line number, and exit status. Normal Dialog Back/Cancel return codes must be handled explicitly and never reach the fatal ERR path.
- **Log preservation:** Keep the live-environment installer log even when target mounts are cleaned up, and copy it into the installed system whenever the target remains available.

### 45. Rework filesystem-plan confirmation into a readable scrollable view
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r26.sh`
- **Area:** Filesystem confirmation UI
- **Observed behavior:** With many devices/LVs the confirmation table wraps across lines and becomes difficult to read.
- **Desired behavior:** Use a wide, vertically scrollable fixed-column view showing at least Number, Device, Action (`FORMAT as ...` / `KEEP`), and Mount point. Keep Continue/Back controls clear and prevent rows from wrapping into each other.
- **Priority:** Safety-critical readability before destructive formatting.

### 46. Improve mount-point defaults from logical-volume/device names
- [x] Enhancement
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r26.sh`
- **Area:** Filesystem assignment / mount-point suggestion
- **Desired behavior:** Infer common mount points from the final LV/device component: `root` -> `/`, `usr` -> `/usr`, `opt` -> `/opt`, `home` -> `/home`, `var` -> `/var`, `tmp` -> `/tmp`, `srv` -> `/srv`, and `swap` -> swap. Keep the suggestion editable.

### 47. Loaded profiles must refresh main-menu configured/pending indicators
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r26.sh`
- **Area:** Installer profiles / main menu state
- **Observed behavior:** Profile values appear to load, but sections still show `[PENDING]`.
- **Desired behavior:** After loading a profile, recalculate each section status from restored values. Storage may remain pending when destructive topology still requires manual recreation.

### 48. Match the Classic Slackware theme to Slackware's actual current dialogrc
- [x] Enhancement
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r26.sh` and `bootstrap-r26.sh`
- **Area:** Installer and bootstrap theme
- **Reference verified:** Slackware64-current `dialog-1.3_20260721-x86_64-1.txz`, `etc/dialogrc.new` (`$Id: slackware.rc,v 1.13 2025/12/22 ...`), which Slackware's `build_installer.sh` copies into the installer as `/etc/dialogrc`.
- **Correction to earlier assumption:** Slackware intentionally uses a BLUE full-screen background. Do not replace it with black merely to look more nostalgic.
- **Goal:** Make BFSOS `Classic Slackware` match the real Slackware dialog palette and behavior as closely as practical, while retaining BFSOS-specific text/layout.
- **Behavior values:** `aspect = 0`, `separate_widget = ""`, `tab_len = 0`, `visit_items = OFF`, `use_scrollbar = OFF`, `use_shadow = ON`, `use_colors = ON`.
- **Core palette:** `screen_color = (WHITE,BLUE,OFF)`, `shadow_color = (WHITE,BLACK,OFF)`, `dialog_color = (BLACK,CYAN,OFF)`, `title_color = (YELLOW,CYAN,ON)`, `border_color = (CYAN,CYAN,ON)`.
- **Buttons:** active `(WHITE,BLUE,ON)`; inactive uses `dialog_color`; inactive accelerator/key `(RED,CYAN,OFF)`; inactive label `(BLACK,CYAN,ON)`.
- **Input/search:** input `(BLUE,WHITE,OFF)` with normal border; search `(YELLOW,WHITE,ON)`; search title `(WHITE,WHITE,ON)`; search border `(RED,WHITE,OFF)`.
- **Menus/items:** menubox and item use `dialog_color`; selected item uses `screen_color`.
- **Tags:** normal tag uses `title_color`; selected tag uses `screen_color`; tag key uses inactive button-key color; selected tag key `(RED,BLUE,ON)`.
- **Checklist/arrows:** check uses `dialog_color`; selected check `(WHITE,CYAN,ON)`; up/down arrows `(GREEN,CYAN,ON)`.
- **Other verified values:** position indicator uses inactive button-key color; item-help uses shadow color; active form text uses inputbox color; form text `(CYAN,BLUE,ON)`; readonly form item `(CYAN,WHITE,ON)`; gauge `(BLUE,WHITE,ON)`; border2/inputbox_border2/searchbox_border2/menubox_border2 use `dialog_color`.
- **Scope:** Apply the same authentic Classic Slackware theme implementation to both the BFSOS installer and `bootstrap.sh`.
- **Regression test:** Compare installer/bootstrap menus, input boxes, checklists, selected rows, buttons, titles, arrows, shadows, and gauges against Slackware's current `dialogrc` behavior.

### 49. Simplify large-console-font persistence
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r26.sh`
- **Area:** Accessibility / console font settings
- **Desired behavior:** Selecting `Large 16` or `Large 20` should apply immediately to the installer and automatically configure the installed BFSOS virtual console to use the same font. Remove the separate `Use selected console font after install` question. `Default` retains the normal installed-system default.

### 50. Optional Software and sudo should not start as pending
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r26.sh`
- **Area:** Main-menu status/defaults
- **Optional Software:** Never show `[PENDING]`; no optional packages is valid. Use `[OPTIONAL]` initially and `[CONFIGURED]` after choices are made.
- **Sudo:** If untouched, default to normal sudo authentication requiring the user's password and show `[DEFAULT]` (or equivalent), not `[PENDING]`.
- **General rule:** Reserve `[PENDING]` for sections that genuinely require user attention before installation can proceed.
- **Optional package addition:** Add the existing BFSOS `wpa_supplicant` port (`ports/core/wpa_supplicant`) to Optional Software.

### 51. Review/install forward action should be Continue
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r26.sh`
- **Area:** Review/install navigation
- **Desired behavior:** The forward action from Review into installation must be labeled `Continue`. `Back` must only return to the previous configuration screen. Make cancellation an explicit separate action.

### 52. Detect stale signatures on newly created MD arrays
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r26.sh`
- **Area:** MD RAID -> LUKS workflow
- **Observed behavior:** A newly created `/dev/mdX` can expose a stale `crypto_LUKS` or filesystem signature from previous contents, causing the LUKS `Create new container` selector to hide the otherwise valid RAID array.
- **Desired behavior:** Immediately after MD creation, inspect the array with `wipefs`. If stale signatures are present, show them and offer an explicit `Wipe signatures`, `Keep`, or `Cancel` choice before continuing.
- **Safety:** Never silently wipe signatures.

### 53. Pre-reboot validation: complex encrypted RAID/LVM/Btrfs install is boot-test ready
- [x] Validation passed
- **Area:** Final installation validation / Dracut / GRUB / storage
- **Validated topology:** UEFI + separate ext2 `/boot`; LUKS `cryptroot` -> LVM `bfs-root` -> separate Btrfs `/`, `/usr`, and `/opt`; MD RAID -> LUKS `cryptraid` -> LVM `bfs-vg` -> separate Btrfs `/home` and `/var`; Btrfs snapshot subvolumes; disk swap.
- **Dracut modules verified in generated initramfs:** `btrfs`, `crypt`, `crypt-lib`, `dm`, `lvm`, `mdraid`, `rootfs-block`, and `usrmount`.
- **Separate `/usr` support verified:** initramfs contains Dracut `pre-pivot/50-mount-usr.sh`; generated `/etc/dracut.conf.d/20-bfs-storage.conf` records `Separate /usr: yes` and forces `usrmount crypt lvm mdraid`.
- **GRUB verified:** generated kernel command line contains `root=/dev/mapper/bfs--root-root`, `rootflags=subvol=@`, `rd.auto`, `rd.md=1`, both LUKS UUID arguments, and `rd.lvm.lv=bfs-root/root`; correct BFSOS kernel and initramfs paths are present.
- **ZRAM verified:** kernel config has `CONFIG_ZRAM=m` and the installed `zram.ko` exists under `/lib/modules/7.1.5-BFS-Linux/kernel/drivers/block/zram/`.
- **Decision:** Do not make further Dracut/GRUB changes before the reboot test. The current configuration should be tested as generated by the installer.
- **Next test:** Cleanly leave chroot/unmount, reboot from the installed disk, confirm both LUKS prompts/unlocks, MD assembly, both VGs, separate `/usr`, `/opt`, `/var`, `/home`, and successful systemd userspace boot.

### 54. Update installed release branding URLs from BFS-Linux to BFSOS
- [ ] Fix
- **Area:** `aaa_filesystem` / `/etc/os-release` branding
- **Observed behavior:** Installed `/etc/os-release` still uses `https://codeberg.org/bmadonnaster/BFS-Linux` for `HOME_URL`, `SUPPORT_URL`, and `BUG_REPORT_URL` even though the repository has been renamed to BFSOS.
- **Desired behavior:** Change all three generated URLs to the current BFSOS repository and BFSOS issues page.
- **Scope:** Search release/branding files and installer-generated metadata for any remaining stale `BFS-Linux` repository references so new installs do not recreate them.
- **Priority:** Cosmetic/non-boot-blocking; fix after the current reboot test rather than modifying this installed test system before first boot.

### 55. Rename the blue theme to Classic Debian and reproduce Debian's real installer palette from source
- [x] Enhancement
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r26.sh` and `bootstrap-r26.sh`
- **Area:** Installer and bootstrap themes / Debian-inspired theme
- **Rename:** Change the existing blue-theme display name to **Classic Debian** everywhere it appears in installer menus, bootstrap menus, saved theme/profile labels, help text, and documentation. Preserve the existing internal key where practical for compatibility, or add a migration/alias so saved configurations using the old theme name still load correctly.
- **Research source of truth:** Do not rely on screenshots or memory. Base the Classic Debian palette on Debian's actual installer frontend source.
- **Primary Debian source:** Debian's installer uses `cdebconf` with a `newt` frontend. The authoritative source tree is the Debian Installer Team `cdebconf` repository and the versioned Debian Sources copies.
- **Historical evidence:** Debian's `cdebconf` changelog records explicit newt color changes, including support for a dark background via `FRONTEND_BACKGROUND=dark` and later readability changes for select, multiselect, and button colors.
- **Related palette source:** `newt` itself defines color-set roles such as root, border, window, shadow, title, button, active button, checkbox, entry, listbox, textbox, helpline, and progress-scale colors. Debian's frontend may override or remap these, so inspect `cdebconf`'s newt frontend first and use `newt` defaults only where Debian leaves them unchanged.
- **Research targets:** Locate and compare the current and historically representative Debian installer newt frontend code/config for root/screen, window/dialog, borders/shadows, titles, active/inactive buttons, entries, normal/selected menu rows, checkboxes/radiolists, help/status text, progress bars, and any `FRONTEND_BACKGROUND` logic.
- **Implementation goal:** Translate the verified Debian installer palette into the BFSOS Dialog-based theme as faithfully as practical while keeping BFSOS-specific layouts and controls.
- **Scope:** Apply the renamed **Classic Debian** theme consistently to both the BFSOS installer and `bootstrap.sh`; do not alter Classic Slackware or other themes.
- **Compatibility:** Existing saved profiles/configs referring to the old blue-theme identifier/name must continue to work and should map automatically to Classic Debian.
- **Regression test:** Compare BFSOS Classic Debian menus, prompts, input boxes, checklists, selected rows, buttons, titles, shadows, help text, and progress displays against the Debian installer source-defined appearance; verify theme selection and saved-profile migration work in both installer and bootstrap.
- **Research starting points:** Debian Installer Team `cdebconf` source on Salsa; Debian Sources package history for `cdebconf`; `cdebconf` newt frontend source and changelog entries for `FRONTEND_BACKGROUND=dark`; Debian `newt` source for base color-set definitions where needed.

- **Source research completed for r26:** Debian `cdebconf` 0.280 `src/modules/frontend/newt/newt.c` uses `newtDefaultColorPalette` unless `FRONTEND_BACKGROUND=dark`; its alternate dark palette remains explicitly defined in the frontend. Debian's `cdebconf` changelog documents the black-background mode and later select/multiselect/button readability changes.
- **Classic palette basis used in BFSOS:** the normal newt palette roles map to white-on-blue root/screen, black-on-light-gray window/border, red-on-light-gray title/active button, yellow-on-blue entry/selected-list accents, and a white-on-black shadow. Dialog's `WHITE` is used as the closest standard-color approximation to newt `lightgray`.
- **Compatibility:** the internal theme key remains `classic`, so existing settings/profiles continue loading while the visible name changes from `Classic Blue` to `Classic Debian`.
### 56. Add explicit early-boot GRUB/LVM arguments for separate `/usr`
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r26.sh`
- **Area:** GRUB generation / Dracut early-LVM activation / separate `/usr`
- **Observed boot failure:** With `/usr` on `bfs-root/usr`, Dracut loaded `usrmount` and all required storage modules, unlocked `cryptroot`, activated `bfs-root/root`, and mounted root, but `/usr` failed because `bfs-root/usr` was not activated early. The generated kernel command line contained `rd.lvm.lv=bfs-root/root` but omitted `rd.lvm.lv=bfs-root/usr`.
- **Manual proof:** Adding `rd.lvm.lv=bfs-root/usr` to the GRUB kernel command line allowed the system to boot successfully.
- **Required fix:** Whenever `/usr` is on an LVM LV, add an explicit `rd.lvm.lv=<VG>/<LV>` argument for that `/usr` LV in addition to the root LV argument.
- **General rule:** Generate explicit `rd.lvm.lv=` arguments for every filesystem that is genuinely required in initramfs/early userspace, not merely every LV in the system.
- **Do not over-broaden by default:** Normal late mounts such as `/opt`, `/var`, `/home`, `/srv`, and similar filesystems do not need explicit early-LVM kernel arguments solely because they are LVs. Let normal systemd/fstab activation handle them after switch-root unless their ancestry is needed to reach `/usr` or another early-boot-critical path.
- **RAID/LUKS handling:** Continue generating explicit early-boot RAID/LUKS arguments from the ancestry of root and separate `/usr`. It is safe to include required parent MD/LUKS devices, but avoid blindly adding every unrelated RAID/LUKS device in the machine because that can trigger unnecessary unlock prompts, array assembly, delays, or failures for storage that is not required to boot.
- **Topology-driven implementation:** Walk the block-device ancestry for `/` and `/usr`; collect only the required LVM LVs, LUKS UUIDs, and MD arrays; deduplicate arguments; persist them in `GRUB_CMDLINE_LINUX`; regenerate `grub.cfg`; and verify the generated normal and recovery entries contain all required early-storage arguments.
- **Regression tests:** 
  1. Root on LVM with no separate `/usr`.
  2. Root + separate `/usr` on different LVs in the same VG.
  3. `/usr` on LUKS -> LVM.
  4. `/usr` on MD RAID -> LUKS -> LVM.
  5. Extra unrelated LVs/RAID/LUKS present for `/home`, `/var`, or data; confirm they do not cause unnecessary early boot prompts or kernel arguments.

- **Boot regression confirmed/fixed:** the first cold boot failed because only `bfs-root/root` was activated. Manually adding `rd.lvm.lv=bfs-root/usr` in GRUB allowed BFSOS to boot successfully. r26 now derives explicit `rd.lvm.lv=` arguments from `/` and `/usr` only, rather than all LVs.
- **Topology scope:** required LUKS UUIDs and MD discovery flags are likewise derived from the ancestry of `/` and `/usr`, avoiding unnecessary unlock prompts or assembly of unrelated data/home storage.

## r26 Tracker Implementation Pass

- **Generated:** 2026-08-10
- **Installer:** `install-bfs-menu-v50-tracker-fixed-r26.sh`
- **Bootstrap:** `bootstrap-r26.sh`
- **Syntax checks:** `bash -n` passed for both scripts.
- **Issues completed in this pass:** #42, #43, #44, #45, #46, #47, #48, #49, #50, #51, #52, #55, #56.
- **Issue #54 remains open:** `/etc/os-release` URL correction belongs in the `aaa_filesystem` port/Pkgfile rather than either of the two scripts supplied for this pass.
- **Storage maintenance:** Settings now includes a previewed `Deactivate only` mode and an explicit checklist-driven destructive metadata reset. Protected live-root/project storage is excluded.
- **Filesystem navigation/UI:** Back from filesystem assignment returns to Storage setup; the final plan is shown in a wide scrollable textbox followed by Continue/Back confirmation; LV names such as `usr`, `opt`, `var`, `home`, `tmp`, and `srv` get sensible mount-point suggestions.
- **Profiles/status:** loaded profiles recalculate configured/pending state; Optional Software defaults to `OPTIONAL`; sudo defaults to password-authenticated `DEFAULT`.
- **Optional software:** `wpa_supplicant` is available as an optional package.
- **Console accessibility:** selecting Large 16/20 automatically persists that choice to the installed system; selecting Default disables persistence.
- **Themes:** Classic Slackware now uses the exact Slackware `dialogrc` values gathered during testing; Classic Blue is renamed Classic Debian and translated from Debian cdebconf/newt source while preserving the `classic` internal key.
- **RAID stale signatures:** newly-created arrays are checked with `wipefs -n` and the user is explicitly offered a safe wipe/keep choice.
- **Failure diagnostics:** ERR trap now records exit status, source, line, function, command, and caller instead of `line 1`.
- **Install navigation:** final installation confirmation is Continue/Back; Back returns to configuration instead of triggering fatal cleanup.
- **Early boot storage:** GRUB arguments are derived from boot-critical `/` and `/usr` ancestry. Separate `/usr` on LVM now receives its own `rd.lvm.lv=` parameter.

## r27 Follow-up Issues Found During Installed-System Testing

### 57. Fix GRUB/Dracut topology logic for complex storage
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r27.sh`
- **Area:** GRUB generation / Dracut / complex storage
- **Observed behavior:** The completed install did not automatically emit the complete boot-storage arguments required by the tested topology. Manual correction was required before reboot.
- **Required behavior:** Derive boot-critical storage ancestry and emit the required `rd.luks.uuid=`, `rd.md.uuid=`, and `rd.lvm.lv=` arguments. Finalize `/etc/crypttab` and mdadm configuration before rebuilding the initramfs, then regenerate `grub.cfg` and validate the generated boot entries/initramfs.
- **Regression scope:** LUKS -> LVM and MD RAID -> LUKS -> LVM, including separate `/usr` and complex Btrfs layouts.
- **r27 implementation:** Generates explicit `rd.md.uuid=` values for mounted MD-backed filesystems, LUKS UUID arguments for boot-critical and MD-backed mounted filesystems, and `rd.lvm.lv=` for root/separate `/usr` plus mounted LVs carried by MD storage. GRUB verification checks normal and recovery entries against the same discovered topology.

### 58. Final Review screen still shows Back instead of Continue
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r27.sh`
- **Area:** Review/install navigation
- **Observed behavior:** During the latest real install, the Review screen immediately before installation still displayed `Back` at the bottom instead of the intended forward `Continue` action.
- **Note:** Issue #51 was previously marked fixed in r26, so the latest test indicates the wrong dialog code path or a regression remains.
- **Desired behavior:** Review must present an unambiguous forward `Continue` action; `Back` must only return to configuration and cancellation must remain separate.
- **r27 implementation:** The actual `Review selections` textbox now labels its exit action `Continue`; the following installation confirmation retains the separate Back path.

### 59. Consolidate BFSOS logs under `/var/log/bfs`
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r27.sh` and `bootstrap-r27.sh`
- **Area:** Bootstrap/build logging / installer logging
- **Observed behavior:** Build logs are currently installed under `/var/logs/bfs-build/`, while installer logs correctly use `/var/log/bfs/installer/`.
- **Desired layout:** `/var/log/bfs/bfs-build/` for package/bootstrap build logs and `/var/log/bfs/installer/` for installer logs.
- **Cleanup:** Remove new uses of the legacy `/var/logs` path and update log-copy/install logic so all BFSOS-specific logs live below `/var/log/bfs/`.
- **r27 implementation:** Bootstrap copies base-package build logs to `/var/log/bfs/bfs-build`; installer logs remain `/var/log/bfs/installer`.

### 60. Add `wireless_tools` to Optional Software
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r27.sh`
- **Area:** Optional Software
- **Package:** `wireless_tools` 30.pre9
- **Status:** Port built and runtime tools verified during installed-system testing.
- **Desired behavior:** Offer `wireless_tools` in the installer's Optional Software selection alongside `wpa_supplicant`.
- **r27 implementation:** Added `BFS_INSTALL_WIRELESS_TOOLS`, profile save/load support, Dialog/text optional-package selection, and chroot package-list installation.

## r27 Test Notes

- Full installer run completed without installer errors before first reboot.
- `wpa_supplicant` 2.11 was verified installed and runnable against OpenSSL 4 (`libssl.so.4` / `libcrypto.so.4`).
- `wireless_tools` was successfully built after correcting the BFSOS port to invoke `build_opt` from `pkg_build` and package the statically linked utilities without expecting a nonexistent `libiw.so.30` from the default upstream build.

### 61. Clear terminal screen on installer/bootstrap exit
- [x] Fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r27.sh` and `bootstrap-r27.sh`
- **Area:** Installer/bootstrap terminal cleanup / UI
- **Observed behavior:** Exiting the installer or `bootstrap.sh` can leave the full-screen `dialog` background and menu colors painted across the terminal instead of restoring a clean shell view.
- **Desired behavior:** On every normal exit, Cancel/Quit path, and handled error exit, restore the terminal state and clear/redraw the screen before returning to the shell.
- **Implementation note:** Centralize terminal cleanup in the existing exit/cleanup handler so both the installer and bootstrap consistently run the appropriate `clear`/terminal-reset sequence after `dialog` is closed. Avoid scattering cleanup calls through individual menus.
- **Regression test:** Exit normally, use Back/Cancel/Quit paths, and trigger a handled failure under each theme; confirm the shell returns with no stale installer/bootstrap background, colors, cursor state, or screen contents.
- **r27 implementation:** Both scripts centralize terminal reset in their EXIT cleanup handlers, reset SGR attributes, show the cursor, and clear/redraw `/dev/tty` after restoring `DIALOGRC`.


## r27 Implementation Pass

- **Generated:** 2026-08-11
- **Installer:** `install-bfs-menu-v50-tracker-fixed-r27.sh`
- **Bootstrap:** `bootstrap-r27.sh`
- **Issues addressed:** #42 regression, #57, #58, #59, #60, #61.
- **Still open:** #54 (`aaa_filesystem` branding URLs) because the port Pkgfile was not part of this script pair.
- **Required regression test:** run a fresh complex-storage VM install and verify generated GRUB/initramfs without manual edits, storage-reset RAID detection/destruction, Review button label, optional `wireless_tools`, installed log paths, and clean terminal exit.
