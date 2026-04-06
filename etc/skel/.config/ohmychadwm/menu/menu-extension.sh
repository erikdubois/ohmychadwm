#!/usr/bin/env bash
# ~/.config/ohmychadwm/menu-extension.sh
#
# Drop this file in place and ohmychadwm-menu will source it automatically.
# You can:
#   - Override any existing function (your version replaces the built-in one)
#   - Add new functions and call them from overridden menus
#   - Use all the built-in helpers: menu(), present_terminal(), install(),
#     aur_install(), edit_in_editor(), go_back(), notify-send, etc.
#
# This example adds:
#   1. An override of show_system_menu to add a Relaunch ohmychadwm option

# ---------------------------------------------------------------------------
# Override the System menu to add a Relaunch ohmychadwm option
# ---------------------------------------------------------------------------
show_system_menu() {
    local options=" Lock\n Suspend\n Logout\n Restart\n Shutdown"

    # if swapon --show | grep -q partition 2>/dev/null || \
    #    swapon --show | grep -q file      2>/dev/null; then
    #     options+=" \n Hibernate"
    # fi

    case $(menu "System" "$options") in
        *Lock*)      _lock_screen ;;
        *Suspend*)   systemctl suspend ;;
        *Hibernate*) systemctl hibernate ;;
        *Logout*)    _logout_chadwm ;;
        *Restart*)   systemctl reboot ;;
        *Shutdown*)  systemctl poweroff ;;
        *)           return 1 ;;
    esac
}

_logout_chadwm() {
    # run.sh loop breaks when ohmychadwm exits with failure (quitting=1)
    # shutdown_ohmychadwm.sh sends SIGTERM which triggers the clean quit path
    local script="${HOME}/.config/ohmychadwm/scripts/shutdown_ohmychadwm.sh"
    if [[ ! -f "$script" ]]; then
        notify-send -u critical "ohmychadwm" "shutdown script not found: $script"
        return 1
    fi
    bash "$script"
}
