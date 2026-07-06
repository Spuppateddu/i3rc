#!/usr/bin/env bash
# Emits network state as JSON for the eww bar (deflisten).

INTERVAL=2

source "$HOME/.i3rc/scripts/net_lib.sh"

prev_rx=0; prev_tx=0; prev_iface=""
while :; do
    read -r iface kind <<<"$(pick_iface)"

    if [ -z "$iface" ]; then
        echo '{"kind":"off","label":"offline","down":"0B","up":"0B"}'
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
    else
        label="$iface"
    fi

    jq -cn --arg k "$kind" --arg l "$label" \
           --arg d "$(fmt_rate "$drx")" --arg u "$(fmt_rate "$dtx")" \
        '{kind:$k, label:$l, down:$d, up:$u}'

    sleep "$INTERVAL"
done
