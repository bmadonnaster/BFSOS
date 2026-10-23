# BFSOS r511 — pkgutils/sudo scoped fakeroot remediation (offline source pass)

## Scope and incident

The VM's sudo 1.9.17p2-1 package archive contained eight entries rather than the expected full payload.  In the uploaded VM chroot build log, upstream sudo `make install` attempted root ownership changes as uid pkgmk, failed with `Operation not permitted`, and the classic one-function Pkgfile proceeded to later successful commands.  With `-if`, the incomplete archive was published.  The unprivileged build should remain unprivileged; the *staging* operation needs a bounded fakeroot context.

## Changed source

* `core/pkgutils` 5.40.12-49: apply `bfs-pkgmk-stage-safety.patch.txt` after the existing r505 split and universal patches.  For classic recipes, a scoped Bash `make()` interceptor uses external `make` without fakeroot for ordinary compilation and invokes `timeout ... fakeroot -- make ... install` for recognized installation targets.  This handles upstream install-time ownership changes without moving configure/compilation back under fakeroot.  Timeout defaults to 1800 seconds (`BFS_PKG_STAGE_TIMEOUT`, in seconds).  The archive-only fakeroot phase remains intact for consistent tar ownership.
* Fix `if ! (set -e; build)` error suppression: execute build() as a standalone command under `set -e` and inspect the resulting status.  Apply the same control-flow fix to the explicit split compilation path.
* Validate required staged sudo executables, sudoers and `usr/bin/sudo` mode 4755 before archive creation, including when `-if` is passed; also require `usr/bin/rsync` for rsync.
* `core/sudo` 1.9.17p2-2: explicit `|| return 1` chaining for configure, compile and DESTDIR install.  This is defense in depth for the known reproducer, not a claim that every Pkgfile is now fully checked.
* New offline regression test.  Update the older r505 static test for the actual `.patch.txt` file name and r511 version.

## Tests performed here

* Supplied source archive SHA-256 verified.
* Both r505 patches applied to the upstream pkgutils `pkgmk.in` baseline, followed by the new r511 patch, with no rejects; patched pkgmk passes `bash -n`.
* `bash -n` for both edited Pkgfiles and bfs-pkgmk wrapper.
* r504, r505, r511 offline source tests passed.
* Scoped fakeroot mock `make install` ran outside the packaging engine using a Makefile that performed `chown 0:0` and `chmod 4755` on a staged executable; staged executable was present with mode 4755.

## Not yet demonstrated; release blocker remains

* The actual sudo source has **not** been rebuilt in a BFSOS VM with pkgutils 5.40.12-49.  Treat this as a candidate remedy, not a verified fix.
* Arbitrary legacy one-function Pkgfiles may stage via `ninja install`, `meson install`, `cmake --install`, `install -o`, custom helper functions or subprocesses, which are **not** automatically intercepted by the `make()` shim.  A generic, universally complete privilege-phase solution for these cases remains open.  Some `make install` targets may perform compile steps as prerequisites; verify those stay short under fakeroot.  Other command wrappers would require separate implementation and careful tests.
* Existing wrapper archive failure cleanup may delete a same-name previously good archive; atomic publication/rollback is still outstanding.  Avoid production deployment until resolved.
* Installer use of `-if` and root/admin-access validation (r508) are still open; this candidate validates sudo/rsync essentials but is not a generic payload/footprint guarantee.
* Re-run fakeroot IPC deadlock/cpio, wget2, rsync, package modes/ownership/symlinks, all installer profiles, and full UEFI VM boot.  Check package archive contents before `pkgadd` and keep broken artifacts for comparison.

## Suggested safe VM validation sequence

1. On bare metal, build/install the revised `pkgutils` in a **test VM**, checking pkgutils package contents and version. Never copy the new pkgmk onto production without a package-build test.
2. In a live-ISO chroot, preserve the broken eight-entry sudo archive and its logs; rebuild with `bfs-pkgmk -f -kw -if` without installing. Require mode 4755 for `usr/bin/sudo` and a complete expected archive footprint, not simply a successful exit code.
3. Test a deliberate make-install failure and verify exit nonzero and no new package publication; then test `prt-get` and finally a fresh ISO install.

No live host, VM or chroot was changed in this offline task.
