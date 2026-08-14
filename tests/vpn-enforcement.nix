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
        # The slice lives under the user manager, whose cgroup path nft
        # resolves at load time, so it must run with nobody logged in.
        linger = true;
      };

      # kdialog is a heavy closure used only for the hard-fail dialog;
      # the test drives the CLI paths.
      annixion.vpnEnforcement.browserPackage = pkgs.hello;

      # Detection keys off link kind, so the regression test needs a real
      # WireGuard device, not a dummy.
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
        # Burp goes through this path; unconfined, Red Team's enforcement
        # would be meaningless.
        machine.fail(asOperator.format("annixion-vpn-run true"))

    with subtest("killswitch refuses to load before the slice exists"):
        machine.fail("annixion-vpn-killswitch-load")

    with subtest("killswitch refuses to load with a slice but no tunnel"):
        machine.succeed(asOperator.format("systemctl --user start annixion-vpn.slice"))
        # systemd nests "-"-separated names: annixion-vpn.slice sits
        # inside annixion.slice, and the killswitch matches this path.
        machine.succeed(
            "test -d /sys/fs/cgroup/user.slice/user-1000.slice/"
            "user@1000.service/annixion.slice/annixion-vpn.slice"
        )
        # Accept rules come from the live tunnels; with none there is
        # nothing to permit, and arming would blackhole the slice.
        machine.fail("annixion-vpn-killswitch-load")

    with subtest("a live tunnel satisfies detection"):
        # Dummy named like a tunnel: exercises the name-pattern fallback.
        machine.succeed("ip link add wg0 type dummy")
        machine.succeed("ip addr add 10.99.0.2/24 dev wg0")
        machine.succeed("ip link set wg0 up")
        assert "wg0" in machine.succeed("annixion-vpn-detect")

    with subtest("killswitch loads once a tunnel is up"):
        # nft resolves the cgroupv2 path to an inode here, so a wrong path
        # or malformed ruleset fails at this point.
        machine.succeed("annixion-vpn-killswitch-load")
        machine.succeed("nft list table inet annixion_vpn_killswitch")

    with subtest("loading is idempotent"):
        machine.succeed("annixion-vpn-killswitch-load")
        machine.succeed("annixion-vpn-killswitch-load")

    with subtest("ruleset permits the tunnel that is actually up"):
        ruleset = machine.succeed("nft list table inet annixion_vpn_killswitch")
        assert "cgroupv2" in ruleset, ruleset
        # Must name the live device: no interface is called "wg*".
        assert 'oifname "wg0"' in ruleset, ruleset
        assert "wg*" not in ruleset, ruleset
        # Loopback DNS must be rejected, or a local resolver would
        # forward queries from outside the cgroup.
        assert "dport 53" in ruleset, ruleset

    with subtest("with a tunnel, the runner places its process in the slice"):
        # Must land in the enforced slice, or nftables matches nothing.
        cgroup = machine.succeed(
            asOperator.format("annixion-vpn-run cat /proc/self/cgroup")
        )
        assert "annixion-vpn.slice" in cgroup, cgroup
        machine.succeed("ip link del wg0")

    with subtest("a vendor-named, policy-routed tunnel is detected"):
        # Regression, both halves of one bug: no "wg*" glob matches
        # "ee-tll-wg-001", and its default route lives in a private table
        # reached by an fwmark rule, leaving main empty.
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
        # Regression: the outer packet keeps the inner packet's socket, so
        # the cgroup match catches it on the physical interface. Rejecting
        # it stops the tunnel transmitting at all, and the app hangs to
        # timeout rather than failing fast.
        machine.succeed("wg set ee-tll-wg-001 fwmark 0xcb46")
        machine.succeed("annixion-vpn-killswitch-load")
        ruleset = machine.succeed("nft list table inet annixion_vpn_killswitch")
        # nft renders marks zero-padded, so match the value, not the
        # spelling passed to `wg set`.
        assert "meta mark" in ruleset, ruleset
        assert "cb46 accept" in ruleset, ruleset
        machine.succeed("ip link del ee-tll-wg-001")

    with subtest("enforced processes resolve inside the cgroup"):
        # Regression: glibc delegates lookups to nscd, outside the cgroup,
        # so DNS escaped the killswitch entirely.
        machine.succeed("ip link add wg0 type dummy")
        machine.succeed("ip addr add 10.99.0.2/24 dev wg0")
        machine.succeed("ip link set wg0 up")
        resolv = machine.succeed(
            asOperator.format("annixion-vpn-run cat /etc/resolv.conf")
        )
        assert "9.9.9.10" in resolv, resolv
        # The socket must be gone, or glibc hands the query straight back
        # to the daemon.
        machine.fail(asOperator.format("annixion-vpn-run test -S /run/nscd/socket"))
        machine.succeed("ip link del wg0")

    with subtest("an interface with no route does not count as a tunnel"):
        machine.succeed("ip link add tun9 type dummy")
        machine.succeed("ip link set tun9 up")
        # Up and tunnel-shaped but routes nothing: must not qualify, or
        # the launcher opens a window the killswitch then blocks. The
        # link-local v6 and local-table entries are not usable routes.
        machine.fail("annixion-vpn-detect")
  '';
}
