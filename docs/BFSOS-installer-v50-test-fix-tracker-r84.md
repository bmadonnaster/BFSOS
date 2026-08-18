# BFSOS Installer v50 Test / Fix Tracker

## r84 implementation / regression-audit pass — 2026-08-18

- **Installer r47 created:** `scripts/install-bfs-menu-v50-r47-tracker-fixes.sh`.
- **Kernel-selection crash fixed:** `kernel_pkgfile_version()` now initializes locals in nounset-safe steps, validates the requested port name, and returns `unknown` instead of aborting for missing/malformed data. Static `bash -u` tests returned live versions for `linux`/`linux-lts` and `unknown` for missing/blank requests.
- **ZRAM review/visibility completed:** the final pre-install review already contained ZRAM state/size and is retained; the Current storage devices view now adds configured/active ZRAM; the ZRAM menu marks the active size with `[CURRENT]`.
- **MD stale-signature regression repaired:** after a new MD array is created, the installer now inspects the array itself for surviving filesystem/LUKS/LVM signatures and offers Keep, Remove, or Cancel. LVM VGs exposed by stale metadata are deactivated before an explicitly approved removal. The new MD array itself remains active.
- **Partition-screen safety improvement:** disks whose partition tables actually changed during the current installer session are marked `[MODIFIED THIS SESSION]`; simply opening/exiting `cfdisk` does not mark the disk because before/after kernel-visible partition fingerprints are compared.
- **Bootstrap Stage 3 ccache hardened:** when ccache is enabled, Stage 3 now verifies the BFSOS ccache binary/wrappers before rebuilding, prepends `/usr/lib/ccache` to the Stage-3 build PATH from the first package, and prints ccache statistics before/after the rebuild.
- **Bootstrap verification status:** successful option 4 now displays bright-yellow `[PASSED!]` rather than green `[COMPLETE]` in both Dialog and text menus.
- **GCC branding fixed:** final GCC now uses `--with-pkgversion="BFSOS"`; the package release is bumped to `2`. The shipped default/LTS kernel config compiler-text fields were also refreshed to `gcc (BFSOS) 16.2.0` (kernel releases bumped to force fresh packages). Attribution comments elsewhere in core/non-core ports were intentionally not rewritten.
- **Last-night regression audit:** no malformed `;;;` case terminators remain in `bootstrap.sh` or `ports/core/pkgutils/Pkgfile`; both scripts parse with `bash -n`. Temporary-toolchain and target UTF-8 locale generation/validation code remains present. The current clean test reached Stage 2 and GCC 16.2 extracted successfully without the previous pathname error, confirming the critical temporary-glibc locale fix in real use. RAID6 creation also reached a live six-member array without the old post-create `wipefs` busy crash, confirming that ordering fix for RAID6.
- **Still requires runtime testing:** failed-download installer resume, storage deactivation/MD stop, Back-navigation paths, all RAID levels other than the newly retested RAID6, ccache hit/miss activity across a full Stage 3, archive restore locale verification, and hardware/bare-metal/release/post-1.0 items.
- **Audit report:** `docs/BFSOS-r84-static-regression-audit-20260818.md` records the static regression checks and the remaining live tests.


## r74 implementation pass — 2026-08-18

- **Installer r46 created:** `scripts/install-bfs-menu-v50-r46-tracker-fixes.sh`.
- **Bootstrap updated:** Stage 1 temporary-glibc UTF-8 locale is now required/verified before toolchain archive creation; the archive is checked for the locale archive; Stage 2 generates and validates the target `C.utf8` locale immediately after glibc installation; Stage 1 `pkgmk` failure capture was hardened.
- **pkgutils updated:** release bumped to 10 and `pkgmk` locale selection now validates actual charmap usability with the libc/toolchain associated with the running `pkgmk`, rather than trusting `locale -a` alone.
- **glibc updated:** temporary glibc now generates and validates its own `C.UTF-8` locale archive before GCC pass 2.
- **Installer fixes implemented:** RAM-backed pkgmk workspace defaults on; storage deactivation unwinds filesystems/LVM/dm-crypt/MD and reports incomplete cleanup; RAID member signatures are handled before `mdadm --create`; ZRAM settings UI is state-aware; kernel versions are read from Pkgfiles; package/download failure capture and persistent non-secret resume profile/checkpoints were hardened; Back/Cancel paths for base archive and optional package selection are non-fatal.
- **Already present and retained:** GPM optional package support and `gpm.service` enablement.
- **GNU source cleanup:** 29 core GNU ports were moved from `ftpmirror.gnu.org` to canonical `ftp.gnu.org/gnu`; the hierarchical kernel.org fallback remains pending downloader support.
- **Not falsely marked complete:** hardware/runtime regression tests, RC/release documentation milestones, post-1.0 UI roadmap items, and the hierarchical GNU mirror fallback. CRUX `PKGMK_SOURCE_MIRRORS` is a flat filename cache; a path-aware GNU alternate-host downloader still requires a deliberate `pkgmk` download-layer enhancement rather than an inert config variable.





### Installer build settings — RAM-backed pkgmk workspace default
- [x] **IMPLEMENTED in installer r46; runtime regression pending:** `RAM-backed pkgmk workspace` now defaults to `Yes` for new installer settings.
  - Current testing shows the feature enabled, but the installer default should explicitly be **Yes** rather than depending on inherited/previous settings.
  - Keep the setting user-configurable so RAM-backed build work can still be disabled.
  - Keep `RAM workspace maximum` defaulting to **Auto**, using the installer's calculated recommendation (16G in the current VM test).
  - This is an installer/build-settings default issue, not a Bootstrap issue.


### Installer storage deactivation — active MD RAID arrays are not stopped
- [x] **FIX IMPLEMENTED in installer r46; runtime regression pending:** storage deactivation now unwinds the stack and explicitly stops eligible active `mdadm` arrays instead of silently reporting success.
- **Required behavior:** Deactivate storage in dependency order so higher layers are removed before the backing MD device is stopped.
- **Expected order:** unmount filesystems -> deactivate LVM logical/volume groups as applicable -> close dm-crypt mappings as applicable -> stop active MD RAID arrays.
- **MD cleanup:** Stop installer-managed/selected arrays with `mdadm --stop <array>` and verify they disappear from `/proc/mdstat` before returning to the storage menu.
- **Safety:** Do not blindly stop unrelated host/live-environment arrays. Limit cleanup to arrays created, assembled, or explicitly selected by the installer session/topology.
- **Error handling:** If an array cannot be stopped because it is still busy, show a useful Dialog error identifying the remaining dependency/device rather than silently reporting successful deactivation.
- **Regression test:** Create/assemble RAID6, optionally layer LVM on it, choose Deactivate storage, and verify filesystems/LVM are deactivated in order and the MD array is no longer active without requiring a manual `mdadm --stop`.


### Installer base package selection — Back closes installer
- [x] **NAVIGATION HARDENED in installer r46; runtime regression pending:** Back/Cancel from the relevant base-archive/package-selection Dialog paths is explicitly captured and returns to the prior installer screen instead of propagating a nonzero Dialog status.
- **Required behavior:** Treat the Dialog **Back/Cancel** navigation result as normal installer navigation, not as a fatal error or installer exit.
- **Audit:** Check the base-package selection function's Dialog return-code handling and make sure a nonzero Back/Cancel result cannot fall through into `set -e`, an ERR trap, or a top-level exit path.
- **State preservation:** Returning from base package selection should preserve the installer's existing configuration and package selections unless the user explicitly changes or resets them.
- **Regression test:** Enter base package selection, choose **Back**, verify the previous installer menu is displayed, verify the installer process remains running, then re-enter package selection and confirm prior state is intact.


### Installer ZRAM settings screen — state/action mismatch and no-op Enable option
- [x] **FIX IMPLEMENTED in installer r46; runtime regression pending:** the ZRAM screen is state-aware and shows only the meaningful Enable/Disable action, with status/size refreshed after each change.
- **Rework the ZRAM screen** so the available action reflects the current state rather than presenting dead/no-op choices.
- When ZRAM is enabled, show a clear `Current status: Enabled` and current size, and offer **Disable ZRAM** plus the size choices.
- When ZRAM is disabled, show `Current status: Disabled` and offer **Enable ZRAM** plus the size choices as appropriate.
- After enabling/disabling ZRAM or changing its size, immediately redraw/refresh the Dialog so the displayed status and size reflect the new setting.
- Avoid simultaneously presenting both **Enable ZRAM** and **Disable ZRAM** as if both are meaningful actions.
- Preserve the existing 50%, 100%, 150%, 200%, and custom-size choices.
- **Regression test:** Toggle ZRAM on/off repeatedly, select each percentage/custom size, verify the status line updates immediately, and verify no selectable menu entry silently performs a no-op.


### Installer kernel selection — simplify descriptions and show live Pkgfile versions
- [x] **IMPLEMENTED in installer r46; runtime regression pending:** kernel selection now reads versions dynamically from the corresponding Pkgfiles and keeps the LTS annotation to the concise `Debian patch set` label.
- **Default kernel:** Display only the kernel name and its current version, read dynamically from the default kernel port's `Pkgfile`.
- **LTS kernel:** Display the kernel name, its current version read dynamically from the LTS kernel port's `Pkgfile`, and a short note such as **`Debian patch set`**.
- Do not hard-code either kernel version in the installer; kernel updates should automatically be reflected by reading the corresponding `Pkgfile`.
- Keep the LTS description concise; no additional long explanatory text is needed.
- **Regression test:** Change each kernel port's version in its `Pkgfile` and verify the installer kernel-selection screen displays the updated versions without requiring an installer code change.


### Installer failed download / package failure — resume path confirmed broken
- [x] **FIX IMPLEMENTED in installer r46; RELEASE-BLOCKING runtime regression test pending:** package/download failure execution is now captured in conditional status paths, persistent failure/checkpoint state is written in the target, and a non-secret resume profile is left beside the installer so relaunch can reconstruct the previous selections instead of exiting immediately.
- **Resume test result:** FAILED. The current installer cannot recover by simply being relaunched after this failed-download state.
- **Startup/resume audit required:** Trace persisted checkpoint/state loading, target mount/state detection, storage topology reconstruction, startup validation, and all `set -e`/ERR-trap/nonzero-return paths that run before the main installer menu is restored.
- **Required relaunch behavior:** A relaunch after an interrupted package phase must reconstruct the prior configuration, validate/remount the existing target as needed, force completed filesystem format actions to `keep`, and return to the installer menu with **Install / Retry** available rather than terminating.
- **Existing intended behavior:** The installer already has a checkpoint/resume design intended to preserve completed destructive/setup stages and allow a later **Install / Retry** to continue from the failed/incomplete package transaction.
- **Current problem:** Real failed-download testing still shows that this recovery path is not fully reliable; the installer can terminate before the resume UI/checkpoint flow is reached.
- **Required behavior on download/package failure:** Catch nonzero statuses from package/source download, `ports -u`, `prt-get sysup`, `prt-get depinst`, package builds, and optional package installation without terminating the installer process.
- **UI behavior:** Show the normal Dialog failure message with package/operation, URL when detectable, exit status, and preserved installer/package log path, then provide **Continue/Back** to return to the installer main menu.
- **Resume behavior:** On rerun or **Install / Retry**, preserve and validate existing storage/filesystem/base-extraction state, force prior format actions to `keep`, re-run `ports -u` so repaired source metadata is picked up, retry only the failed/incomplete package transaction, and continue from the next incomplete checkpoint.
- **Safety:** Never automatically repartition, recreate RAID/LUKS/LVM, reformat filesystems, or re-extract the base archive if those stages already completed successfully.
- **Checkpoint verification:** Confirm the installer persists enough state to distinguish at least `base_extracted`, `packages_complete`, `system_config_complete`, and `bootloader_complete`, and that state survives an installer process exit/relaunch when possible.
- **Regression test:** Intentionally break one package URL, start installation, allow the download to fail, verify the installer stays alive and returns to its menu, repair the URL from another terminal, select **Install / Retry**, verify `ports -u` reruns, verify no destructive/setup stages repeat, and confirm installation resumes through completion.


### Installer MD RAID creation — signature/wipe ordering is backwards for all RAID levels
- [x] **FIX IMPLEMENTED in installer r46; RAID6 runtime regression PASSED 2026-08-18:** the common MD RAID path checks/clears approved stale signatures on member devices **before** `mdadm --create`; the post-create `wipefs -a "$array_device"` operation was removed. A new six-member RAID6 was created and remained active without the prior `wipefs: Device or resource busy` abort. Other RAID levels still need regression coverage.
- **Scope:** Treat this as a common `create_raid_array()` bug affecting every MD RAID level that uses this path (RAID0/1/5/6/10 and any other supported MD level), not as a RAID6-only issue.
- **Observed failure:** `mdadm` reports the new array started successfully, followed immediately by `wipefs` failing to probe the active array because it is busy.
- **Required ordering:** Select member devices -> detect stale filesystem/RAID signatures on the member devices -> ask the user for erase confirmation when needed -> clear approved stale signatures/old MD metadata from the member devices -> run `mdadm --create` -> allow the newly created `/dev/mdX` to remain active for subsequent filesystem/LUKS/LVM setup.
- **Do not:** Run a blanket post-create `wipefs -a` on the newly active `/dev/mdX`.
- **Safety:** Signature confirmation must identify exactly which member device/signature will be erased. Never wipe unrelated devices or an already-created active array merely as part of RAID creation.
- **Regression tests:** Exercise every installer-supported MD RAID level. Test both clean member disks and members containing stale filesystem/MD signatures. Confirm the erase question occurs before array creation, the approved member signatures are cleared, `mdadm --create` succeeds, `/dev/mdX` remains active, and the installer continues without a `wipefs` busy failure.










### Final pre-install review — include ZRAM configuration
- [x] **IMPLEMENTED / STATICALLY VERIFIED in installer r47 (2026-08-18):** The final **BFS Installation review** includes the selected ZRAM Enabled/Disabled state and configured size.
- **Required review fields:** Show whether ZRAM is **Enabled/Disabled** and, when enabled, the configured size (for example `100% of RAM`, `200% of RAM`, or the exact custom size).
- If the installer computes an effective size from a percentage, the review may also show the resolved size in GiB/MiB where practical.
- The review must reflect the currently selected installer settings, not merely the live environment's current `/dev/zram0` state.
- If ZRAM is disabled, show that explicitly rather than omitting the entry.
- Keep the ZRAM review near other memory/swap/storage settings so the user can verify it before committing to installation.
- **Regression test:** Configure several predefined ZRAM percentages, a custom size, and Disabled; open the final review each time and verify the displayed ZRAM state/size exactly matches the installer configuration.

### Kernel selection crashes installer — `kernel_pkgfile_version()` uses unbound `package`
- [x] **FIXED in installer r47 / nounset static regression passed (2026-08-18):** The r46 kernel-selection crash from an unbound `package` local is corrected; runtime Dialog regression remains to be exercised.
- **Observed failure:** `line 3728: package: unbound variable`.
- Installer error report identifies:
  - Function: `configure_kernel`
  - Failing command: `linux_version="$(kernel_pkgfile_version linux)"`
  - Caller: line 3739
  - Exit status: `1`
- **Likely defect location:** `kernel_pkgfile_version()` around line 3728 references shell variable `package` without safely initializing it from the function argument (for example `local package="${1:-}"`) before use. With `set -u`/nounset active, this immediately aborts the installer.
- **Required fix:** Audit the entire `kernel_pkgfile_version()` helper and its callers. Explicitly initialize every local variable before reference, validate the requested kernel package/port name, and make missing/malformed Pkgfile/version information return a safe fallback instead of terminating the installer.
- Dynamic kernel-version display must remain informational/UI logic and **must never be capable of crashing the installer**.
- Verify both normal/default kernel and LTS kernel lookups, including the requested LTS description/branding behavior.
- **Regression tests:**
  1. Open kernel selection with valid default and LTS Pkgfiles and verify both versions display correctly.
  2. Test a missing Pkgfile, missing `version=` field, empty value, and malformed value; installer must remain running and show a sensible `unknown`/unavailable fallback.
  3. Run with nounset (`set -u`) enabled and confirm no unbound-variable failure.
  4. Back out of kernel selection and re-enter it repeatedly without installer termination.

### Current storage devices view — include configured ZRAM swap
- [x] **IMPLEMENTED in installer r47; runtime UI regression pending (2026-08-18):** Current storage devices now includes configured/active ZRAM state and size.
- **Current behavior:** The storage tree shows physical disks, partitions, MD RAID, LUKS mappings, LVM PV/LVs, filesystems, etc., but the configured ZRAM device is absent.
- **Desired behavior:** Show the ZRAM swap device (normally `/dev/zram0`) with a clear type/status such as `zram swap`, its configured/effective size, and whether it is currently active if that information is available.
- If ZRAM is configured for installation but has not yet been instantiated in the live environment, show a separate concise entry such as `ZRAM swap: enabled, 100% of RAM (configured)` rather than pretending a `/dev/zram0` device already exists.
- Keep ZRAM visually distinct from persistent block storage so users do not mistake it for a disk/partition.
- The displayed size/state should update after changing the ZRAM configuration.
- **Regression test:** Enable/disable ZRAM and test predefined/custom sizes; reopen Current storage devices and verify the displayed ZRAM state and size match the installer configuration.

### ZRAM size menu — clearly mark the currently selected size
- [x] **IMPLEMENTED in installer r47; runtime UI regression pending (2026-08-18):** The current predefined/custom ZRAM size is marked `[CURRENT]` directly in the menu.
- **Observed behavior:** With ZRAM enabled at 100%, the choices `50%`, `100%`, `150%`, `200%`, and `Custom` all look identical. The blue highlight only indicates the current cursor position and can therefore be mistaken for the configured value.
- **Desired behavior:** Add an unmistakable marker to the active configuration, for example `Size: 100% of RAM [SELECTED]` or `[CURRENT]`, and update it immediately whenever the user chooses another size.
- If a custom size is active, show the actual configured custom value and mark the Custom entry as selected/current.
- Keep the header summary, but make the menu state independently understandable without relying on the header.
- Consider using the same selected/current-state convention on other installer option menus where cursor highlight and configured value can otherwise be confused.
- **Regression test:** Select each predefined ZRAM size and a custom size, return to/reopen the screen, and confirm exactly one choice clearly reflects the persisted current configuration.

### Newly created MD RAID — detect surviving LVM metadata and ask whether to preserve or remove it
- [x] **IMPLEMENTED in installer r47; runtime Keep/Remove/Cancel regression pending (2026-08-18):** New MD arrays are inspected for surviving signatures including LVM metadata and the user is explicitly offered Keep, Remove, or Cancel.
- **Observed during testing:** A newly created RAID6 `/dev/md0` immediately appeared as an `LVM2_member` and caused the old `bfs-raid` VG with `home` and `var` LVs to reactivate, even though the RAID member disks had just been repartitioned/recreated.
- **Detection:** Inspect the newly available `/dev/mdX` with appropriate non-destructive signature/LVM discovery (`wipefs` read-only inspection, `pvs`, etc.) before using it for LUKS, a new PV, formatting, or other destructive operations.
- **If existing LVM is detected:** Present an explicit choice explaining that existing LVM metadata/logical volumes were found on the RAID device:
  - **Keep existing LVM** — preserve the PV/VG/LVs and do not wipe or overwrite their metadata.
  - **Remove existing LVM** — clearly warn that the existing VG/LVs and their data will be destroyed; deactivate the affected VG/LVs safely, then remove the stale LVM signature/metadata from the selected MD device only.
  - **Cancel / Back** — make no changes.
- Never automatically destroy an existing LVM signature merely because the MD array was newly created; surviving metadata may contain data the user intentionally wants to recover or reuse.
- If the user chooses removal, verify that no LV is mounted/in use, deactivate the correct VG, operate only on the explicitly selected `/dev/mdX`, refresh LVM/device state, and confirm that `LVM2_member` is gone while the MD array itself remains active.
- After removal, refresh subsequent device selectors so `/dev/mdX` becomes available for workflows such as **RAID -> LUKS -> LVM**.
- **Regression test:** Recreate an MD array whose data area still contains a valid LVM PV/VG, confirm the installer detects it, test Keep/Remove/Cancel independently, and verify no unrelated disk or VG is modified.

### Installer partition-disk screen — identify disks modified during current session
- [x] **IMPLEMENTED in installer r47; runtime UI regression pending (2026-08-18):** Partition disks whose kernel-visible partition layout changed are marked `[MODIFIED THIS SESSION]`.
- **Current problem:** The screen lists only device path and size (for example `/dev/vda 250G`), so after editing several similarly sized disks it is easy to lose track of which devices were already changed.
- **Preferred behavior:** Keep modified disks visible, but append a clear status marker such as **`[MODIFIED]`**, **`[PARTITIONED]`**, or **`[CHANGED THIS SESSION]`** after the device/size. Do not silently remove a disk from the list merely because `cfdisk`/`fdisk` wrote a partition table; disappearing entries could make the user think a disk vanished or failed.
- **Detection/state:** Track devices opened through the installer partition editor and mark a disk only after the partitioning tool exits successfully and the kernel sees a changed partition table. Where practical, compare the before/after partition-table state so simply opening and exiting without changes does not falsely mark the disk modified.
- **Refresh:** Run the normal partition-table/device refresh (`partprobe`/`udevadm settle` or installer equivalent) after leaving the partition editor, then redraw the list with the updated status.
- **Optional enhancement:** Show a concise partition summary for modified disks (for example partition count or key partition sizes/types) in a detail/status view without overcrowding the primary selector.
- **Persistence scope:** The marker only needs to represent changes made during the current installer session; it does not need to imply that an existing disk from before installer startup was modified by BFSOS.
- **Regression test:** On a VM/system with many similar disks, edit multiple disks, return to the partition-disk selector after each edit, and verify each actually changed disk is clearly marked while untouched disks remain unmarked and all disks remain selectable.

### Bootstrap Stage 3 — ensure ccache is used for the entire rebuild
- [x] **IMPLEMENTATION HARDENED in bootstrap r84; full Stage-3 statistics regression pending (2026-08-18):** ccache preflight, wrapper PATH from the first Stage-3 package, and before/after statistics are now enforced when ccache is enabled.
- Stage 3 should inherit/use the configured ccache setting consistently across every applicable package build.
- Verify `CC`, `CXX`, compiler wrappers/PATH ordering, and `pkgmk.conf` handling so individual ports cannot unintentionally bypass ccache unless a package explicitly requires it.
- Preserve any intentional package-specific ccache exclusions and document why they are necessary.
- Add/check ccache statistics before and after Stage 3 so a test run can confirm cache hits/misses are actually being recorded.
- **Regression test:** Run Stage 3 with ccache enabled, confirm applicable package builds invoke ccache, and verify `ccache -s` shows Stage-3 activity.

### Bootstrap verification status — show bright-yellow `[PASSED!]`
- [x] **IMPLEMENTED in bootstrap r84; runtime menu redraw regression pending (2026-08-18):** successful verification now renders bright-yellow `[PASSED!]`.
- **Current behavior:** The Bootstrap menu shows option 4 as green `[COMPLETE]`, which looks the same as ordinary completed build stages.
- **Desired behavior:** A successful verification should display **bright yellow `[PASSED!]`** in the right-hand status column.
- Keep build-stage completion states separate from verification results: stages may remain `[COMPLETE]`, while the verification/check result uses `[PASSED!]`.
- Ensure the status survives normal menu redraws and accurately reflects the most recent successful verification rather than being cosmetic-only.
- **Regression test:** Run option 4 successfully, return to the Bootstrap menu, and confirm option 4 displays bright-yellow `[PASSED!]` with alignment matching the other status fields.

### GCC version branding — `Linux From Scratch` string appears in BFSOS compiler output
- [x] **ROOT CAUSE FOUND / FIXED in r84 (2026-08-18):** `ports/core/gcc/Pkgfile` explicitly passed `--with-pkgversion="Linux From Scratch"`; it now passes `--with-pkgversion="BFSOS"`.
- **Observed behavior:** The compiler version banner is carrying the vendor/package branding string `Linux From Scratch` instead of BFSOS/BFS Linux branding or the normal upstream GCC banner.
- **Required investigation:** Determine exactly where the `Linux From Scratch` vendor string is being injected. Audit the GCC `Pkgfile`, bootstrap GCC pass configuration flags, GCC spec/configure options, patches, environment variables, and any copied LFS-era bootstrap code that may set a package version/vendor suffix.
- **Likely areas to inspect:** GCC configure arguments such as `--with-pkgversion=...`, any `PKGVERSION`/vendor definitions, Stage 1/2/3 GCC build functions, and the final installed GCC package build.
- **Desired behavior:** Replace the stale LFS branding with an appropriate BFSOS/BFS Linux identifier, or leave the upstream GCC banner unbranded if that is preferable. Ensure Stage 1 temporary compilers and the final installed compiler do not accidentally retain unrelated distro branding.
- **Regression test:** After rebuilding GCC, verify `gcc --version` and `g++ --version` no longer display `Linux From Scratch` and that the selected BFSOS/upstream branding is consistent across the final installed compiler.

### Bootstrap archive safety / Stage 5 failure handling
- [x] **IMPLEMENTED in bootstrap r45:** Stage 5 base-rootfs archive creation now runs with root privileges so protected files in the verified rootfs can be read instead of producing permission-denied tar errors.
- [x] Stage 5 explicitly unmounts and verifies the bootstrap bind/virtual mounts are gone before creating the archive, including the external sources/packages/build-work mounts.
- [x] Archive creation now checks the actual `tar` exit status. If compression fails, the partial archive is deleted and Stage 5 returns failure instead of printing a false success message.
- [x] The completed base archive is immediately tested with `tar -tJf` and sanity-checked for required BFSOS files (`/usr/bin/bash`, `/usr/bin/pkgmk`, `/etc/os-release`).
- [x] When Stage 5 is entered through sudo from the interactive menu, ownership of the finished archive is returned to the invoking user.
- [ ] **Regression test:** Re-run Stage 5 and verify no `Permission denied` messages occur, the archive passes validation, and an intentionally forced tar failure is reported as failure with no partial archive retained.

### Bootstrap toolchain archive safety
- [x] **IMPLEMENTED in bootstrap r45:** Toolchain archive compression no longer dumps the complete verbose tar member list to the interactive terminal.
- [x] Toolchain archive creation explicitly checks the compression exit status and deletes a partial archive on failure.
- [x] The archive is verified with `tar -tJf` and sanity-checked for the compiler, linker, and `pkgmk` before Stage 1 reports archive success.
- [ ] **Regression test:** On the next clean Stage 1 run, verify concise compression output, successful integrity/payload checks, and correct failure handling if archive creation is deliberately interrupted.

### Bootstrap Stage 5 success-screen cleanup
- [x] **IMPLEMENTED in bootstrap r45:** After a successful Stage 5 base archive operation, return directly to the Bootstrap main menu instead of showing `Operation completed successfully.` / `Press Enter to return to the menu...`.
- Real Stage 5 failures still report their nonzero status and retain the pause so the error can be read.

### Bootstrap Stage 3 success-screen cleanup
- [x] **IMPLEMENTED in bootstrap r45:** After a successful Stage 3 rebuild, return directly to the Bootstrap main menu instead of showing the redundant success/pause screen.
- Stage 2 uses the same direct-return behavior after success.

### Bootstrap time synchronization audit
- [x] **IMPLEMENTED in bootstrap r45:** Root stages launched from the interactive Bootstrap menu no longer re-run the startup time synchronization when `sudo` re-enters `bootstrap.sh`.
- A top-level invocation still performs the normal startup synchronization; child stage invocations receive `BFS_SKIP_TIME_SYNC=yes`.
- This removes the observed duplicate sync before Stage 3 and Stage 4 while preserving clock synchronization when bootstrap is initially launched.
- [ ] **Regression test:** Run Stages 1-5 through the interactive menu and confirm only the initial bootstrap startup performs time synchronization.

### Bootstrap Stage 3 `build-work` mount cleanup — implementation update
- [x] **IMPLEMENTED in bootstrap r45:** The installed/final `pkgmk` work directory is now `/var/cache/pkg/build-work/pkgmk-$name`, a removable child directory beneath the bind mount, rather than the bind-mount root `/var/cache/pkg/build-work`.
- This prevents pkgmk cleanup from attempting to remove the active mount point and producing `Device or resource busy`.
- [x] The bootstrap unmount helper now returns a real error if a busy bootstrap mount cannot be unmounted instead of repeatedly retrying forever.
- [ ] **Regression test:** Run Stage 3 and confirm no `rm: cannot remove '/var/cache/pkg/build-work': Device or resource busy` warning appears and all bootstrap mounts are gone afterward.



### Bootstrap Stage 3 `build-work` mount cleanup
- [x] **FIX IMPLEMENTED in bootstrap r45; regression test pending:** During Stage 3, `pkgmk` emitted `rm: cannot remove '/var/cache/pkg/build-work': Device or resource busy`, but the package build continued.
- Investigation confirmed `/tmp/lfs-rootfs/var/cache/pkg/build-work` is an active overlay-backed mount sourced from the live environment/project `build-work` path.
- This is separate from the locale fixes and was not caused by changing `LC_ALL`/`LANG`.
- Do not unmount the work directory while a package is actively building.
- Review the bootstrap Stage 3 mount/setup and cleanup logic after the current build completes.
- If the `build-work` mount is intentional, cleanup must remove/clean the contents safely without attempting to `rm` the active mount point itself.
- Ensure cleanup unmounts the work directory at the appropriate end-of-stage/exit path before attempting to remove the mount-point directory.
- Verify normal completion, failure, interruption, and rerun paths do not leave stale `build-work` mounts behind.
- [ ] **Regression test:** On the next clean Stage 3 run, confirm there are no `Device or resource busy` cleanup messages and no stale `build-work` mount remains after Stage 3 exits.



### Bootstrap locale warning root cause and fixes
- [x] **COMPLETED / ROOT CAUSE IDENTIFIED:** Repeated Stage 3 locale warnings were traced to explicit UTF-8 locale overrides rather than random bootstrap behavior.
- Upstream `pkgutils 5.40.12` sets `LC_ALL=C.UTF-8` in `pkgmk.in` (`pkgmk`), which is unsafe during early BFSOS bootstrap phases because `C.UTF-8` is not guaranteed to exist yet.
- The running temporary-toolchain copy of `pkgmk` was corrected from `LC_ALL=C.UTF-8` to `LC_ALL=C`.
- The BFSOS `ports/core/pkgutils/Pkgfile` was updated so `bootstrap_build()` patches upstream `pkgmk.in` to use `LC_ALL=C` before installing the temporary-toolchain copy.
- The same pkgutils port also patches the packaged `/usr/bin/pkgmk` in `post_build()` so the installed BFSOS pkgutils package consistently uses the universally available `C` locale.
- The GCC port was also found to force `LANG=en_US.UTF-8`; `ports/core/gcc/Pkgfile` was changed to use `LANG=C` for bootstrap/build consistency.
- Keep the global bootstrap environment on `LANG=C`, `LC_ALL=C`, and `LANGUAGE=C`.
- [ ] **Verification pending on next clean bootstrap/RC run:** confirm Stage 1/2/3 no longer produce the previous flood of `setlocale: LC_ALL: cannot change locale (C.UTF-8)` warnings.
- If isolated locale warnings remain after a clean rebuild, capture the exact package/log and investigate only that package rather than changing the global locale policy again.
- These locale fixes should be pushed to both the main BFSOS project and the separate ports repository so the bootstrap and port trees remain consistent.

### Bootstrap Stage 3 locale regression check
- [ ] During the next clean Stage 3 rebuild, verify that `pkgmk`, GCC, and shell subprocesses inherit plain `C` and that no build-generated environment reintroduces `C.UTF-8` or `en_US.UTF-8`.
- Check the newly installed temporary-toolchain `pkgmk` with `grep -nE 'LC_ALL|LANG' .../pkgmk` as a regression check after pkgutils is rebuilt.



### Bootstrap Stage 3 time synchronization
- [x] **FIX IMPLEMENTED in bootstrap r45; regression test pending:** Remove the redundant time synchronization step from Bootstrap Stage 3.
- Time is already synchronized when `bootstrap.sh` is initially launched, so Stage 3 should not perform another automatic time sync before rebuilding the base system with the final toolchain.
- Preserve the initial bootstrap startup time synchronization; this change applies specifically to the extra Stage 3 sync.



### Pre-1.0 optional software and console usability checks
- [x] **IMPLEMENTED in current installer/ports tree; runtime regression pending:** GPM is available as an optional package (`ports/opt/gpm`) and the installed-system configuration enables `gpm.service` when selected.
- Check whether a `gpm` port already exists in the BFSOS ports tree. If it does not, create and validate a proper GPM port.
- Add **GPM console mouse support** to the installer Optional Software menu.
- If selected, install GPM and enable/configure the appropriate systemd service so console mouse selection/paste works on a real text console.
- Verify that leaving GPM unselected does not alter the default install.

- [ ] **Bare-metal verification of installer console text-size options before BFSOS 1.0.**
- Verify all existing console font/text-size choices on a real Linux virtual console, not only through QEMU/SPICE or SSH.
- Confirm that selecting each size changes the installer console immediately and that returning to **Default** restores the expected normal size.
- Verify the selected persistent font is written correctly to `/etc/vconsole.conf`.
- After first boot, verify `systemd-vconsole-setup` applies the selected font correctly.
- Confirm the requested font files actually exist in the base system and that any fallback behavior is sensible and visible rather than silently masking a missing font.
- Treat broken/nonfunctional text-size selection as a pre-1.0 installer usability bug.

### Bootstrap Stage 2 completion return behavior
- [x] **FIX IMPLEMENTED in bootstrap r45; regression test pending:** Remove the extra terminal completion/pause screen shown after Bootstrap Stage 2 completes successfully.
- Current behavior displays:
  - `Operation completed successfully.`
  - `Press Enter to return to the menu...`
- After a successful Stage 2 completion, return directly to the **Bootstrap main menu** instead of requiring an extra Enter keypress.
- Keep actual Stage 2 success/failure status visible in the Bootstrap menu itself.
- Do not remove or suppress real error dialogs/messages; this change applies only to the redundant success/pause screen after a successful Stage 2 run.



### BFSOS 1.0 public-release documentation and post-1.0 installer UX roadmap
- [ ] **1.0 release/public launch preparation:** After the 1.0 release-candidate storage/RAID/configuration validation is complete and no release-blocking core issues remain, clean up and rewrite the public `README.md` and supporting documentation for the BFSOS 1.0 release.
- The 1.0 README/docs should clearly explain what BFSOS is, current release/stability status, supported architecture, supported installation/storage configurations, build/install workflow, known limitations, where logs are stored, and how users should report useful bugs/issues.
- Clearly distinguish the **core BFSOS system** from the broader **non-core ports collection**, which will continue to receive cleanup and tooling work after core 1.0 validation.
- After BFSOS 1.0 final is published with polished documentation and usable release/install artifacts, consider/prepare a **DistroWatch submission** to bring additional testers and users to the project.
- Wider public exposure is intended to provide more real-world hardware/configuration coverage and additional bug reports, but should follow—not precede—the 1.0 RC validation cycle.

#### Post-1.0 / target 1.1 timezone and locale selector improvements
- [ ] **Post-1.0 enhancement (target 1.1):** Replace or enhance the current timezone prompt with a Dialog-driven hierarchical/scrollable selector.
- Timezone selection should allow the user to choose a region first (for example `America`, `Europe`, `Asia`) and then move through/select the appropriate city/location from a list.
- Provide consistent **Back**, **Select/Continue**, keyboard navigation, and text-mode fallback behavior matching the rest of the installer.
- [ ] **Post-1.0 enhancement (target 1.1):** Replace or enhance locale selection with a scrollable Dialog checklist/radiolist based on available locales.
- Keep `en_US.UTF-8` as the normal/default user locale unless the user chooses another locale.
- Allow additional locales to be selected/generated when desired, while allowing the system default `LANG` to be chosen separately.
- **The `C` locale must always remain available and must not be removable/disableable by the locale-selection UI.**
- Preserve use of the `C` locale for bootstrap/build operations where deterministic output or operation before the full locale environment exists is desirable.
- These timezone/locale UI improvements are **not BFSOS 1.0 release blockers** unless the existing selectors prove functionally broken during RC testing. Avoid adding unnecessary installer feature risk immediately before 1.0 final.
- These are installer usability improvements suitable for the **1.x series (preferably 1.1)** rather than requiring a 2.0 release.



### BFSOS 1.0-rc1 release-candidate milestone
- [ ] **POTENTIAL 1.0-rc1 CANDIDATE:** If the current bare-metal bootstrap/install completes successfully and the resulting BFSOS system boots correctly without a new release-blocking core issue, treat this build line as the first **BFSOS 1.0-rc1** candidate.
- The immediate release-candidate priority is validation of the **core operating system, bootstrap, installer, boot path, storage layouts, RAID combinations, encryption/LVM/Btrfs configurations, and other supported installation scenarios**.
- Over the next several days, test the remaining RAID/storage/configuration combinations and correct any core/bootstrap/installer/boot regressions discovered during those tests.
- A failure of the current installation to boot is considered a **release-candidate blocker** and must be fixed and retested before promoting the build to 1.0-rc1 status.
- Minor/non-blocking tracker cleanup can continue through the 1.0 release-candidate cycle while the supported installation configurations are validated.
- **Non-core ports are not a 1.0-rc1/core release blocker at this stage.** The broader non-core ports tree is known to need substantial cleanup and should be handled after the 1.0 RCs have established that the core OS and supported installation/storage configurations are reliable.
- After the RAID/configuration matrix is verified through the 1.0 RC cycle and no release-blocking core issues remain, target the final **BFSOS 1.0** release.
- Following core 1.0 validation, shift development emphasis toward repairing/maintaining the non-core ports collection and developing better **ports management, validation, update, and maintenance tooling**.



### Bootstrap time synchronization behavior
- [x] **COMPLETED / VERIFIED:** Synchronize system time once when `bootstrap.sh` starts.
- Do **not** redundantly synchronize time again before Bootstrap Stage 2 when continuing in the same running bootstrap session.
- If the machine is rebooted or a new bootstrap session is started, launching `bootstrap.sh` performs the startup time synchronization again.
- This keeps Stage 2 from doing unnecessary duplicate time-sync work while still ensuring a fresh bootstrap session begins with a corrected clock.



### Bootstrap Stage 1 toolchain archive compression output
- [x] **FIX IMPLEMENTED in bootstrap r45; regression test pending:** After Bootstrap Stage 1 verification succeeds, hide/suppress the verbose toolchain archive compression output during normal interactive use.
- The user does not need to watch the full compression file/progress stream after verification has already completed successfully.
- Show a concise status such as **Compressing toolchain archive...** while the archive is being created, then report the completed archive path/size or a clear error if compression fails.
- Preserve detailed compression output in the appropriate bootstrap log for troubleshooting rather than filling the interactive terminal/menu.




### Bootstrap Stage 1 download-failure recovery regression
- [x] **FAILURE CAPTURE HARDENED in r74 code; intentional failed-download regression pending:** Stage 1 now invokes `pkgmk` in an explicit conditional status path so its nonzero result can return to the existing Bootstrap failure-dialog/menu boundary instead of being treated as an uncaught shell failure.
- **Observed behavior:** A Stage 1 source download failed after three attempts; when the final download attempt failed, the Bootstrap UI closed and returned the user to the shell.
- **Required behavior:** Catch the Stage 1 `pkgmk` nonzero status at the parent/menu boundary. When Dialog mode is available, display the standard failure dialog with the package/operation, failed URL when detectable, exit status, and preserved log path.
- **Navigation requirement:** Selecting **Continue** must return directly to the Bootstrap main menu without terminating `bootstrap.sh`.
- **State preservation:** Preserve all successfully completed Stage 1 package markers/toolchain state so the user can repair the source/port and resume Stage 1 without rebuilding completed packages.
- **Audit target:** Check the Stage 1 parent call chain for `set -e` or other uncaught nonzero-status propagation that bypasses the existing failure-handler code.
- **Regression test:** Intentionally use an invalid Stage 1 source URL, allow all configured download retries to fail, verify the failure Dialog appears, select Continue, verify the Bootstrap main menu remains alive, repair the URL, and confirm Stage 1 resumes from the failed/incomplete package.

### Download/package failure messaging in bootstrap and installer
- [x] **IMPLEMENTATION UPDATED in Bootstrap + installer r46; regression tests still required:** download/package operations now use explicit status capture at the critical Stage 1 and installed-system package boundaries, preserve failure context, and return through their parent UI/retry paths.
- **Observed bootstrap failure:** MPC source download returned HTTP 404 and `pkgmk` exited with status 4. Bootstrap Stage 1 terminated without a clear menu-level explanation, while Bootstrap Stage 2 later displayed the raw error text but still did not use the normal dialog/menu workflow.
- **Bootstrap requirement:** Catch source/download/build failures and show a **dialog error box** when Dialog mode is available. The dialog should identify the package or operation, show the failed URL when known, summarize the underlying downloader/build error, include the exit status, and show the preserved package log path.
- **Bootstrap navigation:** The failure dialog should have a **Continue** button. Selecting Continue must return the user directly to the **Bootstrap main menu** without exiting `bootstrap.sh`.
- **Installer review:** The installer currently invokes `ports -u`, `prt-get sysup`, and `prt-get depinst` directly inside a strict-error shell path. A download/build failure from those commands can therefore abort the installation path without installer-specific UI/context unless explicitly caught.
- **Installer requirement:** Catch ports synchronization, mandatory upgrade, and optional package-install failures and show a **dialog error box** with the failed operation/package when known, failed URL when available, useful underlying output, exit status, and installer log path. Preserve the installer log before cleanup.
- **Installer navigation:** The failure dialog should have a **Continue** button. Selecting Continue must return the user to the **installer main menu/configuration screen**, not terminate the installer or dump directly to the shell.
- **Text-mode fallback:** If Dialog is unavailable, print the same failure details in text mode, prompt **Press Enter to continue**, then return to the respective main menu.
- **Do not hide the real error:** The dialog should summarize the failure, but the full raw downloader/build output must remain in the corresponding log for troubleshooting.
- **Regression tests:** Deliberately use a bad source URL once in Bootstrap Stage 1, once in Bootstrap Stage 2, and once during installer package installation. In all cases verify the error is shown in the appropriate dialog/text fallback, the log path is visible, and Continue returns to the correct main menu without terminating the parent workflow.

### pkgmk source URL fallback / backup mirrors
- [~] **PARTIAL IMPLEMENTATION (2026-08-18):** The 29 core GNU Pkgfiles that used `ftpmirror.gnu.org` now use canonical `https://ftp.gnu.org/gnu/...` paths, eliminating dependence on the slow redirector observed during testing. A consistent backup-source URL policy is still required in the pkgmk download layer.
- **r74 remaining work:** The current pkgmk mirror mechanism is filename/flat-cache based; the requested `mirrors.kernel.org/gnu` alternate host requires path-preserving URL substitution. Do not claim full completion merely by adding unused variables to `pkgmk.conf`.
- **Goal:** A slow, unreachable, or failed primary source must not force the user to wait through repeated retries when a known-good alternate source exists.
- **GNU source policy:** For GNU-hosted distfiles, preserve the original package path and support ordered alternate hosts. Current candidates tested successfully with `autoconf-2.73.tar.xz` are `https://ftp.gnu.org/gnu/` and `https://mirrors.kernel.org/gnu/`. Avoid relying on `ftpmirror.gnu.org` as the only source because its redirect/mirror selection can stall for a long time at 0 bytes.
- **Path-aware fallback required:** GNU mirrors are hierarchical, not flat distfile caches. The fallback implementation must preserve paths such as `autoconf/autoconf-$version.tar.xz`, `glibc/glibc-$version.tar.xz`, and `gcc/gcc-$version/gcc-$version.tar.xz` rather than simply appending the filename to a mirror root.
- **Centralized behavior:** Prefer implementing host/path substitution or equivalent fallback handling in BFSOS `pkgmk`/its extension so individual Pkgfiles do not need duplicate source URLs solely for mirror redundancy.
- **Configuration consistency:** Any generated bootstrap `pkgmk.conf` must inherit the same ordered backup-source policy as the final packaged/default configuration so Stage 1, Stage 2, Stage 3, installer package operations, and the installed system behave consistently.
- **Do not restore the removed FreeBSD distcache fallback:** The previous `distcache.FreeBSD.org/ports-distfiles/` fallback was removed after producing incorrect/unreliable behavior and must not be reintroduced.
- **Retry interaction:** Keep per-URL connection/retry limits short enough that `pkgmk` can advance to the next alternate source promptly rather than spending minutes retrying one dead or stalled endpoint.
- **Integrity:** Existing source checksum/signature verification remains authoritative regardless of which alternate URL supplied the distfile.
- **Regression test:** Deliberately make the primary GNU source unreachable; verify `pkgmk` advances to the next configured URL automatically, downloads the identical distfile, passes the normal integrity checks, and completes the package build. Repeat in Stage 1 and in the installed/final `pkgmk` environment.

### Bootstrap Stage 3 availability status
- [x] **COMPLETED / VERIFIED:** Correct Stage 3 (`Rebuild base system with final toolchain`) status logic.
- Stage 3 now shows **[PENDING]** until the required temporary-toolchain/base-system prerequisite stages are complete.
- After Stage 2 is complete, Stage 3 changes to **[AVAILABLE]**.
- After Stage 3 itself is completed, it shows **[COMPLETE]**.
- Corrected in both the dialog and text-fallback bootstrap menus.
- Verified during testing on August 11, 2026: the corrected behavior now appears as intended.


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
- [x] Fix
- **Completed:** Installed test system produced BFSOS Codeberg URLs correctly, and the installer keeps the extracted os-release safeguard. The source `aaa_filesystem` Pkgfile had already been corrected in the project tree before this pass.
- **Area:** `aaa_filesystem` / `/etc/os-release` branding
- **Observed behavior:** Installed `/etc/os-release` still uses `https://codeberg.org/bmadonnaster/BFS-Linux` for `HOME_URL`, `SUPPORT_URL`, and `BUG_REPORT_URL` even though the repository has been renamed to BFSOS.
- **Desired behavior:** Change all three generated URLs to the current BFSOS repository and BFSOS issues page.
- **Scope:** Search release/branding files and installer-generated metadata for any remaining stale `BFS-Linux` repository references so new installs do not recreate them.
- **Priority:** Cosmetic/non-boot-blocking; fix after the current reboot test rather than modifying this installed test system before first boot.
- **r35 safeguard:** The installer now rewrites stale BFS-Linux Codeberg URLs in the extracted `/etc/os-release`/`/usr/lib/os-release` to BFSOS. The source `ports/core/aaa_filesystem/Pkgfile` still needs to be updated directly when that port file is supplied; it was not among the uploaded files for this pass.
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
- [x] Fix — reopened after r27 regression test
- **Implemented in r35:** `scripts/install-bfs-menu-v50-tracker-fixed-r35.sh` and/or `bootstrap.sh` as applicable.
- **Area:** GRUB generation / Dracut / complex storage
- **Observed behavior:** The completed install did not automatically emit the complete/correct boot-storage arguments required by the tested topology. Manual correction was required before reboot.
- **Required behavior:** Derive boot-critical storage ancestry and emit the required `rd.luks.uuid=`, `rd.md.uuid=`, and `rd.lvm.lv=` arguments. Finalize `/etc/crypttab` and mdadm configuration before rebuilding the initramfs, then regenerate `grub.cfg` and validate the generated boot entries/initramfs.
- **Regression scope:** LUKS -> LVM and MD RAID -> LUKS -> LVM, including separate `/usr`, `/opt`, `/home`, `/var`, and complex Btrfs layouts.
- **r27 regression #1 — truncated MD UUID:** The MD UUID parser emitted only the first colon-delimited field (`rd.md.uuid=4a9b5206`) instead of the complete mdadm UUID (`rd.md.uuid=4a9b5206:8ebe46e5:6d41cbba:3468e1e1`). Preserve the complete value exactly as reported by `mdadm --detail` / `mdadm --detail --scan`; do not parse it with a generic colon field split.
- **r27 regression #2 — stale verifier:** The generator switched to explicit `rd.md.uuid=...`, but the GRUB verifier still failed the install with `boot-critical RAID storage requires rd.auto`. Generator and verifier must use the same storage model. A valid explicit `rd.md.uuid=` must satisfy RAID verification; `rd.auto` must not be required when explicit MD UUIDs are emitted.
- **r27 regression #3 — missing explicit LUKS cmdline:** The tested RAID -> LUKS -> LVM plus separate LUKS root topology generated no `rd.luks.uuid=` values even though `/etc/crypttab` contained both mappings. Generate explicit LUKS UUID arguments for every boot-required encrypted layer in the selected storage ancestry.
- **Known-good manual result for this test topology:**
  - `rd.luks.uuid=77d5c3fb-083b-4ea3-9aa8-11f4e85d334e`
  - `rd.luks.uuid=a82d9766-a424-4530-b4a7-9b8de91d0b2c`
  - `rd.md.uuid=4a9b5206:8ebe46e5:6d41cbba:3468e1e1`
  - `rd.lvm.lv=bfs-root/root`
  - `rd.lvm.lv=bfs-root/usr`
  - `rd.lvm.lv=bfs-raid/home`
  - `rd.lvm.lv=bfs-raid/var`
- **Initramfs validation from failed r27 test:** The initramfs already contained `crypttab`, `mdadm.conf`, `cryptsetup`, `mdraid`, and LVM support, so this failure was isolated to GRUB/storage-command-line generation and verification rather than missing initramfs storage tooling.
- **Post-install menu clarification:** The missing Chroot/Finish menu was not a separate post-install-menu bug in this test. The installer aborted during final GRUB verification, so it correctly never reached the success/post-install menu.
- **Regression test:** Build the same RAID0 -> LUKS -> LVM layout plus separate LUKS root, regenerate initramfs/GRUB without manual edits, verify full MD UUID preservation, both LUKS UUIDs, all required LVs in normal and recovery entries, and confirm the installer reaches the final Chroot/Finish menu after validation succeeds.


### 58. Correct Review vs Option 10 final-summary navigation labels
- [x] Fix
- **Implemented in r35:** `scripts/install-bfs-menu-v50-tracker-fixed-r35.sh` and/or `bootstrap.sh` as applicable.
- **Area:** Review/install navigation
- **Observed behavior:** r27 overcorrected the navigation labels so both the configuration Review screen and the Option 10 final installation summary show `Continue`.
- **Desired behavior:** The Review/configuration screen must provide `Back` so the user can return and change selections. Option 10's final installation summary must show `Continue` at the bottom to proceed into installation; it must not show `Back`.
- **Regression test:** Confirm the Review/configuration screen says `Back`, then enter Option 10 and confirm the final summary says `Continue`. Verify Back actually returns to configuration and Continue advances toward installation.


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

### 62. Change OpenSSH prompt to enable-on-boot wording
- [x] Fix
- **Implemented in r35:** `scripts/install-bfs-menu-v50-tracker-fixed-r35.sh` and/or `bootstrap.sh` as applicable.
- **Area:** Optional software / service configuration
- **Observed behavior:** The installer currently presents OpenSSH like an optional package even though `openssh` is already installed by the BFSOS bootstrap/base system.
- **Desired behavior:** Ask `Do you want to enable OpenSSH on boot?` and treat the answer as service configuration for `sshd.service`, not as a package-install decision.
- **Regression test:** Confirm OpenSSH is already present from the base system, the installer asks only whether to enable it at boot, and the selected answer produces the expected `sshd.service` enablement state.

### 63. Run mandatory `prt-get sysup` after `ports -u`
- [x] Enhancement / fix
- **Implemented in r35:** `scripts/install-bfs-menu-v50-tracker-fixed-r35.sh` and/or `bootstrap.sh` as applicable.
- **Area:** Ports synchronization / installed-system upgrade
- **Reason:** A user may install from an older base rootfs archive. Synchronizing the ports tree alone does not upgrade packages already present in that base system.
- **Desired behavior:** After a successful `ports -u`, run `prt-get sysup` inside the installed system as a mandatory system upgrade before the final initramfs/Dracut and GRUB generation.
- **Failure behavior:** A failed `prt-get sysup` must stop the installation rather than silently continuing with a partially upgraded system.
- **Logging:** Capture the system-upgrade output in the installer log so package changes and failures can be diagnosed later.
- **Regression test:** Test with an intentionally older base archive; confirm ports synchronize, installed packages upgrade, failures propagate, and final Dracut/GRUB generation occurs only after the upgrade succeeds.

## r28 Tracker Update

- **Generated:** 2026-08-11
- **Tracker-only update:** No installer/bootstrap code changed in this revision.
- **Reopened:** #58 to distinguish the Review/configuration `Back` action from Option 10 final-summary `Continue`.
- **Added:** #62 OpenSSH enable-on-boot wording/service logic.
- **Added:** #63 mandatory `prt-get sysup` after `ports -u`, before final Dracut/GRUB generation.

### 64. Offer optional package-cache cleanup after successful installation
- [x] Enhancement
- **Implemented in r35:** `scripts/install-bfs-menu-v50-tracker-fixed-r35.sh` and/or `bootstrap.sh` as applicable.
- **Area:** Post-install package/cache cleanup
- **Timing:** Ask only after all package installation and the mandatory `prt-get sysup` have completed successfully, immediately before returning to the installer menu.
- **Prompt:** Ask whether the user wants to clear the built/downloaded binary package cache under `/var/cache/pkg/packages/`.
- **Default:** No. Keeping the cached binary packages can be useful for reinstalling packages or troubleshooting without rebuilding them.
- **Yes behavior:** Remove the contents of `/var/cache/pkg/packages/` while leaving the directory itself in place.
- **Scope:** Do not clear `/var/cache/pkg/sources/`; source-cache cleanup is outside this option.
- **Safety:** Do not offer or perform this cleanup during a failed or partially completed package upgrade, so cached packages remain available for diagnosis/recovery.
- **Regression test:** Complete an install/update with cached packages present, choose No and verify they remain; repeat choosing Yes and verify `/var/cache/pkg/packages/` is empty while `/var/cache/pkg/sources/` is untouched.

### 65. Tie the bootstrap and installer workflows together
- [x] Enhancement
- **Implemented in r35:** `scripts/install-bfs-menu-v50-tracker-fixed-r35.sh` and/or `bootstrap.sh` as applicable.
- **Area:** Bootstrap menu / installer integration
- **Goal:** Make the normal BFSOS workflow flow directly from building a usable base rootfs into launching the installer, instead of treating bootstrap and installation as unrelated entry points.
- **Installer location:** Move the primary installer script into the repository `scripts/` directory. The bootstrap menu should resolve it relative to `SCRIPT_DIR` rather than relying on the caller's current working directory.
- **Bootstrap menu:** Add an explicit `Launch BFSOS installer` entry that runs the repository installer from `scripts/`.
- **Installer discovery:** Do not hard-code a single versioned installer filename in `bootstrap.sh`. Discover matching installer scripts under `scripts/` with a stable pattern (for example `install-bfs-menu-v*.sh`), exclude obvious backups/test artifacts where practical, and select the newest usable version automatically.
- **Version selection rule:** Prefer the highest/newest installer revision deterministically. If filenames contain a date/time or revision component, use that ordering rather than whichever file happens to be returned first by the filesystem.
- **Visibility:** Show the exact installer path/version bootstrap is about to launch so the user can see which revision was selected.
- **Normal workflow:** The common path should make bootstrap stages 1, 2, and 4 plus rootfs archive creation prominent/required for producing an installable BFSOS base.
- **Stage 3:** Keep the full final-toolchain/base rebuild available, but clearly label it **optional**. It is useful for users who deliberately want to rebuild the system a second time, but it must not be presented as a prerequisite for installation.
- **Rootfs archive:** Keep creation/compression of the base rootfs archive as a mandatory part of the normal build-to-install workflow because the installer consumes that archive.
- **Installer handoff:** Before launching the installer, verify that a usable base rootfs archive exists. If not, explain which required bootstrap/archive step is incomplete rather than launching into a guaranteed failure.
- **Return behavior:** When the installer exits normally or is cancelled, return cleanly to the bootstrap menu with the terminal restored.
- **Direct execution:** Moving the installer under `scripts/` must not prevent advanced users from invoking it directly.
- **Path migration:** Update documentation, helper scripts, tracker references, and any hard-coded repository-root installer paths to the new `scripts/` location.
- **Regression test:** From a clean repository, complete the normal bootstrap path without stage 3, create the rootfs archive, launch the installer from the bootstrap menu, cancel/return, relaunch it, and verify paths, permissions, terminal cleanup, archive detection, and direct installer execution all work.

### 66. Clarify mandatory vs optional bootstrap stages in the menu
- [x] UI / workflow enhancement
- **Implemented in r35:** `scripts/install-bfs-menu-v50-tracker-fixed-r35.sh` and/or `bootstrap.sh` as applicable.
- **Area:** Bootstrap menu
- **Goal:** Make it immediately obvious which stages are needed to produce an installable BFSOS base and which are optional validation/rebuild operations.
- **Required normal-build stages:** Present bootstrap options 1, 2, and 4 as part of the normal required workflow, together with mandatory base-rootfs archive creation/compression.
- **Optional rebuild stage:** Mark option 3 as optional and describe it as a second/final rebuild for users who want the additional rebuild pass.
- **Status tracking:** Completion/pending indicators must not treat skipped option 3 as an incomplete/error state when the user follows the normal installable-base workflow.
- **Installer readiness:** The new installer-launch entry should base readiness on the genuinely required stages and availability of the rootfs archive, not on completion of optional stage 3.
- **Existing archive readiness:** On bootstrap startup, inspect the default base-archive directory. If a valid base rootfs archive already exists, treat the installable-base requirement as satisfied even when the current checkout has no fresh stage markers from this session.
- **Menu status:** Reflect that state clearly in the bootstrap menu (for example `READY`/`ARCHIVE AVAILABLE`) so the user can launch the installer immediately without rebuilding mandatory stages unnecessarily.
- **Safety:** Archive presence should satisfy installer readiness only after validating that the file is readable and matches a supported BFSOS base-rootfs archive format.
- **Regression test:** Verify a user can complete the required workflow, intentionally skip stage 3, create the archive, and launch/install BFSOS without warnings claiming the build is incomplete.


## r29 Tracker Update

- **Generated:** 2026-08-11
- **Tracker-only update:** No bootstrap or installer code changed in this revision.
- **Added:** #65 bootstrap-to-installer integration and moving the primary installer into `scripts/`.
- **Added:** #66 distinguish the required bootstrap path from optional stage 3 and ensure installer readiness does not depend on stage 3.
- **Planned workflow:** build required base stages -> create/compress rootfs archive -> launch installer directly from the bootstrap menu.

- **Status semantics:** Use the three status words consistently: `PENDING` means a required prerequisite has not been satisfied; `AVAILABLE` means an action can be run now but is not itself a completion requirement; `COMPLETE` means the corresponding build/verification/archive requirement has been satisfied.
- **Required stages 1, 2, and 4:** Show `PENDING` until their completion checks pass, then `COMPLETE`.
- **Stage 3 optional rebuild:** Do not show `PENDING` merely because it was skipped. Show `AVAILABLE` while it can be run and `COMPLETE` after it has actually completed.
- **Rootfs archive creation:** Show `PENDING` until a valid base archive exists, then `COMPLETE`.
- **Restore actions:** `Restore newest base rootfs archive` and `Restore newest temporary toolchain archive` are actions, not mandatory stages. Show `AVAILABLE` whenever a valid source archive exists. They must not remain `PENDING` just because the user has not chosen to restore something.
- **Chroot:** Show `AVAILABLE` whenever a usable rootfs exists; otherwise `PENDING` because there is nothing to enter yet.
- **Installer launch:** Show `AVAILABLE` whenever a valid base rootfs archive exists and the installer can be discovered; otherwise `PENDING`. Launching the installer is an action, so it should not be labeled `COMPLETE` simply because it was run once.

### 67. Add graphical base-rootfs archive selection and browsing
- [x] UI / workflow enhancement
- **Implemented in r35:** `scripts/install-bfs-menu-v50-tracker-fixed-r35.sh` and/or `bootstrap.sh` as applicable.
- **Area:** Installer base archive selection
- **Goal:** Avoid requiring the user to manually type a base-rootfs archive path when the archive is outside the default location.
- **Default archive behavior:** First search/check the normal BFSOS base-rootfs archive location. If a usable archive exists, show the discovered archive and its full path and offer to use it immediately.
- **Newest archive selection:** When multiple valid base archives exist in the default location, automatically choose the newest one. If the filename contains the BFSOS date/time stamp, sort by that embedded timestamp first; fall back to file modification time only when a reliable timestamp cannot be parsed from the name.
- **Deterministic tie-break:** If two candidates resolve to the same parsed timestamp, use a stable secondary sort (such as modification time then filename) so selection is predictable.
- **Display:** The detected/default archive screen should identify that it is the newest available archive and show the selected filename, full path, size, and timestamp before the user accepts it.
- **Default archive choices:** When an archive is found, provide clear actions to use the detected archive, browse/select a different archive, or go Back.
- **Missing-default behavior:** If no usable archive exists in the default location, open the file-selection/browse interface automatically rather than presenting a dead/default path.
- **Browse interface:** Use a Dialog file selector such as `--fselect` when available so the user can navigate directories and choose the base archive interactively.
- **Archive validation:** After selection, verify the selected path exists, is a regular readable file, and uses an archive/compression format supported by the installer before accepting it.
- **Confirmation:** Show the selected archive's full path and useful metadata such as file size before committing the selection.
- **Session behavior:** Preserve the selected archive path for the remainder of the installer session and in installer profile/state handling where appropriate.
- **Bootstrap integration:** When the installer is launched from the bootstrap workflow added by #65, prefer the rootfs archive just created by bootstrap as the detected/default archive.
- **Text-mode fallback:** If Dialog/file selection is unavailable, retain a text-mode path prompt with validation rather than making archive selection impossible.
- **Regression test:** Test with (1) a valid archive in the default location, (2) no default archive, (3) choosing a different archive despite a valid default, (4) invalid/non-readable selections, and (5) launching from bootstrap immediately after archive creation.


## r30 Tracker Update

- **Generated:** 2026-08-11
- **Tracker-only update:** No installer/bootstrap code changed in this revision.
- **Added:** #67 interactive base-rootfs archive discovery/browsing with default-archive preference, validation, and bootstrap handoff support.


## r31 Tracker Update

- **Generated:** 2026-08-11
- **Tracker-only update:** No bootstrap or installer code changed in this revision.
- **Updated #65:** Bootstrap installer launch must discover the newest versioned installer under `scripts/` instead of hard-coding one filename.
- **Updated #66:** A valid existing base-rootfs archive in the default archive directory can satisfy installer readiness and should be reflected in bootstrap menu status.
- **Updated #67:** When multiple default base archives exist, select the newest archive deterministically, preferring the date/time embedded in the filename when present.


### 69. Normalize bootstrap `PENDING` / `AVAILABLE` / `COMPLETE` status logic
- [x] UI / workflow fix
- **Implemented in r35:** `scripts/install-bfs-menu-v50-tracker-fixed-r35.sh` and/or `bootstrap.sh` as applicable.
- **Area:** Bootstrap menu status indicators
- **Observed behavior:** The current bootstrap helper treats nearly every non-completed item as `PENDING`, including restore operations that are already usable when an archive exists. Chroot is handled separately as `AVAILABLE`, so the menu currently mixes completion state and action availability inconsistently.
- **Required semantics:**
  - `PENDING` — a required prerequisite or required build result is not yet satisfied.
  - `AVAILABLE` — the action can be run now, but running it is optional/repeatable and it is not a required completion gate.
  - `COMPLETE` — a build, verification, or archive requirement has been satisfied.
- **Expected menu behavior:**
  - Temporary toolchain build: `PENDING` -> `COMPLETE`.
  - Base-system build with temporary toolchain: `PENDING` -> `COMPLETE`.
  - Optional final rebuild (stage 3): `AVAILABLE` -> `COMPLETE`; never `PENDING` solely because it was skipped.
  - Verify completed base system: `PENDING` -> `COMPLETE`.
  - Create/compress base rootfs archive: `PENDING` -> `COMPLETE` once a valid archive exists.
  - Restore newest base rootfs archive: `AVAILABLE` whenever a valid archive exists; otherwise `PENDING`.
  - Restore newest temporary toolchain archive: `AVAILABLE` whenever a valid toolchain archive exists; otherwise `PENDING`.
  - Chroot into BFS rootfs: `AVAILABLE` when a usable rootfs exists; otherwise `PENDING`.
  - Launch BFSOS installer: `AVAILABLE` when a valid base archive exists and a current installer is discoverable; otherwise `PENDING`.
- **Implementation:** Replace the one-size-fits-all `_stage_complete_text` / `_dialog_stage_status` use with per-action status helpers or a generic status function that can distinguish completion checks from availability checks.
- **Consistency:** Text-mode and Dialog menus must report the same status for every option.
- **Regression test:** Test a clean tree, completed stage 1 only, completed stage 2, skipped stage 3, verified base, archive present, restored rootfs, restored toolchain, and installer-ready states. Confirm each menu item uses exactly the expected `PENDING`, `AVAILABLE`, or `COMPLETE` label.


## r32 Tracker Update

- **Generated:** 2026-08-11
- **Tracker-only update:** No bootstrap or installer code changed in this revision.
- **Updated #66:** Defined exact `PENDING`, `AVAILABLE`, and `COMPLETE` semantics for the streamlined bootstrap/install workflow.
- **Added #69:** Normalize status logic in both text and Dialog bootstrap menus, especially optional stage 3, restore actions, chroot, and installer launch.


### 70. Offer ZRAM swap when no disk swap is configured
- [x] Enhancement
- **Implemented in r35:** `scripts/install-bfs-menu-v50-tracker-fixed-r35.sh` and/or `bootstrap.sh` as applicable.
- **Area:** Installer storage / swap configuration
- **Trigger:** After storage assignment is complete, detect whether the installed system has a configured swap partition or swap logical volume.
- **No-swap behavior:** If no disk-backed swap is configured, ask whether the user wants to enable ZRAM swap on the installed BFSOS system.
- **Prompt:** Clearly explain that ZRAM provides compressed swap in RAM and does not require a swap partition.
- **Default:** Yes when no other swap exists, while still requiring the user to confirm the choice.
- **Existing-swap behavior:** If disk-backed swap exists, do not silently enable ZRAM. Either skip the ZRAM prompt or present ZRAM separately as an optional supplemental swap choice.
- **Kernel validation:** Before configuring ZRAM, verify the target kernel/config/modules provide ZRAM support (for example built-in `CONFIG_ZRAM=y` or module `CONFIG_ZRAM=m` with the corresponding module installed). Do not assume support from the live environment.
- **Configuration:** Install/write the appropriate BFSOS/systemd ZRAM configuration so ZRAM swap is created automatically during normal boot.
- **Failure behavior:** If the user selects ZRAM but the installed kernel or required userspace support is unavailable, show a clear warning/error and do not claim ZRAM is enabled.
- **Review screen:** Explicitly show both disk swap and ZRAM state, for example `Disk swap: none` and `ZRAM swap: enabled`, so compressed swap is not hidden from the installation summary.
- **Post-install verification:** Verify the installed configuration exists and is enabled before declaring the ZRAM setup successful.
- **Regression test:** Test (1) no swap + ZRAM Yes, (2) no swap + ZRAM No, (3) disk swap configured, (4) ZRAM kernel support missing, and (5) reboot of a completed ZRAM-enabled install followed by `swapon --show`/equivalent verification.


## r33 Tracker Update

- **Generated:** 2026-08-11
- **Tracker-only update:** No installer/bootstrap code changed in this revision.
- **Added:** #70 optional ZRAM swap configuration when no disk-backed swap is selected, including target-kernel validation, review visibility, boot-time configuration, and post-install verification.


### 71. Keep final GRUB verification consistent with generated storage arguments
- [x] Fix
- **Implemented in r35:** `scripts/install-bfs-menu-v50-tracker-fixed-r35.sh` and/or `bootstrap.sh` as applicable.
- **Area:** Final installation validation / success transition
- **Observed behavior:** r27 generated explicit `rd.md.uuid=` arguments, then aborted the installation because the verifier still required `rd.auto`. This prevented the normal successful-installation Chroot/Finish menu from appearing.
- **Desired behavior:** The final verifier must validate exactly the storage arguments the generator intentionally emits. Do not require obsolete/alternative arguments that are not part of the chosen generation strategy.
- **Failure reporting:** When validation fails, clearly state which expected argument/value is missing or malformed. For MD RAID, print the expected complete UUID and the actual generated kernel line.
- **Success transition:** Only after final GRUB/initramfs verification succeeds should the installer show the Installation Complete dialog and the Chroot/Finish menu.
- **Logging:** Keep logging active through final verification and the post-install transition so any late failure is captured in the installer log.
- **Regression test:** Test successful and intentionally broken RAID/LUKS/LVM cmdlines. Broken configuration must fail with an actionable message; correct configuration must pass and reach the post-install menu.


## r34 Tracker Update

- **Generated:** 2026-08-11
- **Tracker-only update:** No installer/bootstrap code changed in this revision.
- **Reopened/expanded #57:** r27 truncated colon-separated MD UUIDs, omitted explicit LUKS UUID arguments for the tested topology, and used a stale verifier that still required `rd.auto`.
- **Added #71:** Keep final GRUB verification synchronized with generated storage arguments and preserve logging through the final validation/post-install transition.
- **Test conclusion:** The missing Chroot/Finish menu was a consequence of final GRUB verification failure, not a standalone menu bug.

## r35 Implementation Pass

- **Generated:** 2026-08-11
- **Installer moved for normal workflow:** `scripts/install-bfs-menu-v50-tracker-fixed-r35.sh`
- **Bootstrap:** `bootstrap.sh`
- **Implemented:** #57, #58, #62, #63, #64, #65, #66, #67, #69, #70, #71.
- **#54:** Installed-system safeguard implemented; source `aaa_filesystem/Pkgfile` remains pending because that port file was not supplied in this pass.
- **GRUB fix:** Full colon-separated MD UUIDs are preserved, explicit LUKS UUIDs come from finalized crypttab, and verification no longer requires stale `rd.auto`/`rd.md=1`.
- **Bootstrap/install handoff:** Bootstrap discovers the newest executable versioned installer under `scripts/` and hands it the newest valid base archive.
- **Normal bootstrap path:** stages 1, 2, 4, and rootfs archive creation are required; stage 3 is optional and reports AVAILABLE until completed.
- **Package policy:** every install performs `ports -u` followed by mandatory `prt-get sysup`; optional packages are installed afterward.
- **Post-install cleanup:** user is asked whether to clear `/var/cache/pkg/packages/*`; default is No.
- **Swap policy:** when no disk swap is selected, installer offers ZRAM (default Yes) and validates installed-kernel ZRAM support before enabling its systemd service.
## r38 Tracker Update

- **Generated:** 2026-08-11
- **Bootstrap:** `bootstrap.sh` through r42
- **Installer:** no installer code changed in this tracker update.
- **Bootstrap changes below are completed and regression-tested interactively in the VM unless otherwise noted.**

### 72. Fix bootstrap theme Settings workflow and defaults
- [x] UI / workflow fix
- **Implemented in:** `bootstrap.sh`
- **Area:** Bootstrap Settings / interface themes
- **Default theme:** Classic Slackware is the startup default on every normal bootstrap invocation. A stale saved theme from an earlier test must not silently make Debian or another theme the startup default.
- **Theme choices:** The bootstrap Settings theme selector now exposes all supported themes in one place:
  - `Slackware` — Classic Slackware theme and default.
  - `Debian` — Classic Debian installer/newt-style theme.
  - `Monochrome`.
  - `Midnight`.
  - `Light`.
- **Visible theme labels:** Capitalize the first character of every left-hand theme name. Use `Debian`, not the internal identifier `classic`, as the visible label.
- **Internal compatibility:** The Debian palette may continue to use the existing internal `classic` theme key so the underlying implementation does not need to be renamed.
- **Back behavior:** Back/Esc from the theme selector returns cleanly to the previous/bootstrap menu. Navigating Settings must not produce `Operation completed successfully` or a `Press Enter to return to the menu...` pause.
- **Settings layout:** The main bootstrap menu shows only `Settings`, with no current-theme text on the right-hand side so additional settings can be added later without changing the main-menu layout.
- **Menu placement:** `Settings` is no longer a numbered/scrollable menu entry. It is a dedicated bottom dialog button positioned between `<Select>` and `<Quit>`.
- **Regression test:** Start bootstrap with no special environment override, confirm Classic Slackware is selected by default, open Settings, verify all five themes and capitalization, apply each theme, use Back/Esc, and confirm the main menu returns immediately without an operation-success/pause screen.

### 73. Use AVAILABLE / NOT AVAILABLE for bootstrap chroot status
- [x] UI / workflow fix
- **Implemented in:** `bootstrap.sh`
- **Area:** Bootstrap main-menu status
- **Observed behavior:** Chroot was shown as `PENDING`, which incorrectly implied it was an unfinished required stage.
- **Desired behavior:** Chroot is an optional action and must display only:
  - `AVAILABLE` when a usable restored BFSOS environment exists.
  - `NOT AVAILABLE` when it cannot currently be entered.
- **Availability gate:** Do not mark chroot available merely because a base archive or toolchain archive exists. Require that the base rootfs and/or temporary toolchain has actually been restored into the working tree and that a usable Bash exists in the rootfs.
- **Consistency:** Apply the same wording and availability logic to both Dialog and text-mode bootstrap menus.
- **Regression test:** With only archives present, verify Chroot shows `NOT AVAILABLE`; restore the base rootfs or temporary toolchain as appropriate and verify it changes to `AVAILABLE` only when the restored filesystem is actually usable.

### 74. Match installer theme-name capitalization to bootstrap
- [x] UI consistency fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r36.sh`. Theme selector now shows `Slackware`, `Debian`, `Monochrome`, `Midnight`, and `Light`, with Slackware first/default and internal `classic` compatibility preserved.
- **Area:** Installer Settings / interface themes
- **Observed behavior:** Bootstrap now presents the left-hand theme names as `Slackware`, `Debian`, `Monochrome`, `Midnight`, and `Light`, while the installer still needs the same visible naming convention.
- **Desired behavior:** Update the installer theme-selection UI to use the same capitalization and user-facing names as `bootstrap.sh`.
- **Required visible names:** `Slackware`, `Debian`, `Monochrome`, `Midnight`, `Light`.
- **Debian naming:** Show `Debian` in the selector rather than exposing an internal theme key such as `classic`; descriptions may still identify it as the Classic Debian installer/newt-style theme.
- **Default:** Classic Slackware remains the installer default.
- **Compatibility:** Preserve internal theme keys/profile compatibility where practical; this is a display-name/UI consistency change, not a requirement to rename stored identifiers.
- **Regression test:** Compare installer and bootstrap theme selectors side-by-side and confirm theme names, capitalization, order/default behavior, and descriptions are consistent.
### 75. Return directly to bootstrap after installer exits
- [x] UI / workflow fix
- **Implemented in:** `bootstrap-r44-tracker-complete.sh`. Returning from the installer now resets the terminal and immediately redraws bootstrap with no generic success/failure message or Enter pause.
- **Area:** Bootstrap-to-installer handoff / return behavior
- **Observed behavior:** After the installer exits back to `bootstrap.sh`, bootstrap currently shows:
  - `Operation completed successfully.`
  - `Press Enter to return to the menu...`
- **Desired behavior:** When the installer exits normally or is cancelled and control returns to bootstrap, immediately redraw and return to the bootstrap main menu.
- **Do not show:** No generic `Operation completed successfully.` message and no `Press Enter to return to the menu...` pause for the installer-launch action.
- **Scope:** This exception applies specifically to the `Launch BFSOS installer` menu action. Normal build stages may continue to show completion/failure output and pause when that output is useful.
- **Terminal handling:** Restore/reset the terminal cleanly after the installer exits before redrawing the bootstrap menu so no installer colors, background, cursor state, or stale screen content remain.
- **Regression test:** Launch the installer from bootstrap, then test both normal installer exit and Cancel/Back/Quit paths. In every case, confirm control returns immediately to the bootstrap main menu with no intermediate success/pause screen.

### 76. Move Bootstrap Settings to bottom action-button row
- [x] UI / workflow fix
- **Implemented in:** `bootstrap.sh` r43
- **Area:** Bootstrap main menu
- **Observed behavior:** `Settings` was incorrectly added as a numbered item at the bottom of the scrollable bootstrap menu.
- **Desired behavior:** Remove `Settings` from the numbered menu entries and place it on the bottom action-button row between `Select` and `Quit`.
- **Final dialog button order:** `<Select>`  `<Settings>`  `<Quit>`.
- **Behavior:** Selecting the Settings button opens the existing Bootstrap Settings / Interface Theme screen; returning from Settings redraws the bootstrap main menu normally.
- **Compatibility:** Text-mode fallback retains the numeric Settings choice because it has no dialog button row.
- **Status:** Completed in bootstrap r43.

### 77. Silently return when Chroot is NOT AVAILABLE
- [x] UI / workflow fix
- **Implemented in:** `bootstrap-r44-tracker-complete.sh`. Selecting Chroot while unavailable now immediately redraws the menu; no root-stage call, error, success message, or pause is produced.
- **Area:** Bootstrap main menu / Chroot action
- **Observed behavior:** When `Chroot into BFS rootfs` shows `NOT AVAILABLE`, pressing Enter on that menu item currently proceeds into the action path and produces an error/message before returning.
- **Desired behavior:** If Chroot is `NOT AVAILABLE`, selecting it should do nothing except immediately redraw the bootstrap main menu.
- **Do not show:** No error message, no `Operation failed`, no `Operation completed successfully`, and no `Press Enter to return to the menu...` pause.
- **Availability logic:** Continue using the existing `_chroot_available` test. The menu action should check availability before invoking the root/chroot stage.
- **Available behavior:** When Chroot shows `AVAILABLE`, Enter should continue to launch the chroot normally.
- **Regression test:** With Chroot showing `NOT AVAILABLE`, highlight it and press Enter; confirm the bootstrap menu immediately redraws with no intermediate output or pause. Then restore a usable rootfs/toolchain, confirm it changes to `AVAILABLE`, and verify Enter launches the chroot normally.
### 78. Rescan all storage after every destructive or topology-changing storage operation
- [x] Installer storage-detection bug
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r36.sh`. Added centralized `refresh_storage_state()` and wired it into cfdisk return, storage metadata destruction, RAID assembly/create/signature wipe, LUKS create/open/close, LVM PV/VG/LV creation, and filesystem/swap formatting.
- **Area:** Installer storage discovery / partitioning / filesystems / RAID / LUKS / LVM
- **Observed behavior:** Possible stale-device-state bug: after launching `cfdisk` from inside the installer and creating or changing partitions, the RAID member selection screen appeared not to reflect the newly written partition table.
- **Expanded requirement:** Do not limit the fix to `cfdisk`. After every destructive or storage-topology-changing operation, force a fresh kernel/userspace storage rescan and rebuild the installer's device inventory before presenting another storage-selection or review screen.
- **Operations that must trigger a rescan include at minimum:**
  - returning from `cfdisk` or another partition-table editor after changes;
  - creating, deleting, resizing, or rewriting partitions/partition tables;
  - formatting or reformatting filesystems and initializing swap;
  - creating, assembling, stopping, destroying, or otherwise changing MD RAID arrays;
  - creating, opening, closing, formatting, or otherwise changing LUKS mappings;
  - creating/removing/changing LVM PVs, VGs, and LVs;
  - destructive signature/wipe operations such as `wipefs`;
  - any other installer action that changes block-device names, mappings, filesystem/type metadata, sizes, parent/child relationships, or availability.
- **Refresh sequence:** Review use of `partprobe`, `blockdev --rereadpt`, `udevadm settle`, MD/LUKS/LVM discovery commands, and/or equivalent safe mechanisms as appropriate for the operation. The goal is a reliable fresh view of all storage devices, not merely the disk that was just edited.
- **No stale cache:** Do not reuse a partition/device list gathered before the destructive operation. Re-run the installer storage-enumeration logic (`lsblk` and any RAID/LUKS/LVM discovery used by the installer) after the rescan.
- **Consumers of refreshed state:** RAID member selection, filesystem/format selection, mount-point assignment, swap selection, LUKS, LVM, installation review, and every later storage screen must use the refreshed inventory.
- **Failure handling:** If the kernel cannot reread a partition table or refresh a device because it is busy, clearly report the condition rather than silently continuing with stale information.
- **Regression test:** Exercise each supported destructive/topology-changing storage path, then immediately enter the next relevant storage screen and verify device names, partitions, sizes, filesystem/type information, RAID/LUKS/LVM mappings, and availability match the new state without restarting the installer.
### 79. Verify sudo default uses password authentication
- [x] Installer configuration verification
- **Verified in source:** The installer default remains `SUDO_MODE=password`, which writes `%wheel ALL=(ALL:ALL) ALL`. `NOPASSWD` is only written when the user explicitly selects the no-password mode, matching the successful VM test.
- **Area:** Installed-system sudo / privilege escalation defaults
- **Check:** Confirm that the installer installs and configures `sudo` as the default privilege-escalation mechanism for regular users.
- **Required default:** `sudo` must require the invoking user's password by default.
- **Do not default to:** Passwordless `NOPASSWD` sudo access.
- **Configuration review:** Check `/etc/sudoers` and any installer-created files under `/etc/sudoers.d/` to make sure the regular-user/admin group rule uses normal password authentication and that no broader `NOPASSWD` rule overrides it.
- **Validation:** Run `visudo -c` on the installed system and test from a regular configured user with a cleared sudo timestamp (`sudo -k`) to confirm the next `sudo` command prompts for that user's password.
- **Regression test:** Fresh install with a normal user, log in as that user, run `sudo -k` followed by a harmless sudo command, and verify a password prompt appears and valid user credentials are required.
### 80. Make Review (option 10) flow directly into Ready to install (option 11)
- [x] Installer UI / workflow fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r36.sh`. Option 10 Review now advances directly to Ready to install; Back from Ready reopens Review; Continue starts installation without returning to the main menu.
- **Area:** Installer main menu options 10 and 11 / final pre-install workflow
- **Observed behavior:** Option 10 (`Review selections`) displays the installation review, but pressing `Continue` returns to the installer main menu instead of advancing to the final installation confirmation.
- **Correct workflow:** Options 10 and 11 should behave as one continuous pre-install sequence:
  1. Select option 10 and display the complete `Review selections` screen.
  2. Press `Continue` on the review screen.
  3. Advance directly to the option 11 `Ready to install` screen (`Begin the BFS installation?`).
  4. Press `Continue` there to begin installation.
  5. Press `Back` on `Ready to install` to return directly to the `Review selections` screen.
- **Review-screen behavior:** The important fix is not to send `Continue` back to the main menu. `Continue` must advance to `Ready to install`.
- **Main-menu option 11:** Directly selecting option 11 may continue to open the `Ready to install` stage, but the normal intended path is Review -> Ready to install -> Install.
- **No state loss:** Moving forward or backward between Review and Ready to install must preserve all current installer selections.
- **Regression test:** Enter option 10, review selections, press `Continue`, verify `Ready to install` appears immediately; press `Back`, verify the same review reappears; press `Continue` again and then `Continue` on Ready to install, and verify installation begins without returning to the main menu between these stages.
### 81. Exit directly to terminal after installation is finished
- [x] Installer UI / workflow cleanup
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r36.sh`. Removed the redundant final completion/unmount text and terminal review dump; Finish restores terminal state and returns directly to the caller while normal cleanup remains active.
- **Area:** Installer completion / final exit
- **Observed behavior:** After the installation has completed and the user finishes the post-install/chroot workflow, the installer still prints an extra completion/unmount message instead of simply returning control to the shell.
- **Desired behavior:** Once installation is complete and the user chooses to finish/exit, perform the required cleanup and unmount operations, restore the terminal state, and return directly to the live-environment terminal prompt.
- **Do not show:** No extra final `BFS installation completed...` message, no generic success message, and no `Press Enter` pause after the user has already finished the installation workflow.
- **Keep:** The existing completion/post-install screen may still provide the explicit choices to chroot into the installed system or finish the installation; this issue concerns what happens after the user chooses to finish.
- **Implementation note:** The current installer path explicitly prints `BFS installation completed. The installer will unmount the target filesystems.` after the post-install menu; remove that redundant final output while preserving cleanup/unmount behavior.
- **Regression test:** Complete an installation, use the post-install chroot option if desired, exit the chroot, then choose Finish. Confirm filesystems are cleaned up/unmounted and control returns directly to the live shell prompt with no additional completion dialog/message or pause.
### 82. Fix `bfs-zram.service` systemd ordering cycle
- [x] Installer / installed-system boot fix
- **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r36.sh`. Generated ZRAM service now uses `DefaultDependencies=no`; default ZRAM capacity is dynamically set to 2× physical RAM. The ordering fix was also validated manually in the VM: ZRAM active and `systemctl is-system-running` returned `running`.
- **Area:** ZRAM swap / systemd unit ordering
- **Observed on first successful installed-system boot:** `bfs-zram.service` itself starts successfully and creates the configured ZRAM swap, but systemd reports an ordering cycle involving `tmp.mount`, `swap.target`, `bfs-zram.service`, `basic.target`, and `sysinit.target`. The cycle can cause `tmp.mount` to be dropped from the boot transaction and leaves `systemctl is-system-running` reporting `degraded`.
- **Current generated unit:** `bfs-zram.service` uses `After=systemd-modules-load.service`, `Before=swap.target`, and `WantedBy=swap.target`, while normal service default dependencies also place it after `basic.target`/`sysinit.target`. Because `tmp.mount` is `After=swap.target` and participates in the early local-filesystem ordering, this produces a dependency cycle.
- **Required fix:** Make the ZRAM setup service an explicitly early boot service by adding `DefaultDependencies=no` while retaining the required module-load ordering and `Before=swap.target` relationship. Keep it enabled from `swap.target`.
- **Target unit shape:**
  ```ini
  [Unit]
  Description=BFSOS compressed ZRAM swap
  DefaultDependencies=no
  After=systemd-modules-load.service
  Before=swap.target

  [Service]
  Type=oneshot
  RemainAfterExit=yes
  ExecStart=/usr/libexec/bfs-zram-setup
  ExecStop=/usr/libexec/bfs-zram-stop

  [Install]
  WantedBy=swap.target
  ```
- **Default ZRAM sizing:** Set the default ZRAM device size to **2× the system's physical RAM**. Example: a system with 32 GiB RAM should default to a 64 GiB `/dev/zram0`.
- **Sizing implementation:** Calculate the size dynamically from detected physical memory rather than hard-coding a fixed size. Keep any explicit user-configured size override if the installer/settings already provide one.
- **Do not regress:** ZRAM must still be initialized before `swap.target` is considered reached, `/dev/zram0` must become active swap, and shutdown must still cleanly stop the service.
- **Regression test:** Fresh install with ZRAM enabled, cold boot, confirm there are no `Found ordering cycle` messages for ZRAM/swap/tmp, `tmp.mount` is not dropped because of the ZRAM unit, `systemctl status bfs-zram.service` is successful, `swapon --show` lists the configured ZRAM device at approximately 2× physical RAM by default, and `systemctl is-system-running` is not degraded because of this ordering issue.
### 83. Diagnose/fix VM reboot not returning after `reboot`
- [x] Boot / VM integration bug
- **Root cause found / host fix applied:** The VM launcher contained QEMU `-no-reboot`, which intentionally exits QEMU on guest reboot. The option was removed from the live launcher and its shell syntax was checked. This is a VM-launcher issue, not a BFSOS guest/GRUB defect; one reboot regression test remains to confirm behavior.
- **Area:** Installed BFSOS reboot behavior under QEMU
- **Observed behavior:** The installed BFSOS VM boots successfully from a cold start, but issuing `reboot` from the running installed system does not bring the VM back up normally/visibly. The VM appears to disappear or fail to return after shutdown/reboot.
- **Important distinction:** Cold boot from the VM launcher works, so this is not currently evidence of a GRUB/initramfs/root-filesystem boot failure. The problem appears specific to the reboot path and may involve guest shutdown/reboot handling, QEMU launcher options, firmware/UEFI reset behavior, or the installed system's reboot mechanism.
- **Investigation:** Determine whether QEMU exits completely on guest reboot, remains running but loses display/network, or resets and then fails during the next firmware/boot sequence. Inspect the launcher command line and QEMU log after reproducing the issue.
- **Checks:** Review QEMU options such as `-no-reboot`, shutdown/reboot handling, background process supervision, SPICE lifecycle, UEFI/OVMF behavior, and whether the launcher intentionally exits when the guest requests reboot.
- **Guest-side checks:** Inspect the previous boot journal (`journalctl -b -1`) after the next successful cold start for shutdown/reboot errors, and verify systemd reached the expected reboot target cleanly.
- **Do not conflate with installer boot success:** The first cold boot already proved that GRUB, initramfs, LUKS, MD RAID, LVM, Btrfs, separate `/usr`, `/opt`, `/var`, `/home`, and EFI boot all work from a powered-off VM.
- **Regression test:** Boot the installed VM, issue `reboot`, and confirm the same QEMU process successfully resets and returns to the BFSOS boot/login prompt without manually restarting the VM launcher.

## r48 Tracker Update

- **Generated:** 2026-08-11
- **Bootstrap implementation:** `bootstrap-r44-tracker-complete.sh`
- **Installer implementation:** `install-bfs-menu-v50-tracker-fixed-r36.sh`
- **Tracker status:** All currently listed code/configuration changes through issue 83 have been applied. Items whose final proof requires another install/reboot remain noted as regression tests even though the requested code change is implemented.
- **Validation performed:** Both updated shell scripts pass `bash -n`. Static checks confirm the new bootstrap short-circuit/return behavior, installer theme labels, storage refresh hooks, sudo password default, Review -> Ready flow, clean final exit, and ZRAM service/sizing changes.

### Bootstrap Stage 1/2 UTF-8 locale archive for temporary toolchain — GCC 16.2 extraction blocker
- [x] **ROOT CAUSE CONFIRMED / PERMANENT CODE FIX IMPLEMENTED; fresh-build regression pending (2026-08-18):** Bootstrap Stage 2 GCC 16.2 extraction failed in temporary-toolchain `bsdtar` because temporary glibc lacked its own usable UTF-8 locale archive.
- **Root cause:** Stage 2 is still using `/tmp/lfs-tools/bin/pkgmk` and `/tmp/lfs-tools/bin/bsdtar`. Those binaries use the temporary glibc in `/tmp/lfs-tools/lib/libc.so.6`, whose compiled locale paths point at `/tmp/lfs-tools/lib/locale/locale-archive` and `/tmp/lfs-tools/lib/locale`. Generating `C.utf8` only in the target rootfs `/usr/lib/locale/locale-archive` therefore does not make UTF-8 available to temporary-toolchain `bsdtar`.
- **Observed proof:** Target `locale -a` reported `C.utf8` and target `LC_ALL=C.utf8 locale charmap` reported `UTF-8`, while temporary-toolchain `bsdtar` still reported `Failed to set default locale`. `strings /tmp/lfs-tools/lib/libc.so.6` confirmed its locale archive path is `/tmp/lfs-tools/lib/locale/locale-archive`.
- [x] **Stage 1 permanent fix implemented:** `ports/core/glibc/Pkgfile` now generates the temporary toolchain `C.UTF-8` locale with the temporary `localedef` and validates `LC_ALL=C.utf8 ... locale charmap` before glibc bootstrap completes; `bootstrap.sh` verifies the archive exists and is usable before Stage 1 is archive-ready.
- [x] **Stage 1 archive requirement implemented:** the normal toolchain archive includes `/tmp/lfs-tools`, and Stage 1 now explicitly rejects an archive that lacks `./tmp/lfs-tools/lib/locale/locale-archive`.
- [x] **Stage 2 target-glibc fix implemented:** immediately after target glibc is installed, `bootstrap.sh` generates `C.UTF-8` with target `/usr/bin/localedef` and validates that target `C.utf8` reports `UTF-8` before continuing.
- [x] **pkgmk environment policy implemented:** generated package-build configs/chroot calls no longer force plain C over `pkgmk` locale selection; non-package deterministic helper operations may still use C.
- [x] **pkgmk detection hardening implemented in pkgutils release 10 and initial-bootstrap patch:** locale selection now checks both locale enumeration and an actual `locale charmap` call, preferring the temporary-toolchain locale command when the running `pkgmk` is under `/tmp/lfs-tools`.
- **Manual workaround result:** After generating the UTF-8 locale for the temporary toolchain, GCC 16.2 successfully extracted; the previous UTF-8 pathname errors disappeared. This confirms the locale-path/toolchain mismatch as the extraction failure's cause.
- [x] **Regression test — fresh Bootstrap 1 / effective runtime proof PASSED 2026-08-18:** the clean Stage 1 temporary toolchain proceeded into Stage 2 with the temporary UTF-8 locale fix in place; Stage 2 temporary-toolchain bsdtar subsequently extracted GCC 16.2 successfully. The explicit archive-path check remains in Bootstrap code.
- [x] **Regression test — Bootstrap 2 PASSED 2026-08-18:** GCC 16.2 extracted successfully during the clean Stage 2 run without the previous pathname-conversion failure.
- [ ] **Regression test — archive restore:** Restore a freshly created Stage 1 toolchain archive and repeat the temporary `bsdtar` UTF-8 test before beginning Stage 2.
- [ ] **Regression test — Stage 3/final system:** Verify the target/final `C.utf8` locale remains usable after glibc/pkgutils rebuild and final-system `bsdtar` can extract the GCC source without locale/pathname errors.
