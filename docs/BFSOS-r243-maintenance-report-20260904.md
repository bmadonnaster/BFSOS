# BFSOS r243 Maintenance Report — 2026-09-04

## Scope

This pass starts from Git baseline `a6ecd1a6` (`updated BFSOS 2026-09-04`) and covers every Pkgfile in the maintained BFSOS trees:

- `core`
- `opt`
- `xorg`
- `plasma`
- `gnome`
- `lxqt`
- `xfce`
- `compiz`

`contrib` and `compat-32` were explicitly excluded and have not been modified.

The final maintained-tree inventory contains **1,130 Pkgfiles**. The generated inventory is `docs/BFSOS-maintained-port-inventory-r243-20260904.tsv`.

## Tracker implementation status

### Kernel cleanup and stale initramfs handling

Implemented a new `bfs-kernel-maintenance` core package and integrated it with both `linux` and `linux-lts`.

The update model is deliberately two-phase:

1. Before replacement, stage the currently running/known-good kernel payload and module tree.
2. Restore that rollback payload if package replacement removed it.
3. Build and validate the new initramfs before marking the new kernel pending.
4. Generate GRUB into a temporary file, validate it, and publish it atomically.
5. Refuse another same-flavor update while the replacement is still pending boot verification.
6. On the first successful boot into the pending kernel, mark it known-good and prune only kernels older than the current kernel plus the immediately previous rollback kernel.

The helper recognizes both `*-BFS-Linux` and `*-BFS-LTS` artifacts, handles versioned `vmlinuz`, initramfs, `System.map`, config, module and source-tree payloads, and updates selected-kernel aliases.

A fake-root regression test exercises normal and LTS multi-update sequences, rollback restoration, pending-update refusal, successful cleanup, and a failed-new-boot preservation case.

### Installer build-work tmpfs sizing

Installer r72 implements the requested physical-RAM-only policy:

| Physical RAM | Auto build-work policy |
| --- | --- |
| <16 GiB | disk-backed |
| 16–31 GiB | 8G tmpfs |
| 32–47 GiB | 16G tmpfs |
| 48–95 GiB | 32G tmpfs |
| 96–191 GiB | 64G tmpfs |
| >=192 GiB | 96G tmpfs |

The installer exposes **Auto**, **Disk-backed**, and **Custom tmpfs size** choices. Swap is not included in the sizing calculation. The active `scripts/install-bfs-menu-current.sh` link now points to `install-bfs-menu-v50-r72-tracker-maintenance.sh`.

### `prt-get --no-new-deps`

The BFSOS `prt-get` wrapper now accepts `--no-new-deps` for `update` and `sysup` transactions. Default behavior remains unchanged: newly required dependencies are automatically installed. With the flag, new dependencies are detected and reported but intentionally not installed; explicit `depinst` remains unchanged.

Help output, README/man-page text, warnings and examples were updated. `scripts/tests/test-prt-get-no-new-deps.sh` covers normal update, opt-out update, opt-out sysup, explicit `depinst`, and help discoverability.

### LTS kernel selected-family consistency

The LTS path now uses the same staged rollback and post-boot cleanup policy as the normal kernel. It maintains `/boot/vmlinuz-lts`, `/usr/src/linux-lts`, and `/usr/src/linux` consistently with `/etc/bfsos/kernel-flavor`. GRUB preference is written using `GRUB_TOP_LEVEL` and then generated/validated atomically.

The normal kernel remains 7.2.3 and LTS remains 6.18.49 because those were already the current kernel.org stable/longterm releases at the time of this pass.

### Debian LTS patch review

Debian's available 6.18 backport patch set is based on an older 6.18.15 package, while BFSOS tracks upstream 6.18.49. The Debian quilt series also contains Debian integration, policy/hardening, DFSG and build-system changes in addition to bug fixes.

**Decision:** do not wholesale apply Debian's older 6.18.15 patch series to BFSOS 6.18.49. Upstream stable fixes present through 6.18.49 should remain authoritative. Individual Debian policy/hardening changes can be evaluated separately if BFSOS deliberately wants that policy; they should not be imported as if they were missing upstream stable fixes.

### sudoers environment preservation

The generated KF6 and X.Org snippets now use quoted `env_keep` lists. Both snippets parse successfully with `visudo -cf` in the maintenance environment. `aaa_filesystem` release was bumped so corrected files propagate on update.

### PipeWire / WirePlumber first-login activation

WirePlumber was updated to 0.5.17. Its BFSOS package now ships a user preset that enables the PipeWire socket, PipeWire-Pulse socket and WirePlumber service, while disabling the standalone PulseAudio service/socket. Post-install applies user presets when systemd supports them.

Fresh-user and cross-desktop runtime verification is still required before this tracker item should be considered fully closed.

### Plasma Login Manager

Added `ports/plasma/plasma-login-manager` at Plasma 6.7.4, alongside SDDM rather than replacing it. The package includes BFSOS PAM policy and a `bfs-display-manager` selector for `sddm`, `plasmalogin`, and status reporting. The selector persists policy under `/etc/bfsos/display-manager` and disables the other manager before enabling the selected one.

The package deliberately fails its build if upstream no longer installs `plasmalogin.service`, so a future service-name/layout change cannot silently leave installer logic pointing at a guessed unit.

Build, KCM, session-discovery and real greeter/login validation remain required on BFSOS.

## Port maintenance

### Coordinated GNOME refresh

The largest stale area was GNOME. This pass refreshes the tree from its GNOME 47-era base toward the current GNOME 50 maintenance generation, including coordinated Shell/Mutter/GJS/SpiderMonkey and application/library dependencies.

Notable resulting versions include:

- GNOME Shell 50.4
- Mutter 50.4
- GDM 50.3
- GNOME Control Center 50.4
- GNOME Settings Daemon 50.1
- GNOME Session 50.1
- GJS 1.88.1
- SpiderMonkey 140.15.0esr
- Evolution / Evolution Data Server 3.60.2
- Nautilus 50.3
- GNOME Maps 50.4
- GNOME Weather 50.0
- Loupe 50.0
- WebKitGTK / WebKitGTK 4.1 2.52.6
- VTE 0.84.1
- dconf 0.49.0 / dconf-editor 49.0
- gucharmap 17.0.2 with Unicode 17.0 data
- librest 0.10.2 replacing obsolete `rest` 0.9.1

Recipe corrections made during the refresh include WebKitGTK source/CMake layout, WebKitGTK 4.1 GTK3+libsoup3 selection, a `gst-plugins-bad` dependency typo, Nautilus modern search/index dependencies, the GCC 16 GNOME Shell calendar-server const-correctness adjustment, and LLVM packaging of Clang/LLD/compiler-rt needed by the modern Mozilla stack.

### Other changed maintained ports

- Vim 9.2.0954 -> 9.2.1025
- FreeRDP 3.30.0 -> 3.31.0
- Mesa 26.2.1 -> 26.2.2
- NVIDIA 550.127.05 -> 595.99.02 production branch
- WirePlumber 0.5.15 -> 0.5.17
- `swaylock` dependency normalized from nonexistent BFSOS package name `pam` to `linux-pam`

KDE Plasma 6.7.4, KDE Frameworks 6.29, KDE Gear 26.08, LXQt 2.4.x, the XFCE 4.20.x set, and Compiz Reloaded 0.8.18 were checked against their current release families and did not require coordinated version changes beyond the changes described above.

### Duplicate package identities removed

Three duplicate identities existed in maintained trees and have been reconciled:

- `dconf-editor`: canonical GNOME port retained; duplicate `opt` port removed.
- `qcoro`: canonical Plasma port retained; duplicate `opt` port removed.
- `nvidia`: canonical `opt` port retained/updated; duplicate `xorg` port removed.

## Update checker hardening

`scripts/checkupdate.sh` no longer labels transport/DNS failures as fake HTTP 404 results. It now distinguishes `FETCH-ERROR` from `NO-MATCH`, adds reasonable curl timeouts, and defaults to the eight maintained trees only.

`scripts/bfs-maintained-port-version-audit.sh` is a no-update online audit wrapper intended to be run on Prism with normal Internet access. It writes a timestamped log for review and deliberately excludes `contrib` and `compat-32`.

This is important because the artifact-build container used for this maintenance pass cannot provide a trustworthy direct network run of the repository's curl-based checker. Every maintained Pkgfile was statically/dependency audited, and coordinated/current-release families were externally verified, but the Prism log is still the final exhaustive package-by-package live URL-parser check.

## Validation added

- `scripts/bfs-r243-source-tests.sh` — aggregate source/static regression suite.
- `scripts/tests/test-kernel-maintenance.sh` — fake-root kernel lifecycle regression.
- `scripts/tests/test-prt-get-no-new-deps.sh` — transaction-mode regression.
- `scripts/tests/test-installer-build-work-sizing.sh` — exact tmpfs bracket regression, including 61 GiB -> 32G.
- `scripts/bfs-r243-runtime-check.sh` — read-only installed-system closeout diagnostics.
- `scripts/bfs-maintained-port-version-audit.sh` — live maintained-tree upstream checker for Prism.

At packaging time the maintained-tree static audit reports no duplicate package identities and no unresolved hard dependency names in the requested trees. The warnings produced by the all-tree checker are confined to the explicitly excluded `compat-32` tree.

## Remaining runtime closeout

The source implementation is complete enough for the next BFSOS build/test cycle, but the following require a real BFSOS VM or machine and therefore remain **runtime verification pending**:

1. Fresh normal-kernel installation and two successive normal-kernel updates/reboots.
2. Fresh LTS installation and two successive LTS updates/reboots, including GRUB default selection and source symlinks.
3. Installer Auto/Disk-backed/Custom build-work behavior, including a ~61 GiB RAM system selecting 32G.
4. Real `prt-get update/sysup --no-new-deps` during the bootstrap ordering case.
5. Fresh-user PipeWire/WirePlumber behavior in Plasma, GNOME, XFCE and LXQt.
6. Plasma Login Manager build, KCM, PAM, login/logout/reboot/session discovery and switching back to SDDM.
7. Build/install testing of the refreshed GNOME 50 stack, especially SpiderMonkey, WebKitGTK, GJS, Mutter and Shell.
8. A Prism run of `scripts/bfs-maintained-port-version-audit.sh`, followed by review of any genuine update hits.

Do not mark those tracker items fully CLOSED until their relevant runtime checks have passed.
