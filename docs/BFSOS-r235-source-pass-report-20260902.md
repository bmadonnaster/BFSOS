# BFSOS r233 source-actionable tracker pass — 2026-09-02

## Baseline / checkpoint identity

This pass was performed against the BFSOS source archive supplied on 2026-09-02.

- Git commit reported by the maintainer: `d5dd294089fd70d9fbc9b2f173ed86ee1fd3ea8b`
- Commit subject: `Remove duplicate cython3 port and use python3-cython`
- Reported branch state: `main`, matching `origin/main` / `origin/HEAD`
- Reported uncommitted state: only `?? BFSOS-20260902.tar.zst`; no source modifications were reported.
- Supplied checkpoint archive SHA-256: `b5d9a58bcd7544901783f40cd0dec10787791f54945beaba8110228a86f53a01`
- Supplied r232 tracker SHA-256: `bbb5a5a49a20ad6d79dba22b10b1e1bacb292142ed673245669eed740d87b226`

The untracked archive is a checkpoint artifact, not source, and should not be committed into the BFSOS repository.

## Scope rule

This pass works source changes that can be supported by static repository evidence and current upstream release information. It does **not** mark package builds, clean installations, desktop logins, cold boots, hardware behavior, upgrade transactions, or other runtime-only regressions as passed without actually running them on BFSOS.

## Static validation status

At the end of the pass:

- `scripts/bfs-ports-static-audit.sh`: **PASS**
- `scripts/bfs-release-static-audit.sh`: **PASS**
- every `ports/*/*/Pkgfile`: **Bash syntax PASS**
- `bootstrap.sh`: **Bash syntax PASS**
- `scripts/bfs-ports-static-audit.sh`: **Bash syntax PASS**
- `scripts/bfs-release-static-audit.sh`: **Bash syntax PASS**
- `scripts/bfs-ports-tree-audit.sh`: **Bash syntax PASS**
- WirePlumber `post-install`: **shell syntax PASS**
- XFCE default panel XML: **XML parse PASS**
- ports-tree inventory: **1300 Pkgfiles**
- duplicate package identities (`name=`): **0**
- unresolved hard-dependency tokens in maintained 64-bit collections: **0**
- remaining unresolved dependency-token diagnostics are confined to the separately tracked legacy `compat-32` architecture.

## Source work completed / reconciled

### pkgutils / generic package-build policy

- Fixed the generic pkgmk extension so `build_opt=(...)` Bash arrays are preserved as arrays. This addresses the runtime-proven bug where only the first Meson option reached `meson setup`.
- Retained historical scalar `build_opt="..."` behavior for existing recipes.
- Added fail-fast return propagation to generic Makefile, Perl, CMake, Autotools and Meson paths.
- Added a CMake 4 compatibility default that supplies `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` when using CMake 4+, unless the package already supplies its own value or the policy is explicitly disabled.
- Added conservative generic test disabling only when a build system actually exposes a recognized test option. Per-package `run_tests=yes` or global `PKGMK_RUN_TESTS=yes` can opt back in.
- Meson remains `--wrap-mode=nodownload` so missing build dependencies cannot silently turn into network-fetched subprojects.

### `bfs-pkgmk` end-of-build parser

- Reconciled the tracker with the supplied source: the fragile quote-heavy `sed` parser for `PKGMK_PACKAGE_DIR` has already been replaced by an `awk` parser that extracts the configured value without the repeated `Unmatched ( or \(` diagnostic.
- Runtime verification still requires updating/reinstalling the changed pkgutils wrapper on the BFSOS test VM and confirming the old diagnostic disappears.

### prt-get newly-added dependency refresh

- Extended the BFSOS `prt-get` front-end wrapper so `update` and `sysup` preflight the current dependency closure and install newly-added hard dependencies through normal `depinst` semantics before executing the requested update.
- `--test` remains non-mutating.
- This is the source-side fix for the behavior observed when an already-installed meta package gained new dependencies but `prt-get update` did not install them.

### source-cache layout and fallback policy

- Stage 1, Stage 2/3, and the special systemd bootstrap transaction now use the same package-namespaced source-cache layout: a common source root plus `$name` namespace.
- The initial pre-pkgmk `pkgutils` bootstrap source is seeded into the same `pkgutils/` namespace.
- This resolves the static root cause of Stage 3 redownloading unchanged archives solely because Stage 1/2 had populated a flat cache.
- Propagated path-aware Savannah/Nongnu and kernel.org fallback mappings into installed and bootstrap pkgmk configurations.
- Retained checksum/signature/footprint policy and package namespacing; mirrors do not weaken integrity verification.
- Buildroot/LFS archival fallbacks remain a review/runtime item because they cannot be safely represented as one unconditional path transform for every upstream package.

### VTE ownership

- Removed `vte.sh` and `vte.csh` from `aaa_filesystem` source/install ownership and bumped `aaa_filesystem` release.
- The upstream VTE package can now own the profile scripts without forcing an overwrite.
- Live upgrade/reinstall ownership migration remains to be tested.

### desktop audio activation

- Added `ports/opt/wireplumber/90-bfsos-audio.preset` with:
  - `enable pipewire.socket`
  - `enable pipewire-pulse.socket`
  - `enable wireplumber.service`
- WirePlumber installs the preset and provides a `post-install` hook using `systemctl --global preset` so new users inherit the intended defaults.
- Removed Plasma-meta-owned hand-written user-unit symlinks; desktop audio activation policy now has one owner instead of Plasma-specific wiring.
- Bumped WirePlumber and Plasma meta releases for the packaging-policy change.
- Fresh-user XFCE and Plasma runtime regressions remain required.

### XFCE first-login panel defaults

- Added a packaged XFCE panel default template and bumped `xfce4-panel` release.
- The default panel explicitly instantiates systray, notification, power-manager and PulseAudio/PipeWire volume plugins rather than merely installing their shared objects.
- Fresh-user regression remains required because existing users with xfconf state will not consume the first-login template.

### Firefox family

- Rapid-release source Firefox updated to `155.0`.
- `firefox-bin` updated to `155.0`.
- Firefox ESR updated to `153.2.0esr`.
- The rapid-release source port retains the current Rust target-vendor compatibility handling; the ESR recipe carries the corresponding compatibility logic.
- Upstream freshness was checked against Mozilla's current 2026-09-01 releases. Runtime/build validation is still required for the newly bumped sources/binary package; the earlier ESR build/audio smoke test predates these exact r233 bumps.

### kernels

- Main Linux and linux-headers are updated to `7.2.3`.
- Linux LTS is updated to `6.18.49`.
- These match kernel.org's stable and longterm listings on 2026-09-02.
- Kernel build, module-compression verification, initramfs generation and cold-boot regressions remain open.

### KDE / Plasma freshness

- Current BFSOS KDE modernization baseline was audited against KDE's current announcements and remains aligned with:
  - KDE Frameworks `6.29.0`
  - Plasma `6.7.4`
  - KDE Gear `26.08.0`
- No speculative jump beyond current stable was made.

### Compiz completion

- Added `ports/compiz/fusion-icon` at upstream `0.2.4`, using Python 3/setuptools packaging.
- Added `ports/compiz/compiz-plugins-experimental` `0.8.18` and includes the upstream GCC-14-era fix commit patch (`35ce86af`) needed by modern compilers.
- Added the missing GLEW port needed by the experimental plugin closure.
- Updated `compiz-meta` to release 3 and added both `fusion-icon` and `compiz-plugins-experimental` to the hard dependency set.
- Compiz runtime switching, CCSM visibility, plugin loading, Emerald and Fusion Icon behavior remain runtime tests.

### duplicate package identity audit

- Removed/retired duplicate package identities found across collections, including the already-maintainer-fixed Cython duplicate and additional duplicate identities encountered in the source pass (`dconf-editor`, `nvidia`, `qcoro`).
- Added `scripts/bfs-ports-tree-audit.sh` to inventory package identities, dependency tokens, stale metadata patterns and focused desktop-suite versions.
- Current result: **0 duplicate `name=` package identities** across 1300 Pkgfiles.
- Payload-level overlap still requires package-build/footprint evidence; static name deduplication cannot prove two differently named packages never install overlapping files.

### maintained-tree metadata normalization

- Normalized the Brian Madonna maintainer line to `Brian Madonna <bmadonnaster@gmail.com>` across the maintained tree and compat-32 recipes encountered during the audit.
- Static package identity/dependency audits were expanded.
- Placeholder comments remain concentrated in `compat-32`, which is already tracked for architectural redesign rather than treated as completed modernization.

### LXQt modernization

- Updated the existing LXQt stack from its old 2.0-era baseline to the current LXQt 2.4 family.
- Current point releases incorporated where published, including `lxqt-panel 2.4.1`, `pcmanfm-qt 2.4.1`, and `lxqt-wayland-session 0.4.1`.
- Added missing current desktop components/ports:
  - `lxqt-notificationd`
  - `lxqt-wayland-session`
  - `lxqt-archiver`
  - `pavucontrol-qt`
  - `lximage-qt`
  - `qps`
  - `screengrab`
- Updated `lxqt-meta` to a complete desktop dependency path including SDDM, PipeWire/WirePlumber, RTKit and the missing applications/components.
- Current upstream LXQt release remains 2.4.0, with component point releases layered on top.
- Full build/install/login testing is still required before marking the migration release-ready.

### GNOME modernization — preparatory source work only

- Added a transitional `gnome-meta` so the intended complete GNOME desktop path is explicit.
- Corrected several concrete legacy recipe defects, including GDM's misspelled `built_opt`, contradictory Mutter test flags, GNOME session staging/install logic, and fail-fast behavior in touched recipes.
- Removed a duplicate `dconf-editor` package identity.
- GNOME session files are no longer deleted from the staged package by the old recipe.
- **The full GNOME migration is intentionally still OPEN.** Current stable GNOME is the 50 branch (50.4 as of this pass), while most BFSOS GNOME recipes are still GNOME 47-era. Blindly changing 80+ package version variables without reconciling module renames, removals, dependency/API changes and actual builds would create a misleading tree. Continue GNOME 50 conversion in dependency-ordered, build-verified batches.
- GNOME 51 is still development/RC during this checkpoint; BFSOS should target current stable GNOME 50 until 51 becomes stable and the migration decision is revisited.

### missing maintained-tree hard dependency

- Added `libdbusmenu-glib` and supporting compatibility patches after the dependency audit exposed the missing canonical provider.
- Hardened the GTK2 companion packaging path.
- Maintained 64-bit collections now have no unresolved hard dependency-name diagnostics in the static tree audit.

## Items deliberately left runtime/build-open

The following cannot be closed from a source archive alone:

- clean Full Bootstrap Stages 1–5, including offline/cache reuse and mirror failover;
- real `prt-get update/sysup` newly-added-dependency transactions;
- package builds for the newly added/updated Compiz and LXQt recipes;
- clean XFCE, Plasma, LXQt and GNOME desktop installs/logins;
- fresh-user PipeWire/WirePlumber activation and XFCE panel template consumption;
- Compiz plugin/Fusion Icon/CCSM runtime behavior;
- Firefox 155 / ESR 153.2.0 exact-build validation and browser trust regression;
- kernel 7.2.3 / 6.18.49 build, `.ko.zst`, Dracut and cold-boot tests;
- installer MD/LUKS/LVM and recovery matrices;
- Qt5 WebEngine ownership migration and other installed-filesystem ownership migrations;
- hardware/GPU/suspend/degraded-RAID/bare-metal tests;
- full GNOME 50 dependency-ordered migration/build validation;
- `compat-32` redesign and its stale dependency-token cleanup.

## Recommended next test order

1. Install/update `pkgutils` and `prt-get` first on the BFSOS VM; confirm the end-of-build sed diagnostic is gone and the new-dependency wrapper behaves normally.
2. Rebuild/reinstall `aaa_filesystem` then VTE; confirm ownership migrates without `-f`.
3. Rebuild/install WirePlumber and create a brand-new user; test first-login audio on XFCE and Plasma.
4. Rebuild `xfce4-panel`, create a fresh user, and confirm the intended status plugins appear automatically.
5. Build/install the two new Compiz ports, then `compiz-meta` release 3 and perform the XFCE + Compiz runtime matrix.
6. Build the LXQt 2.4 dependency chain from a clean/minimal VM before attempting a graphical LXQt login.
7. Build Firefox/Firefox-bin/ESR at the exact r233 versions.
8. Build both kernels and perform module/initramfs/cold-boot tests.
9. Start GNOME 50 conversion in dependency-ordered batches rather than one giant blind version bump.

## r234 follow-up — BLFS LXQt application reconciliation

Before handing off r233, the LXQt tree was re-audited against the current BLFS LXQt Desktop and LXQt Applications chapters.

The complete current BLFS Chapter 38 application set is `lximage-qt`, `lxqt-archiver`, `lxqt-notificationd`, `pavucontrol-qt`, `qps`, `qtermwidget`, `qterminal`, and `screengrab`. All eight had already been created during the r233 modernization and were already dependencies of `lxqt-meta`; no duplicate/replacement ports were created.

Additional fixes made in r234:

- `lxqt-archiver` release 2: add required `liblxqt` dependency.
- `pavucontrol-qt` release 2: add required `liblxqt` dependency.
- `lxqt-meta` release 3: add `openbox`, `obconf-qt`, `breeze-icons`, and `desktop-file-utils` so the default X11 meta install follows BLFS startup/recommended integration expectations.
- Static/release audits now require all eight Chapter 38 applications plus the corrected X11/recommended meta dependencies.
- Added `docs/BFSOS-tracker-r234-lxqt-blfs-apps-20260902.md` with the exact reconciliation and regression plan.

Wayland remains intentionally open. `lxqt-wayland-session` is present, but BFSOS does not yet package a supported compositor such as the BLFS-recommended Wayfire dependency closure. X11 is now the complete default path through Openbox; Wayland should be added and tested deliberately rather than falsely treated as complete.

Validation: both BFSOS static/release audits pass and the ports-tree audit reports zero duplicate package identities.


## r235 follow-up — current BLFS GNOME chapter coverage reconciliation

A second desktop-suite reconciliation was performed before handoff, this time
against the current BLFS systemd GNOME Libraries/Desktop and GNOME Applications
chapters.

### What was actually missing

The r234 tree already contained nearly every BLFS GNOME chapter identity. Two
items that looked absent from `ports/gnome` were already packaged canonically in
`ports/opt` (`libsecret` and `dconf-editor`), so no duplicates were introduced.

The true current GNOME-chapter gaps were:

- `gweather-locations 2026.2`
- `loupe 49.2`
- `showtime 49.1`

The newer apps also required two support packages that BFSOS did not yet carry:

- `glycin 2.1.5`
- `blueprint-compiler 0.22.2`

All five ports are now present.

### Related source corrections

- `libgweather` updated to `4.6.0` and now explicitly depends on
  `gweather-locations`.
- Glycin includes the current first-install bootstrap source fix and is built
  without tests/docs; the default image loader set is narrowed to loaders whose
  dependencies are already represented in BFSOS instead of forcing absent
  optional `libheif`.
- Loupe uses Glycin and the current Rust/libadwaita/libgweather dependency path.
- Showtime uses Blueprint Compiler, GStreamer base, libadwaita and
  `python3-gobject`.

### Meta-package correction

`gnome-apps-meta` now carries all current BLFS GNOME Applications identities.
Loupe and Showtime are hard dependencies. Legacy EOG and `gnome-screenshot`
remain available as standalone ports but are no longer current default app
bundle dependencies.

`gnome-meta` now also explicitly includes shell extensions, Tweaks, GNOME user
documentation, Yelp and DConf Editor in addition to the existing desktop,
applications, portal and common PipeWire/WirePlumber audio path.

### Static enforcement

The release audit now verifies the new GNOME support/application ports, the
`libgweather -> gweather-locations` dependency, complete current GNOME
Applications identity coverage, and the expanded `gnome-meta` dependency set.
The ports-tree audit reports current BLFS GNOME app coverage directly.

Current r235 static result:

- duplicate package identities: 0
- missing current BLFS GNOME application identities: 0
- maintained 64-bit hard dependency names: clean (the remaining unresolved
  diagnostic tokens remain limited to the separately tracked compat-32 tree)
- BFSOS ports static audit: PASS
- BFSOS release static audit: PASS

### GNOME modernization remains open

This is a package/application **coverage** pass, not a claim that every older
GNOME port has already been migrated to GNOME 50. Many existing 47-era recipes
still need dependency-ordered version updates and real builds. The recommended
first runtime build sequence for the new coverage is:

`blueprint-compiler -> gweather-locations -> libgweather -> glycin -> loupe -> showtime -> gnome-apps-meta -> gnome-meta`

After those build successfully, continue the broader GNOME 50 migration in
small dependency-ordered groups and finish with a clean GDM/GNOME login and
fresh-user application/runtime regression.
