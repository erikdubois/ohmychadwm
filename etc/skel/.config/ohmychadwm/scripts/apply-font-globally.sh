#!/usr/bin/env bash
# apply-font-globally.sh
# Ask font preferences and apply them to all configured applications.
# Does NOT touch chadwm config.def.h or theme files — use the theme
# generator for that.

set -euo pipefail

# ── terminal colors ──────────────────────────────────────────────────────────
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'
C='\033[0;36m'; W='\033[1;37m'; NC='\033[0m'

header() { echo -e "\n${C}${W}$*${NC}"; }
ask()    { echo -e "${Y}$*${NC}"; }
ok()     { echo -e "${G}✔ $*${NC}"; }
err()    { echo -e "${R}✘ $*${NC}" >&2; }

# ── backup originals before first modification ───────────────────────────────
bash "${HOME}/.config/ohmychadwm/scripts/backup-originals.sh"

# ── font questions ────────────────────────────────────────────────────────────
ask_font() {
    header "── Apply font globally ─────────────────────────────────"

    THEME_FONT="JetBrainsMono Nerd Font Mono"
    THEME_FONTSTYLE="Bold"
    THEME_FONTSIZE=13
    THEME_ICONSIZE=18

    ask "Keep default font? (JetBrainsMono Nerd Font Mono, Bold, 13, icon 18) [Y/n]:"
    read -rp "> " ans
    if [[ "$ans" =~ ^[Nn]$ ]]; then

        # font family
        ask "Bar font — press Enter to keep default, or any key to browse:"
        read -rp "> " ans
        if [[ -n "$ans" ]]; then
            local picked
            picked=$(fc-list : family \
                | sed 's/,.*//' \
                | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
                | grep -v '^\.' \
                | sort -uf \
                | fzf \
                --prompt="Font > " \
                --height=40% \
                --layout=reverse \
                --border \
                2>/dev/null) || true
            if [[ -n "$picked" ]]; then
                THEME_FONT="$picked"
            fi
        fi
        ok "Font family: $THEME_FONT"

        # font style — query real styles for the selected font
        local styles
        styles=$(fc-list ":family=${THEME_FONT}" style 2>/dev/null \
            | grep -oP '(?<=style=)[^\n]+' \
            | tr ',' '\n' \
            | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
            | sort -u)
        local style_count
        style_count=$(echo "$styles" | grep -c .)
        if [[ $style_count -le 1 ]]; then
            THEME_FONTSTYLE=$(echo "$styles" | head -1)
            [[ -z "$THEME_FONTSTYLE" ]] && THEME_FONTSTYLE="Bold"
            ok "Font style: $THEME_FONTSTYLE (only available style)"
        else
            local picked_style
            picked_style=$(echo "$styles" | fzf \
                --prompt="Style > " \
                --height=40% \
                --layout=reverse \
                --border \
                2>/dev/null) || true
            if [[ -n "$picked_style" ]]; then
                THEME_FONTSTYLE="$picked_style"
            fi
            ok "Font style: $THEME_FONTSTYLE"
        fi

        # font size
        ask "Font size? [default 13]:"
        read -rp "> " ans
        if [[ "$ans" =~ ^[0-9]+$ ]] && (( ans >= 6 && ans <= 72 )); then
            THEME_FONTSIZE=$ans
        fi
        ok "Font size: $THEME_FONTSIZE"

        # icon size
        ask "Bar icon size? [default 18]:"
        read -rp "> " ans
        if [[ "$ans" =~ ^[0-9]+$ ]] && (( ans >= 8 && ans <= 72 )); then
            THEME_ICONSIZE=$ans
        fi
        ok "Icon size: $THEME_ICONSIZE"

    else
        ok "Font: $THEME_FONT, $THEME_FONTSTYLE, $THEME_FONTSIZE, icon $THEME_ICONSIZE (defaults)"
    fi
}

# ── apply to all applications ─────────────────────────────────────────────────
apply_font_globally() {
    header "Applying font to applications"

    # rofi font format: "Family Style Size"
    local rofi_font="${THEME_FONT} ${THEME_FONTSTYLE} ${THEME_FONTSIZE}"

    # ── ohmychadwm menu (ohmychadwm-menu.rasi) ───────────────────────────────
    local rasi="${HOME}/.config/ohmychadwm/menu/ohmychadwm-menu.rasi"
    ask "Apply font to ohmychadwm menu (rofi)? [Y/n]:"
    read -rp "> " ans
    if [[ ! "$ans" =~ ^[Nn]$ ]]; then
        if [[ -f "$rasi" ]]; then
            sed -i "s|font:.*\"[^\"]*\";|font:             \"${rofi_font}\";|" "$rasi"
            ok "Menu font updated → $rofi_font"
        else
            err "rasi file not found: $rasi"
        fi
    fi

    # ── alacritty ────────────────────────────────────────────────────────────
    local alacritty="${HOME}/.config/alacritty/alacritty.toml"
    ask "Apply font to Alacritty? [Y/n]:"
    read -rp "> " ans
    if [[ ! "$ans" =~ ^[Nn]$ ]]; then
        if [[ -f "$alacritty" ]]; then
            sed -i 's|^\(family = \)"[^"]*"|\1"'"${THEME_FONT}"'"|' "$alacritty"
            sed -i 's|^\(size = \)[0-9.]*|\1'"${THEME_FONTSIZE}.0"'|' "$alacritty"
            ok "Alacritty font updated → $THEME_FONT, size ${THEME_FONTSIZE}"
        else
            err "Alacritty config not found: $alacritty"
        fi
    fi

    # ── xfce4 + gtk3/gtk4 ────────────────────────────────────────────────────
    ask "Apply font to XFCE4 / GTK apps (Thunar, etc.)? [Y/n]:"
    read -rp "> " ans
    if [[ ! "$ans" =~ ^[Nn]$ ]]; then
        if command -v xfconf-query &>/dev/null; then
            xfconf-query -c xsettings -p /Gtk/FontName -s "${rofi_font}"
            ok "XFCE4 GTK font updated → $rofi_font"
        fi
        local gtk3="${HOME}/.config/gtk-3.0/settings.ini"
        if [[ -f "$gtk3" ]]; then
            sed -i "s|^gtk-font-name=.*|gtk-font-name=${rofi_font}|" "$gtk3"
            ok "GTK3 font updated → $rofi_font"
        fi
        local gtk4="${HOME}/.config/gtk-4.0/settings.ini"
        if [[ -f "$gtk4" ]]; then
            sed -i "s|^gtk-font-name=.*|gtk-font-name=${rofi_font}|" "$gtk4"
            ok "GTK4 font updated → $rofi_font"
        fi
    fi

    # ── rofi global config + launcher2 (Super+D / ctrl+alt+r) ────────────────
    for rofi_cfg in \
        "${HOME}/.config/ohmychadwm/rofi/config.rasi" \
        "${HOME}/.config/ohmychadwm/rofi/launcher2.rasi"; do
        if [[ -f "$rofi_cfg" ]]; then
            sed -i 's|\(\s*font:\s*\)"[^"]*"|\1"'"${rofi_font}"'"|g' "$rofi_cfg"
            ok "$(basename "$rofi_cfg") font updated → $rofi_font"
        fi
    done

    # system rofi config (rofi-theme-selector)
    local system_rofi="${HOME}/.config/rofi/config.rasi"
    if [[ -f "$system_rofi" ]]; then
        if grep -q '/\*.*font:' "$system_rofi"; then
            sed -i 's|/\*\s*font:.*\*/|font: "'"${rofi_font}"'";|' "$system_rofi"
        else
            sed -i 's|\(\s*font:\s*\)"[^"]*"|\1"'"${rofi_font}"'"|g' "$system_rofi"
        fi
        ok "System rofi config font updated → $rofi_font"
    fi

    # ── launcher rofi themes ─────────────────────────────────────────────────
    local launcher_dir="${HOME}/.config/ohmychadwm/launcher/rofi"
    ask "Apply font to launcher rofi themes? [Y/n]:"
    read -rp "> " ans
    if [[ ! "$ans" =~ ^[Nn]$ ]]; then
        local updated=0
        for rasi_file in "$launcher_dir"/launcher.rasi "$launcher_dir"/keybindings.rasi "$launcher_dir"/powermenu.rasi; do
            if [[ -f "$rasi_file" ]]; then
                sed -i 's|\(\s*font:\s*\)"[^"]*"|\1"'"${rofi_font}"'"|g' "$rasi_file"
                ok "$(basename "$rasi_file") font updated → $rofi_font"
                (( updated++ )) || true
            fi
        done
        [[ $updated -eq 0 ]] && err "No launcher rasi files found in $launcher_dir"
    fi

    # ── kitty (only if installed) ────────────────────────────────────────────
    if command -v kitty &>/dev/null; then
        local kitty_conf="${HOME}/.config/kitty/kitty.conf"
        ask "Apply font to Kitty terminal? [Y/n]:"
        read -rp "> " ans
        if [[ ! "$ans" =~ ^[Nn]$ ]]; then
            if [[ -f "$kitty_conf" ]]; then
                sed -i "s|^font_family.*|font_family      ${THEME_FONT}|" "$kitty_conf"
                sed -i "s|^font_size.*|font_size        ${THEME_FONTSIZE}.0|" "$kitty_conf"
                ok "Kitty font updated → $THEME_FONT, size ${THEME_FONTSIZE}"
            else
                err "Kitty config not found: $kitty_conf"
            fi
        fi
    fi

    echo
    ok "Font settings applied."
}

# ── main ──────────────────────────────────────────────────────────────────────
ask_font
apply_font_globally

echo
