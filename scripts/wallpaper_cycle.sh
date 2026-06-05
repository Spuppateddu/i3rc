#!/usr/bin/env bash
# Cycle a random wallpaper from WALLPAPER_DIR every INTERVAL seconds.
# Safe to run under `exec_always`: kills any previous instance.

WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
INTERVAL="${INTERVAL:-600}"

pkill -f "wallpaper_cycle\.sh" -P 1 2>/dev/null
for pid in $(pgrep -f "wallpaper_cycle\.sh"); do
    [ "$pid" != "$$" ] && kill "$pid" 2>/dev/null
done

while true; do
    if [ -d "$WALLPAPER_DIR" ]; then
        wallpaper=$(find "$WALLPAPER_DIR" -type f \
            \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.bmp' \) \
            2>/dev/null | shuf -n 1)
        if [ -n "$wallpaper" ]; then
            feh --no-fehbg --bg-fill "$wallpaper"
        fi
    fi
    sleep "$INTERVAL"
done
