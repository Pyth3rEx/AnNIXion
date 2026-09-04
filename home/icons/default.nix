# AnNIXion operator marks: renders the catalog's drawings into an icon theme.
# Geometry and colour rules live in docs/visual-identity.md.
{ pkgs, lib }:

let
  # Stroke colours per class. Contrast-checked on the #14171D menu ground.
  # The first six say what running the tool does to the target. The last two
  # say what session you are standing in, and only the terminal family uses
  # them; both values are the prompt's (home/zsh/omp-theme.nix:37).
  classColour = {
    passive = "#33E62B";
    probe = "#FFD000";
    offensive = "#FF0033";
    forensic = "#4A90FF";
    reverse = "#F213A0";
    utility = "#7A8494";
    elevated = "#FF0033";
    nixenv = "#7EBAE4";
  };

  catalog = import ../../catalog { inherit lib; };
  inherit (catalog) marks;

  # Marks are drawn on a 24-unit grid, but a round cap or join reaches half a
  # stroke width past the geometry — so a drip that ends on the bottom edge has
  # its tip sliced flat by the viewBox and reads as a cut, not a drawn end.
  # The viewBox is padded by that margin and the stroke scaled to match, so the
  # rendered weight is unchanged and nothing can be clipped.
  # branding/mark-bbox.py enforces both halves of this.
  # pad 1.3 = half the scaled stroke, rounded up; 24 + 2*1.3 = 26.6;
  # 2.1 * 26.6 / 24 = 2.3275, which keeps the apparent weight unchanged.
  vbMin = "-1.3";
  vbSide = "26.6";
  strokeW = "2.3275";

  # Where one symbol crosses another, both are the same colour and the same
  # weight, so the crossing reads as a single blob once the menu draws 22px.
  # An `over` symbol is therefore drawn twice: once wide in the ground colour
  # to cut a gap, then normally on top. On the menu ground the gap is
  # invisible; on the wallpaper it is the dark outline the marks take anyway.
  ground = "#14171D";
  knockoutW = "4.2";

  render =
    name: mark:
    let
      colour = classColour.${mark.class} or (throw "icon ${name}: unknown class ${mark.class}");
      body = builtins.replaceStrings [ "@c@" ] [ colour ] mark.body;
      over = mark.over or "";
      overInk = builtins.replaceStrings [ "@c@" ] [ colour ] over;
      overCut = builtins.replaceStrings [ "@c@" ] [ ground ] over;
      layer = stroke: width: content: ''
        <g fill="none" stroke="${stroke}" stroke-width="${width}" stroke-linecap="round" stroke-linejoin="round">
        ${content}  </g>
      '';
    in
    pkgs.writeText "annixion-${name}.svg" ''
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="${vbMin} ${vbMin} ${vbSide} ${vbSide}" width="24" height="24">
      ${layer colour strokeW body}${
        lib.optionalString (over != "") (layer ground knockoutW overCut + layer colour strokeW overInk)
      }</svg>
    '';

  copies = lib.mapAttrsToList (
    name: mark: "cp ${render name mark} $out/share/icons/AnNIXion/scalable/apps/annixion-${name}.svg"
  ) marks;

  # An application that ships its own .desktop entry asks for the icon name
  # that entry declares, and home/plasma.nix pins those entries on purpose:
  # Plasma matches a window to its launcher by class, and only the stock name
  # resolves. So each of these marks is installed under the stock name too —
  # without it the launcher falls through to an inherited theme.
  #
  # The list lives in the tool's own catalog file, beside the mark it aliases,
  # so an alias cannot outlive the mark it points at.
  aliases = lib.mapAttrs (_: t: t.aliases) (lib.filterAttrs (_: t: t ? aliases) catalog.tools);

  links = lib.concatLists (
    lib.mapAttrsToList (
      name: stock:
      map (s: "ln -s annixion-${name}.svg $out/share/icons/AnNIXion/scalable/apps/${s}.svg") stock
    ) aliases
  );
in
pkgs.runCommand "annixion-icons" { } ''
  mkdir -p $out/share/icons/AnNIXion/scalable/apps
  cat > $out/share/icons/AnNIXion/index.theme <<'EOF'
  [Icon Theme]
  Name=AnNIXion
  Comment=AnNIXion operator marks
  Inherits=Slot-Dark-Icons,breeze-dark,Adwaita,hicolor
  Directories=scalable/apps

  [scalable/apps]
  Size=24
  MinSize=16
  MaxSize=512
  Type=Scalable
  Context=Applications
  EOF
  ${lib.concatStringsSep "\n  " copies}
  ${lib.concatStringsSep "\n  " links}
''
