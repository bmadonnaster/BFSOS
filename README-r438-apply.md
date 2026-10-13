# BFSOS r438 — merge instructions

This source snapshot includes source-level fixes to the maintainer updater,
installer cache permissions, linux-pam runuser defaults, pkgutils root fallback,
prt-get Office registration, and KDE Frameworks dependency declarations.

## Safest merge

Use the changes-only archive to overlay your local ~/BFSOS checkout **after
inspecting differences**. No `.git` directory is included; your repository
history and user-owned files should remain yours. Make a commit/backup first.

```sh
cd ~
mkdir -p BFSOS-r438-review
# Substitute your download filename below:
tar --zstd -xf BFSOS-r438-changes-20261012.tar.zst -C BFSOS-r438-review
# Inspect differences before overlaying:
diff -ru ~/BFSOS/scripts/bfs-port-updater.py ~/BFSOS-r438-review/BFSOS/scripts/bfs-port-updater.py || true
# When satisfied:
rsync -avh --exclude='.git/' ~/BFSOS-r438-review/BFSOS/ ~/BFSOS/
```

Then run:

```sh
cd ~/BFSOS
python3 -m py_compile scripts/bfs-port-updater.py
python3 scripts/tests/test-r438-installer-updater.py
python3 scripts/tests/test-r413-tracker-fixes.py
bash -n scripts/install-bfs-menu-current.sh
sh -n ports/core/pkgutils/bfs-pkgmk ports/core/prt-get/post-install
```

No live packages were rebuilt or installed in the review container.
Check the revised tracker before deploying `linux-pam`, `pkgutils`, or `prt-get`,
especially on the running graphical workstation. Verify `/usr/ports` sync and
cache ownership separately. Auto-install ON changes installed live packages.
