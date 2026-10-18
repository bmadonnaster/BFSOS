# Begin ~/.bashrc
# Written for Beyond Linux From Scratch
# by James Robertson <jameswrobertson@earthlink.net>

# Personal aliases and functions.

# Personal environment variables and startup programs should go in
# ~/.bash_profile.  System wide environment variables and startup
# programs are in /etc/profile.  System wide aliases and functions are
# in /etc/bashrc.

if [ -f "/etc/bashrc" ] ; then
  source /etc/bashrc
fi

# Set up user specific i18n variables
#export LANG=<ll>_<CC>.<charmap><@modifiers>
# BFSOS system-wide Fastfetch welcome screen
# Run only for interactive, non-root terminals.
if [[ $- == *i* ]] && [[ $EUID -ne 0 ]] && [[ -t 1 ]] &&
   command -v fastfetch >/dev/null 2>&1 &&
   [[ -r /usr/share/fastfetch/bfsos/config.jsonc ]]; then
    fastfetch --config /usr/share/fastfetch/bfsos/config.jsonc
fi
# End ~/.bashrc
