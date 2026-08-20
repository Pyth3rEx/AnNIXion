# System-wide offensive, OSINT, RF and forensics tooling.
{
  pkgs,
  ...
}:

{
  # ── Security tools — offensive & OSINT ────────────────────
  # System-wide, so they are present before any user session starts.
  # Unfree packages need allowUnfree, set in flake.nix.

  environment.systemPackages = with pkgs; [

    # ── Offensive security ────────────────────────────────────
    openssl # TLS/crypto toolkit — cert generation, inspection, conversion
    nmap # network scanner
    netcat-gnu # networking swiss army knife
    wireshark # packet capture & analysis
    burpsuite # web app pentesting proxy
    (pkgs.writeShellApplication {
      name = "annixion-burp-ca";
      runtimeInputs = [
        pkgs.curl
        pkgs.openssl
      ];
      text = ''
        case "''${1:-}" in
          -h | --help)
            printf '%s\n' 'usage: annixion-burp-ca

        Fetches Burp'"'"'s CA certificate from the proxy on 127.0.0.1:8080 and
        writes it where the Firefox enterprise policy expects it. Restart
        Firefox afterwards; no rebuild is needed.

          -h, --help  show this help'
            exit 0
            ;;
        esac

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
        # The policy holds the path, not the contents: Firefox re-reads it.
        echo "restart Firefox to trust it (no rebuild needed)"
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

    # ── SDR / RF ──────────────────────────────────────────────
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
