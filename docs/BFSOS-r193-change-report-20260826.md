# BFSOS r193 change report — 2026-08-26

This pass consolidates the Bootstrap/runtime defects confirmed during the latest clean build and performs the requested coordinated KDE refresh before the next destructive reinstall regression.

## Implemented

- **CA trust transition:** `ca-certificates` release 5 now installs a real canonical `/etc/pki/tls/certs/ca-bundle.crt`; compatibility links remain under `/etc/ssl`; curl release 3 declares `ca-certificates openssl`; Bootstrap validates both the bundle and an HTTPS request at the transition point.
- **Exact failure log selection:** Bootstrap pins the actual active package log when a package closes nonzero, preventing the preceding successful package from being shown in the failure dialog.
- **ccache bootstrap ordering:** ccache release 2 no longer uses the premature standalone `post-install`; the package stages the shared cache directory and Bootstrap owns cache sizing/configuration. Both maintained `pkgin` helpers no longer execute port post-install scripts in the build-only phase.
- **Integrity controls:** Bootstrap and installer r67 expose independent MD5/checksum, signature, and footprint verification switches. All are enabled by default; disabled checks are explicitly logged as a development bypass. pkgutils release 25 ships secure defaults.
- **KDE refresh:** 148 Plasma-collection Pkgfiles/meta ports were moved to the current coordinated release families: 74 Frameworks 6.29.0, 57 Plasma 6.7.4, and 17 Gear 26.08.0. Source URLs were normalized to current KDE release locations; `bluedevil` malformed `ource=` was corrected; Konsole's release-service source was normalized; oxygen-icons was brought forward too; stale KF5-era K3b/KMix descriptions were corrected.
- **Tracker:** r193 records implementation status and leaves runtime-only regression work open.

## Static validation

- `bash -n` PASS: `bootstrap.sh`, installer r67, changed core Pkgfiles, and every Plasma Pkgfile.
- `sh -n` PASS: both `pkgin` helper copies.
- Plasma hard dependency closure against all BFSOS collections: **0 unresolved**.
- Current KDE URL-family pattern audit: **0 errors**.
- Old Plasma-tree version references `6.26.0`, `6.6.5`, `26.04.1`: **0**.
- Generated `.md5sum` / `.footprint` / `.signature` artifacts in supplied project tree: **0**.

## File delta

- Changed/new paths relative to supplied r192 project: **160** (includes this report).
- Removed paths: **2** (`ports/core/ca-certificates/post-install`, `ports/core/ccache/post-install`).

## Required next runtime regression

Run one clean Bootstrap 1 -> 2 -> 3 cycle without manual CA or ccache workarounds. Then build/install the refreshed KDE stack and validate PAM/logind user sessions, X11, Wayland, portals, KIO/default apps, PipeWire/WirePlumber/RTKit audio, and both system/user failed units.
