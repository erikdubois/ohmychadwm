#!/usr/bin/env bash
# =============================================================================
# setup-screens.sh — guided monitor layout wizard for ohmychadwm
#
# Detects connected outputs with xrandr and walks the user through building
# a layout: which display is primary, which resolution, and which is to the
# left/right/above/below of which. The result is written to
#   ~/.screenlayout/<username>.sh
# which is exactly the file run.sh sources on session start (see run.sh:31).
#
# An "Open arandr" escape hatch is offered so users can fall back to the
# visual editor for unusual setups. arandr also saves to ~/.screenlayout/,
# so this script can rename/copy its output to the expected filename.
#
# Run from a terminal:
#   bash ~/.config/ohmychadwm/scripts/setup-screens.sh
# =============================================================================

set -u

# ── colors (only if stdout is a tty) ─────────────────────────────────────────
if [ -t 1 ]; then
    BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'
    GRN=$'\033[32m'; YLW=$'\033[33m'; BLU=$'\033[34m'; RST=$'\033[0m'
else
    BOLD=""; DIM=""; RED=""; GRN=""; YLW=""; BLU=""; RST=""
fi

say()  { printf '%s\n' "$*"; }
info() { printf '%b%s%b\n' "$BLU" "$*" "$RST"; }
ok()   { printf '%b%s%b\n' "$GRN" "$*" "$RST"; }
warn() { printf '%b%s%b\n' "$YLW" "$*" "$RST"; }
err()  { printf '%b%s%b\n' "$RED" "$*" "$RST" >&2; }
hr()   { printf '%b%s%b\n' "$DIM" "────────────────────────────────────────────────────────────" "$RST"; }

# ── prerequisites ────────────────────────────────────────────────────────────
command -v xrandr >/dev/null 2>&1 || { err "xrandr is not installed."; exit 1; }

LAYOUT_DIR="$HOME/.screenlayout"
LAYOUT_FILE="$LAYOUT_DIR/$(whoami).sh"
mkdir -p "$LAYOUT_DIR"

# ── parse xrandr ─────────────────────────────────────────────────────────────
# Build two parallel arrays:
#   OUTPUTS[i]   = output name   (e.g. HDMI-1, DP-2, eDP-1)
#   PREF_MODE[i] = preferred mode "WxH"  (the one xrandr marks with '+')
declare -a OUTPUTS PREF_MODE

current_out=""
while IFS= read -r line; do
    if [[ "$line" =~ ^([A-Za-z0-9_-]+)\ connected ]]; then
        current_out="${BASH_REMATCH[1]}"
        OUTPUTS+=("$current_out")
        PREF_MODE+=("")
    elif [[ -n "$current_out" && "$line" =~ ^[[:space:]]+([0-9]+x[0-9]+) ]]; then
        # First mode listed is the preferred one; only capture if not yet set.
        idx=$(( ${#PREF_MODE[@]} - 1 ))
        if [[ -z "${PREF_MODE[$idx]}" ]]; then
            PREF_MODE[$idx]="${BASH_REMATCH[1]}"
        fi
    elif [[ "$line" =~ ^[A-Za-z] ]]; then
        # New output header that isn't "connected" — stop accumulating modes.
        current_out=""
    fi
done < <(xrandr --query)

N=${#OUTPUTS[@]}

hr
info "${BOLD}ohmychadwm — screen setup wizard${RST}"
hr

if [ "$N" -eq 0 ]; then
    err "No connected displays detected. Plug them in and re-run."
    exit 1
fi

say "Detected ${BOLD}$N${RST} connected display(s):"
for i in "${!OUTPUTS[@]}"; do
    printf '  %s[%d]%s  %-12s  preferred: %s\n' \
        "$BOLD" "$((i+1))" "$RST" "${OUTPUTS[$i]}" "${PREF_MODE[$i]:-?}"
done
echo

# ── top-level menu ───────────────────────────────────────────────────────────
say "How would you like to set up your screens?"
say "  ${BOLD}1${RST}) Guided — answer a few questions (recommended)"
say "  ${BOLD}2${RST}) Open arandr (visual editor) and save the layout"
say "  ${BOLD}3${RST}) Quick: just use each display's preferred mode, side by side"
say "  ${BOLD}4${RST}) Show current xrandr state and exit"
say "  ${BOLD}q${RST}) Quit"
echo
read -r -p "Choice [1]: " CHOICE
CHOICE="${CHOICE:-1}"

# ── helpers ──────────────────────────────────────────────────────────────────
prompt_index() {
    # $1 = prompt; $2 = default index (1-based) or empty
    local prompt="$1" def="${2:-}" reply
    while true; do
        if [ -n "$def" ]; then
            read -r -p "$prompt [$def]: " reply
            reply="${reply:-$def}"
        else
            read -r -p "$prompt: " reply
        fi
        if [[ "$reply" =~ ^[0-9]+$ ]] && (( reply >= 1 && reply <= N )); then
            echo "$((reply-1))"
            return 0
        fi
        warn "Enter a number between 1 and $N."
    done
}

list_modes_for() {
    # Print modes for a given output, one per line.
    local out="$1"
    xrandr --query | awk -v o="$out" '
        $1==o && $2=="connected" {grab=1; next}
        grab && /^[A-Za-z]/ {grab=0}
        grab && /^[ \t]+[0-9]+x[0-9]+/ {print $1}
    '
}

choose_mode() {
    # $1 = output name; echoes chosen mode "WxH"
    local out="$1"
    mapfile -t modes < <(list_modes_for "$out")
    if [ "${#modes[@]}" -eq 0 ]; then
        echo ""
        return
    fi
    echo "    Modes for ${BOLD}$out${RST} (first is preferred):" >&2
    local i
    for i in "${!modes[@]}"; do
        printf '      %s[%d]%s %s\n' "$BOLD" "$((i+1))" "$RST" "${modes[$i]}" >&2
    done
    local reply
    while true; do
        read -r -p "    Mode for $out [1 = ${modes[0]}]: " reply
        reply="${reply:-1}"
        if [[ "$reply" =~ ^[0-9]+$ ]] && (( reply >= 1 && reply <= ${#modes[@]} )); then
            echo "${modes[$((reply-1))]}"
            return
        fi
        warn "    Enter a number between 1 and ${#modes[@]}."
    done
}

# ── option 4: show state ────────────────────────────────────────────────────
if [[ "$CHOICE" == "4" ]]; then
    hr; xrandr --query; hr
    exit 0
fi

# ── option q: quit ──────────────────────────────────────────────────────────
if [[ "$CHOICE" == "q" || "$CHOICE" == "Q" ]]; then
    exit 0
fi

# ── option 2: arandr ────────────────────────────────────────────────────────
if [[ "$CHOICE" == "2" ]]; then
    command -v arandr >/dev/null 2>&1 || { err "arandr is not installed."; exit 1; }
    info "Launching arandr. Inside it: arrange your screens, then Layout → Save As…"
    info "Save into:  $LAYOUT_DIR/"
    info "After you close arandr, this script will list saved layouts so you can pick one."
    arandr || true
    echo
    mapfile -t saved < <(find "$LAYOUT_DIR" -maxdepth 1 -type f -name '*.sh' -printf '%f\n' | sort)
    if [ "${#saved[@]}" -eq 0 ]; then
        warn "No layouts found in $LAYOUT_DIR."
        exit 1
    fi
    say "Saved layouts:"
    for i in "${!saved[@]}"; do
        printf '  %s[%d]%s %s\n' "$BOLD" "$((i+1))" "$RST" "${saved[$i]}"
    done
    while true; do
        read -r -p "Which one should ohmychadwm use on login? [1]: " reply
        reply="${reply:-1}"
        if [[ "$reply" =~ ^[0-9]+$ ]] && (( reply >= 1 && reply <= ${#saved[@]} )); then
            chosen="${saved[$((reply-1))]}"
            break
        fi
        warn "Enter a number between 1 and ${#saved[@]}."
    done
    if [[ "$chosen" != "$(basename "$LAYOUT_FILE")" ]]; then
        cp -f "$LAYOUT_DIR/$chosen" "$LAYOUT_FILE"
        chmod +x "$LAYOUT_FILE"
    fi
    ok "Active layout for this user: $LAYOUT_FILE"
    say  "  (run.sh sources this on session start.)"
    exit 0
fi

# ── option 3: quick auto layout ─────────────────────────────────────────────
if [[ "$CHOICE" == "3" ]]; then
    # Primary = first connected output; the rest are placed --right-of the previous.
    primary="${OUTPUTS[0]}"
    cmd=(xrandr)
    prev=""
    for i in "${!OUTPUTS[@]}"; do
        out="${OUTPUTS[$i]}"
        mode="${PREF_MODE[$i]:-}"
        cmd+=(--output "$out")
        [ -n "$mode" ] && cmd+=(--mode "$mode")
        cmd+=(--rotate normal)
        if [[ "$out" == "$primary" ]]; then
            cmd+=(--primary --pos 0x0)
        else
            cmd+=(--right-of "$prev")
        fi
        prev="$out"
    done
fi

# ── option 1: guided ────────────────────────────────────────────────────────
if [[ "$CHOICE" == "1" ]]; then
    hr
    say "${BOLD}Step 1 — primary display${RST}"
    say "The primary display is where bars, notifications and most apps will open."
    idx_primary=$(prompt_index "Which number is primary?" "1")
    primary="${OUTPUTS[$idx_primary]}"

    # Per-output settings.
    declare -a USE_OUT USE_MODE USE_REL USE_REF
    USE_OUT[$idx_primary]="$primary"
    hr
    say "${BOLD}Step 2 — resolution for $primary${RST}  (primary, anchored at 0x0)"
    USE_MODE[$idx_primary]=$(choose_mode "$primary")
    USE_REL[$idx_primary]="primary"
    USE_REF[$idx_primary]=""

    # placed: indices already positioned, in placement order, starting with primary.
    placed=("$idx_primary")

    # Walk through the remaining displays.
    for j in "${!OUTPUTS[@]}"; do
        [[ "$j" == "$idx_primary" ]] && continue
        out="${OUTPUTS[$j]}"
        hr
        say "${BOLD}Display $out${RST}"
        echo
        say "  Include this display? (y = configure it, n = disable / turn off)"
        read -r -p "  [y]: " yn
        yn="${yn:-y}"
        if [[ "$yn" =~ ^[Nn] ]]; then
            USE_OUT[$j]="$out"
            USE_MODE[$j]="OFF"
            continue
        fi

        # Pick a reference: one of the already-placed displays.
        say "  Place $out relative to which already-placed display?"
        for k in "${!placed[@]}"; do
            pi="${placed[$k]}"
            printf '    %s[%d]%s %s\n' "$BOLD" "$((k+1))" "$RST" "${OUTPUTS[$pi]}"
        done
        while true; do
            read -r -p "  Reference [1]: " r
            r="${r:-1}"
            if [[ "$r" =~ ^[0-9]+$ ]] && (( r >= 1 && r <= ${#placed[@]} )); then
                ref_idx="${placed[$((r-1))]}"
                break
            fi
            warn "  Enter a number between 1 and ${#placed[@]}."
        done

        say "  Position of $out relative to ${OUTPUTS[$ref_idx]}:"
        say "    ${BOLD}1${RST}) left-of    ${BOLD}2${RST}) right-of    ${BOLD}3${RST}) above    ${BOLD}4${RST}) below    ${BOLD}5${RST}) same-as (mirror)"
        while true; do
            read -r -p "  Position [2]: " p
            p="${p:-2}"
            case "$p" in
                1) rel="--left-of";  break;;
                2) rel="--right-of"; break;;
                3) rel="--above";    break;;
                4) rel="--below";    break;;
                5) rel="--same-as";  break;;
                *) warn "  Pick 1-5.";;
            esac
        done

        USE_OUT[$j]="$out"
        USE_MODE[$j]=$(choose_mode "$out")
        USE_REL[$j]="$rel"
        USE_REF[$j]="${OUTPUTS[$ref_idx]}"
        placed+=("$j")
    done

    # Build the xrandr command.
    cmd=(xrandr)
    for j in "${!OUTPUTS[@]}"; do
        out="${OUTPUTS[$j]}"
        mode="${USE_MODE[$j]:-}"
        rel="${USE_REL[$j]:-}"
        ref="${USE_REF[$j]:-}"

        if [[ "$mode" == "OFF" ]]; then
            cmd+=(--output "$out" --off)
            continue
        fi

        cmd+=(--output "$out")
        [ -n "$mode" ] && cmd+=(--mode "$mode")
        cmd+=(--rotate normal)
        if [[ "$rel" == "primary" ]]; then
            cmd+=(--primary --pos 0x0)
        elif [[ -n "$rel" && -n "$ref" ]]; then
            cmd+=("$rel" "$ref")
        fi
    done
fi

# ── preview & confirm ───────────────────────────────────────────────────────
hr
say "${BOLD}Proposed xrandr command:${RST}"
say ""
# Pretty-print: break before each --output for readability.
{
    printf '%s' "${cmd[0]}"
    for ((i=1; i<${#cmd[@]}; i++)); do
        if [[ "${cmd[$i]}" == "--output" ]]; then
            printf ' \\\n    --output'
        else
            printf ' %q' "${cmd[$i]}"
        fi
    done
    printf '\n'
}
echo
say "Options:"
say "  ${BOLD}t${RST}) Test it now (15-second revert if you don't confirm)"
say "  ${BOLD}s${RST}) Save to $LAYOUT_FILE without testing"
say "  ${BOLD}b${RST}) Save AND apply now"
say "  ${BOLD}q${RST}) Quit without saving"
read -r -p "Choice [t]: " ACT
ACT="${ACT:-t}"

save_layout() {
    {
        printf '#!/bin/sh\n'
        printf '# Generated by setup-screens.sh on %s\n' "$(date -Iseconds)"
        printf '%s' "${cmd[0]}"
        for ((i=1; i<${#cmd[@]}; i++)); do
            if [[ "${cmd[$i]}" == "--output" ]]; then
                printf ' \\\n    --output'
            else
                printf ' %q' "${cmd[$i]}"
            fi
        done
        printf '\n'
    } > "$LAYOUT_FILE"
    chmod +x "$LAYOUT_FILE"
    ok "Saved: $LAYOUT_FILE"
    say  "  (run.sh sources this on session start — see line 31 of run.sh.)"
}

apply_now() { "${cmd[@]}"; }

case "$ACT" in
    t|T)
        # Capture current state so we can revert.
        before=$(xrandr --query)
        if ! apply_now; then
            err "xrandr failed — not saving."
            exit 1
        fi
        say ""
        warn "Layout applied. You have 15 seconds to confirm with [y] — otherwise it reverts."
        read -r -t 15 -p "Keep this layout? [y/N]: " keep || keep=""
        if [[ "$keep" =~ ^[Yy] ]]; then
            save_layout
        else
            warn "Reverting…"
            # Best-effort revert: turn every output off, then re-run xrandr with each
            # output set to whatever it had before (auto-mode for connected ones).
            for o in "${OUTPUTS[@]}"; do xrandr --output "$o" --off 2>/dev/null || true; done
            for o in "${OUTPUTS[@]}"; do
                if grep -qE "^$o connected" <<<"$before"; then
                    xrandr --output "$o" --auto 2>/dev/null || true
                fi
            done
            warn "Reverted (best-effort). Re-run if anything looks off."
        fi
        ;;
    s|S) save_layout ;;
    b|B) save_layout && apply_now ;;
    q|Q) say "No changes saved."; exit 0 ;;
    *)   warn "Unknown choice — nothing saved."; exit 1 ;;
esac
