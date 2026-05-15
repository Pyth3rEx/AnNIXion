{ config, lib, pkgs, ... }:

{
  # ============================================================
  # SECURITY TOOLS — OFFENSIVE & OSINT
  # ============================================================
  # Installed system-wide (environment.systemPackages) so these tools
  # are available to all users and before any user session starts.
  #
  # Unfree packages (burpsuite, metasploit) require
  # nixpkgs.config.allowUnfree = true, which is set in flake.nix.

  environment.systemPackages = with pkgs; [

    # ── Offensive Security ────────────────────────────────────
    nmap           # network scanner
    netcat-gnu     # networking swiss army knife
    wireshark      # packet capture & analysis
    burpsuite      # web app pentesting proxy
    metasploit     # exploitation framework
    sqlmap         # SQL injection tool
    gobuster       # directory/DNS brute forcer
    ffuf           # fast web fuzzer
    john           # password cracker
    hashcat        # GPU password cracker
    hydra          # network login brute forcer
    aircrack-ng    # WiFi security auditing
    binwalk        # firmware analysis
    ghidra         # reverse engineering / disassembler

    # ── OSINT ─────────────────────────────────────────────────
    theharvester   # email/domain/IP OSINT
    whois
    dnsutils       # dig, nslookup

    # ── SDR / RF (your HackRF etc.) ───────────────────────────
    hackrf         # HackRF tools
    gqrx           # SDR receiver GUI
    gnuradio       # SDR signal processing

    # ── Post-Exploitation ─────────────────────────────────────
    python313Packages.impacket       # Windows protocol post-exploitation suite

    # ── Forensics ─────────────────────────────────────────────
    volatility3    # memory forensics framework
    autopsy        # disk & file forensics GUI
  ];
}