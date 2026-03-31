#!/bin/sh

set -eu

DWM_FILE="$HOME/.config/ohmychadwm/chadwm/config.def.h"
SXHKD_FILE="$HOME/.config/ohmychadwm/sxhkd/sxhkdrc"

if [ ! -f "$DWM_FILE" ]; then
    printf 'Missing dwm file: %s\n' "$DWM_FILE" >&2
    exit 1
fi

if [ ! -f "$SXHKD_FILE" ]; then
    printf 'Missing sxhkd file: %s\n' "$SXHKD_FILE" >&2
    exit 1
fi

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM

awk '
function trim(s){gsub(/^[ \t]+|[ \t]+$/, "", s); return s}
BEGIN{inarr=0}
{
    if (!inarr && match($0,/static const char \*[A-Za-z0-9_]+\[\][ \t]*=[ \t]*\{/)) {
        name=$0
        sub(/^.*\*/,"",name)
        sub(/\[\].*$/,"",name)
        arrname=trim(name)

        content=$0
        sub(/^.*\{/,"",content)

        if ($0 ~ /\};/) {
            sub(/\};.*$/,"",content)
        } else {
            inarr=1
        }

        arrcontent=content

        if (!inarr) {
            gsub(/NULL|"/,"",arrcontent)
            gsub(/[ \t]*,[ \t]*/," ",arrcontent)
            print arrname "\t" trim(arrcontent)
        }
        next
    }

    if (inarr) {
        content=$0
        if ($0 ~ /\};/) {
            sub(/\};.*$/,"",content)
            inarr=0
        }
        arrcontent=arrcontent " " content

        if (!inarr) {
            gsub(/NULL|"/,"",arrcontent)
            gsub(/[ \t]*,[ \t]*/," ",arrcontent)
            print arrname "\t" trim(arrcontent)
        }
    }
}
' "$DWM_FILE" > "$tmpdir/arrays.tsv"

awk -v arrays="$tmpdir/arrays.tsv" '
function trim(s){gsub(/^[ \t]+|[ \t]+$/, "", s); return s}

function mod(m){
    out=""
    if(m~/MODKEY/) out=out "Super+"
    if(m~/ControlMask/) out=out "Ctrl+"
    if(m~/ShiftMask/) out=out "Shift+"
    if(m~/Mod1Mask/) out=out "Alt+"
    return out
}

function keyclean(k){
    gsub(/^XK_/,"",k)
    gsub(/^XF86XK_/,"",k)
    return k
}

function resolve_array(name,   l,a){
    while((getline l < arrays)>0){
        split(l,a,"\t")
        if(a[1]==name){
            close(arrays)
            return a[2]
        }
    }
    close(arrays)
    return name
}

function action(fn,arg,   v){
    fn=trim(fn)

    if(fn=="spawn"){
        if(arg ~ /\.v[ \t]*=/){
            v=arg
            sub(/^.*=/,"",v)
            gsub(/[ \t}]/,"",v)
            return resolve_array(v)
        }

        if(arg ~ /SHCMD/){
            v=arg
            sub(/^.*SHCMD\("/,"",v)
            sub(/"\).*$/,"",v)
            return v
        }

        return "spawn"
    }

    return fn
}

BEGIN{ink=0}

{
    if($0 ~ /static const Key keys\[\]/){ink=1; next}
    if(ink && $0 ~ /^[ \t]*\};/){ink=0}

    if(ink && $0 ~ /^[ \t]*\{.*\}/){
        raw=$0
        gsub(/^[ \t]*\{[ \t]*/,"",raw)
        gsub(/[ \t]*\},?[ \t]*$/,"",raw)

        split(raw,p,/, */)

        combo=mod(p[1]) keyclean(p[2])
        act=action(p[3], raw)

        print "dwm\t" combo "\t" act
    }

    if(ink && $0 ~ /TAGKEYS/){
        t=$0
        sub(/^.*TAGKEYS\(/,"",t)
        sub(/\).*$/,"",t)
        split(t,a,/, */)

        k=keyclean(a[1])
        tag=a[2]

        print "dwm\tSuper+" k "\tview(" tag ")"
        print "dwm\tSuper+Ctrl+" k "\ttoggleview(" tag ")"
        print "dwm\tSuper+Shift+" k "\ttag(" tag ")"
        print "dwm\tSuper+Ctrl+Shift+" k "\ttoggletag(" tag ")"
    }
}
' "$DWM_FILE" > "$tmpdir/dwm.tsv"

awk '
function trim(s){gsub(/^[ \t]+|[ \t]+$/, "", s); return s}

BEGIN{key=""}

{
    if($0 ~ /^[ \t]*#/ || $0 ~ /^[ \t]*$/) next

    if($0 ~ /^[ \t]/){
        if(key != ""){
            print "sxhkd\t" key "\t" trim($0)
            key=""
        }
    } else {
        key=trim($0)
    }
}
' "$SXHKD_FILE" > "$tmpdir/sxhkd.tsv"

cat "$tmpdir/dwm.tsv" "$tmpdir/sxhkd.tsv" | awk -F '\t' '
function group_from_key(k,   g){
    g=""
    if (k ~ /Super|super/) g = g "Super+"
    if (k ~ /Ctrl|ctrl|control/) g = g "Ctrl+"
    if (k ~ /Shift|shift/) g = g "Shift+"
    if (k ~ /Alt|alt|mod1/) g = g "Alt+"

    if (g == "") return "NoModifier"

    sub(/\+$/, "", g)
    return g
}

{
    src=$1
    key=$2
    act=$3
    grp=group_from_key(key)
    print grp "\t" src "\t" key "\t" act
}
' | sort -t '	' -k1,1 -k3,3 > "$tmpdir/grouped.tsv"

awk -F '\t' '
BEGIN{current=""}
{
    grp=$1
    src=$2
    key=$3
    act=$4

    if (grp != current) {
        if (current != "") print ""
        print "=== " grp " ==="
        current=grp
    }

    printf "%-6s | %-30s | %s\n", src, key, act
}
' "$tmpdir/grouped.tsv" > "$tmpdir/display.txt"

if [ ! -s "$tmpdir/display.txt" ]; then
    printf 'No keybindings were parsed\n' >&2
    exit 1
fi

if command -v rofi >/dev/null 2>&1; then
    rofi -theme ~/.config/ohmychadwm/launcher/rofi/keybindings.rasi -dmenu -i -p "Keybindings" < "$tmpdir/display.txt"
elif command -v dmenu >/dev/null 2>&1; then
    dmenu -i -l 30 -p "Keybindings" < "$tmpdir/display.txt" >/dev/null
else
    cat "$tmpdir/display.txt"
fi
