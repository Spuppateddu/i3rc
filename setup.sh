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
    rofi
    qalc
    git build-essential pkg-config
    libgtk-3-dev libdbusmenu-gtk3-dev
    jq
    picom feh
    dunst libnotify-bin
    network-manager-gnome blueman
    pavucontrol brightnessctl playerctl pulseaudio-utils
    wireplumber
    mpd mpc ncmpcpp mpdris2
    dex xss-lock
    papirus-icon-theme
    curl unzip xz-utils
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

if fc-list 2>/dev/null | grep -iE "caskaydiacove.*nerd" >/dev/null; then
    skip "CaskaydiaCove Nerd Font already installed."
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
    ok "CaskaydiaCove Nerd Font installed."
fi

# ── 2.2. eww bar (built from source — not packaged for Ubuntu) ────────────
step "Checking eww"

EWW_BIN="$HOME/.local/bin/eww"
if [[ -x "$EWW_BIN" ]]; then
    skip "eww already installed."
else
    if ! command -v cargo >/dev/null 2>&1 && [[ ! -x "$HOME/.cargo/bin/cargo" ]]; then
        step "Installing Rust toolchain (rustup, user-local)"
        run bash -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable'
    fi
    # shellcheck disable=SC1091
    source "$HOME/.cargo/env" 2>/dev/null || true
    EWW_SRC="$HOME/.local/src/eww"
    if [[ ! -d "$EWW_SRC" ]]; then
        step "Cloning eww"
        run git clone --depth 1 https://github.com/elkowar/eww.git "$EWW_SRC"
    fi
    step "Building eww (release, X11 only) — takes a few minutes"
    run bash -c "cd '$EWW_SRC' && cargo build --release --no-default-features --features x11"
    run mkdir -p "$HOME/.local/bin"
    run cp "$EWW_SRC/target/release/eww" "$EWW_BIN"
    ok "eww installed to $EWW_BIN."
fi

# Bluetooth lives in the bar (rofi menu) — keep blueman from adding a tray icon.
if command -v gsettings >/dev/null 2>&1; then
    run gsettings set org.blueman.general plugin-list "['!StatusIcon']" || \
        warn "Could not disable blueman tray icon."
fi

# ── 2.5. BreezeX-Dark cursor theme ────────────────────────────────────────
step "Checking BreezeX-Dark cursor theme"

CURSOR_THEME="BreezeX-Dark"
CURSOR_VERSION="v2.0.1"
# Must live under ~/.icons (or /usr/share/icons): libXcursor's default search
# path does NOT include ~/.local/share/icons, so xsetroot can't find it there.
CURSOR_DIR="$HOME/.icons/$CURSOR_THEME"

if [[ -d "$CURSOR_DIR" ]]; then
    skip "$CURSOR_THEME cursor already installed."
else
    url="https://github.com/ful1e5/BreezeX_Cursor/releases/download/$CURSOR_VERSION/BreezeX-Dark.tar.xz"
    tmp="/tmp/BreezeX-Dark.$$.tar.xz"
    dest="$HOME/.icons"
    step "Downloading $CURSOR_THEME cursor ($CURSOR_VERSION)"
    run mkdir -p "$dest"
    run curl -fL --progress-bar -o "$tmp" "$url"
    run tar -xf "$tmp" -C "$dest"
    run rm -f "$tmp"
    ok "$CURSOR_THEME cursor installed."
fi

# Make it the X11 default — no DE settings GUI under i3, so apps resolve the
# "default" theme to BreezeX-Dark via this index.theme.
DEFAULT_INDEX="$HOME/.icons/default/index.theme"
if [[ -f "$DEFAULT_INDEX" ]] && grep -q "Inherits=$CURSOR_THEME" "$DEFAULT_INDEX"; then
    skip "Default cursor already set to $CURSOR_THEME."
else
    run mkdir -p "$HOME/.icons/default"
    if $DRY_RUN; then
        printf '%s  would write:%s Inherits=%s → %s\n' "$C_DIM" "$C_OFF" "$CURSOR_THEME" "$DEFAULT_INDEX"
    else
        printf '[Icon Theme]\nInherits=%s\n' "$CURSOR_THEME" > "$DEFAULT_INDEX"
    fi
    ok "Default cursor set to $CURSOR_THEME."
fi

# Export XCURSOR_* in ~/.xsessionrc — GDM/Xsession source this BEFORE i3
# starts, so i3 sets the root cursor to BreezeX-Dark itself (no flash/reset on
# restart). Requires one full logout/login to take effect.
XSR="$HOME/.xsessionrc"
if [[ -f "$XSR" ]] && grep -q "^export XCURSOR_THEME=$CURSOR_THEME$" "$XSR"; then
    skip "~/.xsessionrc already exports XCURSOR_THEME."
else
    if $DRY_RUN; then
        printf '%s  would set:%s XCURSOR_THEME/SIZE → %s\n' "$C_DIM" "$C_OFF" "$XSR"
    else
        touch "$XSR"
        sed -i '/^export XCURSOR_\(THEME\|SIZE\)=/d' "$XSR"
        printf 'export XCURSOR_THEME=%s\nexport XCURSOR_SIZE=24\n' "$CURSOR_THEME" >> "$XSR"
    fi
    ok "XCURSOR_* exported in ~/.xsessionrc (log out/in to apply)."
fi

# GTK apps read the cursor theme from gsettings separately.
if command -v gsettings >/dev/null 2>&1; then
    run gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR_THEME" || \
        warn "Could not set gsettings cursor-theme."
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
    $enabled_any || warn "mpdris2 service unit not found — bar music titles may not appear."
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
