#!/usr/bin/env bash
# Generate a starter BFSOS port directory and Pkgfile from a source URL.
# This creates a skeleton only; dependencies and package-specific build options
# must still be reviewed by the maintainer.

set -Eeuo pipefail

usage() {
    cat <<'USAGE'
Usage:
  scripts/gentemplate.sh URL [package-name]

Examples:
  scripts/gentemplate.sh https://example.org/releases/foo-1.2.3.tar.xz
  scripts/gentemplate.sh https://files.pythonhosted.org/.../pyqt5_sip-12.19.0.tar.gz pyqt5-sip

Run the command from the collection directory where the new port should be
created, for example:
  cd ~/BFSOS/ports/opt
  ../../scripts/gentemplate.sh https://example.org/foo-1.2.3.tar.xz

The generated Pkgfile is a starting point. Review Description, URL,
dependencies, source naming, build_opt, patches, footprint/signature policy,
and runtime behavior before committing the port.
USAGE
}

case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    '') usage >&2; exit 2 ;;
esac

source_url="$1"
requested_name="${2:-}"
filename="${source_url%%\?*}"
filename="${filename%%\#*}"
filename="${filename##*/}"

[[ -n "$filename" ]] || { echo "gentemplate: URL has no filename: $source_url" >&2; exit 2; }

stem="$filename"
case "$stem" in
    *.tar.gz)  stem="${stem%.tar.gz}" ;;
    *.tar.bz2) stem="${stem%.tar.bz2}" ;;
    *.tar.xz)  stem="${stem%.tar.xz}" ;;
    *.tar.zst) stem="${stem%.tar.zst}" ;;
    *.tar.lz)  stem="${stem%.tar.lz}" ;;
    *.tar.lz4) stem="${stem%.tar.lz4}" ;;
    *.tgz)     stem="${stem%.tgz}" ;;
    *.tbz2)    stem="${stem%.tbz2}" ;;
    *.txz)     stem="${stem%.txz}" ;;
    *.zip)     stem="${stem%.zip}" ;;
    *)         stem="${stem%.*}" ;;
esac

if [[ "$stem" =~ ^(.+)-v?([0-9][0-9A-Za-z._+~-]*)$ ]]; then
    upstream_name="${BASH_REMATCH[1]}"
    version="${BASH_REMATCH[2]}"
else
    echo "gentemplate: cannot derive name/version from '$filename'" >&2
    echo "gentemplate: expected a filename similar to name-1.2.3.tar.xz" >&2
    exit 2
fi

name="${upstream_name,,}"
name="${name//_/-}"
case "$source_url" in
    *pythonhosted*|*pypi*) [[ "$name" == python3-* ]] || name="python3-$name" ;;
    *metacpan*|*cpan*)    [[ "$name" == perl-* ]] || name="perl-$name" ;;
esac
[[ -z "$requested_name" ]] || name="$requested_name"

if [[ -e "$name" ]]; then
    echo "gentemplate: refusing to overwrite existing path: $name" >&2
    if [[ -f "$name/Pkgfile" ]]; then
        grep -E '^(name|version|release)=' "$name/Pkgfile" || true
    fi
    exit 1
fi

pkg_source="$source_url"
# Use the maintainable variables where the URL spelling matches the generated
# BFSOS package name. Otherwise keep the upstream spelling literal and at least
# parameterize the version.
if [[ "${upstream_name,,}" == "$name" ]]; then
    pkg_source="${pkg_source//$upstream_name/\$name}"
fi
pkg_source="${pkg_source//$version/\$version}"

mkdir -p -- "$name"
cat > "$name/Pkgfile" <<EOF_PKG
# Description: TODO - short factual package description
# URL: TODO - upstream project page
# Maintainer: Brian Madonna <bmadonnaster@gmail.com>
# Depends on:

name=$name
version=$version
release=1
source=($pkg_source)

# BFSOS pkgutils auto-detects Meson, Autotools/configure, CMake, setup.py,
# Perl Makefile.PL, and ordinary Makefile builds. Add build_opt only when the
# upstream build needs non-default options; use pkg_build() only for genuinely
# custom build orchestration.
# build_opt=(
#     --example-option
# )
EOF_PKG

printf 'Created %s/Pkgfile\n\n' "$name"
cat "$name/Pkgfile"
