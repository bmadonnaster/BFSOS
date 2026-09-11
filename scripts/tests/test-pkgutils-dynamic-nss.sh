#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
PKGFILE="$ROOT/ports/core/pkgutils/Pkgfile"
EXT="$ROOT/ports/core/pkgutils/extension"

fail()
{
    echo "pkgutils dynamic-NSS regression FAIL: $*" >&2
    exit 1
}

release=$(awk -F= '$1 == "release" {print $2; exit}' "$PKGFILE")

[[ "$release" =~ ^[0-9]+$ ]] ||
    fail "pkgutils release is not numeric: ${release:-missing}"

(( release >= 33 )) ||
    fail "pkgutils release regressed below dynamic-NSS fix floor (33): $release"

boot=$(
    awk '
        /^bootstrap_build\(\)[[:space:]]*\{/ {on=1}
        on {print}
        on && /^}/ {exit}
    ' "$PKGFILE"
)

printf '%s\n' "$boot" | grep -Fq "s/ --static//" ||
    fail "bootstrap build no longer strips --static"

printf '%s\n' "$boot" | grep -Fq "s/ -static//" ||
    fail "bootstrap build no longer strips -static"

normal=$(
    awk '
        /^pre_build\(\)[[:space:]]*\{/ {on=1}
        on {print}
        on && /^}/ {exit}
    ' "$PKGFILE"
)

[ -n "$normal" ] ||
    fail "normal pre_build() hook is missing"

printf '%s\n' "$normal" | grep -Fq "s/ --static//" ||
    fail "normal build does not strip --static"

printf '%s\n' "$normal" | grep -Fq "s/ -static//" ||
    fail "normal build does not strip -static"

grep -q 'command -v pre_build' "$EXT" ||
    fail "pkgmk extension no longer invokes pre_build"

grep -q 'detect_buildtype' "$EXT" ||
    fail "pkgmk extension no longer performs automatic build-type detection"

echo "pkgutils dynamic-NSS regression PASS"
