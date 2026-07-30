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

REPO_URL="https://codeberg.org/bmadonnaster/BFS-Linux.git"
REPO_DIR="$HOME/BFS-Linux"

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

cleanup_repo() {
    if [[ -d "$REPO_DIR" ]]; then
        echo "Removing temporary repository: $REPO_DIR"
        rm -rf -- "$REPO_DIR"
    fi
}

command -v git >/dev/null 2>&1 ||
    die "git is not installed or is not available in PATH."

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
