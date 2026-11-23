# Single source of truth for color palette of the DE
{ lib, config, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.annixion.desktop.hyprland.palette;

  toByteHex = n: lib.fixedWidthString 2 "0" (lib.toLower (lib.toHexString n));
  clampByte =
    n:
    if n < 0 then
      0
    else if n > 255 then
      255
    else
      n;
  channel = hex: offset: lib.fromHexString (lib.substring offset 2 hex);

  # pctA% of `a` mixed with the rest of `b` — the primitive behind shade/tint.
  mix =
    a: b: pctA:
    let
      m =
        offset:
        clampByte (builtins.floor ((channel a offset * pctA + channel b offset * (100 - pctA)) / 100));
    in
    toByteHex (m 0) + toByteHex (m 2) + toByteHex (m 4);
in
{
  options.annixion.desktop.hyprland.palette = {
    ground = mkOption {
      type = types.str;
      default = "0a0a09";
      description = "Deepest ground — base background.";
    };
    surface = mkOption {
      type = types.str;
      default = "121110";
      description = "Raised surface.";
    };
    rootGround = mkOption {
      type = types.str;
      default = "301212";
      description = "Root / elevated-session ground.";
    };
    wallGround = mkOption {
      type = types.str;
      default = "000000";
      description = "Pure-black wallpaper ground.";
    };
    menuGround = mkOption {
      type = types.str;
      default = "14171d";
      description = "Launcher/menu ground, also the crossing-symbol knockout colour.";
    };
    accent = mkOption {
      type = types.str;
      default = "ff0033";
      description = "The signature accent — the one rare saturated hit.";
    };
    text = mkOption {
      type = types.str;
      default = "edeae2";
      description = "Primary text — bone, not pure white.";
    };

    passive = mkOption {
      type = types.str;
      default = "33e62b";
      description = "Semantic class: passive tools.";
    };
    probe = mkOption {
      type = types.str;
      default = "ffd000";
      description = "Semantic class: probe tools.";
    };
    offensive = mkOption {
      type = types.str;
      default = "ff0033";
      description = "Semantic class: offensive tools — same value as accent.";
    };
    forensic = mkOption {
      type = types.str;
      default = "4a90ff";
      description = "Semantic class: forensic tools, stroke weight.";
    };
    forensicFill = mkOption {
      type = types.str;
      default = "0f5ae6";
      description = "Semantic class: forensic tools, large fills.";
    };
    reverse = mkOption {
      type = types.str;
      default = "f213a0";
      description = "Semantic class: reverse-engineering tools.";
    };
    utility = mkOption {
      type = types.str;
      default = "7a8494";
      description = "Semantic class / session: utility — the operator's own shell.";
    };
    nixSession = mkOption {
      type = types.str;
      default = "7ebae4";
      description = "Session colour: inside nix develop / nix-shell.";
    };
  };

  config._module.args = {
    # String composition against the palette above — never a new literal
    # hex. shade/tint are mix() toward black/white, the same operations
    # GTK CSS's own shade()/tint()/mix() give the waybar/wofi side.
    annixionColors = rec {
      hex = c: "#${c}";
      rgb = c: "rgb(${c})";
      alpha = c: pct: "${c}${toByteHex (clampByte (builtins.floor (pct * 255 / 100)))}";
      rgba = c: pct: "rgba(${alpha c pct})";
      shade = c: pct: mix c "000000" (100 - pct);
      tint = c: pct: mix c "ffffff" (100 - pct);
    };

    annixionCssPrelude = ''
      /* tokens/colors.css — generated from annixion.desktop.hyprland.palette (../../palette.nix) */
      @define-color ground #${cfg.ground};
      @define-color surface #${cfg.surface};
      @define-color root_ground #${cfg.rootGround};
      @define-color wall_ground #${cfg.wallGround};
      @define-color menu_ground #${cfg.menuGround};
      @define-color accent #${cfg.accent};
      @define-color text #${cfg.text};
      @define-color passive #${cfg.passive};
      @define-color probe #${cfg.probe};
      @define-color offensive #${cfg.offensive};
      @define-color forensic #${cfg.forensic};
      @define-color forensic_fill #${cfg.forensicFill};
      @define-color reverse #${cfg.reverse};
      @define-color utility #${cfg.utility};
      @define-color nix_session #${cfg.nixSession};
    '';
  };
}
