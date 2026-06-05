#!/usr/bin/env bash
# Queue all tracks from a folder under MPD's music_directory and play (shuffled).
#
# Usage:
#   play_folder.sh                       # interactive rofi picker
#   play_folder.sh "Music-playlist"      # play a named subfolder
#   play_folder.sh ""                    # play the entire library
#
# Assumes mpd's music_directory is ~/Music (see INSTALL.md).

set -e

MUSIC_ROOT="${MUSIC_ROOT:-$HOME/Music}"

if ! command -v mpc >/dev/null 2>&1; then
    notify-send "Music" "mpc not installed — see INSTALL.md"
    exit 1
fi

folder="$1"

if [ -z "${folder+x}" ]; then
    # No argument at all: show rofi picker of top-level folders.
    folder=$(find "$MUSIC_ROOT" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' 2>/dev/null | sort |
        rofi -dmenu -i -p "Play" -config ~/.i3rc/rofi/config.rasi)
    [ -z "$folder" ] && exit 0
fi

mpc -q update --wait >/dev/null 2>&1 || true
mpc -q clear
if [ -z "$folder" ]; then
    mpc -q add /
else
    mpc -q add "$folder"
fi
mpc -q random on
mpc -q consume off
mpc -q repeat on
mpc -q play

notify-send -i media-playback-start "Music" "Playing: ${folder:-entire library} (shuffled)"
