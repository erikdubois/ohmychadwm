#!/usr/bin/env bash
# rename-theme.sh — rename a chadwm theme everywhere it is referenced
# Usage: rename-theme.sh <old-name> <new-name>

set -euo pipefail

THEMES_DIR="${HOME}/.config/ohmychadwm/chadwm/themes"
CONFIG="${HOME}/.config/ohmychadwm/chadwm/config.def.h"
WALLS_DIR="${HOME}/.config/ohmychadwm/wallpapers"

R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; W='\033[1;37m'; NC='\033[0m'
ok()  { echo -e "${G}✔ $*${NC}"; }
err() { echo -e "${R}✘ $*${NC}" >&2; exit 1; }
ask() { echo -e "${Y}$*${NC}"; }

OLD="${1:-}"
NEW="${2:-}"

if [[ -z "$OLD" || -z "$NEW" ]]; then
    echo -e "${W}Usage:${NC} rename-theme.sh <old-name> <new-name>"
    exit 1
fi

OLD="${OLD,,}"; OLD="${OLD// /_}"
NEW="${NEW,,}"; NEW="${NEW// /_}"

[[ "$OLD" == "$NEW" ]] && err "Old and new name are the same."

OLD_FILE="${THEMES_DIR}/${OLD}.h"
NEW_FILE="${THEMES_DIR}/${NEW}.h"

[[ -f "$OLD_FILE" ]] || err "Theme '${OLD}' not found at ${OLD_FILE}"
[[ -f "$NEW_FILE" ]] && err "Theme '${NEW}' already exists at ${NEW_FILE}"

echo -e "\n${W}Renaming theme '${OLD}' → '${NEW}'${NC}\n"

# ── rename the .h file ────────────────────────────────────────────────────────
mv "$OLD_FILE" "$NEW_FILE"
ok "Renamed ${OLD}.h → ${NEW}.h"

# ── update the comment header inside the .h file ─────────────────────────────
sed -i "s|/\* ${OLD^}|/* ${NEW^}|i" "$NEW_FILE"
ok "Updated header comment in ${NEW}.h"

# ── update config.def.h (include lines) ──────────────────────────────────────
if grep -q "themes/${OLD}\.h" "$CONFIG"; then
    sed -i "s|themes/${OLD}\.h|themes/${NEW}.h|g" "$CONFIG"
    ok "Updated include in config.def.h"
else
    echo -e "${Y}  (no include for '${OLD}' found in config.def.h — skipped)${NC}"
fi

# ── rename wallpaper if one exists ───────────────────────────────────────────
renamed_wp=0
for ext in jpg jpeg png webp; do
    old_wp="${WALLS_DIR}/${OLD}.${ext}"
    if [[ -f "$old_wp" ]]; then
        mv "$old_wp" "${WALLS_DIR}/${NEW}.${ext}"
        ok "Renamed wallpaper ${OLD}.${ext} → ${NEW}.${ext}"
        renamed_wp=1
        break
    fi
done
[[ $renamed_wp -eq 0 ]] && echo -e "${Y}  (no wallpaper found for '${OLD}' — skipped)${NC}"

echo -e "\n${G}Done.${NC} Theme renamed to '${NEW}'."
echo -e "  Rebuild with ${W}super+shift+r${NC} to apply.\n"
