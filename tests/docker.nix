{
  name = "annixion-docker";

  nodes.machine =
    { ... }:
    {
      imports = [ ../modules/docker.nix ];

      users.users.operator = {
        isNormalUser = true;
        password = "test";
        uid = 1000;
      };

      # Image tooling closure plus a daemon.
      virtualisation.memorySize = 2048;
    };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # The runtime, and the plugins the CLI carries rather than the module.
    machine.succeed("which docker")
    machine.succeed("docker compose version")
    machine.succeed("docker buildx version")

    # Image tooling.
    machine.succeed("which docker-compose")
    machine.succeed("which lazydocker")
    machine.succeed("which dive")
    machine.succeed("which ctop")
    machine.succeed("which skopeo")
    machine.succeed("which trivy")

    # Rootless is the default, so the two things the rootful path would
    # add are both absent: a root daemon, and a root-equivalent group.
    machine.fail("systemctl cat docker.service")
    machine.fail("getent group docker")

    # The daemon is a user unit, and it comes up for that user. Linger
    # returns before the manager is up, so wait for that first — the
    # user bus it answers on does not exist until then.
    machine.succeed("loginctl enable-linger operator")
    machine.wait_for_unit("user@1000.service")
    machine.wait_for_unit("docker.service", user="operator")

    # Pointing the CLI at that socket is /etc/set-environment's job, and
    # it only fires for a session that has a runtime dir. Supply one, and
    # clear the guard that stops a child shell sourcing the file twice.
    host = machine.succeed(
        "env -u __NIXOS_SET_ENVIRONMENT_DONE XDG_RUNTIME_DIR=/run/user/1000 "
        "bash -c '. /etc/set-environment; echo $DOCKER_HOST'"
    ).strip()
    assert host == "unix:///run/user/1000/docker.sock", f"DOCKER_HOST is {host!r}"

    # A daemon that answers is the point; `docker version` would pass
    # against a dead socket.
    machine.wait_until_succeeds(
        f"su operator -c 'env DOCKER_HOST={host} docker info'", timeout=120
    )

    # Rootless means unprivileged, whatever the daemon says about itself.
    owner = machine.succeed("stat -c %U /run/user/1000/docker.sock").strip()
    assert owner == "operator", f"socket owned by {owner!r}"
  '';
}
