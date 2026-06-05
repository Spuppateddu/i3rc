#!/usr/bin/env bash
# Polybar battery widget — auto-detects a battery and shows %/charging state.
# Outputs an empty line (and hides its leading separator) on desktops with no battery.

INTERVAL=10

pick_battery() {
    for path in /sys/class/power_supply/*; do
        [ -r "$path/type" ] || continue
        [ "$(cat "$path/type")" = "Battery" ] || continue
        echo "${path##*/}"
        return
    done
}

pick_adapter() {
    for path in /sys/class/power_supply/*; do
        [ -r "$path/type" ] || continue
        [ "$(cat "$path/type")" = "Mains" ] || continue
        echo "${path##*/}"
        return
    done
}

capacity_icon() {
    local pct=$1 charging=$2
    if [ "$charging" = "1" ]; then
        printf '%%{F#a6e3a1}%%{T2}%s%%{T-}%%{F-}' ""
        return
    fi
    if   (( pct <= 20 )); then color="#f38ba8"; glyph=""
    elif (( pct <= 40 )); then color="#fab387"; glyph=""
    elif (( pct <= 60 )); then color="#f9e2af"; glyph=""
    elif (( pct <= 80 )); then color="#a6e3a1"; glyph=""
    else                        color="#a6e3a1"; glyph=""
    fi
    printf '%%{F%s}%%{T2}%s%%{T-}%%{F-}' "$color" "$glyph"
}

while :; do
    bat=$(pick_battery)
    if [ -z "$bat" ]; then
        echo ""
        sleep "$INTERVAL"
        continue
    fi

    pct=$(cat "/sys/class/power_supply/$bat/capacity" 2>/dev/null || echo 0)
    status=$(cat "/sys/class/power_supply/$bat/status" 2>/dev/null || echo Unknown)

    charging=0
    [ "$status" = "Charging" ] || [ "$status" = "Full" ] && charging=1

    icon=$(capacity_icon "$pct" "$charging")

    printf '%%{F#45475a}|%%{F-} %s %s%%%%\n' "$icon" "$pct"

    sleep "$INTERVAL"
done
