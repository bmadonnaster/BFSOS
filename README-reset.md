# BFSOS kernel updater regression test reset (2026-10-12)

Versions staged:
- core/linux: 7.2.9 (previous 7.2.10)
- core/linux-lts: 6.18.55 (already at 6.18.55; intentionally retained)
- core/linux-headers: 6.18.55 (previous 6.18.56)

Both LTS and headers now begin at the same version, so the next 6.18.56 update is an observable test. All three source URLs track the `version` variable; configuration, hooks and patches are unaffected.

## Apply to your BFSOS checkout

    cd ~/BFSOS
    tar --zstd -xf ~/Downloads/BFSOS-kernel-reset-test-20261012.tar.zst
    rm -f ports/core/linux/.md5sum ports/core/linux-lts/.md5sum ports/core/linux-headers/.md5sum

The .md5sum removal prevents old tarball hashes from contaminating the test; pkgmk may regenerate them according to your BFSOS policy. This package only supplies the three Pkgfiles; it does not change build products or the installed kernels.

Run updater discovery first, and check the planned versions and source URLs before building. Do not install test kernels until compilation and boot testing is satisfactory.
