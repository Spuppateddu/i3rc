#!/usr/bin/env bash
# Polybar network widget — auto-detects active wifi/ethernet and shows throughput.
# Outputs an empty line (and hides its leading separator) when no interface is up.

INTERVAL=2

fmt_rate() {
    awk -v b="$1" 'BEGIN {
        if (b >= 1048576)   printf "%.1fM", b/1048576
        else if (b >= 1024) printf "%.0fK", b/1024
        else                printf "%dB",   b
    }'
}

# Prints "<iface> <wifi|eth>" for the best active interface, or nothing.
pick_iface() {
    local wired=""
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

prev_rx=0; prev_tx=0; prev_iface=""
while :; do
    read -r iface kind <<<"$(pick_iface)"

    if [ -z "$iface" ]; then
        # No active interface — show an "offline" icon instead of hiding the module.
        printf '%%{F#f38ba8}%%{T2}󰖪%%{T-} offline%%{F-}\n'
        prev_iface=""; prev_rx=0; prev_tx=0
        sleep "$INTERVAL"
        continue
    fi

    rx=$(cat "/sys/class/net/$iface/statistics/rx_bytes" 2>/dev/null || echo 0)
    tx=$(cat "/sys/class/net/$iface/statistics/tx_bytes" 2>/dev/null || echo 0)

    if [ "$iface" = "$prev_iface" ]; then
        drx=$(( (rx - prev_rx) / INTERVAL ))
        dtx=$(( (tx - prev_tx) / INTERVAL ))
    else
        drx=0; dtx=0
    fi
    prev_rx=$rx; prev_tx=$tx; prev_iface=$iface

    if [ "$kind" = "wifi" ]; then
        label=$(iw dev "$iface" link 2>/dev/null | awk -F': ' '/SSID/ {print $2; exit}')
        [ -z "$label" ] && label="$iface"
        icon=""
    else
        icon="󰈀"
        label="$iface"
    fi

    printf '%%{F#89b4fa}%%{T2}%s%%{T-}%%{F-} %s  %%{F#a6e3a1}↓%%{F-}%s %%{F#fab387}↑%%{F-}%s\n' \
        "$icon" "$label" "$(fmt_rate "$drx")" "$(fmt_rate "$dtx")"

    sleep "$INTERVAL"
done
