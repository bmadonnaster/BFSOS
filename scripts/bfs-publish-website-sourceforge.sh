#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SITE="$ROOT/website"
SF_USER="${SF_USER:-}"
SF_PROJECT="${SF_PROJECT:-bfsos}"
SF_HOST="${SF_WEB_HOST:-web.sourceforge.net}"
REMOTE="/home/project-web/$SF_PROJECT/htdocs/"
mode=dry-run

usage() {
    cat <<USAGE
Usage: SF_USER=<sourceforge-user> $0 [--dry-run|--publish]

Synchronize website/ to SourceForge Project Web.
Default mode is --dry-run. --publish performs the upload.
USAGE
}

case "${1:---dry-run}" in
    --dry-run) mode=dry-run ;;
    --publish) mode=publish ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
esac

[[ -n "$SF_USER" ]] || { echo "ERROR: set SF_USER to your SourceForge username" >&2; exit 1; }
[[ -f "$SITE/index.html" && -f "$SITE/style.css" ]] || { echo "ERROR: website tree is incomplete: $SITE" >&2; exit 1; }
command -v rsync >/dev/null 2>&1 || { echo "ERROR: rsync is required" >&2; exit 1; }
command -v ssh >/dev/null 2>&1 || { echo "ERROR: ssh is required" >&2; exit 1; }

dest="$SF_USER@$SF_HOST:$REMOTE"
printf 'BFSOS website source: %s\n' "$SITE/"
printf 'SourceForge target:    %s\n' "$dest"
printf 'Mode:                  %s\n' "$mode"

args=(-av --delete --no-perms -e ssh)
[[ "$mode" == publish ]] || args+=(--dry-run)
rsync "${args[@]}" "$SITE/" "$dest"

if [[ "$mode" == dry-run ]]; then
    echo "Dry-run only. Re-run with --publish after review."
else
    echo "Website published: https://${SF_PROJECT}.sourceforge.io/"
fi
