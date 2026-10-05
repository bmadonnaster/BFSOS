# BFSOS Fix Tracker r377 — 0.9.0

## Port updater: keep Gucharmap Unicode data sources in sync

### Problem

During the GNOME update audit, `gnome/gucharmap` was updated from the previous release to:

```text
gucharmap 18.0.0
```

The updater correctly changed the main Gucharmap source version, but the same Pkgfile still contained hard-coded Unicode Character Database sources for Unicode 17.0.0:

```text
https://www.unicode.org/Public/17.0.0/ucd/UCD.zip
https://www.unicode.org/Public/17.0.0/ucd/Unihan.zip
```

This caused the Gucharmap 18.0.0 build to fail while generating its Unicode tables:

```text
./ucd contains unicode data for version 17.0.0 but version 18.0.0 is required
```

### Required updater behavior

Add a coordinated-source rule for `gnome/gucharmap`.

When the updater changes the Gucharmap version, it must also inspect and update the Unicode data URLs in the same Pkgfile so that the UCD and Unihan data match the Unicode version required by the selected Gucharmap release.

For Gucharmap 18.0.0 the sources must become:

```text
https://www.unicode.org/Public/18.0.0/ucd/UCD.zip
https://www.unicode.org/Public/18.0.0/ucd/Unihan.zip
```

The updater should preserve the existing BFSOS `renames` behavior:

```bash
renames=(SKIP UCD.zipx Unihan.zipx)
```

### Safety requirements

- Do not update only the main Gucharmap tarball while leaving the UCD/Unihan URLs at an older Unicode version.
- Treat the Gucharmap source version and its Unicode UCD/Unihan source version as a coordinated update.
- If the expected Unicode data version cannot be determined safely, mark the candidate for REVIEW rather than guessing.
- Preserve all unrelated BFSOS-local Pkgfile changes.
- Continue using the normal build verification path after applying the coordinated update.

### Regression test

Use a Pkgfile containing:

```text
version=18.0.0
https://www.unicode.org/Public/17.0.0/ucd/UCD.zip
https://www.unicode.org/Public/17.0.0/ucd/Unihan.zip
```

The updater should rewrite both Unicode URLs to `18.0.0`.

Then verify the port with:

```bash
cd ~/BFSOS/ports/gnome/gucharmap
sudo pkgmk -d -kw
```

The build must no longer fail with the Unicode 17.0.0 versus 18.0.0 mismatch.

## Status

- [ ] Add Gucharmap coordinated Unicode source handling to `scripts/bfs-port-updater.py`.
- [ ] Ensure both `UCD.zip` and `Unihan.zip` move together.
- [ ] Add a conservative REVIEW fallback when a matching Unicode version cannot be established.
- [ ] Test with the Gucharmap 18.0.0 update case.

---

## Port updater: GNOME source path handling

### Problem

`gnome/gnome-backgrounds` was updated to `51.0.1`, but the updater/source rewrite produced:

```text
https://download.gnome.org/sources/gnome-backgrounds/51.0/gnome-backgrounds-51.0.1.tar.xz
```

The resulting download returned HTTP 404.

This shows that the updater cannot assume every GNOME package uses `${version%.*}` as its source-directory component. Some GNOME source trees use a different directory convention.

### Required updater behavior

- Preserve a working package-specific GNOME source-directory pattern when one already exists.
- Do not blindly derive every GNOME source directory from `${version%.*}`.
- Before committing an automatic source rewrite, verify that the constructed source URL exists.
- If a safe source-directory transformation cannot be determined, mark the candidate `REVIEW` instead of writing a broken URL.
- Keep package-specific source-layout rules data-driven where practical so other GNOME exceptions can be added without special-case spaghetti.

### Regression test

Use `gnome-backgrounds 51.0.1` as a regression case.

The updater must not leave a source URL that returns 404.

## Port updater: refresh checksum metadata after source-version changes

### Problem

`gnome/webkitgtk-41` was updated from `2.54.0` to `2.54.1`, but the old checksum metadata remained:

```text
MISSING   webkitgtk-2.54.0.tar.xz
NEW       webkitgtk-2.54.1.tar.xz
```

The port therefore failed before compilation with an md5sum mismatch.

### Required updater behavior

When an automatic update changes source filenames or source versions:

- refresh the package checksum metadata as part of the update workflow;
- remove stale checksum entries for source files that no longer exist;
- generate checksum entries for the new source files;
- preserve intentional `SKIP` entries and BFSOS-local source handling;
- do not report the update as ready for build until checksum metadata matches the rewritten `source=()` array.

### Regression test

Update a port whose main source changes from:

```text
webkitgtk-2.54.0.tar.xz
```

to:

```text
webkitgtk-2.54.1.tar.xz
```

The resulting checksum metadata must reference only the new source filename.

## Port updater: version-specific patch review on package updates

### Problem

`gnome/brasero` was proposed for update from `3.12.3` to `3.12.4`.

The existing BFSOS port includes:

```text
brasero-3.12.3-upstream_fixes-1.patch
```

A version-specific patch must not be silently carried into a different upstream release without checking whether it is still required and applicable.

The updater currently returned:

```text
FAILED/REVIEW
```

for this port, which is safer than blindly updating, but the patch transition needs explicit logic.

### Required updater behavior

When a package update changes the version and the Pkgfile references a version-specific patch:

- inspect whether the authoritative source provides a replacement patch;
- determine whether the old patch is already incorporated upstream;
- stage replacement patches when authoritative metadata provides them;
- keep the old patch until the new port has successfully built;
- never blindly rewrite a patch filename to the new package version;
- if patch applicability cannot be established safely, mark the package `REVIEW`.

Use `gnome/brasero 3.12.3 -> 3.12.4` as the regression case.

## Port updater UI: no-update scans must return to the main menu

### Problem

When a selected port tree or the kernel-maintenance path contains no candidate updates, the interactive updater exits completely.

This is incorrect for the Dialog UI. A completed scan with zero updates is not an exit request.

### Required behavior

For interactive use:

1. Scan the selected tree(s) or kernel path.
2. If zero candidates are found, show a message such as:

```text
No candidate updates were found.
```

3. After the user acknowledges the message, return to the main updater menu.
4. Do not terminate the updater unless the user explicitly chooses Exit/Cancel from the appropriate menu.

This applies to:
- selected individual port trees;
- multi-tree scans;
- kernel/kernel-header maintenance;
- any future scan mode using the same interactive main loop.

Noninteractive/report-only modes may still exit normally after printing their result.

## Port updater retry queue: clear stale resolved failures without losing new failures

### Problem to investigate

The Retry Failed Updates menu previously contained stale failures that had already been repaired manually outside the updater.

After the latest GNOME run, the retry screen is also showing newly failed updates. That means the retry mechanism may be partly correct now, but stale-state cleanup still needs to be verified.

We should not assume the retry feature is still entirely broken or entirely fixed.

### Required behavior

The retry queue must represent the current retryable state, not an indefinite accumulation of historical failures.

- Newly failed updates must appear in Retry Failed Updates.
- A package that subsequently builds successfully through the updater must be removed from the retry queue.
- A package repaired manually outside the updater should not remain forever as a stale retry item once the updater can establish that the recorded failure is no longer current.
- Entries whose Pkgfile/version has changed since the recorded failure must be revalidated before retry.
- Do not silently retry an old failure against a different package version or different source state.
- Keep enough history in logs for auditing, but separate historical failure records from the active retry queue.
- If an old entry cannot be safely classified as current or stale, show it as `REVIEW` rather than automatically retrying it.

### Suggested implementation direction

Use a distinct active retry-state file or derive retryable entries from the latest applicable scan/build state rather than treating every historical `BUILD FAILED` result as permanently active.

An active retry record should include enough identity to detect stale state, for example:

```text
port
version
release
Pkgfile fingerprint or mtime/hash
failure timestamp
failure result
```

Before presenting a retry item, compare the current port state to the recorded state.

### Regression tests

- Create a real current build failure: it must appear in Retry Failed Updates.
- Fix and successfully rebuild it through the updater: it must disappear.
- Record a failure, then manually change/fix the Pkgfile outside the updater: the old entry must be revalidated and not blindly treated as current.
- Generate a new failure after stale entries exist: the new failure must still appear.
- Historical logs must remain available even after an item leaves the active retry queue.

## r376 status

- [ ] Keep r375 Gucharmap coordinated Unicode-data fix.
- [ ] Fix GNOME source-directory/path rewriting and URL validation.
- [ ] Refresh checksum metadata when source filenames or versions change.
- [ ] Add safe handling for version-specific patches such as Brasero.
- [ ] Return to the main menu after interactive scans with zero candidates.
- [ ] Audit Retry Failed Updates state handling.
- [ ] Remove/revalidate stale resolved retry entries without dropping genuine new failures.
- [ ] Add regression tests for all r376 cases above.

---

## Port updater: Core tree must scan non-LFS packages too

### Suspected bug

The `core` tree appears to be showing updates only for packages that are represented in the LFS/MLFS/BLFS/GLFS books.

Packages in `core` that do not map to an LFS-family book may be getting skipped entirely instead of falling through to the secondary version sources.

That would make the Core audit incomplete and could explain why some available updates are not appearing.

### Required source policy

The updater must apply the source-priority policy to **every BFSOS port**, not only packages found in an LFS-family book.

For each port:

1. If the port is explicitly mapped to MLFS/LFS/BLFS/GLFS, use the mapped authoritative book version according to BFSOS policy.
2. If the port is not mapped to an LFS-family authoritative source, continue scanning rather than dropping it.
3. Fall through to:
   - CRUX reference;
   - Arch reference;
   - direct upstream discovery.
4. Apply the existing no-downgrade rule:
   - authoritative/reference version newer than BFSOS → candidate;
   - equal → ignore;
   - older than BFSOS → ignore completely.
5. Direct-upstream-only results should remain conservative and may be marked `REVIEW` when there is no trusted distro/book reference.

### Core-specific regression test

Run the updater against `ports/core` and divide the tree into two groups:

```text
A. Ports explicitly mapped to an LFS-family source
B. Ports with no LFS-family mapping
```

Verify that both groups are evaluated.

For group B, confirm that the updater attempts the fallback chain rather than silently omitting the port.

The scan report should make the chosen source visible, for example:

```text
core/foo    ...    CRUX reference
core/bar    ...    Arch reference
core/baz    ...    upstream / REVIEW
```

### Diagnostic requirement

Add enough scan logging to distinguish:

```text
LFS-mapped
not LFS-mapped; checking CRUX
not found in CRUX; checking Arch
not found in Arch; checking upstream
no newer version found
```

This will make it obvious whether a package was actually checked or merely skipped.

### Scope

Although this was noticed while testing `core`, the rule must be global across all BFSOS trees. No tree should require an LFS-family mapping in order to participate in version discovery.

## r377 status addition

- [ ] Audit `core` for ports omitted because they have no LFS-family mapping.
- [ ] Ensure unmapped Core ports fall through CRUX → Arch → upstream.
- [ ] Apply the same fallback behavior globally to every BFSOS port tree.
- [ ] Add scan logging that proves which source chain was attempted for each unmapped port.
- [ ] Add regression coverage for mapped and unmapped Core packages.

