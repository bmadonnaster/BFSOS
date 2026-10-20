#!/usr/bin/env python3
"""Offline: vendor runfile and routine footprint safety/acceptance regressions."""
import importlib.util
import sys
from pathlib import Path
root = Path(__file__).resolve().parents[2]
def load(name, filename):
    sp = importlib.util.spec_from_file_location(name, root/'scripts'/filename)
    module = importlib.util.module_from_spec(sp)
    sys.modules[name] = module
    sp.loader.exec_module(module)
    return module
m = load('bfs_maintained_r495', 'bfs-maintained-port-updater.py')
u = load('bfs_updater_r495', 'bfs-port-updater.py')
url = 'https://download.nvidia.com/XFree86/Linux-x86_64/615.78.08/NVIDIA-Linux-x86_64-615.78.08.run'
for rel in ('opt/nvidia', 'compat-32/nvidia-32'):
    content = (root/'ports'/rel/'Pkgfile').read_text()
    before = m.eval_meta(root/'ports'/rel/'Pkgfile')
    rewritten = m.rewrite_primary_source_from_handoff(content, before, '615.78.08', url)
    assert rewritten == content  # version-driven template remains intact
    assert '615.78.08.run' not in rewritten  # version-dynamic token preserved
    assert 'NVIDIA-Linux-x86_64-$version.run' in rewritten
assert m.is_archive_name('NVIDIA-Linux-x86_64-615.78.08.run')

def fp(*entries):
    return '=======> ERROR: Footprint mismatch found:\n'+'\n'.join(entries)+'\n=======> ERROR: Building failed\n'
vim=fp('NEW -rw-r--r-- root/root usr/share/vim/vim92/syntax/icalendar.vim')
assert u.safe_routine_footprint_change(vim)[0]
lib=fp('MISSING lrwxrwxrwx root/root usr/lib32/libXrender.so -> libXrender.so.1.3.0',
       'NEW lrwxrwxrwx root/root usr/lib32/libXrender.so -> libXrender.so.1')
assert u.safe_routine_footprint_change(lib)[0]
unit=fp('NEW -rw-r--r-- root/root usr/lib/systemd/system/clonesetup.target',
        'NEW lrwxrwxrwx root/root usr/lib/systemd/system/initrd.target.wants/systemd-cryptenroll-firstboot.service -> ../systemd-cryptenroll-firstboot.service')
assert u.safe_routine_footprint_change(unit)[0]
for danger in (
    'NEW -rwsr-xr-x root/root usr/bin/suid',
    'NEW -rwxrwxrwx root/root usr/bin/worldwrite',
    'NEW -rw-r--r-- somebody/root usr/share/a',
    'NEW -rw-r--r-- root/root ../../etc/shadow',
    'NEW lrwxrwxrwx root/root usr/lib/escape -> ../../../../etc/shadow',
    'NEW -rw-r--r-- root/root etc/sudoers.d/evil',
    'CHANGED -rw-r--r-- root/root usr/bin/thing',
    'NEW crw------- root/root dev/null',
):
    assert not u.safe_routine_footprint_change(fp(danger))[0], danger
print('r495 NVIDIA/footprint offline tests: PASS')
