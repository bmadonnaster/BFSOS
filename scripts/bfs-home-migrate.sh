#!/usr/bin/env bash
#
# bfs-home-migrate.sh
#
# Interactive BFS-Linux home-folder migration utility.
#
# Features:
#   1. Remove files supplied by /etc/skel from one or all home directories.
#   2. Back up one or all home directories with xz compression.
#   3. Restore a backup into /home or another home-root directory.
#   4. Optional verbose file listing and pv progress meter.
#
# Run as root:
#
#   sudo ./bfs-home-migrate.sh
#

set -Eeuo pipefail

PROGRAM_NAME="${0##*/}"
DEFAULT_HOME_ROOT="/home"

if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
    INVOKING_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
else
    INVOKING_HOME="$HOME"
fi

[[ -n "$INVOKING_HOME" ]] || INVOKING_HOME="$HOME"

DEFAULT_ARCHIVE_DIR="$INVOKING_HOME/bfs-linux-install/archives/home-folder-backup"
SKEL_DIR="/etc/skel"

TEMP_MOUNT=""
TEMP_LISTS=()
VERBOSE_TAR="no"
SHOW_PROGRESS="yes"
EXCLUDE_VOLATILE="yes"

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

warn() {
    printf 'WARNING: %s\n' "$*" >&2
}

cleanup() {
    local file

    for file in "${TEMP_LISTS[@]:-}"; do
        [[ -n "$file" ]] && rm -f -- "$file"
    done

    if [[ -n "$TEMP_MOUNT" && -d "$TEMP_MOUNT" ]]; then
        if mountpoint -q "$TEMP_MOUNT"; then
            umount "$TEMP_MOUNT" || warn "Could not unmount $TEMP_MOUNT"
        fi
        rmdir "$TEMP_MOUNT" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

require_commands() {
    local command_name
    local missing=0

    for command_name in "$@"; do
        if ! command -v "$command_name" >/dev/null 2>&1; then
            printf 'Missing required command: %s\n' "$command_name" >&2
            missing=1
        fi
    done

    (( missing == 0 )) || die "Install the missing commands and try again."
}

require_root() {
    if (( EUID != 0 )); then
        die "Run this operation as root, for example: sudo ./$PROGRAM_NAME"
    fi
}

ask_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    local answer

    while true; do
        if [[ "$default" == "y" ]]; then
            read -r -p "$prompt [Y/n]: " answer
            answer="${answer:-y}"
        else
            read -r -p "$prompt [y/N]: " answer
            answer="${answer:-n}"
        fi

        case "${answer,,}" in
            y|yes) return 0 ;;
            n|no)  return 1 ;;
            *)     echo "Please answer yes or no." ;;
        esac
    done
}

read_path_with_default() {
    local prompt="$1"
    local default="$2"
    local result

    read -r -p "$prompt [$default]: " result
    printf '%s\n' "${result:-$default}"
}

canonicalize_existing_dir() {
    local path="$1"
    [[ -d "$path" ]] || die "Directory does not exist: $path"
    realpath -- "$path"
}

normalize_directory_path() {
    local path="$1"

    [[ "$path" == /* ]] || path="/$path"

    while [[ "$path" != "/" && "$path" == */ ]]; do
        path="${path%/}"
    done

    printf '%s\n' "$path"
}

select_home_scope() {
    local home_root="$1"
    local choice
    local username
    local user_home

    echo
    echo "1) One user home folder"
    echo "2) All user home folders under $home_root"

    while true; do
        read -r -p "Choose [1-2]: " choice
        case "$choice" in
            1)
                read -r -p "Enter the user name or home-folder name: " username
                [[ -n "$username" ]] || {
                    echo "A user name is required."
                    continue
                }

                user_home="$home_root/$username"
                [[ -d "$user_home" ]] || {
                    echo "Home directory does not exist: $user_home"
                    continue
                }

                SELECTED_SCOPE="single"
                SELECTED_USER="$username"
                SELECTED_HOMES=("$user_home")
                return 0
                ;;
            2)
                mapfile -d '' SELECTED_HOMES < <(
                    find "$home_root" -mindepth 1 -maxdepth 1 -type d -print0 |
                    sort -z
                )

                if (( ${#SELECTED_HOMES[@]} == 0 )); then
                    echo "No home directories were found under $home_root."
                    continue
                fi

                SELECTED_SCOPE="all"
                SELECTED_USER=""
                return 0
                ;;
            *)
                echo "Please choose 1 or 2."
                ;;
        esac
    done
}

build_skel_relative_list() {
    local list_file

    [[ -d "$SKEL_DIR" ]] || die "$SKEL_DIR does not exist."

    list_file="$(mktemp)"
    TEMP_LISTS+=("$list_file")

    (
        cd "$SKEL_DIR"
        find . -mindepth 1 -print0 |
            while IFS= read -r -d '' item; do
                printf '%s\0' "${item#./}"
            done
    ) > "$list_file"

    printf '%s\n' "$list_file"
}

remove_skel_from_home() {
    local home_dir="$1"
    local skel_list="$2"
    local relative
    local target
    local removed=0

    while IFS= read -r -d '' relative; do
        target="$home_dir/$relative"

        if [[ -L "$target" || -f "$target" ]]; then
            rm -f -- "$target"
            printf 'Removed: %s\n' "$target"
            removed=1
        fi
    done < "$skel_list"

    while IFS= read -r -d '' relative; do
        target="$home_dir/$relative"

        if [[ -d "$target" && ! -L "$target" ]]; then
            rmdir -- "$target" 2>/dev/null && {
                printf 'Removed empty directory: %s\n' "$target"
                removed=1
            }
        fi
    done < <(
        tr '\0' '\n' < "$skel_list" |
        awk '{ print length, $0 }' |
        sort -rn |
        cut -d' ' -f2- |
        tr '\n' '\0'
    )

    if (( removed == 0 )); then
        printf 'No matching skel files found in %s\n' "$home_dir"
    fi
}

operation_remove_skel() {
    local home_root
    local skel_list
    local home_dir

    require_root
    require_commands find realpath sort awk cut

    home_root="$(read_path_with_default \
        "Location containing the user home folders" \
        "$DEFAULT_HOME_ROOT")"
    home_root="$(canonicalize_existing_dir "$home_root")"

    select_home_scope "$home_root"
    skel_list="$(build_skel_relative_list)"

    echo
    echo "The following home directories will be checked:"
    printf '  %s\n' "${SELECTED_HOMES[@]}"
    echo
    echo "Only paths also present under $SKEL_DIR will be removed."
    echo "Existing directories are removed only when empty."

    ask_yes_no "Continue removing matching skel files?" "n" || {
        echo "Cancelled."
        return
    }

    for home_dir in "${SELECTED_HOMES[@]}"; do
        echo
        echo "Processing $home_dir"
        remove_skel_from_home "$home_dir" "$skel_list"
    done

    echo
    echo "Skel-file removal completed."
}

directory_size_bytes() {
    local total=0
    local path
    local size

    for path in "$@"; do
        size="$(du -sb -- "$path" | awk '{print $1}')"
        total=$((total + size))
    done

    printf '%s\n' "$total"
}

human_size() {
    local bytes="$1"

    if command -v numfmt >/dev/null 2>&1; then
        numfmt --to=iec-i --suffix=B "$bytes"
    else
        printf '%s bytes\n' "$bytes"
    fi
}

available_bytes_local() {
    local path="$1"
    df -PB1 -- "$path" | awk 'NR == 2 {print $4}'
}

ensure_local_space() {
    local destination_dir="$1"
    local required_bytes="$2"
    local available_bytes
    local reserve_bytes

    available_bytes="$(available_bytes_local "$destination_dir")"
    reserve_bytes=$((required_bytes + required_bytes / 20 + 64 * 1024 * 1024))

    if (( available_bytes < reserve_bytes )); then
        printf 'Required conservative estimate: %s\n' \
            "$(human_size "$reserve_bytes")" >&2
        printf 'Available at destination:      %s\n' \
            "$(human_size "$available_bytes")" >&2
        die "Not enough free space at $destination_dir."
    fi
}

mount_device_destination() {
    local device="$1"
    local mount_dir

    require_root
    require_commands mount mountpoint umount

    [[ -b "$device" ]] || die "Not a block device: $device"

    mount_dir="$(mktemp -d /tmp/bfs-home-backup-mount.XXXXXX)"
    TEMP_MOUNT="$mount_dir"

    echo "Mounting $device at $mount_dir"
    mount "$device" "$mount_dir"
    MOUNTED_PATH="$mount_dir"
}

prompt_remote_directory() {
    local username
    local host
    local default_directory
    local directory

    while true; do
        read -r -p "Remote SSH username: " username
        [[ -n "$username" ]] || {
            echo "A username is required."
            continue
        }

        read -r -p "Remote hostname or IP address: " host
        [[ -n "$host" ]] || {
            echo "A hostname or IP address is required."
            continue
        }

        default_directory="/home/$username"
        directory="$(read_path_with_default \
            "Remote destination directory" \
            "$default_directory")"
        directory="$(normalize_directory_path "$directory")"

        SCP_HOST="$username@$host"
        SCP_PATH="$directory"
        BACKUP_DEST="$SCP_HOST:$SCP_PATH"
        return
    done
}

choose_backup_destination() {
    local choice
    local destination
    local device

    echo
    echo "Backup destination:"
    echo "1) Default BFS archive directory"
    echo "2) Local directory"
    echo "3) Block device mounted automatically"
    echo "4) Remote SSH destination (stream directly; no local temporary file)"

    while true; do
        read -r -p "Choose [1-4]: " choice
        case "$choice" in
            1)
                mkdir -p -- "$DEFAULT_ARCHIVE_DIR"
                BACKUP_DEST_TYPE="local"
                BACKUP_DEST="$(realpath -- "$DEFAULT_ARCHIVE_DIR")"
                return
                ;;
            2)
                read -r -p "Enter the destination directory: " destination
                [[ -n "$destination" ]] || {
                    echo "A destination is required."
                    continue
                }

                mkdir -p -- "$destination"
                BACKUP_DEST_TYPE="local"
                BACKUP_DEST="$(realpath -- "$destination")"
                return
                ;;
            3)
                read -r -p "Enter the device path, for example /dev/sdb1: " device
                [[ -n "$device" ]] || {
                    echo "A device path is required."
                    continue
                }

                mount_device_destination "$device"
                BACKUP_DEST_TYPE="local"
                BACKUP_DEST="$MOUNTED_PATH"
                return
                ;;
            4)
                prompt_remote_directory
                BACKUP_DEST_TYPE="scp"
                return
                ;;
            *)
                echo "Please choose 1, 2, 3, or 4."
                ;;
        esac
    done
}

split_scp_destination() {
    local destination="$1"

    SCP_HOST="${destination%%:*}"
    SCP_PATH="${destination#*:}"
    SCP_PATH="$(normalize_directory_path "$SCP_PATH")"

    [[ -n "$SCP_HOST" && -n "$SCP_PATH" ]] ||
        die "Invalid SSH destination: $destination"
}

ensure_remote_space() {
    local destination="$1"
    local required_bytes="$2"
    local available_bytes
    local reserve_bytes

    split_scp_destination "$destination"

    available_bytes="$(
        ssh "$SCP_HOST" \
            "mkdir -p -- $(printf '%q' "$SCP_PATH") &&
             df -PB1 -- $(printf '%q' "$SCP_PATH") |
             awk 'NR == 2 {print \$4}'"
    )"

    [[ "$available_bytes" =~ ^[0-9]+$ ]] ||
        die "Could not determine free space at $destination."

    reserve_bytes=$((required_bytes + required_bytes / 20 + 64 * 1024 * 1024))

    if (( available_bytes < reserve_bytes )); then
        printf 'Required conservative estimate: %s\n' \
            "$(human_size "$reserve_bytes")" >&2
        printf 'Available on remote machine:   %s\n' \
            "$(human_size "$available_bytes")" >&2
        die "Not enough free space at $destination."
    fi
}

create_tar_exclude_file() {
    local home_root="$1"
    local skel_list="$2"
    shift 2
    local homes=("$@")
    local exclude_file
    local home_dir
    local home_name
    local relative

    exclude_file="$(mktemp)"
    TEMP_LISTS+=("$exclude_file")

    for home_dir in "${homes[@]}"; do
        home_name="${home_dir##*/}"

        while IFS= read -r -d '' relative; do
            printf '%s\n' "$home_name/$relative"
        done < "$skel_list"
    done > "$exclude_file"

    printf '%s\n' "$exclude_file"
}

append_volatile_excludes() {
    local exclude_file="$1"
    shift
    local home_dir
    local home_name

    for home_dir in "$@"; do
        home_name="${home_dir##*/}"

        cat >> "$exclude_file" <<EOF
$home_name/.cache
$home_name/.cache/*
$home_name/.gvfs
$home_name/.gvfs/*
$home_name/.var/app/*/cache
$home_name/.var/app/*/cache/*
$home_name/.var/app/*/.cache
$home_name/.var/app/*/.cache/*
EOF
    done
}

normalize_tar_status() {
    local status="$1"

    case "$status" in
        0)
            return 0
            ;;
        1)
            warn "Some files changed while tar was reading them."
            warn "The archive will still be verified before it is finalized."
            return 0
            ;;
        *)
            return "$status"
            ;;
    esac
}

run_tar_command() {
    local home_root="$1"
    local exclude_file="$2"
    shift 2

    local -a tar_items=("$@")
    local -a tar_options=(
        --acls
        --xattrs
        --numeric-owner
        --one-file-system
    )
    local status

    [[ "$VERBOSE_TAR" == "yes" ]] && tar_options+=(-v)
    [[ -n "$exclude_file" ]] && tar_options+=(--exclude-from="$exclude_file")

    set +e
    tar \
        "${tar_options[@]}" \
        -C "$home_root" \
        -cf - \
        "${tar_items[@]}"
    status=$?
    set -e

    normalize_tar_status "$status"
}

unique_archive_path() {
    local directory="$1"
    local base_name="$2"
    local path="$directory/$base_name"
    local counter=1
    local stem="${base_name%.tar.xz}"

    while [[ -e "$path" || -e "$path.partial" ]]; do
        path="$directory/${stem}-${counter}.tar.xz"
        ((counter++))
    done

    printf '%s\n' "$path"
}

configure_backup_display() {
    if ask_yes_no "Exclude volatile cache and runtime files?" "y"; then
        EXCLUDE_VOLATILE="yes"
    else
        EXCLUDE_VOLATILE="no"
    fi

    if ask_yes_no "Show each file as it is added to the archive?" "n"; then
        VERBOSE_TAR="yes"
    else
        VERBOSE_TAR="no"
    fi

    if command -v pv >/dev/null 2>&1; then
        if ask_yes_no "Show an overall progress meter?" "y"; then
            SHOW_PROGRESS="yes"
        else
            SHOW_PROGRESS="no"
        fi
    else
        SHOW_PROGRESS="no"
        warn "pv is not installed; the overall progress meter is unavailable."
        warn "Install the 'pv' package to enable it."
    fi
}

run_tar_stream() {
    local home_root="$1"
    local exclude_file="$2"
    local source_size="$3"
    shift 3

    local -a tar_items=("$@")

    if [[ "$SHOW_PROGRESS" == "yes" ]]; then
        run_tar_command \
            "$home_root" \
            "$exclude_file" \
            "${tar_items[@]}" |
        pv \
            --size "$source_size" \
            --timer \
            --eta \
            --rate \
            --bytes
    else
        run_tar_command \
            "$home_root" \
            "$exclude_file" \
            "${tar_items[@]}"
    fi
}

operation_backup() {
    local home_root
    local include_skel="yes"
    local skel_list=""
    local exclude_file=""
    local source_size
    local date_stamp
    local archive_name
    local archive_path
    local partial_archive
    local remote_archive
    local remote_temp
    local home_dir
    local -a tar_items=()

    require_root
    require_commands tar xz du df find realpath awk sort ssh scp

    home_root="$(read_path_with_default \
        "Location containing the user home folders" \
        "$DEFAULT_HOME_ROOT")"
    home_root="$(canonicalize_existing_dir "$home_root")"

    select_home_scope "$home_root"

    if ask_yes_no "Include files supplied by $SKEL_DIR in the backup?" "y"; then
        include_skel="yes"
    else
        include_skel="no"
        skel_list="$(build_skel_relative_list)"
        exclude_file="$(create_tar_exclude_file \
            "$home_root" "$skel_list" "${SELECTED_HOMES[@]}")"
    fi

    configure_backup_display

    if [[ "$EXCLUDE_VOLATILE" == "yes" ]]; then
        if [[ -z "$exclude_file" ]]; then
            exclude_file="$(mktemp)"
            TEMP_LISTS+=("$exclude_file")
        fi

        append_volatile_excludes "$exclude_file" "${SELECTED_HOMES[@]}"
    fi

    choose_backup_destination

    echo
    echo "Scanning selected home folder(s)..."
    source_size="$(directory_size_bytes "${SELECTED_HOMES[@]}")"
    echo "Uncompressed source size: $(human_size "$source_size")"

    if [[ "$BACKUP_DEST_TYPE" == "local" ]]; then
        ensure_local_space "$BACKUP_DEST" "$source_size"
    else
        ensure_remote_space "$BACKUP_DEST" "$source_size"
    fi

    date_stamp="$(date '+%Y-%m-%d')"

    if [[ "$SELECTED_SCOPE" == "single" ]]; then
        archive_name="home-folder-backup-${SELECTED_USER}-${date_stamp}.tar.xz"
    else
        archive_name="home-folder-backup-${date_stamp}.tar.xz"
    fi

    for home_dir in "${SELECTED_HOMES[@]}"; do
        tar_items+=("${home_dir##*/}")
    done

    echo
    echo "Home root:          $home_root"
    echo "Included folders:"
    printf '  %s\n' "${SELECTED_HOMES[@]}"
    echo "Include skel files: $include_skel"
    echo "Exclude volatile:   $EXCLUDE_VOLATILE"
    echo "Verbose file list:  $VERBOSE_TAR"
    echo "Progress meter:     $SHOW_PROGRESS"
    echo "Archive name:       $archive_name"
    echo "Destination:        $BACKUP_DEST"
    echo
    echo "The archive stores paths relative to $home_root and preserves"
    echo "permissions, ownership, ACLs, extended attributes, and hard links."

    ask_yes_no "Create this backup?" "y" || {
        echo "Cancelled."
        return
    }

    if [[ "$BACKUP_DEST_TYPE" == "local" ]]; then
        archive_path="$(unique_archive_path "$BACKUP_DEST" "$archive_name")"
        partial_archive="$archive_path.partial"

        rm -f -- "$partial_archive"

        echo
        echo "Creating compressed archive:"
        echo "  $partial_archive"

        run_tar_stream \
            "$home_root" \
            "$exclude_file" \
            "$source_size" \
            "${tar_items[@]}" |
        xz -9e -T0 > "$partial_archive"

        echo
        echo "Verifying archive..."
        xz -t -- "$partial_archive"
        tar -tJf "$partial_archive" >/dev/null

        echo "Finalizing archive..."
        mv -- "$partial_archive" "$archive_path"

        echo "Backup completed successfully:"
        echo "  $archive_path"
    else
        split_scp_destination "$BACKUP_DEST"

        ssh "$SCP_HOST" \
            "mkdir -p -- $(printf '%q' "$SCP_PATH")"

        remote_archive="$SCP_PATH/$archive_name"
        remote_temp="$remote_archive.partial"

        echo
        echo "Streaming archive directly to:"
        echo "  $SCP_HOST:$remote_temp"
        echo "No temporary local archive will be created."

        ssh "$SCP_HOST" \
            "rm -f -- $(printf '%q' "$remote_temp")"

        run_tar_stream \
            "$home_root" \
            "$exclude_file" \
            "$source_size" \
            "${tar_items[@]}" |
        xz -9e -T0 |
        ssh "$SCP_HOST" \
            "cat > $(printf '%q' "$remote_temp")"

        echo
        echo "Verifying and finalizing remote archive..."
        ssh "$SCP_HOST" \
            "xz -t -- $(printf '%q' "$remote_temp") &&
             tar -tJf $(printf '%q' "$remote_temp") >/dev/null &&
             mv -- $(printf '%q' "$remote_temp") $(printf '%q' "$remote_archive")"

        echo "Backup completed successfully:"
        echo "  $SCP_HOST:$remote_archive"
    fi
}

choose_restore_source() {
    local choice
    local source_path
    local device
    local remote_username
    local remote_host
    local remote_path
    local remote
    local local_copy

    echo
    echo "Backup source:"
    echo "1) Default BFS archive directory"
    echo "2) Local directory or archive file"
    echo "3) Block device mounted automatically"
    echo "4) SCP from another machine"

    while true; do
        read -r -p "Choose [1-4]: " choice
        case "$choice" in
            1)
                [[ -d "$DEFAULT_ARCHIVE_DIR" ]] || {
                    echo "Default archive directory does not exist:"
                    echo "  $DEFAULT_ARCHIVE_DIR"
                    continue
                }

                RESTORE_SOURCE_TYPE="local"
                RESTORE_SOURCE="$DEFAULT_ARCHIVE_DIR"
                return
                ;;
            2)
                read -r -p "Enter the archive file or directory: " source_path
                [[ -e "$source_path" ]] || {
                    echo "Path does not exist: $source_path"
                    continue
                }

                RESTORE_SOURCE_TYPE="local"
                RESTORE_SOURCE="$(realpath -- "$source_path")"
                return
                ;;
            3)
                read -r -p "Enter the device path, for example /dev/sdb1: " device
                [[ -n "$device" ]] || {
                    echo "A device path is required."
                    continue
                }

                mount_device_destination "$device"
                RESTORE_SOURCE_TYPE="local"
                RESTORE_SOURCE="$MOUNTED_PATH"
                return
                ;;
            4)
                read -r -p "Remote SSH username: " remote_username
                read -r -p "Remote hostname or IP address: " remote_host
                read -r -p "Remote archive path: " remote_path

                [[ -n "$remote_username" && -n "$remote_host" && -n "$remote_path" ]] || {
                    echo "Username, host, and archive path are required."
                    continue
                }

                remote="$remote_username@$remote_host:$remote_path"
                local_copy="$(mktemp /tmp/bfs-home-restore.XXXXXX.tar.xz)"

                echo "Downloading $remote"
                scp -- "$remote" "$local_copy"

                RESTORE_SOURCE_TYPE="local"
                RESTORE_SOURCE="$local_copy"
                TEMP_LISTS+=("$local_copy")
                return
                ;;
            *)
                echo "Please choose 1, 2, 3, or 4."
                ;;
        esac
    done
}

select_archive_file() {
    local source="$1"
    local -a archives=()
    local index

    if [[ -f "$source" ]]; then
        [[ "$source" == *.tar.xz ]] ||
            die "Selected file is not a .tar.xz archive: $source"
        SELECTED_ARCHIVE="$source"
        return
    fi

    mapfile -d '' archives < <(
        find "$source" -maxdepth 1 -type f \
            -name 'home-folder-backup-*.tar.xz' \
            -print0 |
        sort -z
    )

    case "${#archives[@]}" in
        0)
            die "No home-folder-backup-*.tar.xz files found in $source."
            ;;
        1)
            SELECTED_ARCHIVE="${archives[0]}"
            echo "Detected archive: $SELECTED_ARCHIVE"
            ;;
        *)
            echo
            echo "Available backups:"
            for index in "${!archives[@]}"; do
                printf '%d) %s\n' "$((index + 1))" "${archives[$index]}"
            done

            while true; do
                read -r -p "Choose an archive [1-${#archives[@]}]: " index

                if [[ "$index" =~ ^[0-9]+$ ]] &&
                   (( index >= 1 && index <= ${#archives[@]} )); then
                    SELECTED_ARCHIVE="${archives[$((index - 1))]}"
                    return
                fi

                echo "Invalid selection."
            done
            ;;
    esac
}

validate_archive_paths() {
    local archive="$1"
    local entry

    while IFS= read -r entry; do
        [[ -z "$entry" ]] && continue

        case "$entry" in
            /*)
                die "Archive contains an absolute path: $entry"
                ;;
            ../*|*/../*|*/..)
                die "Archive contains a parent-directory traversal: $entry"
                ;;
        esac
    done < <(tar -tJf "$archive")
}

operation_restore() {
    local restore_root
    local archive_size
    local existing_policy
    local -a tar_options=()

    require_root
    require_commands tar xz df find realpath awk sort ssh scp

    choose_restore_source
    select_archive_file "$RESTORE_SOURCE"

    echo "Testing archive integrity..."
    xz -t -- "$SELECTED_ARCHIVE"
    tar -tJf "$SELECTED_ARCHIVE" >/dev/null
    validate_archive_paths "$SELECTED_ARCHIVE"

    restore_root="$(read_path_with_default \
        "Restore home folders into" \
        "$DEFAULT_HOME_ROOT")"

    mkdir -p -- "$restore_root"
    restore_root="$(realpath -- "$restore_root")"

    archive_size="$(stat -c '%s' "$SELECTED_ARCHIVE")"
    ensure_local_space "$restore_root" "$archive_size"

    echo
    echo "Archive:      $SELECTED_ARCHIVE"
    echo "Restore root: $restore_root"
    echo
    echo "Top-level archive contents:"
    tar -tJf "$SELECTED_ARCHIVE" |
        awk -F/ 'NF && !seen[$1]++ {print "  " $1}' |
        head -n 30

    echo
    echo "Existing-file behavior:"
    echo "1) Overwrite existing files"
    echo "2) Keep existing files and restore only missing files"
    echo "3) Cancel"

    while true; do
        read -r -p "Choose [1-3]: " existing_policy
        case "$existing_policy" in
            1)
                break
                ;;
            2)
                tar_options+=(--skip-old-files)
                break
                ;;
            3)
                echo "Cancelled."
                return
                ;;
            *)
                echo "Please choose 1, 2, or 3."
                ;;
        esac
    done

    echo
    warn "Restoration can overwrite data under $restore_root."

    ask_yes_no "Proceed with restoration?" "n" || {
        echo "Cancelled."
        return
    }

    tar \
        --acls \
        --xattrs \
        --numeric-owner \
        --same-owner \
        --same-permissions \
        "${tar_options[@]}" \
        -C "$restore_root" \
        -xJf "$SELECTED_ARCHIVE"

    echo
    echo "Restore completed successfully into:"
    echo "  $restore_root"
}

show_menu() {
    echo
    echo "BFS-Linux Home Migration Utility"
    echo "================================"
    echo "1) Remove /etc/skel files from home folder(s)"
    echo "2) Back up home folder(s)"
    echo "3) Restore a home-folder backup"
    echo "4) Quit"
    echo
}

main() {
    local choice

    while true; do
        show_menu
        read -r -p "Choose [1-4]: " choice

        case "$choice" in
            1) operation_remove_skel ;;
            2) operation_backup ;;
            3) operation_restore ;;
            4)
                echo "Goodbye."
                exit 0
                ;;
            *)
                echo "Please choose 1, 2, 3, or 4."
                ;;
        esac
    done
}

main "$@"
