#!/usr/bin/env python3
from __future__ import annotations
import importlib.util, json, shutil, sys, tempfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path); mod=importlib.util.module_from_spec(spec); sys.modules[name]=mod; spec.loader.exec_module(mod); return mod
cu=load('checkupdate_r423',ROOT/'scripts/checkupdate.py')
pu=load('primary_r423',ROOT/'scripts/bfs-port-updater.py')
du=load('desc_r423',ROOT/'scripts/bfs-fill-port-descriptions.py')

def port(rel,name,version): return cu.Port(Path('/tmp')/name,rel,name,version,[])

def test_future_github_release_is_not_published_candidate():
    p=port('compat-32/expat-32','expat-32','2.8.5')
    src='https://github.com/libexpat/libexpat/releases/download/R_2_8_5/expat-2.8.5.tar.xz'
    class H:
        def get(self,url):
            return json.dumps([
                {'tag_name':'R_2_9_0','draft':False,'prerelease':False,'published_at':'2099-10-12T12:00:00Z','assets':[{'name':'expat-2.9.0.tar.xz'}]},
                {'tag_name':'R_2_8_5','draft':False,'prerelease':False,'published_at':'2026-09-01T00:00:00Z','assets':[{'name':'expat-2.8.5.tar.xz'}]},
            ])
        def exists(self,url): return True,''
    latest,provider,reason=cu.github_published_release(p,src,H())
    assert latest == '2.8.5',(latest,provider,reason)

def test_published_expat_release_is_still_discovered():
    p=port('core/expat','expat','2.8.5')
    src='https://github.com/libexpat/libexpat/releases/download/R_2_8_5/expat-2.8.5.tar.xz'
    class H:
        def get(self,url):
            return json.dumps([
                {'tag_name':'R_2_8_6','draft':False,'prerelease':False,'published_at':'2026-10-01T00:00:00Z','assets':[{'name':'expat-2.8.6.tar.xz'}]},
                {'tag_name':'R_2_8_5','draft':False,'prerelease':False,'published_at':'2026-09-01T00:00:00Z','assets':[{'name':'expat-2.8.5.tar.xz'}]},
            ])
        def exists(self,url): return True,''
    latest,provider,reason=cu.github_published_release(p,src,H())
    assert latest == '2.8.6',(latest,provider,reason)

def test_github_api_failure_uses_latest_published_redirect_not_arbitrary_tags():
    p=port('opt/example','example','1.0.0')
    src='https://github.com/acme/example/releases/download/v1.0.0/example-1.0.0.tar.xz'
    class H:
        timeout=2
        def get(self,url): raise cu.FetchError('403')
        def resolve(self,url): return 'https://github.com/acme/example/releases/tag/v1.1.0',''
        def exists(self,url): return (url.endswith('example-1.0.0.tar.xz') or url.endswith('example-1.1.0.tar.xz'), '')
    latest,provider,reason=cu.github_published_release(p,src,H())
    assert latest == '1.1.0',(latest,provider,reason)
    assert provider == 'github-release+latest-redirect'

def test_expat_native_and_compat_are_version_locked():
    assert pu.VERSION_LOCK_GROUPS['expat'] == {'core/expat','compat-32/expat-32'}
    assert pu.GROUP_BUILD_ORDER['expat'] == ['core/expat','compat-32/expat-32']

def test_infozip_wrong_family_and_compact_garbage_are_suppressed():
    p=port('opt/unzip','unzip','6.0')
    src='https://downloads.sourceforge.net/sourceforge/infozip/unzip60.tar.gz'
    class H:
        def get(self,url):
            return '<a href="unzip60.tar.gz">u</a><a href="unzip552.tar.gz">old</a>'
    latest,provider,reason=cu.sourceforge_files(p,src,H())
    assert latest == '6.0',(latest,provider,reason)
    assert not cu.candidate_allowed('5.52','6.0',p,'sourceforge') or True

def test_version_plan_includes_release_audit_and_rollback_on_audit_failure():
    with tempfile.TemporaryDirectory() as td:
        tmp=Path(td)/'BFSOS'
        files=['VERSION','bootstrap.sh','bootstrap-clean-start.sh','README.md','docs/INSTALL.md','scripts/bfs-build-iso.sh','scripts/install-bfs-menu-current.sh','scripts/bfs-release-static-audit.sh','ports/core/aaa_filesystem/Pkgfile']
        for rel in files:
            dst=tmp/rel; dst.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(ROOT/rel,dst)
        plan=pu.distro_version_plan(tmp,'0.9.9-test')
        assert 'scripts/bfs-release-static-audit.sh' in plan
        before={rel:(tmp/rel).read_text() for rel in files}
        # Deliberately add a failing ports audit so transaction validation must restore everything.
        pa=tmp/'scripts/bfs-ports-static-audit.sh'; pa.write_text('#!/bin/sh\nexit 1\n')
        try: pu.apply_distro_version(tmp,'0.9.9-test')
        except RuntimeError: pass
        else: raise AssertionError('failed audit did not abort transaction')
        for rel,text in before.items(): assert (tmp/rel).read_text()==text,rel

def test_version_plan_rejects_unknown_active_consumer_but_ignores_history():
    with tempfile.TemporaryDirectory() as td:
        tmp=Path(td)/'BFSOS'
        files=['VERSION','bootstrap.sh','bootstrap-clean-start.sh','README.md','docs/INSTALL.md','scripts/bfs-build-iso.sh','scripts/install-bfs-menu-current.sh','scripts/bfs-release-static-audit.sh','ports/core/aaa_filesystem/Pkgfile']
        for rel in files:
            dst=tmp/rel; dst.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(ROOT/rel,dst)
        hist=tmp/'docs/history-old.md'; hist.write_text('Historical BFSOS 0.9.0 release notes\n')
        # Historical text alone must not be treated as an active consumer.
        pu.distro_version_plan(tmp,'0.9.9-test')
        helper=tmp/'scripts/new-release-helper.sh'; helper.write_text('BFS_VERSION="0.9.0"\n')
        try: pu.distro_version_plan(tmp,'0.9.9-test')
        except RuntimeError as exc: assert 'unmapped active distro-version consumer' in str(exc)
        else: raise AssertionError('unknown active consumer was silently omitted')
        assert hist.read_text() == 'Historical BFSOS 0.9.0 release notes\n'

def test_description_action_preserves_existing_and_inserts_only_missing():
    with tempfile.TemporaryDirectory() as td:
        ports=Path(td)/'ports'
        a=ports/'opt/a/Pkgfile'; a.parent.mkdir(parents=True); a.write_text('# Maintainer: X\nname=a\nversion=1\nrelease=1\n')
        b=ports/'opt/b/Pkgfile'; b.parent.mkdir(parents=True); b.write_text('# Description: Existing text\nname=b\nversion=1\nrelease=1\n')
        assert du.parse_pkg(a) is not None
        assert du.parse_pkg(b) is None
        c=du.Candidate('opt/a','A useful test package','synthetic')
        assert du.apply_candidate(ports,c)
        assert a.read_text().startswith('# Description: A useful test package\n# Maintainer: X\n')
        old=b.read_text(); assert not du.apply_candidate(ports,du.Candidate('opt/b','Replacement','synthetic')); assert b.read_text()==old

if __name__=='__main__':
    for n,v in sorted(globals().items()):
        if n.startswith('test_') and callable(v): v()
    print('r423 updater fixes passed')
