#!/usr/bin/env bash
# Emits active-player state as JSON for the eww bar (deflisten).
# `display` is always exactly TITLE_W chars: short text is centered,
# longer text marquee-scrolls one char per frame.

export LC_ALL=C.UTF-8

source "$HOME/.i3rc/scripts/player_lib.sh"

LAYOUT_STATE="${XDG_RUNTIME_DIR:-/tmp}/i3rc-eww-layout"
TITLE_W=40    # overridden per density tier by layout_w below
SEP="   •   "
FRAMES=6      # scroll frames between metadata refreshes
TICK=0.3

STATUS="none" TITLE="" ARTIST="" SHUFFLE="" LOOP="" MPD=false
SRC="" OFFSET=0 SCROLL=0 TEXT=""

# The marquee is padded to an exact character count, so its width has to
# follow the bar's density tier. screen.sh keeps that number in a state file;
# re-reading it costs nothing and picks up monitor changes without a restart.
layout_w() {
    local LAY_TIER LAY_TITLE
    [ -r "$LAYOUT_STATE" ] || return
    # shellcheck disable=SC1090
    . "$LAYOUT_STATE"
    case "$LAY_TITLE" in
        ''|*[!0-9]*) ;;
        *) [ "$LAY_TITLE" -eq "$TITLE_W" ] || { TITLE_W=$LAY_TITLE; OFFSET=0; } ;;
    esac
}

fetch() {
    local p
    layout_w
    p=$(target_player)
    STATUS=""
    [ -n "$p" ] && STATUS=$(playerctl -p "$p" status 2>/dev/null)
    case "$STATUS" in Playing|Paused) ;; *) STATUS="none" ;; esac

    TITLE=""; ARTIST=""; SHUFFLE=""; LOOP=""
    if [ "$STATUS" != "none" ]; then
        TITLE=$(playerctl -p "$p" metadata title 2>/dev/null)
        ARTIST=$(playerctl -p "$p" metadata artist 2>/dev/null)
        SHUFFLE=$(playerctl -p "$p" shuffle 2>/dev/null)
        LOOP=$(playerctl -p "$p" loop 2>/dev/null)
    fi
    MPD=false
    [ "$(playerctl -p mpd status 2>/dev/null)" = "Playing" ] && MPD=true

    local text="$TITLE"
    [ -n "$ARTIST" ] && text="$TITLE — $ARTIST"
    [ "$text" = "$SRC" ] || { SRC="$text"; OFFSET=0; }
    SCROLL=$(( ${#SRC} > TITLE_W ? 1 : 0 ))
}

# Renders SRC into TEXT, exactly TITLE_W chars wide.
# Spaces become NBSP: Pango drops trailing spaces when measuring,
# which would make the label width jitter while scrolling.
render() {
    local len=${#SRC}
    if [ "$SCROLL" -eq 0 ]; then
        local pad=$((TITLE_W - len)) left=$(( (TITLE_W - len) / 2 ))
        printf -v TEXT '%*s%s%*s' "$left" "" "$SRC" "$((pad - left))" ""
    else
        local loop="${SRC}${SEP}" twice
        twice="$loop$loop"
        TEXT=${twice:OFFSET:TITLE_W}
        OFFSET=$(( (OFFSET + 1) % ${#loop} ))
    fi
    TEXT=${TEXT// /$'\u00a0'}
}

emit() {
    render
    jq -cn --arg s "$STATUS" --arg t "$TITLE" --arg a "$ARTIST" --arg d "$TEXT" \
           --arg sh "$SHUFFLE" --arg l "$LOOP" --argjson m "$MPD" \
        '{status:$s, title:$t, artist:$a, display:$d, shuffle:$sh, loop:$l, mpd_playing:$m}'
}

exec 3< <(playerctl --follow metadata --format '{{status}}' 2>/dev/null)
while :; do
    fetch
    if [ "$SCROLL" -eq 1 ]; then
        # keep scrolling, but refetch early if the player fires an event
        for _ in $(seq "$FRAMES"); do
            emit
            read -t "$TICK" -u 3 -r _ && break
        done
    else
        emit
        read -t 2 -u 3 -r _ || true
    fi
done
