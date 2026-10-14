# BFSOS Fix Tracker r412 — 0.9.1

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
- [ ] Validate during the next full BFSOS tree sweep.

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

- [ ] Audit the GitHub release provider used for Expat and determine exactly how `2.9.0` is being surfaced before it is a published release with a valid source asset.
- [x] Require the Expat candidate to map to a genuinely published upstream release, not merely a tag, milestone, future release marker, branch, or version-looking GitHub object.
- [x] Require the exact expected release asset/archive form to be derivable and reachable before emitting `UPDATE`.
- [x] Keep `core/expat` and `compat-32/expat-32` on the same verified upstream release unless there is an explicit BFSOS compatibility reason to pin one separately.
- [x] Preserve the currently valid `2.8.5` target until a later Expat release is actually published and verifiable.
- [x] Do not construct a hybrid URL that combines the old tag directory (`R_2_8_5`) with a newer filename such as `expat-2.9.0.tar.xz`.
- [x] If a future version is visible upstream but the corresponding published release/source asset is not available, report it as held/unverifiable rather than `UPDATE`.
- [x] Verify the same correction for both native and compat-32 scans.
- [x] Add regression coverage proving `2.8.5 -> 2.9.0` is rejected while 2.9.0 is unpublished/unreachable.
- [ ] Add regression coverage proving a later genuinely published Expat release is accepted for both `core/expat` and `compat-32/expat-32` when its expected release asset exists.

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

## Pending — updater must force selected package builds (2026-10-12)

**Status:** OPEN — fix in next revision; not implemented in the current updater.

### Problem observed

On a repeated kernel updater test, `core/linux` 7.2.10-1 and `core/linux-headers` 6.18.56-1 were reported `BUILT` even though `pkgmk` reported their package archives were already up to date and skipped compilation. Only `core/linux-lts` 6.18.56-1 actually compiled. Existing package archives from the earlier run caused the false success reports.

### Required fix

- In `scripts/bfs-port-updater.py`, use `pkgmk -f` when validating **selected updates that must actually be rebuilt**. The existing builder command uses `bfs-pkgmk` when available, otherwise `pkgmk`, with `-d -kw`; preserve those flags and append `-f` for this build-validation path. Confirm `bfs-pkgmk` forwards `-f` correctly.
- If a corresponding path builds through `prt-get`, use its supported `-fr` force-rebuild option after verifying the local CLI syntax; do not globally force unrelated package operations. The maintainer plans to run `prt-get -fr sysup` separately as a system-wide rebuild test.
- Do not equate a zero exit code with a freshly compiled package. Inspect build logs and resulting archive/version; distinguish `BUILT`, `ALREADY BUILT/SKIPPED`, and failed/rolled-back operations accurately.
- Preserve BFSOS build-work settings, parallel-job policy, existing package files until safe replacement, rollback behavior, and kernel config/patch policies.
- Add a regression test with a pre-existing exact-version package archive: selecting build validation must trigger an actual rebuild, not silently reuse the old archive.
- Avoid gratuitous repeat `glibc` release bumps from a repeated `linux-headers` build with the same version; distinguish new headers-version transitions from forced rebuilds.

### Live retest criteria

Reset kernel recipes for a controlled update scan, select `linux`, `linux-lts`, and `linux-headers`, and confirm each selected package compiles its requested sources. Verify log, produced artifact/version, and accurate summary status. Do not mark fixed from a successful command exit alone.


---

## Pending — register office collection in `/etc/ports/bfsos.git` and `/etc/prt-get.conf` (2026-10-12)

**Status:** OPEN — configuration integration needed; verify on an installed BFSOS system.

### Problem

The new `ports/office` collection is included in the project and referenced by `prt-get`, but **both live configurations** must register it: `/etc/ports/bfsos.git` needs the collection mapping:

```text
office:ports/office
```

and `/etc/prt-get.conf` needs the discovery entry:

```text
prtdir /usr/ports/office
```

### Required fix

- Update the **project-owned source/template or installer logic** responsible for generating `/etc/ports/bfsos.git` so the mapping is present on fresh installations and upgrades. Do not only patch the live file manually.
- Ensure adding the mapping is idempotent, preserves user customizations, and does not duplicate `office:ports/office` on repeated upgrades.
- Verify the repository checkout contains `ports/office`, and the ports synchronization action actually populates `/usr/ports/office`.
- Update the **project-owned `/etc/prt-get.conf` template/install/upgrade integration** to add `prtdir /usr/ports/office` on existing and new installs (not merely verify that it exists). Ensure idempotency and preserve local configuration. Verify that `prt-get` discovers office packages after synchronization. `pkgutils` should not require collection-specific changes merely to install built packages.
- Add regression tests for both fresh installations and upgrades from either configuration missing its office entry, including reruns without duplicates.

### Live retest

Inspect `/etc/ports/bfsos.git` **and** `/etc/prt-get.conf`, update the ports tree with the normal BFSOS sync workflow, verify `/usr/ports/office` exists, and confirm office ports appear in `prt-get` discovery.


---

## Pending — force LibreOffice builds onto disk-backed work storage (2026-10-12)

**Status:** OPEN — validate on BFSOS; do not mark fixed until build-backend selection and a live build are verified.

### Problem

LibreOffice is a very large compile and may exhaust the available RAM-backed/tmpfs build workspace. Its `office/libreoffice` port must use disk-backed build work rather than the default RAM/tmpfs backend, including when built through the BFSOS updater.

### Required fix

- Declare a **per-port disk build-work policy** for `ports/office/libreoffice`, using the existing supported BFSOS `bfs-pkgmk`/`pkgmk.conf` mechanism (`BFS_PKG_BUILD_WORK=disk` if supported). Confirm the exact override against actual wrapper/config before editing; do not invent a new unrelated mechanism.
- Ensure `scripts/bfs-port-updater.py` honors the override when selecting its build backend rather than automatically reverting to tmpfs. Apply the same behavior for normal supported package build entry points as appropriate.
- Keep source archives and generated packages in their existing cache destinations; only build *work* should be disk-backed. Preserve build logs, failure work trees (`-kw`), CPU-parallelism policy, and source integrity checks.
- Preflight disk free space/inodes before starting LibreOffice, and report the selected backend and location. A missing or insufficient disk workspace should fail clearly, **not** silently fall back to tmpfs.
- Add a regression test asserting that LibreOffice chooses disk storage even with plenty of free RAM and that other ports retain their configured policy.

### Live retest

Run a LibreOffice build through the ordinary BFSOS path. Confirm its work directory resides on disk (not tmpfs), it reaches completion without build-work ENOSPC, and the generated package is placed in the normal package cache.


---

## Pending — provide `rpm2cpio` for `office/libreoffice-bin` (2026-10-12)

**Status:** OPEN — build dependency is missing on the test BFSOS system.

### Observed failure

The `libreoffice-bin` Pkgfile stops with `libreoffice-bin requires rpm2cpio` because `rpm2cpio` is not on `PATH`. The recipe needs it to unpack upstream RPM payloads using `rpm2cpio "$rpm" | cpio -idmu --quiet`.

### Required fix

- Check whether an existing BFSOS port already provides `/usr/bin/rpm2cpio` (for example, through an RPM-related package). If absent, create and maintain a suitable `rpm2cpio` provider port in the appropriate collection; follow BFSOS Pkgfile conventions, upstream source and dependency policy. Do not add a duplicate package unnecessarily.
- Add the actual provider package to `# Depends on:` for `ports/office/libreoffice-bin/Pkgfile`; `cpio` is also used and must be declared as a build dependency. Preserve the runtime command checks as helpful error messages.
- Verify `prt-get` resolves and installs the provider before `libreoffice-bin`, and the `rpm2cpio` command is available under the normal package build environment.
- Test unpacking a real LibreOffice RPM and verify expected suite files and final package staging. Keep `libreoffice` and `libreoffice-bin` installation ownership conflicts guarded.
- Add a dependency/port-availability regression check so a new optional office port cannot ship with an undeclared tool requirement.

### Live retest

Install the missing provider through normal BFSOS tools, run `command -v rpm2cpio`, then rebuild `office/libreoffice-bin` and inspect the packaged payload.


---

## Pending — make `libreoffice-bin` co-installable with source-built `libreoffice` (2026-10-12)

**Status:** OPEN — implement and verify both packages installed together.

### Request

Move `office/libreoffice-bin` into an isolated installation prefix so it does not overwrite or conflict with the source-built `office/libreoffice` package. This allows side-by-side testing and supports users who intentionally install both suites.

### Required fix

- Audit the actual staged file lists and existing install paths for both ports. Keep `office/libreoffice` in its standard system location; install `office/libreoffice-bin` in a distinct prefix (suggest `/opt/libreoffice-bin`, subject to upstream RPM layout). Preserve upstream relative layout, shared libraries, extensions, UNO resources, and internal launch scripts.
- Make sure `libreoffice-bin` owns **no conflicting package paths**: binaries/symlinks in `/usr/bin`, desktop entries, icons, MIME definitions, AppStream metadata, man pages, and any system integrations must either have unique names/IDs or be omitted safely. Do not simply rename its top directory while letting shared integration files collide.
- Provide uniquely named launcher command(s), such as `libreoffice-bin` / `soffice-bin`, and distinct desktop application names/IDs, so users can deliberately select each installation. Verify the binary launcher's library/plugin lookup and that launching one suite does not accidentally invoke the other.
- Use separate user-profile directories (or explicitly configured profile URLs) for simultaneous testing; avoid profile locking and accidental migration/cross-version profile corruption.
- Keep source-built `libreoffice` independent; do not add reciprocal package conflicts or force one package to remove the other. Ensure upgrades/removal of either package leave the other functional.
- Preserve and finish the existing `rpm2cpio` provider/dependency fix for `libreoffice-bin`. Document side-by-side usage, storage impact, and chosen paths.
- Add file ownership/footprint and real runtime regression tests: build both packages, check overlapping paths, install both via normal BFSOS tools, launch both separately, then upgrade/remove each independently.

### Live retest

Install `libreoffice` and `libreoffice-bin` simultaneously with `prt-get`, check each package's owned paths and menu entries, open Writer/Calc from each, and confirm neither suite changes the other's binaries or user profile.

---

## Pending — install permanent PAM configuration for `runuser` (2026-10-12)

**Status:** LIVE FIX CONFIRMED; PERMANENT PACKAGING OPEN — `util-linux` final build now provides `runuser`/`setpriv`, and manually installed `/etc/pam.d/runuser` permits switching to `pkgmk` (UID/GID 82). Packaging and upgrade/fresh-install tests remain pending.

### Observed failure and diagnosis

After enabling `runuser` and `setpriv` in the **final** `core/util-linux` build (2.42.4, release 1 → 2), `sudo /usr/sbin/runuser -u pkgmk -- id` failed with `Failure setting user credentials`. The system had `/etc/pam.d/su` but no `/etc/pam.d/runuser` or `runuser-l`. `setpriv --reuid=82 --regid=82 --clear-groups /usr/bin/id` succeeded. Creating the dedicated `/etc/pam.d/runuser` PAM service configuration locally allowed `runuser` to work.

### Required permanent fix

- Audit `ports/core/linux-pam` (and any BFSOS-owned PAM defaults/configuration package) to determine which port owns and installs `/etc/pam.d` service policy. Add and package a properly reviewed **`/etc/pam.d/runuser`** file there, and evaluate whether **`/etc/pam.d/runuser-l`** needs its own service policy for login-style invocation. Do not blindly reuse `su` authentication rules or silently bypass account/session checks.
- Use the working tested configuration as a starting point: `auth sufficient pam_rootok.so`, `account include system-account`, `session required pam_env.so`, `session include system-session`. Validate service semantics against the actual shipped PAM stacks and util-linux runuser behavior. Keep file permissions root-owned and world-readable, and respect administrator-customized files during upgrades.
- Ensure both fresh ISO/installer deployments and existing system upgrades receive any missing configuration, without duplicating files or overwriting local modifications. Check installation-order dependency on linux-pam and util-linux and any alternatives/overlay that might replace the PAM service files.
- Keep the `util-linux` **bootstrap_build()** minimal (`--disable-all-programs` is intentional). Enable `runuser` and `setpriv` **only in the final package** and preserve `--disable-su` where `su` has another owner. Bump package release when package contents change.
- Add a regression test checking installed PAM paths, package ownership, absence of file conflicts, and `sudo /usr/sbin/runuser -u pkgmk -- /usr/bin/id` returning UID/GID 82 on a live BFSOS system. Verify both first install and upgrade paths.
- Related hardening (tracked with the LibreOffice/pkgutils work): `bfs-pkgmk` must not silently fall back to a root build if privilege dropping fails; distinguish real UID 82 from fakeroot's simulated UID 0. LibreOffice's actual configure/compile must execute without fakeroot interception and with a writable disk build workspace.

### Live retest

With the permanent PAM file installed by package management, confirm `runuser` switches to `pkgmk`, and verify the result survives an upgrade/reinstall or a fresh VM install. Then test LibreOffice's non-root compilation separately.


---

## Pending — enforce `pkgmk:pkgmk` ownership of BFSOS package caches and LibreOffice workspaces (2026-10-12)

**Status:** LIVE PERMISSIONS VERIFIED; INSTALLER/BOOTSTRAP AUDIT OPEN — the current system directories are already correctly owned, but provisioning and legacy per-port repair have not been verified in project code.

### Observed failure

With `runuser` enabled and the PAM service repaired, `sudo env BFS_PKG_BUILD_WORK=disk BFS_PKG_BUILD_JOBS=16 bfs-pkgmk -f -kw` initially failed with `ERROR: Directory '/var/cache/pkg/sources/libreoffice' not writable.` Previous root-run builds also left `/var/cache/pkg/build-work-disk/pkgmk-libreoffice` owned by root. The `pkgmk` service account is UID/GID 82, and should be able to create, reuse, and clean its work directories without manual repair.

### Required fix

- Ensure the following directories are created with **`pkgmk:pkgmk`** ownership and usable directory permissions:
  - `/var/cache/pkg/sources`
  - `/var/cache/pkg/sources/libreoffice` (and other per-port source directories as they are created)
  - `/var/cache/pkg/build-work-disk`
  - `/var/cache/pkg/build-work-disk/pkgmk-libreoffice` (and other per-port disk workspaces as they are created)
- Audit BFSOS package-cache initialization, `bfs-pkgmk` wrapper, `pkgmk` workflow, and installation/bootstrap provisioning. Establish ownership at creation time, including new or reused per-port directories, rather than relying on a one-time manual `chown`. Ensure the same policy applies to standard `/var/cache/pkg/build-work` where relevant.
- Safely reconcile existing root-owned cache/work directories from older builds without indiscriminately changing ownership of unrelated paths. Respect package-artifact ownership and permissions where intentional; scope repairs to BFSOS-controlled cache/work areas. Never recursively change ownership of `/var/cache` or `/var/cache/pkg` without auditing contents.
- On privilege drop, fail with an actionable diagnostic if a required cache/work path is not writable; **never silently fall back to real-root compilation**. Note that fakeroot can report UID 0 even while the process has real UID 82.
- Make cache setup idempotent on fresh installs, upgrades, and repeated builds, including selecting `BFS_PKG_BUILD_WORK=disk`. Keep the disk-backed LibreOffice workspace and `BFS_PKG_BUILD_JOBS=16` supported.
- Add regression tests: create a clean cache; run a build as `pkgmk`; simulate root-owned stale per-port directories; verify safe recovery/error reporting; retry a forced rebuild and confirm source-download, unpack, compile, and cleanup access.

### Live retest

Check `stat -c '%U:%G %a %n'` for all four paths, verify write access as `pkgmk`, and repeat `sudo env BFS_PKG_BUILD_WORK=disk BFS_PKG_BUILD_JOBS=16 bfs-pkgmk -f -kw` from `ports/office/libreoffice`. Verify directory ownership remains correct following a failed build and a successful build.


---

## Pending — repair source-built LibreOffice desktop integration and nonworking launchers (2026-10-12)

**Status:** FIXED AND LIVE-VERIFIED — LibreOffice 26.8.1-2 installed with `distro-pack-install`, normalized development-branded desktop entries, correct CLI commands/icons, working application launch and taskbar identity. Preserve regression coverage; no further LibreOffice rebuild is needed for this issue.

### Observed failure

- `pkginfo -i` confirms `libreoffice 26.8.1-1` installed.
- The package archive contains `usr/lib/libreoffice/share/xdg/{base,calc,draw,impress,math,startcenter,writer,xsltfilter}.desktop`, but not corresponding entries under `/usr/share/applications/`.
- Searching `/usr/share/applications` found no LibreOffice launchers. `command -v libreoffice` and `command -v soffice` returned no executable path.
- Manually symlinking `.desktop` entries into `/usr/share/applications` made the launchers visible but none successfully launched LibreOffice. A symlink-only fix is therefore insufficient.

### Required permanent port fix

- Audit `ports/office/libreoffice/Pkgfile`, the installed package manifest, and the actual program launch scripts under `/usr/lib/libreoffice/program/` (including executable mode, relative paths, required libraries, and whether the wrapper exists).
- Provide functioning, package-owned CLI entry points in `/usr/bin/` (e.g. `libreoffice` and `soffice`) using the upstream-supported wrapper/layout; do not guess an `Exec` path or create a dangling symlink.
- During package staging, install correctly named `.desktop` launchers under `/usr/share/applications/` for Writer, Calc, Impress, Draw, Math, Base, and Start Center; evaluate whether XSLT Filter is menu-facing. Make them package-owned rather than relying on ad-hoc post-install symlinks.
- Review each launcher’s `Exec=`, `TryExec=`, `Icon=`, `Categories=`, `MimeType=`, `NoDisplay=` and placeholders (`%U`, `%F`) against actual installed binaries and freedesktop requirements. If upstream desktop files need install-time variable substitution or relative-path rewriting, perform it during staging.
- Install/verify icon assets in the appropriate hicolor/theme lookup paths and include required desktop-file, MIME, and icon cache refresh hooks where applicable. Avoid package conflicts with separately tracked `libreoffice-bin` co-installation work.
- Investigate the **actual runtime failure** by executing the wrapper and collecting stderr/library loader errors; do not assume path placement is the only cause. Verify all needed runtime dependencies and paths before closing.
- Increment the port release number for a packaging-only change, rebuild/package via normal BFSOS tools, inspect archive entries, upgrade via `prt-get`, and clean up any test-only/manual symlinks safely if not package-owned.
- Regression test on GNOME, Plasma, and XFCE: menu entries appear, icons render, CLI `libreoffice`/`soffice` resolve, Writer/Calc/Impress open and create documents, MIME file associations work, and shortcuts survive reinstall/upgrade.

### Live retest

Collect `ls -l /usr/lib/libreoffice/program/soffice`, `grep -E '^(Exec|TryExec|Icon)=' /usr/lib/libreoffice/share/xdg/writer.desktop`, `command -v libreoffice soffice`, and the stderr from running an installed wrapper. Confirm the fixed package contains application launchers and command wrappers and that they actually launch as a normal user.


---

## Pending — `/usr/ports` ownership and trusted ports synchronization (2026-10-12)

**Status:** LIVE OWNERSHIP VERIFIED; PERSISTENCE/SECURITY AUDIT OPEN — `/usr/ports` and its category directories are currently `pkgmk:pkgmk`. The earlier root-owned claim was incorrect or outdated. Confirm nested port directory/file ownership separately; verify future sync/install behavior before making code changes.

### Required decisions and implementation

- Establish and document the **two-tree policy**: developer GitHub checkout (`~/BFSOS/ports`) remains owned by its developer; installed/synchronized `/usr/ports` is separately provisioned for package builds. Never recursively change ownership of the developer's Git tree.
- Audit how `httpup`/ports synchronization, fresh installation, bootstrap, and upgrades populate `/usr/ports`. Ensure the chosen ownership/ACL or scratch-copy policy persists after every update.
- **Security choice requiring review:** either provision the installed per-port build directories for `pkgmk` writes (while ensuring trusted recipes are not silently executed as root) **or**, preferably for isolation, keep authoritative ports root-owned and build from a `pkgmk`-owned working copy. Do not apply `chown -R pkgmk:pkgmk /usr/ports` automatically before settling this boundary.
- Ensure `pkgmk` (UID/GID 82) can safely create/update `.footprint` and any other required build metadata in the designated writable location. Do not grant the unprivileged account write access to the maintainer's checkout.
- Test after a ports sync, an initial BFSOS install, and an upgrade; verify both directory ownership and build behavior.

### Regression

From an installed port such as `/usr/ports/office/libreoffice`, perform a package-only metadata update as the unprivileged builder, verify no `mv: cannot create regular file '.footprint': Permission denied`, and verify a subsequent ports sync does not break the ownership policy.

---

## Pending — `pkgmk` footprint lifecycle and package-first metadata update (2026-10-12)

**Status:** DEVELOPMENT-TREE EDGE CASE; AUDIT OPEN — LibreOffice 26.8.1-2 built successfully and runs. The observed `.footprint` write failure occurred from the developer-owned `~/BFSOS/ports/office/libreoffice` tree, not the installed `pkgmk`-owned `/usr/ports` tree. Do not assume the normal installed-ports build path is broken. Check error reporting and optional developer-tree workflows before changing behavior.

### Observed behavior

- Switching to `distro-pack-install` legitimately added `/usr/bin` launchers, desktop entries, and hicolor icons, changing the recorded file list.
- With the old footprint present, the build hit a mismatch before a new archive was available; `bfs-pkgmk -uf` therefore reported `Unable to update footprint. File '/var/cache/pkg/packages/libreoffice#26.8.1-2.pkg.tar.zst' not found.`
- With `.footprint` absent, the build reported `WARNING: Footprint not found, creating new`, then `mv: cannot create regular file '.footprint': Permission denied`, **but still reported package build succeeded** in 5m 11s. The package archive did contain the expected new desktop assets.

### Required fix

- Audit the installed `pkgmk` and `bfs-pkgmk` wrapper and the already-tracked r405 footprint refresh logic. Define and test the expected sequence for missing footprints, reviewed footprint changes, and unexpected mismatches. Do not invoke `-uf` before the relevant archive exists.
- Make intentional packaging-only changes update package metadata without a full LibreOffice recompile, where the preserved build/staging results can safely be reused. If a review-override build is needed, make it narrow, explicit, and auditable.
- Ensure the footprint is written through an appropriately privileged/safely mediated step or from a writable build copy, not by broadening write permissions on the maintainer's Git checkout. Preserve security review for unexpected footprint changes.
- Do not report complete metadata success when writing the required `.footprint` failed. Distinguish `PACKAGE BUILT` from `FOOTPRINT UPDATE FAILED`, with actionable paths and commands.
- Add regression tests for: new port with no footprint; intentionally changed installed-file layout; stale/missing archive passed to `-uf`; root-owned `/usr/ports`; developer-owned Git checkout; and package-only rebuild reuse.

### Regression

A release-only LibreOffice packaging change should produce a correct `.pkg.tar.zst`, valid footprint, proper ownership, and menu/icon entries without a misleading success message or needless full source compilation.


---

## r413 reconciliation — package-build identity, directory ownership, installer audit (2026-10-12)

**Confirmed on the running BFSOS host:**

- `/etc/prt-get.conf` already has `makecommand bfs-pkgmk` (correct). `pkgmk` is the service-account username and also the underlying CRUX build utility; `bfs-pkgmk` is the BFSOS wrapper. **Do not file a `prt-get.conf` command-name bug or change it to `makecommand pkgmk`.**
- The live host shows `pkgmk:pkgmk` ownership on `/usr/ports` and all listed collection directories (`core`, `opt`, `office`, `plasma`, `gnome`, `xfce`, `xorg`, `compiz`, `lxqt`, `compat-32`, `contrib`). Earlier root-ownership concerns should **not** be treated as an active verified fault. Individual per-port paths and future synchronization behavior still merit verification.
- `/var/cache/pkg/sources`, `/var/cache/pkg/packages`, `/var/cache/pkg/build-work`, `/var/cache/pkg/build-work-disk`, and `/var/cache/ccache` all show `pkgmk:pkgmk` ownership on the live system. `/var/cache/pkg` itself is `root:root`, which is acceptable if its build subdirectories remain writable by the service user. No broad live `chown` is indicated by this evidence.
- Most historical `.pkg.tar.zst` files shown in package listings are `root:root`; LibreOffice 26.8.1-1 and 26.8.1-2 are `pkgmk:pkgmk`. **Existing file ownership does not automatically follow the containing directory** and is consistent with earlier builds having executed as root. This does not prove the current wrapper is still broken, nor require a mass change of old archives for package installation.
- The likely historical root-build cause is the earlier missing/disabled `runuser` (final `util-linux` package) plus absent `/etc/pam.d/runuser`, together with the previously observed wrapper fallback. Local fixes restored user switching and recent LibreOffice builds produced archives owned by `pkgmk`. Permanently package the PAM configuration, retain final util-linux `runuser`/`setpriv`, and **make the wrapper fail closed** when it cannot switch identities. Confirm actual wrapper implementation rather than assuming all paths are fixed.
- The LibreOffice `.footprint` permission failure was observed specifically when building as `pkgmk` from developer-owned `~/BFSOS/ports/office/libreoffice`. It is **not proof of a problem building from correctly owned `/usr/ports`**. Preserve a focused test for that developer-tree case and accurate error reporting instead of describing the entire installed ports tree as broken.

### Remaining tracker action — audit installer/bootstrap/upgrade provisioning (OPEN)

- Inspect the existing installer and bootstrap scripts first; avoid duplicating already-correct ownership initialization.
- On fresh install, upgrade, ports-sync and after tmpfs mounting, verify the actual `pkgmk` user/group and `pkgmk:pkgmk` ownership/writability of the installed ports collections and their required build metadata locations, `/var/cache/pkg/sources` (and per-port source subdirectories), `/var/cache/pkg/packages`, `/var/cache/pkg/build-work`, `/var/cache/pkg/build-work-disk` (including per-port directories), and `/var/cache/ccache` if BFSOS manages it. The parent `/var/cache/pkg` may remain root-owned.
- Distinguish read-only/trusted ports recipes from writable builder metadata in the security review. For the current installed tree, record the verified ownership but do not blindly change it on every run; use narrowly scoped, idempotent remediation and preserve the developer's Git checkout.
- Check fresh installer, existing-system migration, repeated upgrade/sync, reboot/tmpfs mount, and normal `prt-get` builds. Assert the build's **real** user identity and output archive owner, not fakeroot's reported UID.
- Avoid a forced rebuild of large packages purely to retest permissions; use a small representative port for end-to-end validation.

### Status summary

- **RESOLVED ON LIVE HOST:** correct `prt-get.conf` invocation; current top-level ports/cache ownership; `runuser` + PAM operation; LibreOffice 26.8.1-2 desktop integration.
- **STILL OPEN AS PERMANENT PRODUCT WORK:** ship PAM defaults; ensure final util-linux settings in source; remove wrapper root fallback; audit installer/bootstrap/upgrade/ports-sync ownership and tmpfs restoration; validate safe footprint behavior/error reporting from both trees.
- **NOT A CONFIRMED ACTIVE BUG:** root-owned historical package archives, root-owned `/var/cache/pkg` parent, or a misnamed `makecommand` in `prt-get.conf`.


---

## Pending — updater fallback/retry build job-count inconsistency (2026-10-12)

**Status:** REPORTED; NEEDS CODE/LOG VERIFICATION. During the XScreenSaver/XTerm update run, the initial build path reported `logical_cpus=32 jobs=32 source=default-all-cpus`. The user observed that the fallback/retry path instead used **12 jobs**. Treat this as an inconsistent parallelism-policy report, not yet a proven hardcoded `-j12` until the fallback logs and scripts have been inspected.

### Required audit and fix

- Trace each updater build, fallback, rollback/retry, and dependency-build invocation, including calls to `bfs-pkgmk`, `pkgmk`, `prt-get`, and any direct `make`/`ninja` commands. Identify why the fallback gets 12 jobs when the initial invocation gets 32.
- Preserve one shared effective parallelism decision across equivalent initial and fallback build paths, using all detected logical CPUs by default; honor intentional per-port `build_jobs` settings, explicit overrides, and documented resource-based caps. Do not silently reset to a legacy default.
- Verify propagation of `BFS_PKG_BUILD_JOBS`, `BFS_BUILD_JOBS`, `JOBS`, `MAKEFLAGS`, and `CMAKE_BUILD_PARALLEL_LEVEL` as applicable through subprocesses and privilege switching, while avoiding contradictory overrides.
- If the 12-job reduction is an intentional safety limit, log the reason and effective count rather than labeling it a generic fallback.
- Extend build-result logs/tests to show the requested and effective job count **for every attempt**, and regression-test normal, fallback, and rollback/retry routes with a 32-CPU default and an explicit per-port cap.

**Related finding:** the XScreenSaver and XTerm updates rolled back after `ERROR: Directory '/var/cache/pkg/sources/{xscreensaver,xterm}' not writable` (status 3); these were source-cache ownership failures before compilation, not evidence of upstream breakage. Verify per-port cache ownership repair as part of the existing cache-permissions tracker item; keep that independent of the job-count investigation.


---

## Pending — updater preselect routine updates in selection UI (2026-10-12)

**Status:** NEW USER-REQUESTED UX IMPROVEMENT; implementation pending. In a scan with 73 detected updates, manually selecting each ordinary update is unnecessarily tedious.

### Expected behavior

- Routine, eligible update rows start **checked / ON** by default in the updater selection screen.
- Items marked **REVIEW** start **unchecked / OFF** by default, regardless of whether a candidate version was found; preserve the safety rule even on refresh or re-entry.
- **SKIP**, blocked, unsupported, or otherwise ineligible updates start unchecked and cannot be inadvertently applied.
- Preserve user toggles while navigating/backtracking or refreshing the selection UI, where the candidate identity has not changed; do not silently reselect a manually deselected item.
- Retain usable **Select All / Deselect All** bulk actions, with Select All respecting REVIEW/blocked safety policy unless explicitly and safely overridden by the user.
- Make the summary counts distinguish detected, eligible, preselected, review, and blocked updates.

### Verification

Test a large scan (e.g. 73 rows) containing ordinary updates, REVIEW candidates, and blocked items. Confirm normal updates are preselected, REVIEW items remain off, bulk actions and per-item changes behave predictably, and no update executes without the user's final approval.


---

## Pending — updater optionally auto-install successfully built packages (2026-10-12)

**Status:** NEW MAINTAINER WORKFLOW FEATURE; implementation pending. During the Plasma sweep, `plasma/extra-cmake-modules` was **BUILT**, but dependent updates were marked **BLOCKED: updated prerequisite built but not installed/staged**. For the maintainer's local update workflow, allow each successfully built package to be installed/upgraded immediately, making newly built dependencies available to following builds.

### Requested behavior

- Add an explicitly visible **Auto-install built packages: ON/OFF** option to the updater, with **ON as the proposed default for the maintainer workflow**, and OFF for build-only operation. Make the selected mode visible on confirmation/results screens; do not silently install when OFF. Preserve settings over the current run.
- With ON, after verifying a successful build and the expected package archive, perform the appropriate privileged package installation/upgrade (normally `pkgadd -u` for an already-installed package; inspect the existing BFSOS/package-manager interface to determine the correct action for a package not yet installed). Do not install after a failed build or merely because an older archive exists.
- Follow dependency order: install an updated prerequisite such as `extra-cmake-modules` before compiling packages that need that newer version. Refresh installed-version state after success so subsequent packages are not incorrectly BLOCKED. Continue only after successful prerequisite installation.
- With OFF, retain build-only behavior and its safety rule: no dependent rebuild against an unstaged new prerequisite; offer staging in an isolated build root as a future alternative if useful.
- Record separate statuses **BUILT**, **INSTALLED/UPGRADED**, **INSTALL FAILED**, and **BLOCKED**, including archive path, command/exit status, and reason; distinguish a package's build success from install success. Report whether rollback concerns the Pkgfile only, the package archive, or the installed system.
- Privilege escalation must be explicit and narrowly scoped to package installation, not compilation. Audit pre/post-install hooks, dependency changes, failures, and effects on the live desktop. Warn/ask for confirmation before a bulk live-system upgrade, especially Plasma; ON is not a license to bypass final user confirmation.
- Regression-test a chain `extra-cmake-modules -> KDE Frameworks -> Plasma`, new package vs installed package, skipped/REVIEW prerequisite, build failure, install failure, interrupted run, and auto-install OFF. Do not conflate version discovery with confirmed build/install success.

### KDE Frameworks 6.30.0 → 6.31.0 regression findings (2026-10-12)

**Status:** CONFIRMED dependency-ordering/install-state issue; covered by this existing item, **not** a separate CMake/toolchain upgrade task.

After the maintainer built `extra-cmake-modules` and attempted a subset of KDE Frameworks 6.31.0 packages, these were **BUILD FAILED** during CMake configuration because the installed `/opt/kf6` dependency remained at 6.30.0:

- `plasma/kbookmarks` needs **KF6Config >= 6.31.0**; installed config reports **6.30.0**. `kconfig` had successfully built but was not installed.
- `plasma/kcmutils` needs **KF6KIO >= 6.31.0**; installed config reports **6.30.0**. Upgrade `kio` before attempting `kcmutils`.
- `plasma/kdav` needs **KF6CoreAddons and KF6I18n >= 6.31.0**; installed configs report **6.30.0**. `kcoreaddons` had built but was not installed; `ki18n` must also be upgraded before retrying `kdav`.

**Refined acceptance criteria:**

1. Resolve an update batch in **dependency order**, verifying that newly built prerequisites have been **installed/upgraded and version-checked** before building a dependent package when auto-install is ON. Re-evaluate dependents' readiness after prerequisite installation rather than cascading BLOCKED outcomes based on stale installed-version data.
2. Distinguish an identifiable CMake **required KF6 6.31.0, installed KF6 6.30.0** prerequisite mismatch as **DEPENDENCY NOT READY** (with the missing package/version and actionable explanation), rather than a generic **BUILD FAILED**. Preserve genuine compile/configuration failures as BUILD FAILED when the cause is not clearly a missing updated prerequisite.
3. Regression-test the exact `kconfig -> kbookmarks`, `kio -> kcmutils`, and `kcoreaddons + ki18n -> kdav` paths. Verify auto-install OFF still blocks safely without modifying the running system, and that install failure blocks dependents.
4. Do **not** interpret these logs as requiring a CMake version upgrade; CMake correctly rejected incompatible KDE Frameworks configuration files.

### Related tracker items

- Existing dependency-staging / cascading `BLOCKED` issue surfaced by Plasma bulk update.
- Updater initial-vs-fallback job count, normal-update preselection, package-cache permissions, wrapper fail-closed, and PAM/runuser provisioning remain separate issues.

---

## r438 implementation — 2026-10-12 uploaded-project fixes

**Scope:** Changes were made to the attached BFSOS source snapshot and checked locally; no package installation, `ports -u`, reboot, GUI interaction, or real package build occurred on the maintainer's host. An unchecked live retest is not a confirmed installed-system fix.

### Implemented in this source revision (live retest still required)

- [x] **Force selected updater build validation:** `bfs-port-updater.py` now passes `-f` to `bfs-pkgmk` for each selected build, while the separate reviewed package-first `.footprint` commands retain their intended `-if`/`-uf` sequencing (without an accidental `-f` suffix). This prevents a previously cached exact-version package from being reported as newly compiled merely because pkgmk exited successfully; live archive/compiler verification remains necessary.
- [x] **Unify retry build concurrency:** `retry_failed_updates()` no longer runs raw `sudo pkgmk -d -kw`; it selects the same tmpfs/disk backend, job policy (`all logical CPUs`, user override, per-port `build_jobs` cap), environment and forced `bfs-pkgmk` invocation used in first-pass builds. Per-retry log headers show effective parallelism, including when the maintainer has 32 logical CPUs. Tested with a synthetic 32-CPU retry.
- [x] **Remove root fallback from wrapper/updater:** the `pkgutils` `bfs-pkgmk` wrapper now refuses to build as root if the `pkgmk` account, `runuser`, or `fakeroot` is missing. The primary updater also refuses to fall back to `sudo pkgmk` when `bfs-pkgmk` is unavailable. The wrapper still supports an explicitly invoked nonroot developer build from a writable checkout. `ports/core/pkgutils` release increased 41 → 42; install required.
- [x] **PAM `runuser` provisioning:** `ports/core/linux-pam` now packages `/etc/pam.d/runuser` with BFSOS system-account/session includes. Linux-PAM release increased 1 → 2. The supplied `ports/core/util-linux/Pkgfile` already enables `runuser`; no gratuitous additional release bump. Live PAM and `runuser -u pkgmk` test still required.
- [x] **Fresh-install/upgrade cache ownership audit:** installer now has `ensure_pkgmk_build_ownership()` which requires the dedicated account and repairs BFSOS-owned source, archive, tmpfs work, disk work, and ccache trees. The existing tmpfs mount configuration already enforces uid/gid 82 after mounts. `/var/cache/pkg` parent remains root-owned. It does **not** recursively chown `/usr/ports`; the trust boundary and sync policy remain under separate review.
- [x] **Office collection packaged configuration:** the existing installer and `prt-get.conf` already include `office`. Fixed `ports/core/prt-get/bfsos.git` to include `office:ports/office`, and added an idempotent local-customization-preserving registration in its post-install upgrade hook. `prt-get` release increased 3 → 4; live upgrade and office discovery still require verification.
- [x] **Normal update selection UX:** routine `UPDATE` rows start checked, `REVIEW` and blocked/unsupported entries start unchecked. Maintainer can still toggle entries; the updater's transaction guard remains in effect. Persistence of manual toggles across full rescans and bulk action enhancements require additional interactive QA.
- [x] **Optional install-after-build mode:** the interactive menu now explicitly offers build+auto-install ON (the default build workflow) or build-only OFF. Confirmation distinguishes changes to the running system. After a verified successful build, the updater locates the expected archive, queries installed package names, uses `sudo pkgadd -u <archive>` for upgrades or `sudo pkgadd <archive>` for first installs, and advances only on installation success. The old `prt-get -fr depinst` duplicate-build invocation was removed in normal and retry installation paths. This is **not** an atomic rollback of live package upgrades; the live Plasma transaction must be tested carefully.
- [x] **KF6 dependency order/diagnostics:** added direct dependencies for `plasma/kbookmarks -> kconfig` and `plasma/kdav -> kcoreaddons,ki18n` (the existing `kcmutils -> kio` dependency was already present). In logs containing the unambiguous CMake `KF6*` installed-version mismatch, the updater reports retryable `BLOCKED: DEPENDENCY NOT READY`, not a generic compile failure. Genuine/unrecognized build errors remain `BUILD FAILED`.
- [x] **Regression maintenance:** added `scripts/tests/test-r438-installer-updater.py` covering force flags, footprint command sequencing, default selection, wrapper/PAM/office provisioning, 32-job retry, and KF6 mismatch classification. Corrected the old r394 synthetic test to mock the now-required `bfs-pkgmk` lookup. Corrected r423 test to use the project's actual `VERSION` rather than hardcoded old `0.9.0`.

### Confirmed already implemented in the uploaded project, no duplicate fix made

- The source LibreOffice port already has `build_work=disk`, `build_jobs=16`, release 2, and upstream `distro-pack-install` desktop integration; the maintainer already live-tested the program and taskbar behavior. No unnecessary LibreOffice rebuild was performed.
- The installer and `prt-get.conf` already declare the Office collection; only the packaged `bfsos.git` definition was missing it.
- `ports/core/util-linux` already has `--enable-runuser` and `--enable-setpriv` in its final configuration.
- The `/usr/ports` top-level and main BFSOS build cache directories were already observed as `pkgmk:pkgmk` on the user's live system; historical root-owned archive files do not alone prove current builds run as root.

### Still open or live-test-only

- [ ] **Installed `/usr/ports` recipe ownership/trust policy and `.footprint` writes from a developer-owned Git checkout:** choose root-owned scratch-copy policy vs trusted installed-port permissions; don't silently chown an arbitrary developer repository. Test successful missing/changed footprint persistence; prior CLI `mv: Permission denied` was observed in developer tree, not normal installed ports.
- [ ] **Per-package cache repair on builds between installer/upgrade runs:** the new installer repair covers historical root-owned per-port cache children during provisioning; a safe ongoing privileged repair mechanism requires explicit security design rather than arbitrary recursive ownership changes from package scripts.
- [ ] **Office `libreoffice-bin` RPM extraction dependency and coinstallation:** do not claim solved without a verified real RPM/manifest, provider of `rpm2cpio` and `cpio`, unique integration IDs, or a side-by-side install test.
- [ ] **Fribidi file ownership collision and all other historical tracker items not explicitly handled in this revision:** retain prior status; no global unsafe `pkgadd -f` override.
- [ ] **Maintainer live retests:** build/install the changed `linux-pam`, `pkgutils`, and `prt-get` packages; validate `/usr/ports/office` discovery, root-fallback refusal, old root-owned per-port cache repairs, actual kernel forced rebuild, 32-job fallback and full KF6 6.31.0 dependency chain with auto-install ON and OFF. Use a disposable VM or carefully controlled host update for live Plasma installs.

**Validation:** Python compilation and shell syntax checks pass; regression suites r377, r394, r396, r397, r400, r404, r405, r406, r413, r415, r419, r423, r435, r437, r438 plus r436 office shell test pass in the supplied tree. These tests are mostly policy/mocked checks; do not conflate them with successful real package builds.


---

## r442 TODO — Port updater resume/recovery for already-current Pkgfiles (2026-10-12)

**Status:** [ ] OPEN — high priority, updater workflow. This is a tracker requirement, not an implemented fix.

**Problem:** After a partially completed updater run, Pkgfiles may already be updated to their target version even though the package installed on the live system is older. A normal upstream update scan then reports no changes and cannot resume building/installing those packages. Attica 6.31.0 was built with a valid archive while 6.30.0 remained installed until manual `pkgadd -u`; other KDE Frameworks packages may be in the same state.

**Required implementation:**

- [ ] Add **Resume pending updates** to the updater main menu. This scan must use local Pkgfile name/version/release, installed package database, and exact cache archives, independently of whether upstream has a newer Pkgfile version.
- [ ] Compare complete version **and package release**; skip already-installed exact matches. List only pending/out-of-sync packages with their Pkgfile version, installed version, exact archive availability, and proposed action. Respect absent/not-yet-installed packages so resume does not unexpectedly bulk-install every optional port in the tree. Limit initial candidates to interrupted/previously selected work, recorded update history, or an explicit user-chosen scope; require confirmation of any wider scan.
- [ ] With an exact, trustworthy existing archive, offer **install/upgrade from cache with no rebuild**. Do not treat a similarly named or older archive as the target. Reject ambiguous or invalid archives; validate package identity/version/release before privileged installation.
- [ ] If the exact archive is missing, offer **build then install** using the unprivileged `bfs-pkgmk` wrapper and correct metadata ownership; do not silently force a rebuild when a verified artifact exists. Preserve an explicit **auto-install ON/OFF** choice and a reviewed per-package toggle list.
- [ ] Resolve dependency order (especially KF6 6.31.0: `kconfig -> kbookmarks`, `kio -> kcmutils`, `kcoreaddons + ki18n -> kdav`), ensure required installed prerequisite versions are ready, and block dependents when an installation fails. Verify installed version after each successful `pkgadd` rather than trusting its exit code alone.
- [ ] Make interrupted work restartable/idempotent: persist batch identity, intended targets, outcome of build/install/verification, and pending items. Do not discard completed work or reset user-modified Pkgfiles on restart. Keep distinct **BUILT**, **INSTALLED**, **INSTALL FAILED**, **BLOCKED**, and **SKIPPED** states. Do not claim an automatic live-system rollback.
- [ ] Persist exceptions/tracebacks in `logs/update` and provide actionable failure summaries. Regression-test an interrupted Attica/KF6 update, valid cached archive/no rebuild, missing archive/rebuild option, mismatched version/release, already installed, prerequisite failure, `pkginfo` failure, and user-cancelled or auto-install-OFF recovery.

**Acceptance test:** With a 6.31.0 Pkgfile, installed 6.30.0 and a valid cached 6.31.0 archive, resume displays that port as pending and installs it after confirmation **without compiling**. Already-installed Attica 6.31.0 is skipped. The next dependency is not processed until the required packages are installed at the correct versions.

**Related completed r441 tests (not proof of resume):** wrapper `-um`/`-uf` metadata writes in Attica produced `brian:brian` files; the manual Attica 6.31.0 `pkgadd -u` worked; updater auto-install and resume flow still need live end-to-end validation.

---

## r443 TODO — libcap-ng / util-linux build dependency and base/bootstrap integration (2026-10-13)

**Status:** [ ] OPEN — high priority, core/base dependency correctness. Confirmed by clean installed BFSOS VM test.

**Observed regression:** The VM had `util-linux 2.42.4-1` without `runuser` or `setpriv`. Its synchronized `util-linux 2.42.4-2` port correctly enabled both tools, but a fresh build failed at configure time with `setpriv selected, but required libcap-ng library not available`. Installing `libcap-ng 0.9.6-1` allowed the VM to build `util-linux 2.42.4-2`; the resulting archive contained `usr/sbin/runuser` and `usr/bin/setpriv`. The build also exposed a stale `.footprint` that required manual removal/rebuild — track separately under packaging metadata handling.

**Required changes:**

- [ ] Declare `libcap-ng` as a required dependency in `ports/core/util-linux/Pkgfile` (verify the actual `# Depends on:` declaration and any generated dependency metadata).
- [ ] **Audit all existing libcap-ng declarations** against actual BFSOS configure options, installed ELF `DT_NEEDED` linkages, and any optional/dlopen use before promoting or removing dependencies. On the bare-metal installation, `grep` found references in `ports/opt/{cifs-utils,libvirt,qemu,spice-gtk}/Pkgfile`: cifs-utils declares it **optional**; libvirt, qemu, and spice-gtk declare it **required**. These are declarations, not proof each build needs the library.
- [ ] **Confirmed bare-metal linkage evidence:** `/usr/bin/setpriv` (util-linux), `/usr/sbin/mount.cifs` (cifs-utils), `/usr/lib/libvirt.so.0.12008.0` and `/usr/lib/libvirt/connection-driver/libvirt_driver_lxc.so` link directly against `libcap-ng.so`. Preserve util-linux and libvirt as required dependency candidates; inspect cifs-utils' build/configuration and consider promoting its currently optional `libcap-ng` to required **for the enabled feature set**. Do not conclude all cifs-utils configurations require it solely from this installed binary.
- [ ] **Not yet confirmed:** qemu and spice-gtk may need libcap-ng, but the initial `find`/`readelf` test did **not** inspect all their shared objects/plugins or build-system feature probes. Audit entire installed package file lists and build logs/configure flags, including optional linkage or runtime `dlopen`, before changing their `# Depends on:` entries. Record proof or document why the dependency is optional/not used.
- [ ] Keep Linux capabilities libraries distinct: `libcap` (standard LFS/MLFS package) is **not** `libcap-ng`; check whether BFSOS bootstrap already supplies `libcap`, but do not treat it as satisfying util-linux `--enable-setpriv`'s libcap-ng check. Verify exact stage-specific configure options before modifying bootstrap.

- [ ] Audit `libcap-ng`'s present `ports/opt/` location. Decide whether the port should move to `ports/core/` or be pulled in as a cross-collection core prerequisite; ensure no duplicate/conflicting port identity and update all relevant references.
- [ ] Ensure the **base package manifest and base archive build** include `libcap-ng` and install/build it before `util-linux` when `--enable-setpriv` is in effect. Confirm the resulting base filesystem contains `runuser`, `setpriv`, and required runtime libraries.
- [ ] Audit bootstrap stages 1–3, bootstrap package lists, dependency resolution, and base-generation ordering. Add `libcap-ng` to the **earliest stage that builds util-linux with `setpriv` enabled**; do not assume every bootstrap stage needs it. Preserve toolchain purity and explicit stage ordering.
- [ ] Add clean-VM / clean-chroot validation with no preinstalled `libcap-ng`: the declared dependency must be resolved automatically before util-linux configuration; tests must not pass only because the maintainer's workstation already contains `libcap-ng`.
- [ ] Validate the installed VM build workflow: `linux-pam 1.7.3-3`, `util-linux 2.42.4-2`, functional PAM configs, `sudo runuser -u pkgmk -- id`, and a nonroot `bfs-pkgmk` build. Keep `/etc/pam.d` preservation and the historical Linux-PAM release-2 omission under the separate PAM safeguard item.
- [ ] Before publishing a new ISO/base archive, verify package manifests, library linkage (e.g. `ldd /usr/bin/setpriv`), exact installed versions, installer inclusion and dependency ordering.
- [ ] Review all intended changes with `git status`, commit and push them, run `ports -u` in the clean VM, and revalidate. Do not leave tested core fixes uncommitted.

**Acceptance criteria:** A fresh BFSOS VM or chroot starting without `libcap-ng` can resolve prerequisites, build and install util-linux with `setpriv`/`runuser`, run the unprivileged package wrapper, and produce a base archive containing the working dependency chain. No manual `prt-get install libcap-ng` should be required once core/base dependency resolution is configured.

**Related issue:** Stale `.footprint` after payload changes should be handled by a reviewed metadata update workflow, not silently deleted by `sysup`; retain that as a separate package-build tooling task.

---

## r445 OPEN — Kernel upgrade retention, rollback policy, and orphaned /boot artifacts (2026-10-13)

**Observed on bare-metal BFSOS after system update:** Running `6.18.56-BFS-LTS` (`uname -r`). `/lib/modules` includes `6.18.55-BFS-LTS`, `6.18.56-BFS-LTS`, and independently installed `7.2.10-BFS-Linux`. `/boot` retains complete 6.18.55 and 6.18.56 LTS images/configs/System.map/initramfs; active `vmlinuz-lts -> vmlinuz-6.18.56-BFS-LTS`. `/boot` also contains `initramfs-7.2.6-BFS-Linux.img` (135M), `initramfs-7.2.7-BFS-Linux.img` (137M), `initramfs-7.2.8-BFS-Linux.img` (137M), and `initramfs-7.2.9-BFS-Linux.img` (137M), without corresponding vmlinuz files in the provided listing.

- [ ] Audit linux-lts and alternate-kernel pre/post-install hooks, kernel rollbacks, dracut generation, package ownership/footprint and bootloader updates.
- [ ] Determine whether **one previous known-good LTS** with complete matching kernel/modules/initramfs/GRUB entry is intentionally preserved; retain it if this is the rollback policy.
- [ ] Identify obsolete 7.2.x initramfs images and why their generating kernel upgrades leave them behind; check package ownership and GRUB entries before deleting anything.
- [ ] Implement safe, bounded retention and garbage collection for truly orphaned boot images/modules, including dry-run/report-only output; never delete a running kernel, intentionally installed alternate kernel, or verified rollback kernel.
- [ ] Verify free space on `/boot`, `uname -r`, `pkginfo -i`, `ls -l /boot`, `/lib/modules`, and GRUB boot entries after successive kernel upgrades in the VM. Verify normal and rollback boot.
- [ ] Document retention policy and distinguish kernel cache cleanup from installed files cleanup.

**Safety:** Do not manually remove `6.18.55-BFS-LTS` while rollback purpose is unverified; preserve unrelated `7.2.10-BFS-Linux`.

## r446 OPEN — Plasma taskbar Firefox icon and KDE Discover launch/icon regression (2026-10-13)

**Observed:** Bare-metal Plasma taskbar screenshot shows generic document icons for applications; Firefox taskbar icon is wrong. KDE Discover also shows a wrong/missing icon **and does not launch** after package upgrades/recovery. Do not presume these symptoms have one cause.

- [ ] Locate installed Firefox desktop launcher (`firefox.desktop`) and Discover launcher (`org.kde.discover.desktop` or actual installed name), check `Exec`, `Icon`, `StartupWMClass`, DBus activation and installed icon themes/files.
- [ ] Determine if Firefox's pinned task manager entry refers to a stale/incorrect launcher or mismatched WM_CLASS; test launching via the installed `.desktop` file and repinning only after verified metadata.
- [ ] Attempt Discover from a terminal; capture stderr, exit code and journal messages; verify `plasma-discover`, its Qt/KF runtime dependencies, plugins/backends (PackageKit/Flatpak as configured) and icons were actually packaged and installed.
- [ ] Audit upstream Plasma package updates, desktop file paths, icon caches and the KDE menu database; verify whether icons reappear when running apps vs pinned shortcuts.
- [ ] Fix underlying ports or post-install integration and add an upgrade regression test; do not use icon-theme cache rebuild as substitute for diagnosis of Discover's startup failure.
- [ ] Validate both launchers on fresh VM installation and upgraded physical system (after PAM recovery) with expected taskbar icons and functioning Discover.

**Read-only triage:** `command -v discover; command -v firefox; find /usr/share/applications ~/.local/share/applications -maxdepth 1 -iname '*firefox*' -o -iname '*discover*'` (group find predicates when refining); run `plasma-discover`/`discover` from a terminal to capture actual failure before changing files.

---

## r447 TODO — Expat 64-bit update missed while expat-32 detected (2026-10-13)

**Status:** [ ] OPEN — updater detection/collection parity investigation.

**Observed:** BFSOS Port Updater offered `compat-32/expat-32` update `2.8.5 -> 2.9.0` (release `1 -> 1`, `github-release+latest-redirect`, marked REVIEW / toggle OFF), but the user reports that `core/expat` (64-bit) did not appear as available for update in the corresponding updater scan. Prior VM `prt-get diff` showed installed `expat 2.9.0-1` versus repo `2.8.5-1`; do not assume that same state applies to the current bare-metal host.

**Required investigation:**
- [ ] Read both `ports/core/expat/Pkgfile` and `ports/compat-32/expat-32/Pkgfile` for current version, source URL, upstream identity, patching, release, and any update exclusions.
- [ ] **Check BFSOS MLFS/LFS version-source policy first:** determine whether `core/expat` is deliberately pinned to the MLFS development book (or another defined LFS/MLFS source). If so, `compat-32/expat-32` must normally inherit the approved 64-bit Expat **upstream version** and compatible security patches rather than independently following the latest GitHub release. Record any justified, explicitly approved architecture-specific exception. Do not auto-change either port to 2.9.0 until policy and actual book version are verified.
- [ ] Audit the updater priority rules so core LFS/MLFS-managed packages and their compat-32 counterparts use the same authority and report external newer releases as advisory/review instead of treating them as routine upgrades. Add a shared version-source or related-port mapping and a mismatch warning.
- [ ] Compare both local ports, installed versions, scanner candidate state, and the actual scan TSV; establish whether the 64-bit port was already current, disabled, skipped, filtered out, misparsed, or given a different upstream discovery result.
- [ ] Verify that 2.9.0 exists at the *actual source URL each recipe uses*, and check hashes/build compatibility before applying either update.
- [ ] Audit version-source detection, cross-collection coverage, alias handling (`expat` vs `expat-32`), GitHub release/redirect parsing, candidate deduplication, and independent per-port toggle behavior.
- [ ] Ensure updater reports a clear explanation when a sibling architecture port is already current or cannot be resolved; do not silently suppress a 64-bit candidate because a 32-bit candidate was discovered (or vice versa).
- [ ] Add automated paired-port fixture/regression: both out of date; only 64-bit out of date; only 32-bit out of date; both up to date; unreliable GitHub release detection (REVIEW/OFF). Keep 32/64 toggles independent, with optional advisory that matching releases exist.
- [ ] Confirm security-update prioritization does not bypass source/version verification, and test proposed changes in VM before committed publication.

**Acceptance criteria:** For Expat, the updater first applies the approved BFSOS LFS/MLFS version source, then examines both architecture ports and accurately represents their states (update, already-current, version-policy mismatch, or review needed); no genuine 64-bit update is silently omitted, and 32-bit does not auto-advance beyond the approved matching upstream version.

---

## r448 TODO — expat-32 selection blocks unrelated core updater jobs (2026-10-13)

**Status:** [ ] OPEN — reproducible selection-sensitive batch failure; exact failure mode not yet established.

**User-observed behavior:** In one BFSOS Port Updater batch, leaving `compat-32/expat-32` selected caused other core package updates not to apply. On the second attempt, the user left `expat-32` unchecked, and those core updates completed successfully. The failure stage (candidate planning, download, build, install, rollback, or orchestration) is **not yet known**. Do not assert `expat-32` was itself compiled, installed, or rolled back without checking logs.

**Investigation and fixes:**
- [ ] Locate both update runs' `logs/update/scan-*.tsv`, `build-*.log` and orchestration logs; compare selections, scheduling, first error, attempted changes and rollback outcomes.
- [ ] Reproduce in a clean VM with the same checked/unchecked candidates. Include the approved LFS/MLFS Expat version and `core/expat` ↔ `compat-32/expat-32` parity decisions from r447.
- [ ] Inspect the scheduler's failure propagation: one package failure should not silently suppress **unrelated** core jobs; explicitly dependent packages should be deferred with a clear dependency explanation, not reported as successful.
- [ ] Audit transaction scope and rollback: ensure a failed compat-32 update does not undo unrelated successful core upgrades or revert Pkgfiles outside its rollback scope. Preserve the original recipe on failure and log every affected port.
- [ ] Display meaningful per-port outcome and reason: attempted/failed, blocked-by-dependency, skipped-by-policy, rolled-back, or successfully installed. Provide a final summary with a retry path for the unaffected updates.
- [ ] Add batch regression tests: `expat-32` selected and fails, `expat-32` deselected, and `expat-32` selected and succeeds; assert independent core package updates proceed when safe and dependencies are respected.

**Acceptance criteria:** The user's successful second-run behavior is preserved; selecting a problematic compat-32 candidate cannot silently prevent unrelated core package upgrades, and any genuine dependency block is reported accurately. No version-policy violation is introduced to work around the failure.

---

## r449 TODO — SQLite 64-bit detection missed while sqlite-32 updates; upstream version policy (2026-10-13)

**Status:** [ ] OPEN — updater cross-architecture discovery/version-source bug investigation and policy change proposal.

**Observed on bare-metal BFSOS:** `sudo prt-get info sqlite` reports `core/sqlite` **version 3.53.4, release 1** in `/usr/ports/core`. In the same updater activity, the user reports **`compat-32/sqlite-32` received a detected update and was updated**, but `core/sqlite` was not offered an update. This alone does **not** establish that `3.53.4` is behind the latest upstream release: inspect actual scan and installed/recipe versions before deciding.

**User-requested policy:** SQLite releases frequently; **do not automatically pin SQLite to the LFS/MLFS book version**. Propose SQLite as an explicit BFSOS *upstream-tracking exception* to the normal core book-version policy, with independently verified official release metadata, security fixes, and compatibility. Both architectures should ordinarily use the same accepted upstream SQLite version, while allowing separate package release numbers and architecture-specific flags.

**Investigation and actions:**
- [ ] Record `ports/core/sqlite/Pkgfile`, `ports/compat-32/sqlite-32/Pkgfile`, installed versions (`pkginfo -i`), and latest *verified official SQLite upstream version*. Identify whether 64-bit is already current, intentionally excluded, or missed by detection.
- [ ] Examine current updater scans, candidates, selection state and logs for `core/sqlite` versus `compat-32/sqlite-32`. Check whether one architecture's candidate suppresses the other; ensure both are examined and accurately reported.
- [ ] Audit the updater's version-source priority rules: make `core/sqlite` an **explicit upstream-tracking exception** to LFS/MLFS version pinning, rather than changing the overall policy. Ensure `sqlite-32` inherits the same accepted upstream version and security advisories.
- [ ] **Preserve the existing SQLite Pkgfile source-version conversion expressions** and URL logic. The recipe already handles SQLite's special numeric source/archive naming; do not overwrite formulas or hardcode derived source filenames. Change only `version=` when justified, plus separately required patches/release bump.
- [ ] Validate official SQLite version metadata, chosen source archive availability, checksums/signatures, library ABI/SONAME and 32-/64-bit build settings; add review gating when a release cannot be reliably verified.
- [ ] Add regression fixtures for SQLite version conversion and cross-architecture reporting: both stale, 64-bit stale only, 32-bit stale only, both current, upstream metadata unavailable, and unusual archive version naming.
- [ ] Run clean-VM builds and test dependent packages before publishing updates; verify no cross-architecture selection blocks other core updates (related r448).
- [ ] Document the upstream-exception policy in updater documentation and release maintenance notes.

**Acceptance criteria:** On identical approved upstream SQLite releases, 64-bit and 32-bit ports are both checked and correctly identified as current/updatable; neither disappears silently; the correct SQLite archive names are retained; upstream-vs-book policy is explicit, scoped to SQLite, and tested.

---

## r450 TODO — Coordinate GStreamer and gst-plugins 64-bit/32-bit release-set updates (2026-10-13)

**Status:** [ ] OPEN — new updater feature / dependency consistency requirement.

**Requested behavior:** When a new compatible upstream GStreamer release is available, discover and propose the related GStreamer framework and gst-plugins ports as **one coordinated update set**, across both native 64-bit and compat-32 builds. Do not silently update only one component or one architecture while overlooking other members of the selected release train.

**Investigation and implementation:**
- [ ] Inventory the actual BFSOS native and compat-32 GStreamer family ports and their dependency graph (at least `gstreamer`, `gst-plugins-base`, `gst-plugins-good`, `gst-plugins-bad`, `gst-plugins-ugly`, `gst-libav` where present, and any other release-coupled `gst-*` modules). Do not invent or assume a 32-bit counterpart exists for every item.
- [ ] Determine upstream release alignment and which components genuinely share one versioned release set; treat independently versioned components separately, with explicit compatibility checks rather than forced version equality.
- [ ] Apply BFSOS's approved version-source policy consistently to the entire group. Detect the latest verified common upstream release and check source archive availability and integrity for every member **before** offering a coordinated update.
- [ ] Link native and 32-bit counterparts to the same accepted upstream version when applicable, while preserving independent BFSOS package `release=` numbers, arch-specific patches, dependencies, and compile options.
- [ ] Present one grouped proposal in the updater with individual package names, installed/recipe versions, proposed versions, confidence, dependencies, and selectable controls. An intentional partial selection must trigger dependency/ABI validation and a clear warning or block when unsafe.
- [ ] Stage downloads and builds in dependency order (framework, plugins-base, then downstream plugins/modules, with proper native/compat-32 dependencies); ensure failure/rollback never undoes unrelated updates. Record which parts of the release set succeeded or were not attempted.
- [ ] Cover missing upstream artifacts, one architecture lagging, incomplete release sets, one package failing, previously up-to-date members, and safely skipped optional plugins in regression tests.
- [ ] Confirm package metadata, runtime plugin discovery via `gst-inspect-1.0`, and representative multimedia functionality for both available ABIs in a clean VM. Validate full batch application and report results before including in a new BFSOS base/ISO.

**Acceptance criteria:** A GStreamer upstream release produces one accurately version-aligned, dependency-safe review set for the relevant 64-bit and 32-bit BFSOS ports. No valid sibling update is silently missed; unrelated core updates are not blocked by a failure in the GStreamer set; users receive explicit partial/rollback status.

---

## r451 implementation checkpoint — partial tracker work against full 2026-10-13 source archive

**Status:** SOURCE FIXES IMPLEMENTED; synthetic/offline tests PASS; **full tracker not complete**. This checkpoint is based on the supplied BFSOS-current-20261013 archive. Do not interpret it as a booted/installed BFSOS validation or an approved ISO release.

### Source changes completed

- [x] `ports/core/util-linux/Pkgfile`: declare `libcap-ng` and `linux-pam` for the enabled `setpriv` / `runuser` capabilities. Preserve the intended util-linux features.
- [x] `bootstrap.sh`: put `libcap-ng` in the Stage-2/3 `basepkg` **before the final util-linux**, without adding it to the temporary Stage-1 library-only toolchain. Keep bootstrap comments outside the quoted package list.
- [x] `scripts/bfs-port-updater.py`: recognize `core/sqlite` + **actual** `compat-32/sqlite3-32` as a matching upstream version family. The 32-bit port is named `sqlite3-32`, not `sqlite-32`. Add the SQLite-specific upstream exception to MLFS book authority. A verified same-version change is presented as a REVIEW pair (rather than auto-publishing without validated release artifacts), and the existing `_version` archive conversion remains unchanged.
- [x] `scripts/bfs-port-updater.py`: recognize eight actually present GStreamer release-train packages: `opt/gstreamer`, `compat-32/gstreamer-32`, `opt/gst-plugins-base`, `compat-32/gst-plugins-base-32`, `opt/gst-plugins-good`, `opt/gst-plugins-bad`, `opt/gst-plugins-ugly`, and `opt/gst-libav`. Coordinate matching common upstream versions in dependency order, including review/partial-selection safety. Preserve separate versions/flags for packages outside this explicit family.
- [x] Selection UI: make default-selection calculation tolerate an incomplete candidate object (missing `reason`/`policy`), fixing the existing r438 synthetic picker regression.
- [x] `scripts/tests/test-r451-maintenance-policies.py`: add offline assertions for util-linux dependency declaration and stage order, six PAM configuration sources, Nautilus lifecycle and fdk-aac URL, SQLite/GStreamer family membership/order, and refusal of partial SQLite selection.

### Verified from the uploaded snapshot — do not reintroduce old fixes

- [x] `ports/core/linux-pam/Pkgfile` is already at **1.7.3-3** and includes the fixed continued `for file` loop with the `runuser` configuration. **No PAM recipe edit needed** in this pass. The r451 regression checks source structure, not installed authentication or actual archive payload.
- [x] `ports/gnome/nautilus/Pkgfile` is already **51.1** with the dangerous live-system `post_build` removed; the separate `post-install` compiles schemas.
- [x] `ports/opt/fdk-aac/Pkgfile` already uses a `.tar.gz`-ending SourceForge archive URL rather than `/download`.
- [x] SQLite mismatch in uploaded source confirmed: core/sqlite **3.53.4**; compat-32/sqlite3-32 **3.54.0**. This checkpoint does **not** automatically bump core/sqlite before actual archive verification; updater family guard will require a corresponding candidate.

### Tests completed in extracted offline project

- `bash -n bootstrap.sh`: PASS
- `python3 -m py_compile scripts/bfs-port-updater.py`: PASS
- `scripts/tests/test-r451-maintenance-policies.py`: PASS
- Existing r394, r396, r397, r400, r404, r405, r406, r415, r419, r423, r437, r438, and r441 Python regression files: PASS

### Still open / VM or broader source work required

- [ ] r443: audit the `libcap-ng` port's current `opt/` collection membership vs early bootstrap port registration, run a **clean Stage-2 bootstrap**, confirm library/build ordering and produce/test a new base archive. Audit qemu/spice-gtk/cifs-utils dependency declarations based on actual build/configure/link evidence. A manifest edit does not prove a clean bootstrap.
- [ ] r445: investigate actual old kernel/initramfs/GRUB/module ownership and safe retention; no automatic deletion introduced without tested rollback policy.
- [ ] r446: reproduce Firefox taskbar icons and KDE Discover launch failure on real Plasma session; no guessed desktop environment fix.
- [ ] r447–r448: complete Expat MLFS authority and compat-32 pairing diagnostics and reproduce the failed batch with live logs; no unverified 2.9.0 Pkgfile update.
- [ ] r449: obtain authoritative upstream SQLite release verification, test both builds and all dependents, and ensure discovery never drops core/sqlite. r451 adds policy/coordination but **does not independently fetch or verify a release**.
- [ ] r450: confirm actual upstream GStreamer common release across each package, source availability and 32-bit plugin function; r451 adds group membership/guards/order but not isolated transaction/rollback or live `gst-inspect-1.0` checks.
- [ ] Remaining earlier open tracker items not listed here still require separate implementation/verification. Avoid marking the overall tracker complete.

**Next release gate:** run clean bootstrap/base/ISO and installed-VM regression sequence; verify linux-pam shared configuration files, util-linux `runuser` and `setpriv`, SQLite ABI and both architectures, GStreamer plugin loading, kernel rollback and complete `sysup` before publishing 0.9.1.2.


---

## r452 — Bootstrap must not enforce pre-existing package `.footprint` or `.signature` metadata

**Live report:** during fresh bootstrap after tracking generated ports metadata, the build follows `.footprint` and `.signature` files from the development/installed repository. This incorrectly constrains a fresh bootstrap against artifacts produced by other builds.

**Policy:** for Bootstrap stages 1, 2 and 3, ignore package footprint and package signature metadata from ports even when these files are tracked in Git. Do **not** delete or alter tracked metadata. Continue to honor source `.md5sum` validation unless the maintainer explicitly disables checksums. Do **not** globally disable normal installed-system package verification; the installed config remains independently controlled by integrity settings.

### Changes implemented against r451
- [x] Stage 1 already builds using `pkgmk -d -is -if` (left intact).
- [x] Stage 2 bootstrap-generated pkgmk configuration now sets `PKGMK_IGNORE_SIGNATURE=yes` and `PKGMK_IGNORE_FOOTPRINT=yes` regardless of development verification settings.
- [x] Stage 2 and Stage 3 `pkgin` build invocations explicitly pass `-is -if`; retain optional `-im` only when source checksum verification is disabled.
- [x] The installed system `/etc/pkgmk.conf` integrity settings block is unchanged, so ordinary installs/builds can still enforce their configured policy.
- [x] `bash -n bootstrap.sh` passes; source-level assertions cover bootstrap stage configuration and both package-build invocation paths.
- [ ] Validate with a clean bootstrap containing stale/tracked `.footprint` and `.signature` files, including a deliberately mismatching footprint; confirm build succeeds without bypassing source checksum failures.
- [ ] Validate installed-system package verification policy remains enabled after bootstrap and ordinary `pkgmk` continues to honor user security settings.

**Security distinction:** skipping package *metadata comparison* in bootstrap is not the same as verifying upstream source authenticity. Source checksum verification remains on by default, and normal installed-system signature verification is not weakened by this change.


---

# r453 — Uninstalled ports inventory and Plasma installation audit
Date: 2026-10-13
Source: `BFSOS-not-installed.txt`, collected on the maintainer's current BFSOS installation.
Status: OPEN — inventory only; no ports removed or package installations performed.

## Tracker item A: Audit all 213 apparently uninstalled ports

**Observation:** Comparing the ports-tree directory names with `pkginfo -i` yielded 213 paths not recorded as installed. This is a snapshot of one machine, **not** evidence that the ports are obsolete, that they fail to build, or that a normal BFSOS installation must include them. The original comparison used directory names rather than the `name=` values inside Pkgfiles; normalize actual package names before drawing conclusions.

**Tasks:**
- [ ] Re-run the inventory using evaluated Pkgfile `name=` metadata (safely; no arbitrary sourcing of untrusted Pkgfiles), check aliases/renames and verify installed package names.
- [ ] Cross-reference *each* listed port against required/optional dependencies, base/bootstrap manifests, desktop metapackages, ISO/live manifests, installer choices, reverse dependencies, and compatibility/runtime uses.
- [ ] Classify each port: required but missing; optional and maintained; build-only dependency; target-specific (e.g., 32-bit, NVIDIA, LXQt, alternate init or ISO); obsolete/unmaintained; or unresolved.
- [ ] Distinguish missing local installation from missing `.footprint` or an actual package build failure.
- [ ] Check upstream support, active consumers, source availability, and license/architecture constraints before proposing retirement.
- [ ] For retirement candidates, provide explicit rationale and dependency impact; do **not** delete ports automatically. Review and approve individually.
- [ ] Produce a per-port audit table (port, actual package name, installed?, classification, reverse deps, selected profiles, upstream status, proposed action, reason).
- [ ] Run static checks and a clean-VM profile installation smoke test for any proposed manifest or metapackage changes.

**Inventory count by collection:**

| Collection | Count |
|---|---:|
| `compat-32` | 48 |
| `contrib` | 9 |
| `core` | 7 |
| `gnome` | 10 |
| `iso` | 2 |
| `lxqt` | 37 |
| `office` | 1 |
| `opt` | 78 |
| `plasma` | 18 |
| `xfce` | 1 |
| `xorg` | 2 |

| **Total** | **213** |

**Original list (verbatim paths, grouped here as one inventory):**

```text
compat-32/cdparanoia-32
compat-32/db-32
compat-32/glew-32
compat-32/icu-32
compat-32/imlib2-32
compat-32/jq-32
compat-32/libappindicator-gtk2-32
compat-32/libappindicator-sharp-32
compat-32/libcaca-32
compat-32/libcanberra-32
compat-32/libdbusmenu-glib-32
compat-32/libdbusmenu-gtk2-32
compat-32/libgudev-32
compat-32/libidn133-32
compat-32/libidn-32
compat-32/libindicator-gtk2-32
compat-32/libjpeg6-turbo-32
compat-32/libmng-32
compat-32/libnewt-32
compat-32/libnl-32
compat-32/libpng12-32
compat-32/libsamplerate-32
compat-32/libtiff4-32
compat-32/libtirpc-32
compat-32/libtool-32
compat-32/libudev0-shim-32
compat-32/libvdpau-32
compat-32/libwebp-32
compat-32/libxkbfile-32
compat-32/libXmu-32
compat-32/libXt-32
compat-32/libXv-32
compat-32/libXvMC-32
compat-32/mesa-demos-32
compat-32/nvidia-32
compat-32/nvidia-fb-32
compat-32/openldap-32
compat-32/openssl11-32
compat-32/popt-32
compat-32/python-32
compat-32/robin-hood-hashing-32
compat-32/rtmpdump-32
compat-32/slang-32
compat-32/speexdsp-32
compat-32/volk-32
compat-32/vulkan-tools-32
compat-32/vulkan-utility-libraries-32
compat-32/vulkan-validation-layers-32
contrib/alacritty
contrib/asciidoc
contrib/brother-hll8250cdn-cupswrapper
contrib/brother-hll8250cdn-lpr
contrib/gcc-fortran
contrib/libappindicator-gtk2
contrib/libdbusmenu-glib
contrib/libdbusmenu-gtk2
contrib/openblas
core/dash
core/gptfdisk
core/libnsl
core/mpdecimal
core/python3-pycparser
core/python3-pyxdg
core/stripping
gnome/eog
gnome/gnome-apps-meta
gnome/gnome-meta
gnome/gnome-screenshot
gnome/grilo
gnome/libpeas
gnome/libwnck2
gnome/metacity
gnome/telepathy-glib
gnome/uchardet
iso/lynx-iso
iso/networkmanager-iso
lxqt/libdbusmenu-lxqt
lxqt/libfm-extra
lxqt/libfm-qt
lxqt/liblxqt
lxqt/libqtxdg
lxqt/libsysstat
lxqt/lximage-qt
lxqt/lxqt-about
lxqt/lxqt-admin
lxqt/lxqt-archiver
lxqt/lxqt-build-tools
lxqt/lxqt-config
lxqt/lxqt-globalkeys
lxqt/lxqt-menu-data
lxqt/lxqt-meta
lxqt/lxqt-notificationd
lxqt/lxqt-openssh-askpass
lxqt/lxqt-panel
lxqt/lxqt-policykit
lxqt/lxqt-powermanagement
lxqt/lxqt-qtplugin
lxqt/lxqt-runner
lxqt/lxqt-session
lxqt/lxqt-sudo
lxqt/lxqt-themes
lxqt/lxqt-wayland-session
lxqt/menu-cache
lxqt/muparser
lxqt/obconf-qt
lxqt/pavucontrol-qt
lxqt/pcmanfm-qt
lxqt/qps
lxqt/qterminal
lxqt/qtermwidget
lxqt/qtxdg-tools
lxqt/screengrab
lxqt/xdg-desktop-portal-lxqt
office/libreoffice-bin
opt/alsa-tools
opt/appstream-glib
opt/argyllcms
opt/aspell6-en
opt/atkmm
opt/cairomm-1.0
opt/c-ares
opt/cdparanoia
opt/chrony
opt/consolekit
opt/cups-filters
opt/dejagnu
opt/dhcpcd
opt/directx-headers
opt/eudev
opt/fftw
opt/fltk
opt/ftjam
opt/gdb
opt/ghostscript
opt/glibmm
opt/glibmm-2.4
opt/gparted
opt/grantlee
opt/gtkmm3
opt/gutenprint
opt/imlib2
opt/isl
opt/jq
opt/kColorPicker
opt/kImageAnnotator
opt/labwc
opt/lapack
opt/libcupsfilters
opt/libglade
opt/libliftoff
opt/libmusicbrainz5
opt/libpaper
opt/libppd
opt/libsigc++2
opt/libstatgrab
opt/libtracefs
opt/mingw-ccache-bindings
opt/mobile-broadband-provider-info
opt/mupdf
opt/net-tools
opt/nvidia
opt/oniguruma
opt/openbox
opt/oxygen-icons5
opt/pangomm
opt/potrace
opt/pth
opt/pybind11
opt/qpdf
opt/qtwebengine5
opt/robin-hood-hashing
opt/scons
opt/seatd
opt/serf
opt/sgml-common
opt/smartmontools
opt/snapper
opt/strace
opt/subversion
opt/swaylock
opt/swig
opt/sysklogd
opt/syslinux
opt/texlive
opt/volk
opt/vulkan-tools
opt/vulkan-utility-libraries
opt/vulkan-validation-layers
opt/webp-pixbuf-loader
opt/wgetpaste
opt/wlroots
opt/xdotool
plasma/kactivities
plasma/kactivities-stats
plasma/kdelibs4support
plasma/kdesignerplugin
plasma/kdewebkit
plasma/kemoticons
plasma/khtml
plasma/kinit
plasma/kjs
plasma/kjsembed
plasma/kmediaplayer
plasma/kross
plasma/kwayland-integration
plasma/kxmlrpcclient
plasma/libdbusmenu-qt5
plasma/oxygen
plasma/oxygen-icons
plasma/polkit-qt5
xfce/xfce4-meta
xorg/libvdpau-va-gl
xorg/xclip
```

## Tracker item B: Plasma-specific missing-package and dependency audit

**Observation:** 18 ports in the `plasma/` collection appear in the uninstalled inventory. Some names resemble older KDE Frameworks 5 / KDE 4 compatibility components; that **does not establish** that they are required for current Plasma or that they are safe to delete.

**Affected port paths:**

```text
plasma/kactivities
plasma/kactivities-stats
plasma/kdelibs4support
plasma/kdesignerplugin
plasma/kdewebkit
plasma/kemoticons
plasma/khtml
plasma/kinit
plasma/kjs
plasma/kjsembed
plasma/kmediaplayer
plasma/kross
plasma/kwayland-integration
plasma/kxmlrpcclient
plasma/libdbusmenu-qt5
plasma/oxygen
plasma/oxygen-icons
plasma/polkit-qt5
```

**Tasks:**
- [ ] Confirm the installed Plasma version, KDE Frameworks version(s), Qt 5/6 packages, X11/Wayland sessions, and exact `plasma-meta` / KDE metapackage dependencies.
- [ ] Verify which of the 18 packages are expected in a standard BFSOS Plasma installation versus optional legacy/framework/third-party compatibility support.
- [ ] Find missing dependencies by inspecting Pkgfiles and **reverse** dependencies, not just absence from `pkginfo -i`.
- [ ] Check `plasma/kactivities` and `plasma/kactivities-stats` carefully against current activities/session support.
- [ ] Review `plasma/kwayland-integration`, `plasma/polkit-qt5`, `plasma/libdbusmenu-qt5`, and the Oxygen packages for actual Qt-version consumers.
- [ ] Check legacy ports (`kdelibs4support`, `kdewebkit`, `khtml`, `kjs`, `kjsembed`, etc.) for remaining required applications before proposing removal.
- [ ] Check Plasma X11 and Wayland login sessions; test Activities, settings, menus, notifications, policy prompts, icons/themes, and affected KDE applications on a fresh VM.
- [ ] Fix only demonstrated missing metapackage dependencies; do not make every `plasma/` port mandatory.
- [ ] Record a per-port disposition and tests; leave undecided packages in the tree.

**Safety / release gate:** Neither item is a release-blocking failure simply because a package was not installed on one workstation. Escalate only proven gaps in the intended base, desktop, or ISO profiles. Treat package removal as a separate explicitly approved change.

---

# r454 — ISO builder and installer unprivileged pkgmk/chroot audit (OPEN)

## Reproduced ISO failure, 2026-10-13

The base archive `bfs-rootfs-0.9.1.1-20261013.tar.zst` was accepted and the ISO builder passed preflight/static audit, but failed at its first in-root package update:

```text
[BFSOS ISO] Updating pkgutils before system upgrade
prt-get: updating /usr/ports/core/pkgutils
BFSOS pkgmk: building from pkgmk-owned staging copy; original=/usr/ports/core/pkgutils
pkgmk: cannot create package source cache '/var/cache/pkg/sources/pkgutils'
[BFSOS ISO] ERROR: Failed to update pkgutils in ISO root
```

Confirmed from `scripts/bfs-build-iso.sh`:
- `build_iso_package_set()` installs a Git-sourced ports tree into `$root/usr/ports` (lines ~625–627), then enters a chroot and runs `ports -u`, `prt-get update pkgutils` (~640–644), and `prt-get sysup` (~651–655).
- The script extracts the validated base archive into `$WORK_DIR/live-root` (~1368–1374).
- Cache directory creation is visible much later in the final ISO staging path (~1225), **after** the failing updates; that is not sufficient for package builds in the chroot.
- Host-side `chown` of `/var/cache/pkg` does not repair permissions **inside** `$WORK_DIR/live-root`.
- Root cause is strongly consistent with missing/unwritable pkgmk cache inside the chroot, but confirm numeric uid/gid and path ownership before applying a fix. We have not yet verified that the installer shares the same fault.

### Required changes

- [ ] Inspect ISO root `pkgmk` account (`/etc/passwd`, `/etc/group`, uid/gid), cache directory ownership/modes, source-cache config, and whether directories survive base extraction.
- [ ] Ensure a trusted root-owned setup step runs **after extracting the base archive and before the first in-root `prt-get` command**; initialize only the intended package-cache roots (`sources`, `packages`, `build-work`), using the chroot `pkgmk` UID/GID, not assumed host IDs.
- [ ] Ensure namespace subdirectories such as `sources/pkgutils` are creatable by the unprivileged builder, and that wrapper staging locations are writable. Avoid recursive `chown` of massive preserved build-work trees; repair targeted paths or initialize clean directories safely.
- [ ] Audit `bfs-pkgmk` and `pkgmk.conf` for source, build, output, and staging directory policy; verify wrapper privilege drop and root-only package installation boundaries.
- [ ] Run the in-root `pkgutils` update, `sysup`, and remaining ISO package installation in a clean test root. Preserve log output and fail with targeted diagnostics rather than dumping thousands of chown errors.
- [ ] Inspect installer package installs/builds and any target-root/chroot equivalent; confirm correct account creation and cache initialization before first `prt-get`/`bfs-pkgmk` use. Do not assume installer uses pkgmk without inspecting its code.
- [ ] Check first boot/post-install package upgrades in the installed target, not only live ISO build.
- [ ] Add isolated regression tests for bad cache ownership, absent source namespace, numeric account mismatch, and no host-cache permission mutations.
- [ ] Verify live ISO boot, installer run, installed-system package update in VM. Do not claim release-ready without these runtime tests.

## Separate ISO audit policy follow-up

- [ ] `bfs-ports-static-audit.sh` pinned Firefox `157.0.1`, Firefox ESR `153.4.0esr`, and XScreenSaver `6.16` while the updated tree had `158.0`, `153.5.0esr`, and `6.17`. Refactor structural validation away from arbitrary fixed release versions, retaining true lock-group checks (e.g., coordinated Firefox source/binary channels when intended) and security checks such as XScreenSaver bsod configuration.
- [ ] Review other hardcoded version assertions (LXQt, Avahi, xdg-dbus-proxy, etc.) to prevent unrelated port upgrades from blocking ISO assembly.

**Status:** Diagnostic evidence recorded; implementation pending inspection of current project archive and fresh installer/ISO source. Successful base build is retained; avoid unnecessary bootstrap rebuild.


---

# r455 — ISO and installer pkgmk cache setup (SOURCE PATCH COMPLETE; VM VALIDATION OPEN)

Changes staged against the user-supplied ISO debug project snapshot (no modifications made to the running host):

- [x] ISO: Add `prepare_iso_pkgmk_cache` before `ports -u` and `prt-get update pkgutils` in `build_iso_package_set()`.
- [x] ISO: Resolve the package builder numeric UID and GID from **inside the extracted live root**, rather than assuming the host account IDs.
- [x] ISO: Provision `sources`, `packages`, `build-work`, `build-work-disk`, and ccache in the isolated root; verify write access with `runuser -u pkgmk`. Correct any existing `sources/pkgutils` namespace without recursively chowning large build-work trees.
- [x] ISO: Include the cache helper in the `sudo bash -c` exported function set.
- [x] Installer: Move existing `ensure_pkgmk_build_ownership` execution ahead of the first installer package synchronization, upgrade, or dependency install; preserve later build backend/integrity setup.
- [x] Installer: Stop recursively chowning potentially gigantic cache trees; check that the `pkgmk` account can write the cache roots, and fail diagnostically if an existing `sources/pkgutils` namespace cannot be written.
- [x] Add `scripts/tests/test-r455-iso-installer-pkgmk-cache.py` covering source-level ordering, numeric account policy, scope, and unprivileged write probes.
- [x] Pass syntax and source-policy tests: `bash -n` (ISO and installer), r455 test, `test-iso-builder-source.sh`, `test-r438-installer-updater.py`, `test-r321-iso-installer-policy.sh`, `test-r311-installer-runtime-policy.sh`, `test-installer-build-work-sizing.sh`, and `test-r313-live-download-policy.sh`.
- [ ] **VM/live test required:** rerun ISO `prt-get update pkgutils`, `sysup`, package installation, ISO boot, installer and first installed-system upgrade. No ISO was assembled in this sandbox.
- [ ] If a preserved source namespace other than pkgutils is owned by root, handle it with narrowly scoped repair on a case-by-case basis; don't recursively chown the whole build cache.
- [ ] Investigate unrelated `test-r321-lts-default-and-port-cleanup.sh` failure: the supplied ports tree contains several historical `Pkgfile.before-*` / `.bak` copies. Those have not been removed by this patch.
- [ ] Broader release audit hardcoded version baseline cleanup remains open; this patch does not change unrelated version assertions.

**Deployment:** Apply this patch to the development checkout only, review and commit, push to GitHub, then run the ISO-test builder (which fetches the GitHub source). No base archive or user system cache is included or changed.


---

## r456 — ISO live root must not require runuser during pkgmk cache preflight (2026-10-13)

Live ISO failure after r455: `chroot: failed to run command '/usr/bin/runuser': No such file or directory`, followed by misleading `ISO root pkgmk cannot write /var/cache/pkg/sources`. The base archive was verified and both static audits passed.

- [x] Replace the ISO cache preflight's chroot-internal `runuser` call with host GNU `chroot --userspec=UID:GID` running `/usr/bin/test -w` within the isolated root.
- [x] Preserve UID/GID lookup from the isolated root and the cache ownership preparation.
- [x] Update the r455 regression contract and add explicit r456 missing-runuser regression.
- [ ] Live rerun of the ISO package upgrade from the existing 0.9.1.1 base.
- [ ] Verify whether the actual `bfs-pkgmk` wrapper requires a missing chroot binary during package builds; do not assume the preflight fix proves all package builds work.
- [ ] End-to-end ISO boot and installer VM smoke test.


---

## LOW PRIORITY — investigate persistent `revdep` reports for `libreoffice` and `systemd` (2026-10-13)

**Status:** OPEN — diagnostic follow-up only; no urgent rebuild or release blocker.

### Observation

Latest live-host check after rebuilding/reinstalling affected packages:

```text
$ sudo revdep
libreoffice
systemd
```

- `systemd` has repeatedly appeared in `revdep` and is regarded as a known false positive on this installation; it was rebuilt once after the recent PAM changes. Do not force recurring systemd rebuilds merely to clear the report.
- `libreoffice` still appears in `revdep` after reinstall/rebuild; the specific library or file causing the report has not yet been identified. This is separate from the already-fixed LibreOffice launcher/desktop integration issue.
- `expect` was separately corrected and verified; it no longer appears in the latest `revdep` output.

### Deferred investigation

- Capture verbose `revdep` findings or inspect the script to identify the exact ELF object and unresolved SONAME for each reported package.
- Check whether the affected object is used at runtime or is a helper, plugin, optional feature, stale file, or false-positive detection.
- For real missing libraries, correct dependencies, ABI links, or package contents in their respective ports; for confirmed false positives, improve `revdep` detection or document targeted exclusions with regression coverage.
- Rerun `sudo revdep` after the specific cause is addressed. Do **not** repeatedly rebuild large packages or core components without a diagnosed missing dependency.


---

## r457 — Uniform construction-time footprint bypass (2026-10-14)

**Status:** SOURCE PATCHED / STATIC REGRESSIONS PASS; full BFSOS chroot/ISO/installer VM tests OPEN.

**Problem:** Packages legitimately change contents between bootstrap passes, including GLib built before and after GObject Introspection. Stale tracked `.footprint` files must not terminate bootstrap, ISO creation, or installer package transactions. Source checksums and normal installed-system footprint policy are separate concerns.

### Implemented against the supplied 2026-10-14 snapshot

- [x] `bootstrap.sh`: Stage-2 temporary pkgmk configuration forces `PKGMK_IGNORE_SIGNATURE=yes` and `PKGMK_IGNORE_FOOTPRINT=yes`, independent of final installed-system settings. Stage-2/3 `pkgin` invocations explicitly use `-is -if`; source MD5 checking still follows the user's independent choice. Stage-1 already used `-is -if`. The finalized `/etc/pkgmk.conf` retains its user-selected integrity policy.
- [x] `scripts/bfs-build-iso.sh`: new `set_iso_build_footprint_policy` applies `PKGMK_IGNORE_FOOTPRINT=yes` **inside the isolated ISO root** before its first package update, reapplies it after upgrading pkgutils, and checks it again after the full sysup. It does not disable MD5 source checking or change the host.
- [x] `scripts/install-bfs-menu-current.sh`: early construction settings now always bypass footprint comparisons, independent of the final target verification choice. Normal chosen installed-system policy is restored by the existing final `configure_pkgmk_integrity_settings` call. The installer upgrades pkgutils before the broader package transaction when `quickdiff` identifies it, then reapplies temporary settings so pkgutils cannot silently reset them mid-build.
- [x] Installer no longer deletes `opt/glib/.footprint` to make the GLib/Introspection/GLib build cycle pass. Leave tracked metadata untouched and validate final required GIR files.
- [x] Added `scripts/tests/test-r457-build-footprint-policy.py`, verifying source-level ordering, bypass scope, and continued final-system/source-checksum policy.
- [x] `bash -n` for three modified shell scripts; r455, r456, r457, r438, r441, and r451 regression scripts pass in the supplied project.

### Still to verify on BFSOS hardware / VM

- [ ] Rerun the ISO builder using the existing verified 0.9.1.1 base archive; do **not** regenerate it merely to resolve footprint comparisons.
- [ ] Check `prt-get` and the actual `bfs-pkgmk` wrapper honor the temporary `/etc/pkgmk.conf` setting in every isolated upgrade, including GLib's first and final build. Verify final GIR and typelib payload.
- [ ] Exercise the installer on a VM with footprint verification selected ON and a stale intermediate GLib `.footprint`; all construction package operations must succeed, while final target `/etc/pkgmk.conf` restores `PKGMK_IGNORE_FOOTPRINT=no`.
- [ ] Verify installed-system normal `pkgmk` still rejects deliberate footprint mismatches, and malformed source checksum metadata still fails during construction.
- [ ] Test installer error recovery/checkpoint resumes: ensure early bypass remains active during retried builds and final verification policy is restored after successful final configuration.

**Scope:** This is a targeted implementation of the already-tracked r452 construction policy across all three environments, **not** a claim that the entire historical tracker is complete. The low-priority `revdep` investigation remains in this single master tracker; no new separate tracker branch.
