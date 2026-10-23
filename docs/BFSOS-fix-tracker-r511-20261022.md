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


## r497 — HIGH priority: Synchronize GRUB and GRUB-EFI upstream version detection (2026-10-20)

- [ ] **When the BFSOS updater discovers a new upstream GRUB version for `core/grub`, also detect and offer that same upstream version for `core/grub-efi`.** Treat them as distinct ports with a shared upstream release, not as the same installed package.

**Observed:** The updater offered `core/grub` 2.14 → 2.16 (from MLFS DEV), but did not offer `core/grub-efi` even though both ports use the upstream GRUB source. Separately, the GRUB 2.16 candidate was blocked because rewriting the old GNU mirror URL produced an HTTP 404. Neither issue proves a compilation failure.

**Required implementation:**

- [ ] Map both `core/grub` and `core/grub-efi` to the authoritative upstream GRUB version from the applicable MLFS DEV book; check each Pkgfile independently and display both in update selection and reports if outdated.
- [ ] Honor the actual upstream source URL for the target GRUB release instead of assuming older `ftpmirror.gnu.org` URL patterns remain valid; validate downloads and checksums.
- [ ] Keep `grub` (BIOS) and `grub-efi` (UEFI) Pkgfiles, build options, patches, package names and footprints separate. Do not copy one variant's build configuration onto the other.
- [ ] Reset `release=1` when either port's upstream `version=` changes, while preserving unrelated local revisions when the version is unchanged.
- [ ] Offer both variants without silently enabling or installing both; preserve explicit selection, separate rollback states, and report if one variant remains outdated or fails validation.
- [ ] Never automatically run `grub-install`, modify EFI NVRAM entries or overwrite an active bootloader merely because a package update was detected.

**Acceptance tests:**

- [ ] Mock shared upstream release 2.16 with both ports at 2.14: both appear as independent update candidates.
- [ ] If one port is already 2.16, only the outdated variant is offered; if one is intentionally unselected, its files remain untouched.
- [ ] Test release-specific source URLs, missing/404 URLs, footprint regeneration, version reset, independent failure/rollback and safe bootloader non-installation.
- [ ] Build both variants in a BFSOS VM and validate BIOS/UEFI boot paths before releasing the update.

**Status:** NEW / OPEN — tracker only; no code changes or boot tests claimed.


## r498 — HIGH priority: Resume interrupted full bootstrap from failed stage (2026-10-20)

- [ ] **Implement safe, checkpoint-based continuation of a full BFSOS bootstrap without starting again at Stage 1 or requiring the maintainer to select every remaining stage manually.**

**Observed:** On 2026-10-20, the full bootstrap successfully completed Stage 1 after the `core/libarchive` 3.8.10 bootstrap `--without-expat` fix. Stage 2 later stopped on `core/expat` 2.9.0 with an MD5 checksum mismatch (`.md5sum` apparently still held the 2.8.5 value). Restarting *Full Bootstrap* invokes a clean start, wiping expensive completed toolchain work; manually selecting stages 2, 3, 4 and 5 is the current workaround.

**Required implementation:**

- [ ] Add **Resume Full Bootstrap** to the existing menu/CLI, preserving the original selected full-bootstrap sequence (stages 1 through 5) and continuing automatically from the last incomplete stage after a failure.
- [ ] Persist durable, atomic per-stage completion/checkpoint metadata containing stage, input versions/configuration, toolchain/rootfs identifiers and necessary outputs; verify files and toolchain integrity before deciding to skip a completed stage. Do not treat the most recently printed package or a lone exit code as sufficient proof.
- [ ] For interrupted Stage 2 and other restartable stages, detect whether the failing package can be retried without discarding previously built/installed, verified packages. Revalidate partial installations and affected dependencies; restart the failed stage when package-level resume is unsafe.
- [ ] Preserve downloaded source archives, completed stage artifacts, package caches, and diagnostic logs; do not invoke Stage 1's `_clean_start` on the resume path. Maintain the existing **Full Bootstrap / Clean Start** action as an explicit separate option with a clear destructive warning.
- [ ] Present the detected previous run, last verified checkpoint, failed stage/package and planned continuation in the menu; ask for confirmation before resuming and report each stage's state accurately.
- [ ] Invalidate/rebuild affected checkpoints when ports, checksums, patches, build configuration, toolchain binaries, or rootfs state changed incompatibly. Never silently reuse an inconsistent sysroot or skip a required stage.
- [ ] Keep robust logs and status reporting on retry; after successful recovery, automatically proceed through remaining requested stages, including verification and base archive creation.
- [ ] Use explicit locks and atomic state updates so interrupted processes or concurrent bootstrap runs cannot mark an incomplete stage successful.

**Acceptance tests:**

- [ ] Simulate Stage 2 checksum failure after a valid Stage 1: correct the checksum and choose Resume; Stage 1 is not rebuilt, Stage 2 retries safely, and later stages continue automatically.
- [ ] Interrupt midway through another stage: validate checkpoints, preserve completed work and show the exact restart plan.
- [ ] Corrupt or remove required toolchain/rootfs artifacts: resume refuses unsafe reuse and explains which stage must be rebuilt.
- [ ] Change a dependency or build option that invalidates a checkpoint: resume rebuilds affected stages rather than silently skipping them.
- [ ] Full Bootstrap / Clean Start still performs its intentional clean rebuild, distinctly from Resume.

**Status:** NEW / OPEN — tracker updated only. No bootstrap code change or resume test claimed.


## r498 — HIGH priority: Checksum regeneration and version-coupling in port updater (2026-10-20)

- [ ] **Prevent the updater from committing a new `version=` with an obsolete `.md5sum`.**

**Observed:** `core/expat` was updated from 2.8.5 to 2.9.0, but its old MD5 checksum apparently remained. Stage 2 `pkgmk` correctly rejected the 2.9.0 source with a checksum mismatch. Verify the exact updater code path responsible before attributing the regression.

**Required implementation:**

- [ ] For each selected version change, download the *exact* new source artifacts, validate expected filenames/URLs, and verify authenticity against authoritative upstream checksums/signatures where available before regenerating BFSOS `.md5sum`.
- [ ] Update Pkgfile version/source URL, checksums and relevant source-dependent patches/metadata as one validated transaction; refuse to mark an update successful or publish it if the new archive and checksum disagree.
- [ ] Never blindly bless an existing or corrupted cache file by recomputing its checksum; distinguish stale checksums, incomplete/corrupt downloads and upstream artifact substitutions.
- [ ] Preserve older metadata and report a clear error when source validation fails, including package, old/new version, and source path; do not silently leave an inconsistent version/checksum pair.
- [ ] Cover one-source and multi-source ports; preserve appropriate `SKIP` handling for local files and legitimate non-hashed entries according to BFSOS pkgmk semantics.

**Acceptance tests:**

- [ ] Mock Expat 2.8.5 → 2.9.0: stale checksum is detected and corrected only after validating the new source.
- [ ] Wrong archive, truncated download, redirected 404/HTML payload, mirror mismatch and multi-source ports fail safely with actionable diagnostics.
- [ ] Unselected ports and failed updates leave original Pkgfile/checksum files unchanged.

**Status:** NEW / OPEN — tracker only; no updater fix or live test claimed.

## r499 — HIGH priority: Explain and minimize unexpected ISO dependencies (2026-10-20)

- [ ] **Audit why the ISO assembly/package-install phase pulls in unexpected audio/multimedia packages, observed examples `alsa-lib` and `lame`, and determine whether they are needed in the live ISO, only at build time, or neither.**

**Observed:** During the BFSOS 1.0-rc1 ISO test build the maintainer saw audio packages being pulled, including `alsa-lib` and `lame`; the `lame` build reportedly failed. The precise parent dependency and LAME failure are **not yet confirmed**. `alsa-lib` may be legitimately needed for ALSA/PipeWire or the working MSI Godlike optical-audio setup; do not indiscriminately remove audio components.

**Required investigation / implementation:**

- [ ] Trace each chosen ISO package to an explicit seed, dependency edge, package group, profile, or builder default; distinguish build-only dependencies from packages ultimately present in the live filesystem and installed base.
- [ ] Generate a reproducible inclusion report (`package`, `selected-by`, `dependency-chain`, `build-only/live/installed`, `estimated package/payload size`) and report the first parent that pulls in `lame`.
- [ ] Audit ISO package lists, full dependency closure, optional-vs-required dependency handling, and inclusion of multimedia groups that aren't needed for a minimal installer/live session.
- [ ] Inspect LAME's failing log, build flags and true dependency chain; fix a genuine required-port build defect, but avoid including LAME merely to silence the error if no legitimate runtime requirement exists.
- [ ] Maintain required installer/live features, including ALSA/PipeWire paths and the MSI X870E Godlike optical S/PDIF UCM fix; verify actual live audio functionality in a VM or on suitable hardware.
- [ ] Make optional packages explicit and opt-in where appropriate; preserve package closure and avoid breaking other desktop profiles that actually need audio codecs.
- [ ] Report ISO size by package/group and compare against the less-than-2-GB project goal; do not delete required components to meet the target.

**Acceptance tests:** ISO dependency graph is deterministic and understandable, unexpected packages have a defensible origin or are removed, LAME failure is diagnosed, audio/installer smoke tests pass, and ISO contents/size are reported.

**Status:** NEW / OPEN — observed behavior only; no package manifest or LAME build log reviewed for this entry.

## r499 — CRITICAL priority: Prevent false-success pkgmk builds and invalid bootstrap/base packages (2026-10-20)

- [ ] **Make `pkgmk`/bootstrap fail closed if `pkg_build()` or a mandatory `configure`, `make`, or `make install` stage fails, even when subsequent commands succeed.**

**Observed:** In `logs/base/rsync-20261021-023732.log`, rsync 3.5.1 `configure.sh` aborted (`idn2.h` not found); `make` and `make install` then failed, but the Pkgfile continued to install configuration/service/driver files. The Stage 3 wrapper printed `Building ... succeeded`, `Stage 3: reinstalling exact rebuilt package ...`, and `Exit status: 0`. Another observed package archive with the same version subsequently contained `usr/bin/rsync`; that does **not** prove the specific failed-build artifact was healthy. Track logs, timestamps and checksums to distinguish attempts before concluding what landed in the base.

**Required implementation:**

- [ ] Inspect actual `pkgmk` shell execution and `pkg_build()` contract, including error propagation in functions, pipelines/subshells and `set -e` contexts. Make a failing mandatory phase propagate nonzero status to `pkgmk` and the bootstrap supervisor; don't rely solely on maintainers remembering `|| return 1` in each Pkgfile.
- [ ] Reject partial/empty payloads: verify required binaries/libraries for key base packages (e.g. `rsync` must contain an executable `usr/bin/rsync`); validate footprint against payload and package manifest before accepting, caching, installing, or archiving.
- [ ] Do not mark a bootstrap stage successful, write success checkpoints, or publish a verified base/ISO when required packages failed. Capture per-package source revision, build command, exit codes, artifact path/hash and final installed-package result.
- [ ] Preserve diagnostic logs and optionally failed build-work for inspection; honor existing explicit `-kw` and r496 updater-managed failure-retention decisions.
- [ ] Audit the existing 1.0-rc1 base archive generated `2026-10-20` and verify the installed `/usr/bin/rsync` and package metadata in that base *before* treating it as releasable. Do not infer the archive is invalid solely from a log of a possibly separate attempt.
- [ ] Avoid unconditional global `set -e` changes that accidentally alter successful port hooks; test Bash semantics and both bootstrap and ordinary `prt-get`/`pkgmk` paths.

**Acceptance tests:** Force `./configure` failure followed by a successful `install -m` command; overall build must fail with no published package and no successful stage marker. Cover failure in `make`, `make install`, missing binary, stale cache reuse, separate retry success, concurrent logging, and normal valid builds.

**Status:** NEW / OPEN — fix to rsync port was locally tested; generic build-engine safeguards remain unimplemented/unverified.

## r499 — HIGH priority: Resolve rsync 3.5.1 IDN dependency policy in clean bootstrap (2026-10-20)

- [ ] **Decide explicitly whether base `rsync` should build with `libidn2` support or use `--disable-idn`, and keep the clean-bootstrap dependency graph consistent with that decision.**

**Observed:** On the installed host, `rsync --version` reported `IDN`; fresh Stage 3 configure aborted because `idn2.h` was unavailable. A revised port with `--disable-idn` built successfully with unchanged footprint according to maintainer; it has been synced/pulled between BFSOS trees. This is consistent with a difference in build environments, not proof that upstream *newly* made `libidn2` a mandatory dependency.

**Required investigation / implementation:**

- [ ] Compare host and Stage 3 rsync configure results and installed headers/libraries; check `libidn2` availability and actual declared dependency order.
- [ ] If IDN is desired, declare and bootstrap `libidn2` ahead of `rsync`, remove `--disable-idn` and test fresh sysroot builds; otherwise retain explicit disabling and document the reduced feature set.
- [ ] Verify `rsync --version`, binary contents and file footprint in a clean build and in the resulting base archive.

**Status:** NEW / OPEN — workaround builds; final IDN feature/dependency policy awaits verification.


## r500 — Dependency closure audit and targeted source changes (2026-10-20)

- [x] **Identify concrete unexpected ISO package chain:** `fastfetch → imagemagick → ffmpeg → lame` and `fastfetch → imagemagick → ffmpeg → alsa-lib` via the declared `# Depends on:` metadata. ISO explicitly seeds `fastfetch`. This explains a route to the unwanted packages; other independent paths may exist after choosing additional desktop profiles.
- [x] **Source change (offline):** Make `imagemagick` optional in `opt/fastfetch`; select Fastfetch image-logo compilation only if ImageMagick command and development pkg-config metadata are present; otherwise retain the already packaged BFSOS text-logo fallback. Bump port release 2→3. Optional image-logo functionality on an ImageMagick-equipped host still requires a real build and smoke test.
- [x] **Source change (offline):** Make `opt/lame` fail immediately on configure/make/install errors, bump release 2→3. This does **not** resolve the LAME build failure, which cannot be diagnosed because no LAME build log was included in the uploaded archive.
- [x] **Offline graph regression:** Add `scripts/tests/test-r500-iso-deps.py`; verifies the current mandatory ISO closure excludes `lame`, `ffmpeg`, `imagemagick` and that Fastfetch retains optional image-logo support. Declared closure decreased **378 → 122** unique reachable names with the same seed set. This count does not predict the final ISO compressed bytes or include preinstalled base packages/extra resolution beyond declared edges.
- [x] `bash -n` for both modified Pkgfiles; `test-r500-iso-deps.py` PASS; `test-r470-fastfetch.py` PASS.
- [ ] **Live test / packaging:** Build both ports on BFSOS (prefer `pkgmk -kw`), regenerate/review correct `.footprint` and source sums only as needed, run normal `prt-get` install, test console Fastfetch and Kitty image-mode optional feature. Create fresh minimal ISO, inspect installed package set/size, verify audio UCM and installer. Do not distribute archive solely on offline checks.
- [ ] **ISO build-only dependency policy:** `scripts/bfs-build-iso.sh` explicitly installs `gobject-introspection` separately and runs `prt-get -if -is sysup` before ISO seeds. Audit whether those phases still pull extra packages, and whether `-if -is` integrity bypasses are justified. Avoid broad removal without runtime validation.
- [ ] **Generic pkgmk false-success fix:** The log demonstrates rsync's failed configure was followed by failed make/install and then success reported, with `-if -is` integrity bypass active; a full fix needs pkgutils build-engine inspection, generated pkgmk tests, and integration testing. This overlay does not claim to fix global pkgmk failure semantics.
- [ ] **Earlier r493 test drift:** `test-r493-targeted-fixes.py` remains failing at the pre-existing expectation that core Bash has `--enable-system-bashrc=/etc/bashrc`. This is unrelated to the dependency-chain change and has not been adjusted or claimed passed.
- [ ] **Historical backlog:** All other unresolved r484–r499 tracker work remains open and unchanged, including critical kernel migration/rollback safety, updater, package workspace cleanup, and VM-only checks. The submitted snapshot does not enable reliable end-to-end execution of every historical issue.

**Artifact status:** targeted source overlay and documentation, not a complete release-ready fix; no user host/VM/live ISO actions performed.

## r501 — CRITICAL: Installer hangs in fakeroot IPC during cpio configure (2026-10-22)

- [ ] **Fix the BFSOS installer/chroot package-build path so `prt-get depinst` cannot hang indefinitely inside `fakeroot`; audit and complete the planned transition away from fakeroot for compile/configure work while preserving correct package archive metadata.**

**Observed in BFSOS 1.0-rc1 UEFI VM installation, ISO commit `dd02505097b4`:**

- Installer process chain: `install-bfs-menu-current.sh` → `/root/.bfs-install-chroot.sh` → `prt-get.real -if -is depinst linux networkmanager sudo wget wpa_supplicant wireless_tools gpm lynx links parted snapper` → `bfs-pkgmk -d -if -is` → `runuser -u pkgmk ... fakeroot -- pkgmk -d -if -is` → `cpio` `./configure` → `./conftest`.
- After more than ten minutes, `conftest` (PID 40677 in that one run) was sleeping in `do_msgsnd`; `/proc/40677/syscall` began `69 0x12 ...` (x86_64 `msgsnd`, queue ID 18).
- `ipcs -q` showed pkgmk-owned queues 18 and 19, each holding **16,380 bytes / 15 messages**. This strongly suggests a saturated SysV IPC message queue associated with fakeroot, but the actual mechanism/root cause needs verification. No compiler was running because the configure test had not completed.
- Maintainer reports similar behavior in a previous installation. Current live installer demonstrably still invokes fakeroot, despite prior discussions about moving away from it.

**Implementation / investigation:**

- [ ] Trace fakeroot usage across installer, chroot script, `prt-get`, `bfs-pkgmk`, `pkgmk`, `pkgutils`, and bootstrap stages; confirm which package ownership/permission features actually require emulation.
- [ ] Examine `ipcs -l`, `/proc/sys/kernel/msgmnb`, faked processes, the SysV queue protocol, blocked `conftest` call, configure logs and exact queue lifecycle. Distinguish a fakeroot IPC issue from a genuine cpio configure bug.
- [ ] Keep unprivileged package compilation and configuration separate from ownership-sensitive package creation where practical, with verified root ownership/mode/symlink metadata in resulting archives. **Do not simply remove fakeroot or run arbitrary Pkgfiles as root.** If a scoped fakeroot step remains necessary, prevent indefinite IPC blocking and clean up only queues belonging to that build.
- [ ] Add bounded failure detection, clear per-port installer diagnostics, failed-work preservation and safe retry/resume, without corrupting the installed target. Reconcile workspace behavior with r494/r496.
- [ ] Ensure release ISO and target chroot actually use the fixed wrapper; remove any stale copied bootstrap/installer invocation path. Document intended privilege/packaging model.

**Acceptance tests:**

- [ ] Reproduce and resolve the `cpio` configure/`conftest` stall in a clean UEFI VM; record full installer log, process tree, IPC state and relevant `config.log`.
- [ ] Repeated cpio builds, full `prt-get depinst`, interrupted/failed builds and installer continuation do not hang or leak IPC queues.
- [ ] Verify installed/reinstalled packages and generated archive contents (root ownership, modes, symlinks, executables, `.footprint`), both via direct `pkgmk` and wrapped `prt-get` paths.
- [ ] Exercise bootstrap and `pkgmk -kw` workspace retention with existing r494/r496 safety constraints.
- [ ] Complete UEFI installation and boot from virtual disk without ISO; validate bootloader, kernel, networking and desktop sessions.

**Status:** CRITICAL / OPEN — observed installer hang and fakeroot IPC involvement; root cause and permanent fix **not yet verified**. Tracker update only. Related: r494/r496 workspace policy, r499 package-build false success.



## r502 — Targeted source remediation: cpio split build (2026-10-22)

- [x] Root cause for cpio hang mapped to `bfs-pkgmk` fallback invoking `fakeroot -- pkgmk` on non-split ports; split-build infrastructure already existed but cpio did not opt in.
- [x] Update `opt/cpio` to opt in to split build (configure/compile outside fakeroot; DESTDIR staging inside fakeroot); release bump 1→2; fail propagation.
- [x] Add offline contract regression `scripts/tests/test-r502-cpio-fakeroot.py`.
- [ ] Build and package in actual BFSOS VM; validate root metadata, .footprint, no IPC stall and full installer/reboot.
- [ ] Implement generalized safe fakeroot-free configure/build handling for remaining ports, keeping correct package metadata; prior r501 CRITICAL item remains OPEN.

**Status:** Targeted source change, pending live integration/verification. See `docs/BFSOS-r502-fakeroot-cpio-audit-20261022.md`.

## r505 — CRITICAL pkgutils universal classic-build mode (source implemented, 2026-10-22)

- [x] Replace legacy root wrapper `fakeroot -- pkgmk` for classic recipes with `runuser -u pkgmk -- ... BFS_PKG_UNIVERSAL_BUILD=yes pkgmk`.
- [x] Patch package engine so classic `pkg_build()` runs once as uid pkgmk outside fakeroot; short fresh fakeroot re-entry handles only archive and metadata, with virtual owner normalization.
- [x] Bump core/pkgutils `release=48`, add patch to `source=()`, and update local `.md5sum` entries.
- [x] Add source regression test; syntax and patch application pass offline.
- [ ] **CRITICAL** Build actual pkgutils release 48, validate its footprint/archive metadata and installed wrapper, then test cpio/wget2/rsync and a full UEFI VM install.
- [ ] Validate deliberately non-root-owned package payloads, hardlinks, devices and setuid/setgid metadata; document exceptions or adjust ownership policy safely.
- [ ] Verify ISO copies new pkgutils code into live root and target chroot; don't trust port-tree freshness alone.

**Status:** SOURCE FIX PRESENT / CRITICAL REGRESSION CONFIRMED — the live VM sudo build demonstrates a failure in classic unprivileged staging and masked `make install` errors. See **r510** below before treating release 48 as release-ready. r503 remains open. See `docs/BFSOS-r505-pkgmk-universal-audit.md`.


## r506 — Installer: multiple swap partitions silently ignored (2026-10-22)

- [ ] **Support and correctly persist multiple swap partitions in the BFSOS installer.**

**Observed:** During an installer test with **four swap partitions**, only **one** was recognized or processed; the other **three were silently ignored**. It is **not yet known** whether all four appear in the partition-selection UI, whether only the first is formatted/activated, or whether the problem is solely with `/etc/fstab` generation. Do not assume the detection stage or claim an exact root cause until the install path is inspected. Linux supports multiple swap areas; unusual layouts must not be silently discarded.

**Required engineering:**

- [ ] Audit partition enumeration, swap selection/state representation, installer menu behavior, target `mkswap`/`swapon` actions, and `/etc/fstab` generation for scalar/first-match or overwritten swap variables.
- [ ] Handle **all explicitly selected swap partitions** (not arbitrary detected devices). Preserve UUIDs and intended formatting policy; obtain/refresh UUIDs after `mkswap` and emit one stable UUID-based swap entry per selected device.
- [ ] Never silently format or enable an unselected partition; distinguish pre-existing swap from swap explicitly approved for reformatting. Warn clearly on duplicates, invalid devices, missing UUIDs or conflicting use as a mounted filesystem.
- [ ] Ensure repeated installer runs do not duplicate swap entries or reformat without authorization; cleanly report failure for each device rather than silently continuing.
- [ ] Keep existing single-swap and no-swap installation flows working; account for swap files if the installer offers them.

**Acceptance tests:**

- [ ] Test zero, one, two and **four** selected swap partitions, alongside root/EFI and optional `/home`.
- [ ] Verify swap menu visibility/selection, each `mkswap` and `swapon` operation (when explicitly requested), distinct UUIDs, exact `/etc/fstab` entries, and all selected swap devices after target reboot (`swapon --show`).
- [ ] Test preformatted swap, mixed selected/unselected devices, formatting failures, duplicate selection, rerun/idempotence, and clean UEFI VM installation.

**Status:** **OPEN / TRACKER ONLY.** Observed partial handling; discovery vs selection vs activation vs fstab root cause not yet isolated. No installer code change or VM retest claimed.

## r506 — pkgutils live validation note (2026-10-22)

- [~] Maintainer reports `pkgutils 5.40.12-48` built and was installed; installed `/usr/bin/pkgmk` contains `BFS_PKG_UNIVERSAL_BUILD` logic and `bash -n /usr/bin/pkgmk /usr/bin/bfs-pkgmk` returned success. An ordinary `wget` package (whose installed binary is `wget2`) compiled without hanging, with the build output showing `root/root` archive members, executable modes and symlinks. The user did not reinstall `wget`, by design.
- [ ] Remaining release gates: verify exact installed pkgutils release and wrapper policy if needed, repeat `cpio` and `rsync`, exercise actual `prt-get depinst` in installer/target, and boot completed UEFI installation. Do not mark global r503 acceptance complete from one ordinary package build.


## r507 — PROVISIONAL: GRUB menu presentation and unexpected EFI BootNext entries (2026-10-22)

- [ ] **Investigate GRUB menu presentation on a clean, uninterrupted UEFI VM installation; keep this item provisional until reproduced.**

**Observed:** The installed BFSOS 1.0-rc1 VM booted from the virtual hard disk, but the GNU GRUB 2.16 menu displayed `GNU/Linux` and `Advanced options for GNU/Linux` instead of BFSOS-branded labels. It also displayed `UEFI Firmware Settings` plus several additional EFI BootNext entries, including `BootManagerMenuApp`, `EFI Firmware Setup`, `UEFI QEMU DVD-ROM`, `UEFI Misc Device`, `UEFI PXEv4`, `EFI Internal Shell`, and `BFS (EFI BootNext)`. The screenshot was taken after a previously interrupted and manually repaired installation; this does **not** establish that a clean installation produces the same menu or that the EFI BootNext entries are harmful.

**Checks if reproduced after clean reinstall:**

- [ ] Compare `/etc/default/grub`, `/etc/os-release`, `/etc/lsb-release` if present, `/boot/grub/grub.cfg`, installed GRUB scripts (`/etc/grub.d/`), and `grub-mkconfig` generation log. Determine why the primary entries say `GNU/Linux` and whether BFSOS branding/configuration is missing or overwritten.
- [ ] Trace EFI BootNext entries to a GRUB generator, `efibootmgr`/UEFI variables, or OVMF firmware device enumeration before disabling anything. Preserve valid firmware-access/recovery entries, proper UEFI boot order and boot fallbacks.
- [ ] Check duplicate `UEFI Firmware Settings` vs `EFI Firmware Setup (EFI BootNext)` functionality, and whether external/firmware entries are being imported unexpectedly. Avoid blanket disabling `os-prober` or removing NVRAM entries without a verified cause.
- [ ] If needed, use user-facing `BFSOS 1.0-rc1` and `Advanced options for BFSOS` menu labels while keeping versioned kernel/fallback entries and correct mainline/LTS semantics.
- [ ] Regenerate configuration safely in a UEFI VM and verify reboot, default kernel, GRUB menu navigation, firmware menu, and old known-good fallback.

**Disposition after clean reinstall:** If branded entries and expected firmware behavior are already correct, mark this r507 item **NOT REPRODUCED / CLOSED** (or remove this provisional section at maintainer request). If it recurs, retain it as an actionable bug with screenshots/configuration evidence.

**Status:** **PROVISIONAL / UNCONFIRMED ON CLEAN INSTALL.** Tracker entry only. No GRUB configuration/code changes.

**Explicit deferral:** The reported missing `sudo` and locked-root/admin-access state is **not being opened as a new tracker bug** at the maintainer's request. Recheck only after a clean install, including whether `sudo` was selected and an administrator was configured. Existing generic install validation obligations remain unchanged.


## r508 — HIGH priority: Require root-password setup when sudo is omitted (2026-10-22)

- [ ] **Prevent an installation with no usable administrator authentication path when the user deselects `sudo`.**

**Maintainer decision:** Installing `sudo` is optional. If `sudo` is **not selected**, the installer must prompt to set and confirm a root password, apply it in the installed target, and verify root is unlocked and has usable password authentication **before declaring the install successful**. This is an installer usability/safety requirement, not proof that the earlier optional-sudo selection was malfunctioning.

**Required behavior:**

- [ ] Determine the final selected/installed sudo state from the actual target package transaction, not a menu default alone; handle an attempted but failed sudo install as no sudo available.
- [ ] If no sudo is available, require an interactive root password prompt with masked entry and confirmation; support secure noninteractive installer behavior by failing closed with an explicit message unless an approved secure root-credential mechanism was supplied. Never put passwords in shell history, command arguments, logs, tracker output, or build artifacts.
- [ ] Apply password changes within the installed root safely; ensure the root account is not left locked. Do not change or expose the live ISO root credentials.
- [ ] If sudo is selected and installed, retain the existing root-lock policy **only if** at least one configured non-root user can actually authenticate and is authorized via sudo; otherwise require a supported root recovery path or stop with an actionable error.
- [ ] Add a final admin-access validation gate before installation success. If password setup fails, is cancelled, or target credentials cannot be verified safely, report failure without falsely declaring a working install. Avoid logging password input.

**Acceptance tests:**

- [ ] Install without sudo: mandatory root password prompt appears; after disk boot root can authenticate and administer the system.
- [ ] Install with sudo: the designated administrator can use sudo; locked root is permitted only with a verified admin path.
- [ ] Sudo selected but package installation fails: no inaccessible target silently marked successful.
- [ ] Cancel, mismatch, blank-password policy failure and unattended installation all fail securely and leave clear recovery guidance.
- [ ] Reinstall, existing-root-password preservation, and UEFI VM boot checks do not regress.

**Status:** **OPEN / TRACKER ONLY.** No installer source changes or VM tests claimed. The earlier observation remains unconfirmed as a defect; this entry records the new, explicit safeguard.


## r509 — Normal priority: Add Shutdown System as option 5 to the live ISO startup menu (2026-10-22)

- [ ] **Add `5. Shutdown System` to the top-level menu displayed when booting the BFSOS live ISO.** This is the **live ISO startup/installer-launch menu**, not a menu within the installed BFSOS system or an additional installation step.

**Required behavior:**

- [ ] Identify the actual ISO startup menu script/service and its numbered actions; introduce the new option as number **5** while preserving existing options 1–4 and all keyboard navigation. Verify whether an existing item already occupies 5 before making changes.
- [ ] Selecting option 5 presents an explicit confirmation (Shutdown / Cancel, or Yes / No). Cancelling returns to the same live menu without side effects.
- [ ] On confirmation, request a clean live-system poweroff via `systemctl poweroff` from the proper privilege context. Do not power off the host, affect other VMs, or modify the installed root.
- [ ] Where an installation or target filesystem is active/mounted, warn about potentially interrupted work, prevent silent data loss, and rely on clean unmount/shutdown behavior; avoid allowing repeated or concurrent installer actions.
- [ ] Keep the option usable before installation, after installation, and after a failed/cancelled installer run. Make its labeling consistent with the existing menu/UI.

**Acceptance tests:**

- [ ] Boot UEFI/BIOS live ISOs and verify option 5 appears in the **ISO menu** with unchanged existing entries.
- [ ] Cancel shutdown and return to the live menu; confirm shutdown and verify QEMU powers off cleanly.
- [ ] Test with a prior failed installer and mounted target storage; no corrupted filesystem, deleted installed system, or unexpected host shutdown.

**Status:** **OPEN / TRACKER ONLY.** Maintainer-requested ISO menu enhancement; no implementation or VM validation claimed.


## r510 — CRITICAL: Universal fakeroot staging regression and silently truncated sudo package (2026-10-22/23)

- [ ] **Fix the existing r505 universal pkgutils/fakeroot work and r499 false-success package validation so classic Pkgfiles cannot silently publish partial archives when upstream `make install` requires root ownership operations.** This item records a **reproduced regression** and cross-references r499, r503/r505, and the installer access safeguard r508; do **not** assume this is a standalone sudo-only defect or fix by rewriting all classic Pkgfiles.

**Confirmed observations:**

- BFSOS 1.0-rc1 UEFI VM, installed `pkgutils 5.40.12-48`, `/usr/bin/pkgmk` SHA256 `fce228826a22a115e01b95549dd4a0a524b55e6061ccefd251fbaf2e08897c28`, wrapper `bfs-pkgmk`, sudo `1.9.17p2-1` using standard `pkg_build()`. The VM's package database reported sudo installed, but `/usr/bin/sudo`, `/usr/bin/visudo`, and `/etc/sudoers` did not exist. The actual `/var/cache/pkg/packages/sudo#1.9.17p2-1.pkg.tar.zst` contained **8 entries**, only one shared library payload and the manually installed PAM file plus directories; thus the bad payload was built before `pkgadd`, not removed after install.
- The original sudo `.footprint` expected full executable, plugin, manpage, configuration and ownership/mode payload, including setuid-root `usr/bin/sudo` (mode **4755**), `usr/bin/visudo`, and `etc/sudoers`. The bare-metal build of the same sudo port produced **56 archive entries**, including these essentials and correct setuid metadata; source/recipe is capable of a valid build. The bare-metal direct invocation is not proof the VM's root-launched wrapper path is healthy.
- Reproduced using the live ISO, mounting `/dev/vda4` as Btrfs `subvol=@` and chrooting into the installed VM, running the root-launched `bfs-pkgmk -f -kw -if` **without installing**. In the uploaded chroot build log, upstream sudo install attempts `chown` on staged files as UID 0 / GID 0, receives `Operation not permitted`, then reports `make[1]: *** [Makefile:393: install] Error 1` and `make: *** [Makefile:192: install] Error 2`. The remaining Pkgfile commands run, `pkgmk` archives the partial staging tree, prints `WARNING: Footprint ignored`, and reports success. Archive still has **8 entries**. This verifies the failure mechanism in the tested path, not every port's behavior.
- In classic mode `BFS_PKG_UNIVERSAL_BUILD=yes`, pkgutils currently executes the **entire** `pkg_build()` under unprivileged UID `pkgmk`, then enters a short `fakeroot` **archive-only** pass. Merely applying virtual `chown` during archive creation cannot repair a failed upstream installation. The Pkgfile lacks explicit error chaining around `./configure`, `make`, `make DESTDIR="$PKG" install`; and the package engine invokes `build` inside a negated conditional (`if ! (set -e -x; build)`), where Bash `errexit` is not reliable for nested function failures. `-if` suppresses the footprint check; the wrapper may also refresh `.footprint` and `.md5sum` from the bad archive.

**Required engineering (r505/r499 integration):**

- [ ] Preserve the universal requirement: **configure and compile run unprivileged and outside fakeroot**, with **no per-port opt-in and no mass rewrite** of the ~1,300 classic Pkgfiles. Design a safe way for legacy one-function Pkgfiles to execute ownership-sensitive DESTDIR staging inside a bounded fakeroot session **without repeating configure/compile or rerunning the whole Pkgfile unsafely**. Explicit split-phase ports may use the existing two-function route. Assess realistic technical limits of inferring the install phase from arbitrary `pkg_build()`; do not declare a universal fix until independently validated. Avoid bringing back long-running fakeroot IPC deadlocks.
- [ ] Ensure `configure`, `make`, and `make install` failures **propagate** even when followed by successful cleanup/PAM installation. Correct `if ! (...)` / `set -e` function-context behavior in pkgutils; add tests showing error at each mandatory step cannot be obscured by later success. Use per-port error chaining where needed as defense in depth, not as the only global fix.
- [ ] Do **not** publish/archive/cache/install a newly built package on build/stage failure; preserve previous known-good artifacts and source `.footprint` unless a verified successful update explicitly refreshes metadata. Audit `-f`, `-kw`, `-if`, `-uf`, updater refresh, and wrapper postprocessing to prevent poisoned footprint regeneration.
- [ ] Gate critical packages (including sudo) by actual archive content and modes even if an installer/bootstrap intentionally passes `-if`: required sudo payload includes `usr/bin/sudo` mode 4755 and root ownership, `usr/bin/visudo`, `/etc/sudoers`, PAM and plugins. Treat an eight-entry archive as an error. Retain fingerprint/manifest diagnostics and exact unsuccessful stage logs.
- [ ] Audit installed/base/ISO package archives built with `pkgutils 5.40.12-48` for other truncated artifacts; check packages likely to run `chown`, `chmod`, `install -o`, special-mode staging. Don't claim all packages affected; prioritize base and privileged utilities.
- [ ] Integrate with r508: installer must verify a **usable** administrative path before success; sudo being registered in the package DB is insufficient. If sudo is omitted/invalid and root locked, require root-password recovery or stop installation securely.

**Acceptance/regression tests:**

- [ ] Reproduce the original chrooted sudo eight-entry failure using a controlled test before changes; after changes the same path yields a complete valid sudo package (expected footprint, setuid 4755, plugins, `visudo`, `sudoers`) **without installing**. Then test a normal `prt-get depinst` / complete UEFI installer run and verify actual administrator access after disk boot.
- [ ] Test deliberate `make install` `chown` failure, configure failure, compiler failure, missing required payload, partial archive, and `-if` override. Each must fail with nonzero status and **no replacement of good package or `.footprint`**. Test ordinary `pkgmk`, root-launched `bfs-pkgmk`, `prt-get`, chroot, tmpfs/disk backend and optional split-phase ports.
- [ ] Re-test original fakeroot cpio/wget2 deadlock reproduction; no compile/configure process should remain wrapped in long-lived fakeroot and no SysV IPC queue should fill indefinitely. Verify correct root metadata, permissions, symlinks and hardlinks for completed packages.

**Status:** **CRITICAL / REPRODUCED / FIX NOT IMPLEMENTED.** Tracker only; preserve the broken eight-entry sudo archive and uploaded chroot build log as evidence. No production pkgutils changes or package installation claimed in this revision.


## r511 — CRITICAL pkgutils scoped staging and sudo failure propagation (2026-10-22/23)

**Source remediation implemented offline; not yet release-validated.** This is a continuation of r499, r503/r505 and r510, not a new unrelated sudo defect.

- [x] Add `core/pkgutils` 5.40.12-49 source patch that keeps classic configure/compile outside fakeroot, but dispatches recognized `make install` targets to a **bounded short fakeroot** subprocess, without requiring changes to 1,372 ordinary ports.
- [x] Correct classic `if ! (set -e; build)` conditional suppressing `errexit`; also fix split compile conditional. A failing `make install` in a classic one-function recipe cannot be hidden by later Pkgfile commands in the tested shell semantics.
- [x] Add minimum mandatory staged payload checks for `sudo` (`usr/bin/sudo` mode 4755, `visudo`, `etc/sudoers`) and `rsync` (`usr/bin/rsync`) even when `-if` was requested.
- [x] Strengthen `core/sudo` Pkgfile failure propagation and bump release to 2.
- [x] Add offline source regression and a mock `make install` ownership/mode test; verify source patch applies after existing r505 patches and syntax passes.
- [ ] **CRITICAL REMAINING:** Verify actual sudo 1.9.17p2-2 build under root-launched `bfs-pkgmk` in installed VM chroot, exact footprint, complete archive, sudo mode 4755, ownership/plugins/PAM, normal `prt-get` installation, and user sudo authorization. Do not claim the eight-entry problem fixed until this passes.
- [ ] **CRITICAL REMAINING:** Universal legacy coverage for non-`make` staging (`ninja`, `meson`, `cmake --install`, install/chown helpers) and make install invoking compile prerequisites. The new make interceptor is a partial generic remedy, not proof every classic port is safe.
- [ ] **CRITICAL REMAINING:** Atomic archive output/preservation of previous same-version known-good archives on failed rebuilds; wrapper currently has dangerous failure cleanup semantics. Make metadata refresh transactional and never replace good `.footprint` from a truncated build.
- [ ] Re-test cpio SysV fakeroot IPC stall, wget2, rsync, sudo, mixed ports, tmpfs/disk workspaces, `-kw`, `-if`, `-uf`, and kernel/boot safety. Audit all privileged packages built with pkgutils -48 before base/ISO release.
- [ ] Retain r508 installer admin-access gate and explicit sudo validation; an installed package database record alone cannot establish usable admin access.

**Status:** PARTIAL SOURCE FIX / CRITICAL LIVE RELEASE BLOCKER. See `docs/BFSOS-r511-pkgutils-sudo-stage-audit-20261022.md`. This overlay does **not** modify the installed BFSOS machine.
