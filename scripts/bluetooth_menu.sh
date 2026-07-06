#!/usr/bin/env bash
# Rofi bluetooth menu: adapter toggle, connect/disconnect paired devices,
# open blueman-manager. "toggle" argument flips adapter power directly.

# Material Design glyphs kept as ANSI-C escapes so the source stays pure ASCII.
I_ON=$'\U000F00AF'
I_CONN=$'\U000F00B1'
I_OFF=$'\U000F00B2'
I_MGR=$'\U000F0493'

powered() {
    [ "$(bluetoothctl show 2>/dev/null | awk '/Powered:/{print $2; exit}')" = "yes" ]
}

if [ "$1" = "toggle" ]; then
    if powered; then
        bluetoothctl power off >/dev/null
    else
        bluetoothctl power on >/dev/null
    fi
    exit 0
fi

if powered; then
    entries="$I_OFF Turn off"
else
    entries="$I_ON Turn on"
fi

declare -A macs
while read -r _ mac name; do
    [ -z "$mac" ] && continue
    macs["$name"]=$mac
    if bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
        entries+=$'\n'"$I_CONN $name"
    else
        entries+=$'\n'"$I_ON $name"
    fi
done < <(bluetoothctl devices Paired 2>/dev/null || bluetoothctl paired-devices 2>/dev/null)
entries+=$'\n'"$I_MGR Manager"

lines=$(printf '%s\n' "$entries" | wc -l)
chosen=$(printf '%s\n' "$entries" | rofi -dmenu -i -no-show-icons -p "Bluetooth" \
    -theme "$HOME/.i3rc/rofi/powermenu.rasi" \
    -theme-str "listview {lines: $lines;}")
[ -z "$chosen" ] && exit 0

name=${chosen#* }
case "$chosen" in
    *"Turn off") bluetoothctl power off >/dev/null ;;
    *"Turn on")  bluetoothctl power on >/dev/null ;;
    *"Manager")  blueman-manager >/dev/null 2>&1 & ;;
    *)
        mac=${macs["$name"]}
        [ -z "$mac" ] && exit 0
        if bluetoothctl info "$mac" | grep -q "Connected: yes"; then
            bluetoothctl disconnect "$mac" >/dev/null
        else
            bluetoothctl connect "$mac" >/dev/null
        fi
        ;;
esac
