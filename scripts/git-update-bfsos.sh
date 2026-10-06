#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="${BFSOS_REPO_ROOT:-$HOME/BFSOS}"
REMOTE_HTTPS="https://github.com/bmadonnaster/BFSOS.git"
REMOTE_SSH="git@github.com:bmadonnaster/BFSOS.git"

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }

usage() {
    cat <<'EOF'
Usage:
  git-update-bfsos.sh [OPTIONS] [COMMIT MESSAGE]

Options:
  -D, --delete-metadata
      Delete all package-generated .footprint, .md5sum, and .signature files
      under ports/ before staging the commit. Tracked files are therefore
      committed as deletions; untracked files are simply removed.

  -h, --help
      Show this help.

Examples:
  git-update-bfsos.sh
  git-update-bfsos.sh "Update BFSOS ports"
  git-update-bfsos.sh --delete-metadata
  git-update-bfsos.sh --delete-metadata "Refresh ports without generated metadata"
EOF
}

delete_metadata=0
commit_parts=()

while (($#)); do
    case "$1" in
        -D|--delete-metadata)
            delete_metadata=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            while (($#)); do
                commit_parts+=("$1")
                shift
            done
            ;;
        -*)
            die "unknown option: $1 (use --help)"
            ;;
        *)
            commit_parts+=("$1")
            shift
            ;;
    esac
done

[[ -d "$REPO_ROOT/.git" ]] || die "$REPO_ROOT is not a Git checkout"
command -v git >/dev/null 2>&1 || die "git is not installed"

# BFSOS-owned collections are transported by Git now. Remove only obsolete
# generated HttpUp state from the project tree; third-party user configs under
# /etc/ports are outside this maintainer checkout and are not touched here.
if [[ -d "$REPO_ROOT/ports" ]]; then
    find "$REPO_ROOT/ports" -type f         \( -name '.httpup-repo.current' -o -name '.httpup-urlinfo' -o -name REPO \)         -delete

    if ((delete_metadata)); then
        echo "Deleting generated package metadata under ports/..."
        find "$REPO_ROOT/ports" -type f             \( -name '.footprint' -o -name '.md5sum' -o -name '.signature' \)             -print -delete
    fi
fi

remote="$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null || true)"
desired="$REMOTE_SSH"

if [[ -z "$remote" ]]; then
    git -C "$REPO_ROOT" remote add origin "$desired"
elif [[ "$remote" != "$desired" ]]; then
    git -C "$REPO_ROOT" remote set-url origin "$desired"
fi

# Do not merge remote changes implicitly over local edits.
if ! git -C "$REPO_ROOT" diff --quiet || ! git -C "$REPO_ROOT" diff --cached --quiet; then
    warn "Local tracked changes are present; skipping pull before commit."
else
    git -C "$REPO_ROOT" pull --ff-only || die "git pull --ff-only failed"
fi

if ((delete_metadata)); then
    # With the explicit delete switch, tracked metadata deletions should be staged.
    git -C "$REPO_ROOT" add --all
else
    # Default behavior: stage normal project changes, but do not automatically add
    # newly generated package-integrity metadata. Tracked/reviewed metadata updates
    # are still staged normally; only previously-untracked files are left for an
    # explicit maintainer decision.
    mapfile -d '' -t _bfs_untracked_integrity < <(
        git -C "$REPO_ROOT" ls-files --others --exclude-standard -z --             ':(glob)ports/**/.footprint'             ':(glob)ports/**/.signature'             ':(glob)ports/**/.md5sum'
    )

    git -C "$REPO_ROOT" add --all

    if ((${#_bfs_untracked_integrity[@]})); then
        git -C "$REPO_ROOT" restore --staged -- "${_bfs_untracked_integrity[@]}" 2>/dev/null || true
        warn "Untracked package-integrity metadata was left unstaged for review:"
        printf '  %s\n' "${_bfs_untracked_integrity[@]}" >&2
    fi

    unset _bfs_untracked_integrity
fi

if git -C "$REPO_ROOT" diff --cached --quiet; then
    echo "No BFSOS changes to commit."
    exit 0
fi

if ((${#commit_parts[@]})); then
    message="${commit_parts[*]}"
else
    message="updated BFSOS $(date '+%Y-%m-%d')"
fi

git -C "$REPO_ROOT" commit -m "$message"
git -C "$REPO_ROOT" push

echo "BFSOS update pushed successfully."
