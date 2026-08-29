# BFSOS Installer v50 Test / Fix Tracker

## r215 — Stage 2 p11-kit/Meson dependency-order fix — 2026-08-29

### [~] FIXED IN SOURCE / resume + clean-bootstrap regression pending — p11-kit failed because Meson was unavailable

- Full Bootstrap reached Stage 2 and failed while building `p11-kit 0.26.5`: the recipe invoked `meson setup`, but `/usr/bin/meson` was not installed yet (`Pkgfile: line 33: meson: command not found`).
- Root cause: the Stage-2 `basepkg` order placed `p11-kit`/`make-ca` before the final Python packaging stack and `meson`; additionally, `p11-kit` did not declare `meson` as a hard build dependency.
- `p11-kit` release bumped to 4 and now declares `libtasn1 meson`.
- `meson` now explicitly declares `ninja`, `python3-pip`, and `python3-setuptools`; `python3-setuptools` now explicitly declares `python3`.
- Stage-2 order now builds the final Python packaging stack and `meson` before `p11-kit`, with `make-ca` immediately after `p11-kit`.
- Static audits now require the dependency metadata and enforce `meson < p11-kit < make-ca` in the Stage-2 list.
- This failure is independent of the Full Bootstrap orchestration itself: the automation correctly stopped on the package failure and r214's improved failure dialog captured the exact package log and command.
- Added `./bootstrap.sh resume-full` / `continue-full`: it detects the first incomplete stage from existing completion markers, preserves successful work, and continues automatically through Stage 5. For this failure it should resume at Stage 2 instead of rebuilding Stage 1.
- **Regression:** resume the failed Stage 2 and verify already-installed packages are skipped, Meson is installed before p11-kit, p11-kit and make-ca complete, then continue Stages 3/4/5. Repeat once from a completely clean Full Bootstrap before closing.


## r214 — Full Bootstrap Stage-1 startup/preflight fix — 2026-08-28

### [~] IMPLEMENTED IN SOURCE / clean-bootstrap runtime regression pending — Full Bootstrap must start Stage 1 cleanly and report pre-package failures

- r213 Full Bootstrap could fail before the first package log while presenting only `No package log excerpt was available.`
- The Full Bootstrap confirmation now explicitly states that the automatic 1 -> 2 -> 3 -> 4 -> 5 path starts from a clean build state. Downloaded source archives are retained.
- After the user confirms Full Bootstrap, Stage 1 no longer drops into the older raw-terminal `Type YES` clean-start prompt. The already-confirmed Full Bootstrap path performs the clean start directly.
- Full Bootstrap validates `sudo` availability/authentication before destructive cleanup or root stages begin.
- Stage 1 now creates a preflight transcript before package builds. Until a package-specific failure log exists, the failure dialog uses this preflight log so cleanup/path/permission/port-resolution failures are visible instead of reporting that no package log exists.
- Stage 1 explicitly checks clean-start success, safely retries removal of a stale/root-owned `/tmp/lfs-tools` path through sudo when necessary, validates toolchain-directory and symlink creation, and reports port-resolution failure before the first package build.
- `bash -n bootstrap.sh`: PASS for r65.
- **Runtime regression:** from a host with stale/root-owned `/tmp/lfs-tools` and/or `/tmp/lfs-rootfs`, select Full Bootstrap and verify clean startup reaches `binutils-pass1`; independently force a pre-package failure and verify the dialog names the Stage-1 preflight log and shows the real failure reason.



## r213 — Full Bootstrap one-action workflow — 2026-08-28

### [~] IMPLEMENTED IN SOURCE / clean-bootstrap runtime regression pending — run Stages 1 → 2 → 3 → 4 → 5 automatically, then finish or launch installer

- Added a dedicated **Run Full Bootstrap (Stages 1 → 2 → 3 → 4 → 5)** action to the main Bootstrap menu.
- The full workflow deliberately includes Stage 3 (final-toolchain rebuild), even though Stage 3 remains optional when the individual stage menu is used manually. This provides a maximal clean/rebuilt base path before release testing.
- Full Bootstrap starts from the normal unprivileged Bootstrap process because Stage 1 must run as a regular user. Root-required Stages 2–5 continue through the existing sudo/root stage dispatcher.
- Stages run strictly in order: temporary toolchain → base system → final-toolchain rebuild → verification → base archive creation. A nonzero result from any stage stops the sequence immediately; later stages are never attempted after a failure.
- Normal successful Stage-1 and Stage-5 acknowledgement dialogs are suppressed during Full Bootstrap so the sequence can continue without requiring an OK click between successful stages. Individual/manual stage behavior is unchanged.
- Stage 5 still requires the Stage-4 verification marker and still creates and validates the normal `bfs-rootfs-*.tar.xz` archive. Full Bootstrap does not bypass any existing stage prerequisite or validation.
- After Stage 5 succeeds, Bootstrap presents exactly two completion choices when an installer is available: **Launch installer** or **Done**. Launch uses the existing newest-real-installer/newest-valid-base-archive handoff; Done returns without starting installation.
- Added direct CLI aliases `full`, `full-bootstrap`, and `all` for the same orchestration. Interactive start confirmation defaults to Cancel; `BFS_FULL_BOOTSTRAP_ASSUME_YES=yes` is available only for intentional scripted/noninteractive use.
- Existing checksum/signature/footprint settings remain authoritative during the full sequence. Full Bootstrap does not silently disable integrity checks; all verification controls remain secure-by-default unless the user deliberately changed them in Bootstrap Settings.
- Bootstrap Settings now also exposes **Integrity verification** as its own category so MD5/checksum, source-signature, and footprint controls are no longer discoverable only inside Compiler / build settings. The controls still default to enabled, and **Restore secure defaults** re-enables all three.
- Extended `scripts/bfs-release-static-audit.sh` to require the full-workflow function, ordered `1 2 3 4 5` loop, menu/CLI entry, sudo propagation flag, and final **Launch installer / Done** actions.
- **Runtime regression still required:** perform a clean Full Bootstrap from an empty rootfs/toolchain state; prove Stages 1–5 advance without intermediate success prompts; deliberately fail a package during one stage and confirm all later stages are skipped; complete a successful run and test both **Done** and **Launch installer** endings.


## r212 — Xfce / Compiz complete meta-package installation paths — 2026-08-28

### [x] IMPLEMENTED IN SOURCE — add a full `xfce4-meta` and harden `compiz-meta`

- Added `ports/xfce/xfce4-meta` so a clean BFSOS system can install the complete normal Xfce desktop with one `prt-get depinst xfce4-meta` operation rather than knowing every core Xfce component individually.
- `xfce4-meta` pulls the complete user-facing Xfce desktop baseline: session, settings, panel, desktop, XFWM, appfinder, Thunar/volman, Tumbler, power manager, plus `xfce4-apps-meta`; lower-level Xfce libraries are pulled transitively by those packages. Development-only helpers remain dependencies only where the real packages require them rather than being forced solely by the desktop meta-package.
- Existing `xfce4-apps-meta` remains the application-bundle meta package and is now consumed by the new complete desktop meta package.
- Existing `ports/compiz/compiz-meta` already provided the maintained Compiz Reloaded stack; its dependency list is now made explicit for `compiz-bcop` as well, alongside Compiz core, libcompizconfig, Python config bindings, CCSM, main/extra plugins, Emerald, and Emerald themes.
- Bumped `compiz-meta` release to `2` for the dependency-policy change.
- Extended both static audits to require both meta packages and their expected dependency closure, preventing either one-command desktop installation path from silently disappearing.
- **Install targets for the clean VM:** `prt-get depinst xfce4-meta` for the complete Xfce desktop and `prt-get depinst compiz-meta` for the complete maintained Compiz Reloaded stack. Runtime login/Compiz-under-Xfce testing remains part of the graphical regression queue.

## r212 — kernel Zstd module-compression enforcement — 2026-08-28

### [~] IMPLEMENTED IN SOURCE / clean-build + boot regression pending — force every mainline and LTS kernel module to install as `.ko.zst`

- **Root cause confirmed:** the kernel recipes selected `CONFIG_MODULE_COMPRESS_ZSTD=y` but did not force `CONFIG_MODULE_COMPRESS_ALL=y`. The saved mainline and LTS configs were also still selecting XZ and explicitly leaving `CONFIG_MODULE_COMPRESS_ALL` disabled, so `make modules_install` was not guaranteed to compress every installed module with Zstandard.
- Updated both `ports/core/linux` and `ports/core/linux-lts` saved configs to use `CONFIG_KERNEL_ZSTD=y`, `CONFIG_MODULE_COMPRESS=y`, `CONFIG_MODULE_COMPRESS_ZSTD=y`, and `CONFIG_MODULE_COMPRESS_ALL=y`; Gzip kernel compression and XZ/Gzip module compression are explicitly disabled.
- Updated both kernel Pkgfiles to enforce the same policy through `scripts/config` after loading the saved config and to fail if Kconfig reconciliation does not retain it.
- Added `zstd` as an explicit build dependency for both kernel packages so `modules_install` cannot depend on an undeclared host tool.
- Added package-stage verification immediately after `modules_install`: fail if any raw `.ko`, `.ko.xz`, or `.ko.gz` module remains, and fail if no `.ko.zst` modules were produced. This turns future compression regressions into package-build failures instead of silently shipping the wrong module format.
- Bumped the mainline kernel package release to `2` and the LTS package release to `4` so the packaging-policy change is visible to upgrades/rebuilds.
- Extended both static audit scripts to require the recipe policy, saved-config policy, explicit `zstd` dependency, and `.ko.zst` output verification.
- **Static validation:** kernel Pkgfiles and audit scripts pass `bash -n`; `git diff --check` passes for the changed kernel/audit files; `scripts/bfs-ports-static-audit.sh` and `scripts/bfs-release-static-audit.sh` both pass.
- **Runtime/build regression still OPEN:** on the next clean build, build both `linux` and `linux-lts`, verify `find /usr/lib/modules/<kernel> -type f -name '*.ko'` returns nothing, verify modules are present as `*.ko.zst`, run `depmod`, build the Dracut initramfs, and cold-boot both kernels. Also verify MD/LUKS/LVM modules are discoverable/loadable from their compressed form.

## r211 — full tracker source-implementation / reconciliation pass — 2026-08-28

### [x] SOURCE PASS COMPLETE — all safely source-actionable tracker work in the supplied tree was reviewed and either implemented, reconciled with an existing implementation, or moved to an explicit runtime/architecture queue

- **Scope rule for r211:** this pass does **not** falsely mark VM-, hardware-, fresh-install-, cold-boot-, graphical-session-, upgrade-, or long package-build regressions complete. Historical tracker entries remain as evidence. Where an older entry says a source change is still missing, this r211 section supersedes that source-status statement when the implementation below is present.
- **Validation:** `git diff --check` passes. `scripts/bfs-ports-static-audit.sh` passes. New aggregate `scripts/bfs-release-static-audit.sh` passes.
- A detailed change and remaining-runtime report is stored in `docs/BFSOS-tracker-r211-source-pass-20260828.md`.

### [~] IMPLEMENTED IN SOURCE / runtime regression pending — global `/opt` build environment

- `pkgmk.conf` now establishes explicit build-time support for `/opt/rustc`, `/opt/qt6`, `/opt/kf6`, and `/opt/qt5`, including `PATH`, `PKG_CONFIG_PATH`, `CMAKE_PREFIX_PATH`, `QT6DIR`, `QT5DIR`, and `KF6_PREFIX` where the prefixes exist.
- `aaa_filesystem/kf6.sudoers` preserves the relevant Qt/KF/CMake/pkg-config variables through sudo where required.
- This supersedes the source-side part of the older global profile/build-environment item exposed again by VLC's `qmake6` failure. Keep runtime `sudo`/`prt-get`/`pkgmk` environment verification OPEN.

### [~] IMPLEMENTED IN SOURCE / runtime regression pending — pkgmk source-cache collision and package-output cleanup

- `PKGMK_SOURCE_DIR` is now namespaced as `/var/cache/pkg/sources/$name`, preventing unrelated ports that use the same source basename from reusing one another's cached bytes while preserving per-port `renames=` semantics.
- `bfs-pkgmk` failed-package cleanup now honors a configured `PKGMK_PACKAGE_DIR` instead of assuming only `/var/cache/pkg/packages`.
- Keep deliberate collision, interrupted-download, alternate package-directory, and stale-cache runtime regressions OPEN.

### [~] IMPLEMENTED IN SOURCE / runtime regression pending — `prt-get sysup` pkgutils ordering

- `prt-get` now installs a small front-end wrapper and keeps the compiled binary as `/usr/libexec/prt-get.real`.
- A real `sysup` preflights `pkgutils` with the real binary before proceeding, preventing packages that require newer BFSOS pkgmk extensions from being interpreted by an older installed pkgutils during the same upgrade transaction.
- `--test`/`-t` remains non-mutating. Keep real sysup tests OPEN for both an already-current pkgutils and a pkgutils-in-update-set case.

### [~] IMPLEMENTED IN SOURCE / build + upgrade regression pending — Qt5 WebEngine split

- Base `qt5` explicitly skips `qtwebengine` and no longer carries WebEngine-only dependencies.
- Added `ports/opt/qtwebengine5` for Qt 5.15.19 under the shared `/opt/qt5` prefix, with current compatibility patch handling and fail-fast qmake/build/install logic.
- The supplied Qt6 policy was already correctly split (`qt6` + `qt6-webengine`) and remains separate; `khelpcenter` remains a known Qt6 WebEngine consumer.
- Static dependency searches found no additional declared Qt5 WebEngine consumers in the supplied tree requiring conversion.
- Keep clean-build, install, ownership migration from the old monolithic Qt5 package, and representative consumer regressions OPEN before closing historical r204.

### [~] IMPLEMENTED IN installer r71 / runtime matrix pending — equal `/home` + `/var` LVM allocation

- New current installer: `scripts/install-bfs-menu-v50-r71-lvm-equal-split.sh`; `install-bfs-menu-current.sh` points to r71.
- The equal-split workflow snapshots the original free extent count once, allocates half to `/home` and the remainder to `/var`, shows both planned values before destructive creation, and validates actual sizes within one PE afterward.
- It no longer performs two sequential `50%FREE` operations.
- Keep the r203/r87 runtime matrix OPEN: clean VG, pre-existing allocations, odd extent counts, both creation orders where applicable, explicit `%VG`, explicit single-LV `%FREE`, retry/recovery, and final mount validation.

### [~] IMPLEMENTED IN SOURCE / cold-boot regression pending — Linux LTS MD personality policy and initramfs verification

- Linux LTS now matches the normal BFSOS MD policy: `CONFIG_MD=y` with Linear/RAID0/RAID1/RAID10/RAID456 personalities built as modules.
- Installer r71 initramfs verification now reads the installed kernel config: a required driver configured `=y` is accepted as built-in, `=m` requires its `.ko` in the initramfs, and an unsupported/disabled personality fails explicitly.
- Keep normal/LTS cold-boot matrices OPEN, including MD→LUKS→LVM, degraded/failure cases already tracked, and both built-in/module verifier paths.

### [~] IMPLEMENTED IN SOURCE / fresh-install regression pending — SDDM, Plasma defaults, screen locker, and Qt6 multimedia integration

- `plasma-meta` now explicitly depends on `sddm`, retains exactly one `phonon-backend-vlc`, and retains PipeWire/WirePlumber default user-unit integration.
- SDDM is modernized to BFSOS `pkg_build()` semantics and its package hook enables `sddm.service` where systemd is available.
- `kscreenlocker` no longer hard-depends on obsolete ConsoleKit; its hard dependency policy now targets the current systemd/logind/PAM/Qt6/KF6 stack.
- `scripts/bfs-desktop-integration-check.sh` now checks SDDM, locker linkage/PAM, PipeWire/WirePlumber/Pulse compatibility, Qt6 Phonon-VLC, VLC Qt6 linkage, and RTKit state.
- VLC 3.0.23 Qt6 GUI and the Qt6 Phonon VLC backend remain runtime-verified from r210.
- Keep fresh login, repeated lock/unlock, X11/Wayland, suspend/resume, portal, RTKit, and fresh-user audio activation regressions OPEN.

### [~] IMPLEMENTED IN SOURCE / cold-cache and upgrade regression pending — CA / p11-kit / NSS trust initialization

- Corrected dependency direction so `make-ca` depends on `p11-kit`; `p11-kit` no longer depends on `make-ca`.
- `make-ca` creates the expected PKI directories and now has post-install generation/refresh logic (`-g` for initial population, `-r` for refresh), trust/bundle validation, and `update-pki.timer` enablement where available.
- `ca-certificates` refreshes make-ca state when the trust tooling is installed.
- Bootstrap final base packages now include the complete trust stack needed before installed-system HTTPS validation.
- Added `scripts/bfs-trust-check.sh` for canonical bundle, anchors, p11-kit/NSS, curl HTTPS, and certificate-count checks.
- Keep r209 fresh-install, Firefox/NSS, timer, and upgrade-order regressions OPEN.

### [~] IMPLEMENTED IN SOURCE / build/runtime pending — route diagnostics, NetworkManager, libnotify, xterm

- Added a `traceroute` 2.1.6 core port and included it in the Bootstrap final base set.
- Updated NetworkManager to 1.58.1 while retaining the normal default-feature dependency policy; source audit shows the large closure previously associated with Lynx is not caused by the Lynx recipe itself.
- Reduced `libnotify` hard dependencies to `gdk-pixbuf` and disables tests so GTK4 is not pulled merely for its test suite.
- Updated xterm to 411.
- Keep package-build and real-network/runtime tests OPEN.

### [x] SOURCE MODERNIZATION — legacy `build()` eliminated from maintained 64-bit collections

- Migrated remaining legacy recipes in `core`, `opt`, `xorg`, `plasma`, `contrib`, `gnome`, `lxqt`, `xfce`, and `compiz` to BFSOS `pkg_build()` semantics and reconciled extracted-source-directory assumptions with the current pkgmk extension.
- Static audit now requires zero legacy `build()` definitions in those maintained 64-bit trees.
- Duplicate hard dependency tokens found during the pass were removed.
- **Intentional exception:** `compat-32` remains outside this migration because the tracker separately calls for replacing/redesigning the duplicated 32-bit recipe architecture. Do not treat the existing 167 compat-32 legacy recipes as closed work; that architecture remains OPEN.
- Keep representative/full long-build regression OPEN before release, especially for recipes not exercised in the current VM yet.

### [x] SOURCE UX FIX — Bootstrap Stage 1 redundant success acknowledgement removed

- After successful Stage-1 archive validation, Bootstrap now returns directly to the main menu rather than displaying an extra acknowledgement-only success dialog. Failure/error paths remain explicit.

### [x] STATIC RELEASE AUDIT EXPANDED

- `scripts/bfs-ports-static-audit.sh` now additionally guards maintained-tree `pkg_build()` migration, Qt5 WebEngine split, Plasma SDDM/Phonon metadata, `/opt` build environment, and trust dependency direction.
- New `scripts/bfs-release-static-audit.sh` aggregates source policy checks across Bootstrap, current installer, ports, trust, Qt WebEngine splits, Plasma defaults, MD policy, source-cache namespacing, pkgutils/sysup ordering, and duplicate dependency metadata.
- Both audits pass in the r211 source tree.

### [ ] REMAINING R211 RELEASE QUEUE — requires VM/bare-metal/runtime or focused architecture work

- Clean Bootstrap/base build from empty caches, including real mirror failover and trust initialization.
- Build/install/upgrade regression for `qt5` + new `qtwebengine5`; verify ownership migration and real WebEngine consumers.
- Real `prt-get sysup` pkgutils-first tests and package-cache/source-cache collision tests.
- Fresh r71 installer storage matrix including equal LVM split and all previously tracked MD/LUKS/LVM recovery/boot combinations.
- Fresh SDDM/Plasma login, screen locker, audio/RTKit, X11/Wayland, portal, and desktop-session regressions.
- Fresh trust/NSS/Firefox and package upgrade-order regressions.
- X.Org/Wayland and other graphical/runtime package matrices; installed-file ownership/orphan cleanup that requires the live VM database/filesystem.
- Full long-build regression for converted recipes.
- `compat-32` architectural redesign/per-port 32-bit support.
- First-class generalized package lifecycle-hook architecture beyond existing package-specific hooks.
- Hardware-, GPU-, suspend/resume-, degraded RAID-, bare-metal-, and boot-media-specific tests that cannot be executed from the supplied source archive.

**r211 status:** all source-actionable work that can be changed responsibly from the supplied tree has been worked in this pass. Remaining items above stay OPEN because they require evidence that cannot be manufactured by static source inspection.

## r204 tracker update — split Qt5 QtWebEngine into `qtwebengine5` and repair affected dependencies — 2026-08-27

### [ ] OPEN — Rework Qt5 so QtWebEngine5 is a separate package and audit every affected port

-   **Regression / incomplete modernization confirmed:** the current BFSOS `qt5` port is still configured as a monolithic Qt5 build that includes QtWebEngine. The intended cleanup to keep legacy Qt5 available while moving QtWebEngine5 into its own package was not completed.
-   **Required package-layout policy:** keep the main `qt5` package under `/opt/qt5`, but build it **without QtWebEngine**. Create/restore a separate `qtwebengine5` port for the Qt 5.15.x WebEngine component and its WebEngine-specific build dependencies.
-   The base `qt5` package must not force Chromium/WebEngine dependencies, large WebEngine source/build cost, or WebEngine-only tools onto every package that merely needs Qt5 Core/Gui/Widgets/Network/etc.
-   `qtwebengine5` must depend on the matching `qt5` version/release family and install into the same Qt5 prefix in a way that cleanly extends the Qt5 installation without overwriting unrelated files. Version compatibility between `qt5` and `qtwebengine5` must be explicit and regression-tested.
-   **Audit all BFSOS ports that currently depend on `qt5`, old `qtwebengine`, `qtwebengine5`, Qt5 WebEngine libraries, or WebEngine CMake/qmake modules.** Packages that only need ordinary Qt5 must depend on `qt5` alone. Packages that actually use Qt WebEngine must depend on `qtwebengine5` (and transitively `qt5`) rather than relying on WebEngine being bundled inside `qt5`.
-   Search dependency metadata and recipes for at least: `qt5`, `qtwebengine`, `qtwebengine5`, `Qt5WebEngine`, `Qt5WebEngineCore`, `Qt5WebEngineWidgets`, `WebEngine`, and any direct `/opt/qt5` WebEngine paths. Remove stale/obsolete dependency names and update affected releases.
-   Review the Qt5 configure/module-selection logic so WebEngine is unambiguously excluded from the main `qt5` build rather than merely skipped accidentally because of a missing dependency.
-   Review `qtwebengine5` build requirements separately (Chromium toolchain requirements, Python, Ninja, Node/GN-related tooling where applicable, NSS/NSPR, ICU, multimedia, X11/Wayland, system libraries, and any GCC 16 compatibility patches) instead of bloating the base Qt5 dependency closure.
-   Keep the Qt6 policy separate: Qt6/QtWebEngine6 decisions must not be conflated with the legacy Qt5 split. The package name `qtwebengine5` should clearly identify the Qt5 component and avoid ambiguity with Qt6.
-   **Migration/upgrade behavior:** ensure upgrading from the current monolithic `qt5` package does not leave orphaned Qt5 WebEngine files behind. Determine ownership of files formerly shipped by `qt5`, move ownership to `qtwebengine5`, and document/implement any reinstall ordering needed for a clean upgrade.
-   **Regression tests:**
    - clean-build/install `qt5` alone and verify no Qt5 WebEngine libraries, headers, CMake files, qmake modules, helpers, or resources are present;
    - build a representative non-WebEngine Qt5 application using only `qt5`;
    - install/build `qtwebengine5` afterward and verify Qt5 WebEngine applications compile and run;
    - run `prt-get depinst` on representative Qt5 packages and confirm ordinary Qt5 consumers do not pull `qtwebengine5`;
    - run `prt-get depinst` on actual Qt5 WebEngine consumers and confirm `qtwebengine5` is pulled automatically;
    - test upgrade from the old monolithic Qt5 package and verify package ownership/footprints contain no stale or duplicate WebEngine files.
-   **Tracker policy correction:** earlier tracker text that preferred/verified a monolithic Qt5 package with QtWebEngine included is superseded by this r204 item. Keep the Qt5 rehabilitation work OPEN until the split package layout and dependency audit pass clean-build and upgrade regressions.

## r203 tracker update — LVM `/home` + `/var` equal-split sizing regression — 2026-08-27

### [ ] OPEN — Installer still does not create the intended 50/50 `/home` and `/var` LVM layout

-   **Fresh installed-system regression confirmed:** after the current installer run, the resulting LVM logical-volume sizes for `/home` and `/var` still do not match the intended equal 50/50 allocation. The previous LVM percentage-sizing work therefore remains unresolved for the automatic/recommended `/home` + `/var` layout.
-   **Important `%FREE` semantic trap:** two sequential `lvcreate -l 50%FREE` operations do **not** create two equal halves of the original free space. The first LV consumes 50% of the then-free extents; the second consumes 50% of what remains (about 25% of the original VG), leaving roughly 25% unallocated. If the installer currently uses `50%FREE` independently for both `/home` and `/var`, that logic is inherently wrong for an intended equal split.
-   **Required behavior:** when the user requests/reviews an equal split of the available VG space between `/home` and `/var`, calculate both LV allocations from the **same initial free-extent total** before creating either LV, or use an equivalent deterministic strategy (for example create the first LV from the calculated half and allocate the intended remainder to the second). Do not let creation order change the requested ratio.
-   **Preserve explicit manual semantics:** a user-entered `50%FREE` for a single LV should continue to mean 50% of the free extents at the moment that command is intentionally requested. The fix is specifically to the paired/automatic equal-split workflow, not to redefine native LVM `%FREE` semantics globally.
-   **UI/review requirement:** before destructive LV creation, show the calculated sizes/extents for both `/home` and `/var` together and make it clear whether the choice is an equal split of the original available space, `%VG`, or a literal per-command `%FREE` request.
-   **Post-create validation:** immediately query `lvs`/`vgs` after creation and verify the actual LV sizes are within one physical extent of the planned values. Treat a material mismatch as an installer error rather than silently continuing.
-   **Regression matrix:** test a clean VG with only `/home` and `/var`; a VG with pre-existing allocations; odd/non-even free-extent counts; both LV creation orders; explicit `50%VG`; explicit single-LV `50%FREE`; and the installer equal-split preset. Confirm the equal-split preset produces two approximately equal LVs and does not unexpectedly leave one quarter of the original free space unused.
-   **Existing tracker relationship:** keep the earlier r87 LVM sizing/percentage-validation work open for runtime regression. That work correctly distinguishes `%FREE` from `%VG`, but this fresh install demonstrates that the higher-level paired `/home` + `/var` allocation policy still needs correction.


## pkgmk / source-download resilience --- X.Org fallback and network diagnostics

-   [ ] **Review and restore useful default `pkgmk.conf` backup/source
    mirrors.** During X.Org troubleshooting, the default backup/source
    mirror URLs in `pkgmk.conf` were found commented out. Audit the
    shipped/default, bootstrap-generated, installer-generated, and final
    installed `/etc/pkgmk.conf` so useful fallback behavior is not
    accidentally disabled.
-   [ ] **Do not add fake/nonexistent BFSOS distfile hosts.** A
    `distfiles.bfsos.org` entry was encountered and removed because no
    such BFSOS distfiles service is currently configured.
-   [ ] **X.Org source resilience:** Current X.Org downloads redirect
    from `www.x.org` toward `xorg.freedesktop.org`; the latter timed out
    from the test system even though DNS resolution and general Internet
    connectivity worked. Avoid permanently rewriting all X.Org Pkgfiles
    merely to work around a transient routing/upstream-reachability
    problem.
-   [ ] **Keep a usable flat fallback where practical.**
    `https://mirror.freedif.org/pub/blfs/conglomeration/Xorg`
    successfully supplied `util-macros-1.20.2.tar.xz`, allowing
    `util-macros` to build in about 3 seconds, but the mirror does not
    contain every current X.Org source (for example
    `font-util-1.4.1.tar.xz`). Treat it as a partial fallback, not a
    complete X.Org mirror.
-   [ ] **Investigate a robust X.Org fallback strategy** that preserves
    package/category paths when required and can use more than one
    source without causing long repeated timeouts. Retain
    checksum/signature verification.
-   [ ] **Add network route-diagnostic tooling to BFSOS ports/base
    diagnostics.** The test system had neither `tracepath` installed nor
    a `traceroute` port (`prt-get search traceroute` returned no
    matches). Add `traceroute` and/or the package providing `tracepath`
    so routing failures can be diagnosed from a stock BFSOS
    installation.

## r121 implementation pass --- MD boot persistence + serial console + Git-backed BFSOS ports --- 2026-08-22

-   **Installer r57 created:**
    `scripts/install-bfs-menu-v50-r57-git-md-boot-fixes.sh`;
    `scripts/install-bfs-menu-current.sh` now points to r57.
-   [x] **MD Linear/JBOD GRUB discovery fix implemented / fresh-install
    runtime regression pending:** required-MD discovery now recognizes
    Linux `lsblk` type `md` as well as `raid*`. This closes the exact
    static defect that caused the six-member Linear/JBOD array to be
    omitted from topology-derived `rd.md.uuid=` generation. MD UUID
    arguments remain stable-identity based and deduplicated.
-   [x] **Required `/etc/mdadm.conf` generation implemented / runtime
    regression pending:** r57 generates the installed target
    configuration only from MD UUIDs that are ancestors of the selected
    BFSOS filesystem topology. It filters `mdadm --detail --scan`
    against that required UUID set, avoids unrelated live-environment
    arrays, deduplicates output, and fails finalization if a required
    array cannot be represented.
-   [x] **Initramfs MD persistence verification strengthened:** when MD
    is required, final initramfs validation now requires the Dracut
    `mdraid` module, required RAID kernel drivers, and embedded
    `etc/mdadm.conf`. GRUB `rd.md.uuid=` generation and `mdadm.conf`
    generation use the same required-topology discovery path.
-   [x] **Optional serial troubleshooting console implemented / runtime
    regression pending:** System Settings and Installer Settings now
    expose a persisted `SERIAL_CONSOLE` toggle, default `no`. When
    enabled it adds `console=ttyS0,115200 console=tty0`;
    disabling/remaking GRUB strips only the installer-managed serial
    tokens so repeated changes are idempotent. Final review shows the
    setting.
-   [x] **BFSOS-owned ports migrated from HttpUp configuration to one
    Git-backed monorepo definition / network regression pending:** the
    corrected single-branch architecture from r108 is used.
    `/etc/ports/bfsos.git` points at
    `https://codeberg.org/bmadonnaster/BFSOS.git`, branch `main`, and
    maps all ten BFSOS collection directories from one repository
    checkout.
-   [x] **No ten-clone duplication:** the BFSOS extension to the CRUX
    Git driver adds an optional `COLLECTIONS=` monorepo mode. One cached
    checkout under `/var/cache/ports-git/bfsos` services `compat-32`,
    `compiz`, `contrib`, `core`, `gnome`, `lxqt`, `opt`, `plasma`,
    `xfce`, and `xorg`. Ordinary third-party `.git` definitions still
    use the stock single-collection behavior.
-   [x] **Git ports update safety implemented:** a complete remote
    snapshot is fetched/exported before `/usr/ports` is changed; first
    migration moves existing HttpUp trees into a timestamped backup;
    subsequent syncs store manifests and refuse to overwrite detected
    local edits. A failed fetch/export leaves the current ports trees
    unchanged. Local functional tests passed for first migration,
    repeated sync, and local-modification refusal.
-   [x] **Existing-base compatibility implemented --- no new base build
    required for the next install:** Git is removed from the
    optional-package selector. Before the first Git-backed `ports -u`,
    r57 checks for `git`; if absent it seeds the current `ports/opt/git`
    into the extracted old base and runs `prt-get depinst git`, then
    installs the updated Git driver and BFSOS Git config. This allows
    the current saved base archive to be used for the next clean
    install.
-   [x] **Future base policy implemented:** `git` is added to the
    Bootstrap base package list so future archives contain Git from the
    outset. Git port release is bumped to 3 because the installed ports
    driver changed; `prt-get` release is bumped to 3 and now ships
    `bfsos.git` instead of BFSOS `.httpup` definitions.
-   [x] **BFSOS HttpUp maintenance retired:** BFSOS-owned `.httpup`
    collection definitions and generated collection `REPO` manifests
    were removed from the source tree. `bfs-sync-ports.sh`,
    `bfs-update-ports.sh`, and `git-update-bfsos.sh` no longer
    regenerate HttpUp metadata. Generic HttpUp driver support remains
    available for third-party collections.
-   \[\~\] **r117 pkgmk mirror fallback audit:** current CRUX pkgmk
    already defines `PKGMK_SOURCE_MIRRORS` as ordered flat distfile
    fallbacks before the Pkgfile source, and BFSOS `/etc/pkgmk.conf`
    already exposes that array with bounded curl timeout/retry/stall
    handling. No default public BFSOS mirror was invented in this pass;
    runtime failover testing with real mirror endpoints remains pending.
-   [x] **Previously open duplicate tracker items statically
    reconciled:** current r57 retains successful-install
    `clear_resume_state`, human-readable package timing, Install/Retry
    labeling, checkpoint recovery ordering/dedup, and ownership-aware
    failure/success storage cleanup from r49-r56. Their remaining
    tracker work is runtime regression, not missing implementation.
-   **Static validation:** `bash -n` passes for Bootstrap, r57, and
    updated maintainer helpers; `sh -n` passes for the Git driver. The
    Git monorepo driver was functionally exercised against a local
    two-collection repository: initial migration passed, a second sync
    passed, and a deliberate local edit was refused with status 5
    without being overwritten.
-   **Next install regression target using the existing base archive:**
    fresh install -\> automatic pre-sync Git bootstrap if needed -\>
    single-fetch Git `ports -u` -\> sysup -\> layered MD/LUKS/LVM
    install -\> verify target `/etc/mdadm.conf` -\> verify GRUB
    `rd.md.uuid=` -\> verify `lsinitrd` contains mdadm
    configuration/modules -\> cold boot with no manual Dracut recovery.
    Also test the serial-console toggle both disabled and enabled.

## r119 Linear/JBOD installed-system boot regression --- missing Dracut MD kernel argument --- 2026-08-22

-   [x] **RUNTIME ROOT CAUSE CONFIRMED / MANUAL FIX BOOT-TESTED: a
    completed six-member Linear/JBOD -\> LUKS -\> multi-PV LVM
    installation initially dropped to the Dracut emergency shell because
    the installed GRUB kernel command line did not identify the required
    MD array.**
    -   Storage topology under test: six-member MD Linear/JBOD array -\>
        LUKS mapping `cryptraid`, plus a second LUKS mapping
        `cryptroot`; both mappings are LVM PVs in `bfs-vg`; the VG
        provides `root`, `usr`, `opt`, `home`, and `var`.
    -   Initial Dracut failure repeatedly scanned for Btrfs and then
        reported `/dev/bfs-vg/home`, `/dev/bfs-vg/opt`,
        `/dev/bfs-vg/root`, and the other dependent LVs unavailable
        because the MD-backed PV had never appeared.
    -   `/proc/mdstat` showed no assembled array at the failure point
        even though `mdadm`, `cryptsetup`, `lvm`, and `dmsetup` were
        present in the initramfs. `mdadm --examine --scan` correctly
        discovered the saved array UUID
        `c5b01545:77f84a08:8e4fe134:fda98654`.
    -   `lsinitrd` confirmed the Dracut `mdraid` module and required
        RAID kernel modules were present. The failure was therefore not
        a missing `mdadm` binary, missing RAID kernel driver, or omitted
        Dracut mdraid module.
    -   Manual recovery proved the storage stack itself was healthy:
        `mdadm --assemble --scan` assembled all six members,
        `cryptsetup luksOpen` opened the MD-backed LUKS container,
        `lvm vgchange -ay bfs-vg` activated all five LVs, and exiting
        the Dracut shell continued directly into a successful BFSOS
        boot.
    -   **Confirmed boot root cause:** the generated installed-system
        kernel command line contained the required `rd.luks.uuid=` and
        `rd.lvm.lv=` arguments but no `rd.md.uuid=` argument. Dracut's
        mdraid startup therefore had no explicit saved-array identity to
        assemble for this host-only boot path.
    -   Manual persistent test fix added
        `rd.md.uuid=c5b01545:77f84a08:8e4fe134:fda98654` to
        `/etc/default/grub`, regenerated `/boot/grub/grub.cfg`, and
        verified the argument appeared on the normal Linux 7.1.8 boot
        entries.
    -   **Cold reboot PASSED:** after regenerating GRUB with the MD UUID
        argument, the machine booted normally without manual `mdadm`,
        `cryptsetup`, or LVM commands in the Dracut shell.
-   [x] **IMPLEMENTED in installer r57 / fresh-install runtime
    regression pending:** topology-derived boot configuration must emit
    the required Dracut MD activation argument for every MD array that
    participates in the installed root/storage dependency graph.
    -   Prefer stable MD identity, not `/dev/md0`/`/dev/md127` pathname.
        Generate `rd.md.uuid=<MD UUID>` from the installed topology for
        each required array.
    -   Preserve all existing topology-derived `rd.luks.uuid=`,
        `rd.lvm.lv=`, root device, `rootflags=`, console, and other
        kernel arguments; adding MD activation must be additive and
        idempotent.
    -   Write the persistent value through `/etc/default/grub` so later
        `grub-mkconfig` runs and kernel upgrades retain the correct MD
        activation arguments.
    -   Support every installer MD level through the same topology
        logic: Linear/JBOD, RAID0, RAID1, RAID4, RAID5, RAID6, and
        RAID10. Do not special-case only Linear.
    -   Deduplicate MD UUID arguments when an array backs more than one
        downstream mapping/PV/LV.
    -   When the installer builds the initramfs, verify the required
        Dracut mdraid module/tools are included whenever the boot
        topology depends on MD; the current failing image did contain
        them, but this remains a useful final-validator check.
    -   **Regression matrix:** (1) Linear/JBOD -\> LUKS -\> LVM cold
        boot; (2) MD -\> LUKS without LVM where supported; (3) MD -\>
        LVM without LUKS where supported; (4) multi-PV VG spanning
        MD-backed and non-MD-backed LUKS PVs; (5) repeat `grub-mkconfig`
        and verify no duplicate `rd.md.uuid=` values; (6) verify
        array-node renumbering such as `md0` -\> `md127` does not affect
        boot because UUID identity is used.
    -   **Release criterion:** a fresh installer-generated configuration
        must cold boot the full layered topology without any manual
        Dracut-shell `mdadm --assemble --scan`, `cryptsetup luksOpen`,
        or `vgchange` recovery commands.
-   [x] **IMPLEMENTED in installer r57 / fresh-install runtime
    regression pending: generate and install a correct `/etc/mdadm.conf`
    for installer-created MD arrays, including Linear/JBOD.**
    -   The completed Linear/JBOD test installation did not have the
        required installed-system MD array definition in
        `/etc/mdadm.conf`; this is separate from the missing
        `rd.md.uuid=` GRUB argument.
    -   Generate the installed target's MD configuration from the arrays
        actually created/adopted for that installation rather than
        assuming only RAID levels reported as `raid*` require
        persistence. Linux MD Linear/JBOD must be included.
    -   Persist each required array using stable MD metadata/UUID
        identity so boot does not depend on a transient device node such
        as `/dev/md0` versus `/dev/md127`.
    -   Ensure `/etc/mdadm.conf` is written inside the target system
        before initramfs generation and that the generated initramfs
        receives the same required array configuration where Dracut's
        host-only boot path needs it.
    -   Do not copy unrelated arrays from the live environment into the
        installed target. Limit generated entries to arrays belonging to
        the selected/installed BFSOS storage topology.
    -   Make regeneration idempotent: rerunning
        installation/finalization must update or replace BFSOS-managed
        array entries without creating duplicate `ARRAY` records.
    -   Keep `mdadm.conf` generation and GRUB `rd.md.uuid=` generation
        derived from the same authoritative installer MD topology so the
        two boot mechanisms cannot drift.
    -   **Validation:** after installation, verify `/etc/mdadm.conf`
        contains the expected Linear/JBOD array UUID,
        `mdadm --examine --scan` agrees with the recorded identity,
        `lsinitrd` shows the required MD configuration/module content,
        and `/boot/grub/grub.cfg` contains the matching `rd.md.uuid=`.
    -   **Regression matrix:** repeat this validation for Linear/JBOD,
        RAID0, RAID1, RAID4, RAID5, RAID6, and RAID10 as those runtime
        layout tests are completed.
    -   **Release criterion:** no installer-created MD-dependent BFSOS
        installation may require the user to manually create
        `/etc/mdadm.conf` or manually add an MD UUID to GRUB in order to
        cold boot.

## r118 GRUB serial-console troubleshooting option --- 2026-08-22

-   [x] **IMPLEMENTED in installer r57 / runtime regression pending ---
    INSTALLER GRUB OPTION: expose an optional serial console for
    troubleshooting early boot and Dracut failures.**
    -   Add a user-selectable GRUB/kernel-console option in the
        installer rather than requiring a manual one-boot edit at the
        GRUB menu.
    -   Confirmed required QEMU/libvirt-friendly ordering:
        `console=ttyS0,115200 console=tty0`. Keep `console=tty0` last so
        the graphical/local console remains the preferred interactive
        console while serial output remains available.
    -   The option should be **disabled by default** for normal installs
        and clearly labeled as a troubleshooting/debugging aid.
    -   Persist the selection in the installer configuration/resume
        state and include it in the final review so the user can see
        whether serial-console output will be enabled.
    -   Merge the serial-console arguments with the topology-derived
        `GRUB_CMDLINE_LINUX` storage arguments; do not replace or
        suppress required `rd.luks.uuid=`, `rd.md.uuid=`/MD activation,
        `rd.lvm.lv=`, root, or rootflags settings.
    -   Avoid duplicate console arguments when regenerating
        `/etc/default/grub` or rerunning `grub-mkconfig`;
        enabling/disabling the option repeatedly must be idempotent.
    -   For VM troubleshooting, document that a libvirt serial
        PTY/console device must exist; with one present,
        `virsh console <domain>` can then provide a copy/paste-capable
        Dracut emergency shell without requiring networking in the
        initramfs.
    -   **Regression test:** install once with the option disabled and
        verify normal graphical boot is unchanged; enable it and verify
        both the graphical console and `virsh console` receive
        kernel/Dracut output, including a deliberately triggered Dracut
        emergency shell; disable it again and verify the serial
        arguments are removed cleanly.

## r117 pkgmk source-mirror fallback support --- 2026-08-20

-   \[\~\] **CONFIG SUPPORT CONFIRMED / runtime failover test pending
    --- PKGMK: configurable alternate/fallback source URLs for package
    downloads.**
    -   Motivated by highly variable download performance for the \~600
        MiB `linux-firmware` source archive; a single upstream endpoint
        can become a major bootstrap/install bottleneck.
    -   Preserve the Pkgfile's canonical upstream `source=` URL as the
        authoritative final fallback.
    -   Use/support `PKGMK_SOURCE_MIRRORS` in `/etc/pkgmk.conf` for an
        ordered list of alternate source locations before falling back
        to the Pkgfile URL. CRUX documents that multiple mirror URLs may
        be supplied in this array.
    -   Audit BFSOS `pkgmk` behavior to ensure failed/slow mirror
        attempts fall through cleanly without corrupting or accepting
        partial source archives.
    -   Keep the existing source cache behavior: if the correct source
        archive is already present in `PKGMK_SOURCE_DIR` / BFSOS source
        cache, do not download it again.
    -   Consider sensible connection/transfer timeout and retry handling
        so an unreachable or extremely slow mirror does not stall a
        build indefinitely before fallback.
    -   Do **not** solve this by adding duplicate equivalent URLs to a
        Pkgfile `source=(...)` array; those entries represent multiple
        required build sources, not alternate copies of one source.
    -   Initial regression target: `linux-firmware`. Configure at least
        two trustworthy mirrors/endpoints, deliberately make the first
        unavailable, and verify pkgmk automatically obtains the same
        expected archive from the next source and continues the build.
    -   After proving the mechanism, decide whether BFSOS should ship a
        small default global mirror list or leave mirror selection
        entirely to `/etc/pkgmk.conf`.

## r116 Linear/JBOD cold-recovery topology persistence fix --- 2026-08-20

-   [x] **FIX IMPLEMENTED in installer r56 / layered Linear/JBOD
    topology subsequently reached a completed install; dedicated
    cold-relaunch/profile regression remains to be closed
    independently.**
    -   Live relaunch testing showed recovery skipped the six-member
        Linear/JBOD array and only reopened one LUKS mapping.
    -   **Root cause:** `capture_recovery_storage_topology()` recognized
        only `lsblk` ancestor types matching `raid*`. Linux reports an
        MD Linear/JBOD ancestor as type `md`, so `/dev/md0` could be
        omitted from `RECOVERY_MD` persistence.
    -   **Additional robustness issue:** recovery topology was inferred
        primarily by walking selected leaf devices. With a multi-PV VG,
        an individual LV does not necessarily allocate extents from
        every PV, so a valid MD -\> LUKS -\> PV branch could also be
        omitted even when that branch is part of the configured VG.
    -   Installer r56 recognizes both `md` and `raid*` ancestor types.
    -   Installer r56 additionally persists every installer-created MD
        array, every installer-opened LUKS mapping (including its actual
        backing device), and every installer-activated VG, deduplicating
        these against ancestry-derived recovery state.
    -   Recovery order remains strict: **MD -\> LUKS -\> LVM -\>
        filesystems/Btrfs**.
    -   For an older/incomplete resume profile that references a missing
        `/dev/mdX` LUKS backing device but contains no saved MD
        topology, r56 now stops with an explicit non-destructive
        diagnostic instead of silently skipping MD and proceeding with
        only the recoverable LUKS mapping.
    -   Static validation: `bash -n` passes for installer r56.
    -   **Runtime regression:** create Linear/JBOD from six members -\>
        create LUKS on `/dev/md0` plus a second LUKS container -\> use
        both as PVs in one VG -\> save/fail -\> fully deactivate or cold
        reboot -\> relaunch r56 -\> verify MD is assembled/adopted
        first, both LUKS passphrases are requested/opened, VG/LVs
        activate, and the exact filesystem/Btrfs plan mounts.
    -   **Profile verification:** after the next configured run, inspect
        `.bfs-installer-resume.conf` and require one `RECOVERY_MD=`
        entry for the Linear/JBOD array plus both expected
        `RECOVERY_LUKS=` entries before treating this regression as
        passed.

## r115 runtime-confirmed failure cleanup / layered-storage preservation --- 2026-08-20

-   [x] **FIX IMPLEMENTED in installer r55 / runtime regression pending:
    preserve the complete active storage stack after a caught
    installation failure.**
    -   Live JBOD -\> LUKS -\> LVM testing proved `/dev/md0` was
        successfully created and `/dev/mapper/cryptraid` existed long
        enough to become an LVM PV; the later failure was the
        `useradd sys` group-name collision, not JBOD/LUKS creation.
    -   Runtime inspection after leaving the installer showed
        `cryptroot` still active but `/dev/md0` stopped and `cryptraid`
        gone. The EXIT cleanup was unwinding installer-owned VGs, LUKS
        mappings, and MD arrays, producing a partially torn-down stack
        after a recoverable failure.
    -   Installer r55 now sets `KEEP_MOUNTS=yes` immediately when
        `run_chroot_installer` returns a caught nonzero status,
        preserving mounts, LVM, LUKS, and MD state for inspection and
        Install / Retry.
    -   Quit after a failed attempt now explicitly offers: **Leave
        storage active for recovery / inspection**, **Cleanly deactivate
        installer-owned storage**, or **Back to installer**.
    -   A fully successful retry clears failure-preservation mode
        (`KEEP_MOUNTS=no`) so normal successful final cleanup can
        proceed.
    -   Failure dialog wording now states that the complete active
        target storage stack is preserved and explains the Quit
        behavior.
    -   Static validation: `bash -n` passes for installer r55.
    -   Runtime regression: recreate Linear/JBOD -\> LUKS -\> LVM,
        trigger a controlled chroot failure, verify `/dev/md0`, all
        expected `/dev/mapper/*` LUKS mappings, VGs/LVs, and target
        mounts remain active; retry successfully; separately test both
        Quit choices.

## r114 implementation pass --- runtime UI/account/JBOD fixes --- 2026-08-20

-   **Bootstrap r59 created:** `[AVAILABLE]` is now bright yellow in
    both Dialog and text-mode bootstrap status rendering; green remains
    reserved for completed/success states and red for
    pending/unavailable states.
-   **Installer r54 created:** main-menu `[AVAILABLE]` /
    `[RETRY AVAILABLE]` statuses are bright yellow, completed/configured
    states are green, and pending/incomplete/unavailable states are red.
-   **Linear/JBOD LUKS-selector dedup fixed:** active MD devices are
    enumerated from every `/proc/mdstat` array line (including
    `linear`), `lsblk` paths are canonicalized, and every candidate path
    is recorded in a `seen` set before display. This addresses the live
    `/dev/md0` repeated once per JBOD member symptom and applies to all
    MD types.
-   **Users & Groups review reworked:** Primary and Additional accounts
    now use consistent `User`, `Type`, `Groups`, `Login`, and `Password`
    fields with compact `[STANDARD]` / `[SYSTEM]` markers and wrapped
    Standard-group display.
-   **Account-review mojibake fixed:** Unicode em-dash separators were
    removed from the account modify/remove/review paths in favor of
    ASCII separators for the forced POSIX installer locale.
-   **Theme persistence fixed for chroot dialogs:** the active generated
    `DIALOGRC` is copied into the target before chroot configuration and
    exported by the chroot installer, so optional-password/account
    dialogs use the theme selected in the live installer even though the
    chroot is launched through `env -i`. The temporary target copy is
    removed during installer cleanup.
-   **Username/group collision validation added:** primary and
    additional account names are checked against the extracted target
    group database and the BFSOS `aaa_filesystem/group` source before
    they are accepted. The chroot also performs a defensive preflight
    and exits with status 9 rather than letting `useradd -U` fail
    ambiguously if a same-named group exists.
-   **Failure-status propagation fixed:** the real
    `run_chroot_installer` status is retained in
    `SESSION_FAILURE_STATUS`; Quit after a caught failure exits with
    that status instead of forced `0`; the EXIT cleanup also refuses to
    write SUCCESS/0 when a tracked nonzero installation status is
    outstanding. A later fully successful retry still clears the session
    status to 0.
-   **Static validation:** `bash -n` passes for bootstrap r59 and
    installer r54.
-   **Runtime regression next:** retest Linear/JBOD -\> LUKS selector
    uniqueness; choose a non-default theme and verify all chroot
    password dialogs retain it; try reserved-group usernames such as
    `sys` and `audio` and confirm rejection before install; trigger one
    controlled chroot failure and verify the final log footer preserves
    the nonzero status; then retry successfully and verify SUCCESS/0.

## r107 ports synchronization architecture --- migrate BFSOS collections from HttpUp to Git --- 2026-08-19

-   [x] **IMPLEMENTED using the r108 single-main-branch monorepo design
    / network runtime regression pending --- PRE-1.0 PORTS
    INFRASTRUCTURE CHANGE:** Replace BFSOS's HttpUp-based collection
    synchronization with the CRUX ports **git driver** so normal
    `ports -u` synchronizes each BFSOS ports collection directly from
    its Git branch on Codeberg instead of fetching/generated HttpUp
    repository metadata one file at a time. This is intended to
    eliminate the recurring HttpUp/REPO/.httpup metadata failure mode
    that can cascade into hundreds of collection-sync errors.
-   **Current state confirmed from the supplied `/etc/ports/*.httpup`
    files:** `compat-32`, `compiz`, `contrib`, `core`, `gnome`, `lxqt`,
    `opt`, `plasma`, `xfce`, and `xorg` all currently use
    `ROOT_DIR=/usr/ports/<collection>` plus a Codeberg raw-tree URL
    under `BFS-Linux/raw/branch/main/ports/<collection>`. The migration
    must replace these active `.httpup` definitions with `.git`
    collection definitions rather than keeping both active.
-   **Use the existing Codeberg Git repository:** remote repository is
    `https://codeberg.org/bmadonnaster/BFS-Linux.git` (or the final
    canonical BFSOS repository URL if/when the remote is
    renamed/migrated). Do not depend on Codeberg raw-file URLs for
    collection synchronization once this work is complete.
-   **Branch mapping must be verified, not guessed:** enumerate the
    actual remote branches first (for example with
    `git ls-remote --heads <repo-url>`) and record the exact branch
    corresponding to each collection. Expected collection set to
    migrate: `compat-32`, `compiz`, `contrib`, `core`, `gnome`, `lxqt`,
    `opt`, `plasma`, `xfce`, and `xorg`. If a collection is not actually
    stored as a same-named branch, document its real branch/path and
    adapt the migration accordingly rather than silently assuming names.
-   **CRUX git-driver model:** use `/etc/ports/<collection>.git` files
    so the normal CRUX `ports -u` wrapper automatically selects
    `/etc/ports/drivers/git` by file extension. Each definition should
    use the supported git-driver fields `URL=`, `NAME=`, `BRANCH=`, and,
    where useful for explicit BFSOS layout,
    `LOCAL_REPOSITORY=/usr/ports/<collection>`.
-   **Target layout goal:** after migration, `ports -u` should leave the
    normal collection paths intact (`/usr/ports/core`, `/usr/ports/opt`,
    etc.) so `prt-get`, existing `prtdir` entries, installer code, build
    scripts, and package tooling do not need to learn a new ports-tree
    layout merely because the transport changed from HttpUp to Git.
-   **Collection config migration:** create/update the source
    templates/files that BFSOS installs into `/etc/ports/` so each
    active collection has a `.git` definition. Remove/retire the
    corresponding `.httpup` file or rename it inactive so one collection
    is not synchronized by two drivers. Audit any installer/bootstrap
    scripts that generate or copy `/etc/ports/*.httpup` and convert them
    to the git-driver format.
-   **`ports -u` must remain the normal user command:** do not replace
    the CRUX ports wrapper with a BFSOS-only manual
    `git clone`/`git pull` workflow. The desired user experience is
    still `ports -u`; the existing ports wrapper should dispatch to the
    git driver and perform clone/update operations behind that command.
    `prt-get sync` may also be regression-tested because current CRUX
    supports the same driver mechanism, but `ports -u` remains required.
-   **Git becomes a base-system dependency:** add the `git` port/package
    to the BFSOS base package set so a freshly installed system can run
    `ports -u` immediately with git-backed collections. Ensure Git is
    present early enough for any base/bootstrap stage that performs
    ports synchronization. Audit bootstrap ordering/dependencies so the
    switch does not create a bootstrap cycle.
-   **Remove Git from installer optional-package handling:** once Git is
    guaranteed by the base, remove it from installer optional package
    menus/default optional installation lists and any redundant
    `prt-get depinst git`/equivalent installer action. The final review
    should not present Git as an optional add-on when it is required
    infrastructure.
-   **Bootstrap/base archive integration:** ensure newly created base
    rootfs archives already contain Git, `/etc/ports/drivers/git`, and
    the BFSOS `.git` collection definitions. A restored base archive
    must be able to run `ports -u` without first installing Git or
    regenerating HttpUp repository files.
-   **Remove obsolete HttpUp maintenance requirements where no longer
    needed:** audit `bfs-sync-ports.sh`, `bfs-update-ports.sh`,
    repo-generation helpers, installer recovery/update code, bootstrap
    scripts, and documentation for `.httpup-repo.current`,
    `.httpup-urlinfo`, `REPO`, `httpup-repgen`, or raw-Codeberg
    collection assumptions. Retain `httpup` itself only if BFSOS still
    supports third-party/user collections that legitimately use the
    HttpUp driver; do not keep BFSOS's own collections dependent on it.
-   **Do not break third-party CRUX-style collections:** this migration
    is for BFSOS-maintained collections. The generic CRUX ports
    framework should continue to support `.httpup`, `.rsync`, and `.git`
    driver files so users can subscribe to external collections using
    whichever supported driver they require.
-   **First-sync behavior:** on a clean system with an empty
    `/usr/ports/<collection>`, `ports -u` must clone/check out the
    configured branch. On subsequent runs it must update the existing
    local Git-backed collection cleanly and remove/update files in
    accordance with the remote branch. Test a deleted port/file as well
    as added/modified files.
-   **Local-modification policy:** explicitly define what happens when a
    user has uncommitted edits under `/usr/ports/<collection>`. Prefer a
    safe, understandable failure/warning over silently destroying local
    work. Verify the upstream CRUX git driver's behavior and document it
    in BFSOS ports documentation.
-   **Authentication policy:** installed systems should use a
    **read-only HTTPS clone URL** for normal `ports -u`; users must not
    need the maintainer's SSH key or Codeberg credentials merely to
    synchronize public BFSOS ports. Maintainer push workflows remain
    separate and may continue using SSH from the development checkout.
-   **Branch/repository maintenance:** document the maintainer workflow
    for updating each collection branch (checkout/switch branch -\>
    modify ports -\> commit -\> push). If BFSOS later consolidates or
    renames the `BFS-Linux` repository to `BFSOS`, provide a single
    place/template from which all `.git` URL definitions are generated
    so ten collection files do not drift.
-   **Installer/update error handling:** adapt any `ports -u`
    logging/failure parser that assumes HttpUp wording/files. Git
    clone/fetch/checkout failures must surface the collection name,
    remote URL/branch, exit status, and log path without producing
    misleading HttpUp repair instructions. Preserve the installer
    retry/checkpoint behavior already validated around package/download
    failures.
-   **Cleanup migration on existing systems:** provide a safe upgrade
    path that removes/archives old `/etc/ports/*.httpup` BFSOS
    definitions and initializes the matching git-backed collections. Do
    not delete unrelated third-party `.httpup` configurations. Where an
    existing `/usr/ports/<collection>` is not a Git working tree, the
    migration must replace/synchronize it deliberately rather than
    failing because the directory is non-empty.
-   **`prt-get.conf` audit:** verify every migrated collection still has
    the intended `prtdir /usr/ports/<collection>` entry and that
    collection enable/disable policy is unchanged by switching
    transport.
-   **Regression matrix:** (1) clean machine, empty `/usr/ports`, run
    `ports -u`; (2) second `ports -u` with no remote changes; (3)
    upstream add/modify/delete a test port and sync; (4) temporarily
    break one branch/URL and confirm only that collection fails
    clearly; (5) restore it and confirm retry succeeds; (6) verify all
    ten BFSOS collections; (7) verify `prt-get list`/search/depinst sees
    the synchronized trees; (8) verify an external HttpUp collection can
    coexist; (9) verify fresh base archive contains Git and git-driver
    configs; (10) verify installer no longer offers Git as
    optional; (11) verify no BFSOS update path regenerates HttpUp REPO
    metadata.
-   **Release criterion:** do not consider the migration complete until
    a fresh Bootstrap/base build and a fresh installed BFSOS system both
    perform successful Git-backed `ports -u` synchronization for every
    enabled BFSOS collection, followed by normal `prt-get` package
    operations.

## r106 implementation pass / System Settings + account policy + LVM capacity + timing + audit kickoff --- 2026-08-19

-   **Installer r53 created:**
    `scripts/install-bfs-menu-v50-r53-system-settings-users-lvm-timing.sh`.
-   [x] **SYSTEM SETTINGS SUBMENU IMPLEMENTED / runtime regression
    pending:** The long main menu now has one `System Settings` entry.
    Hostname/timezone/locale, console/font, networking, root-account
    policy, Users and Groups, and SSH configuration live underneath it.
    Required child items and the aggregate main-menu entry use explicit
    `[COMPLETE]` / `[INCOMPLETE]` state derived from current
    configuration rather than menu visitation.
-   [x] **STANDARD VS SYSTEM/SERVICE ACCOUNT POLICY IMPLEMENTED /
    runtime regression pending:** Standard users use one centralized
    BFSOS supplementary-group policy
    (`users,wheel,audio,video,optical,cdrom,plugdev,storage,input,render`).
    System/service accounts use a private primary group with no
    supplementary groups unless explicitly selected; they default to
    `/usr/bin/false` and locked password login. An explicitly selected
    interactive service account uses `/bin/bash`.
-   [x] **OPTIONAL PASSWORDS IMPLEMENTED / runtime regression pending:**
    Root, the primary Standard user, additional Standard users, and
    interactive System/service accounts may leave the password blank.
    Blank means the account is explicitly password-locked; it never
    creates an empty-password login. Passwords remain runtime-only and
    are not stored in installer profiles/logs.
-   [x] **USERS/GROUPS MANAGEMENT FLOW IMPLEMENTED / runtime regression
    pending:** Users and Groups now supports primary Standard-user
    configuration, adding Standard/System-service accounts, modifying
    additional-account policy/groups, removing additional accounts, and
    reviewing the resulting account policy. System/service
    supplementary-group input is validated before it is persisted.
-   **Resume profile format:** installer profile header is bumped to v3
    for typed account entries while remaining backward-compatible with
    older `ADDITIONAL_USER=` entries, which load as Standard users.
-   [x] **LVM LIVE CAPACITY UX IMPLEMENTED / runtime regression
    pending:** PV/VG/LV selectors and review screens now show
    human-readable live capacity. PV usable size, VG total/used/free,
    existing LV sizes, current free space, resolved `%FREE`/`%VG`
    allocation, projected free space, and refreshed post-create capacity
    are shown using authoritative LVM state.
-   **IEC size formatting:** human-facing LVM sizes automatically select
    bytes/KiB/MiB/GiB/TiB/PiB/EiB as appropriate instead of exposing raw
    byte/extents values where a human-readable size is useful.
-   [x] **RAW ELAPSED-SECONDS UI FIX IMPLEMENTED / runtime regression
    pending:** the installed `bfs-pkgmk` wrapper now formats
    human-facing elapsed times through one days/hours/minutes/seconds
    helper. `2841s` renders as `47m 21s`; raw `elapsed_seconds` remains
    unchanged for machine-readable logs. `pkgutils` release is bumped
    from 12 to 13.
-   **Static/formatter validation:** `bash -n` passes for installer r53;
    `sh -n` passes for `bfs-pkgmk`; formatter spot tests pass for bytes
    through TiB and elapsed values including `42s`, `4m 12s`, `47m 21s`,
    hours, and days.
-   **Recent runtime confirmations folded forward:** the fresh RAID4 -\>
    LUKS -\> two-PV LVM -\> five-LV Btrfs install completed, survived a
    same-process package/download retry after `linux-firmware` failed,
    and cold-booted successfully. Post-install duplicate checks found no
    duplicate active `fstab`, `crypttab`, `mdadm.conf`, or GRUB
    settings. RAID4 booted 6/6 healthy and the complete layered storage
    stack reconstructed successfully.
-   **`aaa_filesystem` duplicate-group source defect fixed in the
    supplied tree:** duplicate `root`/`bin` records were traced to
    `ports/core/aaa_filesystem/group`, not installer retry/idempotency.
    The supplied project already contains the corrected unique group
    list; retain duplicate-name/GID checks in the core audit.
-   \[\~\] **PRE-1.0 CORE AUDIT STARTED:** use **current MLFS
    development as the primary multilib/toolchain/build-method
    reference**, authoritative upstream as the source of truth for
    current releases/security/build requirements, current CRUX core as a
    distro/package-layout comparison, and ordinary LFS/BLFS development
    only as secondary cross-checks where useful. Do not downgrade a
    deliberate BFSOS point-release update merely to match a stale book
    snapshot.
-   **Kernel/header policy for the audit:** MLFS development explicitly
    permits a newer stable kernel point release unless errata says
    otherwise. BFSOS may track upstream stable point releases; if Linux
    API headers are intentionally advanced beyond the MLFS-tested set,
    require a clean Bootstrap/toolchain/base regression before treating
    the change as validated.
-   **Current live MLFS sanity snapshot used to start the audit:** BFSOS
    already matches the current MLFS development versions for major
    toolchain/base items including GCC 16.2.0, Binutils 2.47, Glibc
    2.44, Coreutils 9.11, Python 3.14.7, Systemd 261.2, Shadow 4.20.2,
    Linux 7.1.8, Util-linux 2.42.2, Wheel 0.48.0, Xz 5.8.3, and Zlib
    1.3.2. Continue the package-by-package source/patch/build/footprint
    audit rather than treating version equality as completion.
-   **Audit report:** `docs/BFSOS-core-audit-r106-20260819.md` records
    the r106 first-pass static checks, 78 directly mapped
    MLFS-development version matches, required-patch coverage, CRUX
    package-management sanity comparisons, and the remaining
    package-by-package work.
-   **Next runtime regression:** exercise r53 account creation
    (Standard, locked-password Standard, noninteractive service,
    interactive service, explicit service groups), System Settings
    status persistence/profile reload, LVM capacity updates across
    multiple PV/LV creations, and a package build long enough to prove
    the `bfs-pkgmk` human-duration path in real installer output.

## r102 System Settings submenu / completion-state UX --- 2026-08-19

-   [x] **IMPLEMENTED in installer r53; runtime regression pending ---
    GROUP SYSTEM CONFIGURATION UNDER ONE MAIN-MENU ENTRY:** Keep the
    already-long installer main menu from growing further by adding a
    **System Settings** submenu rather than adding separate top-level
    entries for users/groups and each additional system setting. The
    main menu should expose one concise `System Settings` entry with an
    aggregate status such as `[INCOMPLETE]` or `[COMPLETE]`.
-   **System Settings contents:** Move/group the system-level
    configuration that must be reviewed or configured before
    installation into this submenu. At minimum account for hostname,
    timezone, locale, console/keyboard settings where applicable,
    network configuration, root-account configuration, Users and Groups,
    and SSH configuration. Preserve existing installer capabilities
    while reorganizing the UX; do not duplicate configuration state in
    two unrelated menu paths.
-   [x] **IMPLEMENTED in installer r53; runtime regression pending ---
    PER-ITEM COMPLETION STATUS:** Every System Settings submenu item
    should visibly report its own state (`[COMPLETE]`, `[INCOMPLETE]`,
    or another existing installer status where appropriate). Returning
    to the submenu after configuring an item must immediately reflect
    the new state.
-   [x] **IMPLEMENTED in installer r53; runtime regression pending ---
    AGGREGATE SYSTEM SETTINGS STATUS:** The main-menu `System Settings`
    entry becomes `[COMPLETE]` only when every **required**
    system-setting requirement is satisfied. Optional configuration must
    not block completion merely because the user did not choose it. The
    completion calculation should derive from actual saved
    configuration/state rather than simply recording that a menu was
    visited.
-   **Users and Groups integration:** Put the r100/r101 account work
    under `System Settings -> Users and Groups`. That screen should
    provide creation/management of **Standard users** and
    **System/service accounts**, modification/removal where safe,
    supplementary-group management, and a concise review of configured
    accounts. Do not expand the main menu with separate
    account-management entries.
-   **Account-policy preservation:** Standard users continue to receive
    the centralized normal BFSOS supplementary-group policy.
    System/service accounts receive their own primary group and no
    supplementary groups by default, while allowing explicitly selected
    supplementary groups. Passwords remain optional; an unset password
    means no usable password credential, never blank-password login.
-   **Completion semantics for accounts:** Do not require creation of a
    System/service account to mark Users and Groups complete. Account
    completion should reflect the installer's actual required account
    policy. An intentionally password-locked account is valid and must
    not remain `[INCOMPLETE]` merely because no password was set.
-   **Dialog-flow goal:** Entering System Settings should present a
    compact checklist-like configuration hub so the user can see at a
    glance what remains. Individual dialogs should explain choices
    before requesting values and avoid repetitive confirmation screens.
    Returning from a child menu must preserve all previously configured
    settings and statuses.
-   **Final review integration:** The installer's final review should
    summarize System Settings from the same underlying state used by the
    submenu, including account types/login state and any unresolved
    required item. Do not allow the final install action to report
    system configuration complete if a required System Settings item is
    still incomplete.
-   **Regression tests:** (1) launch a fresh installer and verify
    required System Settings items begin incomplete as appropriate; (2)
    configure items in arbitrary order and verify their statuses
    persist; (3) verify optional untouched items do not block aggregate
    completion; (4) create Standard and System/service accounts and
    verify r100/r101 policies; (5) verify an intentionally unset
    password does not block completion; (6) leave one required setting
    unfinished and verify the main menu remains `[INCOMPLETE]`; (7)
    complete the final required item and verify
    `System Settings [COMPLETE]`; (8) leave/re-enter the submenu and
    restart/resume the installer and confirm status is reconstructed
    from saved state.

## r101 terminology refinement --- standard user vs system/service account --- 2026-08-19

-   [x] **IMPLEMENTED in installer r53; runtime regression pending ---
    ACCOUNT-TYPE TERMINOLOGY:** Use **Standard user** and
    **System/service account** throughout the installer instead of the
    vague `non-standard` / `restricted user` wording. A Standard user is
    the normal interactive BFSOS login account. A System/service account
    is intended for daemons, services, automation, or deliberately
    restricted-purpose identities.
-   **System/service group policy:** Give a System/service account its
    own primary group by default and **no supplementary groups unless
    explicitly selected**. Do not imply that service accounts can never
    require supplementary groups; some services legitimately need
    explicit membership in one or more functional groups.
-   **System/service login policy:** Default System/service accounts to
    no interactive login/password credential unless the user explicitly
    chooses otherwise. The dialog/review must clearly show the resulting
    login state rather than silently assuming it.
-   **Dialog wording:** Make **Standard user** the normal/default
    account type. Explain both account types before account details are
    requested, and expose any explicit supplementary-group selection for
    System/service accounts as an advanced/custom action.
-   **Regression update:** Test a System/service account with no
    supplementary groups and another with one or more explicitly
    selected supplementary groups; verify only the requested memberships
    are applied.

## r100 user-creation UX / account policy findings --- 2026-08-19

-   [x] **IMPLEMENTED in installer r53; runtime regression pending ---
    STANDARD USER GROUP POLICY:** When creating a **standard user**,
    automatically add that account to the full normal BFSOS
    supplementary-group set already defined/discussed for an interactive
    desktop/admin-capable user. Keep the exact group list centralized in
    one installer policy/helper so the creation dialog, review screen,
    and account-creation command cannot drift apart.
-   [x] **IMPLEMENTED in installer r53; runtime regression pending ---
    SYSTEM/SERVICE ACCOUNT POLICY:** When the user explicitly chooses a
    **System/service account**, create the account with its own primary
    private group and no supplementary groups by default. Do not
    silently add the normal standard-user supplementary groups. Allow
    explicitly selected supplementary groups as an advanced/custom
    action for services that legitimately require them.
-   [x] **IMPLEMENTED in installer r53; runtime regression pending ---
    PASSWORDS MUST BE OPTIONAL:** Do not require a password merely to
    create either a Standard user or System/service account. The user
    must be allowed to leave the password unset.
-   **No-password behavior:** An account created without a password must
    **not** become passwordless-login capable. Leave/mark the password
    authentication state locked/unset so the account cannot authenticate
    with a blank password. The account may later be enabled by
    explicitly setting a password or by configuring another
    authentication method such as SSH keys.
-   **Root/account consistency:** Apply the same safety principle
    anywhere the installer permits an unset password: blank input means
    **no usable password credential**, never an empty password that
    permits login.
-   [x] **IMPLEMENTED in installer r53; runtime regression pending ---
    REDESIGN USER-CREATION DIALOG FLOW:** Rework the user-creation
    Dialog so the account type and consequences are explained before
    asking repetitive questions. The screen should clearly distinguish
    **Standard user** from **System/service account**, summarize the
    automatic group policy for each, and state that passwords are
    optional and that leaving one unset prevents password login.
-   **Suggested flow:** choose account type -\> enter username/full-name
    fields -\> optional password entry -\> concise review/confirmation.
    Do not make the user manually approve every normal standard
    supplementary group when the standard-user policy already defines
    them.
-   **Review visibility:** The final account review should show account
    type, username, whether password login is configured or
    locked/unset, and either the resolved supplementary groups or a
    concise `Standard BFSOS groups` summary with an optional detail
    view.
-   **Validation/safety:** Continue rejecting invalid/duplicate
    usernames and never log, save in profiles, or display entered
    passwords. Do not conflate an intentionally unset password with a
    password-entry error.
-   **Regression tests:** (1) create a standard user and verify the
    complete BFSOS standard supplementary-group set is applied; (2)
    create a System/service account and verify it has no supplementary
    groups unless groups were explicitly selected; (3) create each type
    with no password and verify blank-password login is impossible; (4)
    set a password and verify normal authentication works; (5) confirm
    Back/Cancel and repeated account creation do not lose prior
    installer state or create partial accounts.

## r99 runtime finding --- successful-install resume-state cleanup --- 2026-08-19

-   [x] **IMPLEMENTATION PRESENT in r52-r57 / clean-cycle runtime
    regression pending --- SUCCESSFUL INSTALL MUST CLEAR RESUME FILE:**
    A clean new installer launch from the same BFSOS checkout detected
    `scripts/.bfs-installer-resume.conf` left by the previous
    installation and automatically entered **Previous installation
    detected** recovery. For a genuinely completed successful
    installation, the resume file should not remain behind.
-   **Required behavior:** Preserve `.bfs-installer-resume.conf` across
    failure, interruption, cancellation, or an incomplete install so
    cold-relaunch recovery remains available. Once all required
    completion checkpoints/sanity checks and boot artifacts confirm
    installation success, remove the resume file automatically.
-   **Existing intent:** r52 already contains
    `rm -f "$INSTALLER_RESUME_FILE"` in its completed-install lifecycle;
    verify that the normal fresh-install success path reaches equivalent
    cleanup and that nothing rewrites the resume file afterward.
-   **Development/reused-checkout behavior:** Reusing the same BFSOS
    project directory should not cause the next clean installation test
    to recover a previously completed installation merely because stale
    resume metadata remains in `scripts/`.
-   **Regression test:** Complete a fresh installation successfully,
    exit/reboot normally, verify `scripts/.bfs-installer-resume.conf` is
    absent, then relaunch the installer from the same BFSOS checkout and
    confirm it starts as a fresh install. Separately interrupt an
    installation and verify the resume file remains and recovery still
    activates.

## r97 implementation / recovery UX + completed-install lifecycle --- 2026-08-18

-   **Installer r52 created:**
    `scripts/install-bfs-menu-v50-r52-recovery-ux-complete-state.sh`.
-   **r51 cold-recovery runtime PASSED:** from a cold Gentoo live boot,
    the existing six-disk RAID6 had auto-assembled under a different MD
    node; r51 successfully adopted the active array, requested the
    required LUKS passphrase(s), activated the saved LVM VGs/LVs, and
    restored the saved Btrfs/filesystem layout without manual storage
    reconstruction.
-   **Recovery prompt order fixed:** the installer now displays
    **Previous installation detected** and explains the non-destructive
    MD -\> LUKS -\> LVM -\> filesystem recovery process **before** any
    LUKS password prompt. The dialog explicitly warns that encrypted
    storage may request passphrases and that passphrases are never
    stored.
-   **Completed-install detection implemented:** after storage recovery,
    r52 reloads persistent target checkpoints and distinguishes a
    genuinely incomplete installation from stale resume metadata. A
    target is considered complete only when `base_extracted`,
    `accounts_configured`, `packages_complete`,
    `system_config_complete`, and `bootloader_complete` are all present,
    the BFSOS base sanity checks pass, and selected GRUB boot artifacts
    exist.
-   **Observed completed target:** the recovered/boot-tested
    installation contained all five completion checkpoints, no
    `last_failure`, `/boot/grub/grub.cfg`, the BFS EFI loader, kernel
    `7.1.8-BFS-Linux`, and its initramfs. Therefore offering Install /
    Retry was incorrect for that target.
-   **Stale resume lifecycle fixed:** when a recovered target is already
    complete, r52 clears the stale resume file, reports **Installation
    already complete**, and does not ask the user to rerun installation.
-   **Main-menu completed state:** option 11 becomes **Installation
    Complete \[COMPLETE\]** for the recovered completed target.
    Selecting it only explains that no retry is required; it cannot
    accidentally restart the install transaction. Chroot remains
    available for inspection.
-   **Incomplete recovery behavior retained:** if any required
    completion checkpoint/sanity check is missing, the installer reports
    **Recovery complete** and presents the normal **Install / Retry
    \[RETRY AVAILABLE\]** path.
-   **Static validation:** `bash -n` passes for r52.
-   **Next clean-cycle test:** rebuild the BFSOS base from a fresh
    Bootstrap, perform a full new install, boot the installed system,
    then cold-boot the live environment and verify recovery both (a)
    during an intentionally incomplete installation and (b) against the
    fully completed installation where stale retry state must not be
    offered.
-   **Remaining MD layout coverage:** the installer explicitly supports
    Linear/JBOD, RAID0, RAID1, RAID4, RAID5, RAID6, and RAID10. The
    tracker still records RAID6 as the recently runtime-confirmed
    creation path; do not mark the other RAID levels complete solely
    from static support. Linear/JBOD is a useful next storage-layout
    test, but it is not the only historically pending RAID-level
    regression unless the other levels have been runtime-tested outside
    this tracker.

## r96 implementation / cold-recovery + final-validator pass --- 2026-08-18

-   **Installer r51 created:**
    `scripts/install-bfs-menu-v50-r51-md-identity-fstab-status-fixes.sh`.
-   **Cold MD recovery root cause confirmed:** Gentoo auto-assembled the
    saved six-member RAID6 as `/dev/md127` in `auto-read-only` state.
    r50 then tried to assemble the same members into the saved pathname
    `/dev/md0`; `mdadm` reported every member busy. Recovery was
    running, but it incorrectly treated the MD device node as persistent
    identity.
-   **Stable MD identity fix:** r51 adopts an already-active MD array by
    persisted MD UUID when available, with an exact normalized
    member-set fallback for older r49/r50 resume profiles that did not
    save an MD UUID. If the array is found under a different node (`md0`
    -\> `md127`), r51 rewrites the in-memory dependent LUKS
    backing-device path and continues recovery instead of trying to
    assemble the members twice.
-   **Future resume profiles now persist MD UUIDs** in addition to saved
    array path/member topology; no secret material is added.
-   **Race-safe MD recovery:** if an explicit assemble loses a race with
    live-environment auto-assembly and returns busy, r51 performs one
    stable-identity re-scan before declaring recovery failure.
-   **Failure/status propagation fixed:** unresolved recovery or
    chroot/install failure sets a session failure status. Exiting after
    such a failure can no longer produce a misleading
    `Result: SUCCESS / Exit status: 0`; a later fully successful retry
    clears the failure state.
-   **fstab false failure fixed:** both generated-fstab validation paths
    now accept `tmpfs` and other standard pseudo-filesystem source
    tokens. The booted-system audit proved line 37
    (`tmpfs /var/cache/pkg/build-work tmpfs ...`) was valid and the
    installed system booted successfully.
-   **Failure-dialog URL noise reduced:** the installer no longer
    scrapes an arbitrary historical URL for generic
    configuration/final-validation failures. URL display is limited to
    operations whose name indicates
    download/source/ports/package/upgrade work.
-   **Install/Retry UI implemented:** when persistent resume state
    exists, option 11 is labeled **`Install / Retry BFS (root)`** with
    **`RETRY AVAILABLE`**; fresh installs retain the normal Install
    label.
-   **Human-readable installer package timing implemented:** status
    output now renders `42s`, `8m 17s`, `48m 13s`, `1h 06m 42s` style
    durations while the machine-readable build-times log keeps raw
    `elapsed_seconds`.
-   **Static validation:** `bash -n` passes for r51.
-   **Runtime regression next:** cold Gentoo boot with the array
    auto-assembled as `/dev/md127` -\> launch r51 -\> verify it adopts
    md127 -\> prompts for both required LUKS passphrases -\> activates
    saved VGs -\> mounts exact Btrfs subvolumes/boot filesystems -\>
    presents Install / Retry without manual storage reconstruction.

### Corrected r95 diagnosis

-   The r95 statement that r50 merely detected the prior installation
    without attempting reconstruction was incomplete. The clean
    cold-boot log proves r50 did enter
    `Resume: reconstructing saved storage stack`; it failed specifically
    at the MD layer because the active array pathname changed from saved
    `/dev/md0` to auto-assembled `/dev/md127`.
-   Observed log sequence: `Resume: reconstructing saved storage stack`
    -\> `Resume: assembling saved MD array /dev/md0` -\> all six saved
    member partitions reported `busy - skipping`.
-   The non-destructive stop behavior passed: r50 did not wipe/recreate
    anything when recovery failed.

## r95 cold-relaunch recovery regression --- 2026-08-18

-   [x] **ROOT CAUSE IDENTIFIED / FIX IMPLEMENTED in r51 --- COLD
    RELAUNCH STORAGE RECOVERY:** The initial r50 observation appeared to
    show detection without reconstruction; later cold-boot logging
    proved recovery did start but failed at the MD layer because the
    saved `/dev/md0` array had auto-assembled as `/dev/md127`. r51 now
    matches/adopts MD arrays by stable identity instead of pathname.
-   Detection alone is not recovery. After accepting the
    previous-installation prompt, recovery must read the saved recovery
    profile and reconstruct the target sufficiently for checkpoint
    validation and `Install / Retry`.
-   Required recovery order for the current layered-storage case:
    assemble required MD arrays (for example `md0`) → open required LUKS
    mappings (prompt for passphrases only when mappings are closed) →
    activate required LVM VGs/LVs → mount the saved root filesystem and
    correct Btrfs subvolume (`@`) → mount separate saved
    filesystems/subvolumes (`@usr`, `@opt`, `@home`, `@var`) → mount
    `/boot` and `/boot/efi` → validate persistent installer
    checkpoints/state.
-   Do **not** ask the user to re-enter disk selections, RAID
    membership, VG/LV names, mountpoints, filesystem choices, or Btrfs
    subvolume names when those values exist in the saved recovery
    profile.
-   After successful reconstruction, return to the main menu with the
    retry state clearly visible as **`Install / Retry`** /
    **`RETRY AVAILABLE`**.
-   Recovery failures must identify the layer that could not be restored
    and must not silently fall through to a normal fresh-install path.
-   **Regression test:** complete enough of an installation to persist
    recovery state, fully unmount `/mnt/bfs`, close/deactivate storage
    layers (or reboot the live environment), relaunch the installer,
    accept previous-installation recovery, and verify automatic MD →
    LUKS → LVM → Btrfs/filesystem remount reconstruction before retry.
-   **Observed r50 failure:** previous installation was detected
    successfully, user selected OK, no storage was mounted/opened, and
    the installer simply displayed the main menu.

## r94 UI finding --- human-readable elapsed times --- 2026-08-18

-   [x] **IMPLEMENTED in current installer/pkgutils / runtime regression
    pending --- HUMAN-READABLE COMMAND/PACKAGE ELAPSED TIMES:** Long
    operations currently report raw seconds (observed:
    `2893s (status 0)`). Format elapsed time as hours/minutes/seconds
    when appropriate, e.g. `42s`, `8m 17s`, `48m 13s`, `1h 06m 42s`,
    while preserving `(status N)`.
-   Apply consistently to installer/build/download/package timing.
-   **Regression test:** verify \<1 minute, \>1 minute, and \>1 hour
    formatting without changing exit-status handling.

## r93 cleanup / recovery-state policy --- 2026-08-18

-   [x] **IMPLEMENTED in r55-r57 / runtime regression pending ---
    FAILURE / RETRY CLEANUP POLICY:** When installation fails or returns
    to the menu for retry, preserve the active target storage stack
    rather than automatically dismantling it. Keep the target
    filesystems mounted, LVM active, required LUKS mappings open, and
    required MD arrays assembled so the user can inspect the failed
    installation and immediately retry.
-   [x] **IMPLEMENTED in r55-r57 / runtime regression pending ---
    SUCCESS CLEANUP POLICY:** After a fully successful installation,
    cleanly unmount the target filesystem tree and release storage
    layers opened/activated by the installer in safe reverse dependency
    order. Track ownership so the installer does not blindly
    close/deactivate unrelated storage that was already active before it
    started.
-   [x] **IMPLEMENTED in r55-r57 / runtime regression pending --- QUIT
    WITH ACTIVE TARGET:** If the user chooses Quit while an
    installer/recovery target is still mounted or otherwise active,
    explicitly ask whether to **leave target storage mounted/open for
    recovery** or **cleanly close the installer target**. Make the
    consequences clear before changing storage state.
-   [x] **IMPLEMENTED in r55-r57 / runtime regression pending ---
    OWNERSHIP-AWARE TEARDOWN:** Maintain per-run ownership/state for
    mounts, LVM VGs, LUKS mappings, and MD arrays. Cleanup should
    normally tear down only layers that the installer itself
    mounted/opened/activated/assembled during that run, unless the user
    explicitly requests full target teardown.
-   [x] **IMPLEMENTED in r55-r57 / runtime regression pending --- SAFE
    TEARDOWN ORDER:** For explicit cleanup, unmount target
    filesystems/subvolumes first, then deactivate installer-owned LVM,
    close installer-owned LUKS mappings, and finally stop
    installer-owned MD arrays when appropriate. Never stop an array
    while dependent mappings/filesystems remain active.
-   [ ] **RECOVERY REGRESSION TESTS:** Test (1) package/install failure
    leaves target inspectable and retryable, (2) successful installation
    performs clean teardown, (3) Quit with active target offers
    preserve-vs-cleanup choice, and (4) pre-existing storage layers are
    not accidentally dismantled.

## r92 UI finding --- Install / Retry menu labeling --- 2026-08-18

-   [x] **IMPLEMENTED in r51-r57 / runtime regression pending ---
    MAIN-MENU RETRY LABEL CLARITY:** When resumable/failed installer
    state exists, change the normal `Install BFS (root)` menu entry to
    **`Install / Retry BFS (root)`** so it is immediately clear that the
    same action resumes/retries the interrupted installation rather than
    blindly starting over.
-   When no resumable state exists, retain the normal
    **`Install BFS (root)`** label.
-   When retry state exists, change the menu status from `[AVAILABLE]`
    to **`[RETRY AVAILABLE]`** (or equivalently explicit wording) so
    recovery state is visible without entering the install action.
-   The retry label/status must be driven by actual detected resumable
    state/checkpoints, not merely by files existing under the target
    mount.
-   **Regression test:** verify fresh install shows the normal Install
    label/status; interrupt an installation after a persistent
    checkpoint is written, relaunch, and verify the main menu visibly
    changes to the retry form before selecting Install.

## r91 implementation / r49 runtime checkpoint regression --- 2026-08-18

-   **Installer r50 created:**
    `scripts/install-bfs-menu-v50-r50-checkpoint-errexit-fix.sh`.
-   **Runtime diagnosis corrected:** r49 did **not** fail because it
    skipped reopening LUKS in the latest test. The log showed
    `Target filesystem plan is already mounted correctly; reusing it for installer retry`,
    which means the manually reopened `cryptroot`/`cryptraid`, VGs, and
    Btrfs subvolume mounts were already active and correctly recognized.
-   **Actual r49 crash:** the installer ERR trap fired on a false
    `[[ -f "$TARGET/var/lib/bfs-installer/$state" ]]` test while
    scanning optional checkpoint marker files. A missing checkpoint is
    normal state, not an error.
-   **Fix:** all affected checkpoint-marker scans now use explicit
    `if [[ -f ... ]]; then checkpoint_mark ...; fi` control flow.
    Missing `packages_complete`, `system_config_complete`, or
    `bootloader_complete` markers therefore remain ordinary
    incomplete-state results and cannot trigger the ERR trap.
-   **Static validation:** `bash -n` passes for r50.
-   **Runtime regression required:** with only `base_extracted`,
    `accounts_configured`, and `last_failure` present, relaunch/retry
    must reuse the mounted target and proceed to the next incomplete
    install/package stage without exiting on a missing checkpoint file.

## r90 implementation / full relaunch-recovery pass --- 2026-08-18

-   **Installer r49 created:**
    `scripts/install-bfs-menu-v50-r49-full-relaunch-recovery.sh`.
-   **Fresh-process storage recovery implemented:** resume profiles now
    persist the non-secret MD member topology, LUKS
    backing-device/mapping names, and LVM VG names. On relaunch,
    recovery runs in dependency order: saved MD arrays -\> saved LUKS
    mappings -\> saved VGs -\> filesystem/Btrfs subvolume mounts -\>
    leaf-device/checkpoint validation. LUKS passphrases are never
    written to disk.
-   **Resume state is now saved before the chroot/package transaction**,
    not only after a caught failure, so an abrupt installer exit during
    package installation still leaves enough topology for the next
    launch.
-   **Btrfs recovery metadata implemented:** profile v2 stores the
    expected data subvolume for each filesystem assignment. r49 also
    reconstructs the deterministic r48-era names (`@`, `@usr`, `@opt`,
    `@home`, `@var`, etc.) when loading an older profile that lacks the
    fourth STORAGE field.
-   **Mount-plan validation hardened:** retry/recovery now validates the
    Btrfs subvolume identity, not merely device-to-mountpoint matching,
    so a top-level ID 5 mount is not mistaken for the installed
    filesystem.
-   **Checkpoint recovery hardened:** after the exact storage tree is
    mounted, r49 reloads persistent target checkpoints. If
    `base_extracted` is missing but `/usr/bin/bash`, `/usr/bin/pkgmk`,
    and `/etc/os-release` prove a valid existing base, the checkpoint is
    safely restored rather than forcing re-extraction.
-   **Declining re-extraction is non-fatal:** choosing No keeps a valid
    existing BFSOS base and continues; an invalid/unknown existing tree
    is preserved and returned to the menu without terminating the
    installer.
-   **Profile validation deduplicated:** repeated references to the same
    missing LV/device are canonicalized and displayed once.
-   **Startup ordering fixed:** when a resume file exists, r49
    loads/reconstructs recovery state before any clean-start unmount
    logic can dismantle the very target it is trying to resume.
-   **Static validation:** `bash -n` passes for r49. Runtime regression
    is still required for fresh-process MD/LUKS/LVM/Btrfs recovery, LUKS
    prompts, checkpoint recognition, and interrupted-download
    continuation.

## r89 relaunch-recovery runtime findings --- 2026-08-18

### Fresh-process recovery must restore the full saved storage stack before validating leaf devices

-   [x] **FIX IMPLEMENTED in installer r49; runtime regression pending
    (2026-08-18):** A fresh r48 launch loaded the saved profile while
    the previous install's MD/LUKS/LVM stack was inactive and
    immediately reported saved LV paths as missing.
-   **Runtime proof:** `mdadm --assemble --scan` successfully
    reassembled the saved six-disk RAID6 as `/dev/md0` with all six
    members healthy (`[UUUUUU]`). The saved LUKS containers on
    `/dev/vda3` and `/dev/md0` were intact; after reopening `cryptroot`
    and `cryptraid`, the saved `bfs-root` and `bfs-raid` LVM stacks
    became available again.
-   **Required recovery order:** load saved profile/state -\> assemble
    only saved MD arrays -\> reopen only saved LUKS mappings -\>
    scan/activate only saved VGs/LVs -\> restore filesystem/subvolume
    mounts -\> validate saved leaf devices/checkpoints -\> resume the
    next incomplete installer stage.
-   Recovery must be **non-destructive** and must never recreate RAID,
    LUKS, PVs, VGs, LVs, filesystems, or signatures merely to resume.
-   Do not store LUKS passphrases. Prompt securely for each required
    saved mapping that is not already open.
-   Every step must be idempotent: already-active arrays/mappings/VGs
    should be verified and reused rather than torn down/recreated.
-   If any layer cannot be restored, show the exact failed layer/device
    and return to a recovery/menu path without formatting or wiping
    anything.

### Recovery must restore Btrfs subvolume mount options for every Btrfs filesystem

-   [x] **FIX IMPLEMENTED in installer r49; runtime regression pending
    (2026-08-18):** Reopening the correct block devices was not enough.
    Mounting the Btrfs filesystems without their saved subvolume options
    exposed the Btrfs top-level trees instead of the installed system.
-   **Observed root behavior:** `/dev/bfs-root/root` mounted without
    `subvol=@` appeared as Btrfs top level (`subvolid=5`) and showed
    `@`/`@snapshots` rather than the installed root.
-   **Observed separate-filesystem behavior:** `/dev/bfs-root/usr`
    mounted without `subvol=@usr` showed `@usr` and `@usr-snapshots`
    directories; `bash` and `pkgmk` appeared missing even though the
    installed `/usr` data was intact inside `@usr`.
-   **Confirmed correct saved layout:**
    -   `/` -\> `/dev/bfs-root/root`, `subvol=@`
    -   `/usr` -\> `/dev/bfs-root/usr`, `subvol=@usr`
    -   `/opt` -\> `/dev/bfs-root/opt`, `subvol=@opt`
    -   `/home` -\> `/dev/bfs-raid/home`, `subvol=@home`
    -   `/var` -\> `/dev/bfs-raid/var`, `subvol=@var`
-   After remounting with the correct subvolumes, `bash`, `pkgmk`, and
    `/etc/os-release` were all present and the installer checkpoint
    files became visible.
-   **Required state persistence:** the resume profile/checkpoint data
    must preserve filesystem type, device, mountpoint, Btrfs
    subvolume/subvolume ID or canonical subvolume name, and any other
    mount options required to reconstruct the exact prior filesystem
    view.
-   **Regression test:** relaunch with all Btrfs filesystems inactive,
    reconstruct the saved stack, mount all five saved Btrfs filesystems
    using their recorded subvolumes, and verify the installed
    tree/checkpoints are visible before validation continues.

### Fresh-process relaunch does not honor existing `base_extracted` checkpoint

-   [x] **FIX IMPLEMENTED in installer r49; runtime regression pending
    (2026-08-18):** After manually reconstructing the storage stack and
    mounting all Btrfs subvolumes correctly, the target contained valid
    installer state:
    -   `base_extracted`
    -   `accounts_configured`
    -   `last_failure`
    -   `/usr/bin/bash` present
    -   `/usr/bin/pkgmk` present
    -   `/etc/os-release` present
-   Despite that, a fresh r48 launch still proceeded to the
    base-extraction path and displayed **`Extract into it anyway?`**.
-   **Required behavior:** once the saved target is reconstructed and
    mounted correctly, detect and trust a valid `base_extracted`
    checkpoint after sanity-checking required base-system files. Skip
    base extraction automatically and advance to the next incomplete
    checkpoint.
-   If the checkpoint file is missing but the target clearly contains a
    valid extracted BFSOS base, offer an explicit safe recovery choice
    such as **Use existing base / Re-extract / Cancel**, with **Use
    existing base** as the non-destructive recovery path.
-   Never force users to overwrite a valid partially installed rootfs
    merely because the installer process was restarted.

### Declining re-extraction is incorrectly treated as fatal installation cancellation

-   [x] **FIX IMPLEMENTED in installer r49; runtime regression pending
    (2026-08-18):** When r48 reached the existing-files warning during
    base extraction, choosing **No** to `Extract into it anyway?`
    resulted in `ERROR: Installation cancelled.` and a fatal installer
    exit.
-   **Required behavior:** in recovery mode, **No** must mean **keep the
    existing extracted base and continue/re-evaluate checkpoints**, not
    terminate the installer.
-   Distinguish a user explicitly cancelling the entire installation
    from declining a destructive/redundant re-extraction step.
-   **Regression test:** with `base_extracted` already complete, force
    the extraction confirmation path and choose No; installer must
    remain alive, preserve the target, and continue from the next
    incomplete stage.

### Profile validation missing-device list must be deduplicated

-   [x] **FIX IMPLEMENTED in installer r49; runtime regression pending
    (2026-08-18):** The r48 Profile validation dialog listed the same
    saved LV paths more than once (including `/dev/bfs-root/root` and
    `/dev/bfs-raid/home`).
-   Canonicalize and deduplicate device paths before
    validation/reporting. Preserve deterministic ordering so the warning
    remains easy to audit.
-   The same saved device may legitimately be referenced by several
    installer fields; that must not create duplicate warning rows.

## r88 runtime recovery findings --- 2026-08-18

### Relaunch recovery must reconstruct MD RAID -\> LUKS -\> LVM before profile device validation

-   [x] **FIX IMPLEMENTED in r49-r57 / runtime regression tracked by
    newer recovery items:** After the previous installer process exited
    and its cleanup deactivated the VGs/stopped the MD array, r48 loaded
    the saved profile and immediately reported saved LV paths such as
    `/dev/bfs-root/root`, `/dev/bfs-root/usr`, `/dev/bfs-root/opt`,
    `/dev/bfs-raid/home`, and `/dev/bfs-raid/var` as missing.
-   **Root cause:** profile validation currently checks saved leaf
    block-device paths before reconstructing the storage dependency
    stack that creates those paths.
-   **Runtime confirmation:** `mdadm --assemble --scan` successfully
    reassembled `/dev/md0` as RAID6 with all six members healthy
    (`[UUUUUU]`). `lsblk` then showed `/dev/vda3` and `/dev/md0` as
    intact `crypto_LUKS` containers. `pvs`, `vgs`, and `lvs` remained
    empty because the saved LUKS mappings had not yet been reopened.
-   **Required relaunch order:** load saved profile -\> assemble only
    the saved MD arrays -\> reopen only the saved LUKS mappings -\>
    scan/activate the saved LVM VGs -\> validate saved LV/device paths
    -\> mount the saved target filesystem plan -\> resume installation.
-   **LUKS safety:** never persist passphrases. On relaunch, prompt
    securely for each saved mapping that is required and not already
    open. Reuse an already-open mapping only after verifying that it
    corresponds to the expected backing device.
-   **MD/LVM safety:** recovery must be non-destructive. Do not recreate
    arrays, PVs, VGs, LVs, filesystems, or signatures. Assemble/activate
    only storage recorded by the saved installer state and verify
    identity/topology before reuse.
-   **Idempotence:** every recovery step must tolerate components that
    are already active. A same-process retry and a fresh-process
    relaunch should converge on the same valid storage state without
    unnecessary teardown.
-   **Failure handling:** if a required array cannot be assembled, a
    LUKS mapping cannot be opened, or a VG/LV cannot be activated,
    return to a clear recovery screen without formatting/wiping anything
    and identify the exact layer that failed.
-   **Regression test:** terminate/relaunch the installer after RAID6 +
    LUKS + LVM have been configured, with MD stopped and VGs inactive.
    Verify the installer reconstructs the saved stack in dependency
    order, prompts for required LUKS passphrases, restores the saved
    LVs, mounts the target, and resumes without requiring Storage Setup
    to be redone.

### Profile validation missing-device list contains duplicate LV paths

-   [x] **FIX IMPLEMENTED in r49-r57 / runtime regression tracked by
    newer recovery items:** The r48 Profile validation dialog listed
    `/dev/bfs-root/root` and `/dev/bfs-raid/home` more than once while
    reporting unavailable saved devices.
-   **Required fix:** canonicalize and deduplicate saved block-device
    paths before existence checks and before rendering the
    missing-device dialog. Preserve deterministic ordering so the
    warning is easy to audit.
-   **Regression test:** load a profile in which the same LV is
    referenced by multiple installer roles/state fields and verify each
    missing device is displayed exactly once.

## r87 implementation / installer-recovery pass --- 2026-08-18

-   **Installer r48 created:**
    `scripts/install-bfs-menu-v50-r48-recovery-lvm-download-fixes.sh`.
-   **Same-process Install / Retry recovery hardened:** when the
    target's selected filesystem plan is already mounted correctly after
    a chroot/package failure, r48 reuses it instead of unmounting and
    remounting the target. This directly addresses the observed
    `umount: /mnt/bfs: target is busy` -\> fatal exit on retry.
-   **Download behavior hardened:** pkgutils release 11 removes the
    third-party flat distfile mirror that caused misleading
    first-attempt 404s, retains partial-file continuation, adds
    stalled-transfer detection, and retries truncated/interrupted
    transfers including curl error 18. Bootstrap Stage 2/3 generated
    pkgmk configuration now uses the same policy.
-   **404 diagnosis corrected:** the logged 404s before
    `linux-firmware`, `wpa_supplicant`, and `rdfind` were consistent
    with the configured flat mirror being tried before the actual
    Pkgfile source. The actual Pkgfile URLs were not replaced merely
    because of those mirror misses; the default flat mirror was removed
    instead.
-   **LVM sizing made explicit:** ambiguous bare values such as `50%`
    are rejected. Users must choose `%FREE` or `%VG`; percentage
    requests are checked against free extents, never silently clamped,
    and the calculated effective allocation is shown for confirmation
    before `lvcreate`.
-   **Static validation:** updated Bootstrap, pkgutils Pkgfile, and
    installer r48 pass `bash -n`. Runtime interrupted-download/resume
    and LVM UI tests remain required.

## r84 implementation / regression-audit pass --- 2026-08-18

-   **Installer r47 created:**
    `scripts/install-bfs-menu-v50-r47-tracker-fixes.sh`.
-   **Kernel-selection crash fixed:** `kernel_pkgfile_version()` now
    initializes locals in nounset-safe steps, validates the requested
    port name, and returns `unknown` instead of aborting for
    missing/malformed data. Static `bash -u` tests returned live
    versions for `linux`/`linux-lts` and `unknown` for missing/blank
    requests.
-   **ZRAM review/visibility completed:** the final pre-install review
    already contained ZRAM state/size and is retained; the Current
    storage devices view now adds configured/active ZRAM; the ZRAM menu
    marks the active size with `[CURRENT]`.
-   **MD stale-signature regression repaired:** after a new MD array is
    created, the installer now inspects the array itself for surviving
    filesystem/LUKS/LVM signatures and offers Keep, Remove, or Cancel.
    LVM VGs exposed by stale metadata are deactivated before an
    explicitly approved removal. The new MD array itself remains active.
-   **Partition-screen safety improvement:** disks whose partition
    tables actually changed during the current installer session are
    marked `[MODIFIED THIS SESSION]`; simply opening/exiting `cfdisk`
    does not mark the disk because before/after kernel-visible partition
    fingerprints are compared.
-   **Bootstrap Stage 3 ccache hardened:** when ccache is enabled, Stage
    3 now verifies the BFSOS ccache binary/wrappers before rebuilding,
    prepends `/usr/lib/ccache` to the Stage-3 build PATH from the first
    package, and prints ccache statistics before/after the rebuild.
-   **Bootstrap verification status:** successful option 4 now displays
    bright-yellow `[PASSED!]` rather than green `[COMPLETE]` in both
    Dialog and text menus.
-   **GCC branding fixed:** final GCC now uses
    `--with-pkgversion="BFSOS"`; the package release is bumped to `2`.
    The shipped default/LTS kernel config compiler-text fields were also
    refreshed to `gcc (BFSOS) 16.2.0` (kernel releases bumped to force
    fresh packages). Attribution comments elsewhere in core/non-core
    ports were intentionally not rewritten.
-   **Last-night regression audit:** no malformed `;;;` case terminators
    remain in `bootstrap.sh` or `ports/core/pkgutils/Pkgfile`; both
    scripts parse with `bash -n`. Temporary-toolchain and target UTF-8
    locale generation/validation code remains present. The current clean
    test reached Stage 2 and GCC 16.2 extracted successfully without the
    previous pathname error, confirming the critical temporary-glibc
    locale fix in real use. RAID6 creation also reached a live
    six-member array without the old post-create `wipefs` busy crash,
    confirming that ordering fix for RAID6.
-   **Still requires runtime testing:** failed-download installer
    resume, storage deactivation/MD stop, Back-navigation paths, all
    RAID levels other than the newly retested RAID6, ccache hit/miss
    activity across a full Stage 3, archive restore locale verification,
    and hardware/bare-metal/release/post-1.0 items.
-   **Audit report:**
    `docs/BFSOS-r84-static-regression-audit-20260818.md` records the
    static regression checks and the remaining live tests.

## r74 implementation pass --- 2026-08-18

-   **Installer r46 created:**
    `scripts/install-bfs-menu-v50-r46-tracker-fixes.sh`.
-   **Bootstrap updated:** Stage 1 temporary-glibc UTF-8 locale is now
    required/verified before toolchain archive creation; the archive is
    checked for the locale archive; Stage 2 generates and validates the
    target `C.utf8` locale immediately after glibc installation; Stage 1
    `pkgmk` failure capture was hardened.
-   **pkgutils updated:** release bumped to 10 and `pkgmk` locale
    selection now validates actual charmap usability with the
    libc/toolchain associated with the running `pkgmk`, rather than
    trusting `locale -a` alone.
-   **glibc updated:** temporary glibc now generates and validates its
    own `C.UTF-8` locale archive before GCC pass 2.
-   **Installer fixes implemented:** RAM-backed pkgmk workspace defaults
    on; storage deactivation unwinds filesystems/LVM/dm-crypt/MD and
    reports incomplete cleanup; RAID member signatures are handled
    before `mdadm --create`; ZRAM settings UI is state-aware; kernel
    versions are read from Pkgfiles; package/download failure capture
    and persistent non-secret resume profile/checkpoints were hardened;
    Back/Cancel paths for base archive and optional package selection
    are non-fatal.
-   **Already present and retained:** GPM optional package support and
    `gpm.service` enablement.
-   **GNU source cleanup:** 29 core GNU ports were moved from
    `ftpmirror.gnu.org` to canonical `ftp.gnu.org/gnu`; the hierarchical
    kernel.org fallback remains pending downloader support.
-   **Not falsely marked complete:** hardware/runtime regression tests,
    RC/release documentation milestones, post-1.0 UI roadmap items, and
    the hierarchical GNU mirror fallback. CRUX `PKGMK_SOURCE_MIRRORS` is
    a flat filename cache; a path-aware GNU alternate-host downloader
    still requires a deliberate `pkgmk` download-layer enhancement
    rather than an inert config variable.

### Installer build settings --- RAM-backed pkgmk workspace default

-   [x] **IMPLEMENTED in installer r46; runtime regression pending:**
    `RAM-backed pkgmk workspace` now defaults to `Yes` for new installer
    settings.
    -   Current testing shows the feature enabled, but the installer
        default should explicitly be **Yes** rather than depending on
        inherited/previous settings.
    -   Keep the setting user-configurable so RAM-backed build work can
        still be disabled.
    -   Keep `RAM workspace maximum` defaulting to **Auto**, using the
        installer's calculated recommendation (16G in the current VM
        test).
    -   This is an installer/build-settings default issue, not a
        Bootstrap issue.

### Installer storage deactivation --- active MD RAID arrays are not stopped

-   [x] **FIX IMPLEMENTED in installer r46; runtime regression
    pending:** storage deactivation now unwinds the stack and explicitly
    stops eligible active `mdadm` arrays instead of silently reporting
    success.
-   **Required behavior:** Deactivate storage in dependency order so
    higher layers are removed before the backing MD device is stopped.
-   **Expected order:** unmount filesystems -\> deactivate LVM
    logical/volume groups as applicable -\> close dm-crypt mappings as
    applicable -\> stop active MD RAID arrays.
-   **MD cleanup:** Stop installer-managed/selected arrays with
    `mdadm --stop <array>` and verify they disappear from `/proc/mdstat`
    before returning to the storage menu.
-   **Safety:** Do not blindly stop unrelated host/live-environment
    arrays. Limit cleanup to arrays created, assembled, or explicitly
    selected by the installer session/topology.
-   **Error handling:** If an array cannot be stopped because it is
    still busy, show a useful Dialog error identifying the remaining
    dependency/device rather than silently reporting successful
    deactivation.
-   **Regression test:** Create/assemble RAID6, optionally layer LVM on
    it, choose Deactivate storage, and verify filesystems/LVM are
    deactivated in order and the MD array is no longer active without
    requiring a manual `mdadm --stop`.

### Installer base package selection --- Back closes installer

-   [x] **NAVIGATION HARDENED in installer r46; runtime regression
    pending:** Back/Cancel from the relevant
    base-archive/package-selection Dialog paths is explicitly captured
    and returns to the prior installer screen instead of propagating a
    nonzero Dialog status.
-   **Required behavior:** Treat the Dialog **Back/Cancel** navigation
    result as normal installer navigation, not as a fatal error or
    installer exit.
-   **Audit:** Check the base-package selection function's Dialog
    return-code handling and make sure a nonzero Back/Cancel result
    cannot fall through into `set -e`, an ERR trap, or a top-level exit
    path.
-   **State preservation:** Returning from base package selection should
    preserve the installer's existing configuration and package
    selections unless the user explicitly changes or resets them.
-   **Regression test:** Enter base package selection, choose **Back**,
    verify the previous installer menu is displayed, verify the
    installer process remains running, then re-enter package selection
    and confirm prior state is intact.

### Installer ZRAM settings screen --- state/action mismatch and no-op Enable option

-   [x] **FIX IMPLEMENTED in installer r46; runtime regression
    pending:** the ZRAM screen is state-aware and shows only the
    meaningful Enable/Disable action, with status/size refreshed after
    each change.
-   **Rework the ZRAM screen** so the available action reflects the
    current state rather than presenting dead/no-op choices.
-   When ZRAM is enabled, show a clear `Current status: Enabled` and
    current size, and offer **Disable ZRAM** plus the size choices.
-   When ZRAM is disabled, show `Current status: Disabled` and offer
    **Enable ZRAM** plus the size choices as appropriate.
-   After enabling/disabling ZRAM or changing its size, immediately
    redraw/refresh the Dialog so the displayed status and size reflect
    the new setting.
-   Avoid simultaneously presenting both **Enable ZRAM** and **Disable
    ZRAM** as if both are meaningful actions.
-   Preserve the existing 50%, 100%, 150%, 200%, and custom-size
    choices.
-   **Regression test:** Toggle ZRAM on/off repeatedly, select each
    percentage/custom size, verify the status line updates immediately,
    and verify no selectable menu entry silently performs a no-op.

### Installer kernel selection --- simplify descriptions and show live Pkgfile versions

-   [x] **IMPLEMENTED in installer r46; runtime regression pending:**
    kernel selection now reads versions dynamically from the
    corresponding Pkgfiles and keeps the LTS annotation to the concise
    `Debian patch set` label.
-   **Default kernel:** Display only the kernel name and its current
    version, read dynamically from the default kernel port's `Pkgfile`.
-   **LTS kernel:** Display the kernel name, its current version read
    dynamically from the LTS kernel port's `Pkgfile`, and a short note
    such as **`Debian patch set`**.
-   Do not hard-code either kernel version in the installer; kernel
    updates should automatically be reflected by reading the
    corresponding `Pkgfile`.
-   Keep the LTS description concise; no additional long explanatory
    text is needed.
-   **Regression test:** Change each kernel port's version in its
    `Pkgfile` and verify the installer kernel-selection screen displays
    the updated versions without requiring an installer code change.

### Installer failed download / package failure --- resume path confirmed broken

-   [x] **RECOVERY HARDENED through installer r48; RELEASE-BLOCKING
    runtime regression still required:** package/download failures are
    captured, resume/checkpoint state is preserved, and r48 additionally
    reuses an already-correct target mount plan on same-process Install
    / Retry instead of triggering the fatal busy-unmount path seen in
    the linux-firmware test.
-   **Latest observed test result (r47): FAILED.** Continue -\> Install
    after the interrupted linux-firmware download reached a busy-target
    remount failure. r48 contains a direct fix for that same-process
    retry path; relaunch-after-process-exit remains a separate runtime
    test because encrypted/LVM layers may require user reactivation.
-   **Startup/resume audit required:** Trace persisted checkpoint/state
    loading, target mount/state detection, storage topology
    reconstruction, startup validation, and all
    `set -e`/ERR-trap/nonzero-return paths that run before the main
    installer menu is restored.
-   **Required relaunch behavior:** A relaunch after an interrupted
    package phase must reconstruct the prior configuration,
    validate/remount the existing target as needed, force completed
    filesystem format actions to `keep`, and return to the installer
    menu with **Install / Retry** available rather than terminating.
-   **Existing intended behavior:** The installer already has a
    checkpoint/resume design intended to preserve completed
    destructive/setup stages and allow a later **Install / Retry** to
    continue from the failed/incomplete package transaction.
-   **Current problem:** Real failed-download testing still shows that
    this recovery path is not fully reliable; the installer can
    terminate before the resume UI/checkpoint flow is reached.
-   **Required behavior on download/package failure:** Catch nonzero
    statuses from package/source download, `ports -u`, `prt-get sysup`,
    `prt-get depinst`, package builds, and optional package installation
    without terminating the installer process.
-   **UI behavior:** Show the normal Dialog failure message with
    package/operation, URL when detectable, exit status, and preserved
    installer/package log path, then provide **Continue/Back** to return
    to the installer main menu.
-   **Resume behavior:** On rerun or **Install / Retry**, preserve and
    validate existing storage/filesystem/base-extraction state, force
    prior format actions to `keep`, re-run `ports -u` so repaired source
    metadata is picked up, retry only the failed/incomplete package
    transaction, and continue from the next incomplete checkpoint.
-   **Safety:** Never automatically repartition, recreate RAID/LUKS/LVM,
    reformat filesystems, or re-extract the base archive if those stages
    already completed successfully.
-   **Checkpoint verification:** Confirm the installer persists enough
    state to distinguish at least `base_extracted`, `packages_complete`,
    `system_config_complete`, and `bootloader_complete`, and that state
    survives an installer process exit/relaunch when possible.
-   **Regression test:** Intentionally break one package URL, start
    installation, allow the download to fail, verify the installer stays
    alive and returns to its menu, repair the URL from another terminal,
    select **Install / Retry**, verify `ports -u` reruns, verify no
    destructive/setup stages repeat, and confirm installation resumes
    through completion.

### Installer MD RAID creation --- signature/wipe ordering is backwards for all RAID levels

-   [x] **FIX IMPLEMENTED in installer r46; RAID6 runtime regression
    PASSED 2026-08-18:** the common MD RAID path checks/clears approved
    stale signatures on member devices **before** `mdadm --create`; the
    post-create `wipefs -a "$array_device"` operation was removed. A new
    six-member RAID6 was created and remained active without the prior
    `wipefs: Device or resource busy` abort. Other RAID levels still
    need regression coverage.
-   **Scope:** Treat this as a common `create_raid_array()` bug
    affecting every MD RAID level that uses this path (RAID0/1/5/6/10
    and any other supported MD level), not as a RAID6-only issue.
-   **Observed failure:** `mdadm` reports the new array started
    successfully, followed immediately by `wipefs` failing to probe the
    active array because it is busy.
-   **Required ordering:** Select member devices -\> detect stale
    filesystem/RAID signatures on the member devices -\> ask the user
    for erase confirmation when needed -\> clear approved stale
    signatures/old MD metadata from the member devices -\> run
    `mdadm --create` -\> allow the newly created `/dev/mdX` to remain
    active for subsequent filesystem/LUKS/LVM setup.
-   **Do not:** Run a blanket post-create `wipefs -a` on the newly
    active `/dev/mdX`.
-   **Safety:** Signature confirmation must identify exactly which
    member device/signature will be erased. Never wipe unrelated devices
    or an already-created active array merely as part of RAID creation.
-   **Regression tests:** Exercise every installer-supported MD RAID
    level. Test both clean member disks and members containing stale
    filesystem/MD signatures. Confirm the erase question occurs before
    array creation, the approved member signatures are cleared,
    `mdadm --create` succeeds, `/dev/mdX` remains active, and the
    installer continues without a `wipefs` busy failure.

### Installer package-download failure --- partial download lost and recovery remount path aborts

-   [x] **FIX IMPLEMENTED in installer r48 / runtime regression pending
    (2026-08-18):** During optional package installation,
    `linux-firmware` failed after an interrupted large download. r48 now
    recognizes when the selected target filesystem plan is already
    mounted correctly and reuses it for Install / Retry rather than
    forcing the unmount/remount path that previously hit a busy
    `/mnt/bfs` and terminated the installer.
-   **Observed linux-firmware failure:** Primary kernel.org URL returned
    HTTP 404; a subsequent transfer then downloaded about 104 MiB of a
    \~609 MiB archive before curl exited with error 18
    (`end of response ... bytes missing`).
-   [x] **Download-resume code hardened:** BFSOS pkgmk configuration
    keeps `--continue-at -`, adds stalled-transfer detection
    (`--speed-limit 1024 --speed-time 30`), and uses bounded
    `--retry-all-errors` retries so curl error 18/truncated transfers
    can retry from the partial file. Runtime verification with a
    deliberately interrupted large file is still required.
-   **Retry policy:** Distinguish hard failures such as HTTP 404 from
    transient transport failures such as truncated responses/timeouts.
    Hard-failed URLs should advance quickly to the next valid source;
    interrupted transfers should retry/resume the same source a limited
    number of times before falling back.
-   **Integrity:** Never trust a resumed/partial file without the normal
    pkgmk checksum/signature verification after the complete file is
    assembled.
-   **Installer recovery bug:** After the package failure, the installer
    entered a target-filesystem remount/recovery path and attempted to
    unmount `/mnt/bfs`; `umount` reported `target is busy`, followed by
    `ERROR: Could not unmount /dev/bfs-root/root from /mnt/bfs`, and the
    installer terminated.
-   [x] **Required recovery behavior implemented in r48:** A
    canonicalized mount-plan check verifies root/boot/EFI/home/extra
    assignments. If they already match, r48 reuses the live target and
    proceeds directly back into the retry path without destructive
    storage teardown.
-   **Busy-target handling:** Detect processes/chroots/mounts keeping
    `/mnt/bfs` busy, report them meaningfully if cleanup is genuinely
    required, and never convert a recoverable package-download failure
    into a full installer exit merely because the target is already
    mounted.
-   **State preservation:** Preserve completed package installs. In this
    run many dependencies/optional packages had already installed
    successfully before `linux-firmware` failed; retry should resume at
    the failed/incomplete package rather than reinstalling completed
    work.
-   **Regression test:** Force an interrupted large package download
    after \>100 MiB is received. Verify the partial file is retained,
    retry resumes rather than restarting, installer stays alive, storage
    remains intact, completed packages are not redundantly reinstalled,
    and the failed package can be retried to completion.

### Installer source URLs --- stale 404 primaries still present for linux-firmware, wpa_supplicant, and rdfind

-   [x] **ROOT CAUSE CORRECTED / CONFIG FIX IMPLEMENTED (2026-08-18):**
    The initial 404s seen before several otherwise-successful downloads
    were caused by the configured flat `PKGMK_SOURCE_MIRRORS` cache
    being tried before the real Pkgfile URL. pkgutils release 11
    disables that third-party flat mirror by default, so healthy
    upstream URLs are attempted directly.
-   **Observed log behavior:** `linux-firmware`, `wpa_supplicant`, and
    `rdfind` each showed an initial 404 while the flat mirror policy was
    enabled. Subsequent behavior showed the real source could still be
    attempted; do not mislabel the Pkgfile URL as stale solely from the
    mirror miss.
-   [x] **Required action completed for this regression:** Remove the
    misleading default flat mirror rather than rewriting valid package
    source URLs. Keep source URLs independently maintainable and verify
    them when a failure is demonstrably from the source host itself.
-   Keep backup/fallback handling, but the first configured URL should
    be expected to work under normal conditions.
-   **Regression test:** Clear cached sources and build each affected
    package; verify the primary URL succeeds without an initial 404 and
    fallback is only used when intentionally simulated.

### LVM percentage sizing --- mixed fixed-size and percentage LVs produce confusing allocation

-   [x] **FIX IMPLEMENTED in installer r48 / runtime UI regression
    pending (2026-08-18):** Ambiguous bare percentages are no longer
    accepted. The LVM UI requires explicit `%FREE` or `%VG`, validates
    requested extents against current free extents, refuses
    over-allocation instead of silently clamping, and shows the
    effective allocation before creation.
-   **Observed live test:** `bfs-root` VG was approximately
    `246.98 GiB`. User selected `root = 100G`, `usr = 50%`, and
    `opt = 50%`. Resulting LVs were approximately:
    -   `root = 100.00 GiB`
    -   `usr = 123.49 GiB`
    -   `opt = 23.49 GiB`
-   **Likely current behavior:** `usr = 50%` appears to have been
    calculated against the original total VG size
    (`246.98 / 2 ≈ 123.49 GiB`), leaving only `23.49 GiB` for `opt`; the
    final percentage request then appears to have been reduced/clamped
    to the remaining free space.
-   **UX problem:** Two `50%` selections alongside a fixed `100G` LV do
    not intuitively communicate that one LV may receive \~123.49 GiB
    while the other receives only \~23.49 GiB. The installer must not
    silently reinterpret or clamp percentage requests without making the
    result explicit.
-   **Implemented semantics:** `%FREE` means a percentage of the
    currently free extents at the moment the LV is created; `%VG` means
    a percentage of total VG extents. A bare `50%` is rejected with an
    explanation rather than silently interpreted. A future declarative
    multi-LV planner could provide pooled percentage shares, but r48
    removes the unsafe ambiguity from the current imperative workflow.
-   If percentages intentionally mean `%VG` rather than a share of
    remaining free space, label that explicitly in the UI and
    reject/resolve combinations whose requested total exceeds available
    extents instead of silently shrinking the last LV.
-   [x] **Pre-creation review implemented for each LV:** Before
    `lvcreate`, r48 shows the requested percentage/fixed size and, for
    percentage requests, the calculated effective MiB/extents, then
    requires confirmation.
-   **Validation:** Ensure rounding to physical extents cannot
    over-allocate the VG, and never depend on creation order to produce
    materially different results unless the UI explicitly describes
    sequential allocation.
-   **Regression tests:** Test fixed-only, percentage-only, and mixed
    layouts, including `100G + 50% + 50%`, reversed LV order,
    percentages totaling under/at/over 100%, and very small remaining
    free-space cases.

### Final pre-install review --- include ZRAM configuration

-   [x] **IMPLEMENTED / STATICALLY VERIFIED in installer r47
    (2026-08-18):** The final **BFS Installation review** includes the
    selected ZRAM Enabled/Disabled state and configured size.
-   **Required review fields:** Show whether ZRAM is
    **Enabled/Disabled** and, when enabled, the configured size (for
    example `100% of RAM`, `200% of RAM`, or the exact custom size).
-   If the installer computes an effective size from a percentage, the
    review may also show the resolved size in GiB/MiB where practical.
-   The review must reflect the currently selected installer settings,
    not merely the live environment's current `/dev/zram0` state.
-   If ZRAM is disabled, show that explicitly rather than omitting the
    entry.
-   Keep the ZRAM review near other memory/swap/storage settings so the
    user can verify it before committing to installation.
-   **Regression test:** Configure several predefined ZRAM percentages,
    a custom size, and Disabled; open the final review each time and
    verify the displayed ZRAM state/size exactly matches the installer
    configuration.

### Kernel selection crashes installer --- `kernel_pkgfile_version()` uses unbound `package`

-   [x] **FIXED in installer r47 / nounset static regression passed
    (2026-08-18):** The r46 kernel-selection crash from an unbound
    `package` local is corrected; runtime Dialog regression remains to
    be exercised.
-   **Observed failure:** `line 3728: package: unbound variable`.
-   Installer error report identifies:
    -   Function: `configure_kernel`
    -   Failing command:
        `linux_version="$(kernel_pkgfile_version linux)"`
    -   Caller: line 3739
    -   Exit status: `1`
-   **Likely defect location:** `kernel_pkgfile_version()` around line
    3728 references shell variable `package` without safely initializing
    it from the function argument (for example `local package="${1:-}"`)
    before use. With `set -u`/nounset active, this immediately aborts
    the installer.
-   **Required fix:** Audit the entire `kernel_pkgfile_version()` helper
    and its callers. Explicitly initialize every local variable before
    reference, validate the requested kernel package/port name, and make
    missing/malformed Pkgfile/version information return a safe fallback
    instead of terminating the installer.
-   Dynamic kernel-version display must remain informational/UI logic
    and **must never be capable of crashing the installer**.
-   Verify both normal/default kernel and LTS kernel lookups, including
    the requested LTS description/branding behavior.
-   **Regression tests:**
    1.  Open kernel selection with valid default and LTS Pkgfiles and
        verify both versions display correctly.
    2.  Test a missing Pkgfile, missing `version=` field, empty value,
        and malformed value; installer must remain running and show a
        sensible `unknown`/unavailable fallback.
    3.  Run with nounset (`set -u`) enabled and confirm no
        unbound-variable failure.
    4.  Back out of kernel selection and re-enter it repeatedly without
        installer termination.

### Current storage devices view --- include configured ZRAM swap

-   [x] **IMPLEMENTED in installer r47; runtime UI regression pending
    (2026-08-18):** Current storage devices now includes
    configured/active ZRAM state and size.
-   **Current behavior:** The storage tree shows physical disks,
    partitions, MD RAID, LUKS mappings, LVM PV/LVs, filesystems, etc.,
    but the configured ZRAM device is absent.
-   **Desired behavior:** Show the ZRAM swap device (normally
    `/dev/zram0`) with a clear type/status such as `zram swap`, its
    configured/effective size, and whether it is currently active if
    that information is available.
-   If ZRAM is configured for installation but has not yet been
    instantiated in the live environment, show a separate concise entry
    such as `ZRAM swap: enabled, 100% of RAM (configured)` rather than
    pretending a `/dev/zram0` device already exists.
-   Keep ZRAM visually distinct from persistent block storage so users
    do not mistake it for a disk/partition.
-   The displayed size/state should update after changing the ZRAM
    configuration.
-   **Regression test:** Enable/disable ZRAM and test predefined/custom
    sizes; reopen Current storage devices and verify the displayed ZRAM
    state and size match the installer configuration.

### ZRAM size menu --- clearly mark the currently selected size

-   [x] **IMPLEMENTED in installer r47; runtime UI regression pending
    (2026-08-18):** The current predefined/custom ZRAM size is marked
    `[CURRENT]` directly in the menu.
-   **Observed behavior:** With ZRAM enabled at 100%, the choices `50%`,
    `100%`, `150%`, `200%`, and `Custom` all look identical. The blue
    highlight only indicates the current cursor position and can
    therefore be mistaken for the configured value.
-   **Desired behavior:** Add an unmistakable marker to the active
    configuration, for example `Size: 100% of RAM [SELECTED]` or
    `[CURRENT]`, and update it immediately whenever the user chooses
    another size.
-   If a custom size is active, show the actual configured custom value
    and mark the Custom entry as selected/current.
-   Keep the header summary, but make the menu state independently
    understandable without relying on the header.
-   Consider using the same selected/current-state convention on other
    installer option menus where cursor highlight and configured value
    can otherwise be confused.
-   **Regression test:** Select each predefined ZRAM size and a custom
    size, return to/reopen the screen, and confirm exactly one choice
    clearly reflects the persisted current configuration.

### Newly created MD RAID --- detect surviving LVM metadata and ask whether to preserve or remove it

-   **LIVE TEST UPDATE (2026-08-18):** Stale LVM signatures from the
    previous crashed installation were detected/cleared as expected
    during the new installer test. Continue testing the full
    Keep/Remove/Cancel branches independently, but the stale-signature
    cleanup path has now succeeded in a real reused-storage scenario.
-   [x] **IMPLEMENTED in installer r47; runtime Keep/Remove/Cancel
    regression pending (2026-08-18):** New MD arrays are inspected for
    surviving signatures including LVM metadata and the user is
    explicitly offered Keep, Remove, or Cancel.
-   **Observed during testing:** A newly created RAID6 `/dev/md0`
    immediately appeared as an `LVM2_member` and caused the old
    `bfs-raid` VG with `home` and `var` LVs to reactivate, even though
    the RAID member disks had just been repartitioned/recreated.
-   **Detection:** Inspect the newly available `/dev/mdX` with
    appropriate non-destructive signature/LVM discovery (`wipefs`
    read-only inspection, `pvs`, etc.) before using it for LUKS, a new
    PV, formatting, or other destructive operations.
-   **If existing LVM is detected:** Present an explicit choice
    explaining that existing LVM metadata/logical volumes were found on
    the RAID device:
    -   **Keep existing LVM** --- preserve the PV/VG/LVs and do not wipe
        or overwrite their metadata.
    -   **Remove existing LVM** --- clearly warn that the existing
        VG/LVs and their data will be destroyed; deactivate the affected
        VG/LVs safely, then remove the stale LVM signature/metadata from
        the selected MD device only.
    -   **Cancel / Back** --- make no changes.
-   Never automatically destroy an existing LVM signature merely because
    the MD array was newly created; surviving metadata may contain data
    the user intentionally wants to recover or reuse.
-   If the user chooses removal, verify that no LV is mounted/in use,
    deactivate the correct VG, operate only on the explicitly selected
    `/dev/mdX`, refresh LVM/device state, and confirm that `LVM2_member`
    is gone while the MD array itself remains active.
-   After removal, refresh subsequent device selectors so `/dev/mdX`
    becomes available for workflows such as **RAID -\> LUKS -\> LVM**.
-   **Regression test:** Recreate an MD array whose data area still
    contains a valid LVM PV/VG, confirm the installer detects it, test
    Keep/Remove/Cancel independently, and verify no unrelated disk or VG
    is modified.

### Installer partition-disk screen --- identify disks modified during current session

-   [x] **IMPLEMENTED in installer r47; runtime UI regression pending
    (2026-08-18):** Partition disks whose kernel-visible partition
    layout changed are marked `[MODIFIED THIS SESSION]`.
-   **Current problem:** The screen lists only device path and size (for
    example `/dev/vda 250G`), so after editing several similarly sized
    disks it is easy to lose track of which devices were already
    changed.
-   **Preferred behavior:** Keep modified disks visible, but append a
    clear status marker such as **`[MODIFIED]`**, **`[PARTITIONED]`**,
    or **`[CHANGED THIS SESSION]`** after the device/size. Do not
    silently remove a disk from the list merely because `cfdisk`/`fdisk`
    wrote a partition table; disappearing entries could make the user
    think a disk vanished or failed.
-   **Detection/state:** Track devices opened through the installer
    partition editor and mark a disk only after the partitioning tool
    exits successfully and the kernel sees a changed partition table.
    Where practical, compare the before/after partition-table state so
    simply opening and exiting without changes does not falsely mark the
    disk modified.
-   **Refresh:** Run the normal partition-table/device refresh
    (`partprobe`/`udevadm settle` or installer equivalent) after leaving
    the partition editor, then redraw the list with the updated status.
-   **Optional enhancement:** Show a concise partition summary for
    modified disks (for example partition count or key partition
    sizes/types) in a detail/status view without overcrowding the
    primary selector.
-   **Persistence scope:** The marker only needs to represent changes
    made during the current installer session; it does not need to imply
    that an existing disk from before installer startup was modified by
    BFSOS.
-   **Regression test:** On a VM/system with many similar disks, edit
    multiple disks, return to the partition-disk selector after each
    edit, and verify each actually changed disk is clearly marked while
    untouched disks remain unmarked and all disks remain selectable.

### Bootstrap Stage 3 --- ensure ccache is used for the entire rebuild

-   [x] **IMPLEMENTATION HARDENED in bootstrap r84; full Stage-3
    statistics regression pending (2026-08-18):** ccache preflight,
    wrapper PATH from the first Stage-3 package, and before/after
    statistics are now enforced when ccache is enabled.
-   Stage 3 should inherit/use the configured ccache setting
    consistently across every applicable package build.
-   Verify `CC`, `CXX`, compiler wrappers/PATH ordering, and
    `pkgmk.conf` handling so individual ports cannot unintentionally
    bypass ccache unless a package explicitly requires it.
-   Preserve any intentional package-specific ccache exclusions and
    document why they are necessary.
-   Add/check ccache statistics before and after Stage 3 so a test run
    can confirm cache hits/misses are actually being recorded.
-   **Regression test:** Run Stage 3 with ccache enabled, confirm
    applicable package builds invoke ccache, and verify `ccache -s`
    shows Stage-3 activity.

### Bootstrap verification status --- show bright-yellow `[PASSED!]`

-   [x] **IMPLEMENTED in bootstrap r84; runtime menu redraw regression
    pending (2026-08-18):** successful verification now renders
    bright-yellow `[PASSED!]`.
-   **Current behavior:** The Bootstrap menu shows option 4 as green
    `[COMPLETE]`, which looks the same as ordinary completed build
    stages.
-   **Desired behavior:** A successful verification should display
    **bright yellow `[PASSED!]`** in the right-hand status column.
-   Keep build-stage completion states separate from verification
    results: stages may remain `[COMPLETE]`, while the
    verification/check result uses `[PASSED!]`.
-   Ensure the status survives normal menu redraws and accurately
    reflects the most recent successful verification rather than being
    cosmetic-only.
-   **Regression test:** Run option 4 successfully, return to the
    Bootstrap menu, and confirm option 4 displays bright-yellow
    `[PASSED!]` with alignment matching the other status fields.

### GCC version branding --- `Linux From Scratch` string appears in BFSOS compiler output

-   [x] **ROOT CAUSE FOUND / FIXED in r84 (2026-08-18):**
    `ports/core/gcc/Pkgfile` explicitly passed
    `--with-pkgversion="Linux From Scratch"`; it now passes
    `--with-pkgversion="BFSOS"`.
-   **Observed behavior:** The compiler version banner is carrying the
    vendor/package branding string `Linux From Scratch` instead of
    BFSOS/BFS Linux branding or the normal upstream GCC banner.
-   **Required investigation:** Determine exactly where the
    `Linux From Scratch` vendor string is being injected. Audit the GCC
    `Pkgfile`, bootstrap GCC pass configuration flags, GCC
    spec/configure options, patches, environment variables, and any
    copied LFS-era bootstrap code that may set a package version/vendor
    suffix.
-   **Likely areas to inspect:** GCC configure arguments such as
    `--with-pkgversion=...`, any `PKGVERSION`/vendor definitions, Stage
    1/2/3 GCC build functions, and the final installed GCC package
    build.
-   **Desired behavior:** Replace the stale LFS branding with an
    appropriate BFSOS/BFS Linux identifier, or leave the upstream GCC
    banner unbranded if that is preferable. Ensure Stage 1 temporary
    compilers and the final installed compiler do not accidentally
    retain unrelated distro branding.
-   **Regression test:** After rebuilding GCC, verify `gcc --version`
    and `g++ --version` no longer display `Linux From Scratch` and that
    the selected BFSOS/upstream branding is consistent across the final
    installed compiler.

### Bootstrap archive safety / Stage 5 failure handling

-   [x] **IMPLEMENTED in bootstrap r45:** Stage 5 base-rootfs archive
    creation now runs with root privileges so protected files in the
    verified rootfs can be read instead of producing permission-denied
    tar errors.
-   [x] Stage 5 explicitly unmounts and verifies the bootstrap
    bind/virtual mounts are gone before creating the archive, including
    the external sources/packages/build-work mounts.
-   [x] Archive creation now checks the actual `tar` exit status. If
    compression fails, the partial archive is deleted and Stage 5
    returns failure instead of printing a false success message.
-   [x] The completed base archive is immediately tested with `tar -tJf`
    and sanity-checked for required BFSOS files (`/usr/bin/bash`,
    `/usr/bin/pkgmk`, `/etc/os-release`).
-   [x] When Stage 5 is entered through sudo from the interactive menu,
    ownership of the finished archive is returned to the invoking user.
-   [ ] **Regression test:** Re-run Stage 5 and verify no
    `Permission denied` messages occur, the archive passes validation,
    and an intentionally forced tar failure is reported as failure with
    no partial archive retained.

### Bootstrap toolchain archive safety

-   [x] **IMPLEMENTED in bootstrap r45:** Toolchain archive compression
    no longer dumps the complete verbose tar member list to the
    interactive terminal.
-   [x] Toolchain archive creation explicitly checks the compression
    exit status and deletes a partial archive on failure.
-   [x] The archive is verified with `tar -tJf` and sanity-checked for
    the compiler, linker, and `pkgmk` before Stage 1 reports archive
    success.
-   [ ] **Regression test:** On the next clean Stage 1 run, verify
    concise compression output, successful integrity/payload checks, and
    correct failure handling if archive creation is deliberately
    interrupted.

### Bootstrap Stage 5 success-screen cleanup

-   [x] **IMPLEMENTED in bootstrap r45:** After a successful Stage 5
    base archive operation, return directly to the Bootstrap main menu
    instead of showing `Operation completed successfully.` /
    `Press Enter to return to the menu...`.
-   Real Stage 5 failures still report their nonzero status and retain
    the pause so the error can be read.

### Bootstrap Stage 3 success-screen cleanup

-   [x] **IMPLEMENTED in bootstrap r45:** After a successful Stage 3
    rebuild, return directly to the Bootstrap main menu instead of
    showing the redundant success/pause screen.
-   Stage 2 uses the same direct-return behavior after success.

### Bootstrap time synchronization audit

-   [x] **IMPLEMENTED in bootstrap r45:** Root stages launched from the
    interactive Bootstrap menu no longer re-run the startup time
    synchronization when `sudo` re-enters `bootstrap.sh`.
-   A top-level invocation still performs the normal startup
    synchronization; child stage invocations receive
    `BFS_SKIP_TIME_SYNC=yes`.
-   This removes the observed duplicate sync before Stage 3 and Stage 4
    while preserving clock synchronization when bootstrap is initially
    launched.
-   [ ] **Regression test:** Run Stages 1-5 through the interactive menu
    and confirm only the initial bootstrap startup performs time
    synchronization.

### Bootstrap Stage 3 `build-work` mount cleanup --- implementation update

-   [x] **IMPLEMENTED in bootstrap r45:** The installed/final `pkgmk`
    work directory is now `/var/cache/pkg/build-work/pkgmk-$name`, a
    removable child directory beneath the bind mount, rather than the
    bind-mount root `/var/cache/pkg/build-work`.
-   This prevents pkgmk cleanup from attempting to remove the active
    mount point and producing `Device or resource busy`.
-   [x] The bootstrap unmount helper now returns a real error if a busy
    bootstrap mount cannot be unmounted instead of repeatedly retrying
    forever.
-   [ ] **Regression test:** Run Stage 3 and confirm no
    `rm: cannot remove '/var/cache/pkg/build-work': Device or resource busy`
    warning appears and all bootstrap mounts are gone afterward.

### Bootstrap Stage 3 `build-work` mount cleanup

-   [x] **FIX IMPLEMENTED in bootstrap r45; regression test pending:**
    During Stage 3, `pkgmk` emitted
    `rm: cannot remove '/var/cache/pkg/build-work': Device or resource busy`,
    but the package build continued.
-   Investigation confirmed `/tmp/lfs-rootfs/var/cache/pkg/build-work`
    is an active overlay-backed mount sourced from the live
    environment/project `build-work` path.
-   This is separate from the locale fixes and was not caused by
    changing `LC_ALL`/`LANG`.
-   Do not unmount the work directory while a package is actively
    building.
-   Review the bootstrap Stage 3 mount/setup and cleanup logic after the
    current build completes.
-   If the `build-work` mount is intentional, cleanup must remove/clean
    the contents safely without attempting to `rm` the active mount
    point itself.
-   Ensure cleanup unmounts the work directory at the appropriate
    end-of-stage/exit path before attempting to remove the mount-point
    directory.
-   Verify normal completion, failure, interruption, and rerun paths do
    not leave stale `build-work` mounts behind.
-   [ ] **Regression test:** On the next clean Stage 3 run, confirm
    there are no `Device or resource busy` cleanup messages and no stale
    `build-work` mount remains after Stage 3 exits.

### Bootstrap locale warning root cause and fixes

-   [x] **COMPLETED / ROOT CAUSE IDENTIFIED:** Repeated Stage 3 locale
    warnings were traced to explicit UTF-8 locale overrides rather than
    random bootstrap behavior.
-   Upstream `pkgutils 5.40.12` sets `LC_ALL=C.UTF-8` in `pkgmk.in`
    (`pkgmk`), which is unsafe during early BFSOS bootstrap phases
    because `C.UTF-8` is not guaranteed to exist yet.
-   The running temporary-toolchain copy of `pkgmk` was corrected from
    `LC_ALL=C.UTF-8` to `LC_ALL=C`.
-   The BFSOS `ports/core/pkgutils/Pkgfile` was updated so
    `bootstrap_build()` patches upstream `pkgmk.in` to use `LC_ALL=C`
    before installing the temporary-toolchain copy.
-   The same pkgutils port also patches the packaged `/usr/bin/pkgmk` in
    `post_build()` so the installed BFSOS pkgutils package consistently
    uses the universally available `C` locale.
-   The GCC port was also found to force `LANG=en_US.UTF-8`;
    `ports/core/gcc/Pkgfile` was changed to use `LANG=C` for
    bootstrap/build consistency.
-   Keep the global bootstrap environment on `LANG=C`, `LC_ALL=C`, and
    `LANGUAGE=C`.
-   [ ] **Verification pending on next clean bootstrap/RC run:** confirm
    Stage 1/2/3 no longer produce the previous flood of
    `setlocale: LC_ALL: cannot change locale (C.UTF-8)` warnings.
-   If isolated locale warnings remain after a clean rebuild, capture
    the exact package/log and investigate only that package rather than
    changing the global locale policy again.
-   These locale fixes should be pushed to both the main BFSOS project
    and the separate ports repository so the bootstrap and port trees
    remain consistent.

### Bootstrap Stage 3 locale regression check

-   [ ] During the next clean Stage 3 rebuild, verify that `pkgmk`, GCC,
    and shell subprocesses inherit plain `C` and that no build-generated
    environment reintroduces `C.UTF-8` or `en_US.UTF-8`.
-   Check the newly installed temporary-toolchain `pkgmk` with
    `grep -nE 'LC_ALL|LANG' .../pkgmk` as a regression check after
    pkgutils is rebuilt.

### Bootstrap Stage 3 time synchronization

-   [x] **FIX IMPLEMENTED in bootstrap r45; regression test pending:**
    Remove the redundant time synchronization step from Bootstrap Stage
    3.  
-   Time is already synchronized when `bootstrap.sh` is initially
    launched, so Stage 3 should not perform another automatic time sync
    before rebuilding the base system with the final toolchain.
-   Preserve the initial bootstrap startup time synchronization; this
    change applies specifically to the extra Stage 3 sync.

### Pre-1.0 optional software and console usability checks

-   [x] **IMPLEMENTED in current installer/ports tree; runtime
    regression pending:** GPM is available as an optional package
    (`ports/opt/gpm`) and the installed-system configuration enables
    `gpm.service` when selected.

-   Check whether a `gpm` port already exists in the BFSOS ports tree.
    If it does not, create and validate a proper GPM port.

-   Add **GPM console mouse support** to the installer Optional Software
    menu.

-   If selected, install GPM and enable/configure the appropriate
    systemd service so console mouse selection/paste works on a real
    text console.

-   Verify that leaving GPM unselected does not alter the default
    install.

-   [ ] **Bare-metal verification of installer console text-size options
    before BFSOS 1.0.**

-   Verify all existing console font/text-size choices on a real Linux
    virtual console, not only through QEMU/SPICE or SSH.

-   Confirm that selecting each size changes the installer console
    immediately and that returning to **Default** restores the expected
    normal size.

-   Verify the selected persistent font is written correctly to
    `/etc/vconsole.conf`.

-   After first boot, verify `systemd-vconsole-setup` applies the
    selected font correctly.

-   Confirm the requested font files actually exist in the base system
    and that any fallback behavior is sensible and visible rather than
    silently masking a missing font.

-   Treat broken/nonfunctional text-size selection as a pre-1.0
    installer usability bug.

### Bootstrap Stage 2 completion return behavior

-   [x] **FIX IMPLEMENTED in bootstrap r45; regression test pending:**
    Remove the extra terminal completion/pause screen shown after
    Bootstrap Stage 2 completes successfully.
-   Current behavior displays:
    -   `Operation completed successfully.`
    -   `Press Enter to return to the menu...`
-   After a successful Stage 2 completion, return directly to the
    **Bootstrap main menu** instead of requiring an extra Enter
    keypress.
-   Keep actual Stage 2 success/failure status visible in the Bootstrap
    menu itself.
-   Do not remove or suppress real error dialogs/messages; this change
    applies only to the redundant success/pause screen after a
    successful Stage 2 run.

### BFSOS 1.0 public-release documentation and post-1.0 installer UX roadmap

-   [ ] **1.0 release/public launch preparation:** After the 1.0
    release-candidate storage/RAID/configuration validation is complete
    and no release-blocking core issues remain, clean up and rewrite the
    public `README.md` and supporting documentation for the BFSOS 1.0
    release.
-   The 1.0 README/docs should clearly explain what BFSOS is, current
    release/stability status, supported architecture, supported
    installation/storage configurations, build/install workflow, known
    limitations, where logs are stored, and how users should report
    useful bugs/issues.
-   Clearly distinguish the **core BFSOS system** from the broader
    **non-core ports collection**, which will continue to receive
    cleanup and tooling work after core 1.0 validation.
-   After BFSOS 1.0 final is published with polished documentation and
    usable release/install artifacts, consider/prepare a **DistroWatch
    submission** to bring additional testers and users to the project.
-   Wider public exposure is intended to provide more real-world
    hardware/configuration coverage and additional bug reports, but
    should follow---not precede---the 1.0 RC validation cycle.

#### Post-1.0 / target 1.1 timezone and locale selector improvements

-   [ ] **Post-1.0 enhancement (target 1.1):** Replace or enhance the
    current timezone prompt with a Dialog-driven hierarchical/scrollable
    selector.
-   Timezone selection should allow the user to choose a region first
    (for example `America`, `Europe`, `Asia`) and then move
    through/select the appropriate city/location from a list.
-   Provide consistent **Back**, **Select/Continue**, keyboard
    navigation, and text-mode fallback behavior matching the rest of the
    installer.
-   [ ] **Post-1.0 enhancement (target 1.1):** Replace or enhance locale
    selection with a scrollable Dialog checklist/radiolist based on
    available locales.
-   Keep `en_US.UTF-8` as the normal/default user locale unless the user
    chooses another locale.
-   Allow additional locales to be selected/generated when desired,
    while allowing the system default `LANG` to be chosen separately.
-   **The `C` locale must always remain available and must not be
    removable/disableable by the locale-selection UI.**
-   Preserve use of the `C` locale for bootstrap/build operations where
    deterministic output or operation before the full locale environment
    exists is desirable.
-   These timezone/locale UI improvements are **not BFSOS 1.0 release
    blockers** unless the existing selectors prove functionally broken
    during RC testing. Avoid adding unnecessary installer feature risk
    immediately before 1.0 final.
-   These are installer usability improvements suitable for the **1.x
    series (preferably 1.1)** rather than requiring a 2.0 release.

#### Post-1.0 ZFS support roadmap

-   [ ] **Post-1.0 enhancement:** Add OpenZFS/ZFS support to BFSOS after
    the 1.0 release rather than expanding the pre-1.0 storage regression
    matrix.
-   Start with **ZFS for non-root/data storage**: package the OpenZFS
    userland and kernel module cleanly, verify pool create/import/export
    and boot-time import, and integrate the required module/initramfs
    handling.
-   Validate OpenZFS compatibility against BFSOS-supported kernels,
    including the planned Linux 6.18 LTS line, and define a maintainable
    policy for kernel/OpenZFS version compatibility before enabling it
    by default.
-   Keep existing MD/Linear/JBOD, LUKS, LVM, Btrfs, F2FS, ext\*, and XFS
    behavior unchanged while ZFS support is introduced.
-   Treat **root-on-ZFS as a later phase** after non-root ZFS support is
    stable; root-on-ZFS requires dedicated installer, initramfs,
    bootloader, pool-import, rollback/recovery, and upgrade regression
    testing.
-   Document OpenZFS licensing/distribution considerations and any
    external-module rebuild requirements so kernel upgrades cannot
    silently leave a ZFS installation unbootable or without its pools.
-   This is **not a BFSOS 1.0 release blocker**.

### BFSOS 1.0-rc1 release-candidate milestone

-   [ ] **POTENTIAL 1.0-rc1 CANDIDATE:** If the current bare-metal
    bootstrap/install completes successfully and the resulting BFSOS
    system boots correctly without a new release-blocking core issue,
    treat this build line as the first **BFSOS 1.0-rc1** candidate.
-   The immediate release-candidate priority is validation of the **core
    operating system, bootstrap, installer, boot path, storage layouts,
    RAID combinations, encryption/LVM/Btrfs configurations, and other
    supported installation scenarios**.
-   Over the next several days, test the remaining
    RAID/storage/configuration combinations and correct any
    core/bootstrap/installer/boot regressions discovered during those
    tests.
-   A failure of the current installation to boot is considered a
    **release-candidate blocker** and must be fixed and retested before
    promoting the build to 1.0-rc1 status.
-   Minor/non-blocking tracker cleanup can continue through the 1.0
    release-candidate cycle while the supported installation
    configurations are validated.
-   **Non-core ports are not a 1.0-rc1/core release blocker at this
    stage.** The broader non-core ports tree is known to need
    substantial cleanup and should be handled after the 1.0 RCs have
    established that the core OS and supported installation/storage
    configurations are reliable.
-   After the RAID/configuration matrix is verified through the 1.0 RC
    cycle and no release-blocking core issues remain, target the final
    **BFSOS 1.0** release.
-   Following core 1.0 validation, shift development emphasis toward
    repairing/maintaining the non-core ports collection and developing
    better **ports management, validation, update, and maintenance
    tooling**.

### Bootstrap time synchronization behavior

-   [x] **COMPLETED / VERIFIED:** Synchronize system time once when
    `bootstrap.sh` starts.
-   Do **not** redundantly synchronize time again before Bootstrap Stage
    2 when continuing in the same running bootstrap session.
-   If the machine is rebooted or a new bootstrap session is started,
    launching `bootstrap.sh` performs the startup time synchronization
    again.
-   This keeps Stage 2 from doing unnecessary duplicate time-sync work
    while still ensuring a fresh bootstrap session begins with a
    corrected clock.

### Bootstrap Stage 1 toolchain archive compression output

-   [x] **FIX IMPLEMENTED in bootstrap r45; regression test pending:**
    After Bootstrap Stage 1 verification succeeds, hide/suppress the
    verbose toolchain archive compression output during normal
    interactive use.
-   The user does not need to watch the full compression file/progress
    stream after verification has already completed successfully.
-   Show a concise status such as **Compressing toolchain archive...**
    while the archive is being created, then report the completed
    archive path/size or a clear error if compression fails.
-   Preserve detailed compression output in the appropriate bootstrap
    log for troubleshooting rather than filling the interactive
    terminal/menu.

### Bootstrap Stage 1 download-failure recovery regression

-   [x] **FAILURE CAPTURE HARDENED in r74 code; intentional
    failed-download regression pending:** Stage 1 now invokes `pkgmk` in
    an explicit conditional status path so its nonzero result can return
    to the existing Bootstrap failure-dialog/menu boundary instead of
    being treated as an uncaught shell failure.
-   **Observed behavior:** A Stage 1 source download failed after three
    attempts; when the final download attempt failed, the Bootstrap UI
    closed and returned the user to the shell.
-   **Required behavior:** Catch the Stage 1 `pkgmk` nonzero status at
    the parent/menu boundary. When Dialog mode is available, display the
    standard failure dialog with the package/operation, failed URL when
    detectable, exit status, and preserved log path.
-   **Navigation requirement:** Selecting **Continue** must return
    directly to the Bootstrap main menu without terminating
    `bootstrap.sh`.
-   **State preservation:** Preserve all successfully completed Stage 1
    package markers/toolchain state so the user can repair the
    source/port and resume Stage 1 without rebuilding completed
    packages.
-   **Audit target:** Check the Stage 1 parent call chain for `set -e`
    or other uncaught nonzero-status propagation that bypasses the
    existing failure-handler code.
-   **Regression test:** Intentionally use an invalid Stage 1 source
    URL, allow all configured download retries to fail, verify the
    failure Dialog appears, select Continue, verify the Bootstrap main
    menu remains alive, repair the URL, and confirm Stage 1 resumes from
    the failed/incomplete package.

### Download/package failure messaging in bootstrap and installer

-   [x] **IMPLEMENTATION UPDATED in Bootstrap + installer r46;
    regression tests still required:** download/package operations now
    use explicit status capture at the critical Stage 1 and
    installed-system package boundaries, preserve failure context, and
    return through their parent UI/retry paths.
-   **Observed bootstrap failure:** MPC source download returned HTTP
    404 and `pkgmk` exited with status 4. Bootstrap Stage 1 terminated
    without a clear menu-level explanation, while Bootstrap Stage 2
    later displayed the raw error text but still did not use the normal
    dialog/menu workflow.
-   **Bootstrap requirement:** Catch source/download/build failures and
    show a **dialog error box** when Dialog mode is available. The
    dialog should identify the package or operation, show the failed URL
    when known, summarize the underlying downloader/build error, include
    the exit status, and show the preserved package log path.
-   **Bootstrap navigation:** The failure dialog should have a
    **Continue** button. Selecting Continue must return the user
    directly to the **Bootstrap main menu** without exiting
    `bootstrap.sh`.
-   **Installer review:** The installer currently invokes `ports -u`,
    `prt-get sysup`, and `prt-get depinst` directly inside a
    strict-error shell path. A download/build failure from those
    commands can therefore abort the installation path without
    installer-specific UI/context unless explicitly caught.
-   **Installer requirement:** Catch ports synchronization, mandatory
    upgrade, and optional package-install failures and show a **dialog
    error box** with the failed operation/package when known, failed URL
    when available, useful underlying output, exit status, and installer
    log path. Preserve the installer log before cleanup.
-   **Installer navigation:** The failure dialog should have a
    **Continue** button. Selecting Continue must return the user to the
    **installer main menu/configuration screen**, not terminate the
    installer or dump directly to the shell.
-   **Text-mode fallback:** If Dialog is unavailable, print the same
    failure details in text mode, prompt **Press Enter to continue**,
    then return to the respective main menu.
-   **Do not hide the real error:** The dialog should summarize the
    failure, but the full raw downloader/build output must remain in the
    corresponding log for troubleshooting.
-   **Regression tests:** Deliberately use a bad source URL once in
    Bootstrap Stage 1, once in Bootstrap Stage 2, and once during
    installer package installation. In all cases verify the error is
    shown in the appropriate dialog/text fallback, the log path is
    visible, and Continue returns to the correct main menu without
    terminating the parent workflow.

### pkgmk source URL fallback / backup mirrors

-   \[\~\] **PARTIAL IMPLEMENTATION UPDATED (2026-08-18):** The 29 core
    GNU Pkgfiles use canonical `https://ftp.gnu.org/gnu/...` paths.
    pkgutils release 11 now removes the noisy third-party flat mirror
    and hardens resumable/retry behavior for direct sources.
    Path-preserving automatic GNU host fallback (`ftp.gnu.org/gnu` -\>
    `mirrors.kernel.org/gnu`) is still pending because CRUX
    `PKGMK_SOURCE_MIRRORS` is intentionally flat.
-   **r74 remaining work:** The current pkgmk mirror mechanism is
    filename/flat-cache based; the requested `mirrors.kernel.org/gnu`
    alternate host requires path-preserving URL substitution. Do not
    claim full completion merely by adding unused variables to
    `pkgmk.conf`.
-   **Goal:** A slow, unreachable, or failed primary source must not
    force the user to wait through repeated retries when a known-good
    alternate source exists.
-   **GNU source policy:** For GNU-hosted distfiles, preserve the
    original package path and support ordered alternate hosts. Current
    candidates tested successfully with `autoconf-2.73.tar.xz` are
    `https://ftp.gnu.org/gnu/` and `https://mirrors.kernel.org/gnu/`.
    Avoid relying on `ftpmirror.gnu.org` as the only source because its
    redirect/mirror selection can stall for a long time at 0 bytes.
-   **Path-aware fallback required:** GNU mirrors are hierarchical, not
    flat distfile caches. The fallback implementation must preserve
    paths such as `autoconf/autoconf-$version.tar.xz`,
    `glibc/glibc-$version.tar.xz`, and
    `gcc/gcc-$version/gcc-$version.tar.xz` rather than simply appending
    the filename to a mirror root.
-   **Centralized behavior:** Prefer implementing host/path substitution
    or equivalent fallback handling in BFSOS `pkgmk`/its extension so
    individual Pkgfiles do not need duplicate source URLs solely for
    mirror redundancy.
-   **Configuration consistency:** Any generated bootstrap `pkgmk.conf`
    must inherit the same ordered backup-source policy as the final
    packaged/default configuration so Stage 1, Stage 2, Stage 3,
    installer package operations, and the installed system behave
    consistently.
-   **Do not restore the removed FreeBSD distcache fallback:** The
    previous `distcache.FreeBSD.org/ports-distfiles/` fallback was
    removed after producing incorrect/unreliable behavior and must not
    be reintroduced.
-   **Retry interaction:** Keep per-URL connection/retry limits short
    enough that `pkgmk` can advance to the next alternate source
    promptly rather than spending minutes retrying one dead or stalled
    endpoint.
-   **Integrity:** Existing source checksum/signature verification
    remains authoritative regardless of which alternate URL supplied the
    distfile.
-   **Regression test:** Deliberately make the primary GNU source
    unreachable; verify `pkgmk` advances to the next configured URL
    automatically, downloads the identical distfile, passes the normal
    integrity checks, and completes the package build. Repeat in Stage 1
    and in the installed/final `pkgmk` environment.

### Bootstrap Stage 3 availability status

-   [x] **COMPLETED / VERIFIED:** Correct Stage 3
    (`Rebuild base system with final toolchain`) status logic.
-   Stage 3 now shows **\[PENDING\]** until the required
    temporary-toolchain/base-system prerequisite stages are complete.
-   After Stage 2 is complete, Stage 3 changes to **\[AVAILABLE\]**.
-   After Stage 3 itself is completed, it shows **\[COMPLETE\]**.
-   Corrected in both the dialog and text-fallback bootstrap menus.
-   Verified during testing on August 11, 2026: the corrected behavior
    now appears as intended.

**Installer:** `install-bfs-menu-v50-luks-auto-cryptsetup.sh`\
**Test focus:** RAID + LUKS + LVM\
**Status:** Active testing

## Issues Found

### 1. RAID selection summary is plain text instead of Dialog

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
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

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
-   **Area:** RAID creation / post-create status
-   **Current behavior:** After `mdadm` starts the array, the installer
    drops to plain terminal output showing `/proc/mdstat`, recovery
    percentage, estimated completion time, and
    `Press Enter to continue...`.
-   **Observed example:**

``` text
mdadm: array /dev/md0 started.

Personalities : [raid4] [raid5] [raid6]
md0 : active raid5 ...
      [>....................]  recovery = 0.0% ...
      bitmap: 2/2 pages [8KB], 65536KB chunk

Press Enter to continue...
```

-   **Desired behavior:** Keep the user in Dialog. Show array creation
    success and status in a Dialog `--msgbox`; optionally use a Dialog
    `--gauge` if the installer chooses to monitor initial RAID
    recovery/sync progress.
-   **Priority:** UI cleanup
-   **Regression test:** Create RAID5 and verify the post-create status
    never drops back to the terminal UI.

### 5. LUKS device selection is plain text and dumps full `lsblk` output

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
-   **Area:** LUKS creation / encrypted-device selection
-   **Current behavior:** Choosing "Create a new LUKS container" prints
    a full `lsblk -fp` style device tree to the terminal, including loop
    devices, optical media, whole disks, mounted build storage, RAID
    members, and the assembled MD array, then asks
    `Block device to encrypt:` as a raw text prompt.
-   **Observed behavior:** The terminal shows `/dev/loop0`, `/dev/sr0`,
    `/dev/vda*`, `/dev/vdb1`-`/dev/vdf1`, `/dev/md0`, and `/dev/vdg`,
    followed by:

``` text
Block device to encrypt:
```

-   **Desired behavior:** Use a Dialog selection list for LUKS targets.
    Show only sensible encryptable block-device candidates, with device
    path, size, type, and current filesystem/signature. Exclude loop
    devices, optical media, mounted installer/build media, whole disks
    when a child partition is the intended unit, and RAID member
    partitions that are already claimed by an active MD array. The
    assembled `/dev/md0` should be selectable for the RAID -\> LUKS -\>
    LVM test.
-   **Priority:** UI + safety cleanup
-   **Regression test:** Enter the LUKS create flow with an active RAID
    array and verify `/dev/md0` is offered while
    `/dev/vdb1`-`/dev/vdf1`, `/dev/loop0`, `/dev/sr0`, and `/dev/vdg`
    are not offered as accidental targets.

### 6. `cryptsetup luksFormat` destructive confirmation is raw terminal input

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
-   **Area:** LUKS creation / destructive confirmation
-   **Current behavior:** `cryptsetup luksFormat` exposes its native
    terminal warning and requires the user to type the exact
    confirmation text:

``` text
WARNING!
This will overwrite data on /dev/md0 irrevocably.

Are you sure? (Type 'yes' in capital letters):
```

-   **Desired behavior:** The installer should present its own clear
    Dialog `--yesno` destructive-action warning before invoking
    `cryptsetup`. After explicit confirmation, invoke cryptsetup in a
    non-interactive/force-confirmed mode where supported so its native
    typed confirmation does not break the Dialog workflow.
    Password/passphrase entry should remain secure and must not be
    exposed on the command line.
-   **Priority:** UI + safety cleanup
-   **Regression test:** Create a LUKS container and verify the
    destructive confirmation occurs entirely through Dialog, Cancel/No
    safely returns without formatting, and no plaintext passphrase
    appears in process arguments or logs.

### 7. LUKS mapping-name prompt is plain text

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
-   **Area:** LUKS creation / opening newly created container
-   **Current behavior:** After creating a LUKS container, the installer
    asks `Mapping name to open now [leave blank to skip]:` using a raw
    terminal prompt.
-   **Desired behavior:** Use a Dialog `--inputbox`, with clear guidance
    that this creates `/dev/mapper/<name>`, plus a Cancel/Skip path.
    Consider suggesting a sensible default based on intended use (for
    example `cryptroot` for `/` and `cryptraid` for an encrypted RAID
    device).
-   **Priority:** UI cleanup
-   **Regression test:** Create LUKS on a partition and on an MD array;
    verify mapping-name entry, skip, and cancel all remain in Dialog and
    produce the expected mapper device.

### 8. LUKS mapping name should be required

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
-   **Area:** LUKS creation / mapper naming
-   **Current behavior:** The mapping-name prompt allows a blank value
    to skip opening the newly created LUKS container.
-   **Desired behavior:** Require a valid mapping name when creating a
    LUKS container through the installer. Do not allow an empty name.
    Re-prompt on blank or invalid input and explain that the resulting
    device will be `/dev/mapper/<name>`. Provide sensible suggested
    defaults such as `cryptroot` for an encrypted root partition and
    `cryptraid` for an encrypted RAID device.
-   **Validation:** Reject whitespace, `/`, and names that would
    conflict with an existing `/dev/mapper` mapping. Keep an explicit
    Cancel/Back action separate from an empty mapping name.
-   **Priority:** Workflow + UI cleanup
-   **Regression test:** Verify blank and invalid names are rejected,
    existing mapper names cannot be reused accidentally, and a valid
    name opens the LUKS device successfully.

### 9. LUKS passphrase entry and post-open pause drop to plain terminal UI

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
-   **Area:** LUKS creation/opening / passphrase and completion
-   **Current behavior:** The LUKS passphrase is requested using the raw
    `cryptsetup` terminal prompt, and after the operation the installer
    uses a plain `Press Enter to continue...` pause.
-   **Desired behavior:** Keep the workflow in Dialog. Use a secure
    Dialog password box for passphrase entry and confirmation, then feed
    the passphrase to `cryptsetup` without exposing it in command-line
    arguments, logs, shell tracing, or temporary plaintext files.
    Replace the terminal `Press Enter to continue...` with a Dialog
    success/status message.
-   **Safety:** Never echo the passphrase. Ensure installer
    logging/xtrace cannot capture it. Clear shell variables containing
    the passphrase as soon as practical.
-   **Priority:** UI + security cleanup
-   **Regression test:** Create and open LUKS successfully from Dialog;
    verify passphrase is hidden, confirmation mismatch is handled
    cleanly, no passphrase appears in logs/process arguments, and
    completion returns through Dialog.

### 10. Newly created LUKS containers are not remaining open

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
-   **Area:** LUKS creation / mapper activation
-   **Current behavior:** After creating LUKS containers, `lsblk`
    correctly shows `crypto_LUKS` on `/dev/vda4` and `/dev/md0`, but the
    expected mapper devices are inactive (`cryptsetup status cryptraid`
    and `cryptsetup status luksroot` report inactive).
-   **Desired behavior:** When the installer requires a mapping name
    during LUKS creation, successfully open the new container
    immediately and verify `/dev/mapper/<name>` exists before returning
    to the storage menu. If opening fails, show a Dialog error and
    remain in the LUKS workflow rather than silently continuing.
-   **Validation:** After `cryptsetup open`, verify
    `cryptsetup status <name>` is active and
    `test -b /dev/mapper/<name>` succeeds.
-   **Priority:** Functional LUKS workflow bug
-   **Regression test:** Create LUKS on a normal partition and on an MD
    array; both mappings must remain active and be selectable by the
    filesystem/LVM setup screens until installer cleanup or an explicit
    Close action.

### 11. LVM physical-volume selection should be a Dialog device selector

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
-   **Area:** LVM setup / physical-volume creation
-   **Current behavior:** The installer asks the user to type a
    block-device path manually when creating an LVM physical volume.
-   **Desired behavior:** Present eligible devices in a Dialog
    menu/checklist navigable with Up/Down and selectable with
    Space/Enter as appropriate. Show useful metadata such as device
    path, size, type, and current filesystem/signature.
-   **Filtering/safety:** Include valid devices and active mapper
    devices such as `/dev/mapper/cryptraid`; exclude loop/optical
    devices, mounted installer media, active RAID member partitions, and
    devices already consumed by another storage layer unless explicitly
    appropriate.
-   **Selection model:** Support selecting one or more PV devices if the
    installer supports multi-PV volume groups. Provide Back/Cancel
    without terminating the installer.
-   **Priority:** UI + safety cleanup
-   **Regression test:** With RAID -\> LUKS active, verify
    `/dev/mapper/cryptraid` appears as an eligible PV and can be
    selected entirely through Dialog without manually typing its path.

### 12. LVM operation success messages use plain `Press Enter to continue...`

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
-   **Area:** LVM setup / post-operation feedback
-   **Current behavior:** After successful LVM operations, such as
    creating logical volume `var`, the installer drops to terminal text:

``` text
Logical volume "var" created.

Press Enter to continue...
```

-   **Desired behavior:** Replace terminal pauses after successful
    PV/VG/LV operations with Dialog `--msgbox` success messages and
    return directly to the appropriate LVM Dialog menu.
-   **Priority:** UI cleanup
-   **Regression test:** Create PVs, a VG, and multiple LVs and verify
    every success/failure result remains in Dialog with no raw
    `Press Enter to continue...` screens.

### 13. LVM status/summary output is plain terminal text

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
-   **Area:** LVM setup / status summary
-   **Current behavior:** The installer prints raw `pvs`, `vgs`, and
    `lvs` output to the terminal, followed by
    `Press Enter to continue...`.
-   **Observed example:** PV `/dev/mapper/cryptraid`, VG `bfs-vg`, and
    LVs `home` and `var` are shown using the native LVM table output.
-   **Desired behavior:** Render a concise LVM summary inside Dialog,
    ideally using a `--textbox`, `--msgbox`, or formatted
    menu/table-style screen. Show PV, VG, LV names, sizes, and free
    space while keeping the user inside the Dialog workflow.
-   **Priority:** UI cleanup
-   **Regression test:** Open the LVM status/review screen after
    creating PV/VG/LVs and verify no raw terminal table or
    `Press Enter to continue...` prompt appears.

### 14. Filesystem selector should hide LUKS backing devices when their decrypted layer is in use

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
-   **Area:** Filesystem device selection / storage-layer filtering
-   **Current behavior:** The filesystem selector still offers
    `/dev/md0` and `/dev/vda4` even though both contain active LUKS
    containers. Selecting or formatting either backing device would
    overwrite the encryption layer.
-   **Desired behavior:** When a block device has a LUKS container and
    its decrypted mapper is active or consumed by another storage layer,
    hide the encrypted backing device from normal
    filesystem-format/mount selection. Show only the usable top-level
    devices, such as `/dev/mapper/luksroot` and LVs built on
    `/dev/mapper/cryptraid`.
-   **Safety:** Do not allow accidental filesystem formatting of an
    active LUKS backing device. If an advanced workflow ever exposes it,
    mark it clearly as `LUKS backing device — do not format` and require
    an explicit destructive override.
-   **Priority:** Safety + UI cleanup
-   **Regression test:** With LUKS on `/dev/vda4` and `/dev/md0`, verify
    neither backing device appears as a normal filesystem target while
    their decrypted/derived devices are active.

### 15. Remove plain `Press Enter to continue...` after filesystem selection

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
-   **Area:** Filesystem selection / transition to next installer stage
-   **Current behavior:** After all filesystem targets and mount points
    have been selected, the installer drops to a raw
    `Press Enter to continue...` prompt.
-   **Desired behavior:** Prefer no extra pause at all: once filesystem
    selection is complete and validated, proceed directly to the next
    installer stage. If user confirmation is needed before
    formatting/mounting, use a Dialog summary/confirmation screen
    instead of a terminal pause.
-   **Priority:** UI/workflow cleanup
-   **Regression test:** Complete filesystem assignments and verify the
    installer either advances directly or displays a meaningful Dialog
    confirmation; no raw Enter prompt should appear.

### 16. Remove plain pause after base archive stage

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
-   **Area:** Base archive / transition to next installer stage
-   **Current behavior:** After the base archive operation completes,
    the installer stops at a raw `Press Enter to continue...` prompt.
-   **Desired behavior:** On successful completion, continue
    automatically to the next installer stage. Do not add a Dialog
    message merely to replace an unnecessary terminal pause. Use Dialog
    only when there is meaningful information, a warning, an error, or a
    decision the user needs to make.
-   **Priority:** UI/workflow cleanup
-   **Regression test:** Complete the base archive stage successfully
    and verify the installer advances automatically with no raw Enter
    prompt or redundant OK dialog.

### 17. Installation summary incorrectly reports no encrypted devices

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
-   **Area:** Final installation review / LUKS summary
-   **Current behavior:** The BFS Installation summary reports
    `LUKS Encryption: Enabled YES` but `Encrypted devices: no`, even
    though this test has LUKS containers on `/dev/vda4` (opened as
    `/dev/mapper/luksroot`) and `/dev/md0` (opened as
    `/dev/mapper/cryptraid`, then used by LVM).
-   **Desired behavior:** Detect and list the actual encrypted backing
    devices and mapper names in the final review, including LUKS devices
    that are underneath LVM/RAID layers.
-   **Expected example:** `/dev/vda4 -> luksroot` and
    `/dev/md0 -> cryptraid`.
-   **Priority:** Functional review/reporting bug
-   **Regression test:** Build RAID5 -\> LUKS -\> LVM plus a separate
    LUKS root and verify the final review reports both encrypted devices
    and their mappings rather than `no`. \### 18. Remove raw
    `Press Enter to continue...` before BFS Installation summary
-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
-   **Area:** Transition into final installation review
-   **Current behavior:** A raw terminal `Press Enter to continue...`
    appears before the BFS Installation summary.
-   **Desired behavior:** Continue directly into the Dialog review
    screen unless an actual user decision is required.
-   **Priority:** UI/workflow cleanup

### 19. Fatal crypttab generation failure with existing/reopened LUKS mappings

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
-   **Area:** LUKS detection / `/etc/crypttab` generation
-   **Current behavior:** The installer correctly detects that encrypted
    storage is present, but `generate_crypttab()` produces zero records
    and aborts with:

``` text
ERROR: Encrypted storage was detected, but no crypttab entries could be generated.
```

-   **Test topology:** `/dev/vda4 -> luksroot -> /` and
    `/dev/md0 -> cryptraid -> LVM -> home/var`.
-   **Likely failure point to verify:** `crypt_mapping_records()`
    discovers `crypt` nodes through `lsblk`, then relies on
    `lsblk ... PKNAME` to derive the encrypted backing device.
    Existing/reopened device-mapper stacks may not be represented the
    way this code expects.
-   **Desired behavior:** Discover active LUKS mappings from the actual
    block-device topology regardless of whether they were created in the
    current installer process or opened before restarting the installer.
    Generate entries for both root and encrypted RAID mappings.
-   **Expected crypttab mappings:** `luksroot` backed by the LUKS UUID
    of `/dev/vda4`; `cryptraid` backed by the LUKS UUID of `/dev/md0`.
-   **Priority:** Critical functional blocker
-   **Regression test:** Restart installer with pre-opened LUKS
    mappings, select filesystems on mapper/LVM descendants, and verify
    `/etc/crypttab` is generated correctly without relying on
    current-session LUKS state.

### 20. Base archive path prompt is not using Dialog

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r2.sh`
-   **Area:** Base archive selection
-   **Current behavior:** The installer asks for the base/rootfs archive
    path using a plain terminal prompt rather than Dialog.
-   **Desired behavior:** Use a Dialog `--inputbox` (or a file/path
    selector if practical) with the detected/default base archive path
    pre-filled, so the user can accept or edit it without leaving the
    Dialog UI.
-   **Priority:** UI cleanup
-   **Regression test:** Reach base archive selection and verify the
    archive path is requested entirely through Dialog with the default
    path visible/editable.

### 21. Final installation review does not show configured RAID arrays

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r4.sh`
-   **r4 correction:** The earlier `/proc/mdstat` parser checked the
    wrong field (`$2 ~ /^raid/`) for lines shaped like
    `md0 : active raid5 ...`, causing `RAID enabled: YES` but an array
    list of `none`. r4 parses the actual MD status line correctly and
    reports the live array.
-   **Area:** Final installation review / RAID summary
-   **Current behavior:** The final review omits the configured software
    RAID array(s), so the storage summary does not show the RAID layer
    even when `/dev/md0` is part of the installation topology.
-   **Desired behavior:** Add a RAID section to the review showing each
    array device, RAID level, member devices, size, and current state.
    For this test topology it should show `/dev/md0`, RAID5, and members
    `/dev/vdb1 /dev/vdc1 /dev/vdd1 /dev/vde1 /dev/vdf1`.
-   **Detection:** Derive the review from actual active MD state
    (`/proc/mdstat`/`mdadm --detail`) rather than only installer-session
    variables, so restarted/resumed installs are reported correctly.
-   **Priority:** Review/reporting correctness
-   **Regression test:** Restart the installer with an existing active
    RAID5 and verify the final review still lists the array, level, and
    members.

### 22. Filesystem and mount-point assignment needs a single multi-entry Dialog workflow

-   [x] Partial workflow fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r2.sh`
-   **Note:** Replaced the repeated `Add another?` prompt with a
    persistent selector and explicit `Done selecting filesystems`
    action. A fuller Add/Edit/Remove planner can still be refined later
    if desired.
-   **Area:** Filesystem selection / mount-point assignment
-   **Current behavior:** The installer configures one filesystem/mount
    point at a time and repeatedly asks whether the user wants to add
    another partition/filesystem.
-   **Desired behavior:** Replace the repeated yes/no loop with a
    persistent Dialog assignment screen. The user should be able to move
    through eligible devices, add/edit/remove assignments, and see the
    complete filesystem plan before selecting `Done`.
-   **Suggested workflow:** Show eligible top-level devices in one menu;
    selecting a device opens its filesystem/format/mount-point options;
    return to the same assignment screen with the configured value
    displayed. Provide `Add/Edit`, `Remove`, `Back`, and `Done` actions
    rather than repeatedly asking `Add another?`.
-   **Safety:** Continue hiding consumed backing devices such as active
    LUKS parents and RAID member partitions. Clearly identify EFI, boot,
    swap, mapper devices, and LVs.
-   **Validation on Done:** Require exactly one `/`, reject duplicate
    mount points, validate EFI/boot choices where applicable, and show a
    final filesystem plan before destructive formatting.
-   **Priority:** Major UI/workflow improvement
-   **Regression test:** Configure `/`, `/boot`, `/boot/efi`, swap,
    `/home`, and `/var` without answering a repeated yes/no prompt after
    each assignment.

### 23. make-ca package conflicts with ca-certificates ownership

-   [x] Fix
-   **Implemented in:** `Pkgfile-make-ca-release4-fixed`
-   **Area:** Package installation / CA trust store
-   **Current behavior:** `make-ca 1.16.1-3` tries to install
    `etc/ssl/certs/ca-certificates.crt`, but that path is already owned
    by the installed `ca-certificates` package, causing `pkgadd` to
    abort.
-   **Confirmed owner:** `ca-certificates` owns
    `etc/ssl/certs/ca-certificates.crt`; current link is
    `/etc/ssl/certs/ca-certificates.crt -> /etc/ssl/cert.pem`.
-   **Desired behavior:** Do not have `make-ca` package own a path
    already owned by `ca-certificates`. Remove the compatibility symlink
    from the make-ca package and ensure the CA trust-store packages
    provide a consistent chain that httpup can use.
-   **Priority:** Critical packaging/install blocker
-   **Regression test:** Fresh install with both ca-certificates and
    make-ca must complete without file-ownership conflicts, and
    `ports -u` must succeed afterward.

### 24. Add intelligent default mount points during filesystem assignment

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r3.sh`
-   **Area:** Filesystem / mount-point assignment
-   **Current behavior:** Mount points must be entered manually even
    when the selected device name or filesystem makes the intended mount
    point obvious.
-   **Desired behavior:** Pre-fill a sensible mount-point suggestion
    while keeping it editable by the user.
-   **Suggested defaults:**
    -   LV named `home` -\> `/home`
    -   LV named `var` -\> `/var`
    -   LV named `root` -\> `/`
    -   dm-crypt mapping named `luksroot` -\> `/`
    -   `ext2` partition -\> `/boot` when `/boot` is not already
        assigned
    -   `vfat`/FAT32 partition -\> `/boot/efi` when `/boot/efi` is not
        already assigned
    -   swap -\> `swap`
-   **Safety:** Defaults are suggestions only. Do not overwrite an
    existing assignment or guess for generic Btrfs/ext4/XFS devices
    without a useful device/LV/mapping name.
-   **Priority:** Filesystem workflow improvement
-   **Regression test:** Selecting `bfs-vg/home`, `bfs-vg/var`,
    `/dev/vda2` ext2, `/dev/vda1` vfat, and `luksroot` should pre-fill
    `/home`, `/var`, `/boot`, `/boot/efi`, and `/` respectively.
    \### 25. Show complete filesystem plan in the final Yes/No
    confirmation
-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r3.sh`
-   **Area:** Filesystem assignment confirmation
-   **Current behavior:** The final confirmation page presents only
    Yes/No, so the user cannot verify what was selected before
    continuing.
-   **Desired behavior:** The confirmation Dialog must display the
    complete pending filesystem plan above the Yes/No choice.
-   **Display for each assignment:** device, filesystem, mount point,
    and whether it will be formatted/reformatted. Include swap
    explicitly.
-   **Example information:** `/dev/mapper/luksroot -> btrfs -> /`,
    `/dev/bfs-vg/home -> btrfs -> /home`,
    `/dev/bfs-vg/var -> btrfs -> /var`, `/dev/vda2 -> ext2 -> /boot`,
    `/dev/vda1 -> vfat -> /boot/efi`, `/dev/vda3 -> swap`.
-   **Behavior:** `Yes` accepts the displayed plan; `No` returns to the
    filesystem assignment screen so selections can be corrected rather
    than discarding the whole workflow.
-   **Priority:** Safety / usability
-   **Regression test:** Configure multiple filesystems and verify the
    final Yes/No Dialog visibly lists every selected device, filesystem,
    mount point, format choice, and swap before the user commits.

### 26. Convert "Show Current Storage Devices" to Dialog and remove Enter pause

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r3.sh`
-   **Area:** Storage menu / current-device display
-   **Current behavior:** `Show Current Storage Devices` dumps storage
    information to the terminal and then uses a raw
    `Press Enter to continue...` pause.
-   **Desired behavior:** Capture the storage-device output and display
    it in a scrollable Dialog window (`--textbox` or equivalent) with
    normal Dialog navigation such as OK/Back.
-   **Required cleanup:** Remove the terminal
    `Press Enter to continue...` prompt entirely. Closing the Dialog
    should return directly to the storage menu.
-   **Priority:** UI consistency
-   **Regression test:** Open `Show Current Storage Devices`; verify no
    raw terminal output or Enter pause appears. \### 27. Preselect git
    and wget in Optional Software
-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r3.sh`
-   **Area:** Optional Software Dialog
-   **Current behavior:** `git` and `wget` are not enabled by default.
-   **Desired behavior:** Show both `git` and `wget` as selected/on by
    default while still allowing the user to deselect either package.
-   **Priority:** Default-package usability
-   **Regression test:** Open Optional Software on a fresh installer run
    and verify both `git` and `wget` are initially checked.

### 28. Add save/load support for complete installer configuration profiles

-   \[\~\] Partial implementation
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r3.sh`
    (profile save/load UI, non-secret core settings, filesystem
    assignments, device validation)
-   **Remaining:** RAID/LUKS/LVM creation is currently imperative in
    v50, so a profile cannot yet safely recreate those layers from
    scratch. Finish this when storage setup is refactored into a
    declarative plan; never store LUKS passphrases.
-   **Area:** Installer configuration / main menu
-   **Goal:** Allow the user to save the current installer selections to
    a reusable configuration file and load a saved configuration on a
    later installer run.
-   **Save:** Store non-secret installer choices including hostname,
    timezone, locale, network configuration, users/user options, storage
    topology selections, RAID configuration, LUKS device/mapping
    choices, LVM configuration, filesystem and mount-point assignments,
    Btrfs/Snapper choices, optional software, base archive choice,
    bootloader/GRUB choices, and normal/fallback EFI installation
    choices.
-   **Load:** Populate installer state from the selected profile so the
    user does not need to answer every installer question again.
-   **Secrets:** Never store user/root passwords, LUKS passphrases,
    private keys, or other authentication secrets in the profile. Prompt
    for those normally when required.
-   **Validation:** Loading a profile must validate devices and other
    machine-specific values against the current system. Missing or
    changed devices must be clearly flagged and returned to the user for
    correction; never blindly perform destructive operations using stale
    device paths.
-   **Review:** A loaded profile must still pass through the normal
    installer review/confirmation screens before destructive actions or
    installation begin.
-   **UI:** Add Dialog options such as `Load configuration`,
    `Save current configuration`, and `Save configuration as...`.
-   **Format:** Use a documented, human-readable configuration format
    that can be inspected and edited manually.
-   **Portability:** Where practical, allow stable identifiers such as
    UUID/PARTUUID/LABEL in addition to `/dev/...` paths so profiles
    survive device-name changes.
-   **Priority:** Major usability / repeat-install feature
-   **Regression test:** Save a complete configuration, restart the
    installer, load it, verify all non-secret choices are restored,
    verify passwords/passphrases are still requested, and verify a
    deliberately missing storage device is detected before any
    destructive operation.

### 29. Returning from final chroot should go directly back to installer menu

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r3.sh`
-   **Area:** Final chroot / installer navigation
-   **Current behavior:** After exiting the BFS chroot, the installer
    prints:

``` text
Returned from the BFS chroot.

Press Enter to continue...
```

-   **Desired behavior:** Remove the terminal pause entirely. After the
    chroot exits successfully, return directly to the installer menu (or
    the appropriate post-install menu) without requiring an extra Enter
    key.
-   **UI:** If a message is desired, show it briefly in Dialog or simply
    return to the menu; do not drop to raw terminal output.
-   **Priority:** UI/workflow cleanup
-   **Regression test:** Enter the final BFS chroot, exit it, and verify
    the installer immediately returns to the menu with no raw
    `Press Enter to continue...` prompt.

### 30. Encrypted storage is not activated automatically at boot

-   [x] Fix

-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r4.sh`

-   **Area:** GRUB / Dracut kernel command line / encrypted-root boot

-   **Severity:** Critical boot blocker

-   **Observed first-boot behavior:** GRUB passed the Btrfs root
    filesystem UUID (`root=UUID=d342daa4-...`) but no `rd.luks.uuid=`
    parameter. Dracut waited for that Btrfs UUID for roughly 200
    seconds, then dropped to the debug shell because
    `/dev/mapper/luksroot` had never been created.

-   **Root LUKS proof:** `/dev/vda4` correctly reports
    `TYPE=crypto_LUKS` with UUID `d202ab19-7873-49cf-b625-53d4f8471d06`.
    Manually running `cryptsetup open /dev/vda4 luksroot` immediately
    exposed the expected Btrfs UUID
    `d342daa4-1c49-4616-bf94-bc6cd2690055`, after which exiting the
    Dracut shell allowed boot to continue.

-   **Encrypted RAID proof:** The installed system then assembled
    `/dev/md0` RAID5 successfully with all 5/5 members, but
    `/dev/mapper/cryptraid` was absent. `/dev/md0` correctly reported
    `TYPE=crypto_LUKS` with UUID `e46a2023-298f-475e-8627-32847f93411b`.
    Manually running `cryptsetup open /dev/md0 cryptraid` followed by
    `vgchange -ay` exposed the `bfs-vg/home` and `bfs-vg/var` LVs and
    allowed boot to complete.

-   **Current GRUB defaults:** `/etc/default/grub` contains only
    `GRUB_CMDLINE_LINUX_DEFAULT="consoleblank=1800"`.

-   **Dracut detection proof:** `dracut --print-cmdline` detects at
    least the encrypted root and recommends
    `rd.luks.uuid=luks-d202ab19-7873-49cf-b625-53d4f8471d06`.

-   **Desired behavior:** During bootloader/initramfs configuration,
    derive required Dracut arguments from the actual selected storage
    topology and add them to the GRUB kernel command line. At minimum
    include every LUKS container needed for the installed filesystem
    tree. For this topology that means the root LUKS UUID and the
    LUKS-on-MD UUID; also ensure the MD/LVM portions required to reach
    encrypted RAID-backed filesystems are not disabled in early boot.

-   **Suggested arguments for this test topology:**
    `rd.luks.uuid=luks-d202ab19-7873-49cf-b625-53d4f8471d06`,
    `rd.luks.uuid=luks-e46a2023-298f-475e-8627-32847f93411b`, plus the
    LVM/MD activation arguments recommended by root-run
    `dracut --print-cmdline` for the active layout.

-   **Installer validation:** Before declaring installation complete,
    compare the generated GRUB command line with
    `dracut --print-cmdline`/the detected storage topology and fail or
    warn if an encrypted root lacks an `rd.luks.uuid=` argument.

-   **Regression test:** Rebuild initramfs and GRUB, cold boot with no
    mappings pre-opened, verify the boot process prompts for required
    LUKS passphrase(s), creates `luksroot` and `cryptraid`
    automatically, assembles `/dev/md0`, activates `bfs-vg`, mounts `/`,
    `/home`, and `/var`, and reaches the normal login without a
    Dracut/emergency-shell intervention.

-   **Confirmed root cause / proof:** Explicit `rd.luks.uuid=` arguments
    fixed automatic encrypted-root activation. `rd.md=1` alone was not
    sufficient to assemble the MD array in early boot. Adding `rd.auto`
    caused `/dev/md0` to assemble automatically with all 5/5 members,
    after which Dracut found the LUKS container on `/dev/md0`, prompted
    for it, activated LVM, and booted normally.

-   **Permanent implementation:** r4 derives storage arguments
    dynamically from `/etc/crypttab`, `/etc/fstab`, live LVM metadata,
    and the detected RAID requirement. It writes storage arguments to
    `GRUB_CMDLINE_LINUX` in `/etc/default/grub` so they persist across
    future kernel upgrades and also apply to recovery entries.
    `consoleblank=1800` remains in `GRUB_CMDLINE_LINUX_DEFAULT`.

-   **Generated arguments:** MD RAID adds `rd.auto rd.md=1`; every
    required crypttab UUID adds `rd.luks.uuid=luks-<UUID>`; every
    selected filesystem backed by an LV adds `rd.lvm.lv=<VG>/<LV>`.

-   **Validation:** After `grub-mkconfig`, r4 verifies that the
    generated Linux entries contain all required RAID/LUKS/LVM arguments
    and also checks recovery entries when present.

### 31. "Assemble existing arrays" aborts clean install when no arrays exist

-   [x] Fix
-   **Implemented in:**
    `install-bfs-menu-v50-tracker-fixed-r6-classic-slackware.sh`
-   **Area:** Software RAID / assemble-existing workflow / error
    handling
-   **Observed behavior:** On a deliberately clean target with all
    previous MD signatures wiped, selecting "Assemble existing arrays"
    runs `mdadm --assemble --scan`. `mdadm` correctly returns non-zero
    with `No arrays found in config file or automatically`, but the
    installer's global ERR trap treats that expected result as fatal and
    aborts near line 1777.
-   **Root cause:** The r5 function attempted to tolerate the command
    with `set +e`, but a bare failing command can still interact with
    the installer's ERR trap. The command must execute in a conditional
    context where failure is explicitly handled.
-   **Desired behavior:** No existing arrays is a normal condition on a
    fresh install. Show a Dialog message explaining that no arrays were
    found and return to the RAID menu so the user can choose
    `Create a new array`.
-   **Fix:** Run `mdadm --assemble --scan` inside an `if` condition,
    capture its status without triggering the fatal ERR path, and
    distinguish "no arrays exist" from a partial/real assembly failure.
-   **Regression test:** Wipe all MD member signatures, enter Software
    RAID -\> Assemble existing arrays, verify the installer shows a
    non-fatal "No existing RAID arrays were found" Dialog and returns to
    the RAID menu.

### 32. LUKS mapper name is lost after prompt

-   [x] Fix
-   **Implemented in:**
    `install-bfs-menu-v50-tracker-fixed-r7-classic-slackware.sh`
-   **Area:** LUKS create/open workflow / Bash variable scoping
-   **Observed behavior:** LUKS2 formatting succeeds, but the installer
    reports
    `The new container was created, but /dev/mapper/ could not be opened.`
    The mapper name is blank, `/dev/md0` contains a valid LUKS2 header,
    and `/dev/mapper/cryptraid` remains inactive.
-   **Root cause:** `ask_mapping_name()` declared a local variable named
    `mapping` while also receiving `mapping` as the caller's
    output-variable name. Because Bash local variables are dynamically
    scoped, `printf -v "$result_variable"` updated the helper's local
    `mapping`, leaving `luks_menu`'s `mapping` empty.
-   **Fix:** Rename the helper-local value to `selected_mapping`, so
    `printf -v "$result_variable"` writes back to the caller's `mapping`
    variable.
-   **Regression test:** Create a LUKS container on `/dev/md0`, accept
    the default mapper name `cryptraid`, verify `/dev/mapper/cryptraid`
    is created and active, then continue into LVM setup.

### 33. Active MD RAID array disappears from LUKS target selector

-   [x] Fix
-   **Implemented in:**
    `install-bfs-menu-v50-tracker-fixed-r8-classic-slackware.sh`
-   **Area:** LUKS target discovery / MD RAID integration
-   **Observed behavior:** After creating `/dev/md0`, the RAID array was
    no longer offered as a target when creating a new LUKS container,
    even though `/proc/mdstat` showed the array active.
-   **Root cause:** LUKS target discovery depended primarily on
    `lsblk TYPE` matching `raid*`. MD device TYPE reporting can vary
    with util-linux/array state, so a valid assembled `/dev/md*` device
    could be omitted.
-   **Fix:** Enumerate active MD arrays directly from `/proc/mdstat`
    first, add them explicitly to the LUKS candidate list, deduplicate
    them against the later `lsblk` scan, and continue suppressing the
    individual member partitions.
-   **Regression test:** Create `/dev/md0`, enter LUKS -\> Create a new
    LUKS container, verify `/dev/md0` appears while its member
    partitions do not.

### 34. Existing LUKS selector duplicates an MD-backed LUKS container

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r21.sh`
-   **Area:** LUKS reopen UI / device deduplication
-   **Observed behavior:** A LUKS container on `/dev/md0` appeared once
    for every RAID member because recursive `lsblk` repeated the same MD
    path.
-   **Fix:** Deduplicate LUKS candidates by canonical device path before
    building the Dialog menu.
-   **Regression test:** Close an MD-backed LUKS mapping, choose Open
    existing LUKS, and verify `/dev/md0` appears exactly once.

### 35. LVM PV selector duplicates RAID/LUKS mapper paths

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r21.sh`
-   **Area:** LVM physical-volume UI / device deduplication
-   **Observed behavior:** `/dev/mapper/cryptraid` could appear multiple
    times because recursive `lsblk` repeated descendants beneath each MD
    member.
-   **Fix:** Deduplicate LVM candidate devices by path before presenting
    the checklist.
-   **Regression test:** With RAID -\> LUKS active, verify
    `/dev/mapper/cryptraid` appears exactly once in the PV selector.

### 36. Volume-group creation should select from existing physical volumes

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r21.sh`
-   **Area:** LVM UI / volume-group creation
-   **Current behavior:** Creating a volume group asks for
    physical-volume device path(s) as free-form text.
-   **Desired behavior:** Query actual initialized physical volumes with
    `pvs` and present them in a Dialog checklist. Allow selecting one or
    more PVs with Space, then create the requested VG from those
    selections.
-   **Suggested flow:** `Create PV` -\> device checklist -\> `pvcreate`;
    `Create VG` -\> deduplicated existing-PV checklist -\> `vgcreate`;
    `Create LV` -\> existing-VG selector -\> LV name/size -\>
    `lvcreate`.
-   **Why:** Prevents typing mistakes, prevents selecting devices that
    are not initialized PVs, and makes the LVM workflow consistent with
    the rest of the storage UI.
-   **Related cleanup:** Apply the same device-path deduplication rule
    used for Issues #34/#35 so RAID/LUKS-backed PVs appear only once.
-   **Regression test:** Create a PV on `/dev/mapper/cryptraid`, choose
    Create volume group, verify the PV appears exactly once in the
    checklist, select it, create `bfs-vg`, and confirm `vgs`/`pvs` show
    the expected relationship.

### 37. Filesystem confirmation does not show the selected filesystem plan

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r21.sh`
-   **Area:** Filesystem assignment / confirmation UI
-   **Current behavior:** After selecting devices, filesystem actions,
    and mount points, the final Yes/No confirmation only asks
    `Use these filesystem and mount-point selections?` and does not
    display the actual selections.
-   **Expected behavior:** The confirmation screen itself must show
    every selected device, its mount point, and whether it will be
    formatted or preserved before the user chooses Yes or No.
-   **Required display:** For each selected target show at least
    `Device`, `Mount point`, and an unambiguous action such as
    `FORMAT as btrfs`, `FORMAT as ext2`, `FORMAT as vfat`,
    `FORMAT as swap`, or `KEEP existing filesystem / do not format`.
-   **Implementation note:** The installer already builds
    `storage_selection_summary_text()`, but the current Dialog `--yesno`
    confirmation does not include that summary text. Embed the generated
    filesystem plan directly into the confirmation prompt (or use an
    equivalent confirmation Dialog that presents the full plan before
    Yes/No).
-   **Regression test:** Assign `/`, `/boot`, `/boot/efi`, swap,
    `/home`, `/var`, etc.; select a mix of format and keep actions;
    choose Done; verify the very next confirmation visibly lists every
    device, mount point, and format/keep action before accepting Yes.

### 38. Final review does not show configured LVM volume groups or logical volumes

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r21.sh`
-   **Area:** Final installation review / LVM summary
-   **Observed behavior:** The Review selections screen reports
    `LVM Enabled: yes` but shows `Volume Group: none` and
    `Logical Volumes: none` even after the VG/LVs were created and are
    in use.
-   **Expected behavior:** The final review must enumerate the actual
    active/selected LVM topology instead of only reporting that LVM is
    enabled.
-   **Required display:** Show each VG name and each LV beneath it,
    including at least the LV path/name and size. Where possible, also
    show the backing PV(s) so the user can verify the complete
    `PV -> VG -> LV` chain before installation.
-   **Suggested data source:** Query live LVM metadata with `pvs`,
    `vgs`, and `lvs` rather than relying only on installer state
    variables, because VGs/LVs may have been created or activated
    through multiple paths.
-   **Example:** `Volume Group: bfs-vg`;
    `Logical Volumes: /dev/bfs-vg/home (500G), /dev/bfs-vg/var (500G)`;
    `Physical Volume: /dev/mapper/cryptraid`.
-   **Regression test:** Create the RAID -\> LUKS -\> LVM layout, open
    Review selections, and verify the real VG and all LVs are listed
    instead of `none`.

### 39. Make the Classic Slackware theme more authentically nostalgic and make it the default

-   [x] Enhancement
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r21.sh`
-   **Area:** Dialog theme / visual styling in installer and
    `bootstrap.sh`
-   **Current behavior:** The Classic Slackware theme captures the
    general cyan/blue/yellow palette, but the screen is too uniformly
    cyan and the normal text/border contrast feels flatter and more
    modern than the classic Slackware `setup` appearance. Both scripts
    currently default to another theme unless a saved setting or
    environment override selects Slackware.
-   **Desired behavior:** Tune only the Classic Slackware theme to more
    closely resemble the nostalgic ncurses/Dialog Slackware installer
    look while leaving all other themes available, and make **Classic
    Slackware the default theme for both the installer and
    `bootstrap.sh`** on a fresh configuration.
-   **Default-selection behavior:** Change the built-in fallback/default
    theme in both scripts to `slackware`. Existing users who already
    have a saved theme preference should keep that saved preference;
    explicit environment overrides such as `BFS_INSTALLER_THEME` /
    `BFS_BOOTSTRAP_THEME` should continue to take precedence.
-   **Visual changes to investigate:** Use a black terminal/screen
    background with cyan dialog panels; use black/dark normal dialog
    text; bright yellow dialog titles; strong blue active-selection bars
    with bright white text; vivid red/blue menu tags or accelerator
    characters; yellow selected tags where appropriate; stronger
    gray/white border and scrollbar contrast; and enable the classic
    Dialog drop-shadow/raised-window effect for this theme.
-   **Buttons:** Active buttons should have the high-contrast old Dialog
    appearance (blue background with bright white/yellow text); inactive
    buttons should remain clearly distinguishable against the cyan
    dialog.
-   **Scope:** Apply the same Classic Slackware styling consistently to
    both the BFSOS installer and `bootstrap.sh`. Do not alter the other
    selectable themes.
-   **Regression test:** Cycle through installer and bootstrap menus,
    yes/no prompts, checklists, password/input boxes, scrolling review
    dialogs, and storage menus using Classic Slackware. Verify
    readability, selection visibility, borders/shadows, and a consistent
    nostalgic Slackware `setup` appearance.

### 40. Add explicit support for separate `/usr` and general non-root mount ordering

-   [x] Enhancement
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r21.sh`
-   **Area:** Filesystem layout / mount ordering / Dracut early-boot
    dependencies
-   **Current concern:** The installer supports additional mount points,
    but separate `/usr` needs stronger handling than ordinary mounts
    such as `/opt`, `/srv`, `/var`, or `/home`.
-   **Required behavior for `/usr`:** Treat `/usr` as an
    early-boot-critical filesystem. Ensure the final initramfs can reach
    every storage layer required to mount it (plain block device, LUKS,
    MD RAID, LVM, etc.), generate the correct `/etc/fstab` entry, and
    include `/usr` in the same storage-dependency validation used for
    root.
-   **Dracut module requirement:** When `/usr` is a separate filesystem,
    automatically add Dracut's `usrmount` module to the generated BFS
    storage config (for example `add_dracutmodules+=" usrmount "`). If
    `/usr` depends on LUKS, MD RAID, or LVM, also include the
    corresponding `crypt`, `mdraid`, and/or `lvm` modules based on the
    actual `/usr` ancestry.
-   **Initramfs validation:** After rebuilding the initramfs, verify
    that the image contains `usrmount` whenever `/usr` is separate, plus
    every required supporting storage module. Fail or warn before reboot
    if the early-boot `/usr` dependency cannot be satisfied.
-   **General mount-order rule:** Mount all selected filesystems before
    rootfs extraction and before chroot/package configuration so files
    destined for separate mount points such as `/usr`, `/opt`, `/var`,
    or `/home` are written to the correct filesystem instead of being
    placed underneath the future mount point on `/`.
-   **Normal additional mounts:** `/opt`, `/srv`, `/var`, `/home`,
    `/tmp`, and other non-early-boot mount points can use the normal
    additional-filesystem path, but they still must be mounted before
    extraction/configuration when their content is part of the base
    system or installed packages.
-   **Validation:** Before installation, detect duplicate/nested
    mount-point conflicts and establish parent-before-child mount order.
    Before first boot, verify `/usr` is reachable from the initramfs
    when it is separate.
-   **Regression tests:** Test at least (1) separate plain `/usr`; (2)
    `/usr` on LVM; (3) `/usr` on LUKS/LVM or RAID-backed storage;
    and (4) separate `/opt` to confirm files are extracted onto the
    intended filesystem. For every separate-`/usr` case, inspect the
    final initramfs and confirm `usrmount` and the required storage
    modules are present before cold boot.

### 41. Add installer accessibility option for larger virtual-console font

-   [x] Enhancement
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r21.sh`
-   **Area:** Accessibility / installer settings / Linux virtual console
-   **Motivation:** High-DPI and 4K displays can make the default Linux
    virtual-console font difficult to read. The installer should provide
    an easy large-font mode for users with low vision.
-   **Installer setting:** Add a Settings option such as
    `Console font size` with at least `Default`, `16`, and `20` choices.
    Apply the selected font immediately to the live installer console so
    menus and text become easier to read during installation.
-   **Runtime-only switch:** Add a command-line/environment switch that
    enables large-console mode when launching the installer from a
    terminal without permanently changing the selected installed-system
    console font. Example interfaces could be `--large-console`,
    `--console-font=16`, `--console-font=20`, or an environment variable
    such as `BFS_CONSOLE_FONT=20`.
-   **Installed-system option:** Allow the user to choose whether the
    selected large font should also be written into the installed
    system's vconsole configuration so the same larger font is used at
    boot/login after installation.
-   **Implementation direction:** Use `setfont` with an installed
    console font that is known to exist. Detect available PSF fonts
    before presenting sizes, and gracefully fall back to the current
    font if the requested font is unavailable.
-   **Persistence:** Save the installer UI font preference alongside the
    existing installer settings, while keeping the runtime-only launch
    switch able to override it for the current run.
-   **High-DPI behavior:** Do not assume a fixed screen resolution. The
    feature should be font-size based so it works on 1080p, 1440p, 4K,
    and VM consoles.
-   **Regression tests:** Test the installer on a normal console and a
    4K/high-DPI console; verify switching between Default/16/20 applies
    immediately; verify the launch-time switch works; verify the
    installed-system vconsole font is only changed when explicitly
    requested.

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
-   [x] Complete RAID + LUKS + LVM functional boot proof. Fresh r4
    installer regression still recommended.
-   [x] Complete encrypted-root boot proof after adding the confirmed
    GRUB/Dracut arguments from Issue #30.

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
-   [x] Verify RAID + LUKS + LVM survives reboot with the confirmed
    Issue #30 arguments.
-   [ ] Verify Snapper configs and initial snapshots.
-   [ ] Verify EFI GRUB installation and fallback
    `EFI/BOOT/BOOTX64.EFI`.

## v50 Tracker Fix Build

-   **Generated:** 2026-08-09
-   **Script:** `install-bfs-menu-v50-tracker-fixed-r3.sh`
-   **Syntax check:** `bash -n` passed.
-   **r2 additions:** Dialog base-archive path input, RAID review
    generated from live mdadm state, filesystem-selection loop now uses
    an explicit Done action, and make-ca release 4 removes the
    ca-certificates file conflict.
-   **Critical crypttab change:** active dm-crypt mappings now obtain
    their backing device from `cryptsetup status` rather than
    `lsblk PKNAME`, which was blank for the reopened mappings in this
    test.
-   **Test next:** reuse the existing RAID/LUKS/LVM topology, select the
    filesystems/mount points, and run through installation to verify
    crypttab, dracut, GRUB, and encrypted-root boot.

## r3 Remaining-Changes Build

-   **Generated:** 2026-08-09
-   **Script:** `install-bfs-menu-v50-tracker-fixed-r3.sh`
-   **Syntax check:** `bash -n` passed.
-   **Implemented:** intelligent mount-point defaults; filesystem plan
    embedded directly in the final Yes/No confirmation; Current Storage
    Devices moved to Dialog; git + wget default on; final chroot returns
    directly to the installer menu.
-   **Profiles:** added Save, Save As, and Load under Installer
    Settings. Profiles exclude passwords/passphrases and validate saved
    block-device paths. Full RAID/LUKS/LVM recreation remains
    intentionally tracked as partial until those menus are converted
    from immediate destructive actions to a declarative storage plan.

## r4 Boot-Storage Fix Build

-   **Generated:** 2026-08-09
-   **Script:** `install-bfs-menu-v50-tracker-fixed-r4.sh`
-   **Issue #30:** dynamically generates permanent GRUB/Dracut storage
    arguments and stores them in `/etc/default/grub`; RAID adds the
    confirmed `rd.auto rd.md=1`, LUKS UUIDs come from `/etc/crypttab`,
    and required LV arguments are derived from `/etc/fstab` plus LVM
    metadata.
-   **Future kernels / recovery:** storage arguments are written to
    `GRUB_CMDLINE_LINUX`, not only the generated `grub.cfg`, so later
    `grub-mkconfig` runs and recovery entries retain the required
    storage topology.
-   **Validation:** installer verifies generated normal/recovery GRUB
    entries contain required RAID/LUKS/LVM arguments.
-   **Issue #21:** fixed the live `/proc/mdstat` parser that could
    report `RAID enabled: YES` while listing arrays as `none`.
-   **Additional UI cleanup:** assembling existing RAID arrays and
    viewing RAID details now stay in Dialog instead of dropping to raw
    terminal output with `Press Enter to continue...`.
-   **Still partial by design:** Issue #28 profile support does not
    recreate RAID/LUKS/LVM destructively from a profile until storage
    setup is refactored into a declarative plan.

## r21 Storage / UI / Accessibility Polish Build

-   **Generated:** 2026-08-10
-   **Installer:** `install-bfs-menu-v50-tracker-fixed-r21.sh`
-   **Bootstrap:** `bootstrap-r21-classic-slackware-default.sh`
-   **Syntax checks:** `bash -n` passed for both scripts.
-   **Issues #34/#35:** deduplicate MD-backed LUKS and LVM device paths.
-   **Issue #36:** VG creation now selects from real unassigned PVs; LV
    creation selects from real VGs.
-   **Issue #37:** filesystem confirmation now embeds the full
    device/mount/FORMAT-or-KEEP plan before Yes/No.
-   **Issue #38:** final review queries live `pvs`, `vgs`, and `lvs`
    metadata.
-   **Issue #39:** Classic Slackware is the fresh-install default in
    installer and bootstrap, with black screen, cyan panels, stronger
    borders, blue selections, and Dialog shadow.
-   **Issue #40:** non-root filesystems are mounted parent-before-child
    before extraction; separate `/usr` causes `usrmount` to be forced
    into the generated Dracut config and verified in the completed
    initramfs.
-   **Issue #41:** installer Settings now provide Default/16/20
    console-font choices, optional installed-system persistence, plus
    runtime-only `--large-console`, `--console-font SIZE`, and
    `BFS_CONSOLE_FONT` overrides.
-   **Issue #28 remains intentionally partial:** profile replay does not
    yet recreate destructive RAID/LUKS/LVM topology; that still requires
    a declarative storage planner and must never store passphrases.

## r22 Follow-up Issues Found During VM Regression Testing

### 42. Add a destructive storage-reset helper for repeated installs and recovery

-   [x] Fix / enhancement revalidated
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r27.sh`
-   **r27 regression fix:** Expanded MD detection to report active
    arrays and inactive member metadata with `mdadm --examine`; the
    destructive checklist now retains RAID-member devices after array
    deactivation and labels them explicitly before zeroing
    superblocks/wiping selected metadata.
-   **Area:** Installer Settings / storage maintenance / test workflow
-   **Goal:** Add an explicit Settings action that detects old LVM,
    LUKS, and MD RAID state and can tear it down cleanly before a fresh
    installation.
-   **UI:** Add a clearly destructive option such as
    `Reset existing storage metadata...`. Never run it automatically.
-   **Detection:** Before confirmation, enumerate active and inactive MD
    arrays, LUKS mappings/containers, LVM PVs/VGs/LVs, swap devices,
    mounted target filesystems, and stale filesystem/signature metadata.
-   **Preview:** Show exactly what will be affected before doing
    anything: mounts to unmount, swap to disable, VGs/LVs to
    deactivate/remove, LUKS mappings to close, MD arrays to stop, member
    devices whose MD superblocks will be removed, and devices on which
    `wipefs` will run.
-   **Safety:** Require an explicit destructive confirmation. Exclude
    the live installer media, BFSOS source/build disk, and any device
    not selected/confirmed by the user. Never guess that an unrelated
    disk is safe to erase.
-   **Order of operations:** Unmount target filesystems -\> swapoff -\>
    deactivate/remove LVs/VGs/PVs as requested -\> close LUKS mappings
    -\> stop MD arrays -\> zero MD superblocks when requested -\> run
    `wipefs` on confirmed backing devices/arrays -\> `udevadm settle`.
-   **Modes:** Ideally provide both `Deactivate only` and
    `Destroy metadata / fresh start` so normal recovery work does not
    require wiping anything.
-   **Why:** Repeated VM installer testing currently requires many
    manual `vgchange`, `cryptsetup close`,
    `mdadm --stop/--zero-superblock`, and `wipefs` commands.
-   **Regression test:** Build RAID -\> LUKS -\> LVM storage, leave it
    active, invoke the reset helper, confirm the preview is correct,
    perform a full reset, and verify `pvs`, `vgs`, `lvs`, `/dev/mapper`,
    `/proc/mdstat`, and `lsblk -f` show the expected clean state while
    the BFSOS build disk remains untouched.

### 43. Partition/filesystem Cancel must return to Storage setup, not abort installation

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r26.sh`
-   **Area:** Storage assignment / Dialog navigation / error handling
-   **Observed behavior:** Cancelling the partition/filesystem selection
    path can escape as a non-zero return and trigger
    `ERROR: Installation cancelled`, invoking fatal cleanup.
-   **Desired behavior:** `Back` or Dialog Cancel returns to Storage
    setup. Only an explicit `Cancel installation`/Quit action may
    terminate the installer.
-   **State preservation:** RAID/LUKS/LVM objects already created should
    remain available when returning to Storage setup unless the user
    explicitly removes them.
-   **Regression test:** Create RAID/LUKS/LVM state, enter filesystem
    assignment, press Cancel, and verify the installer returns to
    Storage setup with storage state intact and no fatal cleanup.

### 44. Improve failure logging for navigation and generated/chroot failures

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r26.sh`
-   **Area:** Logging / ERR trap
-   **Current behavior:** Some failures produce only
    `ERROR: Installation cancelled` or
    `Installation stopped near line 1`, hiding the command/function that
    actually returned non-zero.
-   **Desired behavior:** Log the failing command, source file, function
    stack, real line number, and exit status. Normal Dialog Back/Cancel
    return codes must be handled explicitly and never reach the fatal
    ERR path.
-   **Log preservation:** Keep the live-environment installer log even
    when target mounts are cleaned up, and copy it into the installed
    system whenever the target remains available.

### 45. Rework filesystem-plan confirmation into a readable scrollable view

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r26.sh`
-   **Area:** Filesystem confirmation UI
-   **Observed behavior:** With many devices/LVs the confirmation table
    wraps across lines and becomes difficult to read.
-   **Desired behavior:** Use a wide, vertically scrollable fixed-column
    view showing at least Number, Device, Action (`FORMAT as ...` /
    `KEEP`), and Mount point. Keep Continue/Back controls clear and
    prevent rows from wrapping into each other.
-   **Priority:** Safety-critical readability before destructive
    formatting.

### 46. Improve mount-point defaults from logical-volume/device names

-   [x] Enhancement
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r26.sh`
-   **Area:** Filesystem assignment / mount-point suggestion
-   **Desired behavior:** Infer common mount points from the final
    LV/device component: `root` -\> `/`, `usr` -\> `/usr`, `opt` -\>
    `/opt`, `home` -\> `/home`, `var` -\> `/var`, `tmp` -\> `/tmp`,
    `srv` -\> `/srv`, and `swap` -\> swap. Keep the suggestion editable.

### 47. Loaded profiles must refresh main-menu configured/pending indicators

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r26.sh`
-   **Area:** Installer profiles / main menu state
-   **Observed behavior:** Profile values appear to load, but sections
    still show `[PENDING]`.
-   **Desired behavior:** After loading a profile, recalculate each
    section status from restored values. Storage may remain pending when
    destructive topology still requires manual recreation.

### 48. Match the Classic Slackware theme to Slackware's actual current dialogrc

-   [x] Enhancement
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r26.sh` and
    `bootstrap-r26.sh`
-   **Area:** Installer and bootstrap theme
-   **Reference verified:** Slackware64-current
    `dialog-1.3_20260721-x86_64-1.txz`, `etc/dialogrc.new`
    (`$Id: slackware.rc,v 1.13 2025/12/22 ...`), which Slackware's
    `build_installer.sh` copies into the installer as `/etc/dialogrc`.
-   **Correction to earlier assumption:** Slackware intentionally uses a
    BLUE full-screen background. Do not replace it with black merely to
    look more nostalgic.
-   **Goal:** Make BFSOS `Classic Slackware` match the real Slackware
    dialog palette and behavior as closely as practical, while retaining
    BFSOS-specific text/layout.
-   **Behavior values:** `aspect = 0`, `separate_widget = ""`,
    `tab_len = 0`, `visit_items = OFF`, `use_scrollbar = OFF`,
    `use_shadow = ON`, `use_colors = ON`.
-   **Core palette:** `screen_color = (WHITE,BLUE,OFF)`,
    `shadow_color = (WHITE,BLACK,OFF)`,
    `dialog_color = (BLACK,CYAN,OFF)`, `title_color = (YELLOW,CYAN,ON)`,
    `border_color = (CYAN,CYAN,ON)`.
-   **Buttons:** active `(WHITE,BLUE,ON)`; inactive uses `dialog_color`;
    inactive accelerator/key `(RED,CYAN,OFF)`; inactive label
    `(BLACK,CYAN,ON)`.
-   **Input/search:** input `(BLUE,WHITE,OFF)` with normal border;
    search `(YELLOW,WHITE,ON)`; search title `(WHITE,WHITE,ON)`; search
    border `(RED,WHITE,OFF)`.
-   **Menus/items:** menubox and item use `dialog_color`; selected item
    uses `screen_color`.
-   **Tags:** normal tag uses `title_color`; selected tag uses
    `screen_color`; tag key uses inactive button-key color; selected tag
    key `(RED,BLUE,ON)`.
-   **Checklist/arrows:** check uses `dialog_color`; selected check
    `(WHITE,CYAN,ON)`; up/down arrows `(GREEN,CYAN,ON)`.
-   **Other verified values:** position indicator uses inactive
    button-key color; item-help uses shadow color; active form text uses
    inputbox color; form text `(CYAN,BLUE,ON)`; readonly form item
    `(CYAN,WHITE,ON)`; gauge `(BLUE,WHITE,ON)`;
    border2/inputbox_border2/searchbox_border2/menubox_border2 use
    `dialog_color`.
-   **Scope:** Apply the same authentic Classic Slackware theme
    implementation to both the BFSOS installer and `bootstrap.sh`.
-   **Regression test:** Compare installer/bootstrap menus, input boxes,
    checklists, selected rows, buttons, titles, arrows, shadows, and
    gauges against Slackware's current `dialogrc` behavior.

### 49. Simplify large-console-font persistence

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r26.sh`
-   **Area:** Accessibility / console font settings
-   **Desired behavior:** Selecting `Large 16` or `Large 20` should
    apply immediately to the installer and automatically configure the
    installed BFSOS virtual console to use the same font. Remove the
    separate `Use selected console font after install` question.
    `Default` retains the normal installed-system default.

### 50. Optional Software and sudo should not start as pending

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r26.sh`
-   **Area:** Main-menu status/defaults
-   **Optional Software:** Never show `[PENDING]`; no optional packages
    is valid. Use `[OPTIONAL]` initially and `[CONFIGURED]` after
    choices are made.
-   **Sudo:** If untouched, default to normal sudo authentication
    requiring the user's password and show `[DEFAULT]` (or equivalent),
    not `[PENDING]`.
-   **General rule:** Reserve `[PENDING]` for sections that genuinely
    require user attention before installation can proceed.
-   **Optional package addition:** Add the existing BFSOS
    `wpa_supplicant` port (`ports/core/wpa_supplicant`) to Optional
    Software.

### 51. Review/install forward action should be Continue

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r26.sh`
-   **Area:** Review/install navigation
-   **Desired behavior:** The forward action from Review into
    installation must be labeled `Continue`. `Back` must only return to
    the previous configuration screen. Make cancellation an explicit
    separate action.

### 52. Detect stale signatures on newly created MD arrays

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r26.sh`
-   **Area:** MD RAID -\> LUKS workflow
-   **Observed behavior:** A newly created `/dev/mdX` can expose a stale
    `crypto_LUKS` or filesystem signature from previous contents,
    causing the LUKS `Create new container` selector to hide the
    otherwise valid RAID array.
-   **Desired behavior:** Immediately after MD creation, inspect the
    array with `wipefs`. If stale signatures are present, show them and
    offer an explicit `Wipe signatures`, `Keep`, or `Cancel` choice
    before continuing.
-   **Safety:** Never silently wipe signatures.

### 53. Pre-reboot validation: complex encrypted RAID/LVM/Btrfs install is boot-test ready

-   [x] Validation passed
-   **Area:** Final installation validation / Dracut / GRUB / storage
-   **Validated topology:** UEFI + separate ext2 `/boot`; LUKS
    `cryptroot` -\> LVM `bfs-root` -\> separate Btrfs `/`, `/usr`, and
    `/opt`; MD RAID -\> LUKS `cryptraid` -\> LVM `bfs-vg` -\> separate
    Btrfs `/home` and `/var`; Btrfs snapshot subvolumes; disk swap.
-   **Dracut modules verified in generated initramfs:** `btrfs`,
    `crypt`, `crypt-lib`, `dm`, `lvm`, `mdraid`, `rootfs-block`, and
    `usrmount`.
-   **Separate `/usr` support verified:** initramfs contains Dracut
    `pre-pivot/50-mount-usr.sh`; generated
    `/etc/dracut.conf.d/20-bfs-storage.conf` records
    `Separate /usr: yes` and forces `usrmount crypt lvm mdraid`.
-   **GRUB verified:** generated kernel command line contains
    `root=/dev/mapper/bfs--root-root`, `rootflags=subvol=@`, `rd.auto`,
    `rd.md=1`, both LUKS UUID arguments, and `rd.lvm.lv=bfs-root/root`;
    correct BFSOS kernel and initramfs paths are present.
-   **ZRAM verified:** kernel config has `CONFIG_ZRAM=m` and the
    installed `zram.ko` exists under
    `/lib/modules/7.1.5-BFS-Linux/kernel/drivers/block/zram/`.
-   **Decision:** Do not make further Dracut/GRUB changes before the
    reboot test. The current configuration should be tested as generated
    by the installer.
-   **Next test:** Cleanly leave chroot/unmount, reboot from the
    installed disk, confirm both LUKS prompts/unlocks, MD assembly, both
    VGs, separate `/usr`, `/opt`, `/var`, `/home`, and successful
    systemd userspace boot.

### 54. Update installed release branding URLs from BFS-Linux to BFSOS

-   [x] Fix

-   **Completed:** Installed test system produced BFSOS Codeberg URLs
    correctly, and the installer keeps the extracted os-release
    safeguard. The source `aaa_filesystem` Pkgfile had already been
    corrected in the project tree before this pass.

-   **Area:** `aaa_filesystem` / `/etc/os-release` branding

-   **Observed behavior:** Installed `/etc/os-release` still uses
    `https://codeberg.org/bmadonnaster/BFS-Linux` for `HOME_URL`,
    `SUPPORT_URL`, and `BUG_REPORT_URL` even though the repository has
    been renamed to BFSOS.

-   **Desired behavior:** Change all three generated URLs to the current
    BFSOS repository and BFSOS issues page.

-   **Scope:** Search release/branding files and installer-generated
    metadata for any remaining stale `BFS-Linux` repository references
    so new installs do not recreate them.

-   **Priority:** Cosmetic/non-boot-blocking; fix after the current
    reboot test rather than modifying this installed test system before
    first boot.

-   **r35 safeguard:** The installer now rewrites stale BFS-Linux
    Codeberg URLs in the extracted
    `/etc/os-release`/`/usr/lib/os-release` to BFSOS. The source
    `ports/core/aaa_filesystem/Pkgfile` still needs to be updated
    directly when that port file is supplied; it was not among the
    uploaded files for this pass. \### 55. Rename the blue theme to
    Classic Debian and reproduce Debian's real installer palette from
    source

-   [x] Enhancement

-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r26.sh` and
    `bootstrap-r26.sh`

-   **Area:** Installer and bootstrap themes / Debian-inspired theme

-   **Rename:** Change the existing blue-theme display name to **Classic
    Debian** everywhere it appears in installer menus, bootstrap menus,
    saved theme/profile labels, help text, and documentation. Preserve
    the existing internal key where practical for compatibility, or add
    a migration/alias so saved configurations using the old theme name
    still load correctly.

-   **Research source of truth:** Do not rely on screenshots or memory.
    Base the Classic Debian palette on Debian's actual installer
    frontend source.

-   **Primary Debian source:** Debian's installer uses `cdebconf` with a
    `newt` frontend. The authoritative source tree is the Debian
    Installer Team `cdebconf` repository and the versioned Debian
    Sources copies.

-   **Historical evidence:** Debian's `cdebconf` changelog records
    explicit newt color changes, including support for a dark background
    via `FRONTEND_BACKGROUND=dark` and later readability changes for
    select, multiselect, and button colors.

-   **Related palette source:** `newt` itself defines color-set roles
    such as root, border, window, shadow, title, button, active button,
    checkbox, entry, listbox, textbox, helpline, and progress-scale
    colors. Debian's frontend may override or remap these, so inspect
    `cdebconf`'s newt frontend first and use `newt` defaults only where
    Debian leaves them unchanged.

-   **Research targets:** Locate and compare the current and
    historically representative Debian installer newt frontend
    code/config for root/screen, window/dialog, borders/shadows, titles,
    active/inactive buttons, entries, normal/selected menu rows,
    checkboxes/radiolists, help/status text, progress bars, and any
    `FRONTEND_BACKGROUND` logic.

-   **Implementation goal:** Translate the verified Debian installer
    palette into the BFSOS Dialog-based theme as faithfully as practical
    while keeping BFSOS-specific layouts and controls.

-   **Scope:** Apply the renamed **Classic Debian** theme consistently
    to both the BFSOS installer and `bootstrap.sh`; do not alter Classic
    Slackware or other themes.

-   **Compatibility:** Existing saved profiles/configs referring to the
    old blue-theme identifier/name must continue to work and should map
    automatically to Classic Debian.

-   **Regression test:** Compare BFSOS Classic Debian menus, prompts,
    input boxes, checklists, selected rows, buttons, titles, shadows,
    help text, and progress displays against the Debian installer
    source-defined appearance; verify theme selection and saved-profile
    migration work in both installer and bootstrap.

-   **Research starting points:** Debian Installer Team `cdebconf`
    source on Salsa; Debian Sources package history for `cdebconf`;
    `cdebconf` newt frontend source and changelog entries for
    `FRONTEND_BACKGROUND=dark`; Debian `newt` source for base color-set
    definitions where needed.

-   **Source research completed for r26:** Debian `cdebconf` 0.280
    `src/modules/frontend/newt/newt.c` uses `newtDefaultColorPalette`
    unless `FRONTEND_BACKGROUND=dark`; its alternate dark palette
    remains explicitly defined in the frontend. Debian's `cdebconf`
    changelog documents the black-background mode and later
    select/multiselect/button readability changes.

-   **Classic palette basis used in BFSOS:** the normal newt palette
    roles map to white-on-blue root/screen, black-on-light-gray
    window/border, red-on-light-gray title/active button, yellow-on-blue
    entry/selected-list accents, and a white-on-black shadow. Dialog's
    `WHITE` is used as the closest standard-color approximation to newt
    `lightgray`.

-   **Compatibility:** the internal theme key remains `classic`, so
    existing settings/profiles continue loading while the visible name
    changes from `Classic Blue` to `Classic Debian`. \### 56. Add
    explicit early-boot GRUB/LVM arguments for separate `/usr`

-   [x] Fix

-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r26.sh`

-   **Area:** GRUB generation / Dracut early-LVM activation / separate
    `/usr`

-   **Observed boot failure:** With `/usr` on `bfs-root/usr`, Dracut
    loaded `usrmount` and all required storage modules, unlocked
    `cryptroot`, activated `bfs-root/root`, and mounted root, but `/usr`
    failed because `bfs-root/usr` was not activated early. The generated
    kernel command line contained `rd.lvm.lv=bfs-root/root` but omitted
    `rd.lvm.lv=bfs-root/usr`.

-   **Manual proof:** Adding `rd.lvm.lv=bfs-root/usr` to the GRUB kernel
    command line allowed the system to boot successfully.

-   **Required fix:** Whenever `/usr` is on an LVM LV, add an explicit
    `rd.lvm.lv=<VG>/<LV>` argument for that `/usr` LV in addition to the
    root LV argument.

-   **General rule:** Generate explicit `rd.lvm.lv=` arguments for every
    filesystem that is genuinely required in initramfs/early userspace,
    not merely every LV in the system.

-   **Do not over-broaden by default:** Normal late mounts such as
    `/opt`, `/var`, `/home`, `/srv`, and similar filesystems do not need
    explicit early-LVM kernel arguments solely because they are LVs. Let
    normal systemd/fstab activation handle them after switch-root unless
    their ancestry is needed to reach `/usr` or another
    early-boot-critical path.

-   **RAID/LUKS handling:** Continue generating explicit early-boot
    RAID/LUKS arguments from the ancestry of root and separate `/usr`.
    It is safe to include required parent MD/LUKS devices, but avoid
    blindly adding every unrelated RAID/LUKS device in the machine
    because that can trigger unnecessary unlock prompts, array assembly,
    delays, or failures for storage that is not required to boot.

-   **Topology-driven implementation:** Walk the block-device ancestry
    for `/` and `/usr`; collect only the required LVM LVs, LUKS UUIDs,
    and MD arrays; deduplicate arguments; persist them in
    `GRUB_CMDLINE_LINUX`; regenerate `grub.cfg`; and verify the
    generated normal and recovery entries contain all required
    early-storage arguments.

-   **Regression tests:**

    1.  Root on LVM with no separate `/usr`.
    2.  Root + separate `/usr` on different LVs in the same VG.
    3.  `/usr` on LUKS -\> LVM.
    4.  `/usr` on MD RAID -\> LUKS -\> LVM.
    5.  Extra unrelated LVs/RAID/LUKS present for `/home`, `/var`, or
        data; confirm they do not cause unnecessary early boot prompts
        or kernel arguments.

-   **Boot regression confirmed/fixed:** the first cold boot failed
    because only `bfs-root/root` was activated. Manually adding
    `rd.lvm.lv=bfs-root/usr` in GRUB allowed BFSOS to boot successfully.
    r26 now derives explicit `rd.lvm.lv=` arguments from `/` and `/usr`
    only, rather than all LVs.

-   **Topology scope:** required LUKS UUIDs and MD discovery flags are
    likewise derived from the ancestry of `/` and `/usr`, avoiding
    unnecessary unlock prompts or assembly of unrelated data/home
    storage.

## r26 Tracker Implementation Pass

-   **Generated:** 2026-08-10
-   **Installer:** `install-bfs-menu-v50-tracker-fixed-r26.sh`
-   **Bootstrap:** `bootstrap-r26.sh`
-   **Syntax checks:** `bash -n` passed for both scripts.
-   **Issues completed in this pass:** #42, #43, #44, #45, #46, #47,
    #48, #49, #50, #51, #52, #55, #56.
-   **Issue #54 remains open:** `/etc/os-release` URL correction belongs
    in the `aaa_filesystem` port/Pkgfile rather than either of the two
    scripts supplied for this pass.
-   **Storage maintenance:** Settings now includes a previewed
    `Deactivate only` mode and an explicit checklist-driven destructive
    metadata reset. Protected live-root/project storage is excluded.
-   **Filesystem navigation/UI:** Back from filesystem assignment
    returns to Storage setup; the final plan is shown in a wide
    scrollable textbox followed by Continue/Back confirmation; LV names
    such as `usr`, `opt`, `var`, `home`, `tmp`, and `srv` get sensible
    mount-point suggestions.
-   **Profiles/status:** loaded profiles recalculate configured/pending
    state; Optional Software defaults to `OPTIONAL`; sudo defaults to
    password-authenticated `DEFAULT`.
-   **Optional software:** `wpa_supplicant` is available as an optional
    package.
-   **Console accessibility:** selecting Large 16/20 automatically
    persists that choice to the installed system; selecting Default
    disables persistence.
-   **Themes:** Classic Slackware now uses the exact Slackware
    `dialogrc` values gathered during testing; Classic Blue is renamed
    Classic Debian and translated from Debian cdebconf/newt source while
    preserving the `classic` internal key.
-   **RAID stale signatures:** newly-created arrays are checked with
    `wipefs -n` and the user is explicitly offered a safe wipe/keep
    choice.
-   **Failure diagnostics:** ERR trap now records exit status, source,
    line, function, command, and caller instead of `line 1`.
-   **Install navigation:** final installation confirmation is
    Continue/Back; Back returns to configuration instead of triggering
    fatal cleanup.
-   **Early boot storage:** GRUB arguments are derived from
    boot-critical `/` and `/usr` ancestry. Separate `/usr` on LVM now
    receives its own `rd.lvm.lv=` parameter.

## r27 Follow-up Issues Found During Installed-System Testing

### 57. Fix GRUB/Dracut topology logic for complex storage

-   [x] Fix --- reopened after r27 regression test
-   **Implemented in r35:**
    `scripts/install-bfs-menu-v50-tracker-fixed-r35.sh` and/or
    `bootstrap.sh` as applicable.
-   **Area:** GRUB generation / Dracut / complex storage
-   **Observed behavior:** The completed install did not automatically
    emit the complete/correct boot-storage arguments required by the
    tested topology. Manual correction was required before reboot.
-   **Required behavior:** Derive boot-critical storage ancestry and
    emit the required `rd.luks.uuid=`, `rd.md.uuid=`, and `rd.lvm.lv=`
    arguments. Finalize `/etc/crypttab` and mdadm configuration before
    rebuilding the initramfs, then regenerate `grub.cfg` and validate
    the generated boot entries/initramfs.
-   **Regression scope:** LUKS -\> LVM and MD RAID -\> LUKS -\> LVM,
    including separate `/usr`, `/opt`, `/home`, `/var`, and complex
    Btrfs layouts.
-   **r27 regression #1 --- truncated MD UUID:** The MD UUID parser
    emitted only the first colon-delimited field (`rd.md.uuid=4a9b5206`)
    instead of the complete mdadm UUID
    (`rd.md.uuid=4a9b5206:8ebe46e5:6d41cbba:3468e1e1`). Preserve the
    complete value exactly as reported by `mdadm --detail` /
    `mdadm --detail --scan`; do not parse it with a generic colon field
    split.
-   **r27 regression #2 --- stale verifier:** The generator switched to
    explicit `rd.md.uuid=...`, but the GRUB verifier still failed the
    install with `boot-critical RAID storage requires rd.auto`.
    Generator and verifier must use the same storage model. A valid
    explicit `rd.md.uuid=` must satisfy RAID verification; `rd.auto`
    must not be required when explicit MD UUIDs are emitted.
-   **r27 regression #3 --- missing explicit LUKS cmdline:** The tested
    RAID -\> LUKS -\> LVM plus separate LUKS root topology generated no
    `rd.luks.uuid=` values even though `/etc/crypttab` contained both
    mappings. Generate explicit LUKS UUID arguments for every
    boot-required encrypted layer in the selected storage ancestry.
-   **Known-good manual result for this test topology:**
    -   `rd.luks.uuid=77d5c3fb-083b-4ea3-9aa8-11f4e85d334e`
    -   `rd.luks.uuid=a82d9766-a424-4530-b4a7-9b8de91d0b2c`
    -   `rd.md.uuid=4a9b5206:8ebe46e5:6d41cbba:3468e1e1`
    -   `rd.lvm.lv=bfs-root/root`
    -   `rd.lvm.lv=bfs-root/usr`
    -   `rd.lvm.lv=bfs-raid/home`
    -   `rd.lvm.lv=bfs-raid/var`
-   **Initramfs validation from failed r27 test:** The initramfs already
    contained `crypttab`, `mdadm.conf`, `cryptsetup`, `mdraid`, and LVM
    support, so this failure was isolated to GRUB/storage-command-line
    generation and verification rather than missing initramfs storage
    tooling.
-   **Post-install menu clarification:** The missing Chroot/Finish menu
    was not a separate post-install-menu bug in this test. The installer
    aborted during final GRUB verification, so it correctly never
    reached the success/post-install menu.
-   **Regression test:** Build the same RAID0 -\> LUKS -\> LVM layout
    plus separate LUKS root, regenerate initramfs/GRUB without manual
    edits, verify full MD UUID preservation, both LUKS UUIDs, all
    required LVs in normal and recovery entries, and confirm the
    installer reaches the final Chroot/Finish menu after validation
    succeeds.

### 58. Correct Review vs Option 10 final-summary navigation labels

-   [x] Fix
-   **Implemented in r35:**
    `scripts/install-bfs-menu-v50-tracker-fixed-r35.sh` and/or
    `bootstrap.sh` as applicable.
-   **Area:** Review/install navigation
-   **Observed behavior:** r27 overcorrected the navigation labels so
    both the configuration Review screen and the Option 10 final
    installation summary show `Continue`.
-   **Desired behavior:** The Review/configuration screen must provide
    `Back` so the user can return and change selections. Option 10's
    final installation summary must show `Continue` at the bottom to
    proceed into installation; it must not show `Back`.
-   **Regression test:** Confirm the Review/configuration screen says
    `Back`, then enter Option 10 and confirm the final summary says
    `Continue`. Verify Back actually returns to configuration and
    Continue advances toward installation.

### 59. Consolidate BFSOS logs under `/var/log/bfs`

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r27.sh` and
    `bootstrap-r27.sh`
-   **Area:** Bootstrap/build logging / installer logging
-   **Observed behavior:** Build logs are currently installed under
    `/var/logs/bfs-build/`, while installer logs correctly use
    `/var/log/bfs/installer/`.
-   **Desired layout:** `/var/log/bfs/bfs-build/` for package/bootstrap
    build logs and `/var/log/bfs/installer/` for installer logs.
-   **Cleanup:** Remove new uses of the legacy `/var/logs` path and
    update log-copy/install logic so all BFSOS-specific logs live below
    `/var/log/bfs/`.
-   **r27 implementation:** Bootstrap copies base-package build logs to
    `/var/log/bfs/bfs-build`; installer logs remain
    `/var/log/bfs/installer`.

### 60. Add `wireless_tools` to Optional Software

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r27.sh`
-   **Area:** Optional Software
-   **Package:** `wireless_tools` 30.pre9
-   **Status:** Port built and runtime tools verified during
    installed-system testing.
-   **Desired behavior:** Offer `wireless_tools` in the installer's
    Optional Software selection alongside `wpa_supplicant`.
-   **r27 implementation:** Added `BFS_INSTALL_WIRELESS_TOOLS`, profile
    save/load support, Dialog/text optional-package selection, and
    chroot package-list installation.

## r27 Test Notes

-   Full installer run completed without installer errors before first
    reboot.
-   `wpa_supplicant` 2.11 was verified installed and runnable against
    OpenSSL 4 (`libssl.so.4` / `libcrypto.so.4`).
-   `wireless_tools` was successfully built after correcting the BFSOS
    port to invoke `build_opt` from `pkg_build` and package the
    statically linked utilities without expecting a nonexistent
    `libiw.so.30` from the default upstream build.

### 61. Clear terminal screen on installer/bootstrap exit

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r27.sh` and
    `bootstrap-r27.sh`
-   **Area:** Installer/bootstrap terminal cleanup / UI
-   **Observed behavior:** Exiting the installer or `bootstrap.sh` can
    leave the full-screen `dialog` background and menu colors painted
    across the terminal instead of restoring a clean shell view.
-   **Desired behavior:** On every normal exit, Cancel/Quit path, and
    handled error exit, restore the terminal state and clear/redraw the
    screen before returning to the shell.
-   **Implementation note:** Centralize terminal cleanup in the existing
    exit/cleanup handler so both the installer and bootstrap
    consistently run the appropriate `clear`/terminal-reset sequence
    after `dialog` is closed. Avoid scattering cleanup calls through
    individual menus.
-   **Regression test:** Exit normally, use Back/Cancel/Quit paths, and
    trigger a handled failure under each theme; confirm the shell
    returns with no stale installer/bootstrap background, colors, cursor
    state, or screen contents.
-   **r27 implementation:** Both scripts centralize terminal reset in
    their EXIT cleanup handlers, reset SGR attributes, show the cursor,
    and clear/redraw `/dev/tty` after restoring `DIALOGRC`.

## r27 Implementation Pass

-   **Generated:** 2026-08-11
-   **Installer:** `install-bfs-menu-v50-tracker-fixed-r27.sh`
-   **Bootstrap:** `bootstrap-r27.sh`
-   **Issues addressed:** #42 regression, #57, #58, #59, #60, #61.
-   **Still open:** #54 (`aaa_filesystem` branding URLs) because the
    port Pkgfile was not part of this script pair.
-   **Required regression test:** run a fresh complex-storage VM install
    and verify generated GRUB/initramfs without manual edits,
    storage-reset RAID detection/destruction, Review button label,
    optional `wireless_tools`, installed log paths, and clean terminal
    exit.

### 62. Change OpenSSH prompt to enable-on-boot wording

-   [x] Fix
-   **Implemented in r35:**
    `scripts/install-bfs-menu-v50-tracker-fixed-r35.sh` and/or
    `bootstrap.sh` as applicable.
-   **Area:** Optional software / service configuration
-   **Observed behavior:** The installer currently presents OpenSSH like
    an optional package even though `openssh` is already installed by
    the BFSOS bootstrap/base system.
-   **Desired behavior:** Ask `Do you want to enable OpenSSH on boot?`
    and treat the answer as service configuration for `sshd.service`,
    not as a package-install decision.
-   **Regression test:** Confirm OpenSSH is already present from the
    base system, the installer asks only whether to enable it at boot,
    and the selected answer produces the expected `sshd.service`
    enablement state.

### 63. Run mandatory `prt-get sysup` after `ports -u`

-   [x] Enhancement / fix
-   **Implemented in r35:**
    `scripts/install-bfs-menu-v50-tracker-fixed-r35.sh` and/or
    `bootstrap.sh` as applicable.
-   **Area:** Ports synchronization / installed-system upgrade
-   **Reason:** A user may install from an older base rootfs archive.
    Synchronizing the ports tree alone does not upgrade packages already
    present in that base system.
-   **Desired behavior:** After a successful `ports -u`, run
    `prt-get sysup` inside the installed system as a mandatory system
    upgrade before the final initramfs/Dracut and GRUB generation.
-   **Failure behavior:** A failed `prt-get sysup` must stop the
    installation rather than silently continuing with a partially
    upgraded system.
-   **Logging:** Capture the system-upgrade output in the installer log
    so package changes and failures can be diagnosed later.
-   **Regression test:** Test with an intentionally older base archive;
    confirm ports synchronize, installed packages upgrade, failures
    propagate, and final Dracut/GRUB generation occurs only after the
    upgrade succeeds.

## r28 Tracker Update

-   **Generated:** 2026-08-11
-   **Tracker-only update:** No installer/bootstrap code changed in this
    revision.
-   **Reopened:** #58 to distinguish the Review/configuration `Back`
    action from Option 10 final-summary `Continue`.
-   **Added:** #62 OpenSSH enable-on-boot wording/service logic.
-   **Added:** #63 mandatory `prt-get sysup` after `ports -u`, before
    final Dracut/GRUB generation.

### 64. Offer optional package-cache cleanup after successful installation

-   [x] Enhancement
-   **Implemented in r35:**
    `scripts/install-bfs-menu-v50-tracker-fixed-r35.sh` and/or
    `bootstrap.sh` as applicable.
-   **Area:** Post-install package/cache cleanup
-   **Timing:** Ask only after all package installation and the
    mandatory `prt-get sysup` have completed successfully, immediately
    before returning to the installer menu.
-   **Prompt:** Ask whether the user wants to clear the built/downloaded
    binary package cache under `/var/cache/pkg/packages/`.
-   **Default:** No. Keeping the cached binary packages can be useful
    for reinstalling packages or troubleshooting without rebuilding
    them.
-   **Yes behavior:** Remove the contents of `/var/cache/pkg/packages/`
    while leaving the directory itself in place.
-   **Scope:** Do not clear `/var/cache/pkg/sources/`; source-cache
    cleanup is outside this option.
-   **Safety:** Do not offer or perform this cleanup during a failed or
    partially completed package upgrade, so cached packages remain
    available for diagnosis/recovery.
-   **Regression test:** Complete an install/update with cached packages
    present, choose No and verify they remain; repeat choosing Yes and
    verify `/var/cache/pkg/packages/` is empty while
    `/var/cache/pkg/sources/` is untouched.

### 65. Tie the bootstrap and installer workflows together

-   [x] Enhancement
-   **Implemented in r35:**
    `scripts/install-bfs-menu-v50-tracker-fixed-r35.sh` and/or
    `bootstrap.sh` as applicable.
-   **Area:** Bootstrap menu / installer integration
-   **Goal:** Make the normal BFSOS workflow flow directly from building
    a usable base rootfs into launching the installer, instead of
    treating bootstrap and installation as unrelated entry points.
-   **Installer location:** Move the primary installer script into the
    repository `scripts/` directory. The bootstrap menu should resolve
    it relative to `SCRIPT_DIR` rather than relying on the caller's
    current working directory.
-   **Bootstrap menu:** Add an explicit `Launch BFSOS installer` entry
    that runs the repository installer from `scripts/`.
-   **Installer discovery:** Do not hard-code a single versioned
    installer filename in `bootstrap.sh`. Discover matching installer
    scripts under `scripts/` with a stable pattern (for example
    `install-bfs-menu-v*.sh`), exclude obvious backups/test artifacts
    where practical, and select the newest usable version automatically.
-   **Version selection rule:** Prefer the highest/newest installer
    revision deterministically. If filenames contain a date/time or
    revision component, use that ordering rather than whichever file
    happens to be returned first by the filesystem.
-   **Visibility:** Show the exact installer path/version bootstrap is
    about to launch so the user can see which revision was selected.
-   **Normal workflow:** The common path should make bootstrap stages 1,
    2, and 4 plus rootfs archive creation prominent/required for
    producing an installable BFSOS base.
-   **Stage 3:** Keep the full final-toolchain/base rebuild available,
    but clearly label it **optional**. It is useful for users who
    deliberately want to rebuild the system a second time, but it must
    not be presented as a prerequisite for installation.
-   **Rootfs archive:** Keep creation/compression of the base rootfs
    archive as a mandatory part of the normal build-to-install workflow
    because the installer consumes that archive.
-   **Installer handoff:** Before launching the installer, verify that a
    usable base rootfs archive exists. If not, explain which required
    bootstrap/archive step is incomplete rather than launching into a
    guaranteed failure.
-   **Return behavior:** When the installer exits normally or is
    cancelled, return cleanly to the bootstrap menu with the terminal
    restored.
-   **Direct execution:** Moving the installer under `scripts/` must not
    prevent advanced users from invoking it directly.
-   **Path migration:** Update documentation, helper scripts, tracker
    references, and any hard-coded repository-root installer paths to
    the new `scripts/` location.
-   **Regression test:** From a clean repository, complete the normal
    bootstrap path without stage 3, create the rootfs archive, launch
    the installer from the bootstrap menu, cancel/return, relaunch it,
    and verify paths, permissions, terminal cleanup, archive detection,
    and direct installer execution all work.

### 66. Clarify mandatory vs optional bootstrap stages in the menu

-   [x] UI / workflow enhancement
-   **Implemented in r35:**
    `scripts/install-bfs-menu-v50-tracker-fixed-r35.sh` and/or
    `bootstrap.sh` as applicable.
-   **Area:** Bootstrap menu
-   **Goal:** Make it immediately obvious which stages are needed to
    produce an installable BFSOS base and which are optional
    validation/rebuild operations.
-   **Required normal-build stages:** Present bootstrap options 1, 2,
    and 4 as part of the normal required workflow, together with
    mandatory base-rootfs archive creation/compression.
-   **Optional rebuild stage:** Mark option 3 as optional and describe
    it as a second/final rebuild for users who want the additional
    rebuild pass.
-   **Status tracking:** Completion/pending indicators must not treat
    skipped option 3 as an incomplete/error state when the user follows
    the normal installable-base workflow.
-   **Installer readiness:** The new installer-launch entry should base
    readiness on the genuinely required stages and availability of the
    rootfs archive, not on completion of optional stage 3.
-   **Existing archive readiness:** On bootstrap startup, inspect the
    default base-archive directory. If a valid base rootfs archive
    already exists, treat the installable-base requirement as satisfied
    even when the current checkout has no fresh stage markers from this
    session.
-   **Menu status:** Reflect that state clearly in the bootstrap menu
    (for example `READY`/`ARCHIVE AVAILABLE`) so the user can launch the
    installer immediately without rebuilding mandatory stages
    unnecessarily.
-   **Safety:** Archive presence should satisfy installer readiness only
    after validating that the file is readable and matches a supported
    BFSOS base-rootfs archive format.
-   **Regression test:** Verify a user can complete the required
    workflow, intentionally skip stage 3, create the archive, and
    launch/install BFSOS without warnings claiming the build is
    incomplete.

## r29 Tracker Update

-   **Generated:** 2026-08-11

-   **Tracker-only update:** No bootstrap or installer code changed in
    this revision.

-   **Added:** #65 bootstrap-to-installer integration and moving the
    primary installer into `scripts/`.

-   **Added:** #66 distinguish the required bootstrap path from optional
    stage 3 and ensure installer readiness does not depend on stage 3.

-   **Planned workflow:** build required base stages -\> create/compress
    rootfs archive -\> launch installer directly from the bootstrap
    menu.

-   **Status semantics:** Use the three status words consistently:
    `PENDING` means a required prerequisite has not been satisfied;
    `AVAILABLE` means an action can be run now but is not itself a
    completion requirement; `COMPLETE` means the corresponding
    build/verification/archive requirement has been satisfied.

-   **Required stages 1, 2, and 4:** Show `PENDING` until their
    completion checks pass, then `COMPLETE`.

-   **Stage 3 optional rebuild:** Do not show `PENDING` merely because
    it was skipped. Show `AVAILABLE` while it can be run and `COMPLETE`
    after it has actually completed.

-   **Rootfs archive creation:** Show `PENDING` until a valid base
    archive exists, then `COMPLETE`.

-   **Restore actions:** `Restore newest base rootfs archive` and
    `Restore newest temporary toolchain archive` are actions, not
    mandatory stages. Show `AVAILABLE` whenever a valid source archive
    exists. They must not remain `PENDING` just because the user has not
    chosen to restore something.

-   **Chroot:** Show `AVAILABLE` whenever a usable rootfs exists;
    otherwise `PENDING` because there is nothing to enter yet.

-   **Installer launch:** Show `AVAILABLE` whenever a valid base rootfs
    archive exists and the installer can be discovered; otherwise
    `PENDING`. Launching the installer is an action, so it should not be
    labeled `COMPLETE` simply because it was run once.

### 67. Add graphical base-rootfs archive selection and browsing

-   [x] UI / workflow enhancement
-   **Implemented in r35:**
    `scripts/install-bfs-menu-v50-tracker-fixed-r35.sh` and/or
    `bootstrap.sh` as applicable.
-   **Area:** Installer base archive selection
-   **Goal:** Avoid requiring the user to manually type a base-rootfs
    archive path when the archive is outside the default location.
-   **Default archive behavior:** First search/check the normal BFSOS
    base-rootfs archive location. If a usable archive exists, show the
    discovered archive and its full path and offer to use it
    immediately.
-   **Newest archive selection:** When multiple valid base archives
    exist in the default location, automatically choose the newest one.
    If the filename contains the BFSOS date/time stamp, sort by that
    embedded timestamp first; fall back to file modification time only
    when a reliable timestamp cannot be parsed from the name.
-   **Deterministic tie-break:** If two candidates resolve to the same
    parsed timestamp, use a stable secondary sort (such as modification
    time then filename) so selection is predictable.
-   **Display:** The detected/default archive screen should identify
    that it is the newest available archive and show the selected
    filename, full path, size, and timestamp before the user accepts it.
-   **Default archive choices:** When an archive is found, provide clear
    actions to use the detected archive, browse/select a different
    archive, or go Back.
-   **Missing-default behavior:** If no usable archive exists in the
    default location, open the file-selection/browse interface
    automatically rather than presenting a dead/default path.
-   **Browse interface:** Use a Dialog file selector such as `--fselect`
    when available so the user can navigate directories and choose the
    base archive interactively.
-   **Archive validation:** After selection, verify the selected path
    exists, is a regular readable file, and uses an archive/compression
    format supported by the installer before accepting it.
-   **Confirmation:** Show the selected archive's full path and useful
    metadata such as file size before committing the selection.
-   **Session behavior:** Preserve the selected archive path for the
    remainder of the installer session and in installer profile/state
    handling where appropriate.
-   **Bootstrap integration:** When the installer is launched from the
    bootstrap workflow added by #65, prefer the rootfs archive just
    created by bootstrap as the detected/default archive.
-   **Text-mode fallback:** If Dialog/file selection is unavailable,
    retain a text-mode path prompt with validation rather than making
    archive selection impossible.
-   **Regression test:** Test with (1) a valid archive in the default
    location, (2) no default archive, (3) choosing a different archive
    despite a valid default, (4) invalid/non-readable selections,
    and (5) launching from bootstrap immediately after archive creation.

## r30 Tracker Update

-   **Generated:** 2026-08-11
-   **Tracker-only update:** No installer/bootstrap code changed in this
    revision.
-   **Added:** #67 interactive base-rootfs archive discovery/browsing
    with default-archive preference, validation, and bootstrap handoff
    support.

## r31 Tracker Update

-   **Generated:** 2026-08-11
-   **Tracker-only update:** No bootstrap or installer code changed in
    this revision.
-   **Updated #65:** Bootstrap installer launch must discover the newest
    versioned installer under `scripts/` instead of hard-coding one
    filename.
-   **Updated #66:** A valid existing base-rootfs archive in the default
    archive directory can satisfy installer readiness and should be
    reflected in bootstrap menu status.
-   **Updated #67:** When multiple default base archives exist, select
    the newest archive deterministically, preferring the date/time
    embedded in the filename when present.

### 69. Normalize bootstrap `PENDING` / `AVAILABLE` / `COMPLETE` status logic

-   [x] UI / workflow fix
-   **Implemented in r35:**
    `scripts/install-bfs-menu-v50-tracker-fixed-r35.sh` and/or
    `bootstrap.sh` as applicable.
-   **Area:** Bootstrap menu status indicators
-   **Observed behavior:** The current bootstrap helper treats nearly
    every non-completed item as `PENDING`, including restore operations
    that are already usable when an archive exists. Chroot is handled
    separately as `AVAILABLE`, so the menu currently mixes completion
    state and action availability inconsistently.
-   **Required semantics:**
    -   `PENDING` --- a required prerequisite or required build result
        is not yet satisfied.
    -   `AVAILABLE` --- the action can be run now, but running it is
        optional/repeatable and it is not a required completion gate.
    -   `COMPLETE` --- a build, verification, or archive requirement has
        been satisfied.
-   **Expected menu behavior:**
    -   Temporary toolchain build: `PENDING` -\> `COMPLETE`.
    -   Base-system build with temporary toolchain: `PENDING` -\>
        `COMPLETE`.
    -   Optional final rebuild (stage 3): `AVAILABLE` -\> `COMPLETE`;
        never `PENDING` solely because it was skipped.
    -   Verify completed base system: `PENDING` -\> `COMPLETE`.
    -   Create/compress base rootfs archive: `PENDING` -\> `COMPLETE`
        once a valid archive exists.
    -   Restore newest base rootfs archive: `AVAILABLE` whenever a valid
        archive exists; otherwise `PENDING`.
    -   Restore newest temporary toolchain archive: `AVAILABLE` whenever
        a valid toolchain archive exists; otherwise `PENDING`.
    -   Chroot into BFS rootfs: `AVAILABLE` when a usable rootfs exists;
        otherwise `PENDING`.
    -   Launch BFSOS installer: `AVAILABLE` when a valid base archive
        exists and a current installer is discoverable; otherwise
        `PENDING`.
-   **Implementation:** Replace the one-size-fits-all
    `_stage_complete_text` / `_dialog_stage_status` use with per-action
    status helpers or a generic status function that can distinguish
    completion checks from availability checks.
-   **Consistency:** Text-mode and Dialog menus must report the same
    status for every option.
-   **Regression test:** Test a clean tree, completed stage 1 only,
    completed stage 2, skipped stage 3, verified base, archive present,
    restored rootfs, restored toolchain, and installer-ready states.
    Confirm each menu item uses exactly the expected `PENDING`,
    `AVAILABLE`, or `COMPLETE` label.

## r32 Tracker Update

-   **Generated:** 2026-08-11
-   **Tracker-only update:** No bootstrap or installer code changed in
    this revision.
-   **Updated #66:** Defined exact `PENDING`, `AVAILABLE`, and
    `COMPLETE` semantics for the streamlined bootstrap/install workflow.
-   **Added #69:** Normalize status logic in both text and Dialog
    bootstrap menus, especially optional stage 3, restore actions,
    chroot, and installer launch.

### 70. Offer ZRAM swap when no disk swap is configured

-   [x] Enhancement
-   **Implemented in r35:**
    `scripts/install-bfs-menu-v50-tracker-fixed-r35.sh` and/or
    `bootstrap.sh` as applicable.
-   **Area:** Installer storage / swap configuration
-   **Trigger:** After storage assignment is complete, detect whether
    the installed system has a configured swap partition or swap logical
    volume.
-   **No-swap behavior:** If no disk-backed swap is configured, ask
    whether the user wants to enable ZRAM swap on the installed BFSOS
    system.
-   **Prompt:** Clearly explain that ZRAM provides compressed swap in
    RAM and does not require a swap partition.
-   **Default:** Yes when no other swap exists, while still requiring
    the user to confirm the choice.
-   **Existing-swap behavior:** If disk-backed swap exists, do not
    silently enable ZRAM. Either skip the ZRAM prompt or present ZRAM
    separately as an optional supplemental swap choice.
-   **Kernel validation:** Before configuring ZRAM, verify the target
    kernel/config/modules provide ZRAM support (for example built-in
    `CONFIG_ZRAM=y` or module `CONFIG_ZRAM=m` with the corresponding
    module installed). Do not assume support from the live environment.
-   **Configuration:** Install/write the appropriate BFSOS/systemd ZRAM
    configuration so ZRAM swap is created automatically during normal
    boot.
-   **Failure behavior:** If the user selects ZRAM but the installed
    kernel or required userspace support is unavailable, show a clear
    warning/error and do not claim ZRAM is enabled.
-   **Review screen:** Explicitly show both disk swap and ZRAM state,
    for example `Disk swap: none` and `ZRAM swap: enabled`, so
    compressed swap is not hidden from the installation summary.
-   **Post-install verification:** Verify the installed configuration
    exists and is enabled before declaring the ZRAM setup successful.
-   **Regression test:** Test (1) no swap + ZRAM Yes, (2) no swap + ZRAM
    No, (3) disk swap configured, (4) ZRAM kernel support missing,
    and (5) reboot of a completed ZRAM-enabled install followed by
    `swapon --show`/equivalent verification.

## r33 Tracker Update

-   **Generated:** 2026-08-11
-   **Tracker-only update:** No installer/bootstrap code changed in this
    revision.
-   **Added:** #70 optional ZRAM swap configuration when no disk-backed
    swap is selected, including target-kernel validation, review
    visibility, boot-time configuration, and post-install verification.

### 71. Keep final GRUB verification consistent with generated storage arguments

-   [x] Fix
-   **Implemented in r35:**
    `scripts/install-bfs-menu-v50-tracker-fixed-r35.sh` and/or
    `bootstrap.sh` as applicable.
-   **Area:** Final installation validation / success transition
-   **Observed behavior:** r27 generated explicit `rd.md.uuid=`
    arguments, then aborted the installation because the verifier still
    required `rd.auto`. This prevented the normal
    successful-installation Chroot/Finish menu from appearing.
-   **Desired behavior:** The final verifier must validate exactly the
    storage arguments the generator intentionally emits. Do not require
    obsolete/alternative arguments that are not part of the chosen
    generation strategy.
-   **Failure reporting:** When validation fails, clearly state which
    expected argument/value is missing or malformed. For MD RAID, print
    the expected complete UUID and the actual generated kernel line.
-   **Success transition:** Only after final GRUB/initramfs verification
    succeeds should the installer show the Installation Complete dialog
    and the Chroot/Finish menu.
-   **Logging:** Keep logging active through final verification and the
    post-install transition so any late failure is captured in the
    installer log.
-   **Regression test:** Test successful and intentionally broken
    RAID/LUKS/LVM cmdlines. Broken configuration must fail with an
    actionable message; correct configuration must pass and reach the
    post-install menu.

## r34 Tracker Update

-   **Generated:** 2026-08-11
-   **Tracker-only update:** No installer/bootstrap code changed in this
    revision.
-   **Reopened/expanded #57:** r27 truncated colon-separated MD UUIDs,
    omitted explicit LUKS UUID arguments for the tested topology, and
    used a stale verifier that still required `rd.auto`.
-   **Added #71:** Keep final GRUB verification synchronized with
    generated storage arguments and preserve logging through the final
    validation/post-install transition.
-   **Test conclusion:** The missing Chroot/Finish menu was a
    consequence of final GRUB verification failure, not a standalone
    menu bug.

## r35 Implementation Pass

-   **Generated:** 2026-08-11

-   **Installer moved for normal workflow:**
    `scripts/install-bfs-menu-v50-tracker-fixed-r35.sh`

-   **Bootstrap:** `bootstrap.sh`

-   **Implemented:** #57, #58, #62, #63, #64, #65, #66, #67, #69, #70,
    #71.

-   **#54:** Installed-system safeguard implemented; source
    `aaa_filesystem/Pkgfile` remains pending because that port file was
    not supplied in this pass.

-   **GRUB fix:** Full colon-separated MD UUIDs are preserved, explicit
    LUKS UUIDs come from finalized crypttab, and verification no longer
    requires stale `rd.auto`/`rd.md=1`.

-   **Bootstrap/install handoff:** Bootstrap discovers the newest
    executable versioned installer under `scripts/` and hands it the
    newest valid base archive.

-   **Normal bootstrap path:** stages 1, 2, 4, and rootfs archive
    creation are required; stage 3 is optional and reports AVAILABLE
    until completed.

-   **Package policy:** every install performs `ports -u` followed by
    mandatory `prt-get sysup`; optional packages are installed
    afterward.

-   **Post-install cleanup:** user is asked whether to clear
    `/var/cache/pkg/packages/*`; default is No.

-   **Swap policy:** when no disk swap is selected, installer offers
    ZRAM (default Yes) and validates installed-kernel ZRAM support
    before enabling its systemd service. \## r38 Tracker Update

-   **Generated:** 2026-08-11

-   **Bootstrap:** `bootstrap.sh` through r42

-   **Installer:** no installer code changed in this tracker update.

-   **Bootstrap changes below are completed and regression-tested
    interactively in the VM unless otherwise noted.**

### 72. Fix bootstrap theme Settings workflow and defaults

-   [x] UI / workflow fix
-   **Implemented in:** `bootstrap.sh`
-   **Area:** Bootstrap Settings / interface themes
-   **Default theme:** Classic Slackware is the startup default on every
    normal bootstrap invocation. A stale saved theme from an earlier
    test must not silently make Debian or another theme the startup
    default.
-   **Theme choices:** The bootstrap Settings theme selector now exposes
    all supported themes in one place:
    -   `Slackware` --- Classic Slackware theme and default.
    -   `Debian` --- Classic Debian installer/newt-style theme.
    -   `Monochrome`.
    -   `Midnight`.
    -   `Light`.
-   **Visible theme labels:** Capitalize the first character of every
    left-hand theme name. Use `Debian`, not the internal identifier
    `classic`, as the visible label.
-   **Internal compatibility:** The Debian palette may continue to use
    the existing internal `classic` theme key so the underlying
    implementation does not need to be renamed.
-   **Back behavior:** Back/Esc from the theme selector returns cleanly
    to the previous/bootstrap menu. Navigating Settings must not produce
    `Operation completed successfully` or a
    `Press Enter to return to the menu...` pause.
-   **Settings layout:** The main bootstrap menu shows only `Settings`,
    with no current-theme text on the right-hand side so additional
    settings can be added later without changing the main-menu layout.
-   **Menu placement:** `Settings` is no longer a numbered/scrollable
    menu entry. It is a dedicated bottom dialog button positioned
    between `<Select>` and `<Quit>`.
-   **Regression test:** Start bootstrap with no special environment
    override, confirm Classic Slackware is selected by default, open
    Settings, verify all five themes and capitalization, apply each
    theme, use Back/Esc, and confirm the main menu returns immediately
    without an operation-success/pause screen.

### 73. Use AVAILABLE / NOT AVAILABLE for bootstrap chroot status

-   [x] UI / workflow fix
-   **Implemented in:** `bootstrap.sh`
-   **Area:** Bootstrap main-menu status
-   **Observed behavior:** Chroot was shown as `PENDING`, which
    incorrectly implied it was an unfinished required stage.
-   **Desired behavior:** Chroot is an optional action and must display
    only:
    -   `AVAILABLE` when a usable restored BFSOS environment exists.
    -   `NOT AVAILABLE` when it cannot currently be entered.
-   **Availability gate:** Do not mark chroot available merely because a
    base archive or toolchain archive exists. Require that the base
    rootfs and/or temporary toolchain has actually been restored into
    the working tree and that a usable Bash exists in the rootfs.
-   **Consistency:** Apply the same wording and availability logic to
    both Dialog and text-mode bootstrap menus.
-   **Regression test:** With only archives present, verify Chroot shows
    `NOT AVAILABLE`; restore the base rootfs or temporary toolchain as
    appropriate and verify it changes to `AVAILABLE` only when the
    restored filesystem is actually usable.

### 74. Match installer theme-name capitalization to bootstrap

-   [x] UI consistency fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r36.sh`.
    Theme selector now shows `Slackware`, `Debian`, `Monochrome`,
    `Midnight`, and `Light`, with Slackware first/default and internal
    `classic` compatibility preserved.
-   **Area:** Installer Settings / interface themes
-   **Observed behavior:** Bootstrap now presents the left-hand theme
    names as `Slackware`, `Debian`, `Monochrome`, `Midnight`, and
    `Light`, while the installer still needs the same visible naming
    convention.
-   **Desired behavior:** Update the installer theme-selection UI to use
    the same capitalization and user-facing names as `bootstrap.sh`.
-   **Required visible names:** `Slackware`, `Debian`, `Monochrome`,
    `Midnight`, `Light`.
-   **Debian naming:** Show `Debian` in the selector rather than
    exposing an internal theme key such as `classic`; descriptions may
    still identify it as the Classic Debian installer/newt-style theme.
-   **Default:** Classic Slackware remains the installer default.
-   **Compatibility:** Preserve internal theme keys/profile
    compatibility where practical; this is a display-name/UI consistency
    change, not a requirement to rename stored identifiers.
-   **Regression test:** Compare installer and bootstrap theme selectors
    side-by-side and confirm theme names, capitalization, order/default
    behavior, and descriptions are consistent. \### 75. Return directly
    to bootstrap after installer exits
-   [x] UI / workflow fix
-   **Implemented in:** `bootstrap-r44-tracker-complete.sh`. Returning
    from the installer now resets the terminal and immediately redraws
    bootstrap with no generic success/failure message or Enter pause.
-   **Area:** Bootstrap-to-installer handoff / return behavior
-   **Observed behavior:** After the installer exits back to
    `bootstrap.sh`, bootstrap currently shows:
    -   `Operation completed successfully.`
    -   `Press Enter to return to the menu...`
-   **Desired behavior:** When the installer exits normally or is
    cancelled and control returns to bootstrap, immediately redraw and
    return to the bootstrap main menu.
-   **Do not show:** No generic `Operation completed successfully.`
    message and no `Press Enter to return to the menu...` pause for the
    installer-launch action.
-   **Scope:** This exception applies specifically to the
    `Launch BFSOS installer` menu action. Normal build stages may
    continue to show completion/failure output and pause when that
    output is useful.
-   **Terminal handling:** Restore/reset the terminal cleanly after the
    installer exits before redrawing the bootstrap menu so no installer
    colors, background, cursor state, or stale screen content remain.
-   **Regression test:** Launch the installer from bootstrap, then test
    both normal installer exit and Cancel/Back/Quit paths. In every
    case, confirm control returns immediately to the bootstrap main menu
    with no intermediate success/pause screen.

### 76. Move Bootstrap Settings to bottom action-button row

-   [x] UI / workflow fix
-   **Implemented in:** `bootstrap.sh` r43
-   **Area:** Bootstrap main menu
-   **Observed behavior:** `Settings` was incorrectly added as a
    numbered item at the bottom of the scrollable bootstrap menu.
-   **Desired behavior:** Remove `Settings` from the numbered menu
    entries and place it on the bottom action-button row between
    `Select` and `Quit`.
-   **Final dialog button order:** `<Select>` `<Settings>` `<Quit>`.
-   **Behavior:** Selecting the Settings button opens the existing
    Bootstrap Settings / Interface Theme screen; returning from Settings
    redraws the bootstrap main menu normally.
-   **Compatibility:** Text-mode fallback retains the numeric Settings
    choice because it has no dialog button row.
-   **Status:** Completed in bootstrap r43.

### 77. Silently return when Chroot is NOT AVAILABLE

-   [x] UI / workflow fix

-   **Implemented in:** `bootstrap-r44-tracker-complete.sh`. Selecting
    Chroot while unavailable now immediately redraws the menu; no
    root-stage call, error, success message, or pause is produced.

-   **Area:** Bootstrap main menu / Chroot action

-   **Observed behavior:** When `Chroot into BFS rootfs` shows
    `NOT AVAILABLE`, pressing Enter on that menu item currently proceeds
    into the action path and produces an error/message before returning.

-   **Desired behavior:** If Chroot is `NOT AVAILABLE`, selecting it
    should do nothing except immediately redraw the bootstrap main menu.

-   **Do not show:** No error message, no `Operation failed`, no
    `Operation completed successfully`, and no
    `Press Enter to return to the menu...` pause.

-   **Availability logic:** Continue using the existing
    `_chroot_available` test. The menu action should check availability
    before invoking the root/chroot stage.

-   **Available behavior:** When Chroot shows `AVAILABLE`, Enter should
    continue to launch the chroot normally.

-   **Regression test:** With Chroot showing `NOT AVAILABLE`, highlight
    it and press Enter; confirm the bootstrap menu immediately redraws
    with no intermediate output or pause. Then restore a usable
    rootfs/toolchain, confirm it changes to `AVAILABLE`, and verify
    Enter launches the chroot normally. \### 78. Rescan all storage
    after every destructive or topology-changing storage operation

-   [x] Installer storage-detection bug

-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r36.sh`.
    Added centralized `refresh_storage_state()` and wired it into cfdisk
    return, storage metadata destruction, RAID assembly/create/signature
    wipe, LUKS create/open/close, LVM PV/VG/LV creation, and
    filesystem/swap formatting.

-   **Area:** Installer storage discovery / partitioning / filesystems /
    RAID / LUKS / LVM

-   **Observed behavior:** Possible stale-device-state bug: after
    launching `cfdisk` from inside the installer and creating or
    changing partitions, the RAID member selection screen appeared not
    to reflect the newly written partition table.

-   **Expanded requirement:** Do not limit the fix to `cfdisk`. After
    every destructive or storage-topology-changing operation, force a
    fresh kernel/userspace storage rescan and rebuild the installer's
    device inventory before presenting another storage-selection or
    review screen.

-   **Operations that must trigger a rescan include at minimum:**

    -   returning from `cfdisk` or another partition-table editor after
        changes;
    -   creating, deleting, resizing, or rewriting partitions/partition
        tables;
    -   formatting or reformatting filesystems and initializing swap;
    -   creating, assembling, stopping, destroying, or otherwise
        changing MD RAID arrays;
    -   creating, opening, closing, formatting, or otherwise changing
        LUKS mappings;
    -   creating/removing/changing LVM PVs, VGs, and LVs;
    -   destructive signature/wipe operations such as `wipefs`;
    -   any other installer action that changes block-device names,
        mappings, filesystem/type metadata, sizes, parent/child
        relationships, or availability.

-   **Refresh sequence:** Review use of `partprobe`,
    `blockdev --rereadpt`, `udevadm settle`, MD/LUKS/LVM discovery
    commands, and/or equivalent safe mechanisms as appropriate for the
    operation. The goal is a reliable fresh view of all storage devices,
    not merely the disk that was just edited.

-   **No stale cache:** Do not reuse a partition/device list gathered
    before the destructive operation. Re-run the installer
    storage-enumeration logic (`lsblk` and any RAID/LUKS/LVM discovery
    used by the installer) after the rescan.

-   **Consumers of refreshed state:** RAID member selection,
    filesystem/format selection, mount-point assignment, swap selection,
    LUKS, LVM, installation review, and every later storage screen must
    use the refreshed inventory.

-   **Failure handling:** If the kernel cannot reread a partition table
    or refresh a device because it is busy, clearly report the condition
    rather than silently continuing with stale information.

-   **Regression test:** Exercise each supported
    destructive/topology-changing storage path, then immediately enter
    the next relevant storage screen and verify device names,
    partitions, sizes, filesystem/type information, RAID/LUKS/LVM
    mappings, and availability match the new state without restarting
    the installer. \### 79. Verify sudo default uses password
    authentication

-   [x] Installer configuration verification

-   **Verified in source:** The installer default remains
    `SUDO_MODE=password`, which writes `%wheel ALL=(ALL:ALL) ALL`.
    `NOPASSWD` is only written when the user explicitly selects the
    no-password mode, matching the successful VM test.

-   **Area:** Installed-system sudo / privilege escalation defaults

-   **Check:** Confirm that the installer installs and configures `sudo`
    as the default privilege-escalation mechanism for regular users.

-   **Required default:** `sudo` must require the invoking user's
    password by default.

-   **Do not default to:** Passwordless `NOPASSWD` sudo access.

-   **Configuration review:** Check `/etc/sudoers` and any
    installer-created files under `/etc/sudoers.d/` to make sure the
    regular-user/admin group rule uses normal password authentication
    and that no broader `NOPASSWD` rule overrides it.

-   **Validation:** Run `visudo -c` on the installed system and test
    from a regular configured user with a cleared sudo timestamp
    (`sudo -k`) to confirm the next `sudo` command prompts for that
    user's password.

-   **Regression test:** Fresh install with a normal user, log in as
    that user, run `sudo -k` followed by a harmless sudo command, and
    verify a password prompt appears and valid user credentials are
    required. \### 80. Make Review (option 10) flow directly into Ready
    to install (option 11)

-   [x] Installer UI / workflow fix

-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r36.sh`.
    Option 10 Review now advances directly to Ready to install; Back
    from Ready reopens Review; Continue starts installation without
    returning to the main menu.

-   **Area:** Installer main menu options 10 and 11 / final pre-install
    workflow

-   **Observed behavior:** Option 10 (`Review selections`) displays the
    installation review, but pressing `Continue` returns to the
    installer main menu instead of advancing to the final installation
    confirmation.

-   **Correct workflow:** Options 10 and 11 should behave as one
    continuous pre-install sequence:

    1.  Select option 10 and display the complete `Review selections`
        screen.
    2.  Press `Continue` on the review screen.
    3.  Advance directly to the option 11 `Ready to install` screen
        (`Begin the BFS installation?`).
    4.  Press `Continue` there to begin installation.
    5.  Press `Back` on `Ready to install` to return directly to the
        `Review selections` screen.

-   **Review-screen behavior:** The important fix is not to send
    `Continue` back to the main menu. `Continue` must advance to
    `Ready to install`.

-   **Main-menu option 11:** Directly selecting option 11 may continue
    to open the `Ready to install` stage, but the normal intended path
    is Review -\> Ready to install -\> Install.

-   **No state loss:** Moving forward or backward between Review and
    Ready to install must preserve all current installer selections.

-   **Regression test:** Enter option 10, review selections, press
    `Continue`, verify `Ready to install` appears immediately; press
    `Back`, verify the same review reappears; press `Continue` again and
    then `Continue` on Ready to install, and verify installation begins
    without returning to the main menu between these stages. \### 81.
    Exit directly to terminal after installation is finished

-   [x] Installer UI / workflow cleanup

-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r36.sh`.
    Removed the redundant final completion/unmount text and terminal
    review dump; Finish restores terminal state and returns directly to
    the caller while normal cleanup remains active.

-   **Area:** Installer completion / final exit

-   **Observed behavior:** After the installation has completed and the
    user finishes the post-install/chroot workflow, the installer still
    prints an extra completion/unmount message instead of simply
    returning control to the shell.

-   **Desired behavior:** Once installation is complete and the user
    chooses to finish/exit, perform the required cleanup and unmount
    operations, restore the terminal state, and return directly to the
    live-environment terminal prompt.

-   **Do not show:** No extra final `BFS installation completed...`
    message, no generic success message, and no `Press Enter` pause
    after the user has already finished the installation workflow.

-   **Keep:** The existing completion/post-install screen may still
    provide the explicit choices to chroot into the installed system or
    finish the installation; this issue concerns what happens after the
    user chooses to finish.

-   **Implementation note:** The current installer path explicitly
    prints
    `BFS installation completed. The installer will unmount the target filesystems.`
    after the post-install menu; remove that redundant final output
    while preserving cleanup/unmount behavior.

-   **Regression test:** Complete an installation, use the post-install
    chroot option if desired, exit the chroot, then choose Finish.
    Confirm filesystems are cleaned up/unmounted and control returns
    directly to the live shell prompt with no additional completion
    dialog/message or pause. \### 82. Fix `bfs-zram.service` systemd
    ordering cycle

-   [x] Installer / installed-system boot fix

-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r36.sh`.
    Generated ZRAM service now uses `DefaultDependencies=no`; default
    ZRAM capacity is dynamically set to 2× physical RAM. The ordering
    fix was also validated manually in the VM: ZRAM active and
    `systemctl is-system-running` returned `running`.

-   **Area:** ZRAM swap / systemd unit ordering

-   **Observed on first successful installed-system boot:**
    `bfs-zram.service` itself starts successfully and creates the
    configured ZRAM swap, but systemd reports an ordering cycle
    involving `tmp.mount`, `swap.target`, `bfs-zram.service`,
    `basic.target`, and `sysinit.target`. The cycle can cause
    `tmp.mount` to be dropped from the boot transaction and leaves
    `systemctl is-system-running` reporting `degraded`.

-   **Current generated unit:** `bfs-zram.service` uses
    `After=systemd-modules-load.service`, `Before=swap.target`, and
    `WantedBy=swap.target`, while normal service default dependencies
    also place it after `basic.target`/`sysinit.target`. Because
    `tmp.mount` is `After=swap.target` and participates in the early
    local-filesystem ordering, this produces a dependency cycle.

-   **Required fix:** Make the ZRAM setup service an explicitly early
    boot service by adding `DefaultDependencies=no` while retaining the
    required module-load ordering and `Before=swap.target` relationship.
    Keep it enabled from `swap.target`.

-   **Target unit shape:**

    ``` ini
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

-   **Default ZRAM sizing:** Set the default ZRAM device size to **2×
    the system's physical RAM**. Example: a system with 32 GiB RAM
    should default to a 64 GiB `/dev/zram0`.

-   **Sizing implementation:** Calculate the size dynamically from
    detected physical memory rather than hard-coding a fixed size. Keep
    any explicit user-configured size override if the installer/settings
    already provide one.

-   **Do not regress:** ZRAM must still be initialized before
    `swap.target` is considered reached, `/dev/zram0` must become active
    swap, and shutdown must still cleanly stop the service.

-   **Regression test:** Fresh install with ZRAM enabled, cold boot,
    confirm there are no `Found ordering cycle` messages for
    ZRAM/swap/tmp, `tmp.mount` is not dropped because of the ZRAM unit,
    `systemctl status bfs-zram.service` is successful, `swapon --show`
    lists the configured ZRAM device at approximately 2× physical RAM by
    default, and `systemctl is-system-running` is not degraded because
    of this ordering issue. \### 83. Diagnose/fix VM reboot not
    returning after `reboot`

-   [x] Boot / VM integration bug

-   **Root cause found / host fix applied:** The VM launcher contained
    QEMU `-no-reboot`, which intentionally exits QEMU on guest reboot.
    The option was removed from the live launcher and its shell syntax
    was checked. This is a VM-launcher issue, not a BFSOS guest/GRUB
    defect; one reboot regression test remains to confirm behavior.

-   **Area:** Installed BFSOS reboot behavior under QEMU

-   **Observed behavior:** The installed BFSOS VM boots successfully
    from a cold start, but issuing `reboot` from the running installed
    system does not bring the VM back up normally/visibly. The VM
    appears to disappear or fail to return after shutdown/reboot.

-   **Important distinction:** Cold boot from the VM launcher works, so
    this is not currently evidence of a GRUB/initramfs/root-filesystem
    boot failure. The problem appears specific to the reboot path and
    may involve guest shutdown/reboot handling, QEMU launcher options,
    firmware/UEFI reset behavior, or the installed system's reboot
    mechanism.

-   **Investigation:** Determine whether QEMU exits completely on guest
    reboot, remains running but loses display/network, or resets and
    then fails during the next firmware/boot sequence. Inspect the
    launcher command line and QEMU log after reproducing the issue.

-   **Checks:** Review QEMU options such as `-no-reboot`,
    shutdown/reboot handling, background process supervision, SPICE
    lifecycle, UEFI/OVMF behavior, and whether the launcher
    intentionally exits when the guest requests reboot.

-   **Guest-side checks:** Inspect the previous boot journal
    (`journalctl -b -1`) after the next successful cold start for
    shutdown/reboot errors, and verify systemd reached the expected
    reboot target cleanly.

-   **Do not conflate with installer boot success:** The first cold boot
    already proved that GRUB, initramfs, LUKS, MD RAID, LVM, Btrfs,
    separate `/usr`, `/opt`, `/var`, `/home`, and EFI boot all work from
    a powered-off VM.

-   **Regression test:** Boot the installed VM, issue `reboot`, and
    confirm the same QEMU process successfully resets and returns to the
    BFSOS boot/login prompt without manually restarting the VM launcher.

## r48 Tracker Update

-   **Generated:** 2026-08-11
-   **Bootstrap implementation:** `bootstrap-r44-tracker-complete.sh`
-   **Installer implementation:**
    `install-bfs-menu-v50-tracker-fixed-r36.sh`
-   **Tracker status:** All currently listed code/configuration changes
    through issue 83 have been applied. Items whose final proof requires
    another install/reboot remain noted as regression tests even though
    the requested code change is implemented.
-   **Validation performed:** Both updated shell scripts pass `bash -n`.
    Static checks confirm the new bootstrap short-circuit/return
    behavior, installer theme labels, storage refresh hooks, sudo
    password default, Review -\> Ready flow, clean final exit, and ZRAM
    service/sizing changes.

### Bootstrap Stage 1/2 UTF-8 locale archive for temporary toolchain --- GCC 16.2 extraction blocker

-   [x] **ROOT CAUSE CONFIRMED / PERMANENT CODE FIX IMPLEMENTED;
    fresh-build regression pending (2026-08-18):** Bootstrap Stage 2 GCC
    16.2 extraction failed in temporary-toolchain `bsdtar` because
    temporary glibc lacked its own usable UTF-8 locale archive.
-   **Root cause:** Stage 2 is still using `/tmp/lfs-tools/bin/pkgmk`
    and `/tmp/lfs-tools/bin/bsdtar`. Those binaries use the temporary
    glibc in `/tmp/lfs-tools/lib/libc.so.6`, whose compiled locale paths
    point at `/tmp/lfs-tools/lib/locale/locale-archive` and
    `/tmp/lfs-tools/lib/locale`. Generating `C.utf8` only in the target
    rootfs `/usr/lib/locale/locale-archive` therefore does not make
    UTF-8 available to temporary-toolchain `bsdtar`.
-   **Observed proof:** Target `locale -a` reported `C.utf8` and target
    `LC_ALL=C.utf8 locale charmap` reported `UTF-8`, while
    temporary-toolchain `bsdtar` still reported
    `Failed to set default locale`.
    `strings /tmp/lfs-tools/lib/libc.so.6` confirmed its locale archive
    path is `/tmp/lfs-tools/lib/locale/locale-archive`.
-   [x] **Stage 1 permanent fix implemented:**
    `ports/core/glibc/Pkgfile` now generates the temporary toolchain
    `C.UTF-8` locale with the temporary `localedef` and validates
    `LC_ALL=C.utf8 ... locale charmap` before glibc bootstrap completes;
    `bootstrap.sh` verifies the archive exists and is usable before
    Stage 1 is archive-ready.
-   [x] **Stage 1 archive requirement implemented:** the normal
    toolchain archive includes `/tmp/lfs-tools`, and Stage 1 now
    explicitly rejects an archive that lacks
    `./tmp/lfs-tools/lib/locale/locale-archive`.
-   [x] **Stage 2 target-glibc fix implemented:** immediately after
    target glibc is installed, `bootstrap.sh` generates `C.UTF-8` with
    target `/usr/bin/localedef` and validates that target `C.utf8`
    reports `UTF-8` before continuing.
-   [x] **pkgmk environment policy implemented:** generated
    package-build configs/chroot calls no longer force plain C over
    `pkgmk` locale selection; non-package deterministic helper
    operations may still use C.
-   [x] **pkgmk detection hardening implemented in pkgutils release 10
    and initial-bootstrap patch:** locale selection now checks both
    locale enumeration and an actual `locale charmap` call, preferring
    the temporary-toolchain locale command when the running `pkgmk` is
    under `/tmp/lfs-tools`.
-   **Manual workaround result:** After generating the UTF-8 locale for
    the temporary toolchain, GCC 16.2 successfully extracted; the
    previous UTF-8 pathname errors disappeared. This confirms the
    locale-path/toolchain mismatch as the extraction failure's cause.
-   [x] **Regression test --- fresh Bootstrap 1 / effective runtime
    proof PASSED 2026-08-18:** the clean Stage 1 temporary toolchain
    proceeded into Stage 2 with the temporary UTF-8 locale fix in place;
    Stage 2 temporary-toolchain bsdtar subsequently extracted GCC 16.2
    successfully. The explicit archive-path check remains in Bootstrap
    code.
-   [x] **Regression test --- Bootstrap 2 PASSED 2026-08-18:** GCC 16.2
    extracted successfully during the clean Stage 2 run without the
    previous pathname-conversion failure.
-   [ ] **Regression test --- archive restore:** Restore a freshly
    created Stage 1 toolchain archive and repeat the temporary `bsdtar`
    UTF-8 test before beginning Stage 2.
-   [ ] **Regression test --- Stage 3/final system:** Verify the
    target/final `C.utf8` locale remains usable after glibc/pkgutils
    rebuild and final-system `bsdtar` can extract the GCC source without
    locale/pathname errors.

## r98 Tracker Update

-   **Generated:** 2026-08-19
-   **Scope:** Bootstrap/package infrastructure follow-up from the fresh
    Stage 2 rebuild, plus small bootstrap UI cleanup and
    installer-recovery notes observed during the same test cycle.
-   **Status policy:** Items that were fixed during this test are marked
    implemented/verified where the actual retry passed; follow-up
    hardening and UI-only items remain open until changed and
    regression-tested.

### 84. Distinguish bootstrap `AVAILABLE` visually from `COMPLETE`

-   [x] **IMPLEMENTED in bootstrap r59 / runtime visual regression
    pending --- UI cleanup**
-   **Area:** `bootstrap.sh` main-menu status colors
-   **Observed behavior:** `[AVAILABLE]` currently uses the same green
    status color as `[COMPLETE]`, so optional/repeatable actions can
    look finished rather than merely usable.
-   **Desired behavior:** Keep `[COMPLETE]` green, change `[AVAILABLE]`
    to a clearly different color such as cyan, keep `[PENDING]` red, and
    retain the existing exit/accent color for `[EXIT]`.
-   **Scope:** Apply the color distinction consistently to Stage 3,
    restore actions, Chroot, installer launch, and any other status that
    uses `AVAILABLE` in both Dialog and text-mode output where colors
    are supported.
-   **Semantics:** Do not change the already-defined meaning of
    `AVAILABLE`; this is only a visual distinction from `COMPLETE`.
-   **Regression test:** Exercise the bootstrap menu with a mix of
    completed, available, pending, and exit states and confirm no
    available action is rendered with the same green color as a
    completed stage.

### 85. `prt-utils` upstream archive download blocked by CRUX Anubis/login layer

-   [x] Packaging/source fix --- implemented and Stage 2 retry passed
-   **Area:** `ports/core/prt-utils`
-   **Observed failure:** The CRUX
    `git.crux.nu/tools/prt-utils/archive/...tar.gz` URL redirected to
    `/user/login` and ultimately returned HTML from the Anubis/login
    layer instead of a tar archive. `pkgmk` accepted the downloaded body
    and `bsdtar` later failed with `Unrecognized archive format`.
-   **Confirmed behavior:** Both the pinned-commit archive URL and the
    official `release-1.3.7.tar.gz` archive URL were affected, while a
    normal anonymous `git clone https://git.crux.nu/tools/prt-utils.git`
    still worked.
-   **Implemented workaround:** Vendor the verified
    `prt-utils-release-1.3.7.tar.gz` source directly under
    `ports/core/prt-utils/` and use it as a local port source instead of
    relying on the protected archive endpoint.
-   **Pkgfile cleanup:** Keep the port on the new automatic build path
    and retain only the `post_build()` action needed to create
    `$PKG/etc/revdep.d`; no package-specific `pkg_build()` is required
    for the normal Makefile build.
-   **Regression result:** After the pkgutils local-source detection fix
    in #86, Bootstrap Stage 2 successfully rebuilt `prt-utils` from the
    vendored archive.
-   **Follow-up:** Revisit the source location if CRUX restores
    anonymous archive access or provides a stable official mirror; do
    not depend permanently on a temporary third-party mirror.

### 86. pkgutils extension must build local/vendored archives without requiring a source-cache copy

-   [x] Core package-build fix --- implemented and verified by
    `prt-utils` Stage 2 retry
-   **Area:** `ports/core/pkgutils/extension`
-   **Root cause:** The generic build extension successfully let `pkgmk`
    extract a local port archive into its work tree, but
    source-directory detection later attempted to reopen the archive
    from `$PKGMK_SOURCE_DIR`. Local/vendored sources are not guaranteed
    to exist in `/var/cache/pkg/sources`, so `srcdir` became empty and
    automatic build-type detection ran one directory too high.
-   **Observed trace:** `prt-utils` extracted into the pkgmk work tree,
    then
    `bsdtar -tf /var/cache/pkg/sources/prt-utils-release-1.3.7.tar.gz`
    failed because that cache file did not exist; `detect_buildtype`
    therefore could not see `prt-utils/Makefile`.
-   **Implemented fix:** Source-directory detection now prefers the
    conventional `$name-$version` directory and otherwise inspects the
    already-extracted work tree. If exactly one top-level extracted
    directory exists, the extension enters it; if multiple top-level
    directories exist, it refuses to guess.
-   **Design rule:** Once `pkgmk` has already extracted the source, the
    extension should determine where the extracted source tree is rather
    than requiring knowledge of where the original archive was stored.
-   **Package revision:** `pkgutils` was bumped to `5.40.12-12` for the
    extension change.
-   **Regression result:** Bootstrap Stage 2 retried `prt-utils`,
    correctly entered the extracted `prt-utils/` directory, detected its
    Makefile, and completed the build.
-   **Future regression tests:** Test at least one normal downloaded
    `$name-$version` archive, one local archive whose top-level
    directory differs from `$name-$version`, and one deliberately
    multi-directory archive to verify the no-guess failure path.

### 87. Harden `pkgmk` download validation against HTML/login/error bodies masquerading as archives

-   [ ] Package-download hardening
-   **Area:** pkgutils / `pkgmk` source download path
-   **Observed behavior:** The CRUX Anubis/login response ultimately
    returned HTTP success with `Content-Type: text/html`, so the
    downloader treated the body as a successful `.tar.gz` source and
    only failed later during extraction.
-   **Desired behavior:** Fail at download/validation time when an
    archive URL resolves to a login/error/HTML response rather than a
    valid source archive. Preserve the URL and response context in the
    package log.
-   **Implementation options to review:** use curl failure handling for
    HTTP errors/redirect loops, inspect final response metadata where
    practical, and/or validate archive sources with `bsdtar -tf` before
    accepting them into the source cache.
-   **Safety:** Do not reject legitimate text sources/patches/scripts
    merely because they are text; validation should be source-type aware
    and strongest for archive extensions.
-   **Regression test:** Feed `pkgmk` an archive URL returning HTML with
    HTTP 200, an HTTP 404, a redirect to a login page, and a valid
    archive. The first three must fail during source acquisition with a
    clear message; the valid archive must continue normally.

### 88. Install the CRUX Git ports driver from the BFSOS `git` package

-   [x] Packaging fix implemented; installed-package regression pending
-   **Area:** `ports/opt/git`
-   **Background:** The remembered Git helper is a **ports repository
    driver**, not direct Git-source support for `pkgmk`/`prt-get`. CRUX
    installs it as `/etc/ports/drivers/git` from the Git package.
-   **Implemented change:** Add the CRUX `git` driver file to the BFSOS
    Git port sources and install it in `post_build()` with mode 0755 to
    `$PKG/etc/ports/drivers/git`.
-   **Package revision:** Git was bumped from release 1 to release 2 for
    the package-content change.
-   **Do not conflate:** This driver allows `ports` to use Git-backed
    ports repositories; it does not make arbitrary Pkgfile `source=()`
    entries clone Git repositories.
-   **Regression test:** Build/install the BFSOS Git package, verify
    `/etc/ports/drivers/git` exists and is executable, and test a
    disposable Git-backed ports collection without affecting the normal
    httpup collections.

### 89. Keep `prt-utils`, `prt-get`, `pkgutils`, and `ports` roles documented separately

-   [x] **DOCUMENTED in README during r121 --- Documentation /
    maintenance cleanup**
-   **Area:** package/ports architecture documentation
-   **Reason:** The similarly named packages are easy to confuse during
    maintenance.
-   **Document the roles:** `prt-utils` provides maintenance/helper
    utilities such as `revdep`; `prt-get` is the higher-level
    ports/package frontend; `pkgutils` provides lower-level
    `pkgmk`/`pkgadd`/package infrastructure; `ports` handles repository
    synchronization through drivers such as `httpup` and `git`.
-   **Goal:** Add a short architecture note to the
    ports/package-management documentation so future source/driver
    changes are made in the correct component.

### 90. Review `prt-utils` 1.3.7 changes after the emergency source fix

-   [x] **STATIC REVIEW COMPLETED in r106; installed-command runtime
    smoke test pending --- Package audit**

-   **Area:** `ports/core/prt-utils`

-   **Reason:** The immediate priority was restoring a reproducible
    Stage 2 build after the upstream archive endpoint became unusable.
    Because the package version changed, review the vendored source
    `CHANGES` file for updates to `revdep` and the other helper tools
    that may affect BFSOS integration.

-   **Checks:** Compare installed command set, any `revdep.d`
    expectations, configuration paths, dependency assumptions, and
    behavior changes against the previous BFSOS package.

-   **r106 review result:** Vendored `CHANGES` confirms 1.3.7 changes
    are maintenance/tooling updates: Markdown output for `portspage`,
    safer subshell sourcing in `dllist`, repository labeling in
    `prtcheckperms`, Cargo templates in `prtcreate`, whitelist updates
    in `prtverify`, and consolidated man-page documentation. No new
    runtime library path or mandatory service integration was
    identified. `/etc/revdep.d` remains required and BFSOS creates it.

-   **Current CRUX comparison:** CRUX also carries `prt-utils` 1.3.7 and
    installs `/etc/revdep.d`. BFSOS intentionally keeps the known-good
    1.3.7 source tarball vendored while the upstream Git archive
    endpoint is unreliable for non-browser package fetching.

-   **Regression test:** After installation, run the key `prt-utils`
    commands used by BFSOS maintenance and confirm expected
    output/paths.

### 91. Cold-resume installer should request LUKS passphrases after previous-install detection

-   [x] **IMPLEMENTED in r52-r57 / cold-recovery regression remains ---
    Installer recovery UX cleanup**
-   **Area:** cold-boot resume / storage reconstruction
-   **Observed behavior:** During a successful cold restore of a
    previous installation, the installer requested the LUKS passphrase
    before clearly presenting/detecting the previous-install resume
    state. The storage restore ultimately worked, but the prompt order
    felt backwards.
-   **Desired behavior:** First detect and explain that a previous
    incomplete/complete installation profile/storage stack was found,
    then tell the user which encrypted mappings need to be reopened, and
    only then request the required LUKS passphrase(s).
-   **Safety:** Do not weaken the existing non-destructive recovery
    logic; this is prompt ordering and context, not automatic passphrase
    storage or replay.
-   **Regression test:** Cold boot with a saved RAID/LUKS/LVM
    installation state, launch installer, verify previous-install
    detection appears before any passphrase request, unlock mappings,
    and confirm full storage recovery succeeds.

### 92. Revalidate installer cold-recovery status when the saved MD name differs from the kernel auto-assembled name

-   [x] Recovery bug fixed in current installer; keep regression
    coverage
-   **Area:** installer resume / MD identity
-   **Observed failure during earlier cold test:** Saved profile
    expected `/dev/md0`, while the live environment auto-assembled the
    same member set as `/dev/md127`. A naive resume attempt tried to
    assemble `/dev/md0` again and reported every member busy.
-   **Correct behavior:** Identify an already-active array by member/MD
    identity rather than requiring the saved transient `/dev/mdX` node
    name, then continue LUKS/LVM recovery without destructive
    reassembly.
-   **Regression result:** The subsequent installer revision
    successfully reconstructed the saved storage stack after cold boot.
-   **Regression test:** Repeat cold boot with kernel auto-assembly
    producing a different MD node name and confirm the installer
    recognizes/reuses the active array and reaches the installed target
    without reformatting or reassembling members destructively.

### 95. Show live LVM capacity information while creating PV/VG/LV layouts

-   [x] **IMPLEMENTED in installer r53; runtime regression pending ---
    Pre-1.0 LVM installer UX enhancement**
-   **Area:** storage configuration / LVM creation dialogs
-   **Priority:** Pre-1.0; medium priority
-   **Reason:** Advanced LVM layouts currently make it too easy to
    allocate storage without seeing the capacity context. This is
    especially noticeable with multiple PVs, one or more VGs, and
    multiple logical volumes.
-   **Desired PV display:** When selecting/creating physical volumes,
    show each selected PV/device and its usable size so the user can see
    how much storage is being contributed.
-   **Human-readable units:** All human-facing capacity values use
    automatically selected IEC units (`bytes`, `KiB`, `MiB`, `GiB`,
    `TiB`, etc.) rather than raw bytes or awkwardly huge MiB/GiB values.
-   **Desired VG display:** During VG creation and LV management, show
    the VG name, total size, allocated/used space, and remaining free
    space.
-   **Desired LV display:** Show existing logical volumes and their
    sizes while adding additional LVs. Before creating a new LV, clearly
    show the currently available VG free space.
-   **Size-expression UX:** If the installer supports values such as
    `%FREE`, `%VG`, or similar LVM percentage expressions,
    resolve/display the approximate resulting size before committing
    when practical.
-   **After-allocation feedback:** After an LV is created, refresh the
    displayed VG free-space value so subsequent allocations always use
    current information.
-   **Implementation note:** Prefer querying authoritative LVM state
    (`pvs`, `vgs`, `lvs` with machine-friendly output/units) rather than
    maintaining a separate installer-side capacity calculation when the
    LVM objects already exist.
-   **Scope for 1.0:** Keep this informational and low-risk. PV sizes,
    VG total/free/used capacity, existing LV sizes, and current
    remaining capacity are required; graphical capacity bars and other
    cosmetic visualization can wait until after 1.0.
-   **Regression tests:** Create an LVM layout using two PVs in one VG
    and several LVs; verify PV sizes are displayed correctly, VG
    total/free values update after every LV creation, existing LV sizes
    remain visible, and the installer prevents/handles an allocation
    larger than the remaining VG capacity cleanly.

### 104. Pre-1.0 full `ports/core` audit against current MLFS development, upstream, CRUX, and LFS/BLFS

-   \[\~\] **AUDIT STARTED in r106 --- Pre-1.0 package audit / core
    ports refresh**
-   **Area:** all BFSOS `ports/core` packages and their build
    instructions, patches, dependencies, source URLs,
    checksums/signatures, footprints, and installed integration.
-   **Reason:** Core has changed substantially during recent
    toolchain/base work. Before 1.0, perform a fresh package-by-package
    audit rather than assuming earlier LFS/CRUX comparisons are still
    current.
-   **Reference hierarchy:** use current **MLFS development** as the
    primary BFSOS multilib/toolchain/build-method reference; verify
    current release/security/build requirements against each package's
    authoritative upstream project; compare current CRUX core as an
    additional distro/package-layout reference; use ordinary LFS/BLFS
    development as secondary cross-checks where useful.
-   **For every core port, record/check:**
    -   BFSOS version/release versus current LFS/BLFS development, CRUX,
        and upstream stable/current appropriate release.
    -   Source URL availability and whether a more canonical/stable
        upstream URL exists.
    -   Required upstream/LFS/BLFS/CRUX patches and whether BFSOS
        carries obsolete, missing, or locally unnecessary patches.
    -   Configure/CMake/Meson/build flags and install commands against
        current upstream and LFS/BLFS guidance.
    -   Dependencies, optional dependencies intentionally
        enabled/disabled, bootstrap ordering, and circular-dependency
        risks.
    -   Correct BFSOS package naming, especially Python 3/module naming
        and other previously standardized conventions.
    -   Pkgfile archive-extension/source-directory handling and
        compatibility with current BFSOS pkgutils behavior.
    -   Installed files, symlinks, compatibility links, service/unit
        files, configuration defaults, permissions, ownership, and
        `.footprint` correctness.
    -   Security-relevant or ABI-impacting version changes that require
        rebuilds of dependent packages.
    -   Any CRUX-specific behavior BFSOS intentionally differs from;
        document the reason rather than blindly copying CRUX.
-   **Audit policy:** MLFS development is the primary
    multilib/build-method reference but is not a command to downgrade
    newer deliberate BFSOS maintenance releases. Upstream is
    authoritative for current releases/security/build requirements; CRUX
    and ordinary LFS/BLFS are comparison implementations. Preserve
    deliberate BFSOS design choices and document deviations.
-   **Current-reference note (2026-08-19):** MLFS development is
    continuously updated and must be read live at audit time. Current
    MLFS lists Linux 7.1.8 and explicitly permits the latest available
    stable kernel unless errata says otherwise. CRUX exposes its current
    core Pkgfiles for direct comparison. Re-check live versions at each
    audit pass instead of trusting search-index snapshots.
-   **Deliverable:** produce a package-by-package audit table/checklist
    showing BFSOS version, reference versions, source/patch/build
    differences, action required, and regression status. Apply changes
    in controlled batches so a bad update can be isolated.
-   **Regression:** after changes, perform a clean Bootstrap 1/2/3/base
    build, run package/footprint verification, boot a fresh base, and
    exercise installer-critical packages before declaring the audit
    complete.

### 105. Make installer elapsed/duration displays human-readable

-   [x] **IMPLEMENTED in installer r53 / pkgutils release 13; runtime
    regression pending --- Installer UX cleanup**
-   **Area:** install/build progress, completion summaries,
    package/build timing, and any other duration display
-   **Observed behavior:** Long-running operations can still display raw
    seconds such as `2841s`, which is difficult to read at a glance.
-   **Desired behavior:** Convert durations to a compact human-readable
    form throughout the installer rather than displaying large raw
    second counts.
-   **Examples:** `42s`; `4m 12s`; `47m 21s`; `1h 18m 09s`; include days
    if an operation ever exceeds 24 hours.
-   **Consistency:** Use one shared duration-formatting helper so
    progress screens, package/build summaries, final installation
    summaries, logs intended for humans, and other installer UI do not
    each format elapsed time differently.
-   **Precision:** Seconds-only is fine for short operations. For longer
    operations, show hours/minutes/seconds as appropriate without
    unnecessary zero-value units.
-   **Machine data:** Do not change machine-readable timestamps or raw
    timing values that scripts rely on; this requirement applies to
    human-facing output.
-   **Regression test:** Exercise short and long durations, including a
    value equivalent to `2841s`, and confirm it is rendered as `47m 21s`
    (or an equally clear consistent human-readable form) everywhere the
    installer presents elapsed time.

## r108 ports Git-sync architecture correction --- 2026-08-19

-   [x] **DESIGN CORRECTED AND IMPLEMENTED in r121 / live migration +
    repeated network sync regression PASSED 2026-08-22:**
    `https://codeberg.org/bmadonnaster/BFS-Linux.git` currently exposes
    only one branch, `main`. The BFSOS port collections are directories
    under that single branch rather than separate Git branches. Do not
    design `/etc/ports/*.git` around non-existent per-collection
    branches.
-   **Current repository layout assumption:** one Git repository / one
    `main` branch / multiple collection directories such as
    `ports/core`, `ports/opt`, `ports/xorg`, `ports/xfce`,
    `ports/plasma`, etc.
-   **Preferred maintenance direction:** Prefer retaining the
    single-branch multi-directory repository layout unless a
    stock-CRUX-compatible solution proves impractical. Separate branches
    per collection would significantly increase maintainer burden for
    cross-collection updates, auditing, dependency moves, and
    coordinated commits.
-   **Required design investigation:** Determine whether the CRUX Git
    ports driver can cleanly map one repository checkout to multiple
    collection subdirectories. If not, evaluate a small BFSOS
    extension/wrapper that performs one Git fetch/pull and exposes the
    corresponding `ports/<collection>` directories as the normal
    `/usr/ports/<collection>` trees while preserving `ports -u` as the
    user-facing command.
-   **Avoid duplicate clones:** Do not clone the same large repository
    once per collection merely to satisfy ten `/etc/ports/*.git` entries
    unless no cleaner approach exists.
-   **Target user experience:** `ports -u` remains the normal command.
    Internally, BFSOS should synchronize the single Codeberg repository
    efficiently and update all configured BFSOS collections without the
    current HttpUp per-file failure mode.
-   **Git/base policy remains:** Git still belongs in the BFSOS base
    package set and should be removed from the installer
    optional-package list once the Git-backed ports sync path is
    implemented and validated.
-   **HttpUp compatibility:** Keep HttpUp support available for
    third-party collections that still use it; migrate BFSOS-owned
    collections away from HttpUp-specific `REPO`, `.httpup-*`, and
    `httpup-repgen` maintenance once the Git path is proven.
-   **Decision deferred:** Do not restructure the Codeberg repository
    into separate branches yet. Revisit only if the stock driver
    limitations make the single-branch architecture unreasonably
    complex.
-   **Regression tests:** (1) fresh system with Git in base can run
    `ports -u`; (2) one repository update refreshes all BFSOS collection
    directories; (3) no collection is cloned redundantly; (4) a failed
    network sync leaves the previous ports tree intact; (5) third-party
    HttpUp collections still update normally.
-   **Live existing-system migration result --- PASSED 2026-08-22:** An
    installed BFSOS VM with the ten legacy `/etc/ports/*.httpup`
    definitions and Git 2.55.0 successfully migrated to the single BFSOS
    Git monorepo configuration. `ports -u` fetched the Codeberg
    repository and populated all configured collections; `pkgutils` and
    Git upgraded successfully, and after resolving the package-ownership
    edge case `prt-get` upgraded to 5.19.9-3 and `prt-get sysup`
    reported the system up to date.
-   **Migration ownership edge case discovered:** Manually
    pre-installing `/etc/ports/bfsos.git` before upgrading the `prt-get`
    package caused `pkgadd` to refuse the update because `prt-get` now
    owns that path. Migration/update logic must avoid creating an
    unowned `bfsos.git` before the owning package is installed/upgraded,
    or explicitly move/handle the legacy copy first.
-   **Git manifest false-positive discovered and FIX VERIFIED live:**
    Normal `pkgmk` builds create `.md5sum` and `.footprint` files inside
    port directories. The original Git-driver manifest hashed every
    file, so a subsequent `ports -u` incorrectly reported
    `Local modifications detected in /usr/ports/core` after ordinary
    package builds. Update `manifest_tree()` to exclude generated
    `.md5sum` and `.footprint` files while continuing to protect real
    source/Pkgfile/patch/script edits. With those generated files
    intentionally left in place, `ports -u` completed with no errors
    after the exclusion fix, confirming the regression fix.
-   **Repeated-sync regression --- PASSED:** After applying the manifest
    exclusion fix, repeated `ports -u` operation completed without
    local-modification errors. Keep this as a required regression test
    for RC1.

## r109 UI status-color consistency --- 2026-08-20

-   [x] **FIX VERIFIED LIVE in Bootstrap after Stage 2 (2026-08-22);
    installer consistency remains covered separately: make `[AVAILABLE]`
    visually distinct from `[COMPLETE]`.**
    -   Current bootstrap menu displays `[AVAILABLE]` in green, the
        same/similar success color used for `[COMPLETE]`, which makes an
        available-but-not-run action look completed at a glance.
    -   Change `[AVAILABLE]` to a **bright, high-visibility color that
        is not green**.
    -   Apply the same status-color rule consistently to **both
        `bootstrap.sh` and the BFSOS installer** anywhere `[AVAILABLE]`
        or an equivalent available/ready state is shown.
    -   Preserve green for `[COMPLETE]` / successful-completion states.
    -   Preserve red for `[PENDING]` where currently used.
    -   Verify readability with the installer/bootstrap dialog theme and
        selected-row highlighting.
    -   Audit both scripts for all status rendering paths so
        `[AVAILABLE]` cannot fall back to green in another menu or
        refresh state.
    -   **Live Bootstrap regression PASSED (2026-08-22):** menu showed
        `[COMPLETE]` in green, `[AVAILABLE]` in a distinct
        yellow/high-visibility color, `[PENDING]` in red, and `[EXIT]`
        distinctly after Bootstrap Stage 2 completed.

## r110 LUKS device-selection duplicate JBOD/MD device --- 2026-08-20

-   [x] **FIX IMPLEMENTED in installer r54 / runtime regression pending:
    LUKS block-device selector listed the same Linear/JBOD md device
    multiple times.**
    -   Reproduced during live installer testing after creating a
        Linear/JBOD array.
    -   In **Create LUKS container → Select the block device**,
        `/dev/md0 1.5T linear` is displayed repeatedly (six entries in
        the observed test) even though it is one block device.
    -   Expected: each eligible block device appears **exactly once**.
    -   Audit the device-discovery/aggregation code for duplicate
        enumeration of md/Linear/JBOD devices, including any loops over
        component disks, `lsblk`, `/proc/mdstat`, `mdadm`, or cached
        installer device lists.
    -   Deduplicate by canonical block-device path before building the
        dialog menu, while retaining the correct size/type/status
        metadata.
    -   Verify the fix for **Linear/JBOD and all supported md RAID
        levels**, since the underlying enumeration bug may not be
        Linear-specific.
    -   Regression test layered storage flows: md/Linear → LUKS, md/RAID
        → LUKS, and selection after returning/re-entering the LUKS menu.

## r111 Users & Groups review UI cleanup --- 2026-08-20

-   [x] **IMPLEMENTED in installer r54 / runtime regression pending:
    improve the Users & Groups review dialog layout.**
    -   Current review contains the needed information, but account
        details are presented as a dense text block and are harder to
        scan than necessary.
    -   Give the **Primary account** and **Additional accounts** clear
        visual sections/separators.
    -   Render every account with a consistent field layout,
        e.g. `User`, `Type`, `Groups`, `Password`, and `Login` where
        applicable.
    -   Wrap long group lists cleanly beneath the `Groups:` field
        instead of allowing the review to look like an unstructured
        paragraph.
    -   Keep wording concise while preserving important distinctions
        between Standard users and System/service accounts.
    -   Consider a compact right-side account status/type marker such as
        `[STANDARD]` / `[SYSTEM]` if it fits cleanly with the existing
        dialog theme.
    -   Verify layout at the installer's supported terminal sizes and
        with long usernames/group lists.
-   [x] **FIX IMPLEMENTED in installer r54 / runtime regression pending:
    remove stray encoding/control-character garbage from account
    review.**
    -   Live testing shows `~@~T`-style garbage between
        additional-account usernames and their account type (observed
        for `user2` and `sys`).
    -   Audit any Unicode punctuation/dash characters and text passed
        through shell/dialog formatting.
    -   Prefer safe plain-text/ASCII separators where appropriate so the
        review renders correctly under the Gentoo Live environment and
        BFSOS console locale.
    -   Verify Primary and Additional account rows render without
        mojibake/control-character artifacts.

## r112 Dialog theme persistence across new installer screens --- 2026-08-20

-   [x] **FIX IMPLEMENTED in installer r54 / runtime regression pending:
    newly added Dialog screens retain the currently selected installer
    theme.**
    -   Live testing of the new account/password dialogs shows they fall
        back to a different/default Dialog appearance instead of
        inheriting the theme previously selected in the installer.
    -   This applies to the new **System Settings**, **Users and
        Groups**, account/password, LVM-capacity, review, confirmation,
        and any other newly added dialogs introduced in recent installer
        revisions.
    -   Expected behavior: once the user selects an installer theme,
        every subsequent Dialog invocation in that installer session
        must use the same theme consistently until the user explicitly
        changes it.
    -   Audit helper functions and direct `dialog` invocations for
        missing `DIALOGRC`, environment propagation, `--colors`,
        backtitle/title options, or alternate execution paths that
        bypass the normal themed-dialog wrapper.
    -   Prefer routing all Dialog calls through the same shared
        helper/environment so new screens cannot silently fall back to
        the stock theme.
    -   Theme selection/state should also survive normal menu navigation
        and installer profile/resume behavior wherever theme persistence
        is already intended.
    -   Regression tests: choose each available theme, open the new
        password/account dialogs and all newly added System
        Settings/LVM/review screens, navigate Back/Cancel/re-enter
        paths, and confirm the selected theme remains visually
        consistent throughout.

## r113 account-name/group collision + failure-result logging --- 2026-08-20

-   [x] **FIX IMPLEMENTED in installer r54 / runtime regression pending:
    account creation must reject a username that collides with an
    existing group name.**
    -   Live test created a System/service account named `sys`.
    -   BFSOS already has an existing `sys` group, so `useradd` failed
        with:
        `group sys exists - if you want to add this user to that group, use -g.`
    -   Because System/service accounts default to a private primary
        group, a username whose same-named group already exists cannot
        satisfy that policy automatically.
    -   Validate proposed usernames against **both existing usernames
        and existing group names** before saving account configuration
        or entering the install transaction.
    -   For the default private-group policy, reject such collisions
        with a clear Dialog message explaining that the account name
        conflicts with an existing group and asking for another
        username.
    -   Do not silently reuse the pre-existing group unless the
        installer gains an explicit advanced option for that behavior.
    -   Apply the same validation to the primary Standard user and
        additional Standard users because `useradd -m -U`/private-group
        creation can hit the same collision.
    -   Regression tests: attempt usernames matching built-in groups
        such as `sys`, `bin`, `audio`, `wheel`, etc.; verify the
        installer blocks them before installation. Verify a
        non-conflicting Standard and System/service account both create
        successfully.
-   [x] **FIX IMPLEMENTED in installer r54 / runtime regression pending:
    installer session log footer must not report SUCCESS / exit 0 after
    a caught installation failure.**
    -   The live run displayed `Installation operation failed` with exit
        status `9`, and the chroot log shows `useradd` failed followed
        by `Installer exited.`
    -   Despite that, the installer log footer incorrectly recorded:
        `Result: SUCCESS` `Exit status: 0`
    -   Failure/session status propagation is still inconsistent on this
        path.
    -   Ensure any chroot/configuration/install-operation failure
        records the actual nonzero status in the final session result
        unless a later retry fully succeeds and explicitly clears the
        failure state.
    -   Keep the Dialog-reported failure status, internal session
        failure flag, shell exit status, and final log footer
        consistent.
    -   Regression test: intentionally trigger an account-creation
        failure, return to the menu, quit without retrying, and verify
        the final log says FAILURE with the original/nonzero status.
        Then retry successfully and verify a completed session may
        legitimately finish SUCCESS/0.

## r124 pkgmk tmpfs build-work cleanup bug --- 2026-08-22

-   \[\~\] **PRE-RC1 FIX REQUIRED: preserve the mounted
    `/var/cache/pkg/build-work` tmpfs mountpoint during package
    cleanup.**
    -   Live BFSOS VM testing repeatedly prints:
        `rm: cannot remove '/var/cache/pkg/build-work': Device or resource busy`
        during otherwise successful package builds/updates.
    -   Confirmed with `findmnt` that `/var/cache/pkg/build-work` is
        itself an active `tmpfs` mount
        (`rw,nosuid,nodev,...,size=16777216k,mode=775,uid=82,gid=82`).
    -   Root cause: a BFSOS/pkgmk cleanup path is attempting to remove
        the **mounted directory itself** (equivalent to
        `rm -rf /var/cache/pkg/build-work`) rather than only deleting
        the contents of the mounted workspace.
    -   Required behavior: when `build-work` is an active mountpoint,
        cleanup must remove files/directories *inside* the workspace
        while preserving the mountpoint. Do not unmount/recreate the
        tmpfs merely to perform routine per-package cleanup.
    -   Audit `pkgutils`/`pkgmk`, BFSOS wrappers, `bootstrap.sh`, and
        related cleanup helpers for `rm -rf` operations targeting
        `build-work` or the configured package work directory.
    -   Cleanup must include normal and hidden entries without
        attempting to remove `.`/`..`, and must remain safe if the
        workspace is not mounted or is already empty.
    -   Regression test: build/update several packages consecutively
        with the tmpfs workspace mounted; confirm package cleanup
        succeeds with **no `Device or resource busy` warning**, the
        tmpfs remains mounted, and no stale build contents leak into the
        next package build.
    -   This is currently noisy rather than build-blocking (observed
        package builds still succeeded), but it should be fixed before
        BFSOS 1.0-rc1.

## r125 base package policy --- rsync --- 2026-08-22

-   \[\~\] **PRE-RC1 BASE UPDATE: add `rsync` to the BFSOS
    Bootstrap/base package set.**
    -   Live installed-VM testing confirmed `rsync` was available in the
        ports tree but was not installed by default in the existing
        BFSOS base.
    -   `rsync` is considered sufficiently useful for normal system
        administration, recovery, migration, backup, diagnostics, and
        BFSOS maintenance workflows to be part of the base rather than
        an installer-only optional package.
    -   Add `rsync` to the Bootstrap/base package list before producing
        the next canonical base/rootfs archive.
    -   Do not add a redundant installer optional-package prompt once
        `rsync` is guaranteed by the base.
    -   Regression test: create a fresh base/rootfs archive and fresh
        install, then verify `command -v rsync` and `rsync --version`
        succeed without installing any optional packages.

## r126 pre-1.0 ISO delivery + text-browser installer options --- 2026-08-22

-   [ ] **PRE-1.0 RELEASE DELIVERY GOAL: provide a BFSOS
    installation/live ISO before BFSOS 1.0 final if practical.**
    -   Keep the current external-live-environment workflow usable
        during development, but add a first-party BFSOS ISO so users do
        not need to obtain and boot a separate Gentoo LiveGUI image
        merely to install BFSOS.
    -   The ISO should carry or provide straightforward access to the
        BFSOS installer, required installation/storage tools,
        networking, SSH, package/ports tooling needed for
        installation/recovery, and enough diagnostics to troubleshoot
        boot/storage failures.
    -   Prefer reusing the existing Bootstrap/installer logic rather
        than creating a second independent install implementation for
        ISO media.
    -   Preserve both graphical/local-console and serial-console
        troubleshooting paths where practical.
    -   Define how the ISO obtains the base rootfs used by the
        installer: embedded release archive, downloadable archive, or
        another deterministic release-artifact path. Avoid requiring a
        development checkout merely to perform a normal release install.
    -   ISO work should not destabilize the currently validated
        installer/storage stack immediately before RC1; stage it as
        release-packaging/delivery work around the RC cycle.
    -   Regression targets: BIOS and UEFI boot where supported,
        networking, SSH access, installer launch, storage tools, loading
        the release base archive, completing an install, and booting the
        installed BFSOS system.
-   \[\~\] **INSTALLER OPTIONAL PACKAGES: add `lynx` and `links` as
    optional text-mode web browsers.**
    -   Expose both independently in the installer optional-package
        selection; do not make either browser a required base dependency
        solely for ordinary BFSOS installation.
    -   Keep the package names and descriptions distinct so users can
        choose Lynx, Links, both, or neither.
    -   Include them in final optional-package review and normal
        dependency-aware installation via `prt-get`.
    -   Verify each selected browser installs and launches successfully
        on a fresh system after `ports -u`/package synchronization.

## r127 installer/base-archive source-cache retention option --- 2026-08-22

-   \[\~\] **INSTALLER SETTINGS / BUILD-ARTIFACT OPTION: optionally
    preserve downloaded source archives inside the generated BFSOS
    base/rootfs archive.**
    -   Add a persisted Installer Settings toggle such as **Keep package
        source archives in base archive**, default **off** for
        normal/release-size builds and optionally enabled for
        development/testing builds.
    -   When enabled, copy the already-downloaded package source
        tarballs/files into the installed system's normal pkgmk
        source-cache location before the base/rootfs archive is created.
    -   Use the same canonical source-cache path that installed
        BFSOS/pkgmk uses for future downloads (currently
        `/var/cache/pkg/sources` unless the package-cache policy
        changes), rather than inventing a second source directory.
    -   Preserve filenames and usable permissions/ownership so later
        `pkgmk`, `prt-get`, installer package operations, and regression
        builds can reuse the cached sources without downloading them
        again.
    -   Do not copy temporary build trees, extracted source directories,
        package work directories, or completed binary packages as part
        of this option; the intent is specifically to retain reusable
        source archives/distfiles.
    -   Avoid duplicating source files already present in the target
        cache and ensure the archive-creation step reports the
        additional source-cache size so large development archives are
        not created accidentally.
    -   Include the selected state in final review/logging so it is
        obvious whether a generated base archive is a compact
        release-style archive or a development/test archive containing
        source distfiles.
    -   Regression test: enable the option, create a fresh base/rootfs
        archive, inspect `/var/cache/pkg/sources` inside the archive,
        install from it, then build/update representative packages with
        networking disabled or source URLs unavailable and confirm
        cached sources are reused.
    -   Release policy: official compact release archives may keep this
        disabled by default; development/testing archives can enable it
        to reduce repeated downloads and speed installer/package
        regression cycles.

## r128 bootstrap/installer non-interactive CLI interface --- 2026-08-22

-   [ ] **PRE/POST-RC CLI USABILITY: every major Bootstrap and installer
    operation should be invokable without entering the Dialog/text
    menus.**
    -   Preserve the current interactive menu UX as the default when no
        command-line action is supplied.
    -   Add a complete command-line interface to both `bootstrap.sh` and
        the current BFSOS installer so users, developers, CI, test
        harnesses, and automation can invoke supported actions directly.
    -   Both programs must provide `--help` (and preferably `-h`)
        describing available actions, options, accepted values,
        defaults, examples, and exit-status behavior.
    -   Support stable named options/subcommands for major operations;
        numeric aliases may also be provided where useful for parity
        with menu numbering, but automation should not depend solely on
        menu presentation/order.
    -   Bootstrap CLI targets should cover the same meaningful actions
        exposed by the menu, including toolchain build/restore, base
        build stages, verification, archive creation/restoration,
        chroot, installer launch, cleanup/reset operations, and relevant
        build/settings overrides.
    -   Installer CLI targets should cover configuration and execution
        actions exposed by the installer, including storage/profile
        input, base archive selection, system settings, optional
        packages, bootloader settings, installation/retry, recovery
        where safe, chroot/inspection, logging/output controls, and
        future utility actions such as ISO creation.
    -   **ISO builder CLI requirement:** the future standalone BFSOS ISO
        creation script (for example `bfs-build-iso.sh`) must itself
        support `--help`/`-h` and non-interactive switches rather than
        being usable only through Installer Settings. At minimum expose
        explicit options for selecting the base/rootfs archive,
        kernel/initramfs/release inputs where applicable, output
        path/name, included installer/version, optional source-cache
        inclusion, and the build/start action.
    -   The Installer Settings -\> **Build BFSOS ISO** entry should act
        as a frontend to the same ISO-builder script/CLI, not maintain a
        second ISO-generation implementation. Interactive and
        command-line ISO creation must therefore share the same
        validation, defaults, artifact-generation logic, logging, and
        exit statuses.
    -   ISO CLI regression: verify `bfs-build-iso.sh --help`, build an
        ISO entirely from switches without entering a menu, reject
        missing/invalid required inputs cleanly, return meaningful
        nonzero status on failure, and confirm the Installer Settings
        frontend produces the same artifact path/content for equivalent
        settings.
    -   Configuration values supplied on the command line must pass
        through the same validation/helpers used by the interactive UI;
        do not maintain a second independent validation implementation
        that can drift from Dialog behavior.
    -   Allow useful non-interactive combinations such as
        `--action <name>` plus explicit `--option value` settings,
        profile/config-file input where appropriate, and a deliberate
        `--yes`/assume-confirmation mechanism only for operations that
        are safe to automate.
    -   Destructive storage actions must retain strong safeguards.
        Non-interactive mode must require explicit
        target/topology/confirmation data and must never infer
        permission to wipe or format disks merely because a CLI action
        was requested.
    -   Commands should return meaningful, documented nonzero exit
        statuses on validation, download, build, storage, install, or
        bootloader failures so scripts/CI can distinguish success from
        failure without scraping UI text.
    -   Provide machine-readable or plain-text output modes where
        practical so automated tests do not depend on Dialog escape
        sequences or screen rendering.
    -   Maintain backward compatibility with normal interactive
        invocation: running `./bootstrap.sh` or the installer with no
        action switches should continue to open the current menu
        interface.
    -   Regression matrix: compare interactive and CLI execution of
        representative non-destructive actions; run each Bootstrap stage
        directly by CLI; perform a fully specified disposable-VM
        installer run without menu navigation; verify `--help`; verify
        invalid options fail clearly; verify Ctrl-C/nonzero subprocess
        failures propagate correctly; verify destructive actions refuse
        to proceed when required explicit confirmation/targets are
        absent.

## r131 Bootstrap verification status contrast --- 2026-08-22

-   \[\~\] **UI COLOR FIX: make Bootstrap `[PASSED!]` verification
    status more visually distinct/high-contrast.**
    -   Live testing after successful Stages 1, 2, and optional Stage 3
        showed Stage 4 verification as `[PASSED!]` in orange/brown on
        the cyan Dialog background.
    -   The current orange/brown does not stand out sufficiently from
        the background or neighboring status colors.
    -   Change `[PASSED!]` to a high-contrast status color;
        **bright/bold white is the preferred candidate** with the
        current palette.
    -   Preserve the established status distinctions: `[COMPLETE]`
        green, `[AVAILABLE]` yellow/high-visibility, `[PENDING]` red,
        and `[EXIT]` separately distinguishable.
    -   Apply the change consistently anywhere Bootstrap renders a
        successful verification/pass state, including text-mode output
        where applicable.
    -   Regression test on the actual Bootstrap menu after Stage 4
        passes and confirm `[PASSED!]` is immediately distinguishable
        from COMPLETE, AVAILABLE, PENDING, and EXIT states and remains
        readable on selected/unselected rows.

## r132 Bootstrap installer auto-selection by newest timestamp --- 2026-08-22

-   \[\~\] **BOOTSTRAP INSTALLER DISCOVERY: stop relying on
    `scripts/install-bfs-menu-current.sh` symlink for normal installer
    launch.**
    -   When Bootstrap launches the BFSOS installer, discover the real
        versioned installer scripts matching the supported naming
        pattern (for example `scripts/install-bfs-menu-v50-*.sh`) and
        automatically select the newest usable file.
    -   Prefer the installer with the newest filesystem modification
        date/time. Use a deterministic secondary sort such as filename
        if timestamps are identical.
    -   Validate that the selected candidate is a regular readable shell
        script and passes a lightweight syntax check (`bash -n`) before
        launching it.
    -   Do not allow a stale, broken, or incorrectly pointed
        `install-bfs-menu-current.sh` symlink to cause Bootstrap to
        launch an older installer revision.
    -   The `install-bfs-menu-current.sh` symlink may remain as a
        developer convenience/backward-compatibility alias, but
        Bootstrap should not depend on it for installer selection.
    -   Show/log the exact installer path, filename, and modification
        timestamp selected so test logs make it obvious which revision
        actually ran.
    -   If the newest candidate fails validation, report that candidate
        clearly and either fall back to the next-newest valid installer
        with an explicit warning or refuse to launch; do not silently
        run an unexpected revision.
    -   Regression test: create multiple installer revisions with
        different modification times, point
        `install-bfs-menu-current.sh` at an older revision (and
        separately make it broken), then verify Bootstrap still selects
        and launches the newest valid real installer script.
    -   This refines the earlier tracker requirement that Bootstrap
        discover the newest versioned installer instead of hard-coding a
        filename; the selection rule is now explicitly **newest
        modification date/time**, independent of symlink state.

## r133 installer MD reset discovery + bootstrap newest-installer selection --- 2026-08-22

-   [x] **IMPLEMENTED in installer r60 --- deterministic active-MD
    metadata wipe discovery.**
    -   Runtime regression on the six-member Linear/JBOD test array
        proved installer r59 still displayed
        `No safe unmounted storage candidates were found` even though
        `/dev/md127` was active and `wipefs -n /dev/md127` showed two
        `crypto_LUKS` signatures.
    -   Confirmed environment: `/dev/md127` is visible under
        `/sys/class/block/md127/md`, the BFSOS project filesystem is
        `/dev/vdh1`, and the live environment is not backed by
        `/dev/md127`.
    -   r60 snapshots all active MD arrays and their member devices
        **before** upper storage layers are unwound.
    -   Active MD arrays are then added explicitly to the destructive
        checklist when they are safe/unmounted and expose wipeable
        array-level metadata. Discovery no longer depends on
        `lsblk TYPE`, `/proc/mdstat` field layout, or a
        post-deactivation rescan.
    -   Active MD member partitions are suppressed while the array
        remains assembled. Selecting `/dev/mdX` wipes only array-level
        LUKS/LVM/filesystem signatures and does **not** zero member MD
        superblocks.
    -   If an active MD array is detected but rejected by every
        safe-candidate check, the empty-state dialog now names the
        detected array(s), making future rejection failures diagnosable
        instead of silently reporting no candidates.
    -   **Runtime regression:** with `/dev/md127` Linear/JBOD active and
        carrying the old LUKS signature, Destroy selected metadata must
        show `/dev/md127` as `Active MD array; crypto_LUKS`, must not
        show `/dev/vdb1`-`/dev/vdg1`, and wiping `/dev/md127` must leave
        the Linear array assembled with a blank FSTYPE/signature scan.
-   [x] **IMPLEMENTED in Bootstrap r60 --- launch newest real installer
    by filesystem modification timestamp.**
    -   Replaces version-like filename sorting with actual
        modification-time sorting of real
        `scripts/install-bfs-menu-v*.sh` files.
    -   `scripts/install-bfs-menu-current.sh` is explicitly excluded
        from normal discovery; it may remain only as a
        convenience/backward-compatibility symlink.
    -   Each candidate is validated with `bash -n` before selection. A
        syntactically broken newest candidate is reported and skipped in
        favor of the next-newest valid installer rather than silently
        launching it.
    -   Bootstrap logs/displays the exact selected installer path and
        its modification timestamp before handoff.
    -   Deterministic tie-break uses pathname ordering after
        modification time.
    -   **Regression:** point `install-bfs-menu-current.sh` at an older
        file and separately break/remove the symlink; Bootstrap must
        still choose the newest valid real installer by mtime.

## r134 Bootstrap PASSED status color correction --- 2026-08-22

-   [x] **IMPLEMENTED in Bootstrap r61 --- Stage 4 `[PASSED!]` is now
    bright/bold white.**
    -   Runtime UI check after Bootstrap r60 confirmed `[PASSED!]` was
        still orange/yellow.
    -   Root cause: Dialog `_dialog_verification_status()` still emitted
        `\\Z3PASSED!`, where Dialog color 3 is yellow, and text-mode
        rendering still used `$COLOR_YELLOW`.
    -   Dialog mode now emits bold white (`\\Zb\\Z7PASSED!\\Zn`) for
        Stage 4 verification success.
    -   Text mode now renders `PASSED!` as ANSI bold white.
    -   Existing meanings remain unchanged: green = `COMPLETE`, yellow =
        `AVAILABLE`, red = `PENDING`/unavailable.
    -   **Runtime regression:** after Stage 4 has passed, verify
        `[PASSED!]` is clearly bright white on the Slackware cyan menu
        and remains distinct from green COMPLETE and yellow AVAILABLE.

## r135 Filesystem plan / Continue screen consolidation --- 2026-08-22

-   \[\~\] **INSTALLER UI: put the filesystem plan and Continue action
    on the same Dialog screen.**
    -   Current workflow separates reviewing the filesystem plan from
        the action used to continue the installation, creating an
        unnecessary extra screen/navigation step.
    -   Desired workflow: the filesystem-plan screen should display the
        complete configured filesystem/mount-point plan and provide the
        action to continue directly from that same screen.
    -   Keep Back/Edit behavior available so the user can return to
        filesystem assignments when something in the plan needs
        changing.
    -   Do not add another confirmation/menu screen merely to continue
        after the plan has already been reviewed.
    -   Preserve existing filesystem-plan validation and storage safety
        checks before allowing Continue.
    -   This complements the existing single multi-entry filesystem
        assignment workflow: assignment/editing remains the
        configuration step, while the resulting plan and Continue
        control are consolidated into one review screen.
    -   **Regression test:** configure the filesystem assignments,
        finish the assignment workflow, verify the complete filesystem
        plan is shown with Continue available on that same screen, and
        confirm proceeding does not require a second standalone Continue
        screen.

## r136 pkgutils/pkgmk.conf authoritative BFSOS defaults --- 2026-08-22

-   [x] **IMPLEMENTED in project consolidation r138 --- PKGUTILS
    CONFIGURATION: make the packaged `/etc/pkgmk.conf` the authoritative
    permanent BFSOS default instead of relying on Bootstrap to repair it
    afterward.**
    -   Current `ports/core/pkgutils/pkgmk.conf` ships the three
        cache/work directory settings commented out even though the
        pkgutils Pkgfile installs that file directly as
        `$PKG/etc/pkgmk.conf`.

    -   Activate these permanent BFSOS defaults in
        `ports/core/pkgutils/pkgmk.conf`:

        ``` bash
        PKGMK_SOURCE_DIR="/var/cache/pkg/sources"
        PKGMK_PACKAGE_DIR="/var/cache/pkg/packages"
        PKGMK_WORK_DIR="/var/cache/pkg/build-work/pkgmk-$name"
        ```

    -   Update the pkgmk internal/script fallback patched by
        `ports/core/pkgutils/Pkgfile` to use the same per-package work
        path:

        ``` bash
        PKGMK_WORK_DIR="/var/cache/pkg/build-work/pkgmk-$name"
        ```

        rather than the shared `/var/cache/pkg/build-work` directory.

    -   Bump the `pkgutils` port release so installed BFSOS systems
        receive the corrected package/configuration behavior through a
        normal package update.

    -   Keep permanent final-system pkgmk policy owned by the pkgutils
        port. Bootstrap Stage 1/2/3 may continue generating temporary
        bootstrap-specific pkgmk configuration where required.

    -   Remove or reduce Bootstrap's final-system `PKGMK_WORK_DIR`
        rewrite/repair block to a validation check once pkgutils ships
        the authoritative setting, avoiding policy duplication across
        the port, pkgmk fallback, and Bootstrap.

    -   Preserve `/var/cache/pkg/build-work` as the parent tmpfs/mount
        point only; individual package builds must operate below it in
        `pkgmk-$name` work directories.

    -   This also addresses the observed failure
        `rm: cannot remove '/var/cache/pkg/build-work': Device or resource busy`:
        pkgmk must never treat the mounted parent work directory itself
        as the removable per-package build directory.

    -   Audit the installed `/etc/pkgmk.conf` after building/upgrading
        pkgutils and verify the source, package, and work directory
        settings are active rather than commented.

    -   **Regression test:** build at least two different ports and
        verify their work paths resolve below
        `/var/cache/pkg/build-work/pkgmk-<package-name>`, cleanup
        removes only the package-specific directory, the parent tmpfs
        remains mounted, and no `Device or resource busy` error occurs.

## r137 confirmed LUKS + serial-console ordering fix --- 2026-08-22

-   [x] **IMPLEMENTED in installer r61 / runtime regression still
    recommended --- RUNTIME ROOT CAUSE CONFIRMED:** when both the
    QEMU/libvirt serial console and graphical console are enabled,
    generate the kernel console arguments in this order:
    `console=ttyS0,115200 console=tty0`.
    -   The previous installer ordering,
        `console=tty0 console=ttyS0,115200`, reproducibly caused Dracut
        111 to reach `luksOpen` but fail to present a usable interactive
        LUKS password prompt, making early boot appear frozen.
    -   Removing the serial-console argument immediately restored the
        LUKS password prompts and allowed the installed MD Linear/JBOD
        -\> LUKS -\> LVM -\> Btrfs system to boot normally.
    -   Re-enabling serial support with the order reversed to
        `console=ttyS0,115200 console=tty0` also restored the LUKS
        prompts and booted successfully, confirming console ordering as
        the trigger.
    -   Update the installer serial-console generation logic and
        `/etc/default/grub` handling so `tty0` is always last whenever
        both consoles are requested.
    -   Preserve topology-derived `rd.luks.uuid=`, `rd.md.uuid=`,
        `rd.lvm.lv=`, root, and rootflags arguments and keep
        regeneration idempotent/deduplicated.
    -   Undo/avoid carrying the experimental Dracut
        `70crypt-lib/crypt-lib.sh` console-redirection patch as a
        permanent BFSOS fix; stock Dracut works when the console
        ordering is correct.
    -   **Regression test:** encrypted install with graphical console
        only; serial console only where applicable; graphical + serial
        with the corrected ordering; confirm LUKS prompts are usable and
        serial boot diagnostics remain available.

## r138 full-project consolidation, core static audit, and Linux 6.18 LTS refresh --- 2026-08-22

-   [x] **FULL PROJECT TREE CONSOLIDATED:** Bootstrap, installer,
    pkgutils defaults, core ports, documentation, and kernel flavors
    were updated together rather than handed off as isolated scripts.
-   [x] **BOOTSTRAP:** retained r60 newest-installer-by-mtime discovery
    and syntax validation; Stage-4 `[PASSED!]` is bold white; bootstrap
    revision header advanced to r62.
-   [x] **INSTALLER r61:** corrected dual-console ordering to
    `console=ttyS0,115200 console=tty0`, preserving `tty0` as the final
    console so Dracut/LUKS prompts remain interactive; updated LTS
    selector wording.
-   [x] **PKGUTILS r14:** packaged `pkgmk.conf` now owns the BFSOS
    cache/work defaults and uses per-package
    `PKGMK_WORK_DIR=/var/cache/pkg/build-work/pkgmk-$name`; pkgmk
    fallback matches.
-   [x] **LINUX 6.18 LTS:** `linux-lts` advanced from 6.12.101 to
    upstream longterm 6.18.45. The obsolete 6.12-only MD diagnostic
    patch and GCC compatibility patch were removed from the active
    source list/tree. The known-good BFSOS current-kernel config is used
    as the baseline and reconciled with `olddefconfig`.
-   \[\~\] **CORE PORTS AUDIT:** all 198 real core Pkgfiles were
    re-scanned for Bash syntax and required metadata; no syntax or
    required-metadata failures were found. The existing 78-package
    MLFS-development mapping remains version-aligned. A new report
    `docs/BFSOS-core-audit-r138-20260822.md` records every core port and
    outstanding dependency/runtime concerns.
-   [x] **NUMPY DEPENDENCY METADATA:** removed the stale duplicate
    `meson-python` alias from the `python3-numpy` dependency comment;
    the actual BFSOS port is `python3-meson_python`.
-   [ ] **RUNTIME REGRESSION REQUIRED BEFORE RC1 SIGN-OFF:**
    build/install `linux-lts` 6.18.45, verify its
    module/source/initramfs/GRUB coexistence with the normal kernel,
    exercise LUKS boot with graphical+serial consoles, build at least
    two ports through pkgutils r14, and run clean Bootstrap stages
    1/2/3/4 plus fresh installer/boot tests.
-   [ ] **FULL UPSTREAM VERSION AUDIT REMAINS ITERATIVE:** static checks
    cover every core port, while authoritative upstream/security version
    review for BFSOS-only packages remains a maintenance task and must
    not be represented as runtime-validated without actual builds/tests.

## r139 dual-kernel source-symlink policy --- 2026-08-22

-   \[\~\] **PRE-1.0 KERNEL SOURCE SYMLINK POLICY: make `/usr/src/linux`
    follow the selected/default BFSOS kernel flavor without breaking
    normal + LTS coexistence.**
    -   Preserve fully versioned source trees for both flavors:
        -   normal kernel: `/usr/src/linux-<kernelrelease>`
        -   LTS kernel: `/usr/src/linux-<kernelrelease>-BFS-LTS` as
            produced by the package
    -   Preserve a flavor-specific LTS convenience link:
        -   `/usr/src/linux-lts -> linux-<current-LTS-kernelrelease>`
    -   Treat `/usr/src/linux` as the conventional **system-default
        kernel source** link:
        -   if only `linux` is installed, point `/usr/src/linux` to the
            normal kernel source tree;
        -   if only `linux-lts` is installed, point `/usr/src/linux` to
            the LTS source tree;
        -   if both are installed, preserve which flavor is configured
            as the system/default kernel instead of deciding by install
            order.
    -   Use `prt-get isinst linux` and `prt-get isinst linux-lts` to
        resolve the single-kernel cases automatically.
    -   For the dual-kernel case, store the selected/default flavor
        persistently, e.g. `/etc/bfsos/kernel-flavor` containing `linux`
        or `linux-lts`.
    -   The installer must initialize the selected/default flavor
        according to the kernel chosen during installation.
    -   Kernel package post-install/update logic must refresh its own
        flavor link and update `/usr/src/linux` **only when that flavor
        is the configured default**.
    -   An LTS update must not steal `/usr/src/linux` from a
        normal-kernel default; a normal-kernel update must not steal it
        from an LTS default.
    -   Keep `/boot` policy unchanged: use only versioned
        kernel/initramfs files and explicit GRUB entries; do not
        reintroduce generic `/boot/vmlinuz-*` or generic initramfs
        symlinks.
    -   Regression matrix before 1.0:
        -   normal kernel only;
        -   LTS kernel only;
        -   both installed with normal selected/default;
        -   both installed with LTS selected/default;
        -   update normal while LTS is default;
        -   update LTS while normal is default;
        -   verify `/usr/src/linux`, `/usr/src/linux-lts`,
            `/lib/modules/<kver>/{build,source}`, and GRUB entries after
            each case.

## r140 Wi-Fi regulatory database integration --- 2026-08-22

-   \[\~\] **PRE-1.0 WI-FI PACKAGING: add `wireless-regdb` and integrate
    it with `wpa_supplicant`.**
    -   Current BFSOS tree has no `wireless-regdb`/regulatory database
        port or existing `regulatory.db` integration.
    -   Create and validate a `wireless-regdb` port using the current
        upstream wireless regulatory database.
    -   Install the kernel-consumed regulatory database files in the
        BFSOS firmware path, including:
        -   `/usr/lib/firmware/regulatory.db`
        -   `/usr/lib/firmware/regulatory.db.p7s`
    -   Do **not** add obsolete CRDA-era userspace handling.
    -   Make `wireless-regdb` a dependency of `wpa_supplicant` so normal
        `prt-get depinst wpa_supplicant` automatically installs the
        regulatory database.
    -   Keep the installer free of unnecessary special-case package
        logic where possible: selecting `wpa_supplicant`/Wi-Fi support
        should obtain `wireless-regdb` through normal dependency
        resolution.
    -   Verify the installer Wi-Fi option still installs the complete
        dependency chain.
    -   Validate on boot that the kernel no longer reports:
        -   `Direct firmware load for regulatory.db failed with error -2`
    -   Validate regulatory-domain operation on real Wi-Fi hardware
        before 1.0 when practical.
    -   This warning was discovered during the successful Linux
        `6.18.45-BFS-LTS` runtime test; it is a packaging/completeness
        issue and does not invalidate the LTS kernel boot test.

## r141 NetworkManager / Qt / Firefox packaging policy --- 2026-08-22

-   \[\~\] **PRE-1.0 NETWORKMANAGER DEPENDENCY AUDIT: keep the
    installer/networking stack lean and avoid dragging GUI desktop
    stacks into minimal installs.**
    -   Audit the `NetworkManager` port and its full dependency chain.
    -   Verify it does **not** depend on Qt, GTK, Xorg, Wayland GUI
        components, desktop-environment libraries, applets, or other
        graphical frontend packages unless those dependencies are
        strictly required by the core daemon/CLI functionality.
    -   Prefer building the core NetworkManager daemon plus CLI/TUI
        functionality needed by BFSOS installation and normal
        headless/server use.
    -   Keep graphical NetworkManager frontends/applets as separate
        optional packages rather than dependencies of the core
        `NetworkManager` package.
    -   Confirm selecting NetworkManager in the BFSOS installer does not
        unexpectedly install a large portion of Xorg, Qt, GTK, GNOME,
        KDE/Plasma, or other desktop stacks.
    -   Audit optional build flags and Meson options so desktop
        integrations are disabled when they are not required by the base
        networking package.
    -   Record and justify any unavoidable graphical dependency before
        1.0.
    -   Regression test a fresh minimal install with NetworkManager
        selected and inspect the resulting dependency/package set.
-   \[\~\] **PRE-1.0 QT5 REHABILITATION: restore a functional monolithic
    `qt5` port for legacy application compatibility.**
    -   Keep Qt5 available in BFSOS for applications that still require
        it.
    -   Audit the existing `qt5` port against current upstream/community
        maintenance practices and identify why the current BFSOS port is
        broken.
    -   Apply the patches required for modern compilers, current
        glibc/binutils, OpenSSL, Python/tooling, and other contemporary
        build-environment changes as needed.
    -   Prefer **one `qt5` port that builds the complete BFSOS-supported
        Qt5 stack** rather than maintaining a large collection of
        separately versioned Qt5 module ports.
    -   Keep optional components/features disabled only where they are
        obsolete, insecure, unmaintained, or introduce clearly
        unnecessary dependencies.
    -   Ensure the resulting package is internally version-coherent and
        suitable as a compatibility runtime/build dependency for
        remaining Qt5 applications.
    -   Audit old patch files and source-tree workarounds; remove
        obsolete fixes and refresh still-required patches against the
        selected Qt5 release.
    -   Verify the build completes with the BFSOS toolchain and
        representative Qt5 applications can compile/link/run against it.
    -   Document any Qt5 modules intentionally excluded from the
        monolithic package.
-   \[\~\] **PRE-1.0 QT6 PACKAGING POLICY: keep Qt6 as one coordinated
    monolithic BFSOS port.**
    -   Prefer **one `qt6` port that builds the complete BFSOS-supported
        Qt6 stack** rather than splitting Qt6 into many separately
        maintained module packages.
    -   Keep all Qt6 components built from a coherent upstream
        release/version set.
    -   Audit dependencies and build options so optional
        desktop/media/database/web-engine features do not pull in
        unnecessary stacks unless explicitly supported by BFSOS.
    -   Keep package ownership, include paths, CMake metadata,
        pkg-config data, plugins, translations, and runtime resources
        internally consistent.
    -   Validate representative Qt6 applications against the resulting
        package.
    -   If a component is intentionally excluded because it is too
        large, unsupported, or has an unsuitable dependency/security
        profile, document that exception rather than silently
        fragmenting Qt6 into many ports.
-   \[\~\] **PRE-1.0 FIREFOX RELEASE POLICY: track normal rapid-release
    Firefox, not Firefox ESR.**
    -   BFSOS should package the current normal/release-channel Firefox
        rather than following BLFS/LFS ESR version choices.
    -   Use BLFS/LFS Firefox instructions as a build/reference source
        where helpful, but substitute the current stable non-ESR Firefox
        release and adjust patches/build flags accordingly.
    -   Do not automatically downgrade or switch BFSOS to ESR merely
        because the current BLFS book uses ESR.
    -   Audit Mozilla build dependencies and patches against the actual
        rapid-release Firefox version carried by BFSOS.
    -   Keep the Firefox port updated on the normal stable release
        cadence, subject to BFSOS build/regression validation.
    -   Validate startup, profile creation, TLS/CA handling, audio/video
        playback, hardware acceleration where supported, and
        representative web browsing before release.
    -   Document any temporary version pin if a rapid-release Firefox
        update is blocked by a known BFSOS toolchain or dependency
        regression.

## r143 opt + Xorg deep audit / modernization pass --- 2026-08-22

-   [x] **STATIC SWEEP COMPLETE:** audited all 558 current `ports/opt` +
    `ports/xorg` Pkgfiles; all pass `bash -n`, required package
    dependency names resolve with **0 unresolved required
    dependencies**, and `git diff --check` passes.
-   [x] **XORG DRIVER POLICY / META PACKAGE:** use current CRUX +
    upstream X.Org as the primary standalone-driver reference where BLFS
    no longer carries a complete driver set. Removed stray duplicate
    Nouveau directory `ports/xorg/brian@192.168.68.66`; restored
    `xf86-video-openchrome`; `xorg-driver` now covers all 23 present
    input/video driver ports with no missing/stale driver entry.
-   \[\~\] **XORG MODERNIZATION APPLIED / BUILD REGRESSION PENDING:**
    key Xorg infrastructure refreshed (Xorg Server 21.1.24, Xwayland
    24.1.13, xorgproto 2025.1, xkeyboard-config 2.48, Mesa 26.1.7, plus
    selected current utilities/input drivers). Full Xorg and driver
    build/hardware validation remains required before 1.0.
-   \[\~\] **LLVM MONOREPO CLEANUP APPLIED / BUILD REGRESSION PENDING:**
    LLVM 22.1.8 now uses one `llvm-project` source/build for LLVM +
    Clang + compiler-rt. Removed the old split archive extraction/rename
    workflow.
-   \[\~\] **MESA CLEANUP APPLIED / BUILD REGRESSION PENDING:** Mesa
    26.1.7 uses current Meson driver auto-selection rather than the old
    ad-hoc driver-string construction. Validate
    Gallium/Vulkan/X11/Wayland behavior after LLVM/Rust rebuilds.
-   \[\~\] **NETWORKMANAGER LEAN-CORE POLICY IMPLEMENTED / INSTALL
    REGRESSION PENDING:** NetworkManager 1.58.0 core package has no
    required Qt/GTK/Xorg dependency; keeps daemon/CLI/nmtui and disables
    unnecessary Qt, PPP, modem-manager, cloud-setup and CLAT integration
    in the core build. Verify a minimal installer selection does not
    drag in desktop stacks.
-   \[\~\] **QT5 COMPATIBILITY PORT REWORKED / BUILD REGRESSION
    REQUIRED:** `qt5-alternate` is renamed to `qt5`, remains a single
    BFSOS package under `/opt/qt5`, tracks Qt 5.15.19, and stages
    current Debian compatibility fixes for OpenSSL 4/current
    compiler/glibc/Python/Ninja-era build issues. Keep Qt5 for legacy
    applications until real build/application testing passes.
-   \[\~\] **QT6 MONOLITHIC POLICY IMPLEMENTED / BUILD REGRESSION
    REQUIRED:** Qt6 6.11.2 remains one coherent package under
    `/opt/qt6`; standalone BFSOS `qtwebengine` port is retired and
    QtWebEngine is built as part of the Qt6 source tree. Validate full
    WebEngine and representative application runtime before 1.0.
-   \[\~\] **RUST `/opt` POLICY PRESERVED / BUILD REGRESSION PENDING:**
    Rust 1.97.1 installs under `/opt/rustc-<version>` with `/opt/rustc`
    convenience link. Multilib bootstrap configuration was corrected to
    avoid duplicate TOML `[build]` tables.
-   \[\~\] **FIREFOX RAPID-RELEASE POLICY IMPLEMENTED / BUILD REGRESSION
    REQUIRED:** BFSOS Firefox tracks normal stable Firefox rather than
    ESR; port advanced to Firefox 154.0 and stale old-version source
    surgery was removed. Build/launch/TLS/media/profile validation
    remains required.
-   \[\~\] **WIRELESS REGDB IMPLEMENTED / WIFI RUNTIME PENDING:** new
    `wireless-regdb` port installs `regulatory.db` +
    `regulatory.db.p7s`; `wpa_supplicant` depends on it so
    installer/manual dependency installs pull it automatically. Verify
    kernel regulatory warning disappears on Wi-Fi hardware.
-   \[\~\] **LYNX + LINKS INSTALLER INTEGRATION IMPLEMENTED / RUNTIME
    PENDING:** installer r62 exposes Lynx and Links independently,
    persists both selections, shows them in text/Dialog paths, and
    installs them through normal `prt-get` dependency handling. Final
    audit also fixed the text-mode menu numbering collision so Lynx=5,
    Links=6, and Done=7.
-   \[\~\] **SOURCE/EXTRACTION CLEANUP:** hidden build-time downloads
    were removed from shared-mime-info and Speex; TeX Live source assets
    are declared through pkgmk sources; definite package build writes to
    host `/usr` were corrected in cdrdao, desktop-file-utils, FFmpeg and
    Subversion. Remaining complex-source ports require build validation
    rather than speculative mass rewriting.
-   [ ] **PRE-1.0 COMPLETION CRITERION:** build/install the high-risk
    stack in dependency order (LLVM -\> Rust -\> Mesa -\> Qt5/Qt6 -\>
    Firefox, plus NetworkManager/wireless-regdb and Xorg
    server/drivers), then run fresh installer/boot regressions. Static
    audit completion alone does not close runtime validation.
-   **Audit report:** `docs/BFSOS-opt-xorg-audit-r143-20260822.md`
    contains the full 558-port inventory and static audit results.

## r144 opt/service integration audit --- 2026-08-22

-   \[\~\] **PRE-1.0 OPT SERVICE-UNIT AUDIT: verify daemon/service
    integration for packages installed from `ports/opt` and related
    non-core collections.**
    -   Audit every opt/non-core package that installs or expects a
        background daemon, socket-activated service, path unit, timer,
        D-Bus service, or other persistent system service.
    -   For each applicable package, determine whether:
        -   upstream already installs correct systemd unit files;
        -   BFSOS must provide missing unit files itself;
        -   unit files require BFSOS-specific paths, users/groups,
            runtime directories, environment files,
            tmpfiles.d/sysusers.d entries, or permissions;
        -   socket/path/timer activation is preferable to enabling a
            long-running daemon at boot.
    -   Do not blindly enable services merely because a package is
        installed. Installer/package policy must distinguish:
        -   service installed but disabled by default;
        -   service enabled automatically because the selected installer
            feature requires it;
        -   socket/path/timer activation where upstream intends that
            model.
    -   Verify service units reference binaries/configuration paths
        actually installed by the BFSOS port.
    -   Verify service users/groups exist before first service start and
        are created consistently with BFSOS account policy.
    -   Verify `systemctl daemon-reload`, enablement, startup, shutdown,
        restart, and boot behavior where applicable.
    -   Check that uninstall/upgrade behavior does not leave stale
        enabled units pointing at removed binaries.
    -   Record units supplied by upstream versus units maintained by
        BFSOS so future updates do not accidentally duplicate/conflict
        with upstream packaging.
-   \[\~\] **CUPS SERVICE INTEGRATION: audit printing service units and
    installer behavior.**
    -   Verify whether the current CUPS source/package installs:
        -   `cups.service`
        -   `cups.socket`
        -   `cups.path`
        -   any additional CUPS helper/service units required by the
            selected build configuration.
    -   If upstream does not install the units BFSOS needs, add and
        maintain correct BFSOS systemd unit files in the CUPS port.
    -   Verify paths in all units match the actual BFSOS CUPS
        binary/config/runtime locations.
    -   Prefer upstream-supported socket/path activation behavior where
        appropriate rather than forcing an always-running daemon without
        reason.
    -   Verify the installer enables/activates CUPS only when printing
        support is selected; a minimal/headless install that does not
        select printing must not enable CUPS automatically.
    -   Validate `cupsd` startup, socket activation, restart, shutdown,
        boot persistence, and basic local printing administration before
        1.0.
-   [ ] **SERVICE-AUDIT PRIORITY SET:** explicitly inspect at minimum:
    -   CUPS / printing stack;
    -   Avahi;
    -   BlueZ;
    -   NetworkManager;
    -   ModemManager;
    -   power-profiles-daemon;
    -   UDisks;
    -   AccountsService;
    -   colord;
    -   sysklogd where applicable;
    -   GPM;
    -   wpa_supplicant;
    -   any package in opt/xorg whose Pkgfile installs files under
        `usr/lib/systemd`, `lib/systemd`, `etc/systemd`,
        `usr/lib/dbus-1/system-services`, `usr/lib/tmpfiles.d`, or
        `usr/lib/sysusers.d`.
    -   Extend this list automatically from a whole-tree
        file/install-path scan rather than treating the named packages
        as exhaustive.
-   [ ] **SERVICE REGRESSION MATRIX BEFORE 1.0:**
    -   perform a static scan of all opt/xorg Pkgfiles and shipped files
        for service-related artifacts;
    -   build/install representative daemon packages;
    -   verify required service users/groups and runtime directories;
    -   run `systemctl cat`, `systemctl enable/disable`,
        `systemctl start/restart/stop`, and boot tests as appropriate;
    -   confirm optional services remain disabled/uninstalled when their
        installer feature is not selected;
    -   require `systemctl --failed` to remain clean after
        representative service-enabled and minimal installs.

## r146 opt/xorg audit recovery and mandatory full modernization pass --- 2026-08-23

-   \[\~\] **REOPEN / REPLACE THE PRIOR OPT+XORG STATIC-AUDIT COMPLETION
    CLAIMS.**
    -   Tonight's live X.Org dependency build exposed multiple stale or
        incomplete Pkgfiles immediately, including a stale DocBook
        source URL, missing X.Org dependency metadata, and Graphite2
        incompatibilities with current CMake/GCC.
    -   Treat the prior r143 inventory/static audit as useful inventory
        only, **not** as proof that `ports/opt` and `ports/xorg` were
        comprehensively updated.
    -   Do not mark the opt/xorg audit complete again until every
        Pkgfile has been reviewed, changed where required, and validated
        against the current BFSOS pkgutils behavior and current
        upstream/toolchain expectations.
-   \[\~\] **MANDATORY PACKAGE-BY-PACKAGE AUDIT OF ALL `ports/opt` AND
    `ports/xorg`.**
    -   Review **every** Pkgfile in both trees; do not limit changes to
        packages that fail during an install test.
    -   For every package, verify and update as applicable:
        -   current appropriate upstream stable version and BFSOS
            `release=`;
        -   canonical/current source URLs and fallback/archive URLs when
            upstream locations moved;
        -   checksums/signatures and source filename/rename handling;
        -   required upstream, BLFS/LFS, CRUX, distro, compiler, libc,
            OpenSSL, Python, CMake, Meson, Ninja, Rust, LLVM, or other
            compatibility patches;
        -   dependencies and optional dependencies actually required by
            the selected BFSOS feature set;
        -   build-system detection and build/install commands;
        -   footprints, service files, symlinks, compatibility files,
            desktop integration, MIME/icon/schema caches, and runtime
            configuration;
        -   intentional BFSOS deviations from CRUX/BLFS/upstream.
    -   Re-check versions live at audit time rather than trusting the
        versions recorded by the interrupted/partial earlier pass.
-   \[\~\] **CONVERT OPT/XORG PORTS TO CURRENT BFSOS `pkg_build` /
    EXTENSION LOGIC WHERE APPLICABLE.**
    -   Audit all `ports/opt` and `ports/xorg` recipes for old
        hand-written `build()` logic that should now use the BFSOS
        pkgutils extension's automatic build path / `pkg_build`
        behavior.
    -   Use the extension's normal build-type detection and supported
        hooks for ordinary Autotools, CMake, Meson, Makefile, Python,
        and other recognized builds where it can reproduce the package
        correctly.
    -   Retain custom `build()` logic only when the package genuinely
        requires nonstandard sequencing, multi-tree builds, special
        staging, patch orchestration, or another documented exception.
    -   Where only packaging-time adjustments are needed, prefer the
        appropriate extension hook rather than replacing the generic
        build path unnecessarily.
    -   Record exceptions so future audits know why a package is
        intentionally not on the generic path.
-   \[\~\] **APPLY THE CURRENT PKGUTILS SOURCE-EXTENSION / EXTRACTION /
    RENAME LOGIC ACROSS ALL OPT+XORG PORTS.**
    -   Review every source entry and `renames=()` entry for the
        extension rules supported by current BFSOS pkgutils.
    -   Fix stale/manual archive-extension assumptions, including
        `.tar.gz`, `.tar.xz`, `.tar.zst`, `.tgz`, `.tbz*`, `.zip`,
        intentionally renamed files, local/vendored archives,
        patches/scripts, and packages whose extracted top-level
        directory does not match `$name-$version`.
    -   Eliminate old package-specific extraction/rename workarounds
        when the pkgutils extension now handles them correctly.
    -   Preserve explicit package-specific handling only where automatic
        detection cannot safely determine the correct source tree.
    -   Regression-test representative normal archives, renamed
        archives, ZIP sources, local/vendored sources, multi-source
        packages, and nonstandard extracted directory names.
-   \[\~\] **DO NOT SILENTLY CHANGE INTENTIONAL `/opt` INSTALLATION
    POLICY.**
    -   During modernization, preserve packages that BFSOS intentionally
        installs under `/opt` when that layout remains appropriate.
    -   Do not move a package to `/usr` merely because a reference
        distro does so.
    -   Verify PATH, library search paths, pkg-config/CMake metadata,
        desktop files, launchers, symlinks, environment setup, plugin
        paths, and upgrade behavior for packages kept under `/opt`.
    -   Document each major `/opt` package policy so later automated
        cleanup does not undo it.
-   \[\~\] **QT5 FULL RE-AUDIT --- FUNCTIONALITY + `/opt/qt5` POLICY.**
    -   Keep Qt5 as the BFSOS legacy-compatibility Qt stack and keep the
        intentional `/opt/qt5` layout unless testing proves a different
        layout is required.
    -   Re-audit the complete Qt5 recipe rather than assuming the
        earlier rework is correct.
    -   Verify the current Qt 5.15.x maintenance source choice and all
        required current patches for GCC/libstdc++, glibc, OpenSSL 4,
        Python, CMake/Ninja-era tooling, ICU,
        harfbuzz/freetype/fontconfig, X11/XCB, graphics/OpenGL, and
        WebEngine-related requirements that BFSOS intentionally enables.
    -   Verify configure/module selection preserves the functionality
        expected by real Qt5 applications rather than merely producing a
        package.
    -   Verify `/opt/qt5` environment integration (`PATH`,
        library/plugin/QML locations, pkg-config/CMake metadata, Qt
        chooser/symlinks where used) without polluting or conflicting
        with Qt6.
    -   Build and run representative legacy Qt5 applications before
        closing.
-   \[\~\] **QT6 FULL RE-AUDIT --- MONOLITHIC FUNCTIONAL BUILD +
    `/opt/qt6` POLICY.**
    -   Preserve the intended single coherent Qt6 installation under
        `/opt/qt6` and the policy that QtWebEngine is built from the Qt6
        source tree rather than maintained as a stale standalone BFSOS
        port.
    -   Re-check the current Qt6 release and every required
        module/dependency; do not assume the earlier 6.11.2 recipe is
        complete merely because it was statically edited.
    -   Verify WebEngine, multimedia, image formats, X11/XCB, Wayland
        where selected, OpenGL/Vulkan integration, printing, DBus, ICU,
        NSS, harfbuzz, fontconfig/freetype, and other functionality
        needed by representative BFSOS applications.
    -   Verify `/opt/qt6` PATH/library/plugin/QML/CMake/pkg-config
        integration and clean coexistence with `/opt/qt5`.
    -   Build and launch representative Qt6 applications and a
        QtWebEngine application before closing.
-   \[\~\] **RUST FULL RE-AUDIT --- CURRENT TOOLCHAIN + INTENTIONAL
    `/opt` LAYOUT.**
    -   Preserve the BFSOS Rust installation policy under
        `/opt/rustc-<version>` with the `/opt/rustc` convenience link
        unless deliberately changed after testing.
    -   Re-check the current Rust stable version at audit time,
        bootstrap compiler compatibility, LLVM integration, multilib
        configuration, Python/CMake/Ninja requirements, source/vendoring
        behavior, and install staging.
    -   Verify the recipe works with the current BFSOS
        GCC/glibc/binutils/LLVM stack and does not rely on stale
        bootstrap URLs or configuration keys.
    -   Verify `rustc`, `cargo`, target libraries, linker selection, and
        representative Rust builds after installation.
-   \[\~\] **FIREFOX FULL RE-AUDIT --- RAPID-RELEASE FUNCTIONALITY, NOT
    VERSION-ONLY UPDATE.**
    -   Keep the BFSOS policy of tracking normal stable Firefox rather
        than ESR unless that policy is deliberately changed.
    -   Re-check the current stable Firefox version at audit time
        instead of assuming the earlier recorded version is still
        current.
    -   Audit Mozilla build requirements end-to-end: Rust/cargo,
        LLVM/Clang, Python, Node/tooling where required, NSS/NSPR, GTK,
        DBus, audio/video codecs, graphics acceleration, X11/Wayland
        selections, sandboxing, ICU, SQLite, certificates/TLS, and all
        source patches required by current GCC/glibc/OpenSSL/toolchain
        behavior.
    -   Keep Firefox in the normal BFSOS `/usr` system prefix; Firefox
        is not part of the intentional `/opt` framework/toolchain
        policy.
    -   Validate launch, clean-profile creation, TLS browsing,
        audio/video playback, fonts, downloads, sandboxing,
        hardware/software rendering, and desktop integration.
-   \[\~\] **LLVM/MESA AND HIGH-RISK TOOLCHAIN DEPENDENCY CHAIN MUST BE
    RE-AUDITED WITH THE ABOVE.**
    -   Re-check LLVM/Clang/compiler-rt monorepo build choices and
        current versions/patches.
    -   Re-check Mesa build options and dependencies for current
        X11/Wayland/Gallium/Vulkan behavior.
    -   Validate in dependency order so Qt/Firefox failures are not
        caused by an incompletely modernized lower layer.
-   \[\~\] **TONIGHT: CA-BUNDLE PATH REGRESSION REOPENED.**
    -   `make-ca 1.16.1` generated `/etc/pki/tls/certs/ca-bundle.crt`,
        while `curl-config --ca` reported
        `/etc/ssl/certs/ca-certificates.crt`.
    -   The latter path was absent, producing curl error 77
        (`error adding trust anchors from file`) for otherwise reachable
        HTTPS sites.
    -   Creating
        `/etc/ssl/certs/ca-certificates.crt -> /etc/pki/tls/certs/ca-bundle.crt`
        immediately restored HTTPS (`kernel.org` HTTP 200 and X.Org
        redirect response).
    -   Resolve ownership between `make-ca`, `ca-certificates`, and curl
        permanently; regression-test fresh install **and package
        upgrade/reinstall** so the link/bundle cannot disappear again.
-   \[\~\] **TONIGHT: `docbook-xml` STALE SOURCE URL.**
    -   Change all DocBook XML 4.2/4.3/4.4/4.5 sources from
        `https://docbook.org/xml/...` to
        `https://archive.docbook.org/xml/...`.
    -   Archive URLs were verified live and all four source archives
        downloaded successfully; `docbook-xml 4.5-8` then built and
        installed.
    -   Apply the change to the real BFSOS port tree, bump release as
        appropriate, regenerate checksum/footprint metadata, and
        regression-test from an empty source cache.
-   \[\~\] **TONIGHT: `xsetroot` MISSING `libXcursor` DEPENDENCY.**
    -   `xsetroot 1.1.3-1` configure failed because pkg-config could not
        find `xcursor` while the other required X.Org modules were
        present.
    -   Add the package providing `xcursor.pc` (`libXcursor`) to the
        `xsetroot` dependency metadata.
    -   Regression-test that
        `prt-get depinst xorg-server xorg-libs xorg-apps xorg-fonts xorg-driver`
        installs it automatically with no manual intervention.
-   \[\~\] **TONIGHT: GRAPHITE2 1.3.14 REQUIRES MODERN CMAKE/GCC
    FIXES.**
    -   Current CMake rejects Graphite2's old minimum-policy
        declaration; `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` allows
        configuration to proceed.
    -   Under GCC 16.2, the Graphite2 test source
        `tests/featuremap/featuremaptest.cpp` uses fixed-width integer
        types such as `uint8_t`/`uint16_t` without including
        `<cstdint>`, producing cascading compilation failures.
    -   Modernize the port cleanly: prefer a maintained patch (or
        disable nonessential tests if upstream/build policy explicitly
        supports that and package functionality is unaffected) rather
        than accumulating ad-hoc cache-tree edits.
    -   Bump release, rebuild from a clean work directory, and validate
        the installed Graphite2 library with dependent font/text
        packages.
-   [x] **AUDIT EXECUTION / CONNECTION-DROP RECOVERY RULE.**
    -   Because the earlier audit session suffered repeated
        connection/tool interruptions, do not assume an edit landed
        merely because it was planned or discussed.
    -   Before resuming package modernization, compare the actual BFSOS
        repository tree against the audit checklist and record which
        files truly changed.
    -   Work in verifiable batches with a saved diff/commit or generated
        audit report after each batch so an interrupted session cannot
        leave the overall audit status ambiguous.
    -   If a session/tool connection drops during a future mass audit,
        mark the current batch **incomplete** until the repository is
        re-read and verified.
-   \[\~\] **NEW PRE-1.0 OPT/XORG COMPLETION GATE.**
    -   Do not resume treating long X.Org/desktop install runs as the
        primary discovery mechanism until the full opt/xorg Pkgfile
        re-audit above is complete.
    -   Completion requires: whole-tree static review **plus actual
        recipe modifications**, clean source-cache builds of
        representative/high-risk packages, dependency-chain installs,
        `/opt` integration checks, and runtime testing.
    -   Required high-risk build order: LLVM/Clang -\> Rust -\>
        Mesa/X.Org libraries -\> X.Org server/apps/drivers -\> Qt5 -\>
        Qt6/QtWebEngine -\> Firefox, with other opt dependencies
        repaired as encountered during the systematic audit rather than
        left for end-user install-time discovery.
    -   Only after this gate passes should a fresh VM installer/X.Org
        regression be used as confirmation rather than as the first
        audit pass.

### r147 clarification --- `/opt` installation policy

-   [x] **Firefox is NOT an `/opt` package.** Keep Firefox in the normal
    system prefix and audit it separately for current version, patches,
    dependencies, build flags, runtime functionality, and packaging
    correctness.
-   [x] **Preserve `/opt` only where it is an intentional BFSOS
    package-layout decision.** This includes Qt5, Qt6, Rust toolchains,
    and other applications/frameworks that BFSOS deliberately installs
    under `/opt`.
-   \[\~\] During the full `ports/opt` + `ports/xorg` re-audit, classify
    every package individually as either a normal `/usr` install or a
    deliberate `/opt` install. Do not mass-convert packages in either
    direction.
-   \[\~\] Revisit the other applications discussed earlier and preserve
    their intended installation prefix and functionality while
    modernizing versions, patches, dependencies, source/extraction
    handling, and build logic.

## r148 full-project implementation / opt+xorg modernization recovery pass --- 2026-08-23

-   [x] **INTERRUPTED-AUDIT STATE VERIFIED BEFORE RESUME.** The supplied
    full-project archive was unpacked independently and compared against
    a pristine copy before further edits. The final r148 change manifest
    records 481 file-level differences, so this pass no longer relies on
    assumptions about edits that may or may not have survived the
    earlier connection drops.
-   \[\~\] **FULL `ports/opt` + `ports/xorg` RECIPE MIGRATION APPLIED /
    RUNTIME BUILD MATRIX PENDING.** All 558 opt+xorg Pkgfiles were
    re-scanned against the current BFSOS pkgutils extension. There are
    now **zero legacy `build()` functions** in those collections;
    ordinary/custom recipes use the extension and
    `pkg_build()`/`build_opt` policy. The final static gate checked all
    759 core+opt+xorg Pkgfiles with `bash -n` and found zero syntax
    failures.
-   \[\~\] **SOURCE/EXTRACTION/RENAME AUDIT APPLIED / CLEAN-CACHE
    REGRESSION PENDING.** Current source arrays were evaluated for all
    core+opt+xorg ports with zero evaluation failures and zero missing
    local files. Multi-source packages whose main tree cannot be safely
    inferred are handled explicitly; in particular Freetype2 enters
    `freetype-$version` and Qt5 enters
    `qt-everywhere-opensource-src-$version`. Recipes that manually
    orchestrate patches explicitly suppress extension auto-patching so
    patches are not applied twice.
-   \[\~\] **DEPENDENCY METADATA AUDIT APPLIED / DEPSTINST RUNTIME
    PENDING.** A name-resolution pass across all BFSOS collections
    reports zero unresolved dependencies for core+opt+xorg. Added
    missing `libyaml` and `python3-cython` core ports and advanced
    `python3-pyyaml` to 6.0.3 so Mesa's declared PyYAML chain is
    actually satisfiable.
-   \[\~\] **VERSION/RELEASE MODERNIZATION APPLIED / PACKAGE-BUILD
    VALIDATION PENDING.** Relative to the supplied archive, 129
    core/opt/xorg recipes are new or have version/release changes.
    High-risk policy versions now include Rust 1.98.0, Mesa 26.2.1, Qt5
    5.15.19, Qt6 6.11.2, Firefox 154.0, and LLVM 22.1.8.
    `docs/r148-version-release-changes.json` is the exact inventory;
    packages still require real clean-cache builds before release
    sign-off.
-   \[\~\] **INTENTIONAL PREFIX POLICY VERIFIED.** Firefox explicitly
    configures `--prefix=/usr`. Qt5 remains `/opt/qt5`, Qt6 remains
    `/opt/qt6`, and Rust remains versioned under `/opt/rustc-<version>`
    with `/opt/rustc`. Retired `qt5-alternate` and standalone
    `qtwebengine` port directories are absent. Do not infer installation
    prefix from collection name; `ports/opt` is a package collection,
    not a requirement that every application install under `/opt`.
-   \[\~\] **QT5 STATIC REWORK VERIFIED / FULL BUILD+APPLICATION TEST
    PENDING.** Qt5 remains monolithic under `/opt/qt5`, retains the
    selected Debian compatibility-patch staging, explicitly suppresses
    extension auto-patching, and now explicitly enters the Qt source
    tree despite its multiple patch archives. Release bumped for the
    source-tree handling change.
-   \[\~\] **QT6 STATIC REWORK VERIFIED / FULL BUILD+WEBENGINE TEST
    PENDING.** Qt6 remains monolithic under `/opt/qt6`; standalone
    QtWebEngine remains retired. Runtime/module/application validation
    remains a release gate.
-   \[\~\] **RUST STATIC REWORK VERIFIED / TOOLCHAIN BUILD PENDING.**
    Rust is updated to 1.98.0 and retains the intentional versioned
    `/opt` layout and convenience link. Full bootstrap, cargo, multilib
    and representative Rust build validation remains required.
-   \[\~\] **FIREFOX STATIC REWORK VERIFIED / BROWSER RUNTIME PENDING.**
    Firefox is 154.0, rapid-release policy is retained, and the recipe
    installs under `/usr` (not `/opt`).
    Launch/TLS/media/sandbox/rendering/profile tests remain required.
-   \[\~\] **LLVM/MESA LOWER-LAYER STATIC REWORK VERIFIED / BUILD ORDER
    PENDING.** LLVM 22.1.8 and Mesa 26.2.1 recipes are updated; Mesa's
    previously incomplete PyYAML dependencies are now resolvable.
    Validate LLVM -\> Rust -\> Mesa before attributing later Qt/Firefox
    failures to upper layers.
-   \[\~\] **CA-BUNDLE REGRESSION FIX APPLIED / FRESH-INSTALL+UPGRADE
    TEST PENDING.** `ca-certificates` owns compatibility links to
    make-ca's canonical `/etc/pki/tls/certs/ca-bundle.crt`, while curl
    is configured natively for that canonical bundle. This prevents the
    exact curl error 77 reproduced on the VM. Reinstall/upgrade
    ownership still needs a live regression.
-   \[\~\] **DOCBOOK XML SOURCE FIX APPLIED / CLEAN-CACHE RETEST
    PENDING.** All 4.2--4.5 sources use `archive.docbook.org`; the live
    VM already proved those endpoints and built the package
    successfully. BFSOS recipe release is bumped.
-   \[\~\] **XSETROOT DEPENDENCY FIX APPLIED / META-PACKAGE RETEST
    PENDING.** `libXcursor` is explicitly declared, closing the live
    `xcursor.pc` configure failure.
-   \[!\] **GRAPHITE2 r148 STATIC FIX WAS INVALIDATED BY LIVE TESTING
    --- SEE r149.** Runtime produced an effectively empty package
    containing only `usr/`; the r149 item supersedes this r148 status.
-   \[\~\] **SQUASHFS-TOOLS STALE PATCH DEFECT REMOVED.** The 4.7.5
    recipe no longer references a nonexistent versioned symlink patch
    copied from 4.5; it uses the current upstream install behavior and
    the recipe release is bumped. Clean package build remains pending.
-   \[\~\] **PKGUTILS TMPFS WORK-DIR CLEANUP HARDENED / LIVE TMPFS TEST
    PENDING.** pkgutils release 15 rewrites `remove_work_dir()` so an
    active `PKGMK_WORK_DIR` mount has its contents removed without
    removing the mountpoint; ordinary unmounted work directories retain
    normal removal behavior.
-   \[!\] **PACKAGE-DOWNLOAD HARDENING r148 IMPLEMENTATION REGRESSED
    PKGMK --- SEE r149.** Live sysup showed the generated pkgmk called
    `download_source` without defining it; redesign and regression
    testing are required.
-   \[\~\] **SOURCE-CACHE RETENTION + BASE TOOLING IMPLEMENTATION
    PRESENT.** Bootstrap exposes the source-cache retention policy;
    `rsync` and `traceroute` are in the base list. No active
    config/source file contains the nonexistent `distfiles.bfsos.org`
    hostname.
-   \[\~\] **SERVICE INTEGRATION STATIC INVENTORY COMPLETE / SYSTEMD
    RUNTIME PENDING.** `docs/opt-xorg-service-audit-r148.{md,json}`
    records 19 opt/xorg ports with shipped service/config artifacts or
    explicit service integration. CUPS ships BFSOS `cups.service`,
    `cups.socket`, and `cups.path`. Runtime enable/start/stop/boot and
    minimal-install behavior remain open.
-   \[\~\] **BOOTSTRAP UI/DISCOVERY ITEMS VERIFIED IN CODE.**
    `[PASSED!]` renders bold white, and Bootstrap selects the newest
    valid versioned installer by filesystem mtime with syntax validation
    instead of depending on `install-bfs-menu-current.sh`.
-   \[\~\] **FILESYSTEM PLAN + DUAL-KERNEL SOURCE POLICY VERIFIED IN
    INSTALLER r63.** Filesystem confirmation uses one Continue/Back plan
    screen. Kernel packages retain versioned source trees and the
    selected flavor owns the generic `/usr/src/linux` selection policy.
-   \[\~\] **SERIAL-CONSOLE REGRESSION CORRECTED IN r63/current.**
    Managed GRUB console order is now
    `console=tty0 console=ttyS0,115200n8`, preserving VGA output while
    leaving serial as the final/primary interactive console for
    VM/Dracut troubleshooting.
-   [ ] **INSTALLER FULL NON-INTERACTIVE CLI REMAINS OPEN.** Bootstrap
    has stable direct stage/action CLI and help, but the installer still
    exposes only logging/font switches. Do not pretend r128 is complete:
    a destructive storage/install CLI needs one shared validation path,
    explicit profile/target data, and strong confirmation semantics
    before it is safe to ship.
-   [ ] **ISO DELIVERY/ISO-BUILDER CLI REMAINS A DISTINCT RELEASE
    TASK.** No standalone BFSOS ISO artifact was generated in this
    source audit; r126/r128 ISO-builder requirements remain open.
-   [ ] **RUNTIME-ONLY REGRESSIONS REMAIN OPEN.** This source pass
    cannot truthfully close VM/bare-metal checks: clean Bootstrap
    stages, fresh installer/recovery matrices, RAID/LUKS/LVM/Btrfs
    combinations, font/4K behavior, service runtime, high-risk package
    builds, X.Org driver runtime, Qt applications, Rust builds, Firefox
    runtime, and final RC/ISO boot tests.
-   \[\~\] **NEW PRE-1.0 GATE:** use the updated tree for the next clean
    validation in dependency order: Bootstrap/base -\> LLVM -\> Rust -\>
    Mesa/X.Org libraries -\> X.Org server/apps/drivers -\> Qt5 -\>
    Qt6/QtWebEngine -\> Firefox. The VM run is now a
    regression/confirmation pass, not the first mechanism for
    discovering stale recipes.

### r148 generated audit artifacts

-   `docs/r148-change-manifest.txt` --- file-level differences from the
    supplied pristine project.
-   `docs/r148-version-release-changes.json` --- exact version/release
    changes/new core+opt+xorg ports.
-   `docs/opt-xorg-extension-migration-r148.json` ---
    extension/pkg_build migration record.
-   `docs/core-opt-xorg-dependency-audit-r148.json` --- final
    dependency-resolution check (zero unresolved in scope).
-   `docs/local-source-audit-r148.json` --- source-array/local-file
    check (zero missing/evaluation failures).
-   `docs/opt-xorg-service-audit-r148.md` / `.json` --- service-related
    static inventory.

## r149 live-VM dependency / packaging findings --- 2026-08-23

These items supersede any earlier r148 static-audit assumption where
live package builds proved the tree was still incomplete.

-   [ ] **BASE INSTALL: ADD `pciutils`.**
    -   Add `pciutils` to the default/base installation package set.
    -   Goal: ensure `lspci` and related PCI diagnostic tools are
        available on a fresh BFSOS install even when networking/package
        downloads are unavailable.
    -   Regression-test that a fresh base install has `lspci` without an
        additional `prt-get` operation.
-   [ ] **XAUTH DEPENDENCY METADATA: COMPLETE/VERIFY REQUIRED X
    LIBRARIES.**
    -   `xauth 1.1.3` previously failed configure because pkg-config
        modules `x11`, `xau`, `xext`, and `xmuu` were missing.
    -   Ensure the `xauth` port declares the packages providing those
        modules, expected to include `libX11`, `libXau`, `libXext`, and
        `libXmu`.
    -   Regression-test that a clean `prt-get depinst xauth` pulls all
        required libraries automatically.
-   [ ] **XSETROOT DEPENDENCY METADATA: REQUIRE `libXcursor`.**
    -   Live X.Org install previously failed because `xsetroot 1.1.3`
        could not find pkg-config module `xcursor`.
    -   Keep/verify explicit `libXcursor` dependency metadata and test
        on a clean X.Org install.
-   [ ] **XKBUTILS DEPENDENCY METADATA: ADD `libXaw`.**
    -   Live X.Org stack install reached `xkbutils` and configure failed
        with:
        -   `Package 'xaw7' not found`
    -   Add `libXaw` to `xkbutils` required dependencies so `xaw7.pc` is
        present automatically.
    -   User manually installed the dependency to continue the current
        VM validation; the port metadata still needs the permanent fix
        and clean regression.
-   [ ] **HARFBUZZ DEPENDENCY METADATA: REQUIRE FUNCTIONAL `graphite2`
    WHEN `-Dgraphite2=enabled`.**
    -   Harfbuzz 14.3.1 is intentionally configured with
        `-Dgraphite2=enabled`.
    -   Its Meson configure failed because `graphite2` could not be
        discovered.
    -   Declare `graphite2` as a required Harfbuzz dependency whenever
        Graphite2 support is enabled.
    -   Do not solve this by silently disabling Graphite2; preserve the
        intended functionality.
-   [ ] **GRAPHITE2 PACKAGE WAS REGISTERED AS INSTALLED BUT EMPTY ---
    REWRITE/FIX PACKAGE.**
    -   Runtime inspection proved `graphite2 1.3.14-2` produced a
        \~132-byte package containing only `usr/`.
    -   Neither `/usr/lib/libgraphite2.so*` nor `graphite2.pc` existed,
        even though `prt-get` reported the package installed.
    -   This is the direct reason Harfbuzz could not discover Graphite2.
    -   Replace the malformed/ineffective GCC16 compatibility patch
        approach with a reliable source fix or correctly generated
        patch.
    -   Modernize the Graphite2 CMake logic for current CMake 4.x and
        GCC 16.
    -   Use fail-fast configure/build/install sequencing.
    -   Explicitly stage installation into `$PKG`.
    -   Bump the package release.
    -   Regression-test the archive contents before installation;
        require at minimum:
        -   `libgraphite2.so*`;
        -   Graphite2 headers;
        -   `graphite2.pc`;
        -   expected utility/program files where enabled.
    -   Only then retry Harfbuzz.
-   [ ] **MESA DEPENDENCY METADATA: ADD LLVM-SPIR-V TRANSLATOR /
    `LLVMSPIRVLib`.**
    -   Mesa 26.2.1 successfully detects LLVM 22.1.8 and libdrm 2.4.134,
        then fails Meson configure with:
        -   `Run-time dependency llvmspirvlib found: NO`
        -   `ERROR: Dependency "LLVMSPIRVLib" not found`
    -   Add the LLVM-22-compatible `spirv-llvm-translator` dependency
        wherever the selected Mesa feature set requires it.
    -   Preserve required supporting SPIR-V dependency ordering
        (`spirv-headers`, `spirv-tools`, translator) as needed.
    -   Regression-test a clean Mesa/X.Org dependency install rather
        than manually preinstalling these packages.
-   [ ] **LLVM PACKAGING: PRESERVE STATIC COMPONENT ARCHIVES WITH
    `keep_static=1`.**
    -   `spirv-llvm-translator 22.1.5` fails `find_package(LLVM)`
        because `/usr/lib/cmake/llvm/LLVMExports.cmake` references
        `/usr/lib/libLLVMDemangle.a`, but that archive is absent.
    -   Runtime inspection showed the installed LLVM package contains no
        matching static LLVM archives.
    -   BFSOS pkgutils normally removes `*.a`; LLVM's exported CMake
        targets still reference those component archives.
    -   Set **`keep_static=1`** in `ports/opt/llvm/Pkgfile` (this is the
        correct BFSOS extension syntax; do not use `keep_static=yes`).
    -   Bump the LLVM package release and rebuild LLVM so all archives
        referenced by its CMake exports are present.
    -   Verify at minimum:
        -   `/usr/lib/libLLVMDemangle.a` exists;
        -   `pkginfo -l llvm` includes it;
        -   importing LLVM through CMake no longer reports missing
            exported files.
    -   Then rebuild `spirv-llvm-translator`, followed by Mesa.
-   [ ] **PKGUTILS STATIC-LIBRARY CLEANUP POLICY: AUDIT PACKAGES WHOSE
    METADATA REFERENCES `.a` FILES.**
    -   LLVM proves that globally deleting every static archive can
        leave installed CMake/pkg-config metadata internally
        inconsistent.
    -   Audit packages that export CMake/pkg-config/import targets
        referencing static archives.
    -   Use package-level `keep_static=1` where static archives are part
        of the supported development interface.
    -   Do not globally preserve all `.a` files without review; maintain
        the normal BFSOS cleanup policy for packages that do not require
        them.
-   [ ] **SPIRV-LLVM-TRANSLATOR FAIL-FAST BUILD LOGIC.**
    -   When CMake configuration fails, the current recipe still falls
        through to `ninja install`, producing a secondary
        `build.ninja: No such file or directory` error.
    -   Convert the recipe to fail immediately when configure fails
        before any build/install step.
    -   Apply the same fail-fast review to other converted `pkg_build()`
        recipes.
-   [ ] **MESA FAIL-FAST BUILD LOGIC.**
    -   When `meson setup` fails, the Mesa recipe currently continues
        into `meson compile` and `meson install`, creating misleading
        secondary errors.
    -   Chain or guard configure/build/install so the first failing
        stage terminates the package build immediately.
-   [ ] **PYTHON3-PYYAML: NEW DEPENDENCY / SYSUP UPGRADE-PATH
    REGRESSION.**
    -   PyYAML 6.0.3 build failed with
        `ModuleNotFoundError: No module named 'Cython'` until the newly
        added `python3-cython` dependency was installed.
    -   Keep `python3-cython` and `libyaml` dependency metadata correct.
    -   Audit the BFSOS `prt-get sysup` upgrade path: an
        already-installed package whose new release gains a new
        dependency may be updated without that new dependency being
        installed first.
    -   Decide whether BFSOS needs a sysup wrapper/change that resolves
        newly introduced dependencies before package updates.
-   [ ] **WPA_SUPPLICANT 2.12: REMOVE STALE OPENSSL-4 PATCH REFERENCE.**
    -   Live build failed because the Pkgfile still attempted to apply
        `openssl-4-asn1.patch` after that patch file had been removed.
    -   The stale patch invocation was removed manually and
        `wpa_supplicant 2.12-5` then built/installed successfully.
    -   Make the removal permanent in the repository and regression-test
        from a clean source/build cache.
-   [ ] **BOOST 1.92.0: FIX STALE 1.91.0 SOURCE FILENAME.**
    -   During r148 sysup testing, the Boost port reported version
        1.92.0 but still referenced `boost_1_91_0.tar.bz2`.
    -   Correct source/rename metadata for 1.92.0 and validate a clean
        download/build.
-   [ ] **PKGUTILS r148 DOWNLOAD-HARDENING REGRESSION: `download_source`
    WAS REMOVED/BROKEN.**
    -   r148 pkgutils generated `/usr/bin/pkgmk` that called
        `download_source` but no longer defined the function.
    -   This caused unrelated packages (`valgrind`, `boost`, `libuv`,
        `wpa_supplicant`, `glib`, `python3-pyyaml`) to fail immediately
        before source download.
    -   Restoring `/usr/bin/pkgmk` from cached `pkgutils 5.40.12-14`
        restored the function.
    -   Roll back/redesign the archive-content validation hardening so
        it never rewrites/removes core pkgmk functions.
    -   Regression-test pkgmk itself before shipping any pkgutils
        rebuild:
        -   `grep '^download_source()' /usr/bin/pkgmk`;
        -   normal source download;
        -   cached-source build;
        -   failed/404 source;
        -   HTML body masquerading as archive.
    -   Do not mark r148's package-download validation item complete
        until this regression is corrected.
-   [ ] **PKGUTILS PACKAGE UPGRADE VS TMPFS MOUNTPOINT.**
    -   `pkgadd -u` of an older pkgutils package failed with:
        -   `could not remove /var/cache/pkg/build-work/: Device or resource busy`
    -   The path is an active tmpfs mountpoint.
    -   Ensure package upgrade/removal logic does not try to
        unlink/remove an active configured work-area mountpoint.
    -   Preserve the mountpoint and clean only its contents when
        mounted.
-   [ ] **CAIRO SOURCE HOST RESILIENCE.**
    -   Canonical
        `https://www.cairographics.org/releases/cairo-1.18.4.tar.xz`
        timed out from both the VM and Prism, indicating upstream-path
        reachability rather than a VM-only fault.
    -   A first alternate OpenBSD-mirror URL returned 404 and must not
        be retained.
    -   Keep a currently verified reachable source/mirror and validate
        the actual archive before changing the canonical recipe.
    -   This reinforces the existing pkgmk/fallback-mirror tracker work;
        do not treat every timeout as a curl/CA regression.
-   [ ] **LIBDRM SOURCE HOST RESILIENCE / RENAME HANDLING.**
    -   Canonical `dri.freedesktop.org` timed out during the X.Org run.
    -   The test recipe was switched to a Debian-style source filename
        and therefore requires correct
        `renames=(libdrm-$version.tar.xz)` handling.
    -   Verify the chosen mirror, checksum, rename logic, clean
        extraction, and build before closing.
-   [ ] **MESA SOURCE HOST RESILIENCE / RENAME HANDLING.**
    -   `archive.mesa3d.org` timed out during the X.Org run.
    -   The test recipe was switched to a Debian-style
        `mesa_$version.orig.tar.xz` source and uses
        `renames=(mesa-$version.tar.xz)`.
    -   Verify the mirror/checksum and retain correct rename/extraction
        behavior in the permanent port.
-   [ ] **MASTER X.ORG META-PACKAGE STILL REQUIRED.**
    -   Create a top-level `xorg` meta-package so a normal installation
        can use:
        -   `prt-get depinst xorg`
    -   It should pull the intended standard BFSOS X.Org stack
        (`xorg-server`, libraries, apps, fonts, drivers, and required
        lower-layer graphics dependencies).
    -   Do not close until the dependency chain succeeds from a clean
        system without manually installing missing libraries such as
        `libXaw`, `libXcursor`, Graphite2, or the LLVM-SPIR-V
        translator.

### r149 live validation status

-   [x] `wpa_supplicant 2.12-5` built and installed successfully after
    removing the stale patch invocation.
-   [x] `prt-get sysup -is -if -im` subsequently reported the system up
    to date.
-   [x] `spirv-headers 1.4.357.0-2` built and installed successfully.
-   [x] `spirv-tools 1.4.357.0-2` built successfully as a dependency of
    the LLVM-SPIR-V translator.
-   [ ] `spirv-llvm-translator 22.1.5-2` remains blocked until LLVM is
    rebuilt with `keep_static=1`.
-   [ ] Mesa 26.2.1 remains blocked until the LLVM-SPIR-V translator is
    functional.
-   [ ] Harfbuzz remains blocked until Graphite2 is rebuilt as a
    non-empty functional package.
-   [ ] Full X.Org stack installation remains in progress and is not yet
    a passed regression.

## r150 --- X.Org legacy-driver failures found during live regression

-   [ ] **XF86-VIDEO-OPENCHROME 0.6.0 / CURRENT XORG API
    COMPATIBILITY.**
    -   `xf86-video-openchrome 0.6.0` fails against the current X.Org
        server headers because it still calls
        `shadowUpdatePackedWeak()`, which is no longer available.
    -   Research a maintained upstream/downstream compatibility patch or
        a newer maintained source.
    -   If it is no longer reasonable as a default driver, remove it
        from the default `xorg-driver` meta-package while retaining it
        as an optional legacy VIA/OpenChrome driver.
    -   Make the port fail fast: if compilation fails, the recipe must
        not continue into `make install`.
    -   During current live X.Org regression testing, temporarily remove
        `xf86-video-openchrome` from the `xorg-driver` dependency list
        so the rest of the stack can be tested.
-   [ ] **XF86-VIDEO-VBOXVIDEO 1.0.0 / GCC 16 + C23 COMPATIBILITY.**
    -   `xf86-video-vboxvideo 1.0.0` fails to compile with the current
        compiler/C-language defaults because `VBoxVideoIPRT.h` declares
        `false` as an enum constant and defines `bool`; `false` is a C23
        keyword.
    -   Research a maintained/newer source, an upstream/downstream C23
        compatibility patch, or an appropriate narrowly scoped
        build-language compatibility flag.
    -   Do not hide a genuinely obsolete source problem with a global
        compiler downgrade.
    -   Make the port fail fast: the current recipe continues into
        `make DESTDIR=$PKG install` after `make` has already failed.
    -   During current live X.Org regression testing, temporarily remove
        `xf86-video-vboxvideo` from the `xorg-driver` dependency list so
        testing can continue.
    -   Re-evaluate whether VBoxVideo belongs in the default
        `xorg-driver` meta-package versus being an optional
        VirtualBox-specific legacy driver.

### r150 live validation notes

-   [x] `xf86-input-synaptics 1.10.0-2` built, packaged, and installed
    successfully.
-   [x] `xf86-video-fbdev 0.5.1-1` built, packaged, and installed
    successfully.
-   [ ] `xf86-video-openchrome 0.6.0` is temporarily skipped pending
    current-X.Org API compatibility work.
-   [ ] `xf86-video-vboxvideo 1.0.0` is temporarily skipped pending C23
    compatibility work.
-   [ ] Continue the
    `xorg-server xorg-libs xorg-apps xorg-fonts xorg-driver` dependency
    regression after temporarily removing the two blocked legacy
    drivers.

## r151 --- X.Org baseline applications / xterm ownership findings

-   [ ] **XORG-APPS: RESTORE CLASSIC BASELINE APPLICATIONS.**
    -   Restore `xterm`, `twm`, and `xclock` to the `xorg-apps`
        dependency list.
    -   Audit `xorg-apps` for any other standard X.Org applications that
        were accidentally omitted during the ports/meta-package updates.
    -   Regression-test that `prt-get depinst xorg-apps` provides the
        intended usable BFSOS baseline X environment.
-   [ ] **XINIT: INCLUDE IN DEFAULT X.ORG META-PACKAGE CHAIN.**
    -   Add `xinit` to an appropriate default X.Org meta-package,
        preferably `xorg-apps` unless the final top-level `xorg` package
        structure makes another placement cleaner.
    -   A standard BFSOS X.Org installation must provide
        `xinit`/`startx` without requiring the user to discover and
        install it separately.
    -   Regression-test this together with `twm`, `xclock`, and `xterm`.
-   [ ] **XTERM 410-2: TERMINFO PACKAGE-OWNERSHIP CONFLICT.**
    -   `xterm 410-2` builds and packages successfully, but `pkgadd`
        refuses installation because these files are already installed:
        -   `usr/share/terminfo/r/report+da2`
        -   `usr/share/terminfo/r/report+version`
    -   Identify the package that already owns/provides those terminfo
        entries, likely `ncurses` or another terminfo/base package.
    -   Fix packaging so only one package owns each file; do not use
        `pkgadd -f` as the permanent solution.
    -   Prefer removing/excluding duplicate terminfo files from the
        xterm package if they are correctly supplied by the base
        terminfo provider.
    -   Regression-test a normal `prt-get depinst xterm` installation
        with no overwrite/force option and no package ownership
        collision.
    -   For the current live X.Org test, skip xterm until this ownership
        conflict is fixed; `twm`, `xclock`, and `xinit` can still be
        used to validate a minimal X session.

### r151 live validation status

-   [x] `xterm 410-2` **build stage** succeeds.
-   [ ] `xterm 410-2` **installation** remains blocked by the duplicate
    terminfo ownership conflict.
-   [ ] Restore `xterm`, `twm`, `xclock`, and `xinit` to the intended
    X.Org meta-package dependency chain after their individual ports are
    validated.

## r152 implementation pass --- live dependency / X.Org regression fixes --- 2026-08-23

This pass applies the code changes from the r149-r151 live VM findings.
Items marked implemented still require the indicated clean VM/package
runtime regression before release sign-off.

-   \[\~\] **BASE INSTALL / DIAGNOSTICS: `pciutils` IMPLEMENTED, RUNTIME
    REGRESSION PENDING.**
    -   Added `pciutils` to the Bootstrap base package list so future
        base archives contain `lspci` and related PCI diagnostics.
    -   Installer r64 also adds `pciutils` to the package transaction so
        the currently reused older base archive receives it without
        waiting for the next base rebuild.
    -   The previously requested `traceroute` diagnostic is already
        present as a core port and in the supplied Bootstrap base list.
-   \[\~\] **XAUTH DEPENDENCIES IMPLEMENTED.**
    -   `xauth` now explicitly requires `libX11 libXau libXext libXmu`.
    -   Release bumped and recipe converted to fail immediately on
        configure/build/install failure.
    -   Runtime target: clean `prt-get depinst xauth`.
-   \[\~\] **XKBUTILS -\> `libXaw` DEPENDENCY IMPLEMENTED.**
    -   `xkbutils` now explicitly requires `libXaw` in addition to
        `libxkbfile`.
    -   Release bumped and recipe made fail-fast.
    -   Runtime target: clean X.Org dependency install without manually
        preinstalling libXaw.
-   \[\~\] **GRAPHITE2 EMPTY-PACKAGE REGRESSION REWORKED.**
    -   Graphite2 release bumped to 4.
    -   Reworked CMake 4 / GCC 16 compatibility edits, source-tree
        handling, configure/build/install sequencing, and explicit
        `$PKG` staging.
    -   Build now verifies that the staged package contains the
        Graphite2 shared library, `graphite2.pc`, and headers before
        pkgmk can accept the package.
    -   Runtime target: rebuild Graphite2 and verify package/archive
        contents before Harfbuzz.
-   \[\~\] **HARFBUZZ -\> GRAPHITE2 CHAIN HARDENED.**
    -   Harfbuzz retains required `graphite2` metadata because BFSOS
        intentionally enables Graphite2 support.
    -   Release bumped and Meson configure/build/install is now
        fail-fast.
    -   Runtime target: rebuild immediately after the corrected
        Graphite2 package.
-   \[\~\] **LLVM STATIC COMPONENT POLICY ALREADY PRESENT / RETAINED.**
    -   The supplied tree already has `keep_static=1` on LLVM release 3;
        retain this exact BFSOS syntax.
    -   Runtime target remains rebuilding LLVM and verifying
        `/usr/lib/libLLVMDemangle.a` plus the other CMake-exported
        component archives are packaged.
-   \[\~\] **SPIRV-LLVM-TRANSLATOR RECIPE HARDENED.**
    -   Dependencies explicitly include LLVM, SPIR-V Headers, SPIR-V
        Tools, and libxml2.
    -   Release bumped to 3.
    -   CMake configure/build/install is fail-fast, so a configure
        failure no longer cascades into a misleading `ninja install`
        error.
    -   Runtime target: rebuild after LLVM has been rebuilt with
        `keep_static=1`.
-   \[\~\] **MESA -\> LLVM-SPIR-V DEPENDENCY IMPLEMENTED.**
    -   Mesa now explicitly requires `spirv-llvm-translator`.
    -   Release bumped to 4.
    -   Existing working alternate source/rename policy is retained.
    -   Meson setup/compile/install is fail-fast.
    -   Runtime target: clean Mesa build after LLVM and SPIR-V
        translator are functional.
-   \[\~\] **PYTHON3-PYYAML DEPENDENCY/BUILD PATH HARDENED.**
    -   Required `python3-cython`/`libyaml` build chain is retained.
    -   Release bumped and wheel build/install stages now fail
        immediately instead of running installer after a failed wheel
        build.
-   \[\~\] **SYSUP NEW-DEPENDENCY PREFLIGHT IMPLEMENTED IN INSTALLER
    r64.**
    -   Before the mandatory `prt-get sysup`, installer r64 computes the
        outdated package set, expands dependencies, checks for newly
        missing dependencies, and `depinst`s those missing packages
        first.
    -   This works around CRUX/prt-get's documented behavior that
        `update`/`sysup` does not itself process newly introduced
        dependencies.
    -   Runtime target: upgrade an already-installed package whose new
        release gains a dependency and confirm the dependency is
        installed before sysup.
-   \[\~\] **PKGUTILS `download_source()` REGRESSION REMOVED.**
    -   pkgutils release bumped to 17.
    -   The r148 experimental function-rewriting download validator is
        removed entirely so pkgutils no longer renames/replaces the core
        `download_source()` implementation.
    -   Existing tmpfs-aware work-directory cleanup is retained.
    -   Runtime target: rebuild pkgutils and verify `download_source()`
        exists, then test normal download, cached source, 404/failure,
        and invalid-archive paths.
-   \[\~\] **PKGUTILS ACTIVE TMPFS MOUNTPOINT UPGRADE PROTECTION
    IMPLEMENTED.**
    -   `pkgadd.conf` now protects the exact `var/cache/pkg/build-work/`
        mountpoint from replacement/removal during package upgrade.
    -   Existing pkgmk work cleanup continues to delete contents rather
        than the mountpoint when it is actively mounted.
    -   Runtime target: upgrade pkgutils while
        `/var/cache/pkg/build-work` is mounted as tmpfs and verify the
        mount survives.
-   [x] **WPA_SUPPLICANT STALE OPENSSL PATCH REFERENCE ALREADY ABSENT IN
    SUPPLIED TREE.**
    -   The live VM already proved the corrected recipe builds/installs.
-   [x] **BOOST 1.92.0 SOURCE FILENAME FIX ALREADY PRESENT IN SUPPLIED
    TREE.**
    -   The supplied project already uses the corrected 1.92.0 source
        naming.
-   \[\~\] **CAIRO SOURCE RESILIENCE RETAINED + FAIL-FAST BUILD.**
    -   The supplied working alternate Cairo source is retained.
    -   Release bumped and Meson stages now fail immediately.
    -   Runtime target: clean source-cache download/build.
-   \[\~\] **LIBDRM SOURCE RESILIENCE / RENAME RETAINED + FAIL-FAST
    BUILD.**
    -   Debian source plus `renames=(libdrm-$version.tar.xz)` is
        retained.
    -   Release bumped and Meson stages now fail immediately.
    -   Runtime target: clean-cache download/extraction/build.
-   \[\~\] **MESA ALTERNATE SOURCE / RENAME RETAINED.**
    -   Debian-style alternate source and
        `renames=(mesa-$version.tar.xz)` remain in the permanent recipe
        and are exercised through the Mesa r152 build path.
-   \[\~\] **MASTER `xorg` META-PACKAGE CREATED.**
    -   Added `ports/xorg/xorg/Pkgfile`.
    -   Standard target is now `prt-get depinst xorg`.
    -   It pulls `xorg-server`, `xorg-libs`, `xorg-apps`, `xorg-fonts`,
        `xorg-driver`, and `xinit`.
    -   `xinit` is deliberately placed at the top-level meta-package
        rather than inside `xorg-apps` to avoid introducing an
        unnecessary dependency loop with the current server/apps
        relationship.
-   \[\~\] **`xorg-apps` CLASSIC BASELINE RESTORED.**
    -   `twm`, `xclock`, and `xterm` are restored to the `xorg-apps`
        dependency set.
    -   Duplicate `xkbcomp` dependency entry was removed.
    -   Runtime target: clean `prt-get depinst xorg` and basic
        startx/twm/xclock/xterm session.
-   \[\~\] **XINIT UPDATED / DEFAULT CHAIN RESTORED.**
    -   `xinit` remains a normal X.Org port and is pulled by the new
        top-level `xorg` meta-package.
    -   Recipe is fail-fast and documents the expected classic runtime
        clients.
-   \[\~\] **XTERM 410 TERMINFO OWNERSHIP CONFLICT FIXED IN RECIPE.**
    -   The BFSOS recipe's extra `make install-ti` pass was removed. The
        normal xterm install already installs the package; the second
        terminfo install was the source of duplicate terminfo ownership
        (`report+da2`, `report+version`) against the base terminfo
        provider.
    -   `xterm` no longer depends back on `xorg-apps`, avoiding a
        meta-package dependency cycle.
    -   Release bumped to 3.
    -   Runtime target: normal `prt-get depinst xterm` with no
        `pkgadd -f` and no duplicate ownership error.
-   \[\~\] **TWM / XCLOCK MODERNIZED FOR BASELINE X TEST.**
    -   `twm` updated to 1.0.13.1 and `xclock` to 1.2.1.
    -   Both recipes use fail-fast configure/build/install paths.
    -   Runtime target: start a minimal session through xinit/startx.
-   \[\~\] **OPENCHROME LEGACY DRIVER: DEFAULT META REMOVAL +
    COMPATIBILITY FIX IMPLEMENTED.**
    -   `xf86-video-openchrome` is removed from the default
        `xorg-driver` dependency set but remains available as an
        optional legacy VIA driver.
    -   Port release bumped and applies a current-X.Org shadow API
        compatibility edit (`shadowUpdatePackedWeak()` -\>
        `shadowUpdatePacked`), retains the existing `-fcommon`
        compatibility requirement, and is fail-fast.
    -   Runtime target: build the optional driver separately; it no
        longer blocks ordinary `prt-get depinst xorg`.
-   \[\~\] **VBOXVIDEO LEGACY DRIVER: DEFAULT META REMOVAL + C23
    COMPATIBILITY IMPLEMENTED.**
    -   `xf86-video-vboxvideo` is removed from the default `xorg-driver`
        dependency set but remains available as an optional
        VirtualBox-specific legacy driver.
    -   Port release bumped and compiles this old source with
        package-scoped `-std=gnu17`, avoiding C23's
        `bool`/`true`/`false` keyword conflict without globally
        downgrading BFSOS compiler policy.
    -   Recipe is fail-fast.
    -   Runtime target: optional-driver build; it no longer blocks the
        normal X.Org meta-package.
-   \[\~\] **XORG-DRIVER DEFAULT SET CLEANED.**
    -   OpenChrome and VBoxVideo are no longer default dependencies; the
        maintained/general drivers remain in the standard set.
    -   Runtime target: clean `prt-get depinst xorg-driver`.
-   [x] **STATIC r152 VALIDATION PASSED.**
    -   `bash -n` passes for Bootstrap, installer r64, pkgutils, and
        every Pkgfile modified in this pass.
    -   A project change manifest is shipped as
        `docs/r152-live-tracker-change-manifest.txt`.
    -   `scripts/install-bfs-menu-current.sh` points to
        `install-bfs-menu-v50-r64-package-dependency-fixes.sh`.

### r152 next VM regression order

1.  Push/sync the r152 project and run `ports -u`.
2.  Update/rebuild `pkgutils`; verify `/usr/bin/pkgmk` still defines
    `download_source()`.
3.  Rebuild LLVM with `keep_static=1`; verify `libLLVMDemangle.a`.
4.  Build/install `spirv-llvm-translator`.
5.  Build/install Graphite2; verify its library, headers, and
    `graphite2.pc`.
6.  Build Harfbuzz.
7.  Build Mesa.
8.  Run `prt-get depinst xorg`.
9.  Verify `xterm`, `twm`, `xclock`, and `xinit/startx` are present.
10. Start a minimal X session and separately test OpenChrome/VBoxVideo
    only if their legacy hardware coverage is desired.

## r153 --- X.Org live regression results --- 2026-08-23

-   [x] **XF86-VIDEO-OPENCHROME COMPATIBILITY FIX PASSED LIVE BUILD.**
    -   The r152 current-X.Org compatibility fix was tested on the BFSOS
        VM.
    -   `xf86-video-openchrome` now builds/installs successfully.
    -   The driver no longer needs to remain excluded from the standard
        driver set for build-compatibility reasons.
-   [x] **XF86-VIDEO-VBOXVIDEO C23 COMPATIBILITY FIX PASSED LIVE
    BUILD.**
    -   The r152 package-scoped GNU17 compatibility fix was tested on
        the BFSOS VM.
    -   `xf86-video-vboxvideo` now builds/installs successfully with the
        current BFSOS GCC toolchain.
    -   The driver no longer needs to remain excluded from the standard
        driver set for build-compatibility reasons.
-   [ ] **RESTORE OPENCHROME AND VBOXVIDEO TO `xorg-driver`
    META-PACKAGE.**
    -   Add `xf86-video-openchrome` and `xf86-video-vboxvideo` back to
        the default `xorg-driver` dependency list now that both
        corrected ports pass live build/install testing.
    -   Regression-test a clean `prt-get depinst xorg-driver` after
        restoring both dependencies.
    -   Keep the compatibility fixes in the individual driver ports.
-   [x] **BASIC X.ORG DESKTOP SESSION REGRESSION PASSED.**
    -   `twm`, `xterm`, and `xclock` now install and operate as expected
        on the live BFSOS VM.
    -   The xterm terminfo ownership correction is therefore validated
        in the live environment.
    -   The classic baseline X.Org application restoration is
        functioning as intended.
-   \[\~\] **TWM/XCLOCK SOURCE REACHABILITY FIXED DURING LIVE TEST.**
    -   The canonical `www.x.org` application source path was
        unreachable from the test environment.
    -   Prism-side ports for `twm` and `xclock` were switched to the
        reachable BLFS conglomeration mirror and live installation
        succeeded.
    -   Retain this as further evidence for the broader
        X.Org/Freedesktop fallback-source work already tracked.

## r154 --- Firefox dependency-chain live regression findings --- 2026-08-23

-   [ ] **NASM 3.02 XDOC VERSION MISMATCH.**
    -   The NASM port was updated to `version=3.02`, but the build
        recipe still hardcoded the old `2.16.03` xdoc download while
        attempting to extract `nasm-3.02-xdoc.tar.xz`.
    -   Update all xdoc references to the active `$version` or otherwise
        keep the documentation source version synchronized with the
        package version.
    -   Bump the port release.
    -   Regression-test `prt-get depinst nasm` from a clean source
        cache.
    -   Audit this port for other hardcoded version residues so future
        package version bumps do not leave stale secondary downloads.
-   [x] **FRIBIDI 1.0.16 MESON SOURCE-DIRECTORY FIX PASSED LIVE.**
    -   `pkgmk` already enters the extracted `fribidi-1.0.16` source
        directory before invoking `pkg_build()`.
    -   The recipe incorrectly called
        `meson setup build fribidi-1.0.16`, effectively referring to a
        nonexistent nested source directory.
    -   Corrected to configure the current source tree
        (`meson setup build .`) and converted configure/build/install to
        fail-fast chaining.
    -   Release bumped to 2.
    -   Live VM result: `fribidi 1.0.16-2` built and installed
        successfully.
-   [x] **LIBNGHTTP2 SOURCE/VERSION FIX PASSED LIVE.**
    -   The old `libnghttp2 1.64.0` source URL was stale/invalid.
    -   Port was updated to `1.70.0` and switched to the current
        upstream `nghttp2/nghttp2` release archive:
        `https://github.com/nghttp2/nghttp2/releases/download/v$version/nghttp2-$version.tar.gz`
    -   Live VM result: `libnghttp2 1.70.0-1` built and installed
        successfully.
    -   Retain this working source definition and audit dependent
        recipes for assumptions tied to the old 1.64.0 release.
-   [ ] **LIBSNDFILE 1.2.2 GCC 16 / C23 COMPATIBILITY.**
    -   Bundled ALAC sources define `false`, `true`, and `bool` in a way
        that conflicts with C23 keywords under the current GCC 16
        default C language mode.
    -   Apply a package-scoped compatibility mode such as
        `CFLAGS="${CFLAGS} -std=gnu17"` rather than weakening global
        BFSOS compiler policy.
    -   Bump the port release and regression-test a clean build.
    -   Make the recipe fail fast so `make install` and cleanup are not
        attempted after compilation has already failed.
-   [ ] **LIBSNDFILE OPTIONAL/FEATURE DEPENDENCY AUDIT.**
    -   The live configure output reported missing FLAC, Ogg, Vorbis,
        Opus, LAME, MPG123, and ALSA support.
    -   Decide which of these should be required dependencies for the
        BFSOS libsndfile feature baseline versus optional dependencies.
    -   Ensure Firefox/audio-desktop use cases receive the intended
        codec and sound support without silent feature loss.
    -   Regression-test `sndfile-info`/pkg-config and representative
        codec support after dependency metadata is finalized.
-   [ ] **YASM 1.3.0 GCC 16 / C23 COMPATIBILITY.**
    -   Yasm's old source defines `false`/`true` identifiers that
        conflict with C23 keyword behavior under GCC 16.
    -   Apply a package-scoped GNU17 compatibility flag instead of a
        global compiler downgrade.
    -   Release bumped from 2 to 3 during the live repair.
    -   Regression-test `prt-get depinst yasm`.
-   [ ] **YASM FAIL-FAST RECIPE CLEANUP.**
    -   After the initial Yasm compile failure, the recipe continued
        into install and produced secondary errors.
    -   Chain or explicitly test configure/build/install commands so the
        first real failure terminates the package build immediately.
    -   Audit the rest of this legacy recipe for commands that can mask
        the original error.
-   [ ] **PULSEAUDIO 17.0 FREEDESKTOP SOURCE TIMEOUT / FALLBACK.**
    -   The canonical `freedesktop.org/software/pulseaudio/releases/`
        source repeatedly timed out in the BFSOS VM, matching the
        broader Freedesktop/X.Org routing problem already tracked.
    -   The first Prism-side sed attempt failed to replace the URL
        because the actual recipe uses `$name` variables in the source
        string.
    -   The intended temporary source is the Debian DFSG archive:
        `https://ftp.debian.org/debian/pool/main/p/pulseaudio/pulseaudio_$version+dfsg1.orig.tar.xz`
    -   Keep `renames=(pulseaudio-$version.tar.xz)` so the build sees
        the expected local filename.
    -   Verify the exact URL, rebuild from a clean cache, and decide
        whether Debian remains the canonical BFSOS source or becomes a
        fallback once global mirror logic is fixed.
-   [ ] **NODE.JS 24.19.0 OBSOLETE/INVALID `--shared-libnghttp2`
    CONFIGURE FLAG.**
    -   Node.js configure/GYP fails with:
        `gyp: --shared-libnghttp2 not found`
    -   The BFSOS recipe passes `--shared-libnghttp2`, which current
        Node 24.19.0 no longer accepts in this invocation path.
    -   Remove the obsolete flag, bump the release from 2 to 3, and
        regression-test `prt-get depinst nodejs`.
    -   Do not treat the later missing `out/Release/build.ninja` error
        as the root cause; it is only a consequence of configure/GYP
        failing first.
-   [ ] **NODE.JS FAIL-FAST RECIPE CLEANUP.**
    -   After `Error running GYP`, the recipe incorrectly continued into
        `make`, `make install`, and cleanup.
    -   Make configure/GYP failure terminate immediately.
    -   Ensure the package leaves the first actionable error visible
        instead of burying it under secondary Ninja/install/cleanup
        errors.
-   [x] **NSS 3.112 LIVE BUILD PASSED DURING FIREFOX DEPENDENCY TEST.**
    -   `nss 3.112-1` built successfully and installed before the
        Node.js failure.
    -   No corrective action required from this regression pass.

### r154 Firefox-chain regression state

The Firefox dependency walk has now successfully progressed through
multiple previously broken packages. Continue rerunning:

`sudo prt-get depinst firefox`

after each corrected dependency is pushed from Prism and synchronized
with `ports -u`. The current next blocker is Node.js until its invalid
`--shared-libnghttp2` option is removed and the port is retested.

## r155 --- xmlto / shared-mime-info live Firefox-chain findings --- 2026-08-23

-   [x] **XMLTO 0.0.29 SOURCE URL FIX APPLIED.**
    -   The original Pagure archive URL returned HTTP 404.
    -   The alternate `releases.pagure.org` URL also returned HTTP 404
        during direct Prism testing.
    -   The Prism-side `xmlto` port source was switched to a working
        mirror and the source-URL issue has been corrected.
    -   Preserve the working mirror in the project rather than reverting
        to either dead Pagure URL.
    -   Keep this package covered by the broader source-URL/fallback
        audit so future dead upstream locations do not require one-off
        live repairs.
-   [ ] **SHARED-MIME-INFO 2.5.1 XMLTO DEPENDENCY/BUILD POLICY.**
    -   Live Firefox dependency testing reached
        `shared-mime-info 2.5.1-3`.
    -   Meson found `/usr/bin/xmllint` but failed because `xmlto` was
        not installed:
        `ERROR: Program 'xmlto' not found or not executable`.
    -   The current BFSOS build configuration therefore requires
        `xmlto`, but package dependency metadata did not ensure it was
        installed automatically.
    -   Decide the permanent BFSOS policy: declare `xmlto` as a build
        dependency for the current configuration, or alter the
        configuration so optional documentation/tooling does not make
        `xmlto` mandatory.
    -   `prt-get depinst shared-mime-info` must succeed on a clean BFSOS
        installation without manual dependency intervention.
-   [ ] **SHARED-MIME-INFO FAIL-FAST MESON CLEANUP.**
    -   After `meson setup` failed on missing `xmlto`, the recipe
        continued into `meson compile` and `meson install`.
    -   Chain/check the Meson configure, compile, and install stages so
        the package terminates immediately at the first real failure.
    -   Regression-test from a clean build directory after the xmlto
        dependency/build-policy fix.

### r155 current Firefox-chain continuation

`xmlto` source repair is complete on the Prism project. After
synchronizing the corrected port to the VM, install/retest `xmlto`, then
`shared-mime-info`, and resume with `sudo prt-get depinst firefox`.

## r156 --- Modern X.Org / Wayland default integration --- 2026-08-23

-   [ ] **XORG META-PACKAGE SHOULD INSTALL CORE WAYLAND/XWAYLAND STACK.**
    -   **Area:** X.Org / Wayland integration and default graphical package set.
    -   **Observed during live dependency testing:** `libxkbcommon 1.13.2`
        detected that `wayland-protocols` was not installed and attempted to
        disable Wayland support, while its Meson invocation did not actually
        receive the generated `-Denable-wayland=false` option. This exposed a
        broader packaging expectation for a modern BFSOS graphical install.
    -   **Required default behavior:** `prt-get depinst xorg` should also
        install:
        -   `wayland`
        -   `wayland-protocols`
        -   `xwayland`
    -   **Rationale:** Modern graphical environments commonly combine X.Org
        and Wayland components. The standard BFSOS X.Org installation should
        provide the core Wayland runtime/protocol pieces and XWayland
        compatibility instead of requiring users or dependent packages to
        discover them manually.
    -   **Implementation:** Update the appropriate `xorg` meta-package
        dependency chain so all three packages are installed by the normal
        X.Org dependency installation.
    -   **Dependency safety:** Check the resulting graph for dependency cycles,
        especially any reverse dependency from `wayland`, `wayland-protocols`,
        or `xwayland` back through X.Org meta-packages.
    -   **Regression test:** On a clean BFSOS installation run
        `prt-get depinst xorg` and verify `wayland`, `wayland-protocols`, and
        `xwayland` are all installed automatically without manual intervention.
    -   **Follow-up:** Rebuild `libxkbcommon` after the default Wayland stack is
        present and verify its Wayland support configures normally.
### libnotify 0.8.8 missing GTK4 dependency metadata / Meson fail-fast cleanup

-   [ ] **FIX `libnotify` GTK4 dependency metadata and fail-fast behavior.**
    -   **Area:** `ports/opt/libnotify`
    -   **Observed during Firefox dependency testing:** `libnotify 0.8.8-2`
        reached Meson configuration successfully, found `gdk-pixbuf`, GLib,
        GIO, and GIO-Unix, but failed because GTK4 was not installed:
        `ERROR: Dependency "gtk4" not found (tried pkg-config and cmake)`.
    -   **Dependency fix:** Ensure the `libnotify` port declares the BFSOS
        package providing GTK4 (`gtk4`) so `prt-get depinst libnotify`
        installs it automatically on a clean system.
    -   **Build-flow cleanup:** The current recipe continued to
        `ninja install` after `meson setup` failed, producing the secondary
        and misleading `build.ninja: No such file or directory` error.
        Make the Meson configure/build/install chain fail immediately when
        configuration fails (for example with `&&` chaining or explicit
        error handling consistent with the BFSOS Pkgfile extensions).
    -   **Regression test:** On a clean BFSOS installation run
        `prt-get depinst libnotify` and verify GTK4 is installed
        automatically, Meson configures successfully, `libnotify 0.8.8`
        builds/installs without manual intervention, and a forced Meson
        configuration failure does not continue into `ninja install`.
### GTK4 unexpectedly pulls Qt5 — dependency-chain audit

-   [ ] **RESEARCH WHY `prt-get depinst gtk4` PULLS IN `qt5`.**
    -   **Area:** GTK4 / graphical dependency metadata.
    -   **Observed during live testing:** Installing GTK4 caused the dependency
        resolver to begin building `qt5`, even though Qt5 should not normally
        be an inherent requirement of GTK4 itself.
    -   **Research task:** Identify the exact BFSOS dependency chain from
        `gtk4` to `qt5` using the current port metadata.
    -   **Likely issue class:** An optional feature, helper package, or
        overbroad dependency may be declaring Qt5 as a hard dependency and
        dragging the full Qt5 stack into a GTK4 installation.
    -   **Required fix:** If Qt5 is not a genuine hard requirement, remove it
        from the default GTK4 dependency path or split/narrow the responsible
        package dependency so Qt5 is only installed when the feature that
        actually needs it is requested.
    -   **Do not guess:** Record the exact package-to-package chain before
        changing dependency metadata.
    -   **Regression test:** On a clean BFSOS system run
        `prt-get depinst gtk4` and verify Qt5 is not installed unless there is
        a documented, justified hard dependency.
### Kernel maintenance — mainline, headers, and LTS tracking

-   [ ] **MAINTENANCE CHECK 1 — KEEP THE MAINLINE `linux` PORT CURRENT.**
    -   Update the BFSOS `linux` port to **7.1.9**.
    -   Verify the upstream source URL, version-dependent patches, package metadata,
        kernel configuration compatibility, and build/install behavior.
    -   Regression-test that the new kernel installs cleanly, produces the expected
        `/boot` kernel image and `/usr/lib/modules/<version>` tree, and still works
        with the BFSOS initramfs/bootloader workflow.
    -   Keep this as an ongoing maintenance check so the mainline kernel port does
        not silently fall behind upstream releases.

-   [ ] **MAINTENANCE CHECK 2 — KEEP `linux-headers` SYNCHRONIZED WITH MAINLINE LINUX.**
    -   Update the BFSOS `linux-headers` port to **7.1.9**.
    -   Keep `linux-headers` synchronized with the mainline `linux` port unless
        there is a deliberate documented reason for the versions to differ.
    -   Verify source URL/version metadata and regression-test installation of the
        exported userspace kernel headers.
    -   Add an update-time/version-audit check so a kernel bump does not leave
        `linux-headers` behind.

-   [ ] **MAINTENANCE CHECK 3 — TRACK AND KEEP THE `linux-lts` PORT CURRENT.**
    -   Track the currently supported upstream Linux LTS kernel release and keep
        the BFSOS `linux-lts` port updated to the latest appropriate LTS point
        release.
    -   Verify the LTS source URL, any BFSOS/BLFS/Debian compatibility patches,
        kernel configuration, initramfs generation, module tree, and bootloader
        integration whenever the LTS version changes.
    -   Treat this as an ongoing maintenance check rather than a one-time version
        bump.

-   [ ] **ADD/VERIFY LTS KERNEL SYMLINK UPDATE LOGIC.**
    -   Ensure installing or updating `linux-lts` creates/refreshes the intended
        stable LTS kernel symlink rather than leaving a stale link pointing at an
        older versioned kernel image.
    -   The symlink target must be derived from the kernel version actually
        installed by the `linux-lts` package, not from a hard-coded version.
    -   Make replacement atomic/idempotent so reinstalls and upgrades are safe.
    -   Do not let the LTS package accidentally repoint a mainline-kernel symlink;
        keep mainline and LTS link names/ownership unambiguous.
    -   Regression-test fresh install, same-version reinstall, and LTS point-release
        upgrade and verify the symlink resolves to the correct existing kernel
        image after each case.

## r160 --- Build-work tmpfs capacity / heavyweight package build policy --- 2026-08-23

-   [ ] **FIX `/var/cache/pkg/build-work` TMPFS CAPACITY FOR LARGE BUILDS.**
    -   **Area:** pkgutils / pkgmk build workspace / installer or system mount policy.
    -   Live Qt5/QtWebEngine testing exposed that `/var/cache/pkg/build-work` is mounted as a **16 GiB tmpfs**.
    -   QtWebEngine/Chromium exhausted that tmpfs during compilation and produced the real failure `No space left on device`; the subsequent GNU Binutils/BFD assertion spam was secondary fallout, not evidence of a Binutils defect.
    -   The VM's disk-backed `/var` had roughly **483 GiB free**, so total storage capacity was not the problem.
    -   Decide and implement a permanent BFSOS policy rather than allowing heavyweight packages to fail against a fixed 16 GiB RAM-backed build directory.
    -   Evaluate all three approaches: increase the tmpfs size, make the tmpfs size configurable, and/or automatically use disk-backed `/var/cache/pkg/build-work` for heavyweight packages such as Qt5/QtWebEngine/Chromium.
    -   Prefer a solution that retains fast RAM-backed builds for normal packages without imposing an artificial build-size ceiling on unusually large packages.
    -   Add a pre-build capacity check or fallback mechanism so a large build cannot unexpectedly die after substantial compilation time solely because the build-work tmpfs filled.
    -   Regression-test Qt5/QtWebEngine after the build-work storage policy is corrected.

## r161 --- Zstandard compression policy audit --- 2026-08-23

-   [ ] **MOVE KERNEL-RELATED COMPRESSION TO ZSTANDARD WHERE SUPPORTED.**
    -   Audit the BFSOS kernel build/install workflow for remaining gzip/xz/lz4
        compression and standardize on **Zstandard (zstd)** where Linux and the
        associated tooling support it.
    -   Review at minimum:
        - kernel image compression configuration,
        - loadable kernel module compression,
        - initramfs compression,
        - firmware/initramfs artifacts that are generated as part of the kernel
          installation path,
        - any kernel-package archive or installer-side compression assumptions.
    -   Ensure the kernel configuration has the required Zstd decompressor support
        built in early enough for boot/initramfs use.
    -   Verify dracut and the BFSOS installer/kernel-update logic correctly recognize
        and generate Zstd-compressed artifacts.
    -   Confirm GRUB/systemd-boot and the installed boot path can load the resulting
        kernel/initramfs without regression.
    -   Do not convert an artifact to Zstd merely for consistency if the consuming
        boot/runtime component cannot safely support it.
    -   Regression-test both the mainline `linux` and `linux-lts` packages after the
        compression-policy change.

-   [ ] **EVALUATE AND CHANGE DEFAULT BUILT-PACKAGE COMPRESSION TO ZSTANDARD.**
    -   Review the current pkgmk/pkgutils package output policy, which presently
        produces packages such as `*.pkg.tar.xz`.
    -   Prefer **Zstandard** as the BFSOS default package compression format if the
        current pkgutils/pkgadd toolchain fully supports it.
    -   Target a format such as `*.pkg.tar.zst` rather than `*.pkg.tar.xz`.
    -   Update the pkgmk configuration/default compression command and any filename,
        cache, repository, installer, bootstrap, cleanup, or package-discovery logic
        that assumes `.pkg.tar.xz`.
    -   Preserve backward compatibility with existing `.pkg.tar.xz` packages where
        practical so old caches/repositories do not become unusable immediately.
    -   Verify `pkgmk`, `pkgadd`, `pkgrm`, `prt-get`, repository/update tooling, the
        installer, bootstrap scripts, package cache handling, and upgrade paths all
        work with Zstd-compressed packages.
    -   Compare package size, compression/decompression speed, build-time overhead,
        and installation speed before finalizing the default compression level.
    -   Add regression coverage so future code does not hard-code one package
        compression extension.

## r162 --- Qt5 / python3-html5lib dependency-chain fixes --- 2026-08-23

-   [ ] **QT5: ADD `python3-html5lib` AS AN EXPLICIT BUILD DEPENDENCY.**
    -   Live Qt5 5.15.19 testing reached the QtWebEngine/Chromium build and then
        failed when the bundled BeautifulSoup code attempted to select the
        `html5lib` parser but the Python `html5lib` module was not installed.
    -   `prt-get search html5lib` confirms BFSOS already provides the port
        `python3-html5lib`.
    -   Add `python3-html5lib` to the Qt5 port dependency metadata whenever
        QtWebEngine is enabled by the BFSOS Qt5 build.
    -   Do not leave this as a manual pre-build step: a clean
        `prt-get depinst qt5` must install the Python parser dependency before
        QtWebEngine compilation starts.
    -   Regression-test from a clean package state and verify Qt5 proceeds past
        the Chromium `about_tracing`/BeautifulSoup generation step without
        `bs4.FeatureNotFound: Couldn't find a tree builder ... html5lib`.

-   [ ] **`python3-html5lib`: KEEP THE PYTHON 3.14 / MODERN-SETUPTOOLS COMPATIBILITY FIX.**
    -   Live `prt-get depinst python3-html5lib` initially failed because
        html5lib 1.1's old `setup.py` imports the removed/deprecated top-level
        `pkg_resources` API. Testing confirmed `python3-setuptools` 84.0.0 is
        installed and importable, but it no longer provides an importable
        top-level `pkg_resources`, so adding setuptools alone is not a fix.
    -   Keep `python3-packaging` as an explicit dependency and patch the obsolete
        `pkg_resources.parse_version` use to the modern `packaging.version`
        interface.
    -   Keep the additional Python 3.14 AST compatibility changes required by
        html5lib 1.1 (`ast.Str` -> `ast.Constant`, and `.s` -> `.value` for the
        parsed version string).
    -   Bump the port release for the final compatibility recipe and keep every
        build/install step fail-fast.
    -   Also replace the currently missing package checksum: the live build
        emitted `WARNING: Md5sum not found, creating new.` for
        `html5lib-1.1.tar.gz`. Record and ship the verified checksum rather than
        relying on pkgmk to generate one during an install attempt.
    -   Regression-test a clean `prt-get depinst python3-html5lib`, verify
        `python3 -c "import html5lib; print(html5lib.__version__)"` succeeds,
        then rerun a clean `prt-get depinst qt5` to validate the entire
        dependency chain.


## r163 --- aaa_filesystem duplicate package-owned files cleanup --- 2026-08-23

-   [ ] **REMOVE DUPLICATE PACKAGE-OWNED FILES FROM `aaa_filesystem` / BASE SKELETON.**
    -   Audit `ports/core/aaa_filesystem` for files that are also installed and
        owned by normal packages, and remove those duplicates from
        `aaa_filesystem` rather than requiring forced package installation.
    -   Confirmed example: Qt5 5.15.19-9 built successfully but normal
        installation failed because `etc/profile.d/qt5.sh` was already present:
        `pkgadd: listed file(s) already installed (use -f to ignore and overwrite)`.
    -   `prt-get -f depinst qt5` then installed Qt5 successfully, confirming this
        was a package file-ownership collision rather than a Qt5 build failure.
    -   `etc/profile.d/qt5.sh` should be owned by the Qt5 package if Qt5 ships it;
        remove the duplicate copy from `aaa_filesystem` (or whichever base port
        currently installs it).
    -   Extend the fix beyond this one file: compare the `aaa_filesystem` package
        manifest/tree against package manifests and identify other duplicate
        package-specific files under `/etc`, `/usr`, profile.d, configuration
        directories, etc. Keep only true base filesystem directories/defaults in
        `aaa_filesystem` where appropriate.
    -   Regression-test with ordinary `prt-get depinst` installs and ensure no
        package requires `-f` merely to overwrite a file preinstalled by
        `aaa_filesystem`.
    -   Do **not** make `prt-get -f` the permanent workaround; package ownership
        should be unambiguous so upgrades/removals cannot accidentally damage a
        file owned conceptually by another package.

## r164 --- ABI-sensitive library audit / reverse-dependency rebuild handling --- 2026-08-23

-   [ ] **FOLLOW-UP THE PORTS AUDIT FOR ABI/SONAME-SENSITIVE LIBRARY UPDATES.**
    -   The previous ports audit did not catch that BFSOS still shipped ICU
        77.1 while Firefox 154 requires `icu-i18n >= 78.1`. Live testing
        required updating the ICU port to 78.3 before Firefox configuration
        could continue.
    -   Treat this as an audit-gap item, not merely a Firefox-specific fix:
        review major shared-library ports against current consumers and current
        BLFS guidance where applicable, especially libraries whose upgrades
        change SONAMEs or minimum supported versions.
    -   When a shared-library SONAME changes, identify installed reverse
        dependencies that were linked against the old SONAME and rebuild them
        before considering the library upgrade complete.
    -   Confirmed example: after upgrading ICU 77.1 -> 78.3, `/usr/bin/node`
        remained linked to `libicui18n.so.77`. Firefox then reported Node.js as
        unavailable because Node itself could not start after the old ICU 77
        library disappeared.
    -   Rebuild Node.js against ICU 78.3 and audit other installed consumers for
        references to `libicu*.so.77` / missing libraries. Do not create fake
        compatibility symlinks from ICU 77 SONAMEs to ICU 78.
    -   Investigate adding or improving BFSOS reverse-dependency tooling so an
        ABI-changing package update can automatically identify packages needing
        rebuilds, or at minimum emit a clear post-update rebuild list.
    -   Include ABI/reverse-dependency validation in future core/opt ports audits
        instead of checking only port presence, source version, and build recipe.
    -   Regression-test the ICU update path: install representative ICU consumers
        on the old version, update ICU across a SONAME bump, detect/rebuild those
        consumers, verify `ldd` reports no missing ICU libraries, then confirm
        Node.js and Firefox configuration both run successfully.

## r165 --- Full core / opt / xorg ports re-audit required --- 2026-08-23

-   [ ] **RE-AUDIT ALL PACKAGES IN `ports/core`, `ports/opt`, AND `ports/xorg`; THE PREVIOUS TWO-PASS AUDIT WAS INCOMPLETE.**
    -   The earlier collection audit was intended to review the packages in
        `core`, `opt`, and `xorg` as a whole after the first pass was disrupted
        by connection/retrieval problems. Live dependency testing has now shown
        that packages were still missed even after the second pass.
    -   Confirmed example: `icu` remained at 77.1 even though Firefox 154
        requires `icu-i18n >= 78.1`. ICU had to be updated to 78.3 during live
        testing before Firefox configuration could continue.
    -   Do not limit this follow-up to ICU, Firefox, Node.js, ABI changes, or
        packages currently reached by `prt-get depinst gtk4`. Treat the entire
        `core`, `opt`, and `xorg` trees as needing another systematic review.
    -   For every port in those three collections, verify at minimum:
        current upstream version; source URL; checksum metadata; declared
        dependencies and build dependencies; optional-vs-required dependency
        accuracy; build/install commands; current compiler/Python/Rust
        compatibility; DESTDIR/PKG staging correctness; fail-fast behavior;
        post-install/pre-install commands; duplicate-file ownership; and
        whether the installed artifacts match what the port claims to provide.
    -   Compare relevant packages against current LFS/BLFS guidance where that
        guidance applies, while accounting for BFSOS using newer/rapid-release
        packages in some cases (for example Firefox rather than Firefox ESR).
        Also compare against upstream and other maintained distributions when
        BLFS does not cover the package or is behind BFSOS.
    -   Pay special attention to shared-library/SONAME upgrades. When a library
        changes ABI, identify and rebuild all reverse dependencies rather than
        leaving installed programs linked against removed SONAMEs.
    -   Confirmed example of the above: after ICU 77.1 -> 78.3, the installed
        Node.js binary still required `libicui18n.so.77`, causing Firefox to
        report Node.js as unavailable until Node is rebuilt.
    -   Audit package dependency chains for unexpected heavyweight pulls. The
        GTK4 installation path unexpectedly pulled Qt5 and then Firefox-related
        components, exposing multiple overbroad or stale dependency issues.
        Determine which dependencies are truly required and narrow metadata
        where optional features are causing unnecessary dependency trees.
    -   Produce an explicit audit result for every package, even when no change
        is required, so packages cannot silently fall through the review.
        Record package name, current BFSOS version, checked upstream/current
        version, result (`OK`, `UPDATE`, `FIX`, or `REVIEW`), and any dependency
        or ABI notes.
    -   Run the re-audit from a complete local copy of the ports tree so network
        or connection failures cannot silently truncate the review. If external
        verification fails for any package, mark that package `UNVERIFIED` and
        revisit it rather than assuming it is current.
    -   After making changes, regression-test representative clean dependency
        installs from each collection and run a reverse-dependency / missing
        shared-library scan before considering this audit complete.

## r166 --- Firefox dav1d dependency metadata --- 2026-08-23

-   [ ] **`firefox`: ADD `dav1d` AS AN EXPLICIT DEPENDENCY.**
    -   Live Firefox 154 dependency/build testing exposed `dav1d` as a required
        dependency that was not declared by the BFSOS Firefox port.
    -   Add `dav1d` to the Firefox Pkgfile dependency metadata so a clean
        `prt-get depinst firefox` installs it automatically before Firefox
        configuration/build begins.
    -   Verify the Firefox build uses the intended system `dav1d` installation
        and that the dependency is genuinely required by the current Firefox
        154 recipe rather than being an accidental optional feature.
    -   Include this miss in the r165 full `core` / `opt` / `xorg` dependency
        re-audit: required build/runtime dependencies must be validated from a
        clean dependency state, not inferred from packages already present on
        the development/test system.
    -   Regression-test from a clean state with `dav1d` absent: run
        `prt-get depinst firefox`, confirm `dav1d` is pulled automatically, and
        verify Firefox proceeds past the dependency/configure check.

## r167 --- pkgmk compressed-patch extension support --- 2026-08-23

-   [ ] **EXTEND PKGMK PATCH HANDLING TO SUPPORT COMPRESSED PATCH SOURCES CENTRALLY.**
    -   Live Firefox/libpng testing showed `libpng` 1.6.58 was installed without
        the APNG symbols Firefox requires even though the port source list
        includes `libpng-1.6.58-apng.patch.gz`.
    -   Investigate the current `_patch()` / pkgmk extension logic and confirm
        whether compressed patch sources are recognized and applied.
    -   If they are not, add centralized support for common forms such as:
        `*.patch.gz`, `*.diff.gz`, `*.patch.xz`, `*.diff.xz`,
        `*.patch.bz2`, and `*.diff.bz2`.
    -   Prefer decompressing compressed patches to stdout and piping them into
        `patch` rather than requiring every individual Pkgfile to duplicate
        decompression logic.
    -   Preserve existing handling for ordinary `*.patch` / `*.diff` sources.
    -   Ensure a decompression error or patch-application failure returns a
        non-zero status and aborts the package build. A failed patch must never
        be masked by later successful build/install commands.
    -   Avoid double-applying patches: verify whether the current generic patch
        path already handles any compressed formats before adding new cases.
    -   Regression-test with `ports/core/libpng`:
        rebuild from a clean source tree, confirm the APNG patch is applied,
        verify `nm -D /usr/lib/libpng16.so` exposes `png_get_acTL` and
        `png_set_acTL`, and then confirm Firefox's system-libpng APNG configure
        check passes.
    -   Audit the ports tree for other compressed patch sources so this central
        change can replace package-specific workarounds where appropriate.

## r168 --- Future pkgmk multilib and patch-control extensions --- 2026-08-23

-   [ ] **REPLACE THE SEPARATE `compat-32` PORTS TREE WITH OPTIONAL PER-PORT 32-BIT BUILD SUPPORT IN PKGMK EXTENSIONS.**
    -   Long-term goal: remove the duplicated 32-bit ports collection and keep
        a single canonical Pkgfile for each package.
    -   Add a pkgmk extension mechanism that allows a port to request an
        additional 32-bit build after its normal 64-bit build completes.
    -   Model the multilib build flow after the MLFS/GLFS/LFS-style approach:
        use the appropriate 32-bit compiler/linker flags, library directory,
        pkg-config search path, and architecture-specific configure options,
        but adapt installation for BFSOS packaging.
    -   The 32-bit build must **stage into `$PKG`**, not install directly to the
        running system. Its output should become part of the package archive
        produced by pkgmk, alongside the normal 64-bit files.
    -   Keep the normal 64-bit build as the primary/default phase. Only ports
        that explicitly opt into multilib should run the second 32-bit phase.
    -   Design the extension so a Pkgfile can provide package-specific 32-bit
        configure/build/install hooks or variable overrides where generic
        behavior is insufficient.
    -   Define sane default multilib paths and behavior, for example keeping
        64-bit libraries in `/usr/lib` and 32-bit libraries in the BFSOS
        multilib library directory, while preventing duplicate binaries,
        headers, documentation, pkg-config files, or architecture-neutral data
        from colliding in `$PKG`.
    -   Ensure the second build uses a clean/separate build directory so 32-bit
        and 64-bit objects cannot contaminate one another.
    -   Handle packages whose build systems need special multilib treatment
        (Autotools, Meson, CMake, hand-written Makefiles, etc.) without forcing
        a separate duplicated port.
    -   Add dependency/build-order handling so 32-bit dependencies are
        available before a package's 32-bit phase runs, while avoiding a second
        manually maintained dependency tree.
    -   Plan a migration path from existing `compat-32` ports: compare each
        current compat port against its native port, identify special 32-bit
        overrides, fold those differences into the unified Pkgfile/extension
        hooks, then remove the compat port only after regression testing.
    -   Regression-test representative multilib packages and verify the final
        package archive contains both correct 64-bit and 32-bit libraries while
        remaining cleanly installable/removable through pkgadd/pkgremove.

-   [ ] **ADD A PKGFILE SWITCH/HINT TO DISABLE PKGMK'S AUTOMATIC PATCH APPLICATION.**
    -   Current pkgmk extension logic automatically applies patch sources before
        `pkg_build()`. Add a package-level control for ports that need to manage
        patching themselves.
    -   Provide an explicit, simple Pkgfile variable or extension flag such as
        `PKGMK_AUTO_PATCH=no` / equivalent rather than relying on naming tricks
        or removing patch files from `source=()`.
    -   When automatic patching is disabled, pkgmk should still download/copy
        patch sources normally but leave application order, decompression,
        patch level, conditional application, and error handling to the
        Pkgfile.
    -   Default behavior must remain unchanged: ports that do not set the flag
        continue to receive automatic patch handling.
    -   Make this compatible with the r167 compressed-patch work so a port can
        either use centralized automatic handling for `.patch`, `.patch.gz`,
        `.patch.xz`, etc., or opt out and implement its own sequence.
    -   Document the flag in the pkgmk extension/Pkgfile conventions and include
        examples for ports that need conditional patches, non-`-p1` patch
        levels, generated patch inputs, or multiple patches in a strict custom
        order.
    -   Regression-test both modes: one port using normal automatic patching and
        one port explicitly disabling it and applying the same patch manually,
        verifying failures propagate correctly in either case.

## r169 --- Firefox source-port post-build dependency verification --- 2026-08-23

-   [ ] **`firefox` SOURCE PORT: VERIFY THE FINAL DEPENDENCY SET AND CORRECT THE PKGFILE AS NECESSARY.**
    -   Firefox 154.0 now completes a full source build successfully after the
        dependency and compatibility fixes discovered during live testing.
    -   Before considering the source-built Firefox port complete, launch and
        exercise the installed browser and verify that its declared dependency
        metadata matches what the finished build/runtime actually requires.
    -   Audit the final Firefox Pkgfile dependency line against the successful
        build, configure checks, linked libraries, runtime behavior, and clean
        `prt-get depinst firefox` behavior.
    -   Add any required build/runtime dependencies that were only present
        accidentally on the test system, and remove or reclassify dependencies
        that are optional or no longer required.
    -   Specifically retain and verify dependencies uncovered during this test
        cycle, including the corrected ICU/NSS/NSPR requirements and the newly
        added `dav1d` dependency, while checking the remainder of the dependency
        chain rather than assuming the current list is complete.
    -   Run `ldd` / missing-library checks against the installed Firefox
        executable and major shipped shared objects (especially `libxul.so`) and
        map required libraries back to BFSOS package names.
    -   Test representative runtime functionality such as browser startup,
        normal page rendering, HTTPS/TLS, audio/video playback, AV1 playback,
        downloads, and GTK/X11/Wayland integration as applicable.
    -   After verification, remove the source-built Firefox package and test
        `firefox-bin` separately so the two ports do not mask one another's
        missing dependencies or file-ownership problems.
    -   Finish with a clean-state regression test: install Firefox's dependency
        chain through `prt-get depinst firefox`, build/install it without
        manually preinstalling undeclared packages, and confirm the browser runs
        correctly.

## r170 --- firefox-bin dependency inconsistency and Plasma BLFS alignment --- 2026-08-23

-   [ ] **INVESTIGATE INCONSISTENT `firefox-bin` DEPENDENCY RESOLUTION FOR `dbus-glib`.**
    -   On the first `prt-get depinst firefox-bin` attempt, `prt-get` tried to
        pull in `dbus-glib`.
    -   On the second attempt, `prt-get` no longer tried to install `dbus-glib`,
        even though verification showed `dbus-glib` had never actually been
        installed successfully before the source URL was corrected.
    -   Treat this as a dependency-metadata / repository-layout correctness bug
        until proven otherwise.
    -   Audit the `firefox-bin` Pkgfile dependency line for malformed spacing,
        hidden characters, line-ending issues, duplicated dependency tokens, or
        stale metadata.
    -   Search the entire ports tree for duplicate `firefox-bin` directories,
        duplicate `dbus-glib` ports, shadowed Pkgfiles, stale collection copies,
        or same-name ports in multiple collections that could cause `prt-get`
        to resolve a different recipe between runs.
    -   Check whether `ports -u`, local package database state, failed package
        records, or cached dependency metadata can make `prt-get depinst`
        incorrectly conclude a dependency is already satisfied after a failed
        install.
    -   Verify package database ownership/state after failed dependency installs
        so a package that never completed installation cannot be treated as
        installed on a subsequent dependency pass.
    -   Add a regression test: start from a clean system with `dbus-glib`
        absent, run `prt-get depinst firefox-bin`, intentionally fail the
        `dbus-glib` download/build once, confirm `dbus-glib` is still reported
        missing, then retry and verify `prt-get` attempts it again.
    -   Keep the corrected `dbus-glib` source URL and verify version/source
        metadata so network flakiness does not mask dependency-state bugs.

-   [ ] **ALIGN ALL `ports/plasma` PACKAGE VERSIONS WITH CURRENT BLFS DEVELOPMENT GUIDANCE AND VERIFY EVERY SOURCE URL.**
    -   Perform a complete package-by-package audit of the entire `ports/plasma`
        collection.
    -   For every Plasma/KDE Frameworks/related port covered by current BLFS
        development guidance, update BFSOS to the same version BLFS dev is using
        unless there is a documented BFSOS-specific reason to differ.
    -   Do not update only the obvious top-level Plasma packages; include the
        complete dependency set in the Plasma collection so Frameworks, Plasma
        libraries, utilities, and supporting KDE components remain on a
        mutually compatible release set.
    -   Verify every source URL against the current upstream KDE download layout
        and the version selected by BLFS dev. Fix stale release paths, moved
        archives, incorrect major/minor subdirectories, renamed tarballs, and
        dead mirrors.
    -   Verify checksums for every changed source and do not rely on pkgmk
        creating checksum metadata during live install attempts.
    -   Compare BFSOS dependency metadata and build instructions against BLFS dev
        for each applicable package, while preserving BFSOS packaging/staging
        conventions and fail-fast behavior.
    -   Flag packages not covered by BLFS dev for separate upstream verification
        rather than leaving their versions or URLs unverified.
    -   Produce an explicit audit result for every Plasma port (`OK`, `UPDATE`,
        `FIX`, or `UNVERIFIED`) so no package silently falls through the pass.
    -   After updates, run dependency-order validation across the Plasma tree and
        regression-test representative clean installs/upgrades to catch ABI,
        renamed-package, or source-URL issues before desktop testing.

## r171 --- BLFS baseline correction + Plasma/pkgmk maintenance pass --- 2026-08-23

-   [x] **CORRECT THE KDE/PLASMA AUDIT BASELINE TO THE CURRENT BLFS SYSTEMD DEVELOPMENT BOOK.**
    -   Use KDE Frameworks **6.26.0**, Plasma **6.6.5**, and KDE
        Gear/release-service applications **26.04.1**.
    -   Also use Extra-CMake-Modules **6.26.0**,
        `plasma-wayland-protocols` **1.21.0**, `kirigami-addons` **1.12.1**,
        `pulseaudio-qt` **1.8.1**, and `polkit-qt-1` **0.201.1** where
        applicable.
    -   Previous references to Frameworks 6.29.0 were traced to a typo /
        misreading; 6.26.0 is the intended BLFS development baseline.
-   [~] **PLASMA TREE VERSION ALIGNMENT IMPLEMENTED; FETCH/BUILD REGRESSION STILL REQUIRED.**
    -   Updated existing KF6 6.13.0 ports to 6.26.0, Plasma 6.3.4/6.3.4.1
        ports to 6.6.5, and KDE Gear 25.04.0 ports to 26.04.1.
    -   Updated the explicitly tracked supporting KDE packages above and
        adjusted hard-coded old version components in affected KDE source URLs.
    -   147 Plasma-tree Pkgfiles were changed in this pass; all 169 Plasma
        Pkgfiles pass `bash -n`.
    -   Do **not** mark the full URL/dependency audit complete until every
        changed source has been fetched/verified and representative clean
        dependency/build tests have run.
-   [x] **PKGMK COMPRESSED AUTOMATIC PATCH SUPPORT IMPLEMENTED STATICALLY.**
    -   Automatic patching now handles `.patch`/`.diff` plus gzip, xz, and
        bzip2 compressed patch/diff sources.
    -   Patch/decompression failure is propagated before `pkg_build()` can run.
    -   Added explicit `PKGMK_AUTO_PATCH=no` opt-out while preserving the
        existing `skip_patch` compatibility mechanism.
    -   Synchronized the same behavior into `files/pkgmk.bootstrap`; pkgutils
        release bumped from 17 to 18.
    -   Runtime regression remains required with libpng APNG and an intentional
        failed patch.
-   [~] **KERNEL VERSION REVIEW.**
    -   `linux` remains 7.1.8, matching the current LFS development baseline
        used by BFSOS.
    -   `linux-lts` remains 6.18.45, matching the current 6.18 longterm kernel
        observed during this audit.
    -   Upstream kernel 7.2 exists, but no automatic move away from the
        LFS-aligned 7.1.8 BFSOS kernel was made; treat that as a separate kernel
        policy decision.
-   [~] **`firefox-bin` / `dbus-glib` STATIC DUPLICATE/METADATA CHECK.**
    -   The supplied tree has exactly one `firefox-bin`, one `firefox`, and one
        `dbus-glib` port; no duplicate folders/Pkgfiles were found.
    -   The current `firefox-bin` dependency line contains clean ASCII spacing
        and now depends on `dbus`, not `dbus-glib`.
    -   `dbus-glib` is 0.114 release 3 using the corrected Debian source mirror.
    -   This makes duplicate-port and malformed-spacing explanations unlikely
        in the supplied snapshot. Keep the clean-state `prt-get` failed-dep
        regression open to test package-database/cache behavior and the timing
        of the earlier dependency metadata change.
-   **Audit report:** `docs/BFSOS-r171-plasma-pkgmk-audit-20260823.md`.

## r172 --- return to r149-r170 package findings / kernel 7.1.9 / core-opt-xorg dependency pass --- 2026-08-23

-   [~] **MAINLINE KERNEL + BOTH HEADER PORTS MOVED TO 7.1.9.**
    -   `linux` updated 7.1.8 -> **7.1.9**.
    -   `linux-headers` updated 7.1.8 -> **7.1.9**.
    -   `linux-api-headers` updated 7.1.8 -> **7.1.9** as well so all current
        kernel-header packaging stays synchronized.
    -   Fixed a newly found real defect in `linux-api-headers`: its 7.x version
        was still downloading from `kernel/v6.x`; source now uses `kernel/v7.x`.
    -   `linux-lts` remains **6.18.45**, the current 6.18 longterm point release
        verified during this pass.
-   [~] **LTS SYMLINK + ZSTD KERNEL COMPRESSION IMPLEMENTED STATICALLY.**
    -   `linux-lts` now packages `/boot/vmlinuz-lts` as an idempotent symlink to
        the exact versioned kernel image it installs.
    -   Mainline and LTS recipes now enable kernel/module Zstandard compression;
        existing Dracut BFSOS configuration already specifies `compress="zstd"`.
    -   Runtime boot/initramfs/module regression is still required.
-   [~] **r153 XORG DRIVER RESTORATION IMPLEMENTED.**
    -   `xf86-video-openchrome` and `xf86-video-vboxvideo` restored to the
        default `xorg-driver` dependency set after their compatibility fixes had
        already passed live builds.
-   [~] **r156 MODERN XORG/WAYLAND DEFAULT IMPLEMENTED.**
    -   Top-level `xorg` now pulls `wayland`, `wayland-protocols`, and `xwayland`.
-   [~] **GTK4 -> QT5 OVERBROAD DEPENDENCY ROOT CAUSE FOUND AND FIXED.**
    -   Exact metadata path in the supplied tree was:
        `gtk4 -> highlight -> qt5`.
    -   `highlight` is no longer a hard GTK4 dependency; it is classified as
        optional documentation/tooling, preventing ordinary GTK4 installs from
        dragging in Qt5 through that path.
-   [~] **LIBNOTIFY / SHARED-MIME-INFO DEPENDENCIES FIXED.**
    -   `libnotify` now explicitly requires GTK4 for the current recipe and its
        Meson configure/compile/install path is fail-fast.
    -   `shared-mime-info` now explicitly requires `xmlto` for the current build
        configuration and its Meson path is fail-fast.
-   [~] **FIREFOX/WEB TOOLCHAIN DEPENDENCY METADATA HARDENED.**
    -   Firefox retains `dav1d`, ICU, NSS/NSPR and adds explicit system-library
        dependencies required by its mozconfig: `libffi`, `libjpeg-turbo`,
        `libpng`, `pixman`, `wayland`, and `zlib`.
    -   Qt5 now explicitly requires `python3-html5lib`.
    -   NSS now explicitly requires `sqlite` and `zlib` in addition to NSPR
        because its recipe enables the system copies.
    -   Node.js now hard-requires ICU, uses the valid current
        `--shared-nghttp2` option (not the obsolete `--shared-libnghttp2`), uses
        `PKGMK_AUTO_PATCH=no`, and fails fast.
-   [~] **r154/r155 LEGACY/DEPENDENCY BUILD FIXES FOLDED IN.**
    -   NASM xdoc download now follows `$version`; release bumped and recipe
        fails fast.
    -   libsndfile keeps package-scoped GNU17 compatibility, is fail-fast, and
        explicitly requests the intended BFSOS audio/codec baseline:
        `flac libogg libvorbis opus alsa-lib lame mpg123`.
    -   Yasm GNU17 recipe is fail-fast.
    -   PulseAudio retains the working Debian source and is fail-fast.
    -   `xsetroot` is fail-fast while retaining its required `libXcursor`.
-   [~] **QT5 FILE OWNERSHIP / BROKEN HELPER SYMLINK FIX.**
    -   Qt5 helper commands (`qmake-qt5`, `moc-qt5`, etc.) are now created
        inside `$PKG/usr/bin` and point directly to `/opt/qt5/bin/<tool>`.
    -   Removed stale post-install use of undefined `$QT5BINDIR`, which had
        produced broken links such as `/usr/bin/qmake-qt5 -> /qmake`.
    -   Qt5 profile and ld.so files remain package-owned; post-install now only
        runs `ldconfig`.
-   [~] **`aaa_filesystem` DUPLICATE PACKAGE FILE CLEANUP EXTENDED.**
    -   Removed `qt5.sh`, `qt6.sh`, and `rustc.sh` from aaa_filesystem because
        their actual packages own/generate those profile files.
    -   This extends the originally observed Qt5 collision rather than fixing
        only the single reported file.
-   [~] **LIBPNG APNG HANDOFF TO CENTRAL PATCH EXTENSION.**
    -   With compressed `.patch.gz` support now implemented in pkgutils, libpng
        no longer manually reapplies the APNG patch inside `pkg_build()`.
        This avoids double application while retaining APNG in the package.
-   [~] **FULL `core` / `opt` / `xorg` STATIC DEPENDENCY PASS COMPLETED.**
    -   Scanned all **761** Pkgfiles in `core` (201), `opt` (380), and `xorg`
        (180).
    -   Every hard dependency token now resolves to an existing BFSOS port.
    -   Removed duplicate hard-dependency tokens from `gtkmm3`,
        `gst-plugins-ugly`, and `xorg-libs`.
    -   Corrected `libwebp` optional metadata typo `ibjpeg-turbo` ->
        `libjpeg-turbo`.
    -   All 930 Pkgfiles across core/opt/xorg/plasma pass `bash -n`.
    -   **Important:** this is a complete static dependency/syntax pass, not a
        false claim that all 761 upstream versions/URLs have already been
        fetched and live-built. Continue the r165 per-port current-version and
        source-endpoint verification and mark unverified packages explicitly.
-   **Audit report:** `docs/BFSOS-r172-core-opt-xorg-tracker-fixes-20260823.md`.

## r173 --- broad BLFS systemd core/opt/xorg current-version refresh --- 2026-08-23

-   [~] **RESUMED THE FULL r165 `core` / `opt` / `xorg` AUDIT AGAINST THE LIVE BLFS SYSTEMD DEVELOPMENT BOOK.**
    -   Used BLFS systemd development r13.0-1327 (published 2026-08-22) rather
        than the stale/incorrect reference snapshots that caused earlier misses.
    -   Applied **39 additional current-version updates** to directly mapped
        `core`/`opt`/`xorg` packages after the r172 dependency/build fixes.
    -   Notable updates include CrackLib 2.10.3, GnuPG 2.5.21, GPGME 2.1.2,
        Kerberos 1.22.2, OpenSSH 10.5p1, LVM2 2.03.42, mdadm 4.6,
        smartmontools 7.5, libarchive 3.8.9, libblockdev 3.5.0,
        libgcrypt 1.12.2, libgpg-error 1.61, libnvme 1.16.2,
        libqalculate 5.12.0, libwacom 2.19.1, libjpeg-turbo 3.2.0,
        libtiff 4.7.2, Highlight 4.21, Lua 5.4.8, NetworkManager 1.58.1,
        libevent 2.1.13, libpcap 1.10.6, glslang 16.5.0,
        Vulkan-Headers/Vulkan-Loader 1.4.357.0, Gtkmm 3.24.11, and current
        Pangomm API-line point releases.
    -   BFSOS Mesa **26.2.1** and gdk-pixbuf **2.44.8** were deliberately
        retained because they are newer than the BLFS versions in the current
        book; do not downgrade merely for version equality.
-   [~] **XORG LIBRARY/APPLICATION/INPUT PACKAGE LIST RECONCILED WITH CURRENT BLFS.**
    -   The detailed BLFS Xorg lists exposed **56 additional stale package
        versions** that the earlier two audits had missed.
    -   Updated the Xorg library set including xtrans 1.6.0, libX11 1.8.13,
        libXext 1.3.7, libSM 1.2.6, libXpm 3.5.19, libXfont2 2.0.9,
        libXi 1.8.3, libXrandr 1.5.5, libpciaccess 0.19,
        libxkbfile 1.2.0 and the rest of the BLFS library manifest.
    -   Updated stale Xorg applications including xauth 1.1.5,
        xkbutils 1.0.7, xsetroot 1.1.4, xdpyinfo 1.4.0, xrandr 1.5.4
        and the remaining BLFS app manifest entries.
    -   Updated the BLFS input stack where stale: libevdev 1.13.6 and
        libinput 1.31.3; already-current driver versions were retained.
-   [~] **SOURCE/VERSION RESIDUE CHECKS APPLIED TO THE NEW BUMPS.**
    -   Fixed Kerberos's source path, which still hard-coded the `1.21`
        release directory after moving to 1.22.2; it now derives the directory
        from `${version%.*}`.
    -   Fixed Lua's hard-coded `5.4.7` library/install residue after updating
        the package to 5.4.8.
    -   Changed libtiff's source endpoint to HTTPS.
    -   Highlight 4.21 now uses **Qt6**, not legacy Qt5, for the GUI that BFSOS
        builds unconditionally; dependency metadata and QMake path were updated.
    -   Automated residue scan finds no prior-version strings left in the
        Pkgfiles changed by this version pass.
-   [~] **STRUCTURAL AUDIT REMAINS CLEAN AFTER THE LARGE VERSION REFRESH.**
    -   All **930** Pkgfiles across core/opt/xorg/plasma pass `bash -n`.
    -   All **761** hard-dependency graphs in core/opt/xorg resolve to existing
        BFSOS ports.
    -   No duplicate hard-dependency tokens remain.
    -   Clean-cache source downloads and package builds remain required runtime
        regression, especially for ABI-changing library upgrades.
-   **Audit report:** `docs/BFSOS-r173-blfs-core-opt-xorg-version-audit-20260823.md`.

## r174 --- pre-1.0 authentication stack integration --- 2026-08-23

-   [ ] **BLOCKER — Integrate CrackLib, Linux-PAM, libpwquality, and Shadow authentication stack before BFSOS 1.0.**
    -   Establish and verify the intended build/dependency ordering around
        **CrackLib -> Linux-PAM -> libpwquality -> Shadow**, including any
        required Shadow rebuild/reconfiguration after PAM becomes available.
    -   Add or update the `libpwquality` port as necessary and use
        `pam_pwquality.so` rather than relying on legacy `pam_cracklib.so`.
    -   Configure Shadow to use PAM correctly while retaining **yescrypt** as
        the normal BFSOS password-hashing scheme.
    -   Audit ownership and upgrade behavior for `/etc/pam.d/*`,
        `/etc/security/*`, `/etc/login.defs`, and related authentication files
        so package upgrades do not unexpectedly overwrite BFSOS policy.
    -   Ensure installer-created root and regular-user passwords use the
        intended authentication/password stack.
    -   Establish a conservative default password-quality policy appropriate
        for a general-purpose distribution without making normal installations
        unnecessarily restrictive.
    -   Regression-test fresh base-system installations for root and normal
        user creation, console `login`, `su`, `passwd`, root changing another
        user's password, normal users changing their own passwords, and weak
        password handling through `pam_pwquality`.
    -   Regression-test SSH password authentication when enabled.
    -   Verify dependency metadata so installation/update of the authentication
        stack automatically produces the correct package ordering.
    -   Test package upgrade/reinstall scenarios for CrackLib, Linux-PAM,
        libpwquality, and Shadow and verify that working PAM configuration is
        preserved.
    -   Test both **fresh BFSOS installation** and **existing-system package
        upgrade/reinstall** paths.
    -   **Release priority: BLOCKER for BFSOS 1.0.** Basic PAM/Shadow/password
        integration must be complete before 1.0; more advanced/customizable
        password-policy work may remain post-1.0.

## r175 --- CrackLib / Linux-PAM / libpwquality / Shadow pre-1.0 integration implementation --- 2026-08-23

-   [~] **1.0 AUTHENTICATION-STACK BLOCKER IMPLEMENTED STATICALLY; FRESH-BASE RUNTIME REGRESSION REQUIRED.**
    -   Current versions verified before implementation: **CrackLib 2.10.3**,
        **Linux-PAM 1.7.2**, **libpwquality 1.4.5**, **Shadow 4.20.2**, and
        **systemd 261.2**. No chain-version bump was required.
    -   Base build order is now explicitly:
        **CrackLib -> Linux-PAM -> libpwquality -> Shadow**, with PAM-enabled
        systemd built later in the normal base sequence.
    -   `libpwquality` moved from `ports/opt` to `ports/core`; there is now one
        canonical libpwquality port.
-   [~] **CRACKLIB DICTIONARY PACKAGING FIXED.**
    -   CrackLib now stages the recommended word list and generates
        `pw_dict.{hwm,pwd,pwi}` directly under `$PKG/usr/lib/cracklib`.
    -   Avoids running `create-cracklib-dict` against the live build host.
    -   Build fails if the staged dictionary is missing.
    -   Dependency metadata now includes the build tools/Python/Xz used by the
        recipe.
-   [~] **PAM PASSWORD POLICY WIRED TO LIBPWQUALITY.**
    -   `/etc/pam.d/system-password` now runs `pam_pwquality.so` before
        `pam_unix.so`.
    -   `pam_unix.so` retains **yescrypt + shadow + try_first_pass**.
    -   `/etc/pam.d/other` is a restrictive `pam_warn` + `pam_deny` fallback.
    -   libpwquality installs a conservative BFSOS policy:
        `minlen=8`, `difok=1`, `minclass=1`, dictionary/user checks enabled,
        enforcement enabled, dictionary at `/usr/lib/cracklib/pw_dict`.
    -   libpwquality's Python wheel is staged with pip `--root="$PKG"`.
    -   Package creation verifies `pam_pwquality.so` exists.
-   [~] **SHADOW PAM INTEGRATION HARDENED.**
    -   Shadow now explicitly depends on `libpwquality`, `libxcrypt`, and
        `linux-pam`.
    -   Current BLFS PAM/yescrypt configuration and Shadow 4.20.2 stdint
        compatibility fix are incorporated.
    -   Shadow's upstream PAM files are suppressed during installation using
        `pamddir=`; BFSOS service policies are generated afterward.
    -   PAM-managed legacy `login.defs` functions are disabled/commented in the
        packaged configuration.
-   [~] **AUTH CONFIGURATION OWNERSHIP/UPGRADE POLICY DEFINED.**
    -   Linux-PAM owns generic `system-*`/`other` PAM policy.
    -   libpwquality owns `/etc/security/pwquality.conf`.
    -   Shadow owns service-specific PAM files and `/etc/login.defs`.
    -   systemd owns `/etc/pam.d/systemd-user`.
    -   `pkgadd.conf` now explicitly preserves `/etc/pam.d/*`,
        `/etc/security/*`, and `/etc/login.defs` on package upgrades so a
        working/admin-customized authentication policy is not silently replaced.
    -   pkgutils release bumped for this configuration policy change.
-   [~] **SYSTEMD PAM REBUILD PATH RETAINED AND HARDENED.**
    -   systemd remains after Shadow in the base order and already enables PAM.
    -   Configure/build/install stages now fail fast.
-   [~] **INSTALLER r65 AUTHENTICATION INTEGRATION.**
    -   Created `scripts/install-bfs-menu-v50-r65-auth-stack-integration.sh`.
    -   `install-bfs-menu-current.sh` now points to r65.
    -   Installer password setting continues through PAM-enabled Shadow
        `chpasswd`.
    -   A libpwquality/PAM password rejection now returns the user to password
        entry instead of aborting the entire installation.
    -   Blank password behavior is unchanged: the account remains locked rather
        than receiving an empty password.
-   [~] **FUTURE-BASE AUTH CHECK HELPER ADDED.**
    -   Added `scripts/bfs-auth-stack-check.sh` for non-destructive verification
        of package versions, CrackLib dictionary, setuid `unix_chkpwd`,
        `pam_pwquality.so`, yescrypt system-password policy, Shadow PAM service
        files, and systemd-user PAM integration.
-   [ ] **RUNTIME RELEASE-BLOCKER REGRESSION STILL REQUIRED ON THE NEXT CLEAN BASE.**
    -   Run the auth check helper after building/installing the new base.
    -   Test installer-created root/standard-user passwords and intentionally
        locked accounts.
    -   Test weak-password rejection, console `login`, `su`, `passwd`,
        root/user password changes, `chpasswd`, SSH password authentication,
        systemd-logind session registration, and package reinstall/upgrade
        preservation.
    -   Do not mark the BFSOS 1.0 blocker closed until these runtime tests pass.
-   **Implementation report:** `docs/BFSOS-r175-auth-stack-integration-20260823.md`.

## r176 --- Firefox ESR parallel port + sysup tooling-order regression --- 2026-08-24

-   [~] **ADD A SEPARATE `firefox-esr` SOURCE PORT THAT CAN COEXIST WITH RAPID-RELEASE FIREFOX.**
    -   Added `ports/opt/firefox-esr`, based on the proven Firefox source-build
        recipe rather than maintaining a separate unrelated build implementation.
    -   Initial ESR target is Mozilla **153.1.0esr**. Firefox 153 is the current
        ESR line and 153.1 is the current security update during this pass.
    -   Keep `firefox` as the rapid-release source port and `firefox-esr` as an
        independently selectable long-support alternative.
    -   ESR packages separate paths so both may be installed simultaneously:
        `/usr/lib/firefox-esr`, `/usr/bin/firefox-esr`,
        `firefox-esr.desktop`, `firefox-esr.png`, and
        `/etc/revdep.d/firefox-esr`.
    -   Retain the successful Firefox system-library dependency/integration work
        unless ESR configure tests expose version-specific requirements.
    -   Regression-test build, launch, HTTPS, audio/video, AV1, X11/Wayland,
        NSS/p11-kit trust, desktop integration, and simultaneous installation
        with the normal `firefox` package.
    -   Verify updating/removing either browser does not overwrite or remove
        files owned by the other.
-   [ ] **MAKE `prt-get sysup` BOOTSTRAP PACKAGE-MANAGEMENT TOOLING BEFORE DEPENDENT REBUILDS.**
    -   Observed during the 2026-08-24 system update: libpng was rebuilt before
        the newly updated pkgutils extension was active, so its APNG
        `.patch.gz` was not applied even though the new port expected central
        compressed-patch handling.
    -   After pkgutils 5.40.12-19 was active, force-rebuilding libpng produced
        `png_get_acTL` / `png_set_acTL` and Firefox's APNG check passed.
    -   Investigate actual `prt-get sysup` transaction ordering rather than
        assuming `prtdir` collection order controls package update order;
        `core` is already first in `/etc/prt-get.conf`.
    -   If `pkgutils` is part of a sysup, install it before packages whose
        builds consume pkgmk extensions, patch logic, mirror handling, failure
        propagation, staging behavior, or other pkgutils functionality.
    -   Regression-test one sysup containing both a pkgutils behavior change
        and a package requiring that behavior.


## r177 — pkgmk source-cache collision / Vulkan Loader fix — 2026-08-24

-   [x] **FIX VULKAN-HEADERS / VULKAN-LOADER SOURCE-CACHE BASENAME COLLISION.**
    -   `vulkan-headers` and `vulkan-loader` both referenced upstream archives
        whose URL basename was `vulkan-sdk-1.4.357.0.tar.gz`.
    -   The global pkgmk source cache reused the already-cached Vulkan-Headers
        archive while building Vulkan-Loader, causing the Loader port to unpack
        and package Vulkan-Headers content instead of building `libvulkan`.
    -   Give the two ports unique cached source names with `renames=`; Loader now
        uses `vulkan-loader-1.4.357.0.tar.gz` and Headers uses a distinct
        Vulkan-Headers cache name.
    -   `vulkan-loader` was corrected to build the real
        `Vulkan-Loader-vulkan-sdk-1.4.357.0` source tree and includes a package
        validation check that fails if `libvulkan.so` is not staged.
    -   Verified `vulkan-loader 1.4.357.0-5` builds and installs successfully,
        including `/usr/lib/libvulkan.so.1.4.357`, `libvulkan.so.1`,
        `libvulkan.so`, `vulkan.pc`, and VulkanLoader CMake metadata.
    -   `vulkan-headers` remains the sole owner of the Vulkan API headers.

-   [ ] **FIX PKGMK GLOBAL SOURCE-CACHE BASENAME COLLISIONS GENERICALLY.**
    -   **Area:** `ports/core/pkgutils` / pkgmk source download and cache logic.
    -   **Observed:** Two unrelated source URLs can have the same basename. pkgmk
        currently treats the cached basename as sufficient identity and may
        silently reuse an archive downloaded for a different package/source.
    -   **Concrete reproducer:** Vulkan-Headers and Vulkan-Loader SDK tag URLs
        both ended in `vulkan-sdk-1.4.357.0.tar.gz`; the cached file contained
        only `Vulkan-Headers-vulkan-sdk-1.4.357.0`, yet it was reused for the
        Vulkan-Loader build.
    -   **Required behavior:** Never silently accept a cached source solely
        because its basename matches when it can originate from a different
        URL/package.
    -   **Implementation options:** Namespace source-cache entries by package,
        derive a stable URL/hash-qualified cache identity, or retain URL/source
        provenance and reject/redownload ambiguous basename collisions.
    -   Preserve `renames=` semantics and existing mirror/fallback behavior.
    -   Add diagnostics that identify the colliding cached path and both source
        identities instead of proceeding with the wrong archive.
    -   **Regression test:** Create two test ports whose source URLs have the
        same basename but different contents. Build them in both orders and
        verify each receives its own correct source; no build may silently reuse
        the other port's archive.
    -   Keep the Vulkan `renames=` workaround even after the generic pkgmk fix,
        because the explicit cache names are clearer and avoid ambiguity.


## r178 — KDE Frameworks dependency ordering + fallback-download 404 audit — 2026-08-24

-   [ ] **ADD `extra-cmake-modules` AS A REQUIRED KDE FRAMEWORKS DEPENDENCY SO FRAMEWORK PORTS DO NOT FAIL BEFORE ECM IS INSTALLED.**
    -   **Area:** `ports/plasma/kde-frameworks-6` meta-package and individual KDE Frameworks dependency metadata.
    -   **Observed during live testing:** `prt-get depinst kde-frameworks-6` reached
        `ktexttemplate 6.26.0-2` before Extra CMake Modules was available.
        CMake then aborted with `Could NOT find ECM (missing: ECM_DIR)` and
        reported that ECM **>= 6.26.0** was required.
    -   **Required fix:** Ensure `extra-cmake-modules` is installed before any
        KDE Frameworks package that requires ECM. Add it as a hard dependency
        to `kde-frameworks-6` and audit individual Frameworks ports so direct
        `prt-get depinst <framework>` builds are also self-contained rather
        than depending on meta-package ordering alone.
    -   **Dependency-order requirement:** ECM must be resolved early enough that
        the first CMake-based Frameworks package never reaches configure without
        `/usr/share/ECM` / `ECMConfig.cmake` available.
    -   **Version coordination:** Keep the ECM release compatible with the active
        KDE Frameworks release line; the current Frameworks 6.26 test requires
        ECM >= 6.26.0.
    -   **Regression tests:** (1) On a clean BFSOS installation run
        `prt-get depinst kde-frameworks-6` and verify ECM is installed before
        `ktexttemplate` or any other ECM consumer; (2) directly depinst several
        representative Frameworks ports and verify their dependency metadata
        independently pulls ECM where required; (3) no manual ECM install is
        needed to complete the Frameworks stack.

-   [ ] **AUDIT/FIX PKGMK PRIMARY + FALLBACK DOWNLOAD HANDLING THAT PRODUCES REPEATED 404 RETRIES BEFORE A SOURCE EVENTUALLY DOWNLOADS.**
    -   **Area:** `ports/core/pkgutils` / `pkgmk.conf` source downloading,
        redirect handling, retry policy, and fallback-mirror ordering.
    -   **Observed repeatedly during the 2026-08-24 ports/Plasma pass:** valid or
        otherwise obtainable sources first generate repeated HTTP 404 failures
        from the primary URL and/or early fallback attempts, often retrying the
        same failure several times, before a later source/mirror eventually
        downloads the correct archive.
    -   **Concrete KDE example:** `ktexttemplate-6.26.0.tar.xz` attempted
        `https://download.kde.org/stable/frameworks/6.26/...`, produced multiple
        rounds of HTTP 404 retries, and then successfully downloaded the
        ~829 KiB archive from a later fallback path. Similar repeated fallback
        behavior has also been observed with other ports during this update run.
    -   **Research task:** Determine whether the 404s are caused by stale primary
        URLs, redirect/mirror-selector behavior, malformed fallback URL
        construction, flat-vs-path-preserving mirror assumptions, or retrying a
        known permanent HTTP error instead of immediately advancing to the next
        candidate.
    -   **Required behavior:** Treat permanent HTTP errors such as 404 as a fast
        failover condition rather than performing several identical retries;
        retain retries for transient network failures where they can actually
        help.
    -   **Fallback correctness:** Preserve source path/category information when
        a mirror requires it, while still allowing flat distfile mirrors where
        appropriate. Do not accept tiny HTML/error responses as successful
        archives, and keep checksum/source validation intact.
    -   **Diagnostics:** Log which candidate URL is being attempted, whether it
        is the original source or a configured fallback, the HTTP/transport
        failure reason, and which URL ultimately supplied the cached source.
    -   **Regression tests:** Exercise (1) a valid primary URL; (2) a deliberate
        404 primary followed by a working fallback; (3) an HTTP redirector such
        as KDE/X.Org; (4) a dead/unreachable mirror; and (5) a bogus small error
        payload. Verify 404s move on quickly, transient failures retry only as
        configured, valid archives are cached, and no build begins from an
        invalid fallback response.

## r179 — Split Qt WebEngine from the main Qt packages — 2026-08-24

-   [ ] **SPLIT QT WEBENGINE OUT OF THE MAIN QT6 AND QT5 PACKAGES.**
    -   **Area:** `ports/opt/qt6`, Qt 6 WebEngine packaging, `ports/opt/qt5`, Qt 5 WebEngine packaging, and dependent-port metadata.
    -   **Goal:** Follow the BLFS/LFS-style packaging model and keep the ordinary Qt toolkit separate from the exceptionally large Chromium-based Qt WebEngine build.
    -   **Required package layout:** Keep `qt6` as the main Qt 6 package and create a separate `qt6-webengine` package that depends on the matching `qt6`; likewise keep `qt5` as the main Qt 5 package and provide a separate `qt5-webengine` package depending on the matching `qt5`.
    -   **Motivation observed during live testing:** A small Qt6 packaging-policy change (`keep_static=1`, required because installed Qt CMake metadata references private/static archives such as `libQt6QmlAssetDownloader.a`) currently forces the entire Qt + QtWebEngine/Chromium source tree through another package rebuild. Separating WebEngine prevents ordinary Qt rebuilds and packaging-only changes from unnecessarily rebuilding the most expensive component.
    -   **Version coordination:** Keep each WebEngine package on the same upstream Qt release line as its corresponding main Qt package and prevent accidental incompatible Qt/WebEngine combinations.
    -   **Dependency audit:** Update Plasma/KDE, browser/web-content, and other ports so only software that actually requires Qt WebEngine depends on `qt6-webengine`/`qt5-webengine`; ordinary Qt consumers should depend only on `qt6`/`qt5`.
    -   **Packaging requirements:** Preserve any required static/private Qt archives (`keep_static=1` where required), ensure the split does not create duplicate file ownership, and verify CMake/pkg-config metadata from both packages resolves against the installed matching Qt base.
    -   **Build/cache goal:** Allow `qt6` or `qt5` to be rebuilt independently without recompiling WebEngine/Chromium, while retaining ccache benefits for unavoidable rebuilds.
    -   **Regression tests:** On a clean BFSOS installation: (1) build/install `qt6` without `qt6-webengine` and verify normal Qt Core/Gui/QML/Quick development works; (2) install `qt6-webengine` afterward and verify its libraries, CMake metadata, and a WebEngine consumer; (3) repeat the equivalent test for Qt5; (4) rebuild only the base Qt package after a packaging-only release bump and verify WebEngine is not rebuilt; (5) run the KDE Frameworks/Plasma dependency chain and confirm WebEngine is pulled only where genuinely required.

## r180 — Qt WebEngine split dependency-consumer audit — 2026-08-24

-   [ ] **MAKE THE QT5/QT6 WEBENGINE SPLIT COMPLETE BY UPDATING EVERY APPLICABLE CONSUMER DEPENDENCY.**
    -   **Extends r179:** The split is not considered complete merely by creating
        `qt6-webengine` and `qt5-webengine`; all ports that actually link to,
        build against, or require Qt WebEngine at runtime must explicitly pull
        the matching WebEngine package.
    -   **Qt 6 rule:** Ordinary Qt 6 consumers depend on `qt6`; only consumers
        requiring Qt WebEngine / WebEngineCore / WebEngineWidgets /
        WebEngineQuick depend on `qt6-webengine` in addition to `qt6` as needed.
    -   **Qt 5 rule:** Ordinary Qt 5 consumers depend on `qt5`; only consumers
        requiring Qt5 WebEngine components depend on `qt5-webengine` in addition
        to `qt5` as needed.
    -   **Ports-tree audit:** Search the complete BFSOS ports tree for build files,
        package metadata, CMake/qmake checks, and source references to
        `Qt6WebEngine`, `Qt5WebEngine`, `WebEngineCore`, `WebEngineWidgets`,
        `WebEngineQuick`, `Qt::WebEngine`, and related WebEngine component names.
        Do not rely only on existing `# Depends on:` comments because currently
        hidden/implicit WebEngine consumers may not declare the dependency yet.
    -   **Plasma/KDE:** Audit all KDE Frameworks, Plasma, and KDE application
        packages individually. WebEngine must not be made a blanket dependency
        of the entire Plasma stack unless upstream genuinely requires it; only
        the applicable consumers should pull `qt6-webengine`.
    -   **No accidental heavyweight dependency:** Verify installing a normal Qt
        application or the main `qt6`/`qt5` package does not automatically pull
        Chromium/WebEngine unless required by that software.
    -   **Version lock/compatibility:** Ensure `qt6-webengine` is built against and
        requires a compatible matching `qt6` release, and likewise
        `qt5-webengine` with `qt5`; upgrades must not leave incompatible mixed
        Qt/WebEngine versions installed.
    -   **Migration:** Existing BFSOS installations that previously received
        WebEngine files from monolithic `qt6`/`qt5` must upgrade without duplicate
        ownership collisions or leaving stale WebEngine files registered to the
        old package.
    -   **Regression tests:** (1) `prt-get depinst` a known non-WebEngine Qt app
        and verify no WebEngine package is pulled; (2) depinst representative
        Qt6 WebEngine consumers and verify `qt6-webengine` is pulled
        automatically; (3) repeat for Qt5; (4) build Plasma/KDE from a clean
        system and verify every WebEngine consumer resolves automatically with
        no manual install; (5) confirm package ownership cleanly separates base
        Qt files from WebEngine files.

## r181 — Audit VLC packaging for a complete usable Linux GUI — 2026-08-24

- [ ] **AUDIT AND UPDATE THE BFSOS VLC PORT SO VLC PROVIDES THE EXPECTED USABLE LINUX GUI.**
  - **Area:** VLC port version, build configuration, Qt GUI/interface support, runtime plugins, and dependency metadata.
  - **Observed concern:** Review the current BFSOS VLC package because VLC should provide its normal graphical Linux interface rather than leaving the user with only a command-line/minimal or otherwise incomplete build.
  - **Version audit:** Check the current upstream stable VLC release and compare it with the BFSOS port. Update the port when BFSOS is behind, while reviewing upstream build-system/configuration changes required by the newer release.
  - **GUI configuration audit:** Determine exactly which VLC GUI/interface backend the selected VLC release expects on BFSOS (including the applicable Qt generation and required modules), and ensure that interface is explicitly enabled and actually built.
  - **Dependency audit:** Add all required build/runtime dependencies for the graphical interface and normal desktop use. Do not rely on undeclared packages that happen to be present on the maintainer/test system. Account for the planned `qt5`/`qt5-webengine` and `qt6`/`qt6-webengine` split and require WebEngine only if the VLC build genuinely uses it.
  - **Plugin/package audit:** Verify the packaged VLC installation retains the GUI/interface plugins and other required runtime plugin files; ensure generic pkgmk cleanup or packaging rules do not remove components that VLC's graphical frontend requires.
  - **Desktop integration:** Verify the package supplies/installs the expected desktop launcher, icons, MIME integration, and any other normal Linux desktop integration provided upstream.
  - **Clean-install requirement:** Test VLC on a clean BFSOS graphical installation where only declared dependencies are available. Launching `vlc` from a terminal and from the desktop menu should open the normal graphical VLC interface without requiring undocumented manual package installation or command-line flags.
  - **Regression tests:** Confirm basic local audio/video playback, GUI controls, preferences, file-open dialogs, desktop launcher behavior, and terminal launch. Check logs for missing interface modules/plugins or libraries and verify `prt-get depinst vlc` installs everything required for the intended BFSOS desktop experience.

## r182 — Installed-VM inventory versus current core/opt/xorg/plasma trees — 2026-08-24

-   [ ] **AUDIT EVERY PACKAGE INSTALLED IN THE CURRENT BFSOS VM AGAINST THE CURRENT `core`, `opt`, `xorg`, AND `plasma` PORT TREES.**
    -   **Area:** Live installed-system package inventory, current BFSOS ports coverage, dependency/test status, and obsolete-package cleanup.
    -   **Scope:** Treat `ports/core`, `ports/opt`, `ports/xorg`, and `ports/plasma` as the authoritative current trees for this audit. Compare the complete package database from the existing VM against all packages currently present in those four collections.
    -   **Installed-package inventory:** Export the full installed package list including package name and installed version/release. Preserve the raw inventory as an audit artifact so the comparison is reproducible.
    -   **Classify every installed package:** For each installed VM package, record one of: (1) present in a current tree and already live-tested; (2) present in a current tree but still needs a current live build/install/runtime test; (3) installed in the VM but missing from all four current trees and therefore needs a port restored/created if still required; (4) obsolete/renamed/replaced package that should be migrated to its canonical current package; or (5) no longer applicable and should be removed from the VM/default dependency path.
    -   **Do not treat old VM state as authoritative:** Some installed packages may be leftovers from earlier BFSOS trees, duplicate/renamed ports, previous dependency mistakes, or experiments. Determine whether each still belongs in BFSOS before creating/re-adding a port.
    -   **Missing-current-tree packages:** For every installed package absent from `core`, `opt`, `xorg`, and `plasma`, identify what installed it / what currently depends on it, whether upstream is still maintained, whether a newer replacement exists, and whether BFSOS actually needs it. Restore/create a current port only when justified.
    -   **Current-tree but not installed/tested:** Generate the inverse report as well: packages in the four current trees that are not installed in the VM. Distinguish normal optional packages from packages that should have been pulled by the current base/X.Org/KDE dependency paths but have not yet been exercised.
    -   **Dependency-path validation:** For packages judged required, verify they are reached through correct `# Depends on:` metadata or the intended meta-package (`base`, X.Org, `kde-frameworks-6`, `plasma-desktop`, etc.) rather than depending on stale manual installation history.
    -   **Version/release comparison:** Flag installed versions that do not match the current port version/release and distinguish expected in-progress updates from stale installed packages that require rebuilding/upgrading/removal.
    -   **Ownership/rename checks:** Pay special attention to renamed/duplicate packages and ownership transitions such as `yaml` -> `libyaml`, Python package naming changes, Qt/WebEngine split work, and any installed package whose files are now owned by another canonical port.
    -   **Removal safety:** Before removing an installed package deemed obsolete/not applicable, check reverse dependencies and file ownership so cleanup does not silently break an already-tested package or leave orphaned files behind.
    -   **Deliverables:** Produce (1) raw installed-package inventory; (2) installed-vs-tree comparison; (3) missing-port candidates; (4) current-tree packages still requiring live testing; (5) obsolete/remove/rename candidates; and (6) an action list ordered so required dependency fixes happen before removals.
    -   **Regression goal:** After the audit and resulting fixes, a clean VM built from the current trees should be able to reproduce the intended package set through normal meta-package/dependency installation without relying on historical manually installed packages, while obsolete/non-applicable packages are absent.

## r183 — Move bash-completion profile ownership out of aaa_filesystem — 2026-08-25

-   [ ] **REMOVE `/etc/profile.d/bash_completion.sh` FROM `aaa_filesystem` SO THE DEDICATED `bash-completion` PACKAGE CAN OWN IT.**
    -   **Observed collision:** The newly added `bash-completion` core package successfully builds its completion data, but package installation collides with an existing `/etc/profile.d/bash_completion.sh` already owned by `aaa_filesystem`.
    -   **Current ownership:** `pkginfo -o /etc/profile.d/bash_completion.sh` reports `aaa_filesystem` as the owner. The existing script is a generic loader whose purpose is specifically to source `/usr/share/bash-completion/bash_completion` when the bash-completion package is installed.
    -   **Required ownership model:** `aaa_filesystem` should provide only generic filesystem/profile infrastructure and must not own package-specific bash-completion integration once `bash-completion` is a real core package. Remove the script from the `aaa_filesystem` port/footprint/source payload and let `bash-completion` install and own its upstream profile integration.
    -   **Base-system integration:** Retain `bash-completion` in the Bootstrap `basepkg` list immediately after `bash`, so fresh BFSOS systems receive programmable completion by default without relying on a hand-maintained `aaa_filesystem` copy.
    -   **Upgrade/migration:** Ensure an upgrade from an older BFSOS installation cleanly transfers ownership of `/etc/profile.d/bash_completion.sh` from `aaa_filesystem` to `bash-completion` without requiring `pkgadd -f`, leaving duplicate package-database ownership, or deleting the file after the new package is installed.
    -   **Regression tests:** (1) build/install updated `aaa_filesystem`; (2) verify the old profile script is no longer owned by it; (3) `prt-get depinst bash-completion` must install without a file collision; (4) verify `pkginfo -o etc/profile.d/bash_completion.sh` reports `bash-completion`; (5) start a fresh interactive Bash shell and confirm programmable completion loads; and (6) verify a clean Bootstrap/base install includes `bash-completion` automatically.

## r185 tracker update — full X.Org dependency/meta-package audit — 2026-08-25

### OPEN — Audit X.Org sub-meta dependency coverage and top-level `xorg` completeness

- [ ] **Perform a complete dependency and meta-package review of the `xorg` tree, with special attention to the older sub-meta-package paths.** The current VM was built by installing the X.Org sub-meta packages before the newer top-level `xorg` umbrella package existed, so the root problem is not that `prt-get depinst xorg` was known to be incomplete. Instead, the already-used sub-meta/dependency paths failed to pull in the full practical X11/XCB baseline that downstream desktop frameworks expected.
- **Observed audit result:** The VM already contains the overwhelming majority of the X.Org stack, including `xorg-server`, `xorg-libs`, `xorg-apps`, `xorg-fonts`, `xorg-driver`, the core X11 libraries, and `xcb-util`, `xcb-util-renderutil`, `xcb-util-image`, `xcb-util-keysyms`, and `xcb-util-wm`. The remaining uninstalled X.Org-tree ports were `glu`, `libpthread-stubs`, `libunwind`, `libvdpau`, `libvdpau-va-gl`, `mesa-demos`, `nvidia`, `xcb-util-cursor`, `xclip`, the top-level `xorg` meta-package itself, and `xscreensaver`. Do not blindly add all of these to the desktop baseline; classify each as required, optional, hardware-specific, diagnostic, legacy/compatibility, or obsolete.
- **Confirmed XCB metadata gap:** `xcb-util-cursor` remains uninstalled even though the other major XCB utility packages are now present. Its port correctly depends on `xcb-util-image` and `xcb-util-renderutil`, but the existing X.Org sub-meta/dependency graph does not appear to pull `xcb-util-cursor` in. Determine the correct parent dependency group for it (`xorg-libs`, another X.Org sub-meta package, or the top-level `xorg` package) based on how current desktop stacks use it.
- **Earlier XCB failure evidence:** Before the utility packages were manually installed during troubleshooting, Qt 6.11.2 configured without full `QT_FEATURE_xcb` support because `xcb-renderutil`, `xcb-image`, `xcb-keysyms`, and `xcb-icccm` pkg-config modules were absent. The corresponding BFSOS ports already existed as `xcb-util-renderutil`, `xcb-util-image`, `xcb-util-keysyms`, and `xcb-util-wm`; therefore the failure was a dependency/meta-package coverage/build-order issue rather than missing ports.
- **Impact:** The incomplete XCB stack caused Qt6 to omit `qtx11extras.cpp` / `QX11Info` from QtGui. KDE Frameworks `kdbusaddons` then failed on X11: first the private `qtx11extras_p.h` header was absent, and after a temporary manual header install the link still failed because the `QX11Info` implementation symbols were not present in `libQt6Gui`.
- **Required audit scope:** Review every X.Org/XCB-related port in `ports/xorg`, `xorg-libs`, `xorg-apps`, `xorg-driver`, `xorg-fonts`, `xorg-server`, `xinit`, and the newer top-level `xorg` meta-package. Verify that protocol headers, core X11 libraries, XCB libraries, XCB utility libraries, keyboard/input libraries, OpenGL/GLVND integration, Wayland/Xwayland compatibility where intended, and common build-time pkg-config modules are reached through the appropriate dependency groups rather than only through historical manual installs.
- **Specific XCB baseline to verify:** At minimum confirm clean-install availability of `x11`, `x11-xcb`, `xcb`, `xcb-render`, `xcb-renderutil`, `xcb-shape`, `xcb-shm`, `xcb-sync`, `xcb-xfixes`, `xcb-randr`, `xcb-image`, `xcb-keysyms`, `xcb-icccm`, and `xcb-cursor`/the `xcb-util-cursor` package where required, plus any additional modules expected by current Qt5/Qt6, GTK, KDE Plasma, X.Org server/drivers, and normal desktop applications.
- **Classification rule for currently uninstalled ports:** Do not make `nvidia`, `xscreensaver`, `mesa-demos`, `xclip`, `glu`, `libvdpau`, `libvdpau-va-gl`, `libunwind`, or `libpthread-stubs` mandatory merely because they reside in the X.Org tree. Determine their actual consumers and intended BFSOS role first; hardware-specific and optional software must remain optional unless a genuine baseline dependency requires them.
- **Qt follow-up:** After the X.Org dependency graph is corrected and the full required XCB development stack is installed, rebuild Qt6 and verify `QT_FEATURE_xcb=ON`, `qtx11extras_p.h` is installed under the QtGui private include tree, and `QX11Info::*` symbols exist in the installed QtGui library. Review Qt5 for the same XCB dependency assumptions. Do not rely on a manually copied `qtx11extras_p.h` as the permanent fix.
- **Meta-package policy:** Users installing either the relevant X.Org sub-meta packages or the normal top-level BFSOS `xorg` umbrella should not later discover that foundational XCB utility libraries required by mainstream Linux desktop frameworks were omitted. The top-level `xorg` package should compose corrected sub-meta packages rather than masking incomplete lower-level dependency metadata by duplicating every individual library.
- **Regression tests:** (1) On a fresh VM, reproduce the older sub-meta-package installation path and verify the intended practical X11/XCB baseline is complete without manual package additions; (2) separately run `prt-get depinst xorg` on a clean base and verify the same or intentionally broader dependency closure; (3) confirm all required X11/XCB pkg-config modules resolve; (4) rebuild Qt6 and confirm XCB/QX11Info support is genuinely compiled and packaged; (5) build `kdbusaddons` without manual header injection; and (6) audit the remaining uninstalled X.Org-tree packages for missing, duplicate, obsolete, renamed, overbroad, optional, or hardware-specific dependency relationships.

## r186 tracker update — Plasma session/systemd integration + PipeWire desktop audio — 2026-08-25

### OPEN — Plasma 6 black-screen / systemd user-session integration and disappearing KF6 units

- [ ] **Audit and permanently fix the Plasma 6 black-screen failure discovered on the Threadripper BFSOS VM.**
- **PAM/logind root cause found:** `/etc/pam.d/system-session` did not include `pam_systemd.so`, so an SDDM Plasma login initially created no logind user session, no `/run/user/1000`, and no usable systemd user manager. Ensure the normal BFSOS PAM session stack includes `session optional pam_systemd.so` (or the appropriate equivalent) for SDDM and other interactive logins.
- **Second root cause found:** Plasma/KF6 package databases and cached package archives recorded systemd user units under `/opt/kf6/lib/systemd/user/`, but that directory and its files were absent from the installed filesystem. Missing units included `plasma-workspace.target`, `plasma-workspace-x11.target`, `plasma-kactivitymanagerd.service`, KWin/PlasmaShell units, KScreen units, and related Plasma session services.
- **Manual recovery proved the units are valid:** extracting the files from the cached package archives and making the units visible to systemd restored `graphical-session.target`, `plasma-workspace.target`, `plasma-workspace-x11.target`, KWin, PlasmaShell, KActivityManager, KScreen, and xdg-desktop-portal startup. KWin CPU usage also returned from pathological high usage to normal session behavior.
- **Primary investigation:** determine why files that are present in the built package archives and recorded by `pkginfo` disappeared from the installed filesystem. Audit pkgutils/pkgadd upgrade/removal semantics, shared-directory ownership, package replacement, and any Pkgfile/post-install cleanup that touches `/opt/kf6`, `/opt/kf6/lib/systemd`, or shared package directories.
- **Package audit:** programmatically inspect all KDE Frameworks/Plasma Pkgfiles and cached package tarballs that install systemd user units. Build a package-to-path ownership map and compare package archive contents, `/var/lib/pkg/db`, and the live filesystem.
- **Shared-directory safety:** specifically test whether upgrading/removing one package that owns entries below a shared directory can remove the directory or files belonging to other still-installed packages while leaving their package database records intact.
- **Systemd unit destination policy:** review whether KF6/Plasma systemd user units should be installed directly into the normal `/usr/lib/systemd/user` hierarchy rather than requiring `/opt/kf6` integration. Avoid ad-hoc per-user `SYSTEMD_UNIT_PATH` workarounds as the permanent solution.
- **Regression tests:** clean Plasma X11 login, Plasma Wayland login, package reinstall, package upgrade, package removal, and mixed upgrades of packages sharing the systemd user directory. After each operation verify package manifests against the filesystem and require a functioning logind/systemd user session with no manual extraction or symlink repair.

### OPEN — Make PipeWire + WirePlumber + PipeWire-Pulse the default Plasma audio stack

- [ ] **Complete the BFSOS Plasma audio dependency and startup integration.**
- **Required architecture:** use PipeWire for the multimedia graph, WirePlumber as the session/policy manager, and PipeWire-Pulse as the PulseAudio-compatible server used by Plasma and applications.
- **Dependency fix required:** ensure `wireplumber` is pulled automatically by the appropriate PipeWire/Plasma/meta-package dependency path. A normal graphical installation must not require `prt-get depinst wireplumber` manually.
- **Observed conflict:** BFSOS had standalone PulseAudio and PipeWire-Pulse configured simultaneously. `/etc/xdg/autostart/pulseaudio.desktop` launched `start-pulseaudio-x11`, and PulseAudio could also autospawn, causing `pipewire-pulse` to report `D-Bus name org.pulseaudio.Server already taken`.
- **Permanent policy:** when PipeWire-Pulse is the selected desktop audio server, prevent the legacy standalone PulseAudio daemon from XDG autostarting or client-autospawning. Retain PulseAudio client libraries/tools only where compatibility requires them; do not let the legacy daemon compete for `/run/user/$UID/pulse/native`.
- **Socket lifecycle:** testing exposed a stale/unlinked Pulse socket after killing the legacy PulseAudio daemon while PipeWire-Pulse still held the inherited socket descriptor. Restarting `pipewire-pulse.socket` and `pipewire-pulse.service` recreated `/run/user/1000/pulse/native` and restored clients. Ensure normal login/upgrade transitions cannot leave an unlinked or stale Pulse socket.
- **Runtime success confirmed:** after the socket reset, `pactl info` reported `PulseAudio (on PipeWire 1.6.8)`, with the VM's `alsa_output.pci-0000_00_1b.0.analog-stereo` and matching input as the default sink/source. `wpctl` also exposed the Built-in Audio device, Analog Stereo sink/source, and working volume control.
- **RTKit audit:** PipeWire and PipeWire-Pulse currently report that the RTKit D-Bus service is unavailable and fall back to reduced realtime scheduling parameters. Determine the correct BFSOS `rtkit` dependency/package/configuration and include it where appropriate.
- **Optional feature audit:** WirePlumber reports BlueZ unavailable and the libcamera SPA plugin missing. Keep these optional unless Bluetooth audio/camera functionality is part of the selected desktop feature set, but ensure their dependency/status is intentional and documented.
- **ALSA utilities:** add/audit `alsa-utils` for graphical/base audio diagnostics so `speaker-test`, `aplay`, `arecord`, `alsamixer`, and `amixer` are available on normal desktop systems. Do not confuse this with the core ALSA SPA support, which was present and successfully created the VM audio nodes.
- **Regression tests:** fresh Plasma install with no manual audio commands; confirm WirePlumber is dependency-installed; verify no standalone PulseAudio daemon competes with PipeWire-Pulse; verify `pactl`, `wpctl`, Plasma System Settings/volume controls, playback, capture, and speaker testing; repeat on X11 and Wayland and after relevant package upgrades/reinstalls.

### r186 diagnostic artifacts / follow-up audit

- [ ] **Use the captured current-project and installed-VM audit tarballs to investigate the missing KF6 systemd-unit incident.**
- Compare all relevant Pkgfiles, cached package archives, installed `/var/lib/pkg/db` manifests, and the current `/opt/kf6` filesystem inventory.
- Prioritize proving whether the disappearance is caused by a specific KDE/Plasma Pkgfile, pkgutils shared-directory removal/upgrade behavior, or another package ownership transition.
- Do not close the issue merely because manually extracting the package archives repaired the VM; the package manager must preserve files owned by still-installed packages automatically.

## r187 implementation pass — Plasma systemd-unit root cause + desktop audio defaults — 2026-08-25

- [~] **PLASMA BLACK-SCREEN / DISAPPEARING SYSTEMD-UNIT ROOT CAUSE FOUND AND FIXED STATICALLY; FRESH-INSTALL/UPGRADE RUNTIME REGRESSION REQUIRED.**
    - The VM audit proved the cached Plasma/KF6 packages contained their systemd units and `/var/lib/pkg/db` still recorded them, while `/opt/kf6/lib/systemd` was absent from the live filesystem.
    - Project audit found the direct destructive cause in `ports/plasma/plasma-meta/post-install`: `rm -rf $KF6_PREFIX/lib/systemd`.
    - Because many already-installed KDE/Plasma packages shared `$KF6_PREFIX/lib/systemd`, installing/reinstalling `plasma-meta` deleted their package-owned units after pkgadd had correctly registered them.
    - Remove that destructive command. The incident is therefore **not currently attributed to a pkgutils shared-directory removal bug**; retain generic package-manager shared-directory regression testing, but do not patch pkgadd/pkgrm for this incident without a reproducer.
    - `pkgutils` extension now relocates staged `/opt/kf6/lib/systemd/{user,system}` integration files into `/usr/lib/systemd/{user,system}` before package footprint generation. This keeps KDE application/framework payload under `/opt/kf6` while putting systemd integration in systemd's normal vendor search path and making the files directly package-owned there.
    - `pkgutils` release bumped **22 -> 23** for this packaging-policy change.
    - Audit of the captured installed package database found at least 18 installed packages with `/opt/kf6/lib/systemd` content, including `baloo`, `dolphin`, `drkonqi`, `kactivitymanagerd`, `kded`, `kglobalacceld`, `knighttime`, `kscreen`, `ksystemstats`, `kwallet-pam`, `kwin`, `kwin-x11`, `libkscreen`, `plasma-desktop`, `plasma-workspace`, `polkit-kde-agent-1`, `powerdevil`, and `xdg-desktop-portal-kde`. The centralized staging relocation covers current and future KF6 packages rather than hard-coding this list.
    - Regression requirement: rebuild/reinstall representative packages from that list with pkgutils 5.40.12-23 and verify their footprints contain `/usr/lib/systemd/...`, no package recreates package-owned units under `/opt/kf6/lib/systemd`, and Plasma X11/Wayland sessions activate normally without manual symlinks.

- [~] **PAM/LOGIND SESSION FIX IMPLEMENTED STATICALLY.**
    - `ports/core/linux-pam/system-session` now includes `session optional pam_systemd.so` after `pam_unix.so`.
    - `linux-pam` release bumped **3 -> 4**.
    - This ensures SDDM's existing `session include system-session` path creates the normal logind/systemd user session and `/run/user/$UID`, instead of limiting `pam_systemd` to `systemd-user` and the SDDM greeter policy.
    - Regression requirement: fresh SDDM X11 and Wayland login must appear in `loginctl`, create `/run/user/$UID`, start the user manager/bus, and cleanly remove the runtime session on logout.

- [~] **PIPEWIRE/WIREPLUMBER PLASMA DEFAULT INTEGRATION IMPLEMENTED STATICALLY.**
    - `plasma-meta` now explicitly depends on `pipewire`, `wireplumber`, `alsa-utils`, and `rtkit`, so a normal Plasma dependency install pulls the complete intended desktop audio/session stack rather than requiring a later manual WirePlumber install.
    - `plasma-meta` release bumped **4 -> 5**.
    - `plasma-meta` now packages vendor systemd-user wants links for `pipewire.socket`, `pipewire-pulse.socket`, and `wireplumber.service`, making the intended PipeWire stack available automatically for Plasma users without per-user `systemctl enable` commands.
    - Keep the dependency direction at the desktop/meta layer: do **not** make `pipewire` hard-depend on `wireplumber`, because WirePlumber itself depends on PipeWire and that would create a dependency cycle.

- [~] **LEGACY PULSEAUDIO SERVER CONFLICT PREVENTION IMPLEMENTED STATICALLY.**
    - The PulseAudio package remains available for libpulse/client compatibility required by existing applications and KDE packages.
    - Remove packaged `/etc/xdg/autostart/pulseaudio.desktop` so Plasma/XDG does not run `start-pulseaudio-x11` and steal the Pulse protocol socket from PipeWire-Pulse.
    - Package `/etc/pulse/client.conf` with `autospawn = no` so libpulse clients do not resurrect the standalone PulseAudio daemon when PipeWire-Pulse is the intended BFSOS desktop server.
    - `pulseaudio` release bumped **2 -> 3**.
    - Regression requirement: fresh Plasma login must show no standalone `pulseaudio` daemon; `pactl info` must report `PulseAudio (on PipeWire ...)`; `/run/user/$UID/pulse/native` must physically exist and be owned/listened to by `pipewire-pulse`.

- [~] **RTKIT PORT ADDED / LIVE BUILD AND DAEMON REGRESSION REQUIRED.**
    - Added `ports/opt/rtkit` at upstream **0.14** using the current PipeWire/Freedesktop GitLab archive and Meson build, with `dbus`, `libcap`, `polkit`, and `systemd` dependencies.
    - Disable installed tests for the normal package and enable libsystemd integration.
    - Plasma meta depends on `rtkit` so PipeWire/WirePlumber desktop sessions can use the RealtimeKit D-Bus service instead of logging `org.freedesktop.DBus.Error.ServiceUnknown` and falling back to reduced realtime scheduling.
    - Regression requirement: build/install `rtkit`; verify `org.freedesktop.RealtimeKit1` D-Bus activation, `rtkit-daemon.service`, policy files, and PipeWire startup without RTKit service-unknown warnings.

- [~] **ALSA-UTILS DESKTOP DIAGNOSTICS INTEGRATED / RECIPE HARDENED.**
    - `plasma-meta` now pulls `alsa-utils` so normal Plasma systems receive `speaker-test`, `aplay`, `arecord`, `alsamixer`, and `amixer`.
    - `alsa-utils` recipe configure/build/install stages now propagate failures instead of allowing a later command to mask an earlier failure.
    - `alsa-utils` release bumped **1 -> 2**.
    - Regression requirement: clean `prt-get depinst plasma-meta` must install the tools automatically and `speaker-test` must exercise the selected PipeWire/ALSA VM output.

- [x] **r186 DIAGNOSTIC ARTIFACT AUDIT COMPLETED FOR THE DISAPPEARING KF6 UNIT INCIDENT.**
    - Compared the supplied project snapshot, VM `/var/lib/pkg/db`, KF6 filesystem inventory, and cached package archives.
    - The package archives and installed package database agreed that the units existed/should exist.
    - The project contained an explicit post-install deletion in `plasma-meta`, matching the observed complete disappearance of the shared directory.
    - This closes the diagnostic/root-cause portion of r186; runtime validation of the corrected packages remains open.

- [~] **DESKTOP INTEGRATION CHECK HELPER ADDED.**
    - Added `scripts/bfs-desktop-integration-check.sh`.
    - The helper non-destructively checks `pam_systemd` session policy, `/run/user/$UID`, visibility of core Plasma user units, absence of the legacy PulseAudio daemon, PipeWire/WirePlumber state, `pactl` server identity, `wpctl` graph visibility, and `speaker-test` availability.
    - Use it after the next package update and on fresh X11/Wayland test installs as a quick regression gate.

## r188 implementation pass — kernel lifecycle, XCB baseline, bash-completion ownership, and Zstd packages — 2026-08-25

- [~] **KERNEL MAINTENANCE ADVANCED TO CURRENT STABLE/LTS POINT RELEASES; RUNTIME BUILD/BOOT REGRESSION REQUIRED.**
    - Mainline `linux`, `linux-headers`, and `linux-api-headers` move together from **7.1.9 -> 7.1.10**.
    - `linux-lts` moves from **6.18.45 -> 6.18.46**.
    - These are the current kernel.org stable 7.1.y and 6.18 LTS point releases as of the 2026-08-23 kernel.org update.
    - Reset the four package releases to 1 for the new upstream versions.
    - Preserve the existing BFSOS Zstd kernel/module compression and current mainline/LTS configuration policy; the clean build must prove the configs and selected Debian LTS patches still apply to the new point release.

- [~] **KERNEL POST-INSTALL RELEASE/SYMLINK LOGIC HARDENED.**
    - Stop using newest `/boot` modification time as the normal way to identify the kernel that was just installed. Both kernel post-install scripts first derive the exact expected kernel release from the installed package version (`linux` -> `<version>-BFS-Linux`, `linux-lts` -> `<version>-BFS-LTS`) and validate the matching `/boot` image and module tree.
    - Keep a version-sort fallback only for legacy/manual hook execution where package metadata cannot resolve the release; do not let an older touched/restored file win merely because its mtime is newer.
    - LTS `/boot/vmlinuz-lts` and `/usr/src/linux-lts` refresh through a temporary symlink plus `mv -T`, making same-version reinstall and point-release replacement atomic/idempotent.
    - `/usr/src/linux` follows `/etc/bfsos/kernel-flavor`. If both flavors are installed on a legacy system with no saved selection, use deterministic normal-kernel preference rather than install order. If only LTS exists, LTS becomes the default.
    - Kernel updates refresh the generic source link only when that package is the configured default; an LTS update cannot steal `/usr/src/linux` from a mainline default and vice versa.
    - Keep stale-initramfs cleanup constrained to images whose matching module tree is gone and never remove the running/new kernel image.

- [~] **INSTALLER r66 CREATED — EXACT SELECTED-KERNEL FINALIZATION.**
    - New installer: `scripts/install-bfs-menu-v50-r66-kernel-selection-tmpfs-fix.sh`; `install-bfs-menu-current.sh` points to r66.
    - Replace the previous "newest `/boot/vmlinuz-*` by mtime" behavior in final initramfs generation and kernel verification with `selected_kernel_release()`, derived from the actually selected `KERNEL_PACKAGE` and installed package version.
    - This prevents a dual-kernel installation from generating/validating the initramfs for the wrong flavor merely because the other image has a newer timestamp.
    - Installer kernel-source policy now uses atomic source-link replacement and refreshes the LTS flavor links when LTS is the selected/default flavor.
    - Regression matrix: mainline only; LTS only; both installed with mainline selected; both installed with LTS selected; reinstall each flavor; point-release update each flavor; verify `/usr/src/linux`, `/usr/src/linux-lts`, `/boot/vmlinuz-lts`, matching initramfs, modules, and GRUB entries.

- [~] **BUILD-WORK TMPFS POLICY RECONCILED WITH THE EXISTING CONFIGURABLE IMPLEMENTATION.**
    - The current installer was no longer hard-coded to a universal 16 GiB tmpfs: it already supported `BUILD_TMPFS_SIZE=auto` plus explicit user sizes and scaled the ceiling by physical RAM.
    - r66 fixes the remaining low-RAM mismatch: when `auto` is selected on a system with less than 16 GiB RAM, use the disk-backed `/var/cache/pkg/build-work` path instead of silently creating a very small tmpfs even though the settings screen recommends disabling RAM-backed builds.
    - Existing auto ceilings remain 8G for 16-31 GiB RAM, 16G for 32-63 GiB, 32G for 64-127 GiB, and 64G for >=128 GiB; users may still choose another ceiling or disable tmpfs completely.
    - Heavy Qt/Chromium/WebEngine runtime regression remains required; if 32/64 GiB ceilings still prove insufficient, add an explicit package-level disk-work override rather than returning to a fixed global ceiling.

- [~] **X.ORG/XCB SUB-META BASELINE FIX IMPLEMENTED STATICALLY.**
    - `xorg-libs` now pulls the foundational XCB utility set used by modern desktop toolkits: `libxcb`, `xcb-util`, `xcb-util-renderutil`, `xcb-util-image`, `xcb-util-keysyms`, `xcb-util-wm`, `xcb-util-cursor`, and `libxkbcommon` in addition to the existing Xlib libraries.
    - Qt6 and Qt5 explicitly declare the XCB utility packages, including `xcb-util-cursor`, rather than relying solely on incidental transitive installation.
    - Current Qt 6 Linux/X11 requirements explicitly list xcb-render-util, xcb-icccm, xcb-keysyms, xcb-image, xcb-util, and xcb-cursor among the XCB platform-plugin dependencies; this metadata change aligns the BFSOS dependency closure with that required platform baseline.
    - Hardened the six XCB utility recipes so configure/build/install failures propagate instead of allowing a later successful command to mask an earlier failure.
    - `xorg-libs` release 3; Qt6 release 8; Qt5 release 11; XCB utility package releases bumped for the recipe hardening.
    - Fresh X.Org/Qt regression remains required: install via the older X.Org sub-meta path and top-level `xorg`, verify all required pkg-config modules, rebuild Qt6 with `QT_FEATURE_xcb=ON`, and build KDE Frameworks without manual XCB additions.

- [~] **BASH-COMPLETION PROFILE OWNERSHIP MIGRATION IMPLEMENTED STATICALLY.**
    - The current `aaa_filesystem` source no longer contains `/etc/profile.d/bash_completion.sh`; bump `aaa_filesystem` to release 10 so existing installations receive that ownership removal through a normal package upgrade.
    - `bash-completion` release 2 now explicitly packages `/etc/profile.d/bash_completion.sh` and therefore owns the loader that sources `/usr/share/bash-completion/bash_completion`.
    - `bash-completion` remains in the Bootstrap base package list immediately after Bash.
    - Runtime upgrade regression must verify old `aaa_filesystem` ownership transfers cleanly and a fresh interactive Bash shell loads programmable completion.

- [~] **DEFAULT BUILT-PACKAGE COMPRESSION CHANGED TO ZSTANDARD STATICALLY.**
    - Existing BFSOS pkgmk already supports `zst` output (`*.pkg.tar.zst`) through libarchive/bsdtar, so make `PKGMK_COMPRESSION_MODE="zst"` the packaged `/etc/pkgmk.conf` default and patch the installed pkgmk default to `zst` as well.
    - Add `zstd` as an explicit pkgutils dependency. Bootstrap base order already builds `zstd` before final `pkgutils`.
    - `pkgutils` release **23 -> 24**.
    - Keep backward compatibility: pkgmk still recognizes gz/bz2/xz/lz/zst and cleanup tooling already recognizes both `*.pkg.tar.xz` and `*.pkg.tar.zst`; no repository/cache code in the supplied tree hard-codes xz-only package discovery.
    - Runtime regression: build a small package as `.pkg.tar.zst`, verify `bsdtar -t`, `pkgadd`, `pkgrm`, `prt-get depinst/sysup`, cache reuse, installer package discovery, and coexistence with older cached `.pkg.tar.xz` packages before closing r161.

- [x] **SMALL PLASMA DEPENDENCY TYPO FIX:** `k3b` hard dependency corrected from nonexistent `kde-rameworks-6` to `kde-frameworks-6`; recipe remains pending its normal live build regression.

- [ ] **PLASMA OPTIONAL/DEFAULT-APPS DEPENDENCY GAPS DISCOVERED BY THE FULL STATIC GRAPH CHECK.**
    - After the r188 core/opt/xorg/plasma dependency scan, only three unresolved hard-dependency tokens remain in those four collections: `kaccounts-integration -> libaccounts-qt`, `kaccounts-integration -> signond`, and `plasma-default-apps -> kio-extras`.
    - These are not dependencies of the current `plasma-meta` desktop baseline and therefore do not block the next core Plasma session test, but they must be resolved before claiming the entire Plasma/default-apps collection has a closed dependency graph.
    - Do not delete them just to make the audit green: determine whether to add/restore the corresponding ports or narrow/remove the dependency only if upstream no longer requires it.

- **Static validation:** all active BFSOS Pkgfiles pass `bash -n`; r66 installer, Bootstrap, desktop integration checker, and kernel post-install scripts pass their shell syntax checks. The next clean build is still required to validate compilation, package ownership transitions, Zstd package installation, kernel boot, X11/XCB feature detection, PAM/Shadow, and Plasma/Wayland runtime behavior.


## r189 tracker update — close Plasma hard-dependency gaps + Snapper Boost ABI dependency — 2026-08-25

### [~] Plasma dependency closure implemented statically; live builds pending

- [x] **Confirmed the three previously unresolved Plasma dependency names were genuinely absent from the r188 project tree:** `libaccounts-qt`, `signond`, and `kio-extras` had no matching BFSOS ports under any collection.
- [x] **Added `ports/opt/libaccounts-qt` 1.17**, built for Qt6 and explicitly depending on the newly added `libaccounts-glib` support library.
- [x] **Added `ports/opt/signond` 8.61** using the Qt6-capable Accounts-SSO fork/commit used by current distributions. The package installs the SignOn daemon, Qt6 client library, plugins, and D-Bus service integration.
- [x] **Added `ports/plasma/kio-extras` 26.04.1**, matching the active KDE Gear 26.04.1 baseline.
- [x] **Added the required transitive support ports instead of leaving the new ports with hidden/missing prerequisites:** `libaccounts-glib` 1.27, `libproxy` 0.5.12, and `kdsoap-ws-discovery-client` 0.4.0.
- [x] **Updated `kdsoap` 2.3.0 to the Qt6 build path** (`KDSoap_QT6=ON`) because the current KIO Extras discovery stack requires Qt6 KDSoap. Release bumped to 3.
- [x] **Updated `kaccounts-integration` dependency metadata** so Qt6 is explicit alongside `libaccounts-qt`, `signond`, QCoro, Kirigami/KWallet/KCMUtils. Release bumped to 4.
- [x] **Bumped `plasma-default-apps` to release 3** now that its previously unresolved `kio-extras` dependency has a real port.
- [x] **Static dependency result:** every hard dependency referenced by a `ports/plasma/*/Pkgfile` resolves to an existing BFSOS port. A scan of `core`, `opt`, `xorg`, and `plasma` against all BFSOS collections as dependency providers also reports zero unresolved hard dependency names.
- [ ] **Runtime regression required:** on the next clean system, build in dependency order and verify `libaccounts-glib` -> `libaccounts-qt`, `signond`, Qt6 `kdsoap` -> `kdsoap-ws-discovery-client` -> `kio-extras`, followed by `kaccounts-integration` and `plasma-default-apps`. Confirm no undeclared configure/build dependency appears.
- [ ] **Online-accounts functional audit:** after the core stack builds, review whether BFSOS should additionally package the optional/runtime Accounts-SSO helpers used by full online-account provider workflows (for example OAuth/UI/KWallet SignOn helpers). Do not block basic Plasma installation on optional provider functionality unless upstream requires it.

### [~] Snapper Boost dependency / ABI rebuild fix

- [x] **Root cause confirmed on the installed Plasma VM:** installed `boost` was 1.92.0 while `snapper` 0.13.1-1 still linked to `libboost_thread.so.1.91.0`, causing `snapper-boot.service` to exit 127 and every Snapper command to fail before reading configuration.
- [x] **Missing dependency metadata confirmed:** the Snapper port did not declare `boost` despite linking to Boost.Thread.
- [x] **Added `boost` as a hard Snapper dependency**, bumped Snapper to release 2, and made autoreconf/configure/build/install stages fail-fast.
- [ ] **Runtime regression:** rebuild Snapper against Boost 1.92.0 and verify `ldd /usr/bin/snapper` has no missing libraries; run `snapper -c root list`; start `snapper-boot.service`; verify boot/timeline/cleanup services.
- [ ] **Broader ABI/reverse-dependency policy remains open:** dependency metadata fixes the missing graph edge but does not by itself guarantee all reverse dependencies are rebuilt after a future SONAME-changing Boost upgrade. Continue the existing revdep/sysup rebuild-policy work before treating ABI transitions as fully solved.

## r190 tracker update — Bootstrap Stage 2 CA trust-store transition failure — 2026-08-26

### [~] Final-system CA bundle initialization ordering bug confirmed; current build recovered, permanent fix pending

- [x] **Failure reproduced during Bootstrap Stage 2:** `libuv` download failed immediately with `curl: (77) error adding trust anchors from file: /etc/pki/tls/certs/ca-bundle.crt` and package build exit status 4. `python3-wheel` immediately before it had completed successfully; libuv was the first observed uncached HTTPS download to expose the trust-store failure.
- [x] **Host/network problem ruled out:** the Gentoo live environment had a valid real `/etc/ssl/certs/ca-certificates.crt`, and its host curl was configured for `/etc/ssl/certs/ca-certificates.crt`.
- [x] **BFSOS final curl policy confirmed:** `ports/core/curl/Pkgfile` explicitly configures final curl with `--with-ca-bundle=/etc/pki/tls/certs/ca-bundle.crt`. The temporary-tools `bootstrap_build()` instead correctly uses `$TOOLS/etc/ssl/cert.pem`.
- [x] **Broken final-root state confirmed:** `/tmp/lfs-rootfs/etc/ssl/cert.pem`, `/tmp/lfs-rootfs/etc/ssl/ca-bundle.crt`, and `/tmp/lfs-rootfs/etc/ssl/certs/ca-certificates.crt` all pointed at `../pki/tls/certs/ca-bundle.crt` / `../../pki/tls/certs/ca-bundle.crt`, but `/tmp/lfs-rootfs/etc/pki/tls/certs/ca-bundle.crt` did not exist.
- [x] **Dependency/order gap confirmed:** the `make-ca` port exists, but Bootstrap contains no `make-ca` package entry/run at this transition and neither `ca-certificates` nor `curl` currently declares the required dependency relationship. Thus `ca-certificates` can install compatibility symlinks and final BFSOS curl can become active before the canonical bundle target exists.
- [x] **Why earlier builds could appear healthy:** source-cache hits can avoid HTTPS after the final curl transition, hiding the broken trust store until the first uncached source download.
- [x] **Current build recovered without restart:** copied the Gentoo live system's real CA bundle into `/tmp/lfs-rootfs/etc/pki/tls/certs/ca-bundle.crt`; all BFSOS compatibility links then resolved to the real canonical file. A chroot test using `/usr/bin/curl -I https://dist.libuv.org/dist/v1.52.1/libuv-v1.52.1.tar.gz` returned HTTP 200, and Bootstrap Stage 2 resumed successfully.
- [ ] **Permanent package/dependency fix:** integrate `make-ca` into the final base/bootstrap dependency/order chain before final BFSOS curl is allowed to perform downloads. Define explicit `make-ca` / `ca-certificates` / `curl` dependency ownership and ordering without reintroducing the previously fixed file-ownership conflict between `make-ca` and `ca-certificates`.
- [ ] **Trust-store initialization:** ensure `/etc/pki/tls/certs/ca-bundle.crt` is generated/populated as a real non-empty file before the compatibility links and final curl are relied upon. Do not solve this with reverse/circular symlinks.
- [ ] **Bootstrap fail-fast check:** before transitioning to final-system curl or performing subsequent network downloads, verify `test -s /etc/pki/tls/certs/ca-bundle.crt` in the target root and perform a small HTTPS curl sanity test. Abort with an explicit CA trust-store initialization error rather than misreporting the next package as a download failure.
- [ ] **Fresh-cache regression:** repeat Bootstrap with the relevant source cache empty so an HTTPS download is guaranteed immediately after the tools-to-final-system transition. Verify there is no curl error 77 and no manual CA-bundle copy/symlink workaround is required.
- [ ] **Installed-system regression:** after installation, verify the canonical bundle is a real file, all compatibility paths resolve to it, `curl` reports/uses the intended BFSOS CA path, `ports -u` works, and installing/upgrading both `make-ca` and `ca-certificates` causes no ownership conflict.
- **Priority:** Critical bootstrap/network correctness; clean-bootstrap blocker.

## r191 — pkgutils hook integration / post-install failure hardening (2026-08-26)

- [ ] **Move simple package pre/post install hooks into `Pkgfile` instead of separate `pre-install` / `post-install` scripts.**
  - Add first-class `pre_install()` and `post_install()` hook support to BFSOS pkgutils/pkgadd.
  - Keep package build, installation, and short lifecycle logic together in the `Pkgfile` so behavior is easier to audit and maintain.
  - Run install hooks in the **installed target-root context**, not accidentally in the Gentoo/bootstrap host context.
  - Preserve support for external scripts only where a hook is genuinely large or otherwise benefits from being separate.
  - Convert `ccache` as an initial regression-test package. Its current separate `post-install` calls bare `ccache`, which failed during Bootstrap Stage 2 because `/usr/bin/ccache` existed under `/tmp/lfs-rootfs` but not on the Gentoo host.

- [ ] **Make pre/post install hook failures fail loudly and propagate through pkgutils/bootstrap.**
  - A nonzero `pre_install()` or `post_install()` result must be treated as an installation failure rather than scrolling past after the package archive reports a successful build.
  - Clearly identify the package, hook, exit status, and target root in the package/bootstrap log.
  - Ensure Bootstrap stops or marks the package failed according to its normal failure policy instead of silently continuing.
  - Audit existing ports with `pre-install` / `post-install` scripts for host-vs-target assumptions and bare execution of binaries that only exist inside the target root.
  - Regression case: `ccache 4.13.6-1` built successfully, then its old `post-install` line `CCACHE_DIR="$cache" ccache --set-config=...` produced `ccache: command not found` because the hook executed outside `/tmp/lfs-rootfs`.
  - Confirm the replacement keeps `/var/cache/ccache` owned by `pkgmk:pkgmk` and preserves the intended Bootstrap configuration (`max_size = 20G`; ccache disabled during Stage 1 and activated only after the BFSOS ccache package/compiler wrappers exist).

## r192 — Coordinated current KDE stack modernization (2026-08-26)

- [ ] **Refresh the complete KDE stack to the current stable releases at the time this work is performed.**
  - Do **not** hard-code the August 2026 versions as the eventual upgrade target; re-check upstream immediately before starting and use the then-current stable KDE Frameworks, Plasma, and KDE Gear releases.
  - Current reference point on 2026-08-26: KDE Frameworks 6.29.0, Plasma 6.7.4, and KDE Gear 26.08.0.
  - Upgrade KDE Frameworks as a coordinated set rather than leaving a mixture of older 6.26.x and newer Frameworks packages.
  - Upgrade Plasma as a coordinated set and verify all Plasma components use the intended Qt6/KF6 stack.
  - Upgrade all KDE Gear / Plasma application ports to the matching current stable release series where applicable (Dolphin, Konsole, Okular, Gwenview, Kdenlive, K3b and the rest of the maintained application collection).
  - Audit and correct dependency metadata during the refresh, including newly required support libraries and removal/narrowing of obsolete or optional dependencies.
  - Audit source/release-service URLs and package naming against current upstream KDE release layouts.
  - Remove stale KF5/Qt5-era descriptions, assumptions, build flags, and dependency metadata where the current package is Qt6/KF6 based.
  - Apply BFSOS fail-fast build/package conventions while touching the ports so configure/build/install failures cannot be masked.
  - After the coordinated refresh, run a complete dependency-closure audit of the Frameworks/Plasma/Gear collections to catch missing ports like those exposed during the Plasma dependency work.
  - Regression-test a fresh installation under both X11 and Wayland, including login/session startup, audio integration, portals, KIO functionality, default applications, and `systemctl --failed` / `systemctl --user --failed`.
  - Treat the resulting current 64-bit KDE stack as part of the clean baseline to establish before undertaking the larger compat-32/multilib redesign.

## r193 implementation pass — Bootstrap hardening + installer integrity controls + current KDE refresh — 2026-08-26

### [x] Bootstrap CA trust-store transition hardened; cold-cache runtime regression pending

- `ca-certificates` is bumped to release 5 and now seeds `/etc/pki/tls/certs/ca-bundle.crt` as a **real non-empty file** in the final package rather than shipping only compatibility symlinks whose canonical target may not exist yet.
- `/etc/ssl/cert.pem`, `/etc/ssl/ca-bundle.crt`, and `/etc/ssl/certs/ca-certificates.crt` remain compatibility symlinks to the canonical BFSOS bundle.
- `curl` is bumped to release 3 and explicitly declares `ca-certificates` and `openssl`; final curl remains configured for `/etc/pki/tls/certs/ca-bundle.crt`.
- Bootstrap now checks the canonical CA bundle immediately after installing `ca-certificates` and performs an HTTPS sanity request with final BFSOS curl immediately after installing `curl`. A bad tools-to-final trust transition now fails at the actual CA boundary instead of surfacing later as an unrelated package download failure.
- Design refinement from r190: `make-ca` no longer has to be the component that initially creates the canonical file during Bootstrap. `ca-certificates` seeds a usable Mozilla bundle so final curl is never left with a dangling trust path; `make-ca` can later maintain/regenerate the runtime store after its own dependency/ownership policy is audited.
- **Still pending:** repeat Bootstrap with an intentionally cold source cache and verify no manual bundle copy is needed; then verify installed-system `make-ca`/`ca-certificates` upgrades do not reintroduce ownership conflicts.

### [x] Exact Bootstrap failing-package log tracking implemented; runtime regression pending

- Bootstrap records the active package log when a package operation closes nonzero and preferentially displays that exact file in the failure UI.
- This addresses the observed Stage-2 failure where `libuv` exited 4 but the dialog displayed the immediately preceding successful `python3-wheel` log because timestamps were too close for latest-file selection to be reliable.
- **Regression:** deliberately fail one package immediately after a successful package and verify the dialog names/displays only the actual failing package/log.

### [x] ccache Bootstrap post-install regression fixed; broader lifecycle-hook architecture remains open

- `ccache` is bumped to release 2.
- The separate `ports/core/ccache/post-install` hook is removed. The package stages `/var/cache/ccache` directly, while Bootstrap remains the owner of target-specific `ccache.conf` sizing and activation policy.
- Both maintained `pkgin` helper copies no longer execute a port `post-install` immediately after `pkgmk` has merely built the archive and before outer `pkgadd -r <target>` installs it. This removes the exact host/target ordering bug that produced `ccache: command not found` despite a successful ccache package build.
- The completed Bootstrap-3 test already demonstrated active ccache use: 59,639 cacheable compiler calls, 6,216 hits, and a 20 GB configured maximum. The immediate ccache regression is therefore closed subject to one clean no-workaround rebuild.
- **Still open from r191:** design first-class package lifecycle hooks that belong to the actual install transaction and migrate/audit the remaining standalone `pre-install`/`post-install` scripts over time. Do not blindly execute target binaries from build-only helpers.

### [x] Bootstrap integrity controls implemented, secure by default

- Bootstrap Settings now provides independent controls for source checksum/MD5 verification, source signature verification, and package footprint verification.
- All three default to **enabled** and Restore Defaults re-enables all three.
- A deliberate development bypass writes matching `PKGMK_IGNORE_MD5SUM`, `PKGMK_IGNORE_SIGNATURE`, and `PKGMK_IGNORE_FOOTPRINT` policy into the Stage-2/3 and installed pkgmk configuration and emits a visible warning in logs.
- `pkgutils` is bumped to release 25 and its shipped `pkgmk.conf` explicitly defaults all three ignore settings to `no`; the previous forced signature-ignore behavior is removed.
- `git-update-bfsos.sh` continues to purge generated `.md5sum`, `.md5sums`, `.footprint`, `.footprints`, `.signature`, and `.signatures` files from the maintainer ports tree during rapid-development updates so stale generated metadata cannot poison a later test checkout.

### [x] Installer r67 adds matching integrity controls, secure by default; runtime UI regression pending

- New installer: `scripts/install-bfs-menu-v50-r67-integrity-controls.sh`; `install-bfs-menu-current.sh` points to r67.
- `Installer Settings -> Compiler / Build Settings` now exposes independent **Verify MD5/checksums**, **Verify signatures**, and **Verify footprints** toggles.
- All controls default to `yes`, are persisted in installer settings, and Restore Defaults switches all verification back on.
- The generated target configuration maps those settings to `PKGMK_IGNORE_MD5SUM`, `PKGMK_IGNORE_SIGNATURE`, and `PKGMK_IGNORE_FOOTPRINT`. If any are bypassed, the installed-system package transaction logs a conspicuous development-warning line.
- **Regression:** verify default install performs all checks; disable each independently and verify only the selected check is bypassed; reload installer settings and verify state persistence; Restore Defaults must re-enable every integrity check.

### [~] Coordinated KDE current-release refresh statically implemented; clean build/runtime regression pending

- Upstream was re-checked immediately before this pass. The current stable reference used is **KDE Frameworks 6.29.0, Plasma 6.7.4, and KDE Gear 26.08.0**.
- Updated **148 BFSOS Plasma-collection Pkgfiles/meta ports** to the coordinated current series: 74 Frameworks-family ports at 6.29.0, 57 Plasma-family ports at 6.7.4, and 17 Gear/release-service ports at 26.08.0.
- Updated source layouts consistently:
  - Frameworks -> `https://download.kde.org/stable/frameworks/${version%.*}/...`
  - Plasma -> `https://download.kde.org/stable/plasma/$version/...`
  - Gear -> `https://download.kde.org/stable/release-service/$version/src/...`
- Reset package releases to 1 for newly bumped upstream source versions while preserving BFSOS meta-package behavior where no source tarball exists.
- Corrected a pre-existing malformed `bluedevil` `ource=` line and normalized the multiline Konsole release-service source while preserving its local patch.
- Included `oxygen-icons` in the Frameworks 6.29.0 refresh rather than leaving its old 6.0.0 snapshot behind.
- Removed stale KF5-era descriptions from the refreshed K3b and KMix ports.
- Static validation after the refresh: every Plasma `Pkgfile` passes `bash -n`; no old `6.26.0`, `6.6.5`, or `26.04.1` version references remain in Plasma Pkgfiles; no malformed `ource=` or `http://download.kde.org` source remains; all 148 current-series source-bearing ports use the expected KDE upstream path family.
- Full Plasma hard-dependency closure against all BFSOS collections reports **0 unresolved hard dependencies**.
- **Do not call the KDE refresh runtime-complete yet.** The next clean package build must expose any new upstream dependency/CMake changes, followed by fresh Plasma X11 + Wayland login, systemd-user session, portal, KIO/default-app, PipeWire/WirePlumber/RTKit audio, and failed-unit regression checks.
- Legacy KF5 compatibility packages that intentionally remain on 5.x are not blindly rewritten as KF6; audit whether they are still required and remove/modernize them separately.

### r193 static validation

- `bash -n`: Bootstrap, installer r67, pkgutils/ccache/ca-certificates/curl Pkgfiles, and every Plasma Pkgfile: PASS.
- `sh -n`: both maintained `pkgin` helper copies: PASS.
- Plasma hard-dependency closure: **0 unresolved**.
- Generated verification artifacts currently present in supplied project tree: **0**.
- **Next test:** commit/merge r193, begin one clean Bootstrap 1 -> 2 -> 3 cycle with no manual CA/ccache workaround, then build the refreshed desktop from the clean result and validate PAM/logind plus Plasma X11/Wayland/audio.

## r194 Tracker Update — Bootstrap Stage 1 success-screen cleanup

-   **Generated:** 2026-08-26
-   [ ] **OPEN — Remove the redundant Dialog box at the end of Bootstrap Stage 1.**
    After the temporary-toolchain tar archive has been created successfully and
    all existing archive integrity/payload checks have passed, return directly
    to the Bootstrap main menu.
-   Do **not** require an extra acknowledgement/OK/Enter action after successful
    Stage 1 archive creation.
-   Preserve the existing Stage 1 archive creation, compression, validation,
    partial-archive cleanup, and failure reporting. A real archive/compression
    or validation failure must still remain visible to the user and must not be
    treated as success.
-   **Regression test:** Run a clean Bootstrap Stage 1, verify the toolchain
    archive is fully created and validated, and confirm Bootstrap immediately
    returns to the main menu with Stage 1 shown as complete and Stage 2
    available, with no final success Dialog/pause.

## r195 Tracker Update — Lynx dependency-chain audit / optionalization

-   **Generated:** 2026-08-26
-   [ ] **OPEN — Audit the Lynx dependency chain and reduce unnecessary hard dependencies.**
    The first installer run with Lynx selected pulled a much larger dependency
    chain than expected, including packages such as `libpsl`,
    `gobject-introspection`, GLib-related components, and other supporting
    libraries encountered while resolving the optional-package install set.
-   Determine the exact dependency path from `lynx` to each non-obvious package
    that was pulled in. Distinguish dependencies that Lynx actually requires
    for the BFSOS build from features that are optional or only needed when
    enabling additional functionality.
-   Move genuinely optional functionality out of hard `# Depends on:` chains
    where possible. Prefer a minimal Lynx build that provides the expected
    text-browser functionality without dragging in large GUI/introspection
    stacks unless those features are intentionally selected.
-   Review Lynx's current configuration options together with the dependency
    metadata of its direct and transitive dependencies. Do not remove a package
    merely because it is large; only optionalize/remove dependencies after
    confirming the corresponding feature is not required by the default BFSOS
    Lynx build.
-   In particular, explain why selecting Lynx during the installer reached
    `libpsl` and then `gobject-introspection`, and determine whether that path
    can be narrowed or eliminated.
-   **Regression test:** On a clean base system, run `prt-get depinst lynx`
    (or the installer equivalent), record the resulting dependency closure,
    verify Lynx builds and runs successfully, and confirm no unnecessary
    graphical/introspection packages are installed by default.

## r196 Tracker Update — X.Org build environment, GLib/GI bootstrap cycle, and Polkit pre-install

-   **Generated:** 2026-08-26

### [~] X.Org package-build environment / prefix corruption — fix implemented, clean regression pending

-   Confirmed that `/etc/profile.d/xorg.sh` correctly defines:
    - `XORG_PREFIX=/usr`
    - `XORG_CONFIG="--prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static"`
-   Confirmed those variables are present in a login shell but absent from the
    non-login build context used by installer/package transactions.
-   This caused X.Org ports that rely on `$XORG_CONFIG`/`$XORG_PREFIX` to build
    with unintended prefixes. Observed examples:
    - `util-macros` installed `xorg-macros.pc` under
      `/usr/local/share/pkgconfig`.
    - `xcb-proto` additionally contained a malformed
      `./configure --prefix= $XORG_CONFIG`, causing `xcb-proto.pc` to land under
      `/share/pkgconfig`.
    - downstream `libxcb` then failed because neither `xorg-macros` nor
      `xcb-proto` could be found through the normal pkg-config search path.
-   Implemented deterministic X.Org build defaults in the normal
    `ports/core/pkgutils/pkgmk.conf` and Bootstrap-generated pkgmk.conf so
    package builds do not depend on login-shell profile loading.
-   Added `ports/core/aaa_filesystem/xorg.sudoers` preserving
    `XORG_PREFIX` and `XORG_CONFIG` through sudo.
-   Fixed `aaa_filesystem` to actually install both the existing `kf6.sudoers`
    and new `xorg.sudoers` into `/etc/sudoers.d/` with mode 0440. The KF6
    sudoers file had previously existed in the source array without an install
    rule.
-   Fixed `xcb-proto` malformed configure invocation.
-   Repaired the current partially installed target by rebuilding
    `util-macros` and `xcb-proto`; final verification showed:
    - `/usr/share/pkgconfig/xorg-macros.pc`
    - `/usr/share/pkgconfig/xcb-proto.pc`
    - `pkg-config --modversion xorg-macros` -> 1.20.2
    - `pkg-config --modversion xcb-proto` -> 1.17.0
    - no remaining copies in `/usr/local` or `/share`.
-   [ ] **Regression:** perform a clean Bootstrap + installer build and verify
    all X.Org ports see the intended `/usr` prefix from non-login,
    sudo/prt-get/pkgmk, and installer contexts. Audit the tree for any package
    accidentally installed into `/usr/local`, `/share`, or other unintended
    prefixes.

### [~] Port source-directory / stale-version cleanup — fixes found during installer regression

-   Fixed `libpsl` Meson invocation so pkgmk's already-entered source directory
    is used rather than attempting to enter `$name-$version` a second time.
-   Fixed `gobject-introspection` with the same Meson source-directory problem.
-   Fixed `libxcb` stale hard-coded documentation path `libxcb-1.16` to use
    `libxcb-$version`.
-   [ ] **OPEN audit:** scan all ports for:
    - Meson/CMake/configure invocations that redundantly reference
      `$name-$version` after pkgmk has already changed into the extracted source
      directory.
    - hard-coded old version strings in install/doc/path commands after a port
      version bump.
-   [ ] **Regression:** build affected ports from a clean source/build cache.

### [ ] OPEN — Failed package builds must never leave reusable/empty package archives

-   A failed `gobject-introspection` build left
    `gobject-introspection#1.84.0-1.pkg.tar.zst` behind.
-   On retry, pkgmk considered that archive up to date and `pkgadd` rejected it
    as an empty package.
-   Ensure every failed configure/build/install/package transaction removes
    any partial output archive, and that an existing package archive is
    validated before being accepted as an up-to-date build result.
-   Extend the existing pkgmk fail-fast work so the first failed command inside
    `pkg_build()` stops the build immediately rather than allowing later
    install/cleanup commands to run.
-   **Regression:** deliberately fail configure, compile, install, and archive
    creation independently; verify no package archive remains usable after any
    failure and the next retry rebuilds automatically.

### [ ] OPEN — Formalize the GLib / GObject-Introspection two-pass bootstrap cycle

-   Confirmed the installed BFSOS target had `gobject-introspection` tools but
    no `GLib-2.0.gir`, `GObject-2.0.gir`, or `Gio-2.0.gir`.
-   The GLib port enables introspection only when `gobject-introspection` is
    already installed. During the initial dependency sequence, GLib is built
    first without introspection; `gobject-introspection` is installed later,
    but GLib is not automatically rebuilt.
-   This leaves downstream packages such as Polkit unable to generate their
    GIR data even though `g-ir-scanner` is installed.
-   Implement an explicit two-pass dependency/bootstrap strategy:
    1. Build/install GLib in bootstrap mode without introspection.
    2. Build/install `gobject-introspection`.
    3. Rebuild GLib with `-D introspection=enabled`.
    4. Verify `GLib-2.0.gir`, `GObject-2.0.gir`, and `Gio-2.0.gir` are present
       under `/usr/share/gir-1.0`.
    5. Continue Polkit and the desktop dependency graph.
-   Determine whether this belongs in dependency metadata, a dedicated
    bootstrap/rebuild hook, or installer/package-manager transaction logic so
    ordinary `prt-get depinst` produces the same correct final state.
-   **Regression:** clean install of NetworkManager/desktop dependency closure
    must end with usable GLib GIR files without manual package rebuilds.

### [ ] OPEN — Fix Polkit pre-install failure and Polkit introspection build path

-   Installer regression reached `polkit 127`; Meson configuration succeeded
    with PAM, logind, man pages, and introspection enabled, but the build failed
    generating `Polkit-1.0.gir` because `g-ir-scanner` could not find
    `Gio-2.0.gir`.
-   This is expected to be resolved by the GLib/GObject-Introspection two-pass
    fix above; do not permanently disable Polkit introspection as a workaround.
-   Separately, `prt-get` reports `polkit [pre: failed]`. Audit the Polkit
    `pre-install` script independently of the GIR failure:
    - identify the exact failing command and expected user/group/filesystem
      prerequisite;
    - make it idempotent for fresh install, retry, and package update;
    - ensure a failed pre-install aborts clearly and does not leave partial
      account/filesystem state;
    - verify Polkit's `polkitd` user/group, PAM files, systemd units,
      sysusers/tmpfiles integration, and permissions after installation.
-   **Regression:** after GLib GIR repair, rebuild/install Polkit from a clean
    cache and confirm:
    - pre-install exits 0;
    - `Polkit-1.0.gir` builds successfully;
    - package installation succeeds;
    - Polkit daemon and authorization tools work after first boot.

### [ ] OPEN — util-macros `/usr/X11R6/usr` compatibility-symlink cleanup

-   Rebuilding `util-macros` still prints:
    `ln: /usr/X11R6/usr: cannot overwrite directory`.
-   Audit the old X11 compatibility symlink logic in `util-macros` /
    `aaa_filesystem`. Avoid constructing `/usr/X11R6/usr` or recursively
    symlinking `/usr` into itself.
-   Keep only compatibility links that are still needed by current BFSOS/X.Org.
-   **Regression:** clean X.Org bootstrap must produce no `/usr/X11R6/usr`
    collision and no unintended directory/symlink topology.

## r197 Tracker Update — ports-tree audit / installer dependency repair pass

-   **Generated:** 2026-08-26
-   **Basis:** full supplied BFSOS project tree plus the r196 tracker. This pass
    treats the previously successful full X.Org build as a useful baseline:
    today's isolated failures are not assumed to mean that the entire X.Org
    collection is broken. Runtime items below remain open until a clean build
    proves them.

### [~] X.Org tree audit — static cleanup implemented / clean runtime regression pending

-   The r196 global `XORG_PREFIX` / `XORG_CONFIG` fix remains the primary
    correction for non-login `pkgmk`, `prt-get`, sudo, Bootstrap, and installer
    builds.
-   Audited X.Org Pkgfiles for a second ambient build variable, `$docdir`.
    Multiple X.Org library recipes depended on that shell variable without
    defining it locally. Replaced those uses with explicit
    `--docdir=/usr/share/doc/$name-$version` arguments and bumped affected port
    releases.
-   Removed the obsolete `ports/xorg/util-macros/pre-install`. The old hook
    duplicated global X.Org environment policy and attempted compatibility
    links that could produce `/usr/X11R6/usr` collisions and a pointless
    `/usr/share/X11 -> /usr/share/X11` self-link. X.Org profile/sudo policy now
    belongs to `aaa_filesystem` / `pkgmk.conf`.
-   Fixed additional pkgmk source-directory assumptions found in X.Org:
    `libvdpau` and `mesa-demos` now configure Meson from the source directory
    that pkgmk has already entered rather than looking for a nested
    `$name-$version` directory.
-   `libX11` now directly declares `xorgproto` in addition to `libxcb` and
    `xtrans`. A full X.Org meta build can mask missing direct dependency
    metadata because protocol packages may already be installed; isolated
    `prt-get depinst libX11` must not rely on that ordering.
-   Added `scripts/bfs-ports-static-audit.sh`; the current tree passes its
    checks for Pkgfile shell syntax, malformed `${JOBS-1}`, nested Meson/CMake
    `$name-$version` assumptions inside `pkg_build()`, ambient X.Org `$docdir`,
    malformed `--prefix= $XORG_CONFIG`, obsolete util-macros pre-install, and
    the required libX11 `xorgproto` dependency.
-   [ ] **Runtime regression:** from a clean base, build/install
    `util-macros -> xorgproto/xcb-proto -> libxcb -> libX11` using only declared
    dependencies, then build the complete X.Org meta stack. Verify no files
    unexpectedly land in `/usr/local`, `/share`, or `/usr/X11R6/usr`.
-   [ ] **Environment regression:** repeat representative X.Org builds from a
    login shell, non-login shell, `sudo prt-get`, installer chroot, and normal
    installed-system package update. Every path must resolve the same `/usr`
    prefix.

### [~] GLib / GObject-Introspection bootstrap cycle — implementation added / runtime pending

-   Static inspection found a second defect beyond the r196 dependency-cycle
    description: the GLib Pkgfile computed `PKGMK_INTROSPECTION=' -D
    introspection=enabled'` when `gobject-introspection` was installed but did
    **not pass that variable to Meson**. A manual GLib rebuild therefore would
    still have omitted `GLib-2.0.gir`, `GObject-2.0.gir`, and `Gio-2.0.gir`.
-   GLib release is bumped and its build now explicitly chooses
    `-D introspection=disabled` for the bootstrap pass and
    `-D introspection=enabled` when `gobject-introspection` is installed.
    Configure/compile/install steps now return failure immediately.
-   `gobject-introspection` release is bumped; its Meson invocation is corrected
    to `meson setup build .`, and configure/compile/install/byte-compilation
    steps are fail-fast.
-   Added installer **r68**
    `install-bfs-menu-v50-r68-glib-introspection-preflight.sh`, and pointed
    `install-bfs-menu-current.sh` to it.
-   Installer r68 examines the selected optional-package dependency closure
    before the main transaction. If the closure requires
    `gobject-introspection`/Polkit, it installs `gobject-introspection` first
    when needed, force-rebuilds GLib when the three core GIR files are absent,
    and refuses to continue until all three GIR files exist.
-   [ ] **Runtime regression:** clean install selecting NetworkManager and other
    desktop packages must automatically complete the two-pass cycle with no
    manual chroot intervention.
-   [ ] **General package-manager behavior remains open:** the installer
    preflight fixes the installer transaction, but ordinary installed-system
    `prt-get depinst` should eventually receive an equivalent deterministic
    solution or documented package rebuild mechanism.

### [~] Polkit pre-install + introspection — implementation added / runtime pending

-   Polkit release is bumped.
-   Reworked `pre-install` to be idempotent. Existing `polkitd` UID/GID 27 is
    accepted when correct; conflicting users/groups produce explicit errors;
    missing entries are created once. This addresses retry/update states that
    previously surfaced as `polkit [pre: failed]`.
-   Polkit now fails early with a clear diagnostic when
    `/usr/share/gir-1.0/Gio-2.0.gir` is unavailable instead of entering a long
    Meson/Ninja build that later dies in `g-ir-scanner`.
-   Polkit's Meson configure/compile/install commands are now explicitly
    fail-fast. Introspection remains enabled; do **not** permanently disable it
    merely to bypass the GLib bootstrap defect.
-   [ ] **Runtime regression:** fresh Polkit install, repeated install/update,
    and installer retry must all leave the expected `polkitd` account and
    successfully build `Polkit-1.0.gir`.

### [~] Failed-build archive poisoning — wrapper mitigation implemented / core hardening still open

-   `pkgutils` release is bumped and the BFSOS `bfs-pkgmk` wrapper now removes
    the matching package archive when pkgmk returns failure.
-   On apparent success, the wrapper validates an existing matching package
    archive with `bsdtar`; unreadable or empty archives are rejected, removed,
    and converted to a build failure.
-   This directly addresses the observed sequence where failed
    `gobject-introspection` left a package archive that a later run treated as
    current and `pkgadd` rejected as empty.
-   [ ] **Core/generalization:** verify behavior for non-default package
    directories and decide whether the same invariant should also be enforced
    inside pkgmk itself rather than only the BFSOS wrapper.
-   [ ] **Fault-injection regression:** deliberately fail configure, compile,
    install, and archive creation and verify no reusable package survives.

### [~] Pkgfile source-directory / stale-build-pattern audit — fixes implemented / runtime pending

-   Corrected pkgmk auto-source-directory assumptions in affected current
    recipes, including `gobject-introspection`, `glib`, `glibmm`, `libsigc++`,
    `libsigc++2`, `libnma`, `orc`, `pangomm`, `cairomm`, `atkmm`,
    `mm-common`, `lapack`, `c-ares`, `robin-hood-hashing`, `protobuf`,
    `libvdpau`, and `mesa-demos`.
-   Intentional multi-source layouts such as `lld` were not rewritten merely
    because they contain a versioned source directory.
-   Fixed remaining `${JOBS-1}` typo-style defaults found by the audit,
    including affected opt/core/compat-32 recipes.
-   Fixed the LAPACK source URL so the BFSOS package `release=` number is not
    embedded in the upstream source filename.
-   [ ] **Runtime regression:** clean-cache builds of every modified port.
-   [ ] Keep the static audit in maintainer workflow so new ports cannot
    reintroduce these patterns silently.

### [~] Lynx / optional-package dependency attribution corrected

-   The r195 suspicion that Lynx itself was pulling the large GLib/X.Org/GI
    chain was not supported by the supplied dependency metadata.
-   Lynx's hard dependencies are only `brotli openssl`; its listed optional
    dependencies are `gnutls libarchive libidn2 zip sharutils`.
-   The unusual dependency chain encountered during the installer came from the
    simultaneously selected **NetworkManager** stack. Current metadata directly
    pulls `gobject-introspection`, `libpsl`, `polkit`, `python3-gobject`, and
    `vala`; the Python/GObject/Cairo path reaches X.Org libraries including
    `libxcb` and `libX11`.
-   [ ] **OPEN — NetworkManager dependency/feature audit:** determine which of
    its current hard dependencies correspond to BFSOS-required default features
    and which can be optionalized by explicit Meson feature switches. Do not
    remove Polkit, introspection, libpsl, Python bindings, Vala, or other
    dependencies merely to shrink the graph without confirming the resulting
    NetworkManager functionality and desktop integration.
-   [ ] **Regression:** record dependency closures independently for
    `lynx`, `networkmanager`, and `snapper` on a clean base so installer output
    clearly identifies which selected package owns each transitive dependency.

### [ ] Clean-install release gate after r197

-   Start from a fresh Bootstrap/base archive rather than the partially repaired
    installer target used to discover these issues.
-   Run the static ports audit before the install.
-   Exercise the LTS-kernel + NetworkManager + optional-package path again.
-   Verify automatic GLib/GI two-pass handling, Polkit pre-install retry
    safety, isolated libX11 dependencies, full X.Org build, and package-archive
    cleanup.
-   Do not mark the current runtime items complete solely from static checks or
    from manual repair of the abandoned target.

## r198 Tracker Update — destructive-format checkpoint invalidation

-   **Generated:** 2026-08-26

### [~] Installer resume-state invalidation after destructive formatting — fix implemented / runtime regression pending

-   **Runtime root cause confirmed:** a previous installer resume profile restored
    completion checkpoints into the in-memory `/run/bfs-installer-checkpoints`
    view before the user changed the recovered storage plan from KEEP to FORMAT.
    The installer then formatted the new root filesystem but still retained the
    old `base_extracted` runtime checkpoint.
-   The next install phase logged:
    `Resume checkpoint: base archive already extracted; preserving installed target`
    even though `/` had just been recreated.
-   Because base extraction was skipped, the fresh target contained no
    `/usr/bin/env`; entering the chroot failed immediately with exit status 127:
    `chroot: failed to run command '/usr/bin/env': No such file or directory`.
-   **Installer r69 created:**
    `scripts/install-bfs-menu-v50-r69-format-checkpoint-invalidation.sh`.
-   r69 invalidates completion checkpoints **before formatting begins**, based
    on the destructive mountpoint:
    - formatting `/`, `/usr`, or `/var` invalidates
      `base_extracted`, `accounts_configured`, `packages_complete`,
      `system_config_complete`, and `bootloader_complete`;
    - formatting `/opt` invalidates package/system/bootloader completion because
      BFSOS intentionally installs major package stacks there;
    - formatting `/etc` invalidates system/bootloader completion;
    - formatting `/boot` or the EFI System Partition invalidates
      `bootloader_complete`.
-   Checkpoint invalidation clears both the current runtime marker under
    `/run/bfs-installer-checkpoints` and any matching persistent marker under
    `/var/lib/bfs-installer` when it is still accessible.
-   The fix deliberately preserves saved installer **configuration choices**
    (hostname, filesystem assignments, optional-package selections, etc.).
    Remembering those settings is useful; only completion state that became
    invalid because storage was destroyed is discarded.
-   **Required regression:** start with a saved incomplete installation profile,
    recover it, change root from KEEP to a destructive format, and install.
    Require:
    1. the old `base_extracted` checkpoint is invalidated;
    2. the base archive is actually extracted into the new root;
    3. `/usr/bin/env`, `/usr/bin/bash`, `/usr/bin/pkgmk`, and `/etc/os-release`
       exist before chroot;
    4. no stale account/package/system/bootloader checkpoint is reused;
    5. installer proceeds into the chroot instead of returning status 127.
-   **Additional regression matrix:** independently reformat `/boot`, EFI,
    `/opt`, `/usr`, and `/var` during resume and verify only the appropriate
    checkpoint scope is invalidated.
-   **Release criterion:** no destructive storage choice may leave a completion
    checkpoint valid for files that the same installer transaction just erased.

## r199 Tracker Update — GLib two-pass footprint lifecycle + integrity-toggle ordering

-   **Generated:** 2026-08-27

### [~] GLib/GObject-Introspection two-pass footprint bug — fix implemented / runtime regression pending

-   Runtime confirmed that the intended GLib second pass was actually generating
    the required GIR/typelib files (`GLib-2.0.gir`, `GObject-2.0.gir`,
    `Gio-2.0.gir`, and matching typelibs), but pkgmk rejected them as NEW files.
-   **Root cause:** the first bootstrap GLib build (without introspection) was
    allowed to create the port's `.footprint`.  The second/final build then
    legitimately contained more files and mismatched against that bootstrap-only
    footprint.
-   **Installer r70 created:**
    `scripts/install-bfs-menu-v50-r70-glib-footprint-cycle-fix.sh`.
-   r70 treats the first-pass GLib footprint as temporary.  Before the
    introspection-enabled second pass, if the current GLib footprint does not
    contain `usr/share/gir-1.0/Gio-2.0.gir`, r70 removes that bootstrap-only
    footprint so pkgmk can establish/validate the final package layout.
-   With footprint verification enabled, r70 additionally refuses to declare
    the GLib/GI cycle complete if an existing final footprint still omits
    `Gio-2.0.gir`.
-   **Design rule:** only the final introspection-enabled GLib package is
    authoritative for the normal GLib footprint.  The temporary bootstrap pass
    must never define release package contents.
-   [ ] **Runtime regression:** clean installer run with footprint verification
    enabled must complete:
    GLib bootstrap -> gobject-introspection -> GLib final rebuild without a
    footprint mismatch, and the final GLib footprint must contain the GIR and
    typelib files.

### [~] Installer integrity controls were applied too late — fix implemented / runtime regression pending

-   Runtime confirmed selecting `Verify footprints: no` did not affect the GLib
    preflight build even though the saved installer setting changed correctly.
-   **Root cause:** the chroot script configured
    `PKGMK_IGNORE_MD5SUM`, `PKGMK_IGNORE_SIGNATURE`, and
    `PKGMK_IGNORE_FOOTPRINT` only after ports synchronization, sysup, dependency
    preflights, and optional-package installation had already run.
-   r70 now applies the selected integrity policy to `/etc/pkgmk.conf` before
    the first package operation in the chroot.
-   The later configuration call is retained as an idempotent reinforcement for
    the final installed system.
-   [ ] **Regression:** independently toggle MD5, signature, and footprint
    verification off and on, retry the installer, and verify the corresponding
    `PKGMK_IGNORE_*` values are effective during the very first package build as
    well as persisted afterward.
-   [ ] Defaults remain secure: all three verification controls must default to
    enabled for normal/RC/release installs.

### [x] GLib Meson introspection option syntax corrected

-   Corrected the r197 GLib option from the invalid single argument
    `"-D introspection=enabled"` / `"-D introspection=disabled"` to
    `"-Dintrospection=enabled"` / `"-Dintrospection=disabled"`.
-   This removes Meson's `Unknown option: " introspection"` failure.
-   Static `bash -n` validation passes for the updated Pkgfile and installer r70.

## r200 Tracker Update — NetworkManager dependency minimization audit

-   **Generated:** 2026-08-27

### [ ] OPEN — Audit and reduce NetworkManager hard dependencies

-   Current installer testing showed that selecting NetworkManager can pull a
    disproportionately large dependency closure, including GObject
    Introspection/Python/GObject/Cairo-related packages and downstream X.Org
    libraries.
-   This is undesirable for a base/networking component unless those
    dependencies are genuinely required for the default BFSOS NetworkManager
    feature set.
-   Audit the current `ports/opt/networkmanager/Pkgfile` hard dependency list
    package-by-package and map every dependency to the exact Meson feature,
    helper, binding, documentation target, test, or runtime capability that
    requires it.
-   Keep as hard dependencies only what BFSOS intends to provide by default,
    including the NetworkManager daemon, `nmcli`, D-Bus/systemd integration,
    Ethernet support, and the selected default Wi-Fi/network backend behavior.
-   Review likely optional/development-oriented dependencies such as:
    - `gobject-introspection`
    - `python3-gobject`
    - `vala`
    - documentation-generation dependencies
    - test-only dependencies
    - binding/developer API generators
    - dependencies whose only purpose is an optional GUI, introspection, or
      language-binding feature
-   When a dependency becomes optional, explicitly pass the corresponding Meson
    option as disabled when that dependency is absent. Do not rely on Meson's
    `auto` behavior to silently re-enable optional features and recreate the
    large dependency chain.
-   Do **not** remove Polkit, libpsl, introspection, Python bindings, Vala, or any
    other dependency solely to shrink the graph. First prove whether the
    dependency is required for the desired BFSOS default runtime behavior and
    desktop integration.
-   Keep genuinely desktop-specific integration in a separate optional package
    or optional dependency path where practical rather than forcing it into
    every NetworkManager installation.
-   **Dependency-closure regression:** on a clean BFSOS base, record
    `prt-get depinst networkmanager` before and after the audit and compare the
    complete dependency graph. A NetworkManager-only install should not pull a
    broad X.Org/desktop stack unless a retained default feature demonstrably
    requires it.
-   **Functional regression:** after dependency reduction, verify:
    1. `NetworkManager.service` starts successfully;
    2. Ethernet configuration works;
    3. `nmcli` device/connection management works;
    4. Wi-Fi works when the selected BFSOS Wi-Fi backend is installed;
    5. DNS/resolver integration works;
    6. Polkit-controlled privileged operations work when Polkit support is
       intentionally enabled;
    7. desktop integration still works when the optional desktop/introspection
       dependencies are deliberately installed.
-   **Installer regression:** selecting NetworkManager in the installer must
    clearly attribute its transitive dependencies and must not unexpectedly
    turn a networking-only install into a large X.Org/desktop dependency
    transaction.
-   **Release criterion:** NetworkManager's default dependency closure is
    intentional, documented, reproducible, and contains no dependency whose
    only purpose is an unselected optional feature.

## r201 Tracker Update — LTS MD personality consistency + initramfs verification

-   **Generated:** 2026-08-27

### [ ] OPEN — Make Linux LTS MD personalities match the normal kernel module policy

-   Installer regression with the selected `linux-lts` kernel
    `6.18.46-BFS-LTS` confirmed the active JBOD/Linear array was valid and
    healthy:
    - `/dev/md0`
    - RAID personality: `linear`
    - six active members
    - persistent metadata 1.2
-   The LTS kernel configuration currently has:
    - `CONFIG_MD=y`
    - `CONFIG_BLK_DEV_MD=y`
    - `CONFIG_MD_LINEAR=y`
    - `CONFIG_MD_RAID0=y`
    - `CONFIG_MD_RAID1=y`
    - `CONFIG_MD_RAID10=y`
    - `CONFIG_MD_RAID456=y`
-   This differs from the intended/normal BFSOS kernel policy where the MD RAID
    personalities are provided as loadable modules.
-   Change the LTS kernel configuration so the relevant MD personalities use
    modules consistently with the normal kernel, including at least:
    - `CONFIG_MD_LINEAR=m`
    - `CONFIG_MD_RAID0=m`
    - `CONFIG_MD_RAID1=m`
    - `CONFIG_MD_RAID10=m`
    - `CONFIG_MD_RAID456=m`
-   Audit the normal and LTS kernel configs side-by-side for other storage-driver
    policy drift rather than changing only `linear`.
-   After rebuilding `linux-lts`, verify the corresponding module files are
    actually installed under `/usr/lib/modules/$KVER/kernel/drivers/md/`.
-   This item is separate from the existing kernel-module Zstd-compression work:
    after converting the MD personalities to modules, verify they are also
    compressed according to the BFSOS `.ko.zst` policy.
-   **Regression:** boot JBOD/Linear, RAID0, RAID1, RAID10, and RAID456 storage
    layouts using the LTS kernel and confirm Dracut can include/load the exact
    required module set.

### [ ] OPEN — Initramfs verification must distinguish built-in kernel support from modules

-   The installer successfully generated:
    `/boot/initramfs-6.18.46-BFS-LTS.img`
    and correctly generated:
    - `/etc/mdadm.conf`
    - `rd.md.uuid=41eedc31:dd0382aa:ecb48b76:67303744`
    - `rd.lvm.lv=bfs-vg/home`
    - `rd.lvm.lv=bfs-vg/var`
-   The initramfs contained `mdadm`, the generated mdadm configuration, LVM
    tooling, `dm-mod.ko`, and Dracut command-line entries including
    `rd.driver.pre=linear`.
-   The installer nevertheless failed final verification with:
    `Initramfs verification failed: required md driver 'linear' was not found`
    because it searched for a `linear.ko*` module even though the selected LTS
    kernel had `CONFIG_MD_LINEAR=y`.
-   Fix installer initramfs verification so each required MD personality is
    evaluated against `/boot/config-$KVER`:
    - `CONFIG_MD_<PERSONALITY>=y` -> built into the kernel; valid without a
      module file in the initramfs;
    - `CONFIG_MD_<PERSONALITY>=m` -> require the matching module in the
      initramfs, accepting the supported compressed-module suffixes such as
      `.ko.zst`;
    - option unset/disabled -> fail clearly because the selected kernel cannot
      support the required storage personality.
-   Apply this logic generically to at least:
    - Linear/JBOD
    - RAID0
    - RAID1
    - RAID10
    - RAID456
-   Do not treat the presence of `rd.driver.pre=<driver>` as proof that the
    driver exists as a module; built-in drivers have no `.ko` file to find.
-   Review Dracut generation so `--force-drivers` is used only for drivers that
    are actually modular. Built-in MD personalities should not be presented as
    missing merely because Dracut cannot embed a nonexistent module file.
-   **Regression matrix:** test the verifier with both `=y` and `=m` kernel
    configurations and with both uncompressed `.ko` and compressed `.ko.zst`
    modules. A valid built-in configuration must pass, a valid modular
    configuration must pass only when the module is present, and an unsupported
    personality must fail before reboot.


### Kernel source symlink/default-flavor logic still incorrect — regression evidence (2026-08-26)

- [ ] **OPEN / regression confirmed:** `/usr/src/linux` is still being pointed at the LTS source rather than being controlled by the configured BFSOS default kernel flavor.
- **Observed VM state:** both `/usr/src/linux` and `/usr/src/linux-lts` point to `linux-6.18.46-BFS-LTS`.
- `/usr/src/linux-lts -> linux-6.18.46-BFS-LTS` is correct for the installed LTS kernel.
- `/usr/src/linux` must represent the currently configured/default kernel flavor; installing or upgrading `linux-lts` must not steal this generic link when mainline is configured as default, and the inverse must also hold.
- Package installation order must never determine `/usr/src/linux`.
- Kernel install/update logic must consult the persistent BFSOS kernel-flavor/default selection (including `/etc/bfsos/kernel-flavor` where applicable) and update the generic source link deterministically and idempotently.
- **Regression matrix:** test normal-only, LTS-only, both installed with normal default, both installed with LTS default, and independent/cross-updates of each flavor.
- After each case verify `/usr/src/linux`, `/usr/src/linux-lts`, kernel module `build`/`source` links, and GRUB kernel/default entries remain consistent with the configured flavor.
- Keep the existing kernel-source/default-flavor tracker work OPEN until this matrix passes on a fresh install and after kernel package updates.

## 2026-08-28 — Plasma meta dependency closure: SDDM missing after full Plasma install

- [ ] **OPEN — Add SDDM to the Plasma desktop dependency closure and regression-test a fresh install.**
  - **Observed:** `prt-get depinst plasma-meta` completed successfully, including `plasma-default-apps` and `plasma-meta [post: ok]`, but SDDM was not installed. The intended Plasma login/display manager therefore was absent after the supposedly complete Plasma meta-package installation.
  - **Likely cause:** `sddm` is missing from `plasma-meta` or another appropriate top-level Plasma dependency chain. Audit the current dependency graph to determine exactly where the dependency belongs rather than relying on a later manual `prt-get depinst sddm`.
  - **Required fix:** Ensure a normal `prt-get depinst plasma-meta` on a clean BFSOS base installs SDDM automatically, along with the files/services required to present the Plasma login greeter. Keep the dependency explicit enough that future dependency cleanup cannot silently drop the display manager.
  - **Also verify:** SDDM is configured/enabled according to BFSOS desktop policy, Plasma X11 and Wayland sessions appear in the greeter, and the session desktop files resolve to the intended `/opt/kf6` installation rather than broken paths caused by an empty `KF6_PREFIX` under sudo.
  - **Regression test:** On a fresh VM with no preinstalled desktop/display manager, run only the documented Plasma installation path (`prt-get depinst plasma-meta`), verify `prt-get isinst sddm` succeeds, verify the SDDM systemd unit is installed and enabled as intended, reboot, confirm the SDDM greeter appears, and successfully log into both supported Plasma session types where applicable.

## 2026-08-28 — Plasma audio stack must be enabled automatically for fresh users

- [ ] **OPEN — Automate PipeWire + PipeWire-Pulse + WirePlumber activation and keep legacy PulseAudio disabled.**
  - **Observed after full Plasma install:** `pipewire`, `wireplumber`, `rtkit`, and the PipeWire Pulse compatibility units were installed, but the required user units were all disabled for user `brian`:
    - `pipewire.socket` — disabled
    - `pipewire-pulse.socket` — disabled
    - `wireplumber.service` — disabled
  - Manual `systemctl --user enable pipewire.socket pipewire-pulse.socket wireplumber.service` created the expected per-user symlinks and allowed PipeWire and WirePlumber to start successfully. `pipewire-pulse.socket` then became active/listening and can socket-activate `pipewire-pulse.service` on demand.
  - The units reported `preset: enabled` even though they were not actually enabled for the user, so audit why BFSOS user-unit preset policy is not being applied during fresh user/session setup. Do not rely on every user manually running `systemctl --user enable` after installation.
  - **Required fix:** define a deterministic BFSOS default-audio policy that automatically enables the intended user units for each normal desktop user, preferably through proper systemd user presets/default wants or equivalent package/user-session integration rather than a one-off command tied to the currently logged-in account.
  - **Legacy PulseAudio policy:** standalone `pulseaudio.service` and `pulseaudio.socket` were installed but correctly remained disabled/inactive. Preserve that behavior so they cannot race PipeWire-Pulse for `/run/user/$UID/pulse/native`.
  - **Package/dependency audit:** the current `pipewire` port depends on `pulseaudio`, while PipeWire itself installs `pipewire-pulse.service` and `pipewire-pulse.socket`. Determine whether the full PulseAudio daemon package is truly required as a build/runtime dependency or whether only Pulse client libraries/headers are needed. Do not remove it until dependency closure has been proven.
  - **RTKit failure observed:** `rtkit-daemon.service` was installed but failed immediately with status 1. PipeWire and WirePlumber logged `RTKit error: org.freedesktop.DBus.Error.NoReply` and fell back to reduced realtime scheduling parameters. Audit RTKit service startup, D-Bus activation/policy, permissions, and preset behavior so the default Plasma audio stack gets working realtime scheduling.
  - Non-blocking VM warnings about missing UPower ownership, BlueZ service availability, and libcamera SPA support should be classified separately and must not obscure actual audio-stack failures.
  - **Fresh-user regression test:** install Plasma on a clean BFSOS VM, create/log in as a normal user, and without any manual `systemctl --user enable` commands verify:
    - `pipewire.socket` is enabled and active;
    - `pipewire-pulse.socket` is enabled and active/listening;
    - `wireplumber.service` is enabled and active;
    - `pipewire.service` starts successfully via socket/session activation;
    - Pulse clients connect through PipeWire-Pulse;
    - `pulseaudio.service` and `pulseaudio.socket` stay disabled/inactive;
    - `rtkit-daemon.service` is healthy and PipeWire/WirePlumber no longer log RTKit `NoReply` errors;
    - Plasma volume controls, playback, capture, and device switching work after reboot and on both X11 and Wayland sessions where supported.

## OPEN — Refresh XFCE and Compiz port trees; audit XScreenSaver alarming/ransomware-like screens

### Context / evidence
- After the Plasma stabilization work, perform a focused refresh of the BFSOS `xfce` and `compiz` port collections.
- Keep Compiz available if it remains maintainable and compatible with the current BFSOS X11/XFCE stack.
- Upstream/distribution research on 2026-08-28 shows Compiz Reloaded 0.8.x is still maintained: the Compiz Reloaded GitLab projects had 2026 activity, and Fedora Rawhide currently packages Compiz/CCSM 0.8.18. CCSM uses GTK3/Python 3 rather than requiring GTK2.
- Audit the current BFSOS Compiz collection for stale GTK2-era components, versions, source URLs, dependencies, Python bindings, decorators, plugins, and integration with current XFCE/X11.
- Previous XFCE/XScreenSaver testing displayed disturbing fake security/ransomware-like material implying that the system was compromised and payment was required. Do not assume this indicates a real compromise. Determine exactly which XScreenSaver hack/program produced the display and whether it is expected upstream content, an obsolete/undesirable saver, a packaging/configuration issue, or interaction with XFCE/Compiz.
- XScreenSaver includes many intentionally simulated/novelty display hacks, so identify the exact saver before treating the symptom as a security incident.

### Required work
1. Audit every BFSOS `xfce` port against current stable upstream releases and refresh versions, URLs, checksums, dependencies, build options, and integration metadata as needed.
2. Audit every BFSOS `compiz` port against the maintained Compiz Reloaded 0.8.x stack. Prefer maintained GTK3/Python 3 components where available; remove unnecessary GTK2 dependencies unless a current component genuinely requires them.
3. Verify the full Compiz collection remains buildable with the current BFSOS compiler/toolchain and current X.Org/XFCE stack.
4. Test XFCE both with its normal window manager/compositor and with Compiz, including login/logout, window decoration, CCSM, workspace switching, compositing, session save/restore, and fallback behavior.
5. Audit the installed XScreenSaver version and all enabled/default saver hacks. Reproduce the prior ransomware/security-warning-like screen and identify the exact executable/configuration entry responsible.
6. If the alarming screen is an intentional novelty saver, do not enable it by default in BFSOS. Consider excluding clearly misleading fake-malware/fake-security savers from the default random rotation while still allowing users to opt into them.
7. If it is not expected XScreenSaver behavior, investigate XFCE/Compiz session startup, configuration inheritance, stale user configuration, packaging, and executable ownership before concluding compromise.
8. Verify screen locking/authentication remains reliable and that XScreenSaver does not conflict with XFCE power management, DPMS, Compiz, or another locker.

### Regression tests
- Fresh VM: `prt-get depinst` of the XFCE desktop/meta package resolves all required dependencies and reaches a usable login/session without manual package installation.
- Fresh VM: Compiz and CCSM install cleanly from BFSOS ports and Compiz can replace the normal XFCE window manager without crashes or missing decorators/plugins.
- Confirm the maintained Compiz/CCSM stack uses expected current GTK/Python dependencies and does not pull GTK2 solely because of stale BFSOS metadata.
- Exercise XScreenSaver random mode for an extended test and inventory every enabled saver; no default saver should impersonate ransomware, malware, or a real security incident in a way likely to mislead users.
- Lock/unlock repeatedly under XFCE with and without Compiz; verify password authentication, DPMS/display wake, suspend/resume, and session recovery.
- Repeat on a clean user account to distinguish system defaults from stale per-user `~/.xscreensaver`, XFCE, or Compiz configuration.

## 2026-08-28 — VLC GUI build/integration audit

- [ ] **OPEN — Ensure the BFSOS VLC port builds and installs a complete graphical interface.**
  - Audit the current VLC version, source URL, dependencies, configure/build options, and installed files. Update to the appropriate current stable VLC release where needed.
  - Ensure the normal BFSOS VLC package includes a functional desktop GUI rather than producing an effectively command-line-only build.
  - Audit Qt GUI support and choose the Qt generation/configuration that is reliable with the current BFSOS desktop stack; prefer the modern Qt6 path when it passes the full regression matrix, but do not switch solely for version-number consistency.
  - Make all GUI dependencies explicit so `prt-get depinst vlc` on a clean system cannot silently omit the interface because an optional dependency happened not to be installed at build time.
  - Verify desktop files, icons, MIME associations, file dialogs, menus, preferences, subtitles, fullscreen, video output, hardware acceleration where available, and audio output through the BFSOS PipeWire/PipeWire-Pulse stack.
  - Regression-test VLC under both Plasma and XFCE, including X11 and Wayland where supported, and confirm a fresh dependency install produces the same GUI-capable package.

## 2026-08-28 — Plasma screen locker failure after desktop install / Firefox build

- [ ] **OPEN — Diagnose and fix the Plasma screen locker failure shown after the new Plasma installation.**
  - **Observed:** while the Plasma desktop was running, the session displayed a black emergency locker screen stating: `The screen locker is broken and unlocking is not possible anymore.` The displayed recovery instructions specifically used the legacy command `ck-unlock-session <session-name>`.
  - **Important clue:** the `ck-unlock-session` wording is associated with ConsoleKit-era session handling and is suspicious on the current BFSOS systemd/logind Plasma stack. Audit whether BFSOS has installed stale/legacy screen-locker assets, an old locker binary/data file, mixed KDE generations/prefixes, or an unintended ConsoleKit-oriented component.
  - The failure appeared while Firefox was being built/installed, but **do not assume Firefox is the cause**. Reproduce with and without a Firefox build and correlate timestamps before assigning causality. Also check whether the build caused resource exhaustion, process/X-client exhaustion, package replacement, library replacement, or another transient condition that crashed the locker.
  - Audit `kscreenlocker`/`kscreenlocker_greet` package ownership, version, runtime dependencies, QML imports, PAM configuration, systemd-logind integration, Qt6/QtWayland, layer-shell-qt, Plasma workspace dependencies, and `/opt/kf6` versus stale `/usr` KDE files.
  - Check whether the locker package or one of its hard runtime dependencies is missing from `plasma-meta`/the Plasma dependency closure. A successful `prt-get depinst plasma-meta` must leave locking/unlocking functional without manually discovering additional packages.
  - Run the installed `kscreenlocker_greet --testing` equivalent from the Plasma session and capture its stderr/journal output. Check `ldd` for unresolved libraries and inspect `journalctl --user`, the system journal, and coredumps around each failure.
  - Audit for version/ABI mismatches between `kscreenlocker`, `layer-shell-qt`, Qt6/QtWayland, Plasma Workspace, and KDE Frameworks. Similar upstream failures have been caused by locker crashes or mismatched Qt/LayerShell components, so BFSOS must verify its package set as a coherent stack rather than masking the emergency screen.
  - Verify `/etc/pam.d/kde`, `/etc/pam.d/kscreensaver` where applicable, and `/etc/pam.d/system-session` remain correct; `pam_systemd.so` must continue to establish the logind user session.
  - Confirm the recovery text used by the installed current locker is appropriate for systemd/logind (`loginctl`) rather than stale ConsoleKit (`ck-unlock-session`) instructions.

### Screen-locker regression tests
- Fresh VM: install only the documented Plasma meta package/dependency path, boot through SDDM, log into Plasma, manually lock/unlock at least 10 times, and verify password authentication every time.
- Repeat automatic idle lock, display power-off/wake, logout/login, and suspend/resume where supported.
- Repeat while a large package such as Firefox is compiling to determine whether load/resource pressure can reproduce the failure.
- Test both Plasma X11 and Plasma Wayland sessions where supported.
- Verify `kscreenlocker_greet` has no unresolved shared libraries, missing QML modules, crashes, or ABI mismatches and that its testing mode renders correctly.
- Verify no obsolete ConsoleKit-era locker files or recovery instructions are being selected from `/usr`, `/opt/kf6`, or stale package remnants.
- Treat this item as release-blocking for the Plasma desktop: BFSOS must not ship a default desktop that can enter an unrecoverable/broken graphical lock screen.

## r209 — Firefox/NSS p11-kit trust-anchor initialization failure — 2026-08-28

- [x] **Immediate Firefox HTTPS failure diagnosed and repaired on the current VM.** Firefox 154.0 returned `SEC_ERROR_UNKNOWN_ISSUER` for `www.cnn.com`, while the same host certificate chain verified successfully with OpenSSL and `curl -Iv https://www.cnn.com/` returned HTTP 200. This ruled out CNN/network/TLS interception and confirmed that the canonical PEM CA bundle itself was usable.
- [x] **System PEM trust path verified healthy.** `/etc/ssl/cert.pem` and `/etc/ssl/certs/ca-certificates.crt` both resolve to `/etc/pki/tls/certs/ca-bundle.crt`; the canonical bundle was a real ~185 KiB file containing 121 certificates, and OpenSSL returned `Verify return code: 0 (ok)` for CNN.
- [x] **NSS/p11-kit split-brain root cause confirmed.** `/usr/lib/libnssckbi.so` is intentionally linked to `./pkcs11/p11-kit-trust.so`, so Firefox/NSS consumes the p11-kit system trust view rather than directly reading the PEM bundle. `p11-kit` and `make-ca` were installed, but `trust list` returned no trust objects and neither `/etc/pki/anchors` nor `/etc/pki/trust/anchors` existed. Thus OpenSSL/curl had a valid PEM bundle while Firefox/NSS effectively had no trusted roots.
- [x] **make-ca configuration confirmed correct in principle.** `/etc/make-ca/make-ca.conf.dist` specifies `PKIDIR=/etc/pki`, `ANCHORDIR=${PKIDIR}/anchors`, `BUNDLEDIR=${PKIDIR}/tls/certs`, and `CABUNDLE=${BUNDLEDIR}/ca-bundle.crt`. The package installs the make-ca utility plus `update-pki.service`/`update-pki.timer`, but the installed system had not generated/populated the p11-kit anchor store.
- [x] **Runtime repair verified.** Running `sudo make-ca -g` generated the required trust data; Firefox subsequently loaded CNN normally with no certificate warning. This proves the immediate failure was CA/p11-kit initialization, not a Firefox package defect.
- [ ] **PERMANENT FIX — initialize complete runtime trust during install/bootstrap.** Ensure the final installed BFSOS system runs the appropriate `make-ca` generation step only after its required CA source data, p11-kit/NSS integration, and filesystem destinations are available. A fresh install must contain both a usable PEM bundle and a populated p11-kit trust view without manual intervention.
- [ ] **Audit package ownership/order and post-install behavior.** Define which package owns/creates `/etc/pki/anchors`, when `make-ca -g` is invoked, and how `ca-certificates`, `make-ca`, `p11-kit`, and `nss` upgrades interact. Preserve the existing non-empty canonical PEM bundle bootstrap protection and do not reintroduce earlier make-ca/ca-certificates file-ownership conflicts.
- [ ] **Audit `update-pki.service` / `update-pki.timer`.** Verify the service can regenerate/update both trust representations correctly and that enabling/scheduling policy is appropriate for BFSOS. Failure must be visible rather than silently leaving Firefox without roots.
- [ ] **Add installed-system trust regression checks.** On a completely fresh VM verify: `/etc/pki/tls/certs/ca-bundle.crt` is non-empty; `/etc/pki/anchors` exists and is populated as expected; `trust list` returns trust anchors; `/usr/lib/libnssckbi.so` resolves to the intended p11-kit module; OpenSSL verifies a public HTTPS chain; curl succeeds; and a brand-new Firefox profile opens multiple public HTTPS sites without `SEC_ERROR_UNKNOWN_ISSUER` or certificate exceptions.
- [ ] **Regression-test upgrades.** Upgrade/reinstall `ca-certificates`, `make-ca`, `p11-kit`, `nss`, and Firefox in representative orders and confirm neither the PEM bundle nor p11-kit trust anchors disappear or become stale.

**Status:** immediate VM problem **FIXED** by `make-ca -g`; permanent fresh-install/package automation remains **OPEN** until the full trust store is initialized automatically and passes regression testing.

## r210 — VLC Qt6 / Phonon VLC integration verified — 2026-08-28

- [x] **VLC 3.0.23 QT6 GUI BUILD AND RUNTIME — FIXED / VERIFIED.**
  - Updated the BFSOS VLC port from a GUI-less build to an explicitly enabled Qt interface using `--enable-qt` and the `qt6` dependency.
  - BFSOS Qt6 provides `qmake6` under `/opt/qt6/bin`; the package build environment did not initially expose that path, causing configure to report `qmake6: command not found`.
  - Fixed the VLC build environment by exporting `/opt/qt6/bin` in `PATH` and selecting `/opt/qt6/bin/qmake6` for the Qt build.
  - Removed the ineffective `pkgconf lua52` environment setup after it was observed to fail while the build continued; retained the required Lua 5.2 bytecode compiler selection.
  - VLC 3.0.23 subsequently built, installed, launched, and was functionally tested with its Qt6 GUI on the BFSOS VM.
  - Retain the BLFS GStreamer 1.28+ compatibility adjustment in the VLC recipe.

- [x] **FFMPEG 9.0.1 / VDPAU SUPPORT REQUIRED BY VLC — FIXED / VERIFIED.**
  - VLC exposed missing FFmpeg VDPAU symbols because the BFSOS FFmpeg build had headers for VDPAU APIs but was built without VDPAU support.
  - FFmpeg was rebuilt with `libvdpau` declared and `--enable-vdpau` enabled.
  - Verified FFmpeg reports `vdpau` in hardware accelerators and exports `av_vdpau_bind_context` and `av_vdpau_get_surface_parameters` from `libavcodec`.
  - VLC configure subsequently reports VDPAU decoding acceleration activated and the VLC build/install succeeds.

- [x] **PHONON-BACKEND-VLC QT6 INTEGRATION — VERIFIED.**
  - `phonon-backend-vlc` is installed and packages `/opt/kf6/lib/plugins/phonon4qt6_backend/phonon_vlc_qt6.so`.
  - Verified the backend links to `libphonon4qt6.so.4`, `libphonon4qt6experimental.so.4`, VLC libraries, and Qt6 Core/GUI/Widgets/DBus/Core5Compat libraries.
  - `ldd` reports no unresolved shared-library dependencies for `phonon_vlc_qt6.so`.
  - `/usr/bin/phononsettings` is present for functional Phonon configuration/testing.

- [x] **PLASMA META DEPENDENCY — PHONON VLC BACKEND PRESENT.**
  - Audit confirmed `phonon-backend-vlc` was already present in the committed `plasma-meta` dependency list before the attempted addition; do not duplicate it.
  - Keep exactly one `phonon-backend-vlc` dependency in `plasma-meta` so fresh Plasma dependency installs pull the Qt6 VLC Phonon backend automatically.
  - Bump `plasma-meta` release from 2 to 3 for the current metadata revision when committing the cleaned dependency line.

- [ ] **FOLLOW-UP — GLOBAL `/opt` BUILD-ENVIRONMENT AUDIT REMAINS OPEN.**
  - The VLC Qt6 failure is another concrete reproduction of the existing build-environment issue: an interactive shell can resolve `/opt/qt6/bin/qmake6` while builds invoked through `sudo` / `prt-get` / `pkgmk` may not inherit the required `/opt` tool paths.
  - Continue the existing global audit of `/etc/profile.d/*.sh`, sudo environment preservation, and explicit package build environment handling for Qt6/KF6 and other `/opt` prefixes.
  - Do not rely on the VLC-local PATH workaround as the final distro-wide solution.

- [ ] **REMAINING VLC REGRESSION COVERAGE.**
  - The primary Plasma VM Qt6 GUI launch/playback path is verified.
  - Still regression-test the VLC GUI on clean installs and under the other intended desktop/session combinations (especially XFCE and X11/Wayland combinations where supported) before closing the broader historical VLC GUI audit item completely.
