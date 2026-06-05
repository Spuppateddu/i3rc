# .i3rc

My i3 window manager setup: Catppuccin Mocha palette, polybar top bar with
music + volume controls, rofi launcher, random wallpapers, picom compositing,
dunst notifications, and mpd + ncmpcpp for offline music.

- **Install on a new machine:** run `./setup.sh` (idempotent). Full breakdown in [INSTALL.md](./INSTALL.md).
- **Main i3 config:** [config](./config)
- **Top bar:** [polybar/config.ini](./polybar/config.ini)
- **Launcher themes:** [rofi/](./rofi/)
- **Compositor:** [picom/picom.conf](./picom/picom.conf)
- **Notifications:** [dunst/dunstrc](./dunst/dunstrc)
- **Music daemon:** [mpd/mpd.conf](./mpd/mpd.conf) + [ncmpcpp/config](./ncmpcpp/config)
- **Scripts:** [scripts/](./scripts/) — wallpaper cycle, polybar launcher, power menu, music helpers

## Quick layout

```
~/.i3rc/
├── config                     # i3 main config (included from ~/.config/i3/config)
├── INSTALL.md                 # package list + step-by-step setup
├── polybar/config.ini
├── rofi/{config,launcher,powermenu}.rasi
├── picom/picom.conf
├── dunst/dunstrc
├── mpd/mpd.conf
├── ncmpcpp/config
└── scripts/
    ├── launch_polybar.sh      # runs polybar on every connected monitor
    ├── wallpaper_cycle.sh     # random wallpaper every 10 min
    ├── powermenu.sh           # rofi lock/suspend/reboot/shutdown
    ├── polybar_player.sh      # MPRIS-based music widget
    └── play_folder.sh         # rofi-picked folder → mpd shuffle play
```

See [INSTALL.md](./INSTALL.md) for the full keybinding cheat sheet.
