# BFSOS script audit — r358 — 2026-09-30

This audit works the r356 repository/script-maintenance tracker against the 0.9.0 source tree. The goal is to keep only maintained utilities, remove revision/legacy clutter, move canonical helpers under `scripts/`, and make the remaining tools match the GitHub/SourceForge project layout.

## Removed as obsolete or superseded

| Path | Decision | Reason |
|---|---|---|
| `cleanup-github.sh` | DELETE | One-off repository cleanup helper; obsolete after the GitHub migration and current `.gitignore`/project hygiene. |
| `update_pkgs.sh` | DELETE | Unsafe old mass-edit helper that rewrote every Pkgfile header and inserted placeholder text. Superseded by maintained audit/update tooling. |
| root `version-check.sh` | DELETE | Duplicate/stale copy. Canonical host checker is `scripts/version-check.sh`. |
| root `Pkgfile` | DELETE | Accidental stale `mesa-32` recipe outside the ports tree. |
| `scripts/Pkgfile` | DELETE | Stale generic template containing placeholder text and old `build()` conventions. `gentemplate.sh` now emits the maintained starter directly. |
| `scripts/repgen.sh` | DELETE | Legacy HttpUp repository generator with obsolete collection names (`extra`, `multilib`). BFSOS collections are Git-backed. |
| `scripts/gentrigger.sh` | DELETE | Unreferenced inherited trigger generator tied to footprint scanning and old package trigger conventions. No current BFSOS caller. |
| `scripts/update.sh` | DELETE | Unreferenced inherited cache-update helper; current package hooks/system integration own these actions. |
| `scripts/revdep.sh` | DELETE | Unreferenced duplicate of functionality provided by maintained `prt-utils`/`revdep`. |
| `scripts/bfs-publish-sourceforge-v4.sh` | DELETE | Revision compatibility wrapper; canonical publisher is `scripts/bfs-publish-sourceforge.sh`. |

## Renamed to remove historical revision names

| Old path | New path | Decision |
|---|---|---|
| `scripts/bfs-r243-source-tests.sh` | `scripts/bfs-source-tests.sh` | KEEP/RENAME — useful aggregate source/static regression suite. |
| `scripts/bfs-r243-runtime-check.sh` | `scripts/bfs-runtime-check.sh` | KEEP/RENAME — useful read-only installed-system diagnostics. |

Historical tracker documents may still mention the old names as history; maintained documentation uses the canonical new names.

## Updated scripts

| Script | Decision / work |
|---|---|
| `scripts/version-check.sh` | UPDATE — synchronized with LFS 13.1-systemd minimums and functional checks; added BFSOS bootstrap/ISO prerequisites and actionable summary/exit status. |
| `scripts/gentemplate.sh` | UPDATE — confirmed as the canonical new-port/Pkgfile generator; added help, safer name/version parsing, optional name override, no-overwrite protection, BFSOS metadata header, and generic-build guidance. |
| `scripts/bfs-update-ports.sh` | UPDATE — removed stale Codeberg SSH selection; GitHub is authoritative. |
| `scripts/git-update-bfsos.sh` | UPDATE — no longer deletes `.footprint`/`.signature` integrity metadata; only obsolete HttpUp state is auto-cleaned. |
| `scripts/bfs-sync-ports.sh` | UPDATE — accepts `BFSOS_REPO_ROOT` instead of assuming only `$HOME/BFSOS`. |
| `scripts/bfs-home-migrate.sh` | UPDATE — stale BFS-Linux comment/branding corrected to BFSOS. |
| `scripts/bfs-publish-website-sourceforge.sh` | NEW — dry-run-first SourceForge Project Web publisher for the static `website/` tree. |

## Retained maintainer/runtime tools

The following remain maintained because they have a distinct current BFSOS role:

- `bfs-auth-stack-check.sh` — authentication/PAM runtime validation;
- `bfs-build-iso.sh` — canonical ISO builder;
- `bfs-core-port-audit.py` — core-port structure/build audit;
- `bfs-desktop-integration-check.sh` — desktop/logind/PipeWire/runtime sanity checks;
- `bfs-home-migrate.sh` — home backup/migration utility;
- `bfs-maintained-port-updater.py` — controlled maintained-port updater tooling;
- `bfs-maintained-port-version-audit.sh` — version-audit runner;
- `bfs-ports-static-audit.sh` — static package-policy audit;
- `bfs-ports-tree-audit.sh` — complete ports-tree audit;
- `bfs-publish-sourceforge.sh` — canonical release publisher;
- `bfs-release-static-audit.sh` — release source/static audit;
- `bfs-runtime-check.sh` — read-only installed-system diagnostics;
- `bfs-source-tests.sh` — broad source/regression runner;
- `bfs-sync-compat32.py` — native/compat-32 synchronization;
- `bfs-sync-ports.sh` — copy installed maintained ports back to the checkout for review;
- `bfs-trust-check.sh` — CA/NSS/p11-kit trust sanity check;
- `bfs-update-ports.sh` — pull/update the Git-backed BFSOS checkout;
- `bfs-xorg-audit.py` — X.Org audit tooling;
- `checkupdate.py` + `checkupdate.sh` — provider-aware upstream version checking;
- `chroot.sh` — standalone target mount/chroot helper;
- `gentemplate.sh` — canonical starter-port generator;
- `git-update-bfsos.sh` — maintainer Git commit/push helper;
- `install-bfs-menu-current.sh` — canonical installer;
- `multilibvercheck.sh` — tested wrapper around compat-32 synchronization;
- `version-check.sh` — canonical host-requirements checker.

## Test tree

All files under `scripts/tests/` remain test/regression assets. Revision numbers in test filenames identify the regression they protect and are therefore intentionally retained; unlike executable product scripts, they are not obsolete merely because the project revision advanced.

## Policy notes discovered during the audit

- GitHub is the authoritative BFSOS source/ports/issue location; SourceForge is the release and Project Web host.
- HttpUp `REPO` state is legacy for BFSOS-owned collections and should not be regenerated by current maintainer scripts.
- `.footprint` and `.signature` are package integrity metadata. Generic Git helpers must not silently delete them.
- `gentemplate.sh` creates a starter recipe only. A generated Pkgfile still requires dependency, build, payload, integrity, and runtime review.
- Historical docs are not rewritten merely to hide old script names/Codeberg references; maintained source and current documentation are clean.
