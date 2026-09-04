{
  name = "annixion-xrdp-session";

  nodes.machine =
    { ... }:
    {
      imports = [ ../../system/xrdp.nix ];

      users.users.operator = {
        isNormalUser = true;
        uid = 1000;
        password = "test";
      };

      virtualisation.memorySize = 1024;
    };

  testScript =
    { nodes, ... }:
    ''
      launcher = "${nodes.machine.services.xrdp.defaultWindowManager}"

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

      # Block buffered, that log reaches the journal minutes late and every
      # forked session replays the parent's unflushed buffer.
      machine.succeed("systemctl cat xrdp | grep -E '^ExecStart=.*/stdbuf -oL -eL .*/xrdp '")

      # ── Taking over a desktop that is already running ──────────────────
      # The session launcher has to stop the old workspace, or this session's
      # kwin waits forever on a D-Bus name the console session owns.
      takeover = machine.succeed(
          f"grep -o '/nix/store/[^ ]*annixion-take-over-session' {launcher}"
      ).strip()

      user = "su operator -c 'XDG_RUNTIME_DIR=/run/user/1000 %s'"

      # A login is what holds the user manager up on a real machine. Linger
      # stands in for one here — without it the manager exits the moment it
      # has nothing to do, and there is no workspace to take over.
      machine.succeed("loginctl enable-linger operator")
      machine.wait_for_unit("user@1000.service")

      # Stands in for the console session's compositor: wired to the target
      # the workspace hangs off the way Plasma wires its own units, and named
      # what the launcher waits on. Requires pulls the target up, which is
      # the only way to start it — it refuses to be started by hand.
      machine.succeed(
          user % (
              "systemd-run --user --unit=plasma-kwin_x11"
              " --property=PartOf=graphical-session.target"
              " --property=Requires=graphical-session.target"
              " --property=After=graphical-session.target -- sleep 3000"
          )
      )
      machine.succeed(user % "systemctl --user is-active graphical-session.target")
      machine.succeed(user % "systemctl --user is-active plasma-kwin_x11.service")

      # The launcher must not reach Plasma before that process is gone.
      machine.succeed(user % takeover)
      machine.fail(user % "systemctl --user is-active plasma-kwin_x11.service")

      # It runs on a machine with no desktop up at all, which is every first
      # connection after a boot.
      machine.succeed(user % takeover)
    '';
}
