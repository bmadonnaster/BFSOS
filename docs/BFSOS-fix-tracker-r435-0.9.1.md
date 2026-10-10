# BFSOS Fix Tracker — r429
Updated: 2026-10-09

## r429 — CPU-aware parallelism for port update scanning and description refresh

### [ ] OPEN / UPDATER PERFORMANCE — use available logical processors for version-check scanning

The updater currently runs about 10 concurrent version-check jobs while processing the full ports tree (approximately 1,290 ports). Determine the existing worker setting and replace the hardcoded default with a CPU-aware default based on `nproc` (available logical CPUs), while retaining an explicit environment or CLI override to lower concurrency when desired.

Required behavior:
- Apply CPU-aware concurrency to independent **version checks / port scan jobs**, not to simultaneous package builds or the `pkgmk` compiler parallelism setting.
- Default to the number of available logical CPUs (`nproc`), with a sane minimum of 1 and a user-configurable override; respect existing controls rather than introducing conflicting settings.
- Ensure parallel scans retain correct deterministic results, logging, error reporting, cancellation and rate-limit/error handling; avoid overloading upstream services.
- Verify effective worker count on bare-metal BFSOS (up to 32 logical CPUs available) and on a smaller or affinity-restricted environment.
- Document the setting and how to override it.

### [ ] OPEN / DESCRIPTION UPDATER PERFORMANCE — apply the same CPU-aware worker policy

Audit the independent port **description-update / description-refresh** workflow and use the same processor-count-based default for its concurrent update jobs, with an explicit override. Keep this separate from build parallelism; preserve output consistency, ordering where needed, source throttling, retry/error handling, and reporting.

Acceptance: scan and description update each automatically scale to available logical CPUs by default, honor overrides, and pass a small controlled test plus a full-tree run without missing or duplicating ports.

---

# BFSOS Fix Tracker r428 — 0.9.1.1
Updated: 2026-10-09

## [ ] Plasma / KDE meta-package: include KAccounts Integration

**Priority:** Medium — target the next BFSOS release. **Status:** Open / requires dependency audit and installation test.

**Observed:** `plasma/kaccounts-integration` was not installed on the existing BFSOS desktop; direct `prt-get depinst kaccounts-integration` exposed an uninstalled account integration dependency chain. The package declares `kcmutils kirigami kwallet libaccounts-qt qcoro qt6 signond`, but CMake cannot find `AccountsQt6` or `SignOnQt6`. `libaccounts-qt` and `signond` ports exist, but were not installed. `libaccounts-glib` initially fails its Meson setup because `-Dtests=false` is unrecognized; this build issue is being debugged separately.

**Required work:**

- Inspect `plasma-meta`, any KDE applications meta-package, and relevant installer desktop selections; establish which should include `kaccounts-integration` (avoid forcing it onto unrelated minimal installations).
- Add the dependency to the appropriate meta-package Pkgfile(s) and bump their release numbers.
- Validate the chain `libaccounts-glib` → `libaccounts-qt` plus `signond` → `kaccounts-integration`; repair build recipes as needed without masking errors.
- Confirm Qt6 CMake exports (`AccountsQt6`, `SignOnQt6`) and runtime integration are installed correctly.
- Audit companion KDE/Plasma integration packages for other missing or incorrectly assigned meta dependencies.
- Test a clean `prt-get depinst` of the selected meta-package and verify account integration appears without manual installation.
- Keep build failures, staging blockers, and absent dependency metadata distinguished in the update report.

**Acceptance:** Fresh intended KDE/Plasma meta-package installation pulls in and builds KAccounts Integration with its required Qt6 account libraries; no manual `prt-get depinst kaccounts-integration` is required.

---

# Previous tracker state — r427 and earlier (preserved below)

# BFSOS Fix Tracker r424 — 0.9.1

## Live updater fixes carried forward

The following updater issues were identified during live BFSOS testing and are carried forward as completed behavior in the current updater work:

- [x] Kernel-only maintenance scans only the BFSOS kernel ports instead of the entire Core tree.
- [x] `linux-headers` follows the selected BFSOS `linux-lts` target only; generic upstream discovery must never move headers to a different kernel series.
- [x] Interactive no-update scans return to the main menu instead of exiting.
- [x] Core fallback checks no longer appear frozen: CRUX/Arch fallback work is bounded, concurrent, and reports progress.
- [x] WebKitGTK sibling ports are treated as distinct BFSOS targets even when they share the same upstream project.
- [x] `gnome-backgrounds` candidates must be validated against the real GNOME release cache so nonexistent releases are not proposed.
- [x] FAudio 26.10 native build uses `cmake -S .` after `pkgmk` enters the extracted source directory.

---

## Port updater: preserve package provenance and reject false fallback matches

### Bug

The fallback chain currently treats a matching package name in a secondary distribution as enough evidence to compare versions.

Live Core testing exposed this with:

```text
core/signify  0.14 -> 33  [Arch reference; REVIEW]
```

BFSOS carries the CRUX-style/portable `signify` package at version `0.14`. Arch also has a package named `signify`, but its `33` version scheme is not safely comparable to the BFSOS/CRUX lineage.

The updater therefore produced a false candidate solely because the package names matched.

### Required behavior

- Treat the full BFSOS port path as the update target identity.
- Preserve known package provenance/origin when available.
- For CRUX-origin ports, use CRUX as the first fallback reference.
- A newer Arch version may be considered even when CRUX is present, but only when the Arch package is positively verified to be the same upstream project and uses a comparable version lineage.
- Do not allow an Arch package with the same name to override or reinterpret a CRUX-origin package unless upstream identity is verified.
- A matching package name alone is not enough to establish package identity.
- Before comparing versions from a secondary distribution, verify that both packages refer to the same upstream project.
- Also verify that the reported versions belong to a compatible version lineage/numbering scheme.
- If upstream identity or version lineage cannot be established confidently, do not emit an `UPDATE` or `REVIEW` candidate.
- Instead, log the result as unmatched/ambiguous for diagnostics.
- Never compare obviously incompatible version schemes merely because one parses as numerically newer.

### Expected behavior for live Core examples

#### `signify`

Starting state:

```text
BFSOS: core/signify 0.14
CRUX:  signify 0.14
Arch:  signify 33
```

Expected result:

```text
core/signify 0.14
  no update candidate
  Arch same-name result rejected unless same upstream identity
  and a comparable version lineage are proven
```

The Arch `33` result must not appear in the update checklist based on package name alone.

#### `dialog`

Starting state:

```text
BFSOS: 1.3-20260721
CRUX:  1.3-20260721
Arch:  1.3_20260721
```

Expected result:

```text
no update candidate
```

The updater must normalize equivalent separators/encodings before comparing versions so `1.3-20260721` and `1.3_20260721` are treated as the same release.

#### `f2fs-tools`

Starting state:

```text
BFSOS: 1.16.0
CRUX:  1.16.0
Arch:  1.17.0
```

Expected result:

```text
1.17.0 may be offered as REVIEW
only if Arch package identity is verified against the same upstream
f2fs-tools project used by BFSOS
```

This is an example where Arch is allowed to provide a newer version than CRUX once package identity is proven.

### Fallback policy

For a BFSOS port not mapped to LFS/BLFS/MLFS/GLFS:

```text
CRUX lookup
   |
   +--> CRUX package found
   |       |
   |       +--> newer than BFSOS
   |       |       -> CRUX candidate may be offered
   |       |
   |       +--> same/older than BFSOS
   |               -> Arch may still be checked for a newer release
   |                  ONLY after package identity is positively verified
   |
   +--> CRUX package not found
           |
           v
      Arch identity verification
           |
           +--> verified same upstream project
           |    + compatible version lineage
           |        -> compare versions conservatively
           |
           +--> ambiguous / different project /
                incompatible version lineage
                    -> no candidate
```

A newer Arch version is allowed to supersede a same/older CRUX result when the Arch package is verified to be the same upstream project and its version is directly comparable.

Generic direct-upstream discovery remains the final conservative fallback and must still obey existing package-family/version-lock rules.

### Identity verification

The updater should use as much of the following as is available:

- canonical upstream project URL/domain;
- source archive host and path;
- repository owner/project pair for GitHub/GitLab/etc.;
- package metadata URL;
- known BFSOS alias/provenance mapping;
- source filename/project stem;
- existing explicit package-family mapping.

Exact-name matching alone must never be considered sufficient proof.

### Regression coverage

Add regression tests for all of the following:

1. **CRUX-origin `signify` false match**

   ```text
   BFSOS: signify 0.14
   CRUX: signify 0.14
   Arch: signify 33
   ```

   Expected: no candidate.

2. **Verified Arch fallback**

   A synthetic BFSOS port absent from CRUX but present in Arch with the same verified upstream project and a compatible newer version.

   Expected: one conservative `REVIEW` candidate.

3. **Same name, different project**

   Two unrelated packages share a package name across BFSOS and Arch.

   Expected: no candidate; diagnostic says identity could not be verified.

4. **Same project, incompatible version lineage**

   Same upstream project is found, but the downstream package uses a non-comparable epoch/date/revision scheme.

   Expected: no candidate unless an explicit normalization rule exists.

5. **CRUX + newer verified Arch**

   If CRUX provides the same/older version as BFSOS and Arch provides a newer version of the positively verified same upstream project, Arch may produce a conservative `REVIEW` candidate.

6. **Separator-equivalent versions**

   ```text
   BFSOS: 1.3-20260721
   Arch:  1.3_20260721
   ```

   Expected: no candidate.

### Diagnostic logging

Add clear trace rows such as:

```text
core/signify    provenance=CRUX
core/signify    CRUX=0.14 same lineage
core/signify    Arch=33 rejected: incompatible/unverified version lineage
core/signify    no candidate
```

For an accepted Arch fallback:

```text
opt/example     not found in CRUX
opt/example     Arch identity verified: github.com/vendor/example
opt/example     1.2.3 -> 1.2.4 REVIEW
```

### Status

- [x] Preserve fallback provenance through full BFSOS port-path identity and source-derived upstream identity checks.
- [x] Add upstream identity comparison helper using source host/repository/project information.
- [x] Add compatible-version-lineage guard for secondary distribution fallbacks.
- [x] Allow newer Arch fallback only after positive same-upstream identity verification.
- [x] Add separator/version-normalization so equivalent releases such as `1.3-20260721` and `1.3_20260721` compare equal.
- [x] Reject `core/signify 0.14 -> 33` from the candidate list when the numbering lineage is incompatible.
- [x] Permit `core/f2fs-tools 1.16.0 -> 1.17.0` as REVIEW when Arch identity is verified against the same upstream project.
- [x] Add regression coverage for verified and rejected Arch fallback cases.
- [x] Add diagnostic logging for accepted identity matches and rejected ambiguous/incompatible fallback matches.

---


## r383 implementation notes

The r382 fallback/provenance work is now implemented in `scripts/bfs-port-updater.py`.

- Version comparison now normalizes cosmetic `-` / `_` separators, preventing the false `dialog 1.3-20260721 -> 1.3_20260721` update.
- Arch lookup now retains the Arch package's upstream URL instead of returning only `pkgver`.
- BFSOS source URLs are converted into conservative upstream project identities (GitHub owner/project, GitLab owner/project, kernel.org repository path, or same-host project stem).
- Arch candidates are accepted only when that identity matches the BFSOS port and the candidate uses a comparable version lineage.
- A bare-generation candidate such as `signify 33` is rejected against dotted BFSOS `0.14` even if a same-name/same-project package is discovered.
- `f2fs-tools 1.17.0` remains eligible as `REVIEW` when its Arch upstream URL verifies against the same kernel.org `f2fs-tools` repository used by BFSOS.
- CRUX remains the first fallback. If CRUX is same/older, the updater may still consider a newer verified Arch release.
- Accepted/rejected Arch identity decisions are written into `# TRACE:` diagnostics.
- Existing concurrent/bounded CRUX/Arch fallback lookup behavior remains intact.

## Validation

After implementation:

```bash
cd ~/BFSOS

python3 -m py_compile scripts/bfs-port-updater.py

python3 scripts/tests/test-r377-port-updater-fixes.py
```

Also run the newer updater regression suite that contains the kernel/fallback/sibling-port cases.

Then run an interactive Core scan and verify:

```text
core/signify 0.14 -> 33
```

does **not** appear in the checklist.

The Core scan must still find legitimate unmapped updates, and the fallback phase must remain bounded and visibly make progress.

---

## Vulkan/SPIR-V stack: automatic all-or-nothing coordinated update

### Goal

The maintainer updater must never leave Vulkan/SPIR-V SDK coordination up to manual checklist selection.

The updater should offer a Vulkan SDK update only when the **entire BFSOS version-locked stack required for the target SDK release is available and internally consistent**. When that condition is met, the updater should automatically select the complete stack and process it in the required dependency/build order.

If the complete target stack is not available, **none of the Vulkan/SPIR-V members should be selected for update**.

### Current locked family

The existing `vulkan-sdk` group includes:

```text
opt/spirv-headers
opt/spirv-tools
compat-32/spirv-tools-32

opt/vulkan-headers
opt/vulkan-loader
compat-32/vulkan-loader-32

opt/vulkan-tools
compat-32/vulkan-tools-32

opt/vulkan-utility-libraries
compat-32/vulkan-utility-libraries-32

opt/volk
compat-32/volk-32

opt/vulkan-validation-layers
compat-32/vulkan-validation-layers-32
```

Only members that actually exist in the BFSOS tree should be considered required, but every existing member of the lock group must participate in the coordinated target.

### Required discovery behavior

When one or more members indicate a newer Vulkan SDK generation:

1. Determine the intended common target SDK version.
2. Resolve every existing member of the BFSOS `vulkan-sdk` group against that same target.
3. Verify that every member has a valid source/release candidate for that exact target.
4. Verify native and compat-32 members agree on the same SDK target.
5. Do not mix releases from different SDK generations.
6. Do not substitute a merely newer independent component version when it is not part of the common SDK release.
7. If any required member is missing, unavailable, unverifiable, or targets a different SDK release:
   - suppress the entire coordinated update,
   - leave all Vulkan/SPIR-V members OFF,
   - emit a clear diagnostic describing which member blocked the group.
8. Only when the whole group validates:
   - emit the complete Vulkan/SPIR-V update set,
   - mark the complete group selected automatically,
   - treat it as one coordinated transaction.

### Selection policy

The maintainer must not be required to manually select every Vulkan/SPIR-V component.

Expected checklist behavior:

```text
complete validated Vulkan SDK target available
    -> every required group member appears selected ON automatically

incomplete or mixed target
    -> no group member is selected for update
       and preferably the incomplete candidates are suppressed from the normal
       update checklist in favor of one clear diagnostic
```

A user manually unchecking one member must not permit the rest of the group to apply. Before apply/build, the updater must revalidate that the complete group is still selected.

### Apply/build transaction guard

`apply_selected()` must reject any partial `vulkan-sdk` selection, even if a partial set reaches it because of a UI bug or future code change.

The group should be treated as an all-or-nothing transaction:

```text
all required members selected
    -> apply coordinated Pkgfile updates

partial selection
    -> refuse entire Vulkan/SPIR-V transaction
       modify nothing in the group
```

Where practical, stage all Pkgfile edits first and only proceed once every member can be prepared for the same target.

### Required dependency/build order

Use dependency order rather than arbitrary alphabetical/tree order.

At minimum, coordinate the stack in this order:

```text
1. SPIR-V-Headers
2. SPIR-V-Tools
3. SPIR-V-Tools 32-bit

4. Vulkan-Headers

5. Vulkan-Loader
6. Vulkan-Loader 32-bit

7. Vulkan-Utility-Libraries
8. Vulkan-Utility-Libraries 32-bit

9. Volk
10. Volk 32-bit

11. Vulkan-Validation-Layers
12. Vulkan-Validation-Layers 32-bit

13. Vulkan-Tools
14. Vulkan-Tools 32-bit
```

The exact ordering should be dependency-driven if BFSOS metadata requires a more precise sequence, but headers must precede consumers and native libraries should be available before their compat-32 counterparts where the 32-bit build depends on the native SDK metadata/tools.

### Failure behavior

If any member fails to update or build:

- stop advancing dependent members;
- do not continue blindly through the rest of the SDK stack;
- report exactly which member failed;
- retain enough state for the maintainer to fix and retry the coordinated group;
- do not declare the Vulkan SDK update successful until every required member succeeds.

If rollback support is added later, the Vulkan SDK group is a strong candidate for transactional rollback. For now, fail-fast coordinated execution is required.

### Regression coverage

Add tests for:

1. **Complete target available**
   - every existing group member resolves to the same SDK version;
   - whole group is emitted;
   - whole group defaults ON;
   - build order matches dependency order.

2. **One compat-32 member missing**
   - no partial update is allowed;
   - whole group held/suppressed;
   - diagnostic names the missing member.

3. **Mixed SDK versions**
   - some members target `1.4.357.0`, others `1.4.363.0`;
   - whole group rejected.

4. **Manual partial deselection**
   - apply layer refuses the partial group;
   - no group member is modified.

5. **Build failure in middle of stack**
   - dependent later members are not built;
   - retry state retains the failed coordinated target.

6. **Current stack**
   - no candidate if every member already matches the selected SDK generation.

### Status

- [x] Discover one common Vulkan SDK target across all existing lock-group members when any Vulkan member is scanned; the scan expands to existing members in other trees.
- [x] Require complete target availability before automatically approving any Vulkan/SPIR-V SDK update; incomplete/mixed groups are held REVIEW/OFF.
- [x] Automatically select the complete validated stack.
- [x] Prevent manual partial selection from reaching apply.
- [x] Add all-or-nothing selection guard in `apply_selected()` before any updater handoff.
- [x] Apply/update version-locked Pkgfiles transactionally as one coordinated group; selected group port directories are snapshotted and the whole group is restored if any member is rejected during apply.
- [x] Build the Vulkan/SPIR-V group in dependency order.
- [x] Stop/mark later coordinated Vulkan members BLOCKED after the first group build/install failure.
- [x] Preserve coordinated retry state: `BLOCKED:` rows whose target Pkgfile still matches remain visible in the Retry menu and retries run in group build order.
- [x] Add synthetic complete-group and partial-selection regression coverage for the primary updater.


---

## Development-book authority policy: MLFS only where explicitly mapped

### Bug

The updater currently treats any package found in the LFS-family books as an authoritative automatic update. A match in BLFS, LFS, or GLFS can therefore become `UPDATE`/ON with the reason `authoritative development-book version` even when that package is not part of the explicitly maintained BFSOS-to-MLFS mapping.

### Required policy

Only ports explicitly mapped by BFSOS to the **MLFS development book** are authoritative.

```text
explicit BFSOS -> MLFS DEV mapping
        |
        +--> MLFS DEV is authoritative
        +--> version may default ON as UPDATE
        +--> MLFS patch policy may be applied
        +--> never downgrade if BFSOS is already newer
```

For everything else:

```text
LFS / BLFS / GLFS match
        |
        +--> reference information only
        +--> never automatically authoritative
        +--> never default ON solely because a book is newer
        +--> continue normal verification/reference policy
                |
                +--> CRUX
                +--> verified Arch
                +--> direct upstream
                +--> conservative REVIEW
```

A BLFS/LFS/GLFS version can still be a valid update lead; it simply must not bypass normal package identity, source validation, lineage, and review rules.

### Live Opt examples

These may be valid updates, but they must not be labeled authoritative merely because BLFS carries them:

```text
opt/cairo            1.18.4  -> 1.18.6
opt/glib-networking  2.80.1  -> 2.90.0
opt/libsecret        0.21.7  -> 0.21.8.2
opt/lmdb             1.0.1   -> 1.0.2
opt/nodejs           24.21.0 -> 26.10.0
```

### Status

- [x] Restrict automatic development-book authority to MLFS DEV membership; non-MLFS LFS-family books no longer create automatic candidates.
- [x] Keep LFS/BLFS/GLFS indexes available as reference providers only.
- [x] Never emit `authoritative development-book version` for LFS/BLFS/GLFS reference-only ports.
- [x] Do not auto-select reference-only book candidates.
- [x] Preserve the no-downgrade rule when BFSOS is already newer.
- [x] Keep kernel policy independent of the LFS-family book logic.
- [x] Add synthetic regression proving BLFS/LFS/GLFS matches are REVIEW/reference while MLFS DEV remains automatic.
- [x] Add synthetic regression proving MLFS DEV packages still default ON; existing MLFS patch handling remains in the authoritative path.

---

## GNOME release validation must be independent of generic provider choice

### Bug

`gnome-backgrounds` was again changed from `51.0` to nonexistent `51.0.1`. The current protection only validates the target when the generic checker happens to report `provider == gnome-cache`, so a bad book target can still slip through.

### Required behavior

For every port in `GNOME_CACHE_VALIDATED_BOOK_PORTS`:

1. Resolve the proposed target version.
2. Independently consult the GNOME release cache/source index for that package.
3. Confirm the exact target tarball/version exists.
4. Only then allow the candidate to proceed.
5. If GNOME does not publish the exact target, reject it, leave the BFSOS port unchanged, and log the mismatch.

Expected example:

```text
BLFS: gnome-backgrounds 51.0.1
GNOME upstream: latest real tarball 51.0

result:
  reject 51.0.1
  keep BFSOS 51.0
```

### Status

- [x] Remove the `provider == gnome-cache` dependency from protected GNOME validation.
- [x] Validate the exact protected GNOME target URL before creating the candidate.
- [x] Reject protected GNOME candidates before apply/build when the exact upstream target is absent.
- [x] Add synthetic regression for provider-independent `gnome-backgrounds 51.0 -> 51.0.1` rejection.

---

## Maintained updater: source-template migration instead of FAILED/REVIEW

### Bug

Several valid Opt updates were discovered correctly, but the maintained apply/rewrite stage returned `FAILED/REVIEW` because the current Pkgfile source template could not safely produce the new release URL.

Live examples:

```text
opt/cairo            1.18.4  -> 1.18.6
opt/glib-networking  2.80.1  -> 2.90.0
opt/libsecret        0.21.7  -> 0.21.8.2
opt/lmdb             1.0.1   -> 1.0.2
opt/nodejs           24.21.0 -> 26.10.0
```

The first three were manually corrected and built successfully after fixing their source templates.

### Required behavior

The updater must distinguish a bad candidate from a valid candidate whose current source template is stale or inadequate. For a known-safe source family, migrate the template instead of immediately returning `FAILED/REVIEW`.

Known migrations/guards:

- **cairo:** migrate stale mirror URLs to `https://cairographics.org/releases/$name-$version.tar.xz`.
- **glib-networking:** do not hardcode an old GNOME series directory such as `2.80`; derive the series from the target version.
- **libsecret:** handle multi-component versions such as `0.21.8.2` while still using the GNOME `0.21` series directory.
- **lmdb:** preserve/validate the `LMDB_$version` GitHub tag/archive form.
- **nodejs:** the standard `https://nodejs.org/dist/v$version/node-v$version.tar.xz` form is already dynamic; a major-series jump should be validated rather than rejected merely because the major changed.

### Status

- [x] Add target-source derivation helpers for cairo, glib-networking, libsecret, LMDB, and Node.js and pass the derived source to the maintained updater.
- [x] Primary updater derives target URLs and the maintained updater now applies the supplied target source before final remote validation.
- [x] Candidate target sources survive the handoff into `bfs-maintained-port-updater.py`; the staged Pkgfile is validated and still committed last.
- [x] Candidate release resets remain `1` on version changes; same-version MLFS patch changes retain release-bump behavior.
- [x] Non-MLFS and unknown-source candidates remain REVIEW/OFF; source derivation only rewrites known families or literal current-version URLs.
- [x] Maintained-updater `NEEDS-REVIEW` reasons are propagated back into the primary updater result table instead of collapsing to generic `FAILED/REVIEW`.
- [x] Added synthetic handoff regressions for GNOME-series migration, multi-source preservation, ambiguity refusal, and detailed failure-reason propagation.

---

## Brasero 3.12.4: stale patch and Meson migration

### Live result

Brasero `3.12.4` is a valid update, but the old port carried both a version-specific patch and obsolete Autotools-style options:

```text
brasero-3.12.3-upstream_fixes-1.patch
--enable-compile-warnings=no
--enable-cxx-warnings=no
--enable-nautilus
```

After removing the old patch, the 3.12.4 source downloaded correctly. The build then failed because pkgmk detected Meson and passed those old `--enable-*` options into `meson setup`.

### Status

- [ ] Keep holding version-specific old patches for review unless a replacement is known.
- [ ] Detect build-system changes when moving to a new version.
- [ ] Never pass Autotools `--enable-*`/`--disable-*` switches blindly into Meson.
- [ ] Prefer removing obsolete options and re-detecting valid Meson options.
- [ ] Add a Brasero 3.12.3 -> 3.12.4 regression.

---

## Browser coverage: known stale browsers must not disappear silently

During Opt testing, known-outdated browser ports did not appear as candidates even though there were no fetch errors.

### Status

- [x] Add explicit Mozilla product-details and Chromium Dash fallback providers in the primary updater.
- [~] Browser fallback now runs even when generic discovery misses an update; changing raw `checkupdate.py` status text requires that script, which was not included.
- [x] Firefox/Chromium receive a direct provider fallback before the updater concludes there is no newer version.
- [~] Successful browser fallback is traced; raw provider failure diagnostics in `checkupdate.py` still require that script.
- [~] Provider code added; live/network regression should be run in the BFSOS tree.

---

## NVIDIA native/compat-32 lock pair

If native and compat-32 NVIDIA driver ports both exist, they must not drift to different driver versions.

### Status

- [x] Discover `opt/nvidia` + `compat-32/nvidia-32` as a coordinated version pair; `nvidia-fb-32` remains an intentionally separate fallback branch.
- [x] Only approve an automatic NVIDIA pair update when the same target is available for both existing ports.
- [x] Auto-select both members together after common-target validation.
- [x] Apply/build native first, then compat-32.
- [x] Refuse partial or mixed NVIDIA selection at the same group guard used for other locked families.
- [x] Add synthetic NVIDIA pair/group-order regression coverage.


---

## Package update ownership collision: same-package files must not block upgrades

### Live failure

A normal package update failed while upgrading:

```text
fribidi 1.0.16-2 -> 1.0.17-1
```

`prt-get update fribidi` built/found the new package successfully, but `pkgadd` stopped on:

```text
usr/share/man/man1/fribidi.1.gz
pkgadd: listed file(s) already installed (use -f to ignore and overwrite)
```

The first suspicion is that the conflicting path is already owned by the installed `fribidi` package itself. If so, a package replacing one of its own files during an upgrade must not be treated as a foreign-file collision.

### Required diagnosis

Before changing package-manager behavior, identify ownership of every collision:

```bash
pkginfo -o /usr/share/man/man1/fribidi.1.gz
prt-get fsearch fribidi.1.gz
```

The update path must distinguish:

```text
existing file owned by package being upgraded
    -> safe replacement case

existing file owned by another package
    -> real package ownership conflict

existing file not recorded in package database
    -> unmanaged/stale filesystem collision
```

### Required behavior

For an update from package `P-old` to `P-new`:

1. Compare every incoming pathname against the installed package database.
2. If the pathname is already owned by **the same package being upgraded**:
   - allow replacement automatically;
   - do not require the maintainer to pass a blanket force flag;
   - keep ownership assigned to the new version of the same package.
3. If the pathname is owned by **another package**:
   - stop the update;
   - report the conflicting pathname and owning package;
   - do not overwrite automatically.
4. If the pathname exists but has **no package owner**:
   - stop or place the update into explicit REVIEW;
   - report it as an unmanaged/stale-file collision.
5. Never solve this globally by adding unconditional `pkgadd -f` to every update. Force-overwrite is only safe after ownership has been established.

### prt-get/pkgadd integration

Investigate whether the bug is in:

- `prt-get update` invoking `pkgadd` with the wrong update/replace mode;
- `pkgadd` failing to exclude files owned by the package version being replaced;
- stale/incorrect package database ownership records;
- path normalization differences between the old and new package manifests.

The preferred fix belongs at the package-manager/update layer rather than in individual ports such as `fribidi`.

### Diagnostics

On failure, print something equivalent to:

```text
PACKAGE COLLISION:
  updating: fribidi 1.0.16-2 -> 1.0.17-1
  path: /usr/share/man/man1/fribidi.1.gz
  current owner: fribidi

same-package replacement detected; allowing update
```

For a real conflict:

```text
PACKAGE COLLISION:
  updating: package-a
  path: /usr/bin/example
  current owner: package-b

update refused: path belongs to another installed package
```

### Regression coverage

- [ ] Same-package file replacement succeeds during a version update.
- [ ] Different-package ownership collision still fails safely.
- [ ] Unowned pre-existing file is reported and not silently overwritten.
- [ ] Ownership database is correct after successful replacement.
- [ ] `prt-get update` does not require a global force-overwrite mode for ordinary same-package upgrades.
- [ ] Add a regression reproducing the `fribidi.1.gz` update case.

### Status

- [ ] Confirm current owner of `/usr/share/man/man1/fribidi.1.gz`.
- [ ] Determine whether fault is in `prt-get`, `pkgadd`, or stale package metadata.
- [ ] Implement same-package replacement handling.
- [ ] Preserve hard failure for cross-package collisions.
- [ ] Add regression tests.

---

## r387 implementation notes

The uploaded primary updater has been revised for the tracker items that can be implemented safely in `bfs-port-updater.py` alone.

Implemented in r387:

- MLFS DEV is the only LFS-family automatic authority. LFS/BLFS/GLFS are reference-only and produce REVIEW/OFF candidates after the normal CRUX/verified-Arch/direct-upstream path.
- Protected GNOME targets are validated against the exact official GNOME tarball URL independent of the generic provider. This closes the `gnome-backgrounds 51.0.1` hole.
- Known target-source templates are derived for Cairo, glib-networking, libsecret, LMDB, and Node.js; GNOME series handling correctly maps `51.0.1 -> 51` and `0.21.8.2 -> 0.21`.
- Firefox and Chromium have direct fallback version providers so a generic-checker blind spot does not silently hide a known browser update.
- Vulkan/SPIR-V scans expand to the existing lock-group members in other trees, require one complete common target before automatic selection, reject partial manual selection before apply, order builds by dependency, and fail-fast/block later group builds after a failure.

Validated locally with Python syntax compilation and synthetic policy tests for MLFS-vs-BLFS authority, GNOME phantom-release rejection, GNOME series/source derivation, complete Vulkan group auto-selection, and partial Vulkan selection refusal.

Items intentionally **not claimed complete** because their owning source files were not included in this upload:

- `bfs-maintained-port-updater.py`: final Pkgfile source-template rewrite/atomic staging, detailed rewrite failure diagnostics, and automatic Brasero build-option migration.
- `checkupdate.py`: raw `UNVERIFIABLE` reporting/provider diagnostics beyond the new primary-updater browser fallback.
- `prt-get` / `pkgadd` sources and package database: the Fribidi same-package ownership collision cannot be safely fixed from the primary port updater.
- NVIDIA native/compat-32 locking needs the actual BFSOS NVIDIA port names/tree layout before hard-coding or auto-discovering the pair.

The Fribidi tracker item remains diagnostic until ownership is confirmed and the relevant package-manager source is provided. Do not globally force `pkgadd -f`.


---

## Vulkan/SPIR-V coordinated build: fail-fast works, but staged dependency availability still needs handling

### Live result

The coordinated Vulkan/SPIR-V update reached the expected dependency order and stopped safely on the first failed dependent build:

```text
opt/spirv-headers: BUILT
opt/spirv-tools: BUILD FAILED (1)

compat-32/spirv-tools-32: BLOCKED: vulkan-sdk prior build failure
compat-32/vulkan-loader-32: BLOCKED: vulkan-sdk prior build failure
compat-32/vulkan-tools-32: BLOCKED: vulkan-sdk prior build failure
compat-32/vulkan-validation-layers-32: BLOCKED: vulkan-sdk prior build failure
opt/volk: BLOCKED: vulkan-sdk prior build failure
opt/vulkan-headers: BLOCKED: vulkan-sdk prior build failure
opt/vulkan-loader: BLOCKED: vulkan-sdk prior build failure
opt/vulkan-tools: BLOCKED: vulkan-sdk prior build failure
opt/vulkan-utility-libraries: BLOCKED: vulkan-sdk prior build failure
opt/vulkan-validation-layers: BLOCKED: vulkan-sdk prior build failure
```

This confirms the fail-fast/block-later-members part of the coordinated transaction is working.

### Remaining problem

The updater currently performs build-only validation. A package earlier in the coordinated stack can build successfully without being installed into the live system. A later package may therefore still see the old installed headers/libraries/tools instead of the newly built dependency.

This exact pattern was already observed in Core with `python3-vcs-versioning` -> `python3-urllib3`: the dependency package built successfully, but the dependent package failed until the new dependency was installed.

The SPIR-V failure may be the same class of problem, but the `opt/spirv-tools` build log must be checked before declaring the root cause.

### Required behavior

For coordinated build-only validation:

1. Preserve dependency order.
2. Before building a dependent member, determine whether it requires the just-built version of an earlier selected member.
3. If the new dependency is not installed:
   - either stage/install the newly built package into a controlled temporary validation root/environment;
   - or clearly stop and report that build-only validation cannot continue until the prerequisite package is installed.
4. Do not silently classify the dependent port as a bad update when the only issue is that the live system still has the old dependency installed.
5. Do not globally install packages during a supposedly build-only validation pass without an explicit policy/confirmation.
6. Keep the current fail-fast behavior: after a genuine build failure, dependent Vulkan/SPIR-V members remain BLOCKED.

### Diagnostics

The updater should distinguish:

```text
BUILD FAILED: source/build problem
```

from:

```text
BLOCKED: updated prerequisite built but is not installed/staged
```

and from:

```text
BLOCKED: vulkan-sdk prior genuine build failure
```

### Status

- [x] Vulkan/SPIR-V build order begins with SPIR-V-Headers before SPIR-V-Tools.
- [x] A failed SDK member blocks all later dependent members.
- [x] The result screen clearly reports BLOCKED members after the first failure.
- [ ] Inspect the `opt/spirv-tools` failure log and confirm whether this is a stale-installed-dependency problem or a real source/build issue.
- [x] Add dependency-awareness to build-only validation for coordinated update groups.
- [x] Add an explicit prerequisite-install/staging boundary in build-only mode; later coordinated members are BLOCKED instead of falsely failed.
- [x] Avoid false `BUILD FAILED` results caused solely by older installed prerequisites by stopping coordinated build-only validation at the first unstaged prerequisite boundary.
- [x] Add regression coverage for "dependency built successfully but not yet installed" inside the Vulkan/SPIR-V transaction.

---

## TeX Live version normalization: `YYYYMMDD` and `YYYYMMDD-source` are the same release

### Live false positive

The Opt scan still emits:

```text
opt/texlive
20260301 -> 20260301-source
[BLFS DEV reference; REVIEW]
```

This is not a real TeX Live update. The `-source` suffix is part of the source-archive naming convention for the same TeX Live 2026 snapshot/date.

### Required behavior

For TeX Live version comparisons, normalize source-archive suffixes before deciding whether a candidate is newer.

At minimum:

```text
20260301
20260301-source
```

must compare as equivalent.

The normalization must be package-specific or otherwise narrowly scoped so that generic version comparison does not erase meaningful suffixes for unrelated packages.

### Candidate policy

After normalization:

```text
BFSOS: 20260301
BLFS:  20260301-source
```

Expected result:

```text
no update candidate
```

The port must not appear as REVIEW merely because BLFS appends `-source`.

### Status

- [x] Add TeX Live-specific version normalization for `-source`.
- [x] Treat `YYYYMMDD` and `YYYYMMDD-source` as equivalent releases.
- [x] Suppress the false REVIEW candidate from candidate generation when the only difference is TeX Live's `-source` suffix.
- [x] Keep the rule scoped to the `texlive` package so unrelated suffixes retain normal semantics.
- [x] Add regression coverage for `20260301 -> 20260301-source`.


---

## r389 implementation notes

Worked from the uploaded r388 primary updater and tracker.

Implemented in `bfs-port-updater.py`:

- TeX Live comparisons now use package-scoped normalization: `20260301` and `20260301-source` compare as the same release for `texlive` only. This prevents the BLFS `-source` archive suffix from creating a false REVIEW candidate while preserving suffix semantics for every other package.
- Coordinated Vulkan/SPIR-V build-only validation now distinguishes a genuine build failure from the case where an earlier SDK prerequisite built successfully but has not been installed/staged. In build-only mode, after the first newly built coordinated prerequisite, later group members are reported as `BLOCKED: vulkan-sdk updated prerequisite built but not installed/staged` rather than being attempted against the old live SDK and potentially misreported as `BUILD FAILED`.
- `Update + build + install selected` remains the path that can progress through the full coordinated SDK stack on the live system, because each prerequisite is installed before its dependent is built.
- Protected GNOME validation was already provider-independent in the uploaded updater, so the stale tracker checkbox for removing the `provider == gnome-cache` dependency is now marked complete.

Still intentionally open:

- The exact cause of the live `opt/spirv-tools` failure cannot be classified without its build log. r389 prevents future build-only runs from confusing an unstaged prerequisite with a genuine source/build failure, but it does not pretend the already-observed failure has been diagnosed.
- True temporary-root/staged package installation for coordinated build-only validation is not implemented; r389 uses the safe explicit boundary instead of silently modifying the live system.
- Brasero final source/build-option migration still belongs to `bfs-maintained-port-updater.py`, which was not included.
- Fribidi same-package replacement belongs to `prt-get/pkgadd`, which was not included.
- NVIDIA native/compat-32 pairing remains open until the actual BFSOS NVIDIA port names/layout are available; no guessed hard-coded names were added.


---

## Firefox ESR coverage: verify the ESR channel explicitly

### Live Opt result

The current browser scan is behaving correctly for:

```text
firefox
firefox-bin
chromium
```

Those ports are being detected when out of date.

The remaining coverage gap is:

```text
firefox-esr
```

which needs to be checked against Mozilla's ESR channel explicitly.

### Required behavior

Treat `firefox-esr` as an independent BFSOS target:

```text
firefox-esr
    -> Mozilla ESR release channel
    -> never compare against normal Firefox stable
```

Do not infer ESR status from the normal `firefox` port, even though both come from Mozilla.

### Provider requirement

Use Mozilla product-details data with the ESR-specific release value rather than `LATEST_FIREFOX_VERSION`.

Expected behavior:

```text
BFSOS firefox-esr: current=X
Mozilla ESR:       latest=Y
```

If `Y` is newer and comparable:

```text
opt/firefox-esr -> REVIEW candidate
```

If current:

```text
no update candidate
```

If the ESR provider cannot be resolved:

```text
UNVERIFIABLE / explicit provider diagnostic
```

The port must not silently disappear from browser coverage.

### Required diagnostics

Emit a trace line such as:

```text
opt/firefox-esr provider=Mozilla ESR current=X latest=Y candidate=REVIEW
```

or:

```text
opt/firefox-esr provider=Mozilla ESR latest=Y rejected: <exact reason>
```

or:

```text
opt/firefox-esr provider=Mozilla ESR unavailable
```

### Regression coverage

- [x] `firefox` stable detection works in live Opt testing.
- [x] `firefox-bin` stable detection works in live Opt testing.
- [x] Chromium stable detection works in live Opt testing.
- [x] `firefox-esr` uses Mozilla product-details `FIREFOX_ESR` instead of the rapid-release key.
- [x] `firefox-esr` is resolved before generic browser discovery and does not fall through to normal Firefox stable.
- [x] ESR provider failure produces an explicit diagnostic instead of silently disappearing.
- [x] Add synthetic ESR-channel regression coverage, including precedence over a bogus rapid-release generic result.

### Status

- [x] Add an explicit Mozilla ESR provider path for `firefox-esr`.
- [x] Keep `firefox-esr` independent from normal Firefox stable release selection.
- [x] Add ESR-specific provider/current/unavailable diagnostics.
- [x] Add Firefox ESR regression coverage.


---

## libcupsfilters: reject downstream git-snapshot versions for release-tracking ports

### Live Opt result

The updater proposed:

```text
opt/libcupsfilters
2.2.1 -> 2.2.1.r23.gdee3b387
```

The BFSOS port is clearly release-tracking:

```text
version=2.2.1
source=(https://github.com/OpenPrinting/${name}/releases/download/${version}/${name}-${version}.tar.xz)
```

The Arch reference version:

```text
2.2.1.r23.gdee3b387
```

is a downstream git snapshot/revision derived from the 2.2.1 release, not a normal formal upstream release tag.

### Required behavior

When a BFSOS port is release-tracking, a downstream reference must not create a normal update candidate merely because its version string sorts newer if that version is a VCS snapshot.

Recognize common snapshot-style suffixes such as:

```text
.r23.gdee3b387
.rNN.gHASH
.rNN
.gHASH
gitYYYYMMDD
```

when they represent a downstream VCS snapshot layered on top of an existing release.

Expected behavior for this case:

```text
BFSOS: 2.2.1
Arch:  2.2.1.r23.gdee3b387

result:
  no normal update candidate
  diagnostic: downstream snapshot newer than formal release; BFSOS port tracks releases
```

### Scope / safety

Do not globally reject snapshot versions.

A snapshot candidate may still be valid when the BFSOS port itself intentionally tracks VCS snapshots, for example when:

- the port source is a git repository or commit snapshot;
- the current BFSOS version already uses a snapshot-style version;
- the port is explicitly marked/configured as snapshot-tracking.

The rule should be based on the BFSOS port's own source/version policy, not just on the presence of `.rNN.gHASH`.

### Diagnostics

Emit a clear trace entry such as:

```text
opt/libcupsfilters
  Arch=2.2.1.r23.gdee3b387
  rejected: downstream VCS snapshot; BFSOS source tracks formal GitHub releases
```

### Regression coverage

- [x] Release-tracking port at `2.2.1` rejects `2.2.1.r23.gHASH`.
- [x] Snapshot filtering is limited to VCS-style versions; normal formal release candidates remain eligible.
- [x] Snapshot-tracking BFSOS ports remain eligible for newer verified snapshots.
- [x] Snapshot rejection produces a clear diagnostic rather than silently disappearing.

### Status

- [x] Detect release-vs-snapshot tracking from the current version/source shape.
- [x] Reject downstream snapshot-style CRUX/Arch versions for release-tracking ports.
- [x] Keep snapshot candidates allowed for snapshot-tracking ports.
- [x] Add diagnostic logging for rejected downstream snapshot candidates.
- [x] Add regression coverage for the libcupsfilters case.


---

## Maintained updater handoff bug: derived target source is passed in TSV but ignored during apply

### Live Opt diagnosis

Several unrelated valid updates were being reported as:

```text
FAILED/REVIEW
```

even though the target versions themselves are valid and at least some of them build successfully when handled manually.

Examples from the live Opt scan include:

```text
opt/glib-networking  2.80.1 -> 2.90.0
opt/libcap-ng        0.8.5  -> 0.9.6
opt/lmdb             1.0.1  -> 1.0.2
opt/mlt              7.40.0 -> 7.42.0
```

Inspection of the two updater layers identified the common failure path.

### Root cause

`bfs-port-updater.py` already computes a candidate target source and writes it into the selected-update TSV:

```text
status
port
current
latest
provider
reason
source
new_release
patches_json
obsolete_patches_json
```

The `source` column is populated from the candidate's derived/validated target source.

However, `bfs-maintained-port-updater.py` reads that field into:

```python
AuditRow.source
```

but `update_one()` never applies `row.source` to the staged `Pkgfile`.

The maintained updater currently performs:

```text
rewrite version/release
rewrite a few hard-coded coordinated source cases
evaluate proposed Pkgfile
validate changed remote archives
```

without first replacing the primary archive source with the target source supplied by the primary updater.

As a result, a valid version bump can be combined with the old source-template path.

### Concrete example: glib-networking

Current BFSOS source template:

```text
https://download.gnome.org/sources/glib-networking/2.80/glib-networking-$version.tar.xz
```

Target version:

```text
2.90.0
```

The primary updater correctly knows that the target source should use the `2.90` GNOME series directory.

But because the maintained updater ignores `row.source`, it effectively constructs/probes:

```text
https://download.gnome.org/sources/glib-networking/2.80/glib-networking-2.90.0.tar.xz
```

That URL is wrong, so `validate_changed_remote_archives()` rejects the transaction and the primary updater later reports only:

```text
FAILED/REVIEW
```

The same handoff bug can affect any port where the target version requires a source-template migration rather than a literal version substitution.

### Required fix

Before `validate_changed_remote_archives()` runs, the maintained updater must safely apply the supplied target source when `row.source` is present.

Required flow:

```text
candidate selected
    |
    v
rewrite version/release
    |
    v
apply row.source to the primary archive source token
    |
    v
evaluate staged Pkgfile
    |
    v
validate resulting remote archive
    |
    v
continue normal patch/companion checks
    |
    v
commit Pkgfile last
```

### Safety requirements

The maintained updater must not blindly replace arbitrary source entries.

When `row.source` is supplied:

1. Identify the primary remote source archive in the staged Pkgfile.
2. Replace only that primary archive token with the supplied target source.
3. Preserve unrelated secondary sources, patches, local files, signatures, and auxiliary archives.
4. Preserve `alias::URL` source syntax where appropriate.
5. Reject the transaction if the primary source cannot be identified unambiguously.
6. Evaluate the staged Pkgfile after replacement.
7. Validate the resulting target source before committing any change.
8. Keep the existing transactional rule: Pkgfile is written last.
9. Keep checksum invalidation tied to the evaluated before/after source identity.
10. Do not special-case individual packages when the general source handoff can solve them safely.

### Primary updater result reporting

`bfs-port-updater.py` currently converts every helper result that does not contain an exact:

```text
UPDATED <port> ...
```

line into the generic:

```text
FAILED/REVIEW
```

This hides the actual reason emitted by `bfs-maintained-port-updater.py`.

Improve the handoff so the primary updater preserves the helper's per-port `NEEDS-REVIEW` reason in the scan/result output.

Expected result example:

```text
opt/glib-networking
NEEDS REVIEW: rewritten source URL is not reachable:
https://.../2.80/glib-networking-2.90.0.tar.xz
```

rather than only:

```text
FAILED/REVIEW
```

This will make future rewrite failures diagnosable without rerunning the helper manually.

### Regression coverage

Add regression cases for:

1. **glib-networking**
   - current version `2.80.1`;
   - old source directory `2.80`;
   - target `2.90.0`;
   - supplied target source uses `2.90`;
   - expected: Pkgfile source migrates and update succeeds.

2. **libcap-ng**
   - current source uses the old upstream location;
   - candidate supplies a canonical target source;
   - expected: maintained updater applies the supplied source instead of retaining the stale source template.

3. **LMDB**
   - source uses the unusual `LMDB_$version` archive/tag form;
   - supplied target source must survive handoff exactly;
   - expected: valid target source is not rejected because the helper reconstructs an obsolete form.

4. **MLT**
   - version bump requiring a valid release URL;
   - expected: supplied target source is preserved through the transactional apply path.

5. **Multiple source entries**
   - primary archive plus local patch/signature/secondary data;
   - expected: only the primary archive is replaced.

6. **Ambiguous source list**
   - more than one plausible primary archive;
   - expected: explicit REVIEW instead of guessing.

7. **Failure reason propagation**
   - maintained updater emits `NEEDS-REVIEW <port> ...: <reason>`;
   - primary updater records that reason instead of only `FAILED/REVIEW`.

### Status

- [x] Identify the common failure path between primary and maintained updater.
- [x] Confirm that the candidate `source` field is written into the handoff TSV.
- [x] Confirm that `bfs-maintained-port-updater.py` reads `row.source`.
- [x] Confirm that `update_one()` currently ignores `row.source` during Pkgfile rewrite.
- [x] Add a safe primary-source replacement helper to `bfs-maintained-port-updater.py`.
- [x] Apply `row.source` before remote archive validation.
- [x] Preserve secondary sources and patch companions unchanged; ambiguous primary archives are held for review.
- [x] Keep target-source validation before final Pkgfile commit.
- [x] Propagate detailed `NEEDS-REVIEW` reasons back into the primary updater result table.
- [x] Add regression coverage for the shared source-handoff path, including glib-networking-style series migration, multi-source preservation, ambiguity handling, and reason propagation; live package testing remains useful for package-specific behavior.


---

## Avahi release-candidate normalization: `0.9-rc5` equals `0.9rc5`

### Live Opt false positive

The updater proposed:

```text
opt/avahi  0.9-rc5 -> 0.9rc5
```

The BFSOS port and Arch are referring to the same upstream release candidate; only the separator before `rc5` differs.

### Required behavior

Normalize a separator immediately before a numeric `rc` suffix for comparison purposes only:

```text
0.9-rc5
0.9_rc5
0.9rc5
```

must compare as the same release. Do not strip arbitrary punctuation from unrelated versions.

### Status

- [x] Add narrowly-scoped release-candidate separator normalization.
- [x] Suppress the false `0.9-rc5 -> 0.9rc5` candidate.
- [x] Add regression coverage for the Avahi case.

---

## r394 implementation notes

Worked from the full BFSOS project archive, including current ports, both updater layers, tests, and live updater logs.

Implemented:

- **Maintained source handoff:** `bfs-maintained-port-updater.py` now consumes the candidate `source` supplied by the primary updater, safely identifies the primary archive, preserves `$name`/`$version` templating where possible, keeps secondary archives/local companions untouched, rejects ambiguous primary-source lists, validates the rewritten target, and still commits the Pkgfile last.
- **Detailed apply diagnostics:** the primary updater now records the exact per-port `NEEDS-REVIEW` reason emitted by the maintained updater instead of flattening every helper rejection into `FAILED/REVIEW`.
- **Firefox ESR:** explicit Mozilla `FIREFOX_ESR` channel support with diagnostics and precedence over generic rapid-release Firefox discovery.
- **Downstream snapshot guard:** formal-release BFSOS ports reject CRUX/Arch VCS versions such as `2.2.1.r23.gHASH`; snapshot-tracking ports remain eligible. This closes the live libcupsfilters false candidate.
- **Avahi RC equivalence:** `0.9-rc5` and `0.9rc5` now compare equal.
- **NVIDIA pair locking:** `opt/nvidia` and `compat-32/nvidia-32` are a coordinated exact-version pair, auto-selected only with a complete common target and built native first. `nvidia-fb-32` is intentionally not folded into this pair.
- **Atomic coordinated apply:** selected version-locked group port directories are snapshotted before the maintained-updater handoff and the whole touched family is restored if any member fails/requires review during apply.
- **Coordinated retry visibility:** `BLOCKED:` rows remain retryable when the Pkgfile still matches the applied target, preventing an interrupted Vulkan/SPIR-V transaction from vanishing merely because the tree already advanced.
- **Regression maintenance:** updated the older r377 diagnostic expectation to the current MLFS-only terminology and added `scripts/tests/test-r394-updater-fixes.py`.

Validation performed in the supplied tree:

```text
python3 scripts/tests/test-r377-port-updater-fixes.py     PASS
python3 scripts/tests/test-maintained-port-updater.py     PASS
python3 scripts/tests/test-r394-updater-fixes.py          PASS
bash scripts/tests/test-r365-port-updater-policy.sh        PASS
python3 -m py_compile scripts/bfs-port-updater.py scripts/bfs-maintained-port-updater.py  PASS
```

Still intentionally open:

- The exact historical `spirv-tools` compile failure was not reclassified because its original build stderr was not present in the tracker evidence; r394 preserves blocked/retry state and avoids hiding it.
- Fribidi same-package ownership collision still needs live package-database ownership confirmation and/or pkgutils source-level work; no unsafe global `pkgadd -f` change was made.
- Brasero's live port is already at 3.12.4 with the obsolete patch/options removed in this project snapshot, but generic automatic build-system migration detection remains a broader updater enhancement rather than a guessed per-port rewrite.

---

# r395 live follow-up — Opt browser sweep, source rewrite regressions, and port build failures

This section records issues found during the live Opt sweep after the r394 updater changes and after the successful LAME/libclc repair work.

## Resolved: `opt/lame` 4.0 build failures

### Live failure 1 — ID3 UTF-8/UTF-16 API mismatch

The LAME 4.0 frontend failed in `frontend/parse.c` because the `TENC_UTF8` branch passed an `unsigned short const *` value to UTF-8 ID3 helper functions and also referenced obsolete `*_ucs2` helper names.

Observed failures included:

```text
id3tag_set_textinfo_utf8(..., str)
id3tag_set_comment_ucs2(...)
id3tag_set_fieldvalue_ucs2(...)
```

while the same function's `TENC_UTF16` branch already used the current UTF-16 helper names.

### Live failure 2 — analyzer helper symbols hidden by export list

After the first patch, the frontend linked against `hip_finish_pinfo()` but the shared `libmp3lame` export list did not contain either analyzer helper:

```text
hip_set_pinfo
hip_finish_pinfo
```

The function implementations existed in `libmp3lame/mpglib_interface.c`, but `-export-symbols ../include/libmp3lame.sym` hid them from the frontend linker.

A first export-list patch also exposed a packaging detail: blank lines in `include/libmp3lame.sym` become bare semicolons in the generated GNU ld version script and cause a syntax error. The final patch therefore appends the two symbols without an intervening blank line.

### Final BFSOS port fix

- [x] `opt/lame` moved to release 2.
- [x] Add `lame-4.0-id3-utf16.patch`.
- [x] Add `lame-4.0-export-pinfo.patch`.
- [x] Regenerate `.md5sum`.
- [x] Clean `pkgmk -d -kw` build succeeds.

Keep this as a package-specific upstream compatibility fix; it is not an updater-policy failure.

---

## Resolved: `opt/libclc` 23.1.2 build cleanup

### Initial failure

The extra standalone Mesa-target libclc configure pass selected the wrong CLC compiler until the port explicitly supplied:

```text
-DCMAKE_CLC_COMPILER=/usr/bin/clang
```

That exposed the deeper failure:

```text
--target=spirv-unknown-mesa3d
error: SPIR-V target requires a Vulkan environment
```

LLVM 23 successfully built and staged the normal upstream libclc runtimes:

```text
spirv32-unknown-unknown
spirv64-unknown-unknown
```

The obsolete additional loop for:

```text
spirv-unknown-mesa3d
spirv64-unknown-mesa3d
```

was therefore the failing portion of the BFSOS recipe.

### Final BFSOS port fix

- [x] `opt/libclc` moved to 23.1.2 release 2.
- [x] Remove the obsolete Mesa-specific standalone build loop.
- [x] Keep the LLVM runtime build for `spirv32-unknown-unknown` and `spirv64-unknown-unknown`.
- [x] Keep `libclc.pc` aligned to 23.1.2.
- [x] Clean `pkgmk -d -kw` build succeeds.

This simplifies the port instead of carrying another LLVM-version workaround.

---

## BUG: Firefox ESR channel is not being surfaced by the Opt updater

### Live state

Installed/current BFSOS port:

```text
opt/firefox-esr
version=153.2.0esr
release=4
```

The Opt browser sweep did not show `firefox-esr` even though the ESR channel had moved forward.

The port uses Mozilla's ESR archive form:

```text
https://archive.mozilla.org/pub/firefox/releases/$version/source/firefox-$version.source.tar.xz
```

### Required behavior

- [ ] Audit the r394 explicit Mozilla ESR-channel discovery path.
- [ ] Verify that `firefox-esr` is checked against the ESR channel, not rapid-release Firefox.
- [ ] Preserve BFSOS/Mozilla's literal `esr` suffix when constructing candidates.
- [ ] Correctly compare ESR versions such as `153.2.0esr` and the next ESR maintenance release.
- [ ] Do not silently treat an ESR port as current because generic Firefox metadata succeeded or omitted the `esr` suffix.
- [ ] Show a newer ESR candidate in the normal Opt picker when one exists.
- [ ] Add a regression test using the current `opt/firefox-esr/Pkgfile` version/source shape.

Priority: **High**. This is a direct regression against the r394 Firefox-ESR handling claim.

---

## BUG: maintained source rewrite still generates invalid project identities / archive URLs

The live Opt apply produced several `NEEDS REVIEW: rewritten source URL is not reachable` results. These are important because r394 specifically added maintained-source handoff and safe primary-source replacement.

### Live cases

```text
opt/discord:
https://dl1.net/apps/linux/1.0.161/discord-1.0.161.tar.gz
curl: (6) Could not resolve host: dl1.net

opt/libcap-ng:
https://people.redhat.com/sgrubb/libcap-ng/libcap-ng-0.9.6.tar.gz
HTTP 404

opt/lmdb:
https://github.com/LMDB/lmdb/archive/LMDB_1.0.2.tar.gz
HTTP 404

opt/mlt:
https://github.com/mlt/releases/download/v7.42.0/mlt-7.42.0.tar.gz
HTTP 404
```

### Why these matter

These failures are not equivalent to a normal upstream archive disappearing. The generated/replaced URLs show that the updater can still lose or corrupt upstream identity/template information during the maintained-port handoff.

`mlt` is especially clear: the existing BFSOS port identifies the upstream project as:

```text
https://github.com/mltframework/mlt/
```

but the rewritten target became:

```text
https://github.com/mlt/releases/...
```

which drops the `mltframework` owner entirely.

### Required behavior

- [ ] Re-audit the r394 primary-source replacement helper against these four live cases.
- [ ] Never rewrite a GitHub archive by package basename alone when the existing URL already provides a verified owner/repository identity.
- [ ] Preserve repository owner + repository name when only version/tag syntax changes.
- [ ] Preserve known non-GitHub upstream hosts unless a verified source migration is proven.
- [ ] A candidate source supplied by a fallback provider must still pass same-upstream identity checks before replacing the BFSOS primary source.
- [ ] If provider evidence supplies only a version and no trustworthy source migration, update the version while retaining/retemplating the existing verified BFSOS source.
- [ ] If the replacement cannot be proven, return detailed `NEEDS-REVIEW` without committing a malformed URL.
- [ ] Add regression cases for Discord, libcap-ng, LMDB, and MLT.

---

## BUG: `opt/mlt` primary source and version-specific secondary patch need coordinated handling

### Current BFSOS port before the failed rewrite

```text
name=mlt
version=7.40.0
release=7
source=(https://github.com/mltframework/$name/releases/download/v$version/$name-$version.tar.gz
        https://www.linuxfromscratch.org/patches/blfs/svn/mlt-7.40.0-ffmpeg-9.0.patch)
```

The updater attempted a new MLT release but generated an invalid primary GitHub URL.

The port also carries a version-specific BLFS patch whose filename embeds `7.40.0`.

### Required behavior

- [ ] Preserve the canonical `mltframework/mlt` repository identity.
- [ ] Verify the candidate release archive before committing the version bump.
- [ ] Treat the FFmpeg 9 patch as a secondary source with its own lifecycle.
- [ ] On an MLT version bump, verify whether the `mlt-7.40.0-ffmpeg-9.0.patch` is still required and whether a matching patch exists for the new version.
- [ ] Never leave an old version-specific patch attached automatically to a newer MLT release.
- [ ] If the primary release is valid but the required secondary patch state cannot be verified, mark the update `REVIEW` and leave the existing Pkgfile unchanged.

Priority: **High**.

---

## Opt live apply: eight packages now fail during build

The live Opt sweep reached the build stage for multiple candidates but failed for all of the following:

```text
opt/chromium:        BUILD FAILED (5)
opt/cups:            BUILD FAILED (5)
opt/firefox:         BUILD FAILED (5)
opt/firefox-bin:     BUILD FAILED (5)
opt/glib-networking: BUILD FAILED (1)
opt/iniparser:       BUILD FAILED (1)
opt/libqalculate:    BUILD FAILED (5)
opt/upower:          BUILD FAILED (1)
```

These need individual build-log diagnosis before being classified as port bugs, dependency-order bugs, source migration bugs, or upstream incompatibilities.

### Required follow-up

- [ ] Preserve and inspect build stderr for each package from the current updater run.
- [ ] Chromium: determine whether the failure is source/build recipe/dependency related; browser work is now the first Opt priority.
- [ ] CUPS: inspect exact build error and confirm whether any libcupsfilters/cups family coordination is involved.
- [ ] Firefox: inspect rapid-release source and current Rust/Clang compatibility separately from ESR.
- [ ] Firefox-bin: inspect binary archive URL/layout separately from source Firefox.
- [ ] glib-networking: verify that the corrected GNOME series-path handling actually reached the resulting Pkgfile before build.
- [ ] iniparser: inspect whether the current source/archive layout changed.
- [ ] libqalculate: inspect exact build failure and dependency/version compatibility.
- [ ] upower: inspect exact build failure and whether dependency/API changes are involved.
- [ ] Do not infer a common fix from the numeric helper exit code alone.

---

## Opt sweep status: updater is much cleaner, but current failure screen is a regression gate

The Opt tree is substantially improved compared with the previous night: only one package was reported as unverifiable before the apply attempt. However, the apply results show that candidate verification alone is not sufficient: eight ports failed during build and four source rewrites were rejected as unreachable.

Treat this live run as a regression gate before declaring the Opt updater complete.

### Required workflow

- [ ] Finish browser diagnostics first: Chromium, Firefox, Firefox-bin, Firefox ESR detection.
- [ ] Fix MLT and the generic maintained-source rewrite regressions.
- [ ] Re-run the Opt sweep after fixes.
- [ ] Require a clean/reasonably understood Opt result before moving on.
- [ ] Then run another `compat-32` sweep.
- [ ] Then run another Core sweep.
- [ ] After the major trees are clean, work the remaining unverifiable ports systematically.

---

## r395 live evidence / log to retain

The updater result screen referenced:

```text
/home/brian/BFSOS/logs/update/scan-20261005-145808.tsv
```

Keep this log in the project archive for the next updater audit. It is the primary live evidence for the current Opt failure set.

### r395 priority order

1. Browser failures and Firefox ESR discovery.
2. Maintained-source rewrite regressions (`discord`, `libcap-ng`, `lmdb`, `mlt`).
3. Remaining Opt build failures (`cups`, `glib-networking`, `iniparser`, `libqalculate`, `upower`).
4. Re-run Opt.
5. Sweep compat-32 again.
6. Sweep Core again.
7. Resolve remaining unverifiable ports.


---

# r396 implementation — Opt failure regression hardening

Worked from the full `BFSOS-current-20261005.tar.zst` tree and the r395 tracker after the live Opt run.

## Fixed: Firefox ESR overlap-channel selection

The r394 implementation looked only at Mozilla product-details `FIREFOX_ESR`. During ESR overlap, Mozilla can keep the older supported train in `FIREFOX_ESR` while publishing the newer ESR train in `FIREFOX_ESR_NEXT`. This is exactly why BFSOS `153.2.0esr` disappeared: current Mozilla metadata can expose the old 140 ESR under `FIREFOX_ESR` while the 153 train is under `FIREFOX_ESR_NEXT`.

- [x] Read both `FIREFOX_ESR` and `FIREFOX_ESR_NEXT`.
- [x] Select the newest comparable ESR value rather than blindly using the older key.
- [x] Keep ESR independent from rapid-release `LATEST_FIREFOX_VERSION`.
- [x] Add regression coverage for an overlap example (`140.x` + `153.4.0esr`).

## Fixed: maintained-source templating could corrupt hosts/repository owners

The r395 failures for Discord and MLT shared one concrete bug in `_source_token_template_from_target()`: it globally replaced the package name with `$name`. Package names that appear inside a hostname or repository owner were corrupted:

```text
mltframework -> $nameframework -> empty/incorrect owner when evaluated
discordapp   -> $nameapp       -> empty/incorrect hostname when evaluated
```

This produced the observed broken URLs such as `https://github.com//mlt/...` and `https://dl..net/...`.

- [x] Never globally replace package-name substrings while restoring `$name` templating.
- [x] Preserve already-correct dynamic source tokens when target URL is simply the same template at a new version.
- [x] Restore `$name` only at path/filename token boundaries.
- [x] Add direct MLT and Discord regressions.

## Fixed: known source migrations for LMDB and libcap-ng

- [x] LMDB candidate source now uses the canonical OpenLDAP release archive form:
  `https://git.openldap.org/openldap/openldap/-/archive/LMDB_$version/openldap-LMDB_$version.tar.bz2`.
- [x] libcap-ng 0.9+ candidate source migrates from the retired `people.redhat.com` distribution location to the verified `stevegrubb/libcap-ng` GitHub tag archive.
- [x] Remote validation remains mandatory, so a nonexistent candidate tag is held for REVIEW rather than committed.

## Fixed: version-specific secondary remote sources cannot silently survive a version bump

MLT 7.40.0 carries the version-specific BLFS patch `mlt-7.40.0-ffmpeg-9.0.patch`. A version bump to 7.42.0 must not automatically retain that old patch merely because its URL is still reachable.

- [x] Detect secondary remote sources that still contain the old package version after the primary source/version rewrite.
- [x] Hold the transaction as `NEEDS-REVIEW` and leave the Pkgfile unchanged.
- [x] Add regression coverage using the live MLT source layout.

## Fixed: build failures now preserve full stderr/stdout

The r395 result screen recorded only numeric `pkgmk` statuses (`BUILD FAILED (1)` / `(5)`), which is insufficient to diagnose eight unrelated packages from an archive after the run.

- [x] `build_selected()` now captures complete `pkgmk -d -kw` stdout/stderr.
- [x] Output is still echoed to the maintainer terminal.
- [x] A per-port log is written under `logs/update/build-<timestamp>-<tree>-<port>.log`.
- [x] The result row includes the build-log path.

The historical r395 archive did not contain those eight build stderr streams, so Chromium/CUPS/Firefox/Firefox-bin/glib-networking/iniparser/libqalculate/upower cannot be truthfully source-diagnosed from the numeric status alone. The next live retry will retain exact evidence automatically.

## Fixed: failed build validation no longer leaves an unbuilt version applied to the tree

The r395 tree showed every failed build Pkgfile already advanced to its candidate version. That makes subsequent scans/retries confusing and can make a failed candidate appear current.

- [x] Before `Update + build` / `Update + build + install`, snapshot selected port directories.
- [x] If `pkgmk` fails, restore that port directory to the exact pre-apply state.
- [x] Report `ROLLED BACK: BUILD FAILED (...)`.
- [x] Successful builds remain applied; a later install failure does not discard a successfully built port.
- [x] Existing version-locked group transactional rollback remains in place.

The supplied r395 archive's eight failed Opt port edits were restored to their committed pre-run state so this r396 tree does not claim unverified versions.

## Regression suite

Validated in the supplied project tree:

```text
python3 -m py_compile scripts/bfs-port-updater.py scripts/bfs-maintained-port-updater.py  PASS
python3 scripts/tests/test-r396-updater-fixes.py                                  PASS
python3 scripts/tests/test-r394-updater-fixes.py                                  PASS
python3 scripts/tests/test-maintained-port-updater.py                              PASS
python3 scripts/tests/test-r377-port-updater-fixes.py                              PASS
bash scripts/tests/test-r365-port-updater-policy.sh                                PASS
```

The stale r377 diagnostic assertion was updated to the current MLFS-only policy wording (`not MLFS-authoritative; checking CRUX`).

## Still open after r396

- [ ] Re-run the Opt browser/update batch on BFSOS with r396 so the new per-port logs capture any genuine Chromium, CUPS, Firefox, Firefox-bin, glib-networking, iniparser, libqalculate, or upower build errors.
- [ ] Fix genuine package-specific failures from those retained logs rather than inferring causes from exit codes.
- [ ] Confirm live Firefox ESR now surfaces the current 153 ESR maintenance release.
- [ ] Confirm Discord and MLT no longer get corrupted `$name` host/owner rewrites.
- [ ] Confirm LMDB uses the OpenLDAP archive source and libcap-ng uses the new GitHub upstream source when their candidates are selected.
- [ ] Fribidi package-manager ownership collision remains open and still requires live ownership evidence/pkgutils work.
- [ ] Generic Brasero/build-system migration detection remains open; the current Brasero port itself is already repaired.


---

# r397 live follow-up — build-work backend metadata bypass and ENOSPC batch contamination

## Live failure: updater ignored `build_work=disk` and filled the 64 GiB tmpfs

The r396 Opt retry exposed a new updater/build-wrapper bug. The system itself had ample free disk space, but `/var/cache/pkg/build-work` is a dedicated 64 GiB tmpfs and reached 100% usage during the batch:

```text
Filesystem   Type   Size  Used  Avail  Use%  Mounted on
tmpfs        tmpfs   64G   64G   156K  100%  /var/cache/pkg/build-work
```

The root filesystem remained essentially empty by comparison:

```text
/dev/mapper/bfs--root-root  xfs  4.5T  181G  4.3T  4%  /
```

Once the tmpfs filled, Firefox extraction and all later builds emitted `No space left on device`. Those later package results are contaminated infrastructure failures and must not be treated as genuine port/build failures.

### Chromium proves the backend metadata was bypassed

The Chromium port already declares:

```text
build_work=disk
```

BFSOS `/etc/pkgmk.conf` maps the wrapper/exported selector as follows:

```text
PKGMK_TMPFS_WORK_ROOT="/var/cache/pkg/build-work"
PKGMK_DISK_WORK_ROOT="${PKGMK_DISK_WORK_ROOT:-/var/cache/pkg/build-work-disk}"

case "${BFS_PKG_BUILD_WORK:-tmpfs}" in
    disk)     PKGMK_WORK_DIR="$PKGMK_DISK_WORK_ROOT/pkgmk-$name" ;;
    tmpfs|'') PKGMK_WORK_DIR="$PKGMK_TMPFS_WORK_ROOT/pkgmk-$name" ;;
    *)        error ;;
esac
```

However, the live updater build left Chromium under:

```text
/var/cache/pkg/build-work/pkgmk-chromium
```

instead of the expected disk-backed path:

```text
/var/cache/pkg/build-work-disk/pkgmk-chromium
```

The preserved Chromium work tree alone had grown to roughly 24 GiB, helping exhaust the 64 GiB tmpfs during the retained `-kw` batch.

### Root cause / required fix

The port itself is already correct. The updater/build path is bypassing the BFSOS build-work metadata mechanism and invoking `pkgmk` without exporting the backend selected by the port's `build_work=` metadata.

Required behavior:

- [x] Parse simple `build_work=` metadata from each selected Pkgfile before invoking `pkgmk`.
- [x] If a port declares `build_work=disk`, export `BFS_PKG_BUILD_WORK=disk` for that build.
- [x] If a port declares `build_work=tmpfs`, export `BFS_PKG_BUILD_WORK=tmpfs`.
- [x] If the metadata is absent, preserve the current/default tmpfs behavior rather than guessing.
- [x] Do not hard-code Chromium-specific work paths; this is generic build-policy metadata.
- [x] Prefer using the existing BFSOS build wrapper/metadata path if one exists instead of duplicating policy in the updater.
- [x] Add regression coverage proving a synthetic `build_work=disk` port is built with `BFS_PKG_BUILD_WORK=disk` and resolves to the disk work root.
- [x] Add regression coverage proving an unannotated port keeps the existing default backend.

## ENOSPC must abort the remaining batch instead of generating fake port failures

Once the selected build filesystem returns `ENOSPC`, every later build in the same batch is untrustworthy until space/backend state is corrected.

Required behavior:

- [x] Detect `No space left on device` / `ENOSPC` in captured build output.
- [x] Classify the triggering result as an infrastructure failure, not a package source/build regression.
- [x] Stop launching additional selected builds immediately after ENOSPC is detected.
- [x] Mark all not-yet-attempted selected ports as `BLOCKED: build workspace out of space` (or equivalent), not `BUILD FAILED`.
- [x] Preserve/rollback affected Pkgfiles according to the r396 transactional policy.
- [x] Keep the first failing build log and the filesystem/backend diagnostics visible in the result summary.
- [x] Add regression coverage showing one ENOSPC build aborts the remainder of the batch.

## Preflight free-space/backend diagnostics

Because BFSOS deliberately supports tmpfs and disk-backed build roots, the updater should check the actual filesystem containing the selected work root rather than only checking `/` or `/var/cache/pkg`.

Required preflight:

- [x] Resolve the effective `PKGMK_WORK_DIR` backend for each selected port before the build stage.
- [x] Report whether the build uses tmpfs or disk.
- [x] Query free bytes/inodes on the actual work filesystem (`/var/cache/pkg/build-work` vs `/var/cache/pkg/build-work-disk`).
- [x] Refuse to start a build when the selected backend is already effectively full.
- [x] For mixed batches, do not assume every package shares one backend.
- [x] Keep the check advisory/conservative rather than inventing unreliable per-package space estimates.

## Live retry interpretation

The r396 Opt apply/source-rewrite portion looked substantially healthier before the build workspace filled:

- Firefox ESR surfaced correctly on the 153 ESR train.
- Discord/libcap-ng/LMDB source handling no longer showed the previous malformed rewrite pattern.
- MLT correctly stopped as `NEEDS-REVIEW` because the secondary BLFS patch URL is version-specific to 7.40.0.

The subsequent package build failures after the tmpfs hit 100% are not valid evidence against Chromium, CUPS, Firefox, Firefox-bin, Firefox ESR, glib-networking, iniparser, libqalculate, upower, or any later package in that contaminated run.

### r397 next validation pass

- [x] Fix updater honoring of `build_work=` / `BFS_PKG_BUILD_WORK` before retrying the Opt batch.
- [ ] Clear only the stale/contaminated work trees needed to restore tmpfs headroom; do not treat old work retention itself as a port bug.
- [ ] Re-run the same Opt selection after the backend fix.
- [ ] Trust package-specific build logs only from the clean retry.
- [ ] Work MLT manually/review the 7.40.0 FFmpeg 9 patch independently of the ENOSPC issue.



---

# r398 implementation — build-work backend and ENOSPC hardening

Worked from the r396 full project archive plus the r397 live tracker after the Opt retry filled `/var/cache/pkg/build-work`.

## Implemented

- [x] `bfs-port-updater.py` now reads simple top-level `build_work=` metadata without sourcing arbitrary Pkgfile code.
- [x] `build_work=disk` exports `BFS_PKG_BUILD_WORK=disk`; `build_work=tmpfs` exports `tmpfs`; absent metadata preserves the existing tmpfs default.
- [x] Updater builds use the installed `bfs-pkgmk` wrapper when available, so updater validation follows the same ABI, backend-selection, payload-guard, and build-history path as ordinary BFSOS builds. A direct `pkgmk` fallback remains for bootstrap/repair contexts where the wrapper is unavailable.
- [x] The selected backend is passed explicitly through `sudo env BFS_PKG_BUILD_WORK=...`, preventing Chromium/Qt/QEMU-style disk metadata from silently falling back to tmpfs.
- [x] Build-work roots are resolved from the installed `/etc/pkgmk.conf` using safe literal parsing; the disk-root environment override is preserved. No shell configuration is sourced.
- [x] Before each build, the updater checks free bytes and free inodes on the actual selected work filesystem, prints the backend/root diagnostics, and refuses only when that filesystem is effectively full.
- [x] Mixed batches resolve and preflight each port independently instead of assuming one shared backend.
- [x] Captured `No space left on device`, `ENOSPC`, `errno 28`, or `error 28` output is classified as an infrastructure failure.
- [x] The first ENOSPC result aborts launching every remaining selected build and marks those ports `BLOCKED: build workspace out of space ...`.
- [x] Build logs now begin with the effective backend/root/free-space diagnostic so later failures can be correlated with workspace state.
- [x] r396 rollback handling now also restores ports affected by ENOSPC infrastructure failures and preflight workspace blocks.
- [x] Added `scripts/tests/test-r397-updater-fixes.py` covering explicit disk metadata, default tmpfs behavior, wrapper invocation, preflight-full refusal, and ENOSPC abort-the-rest behavior.

## Validation

```text
python3 -m py_compile scripts/bfs-port-updater.py scripts/bfs-maintained-port-updater.py  PASS
python3 scripts/tests/test-r397-updater-fixes.py                                  PASS
python3 scripts/tests/test-r396-updater-fixes.py                                  PASS
python3 scripts/tests/test-r394-updater-fixes.py                                  PASS
python3 scripts/tests/test-maintained-port-updater.py                              PASS
python3 scripts/tests/test-r377-port-updater-fixes.py                              PASS
bash scripts/tests/test-r365-port-updater-policy.sh                                PASS
bash scripts/tests/test-build-work-backend.sh                                      PASS
```

## Still requires live validation

- [ ] Re-run the same Opt selection on BFSOS and confirm Chromium work appears under `/var/cache/pkg/build-work-disk/pkgmk-chromium`.
- [ ] Confirm unannotated Opt ports continue to use `/var/cache/pkg/build-work` while it has adequate headroom.
- [ ] Only diagnose package-specific Chromium/Firefox/CUPS/etc. failures from this clean retry; the prior ENOSPC-contaminated results remain invalid evidence.
- [ ] MLT still requires manual review of the version-specific `mlt-7.40.0-ffmpeg-9.0.patch` before moving to 7.42.0.
- [ ] Fribidi package-manager ownership collision remains open pending live ownership/pkgutils evidence.
- [ ] Generic Brasero build-system migration detection remains a broader open enhancement; the current Brasero port itself is repaired.
---

# r399 live stabilization and dev-book policy corrections

## Live validation: build-work backend fix is working

The clean Opt retry confirmed that the r398 backend-selection fix is functioning on the real BFSOS system.

Observed updater process chain:

```text
python3 ./scripts/bfs-port-updater.py
  -> sudo env BFS_PKG_BUILD_WORK=disk /usr/bin/bfs-pkgmk -d -kw
  -> /usr/bin/pkgmk -d -kw
  -> ninja -C out/Release chrome chrome_sandbox chromedriver
  -> clang++ ...
```

Observed updater diagnostic:

```text
BUILD-WORK opt/chromium:
  backend=disk
  root=/var/cache/pkg/build-work-disk
```

Live Chromium compilation was active with `ninja` and multiple high-CPU `clang++`
workers, confirming that the build was not stuck and that the large-build backend
was no longer using the 64 GiB tmpfs.

Tracker status:

- [x] Confirm Chromium updater build is launched with `BFS_PKG_BUILD_WORK=disk`.
- [x] Confirm Chromium work root resolves to `/var/cache/pkg/build-work-disk/pkgmk-chromium`.
- [x] Confirm the prior Chromium failure was contaminated by tmpfs ENOSPC and is not valid package-failure evidence.
- [x] Let the clean Chromium retry complete and record the actual result.
- [ ] Continue the clean Opt retry and diagnose only failures produced with a healthy selected backend.

## Regression: restore updater live build status

The updater displayed useful live package/build status before the recent build-wrapper
and logging changes. During the r398 live retry, after printing the `BUILD-WORK`
diagnostic, the updater became visually quiet even though Chromium was actively compiling.

This is a regression, not a request for a new UI.

Required stabilization behavior:

- [x] Restore the previous live build-status output.
- [x] Keep the new `BUILD-WORK <port>: backend=... root=... free=... inodes=...` diagnostic.
- [x] Show which selected package is currently being built.
- [x] Preserve the existing success/failure/block result reporting after each build.
- [x] Do not redesign unrelated updater UI or candidate/provider logic while fixing this.
- [x] Do not remove or weaken the r398 build-work backend handling.

### Build-log behavior still needs confirmation

During the live Chromium build, the per-build log initially contained only the
build-work diagnostic while the compile continued in the child process.

This may be output buffering rather than a broken log path.

- [x] After Chromium exits, verify whether the full `pkgmk` output appears in the log.
- [x] If the full output appears only at process completion, treat this as buffered logging
      and decide whether line-by-line teeing is needed to restore the old live behavior.
- [ ] If the full output never appears, fix build-output capture without changing build semantics.

The immediate priority is functionality/stability: restore behavior that previously worked,
keep the source/URL/backend fixes, and avoid unrelated updater changes.

## Regression: updater builds are not using the full available CPU parallelism

### Live Chromium observation

The clean Chromium retry is compiling successfully enough to expose another updater/build-wrapper
regression: the build is clearly **not using all available CPU cores/threads**. Chromium is large
enough that this is immediately visible in build time and CPU utilization.

The updater must not accidentally reduce package-build parallelism when it launches `bfs-pkgmk`,
`pkgmk`, Ninja, Make, Meson, CMake, or another supported build backend.

This is especially important for Chromium, Firefox, LLVM, Qt, Mesa, and other very large ports,
where losing most of the machine's parallelism can turn a normal validation build into an
unnecessarily long-running job.

### Required behavior

- [x] Determine how many logical CPUs are available to the live BFSOS build (`nproc` / equivalent).
- [x] Audit the updater -> `bfs-pkgmk` -> `pkgmk` environment and command chain for lost,
      overwritten, or artificially capped parallel-build settings.
- [x] Preserve an existing explicit maintainer/user parallelism setting when one is configured.
- [x] Otherwise default package builds to the full available logical CPU count.
- [x] Ensure `MAKEFLAGS`/job settings survive the updater's `sudo env` boundary when they are
      part of BFSOS package-build policy.
- [x] Ensure Ninja-based builds receive equivalent full-machine parallelism; do not assume a
      Make-only `-j` setting automatically reaches Ninja.
- [x] Check Meson/CMake/Ninja, GNU Make, and other build paths used by BFSOS so the wrapper does
      not fix Chromium while leaving another backend artificially serialized.
- [x] Respect an explicit per-port job limit when a port intentionally requires one for stability
      or memory reasons; the global default must not override deliberate package-specific caps.
- [x] Do not create nested parallelism that multiplies the requested job count across layers.
- [x] Keep the existing r398 disk/tmpfs build-work backend selection unchanged while fixing CPU
      parallelism.

### Diagnostics

Add one concise build diagnostic before each package build so a live run makes the effective
parallelism obvious, for example:

```text
BUILD-CPU opt/chromium:
  logical_cpus=32
  jobs=32
  source=default-all-cpus
```

If a port intentionally caps jobs:

```text
BUILD-CPU opt/example:
  logical_cpus=32
  jobs=8
  source=port-override
```

The diagnostic should report the **effective** value that reaches the build, not merely the value
the updater intended to set.

### Chromium validation

- [ ] While the current Chromium build is still the live test case, inspect the running Ninja
      command/process pool and determine the effective job count.
- [ ] Confirm whether the lost parallelism originates in the updater, `sudo env`, `bfs-pkgmk`,
      `pkgmk`, the Chromium Pkgfile/build script, or Ninja invocation.
- [ ] After the fix, rerun/continue a Chromium build and confirm CPU utilization/process count is
      consistent with the full configured job count.
- [ ] Record the effective logical CPU count and job count in the live validation notes.

### Regression coverage

- [x] Add a synthetic updater/build-wrapper test proving the default job count follows the
      available logical CPU count.
- [x] Add a test proving an explicit user/maintainer job setting is preserved.
- [x] Add a test proving an intentional per-port lower job cap wins over the global default.
- [x] Add a test proving the `sudo env` launch path does not silently discard the job setting.
- [x] Add a Ninja-path regression so Chromium-style builds cannot silently fall back to a low
      worker count while Make-based tests still pass.

## MLFS development-book source policy: use the Chapter 3 package and patch inventories

For packages that BFSOS deliberately chooses to track against MLFS development, use these
two MLFS development-book inventory pages as the canonical MLFS inputs:

```text
Packages:
https://linuxfromscratch.org/mlfs/view/dev/chapter03/packages.html

Patches:
https://linuxfromscratch.org/mlfs/view/dev/chapter03/patches.html
```

Do not treat every package appearing anywhere in MLFS/LFS/BLFS/GLFS as globally
authoritative for BFSOS.

Required policy:

- [x] Maintain an explicit curated set/map of BFSOS ports that are intentionally
      MLFS-dev-managed.
- [x] For those ports, compare against the version listed in the MLFS development
      Chapter 3 package inventory.
- [x] For those ports, inspect/sync the matching required patch from the MLFS
      development Chapter 3 patch inventory when applicable.
- [x] Do not automatically pin unrelated BFSOS packages to MLFS just because MLFS
      or another LFS-family book carries them.
- [x] Do not downgrade a BFSOS package that intentionally follows a newer stack.
- [x] Keep kernel/kernel-headers under the existing BFSOS LTS kernel policy rather
      than generic MLFS package-version authority.
- [x] Keep Mesa/Xorg/graphics-stack packages on their existing newer BFSOS policy;
      they are not MLFS-managed merely because a book contains related packages.
- [x] Unmapped packages continue through the normal BFSOS fallback/update policy
      (CRUX -> verified same-upstream Arch -> direct upstream/review as appropriate).

### Package-specific development-book authority

The updater should support explicit package-specific preferred authorities rather
than one global "all development books are authoritative" rule.

Example:

```text
rustc:
  preferred version source = BLFS development
  fallback/reference checks = CRUX, verified Arch, direct upstream
```

Rationale: Rust/toolchain compatibility can materially affect Firefox and other
large consumers, so BFSOS may deliberately follow the BLFS development version
for `rustc` even when other packages continue to use the normal fallback chain.

- [x] Add `rustc` as a candidate for explicit BLFS-development tracking.
- [x] Do not make BLFS development globally authoritative for every BFSOS port.
- [x] Allow additional package-specific LFS/BLFS/GLFS-development mappings only
      when BFSOS explicitly chooses them.

## Combined-source/documentation packages: compare the source package BFSOS actually builds

Book inventories can document components separately even when BFSOS intentionally ships
them from one source package. The updater must compare against the source package represented
by the BFSOS port rather than inventing separate version targets for bundled documentation.

### systemd example

BFSOS builds and ships the systemd documentation/manpages with the `systemd` port.

Therefore:

```text
MLFS source package: systemd
BFSOS port: core/systemd
Version comparison: MLFS development systemd version
Documentation/manpages: supplied by the BFSOS systemd build
Separate doc package comparison: none
Matching MLFS Chapter 3 patches: review/sync as applicable
```

Required behavior:

- [x] Follow the MLFS development `systemd` source version for the BFSOS `systemd`
      port when `systemd` is in the curated MLFS-managed set.
- [x] Do not create or compare an independent documentation/manpage pseudo-package
      when BFSOS already ships those files from `systemd`.
- [x] Apply the same source-package ownership rule to other deliberately combined
      BFSOS ports where book documentation is split differently from the BFSOS package model.

## r399 scope discipline

This revision is a stabilization/policy-correction pass.

Do not add unrelated updater features while these items are being worked.

Priority order:

1. Finish the clean Chromium/Opt live validation.
2. Restore the updater's pre-existing live build-status behavior.
3. Confirm/fix build-log capture only as necessary.
4. Correct the development-book authority model to explicit per-package mappings.
5. Use MLFS Chapter 3 package/patch inventories for explicitly MLFS-managed packages.
6. Add package-specific dev-book preferences such as BLFS-development `rustc` only
   where BFSOS deliberately chooses that policy.


## r401 implementation notes

Implemented from the r400 stabilization tracker:

- Restored live build visibility by teeing `pkgmk` stdout/stderr to both the terminal and the per-port log while the child is running. The updater now prints `BUILD-WORK`, `BUILD-CPU`, and `BUILDING` before each package build.
- Added explicit build parallelism resolution. The updater defaults to all logical CPUs, preserves `BFS_BUILD_JOBS`/`JOBS`, supports a simple per-port `build_jobs=N` cap, and carries the resolved value across `sudo env` as `BFS_PKG_BUILD_JOBS`, `JOBS`, `MAKEFLAGS`, and `CMAKE_BUILD_PARALLEL_LEVEL`.
- Updated `bfs-pkgmk` and packaged `pkgmk.conf` so direct/manual builds preserve explicit job policy rather than overwriting it; `pkgutils` release is bumped to 40.
- Updated the Chromium custom recipe to invoke Ninja with `-j"${JOBS:-1}"`, so it consumes the same effective job count as generic Make/CMake/Meson/Ninja paths in the pkgmk extension.
- Replaced implicit MLFS authority-by-name with the explicit historical r106 curated MLFS mapping. MLFS package versions now come from the Chapter 3 package inventory; MLFS required patches continue to come from the Chapter 3 patch inventory.
- Added explicit per-package development-book authority support and mapped `opt/rustc` to BLFS development without making BLFS globally authoritative.
- Kept kernel/kernel-headers on BFSOS LTS policy and left unmapped, Mesa/Xorg, and other newer-stack ports on the normal BFSOS fallback policy. `core/systemd` remains explicitly MLFS-managed as one source package; no separate documentation pseudo-package is created.
- Added `scripts/tests/test-r400-updater-fixes.py` covering all-CPU defaults, user override, per-port cap, sudo-env propagation, Chromium Ninja job use, Chapter 3 inventory parsing, curated MLFS authority, and package-specific BLFS authority. Older r394/r397 build tests were adapted to the streaming build runner.

Validation in the supplied tree:

```text
python3 scripts/tests/test-r400-updater-fixes.py          PASS
bash scripts/tests/test-build-work-backend.sh             PASS
bash scripts/tests/test-pkgmk-payload-guard.sh             PASS
bash scripts/tests/test-r365-port-updater-policy.sh        PASS
python3 scripts/tests/test-r377-port-updater-fixes.py      PASS
python3 scripts/tests/test-r396-updater-fixes.py           PASS
python3 scripts/tests/test-r397-updater-fixes.py           PASS
python3 scripts/tests/test-r394-updater-fixes.py           PASS
python3 scripts/tests/test-maintained-port-updater.py      PASS
python3 -m py_compile scripts/bfs-port-updater.py scripts/bfs-maintained-port-updater.py scripts/checkupdate.py  PASS
```

`test-checkupdate-v2.py` is not counted as an r401 regression result because the supplied test currently expects a `TREES` symbol that the supplied `checkupdate.py` does not define; this predates the r401 changes.

Still requires live BFSOS validation:

- Confirm the new `BUILD-CPU` line reports 32 logical CPUs / 32 jobs on the 9950X3D when no override is set.
- Confirm Chromium now sustains the expected Ninja worker count and materially better CPU utilization/build time.
- Confirm the live updater display/log remains continuously populated during another long package build.
- Re-run online MLFS/BLFS reference loading on BFSOS to validate the live Chapter 3 inventory against current network content.


---

## Updater: treat stale `.footprint` mismatches as packaging metadata changes, not generic build failures

### Live problem

During maintainer tree sweeps, many otherwise successful package builds stop at the final pkgmk footprint check because the installed/committed `.footprint` no longer matches the package produced by the newer version.

This is currently easy to misread as a source/build failure even when compilation and staging completed successfully. Repeated manual footprint refreshes also create unnecessary maintenance work during large update sweeps.

### Required behavior

The maintainer updater must distinguish a genuine build failure from a successful build whose package footprint changed.

```text
compile/configure/link/install into $PKG fails
    -> BUILD FAILED

build and staging succeed, only .footprint differs
    -> FOOTPRINT CHANGED
```

For updater-driven maintainer validation:

1. Detect the pkgmk footprint-mismatch result separately from ordinary command/build failure.
2. Preserve the generated package/staging result long enough to inspect the new footprint.
3. Compare the old and new footprints and present a concise added/removed/changed-path summary.
4. When the footprint change is consistent with the selected package-version update, allow the updater to regenerate the port's `.footprint` automatically.
5. Continue validation after the refreshed footprint rather than classifying the port as `BUILD FAILED`.
6. If the footprint change is suspicious or cannot be classified safely, leave the port as explicit `REVIEW` rather than silently accepting it.
7. Do not globally disable or ignore pkgmk footprint checking for normal user/manual package builds.
8. Keep the behavior scoped to the BFSOS maintainer updater/update workflow.

### Safety / review cases

Automatic refresh should be conservative. Hold for review when the new footprint unexpectedly includes or removes sensitive/system-owned paths, large unrelated directory trees, device nodes, setuid/setgid changes, or other changes inconsistent with the package being updated.

The updater should never solve this by simply deleting `.footprint` files or invoking pkgmk in a mode that permanently bypasses footprint verification.

### Diagnostics

Expected result example:

```text
FOOTPRINT CHANGED: opt/example
  version: 1.2.3 -> 1.2.4
  removed: usr/lib/libexample.so.1.2
  added:   usr/lib/libexample.so.1.3
  action:  refreshed .footprint; continuing validation
```

For a change requiring review:

```text
FOOTPRINT REVIEW: opt/example
  unexpected added path: usr/bin/unrelated-tool
  .footprint left unchanged
```

### Regression coverage

- [x] Successful build with only a normal versioned-library filename change refreshes `.footprint` and continues.
- [ ] Added/removed documentation, headers, icons, and other ordinary package payload changes can be refreshed safely.
- [x] Genuine compile/configure/link failures remain `BUILD FAILED`.
- [x] Suspicious footprint changes are reported as `REVIEW` and do not overwrite the committed footprint.
- [x] Normal/manual `pkgmk` behavior remains strict and unchanged outside maintainer-update mode.
- [x] The result screen clearly distinguishes `FOOTPRINT CHANGED`, `FOOTPRINT REVIEW`, and `BUILD FAILED`.

### Status

- [x] Add footprint-mismatch classification to updater-driven build validation.
- [x] Capture/derive the newly generated footprint after a successful staged build via the documented `pkgmk -uf` refresh path.
- [x] Add old-vs-new footprint diff diagnostics from pkgmk mismatch rows.
- [~] Automatically refresh safe/expected footprint changes in maintainer mode. r404 auto-refreshes conservative versioned shared-library/SO-name changes; broader docs/headers/icons remain REVIEW for now.
- [x] Preserve REVIEW for suspicious/unclassifiable footprint changes.
- [x] Keep normal pkgmk footprint enforcement unchanged outside maintainer mode.
- [x] Add regression tests for safe versioned-library refresh and suspicious review; existing build-failure regressions continue covering genuine failures.

---

## Updater build-work backend selection: large packages must not default to tmpfs and fail with ENOSPC

### Live failure

A live `compat-32` updater sweep reproduced a build-infrastructure failure caused by the updater sending a very large package to the tmpfs-backed build workspace.

Observed result:

```text
compat-32/llvm-32:
  ROLLED BACK: INFRASTRUCTURE FAILED:
  build workspace out of space;
  backend=tmpfs
  root=/var/cache/pkg/build-work
  free=5.1GiB
  inodes=14034223
```

After the first ENOSPC infrastructure failure, later packages were correctly blocked instead of being attempted blindly:

```text
compat-32/mesa-32:
  ROLLED BACK: BLOCKED:
  build workspace out of space after prior ENOSPC infrastructure failure

compat-32/openssl-32:
  ROLLED BACK: BLOCKED:
  build workspace out of space after prior ENOSPC infrastructure failure

compat-32/python-32:
  ROLLED BACK: BLOCKED:
  build workspace out of space after prior ENOSPC infrastructure failure

compat-32/spirv-llvm-translator-32:
  ROLLED BACK: BLOCKED:
  build workspace out of space after prior ENOSPC infrastructure failure

compat-32/xorgproto-32:
  ROLLED BACK: BLOCKED:
  build workspace out of space after prior ENOSPC infrastructure failure
```

This confirms that the current post-ENOSPC fail-safe is working, but the initial backend-selection policy is still wrong.

### Root problem

The updater currently allows ports without explicit `build_work=` metadata to default to the tmpfs backend.

The existing free-space preflight only rejects a build root when it is already critically low. A tmpfs with several GiB free can therefore pass preflight even when the selected package requires tens of GiB of build space.

This is unsafe for large toolchain/browser/graphics packages such as LLVM, Clang, Mesa, Chromium, Firefox, Rust, GCC, WebKitGTK, and similar high-volume builds.

The build backend must be selected based on the expected package workload, not merely on whether tmpfs has more than a small absolute minimum available.

### Required behavior

The updater/build wrapper must choose the build-work backend conservatively before starting the package.

Required policy:

```text
explicit port build_work=disk
    -> disk

explicit port build_work=tmpfs
    -> tmpfs only if preflight says the build can fit safely

known-large package/family
    -> disk automatically

unknown/default package
    -> tmpfs only when sufficient headroom exists
    -> otherwise disk
```

### Known-large package policy

At minimum, automatically prefer the disk-backed workspace for existing BFSOS ports belonging to these families when no stronger explicit policy exists:

```text
llvm
llvm-32
clang
clang-32
mesa
mesa-32
rustc
gcc
chromium
firefox
firefox-esr
webkitgtk*
qtwebengine*
large Vulkan/SPIR-V compiler/toolchain members
kernel builds when configured build output is known to exceed safe tmpfs headroom
```

The policy should be implemented by package identity/family, not by a fragile one-off path list where a family rule is practical.

Native and compat-32 variants should inherit the same large-build classification unless there is a documented reason not to.

### Space-aware fallback

The updater should also make a runtime decision based on available workspace capacity.

For example:

```text
tmpfs candidate selected
    |
    +--> known-large package
    |       -> use disk
    |
    +--> estimated/minimum required headroom exceeds tmpfs free space
    |       -> use disk
    |
    +--> tmpfs free space below configured safety floor
            -> use disk
```

Do not use a tiny fixed threshold such as 512 MiB as the only criterion for deciding whether a package can safely build in tmpfs.

The exact safety floor should be configurable, but a large-build class should require substantial headroom. The implementation may use:

- a conservative fixed large-build threshold;
- package/family-specific minimums;
- historical build-space observations;
- source/extracted-size heuristics;
- or a combination of these.

Correctness and avoiding ENOSPC are more important than maximizing tmpfs use.

### Disk backend requirements

When disk is selected, use the configured persistent build root:

```text
/var/cache/pkg/build-work-disk
```

or the equivalent configured BFSOS disk build-work path.

Before starting the build:

1. verify the path exists or create it safely;
2. verify it is not itself mounted as tmpfs/ramfs;
3. verify sufficient free blocks and inodes;
4. print the selected backend and capacity;
5. abort with an infrastructure diagnostic if neither backend is safe.

Expected diagnostic:

```text
BUILD-WORK compat-32/llvm-32:
  backend=disk
  root=/var/cache/pkg/build-work-disk
  reason=known-large package
  free=<available-space>
  inodes=<available-inodes>
```

For a capacity-driven switch:

```text
BUILD-WORK opt/example:
  backend=disk
  root=/var/cache/pkg/build-work-disk
  reason=tmpfs insufficient headroom
  tmpfs_free=5.1GiB
```

### ENOSPC classification

Preserve the current distinction between package failures and infrastructure failures.

```text
compiler/configure/source failure
    -> BUILD FAILED

build workspace fills
    -> INFRASTRUCTURE FAILED: ENOSPC
```

After an ENOSPC infrastructure failure:

- keep the current fail-safe that blocks later builds using the unsafe workspace;
- do not classify blocked ports as package build failures;
- retain enough state to retry them after backend selection is corrected;
- offer or document a retry using the disk backend rather than requiring a complete rescan when practical.

### Manual port metadata

Explicit per-port metadata such as:

```bash
build_work=disk
```

remains supported and should override the generic default.

However, correctness must not depend on every large package manually carrying that line. The updater/build wrapper needs a safe automatic fallback for large packages that lack explicit metadata.

The port metadata can still be added to especially large ports as documentation and an extra guard.

### Cleanup behavior

Switching to the disk backend must not leave stale partial tmpfs trees that consume RAM.

After an ENOSPC failure or backend migration:

- remove only the failed package's disposable build-work directory when safe;
- do not remove preserved `-kw` work directories unexpectedly;
- report any retained build tree;
- never recursively purge unrelated package workspaces.

### Regression coverage

- [x] `compat-32/llvm-32` with no explicit `build_work=` selects disk automatically.
- [x] Native LLVM/Clang and compat-32 counterparts share the large-build policy.
- [x] `mesa-32` selects disk when part of the large-build class.
- [x] A small ordinary package may still use tmpfs when enough space exists.
- [x] A normally-small package falls back to disk when tmpfs headroom is below the configured safety floor.
- [x] Explicit `build_work=disk` always selects disk.
- [x] Explicit `build_work=tmpfs` is redirected to disk by the updater/wrapper when tmpfs is below the configured safety floor (unless an administrator explicitly forces the backend in the environment).
- [x] Disk backend diagnostics show root, free space, inode availability, filesystem type, and selection reason.
- [x] ENOSPC remains an infrastructure failure, not `BUILD FAILED`.
- [x] Later packages remain BLOCKED after an ENOSPC event until a safe backend is selected/reset.
- [~] Retry after ENOSPC now selects disk automatically on the next updater run; same-run automatic retry is not implemented.
- [ ] Cleanup removes only disposable failed workspace data and preserves requested `-kw` work trees.

### Status

- [x] Audit current `build_work` backend-selection code in the updater and pkgmk wrapper.
- [x] Add known-large package/family classification.
- [x] Add space-aware tmpfs-to-disk fallback before build start.
- [x] Add configurable tmpfs safety/headroom policy (`BFS_TMPFS_MIN_FREE_GIB`, default 16 GiB).
- [x] Verify the selected disk backend does not resolve to tmpfs/ramfs before use.
- [x] Improve `BUILD-WORK` diagnostics with backend-selection reason, capacity, inode count, and filesystem type.
- [x] Preserve current ENOSPC infrastructure-failure/blocking behavior.
- [~] Add safe retry behavior after ENOSPC using the disk backend. r404 guarantees the next retry selects disk for known-large/low-headroom cases; in-batch retry remains open.
- [~] Add regression tests for LLVM-32/Mesa-32 classification, small-package tmpfs use, low-space fallback, and backend selection; cleanup/in-batch retry coverage remains open.

---

## r404 implementation notes — footprint handling, build-work selection, compat-32 diagnostics, and unverifiable-source cleanup

Worked from the 2026-10-06 full BFSOS tree and the retained `compat-32` build/update logs.

### Implemented: safe build-work selection before pkgmk starts

- Added automatic large-build classification for LLVM/LLVM-32, Clang, Mesa/Mesa-32, Rust, GCC, Chromium, Firefox/Firefox ESR, WebKitGTK, QtWebEngine, and BFSOS kernel builds.
- Large builds select the persistent disk workspace even when the port forgot to declare `build_work=disk`.
- Added a configurable tmpfs safety floor: `BFS_TMPFS_MIN_FREE_GIB`, default 16 GiB.
- Ordinary packages keep tmpfs only while it has enough headroom; otherwise they transparently use the disk build root.
- The updater now reports backend, root, selection reason, free space, free inodes, and filesystem type.
- The disk backend is rejected if it resolves to tmpfs/ramfs.
- `bfs-pkgmk` received matching direct-build behavior so safety does not depend on entering through the updater.
- `pkgutils` release bumped from 40 to 41 for the wrapper change.

The retained LLVM-32 log confirms the live failure was genuine ENOSPC near the end of compilation (`No space left on device` around target 5635/5750), not an LLVM source failure. A clean retry should therefore run on `/var/cache/pkg/build-work-disk`.

### Implemented: footprint mismatch classification

- Updater-driven builds now recognize pkgmk's `ERROR: Footprint mismatch found:` separately from compile/configure/link failure.
- Mismatch rows are printed as `FOOTPRINT CHANGED` diagnostics.
- Conservative versioned shared-library/SO-name-only changes are eligible for automatic maintainer refresh using the documented `pkgmk -uf` path.
- Unexpected additions/removals outside the narrow library-version pattern become `FOOTPRINT REVIEW` and are not silently accepted.
- Normal/manual pkgmk footprint checking remains unchanged.

The retained `harfbuzz-32` 14.6.0 log is the motivating live case: all reported differences are versioned `libharfbuzz*.so.0.61450.0 -> .0.61460.0` payload changes after the build completed, so it should be classified as footprint metadata rather than a source/build failure on retry.

### Implemented: selected dependency ordering / stale-installed prerequisite guard

The live `gst-plugins-base-32` failure was not a source regression. Its Meson configure found installed `gstreamer-1.0` 1.28.7 while requiring the selected 1.29.2 build. The updater had attempted the dependent before the selected prerequisite was available to the live system.

r404 now:

- topologically orders selected ports from `# Depends on:` metadata where possible;
- in build-only mode, blocks a dependent when its newly built selected prerequisite is not installed/staged instead of calling it `BUILD FAILED`;
- in build+install mode, dependency order allows the prerequisite to be installed before the dependent build.

### Fixed: compat-32 false candidates exposed by retained logs

The compat sweep exposed several provider-policy bugs rather than valid package updates:

- `gstreamer-32` / GStreamer plugin ports: 1.29.x is an odd-minor development series. Added compat-32 GStreamer ports to the existing stable-series guard and restored `gstreamer-32` from the accidentally applied 1.29.2 candidate back to 1.28.7 release 3.
- `libva-32`: rejected unrelated `4.1-video` git tag by applying the same major-series lock used by native `xorg/libva`.
- `pango-32`: rejected the known bad/historical `1.90.0` candidate just as native Pango does.
- `libtiff4-32`: locked the compatibility port to major version 3 so the updater cannot turn the old ABI compatibility package into normal libtiff 4.x.
- `libjpeg6-turbo-32`: locked to the 1.x compatibility line rather than allowing the separate compatibility package to jump to modern 3.x.

Also generalized GNOME source-series rewriting so compat ports such as Pango derive the target series directory (`1.58 -> 1.60`, etc.) instead of retaining the old series path.

### Unverifiable/source URL cleanup — first pass

Updated stale compat-32 source locations where a canonical maintained source was already known or independently verified:

- `attr-32`: switched from the timing-out Savannah redirect to the same NetCologne Savannah mirror used by native BFSOS `attr`.
- `expat-32`: switched from the stale SourceForge path to the official libexpat GitHub release asset form.
- `fontconfig-32`: switched to the same BLFS/OSUOSL mirror form used by native BFSOS fontconfig.
- `freeglut-32`: switched to the official GitHub `v$version` release asset form.
- `glew-32`: switched to the exact SourceForge file/download path for the verified 2.3.1 release.
- `imlib2-32`: switched to the shorter SourceForge project download form used by native BFSOS Imlib2.
- `libjpeg6-turbo-32`: switched to the exact SourceForge 1.5.3 file/download path; this compatibility port remains series-locked.
- `libmng-32`: switched to the exact `libmng-devel/$version` SourceForge file/download path and the published `.tar.xz` archive.
- `libpcre-32`: switched to the exact SourceForge PCRE 8.45 file/download path.
- `libpng-32`: switched to the same short SourceForge download form used by native BFSOS libpng.
- `libtirpc-32`: switched to the exact SourceForge 1.3.8 file/download path.

Added git-tag discovery overrides for compat `glew-32`, `libndp-32`, `libwebp-32`, `libpng12-32`, `openssl11-32`, and `lcms2-32` so version discovery does not depend on archive/mirror directory listings when a canonical upstream repository can establish the release lineage.

This is intentionally a first pass, not a claim that every `UNVERIFIABLE` row is solved. `db-32`, some legacy SourceForge compatibility packages, SQLite's encoded archive version, NVIDIA URLs, and transient GNU/Savannah timeout cases still need live re-scan evidence before further rewrites.

### Validation

Passed in the supplied tree:

```text
python3 -m py_compile scripts/bfs-port-updater.py scripts/bfs-maintained-port-updater.py scripts/checkupdate.py
bash -n ports/core/pkgutils/bfs-pkgmk
python3 scripts/tests/test-r404-updater-fixes.py             PASS
python3 scripts/tests/test-r400-updater-fixes.py             PASS
python3 scripts/tests/test-r397-updater-fixes.py             PASS
python3 scripts/tests/test-r394-updater-fixes.py             PASS
python3 scripts/tests/test-maintained-port-updater.py         PASS
```

### Live validation still required

- [ ] Run `sysup` so `pkgutils` release 41 installs the new direct-build backend policy.
- [ ] Re-run the compat-32 scan and confirm `gstreamer-32 1.29.2`, `libva-32 4.1-video`, `pango-32 1.90.0`, and `libtiff4-32 4.7.x` no longer appear as candidates.
- [ ] Retry LLVM-32 and confirm `BUILD-WORK` selects `/var/cache/pkg/build-work-disk` before compilation.
- [ ] Retry HarfBuzz-32 and confirm the versioned-library footprint change is refreshed as `FOOTPRINT UPDATED`, not `BUILD FAILED`.
- [ ] Run the unverifiable pass again and record which source rows were cleared by the URL/provider fixes above.
- [ ] Continue working any remaining genuine compat-32 build logs from the clean retry; do not reuse the ENOSPC-contaminated blocked rows as package failures.

---

# r405 follow-up — URL/fetch audit hardening, published-release guards, footprint refresh, and build-work cleanup

Worked from the 2026-10-06 full project archive plus the dedicated URL audit bundle.

## URL audit baseline

The uploaded audit bundle contained historical and current updater rows from the recent tree sweeps. Deduplicating to the newest `UNVERIFIABLE` / `FETCH-ERROR` row for each port produced:

```text
117 unique affected ports
  74 UNVERIFIABLE
  43 FETCH-ERROR
```

The largest recurring failure classes were:

```text
44 timeout-related rows
41 HTTP 404 rows
12 provider-directory/current-version mapping failures
12 source-filename/version-encoding failures
 4 HTTP 403 rows
 4 other
```

The biggest single cluster was GNU infrastructure: 41 latest rows referenced `ftp.gnu.org`, almost all failing at the checker's old hard 4-second connect timeout. SourceForge-style hosts accounted for another large cluster, where download endpoints were reachable but generic directory probing was the wrong discovery mechanism.

These are primarily updater/provider problems, not evidence that 117 BFSOS ports have broken source archives.

## Fixed: network checker was too aggressive about 4-second connect failures

`checkupdate.py` no longer treats a slow first connection to GNU/mirror infrastructure as an immediate fetch failure.

Implemented:

- [x] Raise the connect allowance from the previous hard 4 seconds to up to 8 seconds.
- [x] Add two curl retries with a one-second delay.
- [x] Retry transient curl errors rather than immediately recording `FETCH-ERROR`.
- [x] Expand the Python subprocess timeout so curl retry time is not killed prematurely.
- [x] Keep the overall per-provider timeout bounded.
- [x] Bump the checker user-agent/version to v11.

This directly targets the large `ftp.gnu.org` timeout cluster without rewriting dozens of otherwise-correct GNU Pkgfile URLs.

## Fixed: SourceForge download URLs need a SourceForge-aware provider

Generic directory probing does not work reliably against:

```text
downloads.sourceforge.net
prdownloads.sourceforge.net
sourceforge.net/.../files/.../download
```

Those hosts frequently redirect downloads but do not provide an Apache-style parent directory index at the URL inferred by the generic provider.

r405 adds a SourceForge file-browser provider that:

- [x] Normalizes all three common SourceForge URL forms to the canonical project `/files/` browser.
- [x] Uses the current source filename to prove the version encoding.
- [x] Climbs above a version-specific directory when necessary so sibling release directories can be inspected.
- [x] Matches release directories and exact source filenames conservatively.
- [x] Preserves existing BFSOS series-lock/version-filter policy before accepting a newer candidate.
- [x] Leaves ambiguous projects `UNVERIFIABLE` rather than guessing.

This should clear or substantially reduce the historical SourceForge 404 cluster on the next live all-tree scan without mass-changing working Pkgfile source URLs.

## Fixed: GitHub release-asset ports must follow published releases, not raw future tags

The clean compat-32 retry exposed two false candidates:

```text
compat-32/expat-32     2.8.5  -> 2.9.0
compat-32/harfbuzz-32  14.5.0 -> 14.6.0
```

The problem is that raw repository tags are not always equivalent to a published release with downloadable release assets. A tag for an upcoming release can exist before the upstream release is actually published.

For a source of the form:

```text
https://github.com/OWNER/REPO/releases/download/TAG/file
```

r405 now:

- [x] Resolves GitHub's published `releases/latest` endpoint.
- [x] Maps the published tag back through the current port's tag/version convention.
- [x] Uses the published release as the candidate source of truth.
- [x] Does **not** fall back to raw git tags if the published-release check is unavailable.
- [x] Keeps raw `git ls-remote --tags` behavior for ports that genuinely track tags rather than GitHub release assets.

Live/current corrections:

- [x] Restore `compat-32/expat-32` from the premature `2.9.0` candidate to released `2.8.5`.
- [x] Move `compat-32/harfbuzz-32` to `14.5.1`, matching the current native HarfBuzz maintenance release instead of the false `14.6.0` candidate.

## Fixed: SQLite encoded archive versions

SQLite uses numeric archive IDs such as:

```text
SQLite version: 3.53.4
archive ID:     3530400
file:           sqlite-autoconf-3530400.tar.gz
```

That cannot be discovered by the generic literal-version filename logic.

r405 adds an official SQLite download-page provider for:

```text
core/sqlite
compat-32/sqlite3-32
```

It decodes the seven-digit archive identifier back to the dotted SQLite release and compares releases normally. The current official page maps `3530400` to `3.53.4`, so these ports should no longer be `UNVERIFIABLE` merely because their filenames use SQLite's encoded form.

## Fixed: npm registry tarballs are not directory-index sources

The audit showed `opt/typescript` as `UNVERIFIABLE` because the generic checker attempted to treat npm's tarball path as a browsable release directory.

r405 adds an npm registry provider:

- [x] Resolve the package name from `registry.npmjs.org` tarball URLs.
- [x] Read the package's registry JSON.
- [x] Require the current BFSOS version to exist in the same package.
- [x] Compare only versions from that verified npm package.

## Additional version-discovery mappings

Added conservative repository discovery overrides for archive sites that do not expose a useful version index:

- [x] `opt/doxygen` -> official Doxygen GitHub repository.
- [x] `opt/duktape` -> upstream Duktape repository.
- [x] `opt/libraw` -> official LibRaw GitHub repository.

These overrides affect version discovery only; they do not silently rewrite package source URLs.

## Policy: intentionally pinned compatibility ports should not pollute the URL audit

`compat-32/db-32` is retained specifically as a Berkeley DB 5.3 ABI compatibility port. Treating its old Oracle archive as a generic update-discovery source creates noise and risks a nonsensical major-line jump.

r405 marks it as a policy-pinned compatibility port in the checker:

```text
compat-32/db-32 -> SKIP (pinned Berkeley DB 5.3 compatibility ABI)
```

The source remains available for building the compatibility package; the generic updater does not reinterpret it as a normal current Berkeley DB branch.

## Fixed: safe automatic footprint refresh previously called `pkgmk -uf` too early

The live HarfBuzz-32 refresh log showed:

```text
ERROR: Unable to update footprint.
File '.../harfbuzz-32#14.6.0-1.pkg.tar.zst' not found.
```

The initial successful compile/stage had stopped at the footprint comparison, before pkgmk wrote the package archive. Therefore calling `pkgmk -uf` immediately could never work: `-uf` expects an existing package archive.

r405 changes the safe maintainer-only refresh flow to:

```text
normal build reaches footprint mismatch
    |
    +--> classify mismatch as safe version-only shared-library payload change
    |
    +--> pkgmk -d -if -kw
         create one package while ignoring only the already-reviewed footprint mismatch
    |
    +--> pkgmk -uf
         regenerate .footprint from that package archive
    |
    +--> FOOTPRINT UPDATED
```

Suspicious/unclassified footprint changes still remain `FOOTPRINT REVIEW`; normal/manual pkgmk behavior remains strict.

## Fixed: successful updater builds must not accumulate retained work trees

The live system filled both the 64 GiB tmpfs and the disk-backed build root with successful `pkgmk -kw` work directories. The updater intentionally used `-kw` so failures remained inspectable, but it never removed the work tree after success.

Required policy is now implemented:

```text
failed / review build
    -> preserve work tree for diagnosis

successful updater build
    -> remove only that package's pkgmk work tree

successful build+install
    -> remove only that package's pkgmk work tree
```

Implementation:

- [x] Keep `-kw` during updater builds so a failure remains diagnosable.
- [x] After success, remove only `<selected-build-root>/pkgmk-$name`.
- [x] Apply cleanup identically to tmpfs and disk backends.
- [x] Validate the package name/path before recursive deletion.
- [x] Never recursively clean unrelated work directories.
- [x] Print an explicit `BUILD-WORK CLEANUP` diagnostic.
- [x] Preserve a failed/review work tree.

## Git helper metadata cleanup switch

The current project also carries the requested explicit Git-helper switch:

```text
-D
--delete-metadata
```

When supplied to `scripts/git-update-bfsos.sh`, it deletes generated:

```text
.footprint
.md5sum
.signature
```

files under `ports/` before staging. Without the switch, the existing conservative review behavior remains unchanged.

## Regression coverage

Added:

```text
scripts/tests/test-r405-updater-fixes.py
```

Coverage includes:

- [x] reviewed `-if` package pass followed by `-uf`;
- [x] build-work cleanup path safety;
- [x] corrected Expat-32 and HarfBuzz-32 versions;
- [x] GitHub published-release tag mapping;
- [x] SQLite `3530400 -> 3.53.4` decoding;
- [x] SourceForge file-browser discovery;
- [x] npm registry discovery;
- [x] pinned Berkeley DB 5.3 compat policy;
- [x] retry/connect-timeout policy presence.

Validation in the worked tree:

```text
python3 scripts/tests/test-r405-updater-fixes.py             PASS
python3 scripts/tests/test-r404-updater-fixes.py             PASS
python3 scripts/tests/test-r400-updater-fixes.py             PASS
python3 scripts/tests/test-r397-updater-fixes.py             PASS
python3 scripts/tests/test-r394-updater-fixes.py             PASS
python3 scripts/tests/test-maintained-port-updater.py         PASS
python3 -m py_compile scripts/checkupdate.py scripts/bfs-port-updater.py scripts/bfs-maintained-port-updater.py  PASS
bash -n scripts/git-update-bfsos.sh                           PASS
```

## Live validation still required

- [ ] Merge r405 and run a fresh all-tree URL audit. The uploaded audit includes historical pre-r404 failures, so only a new scan can prove which SourceForge/GNU rows remain.
- [ ] Confirm GNU timeout noise drops substantially with retry + longer connect allowance.
- [ ] Confirm SourceForge-hosted legacy ports move from false provider 404s to `CURRENT`/valid `UPDATE` where the file browser exposes a reliable release lineage.
- [ ] Confirm `core/sqlite` and `compat-32/sqlite3-32` are no longer `UNVERIFIABLE`.
- [ ] Confirm `compat-32/expat-32` remains at released 2.8.5 until upstream actually publishes 2.9.0.
- [ ] Confirm `compat-32/harfbuzz-32` resolves to 14.5.1 rather than the false 14.6.0 candidate.
- [ ] Confirm a safe HarfBuzz-style footprint mismatch completes the two-stage refresh and reports `FOOTPRINT UPDATED`.
- [ ] Confirm successful builds remove their own tmpfs/disk `pkgmk-*` work tree while failures remain preserved.
- [ ] Re-audit the smaller residual set (NVIDIA, fixed-filename/version-in-path projects, protected/403 sites, and any genuinely dead legacy URLs) from fresh evidence rather than the historical bundle.



---

# r406 follow-up — Core fetch failures, successful-build cleanup privilege boundary, CA compatibility links, and distro-version control

## Live Core result: r405 did not reduce the residual fetch/unverifiable set

The first live Core scan after merging r405 completed successfully but still reported:

```text
CURRENT      148
UPDATE        18
UNVERIFIABLE   6
FETCH-ERROR   35
SKIP           3
ERROR          0
TOTAL        210
ELAPSED      315.4s
```

This is not an acceptable improvement in the URL/fetch audit by itself. Process inspection during the apparent pause showed most workers blocked on `ftp.gnu.org` `curl` probes even though the new timeout/retry policy was active. The checker was therefore functioning as designed, but the source host remained the dominant bottleneck.

### r406 GNU source policy fix

GNU's own maintainer documentation recommends `https://ftpmirror.gnu.org/<package>/` as an automatic redirector to a nearby mirror. r406 migrates the 32 Core Pkgfiles that still used `https://ftp.gnu.org/gnu/` to `https://ftpmirror.gnu.org/` while preserving the package-relative paths and filenames.

Status:

- [x] Confirm the r405 retry/timeout flags were actually present in the live worker processes.
- [x] Identify the remaining Core bottleneck as the `ftp.gnu.org` cluster rather than a dead worker pool.
- [x] Migrate all current Core `ftp.gnu.org/gnu/` package sources to the GNU mirror redirector.
- [x] Add regression coverage preventing Core from silently reintroducing the old host.
- [ ] Re-run Core and compare the new `FETCH-ERROR`/`UNVERIFIABLE` counts against 35/6.
- [ ] Work the smaller residual set from the new TSV rather than the historical audit bundle.

## Fixed: successful-build cleanup crashed on root-owned pkgmk work trees

### Live failure

OpenSSH built successfully, but the updater crashed immediately afterward in `cleanup_successful_build_work()` with `PermissionError`. The build workspace was under:

```text
/var/cache/pkg/build-work/pkgmk-openssh
```

and was correctly root-owned because the build itself runs through `sudo`.

The r405 cleanup implementation attempted `shutil.rmtree()` as the unprivileged maintainer account. This turned a successful package build into a fatal updater exception.

### r406 behavior

- [x] Keep strict package-name validation.
- [x] Resolve the requested cleanup root and require it to match one of the configured tmpfs/disk build-work roots.
- [x] Require the target to be exactly one immediate `pkgmk-$name` child of that root.
- [x] Cross the same privilege boundary as the build by running `sudo rm -rf -- <validated-target>`.
- [x] Never run privileged cleanup against an arbitrary path.
- [x] Cleanup failure is non-fatal and is reported as `BUILD-WORK CLEANUP WARNING` rather than crashing the updater or changing a successful build result.
- [x] Preserve failed/review build work exactly as before.
- [x] Add regression coverage for both successful privileged cleanup and a simulated permission failure.

## Fixed: CA trust regeneration could remove the compatibility bundle link

### Live failure

After recent CA/OpenSSL updates, Steam hung with SSL certificate errors. System time/NTP were correct. The canonical BFSOS bundle existed, and `/etc/ssl/cert.pem` was present, but:

```text
/etc/ssl/certs/ca-certificates.crt
```

was missing. Recreating that compatibility link restored Steam immediately.

Inspection showed that `core/ca-certificates/post-install` created the compatibility links **before** running `make-ca -r`, while `core/make-ca/post-install` also ran `make-ca -r` without recreating them afterward. Trust regeneration may rebuild `/etc/ssl/certs`, so the link ordering was unsafe.

### r406 fix

- [x] `ca-certificates` recreates `/etc/ssl/certs/ca-certificates.crt` and `/etc/ssl/ca-bundle.crt` after `make-ca -r` completes.
- [x] `make-ca` also recreates those compatibility names after its trust regeneration pass.
- [x] Bump `ca-certificates` package release from 1 to 2.
- [x] Bump `make-ca` package release from 6 to 7.
- [x] Add regression coverage proving the compatibility link creation occurs after `make-ca -r` in both hooks.
- [ ] Install the rebuilt packages through normal `sysup`, reboot, and confirm Steam/generic HTTPS still see the CA bundle without manual repair.

## New updater feature: set the BFSOS distro version from one dialog box

### Goal

The maintainer should not have to hunt through the tree when promoting the distro from one release identifier to another. The updater main menu now provides a **Set BFSOS distro version** action with an input box containing the current release.

The same operation is also available non-interactively:

```text
./scripts/bfs-port-updater.py --set-distro-version 0.9.1-rc1
```

### r406 behavior

A valid requested release is applied transactionally to the active release consumers:

- [x] authoritative project `VERSION`;
- [x] `ports/core/aaa_filesystem/Pkgfile` `bfs_version`;
- [x] automatically increment `aaa_filesystem` package `release` exactly once so `sysup` sees the distro-identity change;
- [x] bootstrap fallback release;
- [x] clean-start bootstrap fallback release;
- [x] ISO-builder fallback release values;
- [x] installer fallback release value;
- [x] current-release text in `README.md` and `docs/INSTALL.md`;
- [x] reject spaces, slashes, traversal, and other unsafe release strings;
- [x] derive every edit before writing any file so a missing expected target aborts rather than leaving a partial release bump;
- [x] no-op cleanly when the requested release already matches `VERSION`;
- [x] add synthetic regression coverage using a temporary project tree.

Operational consumers that already read the authoritative `VERSION` file (ISO naming/labeling, SourceForge publishing, base/toolchain archive naming, installer project-mode release discovery) continue to derive from that file rather than gaining another hard-coded release source.

## r406 regression coverage

Added:

```text
scripts/tests/test-r406-updater-fixes.py
```

Validation in the worked tree:

```text
python3 scripts/tests/test-r406-updater-fixes.py             PASS
python3 scripts/tests/test-r405-updater-fixes.py             PASS
python3 scripts/tests/test-r404-updater-fixes.py             PASS
python3 scripts/tests/test-r400-updater-fixes.py             PASS
python3 scripts/tests/test-r397-updater-fixes.py             PASS
python3 scripts/tests/test-r394-updater-fixes.py             PASS
python3 scripts/tests/test-maintained-port-updater.py         PASS
bash scripts/tests/test-build-work-backend.sh                 PASS
bash scripts/tests/test-pkgmk-payload-guard.sh                 PASS
bash scripts/tests/test-r365-port-updater-policy.sh            PASS
python3 -m py_compile scripts/checkupdate.py scripts/bfs-port-updater.py scripts/bfs-maintained-port-updater.py  PASS
bash -n scripts/git-update-bfsos.sh                            PASS
bash -n ports/core/ca-certificates/post-install               PASS
bash -n ports/core/make-ca/post-install                       PASS
```

## Live validation next

- [ ] Merge r406 and rerun Core first.
- [ ] Confirm a successfully built package is cleaned without a permission exception.
- [ ] Confirm the Core GNU cluster no longer dominates `FETCH-ERROR` results.
- [ ] Save the fresh Core upstream TSV if any `FETCH-ERROR`/`UNVERIFIABLE` rows remain so those exact residual providers can be fixed next.
- [ ] Run `sysup` and verify the CA compatibility links survive package update + reboot.
- [ ] Exercise the distro-version dialog with a throwaway/test release only when ready to intentionally change the project release marker.

---

## Updater diagnostics: one consolidated problem report for all scanned trees

### Goal

The maintainer should not have to search through multiple `upstream-*.tsv`, `scan-*.tsv`, or build logs to find ports that the updater could not verify. Every updater scan should produce one dedicated problem report containing all `UNVERIFIABLE` and `FETCH-ERROR` results from every tree included in that scan run.

The report must make the tree and port identity explicit so a mixed multi-tree scan can be worked from one file.

### Required output

Create one timestamped TSV per updater scan run, for example:

```text
logs/update/problems-20261007-002530.tsv
```

Use columns equivalent to:

```text
status	tree	port	current_version	provider	reason	source
```

Example rows:

```text
UNVERIFIABLE	compat-32	llvm-32	23.1.2	git-tags	could not map current version to tag pattern	https://...
FETCH-ERROR	opt	example	1.4.0	directory	curl timeout	https://...
```

### Required behavior

- [x] Create exactly one consolidated problem-report file for each updater scan invocation, regardless of how many port trees are selected.
- [x] Include both `UNVERIFIABLE` and `FETCH-ERROR` rows in the same report.
- [x] Include the BFSOS tree name separately from the full port identity.
- [x] Include the full BFSOS port name/path so similarly named ports in native and compat-32 trees are unambiguous.
- [x] Include current version, provider, exact diagnostic reason, and source URL when available.
- [x] Append results from every tree processed by that scan into the same report rather than creating one file per tree.
- [x] Write a header even when the report has zero problem rows so an empty report proves the diagnostics pass ran successfully.
- [x] Do not treat `SKIP`, `CURRENT`, policy holds, or normal `REVIEW` candidates as problem rows unless they are independently `UNVERIFIABLE` or `FETCH-ERROR`.
- [x] Preserve the existing full upstream/scan logs; this report is a concise diagnostic index, not a replacement for detailed logs.
- [x] At the end-of-scan summary, print the exact path to the generated problem report.
- [x] Also print problem totals in the summary, for example `UNVERIFIABLE=15 FETCH-ERROR=2`.
- [x] Keep deterministic TSV escaping/quoting so tabs/newlines in diagnostic text cannot corrupt the file.
- [x] Add regression coverage for a scan spanning at least two trees with both failure classes present.
- [x] Add regression coverage for a completely clean scan that still produces a header-only problem report.

### Long-term maintenance use

This file is intended to become the normal follow-up input for provider maintenance. As new ports are added, upstreams move, release naming changes, or previously working providers break, the maintainer can work from the newest `problems-*.tsv` instead of manually searching arbitrary updater logs.

Expected workflow:

```text
scan one or more trees
    -> updater writes normal detailed logs
    -> updater writes one consolidated problems-*.tsv
    -> maintainer works UNVERIFIABLE/FETCH-ERROR rows by provider/reason
    -> rerun scan and compare the smaller residual report
```

### Status

- [x] Requirement defined from live multi-tree updater maintenance.
- [x] Implement consolidated report generation in the updater/checker handoff.
- [x] Add end-of-run report path to the UI summary.
- [x] Add multi-tree and clean-run regression tests.
- [x] Validate during the 2026-10-07 full BFSOS tree sweep (`problems-20261007-220739.tsv`: 53 UNVERIFIABLE, 1 FETCH-ERROR before r415 cleanup).

---

## Revisit Expat / Expat-32 release discovery after live compat-32 scan

### Live regression

During the compat-32 sweep, `checkupdate.py` again proposed an unpublished/nonexistent Expat target:

```text
compat-32/expat-32  2.8.5 -> 2.9.0  provider=github-release
```

The maintained updater then correctly refused the handoff because the rewritten archive URL did not exist:

```text
https://github.com/libexpat/libexpat/releases/download/R_2_8_5/expat-2.9.0.tar.xz
curl: (22) requested URL returned error: 404
```

The scan trace confirms the bad candidate originated in upstream discovery rather than the maintained rewrite layer:

```text
compat-32/expat-32  upstream  2.9.0
```

### Scope

Revisit both ports because they share the same upstream project/provider logic:

```text
core/expat
compat-32/expat-32
```

A fix that only special-cases the compat-32 port is not sufficient if the same GitHub-release discovery path can later affect native `core/expat`.

### Required behavior

- [x] Audit the GitHub release provider used for Expat and determine exactly how `2.9.0` is being surfaced before it is a published release with a valid source asset.
- [x] Require the Expat candidate to map to a genuinely published upstream release, not merely a tag, milestone, future release marker, branch, or version-looking GitHub object.
- [x] Require the exact expected release asset/archive form to be derivable and reachable before emitting `UPDATE`.
- [x] Keep `core/expat` and `compat-32/expat-32` on the same verified upstream release unless there is an explicit BFSOS compatibility reason to pin one separately.
- [x] Preserve the currently valid `2.8.5` target until a later Expat release is actually published and verifiable.
- [x] Do not construct a hybrid URL that combines the old tag directory (`R_2_8_5`) with a newer filename such as `expat-2.9.0.tar.xz`.
- [x] If a future version is visible upstream but the corresponding published release/source asset is not available, report it as held/unverifiable rather than `UPDATE`.
- [x] Verify the same correction for both native and compat-32 scans.
- [x] Add regression coverage proving `2.8.5 -> 2.9.0` is rejected while 2.9.0 is unpublished/unreachable.
- [x] Add regression coverage proving a later genuinely published Expat release is accepted for both `core/expat` and `compat-32/expat-32` when its expected release asset exists.

### Status

- [x] Live bad candidate reproduced for `compat-32/expat-32`.
- [x] Maintained updater correctly rejected the resulting 404 source rewrite.
- [x] Trace confirms the bad `2.9.0` originated in upstream discovery.
- [x] Audit/fix shared Expat GitHub release discovery.
- [x] Revalidate `core/expat` and `compat-32/expat-32` together.
- [x] Add regression coverage.

---

## Pin xorg-server update policy to BLFS/GLFS book version

### Live regression

During the Xorg tree sweep, the updater discovered `xorg-server 21.1.25` and tried to validate a rewritten BLFS TearFree patch URL:

```text
https://www.linuxfromscratch.org/patches/blfs/svn/xorg-server-21.1.25-tearfree_backport-2.patch
```

That URL returned HTTP 404.

The live BFSOS port remained correctly unchanged at:

```text
xorg/xorg-server
version=21.1.24
release=3
```

The existing BLFS patch is:

```text
xorg-server-21.1.24-tearfree_backport-2.patch
```

The 21.1.24 TearFree patch was then tested against xorg-server 21.1.25 and does **not** apply cleanly, so BFSOS should not advance xorg-server independently of the BLFS/GLFS book recipe.

### Policy decision

Treat `xorg/xorg-server` as a BLFS-development-book-pinned package.

For this port, the authoritative update version should follow the current **BLFS development book** recipe and its matching patch set rather than CRUX, Arch, generic upstream discovery, GLFS, or a newer Xorg tarball by itself.

A newer upstream xorg-server version is not sufficient to emit an actionable BFSOS update when the corresponding book patch set and recipe have not moved with it.

### Required updater behavior

- [x] Add an explicit policy mapping for `xorg/xorg-server` to the **BLFS development book** version.
- [x] Do not promote a newer generic upstream, CRUX, or Arch xorg-server version ahead of the selected book recipe.
- [ ] Keep book-provided patch filenames and patch URLs authoritative; do not blindly substitute a candidate package version into patch filenames.
- [ ] Require all book-required patches for the selected xorg-server version to exist and be reachable before emitting an actionable `UPDATE`.
- [ ] If upstream is newer than the book, report it as informational/policy-held rather than rewriting the Pkgfile or patch URLs.
- [x] Do not attempt to carry the `21.1.24` TearFree patch onto `21.1.25`; live dry-run testing showed it does not apply cleanly.
- [ ] Once the **BLFS development book** advances xorg-server and publishes a matching patch set/recipe, allow BFSOS to move to that version.
- [x] Add a regression test proving an upstream-only `21.1.25` candidate is held while the book remains on `21.1.24`.
- [ ] Add a regression test proving patch URL rewriting cannot turn `xorg-server-21.1.24-tearfree_backport-2.patch` into a nonexistent `21.1.25` patch.

### Status

- [x] Live 21.1.25 candidate encountered.
- [x] Rewritten 21.1.25 BLFS TearFree patch URL reproduced as HTTP 404.
- [x] Live Pkgfile confirmed to remain at 21.1.24-3.
- [x] Existing 21.1.24 TearFree patch tested against 21.1.25 and failed to apply cleanly.
- [x] Policy decision: follow the **BLFS development book** version for `xorg/xorg-server`.
- [x] Implement updater policy mapping and regression coverage.

---

## Updater: synchronize all active version references to the user-selected target

### Bug

The updater can successfully bump and build a port while leaving active BFSOS version references elsewhere in the project at the old version.

This was exposed by the 0.9.1 update sweep: several ports were correctly updated, but `scripts/bfs-ports-static-audit.sh` still expected the previous versions. The ISO builder then fetched the current Git tree, ran the release/static audit, and aborted even though the updated ports and newly built base archive were valid.

Examples seen during the live failure included:

```text
linux           7.2.8   -> 7.2.9
linux-headers   6.18.54 -> 6.18.55
linux-lts       6.18.54 -> 6.18.55
thunar          4.20.9  -> 4.20.10
firefox         155.0.1 -> 157.0.1
firefox-bin     155.0.1 -> 157.0
firefox-esr     153.2.0esr -> 153.4.0esr
xscreensaver    6.15    -> 6.16
xdg-dbus-proxy  0.1.8   -> 0.1.9
```

The corresponding static-audit expectations were not bumped, causing a false release-audit failure during ISO creation.

### Required behavior

When the user selects or explicitly specifies a target version for a port, the updater must treat that version as the requested project-wide active version for that update transaction.

For each accepted update, the updater must:

- update the target port `Pkgfile` to the user-selected version;
- update source URLs, checksums, release numbers, patches, and other version-coupled recipe data as required;
- find and update every **active, authoritative version reference** in the project that is intended to track that port;
- synchronize `scripts/bfs-ports-static-audit.sh` expected versions automatically;
- synchronize active release/audit policy files and current tests that intentionally pin the package version;
- update paired or policy-linked ports together when BFSOS policy requires them to remain aligned, such as:
  - `linux-lts` and `linux-headers`;
  - native/compat-32 pairs where the same upstream version is required;
  - other explicitly declared sibling/version-lock groups;
- preserve historical documentation, archived audit logs, old trackers, and legacy reports as historical records unless they are explicitly marked as active inputs;
- never perform blind global string replacement across the repository;
- show every planned non-Pkgfile version-reference change in the update review before applying it;
- apply all version-linked changes atomically with the port update;
- if any required active reference cannot be updated safely, mark the update as incomplete/failed and do not leave the tree in a partially synchronized state;
- after applying the update, run the relevant static audit/tests before marking the port update successful.

### User-specified version mode

Add an explicit path for the user to enter/select a version instead of only accepting the updater's discovered candidate.

Example:

```text
Port: core/linux-lts
Current: 6.18.54
Detected: 6.18.55
Target version: 6.18.55
```

The chosen `Target version` becomes the version the updater must propagate through all active project references for that port/update group.

If the user chooses a different valid version than the automatically detected one, the updater must validate that version and its source before changing the tree.

### Active-reference model

The updater should maintain or derive a machine-readable mapping of version consumers rather than searching historical text blindly.

At minimum, version consumers should distinguish:

```text
port recipe
static audit expectation
current test expectation
release policy/current metadata
paired/version-locked port
historical documentation/log -- never rewrite automatically
```

Prefer a centralized manifest/mapping so future version bumps do not require adding another ad-hoc search-and-replace rule.

### Transaction and rollback requirement

Before changing files, record the complete planned update set.

Only report `BUILT` / `UPDATED` after:

1. all selected port recipe changes are applied;
2. all required active version consumers are synchronized;
3. source validation succeeds;
4. package build/test succeeds where applicable;
5. `scripts/bfs-ports-static-audit.sh` passes;
6. relevant updater regression tests pass.

If any step fails, roll back **all files changed by that update transaction**, including audit/test/version-reference files, not just the Pkgfile.

### Regression tests

Add tests covering at least:

- a normal single-port version bump updates its static-audit expected version;
- `linux-lts` target bumps `linux-headers` to the same BFSOS LTS version;
- an update with active test expectations updates those expectations;
- historical tracker/audit/log files containing the old version are left unchanged;
- a user-specified valid target version is propagated even when it differs from the auto-detected candidate;
- an invalid/nonexistent user-specified target is rejected without modifying the tree;
- failure while updating any active consumer rolls back the entire transaction;
- the release/static audit passes immediately after a successful updater transaction.

### Acceptance criteria

A port update is not complete merely because its `Pkgfile` builds.

After the updater reports an update as successful, a clean checkout of the resulting commit must be able to run the BFSOS static/release audit without failing because an active expected-version reference was left behind.

**Status:** OPEN — identified during the 0.9.1 ISO build after the updater changed port versions but left the static-audit version baseline stale.


---

## ISO builder: add resume/finalize-only mode for preserved failed builds

### Problem

The ISO builder preserves its working tree/live root when a late-stage failure occurs, but there is currently no supported way to reuse that preserved state and resume only the final ISO assembly steps.

During the 0.9.1 ISO build, the full live package set had already been built and installed successfully. The build then stopped during the final live-root archive audit because two manually downloaded source archives were present under `/home/bfs/BFSOS`.

After removing the offending files, the only practical option was to rerun the entire ISO builder, including expensive package, kernel, firmware, and live-root preparation work that had already completed successfully.

### Required behavior

Add an explicit resume/finalize mode, for example:

```text
./scripts/bfs-build-iso.sh --resume-final
```

or:

```text
./scripts/bfs-build-iso.sh --finalize-existing
```

The final CLI spelling can be chosen during implementation, but the behavior must be unambiguous.

When this mode is requested, the builder must reuse the preserved ISO work tree and skip completed expensive preparation stages.

### Safety validation before resume

Before allowing finalization, verify that the preserved state is valid and belongs to the expected BFSOS build.

At minimum check:

- preserved ISO work directory exists;
- live root exists and is populated;
- live root contains required core files;
- expected BFSOS version matches the current requested build;
- preserved source commit/build identifier matches or is explicitly accepted by the user;
- kernel and required boot files exist;
- required live/installer packages and policy files were installed;
- live-session preset/policy verification previously completed or can be re-run safely;
- no stale mounts, bind mounts, or partially mounted pseudo-filesystems remain;
- required ISO assembly tools are available;
- enough free disk space exists for squashfs and ISO creation.

If validation fails, refuse resume mode with a clear explanation and require a normal rebuild.

### Resume boundary

The resume/finalize mode should begin at the latest safe point after live-root preparation.

Expected operations include, as applicable:

1. re-run final live-root cleanup;
2. re-run the forbidden archive/cache audit;
3. regenerate any final live initramfs/boot artifacts that depend on the finished root;
4. build/update squashfs;
5. construct the ISO filesystem tree;
6. generate GRUB/El Torito/UEFI boot content;
7. run `grub-mkrescue` / `xorriso` or the current equivalent;
8. generate checksum and build-info files;
9. run final ISO validation/smoke checks.

Do not rebuild the complete live package set, kernel, firmware, or base root unless a required resume prerequisite is missing or stale.

### Persistent state marker

Write a machine-readable state file into the ISO work directory as major phases complete.

Example phases:

```text
base-extracted
ports-synced
packages-installed
live-policy-installed
cleanup-complete
squashfs-complete
iso-tree-complete
iso-complete
```

Also record:

```text
BFSOS version
architecture
Git commit
base archive path/hash
build timestamp
builder revision
```

Resume mode should use this state rather than inferring completion only from files that happen to exist.

### Failure behavior

On failure after an expensive completed phase:

- preserve the work tree;
- preserve the state file;
- print the exact resume command the user can run after fixing the problem;
- clearly state which phase completed and which phase failed.

Example:

```text
ISO build stopped during final live-root audit.
Preserved work tree: /var/tmp/bfsos-iso-brian
Last completed phase: live-policy-installed

After correcting the problem, resume with:
  ./scripts/bfs-build-iso.sh --resume-final
```

### Menu integration

Add a corresponding bootstrap/menu option when resumable ISO state is detected, such as:

```text
Resume preserved ISO build
```

Do not present the option when no valid resumable ISO state exists.

### Regression tests

Add tests covering:

- late failure preserves a resumable work tree;
- resume mode skips package/kernel rebuild stages;
- invalid or incomplete preserved state is rejected;
- version mismatch is rejected or explicitly confirmed;
- Git commit mismatch is rejected or explicitly confirmed;
- stale mounts are detected and cleaned/refused safely;
- final live-root audit is re-run on resume;
- successful resumed build produces the same expected ISO artifacts/checksums metadata path as a normal build;
- completed ISO state is not accidentally resumed as an incomplete build.

### Acceptance criteria

A failure after the expensive live-root preparation phase must not require rebuilding the entire ISO from scratch when the preserved state is still valid.

The user must be able to correct a late-stage problem and resume directly into final ISO assembly with one explicit, validated command.

**Status:** IMPLEMENTED / LIVE RETEST PENDING — `--resume-final` / `--finalize-existing` now uses a persistent phase/state file, validates version/arch/Git/base checksum/live-root state, cleans/refuses stale mounts, regenerates the live initramfs, reruns final cleanup/audit, rebuilds squashfs/ISO metadata, and prints an exact resume hint after late failure. Menu auto-discovery of resumable state remains a follow-up enhancement.

---

## Installer/live ISO: restore GPM default enablement

### Problem

GPM is installed, but it is no longer enabled by default after a normal BFSOS installation.

Live testing of the 0.9.1 ISO also suggests GPM may not be enabled in the live environment itself.

This is a regression from the intended console behavior: when GPM is present, the text console should have mouse support available automatically without requiring the user to manually enable `gpm.service`.

### Required behavior

- Ensure the installer enables `gpm.service` on the installed target whenever GPM is installed.
- Verify whether the live ISO should also start/enable GPM by default and restore that behavior if intended.
- Make the behavior explicit in the installer/live service policy rather than relying on package-side defaults.
- Keep the existing general live preset policy intact; if the live image uses a `disable *` systemd preset policy, explicitly allow/enable GPM through the live setup path instead of weakening the preset globally.
- Do not enable GPM on systems where the `gpm` package is not installed.

### Verification

After installation, the installed system should report:

```text
systemctl is-enabled gpm
enabled
```

and after boot:

```text
systemctl is-active gpm
active
```

For the live ISO, verify the intended policy with:

```text
systemctl is-enabled gpm
systemctl is-active gpm
```

If GPM is intentionally meant to run in the live environment, both should reflect that policy without requiring manual intervention.

### Regression tests

Add checks covering:

- installer target with GPM installed gets `gpm.service` enabled;
- live ISO policy handles GPM explicitly;
- the `disable *` live preset does not accidentally suppress a service that BFSOS intends to provide by default;
- installer does not fail if GPM is absent;
- service enablement survives reboot of a freshly installed BFSOS system.

**Status:** IMPLEMENTED / LIVE RETEST PENDING — installer enablement was moved after `offline_systemctl()` is defined and after `preset-all`, and the live ISO now explicitly enables/verifies `gpm.service` while retaining the global `disable *` preset. Static regression coverage was added; fresh installed/live boot verification remains pending.

---

## 2026-10-07 updater retest: Opt tree findings

A fresh updater pass over the Opt tree produced the following live results:

```text
opt/firefox-bin: BUILT
opt/gvim: BUILT
opt/lmdb: NEEDS REVIEW
opt/nodejs: NEEDS REVIEW
opt/spice-gtk: BUILT
opt/subversion: ROLLED BACK: BUILD FAILED (1)
```

Scan log:

```text
/home/brian/BFSOS/logs/update/scan-20261007-205802.tsv
```

Subversion build log:

```text
/home/brian/BFSOS/logs/update/build-20261007-210431-opt-subversion.log
```

### LMDB source rewrite regression remains reproducible

The updater again generated an invalid rewritten OpenLDAP LMDB source URL:

```text
https://git.openldap.org/openldap/openldap/-/archive/LMDB_2.MP/openldap-LMDB_2.MP.tar.bz2
```

The URL returned HTTP 404.

This confirms the LMDB/source-rewrite issue is not historical only; it remains reproducible in the current updater.

Required behavior:

- Never emit unresolved template/version fragments such as `2.MP`, `MAJOR`, `MINOR`, or similar placeholders into a rewritten source URL.
- Treat source URL rewriting as a structured transformation based on the actual candidate version.
- Validate the complete rewritten URL before modifying the port.
- If the rewritten URL is unreachable, preserve the original port unchanged and return `NEEDS REVIEW`.
- Add a regression test specifically for OpenLDAP LMDB tag/archive naming.

### Patch-bearing port behavior

`opt/nodejs` correctly stopped at `NEEDS REVIEW` because the port carries patches and automatic patch handling is disabled for that case.

Keep this conservative behavior until the updater's patch-fetch/replacement workflow is fully implemented and verified.

### Rollback behavior

`opt/subversion` failed its build and was rolled back instead of leaving a partially updated port.

This is the desired safety behavior. Review the build log separately to determine whether the candidate itself is bad or the recipe needs adjustment.

### Successful updates

The following candidates built successfully during this pass:

```text
opt/firefox-bin
opt/gvim
opt/spice-gtk
```

These results should be used as regression evidence for the current updater workflow.

**Status:** FIXED IN r413 / LIVE RETEST PENDING — unresolved version placeholders such as `2.MP` are rejected before candidate generation, while the LMDB canonical OpenLDAP `LMDB_$version` source derivation remains in place. Node.js review gating and Subversion rollback remain intentionally conservative.

---

## 2026-10-07 updater retest: reject sibling release/tag families

A fresh Compat-32 scan produced:

```text
compat-32/libvisual-32: ROLLED BACK: BUILD FAILED (1)
```

The installed/current BFSOS port is already on the correct libvisual release:

```text
name=libvisual-32
version=0.4.2
release=2
source=(https://github.com/Libvisual/libvisual/releases/download/libvisual-$version/libvisual-$version.tar.bz2)
```

The updater incorrectly selected the sibling `libvisual-plugins-0.4.2` release/tag family from the same upstream repository and attempted to build it as `libvisual-32`. The failed candidate unpacked as `libvisual-plugins-0.4.2`, confirming that this was not a real libvisual version update.

The resulting GTK/GdkPixbuf configure failure was therefore secondary to the wrong-source selection. Do not add GTK3-32 or change the current `libvisual-32` recipe to work around this false candidate.

### Required behavior

- Treat a repository containing multiple release/tag families as multiple distinct upstream artifacts.
- Match candidate tags/releases to the BFSOS port's existing source family, not merely to the repository or a version-looking suffix.
- For this port, accept the `libvisual-$version` family and reject sibling families such as `libvisual-plugins-$version`.
- Preserve the source archive basename/prefix lineage when determining whether a tag belongs to the current port.
- Do not reinterpret a sibling component's version as an update to the current package merely because both are hosted in the same repository.
- Validate the selected candidate's tag name, archive basename, and extracted top-level directory against the current port's expected package family before modifying the Pkgfile or starting a build.
- If more than one plausible release family exists and identity cannot be proven, leave the port unchanged and report `NEEDS REVIEW` rather than attempting a cross-component update.
- Keep rollback behavior for any incorrect candidate that nevertheless reaches the build stage.

### Regression test

Add a fixture for a repository that publishes both:

```text
libvisual-0.4.2
libvisual-plugins-0.4.2
```

When scanning `compat-32/libvisual-32` with an existing source pattern containing `libvisual-$version`, the updater must select only the `libvisual-*` family and must never propose or build `libvisual-plugins-*`.

**Status:** FIXED IN r413 / LIVE RETEST PENDING — GitHub release discovery now rejects a sibling release whose extracted candidate does not belong to the current version/tag family. Regression coverage reproduces `libvisual-0.4.2` vs `libvisual-plugins-0.4.2`; the current `libvisual-32 0.4.2-2` recipe is unchanged.


---

## r413 implementation notes

Worked from the uploaded full BFSOS project archive and r412 tracker.

Implemented in this revision:

- **GitHub sibling release-family guard:** `checkupdate.py` no longer accepts a tag such as `libvisual-plugins-0.4.2` as the version for a port whose current release family is `libvisual-0.4.2`.
- **Published-asset validation for GitHub release ports:** a newer release tag is actionable only when the corresponding release asset derived from the current source convention exists. This closes the premature Expat 2.9.0 path.
- **Expat rollback to released state:** both `core/expat` and `compat-32/expat-32` are restored to `2.8.5` pending an actually published 2.9.0 release asset.
- **Unresolved-version guard:** candidate strings containing template placeholders such as `2.MP`, `MAJOR`, `MINOR`, or `PATCH` are rejected rather than being written into source URLs. This closes the live LMDB `LMDB_2.MP` failure path.
- **xorg-server policy hold:** `xorg/xorg-server` is now explicitly mapped to BLFS development-book authority. Generic upstream 21.1.25 is suppressed while BLFS remains on 21.1.24, so the 21.1.24 TearFree patch is not rewritten onto an incompatible upstream release.
- **Consolidated updater problem report:** every scan now writes one `logs/update/problems-<stamp>.tsv` containing only `UNVERIFIABLE` and `FETCH-ERROR` rows, including tree, full port identity, current version, provider, reason, and source. Header-only clean reports are retained and totals/path are printed.
- **GPM default enablement:** installer GPM enablement now runs after `offline_systemctl()` exists and after `preset-all`. The live ISO explicitly enables and verifies `gpm.service` while preserving the BFSOS global `disable *` preset.
- **ISO finalization resume:** added `--resume-final` (alias `--finalize-existing`) with persistent phase metadata, version/architecture/Git/base-hash checks, stale-mount cleanup/refusal, final initramfs regeneration, live-root audit, squashfs/ISO rebuild, and late-failure resume hints.
- **Current static-audit baseline:** synchronized `firefox-bin` to the already-updated `157.0.1` port so both ports/static and release static audits pass again. The broader automatic active-consumer synchronization transaction remains open.
- Added `scripts/tests/test-r413-tracker-fixes.py`.

Validation performed in the supplied tree:

```text
python3 -m py_compile scripts/bfs-port-updater.py scripts/checkupdate.py scripts/bfs-maintained-port-updater.py  PASS
python3 scripts/tests/test-r377-port-updater-fixes.py                                             PASS
python3 scripts/tests/test-r394-updater-fixes.py                                             PASS
python3 scripts/tests/test-r396-updater-fixes.py                                             PASS
python3 scripts/tests/test-r406-updater-fixes.py                                             PASS
python3 scripts/tests/test-r413-tracker-fixes.py                                             PASS
bash scripts/tests/test-iso-builder-source.sh                                                PASS
bash -n scripts/install-bfs-menu-current.sh scripts/bfs-build-iso.sh                         PASS
./scripts/bfs-ports-static-audit.sh                                                          PASS
./scripts/bfs-release-static-audit.sh                                                        PASS
```

Still intentionally open rather than guessed:

- project-wide active-version consumer synchronization / user-selected arbitrary target transaction;
- package-manager-level Fribidi same-owner replacement, which needs `prt-get/pkgadd` implementation/live ownership evidence;
- generic automatic Brasero build-system migration detection beyond the already repaired Brasero port;
- live-only validation checkboxes requiring a fresh BFSOS scan/install/reboot;
- ISO bootstrap-menu auto-detection/presentation of resumable finalization state.


---

## r414 live regression — false Expat and LMDB candidates still reach the picker

A full-tree live scan after the r413 changes still surfaced two invalid REVIEW candidates:

```text
compat-32/expat-32  2.8.5 -> 2.9.0  r1->1  [github-release; REVIEW]
opt/lmdb             1.0.2 -> 2.MP   r1->1  [git-tags; REVIEW]
```

Both must remain OFF. These are updater regressions, not valid package updates.

### Expat 2.8.5 -> 2.9.0 false candidate

The r413 GitHub release/asset guard did not close every discovery path. `compat-32/expat-32` still receives `2.9.0` from the GitHub-release provider even though the target must not be considered actionable unless the actual expected release artifact exists for the port's current source convention.

Required fix:

- Trace the exact `github-release` path that still emits `2.9.0` for `compat-32/expat-32`.
- Require exact target-asset validation before candidate creation, not only during a later apply/build stage.
- Derive the expected asset from the current Pkgfile source family and verify the concrete target URL/archive exists.
- If the release/tag exists but the required source asset does not, suppress the candidate entirely and emit a diagnostic instead of a REVIEW checkbox.
- Apply the same logic to native `core/expat` so native and compat-32 cannot diverge through different discovery paths.
- Add a live-equivalent regression proving `2.8.5 -> 2.9.0` is absent from the picker until the real release asset is published.

Status:

- [x] Reproduce the exact `github-release` candidate path used by the live scanner.
- [x] Move exact release-asset validation ahead of picker generation.
- [x] Suppress unpublished/non-actionable Expat targets from both native and compat-32 scans.
- [x] Add regression coverage matching the live full-tree scan behavior.
- [ ] Live retest: no Expat 2.9.0 candidate appears while the expected source release is unavailable.

### LMDB 1.0.2 -> 2.MP false candidate

The r413 unresolved-version guard also does not cover every provider path. The live scanner still emits:

```text
opt/lmdb 1.0.2 -> 2.MP [git-tags; REVIEW]
```

`2.MP` is not a version. It is a fragment/template token derived from LMDB/OpenLDAP tag naming and must never survive provider parsing into candidate comparison or picker presentation.

Required fix:

- Trace the `git-tags` parser for the LMDB source/tag family.
- Reject unresolved/template-like tokens before version comparison and before candidate creation.
- Treat tokens containing placeholders such as `MP`, `MAJOR`, `MINOR`, `PATCH`, unresolved shell variables, or non-release tag fragments as non-versions.
- For LMDB specifically, preserve the real `LMDB_$version` release family and extract only the concrete numeric release portion.
- Do not let generic tag parsing reinterpret `LMDB_2.MP`, documentation/examples, branch-like refs, or template text as newer releases.
- If no concrete newer LMDB release is found, return current/no-candidate with a trace diagnostic.
- Add a regression reproducing the live `git-tags` provider path, not merely the later apply guard.

Status:

- [x] Reproduce why `git-tags` still emits `2.MP`.
- [x] Reject placeholder/template tokens inside provider discovery before comparison.
- [x] Keep LMDB on the concrete `LMDB_$version` tag family and reject template/non-release tokens before comparison.
- [x] Add regression coverage matching the live full-tree scan behavior.
- [ ] Live retest: `opt/lmdb 1.0.2 -> 2.MP` never appears in the picker.

### Acceptance criteria

After the fix, a full-tree scan on the same project state must not show either invalid candidate. The updater should log why each bad upstream object/tag was ignored, but the normal update checklist should contain neither:

```text
compat-32/expat-32 2.8.5 -> 2.9.0
opt/lmdb            1.0.2 -> 2.MP
```

---

# r415 implementation — full-tree provider and fetch-error cleanup

Worked from the full-tree diagnostic generated by the live BFSOS sweep:

```text
logs/update/problems-20261007-220739.tsv
UNVERIFIABLE=53
FETCH-ERROR=1
```

The purpose of this pass is not to hide provider failures.  It separates ports that need an explicit release provider or maintained source mirror from ports whose version is intentionally derived from a pinned commit/package date and therefore should not be sent through generic release discovery.

## r414 false-candidate regressions

- [x] Move the LMDB unresolved-version guard into the provider comparison layer. `2.MP`, `MAJOR`, `MINOR`, `PATCH`, `VERSION`, unresolved shell variables, and equivalent template fragments are rejected before they can become candidates.
- [x] Replace the GitHub `/releases/latest` heuristic with published Releases API enumeration for release-asset ports.
- [x] Require the exact current release asset to identify the current GitHub release family.
- [x] Require the exact derived target asset to exist in the published release metadata before a target is eligible.
- [x] Ignore draft/prerelease GitHub releases.
- [x] Preserve tag-family encoding, including dotted, underscored, hyphenated, slash-containing, and condensed numeric tags.
- [x] Keep sibling release families out of the candidate list (`libvisual-*` vs `libvisual-plugins-*`).
- [x] Add live-equivalent regressions for Expat `2.8.5 -> 2.9.0`, LMDB `1.0.2 -> 2.MP`, and libvisual sibling releases.
- [ ] Live full-tree retest: neither false candidate appears in the picker.

## SourceForge and provider cleanup

- [x] Rework SourceForge discovery around project RSS/file-browser metadata rather than treating redirector download hosts as browsable indexes.
- [x] Search the exact file folder, its parent release folder, and project root conservatively.
- [x] Support compact historical filename encodings such as Info-ZIP `unzip60`/`zip30` while comparing them as `6.0`/`3.0`.
- [x] Add explicit official-provider paths for Less, mpdecimal, ArgyllCMS, FFTW, Chromium stable, Unicode UCD, Rust stable, NVIDIA Unix drivers, and the annual TeX Live source snapshot.
- [x] Add stable upstream Git repository discovery overrides for packages whose current tarball host does not expose a useful release index, including Dash, fdk-aac, Exempi, libstemmer, libwebp, net-tools, Openbox, mtdev, and the libburn/libisofs/libisoburn family.
- [x] Keep formal-release GitHub ports on the published-release/asset path instead of generic git tags where asset validation is stronger (Little CMS).

## Maintained source URL repairs from the full-tree problem report

The following source templates were repaired without changing package versions:

- [x] `compat-32/icu-32`: use ICU 78+ release naming (`release-$version` / `icu4c-$version-sources.tgz`) to match native ICU and the actual published asset convention.
- [x] `core/dash`: replace the unavailable Gondor tarball host with the stable pkgsrc distfile mirror; version discovery uses the upstream Dash Git tags.
- [x] `opt/expect`: use the explicit SourceForge project/file path.
- [x] `opt/fdk-aac`: use the explicit SourceForge project/file path while discovering releases from the upstream Git repository.
- [x] `opt/gutenprint`: use the explicit SourceForge project/version path.
- [x] `opt/highlight`: use the versioned MacPorts distfile mirror because the canonical server rejects automated fetches; version remains 4.21.
- [x] `opt/lame`: use HTTPS for the SourceForge download path.
- [x] `opt/lcms2` and `compat-32/lcms2-32`: use the canonical GitHub release asset URL for tag `lcms2.$version`.
- [x] `opt/libatasmart`: retain final upstream 0.19 but use a stable Debian original-source mirror because the historical 0pointer host is no longer reliable.
- [x] `opt/libksba`: move from the stale mirror to the canonical GnuPG FTP-over-HTTPS source.
- [x] `opt/nvidia`, `compat-32/nvidia-32`, `compat-32/nvidia-fb-32`: normalize to NVIDIA's canonical `download.nvidia.com` host and use the NVIDIA Unix release page for version discovery.
- [x] `opt/xdotool`: replace the nonexistent GitHub release asset URL with an aliased GitHub tag archive.
- [x] `xorg/mtdev`: replace the stale Launchpad download with a stable Debian original-source mirror and use the maintained upstream tag repository for discovery.

## Intentional non-release ports

Generic upstream release discovery is now skipped, with an explicit `policy-pin` diagnostic, for ports whose BFSOS version is not a normal upstream release number:

- [x] `core/ca-certificates` — BFSOS trust-bundle packaging date; certificate data is audited separately.
- [x] `core/prt-utils` — version tied to the explicitly pinned CRUX commit.
- [x] `opt/gn` — pinned to the Chromium-compatible commit.
- [x] `opt/rapidjson` — intentionally tracks a dated VCS snapshot/commit.
- [x] `plasma/libdbusmenu-qt5` — legacy Ubuntu snapshot without a maintained upstream release series.
- [x] `opt/libatasmart` — dormant final 0.19 release; source mirroring is a build-reliability issue, not an update-discovery problem.

These are reported as `SKIP [policy-pin]`, not as `CURRENT`; this keeps the scan honest while removing false `UNVERIFIABLE` noise.

## Regression maintenance

- [x] Add `scripts/tests/test-r415-updater-fixes.py` covering the LMDB provider-level placeholder guard, Expat exact-asset requirement, libvisual sibling-family rejection, compact SourceForge version parsing, policy-pin behavior, TeX Live annual-source discovery, and repaired source templates.
- [x] Refresh the stale r405 harfbuzz fixture from 14.5.1 to the current tree's 14.6.0 so the historical regression test validates policy rather than an obsolete package version.
- [ ] Live rerun the complete port-tree sweep and compare the new `problems-*.tsv` against `problems-20261007-220739.tsv`.
- [ ] Work any residual `UNVERIFIABLE`/`FETCH-ERROR` rows from the new report; upstream anti-bot responses or temporary timeouts must not be silently reclassified as success.

## Validation boundary

The supplied project can be syntax-checked and regression-tested offline.  A true provider sweep cannot be claimed inside the artifact environment because external DNS/network access is unavailable there.  Therefore the final acceptance gate remains the next live BFSOS all-tree scan.


### r415 offline validation completed

```text
python3 -m py_compile scripts/checkupdate.py scripts/bfs-port-updater.py scripts/bfs-maintained-port-updater.py  PASS
python3 scripts/tests/test-r377-port-updater-fixes.py                                            PASS
python3 scripts/tests/test-maintained-port-updater.py                                            PASS
python3 scripts/tests/test-r394-updater-fixes.py                                                 PASS
python3 scripts/tests/test-r396-updater-fixes.py                                                 PASS
python3 scripts/tests/test-r405-updater-fixes.py                                                 PASS
python3 scripts/tests/test-r406-updater-fixes.py                                                 PASS
python3 scripts/tests/test-r413-tracker-fixes.py                                                 PASS
python3 scripts/tests/test-r415-updater-fixes.py                                                 PASS
bash scripts/tests/test-r365-port-updater-policy.sh                                              PASS
./scripts/bfs-ports-static-audit.sh                                                              PASS
./scripts/bfs-release-static-audit.sh                                                            PASS
bash -n on every Pkgfile changed by r415                                                        PASS
git diff --check                                                                                 PASS
```

A live all-tree provider check is still required on BFSOS because this build environment cannot perform the same external-network sweep.  The next live `problems-*.tsv` is the acceptance evidence for the provider/fetch-error cleanup.


---

# r416 live full-tree follow-up — SKIP audit and residual provider failures

Live full-tree scan summary after r415:

```text
CURRENT      1308
UPDATE         19
UNVERIFIABLE   11
FETCH-ERROR     0
SKIP           28
ERROR           0
TOTAL        1366
ELAPSED      48.4s
```

This is a major improvement over the prior `UNVERIFIABLE=53 / FETCH-ERROR=1` pass. The remaining work is now small enough to classify explicitly instead of treating the provider layer as a generic failure bucket.

## SKIP audit

Most of the 28 SKIPs are intentional and should remain SKIP: local/meta ports, compatibility pins, project meta packages, Chromium-coupled GN, dated VCS snapshots, legacy snapshots, and similar non-release-tracking packages.

Three SKIPs need correction because they are real upstream-tracked packages rather than local/meta ports:

- [x] `compat-32/alsa-plugins-32` — do not classify as `local/meta port: no remote source`; map it to the same ALSA Plugins upstream/version family as the native port and keep native/compat-32 coordinated where appropriate.
- [x] `opt/alsa-plugins` — do not classify as local/meta; add/restore a normal upstream release provider.
- [x] `opt/publicsuffix-list` — do not classify as local/meta merely because the source is generated/data-oriented; add an explicit upstream provider or an explicit policy rule that reflects how BFSOS intends to version/update the list.

Acceptance criterion: these three ports must either be checked against a real upstream/update policy or have a documented intentional pin reason. They must not be hidden behind the generic `local/meta port: no remote source` classification.

## Residual UNVERIFIABLE set

The live problem report contains 11 rows and zero FETCH-ERROR rows. Work these by shared root cause.

### GitHub API 403 / rate-limit fallback

Affected ports:

```text
opt/bubblewrap
opt/c-ares
opt/cups-filters
opt/cyrus-sasl
```

All four have reachable current source archives but the GitHub Releases API returned HTTP 403 repeatedly. This is one provider-infrastructure issue, not four port failures.

Required fix:

- [x] Detect GitHub API 403/rate-limit failures distinctly from package/version verification failures.
- [x] Add a non-API GitHub fallback that can conservatively discover published releases/tags without requiring the rate-limited API.
- [x] Preserve exact release-family and asset validation when using the fallback.
- [x] Do not mark the port CURRENT merely because the API is unavailable.
- [x] Keep the result UNVERIFIABLE only if both the primary and safe fallback paths fail.
- [x] Add one regression fixture proving a simulated API 403 falls back successfully while sibling/prerelease releases remain rejected.

### GitHub release-asset matching bugs

Affected ports:

```text
core/bc 7.1.0
opt/libpaper 2.3.0
plasma/kddockwidgets 2.4.1
```

The current source URLs are reachable, so these are not broken BFSOS ports. The checker is failing to map current release metadata/assets back to the existing source convention.

Required fix:

- [x] Audit asset-name matching so a reachable current source is not rejected solely because GitHub metadata names/cases differ from the local archive convention.
- [x] `core/bc`: correctly match the current `bc-7.1.0.tar.xz` release/source family.
- [x] `opt/libpaper`: correctly map tag `v$version` and the `libpaper-$version.tar.gz` source family.
- [x] `plasma/kddockwidgets`: handle upstream's `v$version` release/tag and archive basename/case without requiring an incorrect `KDDockWidgets-*` asset spelling.
- [x] Keep sibling-release-family protection intact while relaxing only case/known archive-template mismatches that can be proven from the current source.
- [x] Add regressions for all three live cases.

### Ghostscript condensed tag normalization

Live row:

```text
opt/ghostscript 10.08.0
provider results do not contain the current version; sibling/nonmatching release families ignored
source: .../gs10080/ghostscript-10.08.0.tar.xz
```

Required fix:

- [x] Add package-scoped Ghostscript tag normalization so `gs10080` maps to release `10.08.0`.
- [x] Preserve exact archive validation (`ghostscript-$version.tar.xz`).
- [x] Do not generalize condensed-digit decoding to unrelated packages.
- [x] Add regression coverage for `10.08.0 <-> gs10080`.

### Openbox dormant/upstream-tag handling

Live row:

```text
opt/openbox 3.6.1
git-tags: could not derive a tag pattern that maps back to the current version
current source reachable
```

Required fix:

- [x] Audit the Openbox upstream tag/release history and derive an explicit provider rule if there is a stable tag mapping for 3.6.1.
- [x] If upstream is effectively dormant at 3.6.1 and no reliable release-provider mapping exists, use a documented `policy-pin` instead of repeated UNVERIFIABLE noise.
- [x] Do not silently classify the port CURRENT without either a provider or an explicit dormant-final-release policy.

### RARLAB HTTP 403 handling

Live row:

```text
opt/unrar 7.3.1
provider fetch failed: HTTP 403
source: https://www.rarlab.com/rar/unrarsrc-7.3.1.tar.gz
```

Required fix:

- [x] Add site-specific fetch handling for RARLAB, including a normal browser-like User-Agent and conservative retry behavior.
- [x] If the source archive remains directly reachable but the release-index probe is blocked, use a safe alternate discovery path instead of treating the port as a version failure.
- [x] Preserve UNVERIFIABLE if no trustworthy version source can be reached.
- [x] Add a regression for a provider index returning 403 while the current source archive remains valid.

### Info-ZIP / SourceForge compact-version parsing

Live row:

```text
opt/unzip 6.0
sourceforge: provider results do not contain the current version
source: .../infozip/unzip60.tar.gz
```

The filename encodes `6.0` as `60`. r415 added generic compact-version handling, but this live row proves the SourceForge path still does not map the current release correctly.

Required fix:

- [x] Trace the exact SourceForge provider path used by `opt/unzip`.
- [x] Map `unzip60` to version `6.0` before current-version verification.
- [x] Keep the compact-version rule scoped to the Info-ZIP filename family rather than applying it globally.
- [x] Add a live-equivalent regression for `opt/unzip 6.0`.

## Live-validation status from r415

- [x] Consolidated problems report validated during a complete BFSOS tree sweep.
- [x] Full-tree scan completed with `FETCH-ERROR=0`.
- [x] Residual `UNVERIFIABLE` count reduced from 53 to 11.
- [ ] Verify the r414 Expat and LMDB false candidates are absent from the final update picker/results.
- [ ] Audit the 19 UPDATE candidates after picker completion; separate real releases from any remaining false positives before applying.
- [ ] Re-run the full-tree scan after the r416 provider fixes and target a residual problem report consisting only of intentionally unverifiable/policy-held cases.

## Files from the live r415 validation pass

```text
logs/update/upstream-20261007-230007.tsv
logs/update/problems-20261007-230007.tsv
logs/update/scan-20261007-230001.tsv
```

Retain these as regression evidence for the next updater pass.


---

# r417 live picker audit — suppress invalid update candidates

A fresh full-tree picker after r415/r416 still surfaced several REVIEW candidates that must not be treated as normal updates. Only `opt/unicode-character-database 17.0.0 -> 18.0.0` was judged a valid ordinary update from this screen; the items below must remain OFF until the updater logic is corrected.

## Expat / Expat-32 unpublished 2.9.0 still reaches picker

Live picker:

```text
compat-32/expat-32  2.8.5 -> 2.9.0  [github-release; REVIEW]
```

This is already tracked in r414/r416 and remains a hard regression gate.

Required fix:

- [x] Ensure exact published release-asset validation happens before candidate creation on every GitHub-release path.
- [x] Suppress `2.9.0` for both `core/expat` and `compat-32/expat-32` until the expected upstream source asset is actually published.
- [x] Do not downgrade this to REVIEW merely because a version-looking GitHub object exists.
- [x] Keep one shared native/compat-32 regression so the pair cannot diverge.

## Gutenprint: reject SourceForge snapshot builds for release-tracking port

Live picker:

```text
opt/gutenprint  5.3.5 -> 5.3.6-2026-02-16T02-19-a019bf9c  [sourceforge; REVIEW]
```

The candidate is a dated snapshot/VCS-style build, not a normal formal Gutenprint release. BFSOS currently tracks release-style versions.

Required fix:

- [x] Detect SourceForge snapshot/nightly/development directories and snapshot-style candidate versions.
- [x] For release-tracking BFSOS ports, reject dated/hash snapshot candidates unless the port is explicitly configured to track snapshots.
- [x] Keep snapshots eligible only for ports whose current source/version policy is snapshot-tracking.
- [x] Emit a trace such as `rejected: downstream/upstream snapshot; BFSOS port tracks formal releases`.
- [x] Add a Gutenprint regression reproducing `5.3.5 -> 5.3.6-2026-02-16T02-19-a019bf9c` and requiring no picker entry.

## LAME: reject bogus SourceForge compact/legacy artifact version `398-2`

Live picker:

```text
opt/lame  4.0 -> 398-2  [sourceforge; REVIEW]
```

`398-2` is not a valid newer LAME release relative to BFSOS `4.0`; it is a provider parsing artifact from old SourceForge naming/layout.

Required fix:

- [x] Make SourceForge candidate parsing package-family aware for LAME.
- [x] Require candidates to match the active LAME release lineage used by the current source family.
- [x] Reject legacy/compact artifact tokens such as `398-2` when the current port tracks the modern `4.0` release series.
- [x] Do not compare unrelated historical filename encodings numerically against the current release.
- [x] Add regression coverage proving `4.0 -> 398-2` is suppressed.

## LMDB: placeholder/template token `2.BP` still reaches picker

Live picker:

```text
opt/lmdb  1.0.2 -> 2.BP  [git-tags; REVIEW]
```

This is the same class of bug as the earlier `2.MP` false candidate. `2.BP` is a template/tag fragment, not a release version.

Required fix:

- [x] Reject placeholder-like alphabetic tokens generically before version comparison, including `MP`, `BP`, `MAJOR`, `MINOR`, `PATCH`, and unresolved shell/template fragments.
- [x] For OpenLDAP LMDB, only accept tags that fully match the concrete `LMDB_<numeric-version>` release family.
- [x] Do not permit documentation/example/branch/template tag fragments to survive into candidate generation.
- [x] Add regressions for both `2.MP` and `2.BP` through the actual `git-tags` provider path.
- [x] Acceptance: no LMDB placeholder candidate reaches the picker.

## Tcl: protect maintained major release branches

Live picker:

```text
opt/tcl  8.6.18 -> 9.1.0  [sourceforge; REVIEW]
```

`9.1.0` is a real Tcl release, but it is a major ABI/API generation jump. Tcl maintains multiple release branches in parallel, so a generic "latest version wins" rule is unsafe for a BFSOS port currently on the 8.6 branch.

Required fix:

- [x] Add major-series/channel awareness for Tcl.
- [x] A port on `8.6.x` must continue tracking the newest verified `8.6.x` release unless BFSOS explicitly opts into migration to Tcl 9.
- [x] Do not offer Tcl 9.x as an ordinary update to the Tcl 8.6 port.
- [x] If a deliberate Tcl 9 migration is desired later, handle it as an explicit policy/migration transaction with reverse-dependency review.
- [x] Add regression coverage proving an available `9.1.0` does not create an update candidate for current `8.6.18`.

## Unicode Character Database 18.0.0 — valid update, not a bug

Live picker:

```text
opt/unicode-character-database  17.0.0 -> 18.0.0  [unicode-public; REVIEW]
```

This candidate is valid and should remain eligible. Do not suppress it while fixing the false positives above.

Regression requirement:

- [x] Add/retain a positive control proving a genuine newer UCD release still appears while invalid Expat/Gutenprint/LAME/LMDB/Tcl candidates are suppressed.

## r417 acceptance criteria

On the same project state, a repeat picker must not show these invalid candidates:

```text
compat-32/expat-32  2.8.5 -> 2.9.0
opt/gutenprint       5.3.5 -> 5.3.6-2026-02-16T02-19-a019bf9c
opt/lame             4.0 -> 398-2
opt/lmdb             1.0.2 -> 2.BP
opt/tcl              8.6.18 -> 9.1.0
```

The valid UCD candidate must remain discoverable:

```text
opt/unicode-character-database  17.0.0 -> 18.0.0
```

These new picker findings are additive to the r416 residual-provider work for the 11 UNVERIFIABLE rows and the three questionable SKIP classifications.

---

# r418 live follow-up — Unicode Character Database multi-source handoff

## Valid UCD 18.0.0 update is blocked by single-primary-source assumption

The live updater correctly discovered:

```text
opt/unicode-character-database  17.0.0 -> 18.0.0  [unicode-public; REVIEW]
```

but the maintained-updater handoff refused the otherwise-valid update with:

```text
NEEDS REVIEW: ambiguous primary remote source archive; refusing handoff rewrite
```

The current BFSOS Pkgfile intentionally has two equally valid version-coupled remote archives:

```bash
source=(https://www.unicode.org/Public/$version/ucd/UCD.zip
  https://www.unicode.org/Public/$version/ucd/Unihan.zip)
renames=(UCD-$version.zip Unihan-$version.zip)
```

Both source entries belong to the same package release and both are driven by the same `$version`. There is no single primary archive to choose.

### Required updater behavior

- [x] Detect a version-coupled multi-source set when multiple remote sources are all controlled by the same package `$version` and belong to the same upstream release family.
- [x] Do not require a single primary remote archive for this class of port.
- [x] When changing the package version, rewrite/evaluate all version-coupled remote sources as one transaction.
- [x] Preserve source ordering and preserve unrelated local/secondary sources that are not tied to the package version.
- [x] Keep the `renames=()` array aligned with the rewritten/evaluated source set; version-bound rename entries such as `UCD-$version.zip` and `Unihan-$version.zip` must remain consistent with the target version.
- [x] Validate every resulting remote source before committing the Pkgfile.
- [x] If any member of the coupled source set is unreachable or cannot be mapped safely, reject the entire update and leave the Pkgfile unchanged.
- [x] Do not fall back to arbitrary "first archive wins" behavior.
- [x] Keep the existing ambiguous-source refusal for genuinely unrelated multiple-primary-source layouts where a common version-coupled family cannot be proven.

### Unicode-specific expected behavior

For:

```text
version 17.0.0 -> 18.0.0
```

the updater should evaluate and validate both:

```text
https://www.unicode.org/Public/18.0.0/ucd/UCD.zip
https://www.unicode.org/Public/18.0.0/ucd/Unihan.zip
```

and retain the matching effective rename identities:

```text
UCD-18.0.0.zip
Unihan-18.0.0.zip
```

Because the BFSOS Pkgfile already uses `$version` dynamically in both `source=()` and `renames=()`, the maintained updater should normally only need to change `version=` after proving the full coupled source set is valid; it must not attempt to replace one URL and reject the other as an ambiguity.

### Regression coverage

- [x] Add a synthetic multi-source Pkgfile with two remote archives sharing `$version` and matching version-bound `renames=()` entries.
- [x] Prove a valid version bump succeeds when every member of the source set resolves and is reachable.
- [x] Prove failure of one member rejects the entire transaction and leaves the original Pkgfile untouched.
- [x] Prove unrelated secondary/local sources are preserved unchanged.
- [x] Prove genuinely ambiguous multiple independent primary archives still return `NEEDS REVIEW` instead of guessing.
- [x] Add a live-equivalent Unicode Character Database `17.0.0 -> 18.0.0` regression.

### Acceptance criterion

A repeat live update of `opt/unicode-character-database` must no longer produce:

```text
NEEDS REVIEW: ambiguous primary remote source archive; refusing handoff rewrite
```

for the normal `UCD.zip` + `Unihan.zip` layout. The valid 18.0.0 update should pass the maintained-updater handoff once both target archives validate.

---

# r419 implementation notes — r416/r417/r418 updater cleanup

Worked from the uploaded full BFSOS project archive and r418 tracker. This revision implements the current live-scan/picker fixes while deliberately leaving the next live full-tree retest unchecked.

Implemented:

- **ALSA Plugins native/compat-32 discovery:** `ftp://` sources are now recognized as remote sources, both ALSA Plugins ports use the canonical `alsa-project/alsa-plugins` Git tag provider, and native + compat-32 are a coordinated exact-version lock group built native first.
- **Public Suffix List classification:** the date-stamped local data snapshot is now an explicit maintenance-policy SKIP instead of being mislabeled as a generic local/meta port.
- **GitHub API 403 fallback:** GitHub release discovery falls back to public `git ls-remote --tags` when the REST release API is rate-limited/unavailable, while still requiring the exact BFSOS-derived release asset URL to exist before accepting a candidate.
- **GitHub current-asset metadata gaps:** a reachable current BFSOS release URL is accepted as proof of the current release even when GitHub API asset metadata is incomplete/pruned. This covers the live `bc`, `libpaper`, and `kddockwidgets` cases without weakening sibling-release-family checks.
- **Ghostscript condensed tags:** condensed `gs10080`-style tags preserve component widths and map back to `10.08.0` exactly.
- **Openbox:** classified explicitly as a final-formal-release policy pin at 3.6.1 while upstream development contains unreleased 3.7 work, eliminating repeated unverifiable noise without pretending the development tree is a release.
- **RARLAB UnRAR:** version discovery now uses the official RARLAB addons page and parses only the official `unrarsrc-X.Y.Z.tar.gz` link, avoiding the blocked directory/index path.
- **Info-ZIP:** legacy `downloads.sourceforge.net/sourceforge/PROJECT/...` paths now identify the real project name before compact filename decoding, allowing `unzip60` to map to `6.0`.
- **Expat:** GitHub release candidates still require the expected source archive to be reachable; a version-looking release/tag with no matching source asset is suppressed before picker generation.
- **Gutenprint:** SourceForge snapshot/date/hash candidates are rejected for the release-tracking port.
- **LAME:** SourceForge candidate parsing accepts formal dotted release versions and rejects legacy compact artifact tokens such as `398-2`.
- **LMDB:** placeholder guard now includes `BP`; the OpenLDAP provider accepts only concrete `LMDB_<numeric-version>` tags, preventing `2.MP`, `2.BP`, and unrelated repository tags from reaching comparison.
- **Tcl:** the BFSOS 8.6 port is locked to the 8.6 maintenance branch; Tcl 9 is treated as an explicit future migration rather than an ordinary update.
- **Unicode multi-source handoff:** a `$version`-driven source token that exactly evaluates to the primary handoff URL is now recognized even when sibling version-coupled archives are present. The version bump therefore advances `UCD.zip` and `Unihan.zip` together, preserves `renames=()` and local companions, validates every changed archive, and retains the old ambiguity refusal for unrelated multiple-primary layouts.
- The already-selected valid UCD update in the uploaded tree remains at **18.0.0**.
- Added `scripts/tests/test-r419-updater-fixes.py`.

Validation performed in the supplied tree:

```text
python3 -m py_compile scripts/checkupdate.py scripts/bfs-port-updater.py scripts/bfs-maintained-port-updater.py  PASS
python3 scripts/tests/test-r377-port-updater-fixes.py                                           PASS
python3 scripts/tests/test-r394-updater-fixes.py                                               PASS
python3 scripts/tests/test-r396-updater-fixes.py                                               PASS
python3 scripts/tests/test-r397-updater-fixes.py                                               PASS
python3 scripts/tests/test-r400-updater-fixes.py                                               PASS
python3 scripts/tests/test-r404-updater-fixes.py                                               PASS
python3 scripts/tests/test-r405-updater-fixes.py                                               PASS
python3 scripts/tests/test-r406-updater-fixes.py                                               PASS
python3 scripts/tests/test-r413-tracker-fixes.py                                               PASS
python3 scripts/tests/test-r415-updater-fixes.py                                               PASS
python3 scripts/tests/test-r419-updater-fixes.py                                               PASS
python3 scripts/tests/test-maintained-port-updater.py                                          PASS
bash scripts/tests/test-r365-port-updater-policy.sh                                            PASS
./scripts/bfs-ports-static-audit.sh                                                            PASS
./scripts/bfs-release-static-audit.sh                                                          PASS
bash -n ports/opt/unicode-character-database/Pkgfile                                           PASS
git diff --check                                                                               PASS
```

Still requires live BFSOS validation:

- Run the full-tree provider scan again and compare the new `problems-*.tsv` against the r415 11-row residual report.
- Confirm the GitHub 403 quartet no longer becomes UNVERIFIABLE when the API is rate-limited.
- Confirm Expat 2.9.0, Gutenprint snapshot builds, LAME `398-2`, LMDB placeholder tags, and Tcl 9 no longer appear in the picker.
- Confirm ALSA Plugins native/compat-32 are reported through the real upstream provider rather than generic local/meta SKIP.
- Confirm the UCD multi-source handoff no longer returns `ambiguous primary remote source archive`.

Historical live-only/package-manager items elsewhere in this tracker remain open when they require evidence not present in the uploaded archive (for example the Fribidi pkgutils ownership collision and other explicit live-validation checkboxes).

---

# r420 live regression — distro-version bump misses static-audit consumers

A live BFSOS Port Updater distro-version bump changed the distro version to `0.9.1.1` and reported the following files as updated:

```text
VERSION
ports/core/aaa_filesystem/Pkgfile
bootstrap.sh
bootstrap-clean-start.sh
scripts/bfs-build-iso.sh
scripts/install-bfs-menu-current.sh
README.md
docs/INSTALL.md
```

The version-bump transaction did **not** report the static-audit script(s) or other active audit/version consumers as updated. This is the same class of project-wide version-consumer synchronization bug already identified elsewhere in the tracker, now reproduced through the live distro-version UI.

## Required behavior

When the maintainer selects a new BFSOS distro version, the updater must treat the change as one coordinated transaction across **every active authoritative version reference**, not a hard-coded list of a few files.

At minimum the version-bump path must:

- discover every active reference to the current BFSOS distro version before editing;
- update `VERSION` and all runtime/build/install/documentation consumers that intentionally mirror the distro version;
- update `scripts/bfs-release-static-audit.sh` expectations when that audit contains an explicit distro-version baseline;
- update `scripts/bfs-ports-static-audit.sh` only when it contains an active distro-version expectation relevant to the bump;
- update any other current tests/policy files that intentionally pin the distro version;
- avoid rewriting historical trackers, changelogs, archived logs, release notes for old releases, or other historical evidence merely because they contain the old string;
- print the complete planned file list before apply so omissions are visible;
- apply the whole version change atomically: if any active consumer cannot be rewritten or validated, restore every touched file;
- run both static audits after the rewrite and refuse to report success if either audit fails;
- run syntax/tests for touched shell/Python files before committing the transaction;
- show the final complete list of changed files in the success dialog.

## Implementation direction

Do not maintain another fragile hand-written list of versioned files. Prefer an explicit machine-readable active-consumer map plus a verification scan that catches newly introduced active references not represented in the map.

Suggested flow:

```text
selected target version
    -> enumerate authoritative version consumers
    -> verify old value / expected rewrite shape
    -> show complete plan
    -> stage all rewrites
    -> run syntax/tests/static audits
    -> all pass: commit transaction
       any fail: restore every touched file
```

The active-consumer map should distinguish rewrite semantics, for example:

```text
literal distro version
major/minor release family
os-release VERSION / VERSION_ID
archive/ISO naming template
documentation current-version example
audit expected value
```

so the updater does not blindly replace every occurrence of the old string.

## Regression coverage

- [x] Reproduce a `0.9.1 -> 0.9.1.1` distro-version bump in a fixture containing the same active consumers shown by the live UI.
- [x] Include `scripts/bfs-release-static-audit.sh` as an active version consumer and prove its expected value is updated in the same transaction.
- [x] Include a historical document/log containing `0.9.1` and prove it is **not** rewritten.
- [x] Add a deliberately unknown active consumer and prove the pre-apply verification reports it instead of silently omitting it.
- [x] Prove both static audits run after staging and before success is reported.
- [x] Prove an audit failure rolls back `VERSION` and every other touched file.
- [x] Prove the success dialog lists the full synchronized set, including the audit consumer(s).

## Acceptance criteria

A future distro-version bump must not display a success screen like the live `0.9.1.1` example while omitting an active audit consumer. After a successful bump:

```bash
./scripts/bfs-ports-static-audit.sh
./scripts/bfs-release-static-audit.sh
```

must both pass immediately without a follow-up manual audit-baseline edit.

### Status

- [x] Live regression captured from the distro-version UI at `0.9.1 -> 0.9.1.1`.
- [x] Identify the distro-version updater implementation and replace its incomplete hard-coded consumer list.
- [x] Add active-consumer discovery/map and atomic rewrite validation.
- [x] Synchronize static-audit version expectations during the same transaction.
- [x] Add rollback and regression coverage.
- [ ] Live retest with the next distro-version bump.


---

# r421 milestone requirement — fill missing Pkgfile descriptions before BFSOS 1.0

A project-wide metadata audit found **443 real port Pkgfiles** with no `# Description:` line anywhere in the file, excluding the known blank/template `ports/Pkgfile` at the root of the ports tree.

This is not considered a release-blocking issue for current 0.9.x development, but BFSOS 1.0 should ship with descriptions present for every real port.

## Goal

Add a dedicated maintainer/updater metadata action that can populate **only missing** port descriptions from trustworthy package metadata sources, without rewriting descriptions that already exist.

## Required behavior

For every real port under `ports/*/*/Pkgfile`:

- if `# Description:` already exists anywhere in the Pkgfile, leave that description unchanged;
- if `# Description:` is missing, attempt to obtain a concise package description from trusted metadata sources;
- never overwrite or "improve" an existing maintainer-written description during this operation;
- exclude the known root/template `ports/Pkgfile` from the cleanup;
- preserve all existing Pkgfile content, ordering, URL, Maintainer, Depends, hooks, source arrays, and build logic except for inserting the missing description line;
- insert the description as the first metadata line so normal BFSOS Pkgfile headers begin with `# Description:`;
- report ports that cannot be described confidently instead of inventing text.

## Description source priority

Use only metadata that can be positively tied to the same upstream project/package. Prefer sources in this order when available:

```text
1. Explicit BFSOS mapping to MLFS/LFS/BLFS/GLFS package metadata
2. CRUX port metadata for the verified same project
3. Arch package metadata for the verified same upstream project
4. Upstream project/repository/site description
```

The exact order may be adjusted where an existing BFSOS provenance mapping makes one source clearly authoritative, but a same-name package alone is never sufficient proof of identity.

## Identity and safety rules

Before importing a description from CRUX, Arch, or upstream metadata, verify package identity using the same conservative provenance logic already used by the updater where possible:

- canonical upstream URL/domain;
- repository owner/project;
- source archive host/path;
- known BFSOS alias/provenance mapping;
- package-family mapping;
- source filename/project stem.

If identity is ambiguous, leave the Pkgfile unchanged and report `NEEDS REVIEW`.

Do not generate descriptions by merely transforming the port name (for example `foo-bar` -> `Foo Bar package`). A fallback description must come from real package/project metadata.

## Description normalization

Imported descriptions should be normalized conservatively for BFSOS metadata:

- one line only;
- no trailing period requirement unless the source naturally contains one;
- strip HTML/Markdown formatting and embedded links;
- collapse excessive whitespace/newlines;
- avoid vendor marketing boilerplate when a concise factual package description is available;
- preserve meaningful project/product capitalization;
- do not copy excessively long upstream blurbs verbatim;
- reject empty, placeholder, or obviously generic values.

Suggested maximum length should remain practical for a Pkgfile header (for example roughly 120-160 characters), with conservative shortening that does not change meaning.

## UI / updater integration

This should be a **separate maintainer action**, not something silently run during every normal version scan.

Suggested menu item:

```text
Fill missing port descriptions
```

The action should:

```text
scan tree
  -> identify only ports missing # Description:
  -> resolve trusted description candidates
  -> show proposed additions
  -> allow review/selection
  -> stage edits
  -> run syntax/static audits
  -> commit only validated edits
```

Normal version-update scans should not be slowed down by this metadata crawl.

## Static audit policy for 1.0

Once the cleanup is substantially complete and before the BFSOS 1.0 release, extend the static audit so every real port Pkgfile is required to contain a valid `# Description:` line.

The audit must explicitly ignore the known root/template `ports/Pkgfile` unless that file is later converted into a real port.

Recommended audit failure format:

```text
MISSING DESCRIPTION: ports/<tree>/<port>/Pkgfile
```

Do not enable the static-audit hard failure prematurely while hundreds of existing ports are still intentionally queued for cleanup; introduce/enforce it as part of the 1.0 completion work.

## Regression coverage

- [x] Existing description is preserved byte-for-byte.
- [ ] Missing description is filled from an explicit LFS-family mapping when package identity is known.
- [ ] Missing description is filled from verified CRUX metadata.
- [ ] Missing description is filled from verified Arch metadata when CRUX is unavailable/inadequate.
- [ ] Missing description falls back to a verified upstream project description.
- [ ] Same-name/different-project downstream metadata is rejected.
- [ ] Ambiguous identity produces `NEEDS REVIEW` and no edit.
- [x] Root/template `ports/Pkgfile` is excluded.
- [ ] Multi-line/HTML/Markdown source text is normalized to one concise Pkgfile description.
- [x] The action does not alter URL/Maintainer/Depends/build logic/source arrays.
- [ ] Static audit can enforce descriptions once the 1.0 cleanup gate is enabled.

## Acceptance criteria for BFSOS 1.0

Before BFSOS 1.0 is declared complete:

- every real port Pkgfile contains a meaningful `# Description:` line;
- existing descriptions were not mass-rewritten by the cleanup action;
- unresolved ports are reviewed manually rather than receiving fabricated descriptions;
- the static audit enforces the requirement going forward;
- the known root/template `ports/Pkgfile` remains explicitly exempt unless its role changes.

### Status

- [x] Project-wide audit performed; 443 real Pkgfiles currently lack `# Description:`.
- [x] Root/template `ports/Pkgfile` identified as a known intentional blank/template and excluded from the count/requirement.
- [x] Add dedicated updater/maintainer action to fill only missing descriptions.
- [x] Add trusted description providers and reuse conservative package-identity verification.
- [x] Add review UI / machine-readable result logging for unresolved descriptions.
- [ ] Run cleanup across all trees before BFSOS 1.0.
- [ ] Enable static-audit enforcement after the cleanup reaches completion.

---

# r422 live follow-up — Expat future-release leak and Info-ZIP SourceForge family parsing

## BUG: Expat 2.9.0 unreleased/future release still reaches picker

### Live regression

The full-tree updater still offered:

```text
compat-32/expat-32 2.8.5 -> 2.9.0 r1->1 [github-release; REVIEW]
```

This is a regression of the previously tracked Expat false-candidate case. The provider/picker path is still capable of accepting a version that is not yet a published release artifact for the BFSOS release-tracking port.

### Required behavior

- [x] For `expat` and `expat-32`, require the exact target release/tag **and** expected release archive to exist before candidate creation.
- [x] Do not infer a future release from milestones, branches, draft metadata, release-planning text, or non-published tag-like data.
- [x] Validate the release family against the actual BFSOS source form before the candidate reaches the picker.
- [x] Native and compat-32 Expat must remain synchronized to the same validated published release.
- [x] If the candidate is not a published release, classify it as CURRENT/no candidate rather than REVIEW.
- [x] Add a live-regression fixture proving `2.8.5 -> 2.9.0` is suppressed until the real 2.9.0 release artifact is actually published.
- [x] Add a positive-control fixture proving a genuinely published later Expat release is still discovered.

### Acceptance test

With BFSOS Expat at `2.8.5`, a live scan must not show:

```text
compat-32/expat-32 2.8.5 -> 2.9.0
core/expat          2.8.5 -> 2.9.0
```

unless the exact upstream release archive for 2.9.0 is verifiably published.

---

## BUG: Info-ZIP/SourceForge parser emits `unzip 6.0 -> 552`

### Live regression

The full-tree updater offered:

```text
opt/unzip 6.0 -> 552 r9->1 [sourceforge; REVIEW]
```

`552` is not a valid newer UnZip release for the BFSOS `unzip` port. The SourceForge parser is crossing release-family/directory boundaries and converting an old `5.52` family token into the malformed version `552`.

### Required behavior

- [x] Add an Info-ZIP-specific SourceForge family parser for `unzip`.
- [x] Restrict discovery to the **UnZip 6.x** release family used by the BFSOS port.
- [x] Preserve dotted release versions exactly; never normalize `5.52` into `552`.
- [x] Reject versions from older sibling families such as UnZip 5.x when the BFSOS port tracks 6.x.
- [x] Prefer the actual release archive naming (`unzip60`, etc.) only as a filename/tag mapping; do not reinterpret that compact filename form as an upstream numeric version.
- [x] Do not emit a REVIEW candidate when the parsed target is older, malformed, or from the wrong release family.
- [x] Add regression coverage for `6.0 -> 552` suppression.
- [x] Add regression coverage that `5.52` remains recognized as an older 5.x release, not `552`.
- [x] Add a positive-control fixture for a hypothetical/real later **6.x** formal release so valid future Info-ZIP updates remain discoverable.

### Acceptance test

With BFSOS `opt/unzip` at `6.0`, a live scan must not show:

```text
opt/unzip 6.0 -> 552
```

and should classify the port as CURRENT unless a real newer UnZip 6.x release exists.


---

# r423 implementation notes — r420/r421/r422 work + requested test-version reset

Worked from the uploaded full BFSOS tree and r422 tracker.

Implemented in this pass:

- **Distro-version transaction (r420):** split version handling into a dry-run plan and atomic apply path. The UI now displays the complete planned file set before confirmation. `scripts/bfs-release-static-audit.sh` now carries an explicit `EXPECTED_BFSOS_DISTRO_VERSION` baseline and is rewritten in the same transaction as `VERSION`, bootstrap/installer/ISO fallbacks, `aaa_filesystem`, and current release documentation.
- **Rollback/validation:** every staged distro-version update runs shell syntax checks plus both BFSOS static audits. Any validation failure restores every touched file byte-for-byte. A contextual verification scan rejects newly-added active fallback consumers such as an unmapped `BFS_VERSION="<current>"` reference instead of silently omitting it; historical docs/logs are not mass-rewritten.
- **Missing descriptions (r421):** added `scripts/bfs-fill-port-descriptions.py` and a new maintainer menu action, **Fill missing port descriptions**. Existing `# Description:` lines are never rewritten. The helper scans only real `ports/*/*/Pkgfile` entries, excludes the root/template `ports/Pkgfile`, resolves candidates from LFS-family pages, CRUX metadata, verified Arch metadata, and upstream project/site metadata, normalizes to one concise line, presents a dialog checklist, and writes a TSV result log including `NEEDS-REVIEW` rows. The 443-port cleanup itself remains a pre-1.0 live maintenance task, and hard static-audit enforcement remains intentionally disabled until that cleanup is complete.
- **Expat publication guard (r422):** GitHub release discovery now rejects future-dated release metadata. If the GitHub REST API is rate-limited, the fallback uses the public `/releases/latest` redirect as the publication signal instead of trusting arbitrary git tags plus reachable staged assets. Native `core/expat` and `compat-32/expat-32` are now an exact-version lock pair.
- **Info-ZIP UnZip parser (r422):** compact SourceForge filename decoding now fails closed when the digit shape does not match the current dotted release. `opt/unzip` is restricted to the current 6.x release family, so `unzip552`/5.x artifacts can no longer become the malformed candidate `552`; valid future 6.x compact filenames still decode normally.
- Added `scripts/tests/test-r423-updater-fixes.py` and updated the r419 GitHub fallback regression for the safer published-release fallback.

## Requested test baseline

The returned working tree is intentionally reset to **BFSOS 0.9.0** so the live updater can be used to bump it to **0.9.1.1** and exercise the repaired distro-version transaction.

The reset includes the active consumers only:

```text
VERSION                                  0.9.0
ports/core/aaa_filesystem/Pkgfile        bfs_version=0.9.0, release=21
bootstrap.sh                             fallback 0.9.0
bootstrap-clean-start.sh                 fallback 0.9.0
scripts/bfs-build-iso.sh                 fallback 0.9.0
scripts/install-bfs-menu-current.sh      fallback 0.9.0
README.md                                current release 0.9.0
docs/INSTALL.md                          current install release 0.9.0
scripts/bfs-release-static-audit.sh      expected distro version 0.9.0
```

A full copied-tree dry/live-equivalent test of `--set-distro-version 0.9.1.1` succeeded and reported all nine synchronized consumers, including `scripts/bfs-release-static-audit.sh`; both static audits passed after the staged bump.

## Validation

```text
python3 -m py_compile scripts/checkupdate.py scripts/bfs-port-updater.py scripts/bfs-maintained-port-updater.py scripts/bfs-fill-port-descriptions.py  PASS
python3 scripts/tests/test-r419-updater-fixes.py      PASS
python3 scripts/tests/test-r423-updater-fixes.py      PASS
python3 scripts/tests/test-r406-updater-fixes.py      PASS
python3 scripts/tests/test-maintained-port-updater.py PASS
bash scripts/tests/test-r365-port-updater-policy.sh   PASS
./scripts/bfs-ports-static-audit.sh                   PASS
./scripts/bfs-release-static-audit.sh                 PASS
git diff --check                                      PASS
copied-tree 0.9.0 -> 0.9.1.1 version transaction     PASS
```

Still requiring live BFSOS validation:

- Run the updater distro-version UI from this returned 0.9.0 baseline to 0.9.1.1 and confirm the plan/success dialogs include `scripts/bfs-release-static-audit.sh` and both audits pass.
- Run the full-tree provider scan and confirm Expat 2.9.0 no longer appears before publication and `opt/unzip 6.0 -> 552` is gone.
- Run **Fill missing port descriptions** when desired; review/select resolved descriptions and keep unresolved rows for manual review. Do not enable the 1.0 missing-description hard audit until the cleanup is complete.

---

## r424 UX follow-up — explicit PASSED/FAILED status for distro-version transactions

### Live usability finding

The distro-version transaction now performs multiple coordinated edits and validation steps, but the success dialog does not make each completed step visibly explicit. During live testing of a `0.9.0 -> 0.9.1.1` bump, it would be clearer if every synchronized consumer and validation stage showed an unmistakable `PASSED` status rather than requiring the maintainer to infer success from the absence of an error.

### Required behavior

On a successful distro-version transaction, the result dialog should list each changed consumer and each validation stage with a clear status prefix, for example:

```text
BFSOS distro version updated to 0.9.1.1

PASSED  VERSION
PASSED  ports/core/aaa_filesystem/Pkgfile
PASSED  bootstrap.sh
PASSED  bootstrap-clean-start.sh
PASSED  scripts/bfs-build-iso.sh
PASSED  scripts/install-bfs-menu-current.sh
PASSED  README.md
PASSED  docs/INSTALL.md
PASSED  scripts/bfs-release-static-audit.sh

PASSED  bfs-ports-static-audit.sh
PASSED  bfs-release-static-audit.sh
PASSED  shell syntax validation
PASSED  distro-version consumer validation
```

If any transaction step or validation fails, the dialog should identify the failing stage with `FAILED`, explain the reason, and clearly state that the entire version transaction was rolled back. Do not leave a mixed or partially updated version state.

Example failure presentation:

```text
PASSED  VERSION
PASSED  README.md
FAILED  bfs-release-static-audit.sh

Version transaction rolled back; project remains at the previous distro version.
```

### UX / implementation requirements

- Keep the existing atomic transaction and rollback behavior.
- Track status for every planned file edit and every validation stage.
- Present changed consumers in the same deterministic order used by the version plan.
- Show `PASSED` only after the corresponding edit/validation actually completed successfully.
- On failure, show `FAILED` for the exact failing operation and do not mark later, unrun stages as passed.
- Prefer a concise status table/list that remains readable in the dialog UI.
- Preserve the current preflight plan failure behavior for unmapped active distro-version consumers.
- Add regression coverage for both all-pass and rollback/failure result formatting.

### Status

- [ ] Add per-consumer `PASSED` status reporting to the distro-version success dialog.
- [ ] Add per-validation `PASSED` status reporting for static audits, syntax checks, and active-consumer validation.
- [ ] Add exact `FAILED` stage reporting on transaction failure.
- [ ] Explicitly report atomic rollback when any stage fails.
- [ ] Add regression coverage for successful status output and failed/rolled-back output.

---

# r425 live follow-up — Expat trusted-reference policy

## Expat: disable generic GitHub release discovery

### Live regression

After r423/r424 live testing, `compat-32/expat-32` still incorrectly appears as:

```text
compat-32/expat-32  2.8.5 -> 2.9.0  [github-release; REVIEW]
```

The previous GitHub release-asset validation was not sufficient to suppress the future/unpublished candidate in the live updater path.

### New policy

Treat Expat as a trusted-reference/mapped package and do **not** use generic GitHub release discovery for it.

For both:

```text
core/expat
compat-32/expat-32
```

the updater must follow this policy:

1. Prefer the applicable LFS-family reference/mapping when present.
2. Check CRUX as the primary downstream fallback reference.
3. Check verified Arch Linux metadata only when upstream identity and comparable version lineage are proven.
4. Do not call or accept the generic `github-release` provider for Expat.
5. Keep native and compat-32 Expat version-locked together.
6. If trusted references remain at `2.8.5`, both ports remain at `2.8.5`.
7. Only move to `2.9.0` (or later) when the trusted-reference chain reports that release as current/available.
8. If references disagree or cannot be verified, hold both ports for REVIEW/OFF rather than using GitHub to break the tie.

### Required diagnostics

When GitHub discovery is bypassed for Expat, emit a trace similar to:

```text
core/expat
  generic github-release discovery skipped: trusted-reference policy
  trusted reference result: 2.8.5

compat-32/expat-32
  locked to core/expat target: 2.8.5
```

### Regression coverage

- [ ] `core/expat 2.8.5` does not emit `2.9.0` from generic GitHub discovery.
- [ ] `compat-32/expat-32 2.8.5` does not emit `2.9.0` from generic GitHub discovery.
- [ ] Native and compat-32 remain version-locked.
- [ ] A newer Expat version from a trusted reference can still be offered when genuinely published.
- [ ] Conflicting/ambiguous trusted references produce REVIEW/OFF, not a GitHub override.
- [ ] Live targeted scan of `core` + `compat-32` shows no Expat GitHub candidate while trusted references remain at `2.8.5`.

### Status

- [ ] Disable generic `github-release` discovery for Expat.
- [ ] Route Expat through trusted-reference policy.
- [ ] Preserve native/compat-32 lock.
- [ ] Add synthetic regression coverage.
- [ ] Re-run targeted live scan and confirm the false `2.8.5 -> 2.9.0` candidate is gone.

---

# r426 — Website/documentation editor ports

## Bluefish port and dependency closure

### Goal

Add a maintained BFSOS port for **Bluefish** so the website and documentation can be edited with a Linux-native web-focused editor without requiring a full development IDE.

### Required work

- [ ] Add a `bluefish` port in the appropriate BFSOS tree.
- [ ] Determine the current stable upstream release and canonical source archive.
- [ ] Resolve and add every required build/runtime dependency that is not already present in BFSOS.
- [ ] Prefer existing BFSOS ports where dependency equivalents already exist rather than duplicating libraries.
- [ ] Add any genuinely missing dependency ports needed for a clean build.
- [ ] Verify desktop integration:
  - launcher/menu entry;
  - icon;
  - MIME associations where upstream provides them;
  - HTML/CSS/JS file opening behavior.
- [ ] Verify the application can open and edit the BFSOS website/documentation tree.
- [ ] Build with normal BFSOS package policy and produce/update checksum metadata.
- [ ] Add a brief description and upstream URL to the Pkgfile.
- [ ] Test installation through the normal `prt-get` path, not only `pkgmk`.
- [ ] Record any optional dependencies separately from hard requirements.

### Acceptance

A fresh BFSOS system can install Bluefish with:

```text
prt-get depinst bluefish
```

and launch it successfully with all required dependencies resolved.

---

## Pinegrow port feasibility and packaging investigation

### Goal

Investigate adding a **Pinegrow** port because its visual website-editing workflow is closer to a non-coding/WYSIWYG-style site-maintenance experience.

### Licensing/distribution gate

Do not create or redistribute a Pinegrow package until its current licensing and redistribution terms have been reviewed.

Required investigation:

- [ ] Confirm whether Pinegrow provides a Linux build suitable for BFSOS.
- [ ] Review current Pinegrow license/EULA and redistribution terms.
- [ ] Determine whether BFSOS is permitted to redistribute the application binary/archive.
- [ ] Determine whether redistribution is allowed only as a downloader/installer wrapper rather than a hosted binary package.
- [ ] Record any restrictions involving commercial licensing, activation, account login, trademarks, or bundled proprietary components.

### If redistribution is permitted

- [ ] Create a maintained Pinegrow port.
- [ ] Use the vendor's canonical Linux distribution/archive.
- [ ] Resolve runtime dependencies against existing BFSOS ports.
- [ ] Add missing dependency ports only when genuinely required.
- [ ] Preserve vendor licensing files/notices.
- [ ] Add desktop launcher, icon, and MIME integration where appropriate.
- [ ] Verify launch and local-site editing on BFSOS.
- [ ] Verify updates can be maintained without violating the vendor's distribution terms.
- [ ] Add checksum/signature metadata according to BFSOS package policy.

### If redistribution is not permitted

- [ ] Do **not** mirror or package proprietary application payloads in BFSOS repositories.
- [ ] Consider a thin optional installer/downloader port only if the license explicitly permits that model.
- [ ] Otherwise document Pinegrow as a recommended external application rather than a BFSOS package.

### Dependency policy

For both Bluefish and Pinegrow:

- reuse existing BFSOS libraries first;
- avoid adding duplicate dependency stacks under alternate names;
- distinguish hard runtime/build dependencies from optional feature dependencies;
- verify every new dependency port can be built and installed independently;
- ensure the updater can track any newly added ports after they enter the tree.

---

# r427 — Missing-description fallback improvements

## Reuse trusted fallback identity logic for descriptions

### Goal

Improve the existing **Fill missing port descriptions** maintainer action by reusing the same conservative trusted-source and upstream-identity logic already used by the package updater.

The first live pass filled 171 of 443 missing descriptions, leaving 272 unresolved. The next pass should improve coverage without weakening identity checks or inventing descriptions.

### Required behavior

For real upstream-backed ports that do not already contain a `# Description:` line:

1. Reuse the updater's trusted identity/fallback chain where applicable:
   - explicit LFS / BLFS / MLFS / GLFS mapping;
   - CRUX;
   - verified Arch Linux metadata;
   - verified upstream project/repository metadata.
2. Reuse the same package-identity checks used for version fallback:
   - package name alone is not sufficient;
   - repository/project identity must match where possible;
   - source host/project stem and existing explicit mappings may be used;
   - ambiguous same-name packages must not donate descriptions.
3. Use the first clean, trustworthy description from a positively identified source.
4. Existing descriptions must never be overwritten by this action.
5. Keep descriptions concise and on a single line.
6. Strip obvious metadata noise, markup, package-manager boilerplate, duplicated package names, and other unsuitable text before insertion.
7. If the trusted sources disagree materially or identity is uncertain, leave the port unresolved rather than guessing.
8. Preserve all existing `# URL:`, `# Maintainer:`, `# Depends on:`, source, build, and package content unchanged.
9. Continue excluding the known root/template `ports/Pkgfile`.

### Meta/local package policy

Do **not** try to fetch descriptions for BFSOS meta/grouping ports from external package sources.

For this pass, meta/local grouping packages should be **ignored** and left unchanged.

At minimum, skip ports that are clearly local/meta packages, including:

```text
*-meta
```

and any ports already classified by BFSOS updater policy as:

```text
local/meta
```

Examples include desktop/application grouping ports such as Plasma, GNOME, XFCE, X.Org, Compiz, and other BFSOS-only aggregation packages.

The description filler should report these separately as skipped, not unresolved.

Expected status categories:

```text
FILLED
ALREADY HAS DESCRIPTION
SKIPPED META/LOCAL
UNRESOLVED
```

### Diagnostics / summary

At completion, display a summary similar to:

```text
Description metadata pass complete

FILLED                  171
ALREADY HAD DESCRIPTION 923
SKIPPED META/LOCAL       30
UNRESOLVED              242
```

Counts above are illustrative; use the actual tree results.

Where useful, record which source supplied each inserted description:

```text
opt/example    FILLED    source=CRUX
core/example2  FILLED    source=BLFS
opt/example3   FILLED    source=Arch verified
opt/example4   FILLED    source=upstream
plasma/example-meta SKIPPED META/LOCAL
```

### Regression coverage

- [ ] Existing `# Description:` lines are never modified.
- [ ] Trusted LFS-family metadata can fill a missing description when the mapping is explicit.
- [ ] CRUX can fill a missing description when package identity is established.
- [ ] Arch can fill a missing description only after the same upstream-identity verification used by version fallback.
- [ ] Same-name/different-project Arch or CRUX packages cannot donate descriptions.
- [ ] Verified upstream project metadata can be used when distro/book metadata is unavailable.
- [ ] Multiline/HTML/boilerplate descriptions are normalized to one concise line.
- [ ] Ambiguous/conflicting metadata remains unresolved.
- [ ] `*-meta` ports are skipped and counted as `SKIPPED META/LOCAL`.
- [ ] Ports already classified as `local/meta` are skipped.
- [ ] The known blank `ports/Pkgfile` template remains ignored.
- [ ] A second run is idempotent: ports filled by the first run are skipped as already described.

### Status

- [ ] Reuse updater trusted-source fallback helpers for description lookup where practical.
- [ ] Reuse upstream/package identity verification instead of name-only matching.
- [ ] Add description sanitization/one-line normalization.
- [ ] Ignore meta/local ports during description population.
- [ ] Add explicit `SKIPPED META/LOCAL` reporting.
- [ ] Add regression coverage.
- [ ] Re-run the metadata pass and compare the remaining unresolved count against the current 272.

---

# r430 — LibreOffice source/binary ports and Brother HL-L8250CDN printing

## LibreOffice: new dedicated office port tree

- [ ] Introduce `ports/office/` as a first-class port tree. Register it everywhere BFSOS enumerates trees: `/usr/ports` synchronization/configuration, `prt-get` paths, updater discovery, menus, static audits, dependency resolution, ISO/build manifests, documentation and tests. Avoid duplicate package names across trees.
- [ ] Add `ports/office/libreoffice/Pkgfile` as the **source-build** variant, with an accurate dependency list, verified release source and checksum, any required patches, reproducible build options, and package integration (desktop files, MIME, icons, fonts, Java options, etc.).
- [ ] Add `ports/office/libreoffice-bin/Pkgfile` as the **upstream prebuilt** variant. Repackage official upstream x86_64 Linux RPM/DEB release payloads into native BFSOS packages; do not rely on rpm/dpkg installing files directly into the target filesystem. Preserve licensing/notices and check bundled-library compatibility.
- [ ] Evaluate supplemental language packs, dictionaries, offline help, and SDK as separate optional ports only where useful; avoid making language-specific packages mandatory.
- [ ] Enforce source/binary mutual exclusion using package metadata/conflict checks and document how to switch between them. Both must provide equivalent desktop integration and entry points without clobbering each other's files.
- [ ] Version the two variants independently when appropriate, with stable upstream release URLs, checksum verification, source-to-package auditing, and conservative updater rules (no prerelease candidate unless explicitly selected).
- [ ] Test Writer, Calc, Impress, document open/save (ODF and Microsoft formats), PDF export, printing through CUPS, GUI launch from Plasma/GNOME/XFCE, and headless conversion.
- [ ] Confirm builds/packaging under normal `pkgmk -kw` workflow; use `prt-get` install to validate install hooks where required.
- [ ] Consider LibreOffice a candidate feature for the 1.0-rc milestone; do not mark complete until both variants are installable and smoke-tested.

## Brother HL-L8250CDN: contrib print driver ports

- [ ] Check existing `ports/contrib/` packages and available CUPS/driverless printing support first. Test network discovery, IPP Everywhere/AirPrint if the printer exposes it, and generic PCL/PostScript options where supported; don't assume a proprietary driver is required.
- [ ] Add Brother HL-L8250CDN packages in `ports/contrib/` with clear naming, likely `brother-hll8250cdn-lpr` and `brother-hll8250cdn-cupswrapper`, if both vendor components are needed. Verify vendor archive naming, redistribution/license terms, runtime requirements, checksums and installation layout before choosing package structure.
- [ ] Brother provides an LPR driver (1.1.2-1), CUPSwrapper driver (1.1.3-1), and CUPS wrapper source for this model. Inspect whether the wrapper can be built from source and whether the LPR payload or any helper is 32-bit; do not assume x86_64-native compatibility.
- [ ] Repackage vendor RPM/DEB payloads or source into native BFSOS packages; do not use their install scripts blindly. Audit absolute paths, filters, architecture, scripts, symlinks, package ownership, and post-install actions.
- [ ] Ensure model-specific PPD/filter integration and that CUPS lists/configures the printer; provide safe upgrade and uninstall behavior.
- [ ] Test USB and/or network connection as supported by available hardware; avoid publishing a working-driver claim until a real print job succeeds.

## CUPS end-to-end verification

- [ ] Audit `cups`, `cups-filters`, relevant raster/filter/driver dependencies, `ghostscript`, `avahi`, `nss-mdns`/DNS discovery where applicable, and user permissions/groups. Audit version/dependency assumptions before changes.
- [ ] Verify `cups.service`/`cups.socket` unit behavior, service presets, startup, logging and `http://localhost:631` administration; avoid automatically enabling services on the live ISO without an explicit policy decision.
- [ ] Verify printer discovery (`lpinfo -v`), queue creation (`lpadmin`), defaults (`lpoptions`), status (`lpstat -t`), test page (`lp`), cancellation (`cancel`), job filtering and error reporting.
- [ ] Print a color test page and a LibreOffice Writer/Calc document to the physical Brother HL-L8250CDN. Check duplex and common paper settings if the driver exposes them.
- [ ] Test driverless and vendor-driver queues separately when both are viable; record quality, speed, warnings and known limitations.
- [ ] Reboot and verify that the installed system retains a functioning printer queue and CUPS service state.
- [ ] Add printer setup/troubleshooting documentation and a release checklist entry for BFSOS 1.0-rc.

### Status
All r430 tasks are **pending**. This revision adds planning/tracker items only; no port code, CUPS configuration, or printer-driver functionality has been implemented or tested yet.

---

# r431 — Brother HL-L8250CDN: upstream-first driver versions, Arch/AUR reference

- [ ] Review Arch Linux/AUR Brother printer driver PKGBUILDs for compatible packaging methods, patches, dependency mappings, filter paths, 32-bit runtime requirements, and CUPS integration. Treat their versions as hints, **never as the authoritative current release**.
- [ ] For the **exact HL-L8250CDN model**, check Brother's official Linux RPM, DEB, and source download pages independently. Record driver *component*, version, release date, source URL, architecture, checksum, and applicable license. Do not conflate an installer tool's version with the version of the actual LPR or CUPSwrapper drivers.
- [ ] Confirm newest official applicable release of **each component**, rather than selecting one maximum version across distinct components. Check multiple official regional pages only where needed to resolve a genuine version discrepancy; do not substitute drivers for a different Brother model without verified compatibility.
- [ ] Current official Brother Linux download listing observed on 2026-10-10: LPR **1.1.2-1** (2014-05-15), CUPSwrapper **1.1.3-1** (2016-05-13), CUPSwrapper source **1.1.3-1** (2016-05-17); Driver Install Tool **2.2.6-0** (2025-09-24) is a separate utility, *not* an updated printer-driver release. Re-verify before packaging.
- [ ] Compare official versions with any relevant AUR packages. Where AUR is stale, use the newer verified Brother driver release, adapting any required working patches after review; never copy stale versions blindly.
- [ ] Preserve the exact component's upstream version in Pkgfiles, with an independent BFSOS `release` revision for packaging-only changes.
- [ ] Check vendor binary bitness (`file`, `readelf`) and retain any necessary multilib requirements. If an alternative fully native driverless CUPS path works, document it without falsely upgrading version numbers.
- [ ] Integrate the Brother-specific upstream-first rule into port-update auditing so CRUX/Arch/AUR fallback cannot override a verified newer manufacturer package.
- [ ] Test native BFSOS package installation, printer discovery, CUPS jobs and physical printing before recording the driver as verified.

Official model downloads: https://support.brother.com/g/b/downloadlist.aspx?c=us&lang=en&os=128&prod=hll8250cdn_all

---

# r432 — KDE Frameworks 6.30.0 → 6.31.0: broken URL rewrites and atomic rollback

## Observed failure (2026-10-10)

The updater reported `NEEDS REVIEW` / HTTP 404 on rewritten KDE Frameworks URLs. Examples include `plasma/attica`, `baloo`, `bluez-qt`, `breeze-icons`, `extra-cmake-modules`, `frameworkintegration`, `kapidox`, `karchive`, and `kauth`; audit every affected Frameworks port, not just those visible in the dialog. The generated URLs retained the **old** directory `stable/frameworks/6.30/` but changed the archive name to `*-6.31.0.tar.xz`. Correct 6.31.0 paths should use `stable/frameworks/6.31/` (verify upstream artifacts before accepting updates).

## Required changes

- [ ] Detect KDE Frameworks source patterns and derive the download directory from the **candidate version's major.minor** (`6.30.0 -> 6.30/`; `6.30.1 -> 6.30/`; `6.31.0 -> 6.31/`), not the installed version's directory.
- [ ] Rewrite directory and archive filename together, then validate existence (and checksum/source metadata as applicable) **before** making persistent Pkgfile edits.
- [ ] Audit **all** KDE Frameworks ports offered in the run, including those not visible in the screenshot; produce a per-port old/new URL and status report. Do not assume every 404 has the same cause.
- [ ] Ensure each `NEEDS REVIEW` / failed validation leaves its Pkgfile, version, release, checksum metadata, patches and other port content unchanged from its **pre-update** state. If a run edits files before validation, restore exact original content automatically on any failure, including interruption or multi-port partial failures.
- [ ] Track success/failure transactionally per port and do not advance installed/published package state because a candidate version was detected. Never claim automatic rollback without verifying implementation.
- [ ] If `NEEDS REVIEW` leaves an invalidly rewritten Pkgfile today, fix the updater and recover the original file from an existing Git commit or backup (preserving any unrelated uncommitted edits); do not blanket-reset the entire repository.
- [ ] Test KDE Frameworks updates from 6.30.0 to 6.30.1, 6.31.0, and a nonexistent release, plus source failures, network failures and interruption. Confirm failed candidates retain original version/source/checksum byte-for-byte.
- [ ] After the fix, rerun discovery and validate URLs for all 6.31.0 Frameworks candidates before building; stage Frameworks updates together as appropriate and test runtime integration.

## How to check the affected ports right now (run on the BFSOS host)

```bash
cd ~/BFSOS
# If committed, this shows any version/source edits made by the updater:
git diff -- ports/plasma/attica/Pkgfile ports/plasma/baloo/Pkgfile ports/plasma/karchive/Pkgfile
# Inspect the actual candidate/installed Pkgfile state:
grep -HnE '^(version|release)=|download.kde.org/stable/frameworks/' \
  ports/plasma/{attica,baloo,karchive}/Pkgfile
# More generally, find references to both versions in the plasma tree:
grep -RlnE '6\.31\.0|stable/frameworks/6\.30/' ports/plasma --include=Pkgfile
```

**Expected safety policy:** if an update is rejected with `NEEDS REVIEW` due to a 404, retain 6.30.0 in the existing Pkgfile rather than switching to a broken 6.31.0 source. A `NEEDS REVIEW` message **alone does not verify this**; inspect Git diffs/current Pkgfiles. Installed packages are not changed just by a Pkgfile URL rewrite, but repository Pkgfiles may have been changed depending on the updater's implementation.

### Status
All r432 items pending investigation and verification; the screenshot confirms URL validation failure, not rollback behavior.

---

# r433 — SQLite and SQLite-32 version resolver live regression

## Status: previously marked implemented in r405; live verification failed / remains unresolved

The 2026-10-10 all-tree updater sweep again reports that SQLite versions are not resolving properly for `core/sqlite` and `compat-32/sqlite3-32`. The r405 tracker claimed a SQLite-specific official-download-page provider and decoding of encoded archive IDs were implemented, but this behavior is not yet confirmed on the running BFSOS source tree. Do not mark this resolved based on a previous unit test alone.

- [ ] Collect current scan-log rows, TRACE lines, and problem-report entries for both ports; distinguish `UNVERIFIABLE`, wrong candidate, wrong source rewrite, fetch errors, and a port-name mapping mismatch.
- [ ] Inspect the actual Pkgfiles for `core/sqlite` and `compat-32/sqlite3-32`, including `version=`, `source=`, and source archive ID generation. Confirm the native port and compat-32 port resolve to the same compatible upstream SQLite release unless intentionally pinned.
- [ ] Verify the r405 SQLite provider is actually invoked in **all entry points**: URL audit, updater discovery, candidate picker, selected update, and compat-32 coordinated update. Ensure both port identities map to it (`sqlite` vs `sqlite3-32`).
- [ ] Handle official SQLite archive IDs correctly, e.g. `3.53.4` <-> `3530400` and `sqlite-autoconf-3530400.tar.gz`, without confusing current release, prerelease, year-specific upstream download directory, source version, or package release.
- [ ] Check official upstream release verification against published download artifacts, not merely a guessed filename or a version appearing in unrelated news/pages.
- [ ] When updating, rewrite the archive URL and its encoded filename consistently, validate the resulting URL, and only then commit changes; failed validation must preserve the original versions, checksums, patches and Pkgfiles.
- [ ] Add regression tests for native and compat-32 packages in all scan/update code paths, including multiple SQLite encoded-version examples, URL verification failures, and correct synchronized update behavior.
- [ ] Run both a targeted SQLite scan and a fresh full-tree sweep on BFSOS. Mark fixed only when both packages report `CURRENT` or a real verified `UPDATE` instead of false `UNVERIFIABLE`/bad versions.

**Classification:** r405 fix regression / incomplete live integration. **Status:** OPEN; awaiting current logs and project archive.

---

# r434 — Remaining 2026-10-10 scan findings: Little CMS release tags, SQLite provider, and complete log audit

## Confirmed findings from latest shared problem report

The user's latest problem report is `logs/update/problems-20261010-010739.tsv`, with exactly two `UNVERIFIABLE` rows in the excerpt provided:

| Port | Current | Provider | Error seen |
| --- | --- | --- | --- |
| `compat-32/lcms2-32` | `2.19.1` | `github-release` | The current release source returned HTTP 404; provider results do not contain the current version |
| `compat-32/sqlite3-32` | `3.53.4` | `sqlite-download` | Provider results do not contain current version even though the current source is reachable |

**Scope limitation:** Only the displayed excerpt and the previously shared GNOME scan rows are available here. A full scan of all TSV logs and updater state is still pending receipt of the project archive. Do not treat absence of further visible rows as proof that no other problems exist.

## A. Little CMS (`lcms2` and `lcms2-32`) — coordinated native/compat source URL repair

The failing 32-bit port currently references:

`https://github.com/mm2/Little-CMS/releases/download/lcms2.2.19.1/lcms2-2.19.1.tar.gz`

The release tag appears to have an extra `2.` (`lcms2.2.19.1`); check the canonical published upstream tag and actual downloadable release asset before substituting another URL.

- [ ] Review `core/lcms2` (or actual native port location) **and** `compat-32/lcms2-32`, including source URL templates, checksums, patch files, release/version fields, and tracking policy.
- [ ] Identify the actual official published GitHub release/tag and file asset for the exact version. Probe candidate URLs and follow redirects; avoid inferring availability from the tag alone.
- [ ] Ensure Github release-tag rewriting distinguishes tag format (such as `lcms2.19.1`) from source filename format (`lcms2-2.19.1.tar.gz`), rather than blindly concatenating literal prefixes and dotted versions.
- [ ] Fix release discovery, selected update rewriting, URL audit, and the 32-bit sibling policy. Preserve native/compat consistent upstream versions where appropriate, but do not overwrite architecture-specific flags or patches.
- [ ] Validate both ports' source URLs before committing and retain original Pkgfiles/metadata when checks fail.
- [ ] Add tests for both ports, `2.19.1` tag/asset reconstruction, newer releases, missing release assets, malformed tags, and cross-architecture propagation.
- [ ] Re-check actual native-port path rather than assuming `core/lcms2` if it lives elsewhere.

## B. SQLite and SQLite-32 — latest reproducible regression details

- [ ] Reproduce the latest `compat-32/sqlite3-32` failure: `3.53.4`, `sqlite-download`, **current URL reachable**, provider claims **current version absent**.
- [ ] Diagnose download-page scraping and version mapping separately from source reachability; ensure the provider recognizes encoded `3530400` as `3.53.4`, including where the upstream page is reorganized or served in a different format.
- [ ] Inspect `core/sqlite` scan outcome from the same time window, not just the compat-32 row. It may be current, skipped, or absent from the latest problem report; do not assume its status from older reports.
- [ ] Guarantee both packages are handled by the official SQLite provider in all entry points and remain synchronized where required.
- [ ] Add fixture-based regression tests from representative SQLite download-page content and a mocked current-URL-reachable/provider-missing-current case. Verify correct `CURRENT` or genuine `UPDATE` results, not invented version candidates.
- [ ] Preserve all original Pkgfile and metadata content on inconclusive provider results.

## C. Full remaining-log audit (perform once BFSOS archive is supplied)

- [ ] Inspect **every** `logs/update/scan-*.tsv`, `problems-*.tsv`, updater retry-state file, build log and available trace from the current audit window; account for multiple scans, overwritten state, and older failures already fixed manually.
- [ ] Produce a deduplicated per-port findings table with latest timestamp, tree/name, version/candidate, provenance/provider, result (`BUILT`, `BLOCKED`, `NEEDS REVIEW`, `UNVERIFIABLE`, `FAILED`, `CURRENT`), reason, and resolution state.
- [ ] Differentiate source/provider failures, malformed URL transformations, genuine unavailable releases, patch application failures, checksum/footprint errors, dependency staging issues, Pkgfile evaluation failures, policy holds, and transient network failures.
- [ ] Cross-check known live regressions: KDE Frameworks 6.30→6.31 source path; `python3-gobject` staged Pkgfile evaluation exit 31 (manual `3.58.1` build succeeded); `expat-32` false 2.9.0; native/compat NSS patch drift; Evolution blocked on built-but-not-installed EDS (later installed manually); SQLite; Little CMS.
- [ ] Audit `BUILT` vs actually installed package state and unexpected staged changes, without treating intentional build-only operations as failures.
- [ ] Compare results to current Pkgfiles, installed versions, git diffs, upstream authoritative releases, and existing tracker entries; do not reopen already resolved issues without fresh evidence.
- [ ] Give each remaining verified failure an explicit fix plan and regression test; keep unknown or unreachable upstream versions as explained `NEEDS REVIEW` rather than misclassifying as `CURRENT`.
- [ ] Re-run targeted tests and a full all-tree scan after fixes, documenting unresolved exceptions.

### Status

New tasks **OPEN**. Latest shared report provides direct evidence of two unresolved `UNVERIFIABLE` entries, but no complete log directory or full project archive is available in this conversation for exhaustive auditing.

---

# r435 — Implemented first pass and archive-based audit (2026-10-10)

## Implemented and offline-tested

- [x] Correct `opt/lcms2` and `compat-32/lcms2-32` Pkgfile release tag to `lcms${version}` (for `2.19.1` this evaluates to `lcms2.19.1`, not `lcms2.2.19.1`). Verified GitHub release tag; package download/build remain for live verification.
- [x] Fix SQLite `sqlite-download` provider: the official download page advertises the latest SQLite release, not necessarily every historical release. When the current version is not listed but its actual source archive is reachable, treat it as a proven current release and compare against the page's valid candidates. If unreachable, remain `UNVERIFIABLE` rather than inventing the current release.
- [x] Fix KDE Frameworks candidate source construction to migrate `stable/frameworks/6.30/` to `6.31/` on a 6.30.0→6.31.0 update; preserve major.minor on patch updates.
- [x] Change defaults for main updater, raw version checker, and description updater from fixed 10/8 workers to available logical processors; keep explicit `--jobs` and `BFS_AUDIT_JOBS` override.
- [x] Add `scripts/tests/test-r435-source-and-workers.py` for SQLite provider, Little CMS URLs, KDE 6.30.1/6.31.0/6.32.0 cases. Update stale r415 test expectation for corrected Little CMS source format.
- [x] Python syntax compilation, r405, r406, r413, r415, r419, and new r435 focused tests passed.

## Audited logs / remaining work

- [x] Inspect five `scan-20261010-*.tsv` runs, five `upstream-*.tsv` main audits, five problem reports, and available build logs.
- [x] Confirm the Plasma pass contains 73 rejected KDE Frameworks rewrites (all using stale `6.30` directory). The old port versions were retained in the supplied project snapshot.
- [x] Confirm `core/python3-gobject` staged evaluation (exit 31) and `gnome/evolution` blocked on uninstalled EDS in earlier scan; manual package repairs reported separately by maintainer.
- [x] Confirm the last compat-32 scan has two `UNVERIFIABLE` ports (`lcms2-32`, `sqlite3-32`) plus NSS-32 `NEEDS REVIEW` and Expat-32 policy hold.
- [ ] Diagnose `python3-gobject` staged evaluation exit 31 from the helper staging path with a synthetic reproduction; no captured staged Pkgfile remains.
- [ ] Fix NSS/NSS-32 package-specific patch migration and both source/published release rules, test native/compat installation. Snapshot already contains version `3.131` for both, but historical scan errored on a stale `NSS_3_130_RTM` directory. Do not change those versions blindly.
- [ ] Address the persistent false `expat-32` 2.9.0 candidate and authoritative coordinated family hold.
- [ ] Investigate pre-existing `test-r423-updater-fixes.py` failure: `unknown active consumer was silently omitted`; not introduced by the source fixes above.
- [ ] Live-test corrected vendor URLs and full updater scan on BFSOS; container tests do not prove host package builds or installation.
- [ ] Remaining release scope (LibreOffice office ports, Brother HL-L8250CDN ports, CUPS physical printing, Plasma KAccounts installation, other older open tracker items) is **not implemented in r435**; retain earlier OPEN checkboxes.

See `docs/BFSOS-updater-log-audit-r435.md` for observed log details and regression run status. This is a targeted working pass, not a claim that every historical tracker item is complete.
