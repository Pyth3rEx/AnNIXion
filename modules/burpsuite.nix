{ config, lib, pkgs, ... }:

{
  # ============================================================
  # BURP SUITE — COMMUNITY OR PROFESSIONAL
  # ============================================================
  # By default, installs the free Community edition.
  # Set enableBurpPro = true in user/configuration.nix to use Professional.
  #
  # For Professional licensing:
  #   See: https://deepwiki.com/xiv3r/Burpsuite-Professional/2.4-nixos-installation

  options.enableBurpPro = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable Burp Suite Professional instead of Community";
  };

  config = {
    environment.systemPackages = with pkgs; [
      # Install either Community or Pro based on toggle
      (if config.enableBurpPro then
        burpsuite
      else
        burpsuite-community)

      # Certificate extraction helper — works with both versions
      (pkgs.writeShellApplication {
        name = "burp-ca";
        runtimeInputs = [ pkgs.curl pkgs.openssl ];
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
    ];
  };
}
