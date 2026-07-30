#!/usr/bin/env bash
#
# git-update-bfs-linux-install-v2.sh
#
# Locate ~/bfs-linux-install, configure and verify Codeberg SSH access,
# stage all changes, commit them with today's date, and push.
#

set -Eeuo pipefail

PROGRAM_NAME="${0##*/}"
PROJECT_NAME="bfs-linux-install"
CODEBERG_HOST="codeberg.org"
CODEBERG_SSH_USER="git"
CODEBERG_KEY_NAME="id_ed25519_codeberg"

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

warn() {
    printf 'WARNING: %s\n' "$*" >&2
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
            *) echo "Please answer yes or no." ;;
        esac
    done
}

find_user_home() {
    if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
        getent passwd "$SUDO_USER" | cut -d: -f6
    else
        printf '%s\n' "$HOME"
    fi
}

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

get_local_hostname() {
    local host_name=""

    if command -v uname >/dev/null 2>&1; then
        host_name="$(uname -n 2>/dev/null || true)"
    fi

    if [[ -z "$host_name" && -r /proc/sys/kernel/hostname ]]; then
        read -r host_name < /proc/sys/kernel/hostname || true
    fi

    [[ -n "$host_name" ]] || host_name="unknown-host"
    printf '%s\n' "$host_name"
}

ensure_ssh_directory() {
    mkdir -p -- "$SSH_DIR"
    chmod 700 "$SSH_DIR"
}

ensure_codeberg_key() {
    if [[ -f "$SSH_PRIVATE_KEY" && -f "$SSH_PUBLIC_KEY" ]]; then
        echo "Codeberg SSH key found:"
        echo "  $SSH_PUBLIC_KEY"
        return
    fi

    if [[ -e "$SSH_PRIVATE_KEY" || -e "$SSH_PUBLIC_KEY" ]]; then
        die "Only one half of the Codeberg SSH key pair exists. Repair or remove it manually."
    fi

    echo
    echo "No dedicated Codeberg SSH key was found."
    echo "The script can create:"
    echo "  $SSH_PRIVATE_KEY"
    echo

    ask_yes_no "Generate a new Ed25519 Codeberg SSH key?" "y" || {
        die "An SSH key is required for automatic Codeberg authentication."
    }

    local comment
    comment="${USER:-user}@$(get_local_hostname)-codeberg"

    echo
    echo "ssh-keygen will ask for an optional key passphrase."
    echo "A passphrase is recommended; ssh-agent can remember it during your session."
    echo

    ssh-keygen \
        -t ed25519 \
        -a 100 \
        -C "$comment" \
        -f "$SSH_PRIVATE_KEY"

    chmod 600 "$SSH_PRIVATE_KEY"
    chmod 644 "$SSH_PUBLIC_KEY"

    echo
    echo "SSH key created."
}

ensure_ssh_config() {
    local config_file="$SSH_DIR/config"
    local begin_marker="# BEGIN BFS CODEBERG"
    local end_marker="# END BFS CODEBERG"

    touch "$config_file"
    chmod 600 "$config_file"

    if grep -Fq "$begin_marker" "$config_file"; then
        return
    fi

    cat >> "$config_file" <<EOF

$begin_marker
Host codeberg.org
    HostName codeberg.org
    User git
    IdentityFile $SSH_PRIVATE_KEY
    IdentitiesOnly yes
$end_marker
EOF

    echo "Added Codeberg SSH settings to:"
    echo "  $config_file"
}

show_public_key() {
    echo
    echo "Add this PUBLIC key to Codeberg:"
    echo "================================"
    cat "$SSH_PUBLIC_KEY"
    echo "================================"
    echo
    echo "In Codeberg, open:"
    echo "  Settings -> SSH / GPG Keys -> Add Key"
    echo
    echo "Never upload or share the private key:"
    echo "  $SSH_PRIVATE_KEY"
    echo

    if command -v wl-copy >/dev/null 2>&1 &&
       [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        wl-copy -t text/plain < "$SSH_PUBLIC_KEY"
        echo "The public key was copied to the Wayland clipboard."
    elif command -v xclip >/dev/null 2>&1 &&
         [[ -n "${DISPLAY:-}" ]]; then
        xclip -selection clipboard < "$SSH_PUBLIC_KEY"
        echo "The public key was copied to the X11 clipboard."
    fi
}

verify_codeberg_ssh() {
    local output
    local status

    echo
    echo "Verifying Codeberg SSH authentication..."

    set +e
    output="$(
        ssh \
            -o BatchMode=yes \
            -o ConnectTimeout=15 \
            -T "$CODEBERG_SSH_USER@$CODEBERG_HOST" 2>&1
    )"
    status=$?
    set -e

    # Forgejo normally returns a nonzero status because shell access is disabled,
    # so verify the successful-authentication message instead of the exit status.
    if grep -qi "successfully authenticated" <<< "$output"; then
        echo "$output"
        echo "Codeberg SSH authentication verified."
        return 0
    fi

    echo "$output"
    return "$status"
}

ensure_codeberg_authentication() {
    ensure_ssh_directory
    ensure_codeberg_key
    ensure_ssh_config

    if verify_codeberg_ssh; then
        return
    fi

    echo
    warn "Codeberg did not accept the SSH key yet."
    show_public_key
    echo "After adding the public key to Codeberg, press Enter to test again."
    read -r

    verify_codeberg_ssh ||
        die "Codeberg SSH authentication could not be verified."
}

convert_origin_to_ssh() {
    local remote_url
    local owner_repo=""

    remote_url="$(git remote get-url origin 2>/dev/null)" ||
        die "This repository has no 'origin' remote."

    case "$remote_url" in
        git@codeberg.org:*|ssh://git@codeberg.org/*)
            echo "Origin already uses Codeberg SSH:"
            echo "  $remote_url"
            return
            ;;
        https://codeberg.org/*)
            owner_repo="${remote_url#https://codeberg.org/}"
            ;;
        http://codeberg.org/*)
            owner_repo="${remote_url#http://codeberg.org/}"
            ;;
        *)
            die "The origin remote is not a recognized Codeberg URL: $remote_url"
            ;;
    esac

    owner_repo="${owner_repo#/}"
    [[ -n "$owner_repo" ]] || die "Could not determine the Codeberg repository path."

    local ssh_url="git@codeberg.org:$owner_repo"

    echo
    echo "Changing origin from HTTPS to SSH:"
    echo "  Old: $remote_url"
    echo "  New: $ssh_url"

    git remote set-url origin "$ssh_url"
}

main() {
    local user_home
    local project_dir
    local commit_date
    local commit_message

    require_commands git ssh ssh-keygen getent grep

    user_home="$(find_user_home)"
    [[ -n "$user_home" ]] || die "Could not determine the current user's home directory."

    PROJECT_DIR="$user_home/$PROJECT_NAME"
    SSH_DIR="$user_home/.ssh"
    SSH_PRIVATE_KEY="$SSH_DIR/$CODEBERG_KEY_NAME"
    SSH_PUBLIC_KEY="$SSH_PRIVATE_KEY.pub"

    echo "BFS Linux Git Update Utility"
    echo "============================"
    echo

    [[ -d "$PROJECT_DIR" ]] ||
        die "Project directory not found: $PROJECT_DIR"

    [[ -d "$PROJECT_DIR/.git" ]] ||
        die "Not a Git repository: $PROJECT_DIR"

    cd "$PROJECT_DIR"

    echo "Repository:"
    echo "  $PROJECT_DIR"

    ensure_codeberg_authentication
    convert_origin_to_ssh

    echo
    echo "Checking repository status..."
    git status --short

    echo
    echo "Staging all new, modified, and deleted files..."
    git add -A

    if git diff --cached --quiet; then
        echo
        echo "Nothing to commit."
        echo "Checking whether an existing local commit needs to be pushed..."
        git push
        echo
        echo "Repository is up to date."
        exit 0
    fi

    commit_date="$(date '+%Y-%m-%d')"
    commit_message="Updated project $commit_date"

    echo
    echo "Commit message:"
    echo "  $commit_message"

    ask_yes_no "Commit and push these changes?" "y" || {
        echo "Cancelled. Changes remain staged."
        exit 0
    }

    git commit -m "$commit_message"

    echo
    echo "Pushing to Codeberg..."
    git push

    echo
    echo "BFS Linux project update completed successfully."
}

main "$@"
