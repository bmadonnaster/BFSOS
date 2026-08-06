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

LOG_DIR="$SCRIPT_DIR/logs"
TOOLCHAIN_LOG_DIR="$LOG_DIR/toolchain"
BASE_LOG_DIR="$LOG_DIR/base"

ACTIVE_LOG_FILE=""
ACTIVE_LOG_FIFO=""
ACTIVE_LOG_TEE_PID=""
ACTIVE_LOG_STDOUT_FD=7
ACTIVE_LOG_STDERR_FD=8
CURRENT_BASE_LOGS=()

mkdir -p "$TOOLCHAIN_LOG_DIR" "$BASE_LOG_DIR"

if [ -t 1 ] && [ "${TERM:-dumb}" != dumb ]; then
    COLOR_RED=$'\033[1;31m'
    COLOR_GREEN=$'\033[1;32m'
    COLOR_YELLOW=$'\033[1;33m'
    COLOR_CYAN=$'\033[1;36m'
    COLOR_RESET=$'\033[0m'
else
    COLOR_RED=""
    COLOR_GREEN=""
    COLOR_YELLOW=""
    COLOR_CYAN=""
    COLOR_RESET=""
fi

DIALOGRC_FILE=""
ORIGINAL_DIALOGRC="${DIALOGRC-}"
SETTINGS_FILE="$SCRIPT_DIR/.bfs-build-settings"

BFS_THEME="${BFS_THEME:-monochrome}"
BFS_BUILD_JOBS="${BFS_BUILD_JOBS:-$(nproc)}"
BFS_BUILD_OUTPUT="${BFS_BUILD_OUTPUT:-normal}"

_load_build_settings() {
    [ -f "$SETTINGS_FILE" ] || return 0

    while IFS='=' read -r key value; do
        case "$key" in
            BFS_THEME)
                BFS_THEME="$value"
                ;;
            BFS_BUILD_JOBS)
                BFS_BUILD_JOBS="$value"
                ;;
            BFS_BUILD_OUTPUT)
                BFS_BUILD_OUTPUT="$value"
                ;;
        esac
    done < "$SETTINGS_FILE"
}

_save_build_settings() {
    cat > "$SETTINGS_FILE" <<EOF_SETTINGS
BFS_THEME=$BFS_THEME
BFS_BUILD_JOBS=$BFS_BUILD_JOBS
BFS_BUILD_OUTPUT=$BFS_BUILD_OUTPUT
EOF_SETTINGS
}

_load_build_settings
export BFS_THEME BFS_BUILD_JOBS BFS_BUILD_OUTPUT

_write_dialog_theme_classic() {
    cat > "$DIALOGRC_FILE" <<'EOF_DIALOGRC'
use_colors = ON
use_shadow = OFF

screen_color = (WHITE,BLACK,ON)
shadow_color = (BLACK,BLACK,OFF)
dialog_color = (WHITE,BLUE,ON)
title_color = (YELLOW,BLUE,ON)
border_color = (WHITE,BLUE,ON)

button_active_color = (BLACK,WHITE,ON)
button_inactive_color = (WHITE,BLUE,ON)
button_key_active_color = (BLACK,WHITE,ON)
button_key_inactive_color = (YELLOW,BLUE,ON)
button_label_active_color = (BLACK,WHITE,ON)
button_label_inactive_color = (WHITE,BLUE,ON)

inputbox_color = (WHITE,BLUE,ON)
inputbox_border_color = (WHITE,BLUE,ON)
searchbox_color = (WHITE,BLUE,ON)
searchbox_title_color = (YELLOW,BLUE,ON)
searchbox_border_color = (WHITE,BLUE,ON)

position_indicator_color = (YELLOW,BLUE,ON)
menubox_color = (WHITE,BLUE,ON)
menubox_border_color = (WHITE,BLUE,ON)
item_color = (WHITE,BLUE,ON)
item_selected_color = (BLACK,CYAN,ON)
tag_color = (YELLOW,BLUE,ON)
tag_selected_color = (BLACK,CYAN,ON)
tag_key_color = (YELLOW,BLUE,ON)
tag_key_selected_color = (BLACK,CYAN,ON)

check_color = (WHITE,BLUE,ON)
check_selected_color = (BLACK,CYAN,ON)
uarrow_color = (YELLOW,BLUE,ON)
darrow_color = (YELLOW,BLUE,ON)
EOF_DIALOGRC
}

_write_dialog_theme_midnight() {
    cat > "$DIALOGRC_FILE" <<'EOF_DIALOGRC'
use_colors = ON
use_shadow = OFF

screen_color = (WHITE,BLACK,ON)
shadow_color = (BLACK,BLACK,OFF)
dialog_color = (WHITE,CYAN,ON)
title_color = (YELLOW,CYAN,ON)
border_color = (WHITE,CYAN,ON)

button_active_color = (WHITE,BLUE,ON)
button_inactive_color = (BLACK,CYAN,ON)
button_key_active_color = (YELLOW,BLUE,ON)
button_key_inactive_color = (YELLOW,CYAN,ON)
button_label_active_color = (WHITE,BLUE,ON)
button_label_inactive_color = (BLACK,CYAN,ON)

inputbox_color = (BLACK,CYAN,ON)
inputbox_border_color = (WHITE,CYAN,ON)
searchbox_color = (BLACK,CYAN,ON)
searchbox_title_color = (YELLOW,CYAN,ON)
searchbox_border_color = (WHITE,CYAN,ON)

position_indicator_color = (YELLOW,CYAN,ON)
menubox_color = (BLACK,CYAN,ON)
menubox_border_color = (WHITE,CYAN,ON)
item_color = (BLACK,CYAN,ON)
item_selected_color = (WHITE,BLUE,ON)
tag_color = (YELLOW,CYAN,ON)
tag_selected_color = (YELLOW,BLUE,ON)
tag_key_color = (YELLOW,CYAN,ON)
tag_key_selected_color = (YELLOW,BLUE,ON)

check_color = (BLACK,CYAN,ON)
check_selected_color = (WHITE,BLUE,ON)
uarrow_color = (YELLOW,CYAN,ON)
darrow_color = (YELLOW,CYAN,ON)
EOF_DIALOGRC
}

_write_dialog_theme_light() {
    cat > "$DIALOGRC_FILE" <<'EOF_DIALOGRC'
use_colors = ON
use_shadow = OFF

screen_color = (BLACK,WHITE,ON)
shadow_color = (BLACK,BLACK,OFF)
dialog_color = (BLACK,WHITE,ON)
title_color = (BLUE,WHITE,ON)
border_color = (BLUE,WHITE,ON)

button_active_color = (WHITE,BLUE,ON)
button_inactive_color = (BLACK,WHITE,ON)
button_key_active_color = (YELLOW,BLUE,ON)
button_key_inactive_color = (BLUE,WHITE,ON)
button_label_active_color = (WHITE,BLUE,ON)
button_label_inactive_color = (BLACK,WHITE,ON)

inputbox_color = (BLACK,WHITE,ON)
inputbox_border_color = (BLUE,WHITE,ON)
searchbox_color = (BLACK,WHITE,ON)
searchbox_title_color = (BLUE,WHITE,ON)
searchbox_border_color = (BLUE,WHITE,ON)

position_indicator_color = (BLUE,WHITE,ON)
menubox_color = (BLACK,WHITE,ON)
menubox_border_color = (BLUE,WHITE,ON)
item_color = (BLACK,WHITE,ON)
item_selected_color = (WHITE,BLUE,ON)
tag_color = (BLUE,WHITE,ON)
tag_selected_color = (YELLOW,BLUE,ON)
tag_key_color = (BLUE,WHITE,ON)
tag_key_selected_color = (YELLOW,BLUE,ON)

check_color = (BLACK,WHITE,ON)
check_selected_color = (WHITE,BLUE,ON)
uarrow_color = (BLUE,WHITE,ON)
darrow_color = (BLUE,WHITE,ON)
EOF_DIALOGRC
}

_write_dialog_theme_monochrome() {
    cat > "$DIALOGRC_FILE" <<'EOF_DIALOGRC'
use_colors = OFF
use_shadow = OFF
EOF_DIALOGRC
}

_setup_tui_theme() {
    DIALOGRC_FILE="$(mktemp /tmp/bfs-dialogrc.XXXXXX)"

    case "$BFS_THEME" in
        classic)
            _write_dialog_theme_classic
            export NEWT_COLORS='
root=white,black
border=white,blue
window=white,blue
shadow=black,black
title=yellow,blue
button=black,white
actbutton=black,cyan
checkbox=white,blue
actcheckbox=black,cyan
entry=white,blue
label=white,blue
listbox=white,blue
actlistbox=black,cyan
textbox=white,blue
acttextbox=black,cyan
helpline=white,blue
roottext=white,black
emptyscale=white,blue
fullscale=white,cyan
disentry=white,blue
compactbutton=white,blue
actsellistbox=black,cyan
sellistbox=white,blue
'
            ;;
        midnight)
            _write_dialog_theme_midnight
            export NEWT_COLORS='
root=white,black
border=white,cyan
window=black,cyan
shadow=black,black
title=yellow,cyan
button=black,cyan
actbutton=white,blue
checkbox=black,cyan
actcheckbox=white,blue
entry=black,cyan
label=black,cyan
listbox=black,cyan
actlistbox=white,blue
textbox=black,cyan
acttextbox=white,blue
helpline=black,cyan
roottext=white,black
emptyscale=black,cyan
fullscale=white,blue
disentry=black,cyan
compactbutton=black,cyan
actsellistbox=white,blue
sellistbox=black,cyan
'
            ;;
        light)
            _write_dialog_theme_light
            export NEWT_COLORS='
root=black,white
border=blue,white
window=black,white
shadow=black,black
title=blue,white
button=black,white
actbutton=white,blue
checkbox=black,white
actcheckbox=white,blue
entry=black,white
label=black,white
listbox=black,white
actlistbox=white,blue
textbox=black,white
acttextbox=white,blue
helpline=black,white
roottext=black,white
emptyscale=black,white
fullscale=white,blue
disentry=black,white
compactbutton=black,white
actsellistbox=white,blue
sellistbox=black,white
'
            ;;
        monochrome)
            _write_dialog_theme_monochrome
            export NEWT_COLORS='
root=white,black
border=white,black
window=white,black
shadow=black,black
title=white,black
button=black,white
actbutton=black,white
checkbox=white,black
actcheckbox=black,white
entry=white,black
label=white,black
listbox=white,black
actlistbox=black,white
textbox=white,black
acttextbox=black,white
helpline=white,black
roottext=white,black
emptyscale=white,black
fullscale=black,white
disentry=white,black
compactbutton=white,black
actsellistbox=black,white
sellistbox=white,black
'
            ;;
        *)
            echo "WARNING: Unknown BFS_THEME '$BFS_THEME'; using classic." >&2
            BFS_THEME=classic
            _write_dialog_theme_classic
            ;;
    esac

    export DIALOGRC="$DIALOGRC_FILE"
}

_select_theme() {
    local choice=""

    if command -v dialog >/dev/null 2>&1 &&
       [ -r /dev/tty ] &&
       [ -w /dev/tty ]
    then
        set +e
        choice="$(
            dialog \
                --clear \
                --colors \
                --backtitle "BFS Build System" \
                --title "Select Theme" \
                --radiolist \
                "Choose the interface theme." \
                18 64 5 \
                classic "Classic dark-blue installer theme" "$([ "$BFS_THEME" = classic ] && echo on || echo off)" \
                midnight "Midnight Commander-style theme" "$([ "$BFS_THEME" = midnight ] && echo on || echo off)" \
                light "Light theme with black text on white" "$([ "$BFS_THEME" = light ] && echo on || echo off)" \
                monochrome "Monochrome reverse-video theme" "$([ "$BFS_THEME" = monochrome ] && echo on || echo off)" \
                3>&1 1>&2 2>&3 \
                </dev/tty >/dev/tty
        )"
        local rc=$?
        set -e

        [ "$rc" -eq 0 ] || return 0
        [ -n "$choice" ] || return 0

        BFS_THEME="$choice"
        export BFS_THEME

        if [ -n "$DIALOGRC_FILE" ]; then
            rm -f "$DIALOGRC_FILE"
        fi
        _setup_tui_theme
        _save_build_settings
        return 0
    fi

    echo
    echo "Available themes:"
    echo "  1) Classic dark-blue installer"
    echo "  2) Midnight Commander"
    echo "  3) Light"
    echo "  4) Monochrome"
    read -r -p "Choose [1-4, current: $BFS_THEME]: " choice

    case "$choice" in
        1) BFS_THEME=classic ;;
        2) BFS_THEME=midnight ;;
        3) BFS_THEME=light ;;
        4) BFS_THEME=monochrome ;;
        "") return 0 ;;
        *) echo "Invalid theme selection."; return 1 ;;
    esac

    export BFS_THEME

    if [ -n "$DIALOGRC_FILE" ]; then
        rm -f "$DIALOGRC_FILE"
    fi
    _setup_tui_theme
    _save_build_settings
}

_sanitize_log_name() {
    local name="$1"

    name="${name//[^a-zA-Z0-9_.+-]/-}"
    printf '%s\n' "$name"
}

_close_active_package_log() {
    local status="${1:-0}"

    [ -n "$ACTIVE_LOG_FILE" ] || return 0

    printf '\nBuild finished: %s\n' "$(date --iso-8601=seconds 2>/dev/null || date)"
    printf 'Exit status: %s\n' "$status"

    exec 1>&"$ACTIVE_LOG_STDOUT_FD" 2>&"$ACTIVE_LOG_STDERR_FD"
    exec 7>&- 8>&-

    if [ -n "$ACTIVE_LOG_TEE_PID" ]; then
        wait "$ACTIVE_LOG_TEE_PID" 2>/dev/null || true
    fi

    [ -z "$ACTIVE_LOG_FIFO" ] || rm -f "$ACTIVE_LOG_FIFO"

    ACTIVE_LOG_FILE=""
    ACTIVE_LOG_FIFO=""
    ACTIVE_LOG_TEE_PID=""
}

_start_package_log() {
    local phase="$1"
    local package="$2"
    local directory=""
    local safe_package=""
    local timestamp=""

    _close_active_package_log 0

    case "$phase" in
        toolchain) directory="$TOOLCHAIN_LOG_DIR" ;;
        base) directory="$BASE_LOG_DIR" ;;
        *)
            echo "ERROR: Unknown build-log phase: $phase" >&2
            return 1
            ;;
    esac

    mkdir -p "$directory"

    safe_package="$(_sanitize_log_name "$package")"
    timestamp="$(date +%Y%m%d-%H%M%S)"

    if [ "$BFS_BUILD_OUTPUT" = quiet ]; then
        printf 'Building %-28s [%s]\n' "$package" "$phase"
    fi
    ACTIVE_LOG_FILE="$directory/${safe_package}-${timestamp}.log"
    ACTIVE_LOG_FIFO="$(mktemp -u /tmp/bfs-build-log.XXXXXX)"
    mkfifo "$ACTIVE_LOG_FIFO"

    exec 7>&1 8>&2

    if [ "$BFS_BUILD_OUTPUT" = quiet ]; then
        tee -a "$ACTIVE_LOG_FILE" < "$ACTIVE_LOG_FIFO" >/dev/null &
    else
        tee -a "$ACTIVE_LOG_FILE" < "$ACTIVE_LOG_FIFO" >&7 &
    fi

    ACTIVE_LOG_TEE_PID=$!
    exec > "$ACTIVE_LOG_FIFO" 2>&1

    if [ "$phase" = base ]; then
        CURRENT_BASE_LOGS+=("$ACTIVE_LOG_FILE")
    fi

    printf '============================================================\n'
    printf 'BFS build phase: %s\n' "$phase"
    printf 'Package:         %s\n' "$package"
    printf 'Started:         %s\n' "$(date --iso-8601=seconds 2>/dev/null || date)"
    printf 'Port:            %s\n' "$PWD"
    printf 'Log:             %s\n' "$ACTIVE_LOG_FILE"
    printf '============================================================\n\n'
}

_copy_base_logs_into_rootfs() {
    local destination="$LFS/var/logs/bfs-build"
    local log_file=""

    mkdir -p "$destination"

    for log_file in "${CURRENT_BASE_LOGS[@]}"; do
        [ -f "$log_file" ] || continue
        install -m 0644 "$log_file" "$destination/"
    done

    echo
    echo "Base package logs copied to:"
    echo "  $destination"
}

_stage_complete_text() {
    if "$@"; then
        printf '%sCOMPLETE%s' "$COLOR_GREEN" "$COLOR_RESET"
    else
        printf '%sPENDING%s' "$COLOR_RED" "$COLOR_RESET"
    fi
}

_toolchain_complete() {
    _latest_archive "$TOOLCHAIN_ARCHIVE_DIR" 'bfs-toolchain-*.tar.xz' >/dev/null 2>&1
}

_base_stage2_complete() {
    [ -f "$LFS/.bfs-stage2-complete" ]
}

_base_stage3_complete() {
    [ -f "$LFS/.bfs-stage3-complete" ]
}

_verification_complete() {
    [ -f "$LFS/.bfs-verified" ]
}

_rootfs_archive_complete() {
    _latest_archive "$BASE_ARCHIVE_DIR" 'bfs-rootfs-*.tar.xz' >/dev/null 2>&1
}

_rootfs_restore_complete() {
    [ -f "$LFS/.bfs-rootfs-restored" ]
}

_toolchain_restore_complete() {
    [ -f "$LFS/.bfs-toolchain-restored" ]
}

_chroot_available() {
    [ -x "$LFS/usr/bin/bash" ] || [ -x "$LFS/bin/bash" ]
}

_pause_menu() {
    printf '\n'
    read -r -p "Press Enter to return to the menu..." _
}

_run_root_stage() {
    local stage="$1"

    if [ "$(id -u)" -eq 0 ]; then
        "$0" "$stage"
        return $?
    fi

    command -v sudo >/dev/null 2>&1 || {
        echo "ERROR: sudo is required to run stage $stage." >&2
        return 1
    }

    echo
    echo "Stage $stage requires root privileges."
    echo "Running: sudo $0 $stage"
    echo

    sudo -- "$0" "$stage"
}

_enter_bfs_chroot() {
    if [ "$(id -u)" != 0 ]; then
        echo "ERROR: Chroot must be entered as root." >&2
        return 1
    fi

    if ! _chroot_available; then
        echo "ERROR: No usable BFS root filesystem exists at:" >&2
        echo "  $LFS" >&2
        return 1
    fi

    echo
    echo "Mounting virtual filesystems..."
    mountfs

    echo
    echo "Entering BFS chroot."
    echo "Type exit to return to the bootstrap menu."
    echo

    set +e
    chroot "$LFS" \
        env -i \
        HOME=/root \
        TERM="${TERM:-linux}" \
        LANG=C \
        LC_ALL=C \
        LANGUAGE=C \
        PATH=/usr/bin:/usr/sbin:/bin:/sbin \
        /bin/bash --login
    local status=$?
    set -e

    umountfs
    return "$status"
}

_show_bootstrap_menu() {
    local status_column=62

    clear 2>/dev/null || printf '\033[2J\033[H'

    printf '%s\n' \
        '============================================================' \
        '                  BFS Build System' \
        '============================================================' \
        ''

    printf '  %s1)%s %-52s %s\n' \
        "$COLOR_CYAN" "$COLOR_RESET" \
        'Build temporary toolchain' \
        "[$(_stage_complete_text _toolchain_complete)]"

    printf '  %s2)%s %-52s %s\n' \
        "$COLOR_CYAN" "$COLOR_RESET" \
        'Build base system with temporary toolchain' \
        "[$(_stage_complete_text _base_stage2_complete)]"
    printf '     %sRuns automatically with sudo/root privileges%s\n' \
        "$COLOR_YELLOW" "$COLOR_RESET"

    printf '  %s3)%s %-52s %s\n' \
        "$COLOR_CYAN" "$COLOR_RESET" \
        'Rebuild base system with final toolchain' \
        "[$(_stage_complete_text _base_stage3_complete)]"
    printf '     %sRuns automatically with sudo/root privileges%s\n' \
        "$COLOR_YELLOW" "$COLOR_RESET"

    printf '  %s4)%s %-52s %s\n' \
        "$COLOR_CYAN" "$COLOR_RESET" \
        'Verify completed base system' \
        "[$(_stage_complete_text _verification_complete)]"

    printf '  %s5)%s %-52s %s\n' \
        "$COLOR_CYAN" "$COLOR_RESET" \
        'Create base rootfs archive' \
        "[$(_stage_complete_text _rootfs_archive_complete)]"

    printf '  %s6)%s %-52s %s\n' \
        "$COLOR_CYAN" "$COLOR_RESET" \
        'Restore newest base rootfs archive' \
        "[$(_stage_complete_text _rootfs_restore_complete)]"

    printf '  %s7)%s %-52s %s\n' \
        "$COLOR_CYAN" "$COLOR_RESET" \
        'Restore newest temporary toolchain archive' \
        "[$(_stage_complete_text _toolchain_restore_complete)]"

    if _chroot_available; then
        printf '  %s8)%s %-52s [%sAVAILABLE%s]\n' \
            "$COLOR_CYAN" "$COLOR_RESET" \
            'Chroot into BFS rootfs' \
            "$COLOR_GREEN" "$COLOR_RESET"
    else
        printf '  %s8)%s %-52s [%sPENDING%s]\n' \
            "$COLOR_CYAN" "$COLOR_RESET" \
            'Chroot into BFS rootfs' \
            "$COLOR_RED" "$COLOR_RESET"
    fi

    printf '  %s9)%s %-52s [%sTHEME%s]\n' \
        "$COLOR_CYAN" "$COLOR_RESET" \
        'Change interface theme' \
        "$COLOR_YELLOW" "$COLOR_RESET"

    printf '  %s10)%s %s\n\n' \
        "$COLOR_CYAN" "$COLOR_RESET" 'Quit'
}


_dialog_stage_status() {
    if "$@"; then
        printf '%s' '\Z2COMPLETE\Zn'
    else
        printf '%s' '\Z1PENDING\Zn'
    fi
}

_dialog_chroot_status() {
    if _chroot_available; then
        printf '%s' '\Z2AVAILABLE\Zn'
    else
        printf '%s' '\Z1PENDING\Zn'
    fi
}

_dialog_menu_description() {
    local label="$1"
    local status="$2"

    printf '%-57s [%s]' "$label" "$status"
}


_select_build_jobs() {
    local value=""

    if command -v dialog >/dev/null 2>&1 &&
       [ -r /dev/tty ] &&
       [ -w /dev/tty ]
    then
        set +e
        value="$(
            dialog \
                --clear \
                --backtitle "BFS Build System" \
                --title "Parallel Build Jobs" \
                --inputbox \
                "Enter the number of parallel build jobs.\n\nDetected processors: $(nproc)" \
                12 56 "$BFS_BUILD_JOBS" \
                3>&1 1>&2 2>&3 \
                </dev/tty >/dev/tty
        )"
        local rc=$?
        set -e
        [ "$rc" -eq 0 ] || return 0
    else
        read -r -p "Parallel build jobs [$BFS_BUILD_JOBS]: " value
        value="${value:-$BFS_BUILD_JOBS}"
    fi

    if ! [[ "$value" =~ ^[1-9][0-9]*$ ]]; then
        echo "Invalid job count: $value" >&2
        sleep 1
        return 1
    fi

    BFS_BUILD_JOBS="$value"
    export BFS_BUILD_JOBS
    _save_build_settings
}

_select_build_output() {
    local value=""

    if command -v dialog >/dev/null 2>&1 &&
       [ -r /dev/tty ] &&
       [ -w /dev/tty ]
    then
        set +e
        value="$(
            dialog \
                --clear \
                --backtitle "BFS Build System" \
                --title "Build Output" \
                --radiolist \
                "Choose how package build output is displayed.\n\nLogs are always written in both modes." \
                14 66 3 \
                normal "Show build output on screen and save logs" "$([ "$BFS_BUILD_OUTPUT" = normal ] && echo on || echo off)" \
                quiet "Save full logs but show only package headings" "$([ "$BFS_BUILD_OUTPUT" = quiet ] && echo on || echo off)" \
                3>&1 1>&2 2>&3 \
                </dev/tty >/dev/tty
        )"
        local rc=$?
        set -e
        [ "$rc" -eq 0 ] || return 0
    else
        echo "  1) Normal"
        echo "  2) Quiet"
        read -r -p "Choose [1-2, current: $BFS_BUILD_OUTPUT]: " value
        case "$value" in
            1) value=normal ;;
            2) value=quiet ;;
            "") return 0 ;;
            *) return 1 ;;
        esac
    fi

    BFS_BUILD_OUTPUT="$value"
    export BFS_BUILD_OUTPUT
    _save_build_settings
}

_select_settings() {
    local choice=""
    local rc=0

    while true; do
        if command -v dialog >/dev/null 2>&1 &&
           [ -r /dev/tty ] &&
           [ -w /dev/tty ]
        then
            set +e
            choice="$(
                dialog \
                    --clear \
                    --backtitle "BFS Build System" \
                    --title "Settings" \
                    --cancel-label "Back" \
                    --menu \
                    "Configure the BFS build system." \
                    17 72 6 \
                    1 "Theme: $BFS_THEME" \
                    2 "Parallel build jobs: $BFS_BUILD_JOBS" \
                    3 "Build output: $BFS_BUILD_OUTPUT" \
                    4 "Back to main menu" \
                    3>&1 1>&2 2>&3 \
                    </dev/tty >/dev/tty
            )"
            rc=$?
            set -e
            [ "$rc" -eq 0 ] || return 0
        else
            clear 2>/dev/null || true
            echo "BFS Build System Settings"
            echo
            echo "  1) Theme: $BFS_THEME"
            echo "  2) Parallel build jobs: $BFS_BUILD_JOBS"
            echo "  3) Build output: $BFS_BUILD_OUTPUT"
            echo "  4) Back"
            echo
            read -r -p "Choose [1-4]: " choice
        fi

        choice="$(
            printf '%s' "$choice" |
                tr -d '\r\n' |
                sed -e 's/^[[:space:]]*//'                     -e 's/[[:space:]]*$//'                     -e 's/^"//'                     -e 's/"$//'
        )"

        case "$choice" in
            1) _select_theme ;;
            2) _select_build_jobs ;;
            3) _select_build_output ;;
            4) return 0 ;;
            *) ;;
        esac
    done
}

SELECTED_MENU_CHOICE=""

_plain_menu_status() {
    if "$@"; then
        printf '%s' 'COMPLETE'
    else
        printf '%s' 'PENDING'
    fi
}

_plain_chroot_status() {
    if _chroot_available; then
        printf '%s' 'AVAILABLE'
    else
        printf '%s' 'PENDING'
    fi
}

_select_bootstrap_menu_choice() {
    local menu_status=0
    local dialog_error=""
    local error_file=""

    SELECTED_MENU_CHOICE=""

    if command -v dialog >/dev/null 2>&1 &&
       [ -r /dev/tty ] &&
       [ -w /dev/tty ]
    then
        error_file="$(mktemp /tmp/bfs-dialog-error.XXXXXX)"

        set +e
        SELECTED_MENU_CHOICE="$(
            dialog \
                --clear \
                --colors \
                --no-collapse \
                --backtitle "BFS Build System" \
                --title "BFS Build System" \
                --ok-label "Select" \
                --cancel-label "Quit" \
                --extra-button \
                --extra-label "Settings" \
                --menu \
                "Use Up/Down arrows and Enter, or type an option number.\n\n\Z3Options 2 and 3 automatically run with sudo/root privileges.\Zn\n\nUse Tab or Shift+Tab to move between Select, Quit, and Settings." \
                23 92 12 \
                1 "$(_dialog_menu_description \
                    'Build temporary toolchain' \
                    "$(_dialog_stage_status _toolchain_complete)")" \
                2 "$(_dialog_menu_description \
                    'Build base system with temporary toolchain (sudo/root)' \
                    "$(_dialog_stage_status _base_stage2_complete)")" \
                3 "$(_dialog_menu_description \
                    'Rebuild base system with final toolchain (sudo/root)' \
                    "$(_dialog_stage_status _base_stage3_complete)")" \
                4 "$(_dialog_menu_description \
                    'Verify completed base system' \
                    "$(_dialog_stage_status _verification_complete)")" \
                5 "$(_dialog_menu_description \
                    'Create base rootfs archive' \
                    "$(_dialog_stage_status _rootfs_archive_complete)")" \
                6 "$(_dialog_menu_description \
                    'Restore newest base rootfs archive' \
                    "$(_dialog_stage_status _rootfs_restore_complete)")" \
                7 "$(_dialog_menu_description \
                    'Restore newest temporary toolchain archive' \
                    "$(_dialog_stage_status _toolchain_restore_complete)")" \
                8 "$(_dialog_menu_description \
                    'Chroot into BFS rootfs' \
                    "$(_dialog_chroot_status)")" \
                9 "$(_dialog_menu_description \
                    'Quit' \
                    '\Z3EXIT\Zn')" \
                --stdout \
                </dev/tty 2>"$error_file"
        )"
        menu_status=$?
        set -e

        clear </dev/tty >/dev/tty 2>/dev/null || true

        case "$menu_status" in
            0)
                rm -f "$error_file"

                if [ -z "$SELECTED_MENU_CHOICE" ]; then
                    echo "WARNING: dialog returned no menu selection; using the text menu." >&2
                    sleep 1
                else
                    return 0
                fi
                ;;
            1|255)
                SELECTED_MENU_CHOICE=9
                rm -f "$error_file"
                return 0
                ;;
            3)
                SELECTED_MENU_CHOICE=settings
                rm -f "$error_file"
                return 0
                ;;
            *)
                dialog_error="$(cat "$error_file" 2>/dev/null || true)"
                rm -f "$error_file"

                echo
                echo "WARNING: dialog could not open; using the text menu instead." >&2
                if [ -n "$dialog_error" ]; then
                    echo "$dialog_error" >&2
                fi
                sleep 1
                ;;
        esac
    fi

    _show_bootstrap_menu
    printf '%sChoose [1-10]: %s' "$COLOR_YELLOW" "$COLOR_RESET"
    read -r SELECTED_MENU_CHOICE
}

_bootstrap_menu() {
    local choice=""
    local status=0

    while true; do
        _select_bootstrap_menu_choice

        # dialog may return surrounding whitespace, a carriage return, or
        # quoted tags on some terminals/builds. Normalize the result before
        # dispatching it through the case statement.
        choice="$(
            printf '%s' "$SELECTED_MENU_CHOICE" |
                tr -d '\r\n' |
                sed -e 's/^[[:space:]]*//'                     -e 's/[[:space:]]*$//'                     -e 's/^"//'                     -e 's/"$//'
        )"

        status=0

        if [ "$choice" = 10 ]; then
            choice=quit
        elif [ "$choice" = 9 ] &&
             { ! command -v dialog >/dev/null 2>&1 ||
               [ ! -r /dev/tty ] ||
               [ ! -w /dev/tty ]; }; then
            choice=theme
        fi

        if [[ "$choice" =~ ^[1-9]$ ]]; then
            printf '\n%sSelected option %s%s\n' \
                "$COLOR_CYAN" "$choice" "$COLOR_RESET"
        fi

        case "$choice" in
            1)
                set +e
                _buildtoolchain
                status=$?
                set -e
                ;;
            2)
                set +e
                _run_root_stage 2
                status=$?
                set -e
                ;;
            3)
                set +e
                _run_root_stage 3
                status=$?
                set -e
                ;;
            4)
                set +e
                _verifybase
                status=$?
                set -e
                ;;
            5)
                set +e
                _compressrootfs
                status=$?
                set -e
                ;;
            6)
                set +e
                _restore_rootfs
                status=$?
                set -e
                ;;
            7)
                set +e
                _restore_toolchain
                status=$?
                set -e
                ;;
            8)
                set +e
                _enter_bfs_chroot
                status=$?
                set -e
                ;;
            settings)
                set +e
                _select_settings
                status=$?
                set -e
                continue
                ;;
            9|quit)
                echo "BFS bootstrap exited."
                return 0
                ;;
            *)
                echo
                echo "Invalid selection."
                sleep 1
                continue
                ;;
        esac

        echo
        if [ "$status" -eq 0 ]; then
            echo "Operation completed successfully."
        else
            echo "Operation failed with exit status $status."
        fi

        _pause_menu
    done
}

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

    if declare -F _close_active_package_log >/dev/null 2>&1; then
        _close_active_package_log "$status" 2>/dev/null || true
    fi

    if declare -F umountfs >/dev/null 2>&1; then
        umountfs 2>/dev/null || true
    fi

    rm -f "$PID_FILE"

    if [ -n "$DIALOGRC_FILE" ]; then
        rm -f "$DIALOGRC_FILE"
    fi

    if [ -n "$ORIGINAL_DIALOGRC" ]; then
        export DIALOGRC="$ORIGINAL_DIALOGRC"
    else
        unset DIALOGRC
    fi

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

_find_port_dir() {
    local package="$1"
    local normalized="${package%-pass*}"
    local match=""
    local -a matches=()

    while IFS= read -r match; do
        [ -n "$match" ] && matches+=("$match")
    done < <(
        find "$SCRIPT_DIR/ports" \
            -mindepth 2 \
            -maxdepth 2 \
            -type d \
            -name "$normalized" \
            -exec test -f '{}/Pkgfile' ';' \
            -print 2>/dev/null |
        sort
    )

    case "${#matches[@]}" in
        0)
            echo "ERROR: Port not found in any collection: $normalized" >&2
            return 1
            ;;
        1)
            printf '%s\n' "${matches[0]}"
            ;;
        *)
            echo "ERROR: Port exists in more than one collection: $normalized" >&2
            printf '  %s\n' "${matches[@]}" >&2
            return 1
            ;;
    esac
}

_validate_package_ports() {
    local package=""
    local port_dir=""

    for package in "$@"; do
        port_dir="$(_find_port_dir "$package")" || return 1
        printf '  %-28s %s\n' "$package" "${port_dir#$SCRIPT_DIR/}"
    done
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

    touch "$LFS/.bfs-toolchain-restored"

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

    touch "$LFS/.bfs-rootfs-restored"

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
export MAKEFLAGS=-j$BFS_BUILD_JOBS

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

        make -j"$BFS_BUILD_JOBS" -C /tmp/pkgutils-5.40.12

        make -j"$BFS_BUILD_JOBS" \
            -C /tmp/pkgutils-5.40.12 \
            BINDIR="$TOOLS/bin" \
            MANDIR="$TOOLS/man" \
            ETCDIR="$TOOLS/etc" \
            install

        rm -rf /tmp/pkgutils-5.40.12
    fi

    echo
    echo "Resolving temporary-toolchain ports across all collections..."
    # shellcheck disable=SC2086
    _validate_package_ports $toolchainpkg
    echo

    for i in $toolchainpkg; do
        local port_dir=""

        [ -f "$TOOLS/$i" ] && continue

        export tcpkg="$i"
        port_dir="$(_find_port_dir "$i")"

        cd "$port_dir"

        mkdir -p /tmp/lfs-pkg

        _start_package_log toolchain "$i"

        set +e
        pkgmk -d -is -if -cf /tmp/bootstrap.conf
        status=$?
        set -e

        _close_active_package_log "$status"

        if [ "$status" -ne 0 ]; then
            rm -rf /tmp/lfs-pkg
            cd "$SCRIPT_DIR"
            unset tcpkg
            return "$status"
        fi

        rm -rf /tmp/lfs-pkg

        cd "$SCRIPT_DIR"

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
    rm -f         "$LFS/.bfs-verified"         "$LFS/.bfs-rootfs-restored"

    echo
    echo "Resolving base-system ports across all collections..."
    # shellcheck disable=SC2086
    _validate_package_ports $basepkg
    echo

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

export JOBS=$BFS_BUILD_JOBS
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

export JOBS=$BFS_BUILD_JOBS
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

            _start_package_log base "$i"

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

            _close_active_package_log 0
        else
            _start_package_log base "$i"

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

            _close_active_package_log 0
        fi
    done

    if [ "${1:-}" != rebuild ]; then
        _copy_base_logs_into_rootfs
    fi

    umountfs

    if [ "${1:-}" = rebuild ]; then
        touch "$LFS/.bfs-stage3-complete"
    else
        touch "$LFS/.bfs-stage2-complete"
        rm -f "$LFS/.bfs-stage3-complete"
    fi

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
basepkg="aaa_filesystem linux-headers man-pages glibc autoconf zlib bzip2 xz file ncurses readline m4 bc binutils pkgconf libxcrypt gmp mpfr mpc attr acl gcc libcap psmisc sed tzdata iana-etc bison flex pcre2 grep bash libtool gdbm gperf expat inetutils perl perl-xml-parser intltool automake openssl ca-certificates curl gettext elfutils libffi sqlite python coreutils check diffutils gawk findutils groff less gzip zstd iptables libtirpc iproute2 kbd libpipeline make patch man-db tar texinfo python3-setuptools python3-pip python3-flit-core python3-packaging python3-installer python3-build python3-pyproject-hooks python3-wheel libuv cmake boost meson ninja kmod linux-pam shadow libpng which freetype fuse grub popt mandoc efivar efibootmgr grub-efi vim nano python3-markupsafe python3-tomli python3-pytz python3-babel python3-jinja2 systemd util-linux dbus procps-ng e2fsprogs libarchive pkgutils dialog prt-get httpup ports prt-utils lzo btrfs-progs dosfstools exfatprogs f2fs-tools mdadm libaio lvm2 inih liburcu xfsprogs openssh genfstab signify"
sourcedir="$PWD/sources"
packagedir="$PWD/packages"

pkgmkpkg="var/cache/pkg/packages"
pkgmksrc="var/cache/pkg/sources"

_setup_tui_theme

case "${1:-menu}" in
    menu|"")
        _bootstrap_menu
        ;;
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
    8|chroot)
        _enter_bfs_chroot
        ;;
    theme)
        _select_theme
        ;;
    settings)
        _select_settings
        ;;
    0|stop|kill)
        _stop_bootstrap
        ;;
    -h|--help|help)
        cat <<EOF
Usage:
  $0             Open the interactive bootstrap menu
  $0 menu        Open the interactive bootstrap menu
  $0 1-7         Run a bootstrap stage directly
  $0 8|chroot    Enter the BFS chroot
  $0 theme       Change interface theme
  $0 settings    Open build-system settings
  $0 0|stop|kill Stop a running bootstrap process group
EOF
        ;;
    *)
        echo "Unknown option: $1" >&2
        exit 1
        ;;
esac

exit 0
