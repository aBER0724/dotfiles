#!/bin/sh
# Start nbshell and keep its bar out of the way: waybar owns the top bar
# (niri/config.kdl spawns it right after this script).
#
# `nbshell bar hide` only unmaps the bar window (nbshell/bar-visibility.patch),
# so the launcher, notifications, OSD, screensaver and the Alt+T theme chain
# keep running. Retry instead of sleeping a fixed time: the IPC socket shows up
# a moment after systemd reports the unit as started.
set -u
export PATH="$HOME/.local/bin:$PATH"

systemctl --user start nbshell.service >/dev/null 2>&1 || true

attempt=0
while [ "$attempt" -lt 40 ]; do
    attempt=$((attempt + 1))
    if nbshell bar hide >/dev/null 2>&1; then
        # The first answer can arrive while the bar is still mapping, so confirm
        # once more after it has had time to settle. hide is idempotent.
        sleep 0.5
        nbshell bar hide >/dev/null 2>&1 || true
        exit 0
    fi
    sleep 0.25
done

echo "nbshell: bar is still visible after 10s; run 'nbshell bar hide' by hand." >&2
exit 1
