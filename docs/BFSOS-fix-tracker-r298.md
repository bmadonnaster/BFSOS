# BFSOS Fix Tracker — r298
Updated: 2026-09-20

## r298 — RC1 bare-metal audio fixes, authoritative installer handoff, live-font privilege fix, kernel audit

### [x] FIXED / VERIFIED — bare-metal MSI X870E GODLIKE audio integration

Bare-metal testing exposed userspace/package integration gaps that were hidden by simple virtual audio devices. The MSI MEG X870E GODLIKE onboard USB audio device identifies as `0db0:e5c3` and was falling back to generic Pro Audio endpoints (`Pro`, `Pro 1`, `Pro 2`, `Pro 3`). Raw ALSA playback on the optical endpoint worked, proving the kernel/USB-audio driver path was functional.

Source/package fixes now present:

- `ports/opt/alsa-ucm-conf` is maintained at `1.2.15.3-2` and patches the MSI ALC408x matcher to include `0db0:e5c3`.
- `ports/opt/pipewire` is maintained at `1.6.8-5`, depends on `alsa-lib` and `alsa-ucm-conf`, explicitly enables ALSA support, and installs the `/etc/alsa/conf.d/50-pipewire.conf` and `99-pipewire-default.conf` activation symlinks.
- The motherboard now exposes the UCM `HiFi`, `HiFi 5+1`, and `HiFi 7+1` profiles rather than requiring the raw `pro-audio` fallback.
- Optical output is exposed as the stable `S/PDIF Output` sink and survives a user relog as the configured default.
- `aplay -L` exposes both `pipewire` and `default` through PipeWire, and `speaker-test -D pipewire` / `speaker-test -D default` work.
- Plasma audio settings no longer churn/jump between the anonymous Pro Audio endpoints.

This issue is considered fixed for the tested motherboard. Fresh-install/ISO testing should confirm that `alsa-ucm-conf` is pulled automatically through the PipeWire dependency.

### [x] SOURCE FIXED — one authoritative runtime installer entry point

The previously successful `scripts/install-bfs-menu-current.sh` differs from the older r74 snapshot only by the required `od -v` handling in the MD metadata probe, which prevents repeated identical zero lines from being collapsed by `od` and making the reserved-byte validation inconclusive.

r298 source policy:

- `scripts/install-bfs-menu-current.sh` is the authoritative runtime installer entry point.
- `bootstrap.sh` no longer selects a versioned installer by mtime; it validates and launches `install-bfs-menu-current.sh` directly.
- `scripts/bfs-build-iso.sh` already launches `install-bfs-menu-current.sh` from the live menu.
- `scripts/bfs-release-static-audit.sh` now verifies the authoritative current installer instead of requiring a stale symlink to r74.
- Historical `install-bfs-menu-v50-rXX-*.sh` snapshots remain in this archive for now; removing them is cleanup, not runtime correctness work.

Validation performed in this source tree:

```text
bash -n bootstrap.sh                         PASS
bash -n scripts/bfs-build-iso.sh            PASS
bash -n scripts/bfs-release-static-audit.sh PASS
scripts/bfs-release-static-audit.sh         PASS
```

Remaining validation: build the next ISO and confirm both Bootstrap -> Installer and live-menu -> Installer launch the same authoritative file.

### [~] SOURCE FIXED / FRESH-ISO RETEST REQUIRED — live console font privilege handling

The generated live console-font helper now:

- detects the active tty;
- applies fonts only on a local `/dev/ttyN` Linux virtual console;
- uses `setfont -C <tty>` directly when already root;
- otherwise uses `sudo setfont -C <tty>`;
- reports an informational message for SSH/PTS sessions instead of attempting a console-font ioctl there.

This closes the source-side privilege bug. A rebuilt ISO still needs local-VT and SSH/PTS smoke testing before the item is fully closed.

### [x] VERIFIED — installed bare-metal RC1 baseline is operational

The current bare-metal installation has progressed beyond the older tracker state:

- installed BFSOS boots from disk;
- GRUB loads the installed system;
- root mounts successfully;
- the existing RAID10 assembles and its LVM `/home` is reused;
- existing home data remains intact;
- networking works;
- normal user login works;
- Plasma is installed and starts;
- PipeWire/WirePlumber audio now survives relog with the intended optical S/PDIF default.

The RC1 gate remains open for source cleanup, fresh-ISO validation, and any remaining installer/release blockers; it is no longer waiting on first installed-system boot validation.

### [x] KERNEL VERSION AUDIT — no update required on 2026-09-20

Maintained BFSOS kernel ports already match the current released upstream versions checked on 2026-09-20:

```text
linux             7.2.6
linux-headers     7.2.6
linux-api-headers 7.2.6
linux-lts         6.18.52
```

Upstream 7.2.6 is the current stable release. The 6.18 longterm tree remains at 6.18.52; 6.18.53 is only in stable-review and must not be packaged as a released LTS update. No kernel Pkgfile version/release changes were made in r298.

### [ ] OPEN / POST-PLASMA — GNOME 51 alignment

The GNOME tree is still mixed in the GNOME 50 family (`gnome-meta` remains 50.0 and representative components such as `gnome-shell` remain 50.x). GNOME 51 migration remains open and should be handled as a coordinated stack update rather than a meta-package-only version bump.

### Files changed in r298

- `bootstrap.sh` — authoritative installer selection only.
- `scripts/bfs-build-iso.sh` — privilege/TTY-correct live console font application.
- `scripts/bfs-release-static-audit.sh` — authoritative installer policy validation.
- `BFSOS-fix-tracker-r298.md` — this tracker update.
- `BFSOS-RC1-tracker-20260920-r5.md` — consolidated current RC1 state.

---

# Previous tracker state — r297 (preserved below)

# BFSOS Fix Tracker — r297
Updated: 2026-09-17

## r297 — live USB boot race reproduced; ISO live-policy source follow-up

### [~] SOURCE FIXED / USB-VM + BARE-METAL RETEST REQUIRED — live media discovery must wait for USB enumeration

The same BFSOS ISO that boots correctly when QEMU exposes it as an optical CD-ROM (`/dev/sr0`) was reproduced failing in Dracut when QEMU exposes the identical ISO as USB mass storage. This matches the bare-metal USB symptom and isolates the failure to the live-media discovery timing/path rather than the ISO payload itself.

Reproduction evidence from the failed USB-emulation boot:

```text
2.098990  usb-storage: USB Mass Storage device detected
2.296241  dracut Warning: BFSOS live root not found: /bfsos/rootfs.squashfs
3.122720  QEMU HARDDISK appears
3.128370  /dev/sda created
3.188165  sda1 sda2 sda3 sda4 discovered
```

After the Dracut hook had already failed, `/dev/sda3` existed with label `BFSOS_0_9_0_x86_64`, `/dev/disk/by-label/BFSOS_0_9_0_x86_64` pointed to it, and a manual read-only mount by label succeeded. The expected `/bfsos/rootfs.squashfs` and the rest of the live-media payload were present. The current kernel has xHCI/EHCI/UHCI PCI host support built in, and the live initramfs contains `usb-storage`, `uas`, and `squashfs`, so the observed blocker is the one-shot media probe racing device enumeration.

Source change in the r297 ISO builder:

- keep `root=bfs-live`/cmdline handoff unchanged;
- include `udevadm` and `sleep` in the live initramfs module;
- add `bfs.live.wait=<seconds>` with a builder default of 15 seconds (`BFS_ISO_LIVE_MEDIA_WAIT`, valid 1-60);
- in the Dracut pre-mount hook, settle udev and retry label discovery/mounting at 250 ms intervals instead of probing once;
- prefer `blkid -L <label>` but retain `/dev/disk/by-label/<label>` and `/dev/sr0`/`sr1` fallbacks;
- accept any mountable hybrid-media filesystem view carrying the expected label rather than requiring optical-device semantics;
- fail only after the configured wait window and report both the expected label and SquashFS path.

Required retest before closing:

- rebuild the ISO;
- repeat QEMU optical-mode boot (must remain working);
- repeat QEMU USB-mass-storage boot (must now reach the live BFSOS userspace);
- verify the USB boot still finds the expected label and `/bfsos/rootfs.squashfs`;
- repeat a physical USB bare-metal boot on the previously failing machine;
- test at least one slower USB device/port so the retry window is exercised;
- confirm a genuinely missing/wrong-label medium still times out into a useful Dracut failure rather than hanging indefinitely.

### [~] SOURCE IMPLEMENTED / LIVE RETEST REQUIRED — early live console font selector and menu re-entry

The ISO builder now generates a live console-font helper and invokes it from live initialization before the normal BFSOS menu. It dynamically uses known installed console fonts when present, offers `Keep current/default`, includes a large/high-visibility candidate when available, applies the choice with `setfont`, records the selected live font under `/run/bfsos-live-console-font`, falls back without aborting if a font is unavailable, and exposes `Change console font` from the live menu for later adjustment.

The installed-system console-font requirement remains OPEN because it belongs in the installer. The current installer source was not included with the r297 input set, so no installed-target `/etc/vconsole.conf` policy is claimed here.

### [~] SOURCE IMPLEMENTED / LIVE RETEST REQUIRED — live Shell loads the normal profile

The live menu `Shell` action now starts `bash -l` rather than a plain `bash`. `BFS_LIVE_MENU_STARTED` is already exported by the outer login shell, so the nested login shell can load `/etc/profile`/normal profile state without recursively reopening the live menu. Fresh-ISO validation is still required.

### [~] SOURCE PARTIAL / PORT + INSTALLER WORK STILL REQUIRED — chrony live policy

The ISO package set now includes `chrony`. Live initialization waits for NetworkManager connectivity, disables/stops competing `systemd-timesyncd` behavior for the live session, starts the available chrony unit (with a direct `chronyd` fallback), and gives `chronyc waitsync` a bounded opportunity to synchronize before continuing.

This does **not** close the r294 chrony item. The maintained `chrony` Pkgfile/service definition was not supplied in this r297 input set and therefore was not audited or changed here. The installed-system `chrony` versus systemd-timesyncd versus no-service choice also belongs in the installer and remains OPEN until the current installer source is supplied.

### [~] SOURCE PARTIAL / LIVE RETEST + INSTALLED-SYSTEM INTEGRATION REQUIRED — GRUB readability and 30-minute console blanking

The generated live ISO GRUB configuration now prefers `1024x768`, then `800x600`, then firmware `auto`, retains the graphics payload, and adds `consoleblank=1800` to the live kernel command line. This addresses the live-media side of the r296 policy while preserving a fallback mode.

A generated larger GRUB `.pf2` font has **not** been added in this pass because the authoritative redistributable font/package source was not included and should not be guessed. Installed-system GRUB persistence through installer/kernel-update regeneration also remains OPEN and requires the installer/kernel-maintenance source paths.

### Files changed in this r297 pass

- `scripts/bfs-build-iso.sh`: USB discovery retry, configurable live-media wait, live font helper, profile-correct Shell action, live chrony policy, GRUB video fallback, and `consoleblank=1800`.
- `bootstrap.sh`: r74 ISO handoff update and forwarding of `BFS_ISO_LIVE_MEDIA_WAIT` when bootstrap hands the ISO builder back to the invoking non-root user.
- Tracker advanced to r297 with observed USB-race evidence and explicit remaining dependencies.

### Still needed to complete the related tracker work

1. Current installer source, specifically the script invoked as `scripts/install-bfs-menu-current.sh` (or the authoritative current installer if that name is only a symlink/wrapper), to implement installed-system console-font selection, optional chrony policy, `/etc/vconsole.conf`, and installed GRUB/`consoleblank=1800` persistence.
2. Current maintained `chrony` port/Pkgfile plus any BFSOS-specific service/config files, to complete the r294 port audit rather than assuming the package/service contract.
3. If BFSOS already has a kernel-maintenance or GRUB-defaults script separate from the installer, that file is needed to make the 30-minute console blanking and GRUB readability policy survive later kernel/GRUB regeneration.
4. If a specific console-font package is intended as the distribution default (for example Terminus), provide that maintained port/package definition so the live and installed selectors can guarantee the same font set instead of only using fonts already present.

---

# Previous tracker state — r296 (preserved below)

## r296 — live/install accessibility: console font selection, GRUB resolution, and 30-minute screen blanking

### [ ] OPEN / PRE-RC1 — add an early live-ISO console font selection before the main BFSOS menu

The live ISO needs an accessibility-first console-font choice before the user reaches the normal `Bootstrap BFSOS / Run BFSOS installer / Shell / Quit` menu. The default live console is currently harder to read than necessary on high-resolution displays and in VM consoles. Because the live environment is also the recovery/install environment, the font choice needs to be available before any substantial interaction is required.

Required work:

- Add a **console font selection step early in live startup**, before presenting the main BFSOS live menu.
- Offer a small set of clearly described console-font choices, including at least one large/high-visibility option suitable for low-vision use.
- Include a `Keep current/default` choice and make the menu safe to skip noninteractively.
- Apply the selected font immediately with the normal BFSOS console tooling so the following Bootstrap/Installer/Shell menus use the chosen font.
- Ensure the selection works on the local virtual console without depending on a graphical desktop.
- Do not make SSH behavior depend on the local console-font choice.
- Preserve a sane fallback if the requested font is unavailable; the live menu must remain usable rather than aborting startup.
- Make the selection available again from the live menu/tools path so the user can change it later without rebooting.
- When `3) Shell` is selected, the shell should still load `/etc/profile` automatically as tracked separately; the font-selection work must not regress that behavior.

Acceptance evidence:

- Fresh ISO boot reaches the font selector before the main live menu.
- Selecting each offered font changes the live console immediately.
- The large-font option remains readable through the installer and local shell.
- Skipping/keeping the default still reaches the main menu normally.
- Missing-font fallback is tested and does not break startup.

### [ ] OPEN / PRE-RC1 — add installer system console-font selection and persist it to the installed BFSOS system

The installer should let the user choose the installed system's virtual-console font rather than assuming one fixed default. The live-ISO font choice and the installed-system font choice may be related, but they are separate policy decisions: a user may want a very large live/install font while choosing a different persistent font for the installed system.

Required work:

- Add an installer option for the installed system's **virtual-console font**.
- Offer the same known-good font set used by the live ISO where practical, including a large/high-visibility choice and `Use live selection` / `Keep BFSOS default` behavior.
- Persist the chosen console font in the installed system using the systemd/vconsole configuration path used by BFSOS (for example `/etc/vconsole.conf`) rather than a live-only shell tweak.
- Preserve the selected keyboard map independently from the font choice.
- Validate that the configured font is actually present in the installed package set before writing the configuration.
- If the user selects a font package that is optional, ensure the installer stages/installs the required package before enabling that font.
- Resume/install-state handling must preserve the non-secret font selection so a resumed install does not silently fall back to a different font.

Acceptance evidence:

- Complete an install with a non-default large console font selected.
- Reboot into the installed system and confirm the selected font is applied on the real TTY before login.
- Verify `/etc/vconsole.conf` (or the final BFSOS equivalent) matches the installer selection.
- Verify changing the font does not alter the keyboard layout or break serial-console access.

### [ ] OPEN / PRE-RC1 — improve GRUB display resolution/font readability and standardize a 30-minute console screen timeout

BFSOS boot/install/recovery paths should remain readable on modern displays and should not blank too aggressively during long builds, installs, package operations, or troubleshooting sessions.

Required work:

- Audit the current GRUB video setup on UEFI and supported BIOS paths.
- Choose a more readable GRUB graphics mode/resolution policy instead of relying blindly on firmware defaults. Prefer a mode that scales sensibly in common physical displays and VM consoles and provide a safe fallback when the preferred mode is unavailable.
- Audit whether BFSOS should ship/generate a larger GRUB font (`GRUB_FONT`) for improved menu readability. If so, generate it from a redistributable installed font during the build rather than depending on a host-only asset.
- Keep GRUB resolution/font handling compatible with serial-console entries and recovery boot paths.
- Verify `grub-mkconfig` preserves the selected display policy through kernel updates.
- Standardize the normal BFSOS console blanking timeout at **30 minutes (1800 seconds)** for the live ISO and installed system unless the user explicitly chooses another policy.
- Ensure the intended `consoleblank=1800` behavior is present in generated kernel command lines where that is the selected BFSOS policy, including normal and recovery entries where appropriate.
- Do not rely only on a one-time GRUB edit; the kernel-maintenance/GRUB regeneration path must preserve the timeout setting.
- Distinguish console blanking from desktop power-management/display-sleep policy; this tracker item is for the boot/TTY path.

Acceptance evidence:

- Fresh ISO boot shows the GRUB menu at the intended readable resolution/font on the primary VM test path.
- At least one fallback video mode is tested.
- Installed-system GRUB uses the same policy after installation and after a kernel/GRUB regeneration.
- Kernel command lines show `consoleblank=1800` where expected.
- A local TTY remains visible for roughly 30 minutes of inactivity rather than blanking early.
- Serial console remains usable and does not inherit a graphics-only failure mode.

---

## Previous tracker state — r295

## r295 — prt-get dependency-change lifecycle and orphan cleanup audit

### [ ] OPEN / PRE-RC1 — verify `prt-get depinst` handles dependency additions correctly and add safe reverse/orphan cleanup for removed dependencies

Recent package-maintenance work makes dependency-list changes an important package-manager lifecycle case to verify before RC1. BFSOS needs explicit runtime proof that `prt-get depinst` reacts correctly when a maintained port gains new dependencies, and a safe reverse path when dependencies are later removed from the port and are no longer required by anything else.

Required work:

- Verify that `prt-get depinst <package>` installs any **newly added dependencies** when the target package's dependency list changes after the package was already installed.
- Test both a normal dependency addition and a nested/transitive dependency addition.
- Verify package update behavior when dependency resolution changes during an upgrade so the target package cannot be left installed or updated while a newly required dependency is missing.
- Confirm dependency ordering remains correct and that already-satisfied dependencies are not needlessly rebuilt/reinstalled.
- Audit how `prt-get` records or reconstructs which packages were installed as dependencies versus explicitly requested packages. If no reliable distinction currently exists, design one before implementing automatic orphan removal.
- Add or verify a reverse-dependency/orphan query that can identify packages which became unnecessary after a maintained port drops a dependency.
- Provide a **safe explicit cleanup path** for those no-longer-required dependency packages. Do not automatically remove them as a side effect of `depinst` or a normal package update unless BFSOS later adopts that policy deliberately.
- Before proposing removal, calculate reverse dependencies against the current installed package set and current port metadata so a package is never removed while another installed package, meta package, or compat-32 package still requires it.
- Handle shared dependencies, alternative/meta-package relationships, and compat-32 packages conservatively; these are high-risk cases for false orphan detection.
- Prefer user-visible reporting such as “no longer required” candidates plus an explicit cleanup command or confirmation step over silent deletion.
- Verify behavior when a dependency is manually installed before becoming a dependency, and when a package that was originally pulled as a dependency later becomes explicitly requested. Such packages must not be incorrectly classified as disposable.
- Add regression tests covering: dependency added -> `depinst` installs it; dependency removed -> package is reported as a removable orphan only when truly unused; shared dependency remains installed; explicitly requested package remains installed; compat-32/shared dependency remains protected.

Exit criteria: runtime tests prove `prt-get depinst` installs newly introduced dependencies for already-installed targets; BFSOS can reliably identify no-longer-required dependencies without false positives; cleanup requires an explicit safe action; reverse-dependency checks protect shared, explicit, meta, and compat-32 packages; and the behavior is documented for package maintainers/users.

---

# Previous tracker state — r294 (preserved verbatim below)

# BFSOS Fix Tracker — r294
Updated: 2026-09-16

## r294 — Live ISO time synchronization and shell-environment follow-up

### [ ] OPEN / PRE-RC1 — prefer chronyd for live ISO time synchronization; audit/update chrony port; make installed-system use optional

Fresh live-ISO testing showed that the system reached userspace and networking eventually worked, including successful external ping, but automatic time synchronization did not reliably complete during live startup. The current live image relies on systemd time synchronization and the observed behavior suggests startup ordering and/or service choice needs improvement before RC1.

Required work:

- Audit the maintained BFSOS `chrony` port before adding it to the RC1 live package set. Verify current upstream version, source URL, build options, installed configuration, service unit, runtime directories, user/group handling, and clean startup on BFSOS. Update the port if required.
- Make `chronyd` the preferred/default time-synchronization service for the **live ISO**.
- Ensure live startup ordering waits for usable networking before expecting chronyd to synchronize. Validate against the NetworkManager/network-online path used by the live image.
- Avoid running competing NTP clients simultaneously. If chronyd is active on the live image, disable/mask `systemd-timesyncd` there as appropriate.
- Keep bootstrap's existing ability to use whatever supported host/target time-sync mechanism is available; do not conflate bootstrap clock correction with the finished live-system policy.
- For the **installed system**, make chrony optional rather than mandatory. Installer policy should allow the user to select chrony versus the systemd time-sync path (and preserve a deliberate no-service choice if supported by the installer design).
- Keep timezone configuration separate from clock synchronization. The live RAID test showed timestamps consistent with UTC while the local session was EDT; the live environment must not treat timezone selection and NTP synchronization as the same operation.
- Add acceptance testing on a fresh ISO: boot live media, confirm networking becomes usable, verify `chronyd` is active, verify `chronyc tracking` / `chronyc sources` reports synchronization without manual intervention, and confirm the installer carries the chosen installed-system policy into the target.

Exit criteria: maintained chrony port is audited/current, fresh ISO contains and starts chronyd reliably after network availability, live time synchronizes automatically, no competing time-sync daemon is active, and installer-installed chrony remains an explicit/optional policy rather than an unconditional dependency.

### [ ] OPEN / PRE-RC1 — live menu Shell option must load the normal BFSOS profile automatically

Fresh live-ISO testing showed that selecting:

```text
3) Shell
```

drops into a shell without the normal BFSOS profile environment. The user had to run:

```bash
source /etc/profile
```

manually before the expected BFSOS prompt/PATH/profile settings appeared.

Required work:

- Change the live menu's Shell action so it enters an interactive environment with the normal BFSOS profile already loaded.
- Prefer a login-shell-equivalent implementation, or explicitly source `/etc/profile` before handing control to the interactive shell, whichever is cleaner and preserves normal BFSOS shell behavior.
- Do not require the user to manually run `source /etc/profile`.
- Verify that returning from the shell to the live menu still works as intended.
- Acceptance test on a freshly built ISO: choose `3) Shell` immediately after boot and confirm the expected BFSOS prompt, PATH, and profile-provided environment are present before any manual command is run.

Exit criteria: a fresh ISO's Shell menu option opens directly into the normal BFSOS environment and returns cleanly to the live menu without manual profile sourcing.

---

# Previous tracker state — r293 (preserved verbatim below)

# BFSOS Fix Tracker — r293
Updated: 2026-09-16

## r293 — Bootstrap Stage 2/3 transient libarchive loader failure investigation

### [ ] OPEN / PRE-RC INVESTIGATION — bootstrap reports `error loading shared library libarchive.so` while continuing

During a fresh bare-metal PrismLinux full-bootstrap run after manually removing stale `/tmp/lfs*` build state, the bootstrap progressed beyond the earlier Stage 2 glibc/`localedef` failure but emitted an `error loading shared library libarchive.so` message and continued building afterward.

This is not yet proven to be a fatal bootstrap defect, and the exact emitting executable/package still needs to be captured from the package log. The fact that the bootstrap continued suggests a transient tool invocation or package-order/runtime-linker availability problem rather than a complete loss of the target root. Do **not** mark this fixed or change dependency ordering solely from this observation.

Required investigation on the next reproducible run:

- Capture the exact command/binary that prints `error loading shared library libarchive.so` and the Stage/package log containing it.
- Determine whether the warning occurs in Stage 2, Stage 3, or both.
- At the failure point, inspect the relevant binary with `readelf -l`/`ldd` where usable and verify whether it resolves `libarchive.so` from the temporary toolchain or the target `/usr/lib`.
- Record whether `/usr/lib/libarchive.so*` and any temporary-toolchain copy exist at that exact point in the package sequence.
- Audit the bootstrap package order around `libarchive`, `pkgutils`, and any package-management tools that link against libarchive; verify that a consumer cannot execute before its matching libarchive runtime is installed and visible to the active dynamic loader.
- Check both Stage 2 and Stage 3 because Stage 2 uses the temporary toolchain while Stage 3 rebuilds against the target system and may have different ordering requirements.
- Confirm that the bootstrap does not silently ignore a failed package-management command merely because a later package succeeds. Any libarchive-linked command whose result is required must fail the stage explicitly.
- Re-run from a genuinely clean `/tmp/lfs-rootfs` + `/tmp/lfs-tools` state after any ordering fix and require the libarchive loader warning to disappear.

Context from the same validation run:

- The previous one-off Stage 2 glibc/`localedef` failure was not reproduced after manually clearing `/tmp/lfs*`; the clean rerun progressed beyond that point.
- This makes stale temporary build state a plausible explanation for the earlier glibc failure, but **not** proof that the newly observed libarchive warning is also stale-state related.
- The shadow/gshadow finalization bug remains a separate late-bootstrap/account-database issue and should not be conflated with this Stage 2/3 runtime-library ordering investigation.

Exit criteria: identify the exact emitting binary and stage/package, correct dependency/order/linker-path handling if required, complete a clean full bootstrap with no `libarchive.so` loader errors, and verify Stage 4/5 still produce a valid base archive.

---

# Previous tracker state — r292 (preserved verbatim below)

# BFSOS Fix Tracker — r292
Updated: 2026-09-16


## r292 — ISO live-boot acceptance progress and live-user privilege repair

### [x] LIVE VERIFIED — ISO creation and initial live boot

The current ISO pipeline has progressed beyond source-only status:

- the ISO package transaction completed successfully far enough to stage the live root;
- host-side `mformat`/`mtools` is now a required preflight dependency;
- GRUB mastering uses ISO level 3 so `rootfs.squashfs` may exceed the classic 4 GiB single-file ISO9660 limit;
- the custom `bfs-live` Dracut module is included in the generated initramfs;
- GRUB passes `root=bfs-live bfs.live=1`;
- a generated BFSOS ISO boots in a VM and reaches the live BFSOS userspace;
- NetworkManager brought up the VM NIC and the live system obtained an address on the libvirt network.

This closes the old claim that ISO creation and first boot were still completely unverified. It does **not** close installer/bootstrap acceptance.

### [x] SOURCE FIXED / LIVE BOOT VERIFIED — Dracut live-root handoff

The first VM boot failed in Dracut with:

```text
dracut: FATAL: No or empty root= argument
dracut: Refusing to continue
```

The live Dracut module had only registered a `pre-mount` hook, which ran too late to satisfy Dracut's earlier root validation. The builder now:

- adds a `cmdline` hook for `bfs-live`;
- recognizes `root=bfs-live`;
- sets `rootok=1` during the cmdline phase;
- keeps the pre-mount hook for ISO/SquashFS/overlay setup;
- emits `root=bfs-live bfs.live=1` in the generated GRUB entry.

A subsequent ISO boot reached the live BFSOS environment, proving the prior Dracut root-argument blocker is cleared.

### [x] SOURCE FIXED / BUILD-MASTERING VERIFIED — ISO host-tool and large-file requirements

Live builder testing exposed two host/mastering assumptions that are now part of the maintained design:

1. `grub-mkrescue` requires `mformat`, so the host preflight must require `mformat` and map it to the `mtools` package.
2. The BFSOS live SquashFS is larger than 4 GiB, so GRUB/xorriso mastering must use ISO level 3.

Verified working mastering form:

```bash
grub-mkrescue \
    -o "$ISO_PATH" \
    -iso-level 3 \
    -volid "$ISO_LABEL" \
    "$stage"
```

### [~] LIVE SESSION WORKS / MENU PRIVILEGE BLOCKER — passwordless sudo required for temporary `bfs` live account

The live ISO now reaches a usable `bfs` shell and networking works, but privileged live-menu operations are not yet reliable. A direct test of:

```bash
sudo systemctl status sshd
```

produced:

```text
sudo: a terminal is required to read the password
sudo: a password is required
```

The live account is intentionally temporary and already protected by the boot-time/session password used for local login and SSH. Requiring a second interactive sudo-password exchange breaks the installer/bootstrap workflow and provides little value on disposable live media.

**Required source change:**

Change the generated live sudoers policy from:

```text
bfs ALL=(ALL:ALL) ALL
```

to:

```text
bfs ALL=(ALL:ALL) NOPASSWD: ALL
```

Keep this policy strictly live-media-only. Installed BFSOS systems must continue to use the normal installer/account sudo policy.

**Validation before closing:**

- boot a newly generated ISO;
- set the temporary `bfs` live password;
- verify `sudo -n true` succeeds as `bfs`;
- verify `sudo systemctl status NetworkManager` or another harmless privileged command works without a second password prompt;
- launch **Bootstrap BFSOS** from the live menu;
- launch **Run BFSOS installer** from the live menu;
- enter/exit the **Shell** menu option cleanly;
- verify SSH login still uses the temporary live password;
- verify the live-only NOPASSWD rule is not copied into the installed target.

### [~] SOURCE FIXED / LIVE RETEST REQUIRED — live-session service detection

The generated `bfs-live-init.service` originally used:

```text
ConditionPathExists=/run/bfsos-live
```

while the initramfs created the marker under `/sysroot/run`. The real system's `/run` is volatile, making that marker unreliable across the initramfs -> real-root handoff.

The builder now uses the already-present kernel command line as the live-media discriminator:

```text
ConditionKernelCommandLine=bfs.live=1
```

The obsolete `/sysroot/run/bfsos-live` marker creation is removed. A rebuilt ISO must verify that the live initialization service consistently prompts for the temporary password and starts the intended live initialization path.

### [x] ISO CLEANUP POLICY ADJUSTED — preserve `/usr/src`

A cleanup experiment removed package source/build caches plus `/usr/src`, but the finished ISO shrank by only about 200 MiB. `/usr/src` is therefore retained because it can be useful for development/debugging and removing it did not materially improve image size.

The live-root cleanup should continue removing:

```text
/var/cache/pkg/sources/*
/var/cache/pkg/packages/*
/var/cache/pkg/build-work/*
/var/cache/pkg/build-work-disk/*
```

Package archives needed for offline installation may remain as one copy outside the SquashFS under `/bfsos/packages/$ARCH/`. Reassess that repository separately if ISO size remains excessive; do not remove it accidentally while changing live-root cache cleanup.

### Remaining ISO acceptance before release-ready

The ISO is now proven to **master and boot**, but the following remain required:

- live-init password prompt/service behavior after the kernel-command-line condition fix;
- passwordless live-only sudo and working Bootstrap/Installer/Shell menu entries;
- SSH host-key generation/startup and login validation;
- writable overlay behavior under normal and low-memory conditions;
- offline package/install behavior;
- complete VM installation from ISO;
- successful boot of the installed VM;
- repeat clean ISO build;
- UEFI and retained BIOS boot coverage;
- eventual bare-metal smoke test.

**Current r292 status: ISO CREATION + FIRST LIVE BOOT VERIFIED. LIVE USER/PRIVILEGE AND INSTALLER ACCEPTANCE REMAIN OPEN.**

---


## r291 — ISO builder existing-base archive reuse / rebuild-choice flow

### [ ] OPEN — ISO builder should reuse an existing verified base archive

First live ISO-builder testing exposed a workflow defect in the initial r290 implementation. The ISO builder currently invokes `bootstrap.sh full` by default even when the user has already completed the bootstrap and a valid verified BFSOS base rootfs archive exists. The current manual escape hatch, `BFS_ISO_SKIP_BOOTSTRAP=yes`, works for testing but should not be required for the normal interactive workflow.

Required behavior:

- Before launching a full bootstrap, detect the newest valid BFSOS base rootfs archive using the same archive-selection and verification rules used by the bootstrap.
- If a valid archive exists, prompt the user to choose **Use existing base archive**, **Rebuild base from scratch**, or **Cancel**.
- The normal/default choice should be **Use existing base archive** so a completed bootstrap is not repeated unnecessarily.
- If no valid archive exists, explain that a base build is required and then launch the full bootstrap path.
- Preserve `BFS_ISO_SKIP_BOOTSTRAP=yes` as a useful noninteractive/testing override, but do not require it for the normal menu or `./bootstrap.sh iso` workflow.
- Never silently reuse a corrupt, incomplete, or unverifiable archive.
- Before ISO assembly begins, display the selected archive path plus available BFSOS version/build-date metadata and verification status.
- The bootstrap-menu ISO entry and direct `./bootstrap.sh iso` / `build-iso` / `create-iso` entry points must use the same decision logic.
- Add source regression coverage for all three cases: valid existing archive, no archive present, and invalid/corrupt archive.

Current first-test workaround:

```bash
BFS_ISO_SKIP_BOOTSTRAP=yes ./bootstrap.sh iso
```

Exit criteria: an already-completed bootstrap can proceed into ISO assembly without rerunning Stage 1 through Stage 5, while a clean environment with no valid archive still enters the full bootstrap automatically and a corrupt archive is rejected.

---

## r290 — 2026-09-15 completion pass, current-version verification, and ISO-builder implementation

This pass reconciles the tracker with the live work completed during the last several days and the current uploaded project snapshot. Historical OPEN headings below are retained where useful for diagnosis history, but the status in this r290 section supersedes older contradictory headings.

### [x] Uploaded project snapshot integrity verified

The supplied `BFSOS-current.tar.zst` archive verified against its supplied SHA-256 before modification:

```text
fe25e0bc6b99276af6c704ba9d4b2d2063b407b368b206e729379aab03d2212e
```

### [x] RECENT LIVE VERIFIED — QEMU/libvirt/virt-manager stack

The recent virtualization dependency repair is now tracker-closed at the package/runtime level:

- QEMU `11.1.1-4` built and installed after liburing/libslirp fixes, corrected configure ownership, broad target support, and the new `dtc`/libfdt dependency.
- libvirt `12.7.0-3` built/installed; `libvirtd --version`, `virsh --version`, modular sockets, and `qemu:///system` access were exercised successfully as root.
- libvirt-python `12.7.0-1` built/installed and `import libvirt` returned version `12007000`.
- libvirt-glib installed its GIR/typelib payload and the `LibvirtGLib 1.0` GI import succeeded.
- virt-manager `5.1.0-3` built/installed and reached the GTK manager UI successfully.
- libvirt now has an idempotent package `pre-install` hook creating the `kvm` and `libvirt` system groups when absent. User membership remains installer/account-policy work, not a libvirt package-build blocker.

**CLOSED for the KVM package stack.** VM networking/topology and real guest creation remain later bare-metal validation work.

### [x] RECENT LIVE VERIFIED — libxml2 Python binding / virt-manager blocker

`libxml2 2.15.4-4` now uses upstream `--with-python=yes`; its normal build generates Doxygen XML and the Python binding, installs `libxml2.py` plus `libxml2mod` under Python 3.14 site-packages, and a live `import libxml2` succeeded. The earlier manual `setup.py`/Doxygen workaround is superseded and must not be restored.

### [x] RECENT SOURCE + BUILD/INSTALL VERIFIED — native Chromium port

The deferred native Chromium item is no longer an absent-port task. `chromium 153.0.8010.36` now exists in `ports/opt`, and the live build/install completed after the Clang-23, unsupported-warning, system-libffi, and GN fixes. r290 additionally makes the distro API policy explicit with `use_official_google_api_keys=false` and bumps the recipe to release 3.

A release-3 rebuild/runtime browser smoke test is still required before calling the newest recipe runtime-verified, but the old tracker item to “add native Chromium” is **CLOSED**.

### [x] CURRENT-VERSION VERIFIED — maintained kernel sources

The uploaded tree is already at:

```text
linux              7.2.6-1
linux-api-headers  7.2.6-1
linux-headers      7.2.6-1
linux-lts          6.18.52-1
```

On 2026-09-15 kernel.org lists stable `7.2.6` and longterm `6.18.52`, so no kernel source-version bump is required in this pass. The existing 6.18 LTS MD compatibility patch/policy remains in place.

**Source-version refresh is CLOSED/current.** Full package build, initramfs/GRUB inspection, and a successful boot into the current `7.2.6-BFS-Linux` and `6.18.52-BFS-LTS` packages remain live acceptance checks.

### [x] CURRENT RELEASE SPOT-CHECK — major recently touched packages

The current project versions were spot-checked against upstream release sources on 2026-09-15. No source-version bump was identified for the major packages most recently changed: QEMU `11.1.1`, libvirt/libvirt-python `12.7.0`, virt-manager `5.1.0`, Chromium `153.0.8010.36`, Firefox `155.0.1`, Firefox ESR `153.2.0esr`, Mesa `26.2.2`, Wine Staging `11.17`, GCC `16.2.0`, KDE Frameworks `6.30.0`, Plasma `6.7.5`, Gear `26.08.1`, Python `3.14.7`, Qt `6.11.2`, FFmpeg `9.0.1`, OpenSSL `4.0.2`, and systemd `261.2`.

This is **not** a claim that all 1,300+ maintained ports were revalidated online. The full maintained-port online audit remains the authoritative distribution-wide update check.

### [x] SOURCE REGRESSION RECONCILIATION

The aggregate source suite initially exposed two stale tests left behind by recent successful work: the removed standalone `opt/lld` port was still required by the r283 regression, and the Firefox coexistence test still required the now-invalid ESR `MOZ_APP_PROFILE` mozconfig assignment plus old visible names. Those tests were updated to the current intended policy.

Current aggregate result after the corrections and ISO source test addition:

```text
BFSOS r243 source tests: PASS
Firefox coexistence regression: PASS
build-work backend regression: PASS
pkgmk payload guard regression: PASS
ISO builder source regression: PASS
```

### [~] SOURCE IMPLEMENTED — BFSOS ISO creator + bootstrap integration

The major new r290 source work is now present in `scripts/bfs-build-iso.sh` and integrated into `bootstrap.sh`. The bootstrap menu has a **Build BFSOS bootable ISO** action and the CLI accepts `iso`, `build-iso`, or `create-iso`.

The initial implementation now source-defines the agreed design:

- runs a required-tool preflight before destructive/build work and reports all missing commands plus BFSOS package names where known;
- separately warns for optional QEMU boot-test tooling;
- checks both GRUB `i386-pc` and `x86_64-efi` platform payloads;
- rebuilds the complete base through the existing full-bootstrap stages before ISO assembly unless an explicit development override requests an existing archive;
- constructs the ISO live root in an isolated work directory outside the source checkout;
- builds/installs the live + installer option set in an isolated copy so optional packages do not redefine the minimal base archive;
- includes NetworkManager, OpenSSH, both BFSOS kernels, storage packages, installer optional packages, GRUB/EFI/SquashFS/mastering tools, and their resolved dependencies;
- ships the complete BFSOS Git tree at `/home/bfs/BFSOS`;
- creates a dedicated `bfs` live user and prompts for a session-only password at boot;
- enables NetworkManager for the live environment;
- generates fresh SSH host keys at runtime and starts SSH only after live-password initialization;
- safely uses `git pull --ff-only` only when the bundled live tree is clean and networking is available, otherwise keeps the release tree;
- presents Bootstrap / Installer / Shell choices after login;
- adds a BFSOS Dracut live-root module that mounts the ISO SquashFS read-only and overlays a writable tmpfs upper layer;
- stages the rebuilt base archive and binary package cache as ordinary ISO files, with `packages.list` and `packages.sha256`;
- embeds BFSOS version, architecture, build date, and Git commit;
- generates a GRUB rescue ISO and final SHA-256 checksum.

The ISO builder is **SOURCE IMPLEMENTED, NOT LIVE VERIFIED**. Do not mark it release-ready until the first complete BFSOS-side run proves the package-build stage, Dracut live-root handoff, UEFI boot, BIOS boot, writable overlay, live password/SSH flow, offline installer use, and full VM install/boot path.

### Remaining high-priority OPEN work after r290

- ISO live build/boot/install acceptance described above.
- Current-kernel package/initramfs/GRUB/boot validation for `7.2.6` and `6.18.52`.
- Full remaining pkgutils extension-compliance audit for core/xorg/opt/desktop collections.
- r261 remaining real remote-patch vendoring.
- r264 intermittent pkgadd segfault reproduction/backtrace.
- r267 multi-target `prt-get depinst` state/argument matrix.
- r268 deterministic Poppler Qt6 consumer contract.
- Remaining live installer/desktop acceptance tests that have not actually been exercised on a clean target.

---

## r284 — PRE-RC1 extension-compliance audit for all remaining port collections

### [ ] OPEN / PRE-RC1 PACKAGING POLICY — Audit every maintained Pkgfile against the BFSOS pkgutils extension contract

The contrib and compat-32 normalization pass established the intended BFSOS
packaging model, but the remaining maintained collections have not yet received
the same complete extension-compliance review. Complete this audit before RC1;
passing the existing static/tree audits alone does not prove that a recipe uses
the extension correctly or builds a valid runtime payload.

Current review scope after the contrib/compat-32 pass:

```text
collection  Pkgfiles  current pkg_build() candidates
core             210                             138
opt              408                             292
xorg             180                             177
plasma           176                              16
gnome             85                              18
lxqt              37                               1
xfce              26                               4
compiz            12                              12
----------------------------------------------------
total          1,134                             658
```

These 658 `pkg_build()` recipes are review candidates, not automatically 658
defects. Some packages genuinely require custom build orchestration. Likewise,
not every generic recipe needs a `build_opt` assignment when the extension's
defaults are sufficient.

### Required source audit and conversion policy

1. Let the extension own ordinary Autotools, CMake, Meson, and Make configure,
   compile, and staged-install flows.
2. Put package-specific configure/build arguments in `build_opt` when the
   generic builder can perform the build.
3. Use `pre_build()` only for required preparation such as generated sources,
   bootstrap/autogen steps, source-tree adjustment, or build-directory setup.
4. Use `post_build()` only for staged-payload cleanup, compatibility links,
   package-specific relocation, documentation selection, or other operations
   that must occur after the generic install.
5. Retain `pkg_build()` only when the package requires orchestration the
   extension cannot accurately represent, including multi-pass/multi-ABI
   builds, unusual language-specific workflows, partial target staging, or
   vendor binary extraction.
6. Add a concise `Custom build required:` explanation to every retained custom
   recipe and make it fail fast without leaking shell state to pkgmk.
7. Remove duplicated extension-owned defaults such as standard `--prefix`,
   `DESTDIR`, libdir, build-type, and toolchain settings unless the package has
   a documented exception.
8. Preserve package-specific flags and payload behavior during conversion;
   conversion to generic hooks must not silently discard configure switches,
   generated files, symlinks, static-library exceptions, or split-package
   content.
9. Increment `release` exactly once only for Pkgfiles whose recipe or resulting
   package payload changes. Do not blanket-bump packages that were reviewed but
   left byte-for-byte unchanged.
10. Add automated regression coverage that reports, by collection, generic
    recipes, documented custom recipes, unexplained custom recipes, invalid
    hooks, and extension-owned arguments duplicated locally.

### Audit and build order

Perform the work in dependency-aware stages so failures are attributable and a
single update does not queue the entire distribution for an uncontrolled
rebuild:

1. `core` and the pkgutils extension contract;
2. `xorg` and its foundational protocol/library stack;
3. `opt` in dependency groups;
4. `plasma`, `gnome`, `lxqt`, `xfce`, and `compiz` desktop collections;
5. a final repository-wide cross-collection dependency and policy pass.

### Required verification before closing

- Every changed Pkgfile passes `bash -n` and the repository static/tree audits.
- New extension-contract tests pass and contain no unexplained custom recipes.
- Representative Autotools, CMake, Meson, Make, Cargo, Python, and custom ports
  build from clean work directories on BFSOS.
- Foundation libraries are rebuilt and installed in dependency order before
  dependent desktop/application tests.
- Built archives are inspected for correct `/usr`, `/usr/lib`, `/usr/lib32`,
  `/opt/kf6`, debug/static-library, ownership, and footprint behavior as
  applicable.
- At least one clean-system package sweep proves there are no hidden ordering,
  missing-dependency, or stale-source-tree dependencies.
- Desktop smoke tests cover Plasma, GNOME, LXQt, XFCE, and Compiz after their
  converted packages are installed.

### Status

**OPEN / REQUIRED BEFORE RC1 — contrib and compat-32 now establish the intended
extension model; audit, convert where appropriate, and live-build verify the
remaining 1,134 maintained Pkgfiles without treating every custom recipe as an
automatic error.**

---

## r283 — full maintained-port sweep + source-integrity pass

This revision supersedes r282 as the current source tree for the 2026-09-10
pre-RC pass.  r282 was a targeted tracker/source pass and was **not** a complete
maintained-package refresh.  r283 continues from that work and adds the
repository-wide package/version/compatibility audit requested before live VM
validation.

### [x] SOURCE COMPLETE — full package sweep from the verified Git baseline

The current tree contains **1,315 Pkgfiles**.  Relative to baseline commit
`404436ae` (`updated BFSOS 2026-09-10`), the machine-readable package manifest
records:

```text
377 changed Pkgfiles
203 version updates
158 recipe/policy repairs without a version change
14 release-only changes
2 obsolete duplicate ports removed
```

Exact old/new versions and releases are recorded in:

```text
BFSOS-package-sweep-r283.tsv
```

The sweep did not rely only on the 2026-09-05 automated audit.  It also reviewed
the old UNVERIFIABLE/FETCH-ERROR set manually and reconciled releases published
between that audit and 2026-09-10.  This caught packages the old checker could
not discover or could not have seen yet.

Major coordinated updates include:

- Linux 7.2.4 and Linux LTS 6.18.50;
- KDE Frameworks 6.30.0, Plasma 6.7.5, and Gear 26.08.1;
- GStreamer core/plugin family 1.28.7;
- Firefox / Firefox-bin 155.0.1 and Discord 1.0.157;
- NSS 3.128, with native/32-bit/CA-certdata alignment;
- GLib 2.90.0, Samba 4.24.7, OpenLDAP 2.7.1, XZ 5.8.4;
- Poppler 26.09.0, LLVM/lld/libclc 23.1.1, rust-bindgen 0.73.2;
- libpcap 1.10.7, libgcrypt 1.12.3, Fuse 3.18.3,
  Ghostscript 10.08.0, librsvg 2.63.0 and imlib2 1.12.7;
- libedit 20260512_3.1, libksba 1.8.1, x265 4.3, UnRAR 7.2.7;
- Hyphen 2.8.9, gavl 2.0.1, ftjam 2.5.3rc2;
- Node.js 24.21.0 while intentionally retaining the BFSOS Node 24 LTS policy;
- Public Suffix List 20260910 and the 20260813 CA bootstrap bundle.

The full manifest is authoritative for the complete update set rather than this
human-readable selection.

### [x] SOURCE COMPLETE — stale/broken Pkgfile repair sweep

The version sweep was followed by recipe review so a new `version=` assignment
could not hide an old or ignored build recipe.  Confirmed repairs include:

- NSS: removed the obsolete NSS 3.54 patch, generated maintained nss-config /
  pkg-config metadata, and package `certutil`, `modutil`, and `pk12util`;
- Requests 2.34.2: refreshed the system-certificate patch so it no longer
  carries 2.33.0/2.32-era path/context and retains the BFSOS system CA policy;
- gnome-keyring 50.0: replaced the ignored/misspelled old Autotools recipe with
  the current Meson build path;
- python3-certifi: corrected the misspelled `pkg_buile()` hook;
- OpenLDAP: removed the hard-coded 2.7.0 post-install source-tree documentation
  path and stage documentation during package construction;
- libwnck2: repaired stale dependency metadata and DESTDIR install staging;
- Lua 5.4.9: removed the stale remote 5.4.8 shared-library patch dependency;
- Public Suffix List: uses the canonical upstream data endpoint with a versioned
  cache identity;
- RapidJSON: mutable `master` source replaced by an immutable commit;
- Node.js: LTS refreshed to 24.21.0 and the obsolete no-op experimental HTTP
  parser configure switch removed;
- transactional updater: FTP URLs are now recognized as remote sources, rather
  than being misclassified as missing local companion files.

Obsolete duplicate ports removed from the maintained tree:

```text
ports/opt/freetype2       (canonical provider: core/freetype)
ports/opt/cracklib-words  (dictionary/database already provided by core/cracklib)
```

### [x] SOURCE COMPLETE — compat-32 synchronization and legacy-policy cleanup

All **170** compat-32 Pkgfiles were re-audited after the native package sweep.
The old check was insufficient because many recipes could match a version while
still carrying stale per-port multilib policy.  The central pkgutils multilib
contract now owns the ABI defaults, and duplicated hard-coded `-m32`, host,
libdir and pkg-config assumptions were normalized where applicable.

Current synchronization result:

```text
matched/native-paired: 154
intentional legacy/compat-only: 16
drift: 0
unexplained: 0
```

Special mappings now cover real BFSOS package identities such as
`libnm-32 -> networkmanager`, `vulkan-tools-32 -> vulkan-headers`, and
`nvidia-fb-32 -> nvidia`.  `nvidia-fb-32` retains its historical package name
for compatibility but now ships 32-bit userspace libraries matching the native
595.99.02 production driver instead of the obsolete standalone 560 feature
branch.

The dependency audit currently reports **0 unresolved hard-dependency tokens**
and **0 duplicate package identities**.

### [x] SOURCE COMPLETE — source/companion integrity guard

A new repository regression evaluates every Pkgfile and validates that every
non-remote token in `source=()` exists in that port directory.  Current result:

```text
1,315 Pkgfiles evaluated
1,366 remote sources
220 local source companions
0 evaluation errors
0 missing local companions
```

The transactional updater's source classifier now includes FTP in addition to
HTTP/HTTPS, closing a case where valid ALSA/GNU/Sourceware FTP archives could
be mistaken for missing local files.

### [x] SOURCE TEST PASS — r283 aggregate

`./scripts/bfs-r243-source-tests.sh` passes in the r283 tree.  The script name
is historical; the suite now includes r283 regressions.  Passing coverage
includes:

- maintained Pkgfile shell syntax and full tree/release static audit;
- kernel-maintenance rollback/cleanup and MD compatibility policy;
- installer password, RAID personality and build-work policy;
- display-manager activation policy;
- canonical `/opt` environment ownership and Qt compatibility links;
- CA trust and XFCE fresh-profile source policy;
- checkupdate v10 + transactional updater regression;
- GTK4/Meson policy;
- all 170 compat-32 ports (154 paired / 16 intentional special);
- all-source local-companion existence regression;
- r283 maintained-package sweep regression;
- Firefox coexistence, disk-backed build-work and pkgmk payload guards.

### [ ] OPEN — r261 repository-wide remote patch vendoring

The updater/source policy is implemented, but the actual repository migration
is not complete.  The current tree still contains **34 explicit remote patch or
diff source references**.  This execution environment could not reliably
retrieve their bodies, so they were not replaced with unverified or invented
local files.

The exact remaining set is recorded in:

```text
BFSOS-remote-patch-inventory-r283.tsv
```

Exit criteria remain: download each patch from its maintained upstream,
validate content and applicability against the exact source release, store the
validated patch in the owning port directory, replace the remote source token
with the local companion, then rebuild/verify the affected package.  Do not
mark this closed merely because updater support exists.

### [ ] LIVE VALIDATION REQUIRED — source-complete changes

The source/package sweep does not replace BFSOS runtime acceptance testing.
The following tracker items remain live-validation work:

- Wine Staging rebuild/package inspection for `keep_static=1`;
- installer password behavior on a fresh install;
- RAID personality matrix plus RAID10 + LUKS + LVM with 6.18 LTS compatibility;
- build/initramfs/GRUB/boot verification of Linux 7.2.4 and 6.18.50;
- display-manager fresh-install/update/switch behavior;
- Qt5/Qt6 side-by-side package footprint, upgrade and removal tests;
- Firefox / Firefox ESR / Firefox-bin three-way coexistence/runtime tests;
- NSS/CA trust package install and real Firefox HTTPS validation;
- XFCE genuinely fresh-user login/defaults verification;
- large Qt6 disk-backed build completion;
- `/opt` ownership migration on an existing BFSOS install and Plasma reboot;
- representative compat-32 builds plus Wine/Steam runtime validation;
- updated package builds for recipes materially changed by r283.

### [ ] OPEN — r264 intermittent `pkgadd` segfault diagnosis

Remain evidence-driven.  Reproduce the same package/database state under the
required static/dynamic matrix and collect a backtrace before changing
libarchive/glibc/linkage policy.

### [ ] OPEN — r267 multi-target `prt-get depinst` state/argument matrix

The source wrapper audit found no reason to patch dependency resolution
speculatively.  Run the installed-state and target-order matrix on BFSOS and
change resolver/wrapper behavior only if the live reproduction identifies the
failure path.

### [ ] OPEN — r268 Poppler Qt6 feature/consumer contract

Poppler itself is refreshed to 26.09.0, but the Qt6 feature-ordering issue is
not closed by a version bump.  Reproduce the clean kio-extras/Okular consumer
case and decide the package contract from that evidence rather than forcing Qt6
into all Poppler consumers without validation.

### [x] SUPERSEDED / COMPLETE — r263 native Chromium port added and build/install verified

The old deferred state is superseded by r290. Chromium `153.0.8010.36` now exists as a maintained native BFSOS port and has completed a live build/install. Release-3 runtime smoke validation remains follow-up, not an absent-port task.

---

# Historical tracker content retained from r282 and earlier

## r282 source-pass completion — tracker work from the verified 2026-09-10 project archive

This revision records the completed source pass requested against the uploaded
`BFSOS-project-2026-09-10` archive.  Work remained in one extracted Git tree
throughout this pass; it was not restarted from a second archive or unrelated
baseline.

### Baseline / integrity

- Source baseline: Git commit `404436ae` (`updated BFSOS 2026-09-10`).
- The supplied archive SHA-256 was verified before modification:
  `edc82644a7d85097e303c3ed9dd7391f4f1057575fe616277dbbb3d8d6e8fd4a`.
- The r281 tracker was used as the authoritative task list for this pass.
- Historical MinGW r273-r279 OPEN text is retained below for history but is
  superseded by r280, which already records the CRT/GCC 16.2.0 cross-toolchain
  as FIXED / LIVE VERIFIED.  Do not reopen those historical items merely
  because their original headings contain `[ ] OPEN`.

## [x] SOURCE COMPLETE / LIVE PACKAGE VERIFY — r281 Wine Staging static archives

The current `ports/contrib/wine-staging/Pkgfile` already contains the required:

```text
keep_static=1
```

so the source-side r281 requirement survived in the supplied archive.  No
pkgmk-global policy change was made.  The remaining exit criterion is a live
Wine Staging rebuild/package inspection proving the expected Wine `lib*.a`
import libraries survive final package cleanup and `winegcc`/`wineg++` remain
functional.

## [x] SOURCE COMPLETE / LIVE INSTALL VERIFY — installer password floor

Installer current revision is now r74:

```text
scripts/install-bfs-menu-current.sh
  -> install-bfs-menu-v50-r74-pre-rc-source-fixes.sh
```

The shared optional-password path now rejects every nonblank password shorter
than 8 characters before `chpasswd` is called, clears temporary password
variables before reprompting, preserves the deliberate blank-password = locked
account behavior, and continues to let the normal password-policy backend
reject 8+ character candidates.  The same helper remains the common path for
root and login-capable users.

Source regression coverage verifies blank, 1-character, 7-character, exactly
8-character, longer, mismatch/backend-failure handling and shared-function
wiring.  A fresh live installer run remains required before final RC sign-off.

## [x] SOURCE COMPLETE / LIVE RAID BOOT VERIFY — r255 MD personality propagation

The installer now discovers the personality of every MD array required by the
target topology and generates the matching preload token, while preserving the
separate `rd.md.uuid=` requirement:

```text
Linear/JBOD  -> rd.driver.pre=linear
RAID0        -> rd.driver.pre=raid0
RAID1        -> rd.driver.pre=raid1
RAID10       -> rd.driver.pre=raid10
RAID4/5/6    -> rd.driver.pre=raid456
```

The source verifier rejects missing personality tokens.  Live validation must
still cover the RAID personality matrix and, specifically, the previous
RAID10 + LUKS + LVM LTS installation without manual GRUB editing.

## [x] SOURCE COMPLETE / LIVE RAID BOOT VERIFY — r256 Linux 6.18 MD metadata compatibility

The confirmed 6.18 compatibility backport remains package-local to
`linux-lts`.  Installer/kernel-maintenance integration now records the affected
MD requirement and applies:

```text
md_mod.check_new_feature=0
```

only to matching `6.18.*-BFS-LTS` GRUB Linux entries.  It is not added to
mainline kernels and is not made a global `GRUB_CMDLINE_LINUX` default.
`bfs-kernel-maintenance regenerate-grub` preserves the conditional decision so
a later GRUB regeneration cannot silently lose it while the affected 6.18 LTS
kernel remains installed.

The existing safe default remains strict.  Unknown/mixed metadata states are
not treated as permission to disable the kernel check.  Live RAID10 + LUKS +
LVM boot/reboot validation is still required for release sign-off.

## [x] SOURCE UPDATED / BUILD + REBOOT VERIFY — r257 kernel refresh

As checked on 2026-09-10, kernel.org lists:

```text
stable:    7.2.4
longterm:  6.18.50
```

The maintained ports are now aligned to:

```text
linux              7.2.4-1
linux-api-headers  7.2.4-1
linux-headers      7.2.4-1
linux-lts          6.18.50-1
```

The 6.18 LTS MD compatibility patch and its source assertion are retained.
Full kernel package builds, initramfs/GRUB inspection, and one successful boot
into each updated kernel remain mandatory live checks.

## [x] SOURCE COMPLETE / LIVE POLICY VERIFY — r272 display-manager activation

Installing/updating SDDM or Plasma Login Manager no longer selects, enables, or
starts a display manager as a package side effect.  The BFSOS selector defaults
to an explicit `unselected` state when no persisted choice exists.  Activation
is owned by explicit installer/administrator selection through the BFSOS
display-manager mechanism.

Source regression coverage verifies that package hooks do not call service
enablement/selection paths.  Clean-VM install/update/switch tests with multiple
display managers remain required.

## [x] SOURCE COMPLETE / FRESH-USER VERIFY — r270 XFCE first-login defaults

The distro-owned XFCE defaults now preserve the VM-proven two-panel layout and
canonical launcher icon names.  The five bottom launchers retain one-element
array semantics rather than scalar strings.

A guarded `bfs-xfce-first-login` initializer was added for the pieces XFCE 4.20
did not reliably materialize from `/etc/xdg` by itself.  It only fills the
known-empty BFSOS default launcher state and only assigns the default wallpaper
when the user has no existing wallpaper.  It discovers the real monitor name at
runtime and does not encode `Virtual-1` or another VM-only connector.

Existing customized profiles are not wholesale overwritten.  A genuinely new
user login/logout/login cycle remains the live acceptance test.

## [x] SOURCE COMPLETE / PACKAGE VERIFY — r258 Qt `/opt` compatibility layer

Qt5 and Qt6 retain their canonical payload under `/opt/qt5` and `/opt/qt6`.
The compatibility layer is deliberately versioned rather than creating
ambiguous generic `/usr` mirrors:

```text
moc-qt5       moc-qt6
uic-qt5       uic-qt6
rcc-qt5       rcc-qt6
qmake-qt5     qmake-qt6
lconvert-qt5  lconvert-qt6
lrelease-qt5  lrelease-qt6
lupdate-qt5   lupdate-qt6
              qtpaths-qt6
```

Libraries, headers, CMake and pkg-config metadata continue to use the intended
BFSOS `/opt` environment/prefix policy.  Live side-by-side install/update/remove
validation remains required.

## [x] SOURCE UPDATED + CHECKER COVERAGE / LIVE APP VERIFY — r259 Discord

`ports/opt/discord` is updated from `0.0.97` to stable Linux `1.0.157` for this
pass.  The v10 version checker has an explicit Discord stable-release provider
and regression coverage so Discord cannot silently disappear from maintained
version-audit output again.

A BFSOS package build/install and desktop launch/audio/video/notification smoke
test remain live validation work.

## [x] SOURCE COMPLETE — r260 maintained update must validate companion files

The maintained version checker is now v10 and remains read-only.  A separate
transactional updater was added:

```text
scripts/bfs-maintained-port-updater.py
```

The updater consumes reviewed/verified `UPDATE` rows rather than independently
guessing versions while rewriting files.  A version update inventories local
companion files and treats patch validation as part of the same transaction.
A filename containing the old version is a review signal, not automatic proof
that a patch is invalid: patch applicability against the proposed source is the
deciding check.

The regression suite covers stale Requests-style patch behavior and verifies
that a failed companion/patch validation blocks the update transaction.

## [x] SOURCE COMPLETE — r261 vendor required remote patches transactionally

The updater recognizes remote patch/diff inputs, including aliased sources such
as:

```text
fix.patch::https://example.invalid/download?id=123
```

and small suffix-less endpoints whose validated downloaded content is actually
a patch.  It downloads atomically, rejects empty/HTML/error payloads, reuses an
identical local patch, refuses same-name/different-content collisions, preserves
normal upstream source archives as remote sources, rewrites the Pkgfile and
local patch as one transaction, and validates applicability before accepting a
patch-bearing version update.

A full online maintained-port migration/audit is still required before RC
freeze to resolve any real-world remote endpoints the offline source regression
fixtures cannot exercise.

## [x] SOURCE COMPLETE / LIVE COEXISTENCE VERIFY — r262 Firefox family

The three variants now use separate package/application identities:

```text
Firefox      -> /usr/bin/firefox      -> /usr/lib/firefox
Firefox-ESR  -> /usr/bin/firefox-esr  -> /usr/lib/firefox-esr
Firefox-bin  -> /usr/bin/firefox-bin  -> /usr/lib/firefox-bin
```

Source-built Firefox variants set separate Mozilla profile/remoting identities.
The binary package now has its own desktop file/icon/application directory and
uses a package-owned Mozilla `-app` application.ini override to give
`firefox-bin` a distinct remoting/profile identity without forcing global
`-no-remote` behavior.

Static coexistence regression tests pass.  All three packages still require a
live side-by-side build/install/launch/profile/remoting/update/remove test.

## [x] SUPERSEDED BY r290 — r263 native Chromium

Historical deferred state only. The native Chromium port now exists and the initial live build/install succeeded; see r290 for current status.

## [ ] LIVE DIAGNOSIS REQUIRED — r264 intermittent `pkgadd` segfault

No speculative glibc, libarchive or static-linkage change was made.  The tracker
requires the same package/database state to reproduce under static and dynamic
`pkgadd` and a backtrace/data-path diagnosis before choosing a fix.  This cannot
be responsibly closed from the offline source archive alone.

## [x] SOURCE COMPLETE / LARGE BUILD VERIFY — r265 disk-backed build-work escape hatch

The centralized build wrapper now supports per-port build-work backend metadata.
The implementation uses the tracker-preferred alternate-root design rather than
unmounting/remounting the machine-wide tmpfs:

```text
ordinary ports: /var/cache/pkg/build-work
build_work=disk: /var/cache/pkg/build-work-disk
```

`qt6` is the first confirmed port marked `build_work=disk`.  The selection is
made before pkgmk creates/extracts the work tree.  This preserves the normal
installer tmpfs for ordinary packages and avoids a global mount transition or
concurrent-build race.

Live Qt6 completion past the previous 32G ENOSPC point remains the principal
acceptance test; additional heavy ports should only be marked after measured or
credible workspace evidence.

## [x] SOURCE COMPLETE / UPGRADE VERIFY — r266 canonical `/opt` environment ownership

The initial idea of moving the old leaf-owned filenames `qt5.sh`, `qt6.sh` and
`rustc.sh` directly into `aaa_filesystem` was rejected during final review
because an existing installation could still hit an ownership collision if the
base package updated before the old leaf owner relinquished the same pathname.

The final migration is ownership-safe:

```text
/etc/profile.d/bfs-opt.sh
/usr/lib/environment.d/60-bfsos-opt.conf
```

are newly named, base-owned integration files from `aaa_filesystem`.  Qt5, Qt6
and Rustc stop shipping their legacy profile scripts when their package releases
are updated.  The new base profile is guarded so absent optional prefixes are a
no-op.  KF6 profile handling is likewise guarded.

This permits `aaa_filesystem` to be updated before or after the leaf packages
without claiming an existing leaf-owned pathname.  Live package-database
migration testing is still required on an installation that has the old files.

## [ ] LIVE STATE MATRIX REQUIRED — r267 multi-target `prt-get depinst`

No resolver patch was made in this pass.  The current source wrapper does not
change explicit `depinst` semantics, and the tracker explicitly requires the
installed-state/argument-order matrix before changing `prt-get`, `pkgmk`, or
`pkgadd`.  The original observed giant desktop transaction may have been a valid
no-op, stale package-database state, or a resolver bug; the saved VM state or a
minimal live reproduction is needed to identify the correct layer.

## [ ] LIVE REPRODUCTION REQUIRED — r268 Poppler Qt6 optional-feature ordering

Source inspection confirms that the current Poppler recipe conditionally enables
its Qt6 frontend based on whether Qt6 is present at build time, which can create
different Poppler payloads depending on install order.  However, the current
`kio-extras` port itself does not provide enough source-only evidence to choose
between making Qt6 a hard Poppler dependency, splitting the frontend, or encoding
a consumer feature contract.

Per the tracker, no broad dependency change was made without reproducing the
exact required Poppler Qt6 artifact.  Reproduce the prior kio-extras failure in
the BFSOS VM and capture its CMake error before selecting the permanent edge.

## [x] SOURCE COMPLETE / CLEAN-BOOT VERIFY — r269 KF6 systemd-user environment

`aaa_filesystem` now supplies the proven early graphical-session environment via
`/usr/lib/environment.d/60-bfsos-opt.conf`, including `/opt/kf6/bin` in PATH and
`/opt/kf6/share` in XDG_DATA_DIRS before Plasma user units start.  Shell profile
logic is no longer the only source of those paths, and duplicate unconditional
`/opt/kf6/bin` injection was removed from the base profile.

Clean SDDM -> Plasma Wayland boots, plus Plasma X11/GNOME/LXQt/XFCE regression
logins, remain live acceptance tests.

## [x] SOURCE COMPLETE / CLEAN-INSTALL HTTPS VERIFY — r269 CA / p11-kit / NSS trust

The CA package lifecycle no longer relies on `make-ca -g` downloading Mozilla
roots during normal package installation.  `ca-certificates` now obtains pinned
NSS `certdata.txt` through normal pkgmk source handling, installs the maintained
input under `/usr/share/pki/mozilla`, provides the `/etc/ssl/certdata.txt`
compatibility link, and refreshes with `make-ca -r` when the trust tooling is
available.  `make-ca` post-install also uses the offline refresh path.

NSS/native + nss-32 were refreshed to 3.128 for this source set.  Final review
caught and fixed the extracted-tree path used to locate `certdata.txt`, and that
path is now asserted by the regression test.

A clean BFSOS package install still must verify nonzero PEM roots, nonzero
`trust list --filter=ca-anchors`, curl/OpenSSL success and Firefox HTTPS without
manual `make-ca -g`.

## [x] SOURCE HARDENING — generic implausibly-empty package guard

`bfs-pkgmk` now rejects a produced archive that has no regular/symlink package
payload (the historical `usr/`-only MinGW failure class).  This complements
port-specific payload assertions and prevents a failed unrelated build from
becoming an apparently installable directory-only package.

## [x] SOURCE CLEANUP — compat-32 central ABI policy restored

The aggregate suite exposed two remaining recipes that bypassed the central
compat-32 ABI policy with local explicit `-m32` flags: `bzip2-32` and
`ncurses-32`.  Those recipe-local flags were removed.  bzip2 retains its
package-specific PIC/file-offset requirements while inheriting the i686 ABI
compiler/flags from centralized pkgmk policy, and ncurses uses the centralized
multilib host setting.

The complete compat-32 synchronization regression now passes:

```text
170 ports total
151 native-paired
19 compatibility-only/special
```

## r282 source regression result

The complete aggregate source regression suite passes after all final-review
corrections:

```text
BFSOS r243 source tests: PASS
Firefox coexistence regression: PASS
build-work backend regression: PASS
pkgmk payload guard regression: PASS
```

Included subtests also pass for kernel maintenance + MD compatibility, prt-get
`--no-new-deps`, installer build-work sizing, installer password/MD policy,
display-manager activation policy, `/opt` environment ownership, Qt compatibility
links, CA trust policy, XFCE defaults, checkupdate v10, the maintained-port
updater, GTK4/Meson policy, and all 170 compat-32 ports.

## Remaining live validation order after r282 source merge

1. Update `aaa_filesystem`, Qt5/Qt6/Rustc and verify the old -> new profile-file
   ownership migration without `pkgadd -f` or manual deletion.
2. Build/install the CA/NSS/make-ca stack on a clean BFSOS VM and verify both PEM
   and p11-kit roots plus Firefox HTTPS without `make-ca -g`.
3. Build the refreshed 7.2.4 and 6.18.50 kernels; inspect initramfs/GRUB and boot
   each once.
4. Re-run the six-disk RAID10 + LUKS + LVM installer path with Linux 6.18 LTS;
   require `rd.md.uuid`, `rd.driver.pre=raid10`, conditional
   `md_mod.check_new_feature=0`, and a boot with no manual GRUB edit.
5. Exercise SDDM/Plasma Login Manager installation and explicit switching with
   more than one display manager installed.
6. Create a genuinely fresh XFCE user and verify panels, launchers/icons,
   wallpaper and logout/login persistence without editing that user's home.
7. Install/run Firefox, Firefox-ESR and Firefox-bin simultaneously and exercise
   remoting/profile/update/remove isolation.
8. Build Qt6 using the disk backend and pass the previous 32G ENOSPC point.
9. Build/install/launch Discord 1.0.157.
10. Rebuild Wine Staging and verify import `lib*.a` payload plus winegcc/wineg++.
11. Run the r264 static/dynamic pkgadd reproduction/backtrace matrix.
12. Run the r267 depinst installed-state/argument-order matrix.
13. Reproduce the r268 Poppler/kio-extras feature requirement and then choose the
    narrowest deterministic dependency/package split.

**r282 PASS STATUS: source-fixable pre-RC tracker work targeted by this pass is
implemented and the complete source regression suite is green.  Remaining OPEN
items above are intentionally either live-state investigations/boot-package
validation or the explicitly deferred post-RC Chromium port.**

---

# Previous tracker state — r281 (preserved verbatim below)

# BFSOS Fix Tracker — r281
Updated: 2026-09-09

## r281 Wine Staging static import-library preservation

### [ ] OPEN / WINE TOOLCHAIN — preserve Wine import libraries with `keep_static=1`

During the MinGW CRT/GCC repair, BFSOS pkgmk policy was reconfirmed: package-level `keep_static=1` is required whenever `*.a` files are functional package payload. Wine Staging also intentionally installs a large set of Wine import libraries (`lib*.a`) used by the Wine development/toolchain side alongside `winegcc`/`wineg++`. Therefore `ports/contrib/wine-staging/Pkgfile` must opt in with `keep_static=1` if it is not already present. Do not change pkgmk globally.

Required source audit:
- `mingw-w64-crt`: `keep_static=1` required — FIXED/VERIFIED.
- `mingw-w64-gcc`: `keep_static=1` required — FIXED/VERIFIED.
- `wine-staging`: `keep_static=1` required for Wine import-library payload — source/build verification pending.
- `mingw-w64-headers`: no static archive payload requirement; leave normal cleanup policy.
- `mingw-w64-binutils`: do not opt in by default; only add `keep_static=1` if a specific required final-package archive is demonstrated.
- Future `mingw-w64-winpthreads`: when added, audit/preserve its required import/static archives.

Validation for Wine Staging after rebuild:
```bash
bsdtar -tf /var/cache/pkg/packages/wine-staging#*.pkg.tar.zst \
  | grep -E '/lib[^/]*\.a$' \
  | head -n 40
```
Require the expected Wine import libraries to survive package cleanup before considering `winegcc` development functionality complete.

---

# r280 MinGW-w64 CRT + GCC 16.2.0 — FIXED / VERIFIED on BFSOS

## [x] FIXED / VERIFIED — MinGW-w64 CRT and GCC cross-toolchain

Live BFSOS validation on 2026-09-09 completed successfully for both `i686-w64-mingw32` and `x86_64-w64-mingw32`.

### Final verified package state

- `mingw-w64-crt 14.0.0-2`:
  - package contains no leaked `/var/cache/pkg/build-work` tree;
  - i686 target payload count: 495 entries;
  - x86_64 target payload count: 953 entries;
  - required startup objects/import libraries are present for both targets, including `crt2.o`, `dllcrt2.o`, `libmingw32.a`, `libmingwthrd.a`, `libmingwex.a`, `libmoldname.a`, `libmsvcrt.a`, `libkernel32.a`, `libuser32.a`, `libadvapi32.a`, and `libshell32.a`;
  - required archives are preserved with BFSOS `keep_static=1`.
- `mingw-w64-gcc 16.2.0-1`:
  - build completes successfully with `pkgmk` exit status 0;
  - package size is approximately 204 MiB with 3,549 archive entries;
  - package contains all four compiler drivers: `i686-w64-mingw32-gcc`, `i686-w64-mingw32-g++`, `x86_64-w64-mingw32-gcc`, `x86_64-w64-mingw32-g++`;
  - required GCC runtime archives such as `libgcc.a`, `libgcc_eh.a`, and `libgcov.a` are present for both targets;
  - package contains zero `/var/cache/pkg/build-work` leakage;
  - installed compiler reports GCC 16.2.0 for both targets.

### Final functional smoke tests

Both C and C++ link tests succeed for both target architectures:

- i686 C output: `PE32 executable for MS Windows ... Intel i386`;
- x86_64 C output: `PE32+ executable for MS Windows ... x86-64`;
- i686 C++ output: `PE32 executable for MS Windows ... Intel i386`;
- x86_64 C++ output: `PE32+ executable for MS Windows ... x86-64`.

This validates the complete path from installed compiler -> headers -> CRT/startup objects -> MinGW import libraries -> GCC runtime -> successful Windows PE link output for both C and C++.

### Root causes closed

1. `mingw-w64-crt` temporary bootstrap installs inherited BFSOS global `DESTDIR`/install-root staging variables, redirecting the private sysroot into `$PKG/var/cache/pkg/build-work/...`. The repaired recipe explicitly unsets those variables only for private bootstrap installs and keeps final CRT installation staged normally.
2. The CRT package originally lost required MinGW `.a` import/runtime libraries because BFSOS correctly removes static archives by default. `mingw-w64-crt` now explicitly uses `keep_static=1`.
3. The original GCC recipe lacked fail-fast/payload validation and could emit an empty package after build failure. The repaired GCC recipe fails immediately and asserts staged compiler payload.
4. GCC 16.2.0 with the Win32 thread model failed while configuring `libgomp` because pthreads were unavailable. The validated build uses `--enable-threads=win32` with `--disable-libgomp`.
5. `mingw-w64-gcc` also uses `keep_static=1` so required GCC target runtime archives survive normal pkgmk cleanup.

### Remaining follow-up, not a blocker for the verified toolchain

- [ ] OPTIONAL ENHANCEMENT — add a real `mingw-w64-winpthreads` port and deliberately reassess POSIX thread model/OpenMP (`libgomp`) support. Do not re-enable `libgomp` until that dependency path is packaged and tested.
- [ ] AUDIT TOOLING — fix the maintained-port version audit so GCC release-directory providers correctly report current MinGW GCC releases rather than falsely marking 13.1.0 current.
- [ ] PKGUTILS HARDENING — add a generic implausibly-empty package/payload sanity guard so unrelated failed ports cannot generate installable empty archives.

**STATUS: FIXED / VERIFIED. The MinGW-w64 CRT + GCC 16.2.0 C/C++ cross-toolchain is functional on BFSOS for both i686 and x86_64 Windows targets.**

---

# r279 MinGW-w64 GCC live diagnosis — disable libgomp for Win32-thread bootstrap

- [~] **OPEN — mingw-w64-gcc 16.2.0 now passes the prior CRT/runtime linker failure after the corrected `mingw-w64-crt 14.0.0-2` was installed.**
  - Live build evidence shows the stage compiler links and executes configure tests successfully, including producing `a.exe`, and `libatomic` builds/links against `/usr/i686-w64-mingw32/lib`.
  - The next confirmed failure is `configure: error: Pthreads are required to build libgomp`, followed by `configure-target-libgomp` failure.
  - Current GCC repair intentionally uses `--enable-threads=win32`; BFSOS still has no confirmed `mingw-w64-winpthreads` port. Therefore do not enable OpenMP/libgomp in this bootstrap/full compiler repair pass.
  - Change the GCC recipe from `--enable-libgomp` to `--disable-libgomp` and rebuild cleanly. Keep `keep_static=1`, both i686/x86_64 targets, `c,c++,lto`, fail-fast checks, and payload assertions.
  - Future enhancement: add/package `mingw-w64-winpthreads` and deliberately reassess POSIX threading/OpenMP support before re-enabling libgomp. Do not add a nonexistent dependency now.
  - Keep this item OPEN until the rebuilt GCC archive is substantial, contains both target gcc/g++ frontends and required runtime archives, installs successfully, and both i686/x86_64 C/C++ PE-output tests pass.

# BFSOS Fix Tracker — r277
Updated: 2026-09-09


## r277 MinGW-w64 CRT static import-library preservation

### [ ] OPEN / PRE-RC1 TOOLCHAIN — add `keep_static=1` to `mingw-w64-crt` and rebuild release 2

The r276 CRT staging repair worked: `mingw-w64-crt 14.0.0-2` built successfully, `pkgmk` exited 0, and the package no longer leaked the private bootstrap tree under `var/cache/pkg/build-work`. The final staged tree contained the MinGW runtime/import archives during `make install`.

However, BFSOS `pkgmk` then correctly applied its normal package-cleanup policy and removed all `*.a` archives because the port had not opted in to static-library preservation. This left startup objects such as `crt2.o` and `dllcrt2.o` in the final package while deleting required MinGW import/runtime archives including `libmingw32.a`, `libmingwthrd.a`, `libmingwex.a`, `libmoldname.a`, `libmsvcrt.a`, `libkernel32.a`, `libuser32.a`, `libadvapi32.a`, and `libshell32.a`.

This is expected BFSOS pkgutils behavior when `keep_static=1` is absent; the package manager should not be changed globally. `mingw-w64-crt` is a package where the `.a` files are required functional payload, so the port must explicitly opt in.

### Required repair

- Add the BFSOS package-level extension `keep_static=1` near the package metadata in `ports/opt/mingw-w64-crt/Pkgfile`.
- Keep `release=2` while this unpublished/testing recipe is being corrected; rebuild the same release with force rather than introducing another release solely for an uninstalled test artifact.
- Remove/regenerate the test footprint because the current generated footprint reflects the package after static archives were stripped.
- Rebuild with retained work and inspect the archive before installation.
- Require zero `var/cache/pkg/build-work` entries and require the full import/runtime archive set for both i686 and x86_64 targets.
- Only after that install `mingw-w64-crt 14.0.0-2`, verify the live target library trees, and retry `mingw-w64-gcc 16.2.0-1`.

### Validation

```bash
crt_pkg=/var/cache/pkg/packages/mingw-w64-crt#14.0.0-2.pkg.tar.zst

bsdtar -tf "$crt_pkg" | grep -c '^var/cache/pkg/build-work/'

for T in i686-w64-mingw32 x86_64-w64-mingw32; do
    echo "===== $T ====="
    bsdtar -tf "$crt_pkg" | grep -E \
      "^usr/$T/lib/(dllcrt2\.o|crt2\.o|libmingw32\.a|libmingwthrd\.a|libmingwex\.a|libmoldname\.a|libmsvcrt\.a|libkernel32\.a|libuser32\.a|libadvapi32\.a|libshell32\.a)$"
done
```

### Status

**r276 DESTDIR/bootstrap contamination FIX VERIFIED. Remaining packaging defect: required MinGW `.a` import/runtime libraries are removed by normal BFSOS pkgmk cleanup because `mingw-w64-crt` lacks `keep_static=1`.**

---


## r276 MinGW-w64 CRT package root cause confirmed — bootstrap DESTDIR contamination

### [ ] OPEN / PRE-RC1 TOOLCHAIN — repair `mingw-w64-crt` bootstrap staging and regenerate a real CRT package

Live BFSOS package inspection has now confirmed the exact reason `mingw-w64-gcc 16.2.0` cannot link target `libgcc_s`: the installed `mingw-w64-crt 14.0.0-1` package does not contain a usable CRT payload.

Observed archive counts:

```text
mingw-w64-crt package files: 3746
i686 target files:           0
x86_64 target files:         0
leaked build-work files:     3743
```

The archive is overwhelmingly populated by paths under:

```text
/var/cache/pkg/build-work/pkgmk-mingw-w64-crt/src/sysroot/...
```

while it contains zero package files under either intended target prefix:

```text
/usr/i686-w64-mingw32/
/usr/x86_64-w64-mingw32/
```

This explains the GCC failure for missing `dllcrt2.o`, `libmingw32.a`, `libmingwex.a`, `libmoldname.a`, `libmsvcrt.a`, `libkernel32.a`, and related target import/runtime libraries.

### Confirmed root cause

BFSOS `pkgmk` globally exports package staging variables including:

```text
DESTDIR=$PKG
DEST_DIR=$PKG
INSTALLROOT=$PKG
install_root=$PKG
INSTALL_ROOT=$PKG
```

The current `mingw-w64-crt` Pkgfile builds a private bootstrap sysroot under `$SRC/sysroot` and invokes ordinary bootstrap installs such as:

```bash
make install
make install-gcc
```

without clearing the globally exported staging variables. Those temporary bootstrap installs therefore do not remain private to `$SRC/sysroot`; they are redirected through `$PKG`, causing the absolute `$SRC/sysroot` path to be captured as package payload under `var/cache/pkg/build-work/...`.

The Pkgfile then continues after failures because the bootstrap and CRT phases do not consistently propagate nonzero statuses. This allowed an invalid CRT package to be produced and installed.

### Required r276 repair

1. Keep the existing self-bootstrap architecture for this repair pass so a clean BFSOS system can build the CRT without requiring an already-complete MinGW GCC.
2. For all *temporary bootstrap* `make install` / `make install-gcc` operations, explicitly remove BFSOS package-staging variables from the environment so installation truly goes to the private `$SRC/sysroot`.
3. Never clear staging variables for the final CRT installation; the final CRT must explicitly use `DESTDIR="$PKG"`.
4. Make every configure/build/install step fail-fast with `|| return 1`; a failed bootstrap must never fall through to package creation.
5. Rebuild the private bootstrap from current maintained toolchain sources aligned with the live BFSOS ports:
   - binutils 2.47
   - GCC 16.2.0
   - mingw-w64 CRT/headers 14.0.0
6. Use a minimal C-only GCC bootstrap compiler and the Win32 thread model for this pass; POSIX/winpthreads integration remains separate until BFSOS has a maintained winpthreads package and coordinated policy.
7. Force the final CRT configure to use the private bootstrap compiler/binutils rather than accidentally resolving host/final tools from another installation.
8. Add package assertions for both targets requiring startup objects and import/runtime libraries such as `dllcrt2.o`, `crt2.o`, `libmingw32.a`, `libmingwthrd.a`, `libmingwex.a`, `libmoldname.a`, `libmsvcrt.a`, `libkernel32.a`, `libuser32.a`, `libadvapi32.a`, and `libshell32.a`.
9. Add an explicit guard that fails if `$PKG/var/cache/pkg/build-work` exists, preventing private work/sysroot paths from ever becoming distributable package payload.
10. Regenerate the CRT footprint only after the rebuilt archive has passed payload inspection.
11. After installing the corrected CRT, retry `mingw-w64-gcc 16.2.0-1`; the previously retained GCC failure is expected to clear only once both i686 and x86_64 CRT payloads are present in `/usr/<target>/lib`.

### Validation

Before installing the corrected CRT package:

```bash
crt_pkg=$(ls -1t /var/cache/pkg/packages/mingw-w64-crt#*.pkg.tar.zst | head -n1)

bsdtar -tf "$crt_pkg" | grep -c '^var/cache/pkg/build-work/'
bsdtar -tf "$crt_pkg" | grep -c '^usr/i686-w64-mingw32/'
bsdtar -tf "$crt_pkg" | grep -c '^usr/x86_64-w64-mingw32/'

for T in i686-w64-mingw32 x86_64-w64-mingw32; do
    bsdtar -tf "$crt_pkg" | grep -E "^usr/$T/lib/(dllcrt2\.o|crt2\.o|libmingw32\.a|libmingwthrd\.a|libmingwex\.a|libmoldname\.a|libmsvcrt\.a|libkernel32\.a|libuser32\.a|libadvapi32\.a|libshell32\.a)$"
done
```

Required result: build-work count `0`, nonzero target-file counts for both architectures, and all required runtime/startup/import-library assertions present.

### Status

**ROOT CAUSE CONFIRMED. `mingw-w64-crt 14.0.0-1` packaged the private bootstrap work tree because BFSOS globally exported `DESTDIR=$PKG` into bootstrap `make install` operations. The repaired r276 Pkgfile clears staging variables only for temporary bootstrap installs, uses current binutils/GCC bootstrap sources, adds fail-fast behavior and payload guards, and must be validated before retrying the final GCC build.**

---


## r275 MinGW-w64 toolchain bootstrap failure — CRT payload missing during GCC 16.2.0 build

### [ ] OPEN / PRE-RC1 TOOLCHAIN — repair MinGW CRT/bootstrap ordering before retrying full GCC

A retained-work (`pkgmk -d -kw`) BFSOS build of `mingw-w64-gcc 16.2.0-1` now fails correctly instead of producing another empty package. The new fail-fast guard is therefore working. The build reaches the target `libgcc` link stage for `i686-w64-mingw32`, uses the expected cross-binutils from `/usr/i686-w64-mingw32/bin`, and then fails because the MinGW CRT/startup/import-library payload is absent from the target sysroot.

Confirmed linker failures include:

```text
/usr/i686-w64-mingw32/bin/ld: cannot find dllcrt2.o
/usr/i686-w64-mingw32/bin/ld: cannot find -lmingwthrd
/usr/i686-w64-mingw32/bin/ld: cannot find -lmingw32
/usr/i686-w64-mingw32/bin/ld: cannot find -lmingwex
/usr/i686-w64-mingw32/bin/ld: cannot find -lmoldname
/usr/i686-w64-mingw32/bin/ld: cannot find -lmsvcrt
/usr/i686-w64-mingw32/bin/ld: cannot find -ladvapi32
/usr/i686-w64-mingw32/bin/ld: cannot find -lshell32
/usr/i686-w64-mingw32/bin/ld: cannot find -luser32
/usr/i686-w64-mingw32/bin/ld: cannot find -lkernel32
```

The configure phase successfully locates target binutils such as `ar`, `as`, `dlltool`, `ld`, `nm`, `objcopy`, `objdump`, `ranlib`, `readelf`, `strip`, and `windres` under `/usr/i686-w64-mingw32/bin`. Therefore the current failure is not a missing-binutils problem. GCC also creates and uses its bootstrap `xgcc`, so the failure occurs specifically when target runtime objects/libraries are needed.

### Required work

1. Audit the installed `mingw-w64-crt` package and its package archive/footprint for both target triples. Do not trust `prt-get isinst` alone.
2. Require the i686 CRT payload to contain at minimum `dllcrt2.o`, `libmingw32.a`, `libmingwex.a`, CRT import libraries, and Windows system import libraries in the target library directory. Require equivalent x86_64 payload before the x86_64 GCC pass.
3. Audit `ports/opt/mingw-w64-crt/Pkgfile` for target list, configure prefix/sysroot, DESTDIR handling, and whether its build incorrectly depends on an already-complete MinGW GCC.
4. Resolve the circular bootstrap relationship explicitly. The maintained build sequence must be staged, conceptually: target binutils -> headers -> bootstrap C compiler/runtime-capable compiler stage -> CRT -> final GCC C/C++/LTO. Do not model the cycle as ordinary package dependencies that can install empty placeholders.
5. If BFSOS keeps CRT and GCC as separate packages, document which bootstrap artifact provides the compiler needed to build CRT from a clean system. A dedicated bootstrap port/stage is preferable to silently relying on an old installed cross-GCC.
6. Add payload assertions to `mingw-w64-crt` just as for GCC, so an installed CRT package cannot consist only of directories or headers while omitting startup objects/import libraries.
7. Keep the GCC 16.2.0 build tree with `pkgmk -kw` during diagnosis. Do not retry the full build until the CRT package contents and installed sysroot are verified.
8. After the CRT is repaired, retry GCC 16.2.0 and require both i686 and x86_64 compiler/link smoke tests that produce PE executables.

### Immediate BFSOS validation

Inspect the currently installed/package-cache CRT before changing anything:

```bash
prt-get isinst mingw-w64-crt

cd /usr/ports/opt/mingw-w64-crt
nl -ba Pkgfile

echo "===== FOOTPRINT ====="
cat .footprint 2>/dev/null || true

echo "===== PACKAGE ARCHIVE ====="
crt_pkg=$(ls -1t /var/cache/pkg/packages/mingw-w64-crt#*.pkg.tar.zst 2>/dev/null | head -n1)
echo "$crt_pkg"
[ -n "$crt_pkg" ] && bsdtar -tf "$crt_pkg" | sed -n '1,240p'

echo "===== REQUIRED RUNTIME FILES ON LIVE SYSTEM ====="
for T in i686-w64-mingw32 x86_64-w64-mingw32; do
    echo "--- $T ---"
    find /usr/$T -maxdepth 3 -type f \
      \( -name 'dllcrt2.o' -o -name 'crt2.o' -o -name 'libmingw32.a' \
         -o -name 'libmingwex.a' -o -name 'libmoldname.a' \
         -o -name 'libmsvcrt.a' -o -name 'libucrt.a' \
         -o -name 'libkernel32.a' -o -name 'libuser32.a' \
         -o -name 'libadvapi32.a' -o -name 'libshell32.a' \) \
      -print 2>/dev/null | sort
done
```

### Status

**OPEN — GCC 16.2.0 failure root cause identified as missing MinGW CRT/runtime payload for the target sysroot. The GCC fail-fast fix is working. Next action is to audit/fix `mingw-w64-crt` and the clean-system bootstrap sequence before another full GCC build.**

---

## r274 MinGW-w64 GCC live diagnosis — empty-package guard + stale version-audit correction

### [ ] OPEN / PRE-RC1 TOOLCHAIN — repair `mingw-w64-gcc` so failed/empty builds cannot become installable packages

Live BFSOS testing proved that `mingw-w64-gcc` could be recorded as installed even though its package archive contained only the top-level `usr/` directory. Removing the package with `pkgrm` correctly removed the false installed state.

Prism-side source audit of `ports/opt/mingw-w64-gcc/Pkgfile` then confirmed:

```text
version=13.1.0
release=2
Depends on: mingw-w64-binutils mingw-w64-headers mingw-w64-crt
configure: --prefix=/usr --target=$T
install:   make DESTDIR=$PKG install
```

Therefore the defect is **not** the previously suspected missing `DESTDIR` staging argument; `DESTDIR=$PKG` is already present. No `i686-w64-mingw32-gcc` or `x86_64-w64-mingw32-gcc` was found on the Prism host during the audit, so the next test is not allowed to pass by accidentally using a host cross compiler.

The existing recipe also has no explicit fail-fast checks around configure/build/install and no package-payload assertion. This permits the package lifecycle to reach packaging with an empty or nearly empty `$PKG` tree if an earlier GCC step fails or is mishandled by surrounding `pkgmk` behavior.

### Version-audit regression discovered

The maintained-port version audit reported `mingw-w64-gcc 13.1.0` as CURRENT, but GCC 16.2.0 was released on 2026-08-07 and current Arch MinGW packaging has already moved to GCC 16.2.0. The version-audit provider/directory parsing for this port is therefore stale/wrong and must be fixed so GCC release directories such as `gcc-16.2.0/` are recognized correctly.

### Required source fix

1. Update `mingw-w64-gcc` from GCC 13.1.0 to the current maintained GCC 16.2.0 release rather than spending a full cross-toolchain build validating an obsolete compiler first.
2. Use HTTPS for the canonical GCC source URL.
3. Keep both BFSOS target triples unless a later toolchain-policy decision deliberately drops 32-bit Windows support:
   - `i686-w64-mingw32`
   - `x86_64-w64-mingw32`
4. Explicitly enable only the maintained language/runtime set required by BFSOS initially (`c,c++,lto`) instead of relying on GCC defaults that can pull in additional target-runtime requirements.
5. Because BFSOS currently has no confirmed `mingw-w64-winpthreads` port, use the native Win32 GCC thread model for this repair pass rather than adding a nonexistent dependency. Track a POSIX/winpthreads model conversion separately if BFSOS later adds and maintains winpthreads.
6. Make every configure, build, install, and directory transition fail the package immediately on error.
7. After each target install, require the staged target compiler to exist and be executable under `$PKG/usr/bin/`.
8. Before packaging, require both target GCC drivers and a nontrivial staged payload. An archive containing only `usr/` must be impossible to produce successfully.
9. Only regenerate `.footprint` after the staged payload and final archive have been inspected and proven non-empty.
10. Add a package-manager/pkgmk-level generic empty-payload sanity check later so this class of defect cannot silently affect other ports.

### Required build validation

On the BFSOS build VM/chroot, remove any stale cached package and stale source/build directories, then build the repaired port from scratch. Before installation, inspect the package archive and require at minimum:

```text
usr/bin/i686-w64-mingw32-gcc
usr/bin/i686-w64-mingw32-g++
usr/bin/x86_64-w64-mingw32-gcc
usr/bin/x86_64-w64-mingw32-g++
usr/lib/gcc/i686-w64-mingw32/<version>/...
usr/lib/gcc/x86_64-w64-mingw32/<version>/...
```

The archive must contain thousands of real files/directories, not only `usr/`.

After installation, compile at least C and C++ smoke tests for both targets and verify the results are PE/Windows executables rather than ELF host binaries.

### Status

**OPEN — ROOT CAUSE NARROWED. `DESTDIR` is already correct; missing fail-fast/payload validation is confirmed as a packaging-design defect. The MinGW GCC version audit is also confirmed stale (`13.1.0` incorrectly reported CURRENT while GCC 16.2.0 exists). Prism source repair is next, followed by one clean BFSOS VM build of the repaired/current port.**

---


## r273 MinGW-w64 GCC empty-package regression

### [ ] OPEN / PACKAGE-INTEGRITY — `mingw-w64-gcc` builds an effectively empty package

Live BFSOS testing on 2026-09-09 confirmed that `mingw-w64-gcc` can build/install successfully from the package manager's point of view while the generated package contains no compiler payload. The observed package was `mingw-w64-gcc#13.1.0-2.pkg.tar.zst`; `prt-get isinst mingw-w64-gcc` reported the package installed, but both the package archive and generated footprint contained only the top-level `usr/` directory. The bad package was then removed with `pkgrm mingw-w64-gcc`.

Observed evidence:

```text
package mingw-w64-gcc is installed

bsdtar -tf /var/cache/pkg/packages/mingw-w64-gcc#13.1.0-2.pkg.tar.zst
usr/

cat /usr/ports/opt/mingw-w64-gcc/.footprint
drwxr-xr-x      root/root       usr/
```

### Required work

- Audit `ports/opt/mingw-w64-gcc/Pkgfile` for a staging/install-path defect, including incorrect `DESTDIR`, `prefix`, sysroot, build-directory, or install-target handling.
- Verify the GCC cross-toolchain is built for the intended target(s), beginning with `x86_64-w64-mingw32`, and that `make install` / `make install-gcc` writes into `$PKG` rather than the live build host or an untracked build directory.
- Audit dependency/order requirements against `mingw-w64-binutils`, `mingw-w64-headers`, and `mingw-w64-crt`; do not treat an empty archive as a successful toolchain build.
- Add a package-payload sanity check so `pkgmk` fails the port when the staged tree contains only directories or lacks expected MinGW GCC executables/libraries. At minimum, require the generated package to contain a target compiler such as `usr/bin/x86_64-w64-mingw32-gcc` (or the final BFSOS canonical equivalent) plus its associated GCC runtime/support files.
- Check for build-host contamination after failed/incorrect staging. A broken port must not install unowned `x86_64-w64-mingw32-*` binaries or GCC target directories directly under the host `/usr`.
- Regenerate `.footprint` only after the staged package has been manually inspected and confirmed non-empty.
- Rebuild the package on BFSOS, inspect it with `bsdtar -tf` before installing it, then install and run a minimal Windows-target compile/link test.

### Validation

```bash
prt-get isinst mingw-w64-gcc
bsdtar -tf /var/cache/pkg/packages/mingw-w64-gcc#*.pkg.tar.zst | sed -n '1,120p'
grep -E 'x86_64-w64-mingw32-(gcc|g\+\+|cc)$' /usr/ports/opt/mingw-w64-gcc/.footprint
command -v x86_64-w64-mingw32-gcc
x86_64-w64-mingw32-gcc --version
```

Then compile/link a trivial C program and verify the result is a Windows PE executable rather than an ELF host binary.

### Status

**CONFIRMED LIVE REGRESSION — port repair and payload validation remain OPEN.**

---


## r272 display-manager / greeter activation policy

### [ ] OPEN / PRE-RC1 POLICY — Install display managers and greeters without automatically enabling them

Live multi-desktop testing has shown that automatically enabling a newly installed graphical login manager is unsafe when BFSOS can have several desktop environments and display-manager packages installed at the same time. Installing a package such as SDDM, GDM, Plasma Login Manager, LightDM, or another greeter/display-manager implementation must make the software and its service units available, but **must not automatically make it the active graphical login manager merely because the package was installed or updated**.

The package-management layer and individual ports should therefore separate **installation** from **activation**.

### Required BFSOS policy

1. Display-manager/greeter packages must install their binaries, configuration, PAM files, service units, greeter/session support, and other required runtime files normally.
2. A normal `pkgadd`, `prt-get install`, `prt-get depinst`, desktop-meta installation, or package update must **not** automatically enable or start a newly installed display manager.
3. Individual display-manager ports must not run package hooks equivalent to:

```text
systemctl enable <display-manager>.service
systemctl enable --now <display-manager>.service
systemctl start <display-manager>.service
```

and must not silently replace the current `display-manager.service` selection.
4. Do not ship package-owned enablement symlinks that cause a display manager to become active solely from installing its package.
5. Installing an additional display manager must leave the currently selected display manager unchanged.
6. Updating an installed but inactive display manager must leave it inactive.
7. Updating the currently selected display manager must preserve that explicit selection rather than switching to another installed manager.
8. Selection/activation belongs to an explicit administrator or installer action. The BFSOS installer or a dedicated post-install selection tool may offer the installed choices and, after the user deliberately chooses one, enable exactly that one display manager and establish the canonical `display-manager.service` link.
9. If the user installs one or more display managers but has not explicitly selected one, BFSOS must remain in a safe unselected state rather than guessing which greeter should own graphical login. Console/TTY access must remain available.
10. Switching display managers must be a deliberate operation: disable the previously selected manager, select/enable the requested manager, update `display-manager.service`, and avoid uninstalling the old package simply to switch greeters.
11. Desktop meta-packages may depend on or recommend a suitable display-manager package where BFSOS policy requires it, but satisfying that dependency must not count as consent to activate it.
12. Package upgrades, `prt-get sysup`, ports synchronization, and dependency changes must never silently change the active greeter/display manager.

### Relationship to existing Plasma Login Manager / SDDM tracker work

This policy strengthens the existing single-active-display-manager work. Older tracker wording that describes SDDM as a conservative/default choice or Plasma Login Manager as an optional choice must be interpreted as an **installer/user selection default**, not as permission for either package to auto-enable itself during installation.

The same rule applies across GNOME/GDM, Plasma/SDDM or Plasma Login Manager, LXQt, XFCE, and any future BFSOS graphical login manager: packages provide the service; the user or installer explicitly selects which service owns graphical login.

### Audit targets

Audit every maintained display-manager/greeter port and related meta-package for package hooks, post-install scripts, presets, symlink creation, or other logic that can activate a service as a side effect of installation. At minimum inspect the currently shipped choices and any package that creates or modifies:

```text
/etc/systemd/system/display-manager.service
/etc/systemd/system/graphical.target.wants/
```

Also audit installer/bootstrap code for assumptions that installing a desktop or greeter automatically means it should be enabled.

### Validation / exit criteria

On a clean BFSOS VM/image:

1. Install each supported display-manager package individually and verify the package installation succeeds while the service remains unselected/inactive until explicitly chosen.
2. Install two or more display managers together and verify package order does not decide which one becomes active.
3. With one display manager explicitly selected, install another and verify the original selection remains unchanged.
4. Run `prt-get sysup` with multiple display managers installed and verify the active selection does not change.
5. Exercise the installer/display-manager selector and verify an explicit choice enables exactly one manager and establishes the correct `display-manager.service` link.
6. Switch explicitly from one manager to another and verify only the newly selected manager owns graphical login after reboot.
7. Verify an installation with no selected display manager remains reachable by console/TTY and does not enter a boot loop or conflicting greeter start sequence.
8. Verify GNOME, Plasma X11/Wayland, LXQt, and XFCE sessions remain available to whichever compatible display manager the user explicitly selects.

Useful checks include:

```bash
systemctl is-enabled gdm.service 2>/dev/null || true
systemctl is-enabled sddm.service 2>/dev/null || true
systemctl is-enabled plasma-login-manager.service 2>/dev/null || true
readlink -f /etc/systemd/system/display-manager.service 2>/dev/null || true
systemctl status display-manager.service --no-pager 2>/dev/null || true
```

### Status

**OPEN / PRE-RC1 POLICY + PACKAGING AUDIT — display-manager and greeter packages should install their services but must not automatically enable, start, or replace the active graphical login manager. Activation must happen only after an explicit installer/admin selection.**

---

## Previous tracker state — r271


## r271 live GNOME SVG icon validation summary

### COMPLETED / VM-PROVEN — GNOME blue-diamond application icons fixed by enabling the librsvg GdkPixbuf SVG loader

GNOME itself was already usable, but several application icons rendered as blue-diamond/placeholders. Live BFSOS VM diagnostics isolated the failure to SVG decoding rather than the GNOME Shell environment, Adwaita, hicolor metadata, or stale application desktop files.

The active GNOME session was using:

```text
icon-theme = Adwaita
XDG_DATA_DIRS=/usr/local/share:/usr/share/:/opt/kf6/share
```

Adwaita correctly inherited `hicolor`, `/usr/share/icons/hicolor/index.theme` correctly advertised `scalable/apps`, and the required application SVGs were installed, including:

```text
/usr/share/icons/hicolor/scalable/apps/org.gnome.Settings.svg
/usr/share/icons/hicolor/scalable/apps/org.gnome.Nautilus.svg
```

The hicolor cache also contained those icon names. Despite that, GTK/GdkPixbuf initially reported both reverse-DNS icon names as missing, while raster Xfce icons under `48x48/apps` resolved normally.

### Proven root cause — librsvg was built without its GdkPixbuf SVG loader

Before the fix:

- `/usr/lib/librsvg-2.so.2.62.3` existed and was owned by the `librsvg` package;
- no SVG loader module existed under `/usr/lib/gdk-pixbuf-2.0/2.10.0/loaders/`;
- `gdk-pixbuf-query-loaders` showed no registered SVG decoder;
- direct `GdkPixbuf.Pixbuf.new_from_file_at_scale()` attempts on the GNOME Settings and Nautilus SVG icons failed with `Couldn’t recognize the image file format`.

The maintained BFSOS port at `ports/contrib/librsvg/Pkgfile` was therefore corrected on Prism. `librsvg` 2.62.3 was bumped from release 2 to release 3 and the Meson configuration now explicitly enables:

```text
-D pixbuf=enabled \
-D pixbuf-loader=enabled
```

The source change was pushed to the maintained BFSOS tree, synced to the BFSOS VM, and rebuilt as:

```text
librsvg 2.62.3-3
```

Meson confirmed both options as enabled and built the `pixbufloader-svg` target. The resulting package now installs:

```text
/usr/lib/gdk-pixbuf-2.0/2.10.0/loaders/libpixbufloader_svg.so
```

### Cache behavior — no extra librsvg post-install hook proven necessary

Upstream's staged `DESTDIR` install printed a note that GdkPixbuf loader registration may need to be refreshed after installation. BFSOS runtime validation showed that after `prt-get update librsvg`, the installed `loaders.cache` already contained `libpixbufloader_svg.so` and `gdk-pixbuf-query-loaders` reported SVG support.

Both direct SVG render tests succeeded **before** the later manual `gdk-pixbuf-query-loaders --update-cache` command:

```text
/usr/share/icons/hicolor/scalable/apps/org.gnome.Settings.svg: OK 48x48
/usr/share/icons/hicolor/scalable/apps/org.gnome.Nautilus.svg: OK 48x48
```

Therefore do **not** add a special librsvg post-install cache-refresh hook solely on the basis of this incident. The existing BFSOS package-install/cache handling was sufficient once the loader module actually existed. Reopen cache handling only if a clean-install regression proves the loader is installed but absent from `loaders.cache`.

### Final GNOME validation

After the corrected librsvg package was installed, GTK icon lookup changed from `MISSING` to the expected SVG paths:

```text
org.gnome.Settings: /usr/share/icons/hicolor/scalable/apps/org.gnome.Settings.svg
org.gnome.Nautilus: /usr/share/icons/hicolor/scalable/apps/org.gnome.Nautilus.svg
```

Brian then completed a GNOME logout/login visual test and confirmed the blue-diamond/placeholder icon problem was fixed.

### Status

**COMPLETED / VM-PROVEN:** GNOME SVG application icons render correctly with `librsvg 2.62.3-3` built using `-D pixbuf=enabled -D pixbuf-loader=enabled`. Keep these build options in the maintained port and include SVG icon lookup/rendering in future GNOME desktop regression checks.

## r270 live XFCE X11 default-profile validation summary

### XFCE two-panel layout and launcher icons are VM-proven; permanent BFSOS first-login profile fix remains OPEN

Live BFSOS VM testing completed the XFCE X11 layout investigation that was still pending in r269. The XFCE desktop itself is healthy, and the intended classic BFSOS layout can be made fully functional and persistent. The remaining work is to encode the proven runtime state correctly in the BFSOS-owned system defaults so a brand-new user receives it without manual `xfconf-query` repair.

### Proven target layout

The working profile is:

```text
panel-1  full-width top panel
         position p=6;x=0;y=0
         length 100
         size 26
         plugins 1-10

panel-2  centered bottom launcher dock
         position p=10;x=0;y=0
         length 10
         length-adjust true
         size 48
         plugins 11-15
```

The top panel retains the normal Applications/menu, task list, separators, tray, notifications, power, audio, clock and actions plugins. The bottom dock contains five launchers:

```text
11  Terminal
12  Files / Thunar
13  Ristretto Image Viewer
14  Parole Media Player
15  Xfburn Disc Burner
```

The two-panel layout survived a complete XFCE logout/login cycle once the launcher properties were corrected.

### Root cause 1 — launcher `items` properties must be arrays, even for one item

The decisive live failure was that the five launcher plugin properties had become scalar strings such as:

```text
/plugins/plugin-11/items = bfs-terminal.desktop
```

XFCE expects each launcher `items` property to be an array. A one-item launcher must therefore be represented as a one-element string array, for example conceptually:

```text
/plugins/plugin-11/items = [bfs-terminal.desktop]
```

The correct live `xfconf-query` creation form is:

```bash
xfconf-query -c xfce4-panel \
  -p /plugins/plugin-11/items \
  -n -a -t string -s bfs-terminal.desktop
```

and equivalently for plugins 12-15.

Before the type correction, the launcher files and icon names could be valid yet the panel rendered generic blue gear icons after a fresh panel/session start. After converting all five `items` properties to real one-element arrays, the proper application icons appeared immediately and survived logout/login.

**Permanent BFSOS requirement:** the shipped/default XFCE profile must preserve the correct array type in `default.xml` / first-login import data. Do not serialize a single launcher item as a scalar string during profile generation, migration, or post-install scripting.

### Root cause 2 — fresh-user launcher files are not being populated reliably from the current packaged location

A fresh user profile created the five launcher plugins but initially showed:

```text
/plugins/plugin-11/items []
/plugins/plugin-12/items []
/plugins/plugin-13/items []
/plugins/plugin-14/items []
/plugins/plugin-15/items []
```

and there were no corresponding files under:

```text
~/.config/xfce4/panel/launcher-11/
...
~/.config/xfce4/panel/launcher-15/
```

The BFSOS system currently has launcher definitions under:

```text
/etc/xdg/xfce4/panel/launcher-11/
/etc/xdg/xfce4/panel/launcher-12/
/etc/xdg/xfce4/panel/launcher-13/
/etc/xdg/xfce4/panel/launcher-14/
/etc/xdg/xfce4/panel/launcher-15/
```

but a clean XFCE first-login did not reliably materialize those launcher files into the user's active panel directory. Manually copying the launcher directories to `~/.config/xfce4/panel/` and then restoring the correctly typed array properties produced the intended runtime state.

**Permanent BFSOS requirement:** audit the XFCE profile packaging/import mechanism and install the launcher data in the form/location XFCE 4.20 actually consumes for a new user. Do not depend on a package-time path that leaves the user launcher directories empty after first login. The source fix should create the correct state automatically without overwriting existing user customizations on upgrade.

### Root cause 3 — use the canonical installed application icon names

The custom BFSOS launcher files originally used older/generic icon names. Live inspection of the installed application desktop files established the canonical names that are actually shipped by the current XFCE applications:

```text
Terminal       Icon=org.xfce.terminal
Thunar         Icon=org.xfce.thunar
Ristretto      Icon=org.xfce.ristretto
Parole         Icon=org.xfce.parole
Xfburn         Icon=stock_xfburn
```

GTK3 icon lookup in the active XFCE session resolved all five names to real files under `/usr/share/icons/hicolor`, proving that the application icons and hicolor cache are healthy.

Use these canonical names in the BFSOS-owned launcher data instead of stale aliases such as:

```text
utilities-terminal
system-file-manager
ristretto
parole
media-optical
```

Do not treat this as a missing-icon-theme problem. The files and GTK lookup are present and working once the launcher profile is correct.

### Root cause 4 — BFSOS ships no usable XFCE first-login wallpaper assignment

A fresh XFCE user initially had only the desktop migration marker and no wallpaper assignment, producing a black desktop even though the normal XFCE wallpaper exists at:

```text
/usr/share/backgrounds/xfce/xfce-blue.jpg
```

The live VM was fixed by assigning that image to the actual detected monitor, which in the VM was `Virtual-1`:

```text
/backdrop/screen0/monitorVirtual-1/workspace0/last-image
    /usr/share/backgrounds/xfce/xfce-blue.jpg
```

The connector name is VM-specific and **must not** be hard-coded into the distro profile.

**Permanent BFSOS requirement:** provide an XFCE 4.20-compatible, monitor-independent first-login/default wallpaper policy that selects `/usr/share/backgrounds/xfce/xfce-blue.jpg` (or the final BFSOS-selected XFCE wallpaper) on the actual detected monitor. A new user must not receive a black desktop merely because no monitor-specific property existed beforehand.

### Do not regress the already proven Power Manager fix

Retain the r253 correction:

```text
plugin-6 = power-manager-plugin
```

Do not restore the stale profile identifier `xfce4powermanager`.

### Source/package work required on Prism

1. Identify the BFSOS port/package that owns or replaces:

```text
/etc/xdg/xfce4/panel/default.xml
/etc/xdg/xfce4/panel/launcher-11/
...
/etc/xdg/xfce4/panel/launcher-15/
```

2. Update the default panel geometry to the VM-proven layout:

```text
panel-1 p=6
panel-2 p=10
```

3. Ensure plugins 11-15 are retained on panel 2 and each `items` property is serialized as a one-element string array.

4. Package/import the five launcher files so a clean user receives them automatically.

5. Replace the launcher icon keys with the canonical current application icon names listed above.

6. Add a proper first-login/default XFCE wallpaper policy without hard-coding `Virtual-1` or any other connector name.

7. Preserve user customization on package upgrades. The new default is for fresh profiles; any migration of existing profiles must be narrow, versioned and opt-in/safely targeted rather than replacing the whole user panel configuration.

8. Bump the owning BFSOS port release because this changes packaged profile/content behavior.

### Regression coverage required

Add source/profile checks that verify at minimum:

- `/panels` contains `1` and `2`;
- panel 1 position is `p=6;x=0;y=0`;
- panel 2 position is `p=10;x=0;y=0`;
- panel 1 plugin IDs are 1-10;
- panel 2 plugin IDs are 11-15;
- plugin 6 is `power-manager-plugin`;
- plugins 11-15 are launcher plugins;
- each `/plugins/plugin-11..15/items` value is an **array**, not a scalar string;
- each array contains exactly the expected launcher filename;
- all five referenced launcher files are installed/importable for a new user;
- launcher `Exec=` targets exist in the XFCE meta dependency closure;
- launcher `Icon=` keys resolve using the installed icon themes;
- the XFCE default wallpaper file exists;
- the wallpaper policy does not encode a VM-only monitor connector name.

### Live verification required after the source fix

Create a genuinely fresh user account/profile and verify, without copying or editing files in the user's home directory:

1. First XFCE X11 login shows the full-width top panel and centered bottom dock.
2. The bottom dock contains Terminal, Thunar, Ristretto, Parole and Xfburn with their real icons, not generic blue gears.
3. `xfconf-query` reports plugins 11-15 `items` as one-element arrays.
4. The desktop uses the intended XFCE/BFSOS wallpaper instead of black.
5. The Power Manager plugin loads without a missing-plugin warning.
6. Logout/login preserves the exact layout, launcher icons and wallpaper.
7. A controlled panel restart inside the graphical session preserves the same launcher state.
8. Existing users with customized panels are not overwritten by a package update.

### VM result

**VM-proven:** the intended XFCE X11 two-panel layout, canonical launcher icons and wallpaper all work, and the launcher icons survive logout/login once the `items` properties are real arrays and the launcher files exist in the active user panel directory.

**Still OPEN in BFSOS source:** encode that exact state in the distro-owned first-login defaults/profile import path and add regression coverage so no manual per-user repair is required.

### Separate SDDM password observation

During this XFCE validation, SDDM temporarily rejected the existing `brian` password. `passwd -S` and `chage -l` showed the account was unlocked and non-expired; resetting the password with `passwd` restored SDDM authentication immediately. Do not attribute this event to XFCE panel/wallpaper configuration. Keep password-policy/install-time validation under the existing installer/password tracker work unless a separate reproducible SDDM/PAM defect is established.


## r269 live desktop validation summary

### Plasma Wayland runtime now works; permanent `/opt` graphical-session environment fix remains OPEN

Live BFSOS VM testing established that Plasma Wayland itself is functional once the systemd user manager receives the KF6/Qt6 environment **before** the Plasma user services start.

The failing state had `kwin_wayland_wrapper` running from its absolute `/opt/kf6/bin/kwin_wayland_wrapper` path while inheriting only the baseline system path:

```text
/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin
```

The wrapper therefore did not initially spawn the real `/opt/kf6/bin/kwin_wayland`, and `plasma-plasmashell.service` stalled/timed out downstream. The interactive shell already had `/opt/kf6/bin` and `/opt/kf6/share` through profile scripts, but that was not sufficient for the early systemd-user graphical startup path.

A clean-boot A/B test with systemd-user defaults providing the `/opt` paths produced the expected process tree on the first Plasma Wayland login:

```text
/opt/kf6/bin/kwin_wayland_wrapper --xwayland
/opt/kf6/bin/kwin_wayland ...
/usr/bin/Xwayland ...
/opt/kf6/bin/plasmashell --no-respawn
```

`plasma-kwin_wayland.service` and `plasma-plasmashell.service` both remained active, the active seat/session matched the compositor session, and the Plasma Wayland desktop rendered correctly. The earlier DRM/session-ID theories are **not** the current root cause and should not drive permanent changes.

**Runtime result:** Plasma X11 works and Plasma Wayland now works on the BFSOS VM.

### Firefox HTTPS runtime now works; permanent CA/p11-kit generation fix remains OPEN

Firefox launched successfully but initially rejected normal HTTPS sites such as YouTube. Network, DNS, system time, OpenSSL, and the PEM CA bundle were all proven healthy:

- `curl` reached YouTube successfully and returned HTTP 200;
- `openssl s_client` verified the Google certificate chain with `Verify return code: 0 (ok)`;
- `/etc/pki/tls/certs/ca-bundle.crt` contained 121 certificates.

The failure was isolated to the NSS/p11-kit trust path. BFSOS intentionally had:

```text
/usr/lib/libnssckbi.so -> ./pkcs11/p11-kit-trust.so
```

but:

```text
trust list --filter=ca-anchors
```

returned **zero** CA anchors. The p11-kit trust module was compiled to load anchors from:

```text
/etc/pki/anchors:/usr/share/pki/anchors
```

while the installed `ca-certificates` package contained only the generated PEM bundle/symlinks and no populated p11-kit anchor source. `make-ca -r` also failed because `/etc/ssl/certdata.txt` was absent.

Running the intended first-population path with `make-ca -g` downloaded the Mozilla certificate source, generated the required trust data, and Firefox HTTPS browsing then worked normally.

**Runtime result:** Firefox launches and can browse HTTPS sites successfully after proper `make-ca` trust population.

### GNOME desktop item — RESOLVED in r271

The blue-diamond/placeholder GNOME application-icon issue that was deferred in r269 was subsequently diagnosed and fixed in r271. The root cause was the maintained `librsvg` port building without its GdkPixbuf SVG loader. `librsvg 2.62.3-3` now enables `pixbuf` and `pixbuf-loader`; VM render, GTK lookup, logout/login, and visual checks all pass.

## r254 source-completion summary

### New r254 blocker discovered during live installer validation

- **OPEN — installer password minimum-length enforcement:** a nonblank password shorter than 8 characters currently causes `chpasswd`/PAM to print `BAD PASSWORD: The password is shorter than 8 characters`, but the installer can still continue because it trusts the command exit status. The installer must perform its own minimum-length validation and reprompt before attempting to set the password.

## r253 source-completion summary

This revision records the source-tree work completed against BFSOS commit `5d59e9a0`. The r252 project archive itself was clean at that commit, so the previously described uncommitted working-tree changes were reconstructed and audited rather than assumed to be present.

### Completed and regression-tested in source

- Installer r73: final `/` ownership/mode postflight (`root:root 0755`) and serial/LUKS console ordering.
- Base NSS: `nss-systemd` user/group/shadow integration with merged group handling.
- XFCE: corrected Power Manager plugin ID, BFSOS second/bottom launcher panel, and RC1 suppression of the experimental Wayland session when BFSOS does not ship its required compositor path.
- GNOME dependency closure: Highlight is CLI-only so Evolution/`gnome-meta` no longer pulls Qt5 through Highlight.
- `prt-get`: `--no-new-deps` retained and the BFSOS `sysup` wrapper updates `pkgutils` only when `quickdiff` reports it stale.
- Kernel/GRUB: two-phase pending/known-good cleanup retained; duplicate `/boot/vmlinuz-lts` discovery is suppressed during GRUB generation without deleting the public alias.
- GTK4/Meson: ordinary package builds do not run the full upstream test suite; explicit `PKGMK_RUN_TESTS=yes` now runs Meson tests for maintainer/CI validation.
- Upstream checker: v9 includes `contrib`, adds ESR/LTS channel protection, and retains read-only verified-update behavior.
- `contrib`: refreshed Alacritty, AsciiDoc, GCC Fortran, librsvg, Steam/Steam native metadata and Wine Staging; retained current/legacy indicator and OpenBLAS/cargo-c lines where appropriate.
- `compat-32`: all 170 ports now carry `.32bit`, all use `pkg_build()`, 151 native-paired ports are version-synchronized, and 19 compatibility-only ports are explicitly classified. Central pkgutils owns the ordinary i686 ELF32 flags, host triplet, `/usr/lib32`, and 32-bit pkg-config policy.
- Added `scripts/bfs-sync-compat32.py`, replaced the obsolete `multilibvercheck.sh`, and added compat/GTK4 regressions.

### Source test result

`./scripts/bfs-r243-source-tests.sh` passes in full, including static/release audits, kernel-maintenance regression, `prt-get` regression, installer build-work sizing, checker v9 regression, GTK4 policy regression, and the 170-port compat synchronization regression.

### Still requires live BFSOS validation before merge/RC sign-off

Source-level regression tests cannot substitute for real package builds and boots. A BFSOS VM should still run the full online maintained/contrib version audit, representative native + compat-32 builds (Autotools/CMake/Meson/custom), Steam/Wine runtime checks, GNOME/GDM login, XFCE login, Plasma Login Manager selection/login, consecutive `prt-get sysup` runs, and real regular/LTS kernel update + reboot/rollback tests.


---

## OPEN / INSTALLER BLOCKER — Reject nonblank passwords shorter than 8 characters and reprompt

### Live failure observed — 2026-09-07

During the fresh Gentoo Live bootstrap/installer validation, the installer accepted a password that did not meet the intended minimum length. The console displayed:

```text
BAD PASSWORD: The password is shorter than 8 characters
```

but installation continued into the next phase instead of forcing the user to choose another password.

The current r73 `prompt_optional_password()` logic retries only when `chpasswd` returns a non-zero status. That is insufficient: the installed password-policy stack can emit a `BAD PASSWORD` warning while `chpasswd` still returns success for the privileged installer path. Therefore the installer must not use the backend exit status as the only minimum-length gate.

### Required behavior

- For every interactive/login-capable account created or configured by the installer, including:
  - the primary standard user;
  - additional standard users;
  - `service-login` users;
  - `root`;
  reject any **nonblank** password shorter than **8 characters**.
- Perform the 8-character minimum check **inside the installer before calling `chpasswd`**.
- If the entered password contains 1–7 characters:
  - display a clear message such as `Password must be at least 8 characters.`;
  - discard both password variables;
  - return to the password-entry prompt;
  - do not proceed with account configuration or later installation phases.
- Preserve the existing intentional blank-password behavior: a blank entry means **leave password login locked**; it must never create an empty-password login.
- Continue to require password confirmation for accepted nonblank candidates.
- Continue to pass an 8+-character candidate through the normal PAM/libpwquality/`chpasswd` policy afterward so stronger policy checks can still reject weak passwords.
- Never print, log, save, or expose the entered password in installer logs, shell tracing, state files, or error messages.
- Apply the rule consistently to dialog and non-dialog/TTY input paths.

### Recommended implementation shape

Inside `prompt_optional_password()`, after the existing blank-password check and before confirmation/`chpasswd`, enforce the installer-owned floor directly, for example conceptually:

```bash
if (( ${#password_one} < 8 )); then
        # show error and reprompt
        unset password_one password_two
        continue
fi
```

Do not rely on parsing the text `BAD PASSWORD`, because PAM/Shadow wording can change. The installer must own the explicit BFSOS minimum-length rule.

### Regression coverage required

Add an installer/source regression that verifies at minimum:

1. blank password -> account remains locked and is allowed;
2. 1-character password -> rejected and reprompted;
3. 7-character password -> rejected and reprompted;
4. exactly 8-character password -> reaches backend policy/confirmation path;
5. longer password -> reaches backend policy/confirmation path;
6. mismatch on confirmation -> reprompted;
7. backend/PAM rejection of an 8+-character password -> reprompted;
8. root and every login-capable user path use the same validation function;
9. no password value appears in installer logs or persisted state.

### RC relationship

Treat this as a **pre-RC installer blocker**. A warning that is visibly labeled `BAD PASSWORD` must never be followed by an apparently successful account setup. Re-run the fresh RAID10 + LUKS + normal/LTS-kernel installer test after this fix is merged.

## IMPLEMENTED / LIVE BOOT VERIFY — Kernel Update Cleanup / Stale Initramfs Handling

### Problem
Kernel package updates can leave obsolete kernel-specific initramfs images and other stale boot artifacts behind, for example:

```text
/boot/initramfs-7.2.0-BFS-Linux.img
```

Depending on how GRUB scans `/boot` and generates menu entries, stale kernel/initramfs combinations can result in invalid boot entries, boot delays, or potentially a system hang during boot selection or startup.

### Required Changes
- After a **successful kernel package update**, detect obsolete per-kernel boot artifacts that no longer correspond to an installed kernel.
- Remove stale kernel-specific initramfs images and related obsolete boot files only when it is safe to do so.
- Regenerate initramfs/bootloader state only after the new kernel has installed successfully.
- Regenerate the GRUB configuration after cleanup so stale kernel/initramfs combinations are not referenced.
- Ensure kernel package scripts and bootloader update logic fail safely if cleanup or GRUB regeneration fails.

### Rollback / Safety Requirements
- Never remove the **currently booted kernel**.
- Preserve the **immediately previous known-good kernel** until the newly installed kernel has been verified bootable.
- Do not remove a kernel or initramfs merely because it is older; verify that it is no longer required for rollback.
- Do not regenerate GRUB into a partially updated state if the new kernel or initramfs generation failed.
- Avoid producing GRUB menu entries that reference a missing kernel, missing initramfs, or mismatched kernel/initramfs pair.

### Verification
- Update from one BFSOS kernel release to the next and confirm the new kernel and initramfs are generated correctly.
- Confirm the current and previous known-good kernels remain bootable before cleanup.
- Confirm obsolete initramfs images are removed only after the new kernel is verified.
- Regenerate GRUB and verify there are no stale or broken menu entries.
- Reboot and test both the new kernel and rollback entry.
- Verify repeated kernel updates do not accumulate stale `/boot/initramfs-*-BFS-Linux.img` files.

### Historical r252 status
**Superseded by the r253 status below.**

---

### r253 status
r253: kernel-maintenance source/regression covers pending, known-good, obsolete cleanup, atomic GRUB regeneration and retained rollback kernels. Real reboot/rollback remains a live-system check.

## IMPLEMENTED / LARGE-BUILD VERIFY — Installer Build-Work tmpfs Sizing

### Problem
The installer's automatic `/var/cache/pkg/build-work` tmpfs sizing is too conservative for large modern packages.

A system with approximately:

```text
61 GiB physical RAM
122 GiB swap
```

currently receives:

```text
tmpfs  16G  /var/cache/pkg/build-work
```

A 16 GiB build workspace can be too small for large packages such as QtWebEngine, Firefox ESR, LLVM, and kernel builds. It can also increase memory pressure when large builds are performed entirely in tmpfs.

### Proposed Automatic Sizing

```text
Physical RAM        /var/cache/pkg/build-work
------------------------------------------------
< 16 GiB            disk-backed
16–31 GiB           8G tmpfs
32–47 GiB           16G tmpfs
48–95 GiB           32G tmpfs
96–191 GiB          64G tmpfs
>= 192 GiB          96G tmpfs
```

For a machine with about 61 GiB of physical RAM, `Auto` should therefore select:

```text
tmpfs size=32G /var/cache/pkg/build-work
```

### Installer Changes
Provide three build-work choices:

```text
Auto (recommended)
Disk-backed
Custom tmpfs size
```

### Sizing Rules
- Base automatic sizing on **physical RAM only**.
- Do **not** calculate tmpfs size from RAM + swap.
- Treat swap as an OOM safety net, not as build-work capacity.
- Do not reserve the configured tmpfs maximum up front; normal tmpfs on-demand allocation behavior should be retained.
- Ensure the mountpoint is created with appropriate ownership and permissions before package builds begin.
- Preserve the ability to use a disk-backed build directory on low-memory systems or when the user explicitly selects it.

### Runtime / Administration
- Allow an administrator to resize an existing build-work tmpfs with a remount, where supported, without destroying current build data.
- Document a command equivalent to:

```bash
mount -o remount,size=32G /var/cache/pkg/build-work
```

for temporary/manual resizing.
- Do not automatically unmount or resize an actively used build workspace in a way that interrupts an in-progress package build.

### Verification
- Verify Auto selects 32G on a system reporting roughly 61 GiB physical RAM.
- Verify systems below 16 GiB default to disk-backed build-work.
- Verify each RAM bracket selects the expected tmpfs ceiling.
- Test large builds including:
  - Linux kernel
  - Firefox ESR
  - QtWebEngine5
  - LLVM/Clang
- Confirm builds do not fail because the tmpfs ceiling is unnecessarily small.
- Confirm large tmpfs usage does not cause avoidable system OOM failures.
- Verify custom and disk-backed installer choices override Auto correctly.
- Verify swap size does not alter automatic tmpfs sizing.
- Verify remount-based resizing preserves existing build-work contents.

### Historical r252 status
**Superseded by the r253 status below.**

---

### r253 status
r253: automatic sizing regression passes. Large Firefox/QtWebEngine/LLVM/kernel builds remain live capacity validation.

## IMPLEMENTED — prt-get Option to Disable Automatic New-Dependency Installation

### Problem
BFSOS `prt-get update` / `sysup` dependency-refresh logic can automatically discover and install dependencies that were newly added to an already-installed package. This is useful for normal system updates, but it can be undesirable during carefully ordered bootstrap transactions.

A concrete bootstrap case is the GLib / gobject-introspection / Polkit cycle: a Stage 3 update of another package can trigger dependency refresh, introduce `gobject-introspection` and `polkit`, and attempt to build Polkit before GLib has been rebuilt with introspection support. In cases like this, the bootstrap needs to control package ordering explicitly rather than allowing `prt-get` to inject newly discovered dependencies automatically.

### Required Change
Add an explicit command-line switch to `prt-get` that disables **automatic installation of newly discovered dependencies during update operations**.

Proposed long option:

```text
--no-new-deps
```

A short option may be added if there is an unused, unambiguous flag; do not reuse or overload an existing option.

### Required Semantics
With the option **not** supplied, preserve the current default behavior:

```text
prt-get update / sysup
    -> refresh dependency closure
    -> install newly required dependencies
    -> update requested package(s)
```

With `--no-new-deps` supplied:

```text
prt-get update --no-new-deps <package>
prt-get sysup --no-new-deps
```

`prt-get` must:

- Skip the BFSOS automatic "newly required packages" installation step for the affected update transaction.
- Continue updating the explicitly requested package(s) using the existing update path.
- Clearly report any newly required dependencies that were detected but intentionally not installed.
- Never report skipped dependencies as installed or satisfied when they are not present.
- Preserve a non-ambiguous log message showing that automatic new-dependency installation was disabled deliberately.
- Leave explicit dependency-install commands such as `prt-get depinst` unchanged; `depinst` is an explicit request to install dependencies and should continue to do so.
- Do not change the default behavior of normal `prt-get update` or `prt-get sysup` when the option is absent.

### CLI Documentation / Discoverability
- Update `prt-get --help` so `--no-new-deps` is listed with a concise description of its effect.
- Update any command-specific help output for `update` and `sysup` if those subcommands/options have separate help text.
- Update all applicable `prt-get` man pages so the new option, default behavior, warning behavior, and scope are documented.
- If the project ships additional usage/reference documentation for `prt-get`, update that documentation in the same change so CLI help and packaged docs cannot drift.
- Clearly document that the switch affects only automatic installation of newly required dependencies during update/sysup transactions; it does not disable dependency resolution for explicit commands such as `depinst`.
- Include at least one documented example for both package update and system update use:

```text
prt-get update --no-new-deps <package>
prt-get sysup --no-new-deps
```

- Keep terminology consistent between `--help`, man pages, runtime warnings, and transaction logs.

### Bootstrap Use
Allow bootstrap stages to opt out selectively when dependency ordering must be managed explicitly.

For example, Stage 3 may use the equivalent of:

```bash
prt-get update --no-new-deps -fr -fi systemd
```

when the bootstrap has already established its own required order for special dependency cycles.

The bootstrap should then explicitly perform any required sequence, for example:

```text
gobject-introspection available
    -> rebuild glib
    -> verify GLib/GObject/Gio GIR files
    -> allow polkit
    -> continue later package updates
```

This switch is intended as a targeted ordering/control mechanism, not as the normal update mode.

### Safety / UX Requirements
- Default remains automatic dependency refresh/install so ordinary users receive newly required dependencies without manual intervention.
- The opt-out must be explicit on each command invocation unless a future separately designed configuration option is added.
- Print a visible warning such as:

```text
WARNING: automatic installation of newly required dependencies is disabled for this transaction.
```

- If a package build/update subsequently fails because a skipped dependency is genuinely required, preserve the real package failure and identify the skipped dependency list in the transaction log.
- Do not silently weaken dependency handling globally merely because bootstrap uses the option in one special transaction.

### Verification
- Add a newly required dependency to an already-installed test package and confirm normal `prt-get update` installs it automatically.
- Repeat with `--no-new-deps` and confirm the newly required dependency is detected/reported but not installed automatically.
- Confirm the explicitly requested package update is still attempted when the opt-out is active.
- Confirm `prt-get sysup --no-new-deps` applies the same policy consistently across a system update.
- Confirm `prt-get depinst` behavior is unchanged.
- Confirm logs clearly distinguish normal dependency refresh from an intentional no-new-dependencies transaction.
- Test the Stage 3 GLib / gobject-introspection / Polkit ordering case and confirm bootstrap can prevent an early Polkit build while still completing the explicitly managed dependency sequence.
- Confirm normal user-facing `sysup` continues installing newly required dependencies by default.
- Confirm `prt-get --help` documents `--no-new-deps`.
- Confirm applicable man pages document the option and match the implemented semantics.
- Confirm any command-specific help for `update` / `sysup` also exposes the option where appropriate.
- Confirm examples and warning terminology are consistent across CLI help, man pages, and runtime output.

### Historical r252 status
**Superseded by the r253 status below.**

### r253 status
r253: `--no-new-deps` source regression passes for update/sysup behavior.

## IMPLEMENTED / LIVE LTS VERIFY — LTS kernel install/update cleanup and selected-kernel consistency

The LTS-kernel install path still needs the same cleanup and consistency work as the normal kernel path. A current LTS test install leaves both generic and LTS-named kernel/source entries visible, so the installer/update logic must explicitly validate and manage the selected LTS kernel rather than assuming the normal-kernel naming/layout.

Current observed LTS layout includes entries such as:

```text
/boot/config-6.18.49-BFS-LTS
/boot/initramfs-6.18.49-BFS-LTS.img
/boot/System.map-6.18.49-BFS-LTS
/boot/vmlinuz-6.18.49-BFS-LTS
/boot/vmlinuz-lts

/usr/src/linux
/usr/src/linux-6.18.49-BFS-LTS
/usr/src/linux-lts
```

Required work:
- Audit the installer, kernel Pkgfiles, post-install hooks, initramfs generation, and GRUB generation for the LTS-kernel path.
- When the user selects the LTS kernel, keep the selected-kernel aliases and symlinks internally consistent with the LTS tree.
- Verify the exact targets of `/boot/vmlinuz-lts`, `/usr/src/linux-lts`, and `/usr/src/linux`; do not leave a generic alias pointing at the wrong kernel family.
- Ensure cleanup/update logic recognizes `*-BFS-LTS` versioned artifacts and removes obsolete LTS kernel/initramfs/System.map/config files using the same safety policy as the normal kernel.
- Preserve the currently booted LTS kernel and the immediately previous known-good LTS kernel until the replacement has been verified.
- Do not accidentally install, select, or make GRUB prefer the regular kernel when the installation was configured for LTS.
- Regenerate GRUB after an LTS kernel update and verify the default entry corresponds to the selected LTS kernel.
- Verify that repeated LTS kernel upgrades do not accumulate stale `/boot` artifacts or stale `/usr/src/linux-*` trees/symlinks.
- Test both fresh installation and `sysup`/kernel-update paths with the LTS kernel selected.

Verification:
- Fresh LTS install boots the LTS kernel.
- `uname -r` reports the intended `*-BFS-LTS` kernel.
- `/boot` contains only the expected current/retained LTS artifacts and correctly targeted aliases.
- `/usr/src/linux`, `/usr/src/linux-lts`, and the versioned LTS source tree resolve consistently.
- GRUB/default boot selection remains LTS across updates.
- A subsequent LTS update cleans obsolete LTS artifacts without deleting the running or previous known-good kernel.

### r253 status
r253: LTS maintenance regression passes; real LTS sysup/reboot remains required.

## IMPLEMENTED — Fix invalid `/etc/sudoers.d` environment-preservation syntax

Fresh/current BFSOS installations can emit invalid `sudoers` snippets for build-environment variables. The problem is visible on ordinary `sudo` commands such as `sudo ports -u`, which currently reports parser errors similar to:

```text
/etc/sudoers.d/kf6:1:33: syntax error
Defaults env_keep += KF6_PREFIX QT6DIR QT5DIR CMAKE_PREFIX_PATH PKG_CONFIG_PATH
                                ^~~~~

/etc/sudoers.d/xorg:1:34: syntax error
Defaults env_keep += XORG_PREFIX XORG_CONFIG
```

The intended variables still need to be preserved across `sudo`, but the generated `Defaults env_keep` syntax must be valid `sudoers` syntax.

### Required work

- Audit the installer/bootstrap/package logic that creates `/etc/sudoers.d/kf6`, `/etc/sudoers.d/xorg`, and any similar BFSOS-generated `sudoers` snippets.
- Generate valid `env_keep` syntax. For example, use a quoted whitespace-separated list:

```text
Defaults env_keep += "KF6_PREFIX QT6DIR QT5DIR CMAKE_PREFIX_PATH PKG_CONFIG_PATH"
Defaults env_keep += "XORG_PREFIX XORG_CONFIG"
```

  or another form accepted by the installed `sudo` version.
- Do not remove the variables merely to silence the parser error; the purpose of these files is to preserve required build-environment variables for package builds run through `sudo`, `prt-get`, and `pkgmk`.
- Search all generated `/etc/sudoers.d/*` files for the same unquoted multi-variable pattern so the fix is not limited to only KF6 and X.Org.
- Ensure generated files have appropriate ownership and permissions for `sudoers` include files.
- Avoid writing partially valid files during installer/bootstrap execution; generate to a temporary file and validate before installing it when practical.
- Any change to the environment-preservation variable set should remain coordinated with the BFSOS package-build environment policy.

### Validation

Validate the individual files and the complete configuration:

```bash
visudo -cf /etc/sudoers.d/kf6
visudo -cf /etc/sudoers.d/xorg
visudo -c
```

Then confirm normal commands no longer print parser errors:

```bash
sudo true
sudo ports -u
```

Verify the intended variables survive `sudo` where required, for example:

```bash
sudo env | grep -E '^(KF6_PREFIX|QT6DIR|QT5DIR|CMAKE_PREFIX_PATH|PKG_CONFIG_PATH|XORG_PREFIX|XORG_CONFIG)='
```

Also verify package builds that depend on the KF6/Qt6/X.Org build environment still locate the correct prefixes after the syntax correction.

### 2026-09-05 live retest

The defect is **still reproducible** in the current BFSOS VM after the r244 ports refresh and during ordinary package update commands such as `sudo ports -u` and `sudo prt-get update ...`.

Observed parser errors remain:

```text
/etc/sudoers.d/kf6:1:33: syntax error
Defaults env_keep += KF6_PREFIX QT6DIR QT5DIR CMAKE_PREFIX_PATH PKG_CONFIG_PATH

/etc/sudoers.d/xorg:1:34: syntax error
Defaults env_keep += XORG_PREFIX XORG_CONFIG
```

This confirms that the previously tracked fix has **not yet reached the generated/runtime sudoers files**. Keep this issue OPEN until the source that creates these files is corrected, the files are regenerated/updated on an existing installation, and `visudo -c`, `sudo true`, `sudo ports -u`, and representative `prt-get` builds run without parser warnings.

### Historical r252 status
**Superseded by the r253 status below.**


### r253 status
r253: source snippets were already corrected; `aaa_filesystem` release was bumped so installed systems receive the fixed files.

## SOURCE FIXED / LIVE SYSUP VERIFY — r244 sysup / maintained-port update validation

### Context

After pushing the r244 maintained-port updates and version-checker work, a live BFSOS VM `prt-get sysup` exposed a small set of package-update regressions. These are being repaired one at a time in the source tree and retested through the VM.

Initial failed update set:

```text
lua
perl-xml-parser
python3-typogrify
iniparser
libcdio-paranoia
appstream
mesa
imagemagick
xf86-video-amdgpu
```

### Progress

- **lua 5.4.9** — fixed. The new upstream docs no longer include the GIF matched by `doc/*.{html,css,gif,png}`; the port was corrected to stop requiring the missing GIF.
- **perl-xml-parser 2.59** — fixed. XML-Parser 2.59 requires `File::ShareDir::Install` during `Makefile.PL`; BFSOS added a `perl-file-sharedir-install` port/dependency and the update subsequently worked.
- **python3-typogrify 2.1.0** — pyproject/Hatchling packaging fix applied during this validation cycle; continue live verification as needed.
- **iniparser 4.2.6** — **NEXT PACKAGE TO TRIAGE**.
- Remaining after that: `libcdio-paranoia`, `appstream`, `mesa`, `imagemagick`, `xf86-video-amdgpu`.

### Validation policy

For each failed package:

1. Reproduce with `prt-get update <package>` in the BFSOS VM.
2. Identify the first real source/build/install error rather than relying only on the final `prt-get` summary.
3. Apply the permanent fix in the PrismLinux `~/BFSOS` source tree.
4. Commit/push the repair.
5. Run `ports -u` in the VM.
6. Retest the single package before moving to the next failure.
7. After all individual failures are resolved, run a final `prt-get diff` / `prt-get sysup` validation pass.

### Historical r252 status
**Superseded by the r253 status below.**

---

### r253 status
r253: known source regressions addressed; perform a clean live `prt-get diff`/`sysup` cycle before merge.

## COMPLETED — PipeWire / WirePlumber desktop audio stack

### Result

The intended BFSOS desktop audio stack is now proven functional:

```text
PipeWire
WirePlumber
PipeWire PulseAudio compatibility service
```

During the GNOME 50 runtime smoke test, audio worked normally after login and applications were able to produce sound. This confirms the installed PipeWire/WirePlumber stack is functional in the current desktop image and that the GNOME session is receiving a usable audio service without a manual recovery step.

The earlier LXQt test had required manual user-service activation, so that behavior was tracked as a possible default/session activation defect. The later GNOME 50 test demonstrates that the current package/session configuration now starts a working sound stack automatically.

### Closure criteria confirmed

- PipeWire/WirePlumber packages are installed and usable.
- Desktop applications can produce sound.
- GNOME 50 receives working audio after normal login.
- The PulseAudio-compatible application path is functional through the PipeWire stack.
- No manual audio-service recovery was required for the successful GNOME runtime test.

### Future regression check

If a future Plasma, XFCE, LXQt, or other desktop test again requires manual PipeWire/WirePlumber activation, reopen this as a desktop-session integration regression rather than assuming the core audio stack itself is broken.

### Status

**COMPLETED — working sound stack confirmed during the GNOME 50 runtime test on 2026-09-07.**

## IMPLEMENTED / LIVE RUNTIME VERIFY — KDE Plasma Login Manager optional greeter/display manager

### Context

KDE introduced **Plasma Login Manager** (`plasma-login-manager`) as a new Plasma module beginning with the Plasma 6.6 generation. It is KDE's newer Plasma-integrated login manager/greeter and is being actively developed alongside current Plasma releases.

BFSOS currently uses SDDM for Plasma and other desktop sessions. Do **not** remove SDDM globally. Add Plasma Login Manager as an **optional Plasma-specific display-manager choice** so it can be tested and offered without disrupting LXQt, XFCE, GNOME, or other desktop environments.

### Required work

- Add/maintain a BFSOS port for `plasma-login-manager`, following the current stable Plasma release used by the coordinated KDE stack rather than hard-coding an old version.
- Audit all build dependencies, runtime dependencies, Qt6/KF6 `/opt` prefix assumptions, KWin/Wayland integration, PAM requirements, systemd units, session discovery, and configuration paths.
- Add Plasma Login Manager to the Plasma installation workflow as an **optional greeter/display-manager choice**.
- Keep SDDM available and supported; do not make Plasma Login Manager mandatory until it has passed repeated clean-install and runtime testing.
- Ensure the installer/post-install workflow can select exactly one active display manager and does not leave both SDDM and Plasma Login Manager enabled simultaneously.
- When switching display managers, correctly update `display-manager.service` and disable the previously selected manager without deleting its package.
- Ensure the choice survives reboot and package updates.
- Verify Plasma Login Manager discovers all appropriate installed sessions, including Plasma Wayland and non-Plasma sessions where supported.
- Verify that choosing Plasma Login Manager for Plasma does not break the ability to return to SDDM later.
- Integrate any Plasma Login Manager settings/KCM supplied by upstream so users can configure the greeter through Plasma System Settings where supported.
- Audit wallpaper/theme/settings synchronization behavior rather than assuming SDDM theme configuration applies to Plasma Login Manager.
- Document the difference between the login manager/greeter and Plasma's per-user lock screen so the two are not conflated in installer/UI wording.
- Include the package in the coordinated KDE modernization audit so future Plasma upgrades update Plasma Login Manager together with the rest of the Plasma stack.

### Installer/UI behavior

For a Plasma desktop installation, provide a display-manager choice similar to:

```text
Plasma login manager:

  [ ] SDDM
  [ ] Plasma Login Manager
```

Use the existing BFSOS installer conventions for single-choice selection. Until Plasma Login Manager has completed clean-install validation, SDDM should remain the conservative/default choice.

Do not present this Plasma-specific choice as a requirement for LXQt, XFCE, or GNOME.

### Validation

On a clean BFSOS Plasma installation:

```bash
systemctl status display-manager --no-pager
systemctl is-enabled sddm.service 2>/dev/null || true
systemctl is-enabled plasma-login-manager.service 2>/dev/null || true
```

Use the actual upstream-installed Plasma Login Manager unit name if it differs; do not hard-code a guessed service name in installer logic.

Verify:

- the selected login manager starts on boot;
- only one display manager owns the graphical login at a time;
- Plasma Wayland can log in successfully;
- installed non-Plasma sessions remain discoverable where upstream supports them;
- user selection, keyboard layout, HiDPI/multi-monitor behavior, power controls, and authentication behave correctly;
- logout returns cleanly to the greeter;
- reboot returns to the selected greeter;
- switching back to SDDM works cleanly;
- package updates do not silently change the selected display manager;
- the Plasma Login Manager KCM/settings page works when installed;
- no stale SDDM-specific assumptions are used for Plasma Login Manager configuration.

### Historical r252 status
**Superseded by the r253 status below.**

---

### r253 status
r253: BFSOS already contains `plasma-login-manager` plus the single-active-display-manager switch mechanism. Treat as implemented but not release-default until live login/session validation passes.

## 2026-09-06 — Linux 6.18 LTS MD metadata compatibility / encrypted RAID boot findings

### CONFIRMED — Linux 6.18.49-BFS-LTS targeted MD compatibility backport works

A fresh/current BFSOS LTS installation using Linux `6.18.49-BFS-LTS` could not import the six-member MD RAID10 array that had been created under a newer live/install kernel. The affected array uses MD metadata 1.2 and hosts the encrypted LUKS container used for the `bfs-raid` LVM volume group containing `/home` and `/var`.

The unmodified 6.18 MD code rejected the members with messages such as:

```text
Some padding is non-zero on vdd1, might be a new feature
md: vdd1 does not have a valid v1.2 superblock, not importing!
md: md_import_device returned -22
```

The compatibility diagnosis was confirmed: newer MD metadata can store feature data in bytes that Linux 6.18 still treats as reserved padding. BFSOS `linux-lts` release 8 contains the targeted `check_new_feature` compatibility backport and no Debian kernel patch series.

Manual boot testing with:

```text
md_mod.check_new_feature=0
```

produced the expected warning that new-feature checking was disabled and allowed the exact RAID10 to assemble successfully.

Confirmed runtime result on BFSOS:

```text
Kernel: 6.18.49-BFS-LTS
MD compatibility value: N
linux-lts package: 6.18.49-8

md0 : active raid10 ... [6/6] [UUUUUU]
```

The encrypted storage stack then completed successfully:

```text
MD RAID10
  -> LUKS
  -> LVM bfs-raid
  -> Btrfs /home
  -> Btrfs /var
```

Both `/home` and `/var` were verified mounted from the RAID-backed LVM volumes. The successful boot was automatically promoted by `bfs-kernel-maintenance` to:

```text
known-good: 6.18.49-BFS-LTS
```

The earlier failed test marker remains preserved as:

```text
pending.failed-md-compat-r5: 6.18.49-BFS-LTS
```

### OPEN — make the MD compatibility workaround conditional and kernel-specific

The current successful VM test temporarily places:

```text
md_mod.check_new_feature=0
```

in the generated GRUB command line. This is sufficient for the test VM, but it must **not** become an unconditional global BFSOS kernel argument.

Required permanent design:

- Apply the workaround only to affected Linux 6.18 LTS boot entries that actually require it.
- Do not add it to normal/current mainline BFSOS kernels that do not need the compatibility bypass.
- Keep the upstream/default strict behavior whenever compatibility has not been positively identified.
- Teach `bfs-kernel-maintenance regenerate-grub` to preserve the same conditional behavior so a later kernel update or GRUB regeneration cannot silently remove the required argument or apply it globally.
- Record why the workaround is enabled and which required MD UUID(s) triggered it, rather than relying on an unexplained command-line flag.
- Automatically stop applying the workaround once the selected LTS kernel moves to a series that understands the newer metadata natively.
- Never enable the bypass simply because an installation uses RAID or because the selected kernel is LTS.

Safety detection should distinguish the confirmed forward-compatibility case from a genuinely incompatible array. Before enabling the bypass automatically, compare the affected MD v1.x metadata/logical-block-size state with the current member devices and require a safe/consistent match. If the metadata indicates a genuinely unsupported or mixed feature state, block/warn instead of automatically disabling the kernel safety check.

Installer work should also minimize the problem at creation time: when the installer runs under a newer live kernel but targets an older supported BFSOS kernel, create MD arrays using metadata/feature choices that remain bootable by the selected target kernel whenever possible.

### Status

**KERNEL BACKPORT CONFIRMED WORKING — permanent conditional installer/GRUB policy remains OPEN.**

---

## 2026-09-06 — Serial console + LUKS interactive prompt ordering

### CONFIRMED root cause

The generated GRUB default command line used:

```text
console=tty0 console=ttyS0,115200n8
```

With `ttyS0` last, normal boot logging appeared to work, but encrypted boots that required an interactive Dracut/systemd LUKS password prompt could leave the graphical VM console unable to enter the password. The problem was therefore only obvious on systems with LUKS volumes that must be opened during early boot.

The order was manually changed to:

```text
console=ttyS0,115200n8 console=tty0
```

This was then regenerated into GRUB and tested with **no manual GRUB editing**.

Confirmed behavior:

- the graphical console accepted the LUKS passphrase normally;
- the RAID/LUKS/LVM boot completed successfully;
- the system reached the installed BFSOS userspace;
- the QEMU/libvirt serial console still worked from the Threadripper host using `virsh console`;
- serial boot/output capability was therefore preserved while `tty0` remained the local interactive console.

### Required permanent change

- Change installer-generated/default GRUB console ordering to:

```text
console=ttyS0,115200n8 console=tty0
```

when both serial and graphical consoles are enabled.
- Apply the same ordering anywhere BFSOS rewrites or regenerates the managed console arguments.
- Preserve serial diagnostics; do not solve the bug by simply removing serial-console support.
- Test encrypted and unencrypted installs, because unencrypted systems can hide this regression by never requiring interactive initramfs input.
- Test graphical LUKS entry and `virsh console` access during the same boot.

### Status

**RUNTIME FIX CONFIRMED — source/installer policy update remains OPEN.**

---

## IMPLEMENTED — 2026-09-06 Duplicate GRUB entries from LTS kernel alias

### Problem

Current GRUB generation discovers both the versioned LTS kernel and the convenience alias:

```text
/boot/vmlinuz-6.18.49-BFS-LTS
/boot/vmlinuz-lts
```

The generated `/boot/grub/grub.cfg` therefore contains duplicate LTS boot/recovery entries for the same underlying kernel.

The `/boot/vmlinuz-lts` alias itself is part of the selected-kernel policy and does not need to be removed merely to silence GRUB. The problem is that GRUB discovery treats the alias as another independent kernel image.

### Required changes

- Keep the selected-kernel alias policy intact unless a broader kernel-layout redesign deliberately changes it.
- Prevent `grub-mkconfig`/BFSOS GRUB generation from emitting duplicate menu entries for aliases that resolve to an already-discovered versioned kernel.
- Prefer the fully versioned kernel artifact for generated menu entries.
- Ensure normal and recovery entries each appear only once per retained real kernel version.
- Preserve the selected/default LTS behavior through kernel updates.
- Coordinate this with the existing kernel cleanup/rollback tracker item so retained previous-known-good kernels still receive valid menu entries.
- Verify the duplicate suppression works for both `linux` and `linux-lts` flavors and does not suppress a genuinely distinct retained rollback kernel.

### Validation

After GRUB regeneration:

```bash
grep -nE '^[[:space:]]*linux[[:space:]]' /boot/grub/grub.cfg
```

should show one normal and one recovery entry per real retained kernel version, not a second pair generated from `/boot/vmlinuz-lts` or another convenience alias.

### Historical r252 status
**Superseded by the r253 status below.**

---

### r253 status
r253: kernel maintenance temporarily hides only the `/boot/vmlinuz-lts` symlink during `grub-mkconfig`, restores it immediately, and passes regression coverage.

## IMPLEMENTED / GNOME REBUILD VERIFY — Audit unexpected Qt5 dependency in GNOME meta dependency closure

### Context

During the current clean `gnome-meta` dependency/build sweep, `prt-get depinst gnome-meta` unexpectedly pulled **Qt5** into the transaction. GNOME itself is GTK-based, so a Qt5 dependency appearing in the GNOME meta closure is worth tracing rather than accepting silently.

This does **not** prove that Qt5 is wrong or obsolete in BFSOS. A non-GNOME utility, optional integration package, multimedia component, compatibility tool, or shared desktop dependency may legitimately require Qt5. The problem is that the current dependency path is not yet known.

### Required work

- Trace the complete dependency chain from `gnome-meta` to the package that first requires Qt5.
- Distinguish a legitimate shared/optional application dependency from a stale or accidental GNOME dependency.
- Audit all direct dependencies in `gnome-meta`, `gnome-apps-meta`, and their transitive closure for unnecessary Qt5-era packages.
- Check whether the package pulling Qt5 has a current Qt6 replacement, a build option that can disable an unused Qt feature, or an obsolete dependency declaration.
- Do **not** remove Qt5 globally merely because it appeared during a GNOME install; other BFSOS desktops or applications may still legitimately depend on it.
- If Qt5 is genuinely required by a package included in the default GNOME set, document the reason so future dependency audits do not repeatedly treat it as unexplained drift.
- If the dependency is accidental or obsolete, correct the responsible `Pkgfile`/meta-package dependency and bump the affected package release as appropriate.
- Re-run the GNOME dependency closure after the correction and confirm Qt5 is no longer pulled unless a documented package genuinely requires it.

### Suggested investigation

After the current GNOME build sweep is complete, use `prt-get` dependency/dependent reporting and repository searches to identify the first package in the `gnome-meta` closure that depends on Qt5. Also search the port tree for direct Qt5 dependency declarations, for example:

```bash
grep -RInE '^# Depends on:.*(^|[[:space:]])qt5([[:space:]]|$)' ports/*/*/Pkgfile
```

Then compare those packages against the actual `gnome-meta` / `gnome-apps-meta` dependency closure rather than assuming every Qt5 user is part of GNOME.

### Validation

- Start from a clean/minimal BFSOS package state and resolve/install `gnome-meta`.
- Record the dependency path that causes Qt5 to enter the transaction.
- If the dependency was removed, confirm the GNOME desktop and affected application still build and run correctly without Qt5 being added by that path.
- If the dependency is legitimate, document the exact package and reason.
- Confirm Plasma, LXQt, XFCE, and other supported desktop/application stacks are not broken by any Qt5 cleanup made specifically for GNOME.

### Historical r252 status
**Superseded by the r253 status below.**


---

### r253 status
r253: root cause was `evolution -> highlight -> qt5`; Highlight now builds CLI-only. Rebuild `gnome-meta` in BFSOS to verify Qt5 disappears from the closure.

## IMPLEMENTED — Audit GTK4 test execution during normal package builds

### Context

During the current `gnome-meta` dependency/build sweep, the GTK4 package appeared to spend significant time running a large number of tests or test-like checks during the normal package build.

This needs to be audited before changing anything. Meson-based projects often run many compiler, feature, dependency, and configuration probes during `meson setup`; those are not the same thing as executing the project's full upstream test suite. BFSOS should first determine whether GTK4 is merely performing required configuration probes or whether the port/pkgmk path is also running the complete GTK4 test suite automatically.

### Required work

- Inspect the GTK4 `Pkgfile`, Meson options, and the generic `pkgmk` Meson build path to determine exactly which test-related commands are being executed.
- Distinguish required Meson configure/compile probes from `meson test`, `ninja test`, `make check`, or other full upstream test-suite execution.
- Record which layer triggers the tests: the GTK4 port itself, generic `pkgmk` behavior, a packaging hook, or an upstream build target.
- If the full GTK4 test suite is running automatically during ordinary package installation, decide whether that should remain the BFSOS default.
- Prefer normal release/package builds that compile and stage GTK4 without spending substantial extra time on an exhaustive upstream test suite unless the tests are required for a valid build.
- Preserve required generated-code checks, ABI/schema generation, introspection generation, and build-time validation that GTK4 actually needs; do not disable test-looking steps simply because they produce many checks.
- If full tests are made optional, provide an explicit developer/CI/test mode so GTK4 can still be validated deliberately before releases or after major toolchain updates.
- Keep the behavior consistent with the broader BFSOS package-testing policy so individual ports do not invent incompatible test toggles.
- Consider whether the same issue affects other large Meson packages and whether `pkgmk` needs a generic policy for optional test-suite execution.

### Desired behavior

For an ordinary user-facing package build/install:

```text
configure / Meson feature probes   -> enabled as required
compile-time validation            -> enabled as required
full upstream test suite           -> not automatic unless explicitly intended
```

For maintainer/CI validation:

```text
explicit test mode -> build package -> run upstream test suite -> report failures
```

The exact option/interface should be chosen after checking existing BFSOS `pkgmk` conventions rather than hard-coding a new variable prematurely.

### Validation

- Build GTK4 with verbose logging and identify every test/check phase actually executed.
- Confirm whether the observed long-running checks came from Meson configuration probes or from the full GTK4 test suite.
- If full tests are disabled for normal builds, compare build time before and after the change.
- Confirm GTK4 still installs a complete package and that GNOME applications using GTK4 build and start correctly.
- Run the full GTK4 test suite explicitly in maintainer/CI mode and verify that it remains available.
- Repeat the audit after a clean build to ensure cached Meson state did not hide or alter the observed behavior.

### Historical r252 status
**Superseded by the r253 status below.**

---


### r253 status
r253: GTK4 uses the generic Meson path; normal builds compile/install without running `meson test`. `PKGMK_RUN_TESTS=yes` now explicitly executes the Meson suite.

## PARTIAL / CONTINUE AUDIT — Make custom `pkg_build()` paths inherit global `pkgmk` build policy

### Problem

BFSOS uses a significant number of custom `pkg_build()` functions for packages that need nonstandard configuration, patches, feature selection, staging, or build-system handling. Those custom functions can bypass behavior that the generic `pkgmk` CMake, Meson, Autotools, Python, and other automatic build paths normally provide.

This can create silent differences between ordinary auto-detected ports and custom ports. A package may build with different optimization/debug settings, test policy, hardening, parallelism, install/staging behavior, or error handling simply because it defines `pkg_build()`.

A concrete example was observed with `webkitgtk` 2.52.6 during the GNOME dependency sweep. Its custom CMake invocation did not set `CMAKE_BUILD_TYPE`, so upstream WebKit defaulted to `RelWithDebInfo` instead of the BFSOS release-oriented default. The generated compile commands therefore contained full `-g` debug information. The build reached the final `libwebkitgtk-6.0.so` link and failed with `R_X86_64_32` relocation overflow against `.debug_info`. The Pkgfile attempted to append `-g1` to `CFLAGS`/`CXXFLAGS` only after CMake configuration, which was too late to change the already-generated Ninja compile commands.

The same class of problem has already appeared in other forms with custom Meson and CMake ports: generic test-disable logic is not necessarily inherited, custom configure/build/install commands may omit fail-fast handling, and package-specific commands can diverge from global BFSOS policy without making that divergence obvious.

### Required work

- Audit `pkgmk` to identify every policy/default that is currently applied only by its generic automatic build-system paths.
- At minimum, audit:
  - release/debug build mode;
  - optimization and debug-symbol policy;
  - compiler/linker flags and hardening;
  - architecture flags;
  - parallel job handling;
  - ccache integration;
  - test-suite defaults and developer/CI test overrides;
  - Meson wrap/download policy;
  - CMake generator/default options;
  - install prefix/libdir conventions;
  - `DESTDIR`/staging behavior;
  - static-library and libtool archive cleanup policy;
  - locale/documentation/man/info cleanup policy where applicable;
  - source/signature/footprint verification controls where applicable;
  - fail-fast behavior for configure/build/install phases.
- Refactor reusable policy into common helpers, exported variables, wrapper functions, or another centralized mechanism that can be used by both generic and custom package builds.
- Make custom `pkg_build()` functions inherit the normal BFSOS policy by default rather than requiring every Pkgfile maintainer to manually reproduce it.
- Allow a custom port to deliberately override a global default when upstream genuinely requires different behavior, but make the override explicit and easy to audit.
- Avoid blindly injecting options that a particular build system or upstream release does not support; centralized policy should distinguish shared intent from build-system-specific syntax.
- Preserve package-specific flexibility. The goal is not to eliminate custom `pkg_build()`, but to stop custom builds from accidentally becoming a separate policy universe.
- Audit existing custom ports after the common mechanism exists and remove duplicated local policy where it is safe to do so.
- Add lint/QA checks that flag suspicious custom builds, such as:
  - CMake configuration without an explicit/inherited build type;
  - Meson configuration that bypasses the normal BFSOS test policy;
  - configure/build/install commands without fail-fast handling;
  - compiler/debug flags modified only after the configure/generate phase;
  - local copies of global defaults that have drifted from current `pkgmk` behavior.

### Desired behavior

A normal package should receive the same distro policy regardless of whether it uses an auto-detected build path or a custom `pkg_build()`:

```text
auto CMake port       -> BFSOS global CMake policy -> package-specific overrides
custom CMake port     -> BFSOS global CMake policy -> package-specific overrides

auto Meson port       -> BFSOS global Meson policy -> package-specific overrides
custom Meson port     -> BFSOS global Meson policy -> package-specific overrides
```

Custom logic should add or override only what is genuinely package-specific.

For example, a custom CMake port should not need to remember independently that BFSOS wants a release build. It should inherit that policy, while still being able to add WebKit-specific options such as `PORT=GTK`, GTK4 enablement, sandbox options, or feature toggles.

### WebKitGTK evidence / regression case

Use `webkitgtk` 2.52.6 as an explicit regression test for this work:

- A custom `pkg_build()` configured WebKitGTK without `CMAKE_BUILD_TYPE`.
- Upstream selected `RelWithDebInfo`.
- The build generated full debug information and reached approximately `9403/9423` targets.
- The final `libwebkitgtk-6.0.so` link failed with relocation overflow against `.debug_info`.
- Appending `-g1` after CMake configuration did not alter the generated Ninja compile flags.
- The failed `cmake --build` was followed by `cmake --install`, demonstrating that custom build steps also need reliable fail-fast semantics.

After the framework is corrected, WebKitGTK should inherit the intended BFSOS release/debug policy before CMake generation without needing an ad-hoc duplicate of the global default.

### Verification

- Select representative auto and custom ports for CMake, Meson, and Autotools and record their effective configure/build commands.
- Confirm equivalent ports receive the same global optimization, debug, hardening, parallelism, and staging policy.
- Build `webkitgtk` and verify its CMake configuration uses the intended BFSOS release mode before Ninja files are generated.
- Inspect WebKitGTK compile commands and confirm unwanted full debug information is not reintroduced by the custom path.
- Confirm a deliberate package-specific override still works and is visible in verbose logs.
- Force configure, compile, and install failures in test ports and confirm each custom path terminates at the failing phase rather than cascading into later steps.
- Verify maintainer/CI test mode still enables intended upstream test suites while normal package builds retain the standard BFSOS test policy.
- Run a broad rebuild of custom `pkg_build()` ports after the refactor to catch assumptions that had been relying on the old bypass behavior.

### Status

**OPEN — confirmed policy gap. WebKitGTK 2.52.6 exposed that a custom `pkg_build()` can bypass the normal BFSOS build-type/default logic; broader custom-build audit and centralized inheritance are required.**

---

### r253 status
r253: multilib compiler/ABI/pkg-config policy is centralized and extension hooks wrap `pkg_build()`, but a broader per-port custom-build-policy audit remains appropriate.

## IMPLEMENTED / LIVE SYSUP VERIFY — `prt-get sysup` repeatedly reinstalls `pkgutils`

### Problem

On the current BFSOS test system, every `prt-get sysup` run attempts to reinstall `pkgutils` even when `pkgutils` was already installed by the previous system update and there is no intentional package-version change.

This indicates that the system-update/version-comparison path is not recognizing the installed `pkgutils` package as current, or that `pkgutils` is being reintroduced into the transaction for another reason. Reinstalling the package on every system update is unnecessary, adds noise to update logs, and may hide a broader package-database or version-comparison bug.

### Required work

- Reproduce the behavior with consecutive `prt-get sysup` runs where no `pkgutils` port metadata changes occur between runs.
- Record the installed `pkgutils` version/release from `pkginfo` and compare it with the version/release reported by `prt-get info pkgutils` before and after each `sysup`.
- Audit `prt-get` system-update candidate selection to determine why `pkgutils` is repeatedly classified as needing installation/update.
- Audit version and release comparison for `pkgutils`, including any special-case handling for the package-management tools themselves.
- Check whether the `pkgutils` package database entry, package footprint, install record, or package name is being altered during or after `sysup` in a way that makes the next run see it as stale or missing.
- Check whether `prt-get`, `pkgadd`, `pkgmk`, or another update hook deliberately schedules `pkgutils` as a bootstrap/self-update dependency on every transaction.
- Ensure a package that is already installed at the exact repository version and release is not reinstalled during an ordinary `sysup` unless the user explicitly requests a forced reinstall.
- Preserve any required package-manager self-update ordering, but only trigger it when the repository package is actually newer or otherwise requires replacement.
- Make the reason for any forced package-manager reinstall explicit in the transaction log rather than silently treating it as a normal update.

### Suggested diagnostics

Run two consecutive system updates without changing the ports tree and compare:

```bash
pkginfo -i | grep '^pkgutils '
prt-get info pkgutils
sudo prt-get sysup
pkginfo -i | grep '^pkgutils '
prt-get info pkgutils
sudo prt-get sysup
```

Also inspect the package database and update candidate output around `pkgutils` to determine whether the repeated action originates in version comparison, dependency resolution, or special package-manager handling.

### Verification

- With `pkgutils` already installed at the current repository version/release, run `prt-get sysup` twice with no repository changes.
- Confirm the first run performs only genuinely required updates.
- Confirm the second run reports no `pkgutils` reinstall when its version/release is unchanged.
- Update `pkgutils` to a deliberately newer release in the ports tree and confirm `sysup` updates it exactly once.
- Run `sysup` again and confirm it does not reinstall that same release.
- Verify explicit force/reinstall options still reinstall `pkgutils` when deliberately requested.
- Verify any package-manager self-update safety/ordering logic still works when a real `pkgutils` update exists.

### Historical r252 status
**Superseded by the r253 status below.**

---

### r253 status
r253: wrapper now consults `quickdiff` and pre-updates `pkgutils` only when stale; regression covers both current and stale cases. Verify with two consecutive live sysups.

## IMPLEMENTED / GDM VERIFY — Enable `nss-systemd` in the base `/etc/nsswitch.conf` for GDM dynamic users

### Problem

On the GNOME 50 runtime test system, GDM itself started successfully, but its greeter could not authenticate/start correctly because the dynamically allocated `gdm-greeter` user was invisible through NSS.

The installed `/etc/nsswitch.conf` contained only:

```text
passwd: files
group: files
shadow: files
```

even though `libnss_systemd.so.2` was installed.

This caused:

```text
pam_succeed_if(gdm-launch-environment:auth):
requirement "user ingroup gdm" not met by user "gdm-greeter"
```

and:

```text
getent passwd gdm-greeter
    -> no result

id gdm-greeter
    -> no such user
```

Modern GDM uses systemd/userdb-backed dynamic users such as `gdm-greeter`, so BFSOS must expose those identities through NSS.

### Required changes

Update the BFSOS base `/etc/nsswitch.conf` template/defaults to include `systemd` for the relevant databases:

```text
passwd:  files systemd
group:   files [SUCCESS=merge] systemd
shadow:  files systemd
gshadow: files systemd
```

Requirements:

- Preserve normal local `/etc/passwd`, `/etc/group`, `/etc/shadow`, and `/etc/gshadow` lookup behavior.
- Use group merging so the static `gdm` group can receive dynamic membership supplied by systemd userdb.
- Ensure `libnss_systemd.so.2` is installed whenever these NSS entries are shipped.
- Do not work around the issue by creating a permanent `gdm-greeter` account.
- Audit other BFSOS base-image/profile variants so they do not ship an older `files`-only `nsswitch.conf`.
- Document which package or installer component owns `/etc/nsswitch.conf` so future systemd/GDM updates cannot silently regress the configuration.

### Runtime evidence

After changing NSS to the configuration above:

```text
getent passwd gdm-greeter
gdm-greeter:x:60578:21:GDM Greeter:/run/gdm/home/gdm-greeter:/usr/sbin/nologin
```

and:

```text
getent group gdm
gdm:x:21:gdm-greeter
```

with:

```text
id gdm-greeter
uid=60578(gdm-greeter) gid=21(gdm) groups=21(gdm)
```

The previous PAM `user ingroup gdm` failure disappeared after GDM was restarted.

### Verification

- Boot a fresh BFSOS GNOME installation.
- Confirm `/etc/nsswitch.conf` contains the required `systemd` entries.
- Confirm `/usr/lib/libnss_systemd.so.2` is present.
- Start GDM and verify:
  - `getent passwd gdm-greeter` resolves the dynamic greeter user.
  - `getent group gdm` includes `gdm-greeter`.
  - `id gdm-greeter` succeeds.
  - GDM does not log the previous `pam_succeed_if ... user ingroup gdm not met` error.
- Verify ordinary local users and groups continue to resolve correctly.
- Verify the configuration survives upgrades of the package that owns `/etc/nsswitch.conf`.

### Historical r252 status
**Superseded by the r253 status below.**

---

### r253 status
r253: base glibc-owned `nsswitch.conf` now includes systemd lookups and merged groups; validate GDM dynamic users on a rebuilt image.

## IMPLEMENTED — Installer/base image must force `/` to `root:root` mode `0755`

### Problem

The GNOME 50 runtime test exposed a serious filesystem ownership problem on the freshly installed BFSOS system.

The root directory was installed as:

```text
dr-xr-xr-x ... brian ... /
brian:UNKNOWN 555 /
```

instead of:

```text
root:root 755 /
```

This is both a security/correctness problem and a runtime compatibility problem.

One direct consequence was that `systemd-tmpfiles` rejected traversal from `/` into `/tmp`:

```text
Detected unsafe path transition / (owned by brian) → /tmp (owned by root)
during canonicalization of tmp.
```

Because tmpfiles processing could not safely maintain `/tmp/.X11-unix`, GDM's dynamic greeter created or left that directory owned by the greeter UID. A later GNOME user login then failed when Xwayland rejected the directory ownership:

```text
Failed to start X Wayland:
Wrong ownership for directory "/tmp/.X11-unix"
```

GNOME Shell aborted and the session bounced back to GDM.

### Required changes

- Determine where the installer, rootfs staging, archive extraction, ownership restoration, or post-install logic changes the ownership/mode of `/`.
- Ensure the final installed root directory is always:

```text
owner: root
group: root
mode: 0755
```

- Explicitly enforce the expected ownership/mode near the end of installation as a final safety step:

```bash
chown root:root /
chmod 755 /
```

- Do **not** use recursive ownership repair on `/`.
- Audit the installer for commands that may accidentally apply the invoking user's ownership to the root mountpoint or restored filesystem tree.
- Audit tar/copy/rootfs staging operations for unexpected preservation or substitution of top-level directory ownership.
- Ensure any install performed from a non-root desktop/live environment cannot inherit the live user's ownership on the target `/`.
- Add a final filesystem sanity check before declaring installation complete.

### Final installer sanity checks

At minimum verify:

```text
/      root:root 0755
/tmp   root:root 1777
/usr   root:root
/etc   root:root
/var   root:root
/root  root:root
```

Symlink ownership for merged-/usr paths such as `/bin` and `/sbin` should also remain sane.

If `/` is not `root:root 0755`, the installer should report a fatal installation error or correct it before first boot.

### X11 tmpfiles interaction

BFSOS already ships:

```text
/usr/lib/tmpfiles.d/x11.conf:
D /tmp/.X11-unix 1777 root root 1h
```

The rule itself was not the root cause. Once `/` was corrected to `root:root 0755`, `systemd-tmpfiles --create` succeeded and `/tmp/.X11-unix` remained:

```text
root:root 1777
```

So the permanent fix is to correct root filesystem ownership, not to add a duplicate X11 tmpfiles rule.

### Verification

- Perform a completely fresh BFSOS installation as a normal non-root installer user where applicable.
- Before first reboot, verify `/` is `root:root 0755`.
- After first boot, verify `/` remains `root:root 0755`.
- Run `systemd-tmpfiles --create` and confirm there are no unsafe-path-transition errors involving `/`.
- Verify `/tmp/.X11-unix` is `root:root 1777`.
- Start GDM, log into GNOME Wayland, and confirm Xwayland starts without the wrong-ownership error.
- Reboot and repeat to confirm the ownership is not being changed by first-boot or login hooks.
- Audit other top-level directories for accidental non-root ownership.
- Add an installer regression test that fails if `/` is owned by the installer user or has mode `0555`.

### Historical r252 status
**Superseded by the r253 status below.**

---

### r253 status
r253: installer r73 performs the final root ownership/mode postflight.

## IMPLEMENTED / XFCE LOGIN VERIFY — XFCE 4.20 default panel profile cleanup

### Runtime result

`xfce4-meta` installed successfully and the normal XFCE X11 session launches from GDM. The desktop itself is usable, but the default panel profile exposed two packaging/configuration problems.

### 1. Power Manager panel plugin uses the wrong profile identifier

The package and plugin are present and healthy:

```text
xfce4-power-manager              installed
/usr/bin/xfce4-power-manager     present
/usr/lib/xfce4/panel/plugins/libxfce4powermanager.so
                                present
wrapper-2.0                      present
ELF dependencies                 all resolve
undefined symbols                none
xfce4-power-manager daemon       running
```

The installed plugin metadata registers the panel module as:

```text
power-manager-plugin
```

but BFSOS `/etc/xdg/xfce4/panel/default.xml` currently configures plugin 6 as:

```xml
<property name="plugin-6" type="string" value="xfce4powermanager"/>
```

XFCE panel debug output proves the mismatch:

```text
new module power-manager-plugin,
filename=/usr/lib/xfce4/panel/plugins/libxfce4powermanager.so,
internal=false

Module "xfce4powermanager" not found in the factory
```

This causes the first-login popup reporting that the Power Manager Plugin could not be loaded.

The live user fix is:

```bash
xfconf-query -c xfce4-panel \
    -p /plugins/plugin-6 \
    -s power-manager-plugin

xfce4-panel -r
```

The permanent BFSOS default must use:

```xml
<property name="plugin-6" type="string" value="power-manager-plugin"/>
```

Do **not** change the plugin desktop metadata line:

```text
X-XFCE-Module=xfce4powermanager
```

That is the module/library identifier and is not the stale panel-profile key.

### Required package fix

Find which BFSOS port installs or replaces:

```text
/etc/xdg/xfce4/panel/default.xml
```

and update the default profile so new users receive:

```text
power-manager-plugin
```

instead of:

```text
xfce4powermanager
```

If existing installations need migration, perform it narrowly through xfconf/profile migration logic. Do not rewrite unrelated user panel customization.

### Verification

On a fresh user account:

- Log into XFCE.
- Confirm no "Power Manager Plugin could not be loaded" popup appears.
- Confirm:

```bash
xfconf-query -c xfce4-panel -p /plugins/plugin-6
```

returns:

```text
power-manager-plugin
```

- Confirm an external wrapper is running for `libxfce4powermanager.so`.
- Confirm the power icon/plugin appears and `xfce4-power-manager` remains running.

### 2. BFSOS XFCE profile defines only one panel

Both the system default and the newly created user configuration currently contain:

```text
/panels [1]
```

and `/etc/xdg/xfce4/panel/default.xml` defines only `panel-1`.

The observed XFCE desktop therefore has the full-width top panel but no traditional second/bottom launcher panel. This is not a panel crash: the second panel is simply absent from the shipped BFSOS profile.

### Required profile work

BFSOS must provide and own a complete XFCE two-panel first-login profile. Earlier work already showed that XFCE was not populating the desired launcher/icon set automatically, so do not depend on upstream first-login behavior to create a useful bottom panel.

At minimum, define:

```text
panel-1  full-width top panel
panel-2  smaller bottom launcher/dock-style panel
```

Use current XFCE 4.20-compatible plugin names and configuration rather than copying an old profile blindly.

The BFSOS-owned bottom panel must also include the intended default launcher/icon set instead of creating an empty second panel. Use the applications supplied by the BFSOS XFCE meta packages and create valid launcher entries/icons for the expected defaults, such as the BFSOS-selected equivalents of:

```text
Terminal
File Manager
Web Browser
Application Finder
Show Desktop
```

Requirements:

- Install the launcher `.desktop`/panel launcher data needed for the icons to appear on a brand-new user profile.
- Reference applications that are guaranteed by `xfce4-meta` / `xfce4-apps-meta`, or deliberately provide a fallback when an optional application is absent.
- Keep the default layout BFSOS-owned and versioned so later XFCE updates cannot silently remove or rename required launcher/plugin identifiers.
- Validate icon names against the installed icon themes and desktop files instead of relying on stale hard-coded names.
- Preserve the corrected `power-manager-plugin` identifier in the same profile.
- Do not overwrite an existing user's customized panel layout during a normal package upgrade. Fix the system default for new users and use an explicit migration only when needed.

### Verification

With a fresh user profile:

- First XFCE login creates both panel 1 and panel 2.
- `xfconf-query -c xfce4-panel -p /panels` reports both panel IDs.
- The top panel contains its normal task/status controls.
- The bottom panel appears at the bottom and its launchers resolve to installed applications.
- No plugin-load warning appears.
- Logging out and back in preserves both panels.

### Historical r252 status
**Superseded by the r253 status below.**

---

### r253 status
r253: corrected Power Manager ID and added BFSOS launcher panel/profile files; validate first-login layout in a clean user profile.


### r270 live status

The r253 source-side two-panel work was not yet sufficient for a clean XFCE first login. r270 live testing proved the final runtime requirements:

- panel 1: `p=6`, full-width top panel, plugins 1-10;
- panel 2: `p=10`, centered bottom dock, plugins 11-15;
- launcher `items` must remain one-element **string arrays**, never scalar strings;
- the five launcher files must actually be imported/materialized into the active user panel launcher directories on first login;
- use `org.xfce.terminal`, `org.xfce.thunar`, `org.xfce.ristretto`, `org.xfce.parole`, and `stock_xfburn` as the canonical icon keys;
- provide a monitor-independent first-login wallpaper default using the installed XFCE wallpaper rather than leaving a fresh user with a black background.

The manually corrected VM state survived logout/login. Permanent source/profile packaging and fresh-user regression coverage remain OPEN.

## RC1 POLICY IMPLEMENTED / NON-BLOCKING — XFCE 4.20 Wayland session is experimental

### Observation

GDM advertises an XFCE Wayland session in addition to the normal XFCE X11 session. Selecting the Wayland entry on the current BFSOS test system does not produce a usable XFCE desktop.

Do not classify this as a BFSOS regression yet.

XFCE 4.20 upstream explicitly describes Wayland support as **experimental** and recommends it only for advanced users. XFCE 4.20 does not provide a Wayland-capable `xfwm4` compositor; upstream currently recommends external Wayland compositors such as Labwc or Wayfire for experimental XFCE Wayland sessions.

Therefore the failed XFCE Wayland login may simply reflect incomplete upstream support or a missing experimental compositor rather than something BFSOS broke.

### Required audit

Determine exactly which package installs the XFCE Wayland session file and inspect its command/requirements.

Verify:

- the path and contents of the Wayland session `.desktop` file;
- whether it invokes `startxfce4 --wayland`;
- whether it expects Labwc, Wayfire, or another compositor;
- whether BFSOS currently installs the required compositor;
- whether the session file is intended by upstream for general display-manager use or experimental testing only.

### BFSOS policy for RC1

For RC1, the normal XFCE X11 session is the supported XFCE desktop unless/until the Wayland path is proven usable.

Do not spend RC-blocking time trying to make experimental XFCE Wayland feature-complete.

If the Wayland entry cannot work with the packages supplied by BFSOS, choose one of these explicitly:

1. **Hide/omit the experimental Wayland session from the normal GDM session list** until its runtime requirements are shipped; or
2. **Ship the required experimental compositor and document the session as experimental**.

Do not advertise a session as a normal supported desktop if selecting it predictably returns the user to GDM or leaves them without a usable desktop.

### Future verification

When XFCE Wayland support matures:

- re-enable/retest the session;
- verify panel, desktop, settings, power management, notifications, portals, clipboard, input, display handling, logout/reboot, and XWayland application compatibility;
- revisit the policy when XFCE's own compositor/window-manager Wayland support reaches a suitable maturity level.

### Historical r252 status
**Superseded by the r253 status below.**

---

### r253 status
r253: RC1 hides the Xfce Wayland session from the normal login list because BFSOS does not ship a supported compositor path for it. X11 remains supported.

## IMPLEMENTED v9 / ONLINE AUDIT VERIFY — Rework the BFSOS upstream update/version checker and rerun the entire ports audit

### Context

The recent full-tree update work exposed several cases where the BFSOS upstream version checker still needs stronger provider detection, release-series filtering, blocked-source handling, and regression coverage.

The current checker lineage is provider-aware and is used through the BFSOS update-check workflow, including:

```text
scripts/checkupdate.sh
version-check.sh
multilibvercheck.sh
```

The checker must remain conservative: it should only report a package as safely updatable when it can prove that the discovered version belongs to the correct upstream release set for that port. Automatic mass editing of `Pkgfile` versions must remain disabled unless a separate, deliberately designed and reviewed update mode is implemented later.

### Known recent problem classes to preserve as regression cases

Audit and retain regression coverage for issues found during the recent port sweep, including:

- HTTP/access failures such as upstream download locations returning `403` instead of usable release metadata. A blocked source must not be silently treated as `CURRENT`.
- Provider URLs whose release/tag/archive layout differs from a simple directory listing.
- Codeberg and GitLab-style `/-/archive/` source URLs.
- GNOME source paths that need correct path parsing and URL decoding.
- PyPI host variants, including historical `pypi.python.org` forms still present in older ports.
- Netfilter packages such as `iptables` and `libmnl` that need release-page-aware handling rather than weak generic-directory guesses.
- Release-series false positives, including GTK 2.24 ports incorrectly seeing unrelated later/development series such as 2.90.x as an update.
- Ports for which the checker can see newer-looking text but cannot prove that it represents the same project/release channel.
- Redirects, renamed release files, mirror changes, and source hosts that behave differently for `HEAD` and `GET`.
- Pre-release, alpha, beta, RC, snapshot, nightly, ESR/LTS, and other channel/version distinctions that must not be collapsed into one lexical "newer version" comparison.
- Packages whose upstream version syntax contains prefixes/suffixes such as `v`, `-esr`, date-based releases, epoch-like components, or nontrivial tag naming.

### Required checker changes

Audit the complete checker stack rather than patching only one provider.

At minimum:

- Review the current provider-dispatch logic and every provider-specific parser.
- Confirm dedicated handling remains correct for:
  - GNOME;
  - KDE;
  - XFCE;
  - GitHub;
  - GitLab;
  - Codeberg;
  - git.kernel.org;
  - PyPI;
  - generic HTTP/HTTPS directory sources;
  - any other provider currently recognized by the scripts.
- Add provider-specific handling where repeated generic-directory parsing has proven unreliable.
- Use a clear User-Agent and follow legitimate redirects.
- Where a host rejects `HEAD`, retry through an appropriate `GET`/metadata path instead of immediately producing a false result.
- Distinguish at least:
  - `CURRENT`;
  - verified `UPDATE`;
  - `UNVERIFIABLE` / blocked;
  - parser/provider `ERROR`.
- Never convert a network error, HTTP `403`, empty result, or ambiguous release page into `CURRENT`.
- Never emit `UPDATE` solely because a numerically larger token appears on a page.
- Keep release-channel/series constraints explicit where a project publishes parallel stable, legacy, ESR/LTS, or development lines.
- Preserve provider-specific exceptions only when they are documented and covered by regression tests; avoid one-off opaque package hacks when a reusable provider rule can solve the class of problem.
- Keep source URL parsing compatible with BFSOS `Pkgfile` source arrays and variable-expanded URLs.
- Make checker output identify which provider/parser was used and why a result is `UPDATE`, `CURRENT`, `UNVERIFIABLE`, or `ERROR`.
- Keep automatic `Pkgfile` modification disabled during this audit. The checker should report; the maintainer should review and update ports deliberately.

### Full repository re-audit after the checker is corrected

After the checker changes are complete, run the checker over **the entire BFSOS ports tree again**, not just the packages that previously looked stale.

For every port:

1. Re-evaluate the upstream source/provider using the corrected checker.
2. Review every `UPDATE`, `UNVERIFIABLE`, and `ERROR` result manually.
3. Update the port to the current appropriate stable release where warranted.
4. Correct stale source URLs, checksums, signatures, dependencies, patches, build options, and descriptions as needed.
5. Preserve intentional old/legacy versions only when BFSOS has a documented compatibility reason.
6. Re-run the checker after each class of fixes and again after the complete sweep.
7. Ensure a second unchanged checker run produces stable results and does not flap between statuses.

### Integration with the port updater

Re-test the normal ports synchronization/update path while doing this work.

Generated package artifacts such as `.md5sum` and `.footprint` must not be mistaken for maintainer source modifications, while real edits to `Pkgfile`, patches, scripts, and other tracked port content must still be detected.

Also verify:

- a failed network sync preserves the previous usable ports tree;
- one repository refresh updates the BFSOS collections without redundant clones;
- third-party HttpUp collections continue to work;
- checker failures do not corrupt or partially rewrite port metadata.

### Regression suite

Create a repeatable checker regression set containing representative URLs/packages from each supported provider and every recent false-positive/false-negative class.

The suite should include:

```text
known current release
known newer stable release
parallel stable/legacy release lines
development/pre-release newer than stable
HTTP 403 / blocked source
redirected source
Codeberg/GitLab archive URL
GNOME encoded/path-based URL
PyPI host variants
generic directory listing
ESR/LTS-style version
unverifiable/ambiguous source
```

The expected status for each test must be recorded so future checker changes cannot silently reintroduce the same failures.

### Historical r252 status
**Superseded by the r253 status below.**

---

### r253 status
r253: checker v9 includes contrib and ESR/LTS channel guards. Full network-backed audit is still required in a connected BFSOS environment.

## SOURCE PASS IMPLEMENTED / LIVE BUILD VERIFY — Modernize `contrib` and `compat-32` together as one coordinated ports pass

### Why these collections should be handled together

`contrib` and `compat-32` overlap too heavily to treat as unrelated sweeps.

Many 32-bit compatibility ports mirror libraries that also exist in the native collections or are pulled in by `contrib` applications such as Wine/Steam-era software. Updating native packages first and postponing `compat-32` would immediately create version, patch, ABI, dependency, and feature drift.

Perform the `contrib` modernization and the complete `compat-32` synchronization in the same development phase.

### Phase 1 — Update and normalize all `contrib` ports

Audit every port in `contrib`.

For each port:

- Check the current appropriate stable upstream release with the corrected BFSOS version checker.
- Update version/release, source URLs, checksums/signatures, dependencies, patches, and build options where required.
- Convert legacy CRUX-style assumptions and ad-hoc recipes to the current BFSOS port conventions and BFSOS `pkgmk` extensions.
- Prefer BFSOS common build helpers/policy over duplicated local logic.
- Make custom `pkg_build()` paths inherit the normal BFSOS build policy wherever possible.
- Ensure configure/build/install stages fail fast.
- Remove stale options for features that no longer exist upstream.
- Enable/disable optional features deliberately based on BFSOS policy rather than whatever an old recipe happened to select.
- Normalize install prefixes, libdirs, `DESTDIR` use, documentation/locale/static-library cleanup, test policy, hardening, and release/debug policy through BFSOS mechanisms.
- Replace obsolete source locations and dead mirrors.
- Audit dependency comments so they match what the build actually requires.
- Keep package-specific exceptions only where upstream genuinely needs them and document why.
- Rebuild/update repository metadata after changes.

The result should be a `contrib` tree that looks and behaves like a first-class BFSOS collection rather than an inherited CRUX collection with accumulated local exceptions.

### Phase 2 — Synchronize every `compat-32` port with its native counterpart

For every 32-bit compatibility port that has a native BFSOS counterpart:

- Make the native 64-bit port the source of truth for the upstream version.
- Update the 32-bit port to the **same upstream version** as its native counterpart unless a documented ABI/compatibility reason makes that impossible.
- Synchronize relevant patches and source fixes.
- Synchronize feature selections where those features are meaningful for the 32-bit ABI.
- Synchronize security fixes and build-system migrations.
- Re-check dependencies rather than blindly copying the native dependency line; use 32-bit counterparts for libraries that must participate in the 32-bit ABI.
- Detect and report any `compat-32` port whose native counterpart is missing, renamed, older/newer, or otherwise out of sync.
- Use/extend `multilibvercheck.sh` so version drift between native and `compat-32` becomes an automated regression check.
- Add a simple synchronization marker where useful, for example:

```text
# Synced with: opt/foo 1.2.3-4
```

The exact marker format may be standardized during implementation, but the native-to-32-bit relationship must be easy to audit.

### Phase 3 — Convert `compat-32` to the BFSOS/LFS-style multilib install model

The existing 32-bit ports should be converted away from "install a nearly complete duplicate package and then delete unwanted files" behavior.

Use an LFS/BLFS-style multilib model in which 32-bit builds primarily provide the ABI artifacts required by 32-bit applications.

Target layout:

```text
/usr/lib32
/usr/lib32/pkgconfig
```

and, where the upstream project genuinely installs/needs it:

```text
/usr/lib32/cmake
```

Use the appropriate 32-bit compiler/linker mode, conceptually:

```text
CC="gcc -m32"
CXX="g++ -m32"
CFLAGS/CXXFLAGS/LDFLAGS -> inherit BFSOS policy plus the 32-bit ABI selection
--libdir=/usr/lib32
```

The exact implementation should be centralized through BFSOS `pkgmk` extensions rather than copied independently into hundreds of Pkgfiles.

Preferred design:

```text
native build policy
    +
BFSOS ABI/multilib mode
    ->
32-bit compiler flags
32-bit pkg-config search path
/usr/lib32 install location
32-bit dependency resolution
staging/packaging rules
```

An implementation variable may be named along the lines of:

```text
PKGMK_ABI=32
```

or:

```text
PKGMK_MULTILIB=32
```

but choose the final interface after auditing the existing BFSOS extensions so a duplicate mechanism is not invented unnecessarily.

### 32-bit package contents

By default, a `compat-32` package should install only the 32-bit runtime/development artifacts that are actually needed for the compatibility ABI, such as:

- 32-bit shared libraries;
- required loader/library symlinks;
- 32-bit `pkg-config` metadata;
- 32-bit CMake metadata when needed;
- architecture-specific helper objects/plugins/modules that must be 32-bit.

Avoid duplicate installation of ordinary architecture-independent content already supplied by the native package, including where appropriate:

```text
/usr/bin programs
/usr/share documentation
/usr/share man pages
/usr/share locales
generic icons/themes
duplicate headers
duplicate licenses/readmes
```

Do not blindly remove these after a full install. Prefer configure/install options, targeted staging, or an allowlist/selection mechanism so the package installs the intended 32-bit payload from the start.

Document explicit exceptions for projects that genuinely require a 32-bit helper executable, architecture-specific header, loader, plugin, or other non-library artifact.

### Dependency and package-manager behavior

- Keep native and `compat-32` packages installable at the same time without file collisions.
- Ensure 32-bit packages do not overwrite native `/usr/lib`, `/usr/bin`, or architecture-independent files.
- Ensure 32-bit `pkg-config` lookup cannot accidentally resolve the 64-bit `.pc` file during a 32-bit build.
- Ensure native builds do not accidentally resolve `/usr/lib32/pkgconfig`.
- Ensure dependency resolution consistently chooses the correct 32-bit library counterpart when building a `compat-32` port.
- Preserve BFSOS package database ownership/footprints so removing a `compat-32` package cannot delete files owned by the native package.
- Audit dynamic-loader configuration for `/usr/lib32`.
- Verify Wine, Steam/native 32-bit Linux applications, and other compatibility consumers can locate the resulting libraries.

### BFSOS port-style conversion requirements

As the collections are updated, convert their recipes to the current BFSOS design rather than carrying old local workarounds forward.

Audit for:

- custom builds that bypass BFSOS release/debug policy;
- repeated manual `-m32` flag blocks that should become a central extension;
- repeated manual `/usr/lib32` rewrite logic;
- install-all-then-`rm -rf` cleanup;
- missing fail-fast handling;
- stale dependency comments;
- stale test options;
- stale build-system options;
- hand-written cleanup that `pkgmk` already performs globally;
- inconsistent source verification;
- inconsistent package release bumps;
- architecture-independent files duplicated by `compat-32`;
- version drift from the native counterpart.

### Coordinated work order

Use this order for the combined pass:

```text
1. Fix/update the upstream version checker
2. Re-audit native ports and contrib
3. For each updated native library, immediately synchronize its compat-32 counterpart
4. Convert the paired 32-bit recipe to the centralized BFSOS multilib/LFS-style model
5. Build/test the native package
6. Build/test the 32-bit package
7. Continue through the dependency graph
8. Run a final contrib + compat-32 consistency sweep
9. Run final prt-get diff/sysup/install tests
```

Do not wait until the entire native `contrib` tree is finished before beginning its matching 32-bit updates.

### Verification

At completion:

- Every `contrib` port has been checked against current upstream releases.
- Every applicable `compat-32` port matches the intended native version.
- `multilibvercheck.sh` reports no unexplained version drift.
- Native and 32-bit packages coexist without file collisions.
- 32-bit libraries reside under `/usr/lib32`.
- 32-bit `.pc` files resolve from the 32-bit pkg-config path.
- Representative Autotools, CMake, Meson, and custom-build multilib ports all inherit the same BFSOS global build policy.
- No routine `compat-32` recipe depends on install-all-then-delete cleanup unless an upstream limitation is documented.
- Wine and representative 32-bit binaries start and resolve their shared libraries.
- Steam/native 32-bit Linux compatibility requirements are checked before declaring the 32-bit collection complete.
- A final full-tree checker pass reports only understood/documented exceptions.
- A final package-manager update/install pass does not expose dependency or footprint collisions between native and compatibility packages.

### RC relationship

This is a major pre-RC cleanup phase because Wine/Steam and the existing 32-bit compatibility tree depend on it. Keep the current `/usr/lib32` multilib approach for RC1 rather than attempting to replace the entire compatibility model with a newer Wine-only WoW64 design.

A future WoW64 investigation can continue during RC development, but it does not replace the need for a coherent 32-bit ABI collection for native 32-bit Linux software.

### Historical r252 status
**Superseded by the r253 status below.**


### r253 status
r253: source synchronization/normalization is complete and automated; representative and dependency-chain 32-bit package builds plus Steam/Wine runtime validation remain mandatory.

## r255 Tracker Update — Installer must propagate detected MD personality to GRUB

- **Generated:** 2026-09-08

### [ ] OPEN / PRE-RC BLOCKER — Add required `rd.driver.pre=<md-personality>` to GRUB for detected target RAID

- Fresh installer validation with `linux-lts` 6.18.49-BFS-LTS and an active six-member RAID10 target confirmed that the installer correctly generated `/etc/mdadm.conf`, embedded MD/crypt configuration in the initramfs, and added the required `rd.md.uuid=<array-uuid>` to GRUB, but failed to add the required modular MD personality preload argument.
- Observed target topology: `/dev/md0`, RAID personality `raid10`, metadata 1.2, six active members, with LUKS and LVM above the array for `/home` and `/var`.
- Generated GRUB Linux lines contain `rd.md.uuid=76ce0636:be8a23e1:e2ee423d:1ff9fff3` but omit `rd.driver.pre=raid10`.
- Root cause in the current installer: `configure_grub_storage_cmdline()` discovers required MD arrays/UUIDs and appends `rd.md.uuid=...`, but it does not discover each array's MD level/personality and append the matching `rd.driver.pre=...` argument.
- Required behavior: for every MD array required by the installed target topology, determine the personality with `mdadm --detail`/sysfs and append the exact required preload argument to `GRUB_CMDLINE_LINUX`, deduplicated and idempotent:
  - Linear/JBOD -> `rd.driver.pre=linear`
  - RAID0 -> `rd.driver.pre=raid0`
  - RAID1 -> `rd.driver.pre=raid1`
  - RAID10 -> `rd.driver.pre=raid10`
  - RAID4/5/6 -> `rd.driver.pre=raid456`
- Keep `rd.md.uuid=<uuid>` as a separate required argument; the personality preload does not replace the array UUID.
- Apply the storage arguments to `GRUB_CMDLINE_LINUX` so they appear in normal, advanced, and recovery entries for either the normal or LTS kernel.
- Extend `verify_grub_storage_cmdline()` to fail installation if any required MD array's matching `rd.driver.pre=` token is absent from generated Linux entries.
- Extend installer regression tests to cover Linear/JBOD, RAID0, RAID1, RAID10, and RAID456 and verify both the UUID and the personality preload are generated.
- For modular LTS personalities, verify `/boot/config-$KVER` reports the expected `CONFIG_MD_* =m`, the matching `.ko.zst` exists under `/usr/lib/modules/$KVER/kernel/drivers/md/`, and the initramfs contains it.
- **Release criterion:** a RAID10 + LUKS + LVM install using only `linux-lts` generates `rd.md.uuid=... rd.driver.pre=raid10 ...` in every applicable GRUB Linux entry and boots without manual GRUB edits.

## r256 Tracker Correction — 6.18 LTS MD metadata compatibility flag was not propagated to GRUB

- **Generated:** 2026-09-08
- **Supersedes the interpretation in the r255 update above.** The newly observed boot-risk regression is not merely the absence of an MD personality preload token. The critical missing argument is the BFSOS Linux 6.18 LTS MD metadata compatibility parameter provided by `md-check-new-feature-6.18.patch`.

### [ ] OPEN / PRE-RC BLOCKER — Installer failed to add `md_mod.check_new_feature=0` to an affected Linux 6.18 LTS RAID install

Fresh installer validation selected **only** `linux-lts` `6.18.49-BFS-LTS` release 8 and created/used the following target storage stack:

```text
six-member MD RAID10 (/dev/md0, metadata 1.2)
  -> LUKS cryptraid
  -> LVM bfs-raid
  -> Btrfs /home and /var
```

The installed LTS kernel correctly carries the BFSOS `md-check-new-feature-6.18.patch` compatibility backport and exposes the kernel parameter:

```text
md_mod.check_new_feature=0
```

Previous controlled BFSOS VM testing proved that this exact 6.18 LTS compatibility path is required for affected MD v1.x arrays whose metadata contains newer feature/padding state that Linux 6.18 otherwise rejects with messages such as:

```text
Some padding is non-zero ..., might be a new feature
... does not have a valid v1.2 superblock, not importing!
md_import_device returned -22
```

The fresh installer correctly generated the MD/LUKS/LVM storage arguments, including:

```text
rd.md.uuid=76ce0636:be8a23e1:e2ee423d:1ff9fff3
rd.luks.uuid=...
rd.lvm.lv=...
```

but the generated Linux 6.18 LTS GRUB entries **did not contain**:

```text
md_mod.check_new_feature=0
```

This means the kernel backport is present but the installer/GRUB policy that is supposed to activate it for an affected 6.18 LTS RAID target was not applied.

### Required permanent behavior

- When the selected target kernel is an affected BFSOS Linux 6.18 LTS build carrying the `check_new_feature` backport, inspect every MD array required by the installed target topology before generating GRUB.
- Detect the confirmed forward-compatibility condition rather than enabling the bypass merely because "RAID exists" or because the selected kernel is LTS.
- For an affected array that matches the known-safe compatibility case, add `md_mod.check_new_feature=0` **only to the applicable Linux 6.18 LTS GRUB entries**.
- Do not add the argument to normal/current BFSOS kernels that understand the metadata natively.
- Do not make `md_mod.check_new_feature=0` an unconditional global `GRUB_CMDLINE_LINUX` default across all kernels.
- Record which required MD UUID(s) caused the compatibility mode to be enabled and why.
- `bfs-kernel-maintenance regenerate-grub` must reproduce/preserve the same conditional per-kernel decision after kernel updates or GRUB regeneration.
- Stop applying the workaround automatically once the selected LTS kernel series understands the newer metadata natively.
- If metadata inspection indicates an unknown/mixed/inconsistent feature state, fail or warn clearly instead of silently disabling the safety check.

### Installer verification requirement

For an affected Linux 6.18 LTS + MD install, installation must fail final boot verification if the generated LTS `linux` lines do not contain all required storage parameters **and** the compatibility token:

```text
rd.md.uuid=<required-array-uuid>
md_mod.check_new_feature=0
```

The verifier must also confirm that the selected kernel actually exposes the backported parameter, for example through `modules.builtin.modinfo`, before relying on it.

### Regression test

Re-run the current six-disk RAID10 + LUKS + LVM installation with `linux-lts` selected and verify before reboot:

```text
1. /etc/mdadm.conf contains the required array and UUID.
2. The LTS initramfs contains mdraid support and the generated mdadm.conf/crypttab.
3. Every applicable 6.18 LTS GRUB Linux entry contains the required rd.md.uuid= token.
4. Every applicable affected 6.18 LTS GRUB Linux entry also contains md_mod.check_new_feature=0.
5. The system boots without manually editing GRUB.
6. The RAID10 assembles, LUKS opens, bfs-raid LVM activates, and /home + /var mount normally.
7. A later `bfs-kernel-maintenance regenerate-grub` does not remove the compatibility token while the affected 6.18 LTS kernel remains installed/selected.
```

### Status

**CONFIRMED INSTALLER/GRUB REGRESSION — kernel backport is installed and working, but automatic conditional propagation of `md_mod.check_new_feature=0` is still missing and is a pre-RC blocker.**

---

## r257 Tracker Update — Kernel refresh required before RC1

### [ ] OPEN / NEXT TRACKER PASS — Refresh normal and LTS kernels to current kernel.org releases

Kernel.org moved again on **2026-09-07** after the previous BFSOS maintained-port/version pass. The BFSOS kernel ports are therefore out of date again and should be refreshed during the next tracker/source pass before RC1 is frozen.

Current upstream versions recorded for this pass:

```text
BFSOS normal kernel:  7.2.3   -> kernel.org stable 7.2.4
BFSOS LTS kernel:     6.18.49 -> kernel.org longterm 6.18.50
```

Upstream reference: https://www.kernel.org/

### Required work — `linux`

- Update the normal BFSOS kernel port from `7.2.3` to `7.2.4`.
- Refresh the source URL/checksum/signature metadata as required by the BFSOS packaging policy.
- Reapply and verify all BFSOS kernel configuration and local patches against 7.2.4.
- Build/package/install 7.2.4 and verify the expected versioned kernel, initramfs, and normal-kernel aliases are generated correctly.
- Regenerate GRUB and verify there are no duplicate/stale kernel entries and that the normal current kernel remains bootable.

### Required work — `linux-lts`

- Update the BFSOS LTS kernel port from `6.18.49` to `6.18.50`.
- Refresh the source URL/checksum/signature metadata as required by the BFSOS packaging policy.
- Reapply the BFSOS 6.18 MD metadata compatibility backport (`md-check-new-feature-6.18.patch`) and confirm it still applies cleanly to 6.18.50.
- Confirm the resulting kernel still exposes the compatibility switch through the correct built-in MD module namespace:

```text
md_mod.check_new_feature=0
```

- Reverify the intended MD personality configuration/modules and initramfs contents after the 6.18.50 build.
- Preserve the existing requirement that `md_mod.check_new_feature=0` be added **conditionally only to affected Linux 6.18 LTS boot entries** when the installer/maintenance tooling positively detects the known forward-metadata compatibility case.
- Do not turn the compatibility switch into a global/unconditional kernel command-line option merely because the LTS version was refreshed.

### Validation before RC1

After both kernel ports are refreshed:

1. Build both kernels from the updated ports without relying on stale package artifacts.
2. Install/update each kernel through the normal BFSOS package-management path.
3. Verify versioned kernel/initramfs artifacts and aliases point at the intended versions.
4. Regenerate GRUB and verify current, LTS, fallback/known-good, and stale-artifact handling remains correct.
5. For the 6.18.50 LTS kernel, rerun the affected MD RAID10 + LUKS + LVM boot validation and verify the MD metadata compatibility path still works.
6. Verify an affected LTS GRUB entry receives `md_mod.check_new_feature=0` only when required, while normal/current kernel entries do not receive it.
7. Perform at least one successful reboot into each updated kernel before declaring the kernel refresh complete for RC1.

### Status

**OPEN — both BFSOS kernel ports became one point release stale on 2026-09-07 and are queued for the next tracker/source pass before RC1.**


---

## r258 Tracker Update — Restore compatibility symlinks for packages installed under `/opt`

### [ ] OPEN / PRE-RC1 — Audit and restore the intended `/usr` compatibility symlink layer for `/opt`-prefixed packages such as Qt5 and Qt6

During the current full desktop-stack install/validation, it was noticed that packages intentionally installed under `/opt` no longer expose the compatibility symlinks that BFSOS previously used for normal tool/runtime discovery. Qt5 and Qt6 are the immediate examples. The reason those links disappeared is not currently known and must be traced rather than assuming the removal was intentional.

### Required work

- Audit the current `qt5` and `qt6` ports, their post-install logic, `aaa_filesystem`/base-files handling, installer/bootstrap prefix setup, and any cleanup logic that may have removed or stopped creating the historical compatibility links.
- Compare the current installed layout with the last known-good BFSOS layout and restore the intended symlink set for Qt5 and Qt6.
- Audit other packages deliberately installed under `/opt` and identify which ones historically relied on public compatibility links into standard locations such as `/usr/bin`, `/usr/lib`, `/usr/include`, `/usr/share`, `pkg-config`, or CMake discovery paths.
- Restore only the links that are part of the BFSOS compatibility/prefix policy. Do **not** blindly mirror entire `/opt` trees into `/usr` or create links that collide with real files owned by another package.
- Keep the canonical package payload under its intended `/opt/...` prefix; the `/usr` side should be a compatibility/discovery layer, not a second copy of the package.
- Make ownership explicit so every compatibility link is attributable to the package that owns its target and is removed/updated correctly on package upgrade or uninstall.
- Ensure package upgrades recreate/update the links atomically and do not leave stale links pointing at removed versioned files or old prefixes.
- Preserve side-by-side Qt5/Qt6 operation. Restoring compatibility links must not cause an unversioned command or metadata path to silently select the wrong Qt major version.
- Where a generic unversioned link would be ambiguous, use the established BFSOS versioned naming/prefix policy rather than forcing Qt5 and Qt6 to compete for the same path.
- Verify that the existing BFSOS environment policy (`QT5DIR`, `QT6DIR`, `CMAKE_PREFIX_PATH`, `PKG_CONFIG_PATH`, PATH handling, and sudo-preserved build variables where applicable) remains consistent with the restored symlink policy instead of becoming a second conflicting discovery mechanism.

### Validation

After restoring the policy, install Qt5 and Qt6 from a clean/minimal BFSOS environment and verify:

1. The canonical Qt5 and Qt6 files remain under their intended `/opt` prefixes.
2. The expected BFSOS compatibility symlinks exist and resolve to valid targets.
3. `readlink -f` on every restored link resolves inside the package that owns it and no restored link is dangling.
4. Representative Qt5 and Qt6 build tools can be found without ad-hoc manual symlink creation.
5. `pkg-config` and CMake can discover the intended Qt major version through the normal BFSOS environment/prefix policy.
6. Installing both Qt5 and Qt6 together does not overwrite or redirect the other major version's tools, libraries, headers, CMake metadata, or pkg-config metadata.
7. Updating either Qt package refreshes its links without leaving stale targets.
8. Removing one Qt major version removes only its own links and does not damage the other version.
9. Re-run representative Plasma/LXQt/Qt application builds after the links are restored to catch any package that had been depending on the old compatibility layout.
10. Extend the same audit to other `/opt`-prefixed packages and document which links are intentional parts of BFSOS policy.

### Status

**OPEN — restore and regression-test the historical compatibility symlink layer for Qt5/Qt6 and audit other `/opt`-prefixed packages before RC1. The current disappearance of those links is unexplained and should be traced during the next source pass.**

---

## r259 Tracker Update — Discord was missed by the maintained-port update/version sweep

### [ ] OPEN / NEXT TRACKER PASS — Update Discord and make sure the maintained-port updater/checker cannot silently omit it again

During the current pre-RC1 validation it was noticed that the BFSOS Discord port is still stale even though the maintained-port update/version-audit pass was supposed to cover the maintained application set. Treat this as both a package-refresh item and a coverage regression in the update tooling.

### Required work

- Locate the BFSOS `discord` port and compare its packaged version against the current appropriate stable Discord Linux release at the time this item is worked.
- Update the Discord port to the current stable release, including version/release metadata, source URL, checksums/signatures, extraction/install logic, desktop file/icon handling, and any runtime dependencies that changed upstream.
- Audit the maintained-port update/version-check scripts and their package enumeration/input lists to determine why `discord` was not reported or updated during the previous maintained-port sweep.
- If Discord is currently absent from an explicit maintained-port manifest/list, add it.
- If Discord was enumerated but skipped because its upstream/version source is unusual, add or correct the provider/parser logic instead of leaving a permanent silent exception.
- If Discord is intentionally handled as a binary/vendor package rather than a normal source-built port, make that policy explicit in the checker so it is still version-audited even if its update mechanics differ from ordinary ports.
- Ensure Discord is included in the normal maintained-port audit output with an explicit status such as `CURRENT`, `UPDATE`, `UNVERIFIABLE`, or `ERROR`; it must not disappear from the report without explanation.
- Review the maintained-port list for any other manually maintained desktop/application ports that may have been omitted for the same reason.
- Add a coverage check that compares the intended maintained-port inventory with the ports actually examined by the checker/updater and fails or warns loudly when an expected maintained port is missing from the run.
- Keep automatic Pkgfile rewriting reviewable: version detection can be automated, but package updates still need the normal BFSOS source/build/runtime validation before being considered complete.

### Validation

1. Run the maintained-port version audit and confirm `discord` appears in the output.
2. Confirm the checker correctly distinguishes the installed/packaged Discord version from the current stable upstream Linux release.
3. Update/build/package/install Discord through the normal BFSOS ports path.
4. Launch Discord on a desktop session and verify basic startup, login UI rendering, audio/video device discovery where available, notifications/desktop integration, and update-related behavior does not try to bypass BFSOS package ownership.
5. Re-run the maintained-port audit and confirm Discord reports `CURRENT`.
6. Run the maintained-port inventory/coverage check and confirm no expected maintained port is silently omitted.
7. Add Discord to the checker regression set so future script changes cannot drop it unnoticed.

### Status

**OPEN — Discord was missed by the previous maintained-port update/version pass. Update the port and fix the updater/checker coverage so Discord, and any similarly omitted maintained ports, cannot silently fall out of future audits before RC1.**

---

## r260 Tracker Update — Version updater left a stale Requests patch after the package version refresh

### [ ] OPEN / NEXT TRACKER PASS — Make maintained-port version updates audit and validate patches/source-side companion files, not just `version=` metadata

During the current full desktop/world installation, `core/python3-requests` was already at `2.34.2`, but its source array still carried the older version-specific patch:

```text
requests-2.32.2-use_system_certs-1.patch
```

The package therefore downloaded Requests 2.34.2 successfully and then failed immediately while applying that stale patch. The failed hunks included `src/requests/certs.py`, `setup.cfg`, and `setup.py`.

This is a maintained-port update regression: the version refresh correctly moved Requests to 2.34.2, but the update pass did not review whether the package's patches and other companion source files still matched the new upstream source.

### Immediate Requests repair to preserve

- Replace the stale Requests 2.32.2 system-certificate patch with a patch that applies cleanly to the current Requests release being packaged.
- Keep BFSOS's intended system CA / `make-ca` / `p11-kit` integration rather than simply dropping the certificate-policy patch to make the package compile.
- Bump the package `release` for the recipe-content change.
- Keep the Python build/install path fail-fast so a backend, patch, wheel-build, or installer error stops the package immediately.
- Build/install `python3-requests` cleanly and then resume the full desktop dependency sweep.

### Required updater/checker hardening

When a maintained port's upstream version changes, the update tooling must also inventory and review every package-local file referenced by the `Pkgfile`, including:

- patches;
- versioned patches;
- local config fragments;
- helper scripts;
- generated source substitutions;
- renamed source archives;
- vendor fixes;
- desktop/service files when upstream layout changes;
- any source-array item whose filename embeds the old upstream version.

For every version change:

1. Parse the complete `source=()` array and identify local companion files as well as remote archives.
2. Flag any referenced local filename containing the previous package version.
3. Search patch headers/context and obvious embedded version strings for references to the previous upstream release.
4. Confirm every referenced local file still exists after the version bump.
5. Apply every patch in a clean extracted source tree as a pre-build validation step, or perform an equivalent dry-run/applicability check.
6. Treat a failed patch as an update failure, not as a successful version refresh.
7. Detect patches that target files removed or replaced upstream, such as legacy `setup.py` / `setup.cfg` packaging files after a project moves to `pyproject.toml`.
8. Require the audit report to distinguish at least:
   - version current and patch set validated;
   - version updated and patch set validated;
   - stale/version-specific patch requires maintainer review;
   - patch applicability failure;
   - missing local companion source;
   - unverifiable/manual review required.
9. Do not mark a package fully updated/current merely because the upstream version number matches when its maintained patch set has not been validated against that source.
10. Keep automatic rewriting conservative: the tooling may flag or prepare changes, but do not silently discard distribution patches simply because they stop applying.

### Repository-wide follow-up

Audit every port changed by the recent maintained-version refresh for the same class of regression.

At minimum, search for:

- patch filenames containing old package versions;
- `source=()` entries whose local file names reference superseded versions;
- patches that no longer apply to the current source;
- build recipes still referring to files removed by upstream modernization;
- version bumps where `release`, dependencies, build backend, or package layout should also have changed.

The recent Python failures make this especially important for projects that moved from legacy setuptools `setup.py`/`setup.cfg` builds to `pyproject.toml`/PEP 517 backends, but this validation must apply to all maintained ports, not only Python packages.

### Regression coverage

Add a maintained-port updater regression case that deliberately models:

```text
old package version + old-version-named patch
        ↓
upstream version bump
        ↓
patch no longer applies
```

The test must fail the update audit until the patch is replaced, rebased, intentionally removed with review, or otherwise proven applicable to the new source.

Also include a positive case where a versioned patch continues to apply unchanged, so the checker does not assume every old-looking filename is automatically invalid.

### Validation

1. Fix and successfully build/install `python3-requests` at the current packaged version.
2. Confirm its system-certificate behavior still follows BFSOS policy.
3. Run the new companion-file/patch audit against `python3-requests` and confirm it passes.
4. Run the same audit over all ports modified by the last version-refresh pass.
5. Resolve every stale patch, missing companion source, and patch-applicability failure found.
6. Re-run the complete maintained-port audit and require zero silent patch-validation omissions.
7. Run the regression suite and confirm a stale Requests-style patch causes a hard audit failure before the package reaches the long build phase.

### Status

**OPEN / PRE-RC1 TOOLING HARDENING — Requests 2.34.2 exposed that the maintained-port version updater can refresh `version=` while leaving a stale version-specific patch behind. Fix Requests now, then make patch/companion-file validation a required part of every future maintained-port version refresh.**
## r261 Tracker Update — Vendor remote patch URLs into each port during maintained-port updates

### [ ] OPEN / PRE-RC1 TOOLING HARDENING — Make the port updater download required patches into the port directory and replace remote patch URLs with local patch filenames

BFSOS packaging policy should not depend on a third-party patch URL remaining available indefinitely. Patch files have repeatedly moved, disappeared, or been replaced upstream while an older BFSOS port still legitimately needs the original fix. A port that requires a patch must therefore carry the exact patch in its own directory and in the BFSOS repository.

The maintained-port updater must enforce this policy whenever it encounters a remotely hosted patch or diff in a `Pkgfile`.

### Required updater behavior

For every maintained port inspected or updated:

1. Parse the complete `source=()` array and identify remote patch-like sources, including ordinary `.patch` / `.diff` URLs and patch-download endpoints whose final downloaded filename or content is a patch.
2. Download each required remote patch into that port's directory before rewriting the `Pkgfile`.
3. Use a stable local filename. Prefer the upstream filename when it is useful and unambiguous; when necessary, generate a package/version-specific name that makes the patch's purpose clear.
4. Replace the remote patch URL in `source=()` with only the local patch filename.

For example, convert:

```bash
source=(https://example.org/project/project-$version.tar.xz
        https://example.org/patches/project-fix.patch)
```

into:

```bash
source=(https://example.org/project/project-$version.tar.xz
        project-fix.patch)
```

with:

```text
ports/<collection>/<port>/project-fix.patch
```

present locally and committed with the port.

5. Preserve patch provenance in a comment or other updater-managed metadata so a maintainer can determine where the vendored patch originally came from even though the build no longer depends on that URL.
6. Download atomically: fetch to a temporary file, validate it, then move it into the port directory. A failed or partial download must never leave a truncated patch behind.
7. Reject empty files, HTML error pages, login pages, redirect/error responses, and other obviously invalid patch downloads.
8. Do not silently overwrite an existing local patch with different content. If the target filename already exists:
   - if the content is identical, reuse it;
   - if the content differs, stop and require review or choose a clearly distinct filename.
9. After vendoring the patch, validate that it applies to the exact source version being packaged using the same patch strip level/build behavior the port will use.
10. A patch that downloads successfully but does not apply must make the maintained-port update fail/audit as needing maintainer review.
11. The updater must include the new local patch and the rewritten `Pkgfile` in its reported change set so the maintainer cannot accidentally commit one without the other.
12. Do not apply this rule to normal upstream source tarballs, release archives, or other large source payloads. This policy is specifically for patches/diffs and similar small source-side fixes that BFSOS needs to preserve.
13. Package build functions must not compensate by running ad-hoc `curl`/`wget` commands to fetch required patches during `pkg_build()`. Required patches belong in `source=()` and, after updater normalization, in the port directory.

### Interaction with version updates

This requirement extends the r260 patch/companion-file audit.

When a package version changes, the updater must treat every vendored patch as maintained package state:

- determine whether the patch is still required;
- test whether it still applies;
- replace/rebase it when upstream changed;
- remove it only after explicit validation that upstream incorporated the fix or the patch is otherwise obsolete;
- flag old-version-named patches for review rather than blindly carrying them forward;
- never mark the port fully current merely because `version=` matches upstream while its patch set is stale, missing, or unvalidated.

If an updated patch is found only at a remote URL, the updater should download the replacement into the port directory and rewrite `source=()` to the local filename in the same operation.

### Repository-wide migration

Audit the existing BFSOS ports tree for remotely referenced patch/diff files and migrate them to this policy.

The migration should report at least:

- port path;
- original remote patch URL;
- resulting local patch filename;
- download/validation status;
- patch applicability status;
- whether the `Pkgfile` was rewritten;
- any collision, ambiguity, or manual-review condition.

Do not delete or replace an existing local patch merely because a newer remote patch exists. Version/applicability review comes first.

### Regression coverage

Add updater tests covering at least:

1. A normal remote `.patch` URL is downloaded into the port directory and `source=()` is rewritten to the basename.
2. A remote `.diff` URL receives the same treatment.
3. A redirecting patch URL is resolved and the final patch is vendored correctly.
4. A patch endpoint without a `.patch` suffix is recognized when the downloaded content is a valid patch.
5. A 404/error/HTML response fails without modifying the `Pkgfile`.
6. An existing identical local patch is reused safely.
7. An existing same-name but different patch causes a collision/review failure rather than being overwritten.
8. A successfully downloaded patch that does not apply to the new source version is rejected by the update audit.
9. A version update that replaces an old remote patch with a new upstream patch vendors the new patch and rewrites the `Pkgfile` in one transaction.
10. A normal source archive URL remains remote and is not copied into the Git repository.

### Validation

1. Run the migration audit over all maintained ports.
2. Require zero build-required remote patch URLs after approved migrations are complete.
3. Confirm every migrated port has the patch physically present in its port directory.
4. Confirm every migrated `source=()` references the local filename rather than the remote patch URL.
5. Run patch applicability checks against the exact packaged source versions.
6. Re-run the maintained-port updater and confirm it does not reintroduce remote patch URLs.
7. Verify a clean checkout can build patched ports without needing the original third-party patch host to remain online.

### Status

**OPEN / PRE-RC1 TOOLING HARDENING — extend the r260 patch audit so the maintained-port updater vendors required remote patches into each port, rewrites patch URLs to local filenames, preserves provenance, validates applicability, and keeps patch lifecycle changes tied to package-version updates.**
## r262 Tracker Update — Allow Firefox, Firefox-ESR, and Firefox-bin to coexist

### [ ] OPEN — Make all three Firefox package variants simultaneously installable with distinct identities and filesystem paths

BFSOS should support installing all three Firefox variants on the same system at the same time:

- **Firefox**
- **Firefox-ESR**
- **Firefox-bin**

They must not conflict merely because they are Firefox variants. Each package should retain its own clearly visible name and launch independently.

### Required package identities

Use the following user-facing/application identities:

```text
Firefox
Firefox-ESR
Firefox-bin
```

Use distinct package/launcher names and avoid generic path collisions. The intended command layout is:

```text
/usr/bin/firefox
/usr/bin/firefox-esr
/usr/bin/firefox-bin
```

The installed application directories should likewise be separate, for example:

```text
/usr/lib/firefox/
/usr/lib/firefox-esr/
/usr/lib/firefox-bin/
```

Do not let `firefox-esr` or `firefox-bin` overwrite files owned by the normal `firefox` package.

### Desktop integration

Each variant must install a separate desktop entry with its own visible application name:

```text
Firefox
Firefox-ESR
Firefox-bin
```

Use distinct desktop-entry filenames, for example:

```text
/usr/share/applications/firefox.desktop
/usr/share/applications/firefox-esr.desktop
/usr/share/applications/firefox-bin.desktop
```

Audit and separate any other colliding shared files, including:

- icons and icon-cache names;
- man pages;
- shell completion files;
- MIME/default-browser registration files;
- application metadata;
- policy/configuration directories;
- crash/reporting helpers;
- updater helpers;
- any `/usr/lib/firefox*` symlinks or generic launchers.

Where a shared resource is legitimately identical and safe to share, document that explicitly rather than relying on accidental file overlap.

### Process/remoting isolation

Normal Firefox, Firefox-ESR, and Firefox-bin should not incorrectly hand a launch request to a different installed variant.

Give each variant a distinct remoting/application identity where supported, for example:

```text
Firefox      -> firefox
Firefox-ESR  -> firefox-esr
Firefox-bin  -> firefox-bin
```

For source-built Mozilla variants, set the appropriate remoting/application build identity so a running Firefox release process does not capture an ESR launch and vice versa.

### Profile isolation

Do not force all three variants to use the same mutable browser profile.

Provide or document separate default profile roots/launch behavior so testing one variant cannot silently migrate or damage another variant's profile. A suitable model is:

```text
~/.mozilla/firefox/
~/.mozilla/firefox-esr/
~/.mozilla/firefox-bin/
```

If Mozilla's native profile-management behavior makes a different layout preferable, preserve the same requirement: the three package variants must be safely usable side by side without one variant automatically taking ownership of another variant's profile data.

Do not solve profile isolation by hard-coding a single profile directory in a way that breaks normal Firefox profile-manager functionality. Preserve the ability to select/manage multiple profiles.

### Default-browser handling

Coexistence must not mean all three packages fight over the system default browser.

- Installing one variant must not automatically delete or replace another variant.
- Desktop/MIME registration should expose all installed variants.
- The user's selected default browser should remain a separate choice.
- If BFSOS later provides an alternatives/default-browser selector, it should select among the installed variants without changing package ownership.

### Package-manager requirements

1. Remove unnecessary package conflicts between `firefox`, `firefox-esr`, and `firefox-bin`.
2. Ensure the three package footprints contain no unintended file collisions.
3. If any collision is unavoidable, redesign the package layout rather than permitting one package to overwrite another package's files.
4. `prt-get depinst firefox firefox-esr firefox-bin` should be able to resolve and install all three on one clean system.
5. Updating or removing one variant must not remove files belonging to either of the other two variants.

### Validation

On a clean BFSOS VM:

```bash
sudo prt-get depinst firefox firefox-esr firefox-bin
```

Then verify:

```bash
command -v firefox
command -v firefox-esr
command -v firefox-bin
```

Confirm all three desktop entries are present and display exactly:

```text
Firefox
Firefox-ESR
Firefox-bin
```

Launch each variant independently and verify:

1. all three can start;
2. one running variant does not capture launch requests intended for another;
3. profiles remain isolated/safe across variants;
4. each variant reports the expected release/channel;
5. default-browser selection can point to any one of the three without uninstalling the others;
6. updating one package leaves the other two functional;
7. removing one package leaves the other two launchers, application directories, desktop entries, and profiles intact.

Also perform a package-footprint collision audit before installation and after upgrades.

### Status

**OPEN — redesign the Firefox family ports so Firefox, Firefox-ESR, and Firefox-bin are first-class coexistable packages with distinct names, launchers, application directories, desktop entries, remoting identities, and safe profile handling.**
## r263 Tracker Update — Add Chromium as a maintained BFSOS port

### [ ] OPEN / POST-RC1 OR WHEN BROWSER STACK IS READY — Add a native Chromium port

Add **Chromium** as a maintained BFSOS browser port so BFSOS has a second major open-source browser family alongside Firefox.

### Initial goals

Create a first-class source port named:

```text
chromium
```

with a normal launcher:

```text
/usr/bin/chromium
```

and desktop entry:

```text
/usr/share/applications/chromium.desktop
```

The visible application name should be:

```text
Chromium
```

### Packaging requirements

- Build Chromium from source rather than wrapping another distro's package.
- Keep Chromium independent from the Firefox / Firefox-ESR / Firefox-bin package family.
- Audit all required build dependencies, including LLVM/Clang, Python, Node/npm tooling where required, GN/Ninja, graphics/media libraries, sandbox support, NSS, ICU, codecs, Wayland/X11 integration, and any Rust/toolchain requirements present in the targeted Chromium release.
- Prefer BFSOS system libraries where upstream Chromium supports them reliably, but do not force system-library substitutions that create fragile or unsupported builds.
- Keep bundled third-party libraries where Chromium's build system requires or strongly expects them; document deliberate bundled-vs-system choices.
- Build with Wayland and X11 support appropriate for BFSOS desktop environments.
- Ensure hardware acceleration, VA-API/video decode support, Vulkan/OpenGL paths, and Mesa integration are evaluated on supported hardware.
- Ensure Chromium's sandbox is functional and not disabled merely to make the package launch.
- Do not ship unsafe convenience flags such as `--no-sandbox` in the desktop launcher.
- Disable Chromium's self-updater if it would conflict with BFSOS package ownership; browser updates should come through the BFSOS package manager.
- Keep `/usr/lib/chromium` and related resources package-owned and isolated from any future `chromium-bin` or Google Chrome package should BFSOS ever add those separately.
- Provide proper MIME/URL-handler desktop integration without forcibly replacing the user's selected default browser.

### Source and patch policy

Chromium must follow the same BFSOS patch-preservation policy as other maintained ports:

- required patches live in the Chromium port directory;
- remote patch URLs are vendored locally by the maintained-port updater;
- patch provenance is preserved;
- stale patches are reviewed on every Chromium version update;
- the updater must not mark Chromium current solely because the version number matches upstream if its patch set is stale or unvalidated.

### Version updater considerations

Chromium's release cadence is fast, so the maintained-port updater must be able to:

- determine the current stable Chromium release;
- distinguish stable from beta/dev/canary channels;
- update the source URL/version correctly;
- audit local patches and version-specific build workarounds;
- flag toolchain minimum-version changes;
- flag removed or renamed GN args;
- flag dependency changes that require BFSOS port metadata updates;
- avoid silently carrying forward old Chromium patches or GN options.

### Validation

On a clean BFSOS VM and later on bare metal:

1. Build and install `chromium` from the BFSOS port.
2. Launch from both `/usr/bin/chromium` and the desktop menu.
3. Verify normal browsing and HTTPS certificate validation.
4. Verify the sandbox is active.
5. Verify audio through the default PipeWire/WirePlumber stack.
6. Verify Wayland operation under Plasma/GNOME and X11/XWayland fallback where applicable.
7. Verify WebGL/OpenGL/Vulkan acceleration.
8. Verify hardware video decode/VA-API where supported.
9. Verify file downloads, uploads, printing, password-store integration, and desktop notifications.
10. Verify package upgrade and removal leave no files owned by unrelated browser packages.
11. Run a browser sanity comparison against Firefox on the same BFSOS installation.

### Status

**OPEN — add Chromium as a maintained native BFSOS source port. This does not need to block the first RC unless Chromium becomes part of the explicit RC browser scope; Firefox remains sufficient for the initial browser requirement.**
## r264 Tracker Update — Investigate intermittent/static `pkgadd` upgrade segfaults before changing CRUX-style linkage policy

### [ ] OPEN / PACKAGE-MANAGER RELIABILITY — Reproduce and diagnose `pkgadd -u` / `pkgadd -u -f` segmentation faults

During the current full-system package sweep, BFSOS exposed a package-manager failure while repairing/reinstalling CUPS and pkgutils.

Observed behavior:

```text
sudo pkgadd -u -f /var/cache/pkg/packages/cups#2.4.19-2.pkg.tar.zst
Segmentation fault
```

A freshly rebuilt `pkgutils` 5.40.12 package was then produced successfully, but reinstalling/updating pkgutils through `prt-get` failed at the package-install stage. Extracting the newly built `pkgadd` binary from the package and running it directly also reproduced the crash on an upgrade path.

The normal BFSOS/CRUX pkgutils build currently links `pkgadd` fully statically:

```text
g++ ... -o pkgadd -static -larchive -lacl -lexpat -lzstd -lbz2 -lz -llzma -lcrypto -ldl -pthread
```

The linker also emits glibc warnings for NSS/user/group lookup functions such as:

```text
getgrgid
getgrnam_r
getpwnam_r
getpwuid
```

stating that statically linked applications still require the shared libraries from the glibc version used for linking.

A temporary diagnostic build with `-static` removed successfully produced a dynamically linked `pkgadd`, but this tracker must **not** assume the static link is the root cause until an A/B runtime test reproduces the same package operation under both binaries.

Also note: `pkgadd` has subsequently been able to reinstall packages while remaining statically linked, so the failure is currently **intermittent or path/data dependent**, not proven to be "all static pkgadd builds are broken."

### Required investigation

1. Preserve the current CRUX-compatible static-link behavior until the failure is understood.
2. Build a reproducible test matrix for:
   - fresh install;
   - `pkgadd -u`;
   - `pkgadd -u -f`;
   - reinstalling the same version;
   - updating to a newer release;
   - package with missing live files but intact package database;
   - package with pre/post-install hook failure history;
   - updating/reinstalling `pkgutils` itself.
3. Run the same operations using:
   - the normal fully static `pkgadd`;
   - a locally built dynamic `pkgadd`;
   - if practical, a debug/unstripped static `pkgadd`.
4. Record whether the segfault depends on:
   - specific package contents;
   - package database state;
   - missing files on the live filesystem;
   - force-update mode;
   - self-update of pkgutils;
   - hook status;
   - ownership/user/group lookups;
   - libarchive extraction/overwrite behavior.
5. Capture a backtrace from a debug build when the crash is reproducible:
   - enable core dumps or use `gdb`;
   - do not rely only on the final `Segmentation fault` message;
   - identify the exact function and data path causing the fault.
6. Check whether CRUX carries, historically carried, or expects a glibc/static-link compatibility patch for pkgutils.
7. Compare BFSOS glibc, libarchive, ACL, compression libraries, OpenSSL, compiler/linker, and pkgutils build flags with the CRUX combination known to work.
8. Investigate whether BFSOS needs:
   - a glibc patch;
   - a pkgutils patch;
   - a libarchive-related fix;
   - a narrower/static-library-only link strategy;
   - or a dynamic `pkgadd`.
9. Do **not** apply a glibc patch merely because static-link warnings exist. Require a reproducible crash and evidence that the candidate patch fixes the actual failing path.
10. If a glibc patch becomes necessary, vendor it in the BFSOS glibc port according to the r261 patch-preservation policy, preserve provenance, and add a regression test that demonstrates the pkgadd failure before the patch and success after it.
11. If the correct fix is in pkgutils instead, patch pkgutils rather than modifying glibc globally.
12. If BFSOS ultimately changes `pkgadd` to dynamic linkage, document why BFSOS intentionally diverges from the inherited CRUX static-link design and test package-manager recovery behavior during partial upgrades.

### CUPS / FreeRDP incident context

This investigation was triggered while FreeRDP failed to configure because the live system was missing CUPS headers/libraries even though:

- the CUPS package archive contained them;
- the package database listed CUPS as owning them.

CUPS was subsequently reinstalled successfully and FreeRDP then installed successfully.

Keep this distinction clear:

```text
CUPS package archive: valid / contained expected files
CUPS reinstall: ultimately succeeded
FreeRDP: installed successfully after CUPS repair
pkgadd segfault: remains a separate package-manager reliability issue
```

Do not treat the CUPS package recipe itself as corrupt based on the earlier `pkgadd` crash.

### Validation / exit criteria

This item is not complete until we can state which of the following is true with a reproducible test:

```text
A. pkgadd bug fixed in pkgutils
B. glibc/static-link compatibility issue fixed
C. dependent static library/toolchain issue fixed
D. dynamic linkage intentionally adopted
E. another package-database/filesystem-state bug identified and fixed
```

Then verify:

1. `pkgadd -u` succeeds repeatedly.
2. `pkgadd -u -f` succeeds repeatedly.
3. pkgutils can update/reinstall itself without crashing.
4. a package whose files are missing from the live root can be repaired safely.
5. package database ownership remains consistent with the live filesystem.
6. `prt-get update` / `prt-get -fr update` properly propagates any package-manager failure instead of leaving ambiguous state.
7. the package-manager regression test runs as part of the BFSOS pre-RC validation suite.

### Status

**OPEN — pkgadd upgrade/reinstall segfault observed and reproduced with a freshly rebuilt static binary, but later static reinstalls have also succeeded. Root cause is not yet proven. Investigate pkgutils vs glibc/static-linking vs package-state behavior before changing linkage policy or applying a glibc patch.**

---

## r265 Tracker Update — Per-port disk-backed build-work override for oversized packages

### [ ] OPEN / PRE-RC BUILD-SYSTEM HARDENING — Automatically bypass the build-work tmpfs for packages whose working set exceeds the safe tmpfs ceiling

### New live evidence — Qt6 6.11.2 exceeds the 32G build-work tmpfs

The previous installer sizing work intentionally raised a roughly 61 GiB-RAM machine from a 16G build-work tmpfs to a 32G tmpfs. Live Qt6 `6.11.2-8` validation has now shown that **32G is still insufficient for at least one real BFSOS package build**.

The Qt6 build configured successfully, passed the earlier protobuf/QtGRPC blocker, and reached approximately:

```text
7411 / 12029 Ninja build steps
```

before the compiler and assembler repeatedly failed with:

```text
No space left on device
fatal error: cannot write PCH file
fatal error: closing dependency file ... No space left on device
Fatal error: can't write ... No space left on device
```

This is a workspace-capacity failure, not a Qt6 source/compiler failure.

### Relationship to the existing automatic tmpfs sizing item

Keep the existing automatic tmpfs sizing policy for ordinary packages. Do **not** respond to this failure by simply making the default tmpfs larger than is safe for the machine's physical RAM.

For example, on a host with about 61 GiB of physical RAM, increasing the automatic tmpfs ceiling far beyond 32G can turn a disk-capacity failure into avoidable memory pressure/OOM behavior. The correct next layer is a **per-port large-build escape hatch** that uses disk-backed build-work when a package is known to exceed the safe tmpfs ceiling.

The earlier r253 statement that 32G is the automatic choice for roughly 61 GiB RAM therefore remains a reasonable general default, but it is **not sufficient as a universal capacity guarantee for every port**.

### Preferred implementation model

Investigate and implement a centralized per-port build-work backend override in `pkgutils`/`bfs-pkgmk` rather than duplicating shell mount logic in individual ports.

Conceptually, a port that requires disk-backed workspace should be able to declare one simple piece of metadata, for example:

```text
build_work=disk
```

or another project-consistent variable chosen after auditing the existing extension namespace. **Do not lock in the example variable name until the current pkgutils extension is checked for an existing mechanism.**

The centralized wrapper should switch the backing store **before `pkgmk` creates/extracts the package build tree** and restore the normal tmpfs after the build attempt ends.

### Do not use package `pre-install` / `post-install` hooks for this

A package `pre-install` hook runs around package installation, after the expensive source build has already happened. It is therefore too late to solve build-work exhaustion.

The backend switch belongs in the package-build lifecycle, such as `bfs-pkgmk` or the pkgmk extension/wrapper path that runs before the per-package work directory is populated.

### Safe tmpfs-to-disk transition using the existing fstab entry

If `/var/cache/pkg/build-work` is currently a tmpfs and the selected port requires disk-backed workspace, the implementation should prefer using the existing `/etc/fstab` entry as the source of truth rather than rewriting fstab for every build.

A safe lifecycle is conceptually:

```text
1. acquire an exclusive build-work backend lock
2. confirm no other package build is using /var/cache/pkg/build-work
3. record the current mount type/source/options
4. unmount the tmpfs before creating the new package work tree
5. use the underlying /var/cache/pkg/build-work directory on its disk-backed parent filesystem
6. build/package the selected port
7. clean the package work tree according to normal pkgmk policy
8. remount /var/cache/pkg/build-work using its existing fstab definition
9. release the lock
```

For the restore step, prefer behavior equivalent to:

```bash
mount /var/cache/pkg/build-work
```

so the configured fstab options/size remain authoritative. Do not hard-code a second copy of the tmpfs size/options in the per-port logic.

### Required safeguards

- Never unmount `/var/cache/pkg/build-work` while another process/build has open files beneath it.
- Serialize backend switching with an explicit lock; concurrent package builds must not race a mount transition.
- Refuse the transition if the mount cannot be safely unmounted.
- Verify the underlying disk-backed filesystem has enough free bytes **and inodes** before beginning a known-large build.
- Preserve the expected build-work directory ownership/mode on both the mounted tmpfs and the underlying directory.
- Use `trap`/equivalent cleanup so the configured tmpfs is remounted after success, build failure, interruption, or ordinary wrapper exit.
- If the remount fails, report it loudly and return a failure status rather than silently leaving the machine in a changed build-work state.
- Do not edit/remove the persistent fstab entry merely to run one package build.
- If build-work is already disk-backed, the override should be a no-op.
- If the administrator explicitly selected disk-backed build-work globally, do not mount tmpfs merely because the large package has finished.
- Do not destroy unrelated/stale work directories until normal pkgmk cleanup policy says they may be removed.
- Keep source/package caches (`/var/cache/pkg/sources`, `/var/cache/pkg/packages`) separate from this temporary backend decision.

### Candidate-port audit

`qt6` is **confirmed** to require review for the disk-backed override because the live `6.11.2-8` build exhausted a 32G tmpfs before completion.

Audit the following existing or planned heavy builds and measure their peak build-work consumption before deciding whether they should automatically request disk-backed build-work:

```text
qt6                         CONFIRMED capacity problem at 32G
QtWebEngine / QtWebEngine5  audit
firefox                     audit
firefox-esr                 audit
LLVM/Clang                  audit
linux                       audit
linux-lts                   audit
rustc                       audit
Chromium                    audit when the maintained source port is added
```

Also scan the maintained ports for other exceptionally large source/build trees rather than maintaining this list only by memory. A port should receive the override because measured/credible peak workspace demand warrants it, not merely because the package is generally considered "large."

### Better long-term option to evaluate

During implementation, compare the unmount/remount approach with a centralized alternate work-root design, for example placing selected large builds under a dedicated disk-backed directory while leaving the tmpfs mount untouched.

The chosen design should minimize global mount-state changes while preserving existing pkgmk expectations around `$PKGMK_WORK_DIR`. If an alternate-work-root implementation is clean and compatible, prefer it over mount manipulation. If pkgmk requires the canonical path, the locked unmount/build/remount approach above is acceptable with the required safeguards.

### Regression / live validation

1. On a machine where Auto selects a 32G tmpfs, verify an ordinary package still builds in tmpfs.
2. Verify a marked large package switches to disk-backed build-work **before extraction/configure/build begins**.
3. Build Qt6 6.11.2 (or the current Qt6 release at test time) beyond the previous ~7411/12029 failure point and through package creation/install.
4. Verify the build does not fail from the prior 32G tmpfs ENOSPC condition.
5. Force a package build failure and verify the tmpfs is still restored automatically afterward.
6. Interrupt a marked build and verify the tmpfs is restored automatically afterward.
7. Verify a concurrent/second build cannot race the backend switch.
8. Verify insufficient underlying disk space is detected before a very large build begins.
9. Verify the restored tmpfs uses the configured `/etc/fstab` options rather than hard-coded defaults.
10. Verify a globally disk-backed installer choice is preserved and never replaced by tmpfs after the package finishes.
11. Measure peak workspace usage for the candidate-port audit and maintain the per-port override list from real data.

### Status

**OPEN / PRE-RC BUILD-SYSTEM HARDENING — 32G tmpfs is now proven insufficient for Qt6 6.11.2 on the live BFSOS VM. Keep automatic tmpfs sizing for normal builds, but add a centralized per-port disk-backed build-work path for confirmed oversized packages. Do not implement this with package pre/post-install hooks because they occur too late in the lifecycle.**

---

## r265 Validation Update — Protobuf static archive exception fixed the Qt6/QtGRPC blocker

### [x] LIVE FIX CONFIRMED — Preserve protobuf's required `libupb.a` while keeping protobuf shared libraries enabled

The protobuf `36.1` port was producing shared protobuf libraries correctly with:

```text
-D protobuf_BUILD_SHARED_LIBS=ON
```

but the BFSOS pkgutils extension removes staged `*.a` archives by default unless the port sets the established exception:

```text
keep_static=1
```

Protobuf's installed CMake export advertises `protobuf::libupb` as `/usr/lib/libupb.a`, so removing that archive produced an internally inconsistent protobuf development package and caused Qt6 `qtgrpc` configuration to fail.

The corrected protobuf port keeps shared-library mode enabled **and** sets `keep_static=1`, with the package release bumped for the payload change.

The subsequent Qt6 6.11.2 build configured `qtgrpc` successfully and advanced thousands of Ninja steps until the unrelated 32G build-work capacity failure. That is live confirmation that the protobuf/libupb blocker is resolved.

### Follow-up hardening

Add or extend package-audit coverage so BFSOS can detect installed CMake/pkg-config metadata that references a static archive removed by generic post-build cleanup. The default policy of removing unnecessary `.a` files remains correct; ports whose installed development metadata genuinely requires a static archive must opt in with `keep_static=1`.

### Status

**FIXED / LIVE-VALIDATED — protobuf remains a shared build, required `libupb.a` is preserved through `keep_static=1`, and Qt6 now passes the previous QtGRPC configure failure.**

---

## r265 Evidence Update — Dynamic `pkgadd` A/B test passed, static-link root cause still unproven

A temporary dynamically linked `pkgadd` built from pkgutils 5.40.12 successfully completed both previously interesting update paths in the current VM state:

```text
pkgadd -u cups#2.4.19-2.pkg.tar.zst        -> status 0
pkgadd -u -f pkgutils#5.40.12-31.pkg.tar.zst -> status 0
```

This makes the fully static linkage path a stronger suspect in the rare/intermittent `pkgadd` segfault investigation, but it still does **not** prove that static linkage is the root cause because later operations using the normal static `pkgadd` have also succeeded.

Keep the r264 package-manager reliability item OPEN. Do not change the distro linkage policy or patch glibc until the failure is reproducible enough to capture the failing function/data path and compare static vs dynamic behavior on the same state.

### Status

**OPEN — dynamic A/B operations passed; static linkage is a stronger suspect, not a proven root cause. Preserve the CRUX-compatible static default until reproducible evidence identifies the fault.**
## r266 Tracker Update — Centralize `/etc/profile.d` ownership for `/opt`-prefixed BFSOS software

### [ ] OPEN / PRE-RC1 PACKAGING OWNERSHIP — Move canonical `/opt` environment setup out of leaf packages and eliminate duplicate profile-script ownership

A live Qt6 `6.11.2-8` build now completes package creation successfully, but installation fails at the package-manager stage because Qt6 attempts to install a profile script that already exists:

```text
=======> Building '/var/cache/pkg/packages/qt6#6.11.2-8.pkg.tar.zst' succeeded.
BFSOS package timing: qt6-6.11.2-8: 8m 01s (status 0)
prt-get: installing qt6 6.11.2-8
etc/profile.d/qt6.sh
pkgadd: listed file(s) already installed (use -f to ignore and overwrite)
prt-get: error while install
```

This is a package-ownership problem, not a Qt6 compilation failure. The current run proves the Qt6 package can now be built; installation is blocked because `/etc/profile.d/qt6.sh` is already present/owned elsewhere.

### Intended BFSOS policy

Treat the stable environment setup for BFSOS's deliberately nonstandard `/opt` prefixes as **base-system integration**, rather than allowing each leaf package to independently install an overlapping `/etc/profile.d/*.sh` file.

Preferred design:

- `aaa_filesystem` owns the canonical BFSOS `/etc/profile.d` scripts for stable distro-defined prefixes such as Qt5, Qt6, Rust, and any other maintained stack intentionally installed outside the normal `/usr` hierarchy.
- Individual leaf packages (`qt5`, `qt6`, `rustc`, etc.) must stop owning/installing those same canonical profile scripts.
- A profile script moved into `aaa_filesystem` should be written so an absent optional package does not leave a harmful environment behind. Where appropriate, guard PATH/library/tool variables on the existence of the corresponding prefix or executable.
- Do **not** create a profile script merely because a package lives under `/opt`; only centralize scripts that are actually required for system-wide discovery/environment setup.
- Package-specific environment files that truly must appear and disappear with one optional package may remain package-owned, but their filenames and ownership must be unique and must not collide with a base-owned canonical script.
- Keep this policy coordinated with the existing `/opt` compatibility-symlink tracker work so PATH/profile setup and `/usr` compatibility links describe the same intended BFSOS layout.

The goal is that the base environment contract is present and known before optional `/opt` packages are installed, while the package manager still has exactly one owner for every path.

### Required repository audit

Audit the full BFSOS tree for all profile scripts and `/opt`-prefixed installs, not just Qt6.

At minimum inspect:

```text
/etc/profile.d/qt5.sh
/etc/profile.d/qt6.sh
Rust/Rustc profile scripts
KF5/KF6 or other KDE integration scripts, if any
other maintained packages installed under /opt
```

Search for all of the following patterns across maintained ports and base files:

```text
/etc/profile.d
profile.d/
-prefix /opt
--prefix=/opt
CMAKE_INSTALL_PREFIX=/opt
QT5PREFIX
QT6PREFIX
RUSTUP_HOME / CARGO_HOME / Rust toolchain path setup
```

Classify every discovered script as one of:

```text
A. canonical BFSOS base environment -> aaa_filesystem owns it
B. package-specific unique environment -> leaf package may own it
C. obsolete/redundant -> remove it
```

Also audit package footprints/archives for duplicate ownership of the same `/etc/profile.d/*` path so this class of failure is caught before a live `pkgadd` operation.

### Migration requirements

Ownership transfer must work on **existing BFSOS installations**, not only fresh installs.

A coordinated transition is required so users do not need `pkgadd -f` to bulldoze through duplicate ownership:

1. Identify the current package owner of each conflicting profile script.
2. Bump releases for every leaf package whose payload changes because its profile script is removed.
3. Add the canonical guarded script(s) to `aaa_filesystem` and bump its release.
4. Define/update package ordering so the old owner relinquishes the path before the new base owner claims it, or provide another package-manager-safe transfer mechanism that preserves database consistency.
5. Do not leave two packages claiming the same file at any point in the final state.
6. Do not solve the problem by globally forcing package overwrites with `pkgadd -f`.
7. Preserve user-modified configuration semantics if any profile scripts are treated as config files by pkgutils.

For a fresh installation, `aaa_filesystem` should install the canonical profile files before Qt5/Qt6/Rust/etc. are installed, and the later leaf-package installs must have no ownership conflict.

### Suggested canonical-script behavior

For base-owned optional prefixes, prefer guarded, POSIX-shell-compatible logic. Conceptually:

```sh
if [ -d /opt/qt6/bin ]; then
    PATH="/opt/qt6/bin:$PATH"
    export PATH
fi
```

The exact variables for Qt5, Qt6, Rust, KF6, and other stacks must be audited from the current BFSOS scripts before consolidation; do not blindly copy stale variables or introduce unnecessary `LD_LIBRARY_PATH` usage if the loader/pkg-config/CMake integration already handles the libraries correctly.

### Automated regression / static checks

Add a pre-RC audit that can flag likely duplicate integration ownership before package installation. It should at least detect multiple maintained ports that install the same `/etc/profile.d/<name>` path.

Where practical, extend this into a broader package-path collision audit for distro integration files under locations such as:

```text
/etc/profile.d
/usr/share/applications
/usr/share/dbus-1
/usr/lib/systemd
/usr/share/polkit-1
```

The first required scope for this tracker item is `/etc/profile.d`; broader collision detection can be implemented incrementally if it remains reliable and does not create false confidence from source-only heuristics.

### Validation / exit criteria

1. On the current BFSOS VM, determine exactly who owns `/etc/profile.d/qt6.sh` before making the migration.
2. Rebuild the corrected Qt6 package and verify its archive no longer contains a conflicting base-owned `etc/profile.d/qt6.sh`.
3. Verify `aaa_filesystem` owns the canonical `qt6.sh` in the final package database.
4. Install/update Qt6 through normal `prt-get`/`pkgadd` paths **without** `-f` and with no file-collision error.
5. Repeat the same ownership check for Qt5 and Rustc.
6. Audit every maintained `/opt`-prefixed port for required environment/profile integration and resolve any duplicate ownership.
7. Verify a fresh BFSOS installation has the canonical profile scripts before optional `/opt` stacks are installed.
8. Verify an upgrade from the old package-ownership layout to the new layout succeeds without package-database corruption or manual file deletion.
9. Verify removing Qt5/Qt6/Rust/etc. does not delete base-owned profile files; guarded scripts must no-op cleanly when their target prefix is absent.
10. Verify reinstalling those packages restores functionality without modifying ownership of the base integration files.
11. Run a login-shell test after installation/removal to confirm PATH/tool discovery is correct and no stale/broken environment variables are exported.
12. Add the profile-script collision audit to the BFSOS pre-RC source/package validation suite.

### Status

**OPEN / PRE-RC1 PACKAGING INTEGRATION — Qt6 6.11.2-8 now builds successfully, but installation is blocked by duplicate ownership of `etc/profile.d/qt6.sh`. Centralize the canonical `/opt` environment contract in `aaa_filesystem`, remove duplicate copies from Qt5/Qt6/Rustc and other applicable leaf packages, audit all `/opt` ports, and validate a conflict-free ownership migration on both fresh installs and existing systems.**


---

## r267 Tracker Update — Investigate silent/no-op `prt-get depinst` behavior with already-installed explicit targets

### [ ] OPEN / PRE-RC1 PACKAGE-MANAGER DEPENDENCY RESOLUTION — Multi-target `depinst` must not silently suppress unresolved work when one requested package is already installed

During the current giant desktop dependency/install sweep, the following explicit multi-target command was rerun from `/tmp/pkgutils-dynamic`:

```bash
sudo prt-get depinst xorg gnome-meta lxqt-meta plasma-meta xfce4-meta firefox
```

At least `firefox` is already installed. The command can return/run without reporting an error, which may be correct **only if every requested target and every dependency that BFSOS `depinst` is required to satisfy is already in a valid installed state**. Because the previous sweep had stopped on package/build/install failures, this behavior needs to be audited rather than assumed correct.

Do not classify this as a confirmed `prt-get`, `pkgmk`, or `pkgadd` defect yet. First determine whether this is:

```text
A. correct no-op behavior because the full requested closure is already satisfied;
B. a prt-get multi-target/installed-target short-circuit bug;
C. a regression in the newer BFSOS dependency-resolution logic;
D. stale/inconsistent package-database state after an earlier failed install;
E. a pkgadd partial-install/ownership-state problem that makes prt-get believe a package is installed;
F. an environment/PATH artifact from the temporary pkgutils-dynamic test directory;
G. another resolver/planner state bug.
```

### Expected semantics to preserve

For an explicit command such as:

```bash
prt-get depinst A B C D
```

BFSOS should evaluate **all explicitly requested targets**, not let the installed state of one argument terminate or suppress the rest of the transaction.

Expected behavior:

- An already-installed requested target may be skipped as a package install when no update/reinstall was requested.
- Other requested targets that are not installed must still be processed.
- Missing dependencies required by the requested transaction must still be resolved according to normal `depinst` semantics.
- The position of an already-installed package in the argument list — first, middle, or last — must not change the resulting transaction plan.
- If every requested target and required dependency is already satisfied, a successful no-op is valid, but the output should make that state understandable rather than appearing to have silently lost the request.
- A previous failed build/install must not be remembered as successful merely because a package archive was created.
- A package must not count as installed solely because `/var/cache/pkg/packages/<pkg>#<ver>-<rel>.pkg.tar.zst` exists.
- If the package database says a dependency is installed while required package ownership/live state is incomplete after a failed `pkgadd`, diagnose that package-manager consistency failure separately rather than hiding it in dependency resolution.

The existing BFSOS `--no-new-deps` work must **not** change explicit `depinst` semantics. `depinst` is an explicit request to resolve/install dependencies; the update/sysup opt-out must not leak into this command path.

### Reproduce the current state before changing code

On the BFSOS VM, capture the state of all top-level targets and the dependency that most recently failed or was repaired before rerunning the giant command.

At minimum record:

```bash
for p in xorg gnome-meta lxqt-meta plasma-meta xfce4-meta firefox qt6; do
    echo "===== $p ====="
    prt-get isinst "$p" || true
    prt-get info "$p" 2>/dev/null | sed -n '1,20p'
done

pkginfo -i | grep -E '^(xorg|gnome-meta|lxqt-meta|plasma-meta|xfce4-meta|firefox|qt6)( |$)' || true
```

Also record whether Qt6 — whose package build succeeded but whose install previously failed on `etc/profile.d/qt6.sh` ownership — is actually registered as installed, partially installed, or absent. Do not infer this from the existence of the Qt6 package archive.

Where practical, compare package-database ownership and representative live files for any package involved in the earlier failed install.

### Multi-target regression matrix

Build an automated regression around a small synthetic dependency graph so the result is deterministic and does not require rebuilding the desktop stack.

Test at least:

```text
1. none of A/B/C installed
2. first explicit target already installed
3. middle explicit target already installed
4. last explicit target already installed
5. multiple explicit targets already installed
6. all explicit targets installed and all dependencies satisfied
7. installed explicit target with one dependency deliberately absent
8. uninstalled explicit target whose dependency is already installed
9. dependency newly added to the repository metadata for an already-installed target
10. prior dependency build failure followed by the same depinst command
11. prior pkgadd/install failure followed by the same depinst command
12. package archive exists but package is not installed
13. package database says installed but a representative owned file is deliberately missing
```

For every permutation, verify that reordering the same explicit target list does not change which unresolved packages are scheduled.

In particular compare forms equivalent to:

```text
prt-get depinst installed missing1 missing2
prt-get depinst missing1 installed missing2
prt-get depinst missing1 missing2 installed
```

The transaction plan should differ only where package/dependency state genuinely differs, not because the installed target appears at a particular argument position.

### Audit likely code paths

Trace the `depinst` implementation and the newer BFSOS dependency logic before touching `pkgmk`.

Inspect for:

- an early `return`/success path when an explicit target is already installed;
- a loop whose final/last target status incorrectly determines the whole transaction;
- deduplication that removes unresolved siblings along with an installed node;
- a global "already installed" flag accidentally reused across multiple top-level targets;
- dependency graph pruning that treats an installed parent as proof that all of its dependencies are satisfied;
- cached resolver state surviving a failed package operation;
- transaction state that marks a package complete after **build/package creation** rather than after successful `pkgadd` completion;
- the new automatic-dependency/update logic accidentally being shared with `depinst` in a way that suppresses explicit dependency installation;
- special handling for meta packages that causes their dependency closure to be skipped once the meta package itself is installed.

Only investigate `pkgmk` as a causal component if the resolver actually invokes a build and `pkgmk` returns misleading state. If `prt-get` decides there is no work before any build starts, the initial locus is the resolver/planner or package database, not the package compiler.

### Temporary dynamic-pkgutils environment check

Because the command was issued while the shell was in:

```text
/tmp/pkgutils-dynamic
```

verify which binaries are actually being used so the diagnostic build does not muddy the result:

```bash
command -v prt-get
command -v pkgadd
command -v pkgmk
type -a prt-get pkgadd pkgmk
sudo sh -c 'command -v prt-get; command -v pkgadd; command -v pkgmk; printf "%s\n" "$PATH"'
```

Record whether `sudo prt-get` invokes the normal installed `/usr/bin/pkgadd` or any temporary dynamic test binary. The current working directory alone should not change package-manager behavior unless PATH/configuration explicitly makes it do so.

### Failure propagation and user-visible behavior

`prt-get depinst` must clearly distinguish:

```text
nothing to do / all requested packages satisfied
some requested targets already installed, continuing with remaining work
resolution failure
build failure
package creation failure
pkgadd/install failure
```

A failed dependency build/install must produce a non-zero transaction result and must not be converted into a later successful no-op unless a subsequent check proves the dependency is actually installed/satisfied.

If an installed explicit target has a newly required dependency under BFSOS's dependency-refresh policy, define and regression-test whether explicit `depinst <installed-target>` is expected to install that missing dependency. The chosen behavior must be consistent, documented, and must not depend on target ordering.

### Validation / exit criteria

1. Explain the current observed giant-desktop command behavior with a reproducible minimal case.
2. Confirm whether all six explicit targets were actually installed when the no-error/no-op behavior occurred.
3. Confirm the installed/database state of Qt6 after its earlier `pkgadd` collision failure.
4. Prove whether `prt-get` evaluates every top-level argument independently before finalizing the transaction plan.
5. Prove an installed target at the end of the command cannot suppress unresolved earlier targets.
6. Prove an installed target at the beginning or middle also cannot suppress unresolved siblings.
7. Verify missing dependencies of requested targets are handled according to documented `depinst` policy.
8. Verify package archives alone never satisfy the installed-state test.
9. Verify a failed `pkgadd` cannot leave resolver state that causes a later false-success transaction.
10. Verify `--no-new-deps` logic affects only its intended update/sysup paths and does not weaken explicit `depinst`.
11. Run the regression with both the normal static pkgutils build and the temporary dynamic diagnostic build if the behavior reaches `pkgadd`; if it occurs before installation, linkage should be irrelevant and should be documented as such.
12. Re-run:

```bash
sudo prt-get depinst xorg gnome-meta lxqt-meta plasma-meta xfce4-meta firefox
```

and confirm it either continues all genuinely missing work or prints a clear, correct "already satisfied/nothing to do" result based on verified package state.

### Status

**OPEN / INVESTIGATE BEFORE RC1 — the multi-target desktop `depinst` command can complete without an error while at least Firefox is already installed and the preceding sweep had encountered failures. This may be a valid no-op, a dependency-planner regression, or stale package-manager state. Do not patch `prt-get`, `pkgmk`, or `pkgadd` until the installed-state and argument-order matrix identifies the actual failing layer.**

---

## r268 Tracker Update — Investigate Poppler Qt6 optional-feature ordering exposed by `kio-extras`

### [ ] OPEN / PRE-RC1 PACKAGING DETERMINISM — A package required later by the desktop stack must not silently lack a feature merely because its enabling dependency was absent when it was first built

### Live behavior observed — 2026-09-08

During the full desktop dependency sweep, `poppler` was already installed before Qt6 was present. Later, `kio-extras` needed Poppler functionality that was only available after rebuilding `poppler` with Qt6 installed. Rebuilding Poppler after Qt6 became available resolved the immediate blocker.

Treat this as an **investigation item**, not yet as a confirmed defect in `poppler`, `kio-extras`, `prt-get`, or the general optional-dependency policy. The immediate rebuild proves that build-time feature availability changed with package ordering, but it does not by itself establish which package metadata or package-manager behavior should own the permanent fix.

### Questions to answer before changing ports

1. Determine exactly which Poppler Qt6 component, library, CMake package, pkg-config file, or executable `kio-extras` requires.
2. Compare a Poppler build made **without Qt6 installed** against one made **with Qt6 installed** and record the resulting feature/configuration differences.
3. Inspect the maintained `poppler` Pkgfile and upstream build configuration to determine whether Qt6 support is auto-detected, explicitly enabled, explicitly disabled, or otherwise optional.
4. Inspect the maintained `kio-extras` dependency metadata and upstream CMake checks to determine whether it requires the Qt6 Poppler frontend unconditionally for the BFSOS configuration being built.
5. Reproduce the issue from a clean package state so the result is not dependent on stale files from the live desktop sweep.
6. Determine whether a fresh `prt-get depinst plasma-meta` or equivalent dependency closure can legally schedule Poppler before Qt6 and thereby produce a feature-incomplete Poppler package.
7. Check whether any other maintained ports require optional Poppler frontends and could be affected by the same ordering problem.

### Candidate fixes to evaluate

Do **not** choose a permanent fix until the dependency/feature audit above is complete. Evaluate at least these models:

- **Hard dependency:** make Qt6 a declared dependency of Poppler if BFSOS intends every Poppler build to provide the Qt6 frontend. This is simple and deterministic but may pull Qt6 into otherwise non-Qt/minimal installations.
- **Split package:** package the Qt6 frontend separately (for example a Poppler Qt6 subpackage/port) if the current BFSOS packaging model can do so cleanly without file collisions or version skew.
- **Consumer dependency/feature contract:** if `kio-extras` is the component that specifically requires the Qt6 Poppler frontend, encode a dependency relationship that guarantees that frontend is present rather than merely requiring a generic Poppler installation.
- **Feature-aware rebuild mechanism:** investigate whether BFSOS package tooling should ever rebuild an already-installed package when a newly installed optional dependency enables a required feature. This is the broadest solution and should not be implemented solely for Poppler without evidence that the pattern is common enough to justify package-manager complexity.

### Packaging policy to preserve

A clean BFSOS installation should be deterministic. Users should not be expected to know that an already-installed package must be manually rebuilt merely because a later package made an optional build dependency available.

At the same time, do not turn every optional GUI integration into a hard dependency automatically. The investigation should distinguish:

- genuinely optional functionality;
- functionality required by a maintained downstream package;
- functionality BFSOS deliberately promises in its default desktop build;
- and features that are safe to omit on minimal/headless systems.

### Validation / exit criteria

1. Record the exact Poppler Qt6 artifact or CMake feature required by `kio-extras`.
2. Prove the before/after difference between Poppler built without and with Qt6 available.
3. Identify the current dependency edge that permits the feature-incomplete build ordering.
4. Choose and document the narrowest deterministic packaging fix.
5. Rebuild from a clean state using the corrected maintained ports/tooling.
6. Confirm `kio-extras` builds without any manual Poppler rebuild.
7. Confirm the chosen fix does not unnecessarily force Qt6 onto a minimal/headless Poppler installation unless that is the explicit BFSOS policy.
8. Audit at least the other desktop consumers of Poppler for the same optional-feature assumption.

### Status

**OPEN / INVESTIGATE — live desktop testing showed that Poppler built before Qt6 could later be insufficient for `kio-extras`, while rebuilding Poppler after Qt6 was installed resolved the blocker. Determine whether the permanent fix belongs in Poppler dependencies, `kio-extras` dependencies/feature requirements, package splitting, or broader feature-aware rebuild policy. Do not require users to rely on install-order knowledge as the final distro behavior.**

---

## r269 Tracker Update — Make `/opt/kf6` graphical-session environment available before Plasma Wayland user units start

### [ ] OPEN / PRE-RC1 — Replace the VM test override with a distro-owned, deterministic systemd-user environment policy

### Live failure and proof — 2026-09-08

Plasma Wayland originally failed even though the session files, Plasma systemd user units, KWin binaries, Plasma package data, and SDDM session selection were present.

The decisive failure was an environment split between ordinary login shells and the systemd user manager. `/etc/profile.d/kf6.sh` correctly extended the interactive shell environment, but early Plasma user services could start before those `/opt` paths were available to the user manager.

The initial `kwin_wayland_wrapper` process inherited:

```text
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin
```

while the actual compositor binary existed only at:

```text
/opt/kf6/bin/kwin_wayland
```

Because the wrapper launches the compositor by executable name, the wrapper remained alive without a `kwin_wayland` child. Downstream `plasmashell` startup then stalled/timed out.

The related data-path problem was also reproduced: the shell had `/opt/kf6/share` in `XDG_DATA_DIRS`, while the systemd user manager initially did not. Plasma data including `desktoptheme/default`, look-and-feel packages, shells, plasmoids, and wallpapers was correctly installed under `/opt/kf6/share/plasma`.

### Successful VM A/B configuration

The working test configuration provided the required values to the user manager before Plasma started, including:

```text
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/opt/kf6/bin:/opt/qt6/bin
XDG_DATA_DIRS=/usr/local/share:/usr/share:/opt/kf6/share
```

The VM test used systemd-user environment configuration plus the existing environment.d experiment. On a clean reboot directly into SDDM and Plasma Wayland:

- `kwin_wayland_wrapper` inherited the `/opt/kf6/bin` path;
- the wrapper immediately spawned `/opt/kf6/bin/kwin_wayland`;
- Xwayland started under KWin;
- `plasma-kwin_wayland.service` remained active;
- `plasma-plasmashell.service` remained active;
- the active seat/session matched the Plasma session;
- the desktop displayed correctly rather than remaining black.

This validates the environment timing/root cause. Restarting KWin inside a live Wayland session is **not** a valid normal recovery test because KWin is the compositor and terminating/restarting it tears down the session and returns the user to the display manager.

### Permanent BFSOS requirements

1. Do not rely solely on `/etc/profile.d/kf6.sh` for paths required by systemd-managed graphical user services.
2. Install a distro-owned configuration that gives the systemd user manager the required `/opt` executable/data paths from its initial startup.
3. At minimum preserve the proven requirements:
   - `/opt/kf6/bin` in `PATH` before `plasma-kwin_wayland.service` starts;
   - `/opt/kf6/share` in `XDG_DATA_DIRS` before Plasma/KF6 data consumers start.
4. Include `/opt/qt6/bin` only where BFSOS policy requires it; do not expand the environment with unproven paths merely for symmetry.
5. Integrate this with the existing r266 `/etc/profile.d` and `/opt` ownership policy so one base package owns canonical environment configuration and individual ports do not collide.
6. Avoid duplicate path elements. Current shell testing showed repeated `/opt/kf6/bin` entries that should be normalized by the permanent implementation.
7. A nonexistent optional `/opt` directory must not make login fail on systems that do not install the corresponding stack.
8. Do not hard-code per-user configuration or require users to run `systemctl --user import-environment` manually.
9. Do not fix the problem by modifying upstream Plasma unit files to use arbitrary shell wrappers unless the centralized BFSOS environment policy proves insufficient.
10. Preserve normal SDDM/GDM/LXQt/XFCE/GNOME behavior when multiple desktops are installed.

### Validation / exit criteria

1. Remove the temporary VM-only environment overrides and install the permanent packaged solution.
2. Reboot from a cold/clean state with SDDM selected as the display manager.
3. Log directly into Plasma Wayland without first opening another desktop session.
4. Before any manual `daemon-reload`, import, or service restart, verify:

```bash
systemctl --user show-environment | grep -E '^(PATH|XDG_DATA_DIRS)='
```

contains the required `/opt/kf6` values.
5. Verify the first-start wrapper environment also contains `/opt/kf6/bin`.
6. Verify both processes exist immediately:

```text
kwin_wayland_wrapper
kwin_wayland
```

7. Verify `plasma-kwin_wayland.service` and `plasma-plasmashell.service` are active and the Plasma Wayland desktop renders correctly.
8. Reboot and repeat at least once to rule out state carried over from a previous user manager.
9. Verify Plasma X11 still logs in normally.
10. Verify GNOME, LXQt, and XFCE login behavior is not regressed by the centralized environment policy.
11. Verify no duplicate/contradictory `/opt/kf6/bin` or `/opt/kf6/share` entries are emitted by the combination of environment.d, user-manager defaults, and profile scripts.

### Status

**OPEN PERMANENT SOURCE/PACKAGING FIX — live VM proof is successful and Plasma Wayland now works. The remaining work is to replace the temporary environment overrides with the canonical BFSOS-owned systemd-user `/opt` environment policy and regression-test clean boots.**

---

## r269 Tracker Update — Populate p11-kit/NSS CA trust so Firefox validates normal HTTPS certificates

### [ ] OPEN / PRE-RC1 SECURITY + BROWSER INTEGRATION — Generate both the PEM CA bundle and p11-kit trust anchors from one maintained certificate source

### Live failure and proof — 2026-09-08

Firefox built, installed, and launched, but normal HTTPS sites failed certificate validation. This was not a general network, DNS, clock, or OpenSSL problem.

The BFSOS VM proved:

```text
curl HTTPS:                 works
OpenSSL verification:      works
PEM bundle certificate count: 121
Firefox/NSS HTTPS:          failed before trust population
p11-kit CA anchor count:    0
```

The system intentionally redirects NSS built-in trust through p11-kit:

```text
/usr/lib/libnssckbi.so -> ./pkcs11/p11-kit-trust.so
```

and p11-kit is compiled to scan:

```text
/etc/pki/anchors:/usr/share/pki/anchors
```

However, the installed `ca-certificates` package contained only:

```text
/etc/pki/tls/certs/ca-bundle.crt
/etc/ssl/ca-bundle.crt
/etc/ssl/cert.pem
/etc/ssl/certs/ca-certificates.crt
```

with no populated p11-kit trust anchors. `make-ca` and `trust` were installed, but the Mozilla source file required by `make-ca` was absent:

```text
/etc/ssl/certdata.txt was not found
```

Therefore `make-ca -r` could not rebuild the trust stores. Running the proper first-population path with:

```bash
sudo make-ca -g
```

populated the system trust data and Firefox then browsed HTTPS sites successfully.

### Permanent BFSOS requirements

1. Treat this as a `ca-certificates` / `make-ca` / p11-kit integration defect, not as a Firefox preference problem.
2. Do not disable Firefox certificate validation, HSTS, NSS verification, or security warnings.
3. Do not require each Firefox profile to maintain a private workaround CA database.
4. Do not require an Internet download during normal package installation as the permanent solution.
5. Make the maintained port/build process obtain the Mozilla `certdata.txt` source reproducibly through normal BFSOS source handling, checksums/signature/provenance policy, and source cache behavior.
6. Use that maintained source to generate/install both:
   - the traditional PEM compatibility bundle consumed by OpenSSL/curl and similar software;
   - the p11-kit trust anchors consumed by NSS/Firefox through `p11-kit-trust.so`.
7. Keep local administrator trust overrides separate from package-owned Mozilla roots. Prefer package-owned default roots under the appropriate `/usr/share/...` trust source when compatible with the selected `make-ca` layout, reserving `/etc` for local policy/overrides where practical.
8. Ensure CA package updates regenerate all derived trust stores atomically so an update cannot leave OpenSSL and NSS with different root sets.
9. Preserve the existing `/etc/ssl` compatibility symlinks expected by applications.
10. Document which package owns `certdata.txt`, generated anchors, compatibility bundles, and refresh hooks so package upgrades/removals do not create ownership collisions.
11. Audit why `modutil` is not installed even though other NSS utilities such as `certutil` are present. Track/fix that packaging omission separately if the maintained NSS build is expected to provide it; it is **not** the proven cause of the Firefox HTTPS failure.

### Required automated/runtime checks

After a clean installation of the permanent packages, verify without any manual `make-ca -g` step:

```bash
test "$(grep -c 'BEGIN CERTIFICATE' /etc/pki/tls/certs/ca-bundle.crt)" -gt 0

test "$(trust list --filter=ca-anchors 2>/dev/null | grep -c '^pkcs11:')" -gt 0
```

Then verify all three trust consumers:

1. `curl -I https://www.youtube.com/` or another known public HTTPS endpoint succeeds.
2. `openssl s_client ... -verify_return_error` returns `Verify return code: 0 (ok)` for a valid public chain.
3. Firefox opens the same HTTPS site without `SEC_ERROR_UNKNOWN_ISSUER`, HSTS bypass prompts, or equivalent trust failures.

Also verify:

- a package upgrade of CA data refreshes both PEM and p11-kit representations;
- a clean new user/profile works without importing certificates manually;
- Firefox continues to use the intended system trust integration after NSS/Firefox updates;
- local administrator-added anchors remain possible without modifying package-owned files.

### Status

**OPEN PERMANENT SOURCE/PACKAGING FIX — runtime Firefox HTTPS is now proven working after `make-ca -g`, and the root cause is confirmed: BFSOS shipped a valid PEM CA bundle but left the p11-kit/NSS trust store unpopulated because the Mozilla `certdata.txt` input/initial generation step was missing. Fix the CA package lifecycle so this is correct immediately after installation and updates.**


## r278 MinGW-w64 CRT package payload verified — 2026-09-09

- [x] **LIVE VERIFIED: `mingw-w64-crt 14.0.0-2` now produces a valid target payload.**
  - Package archive contains **0** leaked `var/cache/pkg/build-work/` entries.
  - Target payload counts observed: **495** entries for `i686-w64-mingw32` and **953** entries for `x86_64-w64-mingw32`.
  - Both target library trees contain the required GCC-link runtime/import files, including `dllcrt2.o`, `crt2.o`, `libmingw32.a`, `libmingwthrd.a`, `libmingwex.a`, `libmoldname.a`, `libmsvcrt.a`, `libkernel32.a`, `libuser32.a`, `libadvapi32.a`, and `libshell32.a`.
  - Root causes resolved in the CRT port:
    1. BFSOS globally exports package staging variables such as `DESTDIR=$PKG`; temporary bootstrap installs must explicitly clear those variables so private binutils/headers/GCC install into `$SRC/sysroot` instead of contaminating `$PKG`.
    2. `mingw-w64-crt` requires `keep_static=1`; BFSOS pkgmk correctly removes `*.a` archives by default otherwise, but MinGW CRT import/runtime archives are required package payload rather than optional static libraries.
  - Keep normal global pkgmk static-library cleanup policy unchanged; this is a package-level opt-in.
  - Next verification: install `mingw-w64-crt#14.0.0-2`, confirm the same files exist live under `/usr/{i686,x86_64}-w64-mingw32/lib`, then rebuild `mingw-w64-gcc 16.2.0-1` from a clean work tree. If GCC succeeds, inspect the archive before install and test PE output for both C and C++ targets.
  - Before the GCC rebuild, add `keep_static=1` to `mingw-w64-gcc` as well. Its MinGW runtime support includes required `.a` archives (`libgcc.a`, libstdc++ static/support archives, etc.); `.nostrip` does not preserve them from BFSOS pkgmk static-library cleanup. Preserve normal global cleanup and opt this port in explicitly.

## SOURCE IMPLEMENTED / LIVE BUILD VERIFY — contrib and compat-32 `build_opt` correction (2026-09-13)

The blanket conversion of all 170 compat-32 recipes to custom `pkg_build()`
was removed. Ordinary Autotools, CMake, Meson, and Make recipes now use the
BFSOS generic builder and package-specific `build_opt`; preparation and payload
selection live in `pre_build()` and `post_build()` only where required.

The pkgutils extension now owns `/usr/lib32`, the i686 Autotools host argument,
and a generated Meson i686 cross description. Remaining custom recipes are
explicitly documented and fail-fast in an isolated subshell. Contrib received
the same normalization, including corrected GStreamer/BFSOS metadata.

**SOURCE COMPLETE — LIVE BFSOS BUILD/ELF/FOOTPRINT/WINE/STEAM VERIFICATION OPEN.**
## r285 Tracker Update — Chromium Google API / browser-sync policy cleanup (2026-09-15)

### [x] SOURCE COMPLETE / RELEASE-3 REBUILD VERIFY — remove obsolete/misleading Google Sync/API build handling and use the current Chromium GN policy

The maintained BFSOS Chromium port must not imply that a distro-built Chromium package can use Google's private Chrome Sync service in the same way as Google Chrome. Google restricts the private APIs used by Chrome Sync for third-party Chromium distributions.

### Required Pkgfile cleanup

1. Audit the Chromium `build_opt` list for any obsolete, renamed, ineffective, or misleading GN option that was intended to enable Google account/browser synchronization or Google API access.
2. Remove such stale options rather than carrying them forward simply because they do not currently break the build.
3. For an unbranded BFSOS Chromium package, explicitly use the current upstream-supported GN policy:

```text
use_official_google_api_keys=false
```

4. Do **not** bake Google-internal or maintainer-owned credentials into the BFSOS package.
5. Leave these packaged-build values unset/empty unless BFSOS later has a legitimate redistributable credential policy:

```text
google_api_key
google_default_client_id
google_default_client_secret
```

6. Do not claim that supplying those API values restores Google Chrome Sync. Chromium may use API/OAuth credentials for individual Google-backed services, but Google Chrome Sync availability is a separate service-policy restriction for third-party Chromium builds.
7. If runtime environment overrides are documented for developer/testing use, keep them user-supplied and outside package-owned files:

```text
GOOGLE_API_KEY
GOOGLE_DEFAULT_CLIENT_ID
GOOGLE_DEFAULT_CLIENT_SECRET
```

### Packaging/UI expectations

- Chromium must remain clearly identified as **Chromium**, not Google Chrome.
- Browser sign-in or sync UI that cannot function correctly in the BFSOS distro build should not be advertised as a supported BFSOS feature.
- Do not add unsafe patches or copied private Google credentials to force unsupported sync behavior.
- A future supported cross-browser bookmark/settings sync solution may be packaged separately, but it must not masquerade as Google Chrome Sync.

### Updater / audit requirement

The maintained Chromium updater must continue to flag removed or renamed GN arguments and must specifically re-check Google API-key / sign-in related GN variables on every major Chromium update. A non-failing obsolete option is still a packaging defect and should be removed or replaced with the current supported option.

### Validation

For the next successful Chromium package build:

```bash
gn args out/Release --list | grep -E 'use_official_google_api_keys|google_api_key|google_default_client_(id|secret)'
```

Verify that:

- `use_official_google_api_keys` resolves to `false`;
- no BFSOS-distributed Google API key, client ID, or client secret is embedded;
- normal web sign-in to Google sites still works;
- the package documentation does not promise Google Chrome Sync for bookmarks, passwords, settings, or open tabs.

### Status

**SOURCE COMPLETE in r290 — `use_official_google_api_keys=false` is now explicit in the unbranded BFSOS Chromium recipe and no distro API credentials are defined. Rebuild/install/runtime-check release 3 before closing the live verification portion.**


---

## r290 Tracker Update — bootable BFSOS ISO build/release-image path (2026-09-15)

### [~] SOURCE IMPLEMENTED / LIVE BUILD+BOOT VERIFY — repeatable BFSOS ISO build path

BFSOS now has enough of the installer and boot/package stack in-tree that the next release-engineering milestone is a reproducible bootable ISO. The ISO should be a usable live install/bootstrap/recovery environment, not merely a read-only launcher for the installer.

### Existing source/assets already present

The current project snapshot already contains pieces that should be reused rather than replaced by a second installer implementation:

- Current menu installer entry point: `scripts/install-bfs-menu-current.sh`.
- Historical/current installer development scripts under `scripts/install-bfs-menu-v50-*`, including current storage, kernel-selection, RAID, LVM, integrity, and authentication work.
- `core/squashfs-tools` for the compressed live/root filesystem.
- `core/grub` for BFSOS bootloader support.
- `core/dracut` and BFSOS dracut configuration for initramfs generation.
- `core/dosfstools`, `core/mtools`, and `core/efibootmgr` for EFI support.
- `opt/libisoburn` for ISO mastering/xorriso.
- `opt/syslinux` if retained legacy BIOS support requires it.
- NetworkManager, OpenSSH, storage utilities, and the optional packages exposed by the installer should be available to the ISO package set where applicable.

r290 now adds the maintained `scripts/bfs-build-iso.sh` implementation and integrates it into `bootstrap.sh`. Source-level assembly logic and regression coverage are present; the first complete BFSOS-side ISO build and boot/install acceptance remain required before the pipeline can be called release-ready.

### Bootstrap-menu integration

The ISO creator should be launchable from the existing BFSOS bootstrap menu. The menu entry should call the same maintained ISO build logic used elsewhere, not contain a second hidden implementation.

The ISO build entry should:

- prepare/clean a dedicated ISO work area outside `~/BFSOS`;
- verify required ISO-building tools and package artifacts;
- assemble the live/root filesystem and boot media;
- produce the final ISO and checksum in a documented output location;
- record the BFSOS version and Git commit represented by the image;
- optionally offer a boot-test step after creation.

### Required ISO build logic

Before calling the ISO path implemented, define and source-control the logic for:

1. Selecting the exact BFSOS package/rootfs content that belongs on the media.
2. Building the live/install root from controlled BFSOS package artifacts rather than copying arbitrary state from a developer workstation.
3. Building and including **all optional packages exposed by the BFSOS installer**, so selecting an optional installer feature does not fail because its package was omitted from the ISO.
4. Installing the current BFSOS installer and all tools required by its storage, bootloader, filesystem, networking, verification, and package-selection paths.
5. Selecting the release kernel and generating the matching initramfs with the storage/filesystem drivers required by the live environment and installer.
6. Creating the compressed live/root filesystem and documenting its SquashFS mount/discovery convention.
7. Building boot media for UEFI x86_64 and any retained legacy BIOS path.
8. Defining the ISO directory layout, GRUB/Syslinux configuration, kernel command line, live-root discovery, writable-overlay discovery, and handoff into the live startup/installer flow.
9. Embedding release identification such as BFSOS version, architecture, build date, and source Git commit.
10. Producing the final ISO and checksum with deterministic/repeatable filenames and a clean rebuild mode.
11. Failing fast when required package archives, optional installer packages, kernel/initramfs files, bootloader payloads, installer files, networking/SSH components, or ISO-mastering tools are missing.

### Gentoo-live-style writable storage

The live ISO should use storage logic similar in purpose to the Gentoo live ISO so users do not unexpectedly run out of writable space while the immutable SquashFS itself still has space.

Requirements:

- Provide a writable overlay/tmpfs or equivalent writable live layer above the compressed root.
- Size live writable storage sensibly from available RAM and/or other suitable backing storage rather than using a tiny fixed limit.
- Leave enough headroom for the kernel, desktop/live services, installer, package operations, logs, downloads, temporary files, and bootstrap activity.
- Low-memory machines need a safe fallback rather than consuming nearly all RAM for the overlay.
- Large-memory machines should receive enough working space for installer/package operations.
- Keep ISO live-session writable-storage policy separate from the existing `/var/cache/pkg/build-work` tmpfs-sizing policy; do not blindly reuse one as the other.
- Large temporary operations should use the writable live layer rather than attempting to modify the immutable SquashFS.

### Live environment defaults

The BFSOS ISO should boot into a deliberately configured live environment rather than inheriting incomplete package defaults.

- **NetworkManager is the default network-management service on the ISO** and should start automatically.
- Normal DHCP networking should come up automatically where connectivity is available.
- The live account should be a dedicated non-root user, currently preferred name: `bfs`.
- The live account must not ship with a permanent known password embedded in the image.
- At live boot, prompt the user to set a temporary password for the `bfs` live account.
- The live-session password is only for the ISO session and must not automatically become an installed-system password.
- Installed-system root/user password prompts remain separate installer operations.

### Live SSH behavior

After the live user has set the temporary ISO password:

1. Generate SSH host keys at runtime with `ssh-keygen -A` if they do not already exist.
2. Start OpenSSH/`sshd` for the live environment.
3. Permit the `bfs` account to authenticate according to the live-ISO SSH policy.
4. Make it clear that the live password and host keys belong only to the temporary ISO session.
5. Do not copy live ISO SSH host keys into the installed system; the installed BFSOS system must generate its own host identity.
6. Do not silently reuse the live-user password as an installed-system password.
7. Do not start SSH prematurely with an empty/default live-user password.

Expected sequence:

```text
ISO boots
   ↓
`bfs` live account initialized
   ↓
user prompted for temporary live password
   ↓
NetworkManager brings networking up
   ↓
SSH host keys generated
   ↓
sshd starts
```

### Ship the BFSOS project tree in the ISO

The ISO should contain a known-good complete BFSOS project tree corresponding to the ISO release commit. Networking must **not** be required just to boot, launch the installer, or bootstrap from the release snapshot.

When networking is available after boot, the live environment should attempt to refresh the bundled tree with a safe Git update:

- use the bundled tree as the fallback/known-good state;
- if the tree is clean, attempt a fast-forward-only fetch/pull from the BFSOS repository;
- if the update succeeds, use the refreshed tree;
- if networking is unavailable or the pull fails, continue using the bundled release tree;
- if the live tree contains local changes, do not overwrite them; skip the automatic pull and notify the user.

Preferred live path: `/home/bfs/BFSOS`.

### ISO startup choice: bootstrap or install

After live initialization and any safe online project-tree refresh, present the user with a startup choice:

```text
1. Bootstrap BFSOS
2. Run BFSOS installer
3. Shell / live tools
```

- **Bootstrap BFSOS** enters the normal BFSOS bootstrap workflow using the full project tree.
- **Run BFSOS installer** launches the existing BFSOS installer, not a separate ISO-only installer.
- The same choices should remain accessible later through the normal bootstrap/menu interface.

### Initial package/archive strategy before an external BFSOS package repository exists

For the first ISO implementation, BFSOS will **not** depend on an external package server. The ISO creator should rebuild the complete BFSOS base/package set needed by the live environment and installer, then place those exact package archives on the ISO for local installation.

Initial ISO-creation flow:

```text
Launch ISO creator from bootstrap menu
   ↓
rebuild complete BFSOS base/package set
   ↓
build/include live-environment packages
   ↓
build/include every package exposed as an installer option
   ↓
verify all required package archives exist
   ↓
stage exact package archives into ISO media tree
   ↓
generate package manifest + checksums
   ↓
build live SquashFS and boot files from the same known package set
   ↓
create ISO
```

The ISO package archives should remain accessible as ordinary files outside the compressed live SquashFS where practical. The live environment/installer should expose them through one documented local package/archive location so the installer can consume them without downloading anything.

Initial installer lookup logic:

```text
Run installer
   ↓
check required package/archive set
   ↓
required archive available from ISO/local cache?
   ├─ yes → use and verify it
   └─ no  → report exactly what is missing
   ↓
continue installation from local ISO package set
```

For the initial releases, the ISO should therefore be a **complete local package source for every package and option exposed by that ISO's installer**. A larger ISO is acceptable at this stage; reliability and reproducibility take priority over minimizing image size.

The ISO creator must not simply copy whatever happens to exist in `/var/cache/pkg/packages`. It should resolve the required package set, rebuild the base and required/optional packages as defined by the ISO manifest, verify that the expected archives were produced, and only then stage those archives into the image.

Generate a package manifest for the image containing at least package name, version, release, archive filename, checksum, and category/reason such as `base`, `live`, `installer`, or `optional`. The same manifest format should be reusable later for an online BFSOS package repository.

### Future external package/archive handling

Once BFSOS has a defined external package/distribution location, extend the same installer logic rather than replacing it. Local ISO packages should remain the first source, with the external repository used only for missing/newer content according to policy.

Future expected logic:

```text
Run installer
   ↓
check required BFSOS package/base archives
   ↓
local ISO/cache copy available?
   ├─ yes → verify and use it
   └─ no
       ↓
   external BFSOS package source configured and networking available?
       ├─ yes → download verified archive
       └─ no  → report exactly what is missing
   ↓
place downloaded archives in the canonical BFSOS archive/cache layout
   ↓
verify checksum/signature
   ↓
continue installation
```

Requirements:

- Downloaded base/package files must go into the same canonical archive/cache layout expected by the bootstrap and installer logic, not an ISO-only path.
- Never silently use unverified downloaded content.
- Apply BFSOS checksum/signature verification policy before installation.
- Networking and the future external repository must remain enhancements, not requirements for an ISO whose local package set is complete.

### Online/offline behavior

The ISO must support both modes cleanly:

```text
Online live session
  → use bundled BFSOS tree
  → safely fast-forward it when possible
  → bootstrap or install from the complete local ISO package set
  → later, when an external repository exists, obtain missing/newer verified archives as policy allows

Offline live session
  → use bundled BFSOS release tree
  → bootstrap or install entirely from the local ISO package/archive set
  → clearly report anything unexpectedly missing
```

The Git refresh is an enhancement, never a prerequisite for basic ISO usability.


### ISO builder preflight/tool verification

Before the ISO creator modifies the ISO work directory, rebuilds the BFSOS base, or starts package/rootfs generation, it must run a complete host-tool preflight check.

The preflight must verify every command required by the maintained ISO pipeline and clearly separate **required** tools from **optional/test-only** tools. If any required tool is missing, abort before doing build work and print a concise report showing both the missing command and the corresponding BFSOS package name where known.

Expected behavior should resemble:

```text
BFSOS ISO Builder Preflight
===========================

[OK]      git
[OK]      pkgmk
[OK]      prt-get
[OK]      mksquashfs
[OK]      xorriso
[OK]      grub-mkimage
[MISSING] mcopy          package: mtools
[MISSING] cpio           package: cpio
[WARN]    qemu-system-x86_64 not installed; automatic VM boot test unavailable

ISO build cannot continue until all required tools are installed.
```

At minimum, the maintained preflight should account for tools used by the final implementation in these categories:

- BFSOS/package tooling: `pkgmk`, `pkgadd`, `prt-get`, `ports` where applicable.
- Source/project tooling: `git`, shell/core utilities, `tar`, `zstd`, checksum utilities, and any archive helpers actually used by the scripts.
- Live-root tooling: `mksquashfs`/SquashFS utilities plus any overlay/rootfs construction commands used by the implementation.
- Initramfs/kernel tooling: `dracut` and any required supporting utilities.
- ISO/mastering tooling: `xorriso`/libisoburn and any El Torito helpers actually used.
- Bootloader tooling: required GRUB commands such as `grub-mkimage`/`grub-mkrescue`, plus Syslinux tools only if the retained BIOS path uses them.
- EFI/FAT tooling: `mkfs.vfat`, `mcopy`/mtools, and related commands actually used to construct the EFI image/path.
- Archive/initramfs helpers such as `cpio` when required by the implemented build flow.
- Optional validation tooling such as `qemu-system-x86_64` and UEFI firmware/OVMF for automated post-build boot tests.

Requirements:

- Do not wait until a late build stage to discover a missing executable.
- Do not modify or partially populate the ISO staging/work tree before required-tool validation succeeds, except for harmless temporary preflight state if needed.
- Report **all** missing required tools in one pass rather than stopping at the first missing command.
- Where BFSOS has a known package providing the command, print that package name so the user knows what must be installed.
- Missing optional validation tools should generate a warning and disable only the corresponding optional test; they must not block ISO creation unless that test was explicitly requested as mandatory.
- Keep the command/package mapping in the maintained ISO-builder logic so it evolves with the actual implementation rather than becoming stale documentation.
- The bootstrap-menu ISO-creator entry must run this same preflight logic; do not maintain a separate menu-only dependency check.

### Integration requirements

- The ISO must launch the existing BFSOS installer; do not fork a separate installer implementation solely for optical/USB media.
- The ISO should contain every package necessary for every currently exposed installer storage choice and optional feature.
- Installer kernel/storage assumptions must match the kernel actually shipped on the ISO, especially MD RAID, LVM, filesystem support, and any retained encryption/storage-discovery logic.
- The installer must continue to support the existing UEFI/GRUB target logic, including `EFI/BOOT/BOOTX64.EFI` fallback behavior where applicable.
- ISO construction must not modify the authoritative ports tree or hand-install generated package state into `/usr/ports`.
- Build products and temporary roots must live outside `~/BFSOS` and be safely removable/rebuildable.
- ISO construction should consume validated BFSOS packages rather than becoming a second unrelated package-build framework.
- The installer/bootstrap live workflow must not depend on a successful network connection or successful Git pull when the ISO already contains a valid release tree.

### Validation required before closing

A first successful ISO creation is not sufficient. Before this item is marked fixed, verify at minimum:

- ISO-builder preflight reports every missing required tool before build work begins.
- Missing-tool output identifies the corresponding BFSOS package where known.
- Missing optional VM/test tooling produces a warning without blocking a normal ISO build.
- ISO creation completes from a clean ISO work directory.
- The output checksum verifies.
- The image boots in UEFI mode to the intended BFSOS live environment.
- If legacy BIOS remains supported, the same image boots successfully in BIOS mode.
- The shipped kernel and initramfs match the selected release kernel.
- SquashFS live root mounts correctly.
- The writable live overlay/storage is created correctly.
- Writable-space sizing behaves reasonably on both low-memory and high-memory systems.
- Normal live-session/install/bootstrap operations do not immediately exhaust writable space.
- NetworkManager starts automatically and DHCP networking works.
- The expected `bfs` live user exists.
- No fixed reusable live-user password is baked into the image.
- First-boot/live-session password setup works.
- SSH host keys are generated at runtime rather than baked into the ISO.
- `sshd` starts only after live-account authentication is safely initialized.
- Remote SSH login to the live environment works.
- Live SSH keys/passwords are not copied into the installed system.
- The bundled BFSOS project tree matches the ISO release commit.
- With networking, a clean bundled tree can update safely with a fast-forward-only Git operation.
- With no networking, the bundled tree still supports bootstrap/installer startup.
- Local changes to the live project tree are not overwritten by automatic update logic.
- The startup choice offers Bootstrap BFSOS, Run BFSOS installer, and Shell/live tools.
- All optional installer packages are actually available from the ISO/package cache as designed.
- The ISO creator rebuilds the complete base package set rather than trusting stale/random cache contents.
- Every package exposed by the installer, including optional selections, is represented in the staged ISO package set.
- The generated package manifest matches the archives actually present on the ISO and includes checksums.
- A full installation can complete with networking disabled using only the local ISO package/archive set.
- When the future external repository support is implemented, missing archives can be downloaded to the canonical archives/cache location and verified before use.
- Offline behavior reports any unexpectedly missing required archive clearly instead of failing mysteriously.
- A disposable VM can complete an installation from the ISO and boot the installed system.
- Repeat the ISO build without relying on leftover files from the previous run.
- After VM validation, perform a bare-metal boot/install smoke test before publishing an RC image.

### Status

**SOURCE IMPLEMENTED / LIVE VALIDATION REQUIRED — r290 adds the maintained ISO builder and bootstrap-menu/CLI integration. r291 records the first live workflow defect: existing verified base archives must be offered for reuse instead of forcing another full bootstrap by default. The source now contains the preflight, complete-base rebuild handoff, isolated live/package root, bundled package/archive set, SquashFS + writable overlay path, GRUB rescue-media generation, NetworkManager default, temporary `bfs` account/password flow, runtime SSH key generation/startup, bundled Git tree with safe fast-forward refresh, Bootstrap/Installer/Shell menu, build metadata, package/checksum manifests, and final ISO checksum. Do not call this release-ready until an actual BFSOS build produces an ISO and UEFI/BIOS boot, live-overlay behavior, SSH, offline installer package use, full VM installation, installed-system boot, and repeat-clean-build tests pass. External verified package/archive download support remains a later extension using the same canonical cache and manifest model.**
