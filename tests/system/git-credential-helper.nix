{
  name = "annixion-git-credential-helper";

  nodes.machine = {
    imports = [ ../../system/git.nix ];

    users.users.operator = {
      isNormalUser = true;
      uid = 1000;
    };

    virtualisation.memorySize = 1024;
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    hosts = ("https://github.com", "https://gist.github.com")

    with subtest("every user gets the helper, without running gh auth setup-git"):
        for host in hosts:
            for who in ("root", "operator"):
                out = machine.succeed(
                    f"su -l {who} -c 'git config --get \"credential.{host}.helper\"'"
                ).strip()
                assert out.endswith("gh auth git-credential"), f"{who}/{host}: {out!r}"

    with subtest("the binary it names is really on this system"):
        # The failure this test exists for: a helper naming a store path that
        # garbage collection has taken. It starts, fails to exec, and git
        # falls back to asking for a password nobody has.
        for host in hosts:
            helper = machine.succeed(
                f"git config --get \"credential.{host}.helper\""
            ).strip()
            machine.succeed(f"test -x {helper.split()[0]}")

    with subtest("git runs it for a github URL"):
        # No token in the VM, so filling the credential fails — but it has to
        # fail asking for one, not failing to start the helper.
        out = machine.fail(
            "printf 'protocol=https\nhost=github.com\n\n' "
            "| GIT_TERMINAL_PROMPT=0 git credential fill 2>&1"
        )
        assert "No such file or directory" not in out, out
        assert "terminal prompts disabled" in out, out
  '';
}
