#!/usr/bin/env bash
# =============================================================================
# ohmychadwm-menu — hierarchical system menu for ohmychadwm / X11
# Inspired by omarchy-menu (basecamp/omarchy), ported from Wayland to X11.
#
# Dependencies:
#   rofi          — menu renderer  (pacman -S rofi)
#   dunst         — notifications  (pacman -S dunst)
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
        return
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
        case $(menu "Style" " Theme\n Font\n Wallpaper\n Colours (Xresources)\n Picom / compositor") in
            *Theme*)       show_theme_menu    || continue; return 0 ;;
            *Font*)        show_font_menu     || continue; return 0 ;;
            *Wallpaper*)   show_wallpaper_menu || continue; return 0 ;;
            *"Colours"*)   edit_in_editor "${HOME}/.Xresources"; return 0 ;;
            *"Picom"*)     edit_in_editor "${HOME}/.config/ohmychadwm/picom/picom.conf"; return 0 ;;
            *)             return 1 ;;
        esac
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
    local chosen
    chosen=$(menu "Theme" "$theme_list") || return 1
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
    # Save selection
    echo "$font" > "${OHMYCHADWM_CONFIG}/chadwm/current-font"
    # Update fonts[] in config.def.h
    sed -i "s|static const char \*fonts\[\].*|static const char *fonts[] = {\"${font}:style:bold:size=13\"};|" "$config"
    # Apply to alacritty if used
    local alacritty_conf="${HOME}/.config/alacritty/alacritty.toml"
    if [[ -f "$alacritty_conf" ]]; then
        sed -i "s/family = .*/family = \"${font}\"/" "$alacritty_conf"
    fi
    # Rebuild chadwm
    (cd "${OHMYCHADWM_CONFIG}/chadwm" && bash rebuildlocal.sh)
    notify-send "ohmychadwm" "Font set to '${font}' — reboot your system"
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
        local options=" Autostart\n Picom\n Dunst\n Rofi\n Alacritty\n Defaults"

        # Show Xresources option only if the file exists
        [[ -f "${HOME}/.Xresources" ]] && options+=" \n Xresources"

        case $(menu "Setup" "$options") in
            *Autostart*)    edit_in_editor "${OHMYCHADWM_CONFIG}/scripts/run.sh"; return 0 ;;
            *Picom*)        edit_in_editor "${HOME}/.config/ohmychadwm/picom/picom.conf" && _restart_picom; return 0 ;;
            *Dunst*)        edit_in_editor "${HOME}/.config/ohmychadwm/dunst/dunstrc"    && _restart_dunst; return 0 ;;
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
show_install_menu() {
    while true; do
        case $(menu "Install" "Package\n Aur package\n Terminal\n Editor\n Browser\n Dev environment\n Ai tools\n Gaming\n Fonts\n Extras") in
            *"Package"*)  present_terminal 'pacman -Slq | fzf --multi --preview "pacman -Si {}" | xargs -ro sudo pacman -S --needed'; return 0 ;;
            *"AUR"*)      present_terminal 'yay -Slq | fzf --multi --preview "yay -Si {}" | xargs -ro yay -S'; return 0 ;;
            *Terminal*)   show_install_terminal_menu || continue; return 0 ;;
            *Editor*)     show_install_editor_menu   || continue; return 0 ;;
            *Browser*)    show_install_browser_menu  || continue; return 0 ;;
            *"Dev"*)      show_install_dev_menu      || continue; return 0 ;;
            *AI*)         show_install_ai_menu       || continue; return 0 ;;
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
        *"Claude Code"*)   present_terminal "npm install -g @anthropic-ai/claude-code && echo 'Done. Run: claude'" ;;
        *Ollama*)          install "Ollama" "$ollama_pkg" && \
                           present_terminal "sudo systemctl enable --now ollama && echo 'Ollama running. Try: ollama run llama3'" ;;
        *OpenCode*)        present_terminal "npm install -g opencode-ai && echo 'Done. Run: opencode'" ;;
        *Copilot*)         present_terminal "nvim --headless '+Lazy install copilot.vim' +q && echo 'Copilot plugin installed'" ;;
        *)                 return 1 ;;
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
        case $(menu "Remove" " Package\n Dev environment\n Theme\n Autostart entry") in
            *Package*)   present_terminal 'pacman -Qq | fzf --multi --preview "pacman -Qi {}" | xargs -ro sudo pacman -Rns'; return 0 ;;
            *"Dev"*)     show_remove_dev_menu   || continue; return 0 ;;
            *Theme*)     show_remove_theme_menu || continue; return 0 ;;
            *Autostart*) edit_in_editor "${OHMYCHADWM_CONFIG}/scripts/run.sh"; return 0 ;;
            *)           return 1 ;;
        esac
    done
}

show_remove_dev_menu() {
    case $(menu "Remove dev env" " Node.js\n Ruby\n Python\n Go\n Rust\n Docker") in
        *Node*)   present_terminal "mise uninstall node && echo Done" ;;
        *Ruby*)   present_terminal "mise uninstall ruby && echo Done" ;;
        *Python*) present_terminal "mise uninstall python && echo Done" ;;
        *Go*)     remove_pkg "Go" "go" ;;
        *Rust*)   present_terminal "rustup self uninstall" ;;
        *Docker*) remove_pkg "Docker" "docker docker-compose" ;;
        *)        return 1 ;;
    esac
}

show_remove_theme_menu() {
    local themes_dir="${OHMYCHADWM_CONFIG}/themes"
    local theme_list
    theme_list=$(ls -1 "$themes_dir" 2>/dev/null)
    [[ -z "$theme_list" ]] && { notify-send "ohmychadwm" "No themes to remove"; return 1; }
    local chosen
    chosen=$(echo "$theme_list" | rofi -dmenu -p "Remove theme…" -width "$MENU_WIDTH" 2>/dev/null) || return 1
    rm -rf "${themes_dir}/${chosen}" && notify-send "ohmychadwm" "Theme '${chosen}' removed"
}

# ---------------------------------------------------------------------------
# Update
# ---------------------------------------------------------------------------
show_update_menu() {
    while true; do
        case $(menu "Update" "System packages\n AUR packages\n Full update\n Restart process\n Hardware\n Timezone\n Time sync") in
            *"System"*)    present_terminal "sudo pacman -Syu"; return 0 ;;
            *"AUR"*)       present_terminal "yay -Sua"; return 0 ;;
            *"Full"*)      present_terminal "yay -Syu"; return 0 ;;
            *"Restart"*)   show_restart_process_menu  || continue; return 0 ;;
            *Hardware*)    show_restart_hardware_menu || continue; return 0 ;;
            *Timezone*)    present_terminal "tzselect && echo 'Run: sudo timedatectl set-timezone <zone>'"; return 0 ;;
            *"Time sync"*) present_terminal "sudo timedatectl set-ntp true && timedatectl status"; return 0 ;;
            *)             return 1 ;;
        esac
    done
}

show_restart_process_menu() {
    case $(menu "Restart process" " Picom\n Dunst\n Sxhkd") in
        *Picom*)      _restart_picom ;;
        *Dunst*)      _restart_dunst ;;
        *Sxhkd*)      pkill sxhkd; setsid sxhkd &>/dev/null & disown; notify-send "ohmychadwm" "Sxhkd restarted" ;;
        *)            return 1 ;;
    esac
}

show_restart_hardware_menu() {
    case $(menu "Restart hardware" "Audio (PipeWire)\n WiFi\n Bluetooth") in
        *Audio*)     _restart_pipewire ;;
        *WiFi*)      present_terminal "sudo systemctl restart NetworkManager && echo Done" ;;
        *Bluetooth*) present_terminal "sudo systemctl restart bluetooth && echo Done" ;;
        *)           return 1 ;;
    esac
}

_restart_picom() {
    pkill picom 2>/dev/null
    setsid picom --config "${HOME}/.config/ohmychadwm/picom/picom.conf" -b &>/dev/null &
    disown
    notify-send "ohmychadwm" "Picom restarted"
}

_restart_dunst() {
    pkill dunst 2>/dev/null
    setsid dunst &>/dev/null &
    disown
    notify-send "ohmychadwm" "Dunst restarted"
}

_restart_pipewire() {
    systemctl --user restart pipewire pipewire-pulse wireplumber
    notify-send "ohmychadwm" "PipeWire restarted"
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
        case $(menu "ohmychadwm" " Apps\n Learn\n Trigger\n Style\n Setup\n Install\n Remove\n Update\n System") in
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
