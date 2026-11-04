# annixion-config-doctor: the installer's own validation, pointed at this
# machine's ~/.dotfiles — see scripts/annixion-config-doctor. Needs nix
# itself only; it sources scripts/installer/validate.sh straight out of the
# checkout rather than a packaged copy, since ~/.dotfiles already is one.
{ pkgs, ... }:

{
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "annixion-config-doctor";
      text = builtins.readFile ../scripts/annixion-config-doctor;
    })
  ];
}
