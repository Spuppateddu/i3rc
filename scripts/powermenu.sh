#!/usr/bin/env bash
# Simple rofi-based power menu.

chosen=$(printf " Lock\n Suspend\n Logout\n Reboot\n Shutdown" | \
    rofi -dmenu -i -p "Power" -theme "$HOME/.i3rc/rofi/powermenu.rasi")

case "$chosen" in
    *Lock)      i3lock ;;
    *Suspend)   systemctl suspend ;;
    *Logout)    i3-msg exit ;;
    *Reboot)    systemctl reboot ;;
    *Shutdown)  systemctl poweroff ;;
esac
