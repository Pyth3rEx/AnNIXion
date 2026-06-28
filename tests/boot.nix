{
  name = "annixion-boot";

  nodes.machine = { pkgs, lib, ... }: {
    networking.networkmanager.enable = true;

    services.openssh = {
      enable = true;
      settings.PasswordAuthentication = true;
    };

    programs.zsh.enable = true;
    security.sudo.wheelNeedsPassword = true;

    users.users.operator = {
      isNormalUser = true;
      password = "test";
      extraGroups = [ "wheel" "networkmanager" "video" "input" ];
      shell = pkgs.zsh;
    };

    virtualisation.memorySize = 512;
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # User account and group membership
    machine.succeed("id operator")
    machine.succeed("groups operator | grep -q wheel")
    machine.succeed("groups operator | grep -q networkmanager")

    # Core services
    machine.wait_for_unit("NetworkManager.service")
    machine.wait_for_unit("sshd.service")
    machine.succeed("systemctl is-active NetworkManager")
    machine.succeed("systemctl is-active sshd")

    # Shell
    machine.succeed("which zsh")
  '';
}