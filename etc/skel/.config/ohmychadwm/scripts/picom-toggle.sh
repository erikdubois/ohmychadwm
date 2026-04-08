#!/bin/bash

CONFIG_DIR="$HOME/.config/ohmychadwm/picom"

if pgrep -x "picom" > /dev/null; then
    notify-send "Picom" "Stopping picom..."
    killall picom
    exit 0
fi

# kill fastcompmgr if running before starting picom
if pgrep -x "fastcompmgr" > /dev/null; then
    killall fastcompmgr
    sleep 0.3
fi

# Get list of .conf files (basename only)
options=$(basename -a "$CONFIG_DIR"/*.conf)

# Use rofi to prompt the user
chosen=$(echo "$options" | rofi -dmenu -p "Choose picom config:")

if [[ -n "$chosen" && -f "$CONFIG_DIR/$chosen" ]]; then
    notify-send "Picom" "Starting picom with: $chosen"
    picom -b --config "$CONFIG_DIR/$chosen" &
else
    notify-send "Picom" "No valid selection made."
fi
