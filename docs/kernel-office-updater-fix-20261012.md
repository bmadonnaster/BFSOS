# BFSOS kernel and office updater fixes — 2026-10-12

## Kernel source/version regression

- `linux` is now an automatically selectable UPDATE, not a review-only candidate. It remains optional at installation time.
- The maintained-port updater does not apply provider source URL handoffs to `linux`, `linux-lts`, or `linux-headers`. These ports use a version-driven kernel.org tarball; a provider URL describing the old release must never replace that template.
- Before committing a kernel update, validate that the evaluated primary kernel tarball filename matches `linux-${version}.tar.xz`.
- Before launching a kernel build, the updater verifies the Pkgfile's evaluated source/version and resets an existing kernel-specific pkgmk workspace to prevent reuse of stale extracted source trees. After a failed build, `-kw` still retains the failed workspace for inspection until another update attempt begins.
- In apply-and-build mode, `linux-lts` builds before `linux-headers` when both are selected; failed LTS validation prevents the header build and the header port rolls back.
- The glibc release bump in apply-and-build mode waits for a successful linux-headers build. Apply-only mode continues to bump glibc when header metadata is changed; this is a metadata-only operation and is not a successful system rebuild.
- The static audit no longer pins rapidly changing kernel point releases to obsolete revision-specific versions; it requires version-driven source URLs instead.

## Office tree

- `ports/core/prt-get/prt-get.conf` already includes `/usr/ports/office` and the installer already synchronizes `ports/office`.
- `pkgutils` uses the same native build policy for office as for other non-compat-32 collections; no pkgutils source change was necessary.
- Expanded the r436 office integration test and added an updater/source policy regression test.
- The CRUX reference lookup's `core,opt,xorg,compat-32,contrib` list is a list of **remote CRUX collections**, not local BFSOS collections. It was deliberately not changed to add `office`, which CRUX does not expose as an equivalent upstream collection.

## Validation / limitations

Python compilation and local updater regression tests passed. No kernel source builds or installs were performed here. Validate both kernel builds on BFSOS, and inspect `prt-get`'s installed `/etc/prt-get.conf` (package metadata in the repository cannot prove the live host config was upgraded).
