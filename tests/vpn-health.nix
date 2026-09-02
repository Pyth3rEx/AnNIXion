{ pkgs, ... }:
let
  # A root zone with a wildcard answers for every name that reaches it —
  # which is what a relay holding port 53 looks like from the client.
  hijackZoneFile = pkgs.writeText "root.zone" ''
    $TTL 60
    @   IN  SOA ns.relay.test. hostmaster.relay.test. ( 1 3600 900 604800 60 )
    @   IN  NS  ns.relay.test.
    *   IN  A   198.51.100.9
  '';

  # Stands in for the desktop dialog: the test needs to read what was said,
  # not watch a window open.
  stubAlert = pkgs.writeShellScript "stub-alert" ''
    cat > /tmp/vpn-alert
  '';
in
{
  name = "annixion-vpn-health";

  nodes = {
    relay = {
      services.bind = {
        enable = true;
        # The hijack answers whoever it caught, not just localhost.
        cacheNetworks = [ "192.168.1.0/24" ];
        forwarders = [ ];
        zones."." = {
          master = true;
          file = hijackZoneFile;
        };
      };

      networking.firewall.allowedTCPPorts = [ 53 ];
      networking.firewall.allowedUDPPorts = [ 53 ];
    };

    machine =
      { nodes, pkgs, ... }:
      {
        imports = [
          ../modules/vpn-enforcement.nix
          ../modules/vpn-health.nix
        ];

        users.users.operator = {
          isNormalUser = true;
          password = "test";
          uid = 1000;
          linger = true;
        };

        # Both are heavy closures used only by the desktop paths.
        annixion.vpnEnforcement.browserPackage = pkgs.hello;
        annixion.vpnHealth.alertCommand = "${stubAlert}";

        networking.nameservers = [ nodes.relay.networking.primaryIPAddress ];
        networking.nftables.enable = true;
        environment.systemPackages = [
          pkgs.dnsutils
          pkgs.nftables
        ];

        virtualisation.memorySize = 1024;
      };
  };

  testScript =
    { nodes, ... }:
    let
      relayIp = nodes.relay.networking.primaryIPAddress;
    in
    ''
      start_all()

      relay.wait_for_unit("bind.service")
      relay.wait_for_open_port(53)
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("user@1000.service")

      asOperator = (
          "su operator -c 'XDG_RUNTIME_DIR=/run/user/1000 DISPLAY= {}'"
      )

      def arm_hijack():
          """Every port 53 packet lands on the relay, as a real one arranges."""
          machine.succeed("nft add table ip hijack")
          machine.succeed(
              "nft add chain ip hijack output '{ type nat hook output priority dstnat; }'"
          )
          machine.succeed(
              "nft add rule ip hijack output meta l4proto { tcp, udp } th dport 53 "
              "ip daddr != ${relayIp} dnat to ${relayIp}"
          )
          # A relay answers what it can reply to, and the tunnel's own source
          # address is not routable back here.
          machine.succeed(
              "nft add chain ip hijack postrouting "
              "'{ type nat hook postrouting priority srcnat; }'"
          )
          machine.succeed("nft add rule ip hijack postrouting ip daddr ${relayIp} masquerade")

      def disarm_hijack():
          machine.succeed("nft delete table ip hijack")

      with subtest("no tunnel is not a fault — there is nothing to judge"):
          rc, out = machine.execute("annixion-vpn-check")
          assert rc == 2, f"no tunnel should exit 2, got {rc}:\n{out}"
          assert "no tunnel is up" in out, out

      with subtest("the watcher is wired to run on its own"):
          machine.succeed(asOperator.format("systemctl --user is-active annixion-vpn-watch.timer"))
          # From here the test drives it, so a tick of its own cannot decide
          # which fault was already reported.
          machine.succeed(asOperator.format("systemctl --user stop annixion-vpn-watch.timer"))
          machine.succeed(asOperator.format("rm -f /run/user/1000/annixion-vpn-health.state"))

      # A tunnel, and the internet routed through it.
      machine.succeed("ip link add wg0 type dummy")
      machine.succeed("ip addr add 10.99.0.2/24 dev wg0")
      machine.succeed("ip link set wg0 up")
      machine.succeed("ip route add default dev wg0")

      with subtest("a sound tunnel passes"):
          out = machine.succeed("annixion-vpn-check")
          assert "fit for work" in out, out
          assert "port 53 reaches the server it is addressed to" in out, out

      with subtest("a relay answering port 53 is a fault, not a quiet one"):
          arm_hijack()

          rc, out = machine.execute("annixion-vpn-check")
          assert rc == 1, f"an intercepted path should exit 1, got {rc}:\n{out}"
          assert "port 53 is intercepted" in out, out
          # The consequence, not just the symptom.
          assert "Transfer failed." in out, out

      with subtest("the watcher yells, and says what is wrong"):
          machine.fail(asOperator.format("annixion-vpn-watch"))
          machine.wait_for_file("/tmp/vpn-alert")
          alert = machine.succeed("cat /tmp/vpn-alert")
          assert "port 53 is intercepted" in alert, alert

      with subtest("it does not yell again about the same fault"):
          machine.succeed("rm /tmp/vpn-alert")
          machine.fail(asOperator.format("annixion-vpn-watch"))
          machine.fail("test -e /tmp/vpn-alert")

      with subtest("a repaired tunnel is quiet, and a new fault yells again"):
          disarm_hijack()
          machine.succeed(asOperator.format("annixion-vpn-watch"))
          machine.fail("test -e /tmp/vpn-alert")

          arm_hijack()
          machine.fail(asOperator.format("annixion-vpn-watch"))
          machine.wait_for_file("/tmp/vpn-alert")

      with subtest("the unit reads as failed for as long as the tunnel is unsound"):
          machine.fail(asOperator.format("systemctl --user start annixion-vpn-watch.service"))
          state = machine.succeed(
              asOperator.format("systemctl --user is-failed annixion-vpn-watch.service") + " || true"
          )
          assert "failed" in state, state

      with subtest("traffic leaving outside the tunnel is a fault too"):
          disarm_hijack()
          machine.succeed("ip route del default dev wg0")
          machine.succeed("ip route add default via ${relayIp}")

          rc, out = machine.execute("annixion-vpn-check")
          assert rc == 1, f"a leaking route should exit 1, got {rc}:\n{out}"
          assert "outside the tunnel" in out, out

      with subtest("a resolver that answers nothing is a fault"):
          machine.succeed("ip route add default dev wg0 metric 10")
          machine.succeed("ip route del default via ${relayIp}")
          relay.succeed("systemctl stop bind.service")

          rc, out = machine.execute("annixion-vpn-check")
          assert rc == 1, f"a dead resolver should exit 1, got {rc}:\n{out}"
          assert "answers nothing" in out, out
    '';
}
