# user/config/burpsuite.nix
{ pkgs, ... }:

{
  home.packages = [
    (pkgs.burpsuite.override {
      proEdition = true;
    })
  ];
}
