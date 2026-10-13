#!/usr/bin/env python3
"""Test real checklist defaults from primary updater without network or dialog."""
import ast
from pathlib import Path
from types import SimpleNamespace
p = Path(__file__).resolve().parents[1] / 'bfs-port-updater.py'
tree = ast.parse(p.read_text())
fs = [n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name in ('default_update_checked', 'choose_updates_dialog')]
ns = {'__builtins__': __builtins__}
exec(compile(ast.Module(body=fs,type_ignores=[]),str(p),'exec'),ns)
def candidate(status, label, policy='review', reason='same upstream', port='opt/x'):
    return SimpleNamespace(status=status,source_label=label,policy=policy,reason=reason,
                           old='1',new='2',old_release='1',new_release='1',port=port)
cases=[
 (candidate('UPDATE','MLFS DEV'), 'on'),
 (candidate('REVIEW','CRUX reference'), 'on'),
 (candidate('REVIEW','Arch reference'), 'on'),
 (candidate('REVIEW','Arch reference',reason='version-specific patch requires review'), 'off'),
 (candidate('REVIEW','BLFS reference',policy='book-reference'), 'off'),
 (candidate('REVIEW','upstream'), 'off'),
 (candidate('BLOCKED','CRUX reference'), 'off'),
]
seen=[]
def fake_dialog(args,env):
    start=args.index('21')+1
    seen.extend(args[start:])
    return 0, ''
ns['dcall']=fake_dialog
ns['choose_updates_dialog']([c for c,_ in cases],{})
assert [seen[i+2] for i in range(0,len(seen),3)] == [expected for _,expected in cases],seen
print('r440 default-selection regression: PASS')
