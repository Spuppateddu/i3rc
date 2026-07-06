# .i3rc

My i3 window manager setup: Catppuccin Mocha palette, eww top bar (floating
islands with music + volume controls, per-monitor workspaces, calendar popup,
system tray), rofi launcher, random wallpapers, picom compositing, dunst
notifications, and mpd + ncmpcpp for offline music.

- **Install on a new machine:** run `./setup.sh` (idempotent — also builds eww from source). Full breakdown in [INSTALL.md](./INSTALL.md).
- **Main i3 config:** [config](./config)
- **Top bar:** [eww/](./eww/) — `eww.yuck` (layout/widgets), `eww.scss` (style), `scripts/` (data sources)
- **Launcher themes:** [rofi/](./rofi/)
- **Compositor:** [picom/picom.conf](./picom/picom.conf)
- **Notifications:** [dunst/dunstrc](./dunst/dunstrc)
- **Music daemon:** [mpd/mpd.conf](./mpd/mpd.conf) + [ncmpcpp/config](./ncmpcpp/config)
- **Scripts:** [scripts/](./scripts/) — wallpaper cycle, bar launcher, power/bluetooth menus, music helpers

## Quick layout

```
~/.i3rc/
├── config                     # i3 main config (included from ~/.config/i3/config)
├── INSTALL.md                 # package list + step-by-step setup
├── eww/
│   ├── eww.yuck               # bar layout: workspaces, music, status, calendar
│   ├── eww.scss               # Catppuccin Mocha styling
│   └── scripts/               # JSON emitters (workspaces, player, network, volume)
├── rofi/{config,launcher,powermenu}.rasi
├── picom/picom.conf
├── dunst/dunstrc
├── mpd/mpd.conf
├── ncmpcpp/config
└── scripts/
    ├── launch_eww.sh          # runs the bar on the primary monitor
    ├── wallpaper_cycle.sh     # random wallpaper every 10 min
    ├── powermenu.sh           # rofi lock/suspend/reboot/shutdown
    ├── bluetooth_menu.sh      # rofi adapter toggle + device connect
    ├── player_ctl.sh          # MPRIS music control (mpd priority)
    └── play_folder.sh         # rofi-picked folder → mpd shuffle play
```

See [INSTALL.md](./INSTALL.md) for the full keybinding cheat sheet.
