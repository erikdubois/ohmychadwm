#!/bin/sh

# Optional: Define a pattern for bar.sh that should work across users.
# You can keep both patterns to maximize coverage.
SCRIPT_PATH_PATTERN="/.*bar\.sh$"  # loose: matches any bar.sh in cmd line
DASH_INV_PATTERN="/bin/dash .*bar\.sh$"

# Kill the main components
pkill ohmychadwm
pkill picom
pkill sxhkd

sleep 1

# Helper: wait for a given process-like string to disappear, with timeout
wait_until_gone() {
    local name="$1"
    local limit=50      # max iterations
    local i=0
    while pgrep -f "$name" >/dev/null 2>&1; do
        [ "$i" -ge "$limit" ] && break
        sleep 0.1
        i=$((i + 1))
    done
}

# Wait for the known targets to disappear
wait_until_gone ohmychadwm
wait_until_gone picom
wait_until_gone sxhkd