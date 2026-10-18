# BFSOS r493 delivery and validation report

## What was reviewed

- Verified supplied archive checksum and extracted full BFSOS tree.
- Read separate r492 tracker and consolidated r480 historical tracker (5,466 lines; 384 unchecked tasks), as well as affected actual Pkgfiles and updater/source wrapper implementations.
- Implemented the bounded source changes itemized below and preserved the historical trackers.

## Actual modified files

1. `ports/office/libreoffice-bin/Pkgfile` — libarchive/bsdtar in place of missing rpm2cpio, release 2, extraction safety checks.
2. `ports/opt/fastfetch/Pkgfile` — image logo ON, dependencies, release 2.
3. `ports/core/bash/Pkgfile` — compile system `/etc/bashrc` support, release 2.
4. `ports/core/pkgutils/bfs-pkgmk` — nonrecursive per-port source cache ownership repair, only when root.
5. `ports/core/pkgutils/Pkgfile` — release 47.
6. `scripts/bfs-maintained-port-updater.py` — always reset release to 1 on changed version, even with stale requested_release.
7. `scripts/tests/test-r493-targeted-fixes.py` — new offline checks.
8. `docs/BFSOS-fix-tracker-r493-20261016.md` — cumulative r492 plus implementation status.

## Test evidence

- archive `sha256sum -c`: PASS
- `bash -n` changed shell files/Pkgfiles: PASS
- `python -m py_compile scripts/bfs-maintained-port-updater.py`: PASS
- `python scripts/tests/test-r493-targeted-fixes.py`: PASS
- `python scripts/tests/test-r470-fastfetch.py`: PASS
- `bash scripts/tests/test-r436-office-printer.sh`: PASS

## Outstanding work — not silently skipped or called finished

The r492 tracker contains twelve current issue/enhancement categories; only five received source changes above, and none were host/VM tested. Legacy r480 has hundreds of open checkboxes accumulated across earlier project stages, many including duplicate or already partial themes. Work cannot honestly be marked complete without physical builds and boot tests. The latest tracker preserves those tasks with explicit pending status; do not use this archive as a fully validated release.

Priority on BFSOS VM/host: (1) validate LibreOffice RPM contents and metadata; (2) compile/test Bash global startup and Fastfetch image support; (3) root/nonroot pkgmk cache regression; (4) kernel-aware footprint/boot migration VM test; (5) provider-specific scan and Plasma audit; (6) remaining historical backlog.
