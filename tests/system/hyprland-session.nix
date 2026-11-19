{
  name = "annixion-hyprland-session";

  nodes.machine = _: {
    imports = [ ../../system/hyprland.nix ];

    users.users.operator = {
      isNormalUser = true;
      uid = 1000;
      password = "test";
    };

    services.getty.autologinUser = "operator";

    # No real GPU in the test VM. virtio-gpu gives Aquamarine's DRM backend a
    # device to open — the same fix NixOS's own sway test uses — on top of
    # the headless output Hyprland always creates regardless (Compositor.cpp
    # registers headless as AQ_BACKEND_REQUEST_MANDATORY).
    virtualisation.qemu.options = [
      "-vga none"
      "-device virtio-gpu-pci"
    ];

    programs.bash.loginShellInit = ''
      if [ "$(tty)" = "/dev/tty1" ]; then
        Hyprland > /tmp/hyprland.log 2>&1 &
        disown
      fi
    '';
  };

  testScript = ''
    import json

    machine.wait_for_unit("multi-user.target")

    # Session registration at SDDM (the "offered alongside Plasma" half of
    # #223) is a fact about a built derivation, not something that needs a
    # boot — tests/shell/greeter-session.sh checks it there.

    # ── The security wrapper Hyprland needs for SCHED_RR ────────────────────
    machine.succeed("getcap /run/wrappers/bin/Hyprland | grep -q cap_sys_nice")

    # ── hyprlock's PAM stack ─────────────────────────────────────────────────
    # Without this, system/hyprland.nix's home-manager side ships a lock
    # screen that renders but accepts no password.
    machine.succeed("test -f /etc/pam.d/hyprlock")

    # ── The compositor actually starts and answers over IPC ─────────────────
    # "-i 0" picks the sole running instance by index — hyprctl otherwise
    # insists on $HYPRLAND_INSTANCE_SIGNATURE, which a bare `su` never gets.
    user = "su operator -c 'XDG_RUNTIME_DIR=/run/user/1000 hyprctl -i 0 %s'"

    machine.wait_for_file("/run/user/1000/wayland-1")
    machine.wait_until_succeeds(user % "monitors -j")

    monitors = machine.succeed(user % "monitors -j")
    assert len(json.loads(monitors)) > 0, "Hyprland started with no monitor"

    # hyprlock itself needs a real GL context to render the lock surface,
    # which this VM's virtio-gpu/software path does not reliably give it —
    # exercising an actual unlock here trades a fast, reliable check for a
    # flaky one. Its PAM stack (above) is what this test can promise; its
    # generated config is read directly, with no VM, by the fixture tests.
  '';
}
