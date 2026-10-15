#!/usr/bin/env python3
"""Offline regression for r484 pkgutils kernel migration preparation."""
import importlib.util
import os
from pathlib import Path
import sys
import tempfile
from unittest.mock import patch

SRC = Path(__file__).resolve().parents[2] / 'ports/core/bfs-kernel-maintenance/bfs-kernel-migrate.py'
for flavor, old, ver, suffix, new_name in [
    ('lts', 'linux-lts', '6.18.56-1', 'BFS-LTS', 'linux'),
    ('mainline', 'linux', '7.2.10-1', 'BFS-Linux', 'linux-mainline'),
]:
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        db = root/'var/lib/pkg/db'
        db.parent.mkdir(parents=True)
        # pkgutils uses name, version, file list; a blank line closes record.
        db.write_bytes(f'other\n1-1\netc/other\n\n{old}\n{ver}\nboot/\nboot/vmlinuz-lts\nlib/\n\n'.encode())
        kver = ver.rsplit('-', 1)[0] + '-' + suffix
        image = root/'boot'/('vmlinuz-' + kver)
        image.parent.mkdir(parents=True)
        image.write_bytes(b'kernel')
        (root/'lib/modules'/kver).mkdir(parents=True)
        flavorfile = root/'etc/bfsos/kernel-flavor'
        flavorfile.parent.mkdir(parents=True)
        flavorfile.write_text(old + '\n')
        state = root/'var/lib/bfsos/kernel-state'/old
        state.mkdir(parents=True)
        (state/'pending').write_text(kver+'\n')
        env = dict(os.environ, BFS_MIGRATION_DB=str(db), BFS_MIGRATION_ROOT=str(root))
        spec = importlib.util.spec_from_file_location('migrate', SRC)
        with patch.dict(os.environ, env):
            mod = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(mod)
            with patch.object(sys, 'argv', ['migrate', 'prepare', flavor, '--yes']), \
                 patch.object(mod.os, 'geteuid', return_value=0), \
                 patch.object(mod.os, 'uname', return_value=type('U', (), {'release': kver})()):
                mod.main()
        after = db.read_text()
        assert (new_name == 'linux' and 'linux-lts\n6.18.56-1\n' in after and 'boot/vmlinuz-lts\n' not in after) or (new_name == 'linux-mainline' and 'linux-legacy-mainline\n7.2.10-1\n' in after)
        assert image.exists()
        assert flavorfile.read_text().strip() == new_name
        assert (root/f'var/lib/bfsos/kernel-migrations/ready-{new_name}').is_file()
        assert list((root/'var/lib/bfsos/kernel-migrations/backups').glob('*/db'))
        if flavor == 'mainline':
            assert (root/'var/lib/bfsos/kernel-state/linux-legacy-mainline/pending').is_file()
print('r484 kernel migration mock database regression: PASS')
