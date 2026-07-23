
otstrap-check.sh
#
# Validate the completed bootstrap stage-1 toolchain and audit the source
# Pkgfiles that were corrected during the merged-/usr and host-contamination
# review.
#
# This script deliberately does NOT test programs installed by bootstrap
# stages 2 or 3. It only:
#
#   1. tests the temporary stage-1 toolchain under $TOOLS;
#   2. checks stage-1 completion markers;
#   3. statically audits selected source Pkgfiles under ports/core;
#   4. checks the stage-1 toolchain archive.
#
# Default assumptions:
#   Project directory: directory containing this script
#   Temporary tools:  /tmp/lfs-tools
#
# Optional environment overrides:
#   PROJECT_DIR=/path/to/project
#   TOOLS=/path/to/lfs-tools
#   ARCHIVE=/path/to/toolchain.tar.xz
#
# Exit status:
#   0 = no failures
#   1 = one or more failures

set -u
set -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

PROJECT_DIR="${PROJECT_DIR:-$SCRIPT_DIR}"
TOOLS="${TOOLS:-/tmp/lfs-tools}"
ARCHIVE="${ARCHIVE:-$PROJECT_DIR/toolchain.tar.xz}"
PORTS_DIR="$PROJECT_DIR/ports/core"

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

pass() {
    printf '[PASS] %s\n' "$*"
    PASS_COUNT=$((PASS_COUNT + 1))
}

warn() {
    printf '[WARN] %s\n' "$*" >&2
    WARN_COUNT=$((WARN_COUNT + 1))
}

fail() {
    printf '[FAIL] %s\n' "$*" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

section() {
    printf '\n=== %s ===\n' "$*"
}

check_command() {
    local command_path="$1"

    if [ -x "$command_path" ]; then
        pass "Executable exists: $command_path"
    elif [ -e "$command_path" ]; then
        fail "Exists but is not executable: $command_path"
    else
        fail "Missing executable: $command_path"
    fi
}

resolve_and_check() {
    local path="$1"
    local resolved

    if [ ! -e "$path" ] && [ ! -L "$path" ]; then
        fail "Missing path: $path"
        return
    fi

    resolved="$(readlink -f "$path" 2>/dev/null || true)"

    if [ -z "$resolved" ] || [ ! -e "$resolved" ]; then
        fail "Dangling or unresolvable link: $path"
        return
    fi

    pass "$path resolves to $resolved"

    if file "$resolved" 2>/dev/null | grep -q 'ELF'; then
        pass "Resolved target is ELF: $resolved"
    else
        warn "Resolved target is not reported as ELF: $resolved"
    fi
}

pkgfile_path() {
    printf '%s/%s/Pkgfile' "$PORTS_DIR" "$1"
}

require_pkgfile() {
    local package="$1"
    local pkgfile

    pkgfile="$(pkgfile_path "$package")"

    if [ -f "$pkgfile" ] && [ ! -L "$pkgfile" ]; then
        pass "$package Pkgfile exists and is a regular file"
        return 0
    fi

    if [ -L "$pkgfile" ]; then
        fail "$package Pkgfile must not be a symlink: $pkgfile"
    else
        fail "$package Pkgfile is missing: $pkgfile"
    fi

    return 1
}

require_pattern() {
    local package="$1"
    local description="$2"
    local pattern="$3"
    local pkgfile

    pkgfile="$(pkgfile_path "$package")"

    if grep -Eq -- "$pattern" "$pkgfile" 2>/dev/null; then
        pass "$package: $description"
    else
        fail "$package: missing expected rule: $description"
    fi
}

forbid_pattern() {
    local package="$1"
    local description="$2"
    local pattern="$3"
    local pkgfile

    pkgfile="$(pkgfile_path "$package")"

    if grep -Eq -- "$pattern" "$pkgfile" 2>/dev/null; then
        fail "$package: forbidden rule found: $description"
        grep -En -- "$pattern" "$pkgfile" 2>/dev/null | sed 's/^/  /'
    else
        pass "$package: no $description"
    fi
}

check_no_crlf() {
    local package="$1"
    local pkgfile

    pkgfile="$(pkgfile_path "$package")"

    if grep -q $'\r' "$pkgfile" 2>/dev/null; then
        warn "$package Pkgfile contains CRLF line endings"
    else
        pass "$package Pkgfile has no CRLF characters"
    fi
}

check_pkg_name() {
    local package="$1"
    local pkgfile
    local parsed_name

    pkgfile="$(pkgfile_path "$package")"

    parsed_name="$(
        (
            unset name version release
            # shellcheck disable=SC1090
            . "$pkgfile"
            printf '%s' "${name:-}"
        ) 2>/dev/null
    )"

    if [ "$parsed_name" = "$package" ]; then
        pass "$package Pkgfile defines name=$package"
    else
        fail "$package Pkgfile name is '${parsed_name:-empty}'"
    fi
}

section "Configuration"

printf 'Project directory : %s\n' "$PROJECT_DIR"
printf 'Temporary tools   : %s\n' "$TOOLS"
printf 'Ports directory   : %s\n' "$PORTS_DIR"
printf 'Toolchain archive : %s\n' "$ARCHIVE"

if [ -d "$PROJECT_DIR" ]; then
    pass "Project directory exists"
else
    fail "Project directory does not exist: $PROJECT_DIR"
fi

if [ -d "$TOOLS" ]; then
    pass "Temporary stage-1 toolchain directory exists"
else
    fail "Temporary stage-1 toolchain directory does not exist: $TOOLS"
fi

if [ -d "$PORTS_DIR" ]; then
    pass "Core ports directory exists"
else
    fail "Core ports directory does not exist: $PORTS_DIR"
fi

section "Required stage-1 toolchain programs"

required_programs=(
    bash
    gcc
    ld
    sed
    pkgmk
)

for program in "${required_programs[@]}"; do
    check_command "$TOOLS/bin/$program"
done

section "Stage-1 program file types"

for program in bash gcc ld sed; do
    path="$TOOLS/bin/$program"

    if [ -e "$path" ] || [ -L "$path" ]; then
        printf '%s: ' "$path"
        file "$path" || fail "Unable to inspect $path"
    fi
done

section "Dangling symlink checks"

if [ -d "$TOOLS" ]; then
    mapfile -t dangling_tools < <(
        find -L "$TOOLS" -type l -print 2>/dev/null
    )

    if [ "${#dangling_tools[@]}" -eq 0 ]; then
        pass "No dangling symlinks under $TOOLS"
    else
        fail "Dangling symlinks found under $TOOLS:"
        printf '  %s\n' "${dangling_tools[@]}"
    fi
fi

if [ -d "$PROJECT_DIR/ports" ]; then
    mapfile -t dangling_ports < <(
        find -L "$PROJECT_DIR/ports" -type l -print 2>/dev/null
    )

    if [ "${#dangling_ports[@]}" -eq 0 ]; then
        pass "No dangling symlinks under $PROJECT_DIR/ports"
    else
        fail "Dangling symlinks found under $PROJECT_DIR/ports:"
        printf '  %s\n' "${dangling_ports[@]}"
    fi
fi

section "Stage-1 linker checks"

resolve_and_check "$TOOLS/bin/ld"

LD_LOG="/tmp/bootstrap-check-ld-version.$$"

if [ -x "$TOOLS/bin/ld" ]; then
    if "$TOOLS/bin/ld" --version >"$LD_LOG" 2>&1; then
        pass "Stage-1 linker executes successfully"
        head -n 1 "$LD_LOG"
    else
        fail "Stage-1 linker failed to execute"
        sed 's/^/  /' "$LD_LOG"
    fi
fi

rm -f "$LD_LOG"

section "Stage-1 compiler identity and search paths"

if [ -x "$TOOLS/bin/gcc" ]; then
    compiler_path="$(
        PATH="$TOOLS/bin:/usr/bin:/bin" command -v gcc 2>/dev/null || true
    )"

    if [ "$compiler_path" = "$TOOLS/bin/gcc" ]; then
        pass "PATH selects stage-1 GCC: $compiler_path"
    else
        fail "PATH selected unexpected GCC: ${compiler_path:-not found}"
    fi

    dumpmachine="$(
        PATH="$TOOLS/bin:/usr/bin:/bin" gcc -dumpmachine 2>/dev/null || true
    )"

    if [ -n "$dumpmachine" ]; then
        pass "Stage-1 GCC target: $dumpmachine"
    else
        fail "Unable to obtain stage-1 GCC target"
    fi

    libgcc="$(
        PATH="$TOOLS/bin:/usr/bin:/bin" \
            gcc --print-libgcc-file-name 2>/dev/null || true
    )"

    if [ -n "$libgcc" ] && [ -e "$libgcc" ]; then
        pass "Stage-1 GCC libgcc found: $libgcc"
    else
        fail "Stage-1 GCC did not return a valid libgcc path: ${libgcc:-empty}"
    fi

    SEARCH_LOG="/tmp/bootstrap-check-search-dirs.$$"

    if PATH="$TOOLS/bin:/usr/bin:/bin" \
        gcc -print-search-dirs >"$SEARCH_LOG" 2>&1
    then
        pass "Stage-1 GCC search directories are readable"
    else
        fail "Unable to read stage-1 GCC search directories"
        sed 's/^/  /' "$SEARCH_LOG"
    fi

    rm -f "$SEARCH_LOG"
fi

section "Stage-1 compile and link test"

TEST_C="/tmp/bootstrap-check-test.$$.c"
TEST_BIN="/tmp/bootstrap-check-test.$$"
TEST_LOG="/tmp/bootstrap-check-test.$$.log"

cat > "$TEST_C" <<'EOF'
int main(void)
{
    return 0;
}
EOF

if env -i \
    HOME="${HOME:-/tmp}" \
    TERM="${TERM:-dumb}" \
    LC_ALL=C \
    PATH="$TOOLS/bin:/usr/bin:/bin" \
    gcc "$TEST_C" -o "$TEST_BIN" >"$TEST_LOG" 2>&1
then
    pass "Stage-1 GCC compiled and linked a test program"

    if file "$TEST_BIN" | grep -q 'ELF'; then
        pass "Test program is an ELF executable"
    else
        fail "Test program is not reported as ELF"
        file "$TEST_BIN" 2>/dev/null || true
    fi

    if "$TEST_BIN"; then
        pass "Test program executed successfully"
    else
        fail "Test program returned a nonzero status"
    fi

    if command -v readelf >/dev/null 2>&1; then
        interpreter="$(
            readelf -l "$TEST_BIN" 2>/dev/null |
            awk '/Requesting program interpreter/ {print}'
        )"

        if [ -n "$interpreter" ]; then
            printf 'Interpreter: %s\n' "$interpreter"
        else
            warn "Could not determine the test program interpreter"
        fi
    else
        warn "Host readelf is unavailable; interpreter check skipped"
    fi
else
    fail "Stage-1 GCC failed to compile or link the test program"
    sed 's/^/  /' "$TEST_LOG"
fi

rm -f "$TEST_C" "$TEST_BIN" "$TEST_LOG"

section "Stage-1 completion markers"

toolchain_packages=(
    binutils-pass1
    gmp
    mpfr
    mpc
    gcc-pass1
    linux-headers
    glibc
    gcc-pass2
    binutils-pass2
    libxcrypt
    gcc-pass3
    m4
    ncurses
    bash
    bison
    bzip2
    coreutils
    diffutils
    file
    findutils
    gawk
    gettext
    grep
    gzip
    make
    patch
    perl
    zlib
    xz
    libtirpc
    libnsl
    python
    sed
    tar
    texinfo
    openssl
    ca-certificates
    curl
    libarchive
)

missing_markers=()

for package in "${toolchain_packages[@]}"; do
    if [ ! -e "$TOOLS/$package" ]; then
        missing_markers+=("$package")
    fi
done

if [ "${#missing_markers[@]}" -eq 0 ]; then
    pass "All expected stage-1 completion markers exist"
else
    fail "Missing stage-1 completion markers:"
    printf '  %s\n' "${missing_markers[@]}"
fi

section "Audited Pkgfile presence and identity"

audited_packages=(
    aaa_filesystem
    glibc
    gcc
    ncurses
    gawk
    shadow
    linux-pam
    systemd
    dbus
    util-linux
    e2fsprogs
    ca-certificates
    tzdata
    grub
    efibootmgr
    efivar
)

available_audited_packages=()

for package in "${audited_packages[@]}"; do
    if require_pkgfile "$package"; then
        available_audited_packages+=("$package")
        check_pkg_name "$package"
        check_no_crlf "$package"
    fi
done

section "General host-contamination audit"

host_action_pattern='(^|[;&|[:space:]])(systemctl|systemd-sysusers|systemd-machine-id-setup|pwconv|grpconv|grub-install|grub-mkconfig|efibootmgr)([;&|[:space:]]|$)'
unsafe_mount_pattern='(^|[;&|[:space:]])(mount|umount|chroot)([;&|[:space:]]|$)'
unsafe_ldconfig_pattern='(^|[;&|[:space:]])ldconfig([;&|[:space:]]|$)'
unscoped_etc_pattern='(^|[;&|[:space:]])(install|cp|mv|rm|ln|chmod|chown|chgrp)[[:space:]].*[[:space:]]/etc(/|[[:space:]]|$)'
unscoped_var_pattern='(^|[;&|[:space:]])(install|cp|mv|rm|ln|chmod|chown|chgrp)[[:space:]].*[[:space:]]/var(/|[[:space:]]|$)'

for package in "${available_audited_packages[@]}"; do
    forbid_pattern "$package" "runtime system-finalization command" "$host_action_pattern"
    forbid_pattern "$package" "mount, unmount, or chroot command" "$unsafe_mount_pattern"
    forbid_pattern "$package" "unscoped ldconfig command" "$unsafe_ldconfig_pattern"
    forbid_pattern "$package" "unscoped write directly into host /etc" "$unscoped_etc_pattern"
    forbid_pattern "$package" "unscoped write directly into host /var" "$unscoped_var_pattern"
done

section "Merged-/usr package rules"

if [ -f "$(pkgfile_path aaa_filesystem)" ]; then
    for link in bin lib sbin; do
        require_pattern \
            aaa_filesystem \
            "creates merged-/usr /$link compatibility link" \
            "ln[[:space:]]+-s[f]?[[:space:]]+[^[:space:]]*usr/$link[^[:space:]]*[[:space:]]+[^[:space:]]*PKG/$link|ln[[:space:]]+-s[f]?[[:space:]]+usr/$link[[:space:]]+.*PKG/$link"
    done

    require_pattern \
        aaa_filesystem \
        "creates /var/run compatibility link to /run" \
        'ln[[:space:]]+-s[f]?[[:space:]]+\.\./run[[:space:]]+.*PKG/var/run'

    require_pattern \
        aaa_filesystem \
        "creates /var/lock compatibility link to /run/lock" \
        'ln[[:space:]]+-s[f]?[[:space:]]+\.\./run/lock[[:space:]]+.*PKG/var/lock'

    forbid_pattern \
        aaa_filesystem \
        "malformed share brace expansion" \
        'share/\}'
fi

if [ -f "$(pkgfile_path gcc)" ]; then
    require_pattern \
        gcc \
        "/usr/lib/cpp compatibility link" \
        'usr/lib/cpp'
fi

if [ -f "$(pkgfile_path glibc)" ]; then
    require_pattern \
        glibc \
        "/usr/lib32/locale compatibility link" \
        'usr/lib32/locale'
fi

section "Package-specific corrected rules"

if [ -f "$(pkgfile_path ncurses)" ]; then
    require_pattern \
        ncurses \
        "defines the ncurses package normally" \
        '^name=ncurses$'
fi

if [ -f "$(pkgfile_path gawk)" ]; then
    forbid_pattern \
        gawk \
        "absolute host-side manpage symlink destination" \
        'ln[[:space:]]+-s[^#\n]*[[:space:]]/usr/share/man'
fi

if [ -f "$(pkgfile_path shadow)" ]; then
    forbid_pattern shadow "pwconv invocation inside the package build" '(^|[;&|[:space:]])pwconv([;&|[:space:]]|$)'
    forbid_pattern shadow "grpconv invocation inside the package build" '(^|[;&|[:space:]])grpconv([;&|[:space:]]|$)'
fi

if [ -f "$(pkgfile_path systemd)" ]; then
    forbid_pattern systemd "systemd-sysusers invocation inside the package build" '(^|[;&|[:space:]])systemd-sysusers([;&|[:space:]]|$)'
    forbid_pattern systemd "machine-id initialization inside the package build" 'systemd-machine-id-setup'
    forbid_pattern systemd "systemctl preset invocation inside the package build" 'systemctl[[:space:]]+preset'
fi

if [ -f "$(pkgfile_path dbus)" ]; then
    require_pattern \
        dbus \
        "uses DESTDIR while installing" \
        'DESTDIR=.*PKG|DESTDIR="\$PKG"'

    forbid_pattern \
        dbus \
        "bare ninja install without DESTDIR" \
        '^[[:space:]]*ninja[[:space:]]+install[[:space:]]*$'

    require_pattern \
        dbus \
        "packages the machine-id compatibility link" \
        'var/lib/dbus/machine-id'
fi

if [ -f "$(pkgfile_path e2fsprogs)" ]; then
    require_pattern e2fsprogs "uses pkg_build()" '^pkg_build\(\)'
    require_pattern e2fsprogs "installs binaries under /usr/bin" '--bindir=/usr/bin'
    require_pattern e2fsprogs "installs administration binaries under /usr/sbin" '--sbindir=/usr/sbin'
    require_pattern e2fsprogs "installs libraries under /usr/lib" '--libdir=/usr/lib'
fi

if [ -f "$(pkgfile_path ca-certificates)" ]; then
    require_pattern \
        ca-certificates \
        "packages /etc/ssl/cert.pem" \
        'etc/ssl/cert\.pem'

    require_pattern \
        ca-certificates \
        "packages the consolidated certificate bundle" \
        'ca-certificates\.crt'
fi

if [ -f "$(pkgfile_path tzdata)" ]; then
    require_pattern tzdata "installs zoneinfo under /usr/share" 'TZDIR=/usr/share/zoneinfo'
    require_pattern tzdata "uses /usr as TOPDIR" 'TOPDIR=/usr'
    require_pattern tzdata "uses /usr as USRDIR" 'USRDIR=/usr'
fi

if [ -f "$(pkgfile_path grub)" ]; then
    require_pattern grub "uses BIOS PC platform" '--with-platform=pc'
    require_pattern grub "uses the i386 target" '--target=i386'
    forbid_pattern grub "grub-install invocation during packaging" '(^|[;&|[:space:]])grub-install([;&|[:space:]]|$)'
    forbid_pattern grub "grub-mkconfig invocation during packaging" '(^|[;&|[:space:]])grub-mkconfig([;&|[:space:]]|$)'

    if [ -e "$PORTS_DIR/grub/grub.default" ]; then
        warn "grub.default still exists; it is unused unless explicitly installed"
    else
        pass "Unused grub.default file is absent"
    fi

    if [ -e "$PORTS_DIR/grub/grub-2.06-upstream_fixes-1.patch" ]; then
        warn "Obsolete GRUB 2.06 patch still exists"
    else
        pass "Obsolete GRUB 2.06 patch is absent"
    fi
fi

if [ -f "$(pkgfile_path efibootmgr)" ]; then
    require_pattern efibootmgr "compiles with EFIDIR=/boot/efi" 'EFIDIR=/boot/efi'
    require_pattern efibootmgr "installs the binary under /usr/sbin" 'PKG/usr/sbin/efibootmgr'
    require_pattern efibootmgr "sets executable mode explicitly" 'install[[:space:]].*-m[[:space:]]+0755'
    forbid_pattern efibootmgr "firmware-variable command invocation during packaging" '(^|[;&|[:space:]])efibootmgr([;&|[:space:]]|$)'

    if [ -e "$PORTS_DIR/efibootmgr/efivar.patch" ]; then
        warn "Unused efibootmgr efivar.patch still exists"
    else
        pass "Unused efibootmgr efivar.patch is absent"
    fi
fi

if [ -f "$(pkgfile_path efivar)" ]; then
    require_pattern efivar "disables documentation with ENABLE_DOCS=0" 'ENABLE_DOCS=0'
    require_pattern efivar "installs libraries under /usr/lib" 'libdir=/usr/lib'
    require_pattern efivar "uses DESTDIR for installation" 'DESTDIR=.*PKG|DESTDIR="\$PKG"'
    forbid_pattern efivar "fragile Makefile docs sed edit" "sed[[:space:]].*s/docs//"
fi

section "Toolchain archive"

if [ -f "$ARCHIVE" ]; then
    pass "Toolchain archive exists: $ARCHIVE"

    if xz -t "$ARCHIVE" >/dev/null 2>&1; then
        pass "XZ integrity test passed"
    else
        fail "XZ integrity test failed"
    fi

    if tar -tJf "$ARCHIVE" >/dev/null 2>&1; then
        pass "Tar archive listing test passed"
    else
        fail "Tar archive listing test failed"
    fi
else
    fail "Toolchain archive is missing: $ARCHIVE"
fi

printf '\n=== Summary ===\n'
printf 'PASS: %d\n' "$PASS_COUNT"
printf 'WARN: %d\n' "$WARN_COUNT"
printf 'FAIL: %d\n' "$FAIL_COUNT"

if [ "$FAIL_COUNT" -eq 0 ]; then
    printf '\nBootstrap stage-1 and audited Pkgfile checks passed.\n'
    exit 0
fi

printf '\nBootstrap stage-1 and audited Pkgfile checks found failures.\n'
exit 1
