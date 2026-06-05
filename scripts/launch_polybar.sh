#!/usr/bin/env bash
# Launch polybar on every connected monitor.
#
# Only one polybar instance per X session can own the system tray, so we
# launch `bar/main` (with tray) on one monitor and `bar/secondary` (no tray)
# on the rest. Picks xrandr's primary monitor for the tray bar, or falls
# back to the first connected output.

killall -q polybar
while pgrep -x polybar >/dev/null; do sleep 0.1; done

CONFIG="$HOME/.i3rc/polybar/config.ini"

if ! type xrandr >/dev/null 2>&1; then
    polybar --reload main -c "$CONFIG" &
    exit 0
fi

mapfile -t CONNECTED < <(xrandr --query | awk '/ connected/ {print $1}')

PRIMARY=$(xrandr --query | awk '/ connected primary/ {print $1; exit}')

# If primary isn't actually connected (or none flagged), use first connected.
if [[ -z "$PRIMARY" ]] || ! printf '%s\n' "${CONNECTED[@]}" | grep -qx "$PRIMARY"; then
    PRIMARY="${CONNECTED[0]}"
fi

for m in "${CONNECTED[@]}"; do
    if [[ "$m" == "$PRIMARY" ]]; then
        MONITOR=$m polybar --reload main -c "$CONFIG" &
    else
        MONITOR=$m polybar --reload secondary -c "$CONFIG" &
    fi
done
