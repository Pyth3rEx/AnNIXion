# A dynamic loader at the path every prebuilt Linux binary hardcodes.
# AppImages, vendor tarballs and language-toolchain downloads all ship an
# interpreter of /lib64/ld-linux-x86-64.so.2, which NixOS does not have (#172).
{
  pkgs,
  ...
}:

{
  programs.nix-ld = {
    enable = true;

    # Added to the loader's own defaults, which already cover zlib, openssl,
    # curl and the rest of the systemd/nix closure. These are the ones a GUI
    # binary dlopens at run time: invisible to ldd, so the failure they cause
    # arrives as a missing symbol long after the loader has done its job.
    libraries = with pkgs; [
      xorg.libX11
      xorg.libXcursor
      xorg.libXrandr
      xorg.libXi
      xorg.libXext
      xorg.libXrender
      xorg.libXfixes
      xorg.libxcb
      libxkbcommon
      wayland
      libglvnd
      dbus
    ];
  };
}
