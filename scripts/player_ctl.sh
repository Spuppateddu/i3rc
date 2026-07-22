#!/usr/bin/env bash
# Music control helper (used by the eww bar) — local MPD takes priority over other MPRIS players.
#
# Priority when picking the "active" player for title + transport buttons:
#   1. mpd if it is Playing.
#   2. any other player that is Playing.
#   3. mpd if it is Paused.
#   4. any other player that is Paused.
# The play_folder module follows the same idea: while mpd is Playing it
# renders a red stop glyph whose click stops mpd (which hands priority
# back to the browser / other media).

# Material Design glyphs (via CaskaydiaCove Nerd Font). Kept as ANSI-C escapes so the
# source stays pure ASCII — the Write tool strips literal PUA glyphs.
G_PLAY=$'\U000F040A'
G_PAUSE=$'\U000F03E4'
G_STOP=$'\U000F04DB'
G_FOLDER=$'\U000F1359'
G_SHUFFLE=$'\U000F049D'
G_LOOP=$'\U000F0456'

source "$HOME/.i3rc/scripts/player_lib.sh"

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
            printf '%%{F#b8bb26}%%{T2}%s%%{T-}%%{F-}\n' "$G_FOLDER"
            exit 0
        fi
        emit_folder() {
            if [ "$(playerctl -p mpd status 2>/dev/null)" = "Playing" ]; then
                printf '%%{F#fb4934}%%{T2}%s%%{T-}%%{F-}\n' "$G_STOP"
            else
                printf '%%{F#b8bb26}%%{T2}%s%%{T-}%%{F-}\n' "$G_FOLDER"
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
        notify-send -a "player" -r 90910 -t 5000 \
            "${title:-(no title)}" "$body"
        ;;
    shuffle-toggle)
        pctl shuffle Toggle 2>/dev/null
        notify-send -a "player" -r 90911 -t 1500 \
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
        notify-send -a "player" -r 90912 -t 1500 "Repeat: $next"
        ;;
    shuffle-icon)
        case "$(pctl shuffle 2>/dev/null)" in
            On) printf '%%{F#b8bb26}%%{T2}%s%%{T-}%%{F-}\n' "$G_SHUFFLE" ;;
            *)  printf '%%{F#a89984}%%{T2}%s%%{T-}%%{F-}\n' "$G_SHUFFLE" ;;
        esac
        ;;
    loop-icon)
        case "$(pctl loop 2>/dev/null)" in
            Track)    printf '%%{F#fe8019}%%{T2}%s%%{T-}%%{F-}\n' "$G_LOOP" ;;
            Playlist) printf '%%{F#b8bb26}%%{T2}%s%%{T-}%%{F-}\n' "$G_LOOP" ;;
            *)        printf '%%{F#a89984}%%{T2}%s%%{T-}%%{F-}\n' "$G_LOOP" ;;
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
