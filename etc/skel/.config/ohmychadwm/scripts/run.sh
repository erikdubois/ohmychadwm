#!/bin/sh

function run {
 if ! pgrep $1 ;
  then
    $@&
  fi
}

#for virtualbox
#run xrandr --output Virtual-1 --primary --mode 1920x1080 --pos 0x0 --rotate normal
sh /home/erik/.screenlayout/erik.sh
run "signal-in-tray"
run "nm-applet"
run "pamac-tray"
run "variety -n"
run "flameshot"
run "xfce4-power-manager"
run "xfce4-clipman"
run "blueberry-tray"
run "/usr/lib/xfce4/notifyd/xfce4-notifyd"
run "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
run "fastcompmgr -c"
#run "picom -b  --config ~/.config/ohmychadwm/picom/picom.conf &"
run "numlockx on"
run "volctl"
sxhkd -c ~/.config/ohmychadwm/sxhkd/sxhkdrc &
feh --bg-fill ~/.config/ohmychadwm/wallpapers/cyborg.jpg &
run "insync start"
run "slstatus"

while type ohmychadwm >/dev/null; do ohmychadwm && continue || break; done
