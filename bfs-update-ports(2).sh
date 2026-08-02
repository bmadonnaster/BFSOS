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

PROGRAM_NAME="${0##*/}"
CODEBERG_HOST="codeberg.org"
CODEBERG_SSH_USER="git"
CODEBERG_KEY_NAME="id_ed25519_codeberg"

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

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

find_httpup_repgen() {
    local candidate=""

    if command -v httpup-repgen >/dev/null 2>&1; then
        command -v httpup-repgen
        return 0
    fi

    for candidate in \
        /usr/bin/httpup-repgen \
        /usr/local/bin/httpup-repgen \
        /mnt/bfs/usr/bin/httpup-repgen
    do
        if [[ -x "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

ensure_codeberg_ssh() {
    local ssh_dir="$HOME/.ssh"
    local priv="$ssh_dir/$CODEBERG_KEY_NAME"
    local pub="$priv.pub"
    local test_file=""

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

    test_file="$(mktemp /tmp/bfs-codeberg-test.XXXXXX)"
    ssh -o BatchMode=yes -o ConnectTimeout=10 \
        -T git@codeberg.org >"$test_file" 2>&1 || true

    if ! grep -qi "successfully authenticated" "$test_file"; then
        cat "$test_file"
        rm -f "$test_file"

        echo
        echo "Add the SSH key above to Codeberg, then rerun."
        exit 1
    fi

    rm -f "$test_file"
}

cleanup_repo() {
    if [[ -d "$REPO_DIR" ]]; then
        echo "Removing temporary repository: $REPO_DIR"
        rm -rf -- "$REPO_DIR"
    fi
}

regenerate_repo_manifests() {
    local ports_dir="$1"
    local repgen="$2"
    local collection=""
    local generated=0

    echo "Regenerating httpup REPO manifests..."

    while IFS= read -r -d '' collection; do
        [[ -d "$collection" ]] || continue

        echo "  Generating $(basename "$collection")/REPO"
        (
            cd "$collection"
            "$repgen"
        ) || die "Failed to generate REPO in $collection"

        generated=$((generated + 1))
    done < <(
        find "$ports_dir" \
            -mindepth 1 \
            -maxdepth 1 \
            -type d \
            -print0 |
        sort -z
    )

    ((generated > 0)) ||
        die "No port collection directories were found in $ports_dir."

    echo "Generated $generated REPO manifest(s)."
}

for c in git ssh ssh-keygen grep find sort cp rm date mktemp basename; do
    command -v "$c" >/dev/null 2>&1 ||
        die "$c is not installed."
done

HTTPUP_REPGEN="$(find_httpup_repgen)" ||
    die "httpup-repgen was not found. Install httpup or make /mnt/bfs/usr/bin/httpup-repgen available."

ensure_codeberg_ssh

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

# 5. Regenerate every collection's server-side httpup REPO manifest.
regenerate_repo_manifests "$REPO_DIR/ports" "$HTTPUP_REPGEN"

# 6. Remove client-side httpup state files from the repository copy.
#    These are generated on systems running ports -u and should not be pushed.
echo "Removing client-side httpup state files..."
find "$REPO_DIR/ports" -type f \
    \( -name '.httpup-repo.current' -o -name '.httpup-urlinfo' \) \
    -delete

# 7. Stage all changes.
git -C "$REPO_DIR" add --all

# Avoid creating an empty commit.
if git -C "$REPO_DIR" diff --cached --quiet; then
    echo "No ports changes were detected."
    cleanup_repo
    exit 0
fi

# 8. Commit with the current date.
COMMIT_MESSAGE="updated ports $(date '+%Y-%m-%d')"

echo "Creating commit: $COMMIT_MESSAGE"
git -C "$REPO_DIR" commit -m "$COMMIT_MESSAGE"

# 9. Push.
echo "Pushing changes to Codeberg..."
git -C "$REPO_DIR" push

# 10. Remove the temporary clone only after a successful push.
cleanup_repo

echo "BFS-Linux ports update completed successfully."
