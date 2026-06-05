#!/usr/bin/env bash
# Polybar music widget — local MPD takes priority over other MPRIS players.
#
# Priority when picking the "active" player for title + transport buttons:
#   1. mpd if it is Playing.
#   2. any other player that is Playing.
#   3. mpd if it is Paused.
#   4. any other player that is Paused.
# The play_folder module follows the same idea: while mpd is Playing it
# renders a red stop glyph whose click stops mpd (which hands priority
# back to the browser / other media).

# FontAwesome glyphs (via Cascadia Code NF). Kept as ANSI-C escapes so the
# source stays pure ASCII — the Write tool strips literal PUA glyphs.
G_PLAY=$''
G_PAUSE=$''
G_STOP=$''
G_FOLDER=$''
G_SHUFFLE=$''
G_LOOP=$''

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

case "$1" in
    toggle) pctl play-pause ;;
    next)   pctl next       ;;
    prev)   pctl previous   ;;
    stop)   pctl stop       ;;

    folder-click)
        if [ "$(playerctl -p mpd status 2>/dev/null)" = "Playing" ]; then
            mpc -q stop 2>/dev/null || playerctl -p mpd stop 2>/dev/null
        else
            exec ~/.i3rc/scripts/play_folder.sh
        fi
        ;;
    folder-icon)
        if ! command -v playerctl >/dev/null 2>&1; then
            printf '%%{F#a6e3a1}%%{T2}%s%%{T-}%%{F-}\n' "$G_FOLDER"
            exit 0
        fi
        emit_folder() {
            if [ "$(playerctl -p mpd status 2>/dev/null)" = "Playing" ]; then
                printf '%%{F#f38ba8}%%{T2}%s%%{T-}%%{F-}\n' "$G_STOP"
            else
                printf '%%{F#a6e3a1}%%{T2}%s%%{T-}%%{F-}\n' "$G_FOLDER"
            fi
        }
        exec 3< <(playerctl --follow -p mpd status 2>/dev/null)
        while :; do
            emit_folder
            read -t 2 -u 3 -r _ || true
        done
        ;;

    show-title)
        command -v playerctl >/dev/null 2>&1 || exit 0
        p=$(target_player)
        [ -z "$p" ] && exit 0
        title=$(playerctl -p "$p" metadata title 2>/dev/null)
        artist=$(playerctl -p "$p" metadata artist 2>/dev/null)
        album=$(playerctl -p "$p" metadata album 2>/dev/null)
        [ -z "$title$artist$album" ] && exit 0
        body=""
        [ -n "$artist" ] && body="$artist"
        [ -n "$album" ] && body="${body:+$body — }$album"
        notify-send -a "polybar-player" -r 90910 -t 5000 \
            "${title:-(no title)}" "$body"
        ;;
    shuffle-toggle)
        pctl shuffle Toggle 2>/dev/null
        notify-send -a "polybar-player" -r 90911 -t 1500 \
            "Shuffle: $(pctl shuffle 2>/dev/null)"
        ;;
    loop-cycle)
        case "$(pctl loop 2>/dev/null)" in
            None)     next=Track ;;
            Track)    next=Playlist ;;
            Playlist) next=None ;;
            *)        next=None ;;
        esac
        pctl loop "$next" 2>/dev/null
        notify-send -a "polybar-player" -r 90912 -t 1500 "Repeat: $next"
        ;;
    shuffle-icon)
        case "$(pctl shuffle 2>/dev/null)" in
            On) printf '%%{F#a6e3a1}%%{T2}%s%%{T-}%%{F-}\n' "$G_SHUFFLE" ;;
            *)  printf '%%{F#a6adc8}%%{T2}%s%%{T-}%%{F-}\n' "$G_SHUFFLE" ;;
        esac
        ;;
    loop-icon)
        case "$(pctl loop 2>/dev/null)" in
            Track)    printf '%%{F#fab387}%%{T2}%s%%{T-}%%{F-}\n' "$G_LOOP" ;;
            Playlist) printf '%%{F#a6e3a1}%%{T2}%s%%{T-}%%{F-}\n' "$G_LOOP" ;;
            *)        printf '%%{F#a6adc8}%%{T2}%s%%{T-}%%{F-}\n' "$G_LOOP" ;;
        esac
        ;;
    toggle-icon)
        if ! command -v playerctl >/dev/null 2>&1; then
            printf '%%{T2}%s%%{T-}\n' "$G_PLAY"
            exit 0
        fi
        emit_toggle() {
            local p s=""
            p=$(target_player)
            [ -n "$p" ] && s=$(playerctl -p "$p" status 2>/dev/null)
            case "$s" in
                Playing) printf '%%{T2}%s%%{T-}\n' "$G_PAUSE" ;;
                *)       printf '%%{T2}%s%%{T-}\n' "$G_PLAY"  ;;
            esac
        }
        exec 3< <(playerctl --follow status 2>/dev/null)
        while :; do
            emit_toggle
            read -t 2 -u 3 -r _ || true
        done
        ;;
    "" )
        if ! command -v playerctl >/dev/null 2>&1; then
            echo ""
            exit 0
        fi
        emit_title() {
            local p status title artist line
            p=$(target_player)
            if [ -z "$p" ]; then
                echo ""
                return
            fi
            status=$(playerctl -p "$p" status 2>/dev/null)
            case "$status" in
                Playing|Paused) ;;
                *) echo ""; return ;;
            esac
            title=$(playerctl -p "$p" metadata title 2>/dev/null)
            artist=$(playerctl -p "$p" metadata artist 2>/dev/null)
            line="$title"
            [ -n "$artist" ] && line="$line — $artist"
            if [ "${#line}" -gt 45 ]; then
                line="${line:0:42}…"
            fi
            printf '%s\n' "$line"
        }
        exec 3< <(playerctl --follow metadata --format '{{status}}' 2>/dev/null)
        while :; do
            emit_title
            read -t 2 -u 3 -r _ || true
        done
        ;;
esac
