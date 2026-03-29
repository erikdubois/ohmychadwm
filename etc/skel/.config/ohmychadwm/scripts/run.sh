#!/bin/sh
#xrandr --output DVI-D-0 --off --output HDMI-0 --mode 1920x1080 --pos 0x0 --rotate normal --output DP-0 --mode 1920x1080 --pos 1920x0 --rotate normal --output DP-1 --off --output HDMI-1 --off --output None-1-1 --off
sh /home/erik/.screenlayout/erik.sh
#xrdb merge ~/.Xresources 
#xbacklight -set 10 &
#xset r rate 200 50 &

function run {
 if ! pgrep $1 ;
  then
    $@&
  fi
}

run "signal-in-tray"
#run "dex $HOME/.config/autostart/arcolinux-welcome-app.desktop"

#for virtualbox
#run xrandr --output Virtual-1 --primary --mode 1920x1080 --pos 0x0 --rotate normal

#for real metal
#run xrandr --output DVI-1 --right-of DVI-0 --auto
#run xrandr --output DVI-D-0 --off --output HDMI-0 --mode 1920x1080 --pos 0x0 --rotate normal --output DP-0 --mode 1920x1080 --pos 1920x0 --rotate normal --output DP-1 --off --output HDMI-1 --off --output None-1-1 --off
#run xrandr --output DVI-D-1 --right-of DVI-I-1 --auto
#run xrandr --output DVI-I-0 --right-of HDMI-0 --auto
#run xrandr --output eDP-1 --primary --mode 1368x768 --pos 0x0 --rotate normal --output DP-1 --off --output HDMI-1 --off --output DP-2 --off --output HDMI-2 --off
#run xrandr --output HDMI2 --mode 1920x1080 --pos 1920x0 --rotate normal --output HDMI1 --primary --mode 1920x1080 --pos 0x0 --rotate normal --output VIRTUAL1 --off
#run xrandr --output HDMI2 --right-of HDMI1 --auto
#run xrandr --output LVDS1 --mode 1366x768 --output DP3 --mode 1920x1080 --right-of LVDS1
#run xrandr --output VGA-1 --primary --mode 1360x768 --pos 0x0 --rotate normal
#autorandr horizontal
#run "autorandr horizontal"
run "nm-applet"
run "pamac-tray"
#run "protonvpn-app"
run "variety -n"
run "flameshot"
run "xfce4-power-manager"
run "xfce4-clipman"
run "blueberry-tray"
run "/usr/lib/xfce4/notifyd/xfce4-notifyd"
run "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
#fastcompmgr -c &
picom -b  --config ~/.config/arco-chadwm/picom/picom.conf &
# picom -b  --config ~/.config/arco-chadwm/picom/picom-cachyos.conf &
# picom -b  --config ~/.config/arco-chadwm/picom/picom-edu-dwm.conf &
# picom -b  --config ~/.config/arco-chadwm/picom/picom-edu-nodwm.conf &
# picom -b  --config ~/.config/arco-chadwm/picom/picom-original.conf &
# picom --backend glx --vsync &
run "numlockx on"
run "volctl"
#run "pa-applet"
sxhkd -c ~/.config/arco-chadwm/sxhkd/sxhkdrc &
#you can set wallpapers in themes as well
#feh --bg-fill /usr/share/backgrounds/archlinux/arch-wallpaper.jpg &
#feh --bg-fill /usr/share/backgrounds/arcolinux/arco-wallpaper.jpg &
#feh --bg-fill ~/.config/ohmychadwm/wallpaper/chadwm.jpg &
feh --bg-fill ~/.config/ohmychadwm/wallpaper/chadwm4.jpg &
#feh --randomize --bg-fill /home/erik/Insync/Apps/Wallhaven/*

#run applications from startup
run "insync start"
run "slstatus"
while type ohmychadwm >/dev/null; do ohmychadwm && continue || break; done
