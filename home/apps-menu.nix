{
  config,
  lib,
  pkgs,
  ...
}:

let
  term = cmd: "konsole -e ${cmd}";
  termHold = cmd: ''konsole -e bash -c "${cmd}; exec bash"'';

  dir = name: icon: ''
    [Desktop Entry]
    Name=${name}
    Type=Directory
    Icon=${icon}
  '';

  # Generate .desktop file text.
  # xdg.desktopEntries in HM 26.05 installs files into the HM profile
  # (/etc/profiles/per-user/operator/share/applications/) rather than
  # ~/.local/share/applications/. kbuildsycoca6 does not reliably index
  # that path, so categories never appear. We write raw .desktop text via
  # home.file instead, which is proven to land in ~/.local/share/.
  de =
    {
      name,
      exec,
      icon,
      categories,
      genericName ? null,
      comment ? null,
      mimeType ? null,
      noDisplay ? false,
    }:
    lib.concatStringsSep "\n" (
      [ "[Desktop Entry]" "Type=Application" "Name=${name}" ]
      ++ lib.optional (genericName != null) "GenericName=${genericName}"
      ++ [
        "Icon=${icon}"
        "Exec=${exec}"
        "Terminal=false"
        "Categories=${lib.concatStringsSep ";" categories};"
      ]
      ++ lib.optional (comment != null) "Comment=${comment}"
      ++ lib.optional (mimeType != null) "MimeType=${lib.concatStringsSep ";" mimeType};"
      ++ lib.optional noDisplay "NoDisplay=true"
    )
    + "\n";

  # ── Directory label & icon files ─────────────────────────────────────────
  directories = {
    "annixion.directory" = dir "AnNIXion" "security-high";

    "annixion-1-recon.directory" = dir "1. Reconnaissance" "system-search";
    "annixion-1-recon-osint.directory" = dir "Passive OSINT" "applications-internet";
    "annixion-1-recon-scanning.directory" = dir "Active Scanning" "network-wired";
    "annixion-1-recon-rf.directory" = dir "RF / Signal Intel" "audio-input-microphone";

    "annixion-2-weapon.directory" = dir "2. Weaponization" "package-x-generic";
    "annixion-2-weapon-disasm.directory" = dir "Disassembly" "applications-engineering";
    "annixion-2-weapon-firmware.directory" = dir "Firmware Analysis" "drive-harddisk";

    "annixion-3-delivery.directory" = dir "3. Delivery" "mail-send";
    "annixion-3-delivery-proxy.directory" = dir "Web Proxy" "network-proxy";
    "annixion-3-delivery-injection.directory" = dir "Web Injection" "emblem-important";

    "annixion-4-exploit.directory" = dir "4. Exploitation" "dialog-warning";
    "annixion-4-exploit-frameworks.directory" = dir "Frameworks" "applications-development";
    "annixion-4-exploit-creds.directory" = dir "Credential Attacks" "dialog-password";
    "annixion-4-exploit-wireless.directory" = dir "Wireless" "network-wireless";

    "annixion-5-install.directory" = dir "5. Installation" "system-run";
    "annixion-5-install-tunneling.directory" = dir "Tunneling & Shells" "utilities-terminal";

    "annixion-6-c2.directory" = dir "6. C2" "network-server";
    "annixion-6-c2-frameworks.directory" = dir "Frameworks" "applications-development";

    "annixion-7-postex.directory" = dir "7. Post-Exploitation" "emblem-system";
    "annixion-7-postex-lateral.directory" = dir "Lateral Movement" "network-workgroup";

    "annixion-8-forensics.directory" = dir "8. Forensics" "system-file-manager";
    "annixion-8-forensics-memory.directory" = dir "Memory Analysis" "media-flash";
    "annixion-8-forensics-disk.directory" = dir "Disk Analysis" "drive-harddisk";

    "annixion-9-re.directory" = dir "9. Reverse Engineering" "applications-engineering";
    "annixion-9-re-disasm.directory" = dir "Disassemblers" "applications-engineering";
    "annixion-9-re-firmware.directory" = dir "Firmware" "drive-harddisk";

    "annixion-10-sniffing.directory" = dir "10. Sniffing & Analysis" "network-transmit-receive";

    "annixion-tools.directory" = dir "Tools" "applications-other";
    "annixion-internet.directory" = dir "Internet" "applications-internet";
    "annixion-dev.directory" = dir "Development" "applications-development";
    "annixion-productivity.directory" = dir "Productivity" "applications-office";
    "annixion-utils.directory" = dir "Utilities" "applications-utilities";
    "annixion-system.directory" = dir "System" "applications-system";
  };

  # ── Desktop entries ───────────────────────────────────────────────────────
  desktopEntries = {

    # ── 1. Reconnaissance — Passive OSINT ───────────────────────────────────
    "annixion-theharvester" = de {
      name = "theHarvester";
      genericName = "OSINT Harvester";
      icon = "system-search";
      exec = termHold "theHarvester";
      categories = [ "X-AnNIXion-Recon-OSINT" ];
      comment = "Email, domain and IP intelligence gathering";
    };
    "annixion-whois" = de {
      name = "Whois";
      genericName = "Domain Lookup";
      icon = "network-wired";
      exec = termHold "whois";
      categories = [ "X-AnNIXion-Recon-OSINT" ];
    };
    "annixion-dig" = de {
      name = "dig";
      genericName = "DNS Lookup";
      icon = "network-wired";
      exec = termHold "dig";
      categories = [ "X-AnNIXion-Recon-OSINT" ];
    };
    "annixion-whatweb" = de {
      name = "WhatWeb";
      genericName = "Web Recon";
      icon = "folder-remote";
      exec = termHold "whatweb";
      categories = [ "X-AnNIXion-Recon-Scanning" ];
      comment = "Web server fingerprinting and technology detection";
    };

    # ── 1. Reconnaissance — Active Scanning ──────────────────────────────────
    "annixion-nmap" = de {
      name = "Nmap";
      genericName = "Network Scanner";
      icon = "network-wired";
      exec = termHold "nmap";
      categories = [ "X-AnNIXion-Recon-Scanning" ];
      comment = "Network exploration and security auditing";
    };
    "annixion-gobuster" = de {
      name = "Gobuster";
      genericName = "Directory Brute Forcer";
      icon = "folder-remote";
      exec = termHold "gobuster";
      categories = [ "X-AnNIXion-Recon-Scanning" ];
      comment = "Directory, DNS and virtual host brute-forcing";
    };
    "annixion-ffuf" = de {
      name = "ffuf";
      genericName = "Web Fuzzer";
      icon = "folder-remote";
      exec = termHold "ffuf";
      categories = [ "X-AnNIXion-Recon-Scanning" ];
      comment = "Fast web fuzzer";
    };

    # ── 1. Reconnaissance — RF / Signal Intel ────────────────────────────────
    "annixion-gqrx" = de {
      name = "Gqrx";
      genericName = "SDR Receiver";
      icon = "gqrx";
      exec = "gqrx";
      categories = [ "X-AnNIXion-Recon-RF" ];
      comment = "Software defined radio receiver";
    };
    "annixion-gnuradio" = de {
      name = "GNU Radio Companion";
      genericName = "SDR Signal Processing";
      icon = "audio-input-microphone";
      exec = "gnuradio-companion";
      categories = [ "X-AnNIXion-Recon-RF" ];
      comment = "SDR flow-graph signal processing toolkit";
    };
    "annixion-hackrf" = de {
      name = "HackRF Tools";
      genericName = "HackRF Utilities";
      icon = "audio-input-microphone";
      exec = termHold "hackrf_info";
      categories = [ "X-AnNIXion-Recon-RF" ];
      comment = "HackRF hardware interface and diagnostics";
    };

    # ── 2. Weaponization ─────────────────────────────────────────────────────
    "annixion-ghidra" = de {
      name = "Ghidra";
      genericName = "Reverse Engineering Suite";
      icon = "ghidra";
      exec = "ghidra";
      categories = [
        "X-AnNIXion-Weapon-Disasm"
        "X-AnNIXion-RE-Disasm"
      ];
      comment = "NSA software reverse engineering framework";
    };
    "annixion-binwalk" = de {
      name = "Binwalk";
      genericName = "Firmware Analyzer";
      icon = "media-removable";
      exec = termHold "binwalk";
      categories = [
        "X-AnNIXion-Weapon-Firmware"
        "X-AnNIXion-RE-Firmware"
      ];
      comment = "Firmware analysis and extraction";
    };

    # ── 3. Delivery ───────────────────────────────────────────────────────────
    "annixion-burpsuite" = de {
      name = "Burp Suite";
      genericName = "Web App Security Proxy";
      icon = "burpsuite";
      exec = "burpsuite";
      categories = [ "X-AnNIXion-Delivery-Proxy" ];
      comment = "Web application security testing platform";
    };
    "annixion-sqlmap" = de {
      name = "sqlmap";
      genericName = "SQL Injection Tool";
      icon = "dialog-warning";
      exec = termHold "sqlmap";
      categories = [ "X-AnNIXion-Delivery-Injection" ];
      comment = "Automatic SQL injection and database takeover";
    };

    # ── 4. Exploitation ───────────────────────────────────────────────────────
    "annixion-metasploit" = de {
      name = "Metasploit";
      genericName = "Exploitation & C2 Framework";
      icon = "security-high";
      exec = term "msfconsole";
      categories = [
        "X-AnNIXion-Exploit-Frameworks"
        "X-AnNIXion-C2-Frameworks"
      ];
      comment = "Penetration testing, exploitation and C2 via Meterpreter";
    };
    "annixion-john" = de {
      name = "John the Ripper";
      genericName = "Password Cracker";
      icon = "dialog-password";
      exec = termHold "john";
      categories = [ "X-AnNIXion-Exploit-Creds" ];
      comment = "Offline password cracking tool";
    };
    "annixion-hashcat" = de {
      name = "Hashcat";
      genericName = "GPU Password Cracker";
      icon = "dialog-password";
      exec = termHold "hashcat";
      categories = [ "X-AnNIXion-Exploit-Creds" ];
      comment = "Advanced GPU-accelerated password recovery";
    };
    "annixion-hydra" = de {
      name = "Hydra";
      genericName = "Network Login Brute Forcer";
      icon = "dialog-password";
      exec = termHold "hydra";
      categories = [ "X-AnNIXion-Exploit-Creds" ];
      comment = "Online network service brute-forcing";
    };
    "annixion-seclists" = de {
      name = "SecLists";
      genericName = "Curated Wordlists";
      icon = "folder-documents";
      exec = termHold "seclists";
      categories = [ "X-AnNIXion-Exploit-Creds" ];
      comment = "Curated list of wordlists for dictionary attacks";
    };
    "annixion-aircrack" = de {
      name = "Aircrack-ng";
      genericName = "WiFi Security Auditing";
      icon = "network-wireless";
      exec = termHold "aircrack-ng";
      categories = [ "X-AnNIXion-Exploit-Wireless" ];
      comment = "802.11 WEP and WPA/WPA2 cracking suite";
    };

    # ── 5. Installation ───────────────────────────────────────────────────────
    "annixion-netcat" = de {
      name = "Netcat";
      genericName = "Network Swiss Army Knife";
      icon = "network-transmit-receive";
      exec = term "nc";
      categories = [
        "X-AnNIXion-Install-Tunneling"
        "X-AnNIXion-Sniffing"
      ];
      comment = "TCP/IP networking — listeners, pivots, file transfers";
    };

    # ── 7. Post-Exploitation ──────────────────────────────────────────────────
    "annixion-impacket" = de {
      name = "Impacket";
      genericName = "Windows Post-Exploitation Suite";
      icon = "network-server";
      exec = "konsole";
      categories = [ "X-AnNIXion-PostEx-Lateral" ];
      comment = "Python tools for Windows protocols — run impacket-<tool>";
    };

    # ── 8. Forensics ──────────────────────────────────────────────────────────
    "annixion-volatility" = de {
      name = "Volatility 3";
      genericName = "Memory Forensics";
      icon = "media-flash";
      exec = term "vol";
      categories = [ "X-AnNIXion-Forensics-Memory" ];
      comment = "Memory acquisition and forensics framework";
    };
    "annixion-autopsy" = de {
      name = "Autopsy";
      genericName = "Digital Forensics Platform";
      icon = "drive-harddisk";
      exec = "autopsy";
      categories = [ "X-AnNIXion-Forensics-Disk" ];
      comment = "GUI frontend for The Sleuth Kit disk forensics";
    };

    # ── 10. Sniffing & Analysis ───────────────────────────────────────────────
    "annixion-wireshark" = de {
      name = "Wireshark";
      genericName = "Packet Analyzer";
      icon = "wireshark";
      exec = "wireshark";
      categories = [ "X-AnNIXion-Sniffing" ];
      comment = "Network protocol capture and analysis";
    };

    # ── Development ────────────────────────────────────────────────────────────
    "annixion-vscodium" = de {
      name = "VSCodium";
      genericName = "Text Editor";
      icon = "codium";
      exec = "codium";
      categories = [ "X-AnNIXion-Dev" ];
      comment = "Code Editing. Redefined.";
    };
    "annixion-github-desktop" = de {
      name = "GitHub Desktop";
      genericName = "Git GUI";
      icon = "github-desktop";
      exec = "github-desktop";
      categories = [ "X-AnNIXion-Dev" ];
    };
    "annixion-gh" = de {
      name = "GitHub CLI";
      genericName = "Git CLI";
      icon = "utilities-terminal";
      exec = term "gh";
      categories = [ "X-AnNIXion-Dev" ];
    };

    # ── Productivity ───────────────────────────────────────────────────────────
    "annixion-obsidian" = de {
      name = "Obsidian";
      genericName = "Note-Taking & Knowledge Base";
      icon = "obsidian";
      exec = "obsidian";
      categories = [ "X-AnNIXion-Productivity" ];
      comment = "Powerful knowledge base on top of a local folder of plain text Markdown files";
    };
    "annixion-onlyoffice" = de {
      name = "OnlyOffice";
      genericName = "Office Suite";
      icon = "onlyoffice-desktopeditors";
      exec = "onlyoffice-desktopeditors";
      categories = [ "X-AnNIXion-Productivity" ];
      comment = "Office productivity suite — documents, spreadsheets, presentations";
    };

    # ── Utilities ──────────────────────────────────────────────────────────────
    "annixion-kate" = de {
      name = "Kate";
      genericName = "Text Editor";
      icon = "kate";
      exec = "kate";
      categories = [ "X-AnNIXion-Utils" ];
    };
    "annixion-ark" = de {
      name = "Ark";
      genericName = "Archive Manager";
      icon = "ark";
      exec = "ark";
      categories = [ "X-AnNIXion-Utils" ];
    };
    "annixion-kcalc" = de {
      name = "KCalc";
      genericName = "Calculator";
      icon = "kcalc";
      exec = "kcalc";
      categories = [ "X-AnNIXion-Utils" ];
    };
    "annixion-filelight" = de {
      name = "Filelight";
      genericName = "Disk Usage Analyzer";
      icon = "filelight";
      exec = "filelight";
      categories = [ "X-AnNIXion-Utils" ];
    };
    "annixion-kleopatra" = de {
      name = "Kleopatra";
      genericName = "PGP & Certificate Manager";
      icon = "kleopatra";
      exec = "kleopatra";
      categories = [ "X-AnNIXion-Utils" ];
      comment = "OpenPGP and X.509 certificate management";
    };

    # ── System ─────────────────────────────────────────────────────────────────
    "annixion-konsole" = de {
      name = "Konsole";
      genericName = "Terminal Emulator";
      icon = "utilities-terminal";
      exec = "konsole";
      categories = [ "X-AnNIXion-System" ];
    };
    "annixion-dolphin" = de {
      name = "Dolphin";
      genericName = "File Manager";
      icon = "system-file-manager";
      exec = "dolphin";
      categories = [ "X-AnNIXion-System" ];
    };
    "annixion-systemsettings" = de {
      name = "System Settings";
      genericName = "System Configuration";
      icon = "preferences-system";
      exec = "systemsettings";
      categories = [ "X-AnNIXion-System" ];
    };
    "annixion-kwalletmanager" = de {
      name = "KWallet Manager";
      genericName = "Credential Store";
      icon = "kwalletmanager";
      exec = "kwalletmanager";
      categories = [ "X-AnNIXion-System" ];
      comment = "Manage stored passwords and secrets";
    };
    "annixion-htop" = de {
      name = "htop";
      genericName = "System Monitor";
      icon = "utilities-system-monitor";
      exec = term "htop";
      categories = [ "X-AnNIXion-System" ];
      comment = "Interactive process viewer";
    };
  };

in
{
  # Rebuild the KDE service cache after every HM activation.
  # writeBoundary guarantees all files are on disk first.
  home.activation.rebuildMenuCache = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD env XDG_DATA_DIRS="/etc/profiles/per-user/operator/share:${config.home.homeDirectory}/.nix-profile/share:''${XDG_DATA_DIRS:-/run/current-system/sw/share}" \
      ${pkgs.kdePackages.kservice}/bin/kbuildsycoca6 --noincremental 2>/dev/null || true
  '';

  # All menu files written via home.file so they land in ~/.local/share/
  # and ~/.config/ — paths kbuildsycoca6 always indexes.
  home.file =
    # XDG menu — defines the kill-chain category tree
    {
      ".config/menus/applications.menu" = lib.mkDefault {
        text = ''
          <!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
            "http://www.freedesktop.org/standards/menu-spec/menu-1.0.dtd">
          <Menu>
            <Name>Applications</Name>

            <!-- ── Kill-chain phases at root ──────────────────────────────── -->

            <Menu>
              <Name>01. Reconnaissance</Name>
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
              <Name>02. Weaponization</Name>
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
              <Name>03. Delivery</Name>
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
              <Name>04. Exploitation</Name>
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
              <Name>05. Installation</Name>
              <Directory>annixion-5-install.directory</Directory>
              <Menu>
                <Name>Tunneling &amp; Shells</Name>
                <Directory>annixion-5-install-tunneling.directory</Directory>
                <Include><Category>X-AnNIXion-Install-Tunneling</Category></Include>
              </Menu>
            </Menu>

            <Menu>
              <Name>06. C2</Name>
              <Directory>annixion-6-c2.directory</Directory>
              <Menu>
                <Name>Frameworks</Name>
                <Directory>annixion-6-c2-frameworks.directory</Directory>
                <Include><Category>X-AnNIXion-C2-Frameworks</Category></Include>
              </Menu>
            </Menu>

            <Menu>
              <Name>07. Post-Exploitation</Name>
              <Directory>annixion-7-postex.directory</Directory>
              <Menu>
                <Name>Lateral Movement</Name>
                <Directory>annixion-7-postex-lateral.directory</Directory>
                <Include><Category>X-AnNIXion-PostEx-Lateral</Category></Include>
              </Menu>
            </Menu>

            <Menu>
              <Name>08. Forensics</Name>
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
              <Name>09. Reverse Engineering</Name>
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

            <!-- ── Misc tools ──────────────────────────────────────────────── -->

            <Menu>
              <Name>Tools</Name>
              <Directory>annixion-tools.directory</Directory>
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
                <Name>Productivity</Name>
                <Directory>annixion-productivity.directory</Directory>
                <Include><Category>X-AnNIXion-Productivity</Category></Include>
              </Menu>
            </Menu>

            <Menu>
              <Name>System</Name>
              <Directory>annixion-system.directory</Directory>
              <Include><Category>X-AnNIXion-System</Category></Include>
            </Menu>

          </Menu>
        '';
      };
    }
    # .directory files → ~/.local/share/desktop-directories/
    // lib.mapAttrs' (
      n: t: lib.nameValuePair ".local/share/desktop-directories/${n}" { text = t; }
    ) directories
    # .desktop files → ~/.local/share/applications/
    // lib.mapAttrs' (
      n: t: lib.nameValuePair ".local/share/applications/${n}.desktop" { text = t; }
    ) desktopEntries;
}
