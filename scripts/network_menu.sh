#!/usr/bin/env bash
# Rofi network menu: wifi radio toggle, scan/connect networks, VPN up/down,
# open nm-connection-editor. Wifi/VPN actions go through nmcli.

# Material Design glyphs kept as ANSI-C escapes so the source stays pure ASCII.
I_WIFI=$'\U000F05A9'
I_WOFF=$'\U000F05AA'
I_CONN=$'\U000F012C'
I_LOCK=$'\U000F033E'
I_OPEN=$'\U000F033F'
I_EDIT=$'\U000F0493'

MAX_WIFI=12

notify() { notify-send -a network "Network" "$1"; }

wifi_on() { [ "$(nmcli radio wifi)" = "enabled" ]; }

if wifi_on; then
    entries="$I_WOFF Turn wifi off"
else
    entries="$I_WIFI Turn wifi on"
fi

# Menu rows are keyed verbatim; maps recover ssid/security/connection name.
declare -A row_ssid row_sec row_vpn active_wifi=""

if wifi_on; then
    # Kick a background rescan so a reopened menu gets fresh results.
    nmcli device wifi rescan >/dev/null 2>&1 &

    declare -A seen
    count=0
    while IFS=: read -r active signal security ssid; do
        ssid=${ssid//\\:/:}
        [ -z "$ssid" ] && continue
        [ -n "${seen[$ssid]}" ] && continue
        seen[$ssid]=1
        [ "$count" -ge "$MAX_WIFI" ] && [ "$active" != "yes" ] && continue
        count=$((count + 1))
        if [ "$active" = "yes" ]; then
            row="$I_CONN $ssid"
            active_wifi=$ssid
        else
            row="$I_WIFI $ssid ($signal%)"
        fi
        row_ssid["$row"]=$ssid
        row_sec["$row"]=$security
        entries+=$'\n'"$row"
    done < <(nmcli -t -f ACTIVE,SIGNAL,SECURITY,SSID device wifi list --rescan no 2>/dev/null \
             | sort -t: -k1,1r -k2,2rn)
fi

while IFS=: read -r ctype cdev cname; do
    case "$ctype" in vpn|wireguard) ;; *) continue ;; esac
    cname=${cname//\\:/:}
    if [ -n "$cdev" ]; then
        row="$I_LOCK $cname (vpn up)"
    else
        row="$I_OPEN $cname (vpn)"
    fi
    row_vpn["$row"]=$cname
    entries+=$'\n'"$row"
done < <(nmcli -t -f TYPE,DEVICE,NAME connection show 2>/dev/null)

entries+=$'\n'"$I_EDIT Editor"

lines=$(printf '%s\n' "$entries" | wc -l)
[ "$lines" -gt 16 ] && lines=16
chosen=$(printf '%s\n' "$entries" | rofi -dmenu -i -no-show-icons -p "Network" \
    -theme "$HOME/.i3rc/rofi/powermenu.rasi" \
    -theme-str "listview {lines: $lines;}")
[ -z "$chosen" ] && exit 0

case "$chosen" in
    "$I_WOFF Turn wifi off") nmcli radio wifi off ; exit 0 ;;
    "$I_WIFI Turn wifi on")  nmcli radio wifi on  ; exit 0 ;;
    "$I_EDIT Editor")        nm-connection-editor >/dev/null 2>&1 & exit 0 ;;
esac

if [ -n "${row_vpn[$chosen]}" ]; then
    name=${row_vpn[$chosen]}
    case "$chosen" in
        "$I_LOCK"*) nmcli connection down "$name" >/dev/null 2>&1 \
                        && notify "VPN $name disconnected" || notify "Failed to stop $name" ;;
        *)          nmcli connection up "$name" >/dev/null 2>&1 \
                        && notify "VPN $name connected" || notify "Failed to start $name" ;;
    esac
    exit 0
fi

ssid=${row_ssid[$chosen]}
[ -z "$ssid" ] && exit 0

# Clicking the active network disconnects it.
if [ "$ssid" = "$active_wifi" ]; then
    while IFS=: read -r ctype cname; do
        [ "$ctype" = "802-11-wireless" ] || continue
        nmcli connection down "${cname//\\:/:}" >/dev/null 2>&1
    done < <(nmcli -t -f TYPE,NAME connection show --active 2>/dev/null)
    exit 0
fi

# Reuse a saved profile whose ssid matches, else connect fresh.
while IFS=: read -r ctype cname; do
    [ "$ctype" = "802-11-wireless" ] || continue
    cname=${cname//\\:/:}
    if [ "$(nmcli -g 802-11-wireless.ssid connection show "$cname" 2>/dev/null)" = "$ssid" ]; then
        nmcli connection up "$cname" >/dev/null 2>&1 \
            && notify "Connected to $ssid" || notify "Failed to connect to $ssid"
        exit 0
    fi
done < <(nmcli -t -f TYPE,NAME connection show 2>/dev/null)

sec=${row_sec[$chosen]}
if [ -n "$sec" ] && [ "$sec" != "--" ]; then
    pass=$(rofi -dmenu -password -p "Password" \
        -theme "$HOME/.i3rc/rofi/powermenu.rasi" -theme-str "listview {lines: 0;}")
    [ -z "$pass" ] && exit 0
    nmcli device wifi connect "$ssid" password "$pass" >/dev/null 2>&1 \
        && notify "Connected to $ssid" || notify "Failed to connect to $ssid"
else
    nmcli device wifi connect "$ssid" >/dev/null 2>&1 \
        && notify "Connected to $ssid" || notify "Failed to connect to $ssid"
fi
