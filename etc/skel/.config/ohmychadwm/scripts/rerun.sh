#!/bin/sh


# Kill processes
pkill -x chadwm
pkill -f bar.sh
pkill picom
pkill sxhkd

# Function to wait until a process is gone
wait_until_gone() {
    local name="$1"
    while pgrep -f "$name" > /dev/null; do
        sleep 0.1
    done
}

# Wait for full cleanup
wait_until_gone chadwm
wait_until_gone bar.sh
wait_until_gone picom
wait_until_gone sxhkd

# Restart components
~/.config/ohmychadwm/scripts/bar.sh &
picom -b  --config ~/.config/ohmychadwm/picom/picom.conf &
# picom -b  --config ~/.config/ohmychadwm/picom/picom-cachyos.conf &
# picom -b  --config ~/.config/ohmychadwm/picom/picom-edu-dwm.conf &
# picom -b  --config ~/.config/ohmychadwm/picom/picom-edu-nodwm.conf &
# picom -b  --config ~/.config/ohmychadwm/picom/picom-original.conf &
# picom --backend glx --vsync &
#fastcompmgr -c &
sxhkd -c ~/.config/ohmychadwm/sxhkd/sxhkdrc &

LOCAL_CHADWM="$HOME/.local/bin/chadwm"
SYSTEM_CHADWM="/usr/bin/chadwm"

if [ -x "$LOCAL_CHADWM" ]; then
    exec "$LOCAL_CHADWM"
elif [ -x "$SYSTEM_CHADWM" ]; then
    exec "$SYSTEM_CHADWM"
else
    echo "Error: chadwm not found in ~/.local/bin or /usr/bin"
    exit 1
fi