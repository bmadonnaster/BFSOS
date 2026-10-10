# BFSOS updater logs — r435 audit

All counts represent results recorded in shipped scan TSVs, not current installed package status.

## scan-20261010-004322.tsv

Results: 0; 


## scan-20261010-004333.tsv

Results: 0; 


## scan-20261010-004637.tsv

Results: 73; NEEDS REVIEW: 73

KDE Frameworks bad source rewrites: 73


## scan-20261010-005530.tsv

Results: 5; no result: 1, NEEDS REVIEW: 1, BUILT: 2, BLOCKED: 1

- `compat-32/expat-32`: not selected
- `core/python3-gobject`: NEEDS REVIEW: Pkgfile evaluation failed (31): /tmp/bfs-update-python3-gobject-flglaukc/python3-gobject/Pkgfile
- `core/python3-pycparser`: BUILT
- `gnome/evolution`: BLOCKED: updated prerequisite built but not installed/staged: evolution-data-server
- `gnome/evolution-data-server`: BUILT

## scan-20261010-010739.tsv

Results: 2; no result: 1, NEEDS REVIEW: 1

- `compat-32/expat-32`: not selected
- `compat-32/nss-32`: NEEDS REVIEW: rewritten source URL is not reachable: https://archive.mozilla.org/pub/security/nss/releases/NSS_3_130_RTM/src/nss-3.131.tar.gz: curl: (22) The requested URL returned error: 404

## Important qualifications

- Historical scans and user-reported manual repairs may not match the archive’s current Pkgfiles.
- The archive contains no installed package database and no physical printer; live installation, CUPS and user hardware verification cannot be established here.
- `test-r423-updater-fixes.py` currently fails in its existing active-consumer test; left open for independent diagnosis.
