# ohmychadwm

A fully configured, keyboard-driven X11 desktop built on top of **dwm** (Dynamic Window Manager).
Inspired by [omarchy](https://github.com/basecamp/omarchy) (Wayland/Hyprland) — ported to X11.

---

## What is this?

`ohmychadwm` is a complete desktop environment configuration, not just a window manager.

We install it on the KIRO ISO to be found on Sourceforge.

It combines:

| Component | Role |
| --- | --- |
| **ohmychadwm** (patched dwm) | Tiling window manager — manages windows |
| **slstatus** | Status bar — shows time, CPU, RAM, network etc. |
| **sxhkd** | Keybinding daemon — Super/Ctrl/Alt shortcuts |
| **rofi** | App launcher + hierarchical system menu |
| **picom / fastcompmgr** | Compositor — transparency, shadows |
| **feh** | Wallpaper manager |
| **alacritty** | Terminal emulator |

---

## Requirements

```bash
# Core (required)
sudo pacman -S base-devel libx11 libxft libxinerama imlib2 \
               rofi feh sxhkd alacritty picom notify-send xclip \
               maim slop fzf btop ncdu inxi lm_sensors

# Fonts — install at least one Nerd Font
yay -S ttf-jetbrains-mono-nerd

# Optional but recommended
sudo pacman -S redshift xautolock numlockx volctl flameshot \
               nm-applet xfce4-power-manager blueberry
```

---

## Install & Start

```bash
git clone https://github.com/erikdubois/ohmychadwm ~/.config/ohmychadwm
cd ~/.config/ohmychadwm/chadwm
sudo make install
```

### With startx

```bash
startx ~/.config/ohmychadwm/scripts/run.sh
```

### With a display manager (SDDM, LightDM, GDM)

Create `/usr/share/xsessions/ohmychadwm.desktop`:

```ini
[Desktop Entry]
Name=ohmychadwm
Comment=dwm made beautiful
Exec=/home/YOUR_USER/.config/ohmychadwm/scripts/run.sh
Type=Application
```

Replace `YOUR_USER` with your username.

---

## Rebuild after config changes

Any change to `chadwm/config.def.h` or a theme file requires a recompile:

```bash
cd ~/.config/ohmychadwm/chadwm
./rebuild.sh
```

The rebuild script copies `config.def.h` → `config.h`, compiles, installs, and restarts the WM.

---

## Key bindings (most important)

| Key | Action |
| --- | --- |
| `Super + Enter` | Open terminal |
| `Super + Shift + Enter` | Open thunar |
| `Super + 1..9` | Switch to tag/workspace |
| `Super + Shift + Q` | Quit window |
| `Super + Shift + R` | Restart ohmychadwm (reload config) |
| `Super + Alt + Space` | Open ohmychadwm system menu |
| `Super + D` | Open rofi app launcher |

Full keybinding list: open the menu → Learn → Keybindings.

---

## Themes

Themes are `.h` files in `chadwm/themes/`. Activating one requires a rebuild.

### Switch theme via menu

`Style → ohmychadwm → Theme`

### Switch theme manually

Edit `chadwm/config.def.h` — uncomment the theme you want:

```c
//#include "themes/catppuccin.h"
#include "themes/dracula.h"      // ← active theme
//#include "themes/nord.h"
```

Then run `./rebuild.sh`.

### Create your own theme

```bash
~/.config/ohmychadwm/scripts/generate-chadwm-theme.sh
```

The script extracts colors from your current wallpaper and generates a complete `.h` theme file.

### Theme parameters

Each theme `.h` file can define these values (all have sensible defaults if omitted):

| Parameter | Default | Description |
| --- | --- | --- |
| `THEME_TOPBAR` | `1` | Bar position: 1 = top, 0 = bottom |
| `THEME_GAPS` | `5` | Gap size between windows (px) |
| `THEME_BORDER` | `2` | Window border width (px) |
| `THEME_AUTOHIDE` | `0` | Auto-hide bar after N seconds (0 = off) |
| `THEME_SHOWSYSTRAY` | `1` | Show system tray: 1 = yes, 0 = no |
| `THEME_SMARTGAPS` | `0` | Remove gaps with single window: 1 = yes |
| `THEME_MFACT` | `0.50` | Master area width (0.10–0.90) |
| `THEME_NMASTER` | `1` | Number of windows in master area |
| `THEME_FONT` | JetBrainsMono 13 | Bar font (Fontconfig string) |

The `SchemeMenufg` color from the active theme is automatically synced to the rofi menu accent color (`ac:` in `ohmychadwm-menu.rasi`) when you switch themes.

---

## System Menu

Open with `Super + Alt + Space`.

```
ohmychadwm
├── Apps          — rofi app launcher
├── Style
│   ├── ohmychadwm  — theme, tags, gaps, border, font …
│   ├── Alacritty   — terminal color scheme
│   ├── Wallpaper   — browse and set wallpapers
│   ├── Slstatus    — toggle bar modules
│   ├── Picom       — compositor config
│   └── Menu theme  — edit the rofi menu theme
├── Learn         — keybindings, Arch Wiki, Fish, Bash, man pages
├── Trigger
│   ├── Capture     — screenshot, region, screen record, color picker
│   ├── Share       — LocalSend file/folder/clipboard sharing
│   └── Toggle      — night light, auto-lock
├── Setup         — sxhkd, slstatus config
├── Install       — apps, browser, dev tools, AI tools, fonts, gaming
├── Remove        — packages, dev environments
├── Update        — system, AUR, full update, keyboard layout, time sync
├── Info
│   ├── System      — inxi full hardware info
│   ├── Processes   — btop process manager
│   ├── Disk overview — df sorted
│   ├── Disk explorer — ncdu interactive
│   ├── Temperatures  — lm_sensors
│   ├── Battery     — upower battery info (laptops)
│   └── Logs        — journalctl / dmesg viewer
└── System        — lock, suspend, restart, shutdown
```

### Extending the menu

Edit `menu/menu-extension.sh` to override any built-in menu function or add new ones.
The extension file is sourced automatically at startup.

---

## Status bar (slstatus)

Edit which modules are shown in `slstatus/config.def.h` — uncomment any block (CPU, RAM, network speed, etc.), then rebuild:

```bash
cd ~/.config/ohmychadwm/slstatus && ./rebuild.sh
```

The status text color comes from `SchemeNormfg` in the active theme.

---

## Autostart apps

Edit `scripts/run.sh`. Add your app with the `run` helper so it only starts once:

```sh
run "your-application"
```

---

## Patches included

| Patch | Effect |
| --- | --- |
| vanity gaps | Configurable inner/outer gaps |
| barpadding | Padding inside the bar |
| status2d | Per-block colors in the status bar |
| colorful tags | Each tag gets its own color |
| winicon | Window icons in the title bar |
| tag preview | Hover a tag to preview its windows |
| movestack | Move windows up/down in the stack |
| fibonacci | Fibonacci tiling layout |
| gaplessgrid | Grid layout without gaps |
| bottomstack | Stack below master |
| preserveonrestart | Windows stay on their tags after restart |
| dragmfact | Drag the master area border with mouse |

---

## Directory structure

```
~/.config/ohmychadwm/
├── chadwm/               # Window manager source + build
│   ├── config.def.h      # Main WM configuration (edit this)
│   ├── themes/           # Color themes (.h files)
│   ├── rebuild.sh        # Recompile + reinstall + restart
│   └── dwm.c             # Core WM source (rarely needs editing)
├── scripts/
│   ├── run.sh            # Session startup — autostart apps here
│   ├── generate-chadwm-theme.sh  # Create themes from wallpaper
│   └── show-keybindings.sh       # Display all keybindings
├── menu/
│   ├── ohmychadwm-menu.sh        # Hierarchical system menu
│   ├── ohmychadwm-menu.rasi      # Rofi theme for the menu
│   └── menu-extension.sh         # User overrides / additions
├── slstatus/             # Status bar source + config
│   ├── config.def.h      # Enable/disable bar modules here
│   └── rebuild.sh        # Recompile slstatus
├── sxhkd/
│   └── sxhkdrc           # All keyboard shortcuts
├── rofi/                 # App launcher themes
├── picom/                # Compositor configs
├── alacritty/            # Terminal themes (230+)
└── wallpapers/           # Wallpaper images
```

---

## License

MIT/X Consortium License — see [LICENSE](LICENSE).
Originally from [suckless.org/dwm](https://dwm.suckless.org) © Anselm R Garbe and contributors.

---

## Credits & Inspirations

| Project | What we took from it |
| --- | --- |
| [dwm](https://dwm.suckless.org) | The window manager this is built on |
| [chadwm](https://github.com/siduck/chadwm) by siduck | Original patched dwm base, themes, status2d coloring |
| [omarchy](https://github.com/basecamp/omarchy) by Basecamp | Menu system design, workflow philosophy, script structure |
| [dusk](https://github.com/bakkeby/dusk) by bakkeby | Patch reference, dragcfact implementation |
| [rofi themes](https://github.com/adi1090x/rofi) by Aditya Shakya | launcher2.rasi base design |
| [suckless slstatus](https://tools.suckless.org/slstatus/) | Status bar |
