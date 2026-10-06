#!/usr/bin/env python3
from pathlib import Path
import importlib.util
ROOT=Path(__file__).resolve().parents[2]
check=(ROOT/'scripts/checkupdate.py').read_text()
up=(ROOT/'scripts/bfs-port-updater.py').read_text()
assert 'github_published_release' in check
assert 'sqlite_release_page' in check and '3530400' not in check  # decoded generically
assert 'npm_registry' in check
assert 'sourceforge_files' in check
assert 'pinned Berkeley DB 5.3 compatibility ABI' in check
assert '--retry-all-errors' in check and '--connect-timeout", "8"' in check
assert 'pkgmk_footprint_package_command' in up and '"-if"' in up and '"-uf"' in up
assert 'cleanup_successful_build_work' in up and 'BUILD-WORK CLEANUP' in up
exp=(ROOT/'ports/compat-32/expat-32/Pkgfile').read_text()
hb=(ROOT/'ports/compat-32/harfbuzz-32/Pkgfile').read_text()
assert 'version=2.8.5' in exp
assert 'version=14.5.1' in hb
print('PASS')
