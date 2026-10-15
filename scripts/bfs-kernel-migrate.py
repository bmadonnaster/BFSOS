#!/usr/bin/env python3
"""Prepare an installed BFSOS legacy kernel for side-by-side r484 installation.

This edits only pkgutils ownership metadata after taking recoverable backups.
It does not install packages or remove boot artifacts. Only run with no active
pkgutils transaction and with a verified offline VM disk backup.
"""
import argparse
import fcntl
import os
from pathlib import Path
import re
import shutil
import sys
import time

DB = Path(os.environ.get('BFS_MIGRATION_DB', '/var/lib/pkg/db'))
ROOT = Path(os.environ.get('BFS_MIGRATION_ROOT', '/'))

def path(p):
    return ROOT / p.lstrip('/')

def records(data, name):
    # pkgutils records start with standalone name and version-release lines.
    # Restrict matches to true header pairs, not kernel-file names.
    pattern = rb'(?m)(?<![^\n])' + re.escape(name.encode()) + rb'\n([0-9][^\n ]*-[0-9]+)\n'
    return list(re.finditer(pattern, data))

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('action', choices=['status', 'prepare'])
    ap.add_argument('flavor', choices=['lts', 'mainline'])
    ap.add_argument('--yes', action='store_true', help='Explicitly authorize a package database change')
    args = ap.parse_args()
    if args.action == 'prepare' and (os.geteuid() != 0 or not args.yes):
        ap.error('prepare requires root and --yes')
    old = 'linux-lts' if args.flavor == 'lts' else 'linux'
    legacy = 'linux-lts' if args.flavor == 'lts' else 'linux-legacy-mainline'
    target = 'linux' if args.flavor == 'lts' else 'linux-mainline'
    release_suffix = '-BFS-LTS' if args.flavor == 'lts' else '-BFS-Linux'
    marker = path(f'/var/lib/bfsos/kernel-migrations/ready-{target}')
    if not DB.is_file():
        raise SystemExit('pkgutils database missing')
    with open(DB, 'rb') as fh:
        fcntl.flock(fh.fileno(), fcntl.LOCK_EX)
        original = fh.read()
        hits = records(original, old)
        dest_hits = records(original, target)
        if args.flavor == 'lts':
            if len(hits) != 1 or not hits[0].group(1).startswith(b'6.'):
                raise SystemExit('Expected exactly one installed 6.x linux-lts package; refusing')
            if dest_hits:
                raise SystemExit('Package linux already installed; investigate mainline identity first')
        else:
            if len(hits) != 1 or not re.match(rb'7\.', hits[0].group(1)):
                raise SystemExit('Expected exactly one installed legacy 7.x linux; refusing')
            if records(original, legacy) or dest_hits:
                raise SystemExit('Target or legacy migration package already exists; refusing')
        running = os.uname().release
        old_image = path('/boot/vmlinuz-' + running)
        if args.action == 'prepare':
            if not running.endswith(release_suffix):
                raise SystemExit(f'Running {running}, expected legacy {release_suffix}; boot the kernel being migrated first')
            if not old_image.is_file() or not path('/lib/modules/' + running).is_dir():
                raise SystemExit('Running kernel image or module tree missing; refusing')
        print(f'{old} {hits[0].group(1).decode()} -> {target}; running kernel {running}')
        if args.action == 'status':
            print('Prepared:', marker.exists())
            return
        if marker.exists():
            raise SystemExit('Existing prepared migration marker; inspect before attempting again')
        stamp = time.strftime('%Y%m%d-%H%M%S')
        backup = path(f'/var/lib/bfsos/kernel-migrations/backups/{args.flavor}-{stamp}')
        if backup.exists():
            raise SystemExit('Backup destination exists')
        # Validate all destinations before any package database mutation.
        if args.flavor == 'mainline':
            for item in ('kernel-state', 'kernel-rollback'):
                if path(f'/var/lib/bfsos/{item}/linux-legacy-mainline').exists():
                    raise SystemExit(f'Legacy mainline {item} already exists; refusing')
        backup.mkdir(parents=True, mode=0o700)
        shutil.copy2(DB, backup / 'db')
        for rel in ['/etc/bfsos/kernel-flavor', f'/var/lib/bfsos/kernel-state/{old}']:
            src = path(rel)
            if src.exists():
                dst = backup / rel.lstrip('/')
                dst.parent.mkdir(parents=True, exist_ok=True)
                if src.is_dir():
                    shutil.copytree(src, dst, symlinks=True)
                else:
                    shutil.copy2(src, dst)
        # Only mutate ownership for the LTS shared alias. Other path overlaps
        # must be reviewed, not hidden with pkgadd's force/conflict options.
        updated = original
        if args.flavor == 'lts':
            # Exact ownership entry, once; leave the real symlink intact.
            entry = b'boot/vmlinuz-lts\n'
            if original.count(entry) != 1:
                raise SystemExit('Shared boot/vmlinuz-lts ownership not unique; refusing')
            updated = original.replace(entry, b'', 1)
        else:
            # Identity is freed so 6.x LTS can subsequently use `linux`.
            match = hits[0]
            updated = original[:match.start()] + legacy.encode() + original[match.start()+len(old):]
        tmp = DB.with_name('.db.bfsos-migrate-tmp-' + str(os.getpid()))
        try:
            with open(tmp, 'xb') as output:
                output.write(updated)
                output.flush()
                os.fsync(output.fileno())
            os.chmod(tmp, DB.stat().st_mode & 0o777)
            os.replace(tmp, DB)
        finally:
            tmp.unlink(missing_ok=True)
        # Archive old pending/rollback state *without* deleting existing state.
        # The newly named flavor starts with clean pending state so its first
        # boot can be verified independently of the old kernel's state.
        if args.flavor == 'mainline':
            old_state = path('/var/lib/bfsos/kernel-state/linux')
            dest_state = path('/var/lib/bfsos/kernel-state/linux-legacy-mainline')
            if old_state.exists():
                if dest_state.exists():
                    raise SystemExit('Legacy mainline state already exists; inspect backup')
                old_state.rename(dest_state)
            old_rollback = path('/var/lib/bfsos/kernel-rollback/linux')
            dest_rollback = path('/var/lib/bfsos/kernel-rollback/linux-legacy-mainline')
            if old_rollback.exists() and not dest_rollback.exists():
                old_rollback.rename(dest_rollback)
        # Select the new package flavor; no versioned boot artifact is touched.
        flavor_file = path('/etc/bfsos/kernel-flavor')
        if flavor_file.exists():
            current = flavor_file.read_text().strip()
            allowed = ('linux-lts', 'linux') if args.flavor == 'lts' else ('linux', 'linux-mainline')
            if current in allowed:
                temp_flavor = flavor_file.with_name('.kernel-flavor.bfs-migrate-' + str(os.getpid()))
                temp_flavor.write_text(target + '\n')
                os.replace(temp_flavor, flavor_file)
        marker.parent.mkdir(parents=True, exist_ok=True)
        marker.write_text(f'legacy={legacy}\nnew={target}\nbackup={backup}\nrunning={running}\n')
        print('PREPARED. Original kernel untouched. Backup:', backup)
        print('Next: review pkginfo -i, then install the newly built package through pkgadd/prt-get.')

if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError) as exc:
        sys.exit(f'Migration stopped: {exc}')
