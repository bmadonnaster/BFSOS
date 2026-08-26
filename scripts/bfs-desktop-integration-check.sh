#!/bin/sh
# BFSOS Plasma/PipeWire integration sanity check.
# Non-destructive: reports session, unit, and audio integration state.

set -u

fail=0
ok()   { printf 'OK:   %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*"; }
bad()  { printf 'FAIL: %s\n' "$*"; fail=1; }

echo "== PAM / logind =="
if grep -Eq '^[[:space:]]*session[[:space:]]+.*pam_systemd\.so' /etc/pam.d/system-session 2>/dev/null; then
    ok "/etc/pam.d/system-session includes pam_systemd"
else
    bad "/etc/pam.d/system-session does not include pam_systemd"
fi

uid="$(id -u)"
if [ -d "/run/user/$uid" ]; then
    ok "/run/user/$uid exists"
else
    bad "/run/user/$uid missing"
fi

echo
echo "== Plasma systemd user units =="
for unit in \
    plasma-workspace.target \
    plasma-workspace-x11.target \
    plasma-kactivitymanagerd.service \
    plasma-kscreen.service
do
    if systemctl --user cat "$unit" >/dev/null 2>&1; then
        ok "$unit visible"
    else
        bad "$unit missing from systemd user unit path"
    fi
done

if [ -d /opt/kf6/lib/systemd ]; then
    warn "/opt/kf6/lib/systemd still exists; new packages should stage KF6 systemd units in /usr/lib/systemd"
else
    ok "no live /opt/kf6/lib/systemd integration tree"
fi

echo
echo "== PipeWire audio =="
for unit in pipewire.socket pipewire-pulse.socket wireplumber.service; do
    if systemctl --user is-active "$unit" >/dev/null 2>&1; then
        ok "$unit active"
    else
        warn "$unit not active"
    fi
done

if pgrep -x pulseaudio >/dev/null 2>&1; then
    bad "standalone PulseAudio daemon is running"
else
    ok "standalone PulseAudio daemon is not running"
fi

if command -v pactl >/dev/null 2>&1; then
    server="$(pactl info 2>/dev/null | sed -n 's/^Server Name:[[:space:]]*//p' | head -1)"
    case "$server" in
        *PipeWire*) ok "Pulse protocol served by $server" ;;
        "") bad "pactl cannot connect to the Pulse protocol socket" ;;
        *) bad "Pulse protocol is served by legacy server: $server" ;;
    esac
else
    warn "pactl not installed"
fi

if command -v wpctl >/dev/null 2>&1; then
    if wpctl status 2>/dev/null | grep -q 'Audio'; then
        ok "wpctl sees PipeWire audio graph"
    else
        bad "wpctl does not report an audio graph"
    fi
else
    warn "wpctl not installed"
fi

if command -v speaker-test >/dev/null 2>&1; then
    ok "speaker-test available (alsa-utils)"
else
    warn "speaker-test missing (install/check alsa-utils)"
fi

exit "$fail"
