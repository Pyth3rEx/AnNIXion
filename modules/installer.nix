{ config, pkgs, lib, ... }:

with lib;

{
  options.annixion.installer = {
    enable = mkEnableOption "AnNIXion TUI installer" // { default = false; };
    
    includeTools = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Development and installation tools to include in the installer environment";
      example = [ "cryptsetup" "btrfs-progs" "parted" ];
    };
  };

  config = mkIf config.annixion.installer.enable {
    # Ensure installer is available in root's PATH
    environment.systemPackages = with pkgs; [
      # TUI and user interaction
      whiptail
      dialog
      
      # Disk and filesystem tools
      parted
      cryptsetup
      btrfs-progs
      dosfstools
      efibootmgr
      
      # NixOS tools
      nix
      nixos-install-tools
      
      # Utilities
      curl
      wget
      git
      htop
      lsblk
      coreutils
      util-linux
      
      # Locale and fonts
      glibc
      console_fonts
    ];
    
    # Copy installer scripts into the live environment
    systemd.tmpfiles.rules = [
      "d /usr/local/bin 0755 root root -"
      "d /usr/local/lib/annixion 0755 root root -"
    ];
    
    # Installation-specific environment
    environment.variables = {
      ANNIXION_INSTALLER = "1";
    };
    
    # Create installer commands
    environment.shellAliases = {
      annixion-install = "bash /usr/local/bin/annixion-install.sh";
    };
    
    # Disable graphical environment during installation
    services.xserver.enable = mkForce false;
    
    # Use a simple terminal environment for installation
    services.getty.helpLine = ''
      Welcome to the AnNIXion Live Environment
      
      To start the installer, run:
        annixion-install
      
      For manual installation or troubleshooting:
        bash
      
      Documentation available at:
        https://github.com/Pyth3rEx/AnNIXion
    '';
    
    # Kernel parameters for installation
    boot.kernelParams = [
      "quiet"
      "loglevel=3"
    ];
    
    # Enable networking for installation
    networking.wireless.enable = mkForce false;
    networking.useDHCP = true;
    
    # Ensure minimal services
    services.openssh.enable = mkForce false;
    
    # System state version for reproducibility
    system.stateVersion = "24.05";
  };
}
