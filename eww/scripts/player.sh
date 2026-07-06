#!/usr/bin/env bash
# Emits active-player state as JSON for the eww bar (deflisten).

source "$HOME/.i3rc/scripts/player_lib.sh"

emit() {
    local p status title artist shuffle loop mpd
    p=$(target_player)
    status=""
    [ -n "$p" ] && status=$(playerctl -p "$p" status 2>/dev/null)
    case "$status" in Playing|Paused) ;; *) status="none" ;; esac

    title=""; artist=""; shuffle=""; loop=""
    if [ "$status" != "none" ]; then
        title=$(playerctl -p "$p" metadata title 2>/dev/null)
        artist=$(playerctl -p "$p" metadata artist 2>/dev/null)
        shuffle=$(playerctl -p "$p" shuffle 2>/dev/null)
        loop=$(playerctl -p "$p" loop 2>/dev/null)
    fi
    mpd=false
    [ "$(playerctl -p mpd status 2>/dev/null)" = "Playing" ] && mpd=true

    jq -cn --arg s "$status" --arg t "$title" --arg a "$artist" \
           --arg sh "$shuffle" --arg l "$loop" --argjson m "$mpd" \
        '{status:$s, title:$t, artist:$a, shuffle:$sh, loop:$l, mpd_playing:$m}'
}

exec 3< <(playerctl --follow metadata --format '{{status}}' 2>/dev/null)
while :; do
    emit
    read -t 2 -u 3 -r _ || true
done
