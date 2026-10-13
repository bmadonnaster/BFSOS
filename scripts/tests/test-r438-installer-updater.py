#!/usr/bin/env python3
"""Focused regression of the October 12 maintainer-workflow repairs."""
from pathlib import Path
import importlib.util
import sys
import tempfile
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('bfs_updater_r438', ROOT/'scripts/bfs-port-updater.py')
u = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = u
spec.loader.exec_module(u)

# pkgmk build validation must force recompilation, but a reviewed footprint
# package/metadata refresh must not accidentally inherit the force flag.
original = u.shutil.which
u.shutil.which = lambda tool: '/usr/bin/bfs-pkgmk' if tool == 'bfs-pkgmk' else original(tool)
try:
    cmd = u.pkgmk_build_command('disk', 32)
    assert cmd[-3:] == ['-d', '-kw', '-f'], cmd  # last three args plus binary
    assert 'BFS_PKG_BUILD_JOBS=32' in cmd
    assert u.pkgmk_footprint_package_command('disk', 32)[-3:] == ['-d', '-if', '-kw']
    assert u.pkgmk_footprint_update_command('disk', 32)[-3:] == ['-d', '-uf', '-kw']
finally:
    u.shutil.which = original

# Default UI: routine updates ON, REVIEW and skipped candidates OFF.
rows = [SimpleNamespace(port='opt/a', old='1', new='2',old_release='1',new_release='1',source_label='test',status='UPDATE',selected=False),
        SimpleNamespace(port='opt/b', old='1', new='2',old_release='1',new_release='1',source_label='test',status='REVIEW',selected=True),
        SimpleNamespace(port='opt/c', old='1', new='2',old_release='1',new_release='1',source_label='test',status='SKIP',selected=True)]
old_dialog = u.dcall
captured = []
def fake_dialog(args, env):
    captured.extend(args)
    return 0, 'opt/a\n'
u.dcall = fake_dialog
try:
    picked = u.choose_updates_dialog(rows, {})
    assert picked == ['opt/a']
    assert captured[captured.index('opt/a')+2] == 'on'
    assert captured[captured.index('opt/b')+2] == 'off'
    assert captured[captured.index('opt/c')+2] == 'off'
finally:
    u.dcall = old_dialog

pam = (ROOT/'ports/core/linux-pam/Pkgfile').read_text()
assert '\n    runuser\n' in pam
assert (ROOT/'ports/core/linux-pam/runuser').read_text().startswith('# BFSOS runuser PAM')
assert 'exit 126' in (ROOT/'ports/core/pkgutils/bfs-pkgmk').read_text()
assert 'office:ports/office' in (ROOT/'ports/core/prt-get/bfsos.git').read_text()
assert 'ensure_pkgmk_build_ownership || exit 1' in (ROOT/'scripts/install-bfs-menu-current.sh').read_text()
assert 'install_cmd = ["sudo", "pkgadd"]' in (ROOT/'scripts/bfs-port-updater.py').read_text()
assert 'auto_install_mode = mode == "2"' in (ROOT/'scripts/bfs-port-updater.py').read_text()
print('r438 installer/updater regressions: PASS')

# The retry/fallback path must no longer invoke sudo pkgmk directly or lose
# the resolved CPU count (the old path silently used different job settings).
with tempfile.TemporaryDirectory() as td:
    base = Path(td)
    root = base/'ports'
    pkgfile = root/'opt/example/Pkgfile'
    pkgfile.parent.mkdir(parents=True)
    pkgfile.write_text('name=example\nversion=2\nrelease=1\n')
    row = {'port':'opt/example','new_version':'2','new_release':'1','result':'BUILD FAILED (1)'}
    old_preflight, old_jobs, old_count = u.select_build_work_backend, u.read_build_jobs, u.logical_cpu_count
    old_build, old_stream, old_clean, old_log = u.pkgmk_build_command, u.run_build_streaming, u.cleanup_successful_build_work, u.LOG_ROOT
    attempts=[]
    try:
        u.select_build_work_backend = lambda d, rel: ('tmpfs','test',{'root':str(base),'ok':True})
        u.logical_cpu_count = lambda:32
        u.read_build_jobs = lambda d,n: (n,'default-all-cpus')
        u.pkgmk_build_command = lambda backend,jobs: ['bfs-pkgmk','-d','-kw','-f',str(jobs)]
        def capture_build(cmd,cwd,log,header):
            attempts.append((cmd,header))
            return SimpleNamespace(returncode=0,stdout='')
        u.run_build_streaming = capture_build
        u.cleanup_successful_build_work = lambda d,n: (True,'ok')
        u.LOG_ROOT = base/'logs'
        result = u.retry_failed_updates([row], {'opt/example'},root)
        assert result['opt/example'] == 'BUILT ON RETRY',result
        assert attempts[0][0][-1] == '32'
        assert 'jobs=32' in attempts[0][1]
    finally:
        u.select_build_work_backend, u.read_build_jobs, u.logical_cpu_count = old_preflight, old_jobs, old_count
        u.pkgmk_build_command, u.run_build_streaming, u.cleanup_successful_build_work, u.LOG_ROOT = old_build, old_stream, old_clean, old_log
print('r438 retry/fallback regression: PASS')

# True CMake/KF6 installed-version mismatches remain retryable prerequisites.
cmake_log = '''CMake Error at CMakeLists.txt:44 (find_package):
  Could not find a configuration file for package "KF6Config" that is
  compatible with requested version "6.31.0".
  /opt/kf6/lib/cmake/KF6Config/KF6ConfigConfig.cmake, version: 6.30.0
'''
assert u.kf6_prerequisite_mismatch(cmake_log) == 'KF6Config requires 6.31.0, installed 6.30.0'
assert u.kf6_prerequisite_mismatch('CMake Error: unrelated compiler failure') == ''
print('r438 KF6 dependency classification: PASS')
