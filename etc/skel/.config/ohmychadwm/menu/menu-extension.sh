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
#   1. A VPN section bolted onto the Install menu
#   2. A custom NAS mount section in Trigger
#   3. An override of show_system_menu to add a Relaunch ohmychadwm option

# ---------------------------------------------------------------------------
# Example 1: add a VPN submenu
# ---------------------------------------------------------------------------
show_vpn_menu() {
    case $(menu "VPN" "󰖂 Mullvad connect\n Mullvad disconnect\n OpenVPN config\n WireGuard status") in
        *"connect"*)    setsid mullvad connect &>/dev/null & disown ;;
        *"disconnect"*) setsid mullvad disconnect &>/dev/null & disown ;;
        *OpenVPN*)      present_terminal "ls /etc/openvpn/*.conf | fzf | xargs -ro sudo openvpn --config" ;;
        *WireGuard*)    present_terminal "sudo wg show; read -n1" ;;
        *)              return 1 ;;
    esac
}

# ---------------------------------------------------------------------------
# Example 2: override the Trigger menu to bolt on NAS and VPN entries
# ---------------------------------------------------------------------------
show_trigger_menu() {
    while true; do
        case $(menu "Trigger" " Capture\n Share\n Toggle\n VPN\n NAS") in
            *Capture*) show_capture_menu || continue; return 0 ;;
            *Share*)   show_share_menu   || continue; return 0 ;;
            *Toggle*)  show_toggle_menu  || continue; return 0 ;;
            *VPN*)     show_vpn_menu     || continue; return 0 ;;
            *NAS*)     show_nas_menu     || continue; return 0 ;;
            *)         return 1 ;;
        esac
    done
}

show_nas_menu() {
    case $(menu "NAS" "󰒋 Mount NAS\n Unmount NAS\n Open /mnt") in
        *"Mount"*)   present_terminal "sudo mount /mnt/nas && echo 'Mounted'" ;;
        *"Unmount"*) present_terminal "sudo umount /mnt/nas && echo 'Unmounted'" ;;
        *"/mnt"*)    setsid thunar /mnt &>/dev/null & disown ;;
        *)           return 1 ;;
    esac
}

# ---------------------------------------------------------------------------
# Example 3: override the System menu to add a Relaunch ohmychadwm option
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
