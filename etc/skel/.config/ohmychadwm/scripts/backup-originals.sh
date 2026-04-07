#!/usr/bin/env bash
# backup-originals.sh
# Saves a one-time copy of external app config files before ohmychadwm first
# modifies them. Run before any font/style apply. If a backup already exists
# for a file it is never overwritten, preserving the true pre-ohmychadwm state.
#
# Usage:
#   bash backup-originals.sh          — backup only (silent)
#   bash backup-originals.sh --restore — restore all backed-up files

BACKUP_DIR="${HOME}/.config/ohmychadwm/backups/originals"

declare -A FILES=(
    ["alacritty.toml"]="${HOME}/.config/alacritty/alacritty.toml"
    ["kitty.conf"]="${HOME}/.config/kitty/kitty.conf"
    ["gtk-3.0-settings.ini"]="${HOME}/.config/gtk-3.0/settings.ini"
    ["gtk-4.0-settings.ini"]="${HOME}/.config/gtk-4.0/settings.ini"
    ["rofi-config.rasi"]="${HOME}/.config/rofi/config.rasi"
    ["xfce4-xsettings.xml"]="${HOME}/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml"
)

backup() {
    mkdir -p "$BACKUP_DIR"
    for name in "${!FILES[@]}"; do
        local src="${FILES[$name]}"
        local dst="$BACKUP_DIR/$name"
        if [[ -f "$src" && ! -f "$dst" ]]; then
            cp "$src" "$dst"
        fi
    done
}

restore() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Hard Reset — restore original app settings"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  Restores your original settings for:"
    echo "  alacritty, kitty, GTK3/4, rofi"
    echo ""
    echo "  Only files backed up before ohmychadwm first"
    echo "  changed them will be restored."
    echo ""

    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo "  No backups found at $BACKUP_DIR"
        echo "  Nothing to restore."
        return 0
    fi

    local found=0
    for name in "${!FILES[@]}"; do
        if [[ -f "$BACKUP_DIR/$name" ]]; then
            printf "    ✔  %s\n" "$name"
            (( found++ )) || true
        fi
    done

    if [[ $found -eq 0 ]]; then
        echo "  No backups found. Nothing to restore."
        return 0
    fi

    echo ""
    read -rp "  Continue? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] || { echo "  Cancelled."; return 0; }
    echo ""

    for name in "${!FILES[@]}"; do
        local src="$BACKUP_DIR/$name"
        local dst="${FILES[$name]}"
        if [[ -f "$src" ]]; then
            cp "$src" "$dst"
            printf "  Restored: %s\n" "$(basename "$dst")"
        fi
    done

    echo ""
    echo "  Done. Original settings restored."
}

case "${1:-}" in
    --restore) restore ;;
    *)         backup  ;;
esac
