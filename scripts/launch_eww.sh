#!/usr/bin/env bash
# Launch the eww bar on the primary output only.
# Workspaces of other outputs show in the bar as a detached card.

EWW="$HOME/.local/bin/eww"
CFG="$HOME/.i3rc/eww"


"$EWW" --config "$CFG" kill 2>/dev/null
"$EWW" --config "$CFG" daemon
sleep 0.5

out=$(xrandr --listactivemonitors | awk 'NR>1 && $2 ~ /\*/ {print $NF; exit}')
[ -z "$out" ] && out=$(xrandr --listactivemonitors | awk 'NR==2 {print $NF}')

"$EWW" --config "$CFG" open bar --screen "$out" --id "bar-$out" \
    --arg out="$out" --arg tray=true
