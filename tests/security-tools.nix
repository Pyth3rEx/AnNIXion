{
  name = "annixion-security-tools";

  nodes.machine = { pkgs, lib, ... }: {
    imports = [ ../modules/security-tools.nix ];

    users.users.operator = {
      isNormalUser = true;
      password = "test";
    };

    # Extra RAM for the large security tool closure
    virtualisation.memorySize = 2048;
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Network scanning / recon
    machine.succeed("which nmap")
    machine.succeed("which nc")
    machine.succeed("which openssl")

    # Web
    machine.succeed("which ffuf")
    machine.succeed("which gobuster")
    machine.succeed("which sqlmap")
    machine.succeed("which whatweb")

    # Auth / credential attacks
    machine.succeed("which john")
    machine.succeed("which hashcat")
    machine.succeed("which hydra")

    # Wireless / RF
    machine.succeed("which aircrack-ng")

    # Firmware / reverse engineering
    machine.succeed("which binwalk")
    machine.succeed("which ghidra")

    # Post-exploitation
    machine.succeed("which msfconsole")
    machine.succeed("which burpsuite")

    # OSINT
    machine.succeed("which whois")
    machine.succeed("which dig")
    machine.succeed("which theHarvester")
  '';
}
