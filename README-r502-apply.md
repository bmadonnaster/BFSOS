# BFSOS r502 targeted source overlay

Applies on top of BFSOS r501 (the uploaded 2026-10-22 tree).

From the directory containing `BFSOS/`:

```sh
tar --zstd -xvf BFSOS-r502-fakeroot-cpio-overlay.tar.zst
cd BFSOS
python3 scripts/tests/test-r502-cpio-fakeroot.py
python3 scripts/tests/test-r500-iso-deps.py
```

Inspect and commit specifically the modified `ports/opt/cpio/Pkgfile`, new
r502 test, new audit, and r502 tracker. Do not assume an ISO boot or package
ownership test was executed in this environment.

The present fix opts cpio into the **existing** BFSOS split-build API. The
broader r501 fakeroot queue issue is not marked complete.
