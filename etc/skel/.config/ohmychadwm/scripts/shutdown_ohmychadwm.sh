#!/bin/sh

# Optional: Define a pattern for bar.sh that should work across users.
# You can keep both patterns to maximize coverage.
SCRIPT_PATH_PATTERN="/.*bar\.sh$"  # loose: matches any bar.sh in cmd line
DASH_INV_PATTERN="/bin/dash .*bar\.sh$"

# Kill the main components
pkill -x chadwm
# Prefer the exact dash invocation if possible, then fallback to generic bar.sh
pkill -f "$DASH_INV_PATTERN" 2>/dev/null || true
pkill -f "$SCRIPT_PATH_PATTERN" 2>/dev/null || true
pkill picom
pkill sxhkd

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
wait_until_gone chadwm
wait_until_gone "$SCRIPT_PATH_PATTERN"   # matches any bar.sh candidate

# If still present, try explicit PIDs for the most stubborn cases
for pattern in "$DASH_INV_PATTERN" "$SCRIPT_PATH_PATTERN"; do
    pids=$(pgrep -f "$pattern" 2>/dev/null)
    [ -n "$pids" ] && {
        for pid in $pids; do
            kill -TERM "$pid" 2>/dev/null || true
        done
        sleep 0.2
        # Force kill remaining
        for pid in $pids; do
            if ps -p "$pid" >/dev/null 2>&1; then
                kill -KILL "$pid" 2>/dev/null || true
            fi
        done
    }
done

wait_until_gone picom
wait_until_gone sxhkd