#!/usr/bin/env bash
# BFSOS bootstrap host requirements checker.
#
# LFS baseline: Linux From Scratch 13.1-systemd host requirements
# (published 2026-09-01), synchronized for BFSOS on 2026-09-30.
# BFSOS adds the libraries and utilities used by its bootstrap/ISO tooling.

set -u

LC_ALL=C
export LC_ALL
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH

failures=0
warnings=0

ok()    { printf 'OK:    %s\n' "$*"; }
warn()  { printf 'WARN:  %s\n' "$*"; warnings=$((warnings + 1)); }
error() { printf 'ERROR: %s\n' "$*"; failures=$((failures + 1)); }

for tool in grep sed sort; do
    if ! "$tool" --version >/dev/null 2>&1 && [[ "$tool" != sed ]]; then
        error "$tool does not work"
    elif [[ "$tool" == sed ]] && ! sed '' /dev/null >/dev/null 2>&1; then
        error "sed does not work"
    fi
done

version_ge() {
    local have="$1" need="$2"
    printf '%s\n%s\n' "$need" "$have" | sort --version-sort --check=quiet 2>/dev/null
}

version_le() {
    local have="$1" max="$2"
    printf '%s\n%s\n' "$have" "$max" | sort --version-sort --check=quiet 2>/dev/null
}

extract_version() {
    "$1" --version 2>&1 | grep -E -o '[0-9]+\.[0-9]+([.][0-9]+)*[a-z]*' | head -n1
}

ver_check() {
    local label="$1" command="$2" minimum="$3" have=""
    if ! command -v "$command" >/dev/null 2>&1; then
        error "Cannot find $command ($label; $minimum or later required)"
        return 1
    fi
    have="$(extract_version "$command")"
    if [[ -z "$have" ]]; then
        error "Could not determine $label version from $command"
        return 1
    fi
    if version_ge "$have" "$minimum"; then
        printf 'OK:    %-16s %-10s >= %s\n' "$label" "$have" "$minimum"
        return 0
    fi
    error "$label is too old ($have; $minimum or later required)"
    return 1
}

kernel_check() {
    local minimum="$1" have
    have="$(uname -r | grep -E -o '^[0-9]+([.][0-9]+)+' | head -n1)"
    if [[ -n "$have" ]] && version_ge "$have" "$minimum"; then
        ok "Linux kernel $have >= $minimum"
    else
        error "Linux kernel ${have:-unknown} is too old ($minimum or later required)"
    fi
}

printf 'BFSOS host requirements check\n'
printf 'LFS baseline: 13.1-systemd (2026-09-01)\n\n'

# LFS 13.1-systemd minimum versions.
if sort --version 2>&1 | grep -qi uutils; then
    ver_check Coreutils sort 0.8
else
    ver_check Coreutils sort 8.1
fi
ver_check Bash bash 3.2
ver_check Binutils ld 2.13.1
ver_check Bison bison 2.7
ver_check Diffutils diff 2.8.1
ver_check Findutils find 4.2.31
ver_check Gawk gawk 4.0.1
ver_check GCC gcc 5.4
ver_check 'GCC (C++)' g++ 5.4
ver_check Grep grep 2.5.1a
ver_check Gzip gzip 1.3.12
ver_check M4 m4 1.4.10
ver_check Make make 4.0
ver_check Patch patch 2.5.4
ver_check Perl perl 5.8.8
ver_check Python python3 3.4
ver_check Sed sed 4.1.5
ver_check Tar tar 1.22
ver_check Texinfo texi2any 5.0
ver_check Xz xz 5.0.0
kernel_check 5.10

# LFS 13.1 documents these as the tested upper bounds. They are warnings here,
# because BFSOS can deliberately validate newer host toolchains separately.
if command -v gcc >/dev/null 2>&1; then
    gcc_v="$(extract_version gcc)"
    [[ -z "$gcc_v" ]] || version_le "$gcc_v" 16.2.0 || \
        warn "GCC $gcc_v is newer than the LFS 13.1 tested maximum (16.2.0)"
fi
if command -v ld >/dev/null 2>&1; then
    ld_v="$(extract_version ld)"
    [[ -z "$ld_v" ]] || version_le "$ld_v" 2.47 || \
        warn "Binutils $ld_v is newer than the LFS 13.1 tested maximum (2.47)"
fi

printf '\nShell/tool aliases:\n'
if [[ "$(readlink -f /bin/sh 2>/dev/null || true)" == */bash ]]; then
    ok "/bin/sh resolves to bash"
else
    error "/bin/sh does not resolve to bash"
fi
if command -v awk >/dev/null 2>&1 && awk --version 2>&1 | grep -qi GNU; then
    ok "awk is GNU awk"
else
    error "awk is not GNU awk"
fi
if command -v yacc >/dev/null 2>&1 && yacc --version 2>&1 | grep -qi Bison; then
    ok "yacc is Bison"
else
    error "yacc is not Bison"
fi

printf '\nFunctional checks:\n'
compiler_test="$(mktemp /tmp/bfsos-gxx-check.XXXXXX)"
rm -f "$compiler_test"
if printf 'int main(){return 0;}\n' | g++ -x c++ - -o "$compiler_test" >/dev/null 2>&1; then
    ok "g++ can build a hosted C++ program"
else
    error "g++ cannot build a hosted C++ program"
fi
rm -f "$compiler_test"

if command -v nproc >/dev/null 2>&1 && [[ -n "$(nproc 2>/dev/null)" ]]; then
    ok "nproc reports $(nproc) logical cores"
else
    error "nproc is unavailable or returned no CPU count"
fi

if mount | grep -qE '(^| )devpts on /dev/pts( |$)' && [[ -e /dev/ptmx ]]; then
    ok "Linux kernel exposes UNIX 98 PTYs"
else
    error "UNIX 98 PTY support/devpts is not available"
fi

printf '\nBFSOS bootstrap additions:\n'
for command_name in curl git rsync zstd sudo pkg-config bsdtar autoreconf; do
    if command -v "$command_name" >/dev/null 2>&1; then
        ok "$command_name found"
    else
        error "$command_name is required by BFSOS bootstrap/release tooling"
    fi
done

if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists libarchive 2>/dev/null; then
    ok "libarchive development files found ($(pkg-config --modversion libarchive 2>/dev/null))"
else
    error "libarchive development files are required (and bsdtar must be installed)"
fi

compile_link_check() {
    local label="$1" source="$2" libs="$3"
    local out
    out="$(mktemp /tmp/bfsos-link-check.XXXXXX)"
    rm -f "$out"
    # shellcheck disable=SC2086
    if printf '%b' "$source" | gcc -x c - $libs -o "$out" >/dev/null 2>&1; then
        ok "$label development files compile/link correctly"
    else
        error "$label development files are missing or unusable"
    fi
    rm -f "$out"
}

compile_link_check GMP '#include <gmp.h>\nint main(void){mpz_t x; mpz_init(x); mpz_clear(x); return 0;}\n' '-lgmp'
compile_link_check MPFR '#include <mpfr.h>\nint main(void){mpfr_t x; mpfr_init(x); mpfr_clear(x); return 0;}\n' '-lmpfr -lgmp'

if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists libtirpc 2>/dev/null; then
    tirpc_flags="$(pkg-config --cflags --libs libtirpc 2>/dev/null)"
    compile_link_check libtirpc '#include <rpc/rpc.h>\nint main(void){return 0;}\n' "$tirpc_flags"
else
    error "libtirpc development files are required"
fi

printf '\nISO-builder additions (required only when building live ISO media):\n'
for command_name in wget sha256sum mksquashfs xorriso grub-mkrescue mformat; do
    if command -v "$command_name" >/dev/null 2>&1; then
        ok "$command_name found"
    else
        warn "$command_name not found (required by scripts/bfs-build-iso.sh)"
    fi
done

printf '\nHost resources (advisory):\n'
cores="$(nproc 2>/dev/null || printf 0)"
mem_kib="$(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo 2>/dev/null || printf 0)"
if (( cores >= 4 )); then ok "$cores CPU threads available (LFS recommends at least 4 cores)"; else warn "$cores CPU threads available; LFS recommends at least 4 cores"; fi
if (( mem_kib >= 8 * 1024 * 1024 )); then ok "at least 8 GiB RAM available"; else warn "less than 8 GiB RAM detected; builds will be slow or may need extra swap"; fi

printf '\nSummary: %d error(s), %d warning(s).\n' "$failures" "$warnings"
if (( failures > 0 )); then
    printf 'BFSOS host requirements: FAIL\n'
    exit 1
fi
printf 'BFSOS host requirements: PASS\n'
