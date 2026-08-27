{
  name = "annixion-xrdp-session";

  nodes.machine =
    { ... }:
    {
      imports = [ ../modules/xrdp.nix ];

      users.users.operator = {
        isNormalUser = true;
        uid = 1000;
        password = "test";
      };

      virtualisation.memorySize = 1024;
    };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # A user manager that outlives the session it was set up for keeps
    # graphical-session.target active against a dead DISPLAY, and the next
    # login finds Plasma already started. Nobody is logged in here.
    machine.fail("systemctl is-active user@1000.service")

    # Unsetting linger is not enough: NixOS only runs disable-linger for
    # users set false, so a machine that already lingers keeps lingering.
    machine.succeed("loginctl enable-linger operator")
    machine.succeed("systemctl restart linger-users.service")
    machine.fail("test -e /var/lib/systemd/linger/operator")

    # Enhanced Session needs vmconnect. Console logging is what puts xrdp's
    # own log in the journal, where a failed connection can be read back.
    machine.succeed("grep -qx 'vmconnect=true' /etc/xrdp/xrdp.ini")
    machine.succeed("grep -qx 'EnableConsole=true' /etc/xrdp/xrdp.ini")
    machine.succeed("grep -qx 'EnableConsole=true' /etc/xrdp/sesman.ini")
  '';
}
