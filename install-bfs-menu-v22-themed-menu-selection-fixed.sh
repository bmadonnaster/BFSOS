#!/usr/bin/env bash
set -Eeuo pipefail


# The live environment may advertise a UTF-8 locale that is not generated
# inside the installer or target chroot. Use the guaranteed POSIX locale for
# installer execution while keeping BFS_LOCALE as the locale selected for the
# installed system.
force_posix_locale() {
        unset LC_ALL
        unset LC_ADDRESS
        unset LC_COLLATE
        unset LC_CTYPE
        unset LC_IDENTIFICATION
        unset LC_MEASUREMENT
        unset LC_MESSAGES
        unset LC_MONETARY
        unset LC_NAME
        unset LC_NUMERIC
        unset LC_PAPER
        unset LC_TELEPHONE
        unset LC_TIME

        export LANG=C
        export LC_ALL=C
        export LANGUAGE=C
}

force_posix_locale

# BFS Linux installer
#
# Assumptions:
#   - Run from a Linux live environment as root.
#   - Partitions already exist; this script can optionally format them.
#   - A completed BFS rootfs archive is available.
#
# The installer resets /mnt/bfs, presents available partitions while each
# filesystem role is selected, optionally formats selected partitions, mounts
# the target layout, extracts BFS, configures the system, and installs GRUB.

TARGET="${BFS_TARGET:-/mnt/bfs}"
ARCHIVE="${BFS_ARCHIVE:-}"
ROOT_DEV="${BFS_ROOT_DEV:-}"
BOOT_DEV="${BFS_BOOT_DEV:-}"
EFI_DEV="${BFS_EFI_DEV:-}"
SWAP_DEV="${BFS_SWAP_DEV:-}"
HOME_DEV="${BFS_HOME_DEV:-}"
HOSTNAME="${BFS_HOSTNAME:-bfs}"
TIMEZONE="${BFS_TIMEZONE:-America/New_York}"
LOCALE="${BFS_LOCALE:-en_US.UTF-8}"
USERNAME="${BFS_USERNAME:-}"
ADDITIONAL_USERS=()
BOOT_MODE="${BFS_BOOT_MODE:-}"
BOOT_DISK="${BFS_BOOT_DISK:-}"
NETWORK_IFACE="${BFS_NETWORK_IFACE:-}"
NETWORK_MAC="${BFS_NETWORK_MAC:-}"
NETWORK_TARGET_NAME="${BFS_NETWORK_TARGET_NAME:-eth0}"

ROOT_FORMAT="keep"
BOOT_FORMAT="keep"
EFI_FORMAT="keep"
SWAP_FORMAT="keep"
HOME_FORMAT="keep"

KERNEL_PACKAGE="${BFS_KERNEL_PACKAGE:-linux}"
INSTALL_GRUB="${BFS_INSTALL_GRUB:-yes}"
SAVE_BASE_ARCHIVE="${BFS_SAVE_BASE_ARCHIVE:-yes}"
BASE_ARCHIVE_DIR="${BFS_BASE_ARCHIVE_DIR:-/var/cache/bfs/archives/base}"
ENABLE_OPENSSH="${BFS_ENABLE_OPENSSH:-${BFS_INSTALL_OPENSSH:-yes}}"
INSTALL_GIT="${BFS_INSTALL_GIT:-no}"
INSTALL_SUDO="${BFS_INSTALL_SUDO:-yes}"
SUDO_MODE="${BFS_SUDO_MODE:-password}"
INSTALL_WGET="${BFS_INSTALL_WGET:-yes}"
INSTALL_NETWORKMANAGER="${BFS_INSTALL_NETWORKMANAGER:-no}"
INSTALL_CRYPTSETUP="${BFS_INSTALL_CRYPTSETUP:-no}"
AUTO_CRYPTSETUP=no
AUTO_LVM2=no
AUTO_MDADM=no
KEEP_MOUNTS="${BFS_KEEP_MOUNTS:-no}"
FINAL_CHROOT="${BFS_FINAL_CHROOT:-no}"
GRUB_FALLBACK="${BFS_GRUB_FALLBACK:-no}"

DISKS_CONFIGURED=no
ARCHIVE_CONFIGURED=no
SYSTEM_CONFIGURED=no
USERS_CONFIGURED=no
KERNEL_CONFIGURED=no
NETWORK_CONFIGURED=no
PACKAGES_CONFIGURED=no
SUDO_CONFIGURED=no
BOOTLOADER_CONFIGURED=no
PARTITIONING_VISITED=optional

LOG_ENABLED="${BFS_LOG_ENABLED:-yes}"
LOG_FILE="${BFS_LOG_FILE:-}"
LOG_FIFO=""
LOG_TEE_PID=""
LOG_STDOUT_FD=3
LOG_STDERR_FD=4

MOUNTED_BY_SCRIPT=()
USED_DEVICES=()
EXTRA_DEVICES=()
EXTRA_MOUNTPOINTS=()
EXTRA_FORMATS=()
BTRFS_DEVICES=()
BTRFS_MOUNTPOINTS=()
BTRFS_SUBVOLUMES=()
BTRFS_SNAPSHOT_SUBVOLUMES=()
BTRFS_CONFIG_NAMES=()
AVAILABLE_PATHS=()
AVAILABLE_TYPES=()
AVAILABLE_SIZES=()
AVAILABLE_FSTYPES=()
AVAILABLE_LABELS=()
AVAILABLE_MOUNTPOINTS=()
AVAILABLE_NICS=()
AVAILABLE_NIC_MACS=()
AVAILABLE_NIC_STATES=()
AVAILABLE_NIC_DRIVERS=()
CHROOT_INSTALLER="/root/.bfs-install-chroot.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Keep installer logs beside the bootstrap logs, even when this script is
# stored in bfs-linux-install/scripts/.
if [[ "$(basename "$SCRIPT_DIR")" == scripts ]]; then
        PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
else
        PROJECT_DIR="$SCRIPT_DIR"
fi

INSTALLER_LOG_DIR="$PROJECT_DIR/logs/installer"
INSTALLER_SETTINGS_FILE="$SCRIPT_DIR/.bfs-installer-settings"
LOG_STARTED_EPOCH=""
LOG_CLOSED=no

mkdir -p "$INSTALLER_LOG_DIR"
DIALOGRC_FILE=""
ORIGINAL_DIALOGRC="${DIALOGRC-}"
BFS_THEME="${BFS_INSTALLER_THEME:-monochrome}"
SELECTED_MENU_CHOICE=""

load_installer_settings() {
        [[ -f "$INSTALLER_SETTINGS_FILE" ]] || return 0

        while IFS='=' read -r key value; do
                case "$key" in
                        BFS_THEME) BFS_THEME="$value" ;;
                        LOG_ENABLED) LOG_ENABLED="$value" ;;
                esac
        done < "$INSTALLER_SETTINGS_FILE"
}

save_installer_settings() {
        cat > "$INSTALLER_SETTINGS_FILE" <<EOF_SETTINGS
BFS_THEME=$BFS_THEME
LOG_ENABLED=$LOG_ENABLED
EOF_SETTINGS
}

write_dialog_theme_classic() {
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

write_dialog_theme_midnight() {
        cat > "$DIALOGRC_FILE" <<'EOF_DIALOGRC'
use_colors = ON
use_shadow = OFF
screen_color = (WHITE,BLACK,ON)
dialog_color = (BLACK,CYAN,ON)
title_color = (YELLOW,CYAN,ON)
border_color = (WHITE,CYAN,ON)
button_active_color = (WHITE,BLUE,ON)
button_inactive_color = (BLACK,CYAN,ON)
menubox_color = (BLACK,CYAN,ON)
menubox_border_color = (WHITE,CYAN,ON)
item_color = (BLACK,CYAN,ON)
item_selected_color = (WHITE,BLUE,ON)
tag_color = (YELLOW,CYAN,ON)
tag_selected_color = (YELLOW,BLUE,ON)
EOF_DIALOGRC
}

write_dialog_theme_light() {
        cat > "$DIALOGRC_FILE" <<'EOF_DIALOGRC'
use_colors = ON
use_shadow = OFF
screen_color = (BLACK,WHITE,ON)
dialog_color = (BLACK,WHITE,ON)
title_color = (BLUE,WHITE,ON)
border_color = (BLUE,WHITE,ON)
button_active_color = (WHITE,BLUE,ON)
button_inactive_color = (BLACK,WHITE,ON)
menubox_color = (BLACK,WHITE,ON)
menubox_border_color = (BLUE,WHITE,ON)
item_color = (BLACK,WHITE,ON)
item_selected_color = (WHITE,BLUE,ON)
tag_color = (BLUE,WHITE,ON)
tag_selected_color = (YELLOW,BLUE,ON)
EOF_DIALOGRC
}

write_dialog_theme_monochrome() {
        cat > "$DIALOGRC_FILE" <<'EOF_DIALOGRC'
use_colors = OFF
use_shadow = OFF
EOF_DIALOGRC
}

theme_display_name() {
        case "$BFS_THEME" in
                classic) printf '%s' "Classic Blue" ;;
                midnight) printf '%s' "Midnight" ;;
                light) printf '%s' "Light" ;;
                monochrome) printf '%s' "Monochrome" ;;
                *) printf '%s' "$BFS_THEME" ;;
        esac
}

setup_installer_theme() {
        [[ -z "$DIALOGRC_FILE" ]] || rm -f "$DIALOGRC_FILE"
        DIALOGRC_FILE="$(mktemp /tmp/bfs-installer-dialogrc.XXXXXX)"

        case "$BFS_THEME" in
                classic) write_dialog_theme_classic ;;
                midnight) write_dialog_theme_midnight ;;
                light) write_dialog_theme_light ;;
                monochrome) write_dialog_theme_monochrome ;;
                *) BFS_THEME=monochrome; write_dialog_theme_monochrome ;;
        esac

        export DIALOGRC="$DIALOGRC_FILE"
}

select_installer_theme() {
        local choice="" status=0

        if command -v dialog >/dev/null 2>&1 &&
           [[ -r /dev/tty && -w /dev/tty ]]; then
                set +e
                choice="$(
                        dialog --stdout --clear \
                                --backtitle "BFS Linux Installer" \
                                --title "Interface Theme" \
                                --radiolist \
                                "Choose the installer theme." \
                                17 66 5 \
                                monochrome "Best compatibility for SSH and unusual palettes" \
                                        "$([[ "$BFS_THEME" == monochrome ]] && echo on || echo off)" \
                                classic "Classic Blue — bootstrap-style dark-blue theme" \
                                        "$([[ "$BFS_THEME" == classic ]] && echo on || echo off)" \
                                midnight "Midnight Commander-style theme" \
                                        "$([[ "$BFS_THEME" == midnight ]] && echo on || echo off)" \
                                light "Black text on a light background" \
                                        "$([[ "$BFS_THEME" == light ]] && echo on || echo off)" \
                                </dev/tty
                )"
                status=$?
                set -e
                ((status == 0)) || return 0
        else
                echo "  1) Monochrome"
                echo "  2) Classic Blue"
                echo "  3) Midnight"
                echo "  4) Light"
                read -r -p "Choose [1-4, current: $(theme_display_name)]: " choice
                case "$choice" in
                        1) choice=monochrome ;;
                        2) choice=classic ;;
                        3) choice=midnight ;;
                        4) choice=light ;;
                        "") return 0 ;;
                        *) warn "Invalid theme selection."; return 1 ;;
                esac
        fi

        [[ -n "$choice" ]] || return 0
        BFS_THEME="$choice"
        setup_installer_theme
        save_installer_settings
}

installer_settings_menu() {
        local choice="" status=0

        while true; do
                if command -v dialog >/dev/null 2>&1 &&
                   [[ -r /dev/tty && -w /dev/tty ]]; then
                        set +e
                        choice="$(
                                dialog --stdout --clear \
                                        --backtitle "BFS Linux Installer" \
                                        --title "Installer Settings" \
                                        --cancel-label "Back" \
                                        --menu \
                                        "Configure the installer interface and logging." \
                                        16 72 5 \
                                        1 "Theme: $(theme_display_name)" \
                                        2 "Logging: $LOG_ENABLED" \
                                        3 "Back to main menu" \
                                        </dev/tty
                        )"
                        status=$?
                        set -e
                        ((status == 0)) || return 0
                else
                        clear_screen
                        echo "Installer Settings"
                        echo "=================="
                        echo
                        echo "  1) Theme: $(theme_display_name)"
                        echo "  2) Logging: $LOG_ENABLED"
                        echo "  3) Back"
                        read -r -p "Choose [1-3]: " choice
                fi

                case "$choice" in
                        1) select_installer_theme ;;
                        2)
                                [[ "$LOG_ENABLED" == yes ]] &&
                                        LOG_ENABLED=no || LOG_ENABLED=yes
                                save_installer_settings
                                ;;
                        3) return 0 ;;
                        *) warn "Invalid settings selection."; sleep 1 ;;
                esac
        done
}

dialog_status() {
        [[ "$1" == yes ]] && printf '%s' "CONFIGURED" || printf '%s' "PENDING"
}

installer_ready() {
        # Only filesystem/mount-point assignment is required for storage.
        # Visiting cfdisk, RAID, LUKS, or LVM menus is never required.
        [[ "$DISKS_CONFIGURED" == yes &&
           "$ARCHIVE_CONFIGURED" == yes &&
           "$SYSTEM_CONFIGURED" == yes &&
           "$USERS_CONFIGURED" == yes &&
           "$KERNEL_CONFIGURED" == yes &&
           "$NETWORK_CONFIGURED" == yes &&
           "$PACKAGES_CONFIGURED" == yes &&
           "$SUDO_CONFIGURED" == yes &&
           "$BOOTLOADER_CONFIGURED" == yes ]]
}

target_chroot_available() {
        [[ -x "$TARGET/bin/bash" || -x "$TARGET/usr/bin/bash" ]]
}

available_status() {
        if "$@"; then
                printf '%s' "AVAILABLE"
        else
                printf '%s' "PENDING"
        fi
}

dialog_menu_description() {
        printf '%-45s [%s]' "$1" "$2"
}

themed_menu() {
        local result_variable="$1"
        local title="$2"
        local prompt="$3"
        local height="$4"
        local width="$5"
        local menu_height="$6"
        shift 6

        # Do not call this local variable "choice". Bash uses dynamic scoping,
        # so a local choice here would hide the caller's choice variable and
        # prevent printf -v from returning the selected menu tag.
        local selected_value="" status=0 index=0
        local -a items=("$@")

        if command -v dialog >/dev/null 2>&1 &&
           [[ -r /dev/tty && -w /dev/tty ]]; then
                set +e
                selected_value="$(
                        dialog --stdout --clear \
                                --backtitle "BFS Linux Installer" \
                                --title "$title" \
                                --cancel-label "Back" \
                                --menu "$prompt" \
                                "$height" "$width" "$menu_height" \
                                "${items[@]}" \
                                </dev/tty
                )"
                status=$?
                set -e

                if ((status != 0)); then
                        printf -v "$result_variable" '%s' ""
                        return 1
                fi
        else
                clear_screen
                printf '%s\n' "$title"
                printf '%*s\n\n' "${#title}" '' | tr ' ' '='
                printf '%s\n\n' "$prompt"

                for ((index=0; index<${#items[@]}; index+=2)); do
                        printf '  %s) %s\n' \
                                "${items[$index]}" \
                                "${items[$((index + 1))]}"
                done

                printf '\n'
                read -r -p "Choose: " selected_value
        fi

        selected_value="$(
                printf '%s' "$selected_value" |
                        tr -d '\r\n' |
                        sed -e 's/^[[:space:]]*//' \
                            -e 's/[[:space:]]*$//' \
                            -e 's/^"//' \
                            -e 's/"$//'
        )"

        printf -v "$result_variable" '%s' "$selected_value"
        [[ -n "$selected_value" ]]
}

log() { printf '\n==> %s\n' "$*"; }
warn() { printf '\nWARNING: %s\n' "$*" >&2; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

clear_screen() {
        if command -v clear >/dev/null 2>&1; then
                clear
        else
                printf '\033[2J\033[H'
        fi
}

pause_screen() {
        printf '\n'
        read -r -p 'Press Enter to continue...' _
}

run_on_tty() {
        local status=0

        clear
        reset
        stty sane </dev/tty

        set +e
        "$@" </dev/tty >/dev/tty 2>/dev/tty
        status=$?
        set -e

        clear
        reset
        stty sane </dev/tty

        return "$status"
}

ask() {
        local variable="$1" prompt="$2" default="${3:-}" answer=""
        [[ -n "${!variable:-}" ]] && return 0
        if [[ -n "$default" ]]; then
                read -r -p "$prompt [$default]: " answer
                printf -v "$variable" '%s' "${answer:-$default}"
        else
                read -r -p "$prompt: " answer
                printf -v "$variable" '%s' "$answer"
        fi
}

ask_default() {
        local variable="$1" prompt="$2" default="$3" answer=""
        read -r -p "$prompt [$default]: " answer
        printf -v "$variable" '%s' "${answer:-$default}"
}

ask_yes_no() {
        local variable="$1" prompt="$2" default="${3:-no}" answer="" suffix="[y/N]"
        [[ "$default" == yes ]] && suffix="[Y/n]"
        read -r -p "$prompt $suffix: " answer
        answer="${answer,,}"
        if [[ -z "$answer" ]]; then
                printf -v "$variable" '%s' "$default"
        elif [[ "$answer" == y || "$answer" == yes ]]; then
                printf -v "$variable" '%s' yes
        else
                printf -v "$variable" '%s' no
        fi
}

confirm() {
        local answer=""
        read -r -p "$1 [y/N]: " answer
        [[ "${answer,,}" == y || "${answer,,}" == yes ]]
}

usage() {
        cat <<'USAGE'
Usage: install-bfs-menu-v22.sh [options]

The installer may be started as a regular user. It authenticates with sudo
once, then re-executes the full installer as root.

Options:
  --log                  Enable automatic logging (default)
  --no-log               Disable automatic logging
  --log-file PATH        Use PATH for the live-environment log
  -h, --help             Show this help
USAGE
}

parse_arguments() {
        while (($#)); do
                case "$1" in
                        --log)
                                LOG_ENABLED=yes
                                shift
                                ;;
                        --no-log)
                                LOG_ENABLED=no
                                shift
                                ;;
                        --log-file)
                                (($# >= 2)) || die "--log-file requires a path."
                                LOG_ENABLED=yes
                                LOG_FILE="$2"
                                shift 2
                                ;;
                        -h|--help)
                                usage
                                exit 0
                                ;;
                        *)
                                die "Unknown option: $1"
                                ;;
                esac
        done
}

setup_logging() {
        [[ "$LOG_ENABLED" == yes ]] || return 0

        mkdir -p "$INSTALLER_LOG_DIR"

        if [[ -z "$LOG_FILE" ]]; then
                LOG_FILE="$INSTALLER_LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log"
        elif [[ "$LOG_FILE" != /* ]]; then
                LOG_FILE="$INSTALLER_LOG_DIR/$LOG_FILE"
        fi

        mkdir -p "$(dirname "$LOG_FILE")"
        : > "$LOG_FILE"

        LOG_STARTED_EPOCH="$(date +%s)"
        LOG_CLOSED=no

        LOG_FIFO="$(mktemp -u /tmp/bfs-install-log.XXXXXX)"
        mkfifo "$LOG_FIFO"

        exec 3>&1 4>&2
        tee -a "$LOG_FILE" < "$LOG_FIFO" >&3 &
        LOG_TEE_PID=$!
        exec > "$LOG_FIFO" 2>&1

        printf '%s\n' '============================================================'
        printf '%s\n' 'BFS Linux Installer'
        printf 'Started:        %s\n' "$(date --iso-8601=seconds 2>/dev/null || date)"
        printf 'Script:         %s\n' "${BASH_SOURCE[0]}"
        printf 'Script path:    %s\n' "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${BASH_SOURCE[0]}")"
        printf 'Log file:       %s\n' "$LOG_FILE"
        printf 'Host:           %s\n' "$(hostname 2>/dev/null || printf unknown)"
        printf 'Kernel:         %s\n' "$(uname -r 2>/dev/null || printf unknown)"
        printf 'Architecture:   %s\n' "$(uname -m 2>/dev/null || printf unknown)"
        printf 'Installer PID:  %s\n' "$$"
        printf 'Target:         %s\n' "$TARGET"
        printf 'Locale runtime: LANG=%s LC_ALL=%s LANGUAGE=%s\n' \
                "${LANG:-}" "${LC_ALL:-}" "${LANGUAGE:-}"
        printf '%s\n' '============================================================'
}

close_logging() {
        local status="${1:-0}"
        local ended_epoch=""
        local elapsed=0
        local result="SUCCESS"

        [[ "$LOG_ENABLED" == yes ]] || return 0
        [[ "$LOG_CLOSED" == no ]] || return 0
        [[ -n "$LOG_TEE_PID" ]] || return 0

        ended_epoch="$(date +%s)"
        if [[ -n "$LOG_STARTED_EPOCH" ]]; then
                elapsed=$((ended_epoch - LOG_STARTED_EPOCH))
        fi

        [[ "$status" -eq 0 ]] || result="FAILED"

        printf '\n%s\n' '============================================================'
        printf 'Finished:       %s\n' "$(date --iso-8601=seconds 2>/dev/null || date)"
        printf 'Result:         %s\n' "$result"
        printf 'Exit status:    %s\n' "$status"
        printf 'Elapsed:        %02d:%02d:%02d\n' \
                "$((elapsed / 3600))" \
                "$(((elapsed % 3600) / 60))" \
                "$((elapsed % 60))"
        printf '%s\n' '============================================================'

        exec 1>&3 2>&4
        wait "$LOG_TEE_PID" 2>/dev/null || true
        rm -f "$LOG_FIFO"

        LOG_FIFO=""
        LOG_TEE_PID=""
        LOG_CLOSED=yes
}

copy_log_to_installed_system() {
        local installed_dir=""
        local installed_log=""

        [[ "$LOG_ENABLED" == yes && -f "$LOG_FILE" ]] || return 0
        [[ -d "$TARGET" ]] || return 0

        installed_dir="$TARGET/var/log/bfs/installer"
        mkdir -p "$installed_dir"

        installed_log="$installed_dir/$(basename "$LOG_FILE")"
        cp -f "$LOG_FILE" "$installed_log"
        chmod 0600 "$installed_log"

        printf 'Installed-system log: /var/log/bfs/installer/%s\n' \
                "$(basename "$LOG_FILE")"
}

require_root() {
        if [[ $EUID -eq 0 ]]; then
                force_posix_locale
                return 0
        fi

        command -v sudo >/dev/null 2>&1 ||
                die "This installer requires root privileges and sudo is unavailable."

        printf '\nThis installer requires root privileges.\n'
        printf 'Authenticating with sudo before the installer starts...\n'
        printf 'The complete installer session will then run as root.\n\n'

        sudo -v || die "sudo authentication failed."

        exec sudo \
                --preserve-env=TERM,BFS_INSTALLER_THEME,BFS_LOG_ENABLED,BFS_LOG_FILE \
                env \
                LANG=C \
                LC_ALL=C \
                LANGUAGE=C \
                "$0" "$@"
}

require_commands() {
        local command
        for command in mount umount mountpoint findmnt lsblk swapoff swapon tar chroot blkid sed awk grep install readlink sha256sum find sort head cut tee mkfifo mktemp date cp dirname; do
                command -v "$command" >/dev/null 2>&1 || die "Missing host command: $command"
        done
}

prepare_target_environment() {
        log "Preparing clean installer mount state"

        # A previous failed run may have left bind mounts nested under TARGET.
        if findmnt -Rrn "$TARGET" 2>/dev/null | grep -q .; then
                warn "Existing mounts were found under $TARGET; unmounting them."
                umount -R "$TARGET" 2>/dev/null || umount -Rl "$TARGET" 2>/dev/null || \
                        die "Could not unmount everything below $TARGET."
        fi

        if findmnt -Rrn "$TARGET" 2>/dev/null | grep -q .; then
                die "A filesystem is still mounted below $TARGET."
        fi

        # Live media normally does not need swap. Turning it all off prevents a
        # selected swap partition from remaining busy during mkswap.
        if swapon --noheadings --show=NAME 2>/dev/null | grep -q .; then
                log "Disabling active swap before partition selection"
                swapoff -a || die "Could not disable all active swap devices."
        fi

        mkdir -p "$TARGET"
}

is_used_device() {
        local wanted="$1" used
        for used in "${USED_DEVICES[@]}"; do
                [[ "$used" == "$wanted" ]] && return 0
        done
        return 1
}

get_available_partitions() {
        local path type size fstype label mountpoints
        AVAILABLE_PATHS=()
        AVAILABLE_TYPES=()
        AVAILABLE_SIZES=()
        AVAILABLE_FSTYPES=()
        AVAILABLE_LABELS=()
        AVAILABLE_MOUNTPOINTS=()
AVAILABLE_NICS=()
AVAILABLE_NIC_MACS=()
AVAILABLE_NIC_STATES=()
AVAILABLE_NIC_DRIVERS=()

        while read -r path type size fstype label mountpoints; do
                [[ "$type" == part || "$type" == lvm || "$type" == crypt || "$type" == raid* ]] || continue
                is_used_device "$path" && continue
                AVAILABLE_PATHS+=("$path")
                AVAILABLE_TYPES+=("$type")
                AVAILABLE_SIZES+=("${size:--}")
                AVAILABLE_FSTYPES+=("${fstype:--}")
                AVAILABLE_LABELS+=("${label:--}")
                AVAILABLE_MOUNTPOINTS+=("${mountpoints:--}")
        done < <(
                lsblk -prno PATH,TYPE,SIZE,FSTYPE,LABEL,MOUNTPOINTS |
                awk '{p=$1;t=$2;s=$3;f=$4;l=$5;$1=$2=$3=$4=$5="";sub(/^ +/,"");print p,t,s,f,l,$0}'
        )
}

show_available_partitions() {
        local index
        get_available_partitions

        printf '\nAvailable partitions not yet assigned:\n'
        printf '  %-4s %-24s %-9s %-10s %-12s %-16s %s\n' \
                NUM DEVICE TYPE SIZE FSTYPE LABEL MOUNTPOINTS

        for ((index=0; index<${#AVAILABLE_PATHS[@]}; index++)); do
                printf '  %-4d %-24s %-9s %-10s %-12s %-16s %s\n' \
                        "$((index + 1))" \
                        "${AVAILABLE_PATHS[$index]}" \
                        "${AVAILABLE_TYPES[$index]}" \
                        "${AVAILABLE_SIZES[$index]}" \
                        "${AVAILABLE_FSTYPES[$index]}" \
                        "${AVAILABLE_LABELS[$index]}" \
                        "${AVAILABLE_MOUNTPOINTS[$index]}"
        done
        printf '\n'
}

select_partition() {
        local variable="$1" prompt="$2" optional="${3:-no}" answer="" selected_index="" selected_device=""

        if [[ -n "${!variable:-}" ]]; then
                USED_DEVICES+=("${!variable}")
                return 0
        fi

        while true; do
                show_available_partitions
                ((${#AVAILABLE_PATHS[@]} > 0)) || die "No unassigned partitions are available."

                if [[ "$optional" == yes ]]; then
                        printf '  0) Skip this partition\n'
                        read -r -p "$prompt [0-${#AVAILABLE_PATHS[@]}]: " answer
                        [[ "${answer:-0}" == 0 ]] && {
                                printf -v "$variable" ''
                                return 0
                        }
                else
                        read -r -p "$prompt [1-${#AVAILABLE_PATHS[@]}]: " answer
                fi

                [[ "$answer" =~ ^[0-9]+$ ]] || {
                        warn "Enter a partition number from the list."
                        continue
                }

                ((answer >= 1 && answer <= ${#AVAILABLE_PATHS[@]})) || {
                        warn "That selection is outside the available range."
                        continue
                }

                selected_index=$((answer - 1))
                selected_device="${AVAILABLE_PATHS[$selected_index]}"
                printf -v "$variable" '%s' "$selected_device"
                USED_DEVICES+=("$selected_device")
                printf 'Selected %s: %s\n' "$prompt" "$selected_device"
                return 0
        done
}

choose_linux_format() {
        local variable="$1" device="$2" role="$3" choice=""
        [[ -n "$device" ]] || return 0
        cat <<EOF
Formatting choice for $role ($device):
  1) Keep the existing filesystem
  2) ext2
  3) ext4
  4) XFS
  5) Btrfs
  6) F2FS
EOF
        while true; do
                read -r -p "Choose [1-6] [1]: " choice
                case "${choice:-1}" in
                        1) printf -v "$variable" '%s' keep; printf 'Selected format for %s: keep existing filesystem\n' "$role"; break ;;
                        2) printf -v "$variable" '%s' ext2; printf 'Selected format for %s: ext2\n' "$role"; break ;;
                        3) printf -v "$variable" '%s' ext4; printf 'Selected format for %s: ext4\n' "$role"; break ;;
                        4) printf -v "$variable" '%s' xfs; printf 'Selected format for %s: XFS\n' "$role"; break ;;
                        5) printf -v "$variable" '%s' btrfs; printf 'Selected format for %s: Btrfs\n' "$role"; break ;;
                        6) printf -v "$variable" '%s' f2fs; printf 'Selected format for %s: F2FS\n' "$role"; break ;;
                        *) warn "Enter a number from 1 through 6." ;;
                esac
        done
}

choose_efi_format() {
        [[ -n "$EFI_DEV" ]] || return 0
        local choice=""

        cat <<EOF
EFI formatting choice for $EFI_DEV:
  1) Keep the existing filesystem
  2) Format as FAT32 with mkfs.fat -F 32
EOF

        while true; do
                read -r -p "Choose [1-2] [1]: " choice
                case "${choice:-1}" in
                        1)
                                EFI_FORMAT=keep
                                printf 'Selected EFI action: keep existing filesystem\n'
                                break
                                ;;
                        2)
                                EFI_FORMAT=vfat
                                printf 'Selected EFI action: format as FAT32\n'
                                break
                                ;;
                        *)
                                warn "Enter 1 to keep the filesystem or 2 to format it as FAT32."
                                ;;
                esac
        done
}

choose_swap_format() {
        [[ -n "$SWAP_DEV" ]] || return 0
        local choice=""

        cat <<EOF
Swap initialization choice for $SWAP_DEV:
  1) Keep the existing swap signature
  2) Reinitialize with mkswap
EOF

        while true; do
                read -r -p "Choose [1-2] [1]: " choice
                case "${choice:-1}" in
                        1)
                                SWAP_FORMAT=keep
                                printf 'Selected swap action: keep existing swap signature\n'
                                break
                                ;;
                        2)
                                SWAP_FORMAT=swap
                                printf 'Selected swap action: initialize with mkswap\n'
                                break
                                ;;
                        *)
                                warn "Enter 1 to keep the existing swap signature or 2 to run mkswap."
                                ;;
                esac
        done
}

collect_additional_partitions() {
        local answer="" device="" mountpoint="" format=""
        while true; do
                read -r -p "Add another filesystem partition? [y/N]: " answer
                [[ "${answer,,}" == y || "${answer,,}" == yes ]] || break
                device=""
                select_partition device "Device for the additional partition" no
                while true; do
                        read -r -p "Mount point (for example /var): " mountpoint
                        [[ "$mountpoint" == /* && "$mountpoint" != / && "$mountpoint" != /boot && "$mountpoint" != /boot/efi && "$mountpoint" != /home && "$mountpoint" != *'..'* ]] && break
                        warn "Use an absolute, non-reserved mount point such as /var or /srv."
                done
                format=keep
                choose_linux_format format "$device" "$mountpoint"
                EXTRA_DEVICES+=("$device")
                EXTRA_MOUNTPOINTS+=("$mountpoint")
                EXTRA_FORMATS+=("$format")
        done
}


get_available_nics() {
        local interface="" mac="" state="" driver=""

        AVAILABLE_NICS=()
        AVAILABLE_NIC_MACS=()
        AVAILABLE_NIC_STATES=()
        AVAILABLE_NIC_DRIVERS=()

        while IFS= read -r interface; do
                [[ "$interface" == lo ]] && continue
                [[ -d "/sys/class/net/$interface" ]] || continue

                mac="$(cat "/sys/class/net/$interface/address" 2>/dev/null || true)"
                state="$(cat "/sys/class/net/$interface/operstate" 2>/dev/null || printf '%s' unknown)"
                driver="$(basename "$(readlink -f "/sys/class/net/$interface/device/driver" 2>/dev/null || true)")"
                [[ -n "$driver" ]] || driver="-"

                AVAILABLE_NICS+=("$interface")
                AVAILABLE_NIC_MACS+=("${mac:--}")
                AVAILABLE_NIC_STATES+=("${state:--}")
                AVAILABLE_NIC_DRIVERS+=("$driver")
        done < <(
                find /sys/class/net -mindepth 1 -maxdepth 1 -printf '%f\n' 2>/dev/null |
                sort
        )
}

show_available_nics() {
        local index=""

        get_available_nics
        printf '\nAvailable network interfaces:\n'
        printf '  %-4s %-16s %-20s %-12s %s\n' NUM INTERFACE MAC STATE DRIVER

        for ((index=0; index<${#AVAILABLE_NICS[@]}; index++)); do
                printf '  %-4d %-16s %-20s %-12s %s\n' \
                        "$((index + 1))" \
                        "${AVAILABLE_NICS[$index]}" \
                        "${AVAILABLE_NIC_MACS[$index]}" \
                        "${AVAILABLE_NIC_STATES[$index]}" \
                        "${AVAILABLE_NIC_DRIVERS[$index]}"
        done
        printf '\n'
}

select_network_interface() {
        local answer="" selected_index=""

        if [[ -n "$NETWORK_IFACE" ]]; then
                [[ -d "/sys/class/net/$NETWORK_IFACE" ]] ||
                        die "Configured network interface does not exist: $NETWORK_IFACE"
                NETWORK_MAC="$(cat "/sys/class/net/$NETWORK_IFACE/address" 2>/dev/null || true)"
                return 0
        fi

        while true; do
                show_available_nics
                ((${#AVAILABLE_NICS[@]} > 0)) ||
                        die "No usable network interfaces were found."

                read -r -p "Select network interface [1-${#AVAILABLE_NICS[@]}]: " answer

                [[ "$answer" =~ ^[0-9]+$ ]] || {
                        warn "Enter a network-interface number from the list."
                        continue
                }

                ((answer >= 1 && answer <= ${#AVAILABLE_NICS[@]})) || {
                        warn "That selection is outside the available range."
                        continue
                }

                selected_index=$((answer - 1))
                NETWORK_IFACE="${AVAILABLE_NICS[$selected_index]}"
                NETWORK_MAC="${AVAILABLE_NIC_MACS[$selected_index]}"

                printf 'Selected network interface: %s (%s)\n' \
                        "$NETWORK_IFACE" "$NETWORK_MAC"
                return 0
        done
}


get_whole_disks() {
        lsblk -dpno NAME,SIZE,MODEL,TYPE |
        awk '$NF == "disk" {
                type=$NF
                $NF=""
                sub(/[[:space:]]+$/, "")
                print
        }'
}

partition_disks() {
        local choice="" disk="" index="" line="" status=0
        local -a disk_paths=()
        local -a disk_descriptions=()
        local -a menu_items=()

        command -v cfdisk >/dev/null 2>&1 || {
                warn "cfdisk is not available in this live environment."
                pause_screen
                return 0
        }

        while true; do
                disk_paths=()
                disk_descriptions=()
                menu_items=()

                while IFS= read -r line; do
                        [[ -n "$line" ]] || continue
                        disk="${line%% *}"
                        disk_paths+=("$disk")
                        disk_descriptions+=("$line")
                done < <(get_whole_disks)

                ((${#disk_paths[@]} > 0)) || {
                        warn "No whole disks were found."
                        pause_screen
                        return 0
                }

                for ((index=0; index<${#disk_paths[@]}; index++)); do
                        menu_items+=("$((index + 1))" "${disk_descriptions[$index]}")
                done
                menu_items+=("$(( ${#disk_paths[@]} + 1 ))" "Finished partitioning")

                set +e
                themed_menu choice \
                        "Partition disks" \
                        "Choose a disk to open with cfdisk, or finish without changing partitions." \
                        20 88 12 \
                        "${menu_items[@]}"
                status=$?
                set -e
                ((status == 0)) || return 0

                [[ "$choice" =~ ^[0-9]+$ ]] || {
                        warn "Choose a disk number from the menu."
                        sleep 1
                        continue
                }

                if ((choice == ${#disk_paths[@]} + 1)); then
                        return 0
                fi

                ((choice >= 1 && choice <= ${#disk_paths[@]})) || {
                        warn "That selection is outside the available range."
                        sleep 1
                        continue
                }

                disk="${disk_paths[$((choice - 1))]}"
                echo
                echo "Starting cfdisk for $disk..."
                echo "Changes are written only when you choose Write in cfdisk."
                echo

                if ! run_on_tty cfdisk "$disk"; then
                        warn "cfdisk exited with an error for $disk."
                        pause_screen
                fi

                command -v partprobe >/dev/null 2>&1 && partprobe "$disk" || true
                command -v udevadm >/dev/null 2>&1 && udevadm settle || true
                sleep 1
        done
}


list_raid_member_candidates() {
        lsblk -prno PATH,TYPE,SIZE,FSTYPE,MOUNTPOINTS |
        awk '
                ($2 == "disk" || $2 == "part" || $2 == "lvm" || $2 == "crypt") &&
                $5 == "" {
                        print
                }
        '
}

choose_raid_level() {
        local variable="$1"
        local choice="" status=0

        set +e
        themed_menu choice \
                "Select RAID level" \
                "Choose the software RAID layout." \
                20 76 10 \
                1 "Linear / JBOD — combines disks, no redundancy" \
                2 "RAID 0 — striping, performance, no redundancy" \
                3 "RAID 1 — mirroring and redundancy" \
                4 "RAID 4 — striping with dedicated parity" \
                5 "RAID 5 — striping with distributed parity" \
                6 "RAID 6 — striping with dual parity" \
                7 "RAID 10 — striped mirrors" \
                8 "Cancel"
        status=$?
        set -e
        ((status == 0)) || return 1

        case "$choice" in
                1) printf -v "$variable" '%s' linear ;;
                2) printf -v "$variable" '%s' 0 ;;
                3) printf -v "$variable" '%s' 1 ;;
                4) printf -v "$variable" '%s' 4 ;;
                5) printf -v "$variable" '%s' 5 ;;
                6) printf -v "$variable" '%s' 6 ;;
                7) printf -v "$variable" '%s' 10 ;;
                8) return 1 ;;
                *) warn "Choose a RAID level from the menu."; return 1 ;;
        esac
}


show_raid_level_summary() {
        local raid_level="$1"

        clear_screen
        echo "RAID selection summary"
        echo "======================"
        echo

        case "$raid_level" in
                linear)
                        cat <<'EOF_LINEAR'
RAID type     : Linear / JBOD
Minimum disks : 2
Layout        : Concatenation
Redundancy    : None
Performance   : Similar to a single disk
Usable space  : Sum of all member capacities
EOF_LINEAR
                        ;;
                0)
                        cat <<'EOF_RAID0'
RAID type     : RAID 0
Minimum disks : 2
Layout        : Striping
Redundancy    : None
Performance   : Excellent read and write performance
Usable space  : Sum of all member capacities
EOF_RAID0
                        ;;
                1)
                        cat <<'EOF_RAID1'
RAID type     : RAID 1
Minimum disks : 2
Layout        : Mirroring
Redundancy    : One complete mirrored copy
Performance   : Fast reads; writes similar to one disk
Usable space  : Capacity of the smallest member
EOF_RAID1
                        ;;
                4)
                        cat <<'EOF_RAID4'
RAID type     : RAID 4
Minimum disks : 3
Layout        : Striping with dedicated parity
Redundancy    : One drive may fail
Performance   : Fast reads; parity disk may limit writes
Usable space  : Capacity of N-1 members
EOF_RAID4
                        ;;
                5)
                        cat <<'EOF_RAID5'
RAID type     : RAID 5
Minimum disks : 3
Layout        : Striping with distributed parity
Redundancy    : One drive may fail
Performance   : Fast reads; good general-purpose writes
Usable space  : Capacity of N-1 members
EOF_RAID5
                        ;;
                6)
                        cat <<'EOF_RAID6'
RAID type     : RAID 6
Minimum disks : 4
Layout        : Striping with dual distributed parity
Redundancy    : Two drives may fail
Performance   : Fast reads; slower writes than RAID 5
Usable space  : Capacity of N-2 members
EOF_RAID6
                        ;;
                10)
                        cat <<'EOF_RAID10'
RAID type     : RAID 10
Minimum disks : 4
Layout        : Striping across mirrored pairs
Redundancy    : Multiple failures may be tolerated if mirrors remain intact
Performance   : Excellent read and write performance
Usable space  : Approximately 50% of total capacity
EOF_RAID10
                        ;;
                *)
                        warn "Unknown RAID level: $raid_level"
                        ;;
        esac

        pause_screen
}

minimum_raid_members() {
        case "$1" in
                linear|0|1) printf '%s\n' 2 ;;
                4|5)        printf '%s\n' 3 ;;
                6)          printf '%s\n' 4 ;;
                10)         printf '%s\n' 4 ;;
                *)          return 1 ;;
        esac
}

choose_raid_members() {
        local result_variable="$1"
        local minimum="$2"
        local choice=""
        local index=""
        local selected=""
        local candidate=""
        local already_selected=no
        local -a candidates=()
        local -a descriptions=()
        local -a selected_members=()

        while IFS= read -r line; do
                [[ -n "$line" ]] || continue
                candidate="${line%% *}"
                candidates+=("$candidate")
                descriptions+=("$line")
        done < <(list_raid_member_candidates)

        ((${#candidates[@]} >= minimum)) || {
                warn "At least $minimum unused block devices are required."
                return 1
        }

        while true; do
                clear_screen
                echo "Select RAID member devices"
                echo "=========================="
                echo
                echo "Selected: ${selected_members[*]:-none}"
                echo

                for ((index=0; index<${#candidates[@]}; index++)); do
                        printf '  %d) %s\n' \
                                "$((index + 1))" \
                                "${descriptions[$index]}"
                done

                printf '  %d) Finished selecting members\n' \
                        "$(( ${#candidates[@]} + 1 ))"
                printf '  %d) Cancel\n\n' \
                        "$(( ${#candidates[@]} + 2 ))"

                read -r -p "Choose [1-$(( ${#candidates[@]} + 2 ))]: " choice

                [[ "$choice" =~ ^[0-9]+$ ]] || {
                        warn "Enter a number from the list."
                        sleep 1
                        continue
                }

                if ((choice == ${#candidates[@]} + 1)); then
                        if ((${#selected_members[@]} < minimum)); then
                                warn "This RAID level requires at least $minimum members."
                                sleep 2
                                continue
                        fi

                        printf -v "$result_variable" '%s' "${selected_members[*]}"
                        return 0
                fi

                if ((choice == ${#candidates[@]} + 2)); then
                        return 1
                fi

                ((choice >= 1 && choice <= ${#candidates[@]})) || {
                        warn "That selection is outside the available range."
                        sleep 1
                        continue
                }

                selected="${candidates[$((choice - 1))]}"
                already_selected=no

                for candidate in "${selected_members[@]}"; do
                        if [[ "$candidate" == "$selected" ]]; then
                                already_selected=yes
                                break
                        fi
                done

                if [[ "$already_selected" == yes ]]; then
                        warn "$selected is already selected."
                        sleep 1
                        continue
                fi

                selected_members+=("$selected")
        done
}

assemble_raid_arrays() {
        clear_screen
        echo "Assemble existing RAID arrays"
        echo "============================="
        echo

        command -v mdadm >/dev/null 2>&1 || {
                warn "mdadm is not available in this live environment."
                pause_screen
                return 0
        }

        mdadm --assemble --scan ||
                warn "One or more RAID arrays could not be assembled."

        command -v udevadm >/dev/null 2>&1 &&
                udevadm settle || true

        echo
        cat /proc/mdstat 2>/dev/null || true
        pause_screen
}

create_raid_array() {
        local raid_level=""
        local minimum=""
        local member_string=""
        local array_device=""
        local -a members=()

        command -v mdadm >/dev/null 2>&1 || {
                warn "mdadm is not available in this live environment."
                pause_screen
                return 0
        }

        choose_raid_level raid_level || return 0
        minimum="$(minimum_raid_members "$raid_level")"

        show_raid_level_summary "$raid_level"
        choose_raid_members member_string "$minimum" || return 0
        read -r -a members <<< "$member_string"

        clear_screen
        echo "Create software RAID array"
        echo "=========================="
        echo
        echo "RAID level: $raid_level"
        echo "Members:    ${members[*]}"
        echo

        read -r -p "Array device [/dev/md0]: " array_device
        array_device="${array_device:-/dev/md0}"

        [[ "$array_device" =~ ^/dev/md[0-9]+$ ]] || {
                warn "Use an array device such as /dev/md0."
                pause_screen
                return 0
        }

        confirm "Create $array_device? Existing data on all selected members will be destroyed." || {
                echo "RAID creation cancelled."
                pause_screen
                return 0
        }

        if [[ "$raid_level" == linear ]]; then
                mdadm \
                        --create "$array_device" \
                        --level=linear \
                        --raid-devices="${#members[@]}" \
                        "${members[@]}"
        else
                mdadm \
                        --create "$array_device" \
                        --level="$raid_level" \
                        --raid-devices="${#members[@]}" \
                        "${members[@]}"
        fi

        command -v udevadm >/dev/null 2>&1 &&
                udevadm settle || true

        echo
        cat /proc/mdstat 2>/dev/null || true
        pause_screen
}

show_raid_details() {
        local array=""

        clear_screen
        echo "Software RAID status"
        echo "===================="
        echo

        cat /proc/mdstat 2>/dev/null || true

        if command -v mdadm >/dev/null 2>&1; then
                while IFS= read -r array; do
                        [[ -n "$array" ]] || continue
                        echo
                        echo "------------------------------------------------------------"
                        mdadm --detail "$array" 2>/dev/null || true
                done < <(
                        lsblk -prno PATH,TYPE |
                        awk '$2 ~ /^raid/ { print $1 }'
                )
        fi

        pause_screen
}

raid_menu() {
        local choice="" status=0

        while true; do
                set +e
                themed_menu choice \
                        "Software RAID" \
                        "Create, assemble, or inspect Linux software RAID arrays." \
                        17 74 7 \
                        1 "Assemble existing arrays" \
                        2 "Create a new array" \
                        3 "Show array status and details" \
                        4 "Return to Storage setup"
                status=$?
                set -e
                ((status == 0)) || return 0

                case "$choice" in
                        1) assemble_raid_arrays ;;
                        2) create_raid_array ;;
                        3) show_raid_details ;;
                        4) return 0 ;;
                        *) warn "Choose a valid RAID option."; sleep 1 ;;
                esac
        done
}

luks_menu() {
        local choice=""
        local device=""
        local mapping=""
        local status=0

        while true; do
                set +e
                themed_menu choice \
                        "LUKS encryption" \
                        "Create, open, or close encrypted block-device mappings." \
                        17 74 7 \
                        1 "Create a new LUKS container" \
                        2 "Open an existing LUKS container" \
                        3 "Close a mapped LUKS container" \
                        4 "Return to Storage setup"
                status=$?
                set -e
                ((status == 0)) || return 0

                case "$choice" in
                        1)
                                command -v cryptsetup >/dev/null 2>&1 || {
                                        warn "cryptsetup is unavailable."
                                        pause_screen
                                        continue
                                }
                                lsblk -fp
                                echo
                                read -r -p "Block device to encrypt: " device
                                [[ -b "$device" ]] || {
                                        warn "Not a block device: $device"
                                        pause_screen
                                        continue
                                }
                                confirm "Initialize $device as LUKS? Existing data will be destroyed." ||
                                        continue
                                run_on_tty cryptsetup luksFormat "$device"
                                read -r -p "Mapping name to open now [leave blank to skip]: " mapping
                                [[ -z "$mapping" ]] ||
                                        run_on_tty cryptsetup open "$device" "$mapping"
                                command -v udevadm >/dev/null 2>&1 &&
                                        udevadm settle || true
                                pause_screen
                                ;;
                        2)
                                command -v cryptsetup >/dev/null 2>&1 || {
                                        warn "cryptsetup is unavailable."
                                        pause_screen
                                        continue
                                }
                                lsblk -fp
                                echo
                                read -r -p "LUKS block device: " device
                                read -r -p "Mapping name: " mapping
                                run_on_tty cryptsetup open "$device" "$mapping"
                                command -v udevadm >/dev/null 2>&1 &&
                                        udevadm settle || true
                                pause_screen
                                ;;
                        3)
                                command -v cryptsetup >/dev/null 2>&1 || {
                                        warn "cryptsetup is unavailable."
                                        pause_screen
                                        continue
                                }
                                read -r -p "Mapping name to close: " mapping
                                cryptsetup close "$mapping"
                                pause_screen
                                ;;
                        4) return 0 ;;
                        *) warn "Choose a valid LUKS option."; sleep 1 ;;
                esac
        done
}

lvm_menu() {
        local choice=""
        local device=""
        local pv_list=""
        local vg_name=""
        local lv_name=""
        local lv_size=""
        local status=0
        local -a pv_array=()

        while true; do
                set +e
                themed_menu choice \
                        "LVM storage" \
                        "Create or inspect Linux Logical Volume Manager objects." \
                        18 74 8 \
                        1 "Create a physical volume" \
                        2 "Create a volume group" \
                        3 "Create a logical volume" \
                        4 "Show LVM devices" \
                        5 "Return to Storage setup"
                status=$?
                set -e
                ((status == 0)) || return 0

                case "$choice" in
                        1)
                                command -v pvcreate >/dev/null 2>&1 || {
                                        warn "LVM tools are unavailable."
                                        pause_screen
                                        continue
                                }
                                lsblk -fp
                                echo
                                read -r -p "Block device for the physical volume: " device
                                [[ -b "$device" ]] || {
                                        warn "Not a block device: $device"
                                        pause_screen
                                        continue
                                }
                                confirm "Initialize $device as an LVM physical volume?" ||
                                        continue
                                pvcreate "$device"
                                pause_screen
                                ;;
                        2)
                                command -v vgcreate >/dev/null 2>&1 || {
                                        warn "LVM tools are unavailable."
                                        pause_screen
                                        continue
                                }
                                pvs
                                echo
                                read -r -p "New volume-group name: " vg_name
                                read -r -p "Physical volume device(s), separated by spaces: " pv_list
                                read -r -a pv_array <<< "$pv_list"
                                vgcreate "$vg_name" "${pv_array[@]}"
                                pause_screen
                                ;;
                        3)
                                command -v lvcreate >/dev/null 2>&1 || {
                                        warn "LVM tools are unavailable."
                                        pause_screen
                                        continue
                                }
                                vgs
                                echo
                                read -r -p "Volume-group name: " vg_name
                                read -r -p "Logical-volume name: " lv_name
                                read -r -p "Size, for example 100G or 100%FREE: " lv_size
                                if [[ "$lv_size" == *%* ]]; then
                                        lvcreate -l "$lv_size" -n "$lv_name" "$vg_name"
                                else
                                        lvcreate -L "$lv_size" -n "$lv_name" "$vg_name"
                                fi
                                command -v udevadm >/dev/null 2>&1 &&
                                        udevadm settle || true
                                pause_screen
                                ;;
                        4)
                                pvs 2>/dev/null || true
                                echo
                                vgs 2>/dev/null || true
                                echo
                                lvs 2>/dev/null || true
                                pause_screen
                                ;;
                        5) return 0 ;;
                        *) warn "Choose a valid LVM option."; sleep 1 ;;
                esac
        done
}

storage_menu() {
        local choice="" status=0

        while true; do
                set +e
                themed_menu choice \
                        "Storage setup" \
                        "Use only the storage tools you need. Existing partitions may be assigned directly." \
                        21 84 11 \
                        1 "Partition disks with cfdisk (optional)" \
                        2 "Create or assemble software RAID (optional)" \
                        3 "Configure LUKS encryption (optional)" \
                        4 "Configure LVM (optional)" \
                        5 "Assign filesystems and mount points (required)" \
                        6 "Show current storage devices" \
                        7 "Return to main menu"
                status=$?
                set -e
                ((status == 0)) || return 0

                case "$choice" in
                        1) partition_disks ;;
                        2) raid_menu ;;
                        3) luks_menu ;;
                        4) lvm_menu ;;
                        5) configure_disks ;;
                        6) clear_screen; lsblk -fp; pause_screen ;;
                        7) return 0 ;;
                        *) warn "Choose a valid storage option."; sleep 1 ;;
                esac
        done
}

configure_disks() {
        clear_screen
        echo "Disk and filesystem setup"
        echo "========================="
        echo

        USED_DEVICES=()
        EXTRA_DEVICES=()
        EXTRA_MOUNTPOINTS=()
        EXTRA_FORMATS=()

        ROOT_DEV=""
        BOOT_DEV=""
        EFI_DEV=""
        SWAP_DEV=""
        HOME_DEV=""

        select_partition ROOT_DEV "Root filesystem device"
        choose_linux_format ROOT_FORMAT "$ROOT_DEV" "root filesystem (/)"

        select_partition BOOT_DEV "Separate /boot device" yes
        choose_linux_format BOOT_FORMAT "$BOOT_DEV" "/boot"

        select_partition EFI_DEV "EFI System Partition" yes
        choose_efi_format

        select_partition SWAP_DEV "Swap device" yes
        choose_swap_format

        select_partition HOME_DEV "Separate /home device" yes
        choose_linux_format HOME_FORMAT "$HOME_DEV" "/home"

        collect_additional_partitions

        DISKS_CONFIGURED=yes
        pause_screen
}

configure_archive() {
        local installer_dir=""
        local project_dir=""
        local archive_dir=""
        local default_archive=""
        local entered_archive=""

        clear_screen
        echo "Base archive"
        echo "============"
        echo

        installer_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

        # Support the installer being stored either in:
        #   bfs-linux-install/
        # or:
        #   bfs-linux-install/scripts/
        if [[ -d "$installer_dir/archives/base" ]]; then
                project_dir="$installer_dir"
        elif [[ -d "$installer_dir/../archives/base" ]]; then
                project_dir="$(cd "$installer_dir/.." && pwd)"
        elif [[ -n "${HOME:-}" &&
                -d "$HOME/bfs-linux-install/archives/base" ]]; then
                project_dir="$HOME/bfs-linux-install"
        else
                project_dir="$installer_dir"
        fi

        archive_dir="$project_dir/archives/base"

        if [[ -d "$archive_dir" ]]; then
                default_archive="$(
                        find "$archive_dir" \
                                -maxdepth 1 \
                                -type f \
                                \( \
                                        -name 'bfs-rootfs-*.tar.xz' -o \
                                        -name 'bfs-rootfs-*.tar.zst' -o \
                                        -name 'bfs-rootfs-*.tar.gz' \
                                \) \
                                -printf '%T@ %p
' 2>/dev/null |
                        sort -nr |
                        head -n1 |
                        cut -d' ' -f2-
                )" || true
        else
                warn "Base archive directory was not found:"
                warn "  $archive_dir"
        fi

        [[ -n "$ARCHIVE" ]] && default_archive="$ARCHIVE"

        while true; do
                if [[ -n "$default_archive" ]]; then
                        read -r -p \
                                "Path to BFS rootfs archive [$default_archive]: " \
                                entered_archive
                        ARCHIVE="${entered_archive:-$default_archive}"
                else
                        read -r -p \
                                "Path to BFS rootfs archive: " \
                                ARCHIVE
                fi

                [[ -n "$ARCHIVE" ]] || {
                        warn "Enter the path to a BFS rootfs archive."
                        continue
                }

                [[ -f "$ARCHIVE" ]] || {
                        warn "Archive file not found:"
                        warn "  $ARCHIVE"
                        continue
                }

                case "$ARCHIVE" in
                        *.tar.xz|*.tar.zst|*.tar.gz)
                                break
                                ;;
                        *)
                                warn "Expected a .tar.xz, .tar.zst, or .tar.gz archive."
                                ;;
                esac
        done

        ask_yes_no SAVE_BASE_ARCHIVE \
                "Save a copy of the BFS base archive on the installed system?" \
                "$SAVE_BASE_ARCHIVE"

        ARCHIVE_CONFIGURED=yes
        pause_screen
}
configure_system() {
        clear_screen
        echo "System settings"
        echo "==============="
        echo

        ask_default HOSTNAME "Hostname" "$HOSTNAME"
        ask_default TIMEZONE "Timezone" "$TIMEZONE"
        ask_default LOCALE "Locale (for example en_US.UTF-8)" "$LOCALE"

        SYSTEM_CONFIGURED=yes
        pause_screen
}

valid_username() {
        [[ "$1" =~ ^[a-z_][a-z0-9_-]*$ ]]
}

username_selected() {
        local wanted="$1"
        local existing=""

        [[ "$USERNAME" == "$wanted" ]] && return 0

        for existing in "${ADDITIONAL_USERS[@]}"; do
                [[ "$existing" == "$wanted" ]] && return 0
        done

        return 1
}

configure_users() {
        local answer=""
        local extra_user=""

        clear_screen
        echo "User accounts"
        echo "============="
        echo

        while true; do
                ask_default USERNAME "Primary regular username" "${USERNAME:-user}"
                valid_username "$USERNAME" && break
                warn "Invalid username."
        done

        ADDITIONAL_USERS=()

        while true; do
                read -r -p "Add another regular user? [y/N]: " answer
                [[ "${answer,,}" == y || "${answer,,}" == yes ]] || break

                while true; do
                        read -r -p "Additional username: " extra_user

                        if ! valid_username "$extra_user"; then
                                warn "Invalid username."
                                continue
                        fi

                        if username_selected "$extra_user"; then
                                warn "That username is already selected."
                                continue
                        fi

                        ADDITIONAL_USERS+=("$extra_user")
                        break
                done
        done

        USERS_CONFIGURED=yes
        pause_screen
}

configure_kernel() {
        local choice=""

        clear_screen
        echo "Kernel selection"
        echo "================"
        echo
        echo "  1) linux"
        echo "  2) linux-lts"
        echo "  3) Do not install a kernel"
        echo

        while true; do
                read -r -p "Choose [1-3] [1]: " choice

                case "${choice:-1}" in
                        1) KERNEL_PACKAGE=linux; break ;;
                        2) KERNEL_PACKAGE=linux-lts; break ;;
                        3) KERNEL_PACKAGE=none; break ;;
                        *) warn "Choose 1, 2, or 3." ;;
                esac
        done

        KERNEL_CONFIGURED=yes
        pause_screen
}

configure_networking() {
        clear_screen
        echo "Networking"
        echo "=========="
        echo

        select_network_interface
        ask_yes_no INSTALL_NETWORKMANAGER \
                "Use NetworkManager instead of systemd-networkd?" \
                "$INSTALL_NETWORKMANAGER"
        ask_yes_no ENABLE_OPENSSH \
                "Install and enable the OpenSSH server?" \
                "$ENABLE_OPENSSH"

        NETWORK_CONFIGURED=yes
        pause_screen
}

toggle_setting() {
        local variable="$1"

        if [[ "${!variable}" == yes ]]; then
                printf -v "$variable" '%s' no
        else
                printf -v "$variable" '%s' yes
        fi
}

selection_mark() {
        [[ "$1" == yes ]] && printf '[x]' || printf '[ ]'
}

configure_packages() {
        local choice=""

        while true; do
                clear_screen

                cat <<EOF_PACKAGES
Optional software
=================

  1) $(selection_mark "$INSTALL_GIT") git
  2) $(selection_mark "$INSTALL_WGET") wget
  3) $(selection_mark "$INSTALL_CRYPTSETUP") cryptsetup
  4) Done

EOF_PACKAGES
                read -r -p "Choose [1-4]: " choice

                case "$choice" in
                        1) toggle_setting INSTALL_GIT ;;
                        2) toggle_setting INSTALL_WGET ;;
                        3) toggle_setting INSTALL_CRYPTSETUP ;;
                        4)
                                PACKAGES_CONFIGURED=yes
                                return 0
                                ;;
                        *)
                                warn "Choose a number from 1 through 4."
                                sleep 1
                                ;;
                esac
        done
}

configure_sudo() {
        local choice=""

        clear_screen
        echo "Sudo configuration"
        echo "=================="
        echo
        echo "  1) Do not install sudo"
        echo "  2) Install sudo; wheel users must enter a password"
        echo "  3) Install sudo; wheel users do not need a password"
        echo

        while true; do
                read -r -p "Choose [1-3] [2]: " choice

                case "${choice:-2}" in
                        1)
                                INSTALL_SUDO=no
                                SUDO_MODE=disabled
                                break
                                ;;
                        2)
                                INSTALL_SUDO=yes
                                SUDO_MODE=password
                                break
                                ;;
                        3)
                                INSTALL_SUDO=yes
                                SUDO_MODE=nopasswd
                                break
                                ;;
                        *)
                                warn "Choose 1, 2, or 3."
                                ;;
                esac
        done

        SUDO_CONFIGURED=yes
        pause_screen
}

configure_bootloader() {
        clear_screen
        echo "Bootloader"
        echo "=========="
        echo

        if [[ -n "$EFI_DEV" || -d /sys/firmware/efi ]]; then
                BOOT_MODE=uefi
        else
                BOOT_MODE=bios
        fi

        echo "Detected boot mode: $BOOT_MODE"
        echo

        ask_yes_no INSTALL_GRUB \
                "Write and configure the GRUB bootloader?" \
                "$INSTALL_GRUB"

        if [[ "$INSTALL_GRUB" == yes && "$BOOT_MODE" == bios ]]; then
                ask_default BOOT_DISK \
                        "Whole disk for BIOS GRUB, for example /dev/sda" \
                        "$BOOT_DISK"
        fi

        if [[ "$INSTALL_GRUB" == yes && "$BOOT_MODE" == uefi ]]; then
                ask_yes_no GRUB_FALLBACK \
                        "Also install the EFI fallback loader (recommended for some MSI boards)?" \
                        "$GRUB_FALLBACK"
        fi

        BOOTLOADER_CONFIGURED=yes
        pause_screen
}

additional_users_text() {
        local user_name=""

        for user_name in "${ADDITIONAL_USERS[@]}"; do
                printf '%s ' "$user_name"
        done
}

menu_status() {
        [[ "$1" == yes ]] && printf configured || printf pending
}

show_main_menu() {
        clear_screen

        cat <<EOF_MENU
============================================================
                  BFS Linux Installer
============================================================

Configure each section, then select Install BFS.
The installer authenticates once and all installation actions run as root.

  1) Storage assignment         [$(menu_status "$DISKS_CONFIGURED")]
  2) Base archive               [$(menu_status "$ARCHIVE_CONFIGURED")]
  3) System settings            [$(menu_status "$SYSTEM_CONFIGURED")]
  4) User accounts              [$(menu_status "$USERS_CONFIGURED")]
  5) Kernel selection           [$(menu_status "$KERNEL_CONFIGURED")]
  6) Networking                 [$(menu_status "$NETWORK_CONFIGURED")]
  7) Optional software          [$(menu_status "$PACKAGES_CONFIGURED")]
  8) Sudo configuration         [$(menu_status "$SUDO_CONFIGURED")]
  9) Bootloader                 [$(menu_status "$BOOTLOADER_CONFIGURED")]
 10) Review selections          [AVAILABLE]
 11) Install BFS                 [$(available_status installer_ready)]
 12) Chroot into target          [$(available_status target_chroot_available)]
 13) Quit                        [EXIT]

EOF_MENU
}

chroot_into_target() {
        force_posix_locale
        clear_screen
        echo "Chroot into BFS target"
        echo "======================"
        echo

        [[ -n "$ROOT_DEV" ]] ||
                die "Configure the root filesystem first."

        if ! mountpoint -q "$TARGET"; then
                mount_target_filesystems
        fi

        [[ -x "$TARGET/bin/bash" || -x "$TARGET/usr/bin/bash" ]] || {
                warn "No Bash executable exists in $TARGET."
                warn "Install or extract BFS before entering the chroot."
                pause_screen
                return 0
        }

        mount_virtual_filesystems

        if [[ -e /etc/resolv.conf ]]; then
                rm -f "$TARGET/etc/resolv.conf"
                cp -L /etc/resolv.conf "$TARGET/etc/resolv.conf"
        fi

        KEEP_MOUNTS=yes

        echo "Entering $TARGET. Type exit to return to the installer."
        echo

        run_on_tty \
                chroot "$TARGET" /usr/bin/env -i \
                HOME=/root \
                TERM="${TERM:-linux}" \
                PATH=/usr/bin:/usr/sbin:/bin:/sbin \
                LANG=C \
                LC_ALL=C \
                /bin/bash --login

        KEEP_MOUNTS=no
        echo
        echo "Returned from the BFS chroot."
        pause_screen
}

installer_menu() {
        local choice="" status=0 error_file=""

        while true; do
                SELECTED_MENU_CHOICE=""

                if command -v dialog >/dev/null 2>&1 &&
                   [[ -r /dev/tty && -w /dev/tty ]]; then
                        error_file="$(mktemp /tmp/bfs-installer-dialog-error.XXXXXX)"

                        set +e
                        SELECTED_MENU_CHOICE="$(
                                dialog --stdout --clear \
                                        --backtitle "BFS Linux Installer" \
                                        --title "BFS Linux Installer" \
                                        --ok-label "Select" \
                                        --cancel-label "Quit" \
                                        --extra-button \
                                        --extra-label "Settings" \
                                        --menu \
                                        "Use Up/Down arrows and Enter, or type an option number.\n\nThe installer authenticates once with sudo and all installation actions run as root.\n\nUse Tab or Shift+Tab to move between Select, Quit, and Settings." \
                                        26 92 15 \
                                        1 "$(
                                                dialog_menu_description \
                                                        'Storage assignment' \
                                                        "$(dialog_status "$DISKS_CONFIGURED")"
                                        )" \
                                        2 "$(
                                                dialog_menu_description \
                                                        'Base archive' \
                                                        "$(dialog_status "$ARCHIVE_CONFIGURED")"
                                        )" \
                                        3 "$(
                                                dialog_menu_description \
                                                        'System settings' \
                                                        "$(dialog_status "$SYSTEM_CONFIGURED")"
                                        )" \
                                        4 "$(
                                                dialog_menu_description \
                                                        'User accounts' \
                                                        "$(dialog_status "$USERS_CONFIGURED")"
                                        )" \
                                        5 "$(
                                                dialog_menu_description \
                                                        'Kernel selection' \
                                                        "$(dialog_status "$KERNEL_CONFIGURED")"
                                        )" \
                                        6 "$(
                                                dialog_menu_description \
                                                        'Networking' \
                                                        "$(dialog_status "$NETWORK_CONFIGURED")"
                                        )" \
                                        7 "$(
                                                dialog_menu_description \
                                                        'Optional software' \
                                                        "$(dialog_status "$PACKAGES_CONFIGURED")"
                                        )" \
                                        8 "$(
                                                dialog_menu_description \
                                                        'Sudo configuration' \
                                                        "$(dialog_status "$SUDO_CONFIGURED")"
                                        )" \
                                        9 "$(
                                                dialog_menu_description \
                                                        'Bootloader' \
                                                        "$(dialog_status "$BOOTLOADER_CONFIGURED")"
                                        )" \
                                        10 "$(
                                                dialog_menu_description \
                                                        'Review selections' \
                                                        'AVAILABLE'
                                        )" \
                                        11 "$(
                                                dialog_menu_description \
                                                        'Install BFS (root)' \
                                                        "$(available_status installer_ready)"
                                        )" \
                                        12 "$(
                                                dialog_menu_description \
                                                        'Chroot into target (root)' \
                                                        "$(available_status target_chroot_available)"
                                        )" \
                                        13 "$(
                                                dialog_menu_description \
                                                        'Quit' \
                                                        'EXIT'
                                        )" \
                                        </dev/tty 2>"$error_file"
                        )"
                        status=$?
                        set -e

                        case "$status" in
                                0)
                                        choice="$SELECTED_MENU_CHOICE"
                                        ;;
                                1|255)
                                        choice=13
                                        ;;
                                3)
                                        choice=settings
                                        ;;
                                *)
                                        warn "Dialog failed; switching to the text menu."
                                        [[ ! -s "$error_file" ]] || cat "$error_file" >&2
                                        choice=""
                                        ;;
                        esac

                        rm -f "$error_file"
                fi

                if [[ -z "$choice" ]]; then
                        show_main_menu
                        read -r -p "Choose [1-14; 14=Settings]: " choice
                        [[ "$choice" == 14 ]] && choice=settings
                fi

                choice="$(
                        printf '%s' "$choice" |
                                tr -d '\r\n' |
                                sed -e 's/^[[:space:]]*//' \
                                    -e 's/[[:space:]]*$//' \
                                    -e 's/^"//' \
                                    -e 's/"$//'
                )"

                case "$choice" in
                        1)  storage_menu ;;
                        2)  configure_archive ;;
                        3)  configure_system ;;
                        4)  configure_users ;;
                        5)  configure_kernel ;;
                        6)  configure_networking ;;
                        7)  configure_packages ;;
                        8)  configure_sudo ;;
                        9)  configure_bootloader ;;
                        10) show_summary; pause_screen ;;
                        11)
                                if installer_ready; then
                                        return 0
                                fi

                                warn "Complete every configuration section before installing BFS."
                                pause_screen
                                ;;
                        12) chroot_into_target ;;
                        13)
                                echo "Installer exited."
                                exit 0
                                ;;
                        settings)
                                installer_settings_menu
                                ;;
                        *)
                                warn "Choose a valid installer option."
                                sleep 1
                                ;;
                esac

                choice=""
        done
}

validate_format_command() {
        local format="$1" command=""
        case "$format" in
                keep) return 0 ;;
                ext2) command=mkfs.ext2 ;;
                ext4) command=mkfs.ext4 ;;
                xfs) command=mkfs.xfs ;;
                btrfs) command=mkfs.btrfs ;;
                f2fs) command=mkfs.f2fs ;;
                vfat) command=mkfs.fat ;;
                swap) command=mkswap ;;
                *) die "Unknown format selection: $format" ;;
        esac
        command -v "$command" >/dev/null 2>&1 || die "Required formatting command is missing: $command"
}


selected_target_devices() {
        local device=""
        local index=""

        for device in \
                "$ROOT_DEV" \
                "$BOOT_DEV" \
                "$EFI_DEV" \
                "$SWAP_DEV" \
                "$HOME_DEV"
        do
                [[ -n "$device" ]] && printf '%s\n' "$device"
        done

        for ((index=0; index<${#EXTRA_DEVICES[@]}; index++)); do
                [[ -n "${EXTRA_DEVICES[$index]}" ]] &&
                        printf '%s\n' "${EXTRA_DEVICES[$index]}"
        done
}

device_ancestry_has_type() {
        local device="$1"
        local wanted="$2"
        local type=""

        [[ -b "$device" ]] || return 1

        while IFS= read -r type; do
                case "$wanted" in
                        raid)
                                [[ "$type" == raid* ]] && return 0
                                ;;
                        *)
                                [[ "$type" == "$wanted" ]] && return 0
                                ;;
                esac
        done < <(
                lsblk -s -nro TYPE "$device" 2>/dev/null || true
        )

        return 1
}

detect_storage_requirements() {
        local device=""

        AUTO_CRYPTSETUP=no
        AUTO_LVM2=no
        AUTO_MDADM=no

        while IFS= read -r device; do
                [[ -n "$device" ]] || continue

                if device_ancestry_has_type "$device" crypt; then
                        AUTO_CRYPTSETUP=yes
                        INSTALL_CRYPTSETUP=yes
                fi

                if device_ancestry_has_type "$device" lvm; then
                        AUTO_LVM2=yes
                fi

                if device_ancestry_has_type "$device" raid; then
                        AUTO_MDADM=yes
                fi
        done < <(selected_target_devices)
}

crypt_mapping_records() {
        local selected_device=""
        local path=""
        local type=""
        local mapping_name=""
        local parent_name=""
        local parent_device=""
        local luks_uuid=""
        local record=""
        local -a seen=()

        while IFS= read -r selected_device; do
                [[ -n "$selected_device" ]] || continue

                while read -r path type; do
                        [[ "$type" == crypt ]] || continue

                        mapping_name="$(basename "$path")"
                        parent_name="$(lsblk -dnro PKNAME "$path" 2>/dev/null || true)"
                        [[ -n "$parent_name" ]] || continue

                        parent_device="/dev/$parent_name"
                        luks_uuid="$(blkid -s UUID -o value "$parent_device" 2>/dev/null || true)"
                        [[ -n "$luks_uuid" ]] || continue

                        record="$mapping_name|$parent_device|$luks_uuid"

                        if printf '%s\n' "${seen[@]}" | grep -qxF "$record"; then
                                continue
                        fi

                        seen+=("$record")
                        printf '%s\n' "$record"
                done < <(
                        lsblk -s -prno PATH,TYPE "$selected_device" 2>/dev/null || true
                )
        done < <(selected_target_devices)
}

generate_crypttab() {
        local crypttab="$TARGET/etc/crypttab"
        local record=""
        local mapping_name=""
        local parent_device=""
        local luks_uuid=""
        local generated=0

        detect_storage_requirements

        if [[ "$AUTO_CRYPTSETUP" != yes ]]; then
                rm -f "$crypttab"
                return 0
        fi

        log "Generating /etc/crypttab"

        mkdir -p "$TARGET/etc"
        : > "$crypttab"

        while IFS='|' read -r mapping_name parent_device luks_uuid; do
                [[ -n "$mapping_name" && -n "$luks_uuid" ]] || continue

                printf '# %s\n' "$parent_device" >> "$crypttab"
                printf '%-24s UUID=%-36s none luks\n\n' \
                        "$mapping_name" "$luks_uuid" >> "$crypttab"
                generated=$((generated + 1))
        done < <(crypt_mapping_records)

        ((generated > 0)) ||
                die "Encrypted storage was detected, but no crypttab entries could be generated."

        chmod 0600 "$crypttab"
}

validate_settings() {
        detect_storage_requirements
        [[ "$DISKS_CONFIGURED" == yes ]] || die "Disk and filesystem setup is incomplete."
        [[ "$ARCHIVE_CONFIGURED" == yes ]] || die "Base archive selection is incomplete."
        [[ "$SYSTEM_CONFIGURED" == yes ]] || die "System settings are incomplete."
        [[ "$USERS_CONFIGURED" == yes ]] || die "User account setup is incomplete."
        [[ "$KERNEL_CONFIGURED" == yes ]] || die "Kernel selection is incomplete."
        [[ "$NETWORK_CONFIGURED" == yes ]] || die "Networking setup is incomplete."
        [[ "$PACKAGES_CONFIGURED" == yes ]] || die "Optional software selection is incomplete."
        [[ "$SUDO_CONFIGURED" == yes ]] || die "Sudo configuration is incomplete."
        [[ "$BOOTLOADER_CONFIGURED" == yes ]] || die "Bootloader setup is incomplete."
        [[ -b "$ROOT_DEV" ]] || die "Root device does not exist: $ROOT_DEV"
        [[ -f "$ARCHIVE" ]] || die "Rootfs archive does not exist: $ARCHIVE"
        [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]] || die "Invalid username: $USERNAME"
        [[ -d "/sys/class/net/$NETWORK_IFACE" ]] ||
                die "Network interface does not exist: $NETWORK_IFACE"
        [[ "$NETWORK_MAC" =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]] ||
                die "Invalid MAC address for $NETWORK_IFACE: $NETWORK_MAC"
        [[ "$NETWORK_TARGET_NAME" =~ ^[a-zA-Z0-9_.-]+$ ]] ||
                die "Invalid target network-interface name: $NETWORK_TARGET_NAME"
        local device index mountpoint
        for device in "$BOOT_DEV" "$EFI_DEV" "$SWAP_DEV" "$HOME_DEV"; do
                [[ -z "$device" || -b "$device" ]] || die "Device does not exist: $device"
        done
        for ((index=0; index<${#EXTRA_DEVICES[@]}; index++)); do
                device="${EXTRA_DEVICES[$index]}"; mountpoint="${EXTRA_MOUNTPOINTS[$index]}"
                [[ -b "$device" ]] || die "Additional partition does not exist: $device"
                [[ "$mountpoint" == /* && "$mountpoint" != *'..'* ]] || die "Invalid additional mount point: $mountpoint"
                validate_format_command "${EXTRA_FORMATS[$index]}"
        done
        validate_format_command "$ROOT_FORMAT"
        validate_format_command "$BOOT_FORMAT"
        validate_format_command "$EFI_FORMAT"
        validate_format_command "$SWAP_FORMAT"
        validate_format_command "$HOME_FORMAT"
        [[ "$BOOT_MODE" == uefi || "$BOOT_MODE" == bios ]] || die "Boot mode must be uefi or bios."
        if [[ "$INSTALL_GRUB" == yes ]]; then
                [[ "$BOOT_MODE" != uefi || -n "$EFI_DEV" ]] || die "UEFI GRUB requires an EFI partition."
                [[ "$BOOT_MODE" != bios || -b "$BOOT_DISK" ]] || die "BIOS GRUB requires a whole-disk target."
        fi
}

show_additional_partitions() {
        local index
        if ((${#EXTRA_DEVICES[@]} == 0)); then
                printf 'Additional mounts:   none\n'
                return
        fi
        printf 'Additional mounts:\n'
        for ((index=0; index<${#EXTRA_DEVICES[@]}; index++)); do
                printf '  %-18s %-24s format: %s\n' "${EXTRA_MOUNTPOINTS[$index]}" "${EXTRA_DEVICES[$index]}" "${EXTRA_FORMATS[$index]}"
        done
}

show_summary() {
        detect_storage_requirements
        cat <<SUMMARY

BFS installation summary
------------------------
Target:              $TARGET
Archive:             $ARCHIVE
Root:                $ROOT_DEV (format: $ROOT_FORMAT)
Boot:                ${BOOT_DEV:-inside root} (format: $BOOT_FORMAT)
EFI:                 ${EFI_DEV:-not used} (format: $EFI_FORMAT)
Swap:                ${SWAP_DEV:-not configured} (format: $SWAP_FORMAT)
Home:                ${HOME_DEV:-inside root} (format: $HOME_FORMAT)
$(show_additional_partitions)
Hostname:            $HOSTNAME
Timezone:            $TIMEZONE
Locale:              $LOCALE
Primary user:        $USERNAME
Additional users:    $(additional_users_text)
Boot mode:           $BOOT_MODE
GRUB disk:           ${BOOT_DISK:-not applicable}
Network interface:   $NETWORK_IFACE
Network MAC:         $NETWORK_MAC
Installed NIC name:  $NETWORK_TARGET_NAME
Kernel package:      $KERNEL_PACKAGE
Write/configure GRUB: $INSTALL_GRUB
Save base archive:   $SAVE_BASE_ARCHIVE
Archive save dir:    $BASE_ARCHIVE_DIR
Enable OpenSSH:      $ENABLE_OPENSSH
NetworkManager:      $INSTALL_NETWORKMANAGER
Git:                 $INSTALL_GIT
Sudo installed:      $INSTALL_SUDO
Sudo mode:           $SUDO_MODE
Wget:                $INSTALL_WGET
LUKS package:        $INSTALL_CRYPTSETUP
Encrypted targets:  $AUTO_CRYPTSETUP
LVM detected:       $AUTO_LVM2
mdraid detected:    $AUTO_MDADM
Console clears:      yes
Console blanking:    30 minutes
Coredump MaxUse:     5G
Btrfs snapshots:     automatic when formatted as Btrfs
SUMMARY
        local formatting_requested=no format
        for format in "$ROOT_FORMAT" "$BOOT_FORMAT" "$EFI_FORMAT" "$SWAP_FORMAT" "$HOME_FORMAT" "${EXTRA_FORMATS[@]}"; do
                [[ "$format" != keep ]] && formatting_requested=yes
        done
        if [[ "$formatting_requested" == yes ]]; then
                warn "Every partition marked for formatting will be erased."
        else
                printf '\nNo selected partition will be formatted.\n'
        fi
        [[ "$INSTALL_GRUB" == yes && "$KERNEL_PACKAGE" == none ]] && \
                warn "GRUB will be written and configured, but BFS will not install a kernel."
        confirm "Continue?" || die "Installation cancelled."
}

unmount_device_everywhere() {
        local device="$1" destination

        while IFS= read -r destination; do
                [[ -n "$destination" ]] || continue
                umount "$destination" || die "Could not unmount $device from $destination"
        done < <(findmnt -rn -S "$device" -o TARGET 2>/dev/null | sort -r || true)

        # An empty while loop otherwise returns a nonzero status under
        # set -E, which caused misleading ERR-trap reports at this function.
        return 0
}

format_device() {
        local device="$1" format="$2" role="$3"
        [[ -n "$device" && "$format" != keep ]] || return 0
        unmount_device_everywhere "$device"
        swapoff "$device" 2>/dev/null || true
        log "Formatting $device as $format for $role"
        case "$format" in
                ext2) mkfs.ext2 -F "$device" ;;
                ext4) mkfs.ext4 -F "$device" ;;
                xfs) mkfs.xfs -f "$device" ;;
                btrfs) mkfs.btrfs -f "$device" ;;
                f2fs) mkfs.f2fs -f "$device" ;;
                vfat) mkfs.fat -F 32 "$device" ;;
                swap) mkswap -f "$device" ;;
        esac
}


sanitize_btrfs_name() {
        local mountpoint="$1"
        local name="${mountpoint#/}"

        [[ -n "$name" ]] || {
                printf '%s\n' root
                return 0
        }

        name="${name//\//-}"
        name="${name//[^a-zA-Z0-9_.-]/-}"
        printf '%s\n' "$name"
}

register_btrfs_layout() {
        local device="$1" mountpoint="$2"
        local name="" data_subvol="" snapshot_subvol=""

        name="$(sanitize_btrfs_name "$mountpoint")"

        case "$mountpoint" in
                /)
                        data_subvol="@"
                        snapshot_subvol="@snapshots"
                        name=root
                        ;;
                /home)
                        data_subvol="@home"
                        snapshot_subvol="@home-snapshots"
                        name=home
                        ;;
                *)
                        data_subvol="@$name"
                        snapshot_subvol="@$name-snapshots"
                        ;;
        esac

        BTRFS_DEVICES+=("$device")
        BTRFS_MOUNTPOINTS+=("$mountpoint")
        BTRFS_SUBVOLUMES+=("$data_subvol")
        BTRFS_SNAPSHOT_SUBVOLUMES+=("$snapshot_subvol")
        BTRFS_CONFIG_NAMES+=("$name")
}

prepare_btrfs_subvolumes() {
        local index="" device="" data_subvol="" snapshot_subvol="" temp_mount=""

        BTRFS_DEVICES=()
        BTRFS_MOUNTPOINTS=()
        BTRFS_SUBVOLUMES=()
        BTRFS_SNAPSHOT_SUBVOLUMES=()
        BTRFS_CONFIG_NAMES=()

        [[ "$ROOT_FORMAT" == btrfs ]] && register_btrfs_layout "$ROOT_DEV" /
        [[ "$HOME_FORMAT" == btrfs ]] && register_btrfs_layout "$HOME_DEV" /home

        for ((index=0; index<${#EXTRA_DEVICES[@]}; index++)); do
                [[ "${EXTRA_FORMATS[$index]}" == btrfs ]] || continue
                register_btrfs_layout \
                        "${EXTRA_DEVICES[$index]}" \
                        "${EXTRA_MOUNTPOINTS[$index]}"
        done

        ((${#BTRFS_DEVICES[@]} > 0)) || return 0
        command -v btrfs >/dev/null 2>&1 ||
                die "The btrfs command is required for automatic snapshots."

        log "Creating Btrfs data and snapshot subvolumes"

        for ((index=0; index<${#BTRFS_DEVICES[@]}; index++)); do
                device="${BTRFS_DEVICES[$index]}"
                data_subvol="${BTRFS_SUBVOLUMES[$index]}"
                snapshot_subvol="${BTRFS_SNAPSHOT_SUBVOLUMES[$index]}"
                temp_mount="$(mktemp -d /tmp/bfs-btrfs.XXXXXX)"

                mount "$device" "$temp_mount"
                [[ -e "$temp_mount/$data_subvol" ]] ||
                        btrfs subvolume create "$temp_mount/$data_subvol"
                [[ -e "$temp_mount/$snapshot_subvol" ]] ||
                        btrfs subvolume create "$temp_mount/$snapshot_subvol"
                umount "$temp_mount"
                rmdir "$temp_mount"
        done
}

btrfs_layout_index_for_mountpoint() {
        local wanted="$1" index=""

        for ((index=0; index<${#BTRFS_MOUNTPOINTS[@]}; index++)); do
                if [[ "${BTRFS_MOUNTPOINTS[$index]}" == "$wanted" ]]; then
                        printf '%s\n' "$index"
                        return 0
                fi
        done

        return 1
}

mount_btrfs_layout() {
        local device="$1" destination="$2" mountpoint_name="$3"
        local index="" snapshot_destination=""

        index="$(btrfs_layout_index_for_mountpoint "$mountpoint_name")" ||
                return 1

        mkdir -p "$destination"
        mount -o "subvol=${BTRFS_SUBVOLUMES[$index]}" "$device" "$destination"
        record_mount "$destination"

        snapshot_destination="$destination/.snapshots"
        mkdir -p "$snapshot_destination"
        mount -o "subvol=${BTRFS_SNAPSHOT_SUBVOLUMES[$index]}" \
                "$device" "$snapshot_destination"
        record_mount "$snapshot_destination"

        return 0
}

format_selected_partitions() {
        local index
        format_device "$ROOT_DEV" "$ROOT_FORMAT" / 
        format_device "$BOOT_DEV" "$BOOT_FORMAT" /boot
        format_device "$EFI_DEV" "$EFI_FORMAT" /boot/efi
        format_device "$SWAP_DEV" "$SWAP_FORMAT" swap
        format_device "$HOME_DEV" "$HOME_FORMAT" /home
        for ((index=0; index<${#EXTRA_DEVICES[@]}; index++)); do
                format_device "${EXTRA_DEVICES[$index]}" "${EXTRA_FORMATS[$index]}" "${EXTRA_MOUNTPOINTS[$index]}"
        done

        prepare_btrfs_subvolumes
}

record_mount() { MOUNTED_BY_SCRIPT+=("$1"); }

mount_device() {
        local device="$1" destination="$2"
        [[ -n "$device" ]] || return 0
        mkdir -p "$destination"
        mountpoint -q "$destination" && die "$destination unexpectedly remained mounted."
        mount "$device" "$destination"
        record_mount "$destination"
}

mount_target_filesystems() {
        local index="" device="" mountpoint_name=""

        log "Mounting target filesystems"

        for device in "$ROOT_DEV" "$BOOT_DEV" "$EFI_DEV" "$HOME_DEV" "${EXTRA_DEVICES[@]}"; do
                [[ -n "$device" ]] && unmount_device_everywhere "$device"
        done

        mkdir -p "$TARGET"

        if ! mount_btrfs_layout "$ROOT_DEV" "$TARGET" /; then
                mount_device "$ROOT_DEV" "$TARGET"
        fi

        [[ -z "$BOOT_DEV" ]] || mount_device "$BOOT_DEV" "$TARGET/boot"
        [[ "$BOOT_MODE" != uefi ]] || mount_device "$EFI_DEV" "$TARGET/boot/efi"

        if [[ -n "$HOME_DEV" ]]; then
                if ! mount_btrfs_layout "$HOME_DEV" "$TARGET/home" /home; then
                        mount_device "$HOME_DEV" "$TARGET/home"
                fi
        fi

        for ((index=0; index<${#EXTRA_DEVICES[@]}; index++)); do
                device="${EXTRA_DEVICES[$index]}"
                mountpoint_name="${EXTRA_MOUNTPOINTS[$index]}"

                if ! mount_btrfs_layout \
                        "$device" "$TARGET$mountpoint_name" "$mountpoint_name"
                then
                        mount_device "$device" "$TARGET$mountpoint_name"
                fi
        done

        [[ -z "$SWAP_DEV" ]] || swapon "$SWAP_DEV"
}

mount_virtual_filesystems() {
        log "Mounting virtual filesystems"
        mkdir -p "$TARGET"/{dev,dev/pts,proc,sys,run}
        if ! mountpoint -q "$TARGET/dev"; then mount --bind /dev "$TARGET/dev"; record_mount "$TARGET/dev"; fi
        if ! mountpoint -q "$TARGET/dev/pts"; then mount -t devpts devpts "$TARGET/dev/pts" -o gid=5,mode=620; record_mount "$TARGET/dev/pts"; fi
        if ! mountpoint -q "$TARGET/proc"; then mount -t proc proc "$TARGET/proc"; record_mount "$TARGET/proc"; fi
        if ! mountpoint -q "$TARGET/sys"; then mount -t sysfs sysfs "$TARGET/sys"; record_mount "$TARGET/sys"; fi
        if ! mountpoint -q "$TARGET/run"; then mount -t tmpfs tmpfs "$TARGET/run"; record_mount "$TARGET/run"; fi
        if [[ -L "$TARGET/dev/shm" ]]; then mkdir -p "$TARGET/$(readlink "$TARGET/dev/shm")"; else mkdir -p "$TARGET/dev/shm"; fi
        if [[ "$BOOT_MODE" == uefi && -d /sys/firmware/efi/efivars ]]; then
                mkdir -p "$TARGET/sys/firmware/efi/efivars"
                if ! mountpoint -q "$TARGET/sys/firmware/efi/efivars"; then
                        mount --bind /sys/firmware/efi/efivars "$TARGET/sys/firmware/efi/efivars"
                        record_mount "$TARGET/sys/firmware/efi/efivars"
                fi
        fi
}

cleanup() {
        local status=$?
        local index destination

        # Preserve a complete failure log before target filesystems are
        # unmounted. Successful runs close and copy the log in main().
        if [[ "$LOG_ENABLED" == yes && "$LOG_CLOSED" == no ]]; then
                close_logging "$status" || true
                copy_log_to_installed_system || true
        fi

        rm -f "$TARGET$CHROOT_INSTALLER" 2>/dev/null || true

        [[ -z "$DIALOGRC_FILE" ]] || rm -f "$DIALOGRC_FILE"

        if [[ -n "$ORIGINAL_DIALOGRC" ]]; then
                export DIALOGRC="$ORIGINAL_DIALOGRC"
        else
                unset DIALOGRC
        fi
        [[ "$KEEP_MOUNTS" == yes ]] && return 0
        for ((index=${#MOUNTED_BY_SCRIPT[@]}-1; index>=0; index--)); do
                destination="${MOUNTED_BY_SCRIPT[$index]}"
                mountpoint -q "$destination" && umount "$destination" 2>/dev/null || true
        done
        [[ -z "$SWAP_DEV" ]] || swapoff "$SWAP_DEV" 2>/dev/null || true

        return "$status"
}

trap cleanup EXIT
trap 'die "Installation stopped near line $LINENO."' ERR

path_is_or_contains_mount() {
        local path="$1" mounted_target=""

        while IFS= read -r mounted_target; do
                [[ "$mounted_target" == "$path" || "$mounted_target" == "$path/"* ]] && return 0
        done < <(findmnt -Rrn -o TARGET "$TARGET" 2>/dev/null || true)

        return 1
}

extract_rootfs() {
        local entry has_existing_content=no
        log "Extracting BFS root filesystem"

        while IFS= read -r -d '' entry; do
                [[ "$(basename "$entry")" == lost+found ]] && continue

                # Ignore directories created solely to host selected filesystems.
                # This includes direct mounts such as /home and /var, and parent
                # directories such as /boot when only /boot/efi is mounted.
                path_is_or_contains_mount "$entry" && continue

                has_existing_content=yes
                break
        done < <(find "$TARGET" -mindepth 1 -maxdepth 1 -print0)

        if [[ "$has_existing_content" == yes ]]; then
                warn "$TARGET contains existing files."
                confirm "Extract into it anyway?" || die "Installation cancelled."
        fi

        tar --xattrs --acls --numeric-owner -xpf "$ARCHIVE" -C "$TARGET"
}

save_base_archive() {
        local archive_name destination
        [[ "$SAVE_BASE_ARCHIVE" == yes ]] || return 0

        archive_name="$(basename "$ARCHIVE")"
        destination="$TARGET$BASE_ARCHIVE_DIR"

        log "Saving BFS base archive"
        mkdir -p "$destination"
        if [[ "$(readlink -f "$ARCHIVE")" != "$(readlink -m "$destination/$archive_name")" ]]; then
                cp -f "$ARCHIVE" "$destination/$archive_name"
        fi

        (
                cd "$destination"
                sha256sum "$archive_name" > "$archive_name.sha256"
        )

        log "Saved base archive to $BASE_ARCHIVE_DIR/$archive_name"
}

device_is_nonrotational() {
        local device="$1"
        local rota=""

        rota="$(lsblk -dnro ROTA "$device" 2>/dev/null | head -n1 || true)"
        [[ "$rota" == 0 ]]
}

fstab_mount_options() {
        local device="$1"
        local fstype="$2"

        case "$fstype" in
                vfat|fat|msdos)
                        printf '%s\n' defaults
                        ;;
                ext2|ext3|ext4|xfs|btrfs|f2fs)
                        if device_is_nonrotational "$device"; then
                                printf '%s\n' defaults,discard
                        else
                                printf '%s\n' defaults
                        fi
                        ;;
                *)
                        printf '%s\n' defaults
                        ;;
        esac
}

write_fstab_entry() {
        local fstab="$1" device="$2" mountpoint="$3" pass="$4"
        local subvol="${5:-}" uuid="" fstype="" options=""

        [[ -n "$device" ]] || return 0

        uuid="$(blkid -s UUID -o value "$device" 2>/dev/null || true)"
        fstype="$(blkid -s TYPE -o value "$device" 2>/dev/null || true)"

        [[ -n "$uuid" ]] || die "Could not determine UUID for $device."
        [[ -n "$fstype" ]] || die "Could not determine filesystem type for $device."

        options="$(fstab_mount_options "$device" "$fstype")"
        [[ -z "$subvol" ]] || options="$options,subvol=$subvol"

        printf '# %s\n' "$device" >> "$fstab"
        printf 'UUID=%-36s %-20s %-8s %-36s 0 %s\n\n' \
                "$uuid" "$mountpoint" "$fstype" "$options" "$pass" >> "$fstab"
}

write_btrfs_fstab_layout() {
        local fstab="$1" mountpoint_name="$2"
        local index="" device="" snapshot_mountpoint=""

        index="$(btrfs_layout_index_for_mountpoint "$mountpoint_name")" ||
                return 1

        device="${BTRFS_DEVICES[$index]}"
        snapshot_mountpoint="$mountpoint_name/.snapshots"
        [[ "$mountpoint_name" == / ]] && snapshot_mountpoint="/.snapshots"

        write_fstab_entry \
                "$fstab" "$device" "$mountpoint_name" 0 \
                "${BTRFS_SUBVOLUMES[$index]}"
        write_fstab_entry \
                "$fstab" "$device" "$snapshot_mountpoint" 0 \
                "${BTRFS_SNAPSHOT_SUBVOLUMES[$index]}"

        return 0
}


validate_fstab_syntax() {
        local fstab="$1"

        awk '
                /^[[:space:]]*($|#)/ {
                        next
                }

                NF != 6 {
                        printf "Invalid fstab field count on line %d: %s\n", NR, $0 > "/dev/stderr"
                        failed=1
                        next
                }

                $1 !~ /^(UUID=|LABEL=|PARTUUID=|PARTLABEL=|\/dev\/)/ {
                        printf "Invalid fstab source on line %d: %s\n", NR, $1 > "/dev/stderr"
                        failed=1
                }

                $2 != "none" && $2 !~ /^\// {
                        printf "Invalid fstab target on line %d: %s\n", NR, $2 > "/dev/stderr"
                        failed=1
                }

                $3 == "" || $4 == "" {
                        printf "Missing filesystem type or options on line %d\n", NR > "/dev/stderr"
                        failed=1
                }

                $5 !~ /^[0-9]+$/ || $6 !~ /^[0-9]+$/ {
                        printf "Invalid dump/pass fields on line %d: %s %s\n", NR, $5, $6 > "/dev/stderr"
                        failed=1
                }

                END {
                        exit failed
                }
        ' "$fstab"
}

generate_fstab() {
        local fstab="$TARGET/etc/fstab"
        local index="" uuid=""

        log "Generating clean /etc/fstab"
        mkdir -p "$TARGET/etc"
        : > "$fstab"

        if ! write_btrfs_fstab_layout "$fstab" /; then
                write_fstab_entry "$fstab" "$ROOT_DEV" / 1
        fi

        write_fstab_entry "$fstab" "$BOOT_DEV" /boot 2

        if [[ "$BOOT_MODE" == uefi ]]; then
                write_fstab_entry "$fstab" "$EFI_DEV" /boot/efi 2
        fi

        if [[ -n "$HOME_DEV" ]]; then
                if ! write_btrfs_fstab_layout "$fstab" /home; then
                        write_fstab_entry "$fstab" "$HOME_DEV" /home 2
                fi
        fi

        for ((index=0; index<${#EXTRA_DEVICES[@]}; index++)); do
                if ! write_btrfs_fstab_layout "$fstab" "${EXTRA_MOUNTPOINTS[$index]}"; then
                        write_fstab_entry \
                                "$fstab" \
                                "${EXTRA_DEVICES[$index]}" \
                                "${EXTRA_MOUNTPOINTS[$index]}" \
                                2
                fi
        done

        if [[ -n "$SWAP_DEV" ]]; then
                uuid="$(blkid -s UUID -o value "$SWAP_DEV" 2>/dev/null || true)"
                [[ -n "$uuid" ]] || die "Could not determine swap UUID for $SWAP_DEV."
                printf '# %s\n' "$SWAP_DEV" >> "$fstab"
                printf 'UUID=%-36s %-16s %-8s %-20s 0 0\n' \
                        "$uuid" none swap sw >> "$fstab"
        fi

        validate_fstab_syntax "$fstab" ||
                die "Generated fstab failed syntax validation."

        log "Generated /etc/fstab passed syntax validation"
}


build_package_list() {
        local packages=()

        [[ "$KERNEL_PACKAGE" != none ]] && packages+=("$KERNEL_PACKAGE")
        [[ "$INSTALL_NETWORKMANAGER" == yes ]] && packages+=(networkmanager)
        [[ "$INSTALL_CRYPTSETUP" == yes || "$AUTO_CRYPTSETUP" == yes ]] && packages+=(cryptsetup)
        [[ "$AUTO_LVM2" == yes ]] && packages+=(lvm2)
        [[ "$AUTO_MDADM" == yes ]] && packages+=(mdadm)
        [[ "$INSTALL_GIT" == yes ]] && packages+=(git)
        [[ "$INSTALL_SUDO" == yes ]] && packages+=(sudo)
        [[ "$INSTALL_WGET" == yes ]] && packages+=(wget)
        [[ "$ENABLE_OPENSSH" == yes ]] && packages+=(openssh)
        if ((${#BTRFS_DEVICES[@]} > 0)); then
                packages+=(snapper)
        fi

        if ((${#packages[@]} > 0)); then
                printf '%s
' "${packages[@]}" |
                        awk '!seen[$0]++' |
                        tr '
' ' '
        fi
}

write_chroot_installer() {
        local package_list
        detect_storage_requirements
        package_list="$(build_package_list)"
        log "Preparing chroot configuration"
        install -d -m 0755 "$TARGET/root"

        cat > "$TARGET$CHROOT_INSTALLER" <<'CHROOT'
#!/usr/bin/env bash
set -Eeuo pipefail
export PATH=/usr/bin:/usr/sbin:/bin:/sbin
export LANG=C LC_ALL=C LANGUAGE=C

HOSTNAME_VALUE="__HOSTNAME__"
TIMEZONE_VALUE="__TIMEZONE__"
LOCALE_VALUE="__LOCALE__"
USERNAME_VALUE="__USERNAME__"
ADDITIONAL_USERS_VALUE="__ADDITIONAL_USERS__"
BOOT_MODE_VALUE="__BOOT_MODE__"
BOOT_DISK_VALUE="__BOOT_DISK__"
NETWORK_IFACE_VALUE="__NETWORK_IFACE__"
NETWORK_MAC_VALUE="__NETWORK_MAC__"
NETWORK_TARGET_NAME_VALUE="__NETWORK_TARGET_NAME__"
PACKAGE_LIST_VALUE="__PACKAGE_LIST__"
ENABLE_OPENSSH_VALUE="__ENABLE_OPENSSH__"
INSTALL_GRUB_VALUE="__INSTALL_GRUB__"
GRUB_FALLBACK_VALUE="__GRUB_FALLBACK__"
KERNEL_PACKAGE_VALUE="__KERNEL_PACKAGE__"
INSTALL_SUDO_VALUE="__INSTALL_SUDO__"
SUDO_MODE_VALUE="__SUDO_MODE__"
INSTALL_NETWORKMANAGER_VALUE="__INSTALL_NETWORKMANAGER__"
INSTALL_CRYPTSETUP_VALUE="__INSTALL_CRYPTSETUP__"
AUTO_CRYPTSETUP_VALUE="__AUTO_CRYPTSETUP__"
AUTO_LVM2_VALUE="__AUTO_LVM2__"
AUTO_MDADM_VALUE="__AUTO_MDADM__"
BTRFS_CONFIG_NAMES_VALUE="__BTRFS_CONFIG_NAMES__"
BTRFS_MOUNTPOINTS_VALUE="__BTRFS_MOUNTPOINTS__"

log() { printf '\n==> %s\n' "$*"; }

log "Setting hostname and timezone"
printf '%s\n' "$HOSTNAME_VALUE" > /etc/hostname
[[ -e "/usr/share/zoneinfo/$TIMEZONE_VALUE" ]] || { echo "Missing timezone: $TIMEZONE_VALUE" >&2; exit 1; }
ln -sfn "/usr/share/zoneinfo/$TIMEZONE_VALUE" /etc/localtime

log "Configuring locales"
mkdir -p /etc

normalize_locale_entry() {
        local locale_name="$1"
        local locale_base="$locale_name"

        case "$locale_name" in
                C.UTF-8|C.utf8)
                        printf '%s\n' 'C.UTF-8 UTF-8'
                        return 0
                        ;;
        esac

        locale_base="${locale_base%.UTF-8}"
        locale_base="${locale_base%.utf8}"
        printf '%s UTF-8\n' "$locale_base"
}

add_locale_entry() {
        local entry="$1"

        touch /etc/locales
        grep -qxF "$entry" /etc/locales ||
                printf '%s\n' "$entry" >> /etc/locales
}

SELECTED_LOCALE_ENTRY="$(normalize_locale_entry "$LOCALE_VALUE")"
C_UTF8_ENTRY="$(normalize_locale_entry C.UTF-8)"

add_locale_entry "$C_UTF8_ENTRY"
add_locale_entry "$SELECTED_LOCALE_ENTRY"

if command -v genlocales >/dev/null 2>&1; then
        genlocales || {
                echo "Locale generation failed with genlocales." >&2
                echo "Contents of /etc/locales:" >&2
                cat /etc/locales >&2
                exit 1
        }
elif command -v locale-gen >/dev/null 2>&1; then
        locale-gen || {
                echo "Locale generation failed with locale-gen." >&2
                echo "Contents of /etc/locales:" >&2
                cat /etc/locales >&2
                exit 1
        }
else
        echo "No locale generation command was found." >&2
        exit 1
fi

printf 'LANG=%s\n' "$LOCALE_VALUE" > /etc/locale.conf

log "Writing hosts and console configuration"
cat > /etc/hosts <<EOF_HOSTS
127.0.0.1 localhost
127.0.1.1 $HOSTNAME_VALUE
::1 localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF_HOSTS
printf 'FONT=Lat2-Terminus16\n' > /etc/vconsole.conf

cat > /etc/inputrc <<'EOF_INPUTRC'
set horizontal-scroll-mode Off
set meta-flag On
set input-meta On
set convert-meta Off
set output-meta On
set bell-style none
"\eOd": backward-word
"\eOc": forward-word
"\e[1~": beginning-of-line
"\e[4~": end-of-line
"\e[5~": beginning-of-history
"\e[6~": end-of-history
"\e[3~": delete-char
"\e[2~": quoted-insert
"\eOH": beginning-of-line
"\eOF": end-of-line
"\e[H": beginning-of-line
"\e[F": end-of-line
EOF_INPUTRC

log "Configuring systemd"
systemd-machine-id-setup
mkdir -p /etc/systemd/system/getty@tty1.service.d
rm -f /etc/systemd/system/getty@tty1.service.d/noclear.conf
cat > /etc/systemd/system/getty@tty1.service.d/clear.conf <<'EOF_GETTY'
[Service]
TTYVTDisallocate=yes
EOF_GETTY
mkdir -p /etc/systemd/coredump.conf.d
cat > /etc/systemd/coredump.conf.d/maxuse.conf <<'EOF_CORE'
[Coredump]
MaxUse=5G
EOF_CORE

mkdir -p /etc/systemd/network
rm -f \
        /etc/systemd/network/10-bfs-dhcp.network \
        /etc/systemd/network/10-bfs-ethernet.link \
        /etc/systemd/network/20-bfs-dhcp.network

# The .link file is handled by udev, so it provides the same eth0 naming
# whether systemd-networkd or NetworkManager is selected.
cat > /etc/systemd/network/10-bfs-ethernet.link <<EOF_LINK
[Match]
MACAddress=$NETWORK_MAC_VALUE

[Link]
Name=$NETWORK_TARGET_NAME_VALUE
EOF_LINK

chmod 0644 /etc/systemd/network/10-bfs-ethernet.link

if [[ "$INSTALL_NETWORKMANAGER_VALUE" != yes ]]; then
        cat > /etc/systemd/network/20-bfs-dhcp.network <<EOF_NETWORK
[Match]
Name=$NETWORK_TARGET_NAME_VALUE

[Network]
DHCP=ipv4

[DHCPv4]
UseDomains=true
EOF_NETWORK

        chmod 0644 /etc/systemd/network/20-bfs-dhcp.network
fi

log "Checking account database"
[[ -f /etc/passwd ]] || { echo "Missing required account file: /etc/passwd" >&2; exit 1; }
[[ -f /etc/group ]] || { echo "Missing required account file: /etc/group" >&2; exit 1; }

grep -q '^root:' /etc/passwd || { echo "The BFS archive has no root entry in /etc/passwd." >&2; exit 1; }
grep -q '^root:' /etc/group || { echo "The BFS archive has no root entry in /etc/group." >&2; exit 1; }

if [[ ! -f /etc/shadow ]]; then
        log "Creating /etc/shadow from /etc/passwd"
        awk -F: '{ print $1 ":!:1::::::" }' /etc/passwd > /etc/shadow
fi

if [[ ! -f /etc/gshadow ]]; then
        log "Creating /etc/gshadow from /etc/group"
        awk -F: '{ print $1 ":!::" $4 }' /etc/group > /etc/gshadow
fi

grep -q '^root:' /etc/shadow || printf '%s\n' 'root:!:1::::::' >> /etc/shadow
grep -q '^root:' /etc/gshadow || printf '%s\n' 'root:!::' >> /etc/gshadow

chown root:root /etc/passwd /etc/group /etc/shadow /etc/gshadow
chmod 0644 /etc/passwd /etc/group
chmod 0600 /etc/shadow /etc/gshadow

log "Creating users"

DEFAULT_USER_GROUPS="users,wheel,audio,video,optical,cdrom,plugdev,storage,input,render"

ensure_default_user_groups() {
        local group_name=""

        command -v groupadd >/dev/null 2>&1 || {
                echo "groupadd is missing" >&2
                exit 1
        }

        for group_name in ${DEFAULT_USER_GROUPS//,/ }; do
                getent group "$group_name" >/dev/null 2>&1 ||
                        groupadd -r "$group_name"
        done
}

verify_regular_user_groups() {
        local user_name="$1"
        local group_name=""
        local user_groups=""

        user_groups="$(id -nG "$user_name")"

        for group_name in ${DEFAULT_USER_GROUPS//,/ }; do
                if ! grep -qw "$group_name" <<< "$user_groups"; then
                        echo "User $user_name was not added to group $group_name." >&2
                        exit 1
                fi
        done

        printf 'Groups for %s: %s\n' "$user_name" "$user_groups"
}

create_regular_user() {
        local user_name="$1"

        if ! id "$user_name" >/dev/null 2>&1; then
                if [[ -d "/home/$user_name" ]]; then
                        useradd -M \
                                -d "/home/$user_name" \
                                -s /bin/bash \
                                "$user_name"
                else
                        useradd -m \
                                -s /bin/bash \
                                "$user_name"
                fi
        fi

        # Apply the standard BFS groups to both newly-created accounts and
        # accounts that were already present in the base archive.
        usermod -aG "$DEFAULT_USER_GROUPS" "$user_name"

        mkdir -p "/home/$user_name"
        chown -R "$user_name:$user_name" "/home/$user_name"

        verify_regular_user_groups "$user_name"
}

ensure_default_user_groups

set_account_password() {
        local account="$1"
        local label="$2"
        local password_one=""
        local password_two=""

        command -v chpasswd >/dev/null 2>&1 || {
                echo "chpasswd is missing" >&2
                exit 1
        }

        while true; do
                printf '\nSet password for %s.\n' "$label"
                read -r -s -p "New password: " password_one
                printf '\n'
                read -r -s -p "Retype new password: " password_two
                printf '\n'

                if [[ -z "$password_one" ]]; then
                        echo "Password cannot be blank."
                elif [[ "$password_one" != "$password_two" ]]; then
                        echo "Passwords do not match."
                else
                        break
                fi
        done

        printf '%s:%s\n' "$account" "$password_one" | chpasswd
        unset password_one password_two
}

create_regular_user "$USERNAME_VALUE"
set_account_password "$USERNAME_VALUE" "user $USERNAME_VALUE"

read -r -a ADDITIONAL_USERS_ARRAY <<< "$ADDITIONAL_USERS_VALUE"

for user_name in "${ADDITIONAL_USERS_ARRAY[@]}"; do
        [[ -n "$user_name" ]] || continue
        create_regular_user "$user_name"
        set_account_password "$user_name" "user $user_name"
done

set_account_password root root

if [[ -n "$PACKAGE_LIST_VALUE" ]]; then
        if command -v ports >/dev/null 2>&1; then
                log "Synchronizing ports for selected packages"
                ports -u
        fi

        command -v prt-get >/dev/null 2>&1 || {
                echo "prt-get is missing" >&2
                exit 1
        }

        read -r -a PACKAGE_LIST_ARRAY <<< "$PACKAGE_LIST_VALUE"

        ((${#PACKAGE_LIST_ARRAY[@]} > 0)) || {
                echo "Internal error: package selection was empty." >&2
                exit 1
        }

        MISSING_PACKAGES=()

        log "Checking selected package installation status"

        for package in "${PACKAGE_LIST_ARRAY[@]}"; do
                if prt-get isinst "$package" >/dev/null 2>&1; then
                        printf 'Already installed: %s\n' "$package"
                else
                        printf 'Will install:      %s\n' "$package"
                        MISSING_PACKAGES+=("$package")
                fi
        done

        if ((${#MISSING_PACKAGES[@]} > 0)); then
                log "Installing missing packages: ${MISSING_PACKAGES[*]}"
                prt-get depinst "${MISSING_PACKAGES[@]}"
        else
                log "All selected packages are already installed"
        fi
else
        log "No optional packages were selected; skipping ports synchronization and package installation"
fi

if [[ "$INSTALL_SUDO_VALUE" == yes ]]; then
        mkdir -p /etc/sudoers.d

        case "$SUDO_MODE_VALUE" in
                password)
                        cat > /etc/sudoers.d/10-wheel <<'EOF_SUDO_PASSWORD'
## Allow members of group wheel to execute any command
%wheel ALL=(ALL:ALL) ALL
EOF_SUDO_PASSWORD
                        ;;
                nopasswd)
                        cat > /etc/sudoers.d/10-wheel <<'EOF_SUDO_NOPASSWD'
## Allow members of group wheel to execute any command without a password
%wheel ALL=(ALL:ALL) NOPASSWD: ALL
EOF_SUDO_NOPASSWD
                        ;;
                *)
                        echo "Invalid sudo mode: $SUDO_MODE_VALUE" >&2
                        exit 1
                        ;;
        esac

        chmod 0440 /etc/sudoers.d/10-wheel

        if command -v visudo >/dev/null 2>&1; then
                visudo -cf /etc/sudoers.d/10-wheel
        fi
else
        rm -f /etc/sudoers.d/10-wheel
fi

command -v ssh-keygen >/dev/null 2>&1 && ssh-keygen -A
ldconfig
systemctl preset-all || true

if [[ "$INSTALL_NETWORKMANAGER_VALUE" == yes ]] && systemctl list-unit-files NetworkManager.service >/dev/null 2>&1; then
        log "Enabling NetworkManager and disabling systemd-networkd"
        systemctl enable NetworkManager.service
        systemctl disable systemd-networkd.service 2>/dev/null || true
        systemctl disable systemd-networkd-wait-online.service 2>/dev/null || true
elif systemctl list-unit-files systemd-networkd.service >/dev/null 2>&1; then
        log "Enabling systemd-networkd"
        systemctl enable systemd-networkd.service
        systemctl disable systemd-networkd-wait-online.service 2>/dev/null || true
fi

if systemctl list-unit-files systemd-resolved.service >/dev/null 2>&1; then
        systemctl enable systemd-resolved.service
        ln -sfn /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
fi

if [[ "$ENABLE_OPENSSH_VALUE" == yes ]]; then
        if systemctl list-unit-files sshd.service >/dev/null 2>&1; then
                systemctl enable sshd.service
        elif systemctl list-unit-files ssh.service >/dev/null 2>&1; then
                systemctl enable ssh.service
        else
                echo "WARNING: No OpenSSH service unit was found." >&2
        fi
fi

if [[ "$AUTO_LVM2_VALUE" == yes ]] &&
   command -v lvmconfig >/dev/null 2>&1; then
        if [[ ! -f /etc/lvm/lvm.conf ]]; then
                mkdir -p /etc/lvm
                lvmconfig --type full --withcomments > /etc/lvm/lvm.conf
        fi
        systemctl enable lvm2-monitor.service 2>/dev/null || true
fi

if [[ "$AUTO_MDADM_VALUE" == yes ]] &&
   command -v mdadm >/dev/null 2>&1; then
        mdadm --detail --scan > /etc/mdadm.conf || true
fi

if [[ "$INSTALL_CRYPTSETUP_VALUE" == yes ||
      "$AUTO_CRYPTSETUP_VALUE" == yes ]]; then
        mkdir -p /etc/cryptsetup-keys.d
        chmod 0700 /etc/cryptsetup-keys.d
fi

configure_btrfs_snapshots() {
        local -a config_names=()
        local -a mountpoints=()
        local index="" config_name="" mountpoint_name="" config_file=""

        read -r -a config_names <<< "$BTRFS_CONFIG_NAMES_VALUE"
        read -r -a mountpoints <<< "$BTRFS_MOUNTPOINTS_VALUE"

        ((${#config_names[@]} > 0)) || return 0

        command -v snapper >/dev/null 2>&1 || {
                echo "Btrfs was selected but snapper is not installed." >&2
                exit 1
        }

        mkdir -p /etc/snapper/configs /etc/default

        for ((index=0; index<${#config_names[@]}; index++)); do
                config_name="${config_names[$index]}"
                mountpoint_name="${mountpoints[$index]}"
                config_file="/etc/snapper/configs/$config_name"

                cat > "$config_file" <<EOF_SNAPPER
SUBVOLUME="$mountpoint_name"
FSTYPE="btrfs"
QGROUP=""
SPACE_LIMIT="0.5"
FREE_LIMIT="0.2"
ALLOW_USERS=""
ALLOW_GROUPS="wheel"
SYNC_ACL="yes"
BACKGROUND_COMPARISON="yes"
NUMBER_CLEANUP="yes"
NUMBER_MIN_AGE="1800"
NUMBER_LIMIT="50"
NUMBER_LIMIT_IMPORTANT="10"
TIMELINE_CREATE="yes"
TIMELINE_CLEANUP="yes"
TIMELINE_MIN_AGE="1800"
TIMELINE_LIMIT_HOURLY="10"
TIMELINE_LIMIT_DAILY="10"
TIMELINE_LIMIT_WEEKLY="0"
TIMELINE_LIMIT_MONTHLY="10"
TIMELINE_LIMIT_YEARLY="10"
EMPTY_PRE_POST_CLEANUP="yes"
EMPTY_PRE_POST_MIN_AGE="1800"
EOF_SNAPPER
        done

        printf 'SNAPPER_CONFIGS="%s"\n' "${config_names[*]}" > /etc/default/snapper

        systemctl enable snapper-timeline.timer 2>/dev/null || true
        systemctl enable snapper-cleanup.timer 2>/dev/null || true

        for config_name in "${config_names[@]}"; do
                snapper -c "$config_name" create \
                        --description "Initial BFS installation" || true
        done
}

configure_btrfs_snapshots

# Blank the Linux virtual console after 30 minutes.
mkdir -p /etc/default
touch /etc/default/grub

if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub; then
        current_cmdline="$(
                sed -n 's/^GRUB_CMDLINE_LINUX_DEFAULT="\([^"]*\)"/\1/p' \
                        /etc/default/grub |
                head -n1
        )"

        case " $current_cmdline " in
                *" consoleblank="*) ;;
                *) current_cmdline="${current_cmdline:+$current_cmdline }consoleblank=1800" ;;
        esac

        sed -i \
                "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$current_cmdline\"|" \
                /etc/default/grub
else
        printf '%s\n' \
                'GRUB_CMDLINE_LINUX_DEFAULT="consoleblank=1800"' \
                >> /etc/default/grub
fi


configure_dracut_storage_modules() {
        local config_file="/etc/dracut.conf.d/20-bfs-storage.conf"
        local -a modules=()

        mkdir -p /etc/dracut.conf.d

        [[ "$AUTO_CRYPTSETUP_VALUE" == yes ]] && modules+=(crypt)
        [[ "$AUTO_LVM2_VALUE" == yes ]] && modules+=(lvm)
        [[ "$AUTO_MDADM_VALUE" == yes ]] && modules+=(mdraid)

        if ((${#modules[@]} > 0)); then
                printf '# Generated by the BFS installer.\n' > "$config_file"
                printf 'add_dracutmodules+=" %s "\n' "${modules[*]}" >> "$config_file"
        else
                rm -f "$config_file"
        fi
}

rebuild_final_initramfs() {
        local kernel_image=""
        local kernel_release=""
        local initramfs_image=""

        [[ "$KERNEL_PACKAGE_VALUE" != none ]] || return 0

        command -v dracut >/dev/null 2>&1 || {
                echo "A kernel was installed, but dracut is unavailable." >&2
                exit 1
        }

        kernel_image="$(
                find /boot -maxdepth 1 -type f -name 'vmlinuz-*' \
                        -printf '%T@ %p\n' |
                sort -nr |
                head -n1 |
                cut -d' ' -f2-
        )"

        [[ -n "$kernel_image" ]] || {
                echo "Could not find a kernel for initramfs generation." >&2
                exit 1
        }

        kernel_release="${kernel_image#/boot/vmlinuz-}"
        initramfs_image="/boot/initramfs-$kernel_release.img"

        configure_dracut_storage_modules

        log "Generating final initramfs for $kernel_release"
        dracut --force "$initramfs_image" "$kernel_release"
}

rebuild_final_initramfs

verify_kernel_installation() {
        local kernel_image=""
        local kernel_release=""
        local initramfs_image=""

        [[ "$KERNEL_PACKAGE_VALUE" != none ]] || return 0

        kernel_image="$(
                find /boot -maxdepth 1 -type f -name 'vmlinuz-*' \
                        -printf '%T@ %p\n' |
                sort -nr |
                head -n1 |
                cut -d' ' -f2-
        )"

        [[ -n "$kernel_image" && -s "$kernel_image" ]] || {
                echo "No installed kernel image was found." >&2
                exit 1
        }

        kernel_release="${kernel_image#/boot/vmlinuz-}"
        initramfs_image="/boot/initramfs-$kernel_release.img"

        if [[ ! -s "$initramfs_image" ]]; then
                initramfs_image="$(
                        find /boot -maxdepth 1 -type f \
                                \( -name "initramfs*$kernel_release*.img" -o -name "initrd*$kernel_release*" \) \
                                -printf '%T@ %p\n' |
                        sort -nr |
                        head -n1 |
                        cut -d' ' -f2-
                )"
        fi

        [[ -n "$initramfs_image" && -s "$initramfs_image" ]] || {
                echo "No matching initramfs was found for $kernel_release." >&2
                exit 1
        }

        printf 'Verified kernel: %s\n' "$kernel_image"
        printf 'Verified initramfs: %s\n' "$initramfs_image"
}

verify_kernel_installation

if [[ "$INSTALL_GRUB_VALUE" == yes ]]; then
        log "Writing and configuring GRUB"

        command -v grub-install >/dev/null 2>&1 || {
                echo "grub-install is missing" >&2
                exit 1
        }

        command -v grub-mkconfig >/dev/null 2>&1 || {
                echo "grub-mkconfig is missing" >&2
                exit 1
        }

        mkdir -p /boot/grub

        if [[ "$BOOT_MODE_VALUE" == uefi ]]; then
                grub-install \
                        --target=x86_64-efi \
                        --efi-directory=/boot/efi \
                        --bootloader-id=BFS \
                        --recheck

                if [[ "$GRUB_FALLBACK_VALUE" == yes ]]; then
                        grub-install \
                                --target=x86_64-efi \
                                --efi-directory=/boot/efi \
                                --bootloader-id=BFS \
                                --removable \
                                --recheck
                fi
        else
                grub-install "$BOOT_DISK_VALUE"
        fi

        grub-mkconfig -o /boot/grub/grub.cfg

        [[ -s /boot/grub/grub.cfg ]] || {
                echo "GRUB configuration was not generated." >&2
                exit 1
        }

        if [[ "$KERNEL_PACKAGE_VALUE" != none ]]; then
                grep -q '^[[:space:]]*linux[[:space:]]' /boot/grub/grub.cfg || {
                        echo "grub.cfg contains no Linux kernel line." >&2
                        exit 1
                }

                grep -q '^[[:space:]]*initrd[[:space:]]' /boot/grub/grub.cfg || {
                        echo "grub.cfg contains no initrd line." >&2
                        exit 1
                }
        fi

        if [[ "$BOOT_MODE_VALUE" == uefi ]]; then
                [[ -s /boot/efi/EFI/BFS/grubx64.efi ]] || {
                        echo "BFS EFI loader was not installed." >&2
                        exit 1
                }

                if [[ "$GRUB_FALLBACK_VALUE" == yes ]]; then
                        [[ -s /boot/efi/EFI/BOOT/BOOTX64.EFI ]] || {
                                echo "EFI fallback loader was not installed." >&2
                                exit 1
                        }
                fi
        fi
else
        log "Skipping GRUB bootloader configuration"
fi

log "Running final checks"

if [[ "$AUTO_CRYPTSETUP_VALUE" == yes ]]; then
        [[ -s /etc/crypttab ]] || {
                echo "Encrypted storage was detected, but /etc/crypttab is missing." >&2
                exit 1
        }

        command -v cryptsetup >/dev/null 2>&1 || {
                echo "Encrypted storage was detected, but cryptsetup is missing." >&2
                exit 1
        }
fi

[[ -s /etc/systemd/network/10-bfs-ethernet.link ]] ||
        { echo "Missing BFS network link file." >&2; exit 1; }

grep -qx "MACAddress=$NETWORK_MAC_VALUE" /etc/systemd/network/10-bfs-ethernet.link ||
        { echo "BFS network link file has the wrong MAC address." >&2; exit 1; }
grep -qx "Name=$NETWORK_TARGET_NAME_VALUE" /etc/systemd/network/10-bfs-ethernet.link ||
        { echo "BFS network link file has the wrong target interface name." >&2; exit 1; }

if [[ "$INSTALL_NETWORKMANAGER_VALUE" == yes ]]; then
        [[ ! -e /etc/systemd/network/20-bfs-dhcp.network ]] ||
                { echo "A systemd-networkd DHCP file exists while NetworkManager is selected." >&2; exit 1; }
else
        [[ -s /etc/systemd/network/20-bfs-dhcp.network ]] ||
                { echo "Missing BFS DHCP network file." >&2; exit 1; }
        grep -qx "Name=$NETWORK_TARGET_NAME_VALUE" /etc/systemd/network/20-bfs-dhcp.network ||
                { echo "BFS DHCP file has the wrong interface name." >&2; exit 1; }
fi

awk '
        /^[[:space:]]*($|#)/ {
                next
        }

        NF != 6 {
                printf "Invalid fstab field count on line %d: %s\n", NR, $0 > "/dev/stderr"
                failed=1
                next
        }

        $1 !~ /^(UUID=|LABEL=|PARTUUID=|PARTLABEL=|\/dev\/)/ {
                printf "Invalid fstab source on line %d: %s\n", NR, $1 > "/dev/stderr"
                failed=1
        }

        $2 != "none" && $2 !~ /^\// {
                printf "Invalid fstab target on line %d: %s\n", NR, $2 > "/dev/stderr"
                failed=1
        }

        $5 !~ /^[0-9]+$/ || $6 !~ /^[0-9]+$/ {
                printf "Invalid dump/pass fields on line %d\n", NR > "/dev/stderr"
                failed=1
        }

        END {
                exit failed
        }
' /etc/fstab ||
        { echo "Generated /etc/fstab failed syntax validation." >&2; exit 1; }

for command in bash sh env sed grep awk find tar gzip xz make gcc g++ ld ar nm strip readelf mount umount ls cp mv rm chmod chown pkgmk pkgadd pkginfo; do
        command -v "$command" >/dev/null 2>&1 || printf 'MISSING COMMAND: %s\n' "$command" >&2
done

cat > /tmp/bfs-test.c <<'EOF_TEST'
#include <stdio.h>
int main(void) { puts("BFS compiler test passed"); return 0; }
EOF_TEST
gcc /tmp/bfs-test.c -o /tmp/bfs-test
/tmp/bfs-test
if gcc -dumpspecs | grep -q '/tmp/lfs-tools'; then
        echo "ERROR: GCC still references /tmp/lfs-tools." >&2
        exit 1
fi
rm -f /tmp/bfs-test /tmp/bfs-test.c

pkginfo -i | sort > /root/base-system.manifest
find /usr/lib/systemd/system /etc/systemd/system -type f -o -type l 2>/dev/null | sort > /root/systemd-units.manifest
ldconfig -p > /root/ldconfig.manifest

log "BFS installation finished successfully"
CHROOT

        sed -i \
                -e "s|__HOSTNAME__|$(printf '%s' "$HOSTNAME" | sed 's/[&|]/\\&/g')|g" \
                -e "s|__TIMEZONE__|$(printf '%s' "$TIMEZONE" | sed 's/[&|]/\\&/g')|g" \
                -e "s|__LOCALE__|$(printf '%s' "$LOCALE" | sed 's/[&|]/\\&/g')|g" \
                -e "s|__USERNAME__|$(printf '%s' "$USERNAME" | sed 's/[&|]/\\&/g')|g" \
                -e "s|__ADDITIONAL_USERS__|$(printf '%s' "$(additional_users_text)" | sed 's/[&|]/\\&/g')|g" \
                -e "s|__BOOT_MODE__|$BOOT_MODE|g" \
                -e "s|__BOOT_DISK__|$(printf '%s' "$BOOT_DISK" | sed 's/[&|]/\\&/g')|g" \
                -e "s|__NETWORK_IFACE__|$(printf '%s' "$NETWORK_IFACE" | sed 's/[&|]/\\&/g')|g" \
                -e "s|__NETWORK_MAC__|$(printf '%s' "$NETWORK_MAC" | sed 's/[&|]/\\&/g')|g" \
                -e "s|__NETWORK_TARGET_NAME__|$(printf '%s' "$NETWORK_TARGET_NAME" | sed 's/[&|]/\\&/g')|g" \
                -e "s|__PACKAGE_LIST__|$(printf '%s' "$package_list" | sed 's/[&|]/\\&/g')|g" \
                -e "s|__ENABLE_OPENSSH__|$ENABLE_OPENSSH|g" \
                -e "s|__INSTALL_GRUB__|$INSTALL_GRUB|g" \
                -e "s|__GRUB_FALLBACK__|$GRUB_FALLBACK|g" \
                -e "s|__KERNEL_PACKAGE__|$KERNEL_PACKAGE|g" \
                -e "s|__INSTALL_SUDO__|$INSTALL_SUDO|g" \
                -e "s|__SUDO_MODE__|$SUDO_MODE|g" \
                -e "s|__INSTALL_NETWORKMANAGER__|$INSTALL_NETWORKMANAGER|g" \
                -e "s|__INSTALL_CRYPTSETUP__|$INSTALL_CRYPTSETUP|g" \
                -e "s|__AUTO_CRYPTSETUP__|$AUTO_CRYPTSETUP|g" \
                -e "s|__AUTO_LVM2__|$AUTO_LVM2|g" \
                -e "s|__AUTO_MDADM__|$AUTO_MDADM|g" \
                -e "s|__BTRFS_CONFIG_NAMES__|$(printf '%s' "${BTRFS_CONFIG_NAMES[*]}" | sed 's/[&|]/\\&/g')|g" \
                -e "s|__BTRFS_MOUNTPOINTS__|$(printf '%s' "${BTRFS_MOUNTPOINTS[*]}" | sed 's/[&|]/\\&/g')|g" \
                "$TARGET$CHROOT_INSTALLER"
        chmod 0700 "$TARGET$CHROOT_INSTALLER"
}

run_chroot_installer() {
        log "Entering BFS chroot"
        chroot "$TARGET" /usr/bin/env -i \
                HOME=/root \
                TERM="${TERM:-linux}" \
                PATH=/usr/bin:/usr/sbin:/bin:/sbin \
                LANG=C \
                LC_ALL=C \
                /bin/bash "$CHROOT_INSTALLER"
}

offer_final_chroot() {
        local answer=""

        read -r -p "Chroot into the installed BFS system now? [y/N]: " answer
        if [[ "${answer,,}" != y && "${answer,,}" != yes ]]; then
                printf '\nBFS installation completed. The installer will unmount the target filesystems.\n'
                return 0
        fi

        FINAL_CHROOT=yes
        KEEP_MOUNTS=yes

        printf '\nEntering the installed BFS system. Type exit to return to the live environment.\n'
        run_on_tty \
                chroot "$TARGET" /usr/bin/env -i \
                HOME=/root \
                TERM="${TERM:-linux}" \
                PATH=/usr/bin:/usr/sbin:/bin:/sbin \
                LANG="${LOCALE:-C}" \
                /bin/bash --login

        printf '\nExited the installed BFS chroot.\n'
        KEEP_MOUNTS=no
}

main() {
        parse_arguments "$@"
        require_root "$@"
        force_posix_locale
        load_installer_settings
        setup_installer_theme
        setup_logging
        require_commands
        prepare_target_environment

        installer_menu
        validate_settings
        show_summary

        confirm "Begin the BFS installation?" ||
                die "Installation cancelled."

        format_selected_partitions
        mount_target_filesystems
        extract_rootfs
        save_base_archive
        generate_fstab
        generate_crypttab
        mount_virtual_filesystems
        write_chroot_installer
        run_chroot_installer

        log "Installation complete"

        cat <<DONE

Review before rebooting:

    $TARGET/etc/fstab
    $TARGET/etc/hostname
    $TARGET/etc/locale.conf
    $TARGET/etc/systemd/network/10-bfs-ethernet.link
    $TARGET/boot/grub/grub.cfg

Saved validation manifests:

    $TARGET/root/base-system.manifest
    $TARGET/root/systemd-units.manifest
    $TARGET/root/ldconfig.manifest
DONE

        if [[ "$LOG_ENABLED" == yes ]]; then
                printf '
Live-environment log: %s
' "$LOG_FILE"
                close_logging 0
                copy_log_to_installed_system
        fi

        offer_final_chroot
}

main "$@"
