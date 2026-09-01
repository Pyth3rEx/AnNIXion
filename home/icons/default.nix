# AnNIXion operator marks: renders home/icons/marks.nix into an icon theme.
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

  marks = import ./marks.nix;

  render =
    name: mark:
    let
      colour = classColour.${mark.class} or (throw "icon ${name}: unknown class ${mark.class}");
      body = builtins.replaceStrings [ "@c@" ] [ colour ] mark.body;
    in
    pkgs.writeText "annixion-${name}.svg" ''
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24">
        <g fill="none" stroke="${colour}" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round">
      ${body}  </g>
      </svg>
    '';

  copies = lib.mapAttrsToList (
    name: mark: "cp ${render name mark} $out/share/icons/AnNIXion/scalable/apps/annixion-${name}.svg"
  ) marks;
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
''
