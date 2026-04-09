#!/usr/bin/env bash
# generate-theme-previews.sh
# Generates 1024x768 PNG preview images for every chadwm theme.
# Renders a realistic bar + tiled windows mockup using ImageMagick.

set -euo pipefail

THEMES_DIR="${HOME}/.config/ohmychadwm/chadwm/themes"
OUTPUT_DIR="${HOME}/.config/ohmychadwm/previews"
W=1024
H=768
BAR_H=28
LABEL_FONT="DejaVu-Sans-Bold"

mkdir -p "$OUTPUT_DIR"

# ── helpers ───────────────────────────────────────────────────────────────────

col() {
    grep -oP "${1}\[\]\s*=\s*\"\K[^\"]+" "$2" 2>/dev/null | head -1
}

def_val() {
    grep -oP "#define\s+${1}\s+\K\S+" "$2" 2>/dev/null | head -1
}

# draw a filled rectangle: rect X1 Y1 X2 Y2
rect() { echo "rectangle ${1},${2} ${3},${4}"; }

# ── per-theme generator ───────────────────────────────────────────────────────

gen_preview() {
    local f="$1"
    local name; name=$(basename "$f" .h)
    local out="${OUTPUT_DIR}/${name}.png"

    # ── extract colors ────────────────────────────────────────────────────────
    local bg;     bg=$(col    "SchemeNormbg"       "$f"); bg="${bg:-#1e1e2e}"
    local nbr;    nbr=$(col   "SchemeNormbr"       "$f"); nbr="${nbr:-$bg}"
    local nfg;    nfg=$(col   "SchemeNormfg"       "$f"); nfg="${nfg:-#cdd6f4}"
    local selbg;  selbg=$(col "SchemeSelbg"        "$f"); selbg="${selbg:-#89b4fa}"
    local selfg;  selfg=$(col "SchemeSelfg"        "$f"); selfg="${selfg:-$bg}"
    local selbr;  selbr=$(col "SchemeSelbr"        "$f"); selbr="${selbr:-$selbg}"
    local tfg;    tfg=$(col   "SchemeTitlefg"      "$f"); tfg="${tfg:-$nfg}"
    local tbg;    tbg=$(col   "SchemeTitlebg"      "$f"); tbg="${tbg:-$bg}"
    local layf;   layf=$(col  "SchemeLayoutfg"     "$f"); layf="${layf:-$nfg}"
    local menuf;  menuf=$(col "SchemeMenufg"       "$f"); menuf="${menuf:-$nfg}"
    local menub;  menub=$(col "SchemeMenubg"       "$f"); menub="${menub:-$bg}"
    local menubr; menubr=$(col "SchemeMenubr"      "$f"); menubr="${menubr:-$nbr}"
    local btnpf;  btnpf=$(col "SchemeBtnPrevfg"    "$f"); btnpf="${btnpf:-$nfg}"
    local btnnf;  btnnf=$(col "SchemeBtnNextfg"    "$f"); btnnf="${btnnf:-$nfg}"
    local btncf;  btncf=$(col "SchemeBtnClosefg"   "$f"); btncf="${btncf:-$nfg}"

    local tags=()
    for i in 1 2 3 4 5 6 7 8 9 10; do
        local tc; tc=$(col "SchemeTag${i}fg" "$f"); tags+=("${tc:-$nfg}")
    done

    local topbar; topbar=$(def_val "THEME_TOPBAR" "$f"); topbar="${topbar:-1}"
    local gap;    gap=$(def_val   "THEME_GAPS"    "$f"); gap="${gap:-5}"
    local bw;     bw=$(def_val   "THEME_BORDER"  "$f"); bw="${bw:-2}"

    # ── layout constants ──────────────────────────────────────────────────────
    local bar_y bar_y2 content_y
    if [[ "$topbar" == "1" ]]; then
        bar_y=0; bar_y2=$((BAR_H - 1)); content_y=$((BAR_H + gap))
    else
        bar_y=$((H - BAR_H)); bar_y2=$((H - 1)); content_y=$gap
    fi

    local pal_h=20                               # palette strip height
    local content_h

    if [[ "$topbar" == "1" ]]; then
        content_h=$((H - BAR_H - gap * 2 - pal_h))
    else
        content_h=$((H - BAR_H - gap * 2 - pal_h))
    fi

    local menu_w=32
    local tag_w=28
    local btn_w=28
    local tags_end=$((menu_w + tag_w * 10))

    local close_x=$((W - btn_w))
    local next_x=$((close_x - btn_w))
    local prev_x=$((next_x  - btn_w))
    local lay_x=$((prev_x   - btn_w))
    local title_x=$tags_end
    local title_x2=$((lay_x - 1))

    # master window (left 58%)
    local win1_x=$gap
    local win1_y=$content_y
    local win1_w=$(( (W - gap * 3) * 58 / 100 ))
    local win1_h=$content_h

    # stack area (right)
    local win2_x=$((win1_x + win1_w + gap))
    local win2_w=$((W - win2_x - gap))
    local win2_h=$(( content_h * 53 / 100 ))
    local win3_y=$((content_y + win2_h + gap))
    local win3_h=$((content_h - win2_h - gap))

    # palette strip (very bottom)
    local pal_y=$((H - pal_h))

    # ── build draw operations ─────────────────────────────────────────────────
    local d=()

    # background
    d+=(-fill "$bg" -stroke none -draw "$(rect 0 0 $((W-1)) $((H-1)))")

    # ── bar ───────────────────────────────────────────────────────────────────
    # full bar bg
    d+=(-fill "$bg" -stroke none -draw "$(rect 0 $bar_y $((W-1)) $bar_y2)")

    # menu button (border + fill + 3-line icon)
    d+=(-fill "$menubr" -stroke none -draw "$(rect 0 $bar_y $((menu_w-1)) $bar_y2)")
    d+=(-fill "$menub"  -stroke none -draw "$(rect $bw $bar_y $((menu_w-bw-1)) $((bar_y2-bw)))")
    local mfx=$((bw+5)) mfx2=$((menu_w-bw-6))
    d+=(-fill "$menuf" -stroke none -draw "$(rect $mfx $((bar_y+6))  $mfx2 $((bar_y+8)))")
    d+=(-fill "$menuf" -stroke none -draw "$(rect $mfx $((bar_y+12)) $mfx2 $((bar_y+14)))")
    d+=(-fill "$menuf" -stroke none -draw "$(rect $mfx $((bar_y+18)) $mfx2 $((bar_y+20)))")

    # tags (colored square indicator per tag)
    local tx=$menu_w
    for i in "${!tags[@]}"; do
        local tc="${tags[$i]}"
        d+=(-fill "$bg"  -stroke none -draw "$(rect $tx $bar_y $((tx+tag_w-1)) $bar_y2)")
        local dx=$((tx + tag_w/2 - 4)) dy=$((bar_y + BAR_H/2 - 4))
        d+=(-fill "$tc"  -stroke none -draw "$(rect $dx $dy $((dx+8)) $((dy+8)))")
        tx=$((tx + tag_w))
    done

    # title area
    d+=(-fill "$tbg" -stroke none -draw "$(rect $title_x $bar_y $title_x2 $bar_y2)")
    d+=(-fill "$tfg" -stroke none -draw "$(rect $((title_x+8)) $((bar_y+BAR_H/2-2)) $((title_x+160)) $((bar_y+BAR_H/2+2)))")
    d+=(-fill "$tfg" -stroke none -draw "$(rect $((title_x+8)) $((bar_y+BAR_H/2+6)) $((title_x+90))  $((bar_y+BAR_H/2+8)))")

    # layout icon (2×2 grid)
    d+=(-fill "$bg"   -stroke none -draw "$(rect $lay_x $bar_y $((lay_x+btn_w-1)) $bar_y2)")
    d+=(-fill "$layf" -stroke none -draw "$(rect $((lay_x+5))  $((bar_y+5))  $((lay_x+13)) $((bar_y+12)))")
    d+=(-fill "$layf" -stroke none -draw "$(rect $((lay_x+15)) $((bar_y+5))  $((lay_x+23)) $((bar_y+12)))")
    d+=(-fill "$layf" -stroke none -draw "$(rect $((lay_x+5))  $((bar_y+15)) $((lay_x+23)) $((bar_y+22)))")

    # prev button (◀)
    d+=(-fill "$bg"   -stroke none -draw "$(rect $prev_x $bar_y $((prev_x+btn_w-1)) $bar_y2)")
    d+=(-fill "$btnpf" -stroke none -draw "$(rect $((prev_x+14)) $((bar_y+6))  $((prev_x+18)) $((bar_y2-6)))")
    d+=(-fill "$btnpf" -stroke none -draw "$(rect $((prev_x+10)) $((bar_y+9))  $((prev_x+14)) $((bar_y+14)))")
    d+=(-fill "$btnpf" -stroke none -draw "$(rect $((prev_x+10)) $((bar_y+14)) $((prev_x+14)) $((bar_y+19)))")

    # next button (▶)
    d+=(-fill "$bg"   -stroke none -draw "$(rect $next_x $bar_y $((next_x+btn_w-1)) $bar_y2)")
    d+=(-fill "$btnnf" -stroke none -draw "$(rect $((next_x+10)) $((bar_y+6))  $((next_x+14)) $((bar_y2-6)))")
    d+=(-fill "$btnnf" -stroke none -draw "$(rect $((next_x+14)) $((bar_y+9))  $((next_x+18)) $((bar_y+14)))")
    d+=(-fill "$btnnf" -stroke none -draw "$(rect $((next_x+14)) $((bar_y+14)) $((next_x+18)) $((bar_y+19)))")

    # close button (■)
    d+=(-fill "$bg"    -stroke none -draw "$(rect $close_x $bar_y $((W-1)) $bar_y2)")
    d+=(-fill "$btncf" -stroke none -draw "$(rect $((close_x+7)) $((bar_y+7)) $((close_x+btn_w-8)) $((bar_y2-7)))")

    # ── master window (selected) ──────────────────────────────────────────────
    d+=(-fill "$selbr" -stroke none -draw "$(rect $win1_x $win1_y $((win1_x+win1_w)) $((win1_y+win1_h)))")
    d+=(-fill "$bg"    -stroke none -draw "$(rect $((win1_x+bw)) $((win1_y+bw)) $((win1_x+win1_w-bw)) $((win1_y+win1_h-bw)))")
    # title bar
    d+=(-fill "$selbg" -stroke none -draw "$(rect $((win1_x+bw)) $((win1_y+bw)) $((win1_x+win1_w-bw)) $((win1_y+bw+BAR_H)))")
    d+=(-fill "$selfg" -stroke none -draw "$(rect $((win1_x+10)) $((win1_y+bw+BAR_H/2-2)) $((win1_x+200)) $((win1_y+bw+BAR_H/2+2)))")
    # content lines
    local lws=(190 120 210 80 165 145 110 180 95 200 130 75)
    for li in "${!lws[@]}"; do
        local ly=$((win1_y + bw + BAR_H + (li+1) * 22 + 6))
        [[ $ly -ge $((win1_y + win1_h - 14)) ]] && break
        d+=(-fill "$nfg" -stroke none -draw "$(rect $((win1_x+14)) $ly $((win1_x+14+${lws[$li]})) $((ly+3)))")
    done

    # ── top stack window (normal) ─────────────────────────────────────────────
    d+=(-fill "$nbr" -stroke none -draw "$(rect $win2_x $content_y $((win2_x+win2_w)) $((content_y+win2_h)))")
    d+=(-fill "$bg"  -stroke none -draw "$(rect $((win2_x+bw)) $((content_y+bw)) $((win2_x+win2_w-bw)) $((content_y+win2_h-bw)))")
    d+=(-fill "$tbg" -stroke none -draw "$(rect $((win2_x+bw)) $((content_y+bw)) $((win2_x+win2_w-bw)) $((content_y+bw+BAR_H)))")
    d+=(-fill "$tfg" -stroke none -draw "$(rect $((win2_x+10)) $((content_y+bw+BAR_H/2-2)) $((win2_x+120)) $((content_y+bw+BAR_H/2+2)))")
    local lws2=(90 115 65 100 80)
    for li in "${!lws2[@]}"; do
        local ly=$((content_y + bw + BAR_H + (li+1) * 20 + 4))
        [[ $ly -ge $((content_y + win2_h - 10)) ]] && break
        d+=(-fill "$nfg" -stroke none -draw "$(rect $((win2_x+12)) $ly $((win2_x+12+${lws2[$li]})) $((ly+3)))")
    done

    # ── bottom stack window ───────────────────────────────────────────────────
    if [[ $win3_h -gt 36 ]]; then
        d+=(-fill "$nbr" -stroke none -draw "$(rect $win2_x $win3_y $((win2_x+win2_w)) $((win3_y+win3_h)))")
        d+=(-fill "$bg"  -stroke none -draw "$(rect $((win2_x+bw)) $((win3_y+bw)) $((win2_x+win2_w-bw)) $((win3_y+win3_h-bw)))")
        d+=(-fill "$tbg" -stroke none -draw "$(rect $((win2_x+bw)) $((win3_y+bw)) $((win2_x+win2_w-bw)) $((win3_y+bw+BAR_H)))")
        d+=(-fill "$tfg" -stroke none -draw "$(rect $((win2_x+10)) $((win3_y+bw+BAR_H/2-2)) $((win2_x+85)) $((win3_y+bw+BAR_H/2+2)))")
        local lws3=(70 95 55)
        for li in "${!lws3[@]}"; do
            local ly=$((win3_y + bw + BAR_H + (li+1) * 20 + 4))
            [[ $ly -ge $((win3_y + win3_h - 10)) ]] && break
            d+=(-fill "$nfg" -stroke none -draw "$(rect $((win2_x+12)) $ly $((win2_x+12+${lws3[$li]})) $((ly+3)))")
        done
    fi

    # ── palette strip ─────────────────────────────────────────────────────────
    local pal_colors=(
        "$bg" "$nbr" "$nfg" "$selbg" "$selfg" "$tbg" "$tfg"
        "${tags[0]}" "${tags[1]}" "${tags[2]}" "${tags[3]}" "${tags[4]}"
        "${tags[5]}" "${tags[6]}" "${tags[7]}" "${tags[8]}" "${tags[9]}"
    )
    local nc=${#pal_colors[@]}
    local sw=$(( W / nc ))
    for pi in "${!pal_colors[@]}"; do
        local px=$((pi * sw))
        local px2=$(( pi == nc-1 ? W-1 : px+sw-1 ))
        d+=(-fill "${pal_colors[$pi]}" -stroke none -draw "$(rect $px $pal_y $px2 $((H-1)))")
    done

    # ── theme name label ──────────────────────────────────────────────────────
    # shadow for readability on any background
    d+=(-font "$LABEL_FONT" -pointsize 16
        -fill black    -annotate +$((win1_x+13))+$((win1_y+win1_h-13)) "$name"
        -fill "$selbr" -annotate +$((win1_x+12))+$((win1_y+win1_h-14)) "$name")

    # ── render ────────────────────────────────────────────────────────────────
    magick -size "${W}x${H}" "xc:${bg}" "${d[@]}" "$out"
    printf '  %-32s → %s\n' "$name" "$(basename "$out")"
}

# ── main ──────────────────────────────────────────────────────────────────────
count=0; failed=0

echo "Generating 1024×768 theme previews → $OUTPUT_DIR"
echo

for f in "$THEMES_DIR"/*.h; do
    [[ -f "$f" ]] || continue
    if gen_preview "$f"; then
        (( count++ )) || true
    else
        echo "  FAILED: $(basename "$f" .h)" >&2
        (( failed++ )) || true
    fi
done

echo
echo "Done: ${count} generated, ${failed} failed"
