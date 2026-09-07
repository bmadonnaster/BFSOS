# BFSOS Fix Tracker — r253
Updated: 2026-09-07

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
