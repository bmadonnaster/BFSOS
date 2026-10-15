#!/usr/bin/env bash
# Prepares verified expat 2.9.0 source checksums for both BFSOS architectures.
# Does not build, install or regenerate footprints.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="https://github.com/libexpat/libexpat/releases/download/R_2_9_0/expat-2.9.0.tar.xz"
SHA256="1e6371862cc31999b368c3b89b49994f0677e1bab5f1b2b85ae3741f5d803051"
for port in core/expat compat-32/expat-32; do
  grep -qx 'version=2.9.0' "$ROOT/ports/$port/Pkgfile" || {
    echo "Version mismatch: $port" >&2; exit 1;
  }
done
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
curl --fail --location --retry 3 --connect-timeout 15 --max-time 180 \
  --output "$work/expat-2.9.0.tar.xz" "$SOURCE"
printf '%s  %s\n' "$SHA256" "$work/expat-2.9.0.tar.xz" | sha256sum -c -
md5="$(md5sum "$work/expat-2.9.0.tar.xz" | cut -d' ' -f1)"
for port in core/expat compat-32/expat-32; do
  printf '%s  expat-2.9.0.tar.xz\n' "$md5" > "$ROOT/ports/$port/.md5sum"
  echo "Verified source checksum updated: $port"
done
echo 'Footprints are NOT updated; build/review both architectures before acceptance.'
