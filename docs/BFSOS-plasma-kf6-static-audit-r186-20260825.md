# BFSOS Plasma/KF6 Static Audit — r186 — 2026-08-25

This report records changes made from the supplied whole-project snapshot. It distinguishes static metadata/recipe repairs from runtime validation that must still happen inside BFSOS.

## Implemented in this pass

- Added hard ECM ordering across affected KF6 6.26 Framework recipes.
- Added a Qt-for-Python 6.11.2 system port (`pyside6`) providing the Shiboken/PySide source stack against BFSOS Qt 6.11.2 and system LLVM/libclang.
- Re-enabled KCoreAddons Python bindings and declared the new dependency in KCoreAddons/KGuiAddons.
- Split Qt6 WebEngine from the base Qt6 recipe; added `qt6-webengine` and restored KHelpCenter WebEngine support.
- Corrected broken dependency names in Plasma metadata: `polkit-qt-1`, `docbook-xsl-nons`, `xf86-input-*`, `sentry_sdk`, `pulseaudio-qt`, `kdecoration`, and `kdeplasma-addons`; removed stale `krb5` from plasma-integration.
- Replaced KMix's obsolete KF5 meta dependency with direct KF6/Qt6 dependencies.
- Removed KTextTemplate's self-dependency.
- Removed `--retry-all-errors` from pkgmk curl policy so permanent HTTP failures such as 404 do not get the same retry treatment as transient transport failures.
- Removed bash-completion profile ownership from `aaa_filesystem`.

## Current upstream alignment finding

The snapshot is internally centered on KDE Frameworks 6.26.0, Plasma 6.6.5 and KDE Gear 26.04.1. Current releases on 2026-08-25 are Frameworks 6.29.0, Plasma 6.7.4 and Gear 26.08.0. Those family updates should be coordinated and runtime-tested rather than applied as a blind global version substitution.

## Known unresolved dependency providers

- `kaccounts-integration`: BFSOS still lacks `libaccounts-qt` and `signond` (and the complete SignOn integration path must be audited).
- `plasma-default-apps`: BFSOS still lacks `kio-extras`; the dependency is valid and the missing port should be created rather than removed.
- Qt5 WebEngine remains monolithic; the r179/r180 split is only implemented for Qt6 so far.
- Legacy KF5 compatibility recipes in `ports/plasma` still need classification before removal or modernization.

## Runtime test order

1. Rebuild/install `pkgutils`, verify 404 failover behavior and normal transient retry/resume behavior.
2. Rebuild `aaa_filesystem` and install `bash-completion`; verify clean ownership transfer.
3. Build/install `qt6` without WebEngine and verify ordinary Qt/QML consumers.
4. Build/install `qt6-webengine`; verify Qt6WebEngine CMake metadata and KHelpCenter.
5. Build/install `pyside6`; verify `Shiboken6Config.cmake`, generator tooling and PySide modules.
6. Rebuild KCoreAddons and KGuiAddons with bindings enabled.
7. Add/test the remaining KAccounts and KIO Extras providers.
8. On a clean package state, run the intended Plasma dependency install and then boot/test Plasma Wayland plus the supported X11/XWayland path.
