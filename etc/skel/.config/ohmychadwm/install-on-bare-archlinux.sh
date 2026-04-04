#!/usr/bin/env bash
# Install script for ohmychadwm on a bare Arch Linux system.
# Run as a regular user with sudo privileges.

set -euo pipefail

# ── helpers ──────────────────────────────────────────────────────────────────

info()  { printf '\e[32m==> \e[0m%s\n' "$*"; }
warn()  { printf '\e[33m==> WARN: \e[0m%s\n' "$*"; }
die()   { printf '\e[31m==> ERROR: \e[0m%s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] && die "Run this script as a regular user, not root."
[[ -f /etc/arch-release ]] || die "This script is for Arch Linux only."

# ── 1. ensure yay ────────────────────────────────────────────────────────────

if ! command -v yay &>/dev/null; then
    info "Installing yay (AUR helper)..."
    sudo pacman -S --needed --noconfirm git base-devel
    tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
    (cd "$tmpdir/yay" && makepkg -si --noconfirm)
    rm -rf "$tmpdir"
fi

# ── 2. chaotic-aur ───────────────────────────────────────────────────────────
# Provides pre-built AUR packages: picom-git, pamac-aur, variety, volctl,
# fastcompmgr, ttf-meslo-nerd-font-powerlevel10k, and more.

if ! grep -q '^\[chaotic-aur\]' /etc/pacman.conf; then
    info "Setting up chaotic-aur..."
    sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    sudo pacman-key --lsign-key 3056513887B78AEB
    sudo pacman -U --noconfirm \
        'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
    sudo pacman -U --noconfirm \
        'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
    sudo tee -a /etc/pacman.conf > /dev/null <<'EOF'

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF
    info "chaotic-aur added to /etc/pacman.conf"
fi

# ── 3. nemesis_repo (ArcoLinux) ───────────────────────────────────────────────
# Provides ArcoLinux-specific packages: archlinux-logout-git, edu-chadwm-git,
# edu-xfce-git, and other arcolinux-* tools.

if ! grep -q '^\[nemesis_repo\]' /etc/pacman.conf; then
    info "Setting up nemesis_repo (ArcoLinux)..."

    # Install the ArcoLinux keyring so pacman trusts the repo's signatures.
    # arcolinux-keyring is available on the AUR.
    yay -S --needed --noconfirm arcolinux-keyring

    sudo tee -a /etc/pacman.conf > /dev/null <<'EOF'

[nemesis_repo]
Server = https://nemesis.arcolinux.com/$arch
EOF
    info "nemesis_repo added to /etc/pacman.conf"
fi

# Refresh package databases after any repo additions
sudo pacman -Sy

# ── 4. package lists ─────────────────────────────────────────────────────────

# Build dependencies for chadwm and slstatus (compiled from source)
build_deps=(
    base-devel        # gcc, make, etc.
    libx11
    libxinerama
    libxft
    fontconfig
    libxrender
    imlib2            # chadwm: -lImlib2 in config.mk
    libxext
    freetype2
    xorgproto         # X11/XF86keysym.h
)

# Core WM runtime — everything needed for ohmychadwm to start and be usable
core=(
    alacritty
    autorandr
    dash
    dmenu
    feh
    lolcat
    lxappearance
    picom-git             # chaotic-aur
    polkit-gnome
    rofi
    sxhkd
    xorg-xsetroot
)

# File manager
files=(
    gvfs
    thunar
    thunar-archive-plugin
    thunar-volman
)

# Autostart services launched by run.sh
autostart=(
    network-manager-applet    # nm-applet
    pamac-aur                 # pamac-tray — chaotic-aur
    variety                   # wallpaper switcher — chaotic-aur
    flameshot                 # screenshot daemon
    xfce4-clipman             # clipboard manager
    blueberry                 # bluetooth tray
    numlockx                  # numlock on boot
    volctl                    # volume tray — chaotic-aur
    fastcompmgr               # compositor fallback — chaotic-aur
)

# ArcoLinux / nemesis_repo + XFCE components
xfce=(
    archlinux-logout-git      # nemesis_repo
    edu-chadwm-git            # nemesis_repo
    edu-xfce-git              # nemesis_repo
    xfce4-notifyd
    xfce4-power-manager
    xfce4-screenshooter
    xfce4-settings
    xfce4-taskmanager
    xfce4-terminal
)

# Keybinding tools referenced in sxhkdrc / config.def.h
keybinding_tools=(
    btop                # alacritty -e btop
    alsa-utils          # amixer (volume keys)
    playerctl           # media keys
    xorg-xbacklight     # brightness keys
    scrot               # screenshot
    xorg-xkill          # xkill
    pavucontrol         # audio settings
)

# Menu script dependencies (ohmychadwm-menu.sh)
menu_tools=(
    xclip
    maim
    slop
    xdotool
    fzf
    libnotify           # notify-send
)

# Fonts
fonts=(
    ttf-hack
    ttf-font-awesome
    ttf-jetbrains-mono-nerd
    ttf-meslo-nerd-font-powerlevel10k    # chaotic-aur
)

# ── 5. install all packages ───────────────────────────────────────────────────

all_packages=(
    "${build_deps[@]}"
    "${core[@]}"
    "${files[@]}"
    "${autostart[@]}"
    "${xfce[@]}"
    "${keybinding_tools[@]}"
    "${menu_tools[@]}"
    "${fonts[@]}"
)

info "Installing ${#all_packages[@]} packages..."
yay -S --needed --noconfirm "${all_packages[@]}"

# ── 6. build chadwm and slstatus from source ──────────────────────────────────

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

info "Building chadwm..."
(cd "$REPO_DIR/chadwm" && make clean && sudo make install)

info "Building slstatus..."
(cd "$REPO_DIR/slstatus" && make clean && sudo make install)

# ── 7. install session entry ─────────────────────────────────────────────────

SESSION_FILE="/usr/share/xsessions/ohmychadwm.desktop"

if [[ ! -f "$SESSION_FILE" ]]; then
    info "Installing ohmychadwm.desktop session entry..."
    sudo mkdir -p /usr/share/xsessions
    sudo tee "$SESSION_FILE" > /dev/null <<EOF
[Desktop Entry]
Name=ohmychadwm
Comment=ohmychadwm — dynamic window manager
Exec=$REPO_DIR/scripts/run.sh
Type=Application
EOF
fi

info "Done! Log out and select ohmychadwm from your display manager, or add"
info "  exec $REPO_DIR/scripts/run.sh"
info "to your ~/.xinitrc and run \`startx\`."
