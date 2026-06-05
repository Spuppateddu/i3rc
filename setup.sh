#!/usr/bin/env bash
# One-shot setup for the i3 rice. Idempotent — safe to re-run.
# Installs only what's missing, links configs, enables mpd services.
#
# Usage:   ./setup.sh
#          ./setup.sh --dry-run       # only report what would be done

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

# ── Colors ────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
    C_BLUE=$'\033[1;34m'; C_GREEN=$'\033[1;32m'; C_YELLOW=$'\033[1;33m'
    C_RED=$'\033[1;31m';  C_DIM=$'\033[2m';       C_OFF=$'\033[0m'
else
    C_BLUE=''; C_GREEN=''; C_YELLOW=''; C_RED=''; C_DIM=''; C_OFF=''
fi

step()  { printf '%s▸%s %s\n' "$C_BLUE"  "$C_OFF" "$*"; }
ok()    { printf '%s✓%s %s\n' "$C_GREEN" "$C_OFF" "$*"; }
skip()  { printf '%s·%s %s%s%s\n' "$C_DIM" "$C_OFF" "$C_DIM" "$*" "$C_OFF"; }
warn()  { printf '%s!%s %s\n' "$C_YELLOW" "$C_OFF" "$*"; }
fail()  { printf '%s✗%s %s\n' "$C_RED"   "$C_OFF" "$*" >&2; }

run() {
    if $DRY_RUN; then
        printf '%s  would run:%s %s\n' "$C_DIM" "$C_OFF" "$*"
    else
        "$@"
    fi
}

# ── 0. Sanity ─────────────────────────────────────────────────────────────
if [[ ! -f "$REPO/config" ]]; then
    fail "Can't find i3 config at $REPO/config — are you running from the repo root?"
    exit 1
fi

if ! command -v apt >/dev/null 2>&1; then
    fail "This script targets Debian/Ubuntu (apt). Adapt for your distro."
    exit 1
fi

# ── 1. apt packages ───────────────────────────────────────────────────────
step "Checking apt packages"

PACKAGES=(
    i3 i3lock
    polybar rofi
    qalc
    git build-essential
    picom feh
    dunst libnotify-bin
    fonts-font-awesome
    network-manager-gnome blueman pasystray
    pavucontrol brightnessctl playerctl pulseaudio-utils
    wireplumber
    mpd mpc ncmpcpp mpdris2
    dex xss-lock
    papirus-icon-theme
    curl unzip
    gsimplecal
    iw
    x11-xserver-utils x11-xkb-utils
)

missing=()
for pkg in "${PACKAGES[@]}"; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
        continue
    fi
    # Check that the package has a real installation candidate.
    # `apt-cache show` can succeed for packages that only exist as
    # references in other packages' dependencies (no candidate).
    candidate=$(apt-cache policy "$pkg" 2>/dev/null | awk '/Candidate:/ {print $2}')
    if [[ -n "$candidate" && "$candidate" != "(none)" ]]; then
        missing+=("$pkg")
    else
        warn "Package '$pkg' not available on this system — skipping."
    fi
done

if [[ ${#missing[@]} -eq 0 ]]; then
    skip "All apt packages already installed."
else
    step "Installing ${#missing[@]} missing package(s): ${missing[*]}"
    if ! $DRY_RUN; then
        # apt update can exit non-zero when a third-party PPA is broken
        # (e.g. has no Release file for this distro). That shouldn't abort
        # setup — the install still works against the cached indexes.
        sudo apt update || warn "apt update reported errors (likely a stale PPA) — continuing."
        sudo apt install -y "${missing[@]}"
    fi
    ok "apt packages installed."
fi

# ── 2. Cascadia Code Nerd Font ────────────────────────────────────────────
step "Checking Cascadia Code Nerd Font"

if fc-list 2>/dev/null | grep -iE "cascadia code nf|caskaydia.*nerd" >/dev/null; then
    skip "Cascadia Code Nerd Font already installed."
else
    url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaCode.zip"
    tmp="/tmp/CascadiaCode.$$.zip"
    dest="$HOME/.local/share/fonts"
    step "Downloading Cascadia Code Nerd Font"
    run mkdir -p "$dest"
    run curl -fL --progress-bar -o "$tmp" "$url"
    run unzip -oq "$tmp" -d "$dest"
    run rm -f "$tmp"
    run fc-cache -f
    ok "Cascadia Code NF installed."
fi

# ── 3. i3 include ─────────────────────────────────────────────────────────
step "Wiring ~/.config/i3/config → $REPO/config"

I3_CONFIG_DIR="$HOME/.config/i3"
I3_CONFIG_FILE="$I3_CONFIG_DIR/config"
INCLUDE_LINE="include \"$REPO/config\""

run mkdir -p "$I3_CONFIG_DIR"

# Detect an existing include that points at this repo, whether written with
# an absolute path, ~, or $HOME.
already_wired=false
if [[ -f "$I3_CONFIG_FILE" ]]; then
    if grep -Eq "^[[:space:]]*include[[:space:]]+\"(($HOME|~|\\\$HOME)/\\.i3rc/config|$REPO/config)\"" "$I3_CONFIG_FILE"; then
        already_wired=true
    fi
fi

if $already_wired; then
    skip "i3 config already includes repo."
elif [[ -s "$I3_CONFIG_FILE" ]]; then
    backup="$I3_CONFIG_FILE.backup.$(date +%s)"
    warn "Existing i3 config found — backing up to $backup"
    run cp "$I3_CONFIG_FILE" "$backup"
    if $DRY_RUN; then
        printf '%s  would write:%s %s → %s\n' "$C_DIM" "$C_OFF" "$INCLUDE_LINE" "$I3_CONFIG_FILE"
    else
        printf '%s\n' "$INCLUDE_LINE" > "$I3_CONFIG_FILE"
    fi
    ok "i3 config replaced with include."
else
    if $DRY_RUN; then
        printf '%s  would write:%s %s → %s\n' "$C_DIM" "$C_OFF" "$INCLUDE_LINE" "$I3_CONFIG_FILE"
    else
        printf '%s\n' "$INCLUDE_LINE" > "$I3_CONFIG_FILE"
    fi
    ok "i3 config wired."
fi

# ── 4. Symlinks into ~/.config ────────────────────────────────────────────
step "Linking per-tool configs"

link() {
    local src="$1" dst="$2"
    run mkdir -p "$(dirname "$dst")"
    if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
        skip "$dst already linked."
        return
    fi
    if [[ -e "$dst" && ! -L "$dst" ]]; then
        local backup="$dst.backup.$(date +%s)"
        warn "$dst exists — backing up to $backup"
        run mv "$dst" "$backup"
    fi
    run ln -sfn "$src" "$dst"
    ok "linked $dst"
}

link "$REPO/polybar/config.ini"   "$HOME/.config/polybar/config.ini"
link "$REPO/rofi/config.rasi"     "$HOME/.config/rofi/config.rasi"
link "$REPO/rofi/launcher.rasi"   "$HOME/.config/rofi/launcher.rasi"
link "$REPO/rofi/powermenu.rasi"  "$HOME/.config/rofi/powermenu.rasi"
link "$REPO/picom/picom.conf"     "$HOME/.config/picom/picom.conf"
link "$REPO/dunst/dunstrc"        "$HOME/.config/dunst/dunstrc"
link "$REPO/mpd/mpd.conf"         "$HOME/.config/mpd/mpd.conf"
link "$REPO/ncmpcpp/config"       "$HOME/.config/ncmpcpp/config"

# ── 5. Make scripts executable ────────────────────────────────────────────
step "Ensuring scripts are executable"
run chmod +x "$REPO"/scripts/*.sh
ok "scripts ready."

# ── 6. mpd directories + services ─────────────────────────────────────────
step "Setting up mpd"

run mkdir -p "$HOME/.local/share/mpd/playlists"

if command -v systemctl >/dev/null 2>&1; then
    # mpd user service
    if systemctl --user is-enabled mpd.service >/dev/null 2>&1 &&
       systemctl --user is-active  mpd.service >/dev/null 2>&1; then
        skip "mpd.service already enabled + running."
    else
        run systemctl --user enable --now mpd.service || warn "Could not enable mpd.service"
    fi

    # mpdris2 bridge (case varies between packagings)
    enabled_any=false
    for svc in mpdris2.service mpDris2.service; do
        if systemctl --user list-unit-files "$svc" >/dev/null 2>&1 &&
           systemctl --user list-unit-files "$svc" 2>/dev/null | grep "$svc" >/dev/null; then
            if systemctl --user is-enabled "$svc" >/dev/null 2>&1; then
                skip "$svc already enabled."
            else
                run systemctl --user enable --now "$svc" || true
            fi
            enabled_any=true
            break
        fi
    done
    $enabled_any || warn "mpdris2 service unit not found — polybar music titles may not appear."
else
    warn "systemctl not available — start mpd and mpdris2 manually."
fi

# First library scan (non-fatal).
if command -v mpc >/dev/null 2>&1; then
    step "Kicking off mpd library scan"
    run mpc update >/dev/null 2>&1 || warn "mpc update failed — music folder may be empty or mpd not running yet."
fi

# ── 7. Done ───────────────────────────────────────────────────────────────
echo
ok "Setup complete."
echo
echo "Next: log into i3, then press  ${C_BLUE}\$mod+Shift+r${C_OFF}  to restart."
echo "If you're on another WM right now, log out and pick 'i3' at the login screen."
