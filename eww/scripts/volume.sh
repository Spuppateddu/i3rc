#!/usr/bin/env bash
# Default sink volume as JSON (deflisten); "scroll up|down" adjusts the level.

get() {
    local lvl mut
    lvl=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -oP '\d+(?=%)' | head -n1)
    mut=$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | awk '{print ($2 == "yes") ? "true" : "false"}')
    printf '{"level":%s,"muted":%s}\n' "${lvl:-0}" "${mut:-false}"
}

if [ "$1" = "scroll" ]; then
    if [ "$2" = "up" ]; then
        pactl set-sink-volume @DEFAULT_SINK@ +3%
    else
        pactl set-sink-volume @DEFAULT_SINK@ -3%
    fi
    exit 0
fi

get
pactl subscribe 2>/dev/null | grep --line-buffered "on sink" | while read -r _; do
    get
done
