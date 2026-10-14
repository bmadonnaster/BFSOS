#!/usr/bin/env python3
"""List Pkgfiles using unsupported filename::URL source aliases.

This is a read-only preflight; never rewrite source archives/checksums based on
text matching. Exit nonzero if any unsupported declarations are found.
"""
import argparse
from pathlib import Path
import re

ALIAS = re.compile(r'(?P<alias>[^\s()"\']+)::(?P<url>https?://[^\s()"\']+)')


def scan(root):
    for pkgfile in sorted(root.glob('ports/**/Pkgfile')):
        for line_number, line in enumerate(pkgfile.read_text(errors='replace').splitlines(), 1):
            if line.lstrip().startswith('#'):
                continue
            for match in ALIAS.finditer(line):
                yield pkgfile.relative_to(root), line_number, match.group('alias'), match.group('url')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    findings = list(scan(args.root))
    for path, line, alias, url in findings:
        print(f'{path}:{line}: UNSUPPORTED filename::URL source alias: {alias}::{url}')
    print(f'Source alias audit: {len(findings)} unsupported declaration(s)')
    return 1 if findings else 0


if __name__ == '__main__':
    raise SystemExit(main())
