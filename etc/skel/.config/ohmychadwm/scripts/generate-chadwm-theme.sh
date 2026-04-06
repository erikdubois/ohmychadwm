#!/usr/bin/env bash
# generate-chadwm-theme.sh
# Create a chadwm theme from the current wallpaper colors.

set -euo pipefail

THEMES_DIR="$HOME/.config/ohmychadwm/chadwm/themes"
CONFIG="$HOME/.config/ohmychadwm/chadwm/config.def.h"

# ── terminal colors ──────────────────────────────────────────────────────────
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'
B='\033[0;34m'; C='\033[0;36m'; W='\033[1;37m'; NC='\033[0m'

header() { echo -e "\n${C}${W}$*${NC}"; }
ask()    { echo -e "${Y}$*${NC}"; }
ok()     { echo -e "${G}✔ $*${NC}"; }
err()    { echo -e "${R}✘ $*${NC}" >&2; }

# ── detect current wallpaper ─────────────────────────────────────────────────
WALLPAPERS_DIR="$HOME/.config/ohmychadwm/wallpapers"

detect_wallpaper() {
    local wp=""

    # 1. variety
    if [[ -f "$HOME/.config/variety/wallpaper/wallpaper.jpg" ]]; then
        wp="$HOME/.config/variety/wallpaper/wallpaper.jpg"
    fi

    # 2. .fehbg (covers feh-set wallpapers including ohmychadwm/wallpapers/)
    if [[ -z "$wp" && -f "$HOME/.fehbg" ]]; then
        wp=$(grep -oP "(?<='|\")/[^'\"]+(?='|\")" "$HOME/.fehbg" | head -1)
    fi

    # 3. pick from ohmychadwm wallpapers folder
    if [[ -z "$wp" || ! -f "$wp" ]]; then
        local wp_dir="$HOME/.config/ohmychadwm/wallpapers"
        if [[ -d "$wp_dir" ]]; then
            mapfile -t images < <(find "$wp_dir" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) | sort)
            if [[ ${#images[@]} -gt 0 ]]; then
                ask "Could not detect current wallpaper. Pick from ohmychadwm wallpapers:"
                for i in "${!images[@]}"; do
                    printf "  %2d) %s\n" $((i+1)) "$(basename "${images[$i]}")"
                done
                read -rp "> " pick
                if [[ "$pick" =~ ^[0-9]+$ ]] && (( pick >= 1 && pick <= ${#images[@]} )); then
                    wp="${images[$((pick-1))]}"
                fi
            fi
        fi
    fi

    # 4. manual fallback
    if [[ -z "$wp" || ! -f "$wp" ]]; then
        ask "Could not detect wallpaper automatically. Enter path:"
        read -rp "> " wp
    fi

    if [[ ! -f "$wp" ]]; then
        err "File not found: $wp"
        exit 1
    fi
    echo "$wp"
}

# ── extract N dominant colors, sorted darkest → lightest ─────────────────────
extract_colors() {
    local wallpaper="$1"
    local count="${2:-12}"

    magick "$wallpaper" \
        -resize 200x200^ -gravity Center -extent 200x200 \
        +dither -colors "$count" -unique-colors txt:- \
        2>/dev/null \
        | grep -oE '#[0-9A-Fa-f]{6}' \
        | head -"$count"
}

# luminance of a hex color (0–255 scale)
luminance() {
    local hex="${1#'#'}"
    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))
    echo $(( (299*r + 587*g + 114*b) / 1000 ))
}

# saturation of a hex color (0–255 scale, higher = more vivid)
saturation() {
    local hex="${1#'#'}"
    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))
    local max min
    max=$r
    if [[ $g -gt $max ]]; then max=$g; fi
    if [[ $b -gt $max ]]; then max=$b; fi
    min=$r
    if [[ $g -lt $min ]]; then min=$g; fi
    if [[ $b -lt $min ]]; then min=$b; fi
    if [[ $max -eq 0 ]]; then
        echo 0
    else
        echo $(( (max - min) * 255 / max ))
    fi
}

# darken a hex color by a fixed amount (clamps to 0)
darken() {
    local hex="${1#'#'}" amt="${2:-20}"
    local r=$(( 16#${hex:0:2} - amt )); r=$(( r < 0 ? 0 : r ))
    local g=$(( 16#${hex:2:2} - amt )); g=$(( g < 0 ? 0 : g ))
    local b=$(( 16#${hex:4:2} - amt )); b=$(( b < 0 ? 0 : b ))
    printf '#%02x%02x%02x' $r $g $b
}

# lighten a hex color by a fixed amount (clamps to 255)
lighten() {
    local hex="${1#'#'}" amt="${2:-20}"
    local r=$(( 16#${hex:0:2} + amt )); r=$(( r > 255 ? 255 : r ))
    local g=$(( 16#${hex:2:2} + amt )); g=$(( g > 255 ? 255 : g ))
    local b=$(( 16#${hex:4:2} + amt )); b=$(( b > 255 ? 255 : b ))
    printf '#%02x%02x%02x' $r $g $b
}

# ensure a foreground color is at least 10% (26 lum units) brighter than bg.
# lightens in steps of 8 until the threshold is met, capping at white.
ensure_min_contrast() {
    local fg="$1" bg="$2"
    local threshold=26   # 10% of 255
    local lum_fg lum_bg diff
    lum_bg=$(luminance "$bg")
    lum_fg=$(luminance "$fg")
    diff=$(( lum_fg - lum_bg ))
    while [[ $diff -lt $threshold ]]; do
        fg=$(lighten "$fg" 8)
        lum_fg=$(luminance "$fg")
        diff=$(( lum_fg - lum_bg ))
        # stop if we've hit pure white
        if [[ "$fg" == "#ffffff" ]]; then break; fi
    done
    echo "$fg"
}

# sort colors by luminance (darkest first), output one per line
sort_by_luminance() {
    local colors=("$@")
    local pairs=()
    for c in "${colors[@]}"; do
        pairs+=("$(luminance "$c") $c")
    done
    printf '%s\n' "${pairs[@]}" | sort -n | awk '{print $2}'
}

# pick the most saturated color from a list
most_saturated() {
    local best="" best_sat=-1
    for c in "$@"; do
        local s; s=$(saturation "$c")
        if [[ $s -gt $best_sat ]]; then best_sat=$s; best=$c; fi
    done
    echo "$best"
}

# ── build color palette from sorted list ─────────────────────────────────────
build_palette() {
    local -a sorted=("$@")
    local n=${#sorted[@]}

    # background: darkest color, with a slightly lighter border variant
    BG="${sorted[0]}"
    BR=$(darken "$BG" -12)   # slightly lighter than bg for borders

    # dim foreground: near-darkest, for empty tags and inactive window text
    local dim_idx=$(( n / 8 ))
    if [[ $dim_idx -lt 1 ]]; then dim_idx=1; fi
    DIM_FG="${sorted[$dim_idx]}"

    # muted normal foreground: ~1/4 from darkest
    local idx=$(( n / 4 ))
    NORM_FG="${sorted[$idx]}"

    # bright foreground / title: ~90% from darkest
    local bright_idx=$(( n * 9 / 10 ))
    if [[ $bright_idx -ge $n ]]; then bright_idx=$(( n - 1 )); fi
    BRIGHT="${sorted[$bright_idx]}"

    # accent / selection: most saturated of the mid-range colors
    local mid_start=$(( n / 4 ))
    local mid_end=$(( n * 3 / 4 ))
    local mids=("${sorted[@]:$mid_start:$(( mid_end - mid_start ))}")
    ACCENT=$(most_saturated "${mids[@]}")

    # 10 tag colors: spread across the bright half of the palette
    # (occupied tags must be visibly brighter than empty tags which use DIM_FG)
    local range_start=$(( n / 2 ))
    local range_end=$(( n - 1 ))
    local range_colors=("${sorted[@]:$range_start:$(( range_end - range_start + 1 ))}")
    local rc=${#range_colors[@]}

    TAG=()
    for i in {0..9}; do
        local pick=$(( i * rc / 10 ))
        if [[ $pick -ge $rc ]]; then pick=$(( rc - 1 )); fi
        TAG+=("${range_colors[$pick]}")
    done

    # ── enforce minimum contrast: every fg must be ≥10% brighter than BG ────
    DIM_FG=$(ensure_min_contrast "$DIM_FG" "$BG")
    NORM_FG=$(ensure_min_contrast "$NORM_FG" "$BG")
    BRIGHT=$(ensure_min_contrast "$BRIGHT" "$BG")
    ACCENT=$(ensure_min_contrast "$ACCENT" "$BG")
    local new_tags=()
    for t in "${TAG[@]}"; do
        new_tags+=("$(ensure_min_contrast "$t" "$BG")")
    done
    TAG=("${new_tags[@]}")

    # ── SchemeMenu fg: must be brighter than every tag color ─────────────────
    # find the highest luminance among all tag colors
    local max_tag_lum=0
    for t in "${TAG[@]}"; do
        local lum; lum=$(luminance "$t")
        if [[ $lum -gt $max_tag_lum ]]; then
            max_tag_lum=$lum
        fi
    done
    # start from BRIGHT and keep lightening until it exceeds all tags
    MENU_FG="$BRIGHT"
    while [[ $(luminance "$MENU_FG") -le $max_tag_lum ]]; do
        MENU_FG=$(lighten "$MENU_FG" 8)
        if [[ "$MENU_FG" == "#ffffff" ]]; then break; fi
    done
}

# ── interactive questions ─────────────────────────────────────────────────────
ask_questions() {
    header "── chadwm theme generator ──────────────────────────────"
    echo -e "${W}Wallpaper:${NC} $WALLPAPER"
    echo -e "${W}Extracted ${#SORTED[@]} colors${NC}"
    echo

    # name
    # names that ship with ohmychadwm and must not be overwritten
    local -a DEFAULT_NAMES=(
        saturn pluto uranus jupiter venus mercury mars neptune
        catppuccin dracula everforest gruvchad kanagawa material
        monokai nord onedark prime rosepine solarized tokyonight tundra
        elephant giraffe hippo rhino buffalo
    )

    while true; do
        ask "Theme name (lowercase, no spaces, e.g. 'savannah'):"
        read -rp "> " THEME_NAME
        THEME_NAME="${THEME_NAME,,}"
        THEME_NAME="${THEME_NAME// /_}"
        if [[ -z "$THEME_NAME" ]]; then
            err "Name cannot be empty."
            continue
        fi
        local is_default=0
        for d in "${DEFAULT_NAMES[@]}"; do
            if [[ "$THEME_NAME" == "$d" ]]; then is_default=1; break; fi
        done
        if [[ $is_default -eq 1 ]]; then
            err "'$THEME_NAME' is a built-in theme and cannot be overwritten. Choose another name."
            continue
        fi
        if [[ -f "$THEMES_DIR/$THEME_NAME.h" ]]; then
            ask "Theme '$THEME_NAME' already exists. Overwrite? [y/N]:"
            read -rp "> " ow
            if [[ "$ow" =~ ^[Yy]$ ]]; then break; else continue; fi
        fi
        break
    done

    # bar position
    ask "Bar position — (t)op or (b)ottom? [T/b]:"
    read -rp "> " ans
    if [[ "$ans" =~ ^[Bb]$ ]]; then
        THEME_TOPBAR=0
    else
        THEME_TOPBAR=1
    fi

    # gaps
    ask "Gap size between windows in pixels? [0-20, default 5]:"
    read -rp "> " ans
    if [[ "$ans" =~ ^[0-9]+$ ]] && (( ans <= 20 )); then
        THEME_GAPS=$ans
    else
        THEME_GAPS=5
    fi

    # autohide
    ask "Auto-hide bar after how many seconds? [0 = disabled, default 0]:"
    read -rp "> " ans
    if [[ "$ans" =~ ^[0-9]+$ ]]; then
        THEME_AUTOHIDE=$ans
    else
        THEME_AUTOHIDE=0
    fi

    # systray
    ask "Show systray? [Y/n]:"
    read -rp "> " ans
    if [[ "$ans" =~ ^[Nn]$ ]]; then
        THEME_SHOWSYSTRAY=0
    else
        THEME_SHOWSYSTRAY=1
    fi

    # border
    ask "Border width in pixels? [default 2]:"
    read -rp "> " ans
    if [[ "$ans" =~ ^[0-9]+$ ]]; then
        THEME_BORDER=$ans
    else
        THEME_BORDER=2
    fi

    # smartgaps
    ask "Remove gaps when only one window is open? [y/N]:"
    read -rp "> " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        THEME_SMARTGAPS=1
    else
        THEME_SMARTGAPS=0
    fi

    # mfact
    ask "Master area size? [0.10-0.90, default 0.50]:"
    read -rp "> " ans
    if [[ "$ans" =~ ^0\.[0-9]+$ ]] && awk "BEGIN{exit !($ans >= 0.10 && $ans <= 0.90)}"; then
        THEME_MFACT=$ans
    else
        THEME_MFACT=0.50
    fi

    # nmaster
    ask "Number of windows in master area? [1-4, default 1]:"
    read -rp "> " ans
    if [[ "$ans" =~ ^[1-4]$ ]]; then
        THEME_NMASTER=$ans
    else
        THEME_NMASTER=1
    fi

    # font
    echo
    ask "Bar font — press Enter for default (JetBrainsMono Nerd Font Mono), or any key to browse:"
    read -rp "> " ans
    if [[ -z "$ans" ]]; then
        THEME_FONT="JetBrainsMono Nerd Font Mono:style:bold:size=13"
        ok "Font: $THEME_FONT (default)"
    else
        local picked
        picked=$(fc-list : family | sort -u | fzf \
            --prompt="Font > " \
            --height=40% \
            --layout=reverse \
            --border \
            --preview="echo 'Suffix :style:bold:size=13 will be appended'" \
            --preview-window=up:1 \
            2>/dev/null) || true
        if [[ -n "$picked" ]]; then
            THEME_FONT="${picked}:style:bold:size=13"
            ok "Font: $THEME_FONT"
        else
            THEME_FONT="JetBrainsMono Nerd Font Mono:style:bold:size=13"
            ok "Font: $THEME_FONT (default)"
        fi
    fi
}

# ── write theme file ──────────────────────────────────────────────────────────
write_theme() {
    local file="$THEMES_DIR/$THEME_NAME.h"

    # cycle tag colors
    local t0="${TAG[0]}" t1="${TAG[1]}" t2="${TAG[2]}" t3="${TAG[3]}" t4="${TAG[4]}"
    local t5="${TAG[5]}" t6="${TAG[6]}" t7="${TAG[7]}" t8="${TAG[8]}" t9="${TAG[9]}"

    cat > "$file" <<EOF
/* ${THEME_NAME^} — generated from wallpaper */
#define THEME_TOPBAR   $THEME_TOPBAR
#define THEME_GAPS     $THEME_GAPS
#define THEME_AUTOHIDE    $THEME_AUTOHIDE
#define THEME_SHOWSYSTRAY $THEME_SHOWSYSTRAY
#define THEME_BORDER      $THEME_BORDER
#define THEME_SMARTGAPS   $THEME_SMARTGAPS
#define THEME_MFACT       $THEME_MFACT
#define THEME_NMASTER     $THEME_NMASTER
#define THEME_FONT        "$THEME_FONT"

static const char col_borderbar[]      = "$BG";

static const char SchemeNormfg[]       = "$DIM_FG";
static const char SchemeNormbg[]       = "$BG";
static const char SchemeNormbr[]       = "$BR";

static const char SchemeSelfg[]        = "$BG";
static const char SchemeSelbg[]        = "$ACCENT";
static const char SchemeSelbr[]        = "$ACCENT";

static const char SchemeTitlefg[]      = "$BRIGHT";
static const char SchemeTitlebg[]      = "$BG";
static const char SchemeTitlebr[]      = "$BG";

static const char TabSelfg[]           = "$ACCENT";
static const char TabSelbg[]           = "$BR";
static const char TabSelbr[]           = "$BG";

static const char TabNormfg[]          = "$DIM_FG";
static const char TabNormbg[]          = "$BG";
static const char TabNormbr[]          = "$BG";

static const char SchemeTagfg[]        = "$DIM_FG";
static const char SchemeTagbg[]        = "$BG";
static const char SchemeTagbr[]        = "$BG";

static const char SchemeTag1fg[]       = "$t0";
static const char SchemeTag1bg[]       = "$BG";
static const char SchemeTag1br[]       = "$BG";

static const char SchemeTag2fg[]       = "$t1";
static const char SchemeTag2bg[]       = "$BG";
static const char SchemeTag2br[]       = "$BG";

static const char SchemeTag3fg[]       = "$t2";
static const char SchemeTag3bg[]       = "$BG";
static const char SchemeTag3br[]       = "$BG";

static const char SchemeTag4fg[]       = "$t3";
static const char SchemeTag4bg[]       = "$BG";
static const char SchemeTag4br[]       = "$BG";

static const char SchemeTag5fg[]       = "$t4";
static const char SchemeTag5bg[]       = "$BG";
static const char SchemeTag5br[]       = "$BG";

static const char SchemeTag6fg[]       = "$t5";
static const char SchemeTag6bg[]       = "$BG";
static const char SchemeTag6br[]       = "$BG";

static const char SchemeTag7fg[]       = "$t6";
static const char SchemeTag7bg[]       = "$BG";
static const char SchemeTag7br[]       = "$BG";

static const char SchemeTag8fg[]       = "$t7";
static const char SchemeTag8bg[]       = "$BG";
static const char SchemeTag8br[]       = "$BG";

static const char SchemeTag9fg[]       = "$t8";
static const char SchemeTag9bg[]       = "$BG";
static const char SchemeTag9br[]       = "$BG";

static const char SchemeTag10fg[]      = "$t9";
static const char SchemeTag10bg[]      = "$BG";
static const char SchemeTag10br[]      = "$BG";

static const char SchemeLayoutfg[]     = "$ACCENT";
static const char SchemeLayoutbg[]     = "$BG";
static const char SchemeLayoutbr[]     = "$BG";

static const char SchemeBtnPrevfg[]    = "$t3";
static const char SchemeBtnPrevbg[]    = "$BG";
static const char SchemeBtnPrevbr[]    = "$BG";

static const char SchemeBtnNextfg[]    = "$t5";
static const char SchemeBtnNextbg[]    = "$BG";
static const char SchemeBtnNextbr[]    = "$BG";

static const char SchemeBtnClosefg[]   = "$t1";
static const char SchemeBtnClosebg[]   = "$BG";
static const char SchemeBtnClosebr[]   = "$BG";

static const char SchemeLayoutFFfg[]   = "$t2";
static const char SchemeLayoutFFbg[]   = "$BG";
static const char SchemeLayoutFFbr[]   = "$BG";

static const char SchemeLayoutEWfg[]   = "$t4";
static const char SchemeLayoutEWbg[]   = "$BG";
static const char SchemeLayoutEWbr[]   = "$BG";

static const char SchemeLayoutDSfg[]   = "$t1";
static const char SchemeLayoutDSbg[]   = "$BG";
static const char SchemeLayoutDSbr[]   = "$BG";

static const char SchemeLayoutTGfg[]   = "$t3";
static const char SchemeLayoutTGbg[]   = "$BG";
static const char SchemeLayoutTGbr[]   = "$BG";

static const char SchemeLayoutMSfg[]   = "$t6";
static const char SchemeLayoutMSbg[]   = "$BG";
static const char SchemeLayoutMSbr[]   = "$BG";

static const char SchemeLayoutPCfg[]   = "$t2";
static const char SchemeLayoutPCbg[]   = "$BG";
static const char SchemeLayoutPCbr[]   = "$BG";

static const char SchemeLayoutVVfg[]   = "$t4";
static const char SchemeLayoutVVbg[]   = "$BG";
static const char SchemeLayoutVVbr[]   = "$BG";

static const char SchemeLayoutOPfg[]   = "$t1";
static const char SchemeLayoutOPbg[]   = "$BG";
static const char SchemeLayoutOPbr[]   = "$BG";

static const char SchemeMenufg[]       = "$MENU_FG";
static const char SchemeMenubg[]       = "$BG";
static const char SchemeMenubr[]       = "$BG";
EOF

    ok "Theme written to $file"

    # save wallpaper alongside the theme so it can be restored when activated
    local wp_dir="$HOME/.config/ohmychadwm/wallpapers"
    mkdir -p "$wp_dir"
    if [[ "$WALLPAPER" != "$wp_dir/${THEME_NAME}.jpg" ]]; then
        cp -f "$WALLPAPER" "$wp_dir/${THEME_NAME}.jpg"
    fi
    ok "Wallpaper saved to $wp_dir/${THEME_NAME}.jpg"
}

# ── update config.def.h ───────────────────────────────────────────────────────
update_config() {
    local active_line="#include \"themes/${THEME_NAME}.h\""
    local section="// custom themes"

    # deactivate all active theme includes
    sed -i 's|^#include "themes/\(.*\)\.h"|//&|' "$CONFIG"

    # ensure custom themes section exists
    if ! grep -q "$section" "$CONFIG"; then
        sed -i "/^\/\* fallback layout settings/i $section\n" "$CONFIG"
    fi

    # add or uncomment this theme's include line, then activate it
    if ! grep -q "themes/${THEME_NAME}.h" "$CONFIG"; then
        sed -i "/^\/\/ custom themes/a $active_line" "$CONFIG"
    else
        sed -i "s|^//\(#include \"themes/${THEME_NAME}.h\"\)|\1|" "$CONFIG"
    fi

    ok "config.def.h updated — theme activated"

    # Sync SchemeMenufg → rofi menu accent color
    local rasi="$HOME/.config/ohmychadwm/menu/ohmychadwm-menu.rasi"
    local theme_file="$THEMES_DIR/$THEME_NAME.h"
    if [[ -f "$rasi" && -f "$theme_file" ]]; then
        local color
        color=$(grep -oP 'SchemeMenufg\[\]\s*=\s*"\K[^"]+' "$theme_file" | head -1)
        if [[ -n "$color" ]]; then
            local safe_color="${color//&/\\&}"
            sed -i "s|ac:.*\/\* selected item text.*|ac:     ${safe_color};   /* selected item text   (synced from SchemeMenufg)  */|" "$rasi"
            ok "Menu accent color synced to SchemeMenufg: $color"
        fi
    fi
}

# ── main ──────────────────────────────────────────────────────────────────────
main() {
    header "Detecting wallpaper..."
    WALLPAPER=$(detect_wallpaper)
    ok "Wallpaper: $WALLPAPER"

    header "Extracting colors..."
    mapfile -t COLORS < <(extract_colors "$WALLPAPER" 12)

    if [[ ${#COLORS[@]} -lt 4 ]]; then
        err "Could not extract enough colors from the wallpaper (got ${#COLORS[@]})."
        exit 1
    fi

    mapfile -t SORTED < <(sort_by_luminance "${COLORS[@]}")
    build_palette "${SORTED[@]}"

    echo -e "\n${W}Color palette:${NC}"
    printf "  BG      %s  (bar/window background)\n"    "$BG"
    printf "  Dim     %s  (empty tags, inactive text)\n" "$DIM_FG"
    printf "  Muted   %s  (normal foreground)\n"        "$NORM_FG"
    printf "  Accent  %s  (active window / selection)\n" "$ACCENT"
    printf "  Bright  %s  (focused title text)\n"       "$BRIGHT"
    printf "  Tags    %s\n" "${TAG[*]}"

    ask_questions
    write_theme
    update_config

    # ── fix wallpaper ─────────────────────────────────────────────────────────
    ask "Fix this wallpaper to the theme? [Y/n]:"
    read -rp "> " fix_wp
    if [[ ! "$fix_wp" =~ ^[Nn]$ ]]; then
        local ext="${WALLPAPER##*.}"
        local wp_dest="$WALLPAPERS_DIR/${THEME_NAME}.${ext}"
        if [[ "$WALLPAPER" != "$wp_dest" ]]; then
            cp "$WALLPAPER" "$wp_dest"
            ok "Wallpaper saved to $(basename "$wp_dest")"
        fi
        if feh --bg-fill "$wp_dest" 2>/dev/null; then
            ok "Wallpaper set with feh"
        else
            err "feh could not set wallpaper — set manually: $wp_dest"
        fi
    fi

    echo
    header "Done!"
    echo -e "  Theme file : ${W}$THEMES_DIR/$THEME_NAME.h${NC}"
    echo -e "  config     : ${W}$CONFIG${NC}"
    echo
    ask "Run ./rebuild.sh now? [Y/n]:"
    read -rp "> " do_rebuild
    if [[ ! "$do_rebuild" =~ ^[Nn]$ ]]; then
        cd "$HOME/.config/ohmychadwm/chadwm" && ./rebuild.sh
    else
        echo -e "  Rebuild manually: ${W}cd ~/.config/ohmychadwm/chadwm && ./rebuild.sh${NC}"
    fi
}

main "$@"
