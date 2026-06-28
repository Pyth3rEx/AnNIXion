{
  config,
  lib,
  pkgs,
  ...
}:

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
    openssl # TLS/crypto toolkit — cert generation, inspection, conversion
    nmap # network scanner
    netcat-gnu # networking swiss army knife
    wireshark # packet capture & analysis
    burpsuite # web app pentesting proxy
    (pkgs.writeShellApplication {
      name = "burp-ca";
      runtimeInputs = [
        pkgs.curl
        pkgs.openssl
      ];
      text = ''
        CERT_DIR="$HOME/.dotfiles/assets/certs"
        CERT_OUT="$CERT_DIR/burp-ca.pem"

        if ! curl -sf http://127.0.0.1:8080/cert -o /tmp/burp-ca.der; then
          echo "error: Burp proxy not running on 127.0.0.1:8080" >&2
          exit 1
        fi

        mkdir -p "$CERT_DIR"
        openssl x509 -inform der -in /tmp/burp-ca.der -out "$CERT_OUT"
        rm -f /tmp/burp-ca.der
        echo "saved to $CERT_OUT"
        echo "run 'rebuild' to apply to Firefox"
      '';
    })
    metasploit # exploitation framework
    sqlmap # SQL injection tool
    gobuster # directory/DNS brute forcer
    ffuf # fast web fuzzer
    john # password cracker
    hashcat # GPU password cracker
    thc-hydra # network login brute forcer
    aircrack-ng # WiFi security auditing
    binwalk # firmware analysis
    ghidra # reverse engineering / disassembler
    whatweb # web recon
    seclists # wordlists

    # ── OSINT ─────────────────────────────────────────────────
    theharvester # email/domain/IP OSINT
    whois
    dnsutils # dig, nslookup

    # ── SDR / RF (your HackRF etc.) ───────────────────────────
    hackrf # HackRF tools
    gqrx # SDR receiver GUI
    gnuradio # SDR signal processing

    # ── Post-Exploitation ─────────────────────────────────────
    python313Packages.impacket # Windows protocol post-exploitation suite

    # ── Forensics ─────────────────────────────────────────────
    volatility3 # memory forensics framework
    autopsy # disk & file forensics GUI
  ];
}
