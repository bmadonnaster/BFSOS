# BFSOS r441 — updater crash and pkgmk metadata fixes

## Confirmed crash

`run(["pkginfo", "-i"])` did not capture output, but code read `installed.stdout.splitlines()`. This raises `AttributeError` after a successful build. Both the main auto-install path and the retry-install path now pass `capture=True`. Unexpected Python errors are also saved to `logs/update/crash-YYYYMMDD-HHMMSS-PID.log`.

## Metadata handling

When root invokes `bfs-pkgmk` from a developer-owned port directory that user `pkgmk` cannot write, the wrapper stages a copy of that one port beneath `/var/cache/pkg/build-work-disk`, builds as `pkgmk`, and returns generated `.md5sum`, `.footprint`, and `.signature` files to the original port directory, using its UID/GID. Failed metadata synchronization returns a nonzero status. `/usr/ports` directories already writable by `pkgmk` continue to build in place.

No changes to group membership, developer checkout ownership, or root privileges for `pkgmk`.

## Apply

Extract the archive into an empty temporary directory, then merge while logged in as the normal checkout owner:

```
cd ~
mkdir -p BFSOS-r441-temp
tar --zstd -xf ~/Downloads/BFSOS-r441-fixes.tar.zst -C ~/BFSOS-r441-temp
rsync -avh ~/BFSOS-r441-temp/BFSOS/ ~/BFSOS/
cd ~/BFSOS
python3 scripts/tests/test-r441-updater-wrapper.py
```

**The current /usr/bin/bfs-pkgmk binary/script is separate from the checkout**. To test the new wrapper with the updater before rebuilding/installing pkgutils, install the inspected revised script:

```
sudo cp -a /usr/bin/bfs-pkgmk /usr/bin/bfs-pkgmk.pre-r441
sudo install -m 755 ~/BFSOS/ports/core/pkgutils/bfs-pkgmk /usr/bin/bfs-pkgmk
```

Do not run the whole Plasma sweep to test this. The Attica 6.31.0 archive already exists and can be installed separately when you are ready. First check the traceback log from any failure. Do not use `sudo` to merge files into the developer checkout.

## Offline verification performed

- `python3 -m py_compile` for the updater
- `sh -n` for wrapper
- `scripts/tests/test-r441-updater-wrapper.py` passed

No live BFSOS build, root install, full upstream scan, or KDE desktop upgrade was executed here.
