# BFSOS Fix Tracker r378 — 0.9.0

## r377 implementation pass

This pass implements the active r377 updater fixes and carries forward the outstanding coordinated port additions from the immediately preceding updater audit work.

### Implemented updater changes

- [x] Gucharmap coordinated Unicode source handling: when the Gucharmap version changes, `UCD.zip` and `Unihan.zip` are rewritten to the same Unicode version.
- [x] GNOME source-layout exception table added; `gnome-backgrounds` uses the GNOME major source directory (`51/` for `51.0.1`) rather than blindly using `${version%.*}`.
- [x] Changed remote archive URLs are probed before an automatic update is committed. A dead constructed URL becomes `NEEDS-REVIEW` instead of a broken Pkgfile.
- [x] Stale generated `.md5sum` / `.md5sums` files are invalidated when source filenames change so the next `pkgmk` build regenerates metadata instead of failing on `MISSING` / `NEW` source names.
- [x] Version-specific local patches are held as `REVIEW` when a version changes and no authoritative replacement patch is known; this covers the Brasero 3.12.3 -> 3.12.4 case conservatively.
- [x] Interactive scans with zero candidates now display a message and return to the main menu instead of closing the updater.
- [x] The interactive updater is now a persistent main-menu loop. Completed scans, cancelled submenus, and retry runs return to the main menu.
- [x] Retry state now records a Pkgfile SHA-256 fingerprint. Manual Pkgfile repairs invalidate stale failure records even if version/release did not change.
- [x] Retry discovery uses the newest state per port rather than resurrecting older historical failures.
- [x] Successful retry results are written as a newer scan-state record so the old failure drops out of the active retry menu while historical logs remain intact.
- [x] Non-LFS-mapped ports are no longer skipped. The fallback chain now runs independently of whether generic upstream discovery already returned `UPDATE`: CRUX -> Arch -> upstream.
- [x] Fallback candidates use the actual CRUX or Arch version that justified the candidate, rather than labeling a generic upstream version with a secondary distribution reference.
- [x] Scan logs now include source-chain trace comments showing whether a port was LFS-mapped or fell through CRUX / Arch / upstream.
- [x] GTK2 family guard added for `compat-32/gtk-32` so generic discovery cannot move that port onto GTK3.
- [x] Vulkan/SPIR-V coordinated version-lock group added across native and compat-32 members; partial SDK updates are held for review instead of producing a mixed stack.

### New ports / coordinated package work

- [x] Added `ports/opt/sdl3` at SDL 3.4.18.
- [x] Added `ports/compat-32/libsdl3-32` at SDL 3.4.18.
- [x] Updated native FAudio to 26.10 and changed its dependency from SDL2 to SDL3.
- [x] Changed `faudio-32` dependency from `libsdl2-32` to `libsdl3-32` for the FAudio 26.10 SDL3 transition.
- [x] Added missing native `ports/opt/vulkan-tools`, aligned with the current BFSOS Vulkan SDK generation (`1.4.357.0`) so it does not introduce a partial SDK bump.

### Regression coverage

Added `scripts/tests/test-r377-port-updater-fixes.py` covering:

- Gucharmap Unicode URL synchronization;
- `gnome-backgrounds` major-directory source rewriting;
- generated checksum invalidation;
- Core/unmapped CRUX fallback even without an upstream `UPDATE` row;
- retry fingerprint invalidation after a manual Pkgfile edit;
- GTK2/GTK3 family guard.

Also reran the existing r365 updater policy regression and Python syntax compilation successfully.

### Still requires BFSOS live build testing

- [ ] Build/install `opt/sdl3` on BFSOS.
- [ ] Build/install `compat-32/libsdl3-32` on BFSOS.
- [ ] Rebuild native `faudio 26.10` against SDL3.
- [ ] Rebuild `faudio-32 26.10` against `libsdl3-32`.
- [ ] Build native `vulkan-tools` against the current `1.4.357.0` Vulkan stack.
- [ ] Run an interactive no-update Core/kernel scan and verify it returns to the main menu on a real TTY.
- [ ] Exercise a current failed build, retry it successfully, and verify it disappears from the Retry menu.
- [ ] Run a full Core scan and inspect `# TRACE:` rows in the scan log to confirm non-LFS packages are being evaluated through the fallback chain.

Do not bump the installed Vulkan/SPIR-V stack to a newer SDK generation until the full native + compat-32 version-lock group is ready to move together.
