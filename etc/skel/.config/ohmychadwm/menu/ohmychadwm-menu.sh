#!/usr/bin/env bash
# =============================================================================
# ohmychadwm-menu — hierarchical system menu for ohmychadwm / X11
# Inspired by omarchy-menu (basecamp/omarchy), ported from Wayland to X11.
#
# Dependencies:
#   rofi          — menu renderer  (pacman -S rofi)
#   fastcompmgr   — compositor     (pacman -S fastcompmgr)
#   notify-send   — part of libnotify
#   xclip         — clipboard      (pacman -S xclip)
#   maim + slop   — screenshots    (pacman -S maim slop)
#   xcolor        — colour picker  (pacman -S xcolor)  [optional]
#   xdotool       — window control (pacman -S xdotool) [optional]
#   xdg-open      — open URLs / files
#   pacman / yay  — package management
#   fzf           — fuzzy finder   (pacman -S fzf)
#   redshift      — night light    (pacman -S redshift) [optional]
#   xautolock     — idle lock      (pacman -S xautolock) [optional]
#   slock / i3lock — screen locker [optional]
#
# Install path: put this file somewhere on your PATH, e.g. ~/.local/bin/ohmychadwm-menu
# Make executable: chmod +x ~/.local/bin/ohmychadwm-menu
#
# ohmychadwm keybinding (add to your config.h or scripts/keybindings.sh):
#   Super + Alt + Space  →  ohmychadwm-menu
#   Super + Alt + Space  →  ohmychadwm-menu screenshot   (jump straight in)
#
# =============================================================================

set -uo pipefail

# ---------------------------------------------------------------------------
# User-tuneable settings — override in ~/.config/ohmychadwm/menu.conf if present
# ---------------------------------------------------------------------------
TERMINAL="${TERMINAL:-alacritty}"
EDITOR="${EDITOR:-nvim}"
# Detect installed browser — use $BROWSER if already set, otherwise find first available
if [[ -z "${BROWSER:-}" ]]; then
    for _b in firefox chromium brave-browser qutebrowser epiphany midori; do
        if command -v "$_b" &>/dev/null; then
            BROWSER="$_b"
            break
        fi
    done
    BROWSER="${BROWSER:-xdg-open}"  # xdg-open as last resort
fi
PRESENT_FONT_SIZE="${PRESENT_FONT_SIZE:-14}"
MENU_WIDTH="${MENU_WIDTH:-40}"

# ohmychadwm config root
OHMYCHADWM_CONFIG="${HOME}/.config/ohmychadwm"

# Rofi theme — defaults to ohmychadwm-menu.rasi next to this script,
# then falls back to ~/.config/rofi/ohmychadwm-menu.rasi
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROFI_THEME="${ROFI_THEME:-}"
if [[ -z "$ROFI_THEME" ]]; then
    if [[ -f "${_SCRIPT_DIR}/ohmychadwm-menu.rasi" ]]; then
        ROFI_THEME="${_SCRIPT_DIR}/ohmychadwm-menu.rasi"
    elif [[ -f "${HOME}/.config/rofi/ohmychadwm-menu.rasi" ]]; then
        ROFI_THEME="${HOME}/.config/rofi/ohmychadwm-menu.rasi"
    fi
fi

# Source user overrides if they exist
[[ -f "${OHMYCHADWM_CONFIG}/menu.conf" ]] && source "${OHMYCHADWM_CONFIG}/menu.conf"

# Load user extension (can override any function defined before the source line)
USER_EXTENSION="${OHMYCHADWM_CONFIG}/menu/menu-extension.sh"

# ---------------------------------------------------------------------------
# Back-navigation flag
# When jumping directly to a submenu via CLI (ohmychadwm-menu screenshot),
# pressing Escape exits rather than returning to the parent menu.
# ---------------------------------------------------------------------------
BACK_TO_EXIT=false

go_back() {
    :
}

# ---------------------------------------------------------------------------
# Core helper: menu renderer
# Usage: menu "Prompt" "option1\noption2\noption3" ["extra rofi args"]
# Returns the selected item on stdout; exits/goes-back on cancel.
# ---------------------------------------------------------------------------
menu() {
    local prompt="$1"
    local options="$2"
    local extra="${3:-}"

    local theme_arg=()
    [[ -n "$ROFI_THEME" ]] && theme_arg=(-theme "$ROFI_THEME")

    local choice
    # Capture exit code explicitly — rofi returns 1 on Escape, not an error
    choice=$(echo -e "$options" | rofi -dmenu \
        -p "" \
        -no-show-match \
        -no-fixed-num-lines \
        -cycle \
        "${theme_arg[@]}" \
        ${extra} \
        2>/dev/null) || true

    # Empty result (Escape / no selection) → navigate back or exit
    if [[ -z "$choice" ]]; then
        go_back
        return 1
    fi

    echo "$choice"
}

# ---------------------------------------------------------------------------
# Terminal helpers
# ---------------------------------------------------------------------------

# Launch a plain terminal (for interactive TUI tools)
terminal() {
    setsid "$TERMINAL" "$@" >/dev/null 2>&1 &
    disown
}

# Launch a floating "presentation" terminal for progress output.
# Uses a WM_CLASS so you can set a ohmychadwm floating rule for it:
#   { "OhmychadwmPresent", NULL, NULL, 0, 1, 0, 0, -1 }   ← example rules entry
present_terminal() {
    local cmd="$*"
    setsid "$TERMINAL" \
        --class OhmychadwmPresent \
        -e bash -c "
            echo
            printf '  \e[1m%s\e[0m\n\n' 'ohmychadwm'
            ${cmd}
            echo
            printf '  Press any key to close...'
            read -n1 -s
        " >/dev/null 2>&1 &
    disown
}

# Open a file in $EDITOR inside a floating terminal
edit_in_editor() {
    local file="$1"
    notify-send -t 2000 "ohmychadwm" "Editing $(basename "$file")"
    present_terminal "${EDITOR} '${file}'"
}

# ---------------------------------------------------------------------------
# Package install helpers
# ---------------------------------------------------------------------------
install() {
    # install "Display Name" "pkg1 pkg2"
    local name="$1"
    local pkgs="$2"
    present_terminal "echo 'Installing ${name}...'; sudo pacman -S --needed --noconfirm ${pkgs} && notify-send 'ohmychadwm' '${name} installed.' || notify-send -u critical 'ohmychadwm' 'Install failed.'"
}

aur_install() {
    # aur_install "Display Name" "aur-pkg"
    local name="$1"
    local pkg="$2"
    present_terminal "echo 'Installing ${name} from AUR...'; yay -S --noconfirm ${pkg} && notify-send 'ohmychadwm' '${name} installed.' || notify-send -u critical 'ohmychadwm' 'AUR install failed.'"
}

remove_pkg() {
    local name="$1"
    local pkgs="$2"
    present_terminal "echo 'Removing ${name}...'; sudo pacman -Rns --noconfirm ${pkgs} && notify-send 'ohmychadwm' '${name} removed.' || notify-send -u critical 'ohmychadwm' 'Remove failed.'"
}

# ===========================================================================
# MENU FUNCTIONS
# ===========================================================================

# ---------------------------------------------------------------------------
# Learn
# ---------------------------------------------------------------------------
show_learn_menu() {
    case $(menu "Learn" " Keybindings\n Arch Wiki\n Chadwm source\n Neovim\n Bash\n Man pages") in
        *Keybindings*)  ~/.config/ohmychadwm/scripts/show-keybindings.sh ;;
        *"Arch Wiki"*)  setsid "$BROWSER" "https://wiki.archlinux.org" >/dev/null 2>&1 & disown ;;
        *Chadwm*)       setsid "$BROWSER" "https://github.com/erikdubois/ohmychadwm" >/dev/null 2>&1 & disown ;;
        *Neovim*)       setsid "$BROWSER" "https://www.lazyvim.org/keymaps" >/dev/null 2>&1 & disown ;;
        *Bash*)         setsid "$BROWSER" "https://devhints.io/bash" >/dev/null 2>&1 & disown ;;
        *"Man pages"*)  present_terminal "man -k . | fzf --preview 'man {1}' | awk '{print \$1}' | xargs -r man" ;;
        *)              return 1 ;;
    esac
}

# ---------------------------------------------------------------------------
# Trigger — Capture / Share / Toggle
# ---------------------------------------------------------------------------
show_trigger_menu() {
    while true; do
        case $(menu "Trigger" " Capture\n Share\n Toggle") in
            *Capture*) show_capture_menu || continue; return 0 ;;
            *Share*)   show_share_menu   || continue; return 0 ;;
            *Toggle*)  show_toggle_menu  || continue; return 0 ;;
            *)         return 1 ;;
        esac
    done
}

show_capture_menu() {
    while true; do
        case $(menu "Capture" " Screenshot\n Screenshot → clipboard\n Screenshot region\n Screen record\n Colour picker") in
            *"Screenshot →"*)      _screenshot_clipboard; return 0 ;;
            *"Screenshot region"*) _screenshot_region;    return 0 ;;
            *"Screenshot"*)        _screenshot_smart;     return 0 ;;
            *"Screen record"*)     show_screenrecord_menu || continue; return 0 ;;
            *"Colour picker"*)     _colour_picker;        return 0 ;;
            *)                     return 1 ;;
        esac
    done
}

_screenshot_smart() {
    # Full-screen screenshot saved to ~/Pictures/Screenshots, notified with option to annotate
    local dir="${HOME}/Pictures/Screenshots"
    mkdir -p "$dir"
    local file="${dir}/$(date +%Y-%m-%d_%H-%M-%S).png"
    maim "$file"
    xclip -selection clipboard -t image/png < "$file"
    notify-send -t 5000 "Screenshot saved" "$file" --action="Edit=xdg-open '${file}'"
}

_screenshot_clipboard() {
    maim | xclip -selection clipboard -t image/png
    notify-send -t 2000 "Screenshot" "Copied to clipboard"
}

_screenshot_region() {
    local dir="${HOME}/Pictures/Screenshots"
    mkdir -p "$dir"
    local file="${dir}/$(date +%Y-%m-%d_%H-%M-%S).png"
    maim -s "$file"
    xclip -selection clipboard -t image/png < "$file"
    notify-send -t 3000 "Region screenshot" "Saved & copied to clipboard"
}

_colour_picker() {
    if command -v xcolor &>/dev/null; then
        local color
        color=$(xcolor)
        echo -n "$color" | xclip -selection clipboard
        notify-send -t 2000 "Colour picked" "$color"
    else
        notify-send -u critical "ohmychadwm" "xcolor not installed. Run: sudo pacman -S xcolor"
    fi
}

show_screenrecord_menu() {
    case $(menu "Screen record" "Record screen\nRecord screen + mic\n Stop recording") in
        *"Record screen + mic"*) _screenrecord start mic ;;
        *"Record screen"*)       _screenrecord start ;;
        *"Stop"*)                _screenrecord stop ;;
        *)                       return 1 ;;
    esac
}

_screenrecord() {
    local action="${1:-start}"
    local dir="${HOME}/Videos/Recordings"
    mkdir -p "$dir"
    local file="${dir}/$(date +%Y-%m-%d_%H-%M-%S).mp4"

    if [[ "$action" == "stop" ]]; then
        pkill -INT ffmpeg 2>/dev/null && notify-send "Screen record" "Recording stopped"
        return
    fi

    local audio_flags=""
    if [[ "${2:-}" == "mic" ]]; then
        audio_flags="-f pulse -i default"
    fi

    # Get screen geometry
    local display="${DISPLAY:-:0}"
    local geo
    geo=$(xdpyinfo | grep dimensions | awk '{print $2}')

    setsid bash -c "
        ffmpeg -f x11grab -r 30 -s '${geo}' -i '${display}' \
            ${audio_flags} \
            -c:v libx264 -preset ultrafast -crf 18 \
            '${file}' >/dev/null 2>&1
        notify-send 'Screen record' 'Saved to ${file}'
    " &
    disown
    notify-send "Screen record" "Recording started (run Trigger > Stop recording to finish)"
}

show_share_menu() {
    if ! command -v localsend &>/dev/null; then
        notify-send -u critical "ohmychadwm" "LocalSend not installed. Install via Install > Apps > LocalSend"
        return 1
    fi
    case $(menu "Share" " Clipboard\n File\n Folder") in
        *Clipboard*) _share_clipboard ;;
        *File*)      _share_file ;;
        *Folder*)    _share_folder ;;
        *)           return 1 ;;
    esac
}

_share_clipboard() {
    local tmp
    tmp=$(mktemp /tmp/ohmychadwm-share-XXXX.txt)
    xclip -selection clipboard -o > "$tmp"
    localsend "$tmp" &
    disown
}

_share_file() {
    local file
    file=$(find "${HOME}" -maxdepth 5 -type f 2>/dev/null | fzf --prompt="Select file to share: ")
    [[ -n "$file" ]] && setsid localsend "$file" &>/dev/null &
}

_share_folder() {
    local folder
    folder=$(find "${HOME}" -maxdepth 4 -type d 2>/dev/null | fzf --prompt="Select folder to share: ")
    [[ -n "$folder" ]] && setsid localsend "$folder" &>/dev/null &
}

show_toggle_menu() {
    local _nightlight_state="Enable"
    local _autolock_state="Enable"

    [[ -f "${HOME}/.local/state/ohmychadwm/toggles/nightlight-on" ]] && _nightlight_state="Disable"
    [[ -f "${HOME}/.local/state/ohmychadwm/toggles/autolock-on" ]]   && _autolock_state="Disable"

    case $(menu "Toggle" "${_nightlight_state} night light\n ${_autolock_state} auto-lock") in
        *"night light"*) _toggle_nightlight ;;
        *"auto-lock"*)   _toggle_autolock ;;
        *)               return 1 ;;
    esac
}

_toggle_nightlight() {
    local state_file="${HOME}/.local/state/ohmychadwm/toggles/nightlight-on"
    mkdir -p "$(dirname "$state_file")"
    if [[ -f "$state_file" ]]; then
        pkill redshift 2>/dev/null; rm -f "$state_file"
        notify-send "Night light" "Disabled"
    else
        touch "$state_file"
        redshift -O 4000 &>/dev/null &
        disown
        notify-send "Night light" "Enabled (4000K)"
    fi
}

_toggle_autolock() {
    local state_file="${HOME}/.local/state/ohmychadwm/toggles/autolock-on"
    mkdir -p "$(dirname "$state_file")"
    if [[ -f "$state_file" ]]; then
        pkill xautolock 2>/dev/null; rm -f "$state_file"
        notify-send "Auto-lock" "Disabled"
    else
        touch "$state_file"
        xautolock -time 10 -locker slock &>/dev/null &
        disown
        notify-send "Auto-lock" "Enabled (10 min)"
    fi
}

# ---------------------------------------------------------------------------
# Style
# ---------------------------------------------------------------------------
show_style_menu() {
    while true; do
        case $(menu "Style" " Theme\n Tags\n Border\n Gaps\n Bar position\n Smart gaps\n Hide systray\n New window\n Launcher icons\n Master area\n Alacritty\n Font\n Wallpaper\n Picom / compositor\n Colours (Xresources)") in
            *Theme*)           show_theme_menu        || continue; return 0 ;;
            *Tags*)            show_tags_menu         || continue; return 0 ;;
            *Border*)          show_border_menu       || continue; return 0 ;;
            *Gaps*)            show_gaps_menu         || continue; return 0 ;;
            *"Bar position"*)  show_bar_menu          || continue; return 0 ;;
            *"Smart gaps"*)    show_smartgaps_menu    || continue; return 0 ;;
            *"Hide systray"*)  show_systray_menu      || continue; return 0 ;;
            *"New window"*)    show_newwindow_menu    || continue; return 0 ;;
            *"Launcher icons"*) show_launchers_menu  || continue; return 0 ;;
            *"Master area"*)   show_mfact_menu        || continue; return 0 ;;
            *Alacritty*)       show_alacritty_menu   || continue; return 0 ;;
            *Font*)            show_font_menu         || continue; return 0 ;;
            *Wallpaper*)     show_wallpaper_menu  || continue; return 0 ;;
            *"Picom"*)       edit_in_editor "${HOME}/.config/ohmychadwm/picom/picom.conf"; return 0 ;;
            *"Colours"*)     edit_in_editor "${HOME}/.Xresources"; return 0 ;;
            *)             return 1 ;;
        esac
    done
}

show_tags_menu() {
    local chosen
    chosen=$(menu "Tags" "default tags\nArabic numbers\nRoman numbers\nPowerline\nWebdings\nJapanese numbers\nAlphabetic\nEmoji\nGeometric shapes\nChinese numbers\nPurposemenu") || return 1
    _apply_tags "$chosen"
}

_apply_tags() {
    local chosen="$1"
    local config="${OHMYCHADWM_CONFIG}/chadwm/config.def.h"

    python3 - "$chosen" "$config" <<'PYEOF'
import sys, re

chosen = sys.argv[1]
config = sys.argv[2]

with open(config) as f:
    content = f.read()

# Comment out any currently active tags line
content = re.sub(r'^(static char \*tags\[\])', r'//\1', content, flags=re.MULTILINE)

# Uncomment the tags line that immediately follows the matching comment
pattern = r'(//' + re.escape(chosen) + r'\n)//(static char \*tags\[\])'
new_content, n = re.subn(pattern, r'\1\2', content)

if n == 0:
    print(f"No tags entry found for '{chosen}'", file=sys.stderr)
    sys.exit(1)

with open(config, 'w') as f:
    f.write(new_content)
PYEOF

    if [[ $? -ne 0 ]]; then
        notify-send -u critical "ohmychadwm" "Tags '${chosen}' not found in config.def.h"
        return 1
    fi

    (cd "${OHMYCHADWM_CONFIG}/chadwm" && alacritty -e bash -c './rebuild.sh; exec bash')
    notify-send "ohmychadwm" "Tags set to '${chosen}'"
}

show_border_menu() {
    local current
    current=$(grep -oP 'borderpx\s*=\s*\K[0-9]+' "${OHMYCHADWM_CONFIG}/chadwm/config.def.h")
    local chosen
    chosen=$(menu "Border (current: ${current}px)" "0\n1\n2\n3\n4\n5\n6\n7\n8\n9\n10") || return 1
    _apply_border "$chosen"
}

_apply_border() {
    local px="$1"
    local config="${OHMYCHADWM_CONFIG}/chadwm/config.def.h"
    sed -i "s/static const unsigned int borderpx\s*=\s*[0-9]\+/static const unsigned int borderpx  = ${px}/" "$config"
    (cd "${OHMYCHADWM_CONFIG}/chadwm" && alacritty -e bash -c './rebuild.sh; exec bash')
    notify-send "ohmychadwm" "Border set to ${px}px"
}

show_gaps_menu() {
    local current
    current=$(grep -oP 'gappih\s*=\s*\K[0-9]+' "${OHMYCHADWM_CONFIG}/chadwm/config.def.h")
    local chosen
    chosen=$(menu "Gaps (current: ${current}px)" "0\n1\n2\n3\n4\n5\n6\n7\n8\n9\n10") || return 1
    _apply_gaps "$chosen"
}

_apply_gaps() {
    local px="$1"
    local config="${OHMYCHADWM_CONFIG}/chadwm/config.def.h"
    sed -i "s/\(gappih\s*=\s*\)[0-9]\+/\1${px}/" "$config"
    sed -i "s/\(gappiv\s*=\s*\)[0-9]\+/\1${px}/" "$config"
    sed -i "s/\(gappoh\s*=\s*\)[0-9]\+/\1${px}/" "$config"
    sed -i "s/\(gappov\s*=\s*\)[0-9]\+/\1${px}/" "$config"
    (cd "${OHMYCHADWM_CONFIG}/chadwm" && alacritty -e bash -c './rebuild.sh; exec bash')
    notify-send "ohmychadwm" "Gaps set to ${px}px"
}

show_bar_menu() {
    local config="${OHMYCHADWM_CONFIG}/chadwm/config.def.h"
    local current
    current=$(grep -oP 'topbar\s*=\s*\K[01]' "$config")
    local current_label="top"
    [[ "$current" == "0" ]] && current_label="bottom"
    local chosen
    chosen=$(menu "Bar position (current: ${current_label})" "top\nbottom") || return 1
    local value=1
    [[ "$chosen" == "bottom" ]] && value=0
    sed -i "s/\(static const int topbar\s*=\s*\)[01]/\1${value}/" "$config"
    (cd "${OHMYCHADWM_CONFIG}/chadwm" && alacritty -e bash -c './rebuild.sh; exec bash')
    notify-send "ohmychadwm" "Bar moved to ${chosen}"
}

show_smartgaps_menu() {
    local config="${OHMYCHADWM_CONFIG}/chadwm/config.def.h"
    local current
    current=$(grep -oP 'smartgaps\s*=\s*\K[01]' "$config")
    local current_label="no"
    [[ "$current" == "1" ]] && current_label="yes"
    local chosen
    chosen=$(menu "Smart gaps (current: ${current_label})" "yes\nno") || return 1
    local value=0
    [[ "$chosen" == "yes" ]] && value=1
    sed -i "s/\(static const int smartgaps\s*=\s*\)[01]/\1${value}/" "$config"
    (cd "${OHMYCHADWM_CONFIG}/chadwm" && alacritty -e bash -c './rebuild.sh; exec bash')
    notify-send "ohmychadwm" "Smart gaps set to ${chosen}"
}

show_systray_menu() {
    local config="${OHMYCHADWM_CONFIG}/chadwm/config.def.h"
    local current
    current=$(grep -oP 'showsystray\s*=\s*\K[01]' "$config")
    local current_label="no"
    [[ "$current" == "1" ]] && current_label="yes"
    local chosen
    chosen=$(menu "Hide systray (currently hidden: ${current_label})" "yes\nno") || return 1
    local value=1
    [[ "$chosen" == "yes" ]] && value=0
    sed -i "s/\(static const int showsystray\s*=\s*\)[01]/\1${value}/" "$config"
    (cd "${OHMYCHADWM_CONFIG}/chadwm" && alacritty -e bash -c './rebuild.sh; exec bash')
    notify-send "ohmychadwm" "Systray hidden: ${chosen}"
}

show_newwindow_menu() {
    local config="${OHMYCHADWM_CONFIG}/chadwm/config.def.h"
    local current
    current=$(grep -oP 'new_window_attach_on_end\s*=\s*\K[01]' "$config")
    local current_label="on the front"
    [[ "$current" == "1" ]] && current_label="on the end"
    local chosen
    chosen=$(menu "New window (current: ${current_label})" "on the front\non the end") || return 1
    local value=0
    [[ "$chosen" == "on the end" ]] && value=1
    sed -i "s/\(new_window_attach_on_end\s*=\s*\)[01]/\1${value}/" "$config"
    (cd "${OHMYCHADWM_CONFIG}/chadwm" && alacritty -e bash -c './rebuild.sh; exec bash')
    notify-send "ohmychadwm" "New windows open ${chosen}"
}

show_mfact_menu() {
    local config="${OHMYCHADWM_CONFIG}/chadwm/config.def.h"
    local current
    current=$(grep -oP 'mfact\s*=\s*\K[0-9.]+' "$config")
    local current_pct
    current_pct=$(printf "%.0f" "$(echo "$current * 100" | bc)")
    local chosen
    chosen=$(menu "Master area (current: ${current_pct}%)" \
        "10%\n20%\n30%\n40%\n50%\n60%\n70%\n80%\n90%") || return 1
    local pct="${chosen/\%/}"
    local value
    value=$(printf "0.%02d" "$pct")
    sed -i "s/\(static const float mfact\s*=\s*\)[0-9.]*/\1${value}/" "$config"
    (cd "${OHMYCHADWM_CONFIG}/chadwm" && alacritty -e bash -c './rebuild.sh; exec bash')
    notify-send "ohmychadwm" "Master area set to ${chosen}"
}

ALACRITTY_CONF="${HOME}/.config/alacritty/alacritty.toml"

show_alacritty_menu() {
    while true; do
        case $(menu "Alacritty" " Font family\n Font size\n Opacity\n Shell\n Back to default") in
            *"Font family"*)    show_alacritty_font_menu    || continue; return 0 ;;
            *"Font size"*)      show_alacritty_size_menu    || continue; return 0 ;;
            *Opacity*)          show_alacritty_opacity_menu || continue; return 0 ;;
            *Shell*)            show_alacritty_shell_menu   || continue; return 0 ;;
            *"Back to default"*) _alacritty_reset_default  ; return 0 ;;
            *)                  return 1 ;;
        esac
    done
}

show_alacritty_font_menu() {
    local font_list
    font_list=$(fc-list : family | sort -u)
    local chosen
    chosen=$(echo "$font_list" | rofi -dmenu -p "Alacritty font…" -width "$MENU_WIDTH" -lines 20 2>/dev/null) || return 1
    sed -i "s|^\(family = \).*|\1\"${chosen}\"|" "$ALACRITTY_CONF"
    notify-send "ohmychadwm" "Alacritty font set to '${chosen}'"
}

show_alacritty_size_menu() {
    local current
    current=$(grep -oP 'size\s*=\s*\K[0-9.]+' "$ALACRITTY_CONF" | head -1)
    local chosen
    chosen=$(menu "Font size (current: ${current})" \
        "8\n9\n10\n11\n12\n13\n14\n15\n16\n17\n18\n20\n22\n24") || return 1
    sed -i "s/^\(size\s*=\s*\)[0-9.]*/\1${chosen}.0/" "$ALACRITTY_CONF"
    notify-send "ohmychadwm" "Alacritty font size set to ${chosen}"
}

show_alacritty_opacity_menu() {
    local current
    current=$(grep -oP 'opacity\s*=\s*\K[0-9.]+' "$ALACRITTY_CONF" | head -1)
    local chosen
    chosen=$(menu "Opacity (current: ${current})" \
        "0.1\n0.2\n0.3\n0.4\n0.5\n0.6\n0.7\n0.8\n0.9\n1.0") || return 1
    sed -i "s/^\(opacity\s*=\s*\)[0-9.]*/\1${chosen}/" "$ALACRITTY_CONF"
    notify-send "ohmychadwm" "Alacritty opacity set to ${chosen}"
}

show_alacritty_shell_menu() {
    local current
    current=$(grep -oP 'program\s*=\s*"\K[^"]+' "$ALACRITTY_CONF" | head -1)
    local shell_list
    shell_list=$(grep -v '^#' /etc/shells | grep '^/bin/')
    local chosen
    chosen=$(echo "$shell_list" | rofi -dmenu -p "Shell (current: ${current})" -width "$MENU_WIDTH" 2>/dev/null) || return 1
    sed -i "s|^\(program\s*=\s*\)\"[^\"]*\"|\1\"${chosen}\"|" "$ALACRITTY_CONF"
    notify-send "ohmychadwm" "Alacritty shell set to ${chosen}"
}

_alacritty_reset_default() {
    local default="${HOME}/.config/alacritty/default-arcolinux.toml"
    if [[ ! -f "$default" ]]; then
        notify-send -u critical "ohmychadwm" "Default not found: ${default}"
        return 1
    fi
    cp "$default" "$ALACRITTY_CONF"
    notify-send "ohmychadwm" "Alacritty reset to default"
}

show_launchers_menu() {
    local config="${OHMYCHADWM_CONFIG}/chadwm/config.def.h"
    local -a names=(discord firefox brave opera mintstick pavucontrol telegram vivaldi)
    local -A labels=(
        [discord]="Discord"
        [firefox]="Firefox"
        [brave]="Brave"
        [opera]="Opera"
        [mintstick]="Mintstick"
        [pavucontrol]="Pavucontrol"
        [telegram]="Telegram"
        [vivaldi]="Vivaldi"
    )

    while true; do
        local options=""
        for name in "${names[@]}"; do
            if grep -qP "^\s*\{\s*${name}," "$config"; then
                options+="✓ ${labels[$name]}\n"
            else
                options+="✗ ${labels[$name]}\n"
            fi
        done
        options+=" Apply & rebuild"

        local chosen
        chosen=$(menu "Launcher icons" "$options") || return 1

        if [[ "$chosen" == *"Apply"* ]]; then
            (cd "${OHMYCHADWM_CONFIG}/chadwm" && alacritty -e bash -c './rebuild.sh; exec bash')
            notify-send "ohmychadwm" "Launcher icons updated"
            return 0
        fi

        for name in "${names[@]}"; do
            if [[ "$chosen" == *"${labels[$name]}"* ]]; then
                if grep -qP "^\s*\{\s*${name}," "$config"; then
                    sed -i "s|^\(\s*\){ ${name},|\1//{ ${name},|" "$config"
                else
                    sed -i "s|^\(\s*\)//{ ${name},|\1{ ${name},|" "$config"
                fi
                break
            fi
        done
    done
}

show_theme_menu() {
    local themes_dir="${OHMYCHADWM_CONFIG}/chadwm/themes"
    if [[ ! -d "$themes_dir" ]]; then
        notify-send "ohmychadwm" "No themes directory found at ${themes_dir}"
        return 1
    fi
    local theme_list
    theme_list=$(ls -1 "$themes_dir"/*.h 2>/dev/null | xargs -n1 basename | sed 's/\.h$//')
    if [[ -z "$theme_list" ]]; then
        notify-send "ohmychadwm" "No themes found in ${themes_dir}"
        return 1
    fi
    local count
    count=$(echo "$theme_list" | wc -l)
    local chosen
    chosen=$(menu "Theme  ($count total — ↑↓ scroll)" "$theme_list" "-lines 8") || return 1
    _apply_theme "$chosen"
}

_apply_theme() {
    local theme="$1"
    local config="${OHMYCHADWM_CONFIG}/chadwm/config.def.h"
    if [[ ! -f "${OHMYCHADWM_CONFIG}/chadwm/themes/${theme}.h" ]]; then
        notify-send -u critical "ohmychadwm" "Theme '${theme}' not found"
        return 1
    fi
    # Comment out any active theme include
    sed -i "s|^#include \"themes/\(.*\)\.h\"|//#include \"themes/\1.h\"|" "$config"
    # Uncomment the chosen theme
    sed -i "s|^//#include \"themes/${theme}\.h\"|#include \"themes/${theme}.h\"|" "$config"
    # Apply Xresources if present
    local xres="${OHMYCHADWM_CONFIG}/chadwm/themes/${theme}.Xresources"
    [[ -f "$xres" ]] && xrdb -merge "$xres"
    # Apply alacritty colours if present
    local alacritty_theme="${OHMYCHADWM_CONFIG}/chadwm/themes/alacritty/${theme}.toml"
    [[ -f "$alacritty_theme" ]] && cp "$alacritty_theme" "${HOME}/.config/alacritty/colors.toml"
    # Rebuild chadwm
    (cd "${OHMYCHADWM_CONFIG}/chadwm" && alacritty -e bash -c 'cd ~/.config/ohmychadwm/chadwm && ./rebuild.sh; exec bash')
    notify-send "ohmychadwm" "Theme '${theme}' applied — reboot your system"
}

show_font_menu() {
    local font_list
    font_list=$(fc-list : family | sort -u)
    local chosen
    chosen=$(echo "$font_list" | rofi -dmenu -p "Font…" -width "$MENU_WIDTH" -lines 20 2>/dev/null) || return 1
    _apply_font "$chosen"
}

_apply_font() {
    local font="$1"
    local config="${OHMYCHADWM_CONFIG}/chadwm/config.def.h"
    # Update fonts[] in config.def.h
    sed -i "s|static const char \*fonts\[\].*|static const char *fonts[] = {\"${font}:style:bold:size=13\"};|" "$config"
    # Rebuild chadwm
    (cd "${OHMYCHADWM_CONFIG}/chadwm" && alacritty -e bash -c './rebuild.sh; exec bash')
    notify-send "ohmychadwm" "Font set to '${font}'"
}

show_wallpaper_menu() {
    local walls_dir="${OHMYCHADWM_CONFIG}/wallpapers"
    if [[ ! -d "$walls_dir" ]]; then
        notify-send "ohmychadwm" "No wallpapers directory at ${walls_dir}"
        return 1
    fi
    local wall_list
    wall_list=$(ls -1 "$walls_dir" 2>/dev/null | grep -E '\.(jpg|jpeg|png|webp)$')
    if [[ -z "$wall_list" ]]; then
        notify-send "ohmychadwm" "No wallpaper images found"
        return 1
    fi
    local chosen
    chosen=$(echo "$wall_list" | rofi -dmenu -p "Wallpaper…" -width "$MENU_WIDTH" 2>/dev/null) || return 1 1
    feh --bg-fill "${walls_dir}/${chosen}" && \
        notify-send "ohmychadwm" "Wallpaper set to '${chosen}'"
}

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------
show_setup_menu() {
    while true; do
        local options=" Autostart\n Picom\n Rofi\n Alacritty\n Defaults"

        # Show Xresources option only if the file exists
        [[ -f "${HOME}/.Xresources" ]] && options+=" \n Xresources"

        case $(menu "Setup" "$options") in
            *Autostart*)    edit_in_editor "${OHMYCHADWM_CONFIG}/scripts/run.sh"; return 0 ;;
            *Picom*)        edit_in_editor "${HOME}/.config/ohmychadwm/picom/picom.conf" && _restart_picom; return 0 ;;
            *Rofi*)         edit_in_editor "${HOME}/.config/ohmychadwm/rofi/config.rasi"; return 0 ;;
            *Alacritty*)    edit_in_editor "${HOME}/.config/alacritty/alacritty.toml"; return 0 ;;
            *Defaults*)     show_defaults_menu || continue; return 0 ;;
            *)              return 1 ;;
        esac
    done
}

show_defaults_menu() {
    case $(menu "Defaults" " Terminal\n Editor\n Browser") in
        *Terminal*) _set_default_terminal ;;
        *Editor*)   _set_default_editor ;;
        *Browser*)  _set_default_browser ;;
        *)          return 1 ;;
    esac
}

_set_default_terminal() {
    local terminals="alacritty\nghostty\nkitty\nxterm\nurxvt"
    local chosen
    chosen=$(echo -e "$terminals" | rofi -dmenu -p "Terminal…" -width "$MENU_WIDTH" 2>/dev/null) || return 1
    mkdir -p "${OHMYCHADWM_CONFIG}"
    sed -i "s|^TERMINAL=.*|TERMINAL=${chosen}|" "${OHMYCHADWM_CONFIG}/menu.conf" 2>/dev/null || \
        echo "TERMINAL=${chosen}" >> "${OHMYCHADWM_CONFIG}/menu.conf"
    notify-send "ohmychadwm" "Default terminal set to ${chosen} (takes effect on next menu open)"
}

_set_default_editor() {
    local editors="nvim\nvim\nemacs\nnano\ngedit\ncode"
    local chosen
    chosen=$(echo -e "$editors" | rofi -dmenu -p "Editor…" -width "$MENU_WIDTH" 2>/dev/null) || return 1
    mkdir -p "${OHMYCHADWM_CONFIG}"
    sed -i "s|^EDITOR=.*|EDITOR=${chosen}|" "${OHMYCHADWM_CONFIG}/menu.conf" 2>/dev/null || \
        echo "EDITOR=${chosen}" >> "${OHMYCHADWM_CONFIG}/menu.conf"
    notify-send "ohmychadwm" "Default editor set to ${chosen}"
}

_set_default_browser() {
    local browsers="firefox\nchromium\nbrave\nqutebrowser\nmidori"
    local chosen
    chosen=$(echo -e "$browsers" | rofi -dmenu -p "Browser…" -width "$MENU_WIDTH" 2>/dev/null) || return 1
    mkdir -p "${OHMYCHADWM_CONFIG}"
    sed -i "s|^BROWSER=.*|BROWSER=${chosen}|" "${OHMYCHADWM_CONFIG}/menu.conf" 2>/dev/null || \
        echo "BROWSER=${chosen}" >> "${OHMYCHADWM_CONFIG}/menu.conf"
    notify-send "ohmychadwm" "Default browser set to ${chosen}"
}

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------
show_pamac_menu() {
    if ! command -v pamac &>/dev/null; then
        present_terminal "yay -S pamac-aur"
        return 0
    fi
    pamac-manager &
}

show_install_menu() {
    while true; do
        local items="Pamac"
        command -v octopi &>/dev/null && items+=" \n Octopi"
        items+="\n Package\n Aur package\n Terminal\n Editor\n Browser\n Dev environment\n Ai tools\n Gaming\n Fonts\n Extras"
        case $(menu "Install" "$items") in
            *"Package"*)  present_terminal 'pacman -Slq | fzf --multi --preview "pacman -Si {}" | xargs -ro sudo pacman -S --needed'; return 0 ;;
            *"Aur"*)      present_terminal 'yay -Slq | fzf --multi --preview "yay -Si {}" | xargs -ro yay -S'; return 0 ;;
            *Pamac*)      show_pamac_menu || continue; return 0 ;;
            *Octopi*)     octopi & return 0 ;;
            *Terminal*)   show_install_terminal_menu || continue; return 0 ;;
            *Editor*)     show_install_editor_menu   || continue; return 0 ;;
            *Browser*)    show_install_browser_menu  || continue; return 0 ;;
            *"Dev"*)      show_install_dev_menu      || continue; return 0 ;;
            *Ai*)         show_install_ai_menu       || continue; return 0 ;;
            *Gaming*)     show_install_gaming_menu   || continue; return 0 ;;
            *Fonts*)      show_install_fonts_menu    || continue; return 0 ;;
            *Extras*)     show_install_extras_menu   || continue; return 0 ;;
            *)            return 1 ;;
        esac
    done
}

show_install_terminal_menu() {
    case $(menu "Terminal" " Alacritty\n Ghostty\n Kitty\n Urxvt\n Xterm") in
        *Alacritty*) install "Alacritty" "alacritty" ;;
        *Ghostty*)   aur_install "Ghostty" "ghostty" ;;
        *Kitty*)     install "Kitty" "kitty" ;;
        *Urxvt*)     install "Urxvt" "rxvt-unicode" ;;
        *Xterm*)     install "Xterm" "xterm" ;;
        *)           return 1 ;;
    esac
}

show_install_editor_menu() {
    case $(menu "Editor" " Neovim\n VSCode\n Cursor\n Zed\n Helix\n Emacs") in
        *Neovim*) install    "Neovim"  "neovim" ;;
        *VSCode*) aur_install "VSCode" "visual-studio-code-bin" ;;
        *Cursor*) aur_install "Cursor" "cursor-bin" ;;
        *Zed*)    install    "Zed"    "zed" ;;
        *Helix*)  install    "Helix"  "helix" ;;
        *Emacs*)  install    "Emacs"  "emacs" ;;
        *)        return 1 ;;
    esac
}

show_install_browser_menu() {
    case $(menu "Browser" " Firefox\n Chromium\n Brave\n Qutebrowser") in
        *Firefox*)     install    "Firefox"     "firefox" ;;
        *Chromium*)    install    "Chromium"    "chromium" ;;
        *Brave*)       aur_install "Brave"      "brave-bin" ;;
        *Qutebrowser*) install    "Qutebrowser" "qutebrowser" ;;
        *)             return 1 ;;
    esac
}

show_install_dev_menu() {
    case $(menu "Dev environment" " Node.js + mise\n Ruby + mise\n Python + mise\n Go\n Rust\n Docker\n Podman") in
        *Node*)   present_terminal "mise use -g node@lts && node --version" ;;
        *Ruby*)   present_terminal "mise use -g ruby@latest && ruby --version" ;;
        *Python*) present_terminal "mise use -g python@latest && python --version" ;;
        *Go*)     install "Go" "go" ;;
        *Rust*)   present_terminal "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh" ;;
        *Docker*) install "Docker" "docker docker-compose" && \
                  present_terminal "sudo systemctl enable --now docker && sudo usermod -aG docker \$USER && echo 'Log out and back in for group change'" ;;
        *Podman*) install "Podman" "podman" ;;
        *)        return 1 ;;
    esac
}

show_install_ai_menu() {
    # Detect GPU for appropriate Ollama package
    local ollama_pkg="ollama"
    command -v nvidia-smi &>/dev/null && ollama_pkg="ollama-cuda"
    command -v rocminfo   &>/dev/null && ollama_pkg="ollama-rocm"

    case $(menu "AI tools" " Claude Code\n Ollama (${ollama_pkg})\n OpenCode\n GitHub Copilot (nvim)") in
        *"Claude Code"*)
            present_terminal "sudo pacman -S --needed --noconfirm nodejs npm && npm install -g @anthropic-ai/claude-code && echo 'Done. Run: claude'"
            ;;
        *Ollama*)
            present_terminal "sudo pacman -S --needed --noconfirm ${ollama_pkg} && sudo systemctl enable --now ollama && echo 'Ollama running. Try: ollama run llama3'"
            ;;
        *OpenCode*)
            present_terminal "sudo pacman -S --needed --noconfirm nodejs npm && npm install -g opencode-ai && echo 'Done. Run: opencode'"
            ;;
        *Copilot*)
            present_terminal "sudo pacman -S --needed --noconfirm neovim && nvim --headless '+Lazy install copilot.vim' +q && echo 'Copilot plugin installed'"
            ;;
        *)  return 1 ;;
    esac
}

show_install_gaming_menu() {
    case $(menu "Gaming" " Steam\n Lutris\n RetroArch\n Heroic (Epic Games)\n Bottles (Wine)") in
        *Steam*)   install "Steam"  "steam" ;;
        *Lutris*)  install "Lutris" "lutris" ;;
        *Retro*)   install "RetroArch" "retroarch" ;;
        *Heroic*)  aur_install "Heroic" "heroic-games-launcher-bin" ;;
        *Bottles*) install "Bottles" "bottles" ;;
        *)         return 1 ;;
    esac
}

show_install_fonts_menu() {
    case $(menu "Fonts" " Nerd Fonts (JetBrains)\n Nerd Fonts (FiraCode)\n Noto fonts\n Inter\n Custom (AUR)") in
        *JetBrains*)  aur_install "JetBrains Nerd Font" "ttf-jetbrains-mono-nerd" ;;
        *FiraCode*)   aur_install "FiraCode Nerd Font"  "ttf-firacode-nerd" ;;
        *Noto*)       install "Noto Fonts" "noto-fonts noto-fonts-emoji noto-fonts-cjk" ;;
        *Inter*)      install "Inter" "ttf-inter" ;;
        *Custom*)     present_terminal 'yay -Slq | grep -i font | fzf --multi | xargs -ro yay -S' ;;
        *)            return 1 ;;
    esac
}

show_install_extras_menu() {
    case $(menu "Extras" "LocalSend\n Obsidian\n Signal\n Spotify\n OBS Studio\n Bitwarden") in
        *LocalSend*)  aur_install "LocalSend" "localsend-bin" ;;
        *Obsidian*)   aur_install "Obsidian"  "obsidian" ;;
        *Signal*)     install    "Signal"    "signal-desktop" ;;
        *Spotify*)    aur_install "Spotify"   "spotify" ;;
        *OBS*)        install    "OBS Studio" "obs-studio" ;;
        *Bitwarden*)  install    "Bitwarden"  "bitwarden" ;;
        *)            return 1 ;;
    esac
}

# ---------------------------------------------------------------------------
# Remove
# ---------------------------------------------------------------------------
show_remove_menu() {
    while true; do
        case $(menu "Remove" " Package\n Dev environment\n Autostart entry") in
            *Package*)   present_terminal 'pacman -Qq | fzf --multi --preview "pacman -Qi {}" | xargs -ro sudo pacman -Rns'; return 0 ;;
            *"Dev"*)     show_remove_dev_menu   || continue; return 0 ;;
            *Autostart*) edit_in_editor "${OHMYCHADWM_CONFIG}/scripts/run.sh"; return 0 ;;
            *)           return 1 ;;
        esac
    done
}

show_remove_dev_menu() {
    case $(menu "Remove dev" "Go\n Rust\n Docker") in
        *Go*)     remove_pkg "Go" "go" ;;
        *Rust*)   present_terminal "rustup self uninstall" ;;
        *Docker*) remove_pkg "Docker" "docker docker-compose" ;;
        *)        return 1 ;;
    esac
}

# ---------------------------------------------------------------------------
# Update
# ---------------------------------------------------------------------------
show_update_menu() {
    while true; do
        case $(menu "Update" "System packages\n Aur packages\n Full update\n Restart process\n Hardware\n Timezone\n Keyboard\n Time sync") in
            *"System"*)    present_terminal "sudo pacman -Syu"; return 0 ;;
            *"Aur"*)       present_terminal "yay -Sua"; return 0 ;;
            *"Full"*)      present_terminal "yay -Syu"; return 0 ;;
            *"Restart"*)   show_restart_process_menu  || continue; return 0 ;;
            *Hardware*)    show_restart_hardware_menu || continue; return 0 ;;
            *Timezone*)    present_terminal "tzselect && echo 'Run: sudo timedatectl set-timezone <zone>'"; return 0 ;;
            *Keyboard*)    show_keyboard_menu || continue; return 0 ;;
            *"Time sync"*) present_terminal "sudo timedatectl set-ntp true && timedatectl status"; return 0 ;;
            *)             return 1 ;;
        esac
    done
}

show_keyboard_menu() {
    local keymap
    keymap=$(localectl list-keymaps | rofi -dmenu -p "Keyboard layout" -width "$MENU_WIDTH" 2>/dev/null) || return 1
    [[ -z "$keymap" ]] && return 1
    present_terminal "sudo localectl set-keymap '$keymap' && localectl status"
}

show_restart_process_menu() {
    case $(menu "Restart process" "Picom\n Fastcompmgr\n Sxhkd") in
        *Picom*)      _restart_picom ;;
        *Fastcompmgr*)  _restart_fastcompmgr ;;
        *Sxhkd*)      pkill sxhkd; setsid sxhkd -c "${HOME}/.config/ohmychadwm/sxhkd/sxhkdrc" &>/dev/null & disown; notify-send "ohmychadwm" "Sxhkd restarted" ;;
        *)            return 1 ;;
    esac
}

show_restart_hardware_menu() {
    case $(menu "Restart hardware" "Audio (PipeWire)\n Audio (PulseAudio)\n WiFi\n Bluetooth") in
        *PipeWire*)  _restart_pipewire ;;
        *PulseAudio*) _restart_pulseaudio ;;
        *WiFi*)      present_terminal "printf 'Running: sudo systemctl restart NetworkManager\n\n'; sudo systemctl restart NetworkManager && echo Done" ;;
        *Bluetooth*) present_terminal "printf 'Running: sudo systemctl restart bluetooth\n\n'; sudo systemctl restart bluetooth && echo Done" ;;
        *)           return 1 ;;
    esac
}

_restart_picom() {
    local run="${HOME}/.config/ohmychadwm/scripts/run.sh"
    sed -i 's|^#run "picom|run "picom|' "$run"
    sed -i 's|^run "fastcompmgr|#run "fastcompmgr|' "$run"
    pkill fastcompmgr 2>/dev/null
    pkill picom 2>/dev/null
    setsid picom --config "${HOME}/.config/ohmychadwm/picom/picom.conf" -b &>/dev/null &
    disown
    notify-send "ohmychadwm" "Picom restarted"
}

_restart_fastcompmgr() {
    local run="${HOME}/.config/ohmychadwm/scripts/run.sh"
    sed -i 's|^#run "fastcompmgr|run "fastcompmgr|' "$run"
    sed -i 's|^run "picom|#run "picom|' "$run"
    pkill picom 2>/dev/null
    pkill fastcompmgr 2>/dev/null
    setsid fastcompmgr -c &>/dev/null &
    disown
    notify-send "ohmychadwm" "Fastcompmgr restarted"
}

_restart_pipewire() {
    present_terminal "printf 'Running: systemctl --user restart pipewire pipewire-pulse wireplumber\n\n'; systemctl --user restart pipewire pipewire-pulse wireplumber && notify-send 'ohmychadwm' 'PipeWire restarted' && echo Done"
}

_restart_pulseaudio() {
    present_terminal "printf 'Running: systemctl --user restart pulseaudio\n\n'; systemctl --user restart pulseaudio && notify-send 'ohmychadwm' 'PulseAudio restarted' && echo Done"
}

# ---------------------------------------------------------------------------
# System — power management
# ---------------------------------------------------------------------------
show_system_menu() {
    local options=" Lock\n Suspend\n Restart\n Shutdown"

    # Add Hibernate only if a swap partition/file is available
    if swapon --show | grep -q partition 2>/dev/null || \
       swapon --show | grep -q file      2>/dev/null; then
        options+=" \n Hibernate"
    fi

    case $(menu "System" "$options") in
        *Lock*)      _lock_screen ;;
        *Suspend*)   systemctl suspend ;;
        *Hibernate*) systemctl hibernate ;;
        *Restart*)   systemctl reboot ;;
        *Shutdown*)  systemctl poweroff ;;
        *)           return 1 ;;
    esac
}

_lock_screen() {
    if command -v betterlockscreen &>/dev/null; then
        betterlockscreen -l dim -- --time-str="%H:%M"
    elif command -v slock &>/dev/null; then
        slock
    else
        notify-send -u critical "ohmychadwm" "No screen locker found. Install slock or i3lock."
    fi
}

# ---------------------------------------------------------------------------
# MAIN MENU
# ---------------------------------------------------------------------------
show_main_menu() {
    while true; do
        case $(menu "ohmychadwm" " Apps\n Style\n Learn\n Trigger\n Setup\n Install\n Remove\n Update\n System") in
            *Apps*)    rofi -no-config -no-lazy-grab -show drun -modi drun -theme ~/.config/ohmychadwm/rofi/launcher2.rasi; break ;;
            *Learn*)   show_learn_menu   || continue; break ;;
            *Trigger*) show_trigger_menu || continue; break ;;
            *Style*)   show_style_menu   || continue; break ;;
            *Setup*)   show_setup_menu   || continue; break ;;
            *Install*) show_install_menu || continue; break ;;
            *Remove*)  show_remove_menu  || continue; break ;;
            *Update*)  show_update_menu  || continue; break ;;
            *System*)  show_system_menu  || continue; break ;;
            *)         break ;;
        esac
    done
}

# ===========================================================================
# ENTRY POINT — direct submenu access or full menu
# ===========================================================================

# Load user extension (can override any function above)
[[ -f "$USER_EXTENSION" ]] && source "$USER_EXTENSION"

if [[ -n "${1:-}" ]]; then
    case "${1,,}" in
        *screenshot*)    _screenshot_smart ;;
        *screenrecord*)  show_screenrecord_menu ;;
        *capture*)       show_capture_menu ;;
        *trigger*)       show_trigger_menu ;;
        *style*)         show_style_menu ;;
        *theme*)         show_theme_menu ;;
        *install*)       show_install_menu ;;
        *remove*)        show_remove_menu ;;
        *update*)        show_update_menu ;;
        *system*)        show_system_menu ;;
        *setup*)         show_setup_menu ;;
        *learn*)         show_learn_menu ;;
        *lock*)          _lock_screen ;;
        *toggle*)        show_toggle_menu ;;
        *ai*)            show_install_ai_menu ;;
        *gaming*)        show_install_gaming_menu ;;
        *)               show_main_menu ;;
    esac
else
    show_main_menu
fi
