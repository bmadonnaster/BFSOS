# BFSOS r495 offline implementation and tracker audit — 2026-10-20

## Scope and status

This is a **targeted implementation pass, not completion of every tracker item**. The project's historical trackers collectively contain hundreds of unresolved tasks. No BFSOS live host/VM, kernel build, privilege-boundary pkgmk cleanup, NVIDIA vendor package build, or ISO boot was run in this environment.

## Changes implemented in source

1. **NVIDIA and NVIDIA-32 update source handoff**: `scripts/bfs-maintained-port-updater.py` now recognizes vendor `.run` sources as archives. The existing source-selection logic can identify the primary `NVIDIA-Linux-x86_64-$version.run` source of both ports; the version-dynamic URL remains templated, and coordinated version lock/rollback behavior is unchanged. The version detected in the supplied scan was `615.78.08` from GLFS DEV. *Offline source-rewrite tests pass; live archive download and both package builds still required.*
2. **Routine footprint update acceptance**: `scripts/bfs-port-updater.py` now permits the pre-existing `pkgmk -if` → `pkgmk -uf` verification flow for ordinary new/removed files, directories and contained relative symlinks with standard root ownership and unprivileged modes. Explicit review remains required for privileged/special modes, nonstandard owners, abnormal paths, absolute/escaping symlinks, known sensitive paths, CHANGED metadata entries, and kernels. Kernel protection/boot validation policy was deliberately not weakened.
3. **Regression tests**: `scripts/tests/test-r495-updater-footprints-nvidia.py` exercises the NVIDIA source handoff, routine footprint examples, and unsafe payload rejection. PASS offline.

## Supplied logs reviewed

The updated routine policy classifies these logged October 18 mismatch examples as benign *candidate footprint changes* that may proceed into package creation/validation: `librsvg`, `python3-chardet`, `systemd`, `vim`, `libunistring`, `libunistring-32`, `libXrender-32`, and `wine-staging`. These are NOT claims that corresponding updates have been rebuilt, installed, or successfully run. The verified archive still must be generated; no blanket footprint-ignore setting was added.

The reported `pkgconf 3.0.8` source/meson issue and Linux 7.3.0 release string fix were already addressed by the user; this pass does not revalidate those live builds. Earlier `grub 2.16` URL 404, pkgmk workspace owner/cleanup, kernel footprint strategy, and other historical tracker items remain outstanding.

## Tests

- PASS: `scripts/tests/test-r495-updater-footprints-nvidia.py`
- PASS: `scripts/tests/test-r404-updater-fixes.py`
- PASS: `scripts/tests/test-r438-installer-updater.py`
- FAIL in supplied baseline: `scripts/tests/test-r493-targeted-fixes.py` asserts the old `--enable-system-bashrc=/etc/bashrc` flag remains, although the local bash port was changed since r493.
- FAIL in supplied baseline: `scripts/tests/test-r480-updater-resilience.py` expectation about default update selection conflicts with current policy. Neither failure is claimed caused/fixed by the r495 edits; they require updating tests or product policy after investigation.

## Still requires action (unclosed tracker areas)

- **High:** Live rebuilds of NVIDIA + NVIDIA-32 (transactional install/version matching), rollback and test in VM; actual pkgmk `-if`/`-uf` behavior under dedicated build user, and source/work cache cleanup including failed builds and `-kw` retention.
- **High:** Kernel-aware versioned footprint validator with preserved boot fallback, protected migration, headers/glibc sequencing, actual boot checks and ISO tests.
- **Normal:** Upstream version/provider reliability and the six unverified ports, optional source prefetch, all historical desktop/installer/printer/graphics/ports audit tasks and their user acceptance tests.
- **Process:** Reconcile and consolidate existing tracker backlog; do not check off tasks based only on offline source changes.
