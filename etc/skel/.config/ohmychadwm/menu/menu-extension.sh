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
    local options=" Lock\n Suspend\n Relaunch ohmychadwm\n Restart\n Shutdown"

    # if swapon --show | grep -q partition 2>/dev/null || \
    #    swapon --show | grep -q file      2>/dev/null; then
    #     options+=" \n Hibernate"
    # fi

    case $(menu "System" "$options") in
        *Lock*)      _lock_screen ;;
        *Suspend*)   systemctl suspend ;;
        *Hibernate*) systemctl hibernate ;;
        *"Relaunch"*) _relaunch_chadwm ;;
        *Restart*)   systemctl reboot ;;
        *Shutdown*)  systemctl poweroff ;;
        *)           return 1 ;;
    esac
}

_relaunch_chadwm() {
    # Sends ohmychadwm a restart signal — adjust if your setup differs
    pkill -USR1 ohmychadwm 2>/dev/null || \
        notify-send -u critical "ohmychadwm" "Could not signal ohmychadwm to restart"
}
