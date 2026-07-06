# Shared network helpers (sourced by eww/scripts/network.sh).

fmt_rate() {
    awk -v b="$1" 'BEGIN {
        if (b >= 1048576)   printf "%.1fM", b/1048576
        else if (b >= 1024) printf "%.0fK", b/1024
        else                printf "%dB",   b
    }'
}

# Prints "<iface> <wifi|eth>" for the best active interface, or nothing.
pick_iface() {
    local wired="" name path
    for path in /sys/class/net/*; do
        name=${path##*/}
        [ "$name" = "lo" ] && continue
        [ -r "$path/operstate" ] || continue
        [ "$(cat "$path/operstate")" = "up" ] || continue
        if [ -d "$path/wireless" ]; then
            echo "$name wifi"
            return
        fi
        [ -z "$wired" ] && wired="$name"
    done
    [ -n "$wired" ] && echo "$wired eth"
}
