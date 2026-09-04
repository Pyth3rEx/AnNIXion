{ pkgs, ... }:
let
  zone = "annixion.test";

  # A zone small enough to read, with an apex the script can count on.
  zoneFile = pkgs.writeText "${zone}.zone" ''
    $TTL 3600
    @   IN  SOA ns.${zone}. hostmaster.${zone}. ( 1 3600 900 604800 3600 )
    @   IN  NS  ns.${zone}.
    ns  IN  A   192.168.1.1
    www IN  A   192.168.1.10
    vpn IN  A   192.168.1.20
    @   IN  TXT "annixion axfr fixture"
  '';
in
{
  name = "annixion-bind-axfr";

  nodes = {
    server = {
      services.bind = {
        enable = true;
        zones."${zone}" = {
          master = true;
          file = zoneFile;
          # The point of the fixture: this zone is meant to transfer.
          slaves = [ "any" ];
        };
      };

      networking.firewall.allowedTCPPorts = [ 53 ];
      networking.firewall.allowedUDPPorts = [ 53 ];
    };

    client.environment.systemPackages = [ pkgs.dnsutils ];
  };

  testScript = ''
    start_all()

    server.wait_for_unit("bind.service")
    server.wait_for_open_port(53)
    client.wait_for_unit("multi-user.target")

    # The transfer itself, before any of the script's parsing is involved.
    out = client.succeed("dig +time=5 +tries=1 +tcp axfr ${zone} @server")
    assert "XFR size:" in out, f"no record tally in dig output:\n{out}"
    assert "SOA" in out, f"transfer carried no apex SOA:\n{out}"
    assert "www.${zone}." in out, f"transfer is missing zone data:\n{out}"

    # A zone that refuses transfers must read as refused, not as success.
    client.fail("dig +time=5 +tries=1 +tcp axfr nosuch.test @server | grep -q 'XFR size:'")

    # dns-axfr.sh against a server we control: the same script CI runs against
    # the internet, so its parsing is covered without depending on a zone
    # somebody else publishes. 192.0.2.1 is unroutable from here, so the
    # interception probe reads clean exactly as it does on a healthy machine.
    out = client.succeed("AXFR_ZONE=${zone} bash ${../shell/dns-axfr.sh} server")
    assert "port 53 is not intercepted" in out, f"probe misread a silent address:\n{out}"
    assert "zone transfers work from here" in out, f"script rejected a good transfer:\n{out}"

    # And it has to fail when the transfer does. bind is down, nothing answers.
    server.succeed("systemctl stop bind.service")
    client.fail("AXFR_ZONE=${zone} bash ${../shell/dns-axfr.sh} server")
  '';
}
