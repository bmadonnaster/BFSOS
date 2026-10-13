# BFSOS Fix Tracker r406 — 0.9.0

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
