# annixion-nixpkgs-cooldown: reapplies this machine's stored nixpkgs
# cooldown pin after a flake update — see scripts/annixion-nixpkgs-cooldown
# and scripts/installer/nixpkgs-pin.sh. Needs network tools and nix itself
# to resolve a release/day-count policy against GitHub and rewrite
# flake.lock; it sources both scripts straight out of the checkout rather
# than a packaged copy, since ~/.dotfiles already is one.
{ pkgs, ... }:

{
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "annixion-nixpkgs-cooldown";
      runtimeInputs = [
        pkgs.curl
        pkgs.jq
        pkgs.git
      ];
      text = builtins.readFile ../scripts/annixion-nixpkgs-cooldown;
    })
  ];
}
