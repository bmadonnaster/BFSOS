BFSOS r505b correction
The r505 patch was accidentally named *.patch, triggering pkgmk automatic -p1 patching against the upstream pkgutils directory. It must instead be named *.patch.txt and explicitly applied in post_build with -p0 against $PKG/usr/bin/pkgmk.

Extract this overlay from ~/iso-test, delete the old ports/core/pkgutils/bfs-pkgmk-universal-build.patch, then retry building pkgutils. This correction fixes the earlier "can't find file to patch" error; it does not prove a successful package build or runtime functionality.
