#!/usr/bin/env bash
# Launch the eww bar on the primary output only.
# Workspaces of other outputs show in the bar as a detached card.
#
# i3 runs this from exec_always, so it fires again on every reload. Two runs
# overlapping used to race each other into two daemons — each opening its own
# bar, stacked. The lock serialises them, and the sweep clears listener scripts
# left orphaned by a daemon that died without reaping its children.

EWW="$HOME/.local/bin/eww"
CFG="$HOME/.i3rc/eww"

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/i3rc-launch-eww.lock"
flock -w 15 9 || exit 0   # another run is already doing this

"$EWW" --config "$CFG" kill 2>/dev/null
pkill -f "$CFG/scripts/" 2>/dev/null
sleep 0.5

"$EWW" --config "$CFG" daemon
sleep 0.5

out=$(xrandr --listactivemonitors | awk 'NR>1 && $2 ~ /\*/ {print $NF; exit}')
[ -z "$out" ] && out=$(xrandr --listactivemonitors | awk 'NR==2 {print $NF}')

"$EWW" --config "$CFG" open bar --screen "$out" --id "bar-$out" \
    --arg out="$out" --arg tray=true
