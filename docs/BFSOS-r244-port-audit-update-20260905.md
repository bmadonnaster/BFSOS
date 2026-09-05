# BFSOS r244 port-audit update — 2026-09-05

Applied from the maintained-port version audit:

- lxqt/libfm-extra: 1.3.2 -> 1.4.1, release reset to 1.
- lxqt/menu-cache: 1.1.0 -> 1.1.1, release reset to 1.
- plasma/polkit-qt5: 0.114.0 -> 0.201.1, release reset to 1.
  The build now explicitly sets QT_MAJOR_VERSION=5 because polkit-qt 0.201.x
  supports both Qt 5 and Qt 6.
- opt/gtk remains 2.24.33.  The checker was fixed to lock GTK2 to the 2.24
  release series so 2.90.x development releases are not reported as updates.
- Added a regression test for the observed 2.24.33 -> 2.90.7 false positive.
- Version-audit/checkupdate banners normalized to v8.

Source checksum files should be regenerated with `pkgmk -d -um` for the three
updated ports before committing if pkgmk is available in the active build
environment.
