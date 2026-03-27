#!/usr/bin/env bash

set -euo pipefail

CONFIG="$HOME/.config/ohmychadwm/chadwm/config.def.h"

themes=(
  "catppuccin"
  "dracula"
  "everforest"
  "gruvchad"
  "nord"
  "onedark"
  "prime"
  "tokyonight"
  "tundra"
)

chosen="$(printf '%s\n' "${themes[@]}" | rofi -dmenu -i -p "Theme")"
[ -z "${chosen:-}" ] && exit 0

tmp="$(mktemp)"

awk -v selected="$chosen" '
{
    if ($0 ~ /^\/\/#include "themes\/.*\.h"$/ || $0 ~ /^#include "themes\/.*\.h"$/) {
        if ($0 ~ "themes/" selected ".h\"") {
            sub(/^\/\//, "", $0)
        } else {
            if ($0 !~ /^\/\//) {
                $0 = "//" $0
            }
        }
    }
    print
}
' "$CONFIG" > "$tmp"

mv "$tmp" "$CONFIG"

cd ~/.config/ohmychadwm/chadwm/
./rebuild.sh

# reload chadwm
xdotool key super+shift+r