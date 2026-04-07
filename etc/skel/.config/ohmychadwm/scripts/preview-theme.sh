#!/usr/bin/env bash
# preview-theme.sh <theme-name>
# Prints an ANSI truecolor palette preview for use as an fzf preview pane.

THEMES_DIR="$HOME/.config/ohmychadwm/chadwm/themes"
theme="$1"
file="$THEMES_DIR/${theme}.h"

[[ -f "$file" ]] || { echo "Theme file not found: $file"; exit 1; }

# ── helpers ──────────────────────────────────────────────────────────────────
extract() { grep -oP "${1}\[\]\s*=\s*\"\K[^\"]+" "$file" | head -1; }

block() {
    local hex="${1#'#'}"
    [[ ${#hex} -eq 6 ]] || return
    local r=$((16#${hex:0:2})) g=$((16#${hex:2:2})) b=$((16#${hex:4:2}))
    printf '\e[48;2;%d;%d;%dm  \e[0m' "$r" "$g" "$b"
}

swatch() {
    local hex="$1" label="$2"
    local h="${hex#'#'}"
    [[ ${#h} -eq 6 ]] || return
    local r=$((16#${h:0:2})) g=$((16#${h:2:2})) b=$((16#${h:4:2}))
    printf '\e[48;2;%d;%d;%dm    \e[0m \e[38;2;%d;%d;%dm%-8s\e[0m  %s\n' \
        "$r" "$g" "$b" "$r" "$g" "$b" "$hex" "$label"
}

# ── extract colors ────────────────────────────────────────────────────────────
BG=$(extract "SchemeNormbg")
BR=$(extract "SchemeNormbr")
DIM=$(extract "SchemeNormfg")
ACCENT=$(extract "SchemeSelbg")
TITLE=$(extract "SchemeTitlefg")
MENU=$(extract "SchemeMenufg")

T1=$(extract "SchemeTag1fg");  T2=$(extract "SchemeTag2fg")
T3=$(extract "SchemeTag3fg");  T4=$(extract "SchemeTag4fg")
T5=$(extract "SchemeTag5fg");  T6=$(extract "SchemeTag6fg")
T7=$(extract "SchemeTag7fg");  T8=$(extract "SchemeTag8fg")
T9=$(extract "SchemeTag9fg");  T10=$(extract "SchemeTag10fg")

FONT=$(grep -oP '#define THEME_FONT\s+"\K[^"]+' "$file" | head -1)
SIZE=$(grep -oP '#define THEME_FONTSIZE\s+\K[0-9]+' "$file" | head -1)

# ── render ────────────────────────────────────────────────────────────────────
echo
printf '  \e[1m%s\e[0m\n' "$theme"
[[ -n "$FONT" ]] && printf '  %s  %s\n' "$FONT" "${SIZE}pt"
echo

swatch "$BG"     "background"
swatch "$BR"     "border"
swatch "$DIM"    "inactive"
swatch "$ACCENT" "selection"
swatch "$TITLE"  "title"
swatch "$MENU"   "menu fg"
echo

printf '  tags  '
for t in "$T1" "$T2" "$T3" "$T4" "$T5" "$T6" "$T7" "$T8" "$T9" "$T10"; do
    [[ -n "$t" ]] && block "$t"
done
echo
echo
