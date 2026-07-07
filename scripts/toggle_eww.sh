#!/usr/bin/env bash
# Toggle the eww bar on the primary output. Reuses launch_eww's output logic.

EWW="$HOME/.local/bin/eww"
CFG="$HOME/.i3rc/eww"

out=$(xrandr --listactivemonitors | awk 'NR>1 && $2 ~ /\*/ {print $NF; exit}')
[ -z "$out" ] && out=$(xrandr --listactivemonitors | awk 'NR==2 {print $NF}')
id="bar-$out"

if "$EWW" --config "$CFG" active-windows 2>/dev/null | grep -q "^$id:"; then
    "$EWW" --config "$CFG" close "$id"
else
    "$EWW" --config "$CFG" open bar --screen "$out" --id "$id" \
        --arg out="$out" --arg tray=true
fi
