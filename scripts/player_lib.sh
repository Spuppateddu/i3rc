# Shared player-selection logic (sourced by player_ctl.sh and eww/scripts/player.sh).
#
# Priority when picking the "active" player for title + transport buttons:
#   1. mpd if it is Playing.
#   2. any other player that is Playing.
#   3. mpd if it is Paused.
#   4. any other player that is Paused.

target_player() {
    local mpd_s other p s
    mpd_s=$(playerctl -p mpd status 2>/dev/null)
    if [ "$mpd_s" = "Playing" ]; then
        printf 'mpd\n'
        return
    fi
    other=""
    while IFS= read -r p; do
        [ -z "$p" ] && continue
        [ "$p" = "mpd" ] && continue
        s=$(playerctl -p "$p" status 2>/dev/null)
        if [ "$s" = "Playing" ]; then
            printf '%s\n' "$p"
            return
        fi
        [ -z "$other" ] && [ "$s" = "Paused" ] && other="$p"
    done < <(playerctl -l 2>/dev/null)
    if [ "$mpd_s" = "Paused" ]; then
        printf 'mpd\n'
        return
    fi
    [ -n "$other" ] && printf '%s\n' "$other"
}

pctl() {
    local p
    p=$(target_player)
    if [ -n "$p" ]; then
        playerctl -p "$p" "$@"
    else
        playerctl --ignore-player=mpd "$@" 2>/dev/null
    fi
}
