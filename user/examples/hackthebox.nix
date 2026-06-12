# hackthebox.nix | HTB Networking & DNS helper for AnNIXion

# What it does:
#   * Runs a local dnsmasq as the system resolver (127.0.0.1). The HTB VPN can push whatever DNs it likes, nothing consumes it; so internet resolution never breaks.
#   * Forwards normal queries to real upstreams; never leaks *.htb upstream.
#   * Goves you `addTheBox` to manage per-box host entries and *.htb forwarding at runtime (no rebuild needed).
#   * Ships `vpnTheBox` to connect to any lab .ovpn with split-tunnel + no DNS/resolv.conf hijacking (covers Pro Labs that push redirect-gateway).

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.htb;

  stateDir = "/var/lib/htb";
  hostsFile = "${stateDir}/hosts"; # dnsmasq addn-hosts (runtime, per-box)
  serversFile = "${stateDir}/servers"; # dnsmasq servers-file (the *.htb forwarder)

  # Create state dir + files as root BEFORE dnsmasq --test runs
  # Only creates when missing, so existing host entries are never wiped
  ensureState = pkgs.writeShellScript "htb-ensure-state" ''
    ${pkgs.coreutils}/bin/install -d -m 0755 -o ${cfg.user} -g users ${stateDir}
    for f in ${hostsFile} ${serversFile}; do
      if [ ! -e "''$f" ]; then
        : > "''$f"
        ${pkgs.coreutils}/bin/chown ${cfg.user}:users "''$f"
        ${pkgs.coreutils}/bin/chmod 0644 "''$f"
      fi
    done
  '';

  # addTheBox | manages HTB host entries and *.htb DNS forwarding
  addTheBox = pkgs.writeShellApplication {
    name = "addTheBox";
    runtimeInputs = [
      pkgs.gawk
      pkgs.coreutils
      pkgs.systemd
    ];
    text = ''
      set -euo pipefail

      HOSTS="${hostsFile}"
      SERVERS="${serversFile}"

      reload() {
        systemctl reload dnsmasq
      }

      ip_ok() {
        [[ "''$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
      }

      # drop any existing host line whose last field matches the given domain(s)
      rm_domains() {
        for d in "''$@"; do
          awk -v dd="''$d" '$NF != dd' "''$HOSTS" > "''${HOSTS}.tmp" 2>/dev/null || true
          mv "''${HOSTS}.tmp" "''$HOSTS"
        done
      }

      case "''${1:-}" in
        add|update)
          shift
          ip="''${1:-}"; shift || true
          ip_ok "''$ip" || { echo "bad IP: ''${ip:-<none>}"; exit 1; }
          [ "''$#" -ge 1 ] || { echo "need at least one domain"; exit 1; }
          rm_domains "''$@"
          for d in "''$@"; do
            printf '%s %s\n' "''$ip" "''$d" >> "''$HOSTS"
            echo "[+] ''$d -> ''$ip"
          done
          reload
          ;;

        remove|rm|del)
          shift
          [ "''$#" -ge 1 ] || { echo "need at least one domain"; exit 1; }
          rm_domains "''$@"
          for d in "''$@"; do
            echo "[-] removed $d"
          done
          reload
          ;;

        dns)
          shift
          ip="''${1:-}"
          if [ -z "''$ip" ] || [ "''$ip" = "off" ]; then
            : > "''$SERVERS"
            echo "[*] *.htb -> local only (host entries)"
          else
            ip_ok "''$ip" || { echo "bad IP: $ip"; exit 1; }
            echo "server=/htb/$ip" > "''$SERVERS"
            echo "[*] *.htb -> $ip (subdomains auto-resolve via box DNS)"
          fi
          reload
          ;;

        list|ls)
          echo "# host entries ($HOSTS)"
          cat "''$HOSTS" 2>/dev/null || true
          echo
          echo "# *.htb forwarder ($SERVERS)"
          cat "''$SERVERS" 2>/dev/null || true
          ;;

        flush|clear)
          : > "''$HOSTS"
          : > "''$SERVERS"
          reload
          echo "[*] cleared all host entries and reset *.htb forwarder"
          ;;

        *)
          echo "addTheBox | HTB host/DNS manager"
          echo "  addTheBox add <ip> <domain...>     | add/replace host entries"
          echo "  addTheBox update <ip> <domain...>  | alias for add (boxes re-IP on respawn)"
          echo "  addTheBox remove <domain...>       | remove host entries"
          echo "  addTheBox dns <ip|off>             | send all *.htb to a box DNS (AD boxes)"
          echo "  addTheBox list                     | show current state"
          echo "  addTheBox flush                    | wipe everything"
          exit 1
          ;;
      esac
    '';
  };

  # vpnTheBox | connect to a lab or academy config without losing internet or resolv.conf
  vpnTheBox = pkgs.writeShellScriptBin "vpnTheBox" ''
    set -euo pipefail
    if [ "''$#" -lt 1 ]; then
      echo "usage: vpnTheBox <config.ovpn>";
      exit 1;
    fi
    exec sudo ${pkgs.openvpn}/bin/openvpn \
      --config "''$1" \
      --pull-filter ignore "redirect-gateway" \
      --pull-filter ignore "dhcp-option DNS" \
      --script-security 1
  '';

in
{
  options.htb = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Apply HTB resolver/helpers when this module is imported";
    };
    user = lib.mkOption {
      type = lib.types.str;
      default = "operator";
      description = "Username of the user";
    };
    upstreams = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "9.9.9.9"
        "84.200.69.80"
      ];
      description = "Real DNS upstreams dnsmasq forwards non-.htb queries to.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Local resolver. Immune to anything the VPN pushes.
    services.dnsmasq = {
      enable = true;
      settings = {
        listen-address = "127.0.0.1";
        bind-interfaces = true;
        no-resolv = true; # ignore /etc/resolv.conf for upstreams
        server = cfg.upstreams;
        cache-size = 1000;
        addn-hosts = hostsFile; # runtime per-box entries (addTheBox add)
        servers-file = serversFile; # the *.htb forwarder (addTheBox dns)
      };
    };

    # Garantee state exists (as root) before dnsmasq --test runs
    systemd.services.dnsmasq.serviceConfig.ExecStartPre = lib.mkBefore [ "+${ensureState}" ];

    # Pin the system resolver to dnsmasq and stop anything else fighting over it
    services.resolved.enable = lib.mkForce false;
    networking.networkmanager.dns = "none";
    networking.nameservers = [ "127.0.0.1" ];

    # Let your user reload dnsmasq without sudo (so addTheBox is friction-free)
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-utils" &&
          actions.lookup("unit") == "dnsmasq.service" &&
          subject.user == "''${cfg.user}") {
        return polkit.Results.YES;
        }
      });
    '';

    environment.systemPackages = [
      addTheBox
      vpnTheBox
    ];
  };
}
