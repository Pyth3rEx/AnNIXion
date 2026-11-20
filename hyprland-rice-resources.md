Hyprland ricing — resources to browse
======================================

OFFICIAL DOCS (syntax/options for binds.nix, workspace.nix, etc.)
-------------------------------------------------------------------
Hyprland Wiki
  https://wiki.hypr.land/
Hyprland Wiki — Configuring Basics
  https://wiki.hypr.land/0.56.0/Configuring/Basics/
(hyprpaper, hyprlock, hypridle, hyprcursor wikis are linked from the
Hyprland Wiki sidebar under "Hypr Ecosystem")

CURATED DOTFILE GALLERIES (finished waybar CSS / hyprlock layouts / anims)
-------------------------------------------------------------------
r/unixporn — search "Hyprland", posts usually link a dotfiles repo
  https://reddit.com/r/unixporn

GitHub topic: hyprland-dotfiles
  https://github.com/topics/hyprland-dotfiles
GitHub topic: hyprland-rice
  https://github.com/topics/hyprland-rice?l=css

Nabeel3770/dotfiles — simple, readable baseline (waybar/wofi/hyprlock/wlogout)
  https://github.com/Nabeel3770/dotfiles
Kernel236/my-hyprland-dotfiles — dual-theme switching example
  https://github.com/Kernel236/my-hyprland-dotfiles
VicMeGa/Hypr-Dotfiles — minimal rice, hyprpaper/hyprlock
  https://github.com/VicMeGa/Hypr-Dotfiles
nickyeganeh/hyprland-dotfiles — waybar modules (media, weather, etc.)
  https://github.com/nickyeganeh/hyprland-dotfiles

NIX-SPECIFIC (this stack is home-manager options, not raw config files)
-------------------------------------------------------------------
Stylix — Hyprland module (one base16 palette -> hyprland/hyprpaper/
hyprlock/waybar/GTK via home-manager)
  https://nix-community.github.io/stylix/options/modules/hyprland.html
FinnPL/NixOS-Configuration — Stylix + Hyprland + Quickshell, flakes/home-manager
  https://github.com/FinnPL/NixOS-Configuration

COLOR / PALETTE GENERATION
-------------------------------------------------------------------
pywal and wallust — generate a palette from a wallpaper image, feed the
hex values into waybar CSS vars or a Stylix base16 scheme instead of
hand-picking colors.

NOTE TO SELF
-------------------------------------------------------------------
Dotfile-gallery configs are plain files (~/.config/waybar/style.css).
In this repo those become Nix strings: programs.waybar.style,
programs.hyprlock.settings, etc. Paste found CSS/hyprlock.conf content
into user/home.nix as a multi-line Nix string, not as a standalone file.

Personal rice goes in user/home.nix (never committed, wins over every
mkDefault in home/desktop/hyprland/*.nix with no lib.mkForce needed).
Shared/base AnNIXion changes go in home/desktop/hyprland/*.nix and must
follow docs/visual-identity.md's palette and motif rules.
