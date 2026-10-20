# BFSOS r484 Kernel Migration Tracker — 2026-10-15

## Implemented in r484 source

- [x] Add explicit migration preparation tool to kernel-maintenance package.
- [x] Backup pkgutils DB and legacy kernel metadata before any DB edit.
- [x] LTS pre-install supports migration only with preparation marker.
- [x] Mainline old `linux` 7.x identity safely relabelled as archival package.
- [x] Preserve old kernel images/modules/source and disallow silent removal.
- [x] Include offline mock pkgutils tests; existing kernel-maintenance tests pass.
- [x] Keep new BFSOS kernel release suffixes introduced by r483.

## Still to validate or implement

- [ ] Build/install `bfs-kernel-maintenance 1.0-5` in VM; reconcile `.footprint`.
- [ ] Verify LTS side-by-side install and pkgadd conflicts; boot BFSOS-LTS.
- [ ] Build/install mainline, including legacy 7.x VM migration and boot.
- [ ] Confirm Dracut, GRUB, RAID, LVM, rollback, and kernel flavor semantics.
- [ ] Implement robust post-validation cleanup of legacy package records.
- [ ] Implement tested automated rollback for interrupted migration.
- [ ] Validate next kernel upgrade after migration, then consider updater support.

**Safety:** Do not run `pkgrm linux-lts` or `pkgrm linux-legacy-mainline`
until explicit cleanup tooling and boot fallback tests are complete.

## NEW — High priority: `pkgmk` source-cache ownership regression

- [ ] **Fix source-cache ownership/permissions across `sudo pkgmk` and `prt-get` builds.**

**Observed on bare-metal BFSOS (2026-10-15):** After `sudo pkgmk -d -um` / direct `pkgmk` usage with `core/linux-mainline`, `/var/cache/pkg/sources/linux-mainline` was `root:root` mode `0755`, while its parent `/var/cache/pkg/sources` was `pkgmk:pkgmk` mode `0775`. Subsequently `sudo prt-get depinst linux-mainline` failed immediately with:

```text
ERROR: Directory '/var/cache/pkg/sources/linux-mainline' not writable.
BFSOS package timing: linux-mainline-7.2.10-4: 0s (status 3)
```

The local workaround was changing **only that source-cache directory** to `pkgmk:pkgmk` and mode `0775`. The exact code path that created or changed its ownership has **not yet been confirmed**.

**Required fix:**

- Identify which code path creates the per-port source directory as root and why direct `sudo pkgmk` and `prt-get` use incompatible write identities.
- Ensure `pkgmk`-managed source caches are consistently writable by the designated `pkgmk` build identity without unsafe world-writable directories or broad recursive ownership changes.
- Handle existing stale root-owned source-cache directories safely; validate path ownership and refuse unsafe paths/symlinks rather than blindly recursive-`chown`ing.
- Keep `.md5sum`, `.footprint`, download, build, and install flows consistent when run as root, via `sudo`, or via `prt-get`.
- Add regression tests: direct `sudo pkgmk -d -um`, `sudo pkgmk -d`, and `sudo prt-get depinst linux-mainline` in sequence; verify cache owner/mode and zero permission errors.
- Check whether a valid existing package is unnecessarily rebuilt by `prt-get` independently of the ownership failure; do not conflate package reuse with footprint generation.

**Status:** Open — reproduced and manually worked around; permanent implementation and automated tests pending.


## NEW — High priority: Kernel ports offered during routine full updater scan

- [ ] **Audit kernel detection and selection policy in the full port-update sweep.**

**Observed (2026-10-16):** The routine update-selection screen still reports `core/linux` `6.18.56 -> 6.18.57`, `core/linux-headers` `6.18.56 -> 6.18.57`, and `core/linux-mainline` `7.2.10 -> 7.2.11` after the r484 kernel identity/migration changes. All three were initially **OFF** (`[ ]`) and marked `REVIEW` in the screenshot. The issue is their continued appearance in this routine scan, **not** an observed automatic kernel installation.

**Investigation / acceptance criteria:**

- Confirm the intended policy: should routine full scans hide kernels, show but force explicit opt-in, or move them to a dedicated kernel-maintenance/update workflow? Implement the decided behavior consistently.
- Do not let toggling on or generic batch updating bypass `bfs-kernel-migrate` readiness, package identity safeguards, matching LTS headers, GRUB/initramfs checks, or existing known-good kernel retention.
- Test separately with `linux` (LTS), `linux-headers`, and optional `linux-mainline`, including full scan, selected update, fresh install, and post-migration machine.
- Verify no accidental rollback of user-selected kernel flavor or boot default.

**Status:** Open — routine-scan policy and safeguards need verification; screenshot does not show an unsafe install.

## NEW — High priority: Kernel-aware footprint verification and safe update sequencing

- [ ] **Fix routine updater rejection of valid versioned kernel payload changes while keeping strict protection against unexpected kernel file changes.**

**Observed (2026-10-16):** In the full updater results, `core/linux` (LTS 6.18.56 → 6.18.57) and `core/linux-mainline` (7.2.10 → 7.2.11) were built but **rolled back** with `FOOTPRINT REVIEW: payload changed beyond safe versioned-library refresh`. `core/linux-headers` was then rolled back/deferred with `LTS kernel not validated`, and `core/glibc` was deferred because the headers build did not succeed. User will update kernels and headers manually for now. **Do not interpret a successful compilation as an installed or boot-validated kernel.**

**Supporting evidence:** `logs/update/build-20261016-143649-core-linux.log` shows normal versioned paths changing from `boot/vmlinuz-6.18.56-BFSOS-LTS`, `boot/config-*`, `boot/System.map-*`, and `usr/src/linux-6.18.56-BFSOS-LTS/` to their `6.18.57-BFSOS-LTS` counterparts, along with an updated `boot/vmlinuz-lts` symlink. Tens of thousands of versioned source-tree files appear as `MISSING`/`NEW`, so generic footprint comparisons overstate a normal kernel-version transition.

**Investigation / acceptance criteria:**

- Add package-specific validation for `linux` (BFSOS LTS), `linux-mainline`, and `linux-headers`; normalize *known* kernel-version paths (e.g. `/boot` versioned images, `/lib/modules/<release>`, `/usr/src/linux-<release>`) during comparison, but reject unexpected additions/removals outside documented layouts, missing kernel essentials, file-type changes, or unsafe symlink targets.
- Keep `/boot/vmlinuz-lts` and other unversioned boot symlinks under explicit target verification; ensure the old known-good kernel remains bootable and no migration/ownership protections are bypassed.
- Separate expected `.footprint` version churn from genuine package payload changes; preserve proper regeneration/approval of footprints and hashes through the existing build tools.
- Handle the LTS sequence explicitly: successful kernel **build** is not boot validation. Define whether headers/glibc may proceed after verified package installation versus after successful reboot, and make the dependency reason accurate. Never automatically force glibc when headers are unvalidated.
- Review interaction with updater kernel-default OFF selection policy and the r484 kernel migration/rollback safeguards; ensure side-by-side LTS and mainline updates cannot overwrite each other's files.
- Add regression tests covering the 6.18.56 → 6.18.57 LTS path changes, 7.2.10 → 7.2.11 mainline path changes, malicious/unexpected payload differences, symlink validation, rollback, and headers/glibc deferral behavior.
- Test in VM first, including GRUB, dracut, installed package metadata, reboot, and known-good fallback, before permitting routine automatic kernel updates.

**Status:** Open — updater kernel-footprint false-positive strongly indicated; current user workaround is manual kernel/header updates with known-good boot entry retained. No update-code changes included in this tracker revision.

## NEW — Medium priority: Unexpected `sysklogd` update offered on systemd BFSOS

- [ ] **Audit whether `opt/sysklogd` belongs in the active routine updater selection.**

**Observed (2026-10-16):** The update-selection screen offers `opt/sysklogd` `2.7.2 -> 2.8.0` (`[ * ]`, marked `REVIEW`). BFSOS uses systemd/journald by default, so the reason for offering this traditional syslog daemon needs review. Its existence in the ports tree is not itself a defect: optional syslog daemons may be useful.

**Investigation / acceptance criteria:**

- Determine whether `sysklogd` is installed, intentionally optional, pulled in by a meta-package, or merely scanned because every port in the tree is included.
- Define whether routine updates should offer all ports, installed packages only, and/or explicitly enabled optional packages; ensure descriptions make this distinction clear.
- Keep `sysklogd` available as an optional port if desired, but do not enable/replace logging services or introduce conflicts with systemd-journald without explicit user choice.
- Verify selection defaults and update behavior under systemd on both host and VM.

**Status:** Open — unexpected selection; package/service conflict has not been demonstrated.

## NEW — Normal priority: Optional source prefetch for updater-selected ports

- [ ] **Investigate and implement an optional prefetch/download stage for selected updates, without modifying CRUX package manager behavior unless necessary.**

**Motivation (2026-10-16):** After a full scan, let the user download source archives for only the ports selected for updating before starting long builds (such as Chromium). Catch broken URLs earlier and take advantage of existing source caching.

**Research / implementation plan:**

- Ask CRUX developers on IRC whether an official source-prefetch workflow exists already, is supported by `pkgmk`, or is on their feature roadmap. Record the answer before implementing.
- Confirm behavior of installed `pkgmk` download-only options (`pkgmk -d` and related flags) against its actual help/manual; do not assume an option is universally supported.
- Prefer an **optional** updater action after the selection dialog, e.g. `Download selected sources`, using the existing `pkgmk` cache and build-user identity rather than inventing a parallel downloader or altering CRUX tools.
- Scope prefetch to user-selected ports; preserve OFF selections and kernel opt-in policy.
- Limit concurrent network requests, retries, and per-URL/overall time spent; report failed downloads without hanging the sweep.
- Reuse and validate cached sources when the subsequent build runs; test with Chromium and mixed remote/local sources.
- Test direct `pkgmk` and `prt-get` integration, particularly the separate `pkgmk` source-cache ownership regression above.

**Status:** Proposed enhancement — pending CRUX IRC feedback and current `pkgmk` capability check. No changes to pkgmk or updater have been made.


## NEW — Normal priority: Enable graphics-capable Fastfetch builds with text fallback

- [ ] **Audit the `opt/fastfetch` build configuration and add optional image-logo support.**

**Observed (2026-10-16):** Installed Fastfetch 2.70.0 prints `JsonConfig Error (logo.type): Image logo types are not supported because Fastfetch was built without image logo support` when invoked without arguments. The existing user-level `~/.config/fastfetch/config.jsonc` requests a PNG via `"type": "kitty"`. The distro-supplied `/usr/share/fastfetch/bfsos/config.jsonc` with its text-file BFSOS logo works when invoked explicitly. `fastfetch --list-features` does not report image support.

**Implementation / acceptance criteria:**

- Inspect Fastfetch 2.70.0 CMake options and available system libraries, identify and enable the supported image-logo backend(s) in the BFSOS port; do not invent CMake flags.
- Add appropriate declared dependencies and test on a compatible terminal with `kitty`-style image output; verify behavior in non-graphics terminals.
- Preserve the distro ASCII/text BFSOS branding configuration as a reliable default/fallback for live ISO, SSH, consoles, and minimal systems.
- Verify both `fastfetch --config /usr/share/fastfetch/bfsos/config.jsonc` and a user-configured PNG logo; provide graceful behavior when a terminal cannot render images.
- Bump port release, regenerate package metadata and test normal `prt-get` installation after the implementation is verified.

**Status:** Open — enhancement requested; current binary is functional with BFSOS text branding, but not user PNG image logos.

## NEW — Normal priority: Run BFSOS Fastfetch welcome screen for all interactive Bash users

- [ ] **Fix system-wide Bash initialization so the installed Fastfetch welcome hook runs in new interactive terminals, without per-user `.bashrc` edits.**

**Observed (2026-10-16):** `aaa_filesystem` installs `/etc/profile.d/bfsos-fastfetch.sh`, and the source-tree `ports/core/aaa_filesystem/bashrc` references it; however, `grep -n bfsos-fastfetch /etc/bash.bashrc /etc/bashrc ~/.bashrc` found no active hook on the installed system. New Konsole terminals did not display the BFSOS Fastfetch welcome screen. Adding a source command to `~/.bashrc` resolved the issue. The hook intentionally exits in noninteractive shells; `bash -c 'source ...'` producing no output is expected. The distro text-logo configuration works when invoked explicitly.

**Investigation / acceptance criteria:**

- Inspect the `aaa_filesystem` packaging and the Bash startup paths actually read by BFSOS (`/etc/bashrc`, `/etc/bash.bashrc`, `/etc/profile`, and any relevant Bash patches/configuration); identify why the project's `bashrc` hook isn't active on installed systems.
- Install/source the existing `/etc/profile.d/bfsos-fastfetch.sh` via the correct system-wide interactive Bash startup path; don't modify users' dotfiles or append duplicate hooks.
- Ensure Fastfetch runs once for each new interactive terminal where appropriate, but remains silent for noninteractive scripts, pipelines, remote commands, and dumb/non-TTY sessions; honor `BFSOS_NO_FETCH=1`.
- Retain the known-working `/usr/share/fastfetch/bfsos/config.jsonc` ASCII/text branding independent of the separate graphics-support enhancement.
- Test fresh ISO install and upgrade, normal user and root, login/non-login interactive shells and Konsole; bump `aaa_filesystem` release and regenerate metadata when verified.

**Status:** Open — manual user-level `.bashrc` workaround tested successfully; global package fix pending.

## NEW — Normal priority: Investigate six remaining UNVERIFIABLE ports in updater full scan

- [ ] **Audit the six ports from `problems-20261016-142933.tsv` individually; distinguish retired Plasma components from upstream version-provider gaps.**

**Observed (2026-10-16):** Latest full scan finished with `UNVERIFIABLE=6`, `FETCH-ERROR=0`, `ERROR=0`. The six remaining entries are:

| Port | Current version | Reported issue |
| --- | --- | --- |
| `compat-32/libnewt-32` | `0.52.25` | Directory provider does not contain current version; current source reachable. |
| `opt/libosinfo` | `1.12.0` | Directory provider does not contain current version; current source reachable in latest scan. Earlier scan reported a source URL 404. |
| `opt/rustc` | `1.99.0` | Rust stable provider does not contain current version; current source reachable. |
| `opt/sgml-common` | `0.6.3` | Directory provider does not contain current version; current FTP source reachable. |
| `plasma/kgamma` | `6.7.5` | Package not found in newest compatible KDE Plasma release directory; current source reachable. |
| `plasma/kwin-x11` | `6.7.5` | Package not found in newest compatible KDE Plasma release directory; current source reachable. |

**Required investigation:**

- For `kgamma` and `kwin-x11`, review whether Plasma 6.8 has replaced, merged, renamed, or retired these components. Remove/retire obsolete ports and meta-package references **only after** verifying the current Plasma stack and actual installed dependencies. Do not force-update these against nonexistent release tarballs.
- For `libnewt-32`, compare its provider logic with native `newt` and ensure 32-bit ports use matching valid source/version discovery.
- For `libosinfo`, verify the maintained upstream source and release listing; address inconsistency between the earlier URL 404 and the latest `source reachable` result.
- For `rustc`, verify stable-release parsing (including source tarball naming/version) and why the current stable-version provider omits `1.99.0`. Avoid flagging a reachable existing source as failed solely because provider discovery is incomplete.
- For `sgml-common`, verify old FTP release location and determine whether a modern authoritative version source exists; classify genuinely unmaintained ports separately from transient network failures.
- Add provider-specific regression tests and ensure end-of-scan reports display each remaining `UNVERIFIABLE` package and reason clearly.
- Do not classify the older Xorg/freedesktop timeouts as part of **this** six-port list; those were present in older problem reports, not in `problems-20261016-142933.tsv`.

**Status:** Open — audit only; no port/version changes yet.

## NEW — Normal priority: Reset port release to 1 on upstream version bumps

- [ ] **Fix the BFSOS updater so an accepted `version=` change always resets `release=1` in the port Pkgfile.**

**Expected behavior:** If an update changes `version=OLD` to `version=NEW`, reset any existing `release=N` to `release=1` (including native and `-32` ports). Do not carry a previous version's local rebuild count into a new upstream release. If `version=` is unchanged, preserve its existing release unless an explicit revision-only update is requested.

**Acceptance criteria:**

- Apply reset during the updater's actual Pkgfile update path (not just the candidate preview), including batch updates and fallback/provider flows.
- Preserve `release=1` for a newly updated version even when previous release was already 1; do not modify an unselected/skipped port.
- Ensure package filenames, update UI (old/new version and release), reports, and build/install actions reflect the reset release.
- Add tests for `1.2.3 r7 → 1.2.4 r1`, `1.2.3 r1 → 1.2.4 r1`, and unchanged-version or skipped updates remaining untouched.
- Ensure the rule is applied consistently for native and compat-32 ports, without changing pkgmk/prt-get itself.

**Status:** Open — tracker item only; implementation pending.


## r493 — Source-audit and implementation pass (2026-10-16)

**Scope warning:** This is a partial implementation pass, not closure of every tracker item. The earlier consolidated `docs/BFSOS-fix-tracker-r480-20261015.md` alone contains 384 unchecked boxes and 7 partial items; r492 adds the more recent kernel/updater/desktop work. All prior tracker contents remain preserved. No live BFSOS host, VM, full kernel compilation or ISO boot test was available in this offline session.

### Implemented in source; pending live package validation

- [~] `office/libreoffice-bin`: remove dependency on nonexistent `rpm2cpio` package and use `libarchive`'s `bsdtar` for direct RPM extraction. Added RPM listing/read checks and path-traversal rejection. Bumped port release 1→2. **Pending** real RPM extraction, complete `/opt` payload audit, launcher/menu co-installation tests, and metadata regeneration.
- [~] `opt/fastfetch`: enable upstream-supported `ENABLE_IMAGE_LOGO=ON`; depend on ImageMagick, Ninja and CMake; bump release 1→2. **Pending** build, `--list-features`, Kitty PNG display, fallback/SSH tests, and metadata regeneration.
- [~] Global Fastfetch startup: `core/bash` now requests upstream system bashrc support (`--enable-system-bashrc=/etc/bashrc`) to connect interactive non-login shells to the existing `aaa_filesystem` hook; bump release 1→2. **Pending** configure flag/build verification and real Konsole/SSH/new-user testing.
- [~] `pkgutils`: change `bfs-pkgmk` to create or correct only its immediate per-port source cache directory when directly invoked as root, never following directory symlinks or doing recursive chmod/chown. Bump pkgutils release 46→47. **Pending** root/pkgmk user tests and permission edge cases.
- [~] New-version release reset: existing maintained updater already handled default reset; hardened `rewrite_version_release` so an incoming stale/candidate `new_release` cannot override a version-change reset. **Offline regression tests PASS**, including same-version revision preservation. Still pending end-to-end updater selection/build tests.

### Assessed; not implemented or closed

- [ ] LTS/mainline kernel footprint verification + headers/glibc sequencing: remains high-priority and **unchanged**. Must test in VM before changing boot/rollback paths.
- [ ] Kernel migrations, pending-boot protection and legacy kernel cleanup: unchanged pending VM verification. Never remove archived kernels without a verified safe rollback.
- [ ] Scan kernel selection policy: full scan already sets OFF/REVIEW; whether kernels should be hidden is a product decision, not a defect proven by the screenshot.
- [ ] Optional prefetch: awaiting CRUX IRC response; do not change pkgmk architecture speculatively.
- [ ] `sysklogd`: audit installation/dependency policy; cannot infer from a full-tree scan that it is installed or incorrectly enabled.
- [ ] Six unverifiable ports (`libnewt-32`, `libosinfo`, `rustc`, `sgml-common`, `kgamma`, `kwin-x11`): require live provider tests and current Plasma 6.8 transition audit. Do not delete ports based only on missing upstream listings.
- [ ] LibreOffice source variant, desktop launchers, Brother printer/CUPS and the longer historical backlog require dedicated build/run tests. **Not claimed fixed.**

**Offline tests executed:** `scripts/tests/test-r493-targeted-fixes.py`, `scripts/tests/test-r470-fastfetch.py`, `scripts/tests/test-r436-office-printer.sh`; Bash syntax checks and maintained-updater Python compile all passed.

**Package metadata caution:** Updated `Pkgfile` releases require fresh `.footprint`/`.md5sum` generated from actual builds. Existing metadata was not invented or regenerated in this environment. Do not force-install or blanket-bypass footprint checks.

## r494 — HIGH priority: Dedicated pkgmk workspace ownership and cleanup (2026-10-18)

- [ ] **Fix `ports/core/pkgutils` (`bfs-pkgmk` / `pkgmk`) so unprivileged builds can reliably clean their own staging trees and do not retain build-work by default.**

**Observed on bare-metal BFSOS:** Rebuilding `office/libreoffice-bin` under the dedicated `pkgmk` user failed during removal of the prior `/var/cache/pkg/build-work/pkgmk-libreoffice-bin/pkg/opt/libreoffice26.8/...` RPM-extracted payload with hundreds of `Permission denied` errors. The earlier `pkgutils 5.40.12-47` change addressed ownership of `/var/cache/pkg/sources/<port>`; this exposes a separate *build-work* ownership/cleanup issue. Root cause within the wrapper/extraction/cleanup sequence still needs investigation.

**Required behavior:**

- [ ] Privileged `bfs-pkgmk` prepares the exact per-port workspace and handles cleanup at the privilege boundary, while compilation/extraction/build execution remains under dedicated unprivileged `pkgmk`.
- [ ] On starting a new build, resolve stale workspace permissions safely: prefer privileged cleanup and recreation when prior work was not explicitly retained; if a retained workspace must be reused, correct its ownership/permissions deliberately (for example `chown -R pkgmk:pkgmk` within a validated boundary), not globally.
- [ ] **Default:** remove the temporary package-specific `build-work/pkgmk-<port>` tree on both successful and failed builds; do **not** preserve builds by default or silently preserve them on failure.
- [ ] **Explicit `-kw` only:** preserve the build workspace for inspection; ensure `-kw` reaches the effective `pkgmk` invocation through `bfs-pkgmk`, `sudo pkgmk`, and `prt-get` as applicable. Document any conflicts with existing pkgmk configuration and flag semantics.
- [ ] Never delete `/var/cache/pkg/sources`, `/var/cache/pkg/packages`, shared ccache, or other ports' active workspaces. Handle both regular build-work and `build_work=disk` modes.
- [ ] Before privileged recursive removal, canonicalize and validate the workspace path against configured build-work root; reject symlink escapes, unexpected mount points, empty/unset variables, and unsafe paths. Do not give the unprivileged account unrestricted `sudo rm` or `chown` rights.
- [ ] Ensure concurrent builds and interrupted builds cannot delete each other's active workspace; make cleanup failures explicit and actionable.

**Acceptance tests:**

- [ ] Normal successful build removes its workspace.
- [ ] Normal failed build removes its workspace, while logging the actual failure.
- [ ] `pkgmk -kw` retains the work tree and contents for debugging.
- [ ] Subsequent normal build after a `-kw` retained extraction with restrictive/root-owned directories works without permission errors.
- [ ] Test direct `pkgmk`, `sudo pkgmk`, and `prt-get depinst/update`; verify active builds and caches are unaffected.
- [ ] Reproduce and resolve the real `libreoffice-bin` RPM payload cleanup failure, including restrictive nested directories.

**Status:** Open — tracker only; no implementation or runtime regression test claimed.

## r495 — source work and test results (2026-10-20)

- [~] NVIDIA/32-bit handoff: accept `.run` installer archives and preserve version-coupled sources; new offline regression PASS. **Live NVIDIA installation and GLFS DEV end-to-end check remain open.**
- [~] Footprint mismatch updater: expand automatic, safety-gated update for ordinary files/dirs/symlinks, excluding kernels and suspicious payload. Eight logged Oct 18 mismatches now qualify for automated review + `-if`/`-uf` workflow in an offline classification run. **Live package creation, installation, and safety validation still needed.**
- [x] Add `test-r495-updater-footprints-nvidia.py` with malicious path, ownership, mode and symlink negative cases; PASS offline.
- [ ] Reconcile outdated test expectations for global Bash initialization and update-selection policy, uncovered by full project regression pass.
- [ ] Work through remaining open historical tracker items (prior trackers contain hundreds), including pkgmk dedicated workspace cleanup and protected kernel upgrades. No claims of completion of these items.

Detailed findings: `docs/BFSOS-r495-offline-audit-20261020.md`.


## r496 — HIGH priority: Single-pass footprint refresh and conditional build-work cleanup (2026-10-20)

- [ ] **Implement an updater-controlled, single-build package update workflow with automatic `.footprint` regeneration and outcome-based workspace retention.**

**Maintainer decision (supersedes r494 cleanup-on-failure policy for updater-managed builds):** For a selected upstream version update, update the `.footprint` as part of packaging; **successful update = delete that port's build-work, failed update = preserve that port's build-work**, even when `-kw` was not explicitly requested by the maintainer. The old r494 instructions to delete failed work and preserve only for user-supplied `-kw` remain historical; follow this r496 policy for updater operations.

**Required implementation:**

- [ ] Update selected port `version=` and reset `release=1` on upstream version changes; do not touch unselected ports.
- [ ] Use the BFSOS `pkgmk` implementation to determine exactly what `-uf`, `-kw`, and any packaging-only/reuse mode do. Avoid redundant `pkgmk -d -if -kw` plus `pkgmk -d -uf -kw` sequences that repeat compilation. Prefer one build and a footprint refresh at the proper packaging stage; do not assert that `pkgmk -uf` is packaging-only without checking its actual behavior.
- [ ] While running an updater-managed package attempt, retain the per-port staging/work tree until all build, footprint generation, package validation and applicable transaction checks have finished. One proposed invocation is `pkgmk -uf -kw`, **subject to verified BFSOS flag semantics**; never claim it avoids recompilation until tested.
- [ ] On full package-update success, safely clean **only** that package's validated build-work directory; on **any** build, footprint, packaging, validation or apply failure, preserve its work tree and report its exact location and failure reason. Explicit maintainer `-kw` must override automatic cleanup and preserve work even after success.
- [ ] Keep safety checks for unexpected installation paths, unsafe symlinks, abnormal ownership/modes and cross-package file conflicts; a regenerated footprint must not automatically approve dangerous payloads. Maintain special kernel safeguards and versioned-kernel/boot-entry checks.
- [ ] Ensure privileged cleanup handles restrictive directories from RPM extraction (e.g. `libreoffice-bin`) without chowning caches or allowing symlink/mount traversal; lock per-port work trees to avoid concurrent cleanup. Do not remove `/var/cache/pkg/sources`, `/var/cache/pkg/packages`, shared ccache or another port's workspace.
- [ ] Preserve correct rollback of Pkgfile/metadata on actual failures without deleting failed-work evidence, and clearly distinguish compile, footprint, package, and apply outcomes in scan reports.

**Acceptance tests:**

- [ ] Version update with changed ordinary files produces a valid updated `.footprint` and package without a second full compile; instrument `pkg_build()` invocation count.
- [ ] Successful update removes only its work tree; failed compilation, footprint regeneration, package validation, or apply retains work with actionable logs.
- [ ] Explicit `-kw` keeps work on success; ordinary direct `pkgmk`, `sudo pkgmk`, and `prt-get` behavior remains intentional and documented.
- [ ] Test root-owned/restrictive LibreOffice RPM staging, `build_work=disk`, concurrent builds, symlink/mount escapes and interrupted runs.
- [ ] Existing NVIDIA/32 coordinated update safety, kernel opt-in/boot protections, and suspicious-footprint rejection continue to pass.

**Status:** NEW / OPEN — tracker updated only. No r496 source implementation or live test is claimed.
