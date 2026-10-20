{
  name = "annixion-offensive-net";

  nodes.machine =
    { ... }:
    {
      imports = [
        ../../system/hardening.nix
        ../../system/offensive-net.nix
      ];

      annixion.offensiveNet.enable = true;
      networking.nftables.enable = true;

      users.users.operator = {
        isNormalUser = true;
        password = "test";
      };

      virtualisation.memorySize = 1024;
    };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("nftables.service")

    # A tunnel-shaped interface to open inbound on.
    machine.succeed("ip link add tun0 type dummy")
    machine.succeed("ip link set tun0 up")

    with subtest("boots disarmed"):
        machine.fail("systemctl is-active --quiet annixion-offensive.service")
        machine.succeed(
            "nft list chain inet nixos-fw input | (! grep -q annixion-offensive)"
        )
        assert machine.succeed(
            "cat /proc/sys/net/ipv4/conf/all/accept_redirects"
        ).strip() == "0"

    with subtest("arm opens tun0 inbound"):
        machine.succeed("annixion-offensive on")
        machine.succeed("systemctl is-active --quiet annixion-offensive.service")
        chain = machine.succeed("nft list chain inet nixos-fw input")
        assert 'iifname "tun0" accept comment "annixion-offensive"' in chain, chain

    with subtest("arm flips the MITM sysctls over hardening"):
        for key in [
            "net.ipv4.conf.all.accept_redirects",
            "net.ipv4.conf.all.send_redirects",
            "net.ipv4.conf.all.accept_source_route",
        ]:
            path = "/proc/sys/" + key.replace(".", "/")
            val = machine.succeed("cat " + path).strip()
            assert val == "1", key + " = " + val

    with subtest("real NICs stay closed while armed"):
        # Only tun0 is trusted; no other interface is accepted by our rules.
        machine.succeed(
            "nft list chain inet nixos-fw input | grep annixion-offensive "
            "| (! grep -qE 'eth[0-9]')"
        )

    with subtest("arming is idempotent"):
        # Run the arm step again directly; the guard must not add a duplicate.
        arm = machine.succeed(
            "systemctl show -p ExecStart --value annixion-offensive.service"
        ).split("path=")[1].split(" ")[0]
        machine.succeed(arm)
        machine.succeed(arm)
        count = machine.succeed(
            "nft list chain inet nixos-fw input | grep -c annixion-offensive"
        ).strip()
        assert count == "1", "expected one tagged rule, found " + count

    with subtest("disarm restores the hardened state"):
        machine.succeed("annixion-offensive off")
        machine.fail("systemctl is-active --quiet annixion-offensive.service")
        machine.succeed(
            "nft list chain inet nixos-fw input | (! grep -q annixion-offensive)"
        )
        assert machine.succeed(
            "cat /proc/sys/net/ipv4/conf/all/accept_redirects"
        ).strip() == "0"
  '';
}
