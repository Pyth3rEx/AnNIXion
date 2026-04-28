{ pkgs ? import <nixpkgs> {} }:

pkgs.stdenv.mkDerivation rec {
  pname = "slot-plasma-themes";
  version = "1.0"; # can be a tag or commit hash

  src = pkgs.fetchFromGitHub {
    owner = "L4ki";
    repo = "Slot-Plasma-Themes";
    rev = "4dd93ad62cf47307d85e3a624eacba34578bf1fe";
    url = "https://github.com/L4ki/Slot-Plasma-Themes.git";
    sha256 = "sha256-M2jCyPLPDqhF2KnovRIrsISOECpFgaR4TUI0N++P8ho="; # we'll fix this in next step
  };

  installPhase = ''
    mkdir -p $out/share/plasma/desktoptheme
    cp -r * $out/share/plasma/desktoptheme/
  '';

  meta = with pkgs.lib; {
    description = "A collection of Slot Plasma themes";
    homepage = "https://github.com/L4ki/Slot-Plasma-Themes";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ Pyth3rEx ];
  };
}