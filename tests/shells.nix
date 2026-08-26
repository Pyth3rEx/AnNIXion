{
  name = "annixion-shells";

  nodes.machine =
    { pkgs, ... }:
    {
      imports = [ ../modules/shell.nix ];

      users.users.operator = {
        isNormalUser = true;
        password = "test";
        uid = 1000;
      };

      # The prompt and the tint are asserted against the same sources the
      # system wires in, so the test cannot pass on a stale copy.
      environment.etc."annixion/omp-theme.json".source =
        (pkgs.formats.json { }).generate "oh-my-posh.json"
          (import ../home/zsh/omp-theme.nix);
      environment.systemPackages = [ pkgs.oh-my-posh ];

      virtualisation.memorySize = 1024;
    };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # oh-my-posh serves a cached prompt per session; without an empty cache the
    # renders below would not reflect the config under test.
    posh = (
        "OMP_CACHE_DIR=$(mktemp -d) oh-my-posh print primary --shell zsh "
        "--config /etc/annixion/omp-theme.json --terminal-width 80"
    )
    # The session segment's background, as oh-my-posh emits it.
    BLUE = "48;2;126;186;228"
    RED = "48;2;255;0;51"

    with subtest("every login shell is zsh"):
        for who in ("operator", "root"):
            shell = machine.succeed(f"getent passwd {who} | cut -d: -f7").strip()
            assert shell.endswith("/zsh"), f"{who} landed in {shell}, not zsh"

    with subtest("the operator's prompt names the operator"):
        out = machine.succeed(f"su -l operator -c '{posh}'")
        assert "operator @" in out, out

    with subtest("root's prompt is marked ROOT"):
        out = machine.succeed(posh)
        assert "ROOT" in out, out

    with subtest("a nix-shell is marked at an ordinary width"):
        out = machine.succeed(f"su -l operator -c 'IN_NIX_SHELL=impure {posh}'")
        assert "❄" in out, out
        plain = machine.succeed(f"su -l operator -c '{posh}'")
        assert "❄" not in plain, plain

    with subtest("the session segment flips blue inside a nix-shell"):
        out = machine.succeed(f"su -l operator -c 'export IN_NIX_SHELL=impure; {posh}'")
        assert BLUE in out, out

    with subtest("and stays on the default background outside one"):
        out = machine.succeed(f"su -l operator -c '{posh}'")
        assert BLUE not in out, out
        assert RED not in out, out

    with subtest("root flips it red, and outranks a nix-shell"):
        out = machine.succeed(posh)
        assert RED in out, out
        both = machine.succeed(f"export IN_NIX_SHELL=impure; {posh}")
        assert RED in both, both
        assert BLUE not in both, "a root nix-shell read as blue, hiding root"

  '';
}
