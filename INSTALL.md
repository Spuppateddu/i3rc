# Install guide — i3 rice

Full setup for this i3 configuration on a fresh Ubuntu (tested on 25.10). At
the end you get: i3 with gaps + Catppuccin colors, a polybar top bar, rofi
launcher, random wallpaper cycling, picom compositing, dunst notifications,
and mpd + ncmpcpp for music with controls in the top bar.

## TL;DR — one command

```bash
git clone <this-repo> ~/.i3rc
cd ~/.i3rc
./setup.sh
```

The script is idempotent: it checks what's already installed and only does
the missing work (apt packages, Cascadia Code Nerd Font download, config
symlinks, mpd user services). Re-run it anytime. `./setup.sh --dry-run`
shows what would change without touching anything.

The sections below explain each step manually if you want to do it by hand
or understand what `setup.sh` is doing.

## 1. Clone the repo

```bash
git clone <this-repo> ~/.i3rc
```

Then tell i3 to use it:

```bash
mkdir -p ~/.config/i3
printf 'include "~/.i3rc/config"\n' > ~/.config/i3/config
```

## 2. Install packages

```bash
sudo apt update
sudo apt install -y \
    i3 i3lock \
    polybar rofi \
    picom feh \
    dunst libnotify-bin \
    fonts-font-awesome \
    flameshot \
    alacritty \
    nm-applet network-manager-gnome blueman pasystray \
    pavucontrol brightnessctl playerctl pulseaudio-utils \
    mpd mpc ncmpcpp mpdris2 \
    dex xss-lock \
    papirus-icon-theme
```

> Everything is in the default Ubuntu repos on 25.10. If `polybar` isn't
> available on older Ubuntu releases, build from source (see
> <https://github.com/polybar/polybar>).

## 3. Fonts — Cascadia Code Nerd Font

Polybar/rofi/dunst expect `Cascadia Code NF` (the Nerd Font variant shipping
icon glyphs). Install into your user fonts directory:

```bash
mkdir -p ~/.local/share/fonts
curl -L -o /tmp/CascadiaCode.zip \
  https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaCode.zip
unzip -o /tmp/CascadiaCode.zip -d ~/.local/share/fonts/
fc-cache -fv
```

Verify:

```bash
fc-list | grep -i "Cascadia Code NF"
```

## 4. Link the per-tool configs into `~/.config`

This keeps all files tracked in `~/.i3rc` and each tool finds them in its
default location:

```bash
mkdir -p ~/.config/{polybar,rofi,picom,dunst,mpd,ncmpcpp}
ln -sf ~/.i3rc/polybar/config.ini   ~/.config/polybar/config.ini
ln -sf ~/.i3rc/rofi/config.rasi     ~/.config/rofi/config.rasi
ln -sf ~/.i3rc/picom/picom.conf     ~/.config/picom/picom.conf
ln -sf ~/.i3rc/dunst/dunstrc        ~/.config/dunst/dunstrc
ln -sf ~/.i3rc/mpd/mpd.conf         ~/.config/mpd/mpd.conf
ln -sf ~/.i3rc/ncmpcpp/config       ~/.config/ncmpcpp/config
```

The i3 config already references the in-repo paths directly for polybar,
rofi, picom, and dunst, so the symlinks above are optional for those — they
only help if you later run the tools standalone (e.g. `rofi -show drun`
without passing `-config`). For mpd + ncmpcpp the symlinks **are** required,
since those daemons auto-load from `~/.config`.

## 5. Wallpapers

The cycle script reads from `~/Pictures/Wallpapers` by default and picks a
new random image every 10 minutes. Override with env vars if needed:

```bash
WALLPAPER_DIR=~/Pictures/wallpapers INTERVAL=300 ~/.i3rc/scripts/wallpaper_cycle.sh
```

Accepted formats: jpg, jpeg, png, webp, bmp. Recursive — subfolders are fine.

## 6. Music (mpd + ncmpcpp)

Edit `~/.i3rc/mpd/mpd.conf` if your music folder is not `~/Music`,
then enable and start the **user** mpd service + MPRIS bridge:

```bash
mkdir -p ~/.local/share/mpd/playlists
systemctl --user enable --now mpd.service
systemctl --user enable --now mpDris2.service   # case varies; try both:
systemctl --user enable --now mpdris2.service || true
```

First library scan:

```bash
mpc update --wait
```

Controls:

| Action | Binding / Place |
|---|---|
| Open full TUI (random/queue/volume/etc.) | `$mod+m` (or right-click music widget) |
| Rofi folder picker → queue + shuffle + play | `$mod+Shift+m` |
| Play / pause | Click the ▶ icon in the top bar |
| Prev / next | Click ⏮ / ⏭ in top bar, or scroll on track name |
| Media keys | XF86AudioPlay / Next / Prev (if your keyboard has them) |

Inside ncmpcpp the useful keys are: `z` = random, `r` = repeat, `c` = clear
queue, `+/-` = volume, `space` = enqueue, `p` = pause, `>/<` = next/prev,
`/` = search, `1/2/3/4` = switch panes.

## 7. First launch

Log out, pick **i3** at the login screen, log back in. Or if you're already
in i3: `$mod+Shift+r` to restart.

If the top bar doesn't appear:

```bash
~/.i3rc/scripts/launch_polybar.sh
tail -f /tmp/polybar_main.log   # only if the script was modified to log
polybar --list-monitors
```

## 8. Keybindings cheat sheet

| Keys | Action |
|---|---|
| `$mod+Return` | Terminal (alacritty) |
| `$mod+d` | App launcher (rofi) |
| `$mod+Tab` | Window switcher (rofi) |
| `$mod+q` | Kill focused window |
| `$mod+Shift+s` | Screenshot (flameshot) |
| `$mod+Shift+x` | Lock screen |
| `$mod+Shift+p` | Power menu |
| `$mod+m` | Music TUI (ncmpcpp) |
| `$mod+Shift+m` | Pick a folder → shuffle play |
| `$mod+f` | Fullscreen |
| `$mod+h/j/k/l` | Focus left/down/up/right |
| `$mod+Shift+h/j/k/l` | Move window |
| `$mod+1..0` | Workspace 1..10 |
| `$mod+Shift+1..0` | Move window to workspace |
| `$mod+r` | Resize mode |
| `$mod+Shift+c` | Reload i3 |
| `$mod+Shift+r` | Restart i3 |
| `$mod+Shift+e` | Exit i3 |

`$mod` is the Super (Windows) key.

## 9. Customizing

- **Colors** — search `#1e1e2e` / `#b4befe` etc. The palette is Catppuccin
  Mocha; swap values consistently across `polybar/config.ini`,
  `rofi/launcher.rasi`, `dunst/dunstrc`, and the `client.*` lines in
  `config`.
- **Bar modules** — edit `modules-left/center/right` in
  `polybar/config.ini`.
- **Gaps** — `gaps inner`/`gaps outer` in `config`.
- **Wallpaper interval** — `INTERVAL` env var or edit the default in
  `scripts/wallpaper_cycle.sh`.

## 10. Uninstall / revert

```bash
rm ~/.config/i3/config
# and/or re-point it to a default i3 config
```

Everything else is self-contained in `~/.i3rc` + the symlinks in
`~/.config/{polybar,rofi,picom,dunst,mpd,ncmpcpp}`.
