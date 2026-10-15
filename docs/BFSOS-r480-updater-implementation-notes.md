# BFSOS r480 implementation and verification notes

## Changed code
- `scripts/bfs-port-updater.py`: protected kernel defaults, independently isolated blocked coordinated-family updates, single-port menu/CLI, selective upstream retry menu/CLI.
- `scripts/checkupdate.py`: X.Org request limits, longer timeouts, conditional TLS1.2 retry, read literal pkgmk.conf fallback arrays and check exact archive reachability via mirrors.
- `scripts/tests/test-r480-updater-resilience.py`: deterministic offline tests.

## Commands on your BFSOS checkout

After safely overlaying the patch archive onto the matching October 15 tree:

```sh
cd ~/BFSOS
python3 -m py_compile scripts/bfs-port-updater.py scripts/checkupdate.py
python3 scripts/tests/test-r480-updater-resilience.py
python3 scripts/tests/test-r440-update-selection.py
```

Single-port check, no writes:

```sh
python3 scripts/bfs-port-updater.py --port chromium --report-only
```

Selective retry against an existing report, no port changes:

```sh
python3 scripts/bfs-port-updater.py \
  --retry-problems logs/update/problems-20261015-104900.tsv \
  --include-unverifiable --report-only
```

For full interactive mode, run the updater normally; the main menu now contains
**Find and check a single port** and **Retry failed upstream checks from last report**.

## Limitations / pending validation
The current source archive excludes updater logs; these were uploaded separately.
This patch does not validate real downloads with a checksum; use pkgmk to download
and verify source archives. The fallback feature checks existence only.
Do not execute full live update/apply workflows without reviewing the selected
packages and a backup of the working tree. Unverified network conditions may
still yield FETCH-ERROR or UNVERIFIABLE.
