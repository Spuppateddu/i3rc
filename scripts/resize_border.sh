#!/usr/bin/env bash
# Recolor the focused-window border for i3 resize mode.
#
# i3 has no per-mode client colors and cannot change client.focused at
# runtime, so we swap a small include file and reload the config:
#   on  -> write a red client.focused line that overrides the orange default
#   off -> empty the file, restoring the default from config
#
# Reloading resets i3 to the default mode, so "on" re-enters resize mode
# afterwards; "off" is meant to leave the mode, so it does not.
#
# The main config includes the override file just after its client.focused
# line, and $mod+r execs this script instead of switching mode directly.
set -eu

override="${XDG_CACHE_HOME:-$HOME/.cache}/i3/focus-override.conf"
mkdir -p "$(dirname "$override")"

case "${1:-off}" in
    on)
        printf 'client.focused #fb4934 #fb4934 #282828 #fb4934 #fb4934\n' > "$override"
        i3-msg reload >/dev/null
        i3-msg mode resize >/dev/null
        ;;
    off)
        : > "$override"
        i3-msg reload >/dev/null
        ;;
    *)
        echo "usage: ${0##*/} on|off" >&2
        exit 2
        ;;
esac
