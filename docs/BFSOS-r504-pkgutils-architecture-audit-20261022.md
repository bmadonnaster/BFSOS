# BFSOS r504 — package-build privilege architecture audit

## Verified from uploaded r503 snapshot

* SHA256 of uploaded archive matched its supplied checksum.
* 1,373 Pkgfiles, only **one** has `bfs_build_phases=split`. The normal wrapper runs `runuser -u pkgmk ... fakeroot -- pkgmk "$@"`. Thus compilation occurs as uid `pkgmk` but with fakeroot's `LD_PRELOAD`/IPC machinery around the whole build, precisely the prohibited behavior.
* Split-build branch invokes `pkgmk` unwrapped but requires `pkg_compile()` and `pkg_stage()`, which does not solve compatibility for normal one-function `pkg_build()` ports.
* r503 is OPEN, and the reported `wget2` queue deadlock is consistent with the legacy branch.
* The upstream source of pkgutils 5.40.12 (`pkgmk.in`) is NOT included in the uploaded tarball. It is downloaded during a normal port build. Project's patches refer to its functions, but an archive ownership rewrite must be checked against its real current contents. We did not invent or apply an unsafe root-ownership rewrite.

## Required next engineering pass

1. Obtain the actual pkgutils source archive (or capture the patched generated `/usr/bin/pkgmk` from BFSOS) to inspect `build_package`, footprint and tar/archive creation. Add a general unprivileged normal build path while preserving conventional `pkg_build()` recipes.
2. Preserve correct root uid/gid, owner names and modes for archives WITHOUT wrapping configure/make in fakeroot. Validate archive ownership normalization with `bsdtar -tvf` and `pkginfo --footprint`; do not simply remove fakeroot while shipping packages owned by `pkgmk`.
3. Ensure setuid bits, symlinks, hardlinks, special payloads, package signatures, worktree ownership, -kw, post hooks, and failure propagation remain safe. Never run arbitrary Pkgfiles as real root.
4. Update pkgutils release and ensure ISO build actually upgrades its copy before building further packages; installed target gets correct wrapper, too.
5. Run `python3 scripts/tests/test-r504-build-privilege-policy.py`. Its FAIL is intentional until the global change and live acceptance checks are done.
6. Exercise installer cpio/wget2, ordinary pkgmk, sudo pkgmk, prt-get, bootstrap, and updater; verify no blocked SysV queues or `faked` processes, then complete clean UEFI VM install/reboot.

## Result

**r503: not fixed.** This audit and a fail-closed release-gate test are implemented. Historical tracker entries remain open as previously recorded. No live VM/system verification performed.
