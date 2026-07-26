#!/bin/bash -e

# Bootstrap environments do not necessarily have generated UTF-8 locales.
# The POSIX C locale is always available and keeps all bootstrap stages
# deterministic.
unset LC_CTYPE
unset LC_COLLATE
unset LC_MESSAGES
unset LC_MONETARY
unset LC_NUMERIC
unset LC_TIME

export LANG=C
export LC_ALL=C
export LANGUAGE=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PID_FILE="$SCRIPT_DIR/.bootstrap.pid"

_stop_bootstrap() {
    local pid=""
    local pgid=""

    if [ -f "$PID_FILE" ]; then
        read -r pid pgid < "$PID_FILE" || true
    fi

    if [ -z "$pid" ] || [ -z "$pgid" ]; then
        echo "No recorded BFS bootstrap process is running."
        rm -f "$PID_FILE"
        return 0
    fi

    if ! kill -0 "$pid" 2>/dev/null; then
        echo "Recorded BFS bootstrap process is no longer running."
        rm -f "$PID_FILE"
        return 0
    fi

    echo "Stopping BFS bootstrap process group $pgid..."

    kill -TERM -- "-$pgid" 2>/dev/null || true

    for _ in 1 2 3 4 5; do
        kill -0 "$pid" 2>/dev/null || break
        sleep 1
    done

    if kill -0 "$pid" 2>/dev/null; then
        echo "Processes did not stop normally; forcing termination..."
        kill -KILL -- "-$pgid" 2>/dev/null || true
    fi

    rm -f "$PID_FILE"
    echo "BFS bootstrap stopped."
}

# The stop command must run outside the build's process group.
case "${1:-}" in
    0|stop|kill)
        _stop_bootstrap
        exit 0
        ;;
esac

# Run every bootstrap stage in its own process group. This makes Ctrl+C and
# the stop command terminate pkgmk, make, gcc, tar, and other descendants too.
CURRENT_PGID="$(ps -o pgid= -p "$$" | tr -d '[:space:]')"

if [ "$$" != "$CURRENT_PGID" ]; then
    exec setsid "$0" "$@"
fi

printf '%s %s\n' "$$" "$CURRENT_PGID" > "$PID_FILE"

_cleanup_on_exit() {
    local status=$?

    trap - EXIT INT TERM HUP

    if declare -F umountfs >/dev/null 2>&1; then
        umountfs 2>/dev/null || true
    fi

    rm -f "$PID_FILE"
    exit "$status"
}

_interrupt_bootstrap() {
    echo
    echo "Bootstrap interrupted. Stopping all child processes..."

    trap - INT TERM HUP

    # Kill every remaining process in this bootstrap process group except
    # this shell, which will exit through the EXIT cleanup trap.
    kill -TERM -- "-$$" 2>/dev/null || true
    sleep 1
    kill -KILL -- "-$$" 2>/dev/null || true
}

trap _interrupt_bootstrap INT TERM HUP
trap _cleanup_on_exit EXIT

# BFS release. The VERSION file is authoritative when present.
if [ -f "$SCRIPT_DIR/VERSION" ]; then
    BFS_VERSION="$(tr -d '[:space:]' < "$SCRIPT_DIR/VERSION")"
else
    BFS_VERSION="0.9.0"
fi

BUILD_DATE="$(date +%Y%m%d)"

ARCHIVE_DIR="$SCRIPT_DIR/archives"
TOOLCHAIN_ARCHIVE_DIR="$ARCHIVE_DIR/toolchain"
BASE_ARCHIVE_DIR="$ARCHIVE_DIR/base"

_ensure_archive_dirs() {
    mkdir -p "$TOOLCHAIN_ARCHIVE_DIR" "$BASE_ARCHIVE_DIR"
}

_clean_start() {
    local answer

    echo
    echo "Start a completely clean BFS build?"
    echo
    echo "This will permanently delete:"
    echo "  /tmp/lfs*"
    echo "  $packagedir/*"
    echo "  $TOOLCHAIN_ARCHIVE_DIR/bfs-toolchain-*.tar.xz"
    echo "  $BASE_ARCHIVE_DIR/bfs-rootfs-*.tar.xz"
    echo
    printf "Type YES to continue, or press Enter to keep existing files: "
    read -r answer

    if [ "$answer" != "YES" ]; then
        echo
        echo "Keeping existing build files."
        return 0
    fi

    case "$LFS" in
        /tmp/lfs-rootfs)
            ;;
        *)
            echo "ERROR: Refusing to remove unexpected LFS path: $LFS" >&2
            exit 1
            ;;
    esac

    case "$TOOLS" in
        /tmp/lfs-tools)
            ;;
        *)
            echo "ERROR: Refusing to remove unexpected tools path: $TOOLS" >&2
            exit 1
            ;;
    esac

    echo
    echo "Removing old BFS build files..."

    find /tmp \
        -mindepth 1 \
        -maxdepth 1 \
        -name 'lfs*' \
        -print \
        -exec sudo rm -rf -- {} +

    sudo mkdir -p "$packagedir"

    sudo find "$packagedir" \
        -mindepth 1 \
        -maxdepth 1 \
        -print \
        -exec rm -rf -- {} +

    _ensure_archive_dirs

    sudo find "$TOOLCHAIN_ARCHIVE_DIR" \
        -mindepth 1 \
        -maxdepth 1 \
        -type f \
        -name 'bfs-toolchain-*.tar.xz' \
        -print \
        -delete

    sudo find "$BASE_ARCHIVE_DIR" \
        -mindepth 1 \
        -maxdepth 1 \
        -type f \
        -name 'bfs-rootfs-*.tar.xz' \
        -print \
        -delete

    echo
    echo "Clean start completed."
}

_latest_archive() {
    local directory="$1"
    local pattern="$2"
    local latest

    latest="$(
        find "$directory" -maxdepth 1 -type f -name "$pattern" -printf '%f\n' 2>/dev/null |
            sort -V |
            tail -n 1
    )"

    [ -n "$latest" ] || return 1

    printf '%s/%s\n' "$directory" "$latest"
}

_clear_rootfs() {
    case "$LFS" in
        /tmp/lfs-rootfs)
            ;;
        *)
            echo "ERROR: Refusing to clear unexpected LFS path: $LFS" >&2
            exit 1
            ;;
    esac

    /usr/bin/mkdir -p "$LFS"
    /usr/bin/find "$LFS" -mindepth 1 -maxdepth 1 -exec /usr/bin/rm -rf -- {} +
}

_restore_toolchain() {
    local archive
    local restored_tools="${LFS}${TOOLS}"
    local listing_file
    local toolchain_member=""

    archive="$(
        _latest_archive \
            "$TOOLCHAIN_ARCHIVE_DIR" \
            'bfs-toolchain-*.tar.xz'
    )" || {
        echo "ERROR: No toolchain archive found in:" >&2
        echo "  $TOOLCHAIN_ARCHIVE_DIR" >&2
        exit 1
    }

    echo "Restoring newest toolchain archive:"
    echo "  $archive"
    echo

    case "$restored_tools" in
        /tmp/lfs-rootfs/tmp/lfs-tools)
            ;;
        *)
            echo "ERROR: Refusing to replace unexpected toolchain path:" >&2
            echo "  $restored_tools" >&2
            exit 1
            ;;
    esac

    # List the archive once. Some tar versions print members with a leading
    # "./" and others do not, so stage 7 must accept either representation.
    listing_file="$(/usr/bin/mktemp /tmp/bfs-toolchain-list.XXXXXX)"

    if ! /usr/bin/nice -n 19 /bin/tar -tJf "$archive" > "$listing_file"; then
        /usr/bin/rm -f "$listing_file"
        echo "ERROR: Toolchain archive is unreadable or damaged." >&2
        exit 1
    fi

    if grep -qx './tmp/lfs-tools' "$listing_file"; then
        toolchain_member='./tmp/lfs-tools'
    elif grep -qx 'tmp/lfs-tools' "$listing_file"; then
        toolchain_member='tmp/lfs-tools'
    elif grep -q '^\./tmp/lfs-tools/' "$listing_file"; then
        toolchain_member='./tmp/lfs-tools'
    elif grep -q '^tmp/lfs-tools/' "$listing_file"; then
        toolchain_member='tmp/lfs-tools'
    fi

    if [ -z "$toolchain_member" ]; then
        echo "ERROR: Toolchain archive does not contain the temporary toolchain:" >&2
        echo "  tmp/lfs-tools" >&2
        echo >&2
        echo "Toolchain-like entries found:" >&2
        grep -E '(^|/)lfs-tools(/|$)' "$listing_file" | head -20 >&2 || true
        /usr/bin/rm -f "$listing_file"
        exit 1
    fi

    # Do not require one exact archive spelling for gcc. Verify that the
    # archive contains the toolchain tree, extract it, and then test the
    # restored executable paths directly.
    /usr/bin/rm -f "$listing_file"

    # Stage 7 preserves an existing base rootfs and replaces only its
    # temporary toolchain.
    #
    # PATH begins with /tmp/lfs-tools/bin. Once that symlink or directory is
    # removed, unqualified commands may disappear mid-restore. Use the live
    # system's absolute command paths during replacement and extraction.
    /usr/bin/mkdir -p "$LFS/tmp"

    # Remove the host-side convenience symlink before replacing its target.
    /usr/bin/rm -f "$TOOLS"
    /usr/bin/rm -rf "$restored_tools"

    if ! /usr/bin/nice -n 19 /bin/tar -xJpf "$archive" \
        -C "$LFS" \
        "$toolchain_member"
    then
        echo "ERROR: Failed to extract the temporary toolchain." >&2
        exit 1
    fi

    # Recreate:
    # /tmp/lfs-tools -> /tmp/lfs-rootfs/tmp/lfs-tools
    /usr/bin/ln -s "$restored_tools" "$TOOLS"

    if [ ! -x "$TOOLS/bin/gcc" ] ||
        [ ! -x "$TOOLS/bin/ld" ] ||
        [ ! -x "$TOOLS/bin/pkgmk" ]
    then
        echo "ERROR: Restored toolchain failed verification." >&2
        echo >&2
        echo "Expected executable files:" >&2
        echo "  $TOOLS/bin/gcc" >&2
        echo "  $TOOLS/bin/ld" >&2
        echo "  $TOOLS/bin/pkgmk" >&2
        echo >&2
        echo "Available compiler/linker entries:" >&2
        /usr/bin/find "$TOOLS/bin" -maxdepth 1 \
            \( -name '*gcc*' -o -name 'cc' -o -name 'ld*' -o -name 'pkgmk' \) \
            -printf '  %f -> %l\n' 2>/dev/null | /usr/bin/sort >&2 || true
        exit 1
    fi

    echo "Toolchain restored successfully."
    echo

    if [ -x "$LFS/usr/bin/bash" ] &&
        [ -x "$LFS/usr/bin/pkgmk" ] &&
        [ -f "$LFS/var/lib/pkg/db" ]
    then
        echo "Existing base rootfs was preserved."
        echo "Continue with:"
        echo "  sudo $0 3"
    else
        echo "No completed base rootfs was detected."
        echo "Continue with:"
        echo "  sudo $0 2"
    fi
}

_restore_rootfs() {
    local archive

    archive="$(
        _latest_archive \
            "$BASE_ARCHIVE_DIR" \
            'bfs-rootfs-*.tar.xz'
    )" || {
        echo "ERROR: No base rootfs archive found in:" >&2
        echo "  $BASE_ARCHIVE_DIR" >&2
        exit 1
    }

    echo "Restoring newest base rootfs archive:"
    echo "  $archive"

    # Stage 6 destroys the current rootfs, including any temporary toolchain
    # living below it. Never use commands resolved through $TOOLS during this
    # operation; use the live system's absolute command paths throughout.
    if ! /bin/tar -tJf "$archive" >/dev/null; then
        echo "ERROR: Base rootfs archive is unreadable or damaged." >&2
        exit 1
    fi

    _clear_rootfs

    if ! /bin/tar -xJpf "$archive" -C "$LFS"; then
        echo "ERROR: Failed to extract base rootfs archive." >&2
        exit 1
    fi

    for link in bin lib sbin; do
        if [ ! -e "$LFS/$link" ]; then
            /usr/bin/ln -s "usr/$link" "$LFS/$link"
        fi
    done

    if [ -d "$LFS/usr/lib32" ] && [ ! -e "$LFS/lib32" ]; then
        /usr/bin/ln -s usr/lib32 "$LFS/lib32"
    fi

    if [ -d "$LFS/usr/libx32" ] && [ ! -e "$LFS/libx32" ]; then
        /usr/bin/ln -s usr/libx32 "$LFS/libx32"
    fi

    /usr/bin/mkdir -p \
        "$LFS/dev/pts" \
        "$LFS/proc" \
        "$LFS/run" \
        "$LFS/sys" \
        "$LFS/tmp"

    # A base-rootfs archive intentionally does not require the temporary
    # bootstrap toolchain. Remove any stale host-side convenience symlink.
    /usr/bin/rm -f "$TOOLS"

    if [ ! -x "$LFS/usr/bin/bash" ] ||
        [ ! -x "$LFS/usr/bin/gcc" ] ||
        [ ! -f "$LFS/var/lib/pkg/db" ]
    then
        echo "ERROR: Restored base rootfs failed basic verification." >&2
        exit 1
    fi

    echo
    echo "Base rootfs restored successfully."
    echo "Verify the restored system with:"
    echo "  sudo $0 4"
}
_buildtoolchain() {
    _ensure_archive_dirs

    if [ "$(id -u)" = 0 ]; then
        echo "temporary toolchain need to build as regular user"
        exit 1
    fi

    _clean_start

    export PATCH=~/bfs-linux-install/sources/
    export BOOTSTRAP=1
    export LFS_TGT=x86_64-lfs-linux-gnu
    export LFS_TGT32=i686-lfs-linux-gnu
    export LFS_TGTX32=x86_64-lfs-linux-gnux32

    mkdir -p ${LFS}${TOOLS} "$sourcedir"
    rm -f "$TOOLS"
    ln -sf "${LFS}${TOOLS}" "$TOOLS"

    cat > /tmp/bootstrap.conf <<EOF
export LANG=C
export LC_ALL=C
export LANGUAGE=C
export MAKEFLAGS=-j$(nproc)

PKGMK_SOURCE_DIR=$sourcedir
PKGMK_PACKAGE_DIR=/tmp/lfs-pkg

. $PWD/files/pkgmk.bootstrap
EOF

    if [ ! "$(PATH=$TOOLS/bin command -v pkgmk)" ]; then
        if [ ! -f "$sourcedir/pkgutils-5.40.12.tar.xz" ]; then
            curl -o "$sourcedir/pkgutils-5.40.12.tar.xz" \
                https://crux.nu/files/pkgutils-5.40.12.tar.xz
        fi

        rm -rf /tmp/pkgutils-5.40.12
        tar -xf "$sourcedir/pkgutils-5.40.12.tar.xz" -C /tmp

        sed -i \
            -e 's/ --static//' \
            -e 's/ -static//' \
            /tmp/pkgutils-5.40.12/Makefile

        make -j"$(nproc)" -C /tmp/pkgutils-5.40.12

        make -j"$(nproc)" \
            -C /tmp/pkgutils-5.40.12 \
            BINDIR="$TOOLS/bin" \
            MANDIR="$TOOLS/man" \
            ETCDIR="$TOOLS/etc" \
            install

        rm -rf /tmp/pkgutils-5.40.12
    fi

    for i in $toolchainpkg; do
        [ -f "$TOOLS/$i" ] && continue

        export tcpkg="$i"

        cd "ports/core/${i%-pass*}"

        mkdir -p /tmp/lfs-pkg

        pkgmk -d -is -if -cf /tmp/bootstrap.conf

        rm -rf /tmp/lfs-pkg

        cd - >/dev/null 2>&1

        touch "$TOOLS/$i"

        unset tcpkg
    done

    rm -f /tmp/bootstrap.conf

    local toolchain_archive

    _ensure_archive_dirs

    toolchain_archive="$TOOLCHAIN_ARCHIVE_DIR/bfs-toolchain-${BFS_VERSION}-${BUILD_DATE}.tar.xz"

    rm -f "$toolchain_archive"

    (
        cd "$LFS"
        XZ_DEFAULTS='-T0' tar -cvJpf "$toolchain_archive" .
    )

    tar -tJf "$toolchain_archive" >/dev/null

    echo
    echo "Toolchain build completed."
    echo "Archive created:"
    echo "  $toolchain_archive"
}

_verifybase() {
    local marker="$LFS/.bfs-verified"
    local failed=0

    if [ "$(id -u)" != 0 ]; then
        echo "ERROR: Base verification must be run as root." >&2
        exit 1
    fi

    echo
    echo "========================================"
    echo " BFS BASE SYSTEM VERIFICATION"
    echo "========================================"
    echo

    # Never leave a stale success marker behind after a failed verification.
    rm -f "$marker"

    _verify_path() {
        if [ -e "$1" ] || [ -L "$1" ]; then
            printf '  [PASS] %s\n' "$1"
        else
            printf '  [FAIL] %s is missing\n' "$1" >&2
            failed=1
        fi
    }

    echo "Checking base filesystem..."
    _verify_path "$LFS/usr/bin/bash"
    _verify_path "$LFS/usr/bin/gcc"
    _verify_path "$LFS/usr/bin/g++"
    _verify_path "$LFS/usr/bin/ld"
    _verify_path "$LFS/usr/bin/make"
    _verify_path "$LFS/usr/bin/pkgmk"
    _verify_path "$LFS/var/lib/pkg/db"
    _verify_path "$LFS/etc"
    _verify_path "$LFS/var"
    _verify_path "$LFS/usr"

    if [ "$failed" -ne 0 ]; then
        echo
        echo "ERROR: Base filesystem verification failed." >&2
        return 1
    fi

    echo
    echo "Mounting virtual filesystems for chroot tests..."
    mountfs

    if ! chroot "$LFS" \
        env -i \
        HOME=/root \
        TERM="${TERM:-dumb}" \
        LANG=C \
        LC_ALL=C \
        LANGUAGE=C \
        PATH=/usr/bin:/usr/sbin:/bin:/sbin \
        /bin/bash -c '
            set -eu

            pass() {
                printf "  [PASS] %s\\n" "$1"
            }

            fail() {
                printf "  [FAIL] %s\\n" "$1" >&2
                exit 1
            }

            echo "Checking final toolchain..."
            for cmd in gcc g++ ld make pkg-config pkgmk pkgadd pkginfo; do
                command -v "$cmd" >/dev/null 2>&1 || fail "$cmd is not available"
                pass "$cmd"
            done

            echo
            echo "Checking shell and runtime linker..."
            [ -x /bin/bash ] || fail "/bin/bash is not executable"
            [ -e /bin/sh ] || fail "/bin/sh is missing"
            readlink -e /bin/sh >/dev/null 2>&1 || fail "/bin/sh is a broken link"
            pass "/bin/sh"

            command -v ldconfig >/dev/null 2>&1 || fail "ldconfig is not available"
            ldconfig -p >/dev/null 2>&1 || fail "ldconfig cache cannot be read"
            pass "ldconfig"

            ldd /bin/bash >/dev/null 2>&1 || fail "/bin/bash dynamic libraries cannot be resolved"
            pass "/bin/bash dynamic libraries"

            echo
            echo "Checking for temporary-toolchain leakage..."
            if gcc -dumpspecs | grep -Fq /tmp/lfs-tools; then
                fail "GCC specs still reference /tmp/lfs-tools"
            fi
            pass "GCC specs contain no /tmp/lfs-tools references"

            if gcc -print-search-dirs | grep -Fq /tmp/lfs-tools; then
                fail "GCC search paths still reference /tmp/lfs-tools"
            fi
            pass "GCC search paths contain no /tmp/lfs-tools references"

            echo
            echo "Checking package database..."
            pkginfo -i >/dev/null 2>&1 || fail "package database is not readable"
            pass "package database"

            echo
            echo "Compiling and running a C test..."
            cat > /tmp/bfs-verify.c <<"EOF_C"
#include <stdio.h>
int main(void) {
    puts("BFS C compiler test passed");
    return 0;
}
EOF_C
            gcc /tmp/bfs-verify.c -o /tmp/bfs-verify-c || fail "C compilation failed"
            /tmp/bfs-verify-c >/dev/null || fail "compiled C program failed to run"
            pass "C compile and run"

            echo
            echo "Compiling and running a C++ test..."
            cat > /tmp/bfs-verify.cpp <<"EOF_CPP"
#include <iostream>
int main() {
    std::cout << "BFS C++ compiler test passed\\n";
    return 0;
}
EOF_CPP
            g++ /tmp/bfs-verify.cpp -o /tmp/bfs-verify-cpp || fail "C++ compilation failed"
            /tmp/bfs-verify-cpp >/dev/null || fail "compiled C++ program failed to run"
            pass "C++ compile and run"

            rm -f \
                /tmp/bfs-verify.c \
                /tmp/bfs-verify.cpp \
                /tmp/bfs-verify-c \
                /tmp/bfs-verify-cpp
        '
    then
        failed=1
    fi

    umountfs

    if [ "$failed" -ne 0 ]; then
        rm -f "$marker"
        echo
        echo "========================================" >&2
        echo " BFS BASE SYSTEM VERIFICATION FAILED" >&2
        echo "========================================" >&2
        return 1
    fi

    cat > "$marker" << EOF
BFS_VERSION=$BFS_VERSION
BUILD_DATE=$BUILD_DATE
VERIFIED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

    echo
    echo "Verification marker created:"
    echo "  $marker"
    echo
    echo "========================================"
    echo " BFS BASE SYSTEM VERIFICATION PASSED"
    echo "========================================"
}

_compressrootfs() {
    local rootfs_archive

    if [ ! -f "$LFS/.bfs-verified" ]; then
        echo "ERROR: Base system has not passed stage 4 verification." >&2
        echo "Run:" >&2
        echo "  sudo $0 4" >&2
        exit 1
    fi

    _ensure_archive_dirs

    rootfs_archive="$BASE_ARCHIVE_DIR/bfs-rootfs-${BFS_VERSION}-${BUILD_DATE}.tar.xz"

    rm -f "$rootfs_archive"

    (
        cd "$LFS"

        XZ_DEFAULTS='-T0' tar \
            --exclude='./var/lib/pkg/rejected' \
            --exclude=".$TOOLS" \
            --exclude='./tmp/*' \
            --exclude='./dev/*' \
            --exclude='./sys/*' \
            --exclude='./proc/*' \
            --exclude='./run/*' \
            --exclude='./root/.cache' \
            -cvJpf "$rootfs_archive" .
    )

    tar -tJf "$rootfs_archive" >/dev/null

    echo
    echo "Base rootfs compressed successfully."
    echo "Archive created:"
    echo "  $rootfs_archive"
}

_buildbase() {
    if [ "$(id -u)" != 0 ]; then
        echo "ERROR: Stages 2 and 3 must be run as root." >&2
        exit 1
    fi

    # Any Stage 2/3 build changes the rootfs. Require Stage 4 to verify it again
    # before a new release archive can be created.
    rm -f "$LFS/.bfs-verified"

    if [ ! -f "$LFS/var/lib/pkg/db" ]; then
        mkdir -pv "$LFS"/{etc,var} "$LFS"/usr/{bin,lib,sbin} "$LFS/dev"

        for i in bash cat chmod dd echo ln mkdir pwd rm stty; do
            ln -svf "$TOOLS/bin/$i" "$LFS/usr/bin"
        done

        for i in env install perl printf touch; do
            ln -svf "$TOOLS/bin/$i" "$LFS/usr/bin"
        done

        for i in bin lib sbin; do
            ln -sv "usr/$i" "$LFS/$i"
        done

        case $(uname -m) in
            x86_64)
                mkdir -pv "$LFS/lib64"
                ;;
        esac

        mkdir -pv "$LFS/usr/lib32" "$LFS/usr/libx32"

        ln -sv usr/lib32 "$LFS/lib32"
        ln -sv usr/libx32 "$LFS/libx32"

        ln -svf \
            "$TOOLS/lib/libgcc_s.so" \
            "$TOOLS/lib/libgcc_s.so.1" \
            "$LFS/usr/lib"

        ln -svf \
            "$TOOLS/lib/libstdc++.a" \
            "$TOOLS/lib/libstdc++.so" \
            "$TOOLS/lib/libstdc++.so.6" \
            "$LFS/usr/lib"

        ln -svf bash "$LFS/bin/sh"

        ln -svf /proc/self/mounts "$LFS/etc/mtab"

        cat ports/core/aaa_filesystem/passwd > "$LFS/etc/passwd"
        cat ports/core/aaa_filesystem/group > "$LFS/etc/group"

        mkdir -p "$LFS/var/lib/pkg"
        touch "$LFS/var/lib/pkg/db"

        mkdir -p "$LFS/$pkgmkpkg"
        mkdir -p "$LFS/$pkgmksrc"
        mkdir -p "$packagedir"
    fi

    rm -rf "$LFS/usr/ports/"

    cp -r ports/ "$LFS/usr/"

    mkdir -p "$LFS/tmp/lfs-tools/bin"
    cp files/pkgin "$LFS/tmp/lfs-tools/bin/pkgin"
    chmod +x "$LFS/tmp/lfs-tools/bin/pkgin"

    mkdir -p "$LFS/var/lib/pkgmk"

    cp ports/core/pkgutils/extension \
        "$LFS/var/lib/pkgmk"

    cat > "$LFS/tmp/pkgmk.conf" <<EOF
export LANG=C
export LC_ALL=C
export LANGUAGE=C

export CPPFLAGS="-I/usr/include"
export CFLAGS="-O2 -march=x86-64 -pipe"
export CXXFLAGS="\${CFLAGS}"
export LDFLAGS="-L/usr/lib -Wl,-rpath-link,/usr/lib"
export LIBRARY_PATH="/usr/lib"

export PKG_CONFIG_PATH="/usr/lib/pkgconfig:/usr/share/pkgconfig"
export PKG_CONFIG_LIBDIR="/usr/lib/pkgconfig:/usr/share/pkgconfig"

export JOBS=$(nproc)
export MAKEFLAGS="-j \$JOBS"

PKGMK_SOURCE_DIR="/$pkgmksrc"
PKGMK_PACKAGE_DIR="/$pkgmkpkg"
PKGMK_WORK_DIR="/tmp/pkgmk-\$name"

. /var/lib/pkgmk/extension
EOF

    cat > "$LFS/tmp/pkgmk.systemd-bootstrap.conf" <<EOF
export LANG=C
export LC_ALL=C
export LANGUAGE=C

# systemd needs these before final util-linux exists.
export CFLAGS="-O2 -march=x86-64 -pipe"
export CXXFLAGS="\${CFLAGS}"
export LDFLAGS="-L/usr/lib -Wl,-rpath-link,/usr/lib"

# Expose only the temporary util-linux libraries to systemd.
# All other dependencies must come from the Stage-2 BFS system.
export PKG_CONFIG_PATH="/tmp/systemd-util-linux-pc:/usr/lib/pkgconfig:/usr/share/pkgconfig"
export PKG_CONFIG_LIBDIR="/tmp/systemd-util-linux-pc:/usr/lib/pkgconfig:/usr/share/pkgconfig"

export JOBS=$(nproc)
export MAKEFLAGS="-j \$JOBS"

PKGMK_SOURCE_DIR="/$pkgmksrc"
PKGMK_PACKAGE_DIR="/$pkgmkpkg"
PKGMK_WORK_DIR="/tmp/pkgmk-\$name"

. /var/lib/pkgmk/extension
EOF

    # Provide systemd with only the temporary util-linux pkg-config files.
    mkdir -p "$LFS/tmp/systemd-util-linux-pc"

    for pc in uuid blkid mount; do
        cp "$LFS/tmp/lfs-tools/lib/pkgconfig/$pc.pc"             "$LFS/tmp/systemd-util-linux-pc/$pc.pc"
    done

    LFSPATH=/bin:/usr/bin:/sbin:/usr/sbin

    if [ "${1:-}" != rebuild ]; then
        LFSPATH=$LFSPATH:$TOOLS/bin
    fi

    mountfs

    for i in $basepkg; do
        if [ "${1:-}" != rebuild ]; then
            pkginfo -i -r "$LFS" |
                awk '{print $1}' |
                grep -qx "$i" &&
                continue

            unset _force

            case $i in
                aaa_filesystem|gcc|bash|dash|perl|coreutils|pkgutils)
                    _force=-f
                    ;;
            esac

            pkgmk_conf=/tmp/pkgmk.conf

            if [ "${1:-}" != rebuild ] && [ "$i" = systemd ]; then
                pkgmk_conf=/tmp/pkgmk.systemd-bootstrap.conf
                echo "Using temporary util-linux libraries for systemd bootstrap."
            fi

            chroot "$LFS" \
                env -i \
                HOME=/root \
                TERM="${TERM:-dumb}" \
                LANG=C \
                LC_ALL=C \
                LANGUAGE=C \
                PATH="$LFSPATH" \
                pkgin -d "$i" -is -if -im -cf "$pkgmk_conf" \
                || {
                    umountfs
                    exit 1
                }

            pkgadd -r "$LFS" ${_force:-} -f \
                "$(ls -1 "$packagedir/$i#"* | tail -n1)" \
                || {
                    umountfs
                    exit 1
                }

            case $i in
                glibc)
                    cat << EOF > "$LFS/tmp/glibc-postinstall"
#!/bin/sh
set -e

export LANG=C
export LC_ALL=C
export LANGUAGE=C

TOOLS="$TOOLS"
HOST_TRIPLET="\$(uname -m)-pc-linux-gnu"
REAL_LD=""
SAVED_LD="/tmp/ld-real.\$\$"

cleanup() {
    rm -f "\$SAVED_LD"
}

trap cleanup EXIT HUP INT TERM

echo "Adjusting GCC and binutils after glibc"

for candidate in \
    "\$TOOLS/bin/ld.bfd" \
    "\$TOOLS/\$HOST_TRIPLET/bin/ld.bfd" \
    "\$TOOLS/bin/ld-new" \
    "\$TOOLS/\$HOST_TRIPLET/bin/ld-new" \
    "\$TOOLS/bin/ld" \
    "\$TOOLS/\$HOST_TRIPLET/bin/ld"
do
    if [ -f "\$candidate" ] &&
        file "\$candidate" 2>/dev/null | grep -q 'ELF'
    then
        REAL_LD="\$candidate"
        break
    fi
done

if [ -z "\$REAL_LD" ]; then
    echo "ERROR: No real ELF ld executable found."

    echo
    echo "Available linker candidates:"

    for candidate in \
        "\$TOOLS/bin/ld.bfd" \
        "\$TOOLS/\$HOST_TRIPLET/bin/ld.bfd" \
        "\$TOOLS/bin/ld-new" \
        "\$TOOLS/\$HOST_TRIPLET/bin/ld-new" \
        "\$TOOLS/bin/ld" \
        "\$TOOLS/\$HOST_TRIPLET/bin/ld"
    do
        if [ -e "\$candidate" ]; then
            file "\$candidate"
        fi
    done

    exit 1
fi

echo "Using linker: \$REAL_LD"

# Save the real linker before renaming any path that may refer to it.
cp -av "\$REAL_LD" "\$SAVED_LD"

if [ -e "\$TOOLS/bin/ld" ] &&
    [ ! -e "\$TOOLS/bin/ld-old" ]
then
    mv -v "\$TOOLS/bin/ld" "\$TOOLS/bin/ld-old"
fi

if [ -e "\$TOOLS/\$HOST_TRIPLET/bin/ld" ] &&
    [ ! -e "\$TOOLS/\$HOST_TRIPLET/bin/ld-old" ]
then
    mv -v \
        "\$TOOLS/\$HOST_TRIPLET/bin/ld" \
        "\$TOOLS/\$HOST_TRIPLET/bin/ld-old"
fi

install -m 0755 "\$SAVED_LD" "\$TOOLS/bin/ld"
install -m 0755 \
    "\$SAVED_LD" \
    "\$TOOLS/\$HOST_TRIPLET/bin/ld"

gcc -dumpspecs | sed \
    -e "s@\$TOOLS@@g" \
    -e "/\*startfile_prefix_spec:/{n;s@.*@/usr/lib/ @}" \
    -e '/\*cpp:/{n;s@\$@ -isystem /usr/include@}' \
    > "\$(dirname "\$(gcc --print-libgcc-file-name)")/specs"

echo 'int main(void) { return 0; }' > dummy.c

cc -c dummy.c -o dummy.o

rm -f dummy.c dummy.o

echo 'int main(void) { return 0; }' > dummy.c

cc dummy.c -v -Wl,--verbose > dummy.log 2>&1

readelf -l a.out | grep ': /lib' \
    > /tmp/adjusttoolchainresult || true

grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log \
    >> /tmp/adjusttoolchainresult || true

grep -B1 '^ /usr/include' dummy.log \
    >> /tmp/adjusttoolchainresult || true

grep 'SEARCH.*/usr/lib' dummy.log |
    sed 's|; |\n|g' \
    >> /tmp/adjusttoolchainresult || true

grep "/lib.*/libc.so.6 " dummy.log \
    >> /tmp/adjusttoolchainresult || true

grep found dummy.log \
    >> /tmp/adjusttoolchainresult || true

rm -fv dummy.c dummy.o a.out dummy.log
EOF

                    chroot "$LFS" \
                        env -i \
                        HOME=/root \
                        TERM="${TERM:-dumb}" \
                        LANG=C \
                        LC_ALL=C \
                        LANGUAGE=C \
                        PATH="$LFSPATH" \
                        sh /tmp/glibc-postinstall

                    rm -f "$LFS/tmp/glibc-postinstall"
                    ;;
            esac
        else
            chroot "$LFS" \
                env -i \
                HOME=/root \
                TERM="${TERM:-dumb}" \
                LANG=C \
                LC_ALL=C \
                LANGUAGE=C \
                PATH="$LFSPATH" \
                prt-get update -im -fr -if -fi "$i" \
                || {
                    umountfs
                    exit 1
                }
        fi
    done

    umountfs

    echo
    echo "base system build completed"
}

mountfs() {
    umountfs

    mkdir -p "$LFS/dev" "$LFS/run" "$LFS/proc" "$LFS/sys"

    mount --bind /dev "$LFS/dev"

    mount -t devpts devpts \
        "$LFS/dev/pts" \
        -o gid=5,mode=620

    mount -t proc proc "$LFS/proc"
    mount -t sysfs sysfs "$LFS/sys"
    mount -t tmpfs tmpfs "$LFS/run"

    if [ -h "$LFS/dev/shm" ]; then
        mkdir -p "$LFS/$(readlink "$LFS/dev/shm")"
    fi

    mkdir -p "$LFS/$pkgmksrc"
    mkdir -p "$LFS/$pkgmkpkg"

    mount --bind "$sourcedir" "$LFS/$pkgmksrc"
    mount --bind "$packagedir" "$LFS/$pkgmkpkg"
}

umountfs() {
    unmount "$LFS/dev/pts"
    unmount "$LFS/dev"
    unmount "$LFS/run"
    unmount "$LFS/proc"
    unmount "$LFS/sys"
    unmount "$LFS/$pkgmkpkg"
    unmount "$LFS/$pkgmksrc"
}

unmount() {
    while true; do
        mountpoint -q "$1" || break
        umount "$1" 2>/dev/null
    done
}

export LFS=/tmp/lfs-rootfs
export TOOLS=/tmp/lfs-tools

export PATH=$TOOLS/bin:$PATH

toolchainpkg="
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
util-linux
"
basepkg="
aaa_filesystem
linux-headers
man-pages
glibc
autoconf
zlib
bzip2
xz
file
ncurses
readline
m4
bc
binutils
pkgconf
libxcrypt
gmp
mpfr
mpc
attr
acl
gcc
libcap
psmisc
sed
tzdata
iana-etc
bison
flex
pcre2
grep
bash
libtool
gdbm
gperf
expat
inetutils
perl
perl-xml-parser
intltool
automake
openssl
ca-certificates
curl
gettext
elfutils
libffi
sqlite
python
coreutils
check
diffutils
gawk
findutils
groff
less
gzip
zstd
iptables
libtirpc
iproute2
kbd
libpipeline
make
patch
man-db
tar
texinfo
python3-setuptools
python3-pip
python3-flit-core
python3-packaging
python3-installer
python3-build
python3-pyproject-hooks
python3-wheel
meson
ninja
kmod
linux-pam
shadow
libpng
which
freetype
fuse
grub
popt
mandoc
efivar
efibootmgr
grub-efi
vim
nano
python3-markupsafe
python3-tomli
python3-pytz
python3-babel
python3-jinja2
systemd
util-linux
dbus
procps-ng
e2fsprogs
libarchive
pkgutils
dialog
prt-get
httpup
ports
prt-utils
lzo
btrfs-progs
dosfstools
exfatprogs
f2fs-tools
mdadm
libaio
lvm2
inih
liburcu
xfsprogs
openssh
genfstab
signify
"
sourcedir="$PWD/sources"
packagedir="$PWD/packages"

pkgmkpkg="var/cache/pkg/packages"
pkgmksrc="var/cache/pkg/sources"

if [ -z "${1:-}" ]; then
    cat << EOF
Usage:
  $0 <options>

Options:
  1  build temporary toolchain
  2  build base system (using temporary toolchain)
  3  rebuild base system (using final system toolchain itself)
  4  verify completed base system
  5  create base rootfs archive
  6  restore newest base rootfs archive
  7  restore newest temporary toolchain archive (optional)
  0  stop a running bootstrap and all child processes
     aliases: stop, kill
EOF

    exit 0
fi

case $1 in
    1)
        _buildtoolchain
        ;;
    2)
        _buildbase
        ;;
    3)
        _buildbase rebuild
        ;;
    4)
        _verifybase
        ;;
    5)
        _compressrootfs
        ;;
    6)
        _restore_rootfs
        ;;
    7)
        _restore_toolchain
        ;;
    *)
        echo "Unknown option: $1" >&2
        exit 1
        ;;
esac

exit 0
