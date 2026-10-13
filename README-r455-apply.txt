BFSOS r455 ISO + Installer cache-order source patch

Files replace the same relative paths in the project checkout.
Review with git diff, run: 
  bash -n scripts/bfs-build-iso.sh
  bash -n scripts/install-bfs-menu-current.sh
  python3 scripts/tests/test-r455-iso-installer-pkgmk-cache.py

This patch is NOT runtime validated on an ISO root or installer VM.
The base archive is not modified.
Do not extract over ~/iso-test/BFSOS first: the ISO builder fetches GitHub main.
Install/update files in ~/BFSOS, commit/push, then retry ISO builder.
