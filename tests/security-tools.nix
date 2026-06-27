{
  name = "annixion-security-tools";

  nodes.machine = { pkgs, lib, ... }: {
    imports = [ ../modules/security-tools.nix ];

    nixpkgs.config.allowUnfree = true;

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
    machine.succeed("nmap --version")
    machine.succeed("nc -h 2>&1 | head -1")
    machine.succeed("openssl version")

    # Web
    machine.succeed("ffuf -V 2>&1 | grep -qi ffuf")
    machine.succeed("which gobuster")
    machine.succeed("which sqlmap")
    machine.succeed("whatweb --version")

    # Auth / credential attacks
    machine.succeed("john --list=formats 2>&1 | head -1")
    machine.succeed("hashcat --version 2>&1 | head -1")
    machine.succeed("hydra -h 2>&1 | grep -qi hydra")

    # Wireless / RF
    machine.succeed("aircrack-ng --help 2>&1 | head -3")

    # Firmware / reverse engineering
    machine.succeed("binwalk --help 2>&1 | head -1")
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