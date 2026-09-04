# annixion-burp-ca: fetch Burp's CA and put it where Firefox's enterprise
# policy expects it. Its own module rather than a package in a list — it is a
# program with an interface, not a name in the catalog.
{ pkgs, ... }:

{
  environment.systemPackages = [
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
  ];
}
