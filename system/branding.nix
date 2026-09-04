# Identity on the surfaces outside the desktop session: boot splash and greeter.
{
  lib,
  pkgs,
  ...
}:

let
  branding = import ../branding { inherit pkgs; };
in
{
  # ── Boot splash ───────────────────────────────────────────────────────────
  # systemd-boot draws a text menu and takes no theme, so the mark's first
  # appearance is Plymouth, once the kernel hands over.
  boot = {
    plymouth = {
      enable = lib.mkDefault true;
      themePackages = [ branding.plymouthTheme ];
      theme = lib.mkDefault "annixion";
    };

    # Without these the kernel's own log scrolls over the splash.
    kernelParams = [
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "udev.log_priority=3"
      "rd.systemd.show_status=auto"
    ];

    # The menu still has to be reachable — a splash that cannot be interrupted
    # is a machine you cannot boot into an older generation.
    loader.timeout = lib.mkDefault 3;
  };

  # ── Greeter ───────────────────────────────────────────────────────────────
  # plasma6.nix also sets this with mkDefault, so mkDefault here is a conflict
  # rather than an override. 900 beats it while still yielding to a plain
  # assignment in user/configuration.nix.
  services.displayManager.sddm.theme = lib.mkOverride 900 "annixion";
  environment.systemPackages = [ branding.sddmTheme ];
}
