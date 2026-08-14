{
  name = "annixion-vpn-enforcement";

  nodes.machine =
    { pkgs, lib, ... }:
    {
      imports = [ ../modules/vpn-enforcement.nix ];

      users.users.operator = {
        isNormalUser = true;
        password = "test";
        uid = 1000;
        # The enforced slice lives under the user manager, and the nftables
        # rule resolves that cgroup path at load time — so the user manager
        # has to be running without anyone logging in.
        linger = true;
      };

      # kdialog is a heavy KDE closure and the launcher only uses it to
      # display the hard-fail message; the test drives the CLI paths.
      annixion.vpnEnforcement.browserPackage = pkgs.hello;

      # Detection keys off the link kind, so the regression test needs a
      # genuine WireGuard device rather than a dummy standing in for one.
      boot.kernelModules = [ "wireguard" ];
      environment.systemPackages = [ pkgs.wireguard-tools ];

      virtualisation.memorySize = 1024;
    };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("user@1000.service")
    machine.wait_for_unit("nftables.service")

    asOperator = (
        "su operator -c 'XDG_RUNTIME_DIR=/run/user/1000 DISPLAY= {}'"
    )

    with subtest("no tunnel: detection fails closed"):
        machine.fail("annixion-vpn-detect")

    with subtest("no tunnel: launcher refuses to start the browser"):
        machine.fail(asOperator.format("annixion-vpn-browser Puppet"))

    with subtest("no tunnel: the generic runner refuses too"):
        # Burp goes through this path. If it ran unconfined, the Red Team
        # profile's enforcement would be meaningless — the browser only
        # talks to loopback and Burp makes the real requests.
        machine.fail(asOperator.format("annixion-vpn-run true"))

    with subtest("killswitch refuses to load before the slice exists"):
        machine.fail("annixion-vpn-killswitch-load")

    with subtest("killswitch refuses to load with a slice but no tunnel"):
        machine.succeed(asOperator.format("systemctl --user start annixion-vpn.slice"))
        # systemd nests "-"-separated slice names, so annixion-vpn.slice
        # sits inside annixion.slice — the killswitch matches this path.
        machine.succeed(
            "test -d /sys/fs/cgroup/user.slice/user-1000.slice/"
            "user@1000.service/annixion.slice/annixion-vpn.slice"
        )
        # Accept rules are generated from the live tunnels, so with none
        # there is nothing to permit; arming anyway would blackhole the
        # slice with no way to tell why.
        machine.fail("annixion-vpn-killswitch-load")

    with subtest("a live tunnel satisfies detection"):
        # A dummy named like a tunnel — exercises the name-pattern
        # fallback for devices that are not a recognised tunnel type.
        machine.succeed("ip link add wg0 type dummy")
        machine.succeed("ip addr add 10.99.0.2/24 dev wg0")
        machine.succeed("ip link set wg0 up")
        assert "wg0" in machine.succeed("annixion-vpn-detect")

    with subtest("killswitch loads once a tunnel is up"):
        # nft resolves the cgroupv2 path to an inode here, so a wrong
        # path or malformed generated ruleset fails at this point.
        machine.succeed("annixion-vpn-killswitch-load")
        machine.succeed("nft list table inet annixion_vpn_killswitch")

    with subtest("loading is idempotent"):
        machine.succeed("annixion-vpn-killswitch-load")
        machine.succeed("annixion-vpn-killswitch-load")

    with subtest("ruleset permits the tunnel that is actually up"):
        ruleset = machine.succeed("nft list table inet annixion_vpn_killswitch")
        assert "cgroupv2" in ruleset, ruleset
        # The accept rule must name the live device: no interface is
        # literally called "wg*", so a glob here would match nothing.
        assert 'oifname "wg0"' in ruleset, ruleset
        assert "wg*" not in ruleset, ruleset
        # Plaintext DNS on loopback must be rejected, or a local resolver
        # would forward queries from outside the cgroup and escape it.
        assert "dport 53" in ruleset, ruleset

    with subtest("with a tunnel, the runner places its process in the slice"):
        # The process must land in the enforced slice, or nftables has
        # nothing to match and enforces nothing.
        cgroup = machine.succeed(
            asOperator.format("annixion-vpn-run cat /proc/self/cgroup")
        )
        assert "annixion-vpn.slice" in cgroup, cgroup
        machine.succeed("ip link del wg0")

    with subtest("a vendor-named, policy-routed tunnel is detected"):
        # Regression, both halves of one bug: "ee-tll-wg-001" is matched
        # by no "wg*" glob, and its default route lives in a private
        # table reached by an fwmark rule, leaving main empty.
        machine.succeed("ip link add ee-tll-wg-001 type wireguard")
        machine.succeed("ip addr add 10.69.105.122/32 dev ee-tll-wg-001")
        machine.succeed("ip link set ee-tll-wg-001 up")
        machine.succeed("ip route add default dev ee-tll-wg-001 table 52038")
        machine.succeed("ip route show dev ee-tll-wg-001 | (! grep -q .)")
        assert "ee-tll-wg-001" in machine.succeed("annixion-vpn-detect")

    with subtest("its real name reaches the ruleset"):
        machine.succeed("annixion-vpn-killswitch-load")
        ruleset = machine.succeed("nft list table inet annixion_vpn_killswitch")
        assert 'oifname "ee-tll-wg-001"' in ruleset, ruleset

    with subtest("WireGuard's own encapsulated egress is permitted"):
        # Regression: the outer packet keeps the inner packet's socket,
        # so the cgroup match catches it, and its fwmark routes it out
        # the physical interface rather than the tunnel. Rejecting it
        # stops the tunnel transmitting at all -- and because the inner
        # packet was accepted, the app hangs to timeout instead of
        # failing fast, which reads as a dead VPN rather than a block.
        machine.succeed("wg set ee-tll-wg-001 fwmark 0xcb46")
        machine.succeed("annixion-vpn-killswitch-load")
        ruleset = machine.succeed("nft list table inet annixion_vpn_killswitch")
        # nft renders marks zero-padded, so match the value rather than
        # the literal spelling passed to `wg set`.
        assert "meta mark" in ruleset, ruleset
        assert "cb46 accept" in ruleset, ruleset
        machine.succeed("ip link del ee-tll-wg-001")

    with subtest("enforced processes resolve inside the cgroup"):
        # Regression: glibc delegates lookups to nscd, which runs outside
        # the cgroup, so DNS escaped the killswitch entirely and would
        # have kept resolving in the clear after the tunnel dropped.
        machine.succeed("ip link add wg0 type dummy")
        machine.succeed("ip addr add 10.99.0.2/24 dev wg0")
        machine.succeed("ip link set wg0 up")
        resolv = machine.succeed(
            asOperator.format("annixion-vpn-run cat /etc/resolv.conf")
        )
        assert "9.9.9.10" in resolv, resolv
        # The nscd socket must be gone, or glibc would hand the query
        # straight back to the daemon and out of the cgroup again.
        machine.fail(asOperator.format("annixion-vpn-run test -S /run/nscd/socket"))
        machine.succeed("ip link del wg0")

    with subtest("an interface with no route does not count as a tunnel"):
        machine.succeed("ip link add tun9 type dummy")
        machine.succeed("ip link set tun9 up")
        # Up, tunnel-shaped name, but routes nothing — must not qualify,
        # or the launcher would open a window the killswitch then blocks.
        # Link-local v6 and the local table are present here and must not
        # be mistaken for a usable route.
        machine.fail("annixion-vpn-detect")
  '';
}
