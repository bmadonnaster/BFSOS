#!/usr/bin/env bash
set -Eeuo pipefail

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
BOOT_MODE="${BFS_BOOT_MODE:-}"
BOOT_DISK="${BFS_BOOT_DISK:-}"
NETWORK_IFACE="${BFS_NETWORK_IFACE:-}"

ROOT_FORMAT="keep"
BOOT_FORMAT="keep"
EFI_FORMAT="keep"
SWAP_FORMAT="keep"
HOME_FORMAT="keep"

INSTALL_KERNEL="${BFS_INSTALL_KERNEL:-yes}"
INSTALL_GRUB="${BFS_INSTALL_GRUB:-yes}"
SAVE_BASE_ARCHIVE="${BFS_SAVE_BASE_ARCHIVE:-yes}"
BASE_ARCHIVE_DIR="${BFS_BASE_ARCHIVE_DIR:-/var/cache/bfs/archives/base}"
ENABLE_OPENSSH="${BFS_ENABLE_OPENSSH:-${BFS_INSTALL_OPENSSH:-yes}}"
INSTALL_NETWORKMANAGER="${BFS_INSTALL_NETWORKMANAGER:-yes}"
INSTALL_CRYPTSETUP="${BFS_INSTALL_CRYPTSETUP:-no}"
KEEP_MOUNTS="${BFS_KEEP_MOUNTS:-no}"
FINAL_CHROOT="${BFS_FINAL_CHROOT:-no}"

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
AVAILABLE_PATHS=()
AVAILABLE_TYPES=()
AVAILABLE_SIZES=()
AVAILABLE_FSTYPES=()
AVAILABLE_LABELS=()
AVAILABLE_MOUNTPOINTS=()
CHROOT_INSTALLER="/root/.bfs-install-chroot.sh"

log() { printf '\n==> %s\n' "$*"; }
warn() { printf '\nWARNING: %s\n' "$*" >&2; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

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
Usage: install-bfs-fixed-v12.sh [options]

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

        if [[ -z "$LOG_FILE" ]]; then
                LOG_FILE="$PWD/bfs-install-$(date +%Y%m%d-%H%M%S).log"
        elif [[ "$LOG_FILE" != /* ]]; then
                LOG_FILE="$PWD/$LOG_FILE"
        fi

        mkdir -p "$(dirname "$LOG_FILE")"
        : > "$LOG_FILE"

        LOG_FIFO="$(mktemp -u /tmp/bfs-install-log.XXXXXX)"
        mkfifo "$LOG_FIFO"

        exec 3>&1 4>&2
        tee -a "$LOG_FILE" < "$LOG_FIFO" >&3 &
        LOG_TEE_PID=$!
        exec > "$LOG_FIFO" 2>&1

        printf '%s\n' '=================================================='
        printf '%s\n' 'BFS Linux installer log'
        printf 'Started:  %s\n' "$(date --iso-8601=seconds 2>/dev/null || date)"
        printf 'Script:   %s\n' "${BASH_SOURCE[0]}"
        printf 'Log file: %s\n' "$LOG_FILE"
        printf '%s\n' '=================================================='
}

close_logging() {
        [[ "$LOG_ENABLED" == yes ]] || return 0
        exec 1>&3 2>&4
        wait "$LOG_TEE_PID" 2>/dev/null || true
        rm -f "$LOG_FIFO"
        LOG_FIFO=""
        LOG_TEE_PID=""
}

copy_log_to_installed_system() {
        local installed_log=""
        [[ "$LOG_ENABLED" == yes && -f "$LOG_FILE" ]] || return 0

        mkdir -p "$TARGET/var/log"
        installed_log="$TARGET/var/log/$(basename "$LOG_FILE")"
        cp -f "$LOG_FILE" "$installed_log"
        chmod 0600 "$installed_log"
        printf 'Installed-system log: /var/log/%s\n' "$(basename "$LOG_FILE")"
}

require_root() { [[ $EUID -eq 0 ]] || die "Run this installer as root."; }

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

collect_settings() {
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

        local script_dir default_archive=""
        script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        if [[ -z "$ARCHIVE" ]]; then
                default_archive="$(
                        find "$script_dir/archives/base" -maxdepth 1 -type f \
                                \( -name 'bfs-rootfs-*.tar.xz' -o -name 'bfs-rootfs-*.tar.zst' -o -name 'bfs-rootfs-*.tar.gz' \) \
                                -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n1 | cut -d' ' -f2-
                )"
        fi
        ask ARCHIVE "Path to BFS rootfs archive" "$default_archive"
        ask_default HOSTNAME "Hostname" "$HOSTNAME"
        ask_default TIMEZONE "Timezone" "$TIMEZONE"
        ask_default LOCALE "Locale (for example en_US.UTF-8)" "$LOCALE"
        ask USERNAME "Regular username"

        if [[ -z "$BOOT_MODE" ]]; then
                if [[ -n "$EFI_DEV" || -d /sys/firmware/efi ]]; then BOOT_MODE=uefi; else BOOT_MODE=bios; fi
        fi
        ask_yes_no INSTALL_GRUB "Write and configure the GRUB bootloader?" "$INSTALL_GRUB"
        [[ "$INSTALL_GRUB" == yes && "$BOOT_MODE" == bios ]] && ask BOOT_DISK "Whole disk for BIOS GRUB, for example /dev/sda"

        if [[ -z "$NETWORK_IFACE" ]]; then
                NETWORK_IFACE="$(find /sys/class/net -mindepth 1 -maxdepth 1 -printf '%f\n' 2>/dev/null | grep -v '^lo$' | head -n1 || true)"
        fi
        ask_default NETWORK_IFACE "Network interface" "${NETWORK_IFACE:-ether0}"
        ask_yes_no INSTALL_KERNEL "Install Linux kernel from ports?" "$INSTALL_KERNEL"
        ask_yes_no SAVE_BASE_ARCHIVE "Save a copy of the BFS base archive on the installed system?" "$SAVE_BASE_ARCHIVE"
        ask_yes_no ENABLE_OPENSSH "Enable the OpenSSH server at boot?" "$ENABLE_OPENSSH"
        ask_yes_no INSTALL_NETWORKMANAGER "Install and enable NetworkManager?" "$INSTALL_NETWORKMANAGER"
        ask_yes_no INSTALL_CRYPTSETUP "Install optional disk-encryption tools (LUKS/cryptsetup)?" "$INSTALL_CRYPTSETUP"
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

validate_settings() {
        [[ -b "$ROOT_DEV" ]] || die "Root device does not exist: $ROOT_DEV"
        [[ -f "$ARCHIVE" ]] || die "Rootfs archive does not exist: $ARCHIVE"
        [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]] || die "Invalid username: $USERNAME"
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
Username:            $USERNAME
Boot mode:           $BOOT_MODE
GRUB disk:           ${BOOT_DISK:-not applicable}
Network interface:   $NETWORK_IFACE
Kernel:              $INSTALL_KERNEL
Write/configure GRUB: $INSTALL_GRUB
Save base archive:   $SAVE_BASE_ARCHIVE
Archive save dir:    $BASE_ARCHIVE_DIR
Enable OpenSSH:      $ENABLE_OPENSSH
NetworkManager:      $INSTALL_NETWORKMANAGER
LUKS:                $INSTALL_CRYPTSETUP
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
        [[ "$INSTALL_GRUB" == yes && "$INSTALL_KERNEL" != yes ]] && \
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
        local index device
        log "Mounting target filesystems"

        # Even when formatting is skipped, selected partitions must not remain
        # mounted elsewhere in the live environment.
        for device in "$ROOT_DEV" "$BOOT_DEV" "$EFI_DEV" "$HOME_DEV" "${EXTRA_DEVICES[@]}"; do
                [[ -n "$device" ]] && unmount_device_everywhere "$device"
        done

        mkdir -p "$TARGET"
        mount_device "$ROOT_DEV" "$TARGET"
        [[ -z "$BOOT_DEV" ]] || mount_device "$BOOT_DEV" "$TARGET/boot"
        [[ "$BOOT_MODE" != uefi ]] || mount_device "$EFI_DEV" "$TARGET/boot/efi"
        [[ -z "$HOME_DEV" ]] || mount_device "$HOME_DEV" "$TARGET/home"
        for ((index=0; index<${#EXTRA_DEVICES[@]}; index++)); do
                mount_device "${EXTRA_DEVICES[$index]}" "$TARGET${EXTRA_MOUNTPOINTS[$index]}"
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
        local index destination
        rm -f "$TARGET$CHROOT_INSTALLER" 2>/dev/null || true
        [[ "$KEEP_MOUNTS" == yes ]] && return 0
        for ((index=${#MOUNTED_BY_SCRIPT[@]}-1; index>=0; index--)); do
                destination="${MOUNTED_BY_SCRIPT[$index]}"
                mountpoint -q "$destination" && umount "$destination" 2>/dev/null || true
        done
        [[ -z "$SWAP_DEV" ]] || swapoff "$SWAP_DEV" 2>/dev/null || true
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

generate_fstab() {
        local fstab="$TARGET/etc/fstab" source destination fstype options relative uuid pass
        log "Generating /etc/fstab"
        mkdir -p "$TARGET/etc"

        if command -v genfstab >/dev/null 2>&1; then
                genfstab -U "$TARGET" > "$fstab"
                return
        fi

        : > "$fstab"
        while read -r source destination fstype options; do
                [[ "$destination" == "$TARGET"* ]] || continue
                relative="${destination#"$TARGET"}"
                [[ -n "$relative" ]] || relative=/
                uuid="$(blkid -s UUID -o value "$source" 2>/dev/null || true)"
                [[ -n "$uuid" ]] || continue
                pass=2; [[ "$relative" == / ]] && pass=1
                printf 'UUID=%s %s %s %s 0 %s\n' "$uuid" "$relative" "$fstype" "$options" "$pass" >> "$fstab"
        done < <(findmnt -Rrn -o SOURCE,TARGET,FSTYPE,OPTIONS "$TARGET")

        if [[ -n "$SWAP_DEV" ]]; then
                uuid="$(blkid -s UUID -o value "$SWAP_DEV" 2>/dev/null || true)"
                if [[ -n "$uuid" ]]; then
                        printf 'UUID=%s none swap defaults 0 0\n' "$uuid" >> "$fstab"
                else
                        printf '%s none swap defaults 0 0\n' "$SWAP_DEV" >> "$fstab"
                fi
        fi
}

build_package_list() {
        local packages=()

        [[ "$INSTALL_KERNEL" == yes ]] && packages+=(linux)
        [[ "$INSTALL_NETWORKMANAGER" == yes ]] && packages+=(networkmanager)
        [[ "$INSTALL_CRYPTSETUP" == yes ]] && packages+=(cryptsetup)

        if ((${#packages[@]} > 0)); then
                printf '%s' "${packages[0]}"
                if ((${#packages[@]} > 1)); then
                        printf ' %s' "${packages[@]:1}"
                fi
        fi
}

write_chroot_installer() {
        local package_list
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
BOOT_MODE_VALUE="__BOOT_MODE__"
BOOT_DISK_VALUE="__BOOT_DISK__"
NETWORK_IFACE_VALUE="__NETWORK_IFACE__"
PACKAGE_LIST_VALUE="__PACKAGE_LIST__"
ENABLE_OPENSSH_VALUE="__ENABLE_OPENSSH__"
INSTALL_GRUB_VALUE="__INSTALL_GRUB__"
INSTALL_NETWORKMANAGER_VALUE="__INSTALL_NETWORKMANAGER__"
INSTALL_CRYPTSETUP_VALUE="__INSTALL_CRYPTSETUP__"

log() { printf '\n==> %s\n' "$*"; }

log "Setting hostname and timezone"
printf '%s\n' "$HOSTNAME_VALUE" > /etc/hostname
[[ -e "/usr/share/zoneinfo/$TIMEZONE_VALUE" ]] || { echo "Missing timezone: $TIMEZONE_VALUE" >&2; exit 1; }
ln -sfn "/usr/share/zoneinfo/$TIMEZONE_VALUE" /etc/localtime

log "Configuring locale"
mkdir -p /etc
LOCALE_BASE="$LOCALE_VALUE"
LOCALE_BASE="${LOCALE_BASE%.UTF-8}"
LOCALE_BASE="${LOCALE_BASE%.utf8}"
LOCALE_ENTRY="$LOCALE_BASE UTF-8"
if [[ -f /etc/locales ]]; then
        grep -qxF "$LOCALE_ENTRY" /etc/locales || printf '%s\n' "$LOCALE_ENTRY" >> /etc/locales
else
        printf '%s\n' "$LOCALE_ENTRY" > /etc/locales
fi
if command -v genlocales >/dev/null 2>&1; then
        genlocales
elif command -v locale-gen >/dev/null 2>&1; then
        locale-gen
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
cat > /etc/systemd/system/getty@tty1.service.d/noclear.conf <<'EOF_GETTY'
[Service]
TTYVTDisallocate=no
EOF_GETTY
mkdir -p /etc/systemd/coredump.conf.d
cat > /etc/systemd/coredump.conf.d/maxuse.conf <<'EOF_CORE'
[Coredump]
MaxUse=5G
EOF_CORE

mkdir -p /etc/systemd/network
cat > /etc/systemd/network/10-bfs-dhcp.network <<EOF_NETWORK
[Match]
Name=$NETWORK_IFACE_VALUE

[Network]
DHCP=ipv4

[DHCPv4]
UseDomains=true
EOF_NETWORK

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

log "Creating user"
if ! id "$USERNAME_VALUE" >/dev/null 2>&1; then
        if [[ -d "/home/$USERNAME_VALUE" ]]; then
                useradd -M -d "/home/$USERNAME_VALUE" -G users,wheel,audio,video -s /bin/bash "$USERNAME_VALUE"
        else
                useradd -m -G users,wheel,audio,video -s /bin/bash "$USERNAME_VALUE"
        fi
fi
chown -R "$USERNAME_VALUE:$USERNAME_VALUE" "/home/$USERNAME_VALUE" 2>/dev/null || true

set_account_password() {
        local account="$1" label="$2" password_one="" password_two=""
        command -v chpasswd >/dev/null 2>&1 || { echo "chpasswd is missing" >&2; exit 1; }

        while true; do
                printf '\nSet password for %s.\n' "$label"
                read -r -s -p "New password: " password_one
                printf '\n'
                read -r -s -p "Retype new password: " password_two
                printf '\n'

                if [[ -z "$password_one" ]]; then
                        echo "Password cannot be blank."
                elif [[ "$password_one" != "$password_two" ]]; then
                        echo "Passwords do not match. Try again."
                else
                        break
                fi
        done

        if chpasswd --help 2>&1 | grep -q -- '--crypt-method'; then
                printf '%s:%s\n' "$account" "$password_one" | chpasswd --crypt-method SHA512
        else
                printf '%s:%s\n' "$account" "$password_one" | chpasswd
        fi
        unset password_one password_two
}

set_account_password "$USERNAME_VALUE" "user $USERNAME_VALUE"
set_account_password root "root"

if [[ -n "$PACKAGE_LIST_VALUE" ]]; then
        if command -v ports >/dev/null 2>&1; then
                log "Synchronizing ports for selected packages"
                ports -u
        fi

        command -v prt-get >/dev/null 2>&1 || { echo "prt-get is missing" >&2; exit 1; }
        log "Installing selected packages: $PACKAGE_LIST_VALUE"

        read -r -a PACKAGE_LIST_ARRAY <<< "$PACKAGE_LIST_VALUE"
        ((${#PACKAGE_LIST_ARRAY[@]} > 0)) || {
                echo "Internal error: package selection was empty." >&2
                exit 1
        }

        prt-get depinst "${PACKAGE_LIST_ARRAY[@]}"
else
        log "No optional packages were selected; skipping ports synchronization and package installation"
fi

command -v ssh-keygen >/dev/null 2>&1 && ssh-keygen -A
ldconfig
systemctl preset-all || true

if [[ "$INSTALL_NETWORKMANAGER_VALUE" == yes ]] && systemctl list-unit-files NetworkManager.service >/dev/null 2>&1; then
        systemctl enable NetworkManager.service
        systemctl disable systemd-networkd.service 2>/dev/null || true
        systemctl disable systemd-networkd-wait-online.service 2>/dev/null || true
elif systemctl list-unit-files systemd-networkd.service >/dev/null 2>&1; then
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

if command -v lvmconfig >/dev/null 2>&1; then
        if [[ ! -f /etc/lvm/lvm.conf ]]; then
                mkdir -p /etc/lvm
                lvmconfig --type full --withcomments > /etc/lvm/lvm.conf
        fi
        systemctl enable lvm2-monitor.service 2>/dev/null || true
fi

if command -v mdadm >/dev/null 2>&1; then
        mdadm --detail --scan > /etc/mdadm.conf || true
fi

if [[ "$INSTALL_CRYPTSETUP_VALUE" == yes ]]; then
        mkdir -p /etc/cryptsetup-keys.d
        chmod 0700 /etc/cryptsetup-keys.d
fi

if [[ "$INSTALL_GRUB_VALUE" == yes ]]; then
        log "Writing and configuring GRUB"
        command -v grub-install >/dev/null 2>&1 || { echo "grub-install is missing" >&2; exit 1; }
        command -v grub-mkconfig >/dev/null 2>&1 || { echo "grub-mkconfig is missing" >&2; exit 1; }

        mkdir -p /boot/grub
        if [[ "$BOOT_MODE_VALUE" == uefi ]]; then
                grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=BFS-GRUB
        else
                grub-install "$BOOT_DISK_VALUE"
        fi
        grub-mkconfig -o /boot/grub/grub.cfg
else
        log "Skipping GRUB bootloader configuration"
fi

log "Running final checks"
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
                -e "s|__BOOT_MODE__|$BOOT_MODE|g" \
                -e "s|__BOOT_DISK__|$(printf '%s' "$BOOT_DISK" | sed 's/[&|]/\\&/g')|g" \
                -e "s|__NETWORK_IFACE__|$(printf '%s' "$NETWORK_IFACE" | sed 's/[&|]/\\&/g')|g" \
                -e "s|__PACKAGE_LIST__|$(printf '%s' "$package_list" | sed 's/[&|]/\\&/g')|g" \
                -e "s|__ENABLE_OPENSSH__|$ENABLE_OPENSSH|g" \
                -e "s|__INSTALL_GRUB__|$INSTALL_GRUB|g" \
                -e "s|__INSTALL_NETWORKMANAGER__|$INSTALL_NETWORKMANAGER|g" \
                -e "s|__INSTALL_CRYPTSETUP__|$INSTALL_CRYPTSETUP|g" \
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
        require_root
        setup_logging
        require_commands
        prepare_target_environment
        collect_settings
        validate_settings
        show_summary
        format_selected_partitions
        mount_target_filesystems
        extract_rootfs
        save_base_archive
        generate_fstab
        mount_virtual_filesystems
        write_chroot_installer
        run_chroot_installer

        log "Installation complete"
        cat <<DONE

Review before rebooting:

    $TARGET/etc/fstab
    $TARGET/etc/hostname
    $TARGET/etc/locale.conf
    $TARGET/boot/grub/grub.cfg

Saved validation manifests:

    $TARGET/root/base-system.manifest
    $TARGET/root/systemd-units.manifest
    $TARGET/root/ldconfig.manifest
DONE

        if [[ "$LOG_ENABLED" == yes ]]; then
                printf '\nLive-environment log: %s\n' "$LOG_FILE"

                # Flush the current log before copying it into the installed system.
                exec 1>&3 2>&4
                wait "$LOG_TEE_PID" 2>/dev/null || true
                rm -f "$LOG_FIFO"
                LOG_FIFO=""
                LOG_TEE_PID=""

                copy_log_to_installed_system
        fi

        offer_final_chroot
}

main "$@"
