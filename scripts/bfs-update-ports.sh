#!/usr/bin/env bash
#
# bfs-update-ports.sh
#
# Synchronize ~/bfs-linux-install/ports with the BFS-Linux Codeberg repo.
# This script may be stored and run from any subfolder.
#

set -Eeuo pipefail

INSTALL_DIR="$HOME/bfs-linux-install"
SOURCE_PORTS="$INSTALL_DIR/ports"

REPO_URL="git@codeberg.org:bmadonnaster/BFS-Linux.git"
REPO_DIR="$HOME/BFS-Linux"

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}


PROGRAM_NAME="${0##*/}"
CODEBERG_HOST="codeberg.org"
CODEBERG_SSH_USER="git"
CODEBERG_KEY_NAME="id_ed25519_codeberg"

get_local_hostname() {
    if command -v uname >/dev/null 2>&1; then
        uname -n 2>/dev/null && return
    fi
    if [[ -r /proc/sys/kernel/hostname ]]; then
        cat /proc/sys/kernel/hostname
        return
    fi
    echo unknown-host
}

ensure_codeberg_ssh() {
    local ssh_dir="$HOME/.ssh"
    local priv="$ssh_dir/$CODEBERG_KEY_NAME"
    local pub="$priv.pub"
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"

    if [[ ! -f "$priv" ]]; then
        echo "Creating dedicated Codeberg SSH key..."
        ssh-keygen -t ed25519 -a 100 \
            -C "${USER:-user}@$(get_local_hostname)-codeberg" \
            -f "$priv"
        chmod 600 "$priv"
        chmod 644 "$pub"
        echo
        echo "Add this public key to Codeberg:"
        cat "$pub"
        echo
        echo "Then rerun this script."
        exit 1
    fi

    touch "$ssh_dir/config"
    chmod 600 "$ssh_dir/config"
    if ! grep -q '^Host codeberg\.org$' "$ssh_dir/config"; then
cat >>"$ssh_dir/config" <<EOF

Host codeberg.org
    HostName codeberg.org
    User git
    IdentityFile $priv
    IdentitiesOnly yes
EOF
    fi

    ssh -o BatchMode=yes -o ConnectTimeout=10 -T git@codeberg.org >/tmp/bfs-codeberg-test.$$ 2>&1 || true
    if ! grep -qi "successfully authenticated" /tmp/bfs-codeberg-test.$$; then
        cat /tmp/bfs-codeberg-test.$$
        rm -f /tmp/bfs-codeberg-test.$$
        echo
        echo "Add the SSH key above to Codeberg, then rerun."
        exit 1
    fi
    rm -f /tmp/bfs-codeberg-test.$$
}

cleanup_repo() {
    if [[ -d "$REPO_DIR" ]]; then
        echo "Removing temporary repository: $REPO_DIR"
        rm -rf -- "$REPO_DIR"
    fi
}

for c in git ssh ssh-keygen grep; do command -v "$c" >/dev/null 2>&1 || die "$c is not installed."; done

ensure_codeberg_ssh()

# 1. Verify ~/bfs-linux-install exists.
[[ -d "$INSTALL_DIR" ]] ||
    die "$INSTALL_DIR does not exist."

[[ -d "$SOURCE_PORTS" ]] ||
    die "$SOURCE_PORTS does not exist."

# 2. Clone BFS-Linux into the current user's home directory,
#    or update it if it already exists.
if [[ -e "$REPO_DIR" && ! -d "$REPO_DIR/.git" ]]; then
    die "$REPO_DIR exists but is not a Git repository."
fi

if [[ -d "$REPO_DIR/.git" ]]; then
    echo "Updating existing repository: $REPO_DIR"
    git -C "$REPO_DIR" pull --ff-only
else
    echo "Cloning BFS-Linux into $REPO_DIR"
    git clone "$REPO_URL" "$REPO_DIR"
fi

# 3. Remove the repository's existing ports folder.
echo "Removing old ports folder..."
rm -rf -- "$REPO_DIR/ports"

# 4. Copy ports from ~/bfs-linux-install.
echo "Copying $SOURCE_PORTS to $REPO_DIR/ports"
cp -a -- "$SOURCE_PORTS" "$REPO_DIR/ports"

# 5. Stage all changes.
git -C "$REPO_DIR" add --all

# Avoid creating an empty commit.
if git -C "$REPO_DIR" diff --cached --quiet; then
    echo "No ports changes were detected."
    cleanup_repo
    exit 0
fi

# 6. Commit with the current date.
COMMIT_MESSAGE="updated ports $(date '+%Y-%m-%d')"

echo "Creating commit: $COMMIT_MESSAGE"
git -C "$REPO_DIR" commit -m "$COMMIT_MESSAGE"

# 7. Push. Git will request credentials if necessary.
echo "Pushing changes to Codeberg..."
git -C "$REPO_DIR" push

# 8. Remove the temporary clone only after a successful push.
cleanup_repo

echo "BFS-Linux ports update completed successfully."
