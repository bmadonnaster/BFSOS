# Source from /etc/bashrc, not directly from PAM or the login banner.
# Never print anything to commands, pipelines, remote noninteractive SSH, etc.
case $- in *i*) ;; *) return 0 ;; esac
[ -t 1 ] || return 0
[ "${BFSOS_NO_FETCH:-0}" != 1 ] || return 0
[ "${TERM:-dumb}" != dumb ] || return 0
command -v fastfetch >/dev/null 2>&1 || return 0
# Avoid printing twice if login startup sources /etc/bashrc more than once.
[ "${BFSOS_FETCH_SHOWN:-0}" != 1 ] || return 0
BFSOS_FETCH_SHOWN=1
fastfetch --config /usr/share/fastfetch/bfsos/config.jsonc 2>/dev/null || true
