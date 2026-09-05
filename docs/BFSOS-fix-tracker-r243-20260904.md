# BFSOS Fix Tracker r243 — Implementation Status

This r243 copy preserves the r242 requirements below and records the source implementation completed in the 2026-09-04 maintenance pass. Items are **not marked fully CLOSED** until their runtime/build verification has passed on BFSOS.

| r242 item | r243 state |
| --- | --- |
| Kernel Update Cleanup / Stale Initramfs Handling | **SOURCE IMPLEMENTED — runtime reboot/rollback verification pending** |
| Installer Build-Work tmpfs Sizing | **SOURCE IMPLEMENTED — installer/runtime verification pending** |
| `prt-get --no-new-deps` | **SOURCE IMPLEMENTED — local regression PASS; bootstrap/runtime verification pending** |
| LTS kernel cleanup / selected-kernel consistency | **SOURCE IMPLEMENTED — LTS fresh-install/update/reboot verification pending** |
| Invalid sudoers environment-preservation syntax | **SOURCE IMPLEMENTED — standalone `visudo -cf` PASS; installed-system validation pending** |
| PipeWire / WirePlumber activation | **SOURCE IMPLEMENTED — fresh-user/multi-desktop runtime verification pending** |
| Plasma Login Manager | **PORT + selector IMPLEMENTED — build/login/KCM/session verification pending** |

Supporting implementation/validation files:

- `docs/BFSOS-r243-maintenance-report-20260904.md`
- `docs/BFSOS-maintained-port-inventory-r243-20260904.tsv`
- `scripts/bfs-r243-source-tests.sh`
- `scripts/bfs-r243-runtime-check.sh`
- `scripts/bfs-maintained-port-version-audit.sh`
- `scripts/tests/test-kernel-maintenance.sh`
- `scripts/tests/test-prt-get-no-new-deps.sh`
- `scripts/tests/test-installer-build-work-sizing.sh`

---

# BFSOS Fix Tracker

## IMPLEMENTED — runtime verification pending — Kernel Update Cleanup / Stale Initramfs Handling

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

### Status
**SOURCE IMPLEMENTED — runtime verification pending**

---

## IMPLEMENTED — runtime verification pending — Installer Build-Work tmpfs Sizing

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

### Status
**SOURCE IMPLEMENTED — runtime verification pending**

---

## IMPLEMENTED — runtime verification pending — prt-get Option to Disable Automatic New-Dependency Installation

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

### Status
**SOURCE IMPLEMENTED — runtime verification pending**

## IMPLEMENTED — runtime verification pending — LTS kernel install/update cleanup and selected-kernel consistency

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
## IMPLEMENTED — runtime verification pending — Fix invalid `/etc/sudoers.d` environment-preservation syntax

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

### Status
**SOURCE IMPLEMENTED — runtime verification pending**


## IMPLEMENTED — runtime verification pending — PipeWire / WirePlumber user-session activation is not reliable

### Problem

During the LXQt runtime test, the required audio packages were installed but audio was initially not working. Audio began working after the PipeWire/WirePlumber user-session services were manually activated.

This indicates that BFSOS currently does not reliably establish the intended audio stack automatically on first desktop login. The exact cause still needs to be determined: the user-unit enablement/activation logic may be missing, incomplete, or broken.

The intended BFSOS desktop audio stack is:

```text
PipeWire
WirePlumber
PipeWire PulseAudio compatibility service
```

Standalone legacy PulseAudio must not compete with or replace that stack.

### Required work

- Audit the `pipewire`, `wireplumber`, desktop meta-package, installer/bootstrap, and post-install logic that is responsible for activating the per-user audio session.
- Ensure a freshly installed desktop does **not** require the user to manually run `systemctl --user enable --now ...` before audio works.
- Verify the relevant PipeWire user socket/service units and WirePlumber user service are installed in a location visible to the systemd user manager.
- Ensure the PipeWire PulseAudio compatibility service/socket is present and automatically usable by applications that speak the PulseAudio protocol.
- Determine whether BFSOS should rely on socket activation, explicit user-unit enablement, systemd user presets, desktop-session startup, or a coordinated combination; make the chosen behavior deterministic.
- Ensure WirePlumber is pulled in automatically by the correct package dependencies rather than being an optional/manual afterthought.
- Prevent standalone legacy `pulseaudio` from autostarting or competing for the PulseAudio socket when PipeWire is selected as the default audio stack.
- Do not solve this only in LXQt. Apply the same audio-session policy consistently to Plasma, XFCE, LXQt, GNOME, and other supported graphical sessions.
- Verify the solution works for a newly created user as well as for an existing user with no manually enabled PipeWire/WirePlumber units.
- Document any required systemd user presets or package post-install hooks so future package updates do not regress first-login audio.

### Validation

On a clean installation and a fresh user account, log into each supported desktop without manually starting audio services and verify:

```bash
systemctl --user status \
  pipewire.service \
  pipewire.socket \
  pipewire-pulse.service \
  pipewire-pulse.socket \
  wireplumber.service \
  --no-pager
```

Confirm the expected processes are running:

```bash
pgrep -a -f 'pipewire|wireplumber|pulseaudio'
```

Confirm PulseAudio-compatible clients are actually connected to PipeWire:

```bash
pactl info
```

The server should identify PipeWire as the backend rather than a standalone PulseAudio daemon.

Confirm WirePlumber sees the devices and default nodes:

```bash
wpctl status
```

Then verify:
- audio works immediately on first login;
- output and input devices are visible;
- volume controls work;
- logout/login preserves working audio;
- reboot preserves working audio;
- switching between supported desktop sessions does not require manual service activation;
- standalone PulseAudio is not started alongside PipeWire.

### Observed status

**SOURCE IMPLEMENTED — runtime verification pending.** Audio works after manual user-service activation, so the packages themselves are functional; the remaining defect is automatic session/service activation and default-stack integration.


## IMPLEMENTED — runtime verification pending — Add KDE Plasma Login Manager as an optional Plasma greeter/display manager

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

### Status

**SOURCE IMPLEMENTED — build/login/runtime verification pending.**
