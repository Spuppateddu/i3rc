# .i3rc

My i3 window manager setup: Gruvbox Dark palette, eww top bar (floating
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

## Machine-specific settings

Anything that should apply to **only one computer** (and never be committed or
shared with people who clone this repo) goes in:

```
~/.i3rc/config.local
```

The main [config](./config) ends with `include ~/.i3rc/*.local`, so this file is
loaded **last** — meaning it can override anything in the shared config. Any
`*.local` file is git-ignored, and the wildcard is a harmless no-op on machines
that don't have one, so the repo stays clean and portable.

Use plain i3 config syntax. Typical uses: per-monitor layout, extra keybinds, or
display scaling. For example, to make everything on a low-res laptop panel
smaller:

```
# ~/.i3rc/config.local
exec_always --no-startup-id xrandr --output eDP-1 --scale 1.25x1.25
```

`xrandr --scale` renders the desktop at a larger virtual size and shrinks it onto
the panel — higher number = smaller UI. Reset with `--scale 1x1`. Reload i3 after
editing with `$mod+Shift+c`.

## Quick layout

```
~/.i3rc/
├── config                     # i3 main config (included from ~/.config/i3/config)
├── config.local              # per-machine overrides (git-ignored, optional)
├── INSTALL.md                 # package list + step-by-step setup
├── eww/
│   ├── eww.yuck               # bar layout: workspaces, music, status, calendar
│   ├── eww.scss               # Gruvbox Dark styling
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
    ├── network_menu.sh        # rofi wifi scan/connect + VPN up/down
    ├── player_ctl.sh          # MPRIS music control (mpd priority)
    ├── play_folder.sh         # rofi-picked folder → mpd shuffle play
    └── restart_xbanish.sh     # hide pointer while typing, show on mouse move
```

See [INSTALL.md](./INSTALL.md) for the full keybinding cheat sheet.
