#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WRAPPER="$ROOT/files/bfs-prefetch-curl"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat > "$tmp/bin/curl" <<'CURL'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$FAKE_CURL_ARGS"
exit "${FAKE_CURL_STATUS:-0}"
CURL
chmod +x "$tmp/bin/curl"

export PATH="$tmp/bin:$PATH"
export FAKE_CURL_ARGS="$tmp/args"

set +e
"$WRAPPER" https://example.invalid/archive.tar.xz >"$tmp/stdout" 2>"$tmp/stderr"
status=$?
set -e
[[ $status -eq 2 ]] || { echo "FAIL: missing-output guard returned $status" >&2; exit 1; }
[[ ! -s "$tmp/stdout" ]] || { echo 'FAIL: wrapper wrote payload/diagnostics to stdout' >&2; exit 1; }
grep -q 'refusing to download without an explicit output destination' "$tmp/stderr"

"$WRAPPER" -L -o "$tmp/archive.tar.xz" https://example.invalid/archive.tar.xz
mapfile -t args <"$tmp/args"
[[ "${args[*]}" == *"-o $tmp/archive.tar.xz https://example.invalid/archive.tar.xz"* ]] || {
    printf 'FAIL: curl arguments were not preserved: %q\n' "${args[*]}" >&2
    exit 1
}

health="$tmp/health"
export BFS_PREFETCH_HEALTH_FILE="$health"
export BFS_PREFETCH_SOURCE_PREFIXES='https://ftp.gnu.org/gnu/'
export FAKE_CURL_STATUS=28
set +e
"$WRAPPER" -o "$tmp/a" https://ftp.gnu.org/gnu/bash/bash.tar.xz >/dev/null 2>"$tmp/transport.err"
status=$?
set -e
[[ $status -eq 28 ]] || { echo "FAIL: transport status changed: $status" >&2; exit 1; }
grep -Fxq 'https://ftp.gnu.org/gnu/' "$health"

export FAKE_CURL_STATUS=0
rm -f "$tmp/args"
set +e
"$WRAPPER" -o "$tmp/b" https://ftp.gnu.org/gnu/coreutils/coreutils.tar.xz >/dev/null 2>"$tmp/skip.err"
status=$?
set -e
[[ $status -eq 7 ]] || { echo "FAIL: unhealthy primary was not skipped: $status" >&2; exit 1; }
[[ ! -e "$tmp/args" ]] || { echo 'FAIL: curl was invoked for cached unhealthy primary' >&2; exit 1; }

echo 'prefetch curl wrapper regression: PASS'
