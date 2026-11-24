# annixion-kill-chain — a Vicinae extension replacing the rofi picklist this
# started as (#223 follow-up). Vicinae's own component model (List.Section +
# a read-only detail pane, screens pushed with a back breadcrumb) is the
# closest thing on Wayland to Plasma's Kickoff, so the kill-chain tree is
# rendered there instead of reinventing its chrome. The extension itself
# (../../../vicinae-extension) is generic — it just renders whatever tree
# JSON it's given — so this file's only job is turning catalog/ into that
# tree, byte-identical in content to apps-menu.nix's XDG menu.
{
  config,
  lib,
  pkgs,
  annixionColors,
  ...
}:

let
  palette = config.annixion.desktop.hyprland.palette;
  catalog = import ../../../catalog { inherit lib; };
  resolveExec = import ../menu-lib.nix config.home.homeDirectory;

  iconsDir = "${config.home.homeDirectory}/.local/share/icons/AnNIXion/scalable/apps";
  iconPath = markName: "${iconsDir}/annixion-${markName}.svg";

  toolJson = key: tool: {
    id = tool.path + "/" + key;
    inherit (tool) name;
    genericName = tool.genericName or null;
    comment = tool.comment or null;
    markClass = tool.mark.class;
    icon = iconPath key;
    exec = resolveExec tool;
  };

  # A node is a container or a leaf with tools, never both (catalog/default.nix).
  nodeJson = n: {
    id = n.path;
    inherit (n) label;
    markClass = n.mark.class;
    icon = iconPath n.mark.name;
    children = map nodeJson n.children;
    tools = lib.mapAttrsToList toolJson n.tools;
  };

  killChain = lib.filter (n: n.order <= 10) catalog.menu;
  misc = lib.filter (n: n.order > 10) catalog.menu;

  treeJson = pkgs.writeText "annixion-kill-chain.json" (
    builtins.toJSON {
      phases = map nodeJson killChain;
      other = map nodeJson misc;
    }
  );

  # Themed from the same palette as the rest of the Hyprland desktop (palette.nix)
  hexq = c: ''"${annixionColors.hex c}"'';

  # Vicinae's theme colours use Qt's #AARRGGBB order (alpha first, unlike the
  # CSS #RRGGBBAA the rest of the desktop's GTK-CSS prelude uses)
  hexaq =
    pctAlpha: c:
    let
      byte = lib.fixedWidthString 2 "0" (
        lib.toLower (lib.toHexString (builtins.floor (pctAlpha * 255 / 100)))
      );
    in
    ''"#${byte}${c}"'';

  theme = pkgs.writeText "annixion-dark.toml" ''
    [meta]
    name = "AnNIXion Dark"
    description = "AnNIXion's red-on-Nord chrome"
    variant = "dark"
    inherits = "vicinae-dark"

    [colors.core]
    accent = ${hexq palette.accent}
    accent_foreground = ${hexq palette.text}
    background = ${hexaq 78 palette.ground}
    foreground = ${hexq palette.text}
    secondary_background = ${hexaq 85 palette.surface}
    # waybar/tokens/glass.css's "glass pane" edge is a soft 1px CSS inset
    # shadow at alpha(@text, 0.16) — blurred and anti-aliased by GTK, so it
    # reads as a whisper. Vicinae's border is a hard, unblurred stroke at
    # the same width, so the same alpha reads far stronger here; dropped
    # well below it to land at the same visual weight.
    border = ${hexaq 8 palette.text}

    [colors.main_window]
    border = ${hexaq 8 palette.text}

    [colors.accents]
    blue = ${hexq palette.forensic}
    green = ${hexq palette.passive}
    magenta = ${hexq palette.reverse}
    orange = ${hexq palette.probe}
    red = ${hexq palette.offensive}
    yellow = ${hexq palette.probe}
    cyan = ${hexq palette.nixSession}
    purple = ${hexq palette.reverse}

    [colors.list.item.selection]
    background = ${hexaq 85 (annixionColors.tint palette.surface 20)}
    foreground = ${hexq palette.text}
    secondary_background = ${hexaq 85 (annixionColors.tint palette.surface 20)}
    secondary_foreground = ${hexq palette.text}
  '';

  settings = pkgs.writeText "vicinae-settings.json" (
    builtins.toJSON {
      theme = {
        dark.name = "annixion-dark";
        light.name = "annixion-dark";
      };
      font.normal = {
        size = 12;
        family = "JetBrains Mono";
      };
      activate_on_single_click = true;
      launcher_window = {
        # 0.95 (the earlier value) is nearly indistinguishable from fully
        # opaque — `vicinae config default`'s own example is 0.6. Picked 0.75
        # as a middle ground: visibly translucent without the readability
        # problems reported at very low opacity (vicinaehq/vicinae#2097).
        opacity = 0.75;
        blur.enabled = true;
        # "auto" would pick liquid_glass via ext-background-effect, but that
        # protocol only landed in Hyprland 0.56.0 — this flake's pinned to
        # 0.55.4, so force the compositor-blur path instead of trusting
        # auto-detection to fall back cleanly.
        material = "blur";
        rounding = 18; # waybar's own capsules round this hard (tokens/widget.css's border-radius: 20px)
      };
      # Pinned to the top of the root search's empty-query view
      favorites = [ "@annixion/annixion-kill-chain:kill-chain" ];
    }
  );

  extension = pkgs.buildNpmPackage {
    pname = "annixion-kill-chain";
    version = "0.1.0";
    src = ../../../vicinae-extension;
    npmDepsHash = "sha256-9sc5irQ9xW+bM4guJ65udWttS2OgiSHc33ohpAT4mCM=";
    dontNpmBuild = true;
    buildPhase = ''
      runHook preBuild
      node_modules/.bin/vici build -o "$out"
      runHook postBuild
    '';
    installPhase = "true";
  };
in
{
  home.packages = [ pkgs.vicinae ];

  wayland.windowManager.hyprland.settings = {
    layerrule = [
      {
        name = "vicinae-blur";
        blur = "on";
        # on (Hyprland's default) means the blur only ever reveals the
        # wallpaper/bottom layers, never real windows — off shows the
        # actual desktop through it.
        xray = "off";
        ignore_alpha = 0;
        "match:namespace" = "vicinae";
      }
      {
        name = "vicinae-no-animation";
        no_anim = "on";
        "match:namespace" = "vicinae";
      }
    ];
    misc.focus_on_activate = true;
  };

  home.file = {
    ".local/share/annixion/kill-chain.json".source = treeJson;
    ".local/share/vicinae/themes/annixion-dark.toml".source = theme;
    ".local/share/vicinae/extensions/annixion-kill-chain".source = extension;
    ".config/vicinae/settings.json".source = settings;
  };

  home.activation.restartVicinae = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD systemctl --user try-restart vicinae.service 2>/dev/null || true
  '';

  systemd.user.services.vicinae = {
    Unit = {
      Description = "Vicinae launcher server";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.vicinae}/bin/vicinae server";
      Restart = "on-failure";
      RestartSec = "3s";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
