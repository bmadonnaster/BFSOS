# BFSOS r517 pkgutils scoped ownership-stage audit

The previous universal-build patch compiled and ran `post_build` as uid pkgmk and invoked fakeroot later only to normalize archive ownership. That broke `core/pkgutils` because its post-build used explicit root and UID82 ownership, which unprivileged `install -o` cannot apply.

The r517 change eliminates privileged ownership operations in pkgutils' unprivileged `post_build`, explicitly restores directory modes, and defines an opt-in archive metadata hook. The existing archive-only fakeroot phase first maps the staged tree to root:root and then invokes any declared `bfs_archive_metadata` hook before archive packaging. pkgutils' hook maps its known UID82 cache/work directories and timing log. Direct-root pkgmk invokes that same function with real privileges. This avoids running compilation or the full post-build under fakeroot.

It does NOT solve arbitrary post_build ownership operations, privileged workspace recovery, signing delegation, multi-file metadata rollback, or UEFI/BIOS VM validation. Those stay open. The prior 51 archive remains preferable until the VM demonstrates a correct 52 build and ownership metadata.

Offline tests: r505, r511, r513, r515, r517 source tests PASS; Bash syntax PASS; universal patch hunks have internally consistent lengths. Upstream source was not rebuilt here; no footprint or archive was fabricated.
