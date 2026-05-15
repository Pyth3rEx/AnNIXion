{ config, lib, pkgs, ... }:

let
  term     = cmd: "konsole -e ${cmd}";
  termHold = cmd: ''konsole -e bash -c "${cmd}; exec bash"'';
  dir      = name: icon: ''
    [Desktop Entry]
    Name=${name}
    Type=Directory
    Icon=${icon}
  '';
in {

  # ============================================================
  # XDG MENU — KILL CHAIN STRUCTURE
  # Merged into the system Applications menu at:
  #   ~/.config/menus/applications-merged/annixion.menu
  # ============================================================

  home.file.".config/menus/applications-merged/annixion.menu" = lib.mkDefault {
    text = ''
      <!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
        "http://www.freedesktop.org/standards/menu-spec/menu-1.0.dtd">
      <Menu>
        <Name>Applications</Name>
        <Menu>
          <Name>AnNIXion</Name>
          <Directory>annixion.directory</Directory>

          <Menu>
            <Name>1. Reconnaissance</Name>
            <Directory>annixion-1-recon.directory</Directory>
            <Menu>
              <Name>Passive OSINT</Name>
              <Directory>annixion-1-recon-osint.directory</Directory>
              <Include><Category>X-AnNIXion-Recon-OSINT</Category></Include>
            </Menu>
            <Menu>
              <Name>Active Scanning</Name>
              <Directory>annixion-1-recon-scanning.directory</Directory>
              <Include><Category>X-AnNIXion-Recon-Scanning</Category></Include>
            </Menu>
            <Menu>
              <Name>RF / Signal Intel</Name>
              <Directory>annixion-1-recon-rf.directory</Directory>
              <Include><Category>X-AnNIXion-Recon-RF</Category></Include>
            </Menu>
          </Menu>

          <Menu>
            <Name>2. Weaponization</Name>
            <Directory>annixion-2-weapon.directory</Directory>
            <Menu>
              <Name>Disassembly</Name>
              <Directory>annixion-2-weapon-disasm.directory</Directory>
              <Include><Category>X-AnNIXion-Weapon-Disasm</Category></Include>
            </Menu>
            <Menu>
              <Name>Firmware Analysis</Name>
              <Directory>annixion-2-weapon-firmware.directory</Directory>
              <Include><Category>X-AnNIXion-Weapon-Firmware</Category></Include>
            </Menu>
          </Menu>

          <Menu>
            <Name>3. Delivery</Name>
            <Directory>annixion-3-delivery.directory</Directory>
            <Menu>
              <Name>Web Proxy</Name>
              <Directory>annixion-3-delivery-proxy.directory</Directory>
              <Include><Category>X-AnNIXion-Delivery-Proxy</Category></Include>
            </Menu>
            <Menu>
              <Name>Web Injection</Name>
              <Directory>annixion-3-delivery-injection.directory</Directory>
              <Include><Category>X-AnNIXion-Delivery-Injection</Category></Include>
            </Menu>
          </Menu>

          <Menu>
            <Name>4. Exploitation</Name>
            <Directory>annixion-4-exploit.directory</Directory>
            <Menu>
              <Name>Frameworks</Name>
              <Directory>annixion-4-exploit-frameworks.directory</Directory>
              <Include><Category>X-AnNIXion-Exploit-Frameworks</Category></Include>
            </Menu>
            <Menu>
              <Name>Credential Attacks</Name>
              <Directory>annixion-4-exploit-creds.directory</Directory>
              <Include><Category>X-AnNIXion-Exploit-Creds</Category></Include>
            </Menu>
            <Menu>
              <Name>Wireless</Name>
              <Directory>annixion-4-exploit-wireless.directory</Directory>
              <Include><Category>X-AnNIXion-Exploit-Wireless</Category></Include>
            </Menu>
          </Menu>

          <Menu>
            <Name>5. Installation</Name>
            <Directory>annixion-5-install.directory</Directory>
            <Menu>
              <Name>Tunneling &amp; Shells</Name>
              <Directory>annixion-5-install-tunneling.directory</Directory>
              <Include><Category>X-AnNIXion-Install-Tunneling</Category></Include>
            </Menu>
          </Menu>

          <Menu>
            <Name>6. C2</Name>
            <Directory>annixion-6-c2.directory</Directory>
            <Menu>
              <Name>Frameworks</Name>
              <Directory>annixion-6-c2-frameworks.directory</Directory>
              <Include><Category>X-AnNIXion-C2-Frameworks</Category></Include>
            </Menu>
          </Menu>

          <Menu>
            <Name>7. Post-Exploitation</Name>
            <Directory>annixion-7-postex.directory</Directory>
            <Menu>
              <Name>Lateral Movement</Name>
              <Directory>annixion-7-postex-lateral.directory</Directory>
              <Include><Category>X-AnNIXion-PostEx-Lateral</Category></Include>
            </Menu>
          </Menu>

          <Menu>
            <Name>8. Forensics</Name>
            <Directory>annixion-8-forensics.directory</Directory>
            <Menu>
              <Name>Memory Analysis</Name>
              <Directory>annixion-8-forensics-memory.directory</Directory>
              <Include><Category>X-AnNIXion-Forensics-Memory</Category></Include>
            </Menu>
            <Menu>
              <Name>Disk Analysis</Name>
              <Directory>annixion-8-forensics-disk.directory</Directory>
              <Include><Category>X-AnNIXion-Forensics-Disk</Category></Include>
            </Menu>
          </Menu>

          <Menu>
            <Name>9. Reverse Engineering</Name>
            <Directory>annixion-9-re.directory</Directory>
            <Menu>
              <Name>Disassemblers</Name>
              <Directory>annixion-9-re-disasm.directory</Directory>
              <Include><Category>X-AnNIXion-RE-Disasm</Category></Include>
            </Menu>
            <Menu>
              <Name>Firmware</Name>
              <Directory>annixion-9-re-firmware.directory</Directory>
              <Include><Category>X-AnNIXion-RE-Firmware</Category></Include>
            </Menu>
          </Menu>

          <Menu>
            <Name>10. Sniffing &amp; Analysis</Name>
            <Directory>annixion-10-sniffing.directory</Directory>
            <Include><Category>X-AnNIXion-Sniffing</Category></Include>
          </Menu>

          <Menu>
            <Name>Internet</Name>
            <Directory>annixion-internet.directory</Directory>
            <Include><Category>X-AnNIXion-Internet</Category></Include>
          </Menu>

          <Menu>
            <Name>Development</Name>
            <Directory>annixion-dev.directory</Directory>
            <Include><Category>X-AnNIXion-Dev</Category></Include>
          </Menu>

          <Menu>
            <Name>Utilities</Name>
            <Directory>annixion-utils.directory</Directory>
            <Include><Category>X-AnNIXion-Utils</Category></Include>
          </Menu>

          <Menu>
            <Name>System</Name>
            <Directory>annixion-system.directory</Directory>
            <Include><Category>X-AnNIXion-System</Category></Include>
          </Menu>

        </Menu>
      </Menu>
    '';
  };

  # ============================================================
  # DIRECTORY FILES — category labels & icons
  # Written to ~/.local/share/desktop-directories/
  # ============================================================

  xdg.dataFile = lib.mkDefault {
    "desktop-directories/annixion.directory".text                      = dir "AnNIXion"                "security-high";

    "desktop-directories/annixion-1-recon.directory".text              = dir "1. Reconnaissance"       "system-search";
    "desktop-directories/annixion-1-recon-osint.directory".text        = dir "Passive OSINT"            "applications-internet";
    "desktop-directories/annixion-1-recon-scanning.directory".text     = dir "Active Scanning"          "network-wired";
    "desktop-directories/annixion-1-recon-rf.directory".text           = dir "RF / Signal Intel"        "audio-input-microphone";

    "desktop-directories/annixion-2-weapon.directory".text             = dir "2. Weaponization"         "package-x-generic";
    "desktop-directories/annixion-2-weapon-disasm.directory".text      = dir "Disassembly"              "applications-engineering";
    "desktop-directories/annixion-2-weapon-firmware.directory".text    = dir "Firmware Analysis"        "drive-harddisk";

    "desktop-directories/annixion-3-delivery.directory".text           = dir "3. Delivery"              "mail-send";
    "desktop-directories/annixion-3-delivery-proxy.directory".text     = dir "Web Proxy"                "network-proxy";
    "desktop-directories/annixion-3-delivery-injection.directory".text = dir "Web Injection"            "emblem-important";

    "desktop-directories/annixion-4-exploit.directory".text            = dir "4. Exploitation"          "dialog-warning";
    "desktop-directories/annixion-4-exploit-frameworks.directory".text = dir "Frameworks"               "applications-development";
    "desktop-directories/annixion-4-exploit-creds.directory".text      = dir "Credential Attacks"       "dialog-password";
    "desktop-directories/annixion-4-exploit-wireless.directory".text   = dir "Wireless"                 "network-wireless";

    "desktop-directories/annixion-5-install.directory".text            = dir "5. Installation"          "system-run";
    "desktop-directories/annixion-5-install-tunneling.directory".text  = dir "Tunneling & Shells"       "utilities-terminal";

    "desktop-directories/annixion-6-c2.directory".text                 = dir "6. C2"                    "network-server";
    "desktop-directories/annixion-6-c2-frameworks.directory".text      = dir "Frameworks"               "applications-development";

    "desktop-directories/annixion-7-postex.directory".text             = dir "7. Post-Exploitation"     "emblem-system";
    "desktop-directories/annixion-7-postex-lateral.directory".text     = dir "Lateral Movement"         "network-workgroup";

    "desktop-directories/annixion-8-forensics.directory".text          = dir "8. Forensics"             "system-file-manager";
    "desktop-directories/annixion-8-forensics-memory.directory".text   = dir "Memory Analysis"          "media-flash";
    "desktop-directories/annixion-8-forensics-disk.directory".text     = dir "Disk Analysis"            "drive-harddisk";

    "desktop-directories/annixion-9-re.directory".text                 = dir "9. Reverse Engineering"   "applications-engineering";
    "desktop-directories/annixion-9-re-disasm.directory".text          = dir "Disassemblers"            "applications-engineering";
    "desktop-directories/annixion-9-re-firmware.directory".text        = dir "Firmware"                 "drive-harddisk";

    "desktop-directories/annixion-10-sniffing.directory".text          = dir "10. Sniffing & Analysis"  "network-transmit-receive";

    "desktop-directories/annixion-internet.directory".text             = dir "Internet"                 "applications-internet";
    "desktop-directories/annixion-dev.directory".text                  = dir "Development"              "applications-development";
    "desktop-directories/annixion-utils.directory".text                = dir "Utilities"                "applications-utilities";
    "desktop-directories/annixion-system.directory".text               = dir "System"                   "applications-system";
  };

  # ============================================================
  # DESKTOP ENTRIES
  # All entries use the annixion- prefix to avoid colliding with
  # system-provided .desktop files. Tools appear in the AnNIXion
  # menu via their X-AnNIXion-* categories.
  # ============================================================

  xdg.desktopEntries = lib.mkDefault {

    # ── 1. Reconnaissance — Passive OSINT ─────────────────────────────────
    annixion-theharvester = {
      name        = "theHarvester";
      genericName = "OSINT Harvester";
      exec        = termHold "theHarvester";
      terminal    = false;
      categories  = [ "X-AnNIXion-Recon-OSINT" ];
      comment     = "Email, domain and IP intelligence gathering";
    };
    annixion-whois = {
      name        = "Whois";
      genericName = "Domain Lookup";
      exec        = termHold "whois";
      terminal    = false;
      categories  = [ "X-AnNIXion-Recon-OSINT" ];
    };
    annixion-dig = {
      name        = "dig";
      genericName = "DNS Lookup";
      exec        = termHold "dig";
      terminal    = false;
      categories  = [ "X-AnNIXion-Recon-OSINT" ];
    };

    # ── 1. Reconnaissance — Active Scanning ───────────────────────────────
    annixion-nmap = {
      name        = "Nmap";
      genericName = "Network Scanner";
      exec        = termHold "nmap";
      terminal    = false;
      categories  = [ "X-AnNIXion-Recon-Scanning" ];
      comment     = "Network exploration and security auditing";
    };
    annixion-gobuster = {
      name        = "Gobuster";
      genericName = "Directory Brute Forcer";
      exec        = termHold "gobuster";
      terminal    = false;
      categories  = [ "X-AnNIXion-Recon-Scanning" ];
      comment     = "Directory, DNS and virtual host brute-forcing";
    };
    annixion-ffuf = {
      name        = "ffuf";
      genericName = "Web Fuzzer";
      exec        = termHold "ffuf";
      terminal    = false;
      categories  = [ "X-AnNIXion-Recon-Scanning" ];
      comment     = "Fast web fuzzer";
    };

    # ── 1. Reconnaissance — RF / Signal Intel ─────────────────────────────
    annixion-gqrx = {
      name        = "Gqrx";
      genericName = "SDR Receiver";
      icon        = "gqrx";
      exec        = "gqrx";
      terminal    = false;
      categories  = [ "X-AnNIXion-Recon-RF" ];
      comment     = "Software defined radio receiver";
    };
    annixion-gnuradio = {
      name        = "GNU Radio Companion";
      genericName = "SDR Signal Processing";
      exec        = "gnuradio-companion";
      terminal    = false;
      categories  = [ "X-AnNIXion-Recon-RF" ];
      comment     = "SDR flow-graph signal processing toolkit";
    };
    annixion-hackrf = {
      name        = "HackRF Tools";
      genericName = "HackRF Utilities";
      exec        = termHold "hackrf_info";
      terminal    = false;
      categories  = [ "X-AnNIXion-Recon-RF" ];
      comment     = "HackRF hardware interface and diagnostics";
    };

    # ── 2. Weaponization — Disassembly ────────────────────────────────────
    # ghidra and binwalk also appear in 9. Reverse Engineering via dual categories
    annixion-ghidra = {
      name        = "Ghidra";
      genericName = "Reverse Engineering Suite";
      icon        = "ghidra";
      exec        = "ghidra";
      terminal    = false;
      categories  = [ "X-AnNIXion-Weapon-Disasm" "X-AnNIXion-RE-Disasm" ];
      comment     = "NSA software reverse engineering framework";
    };

    # ── 2. Weaponization — Firmware Analysis ──────────────────────────────
    annixion-binwalk = {
      name        = "Binwalk";
      genericName = "Firmware Analyzer";
      exec        = termHold "binwalk";
      terminal    = false;
      categories  = [ "X-AnNIXion-Weapon-Firmware" "X-AnNIXion-RE-Firmware" ];
      comment     = "Firmware analysis and extraction";
    };

    # ── 3. Delivery — Web Proxy ───────────────────────────────────────────
    annixion-burpsuite = {
      name        = "Burp Suite";
      genericName = "Web App Security Proxy";
      exec        = "burpsuite";
      terminal    = false;
      categories  = [ "X-AnNIXion-Delivery-Proxy" ];
      comment     = "Web application security testing platform";
    };
    # firefox-red and firefox-osint are defined in home/firefox/default.nix
    # with their AnNIXion categories set there.

    # ── 3. Delivery — Web Injection ───────────────────────────────────────
    annixion-sqlmap = {
      name        = "sqlmap";
      genericName = "SQL Injection Tool";
      exec        = termHold "sqlmap";
      terminal    = false;
      categories  = [ "X-AnNIXion-Delivery-Injection" ];
      comment     = "Automatic SQL injection and database takeover";
    };

    # ── 4. Exploitation — Frameworks ──────────────────────────────────────
    annixion-metasploit = {
      name        = "Metasploit";
      genericName = "Exploitation & C2 Framework";
      exec        = term "msfconsole";
      terminal    = false;
      categories  = [ "X-AnNIXion-Exploit-Frameworks" "X-AnNIXion-C2-Frameworks" ];
      comment     = "Penetration testing, exploitation and C2 via Meterpreter";
    };

    # ── 4. Exploitation — Credential Attacks ──────────────────────────────
    annixion-john = {
      name        = "John the Ripper";
      genericName = "Password Cracker";
      exec        = termHold "john";
      terminal    = false;
      categories  = [ "X-AnNIXion-Exploit-Creds" ];
      comment     = "Offline password cracking tool";
    };
    annixion-hashcat = {
      name        = "Hashcat";
      genericName = "GPU Password Cracker";
      exec        = termHold "hashcat";
      terminal    = false;
      categories  = [ "X-AnNIXion-Exploit-Creds" ];
      comment     = "Advanced GPU-accelerated password recovery";
    };
    annixion-hydra = {
      name        = "Hydra";
      genericName = "Network Login Brute Forcer";
      exec        = termHold "hydra";
      terminal    = false;
      categories  = [ "X-AnNIXion-Exploit-Creds" ];
      comment     = "Online network service brute-forcing";
    };

    # ── 4. Exploitation — Wireless ────────────────────────────────────────
    annixion-aircrack = {
      name        = "Aircrack-ng";
      genericName = "WiFi Security Auditing";
      exec        = termHold "aircrack-ng";
      terminal    = false;
      categories  = [ "X-AnNIXion-Exploit-Wireless" ];
      comment     = "802.11 WEP and WPA/WPA2 cracking suite";
    };

    # ── 5. Installation — Tunneling & Shells ──────────────────────────────
    annixion-netcat = {
      name        = "Netcat";
      genericName = "Network Swiss Army Knife";
      exec        = term "nc";
      terminal    = false;
      categories  = [ "X-AnNIXion-Install-Tunneling" "X-AnNIXion-Sniffing" ];
      comment     = "TCP/IP networking — listeners, pivots, file transfers";
    };

    # ── 6. C2 — Frameworks ────────────────────────────────────────────────
    # Metasploit appears here via its dual categories (see 4. Exploitation above)

    # ── 7. Post-Exploitation — Lateral Movement ───────────────────────────
    annixion-impacket = {
      name        = "Impacket";
      genericName = "Windows Post-Exploitation Suite";
      exec        = "konsole";
      terminal    = false;
      categories  = [ "X-AnNIXion-PostEx-Lateral" ];
      comment     = "Python tools for Windows protocols — run impacket-<tool>";
    };

    # ── 8. Forensics — Memory Analysis ────────────────────────────────────
    annixion-volatility = {
      name        = "Volatility 3";
      genericName = "Memory Forensics";
      exec        = term "vol";
      terminal    = false;
      categories  = [ "X-AnNIXion-Forensics-Memory" ];
      comment     = "Memory acquisition and forensics framework";
    };

    # ── 8. Forensics — Disk Analysis ──────────────────────────────────────
    annixion-autopsy = {
      name        = "Autopsy";
      genericName = "Digital Forensics Platform";
      exec        = "autopsy";
      terminal    = false;
      categories  = [ "X-AnNIXion-Forensics-Disk" ];
      comment     = "GUI frontend for The Sleuth Kit disk forensics";
    };

    # ── 10. Sniffing & Analysis ───────────────────────────────────────────
    annixion-wireshark = {
      name        = "Wireshark";
      genericName = "Packet Analyzer";
      icon        = "wireshark";
      exec        = "wireshark";
      terminal    = false;
      categories  = [ "X-AnNIXion-Sniffing" ];
      comment     = "Network protocol capture and analysis";
    };

    # ── Internet ──────────────────────────────────────────────────────────
    # (firefox-red and firefox-osint — defined in home/firefox/default.nix)

    # ── Development ───────────────────────────────────────────────────────
    annixion-vscode = {
      name        = "VS Code";
      genericName = "Code Editor";
      icon        = "code";
      exec        = "code";
      terminal    = false;
      categories  = [ "X-AnNIXion-Dev" ];
    };
    annixion-github-desktop = {
      name        = "GitHub Desktop";
      genericName = "Git GUI";
      exec        = "github-desktop";
      terminal    = false;
      categories  = [ "X-AnNIXion-Dev" ];
    };
    annixion-gh = {
      name        = "GitHub CLI";
      genericName = "Git CLI";
      exec        = term "gh";
      terminal    = false;
      categories  = [ "X-AnNIXion-Dev" ];
    };

    # ── Utilities ─────────────────────────────────────────────────────────
    annixion-kate = {
      name        = "Kate";
      genericName = "Text Editor";
      icon        = "kate";
      exec        = "kate";
      terminal    = false;
      categories  = [ "X-AnNIXion-Utils" ];
    };
    annixion-ark = {
      name        = "Ark";
      genericName = "Archive Manager";
      icon        = "ark";
      exec        = "ark";
      terminal    = false;
      categories  = [ "X-AnNIXion-Utils" ];
    };
    annixion-kcalc = {
      name        = "KCalc";
      genericName = "Calculator";
      icon        = "kcalc";
      exec        = "kcalc";
      terminal    = false;
      categories  = [ "X-AnNIXion-Utils" ];
    };
    annixion-filelight = {
      name        = "Filelight";
      genericName = "Disk Usage Analyzer";
      icon        = "filelight";
      exec        = "filelight";
      terminal    = false;
      categories  = [ "X-AnNIXion-Utils" ];
    };

    # ── System ────────────────────────────────────────────────────────────
    annixion-konsole = {
      name        = "Konsole";
      genericName = "Terminal Emulator";
      icon        = "utilities-terminal";
      exec        = "konsole";
      terminal    = false;
      categories  = [ "X-AnNIXion-System" ];
    };
    annixion-dolphin = {
      name        = "Dolphin";
      genericName = "File Manager";
      icon        = "system-file-manager";
      exec        = "dolphin";
      terminal    = false;
      categories  = [ "X-AnNIXion-System" ];
    };
    annixion-systemsettings = {
      name        = "System Settings";
      genericName = "System Configuration";
      icon        = "preferences-system";
      exec        = "systemsettings";
      terminal    = false;
      categories  = [ "X-AnNIXion-System" ];
    };

  };
}
