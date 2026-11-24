# Exec= resolution shared by every surface that lists the kill-chain catalog
# (apps-menu.nix's Plasma menu, hyprland/vicinae.nix's launcher)
let
  term = cmd: "konsole -e ${cmd}";
  # -name sets WM_CLASS so annixion-raise and the task manager can tell this window from a plain Konsole.
  termNamed = wmName: cmd: "konsole -name ${wmName} -e ${cmd}";
  termHold = cmd: ''konsole -e zsh -c "export ANNIXION_NO_BANNER=1; ${cmd}; exec zsh"'';
in
homeDirectory: tool:
let
  # Catalog is data and can't reach config, so an exec needing the home dir says @home@, substituted here.
  cmd = builtins.replaceStrings [ "@home@" ] [ homeDirectory ] tool.exec;
in
{
  gui = cmd;
  term = term cmd;
  hold = termHold cmd;
  named = termNamed tool.wmName cmd;
}
.${tool.launch}
