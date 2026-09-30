#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="${BFSOS_REPO_ROOT:-$HOME/BFSOS}"
REMOTE_HTTPS="https://github.com/bmadonnaster/BFSOS.git"
REMOTE_SSH="git@github.com:bmadonnaster/BFSOS.git"

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }

[[ -d "$REPO_ROOT/.git" ]] || die "$REPO_ROOT is not a Git checkout"
command -v git >/dev/null 2>&1 || die "git is not installed"

# BFSOS-owned collections are transported by Git now. Remove only obsolete
# generated HttpUp state from the project tree; third-party user configs under
# /etc/ports are outside this maintainer checkout and are not touched here.
#
# Do NOT delete .footprint/.signature metadata here. Those files are package
# integrity data and may be intentionally maintained. Untracked metadata should
# be reviewed by the maintainer rather than silently destroyed by a Git helper.
if [[ -d "$REPO_ROOT/ports" ]]; then
    find "$REPO_ROOT/ports" -type f \
        \( -name '.httpup-repo.current' -o -name '.httpup-urlinfo' -o -name REPO \) \
        -delete
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

# Stage normal project changes, but do not automatically add newly generated
# package-integrity metadata. Tracked/reviewed metadata updates are still staged
# normally; only previously-untracked .footprint/.signature/.md5sum files are
# left for an explicit maintainer decision.
mapfile -d '' -t _bfs_untracked_integrity < <(
    git -C "$REPO_ROOT" ls-files --others --exclude-standard -z -- \
        ':(glob)ports/**/.footprint' \
        ':(glob)ports/**/.signature' \
        ':(glob)ports/**/.md5sum'
)
git -C "$REPO_ROOT" add --all
if ((${#_bfs_untracked_integrity[@]})); then
    git -C "$REPO_ROOT" restore --staged -- "${_bfs_untracked_integrity[@]}" 2>/dev/null || true
    warn "Untracked package-integrity metadata was left unstaged for review:"
    printf '  %s\n' "${_bfs_untracked_integrity[@]}" >&2
fi
unset _bfs_untracked_integrity

if git -C "$REPO_ROOT" diff --cached --quiet; then
    echo "No BFSOS changes to commit."
    exit 0
fi

message="${1:-updated BFSOS $(date '+%Y-%m-%d')}"
git -C "$REPO_ROOT" commit -m "$message"
git -C "$REPO_ROOT" push

echo "BFSOS update pushed successfully."
