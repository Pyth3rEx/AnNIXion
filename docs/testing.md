# Testing

Every feature ships with its tests, in the same pull request as the feature.

That is the whole policy. The rest of this document is what it means in
practice: which kind of test a given change needs, where it goes, and how it
gets run.

---

## Why the rule is absolute

This is a distribution for offensive work, and the failure that matters most is
not a crash. It is a tool that runs, exits zero, and tells you something untrue
— a VPN killswitch that reports itself active while leaking, a zone transfer
that reads as refused because the workstation hijacked port 53. Nobody notices
those from the desktop. They are noticed on an engagement, in a report, once.

A feature without a test is a claim nobody checked. The tree makes a great many
claims — that the browser forgets, that the prompt marks a `nix-shell`, that a
token cannot do more than its job — and each one is only as good as the thing
that re-checks it on every push.

Tests are also the only durable form of the reasoning behind a change. A commit
message explains a decision once; a test enforces it forever. When a test is
written to cover a bug, it stops that specific bug returning under a different
name.

---

## What "its tests" means

A test has to be able to fail for the reason the feature exists. That is the
bar, and it rules out most of what gets written to satisfy a policy.

- **A change to a script** needs a fixture test that drives the real script.
  Not a reimplementation of its logic — the actual entry point, through its
  own flags. A test that reimplements the decision it is checking passes
  forever, including after the script stops agreeing with it.
- **A change to a module** needs a `nixosTest` that boots it and asserts the
  behaviour, not the configuration. `services.foo.enable = true` evaluating is
  L1's job. Whether the service does the thing is this one's.
- **A change to CI or repository automation** needs a fixture test as well.
  `tests/workflow-injection.sh` and `tests/workflow-permissions.sh` exist
  because a workflow is code that runs with a token, and it is the one kind of
  code that cannot be tried locally before it matters.
- **A bug fix** needs a test that fails before the fix. If you cannot write one,
  say so in the pull request and explain why — that is a reviewable position.
  Skipping it silently is not.

**Where a test genuinely does not apply** — documentation, comments, cosmetic
theming, a version bump — say so in the pull request in one line. Reviewers
should not have to guess whether it was considered or forgotten.

---

## The two kinds

| | Fixture tests (`tests/*.sh`) | VM tests (`tests/*.nix`) |
|---|---|---|
| What they are | Plain shell, driving a real script | `nixosTest` — boots one or more machines in QEMU |
| What they prove | A decision is made correctly | A system behaves correctly once running |
| Runtime | Under a second | Minutes; needs KVM |
| Level | L0, in the **Lint** job | L3, in the **Nix CI** job |
| Wiring | Add a line to the `[L0] Script tests` step | Add a line to `checks` in `flake.nix` |

Prefer a fixture test when the thing under test is a decision — which milestone,
which column, which review has gone stale. They run in the time it takes to read
the output, so they get run.

Reach for a VM test when the claim only becomes true on a booted system: a unit
that has to be active, a firewall that has to drop, a file that has to exist at
a path a module chose.

---

## The suite as it stands

**Fixture tests — L0**

| Test | What it covers |
|---|---|
| `tests/milestone.sh` | Which milestone new work lands on, and the column that implies. Drives `assign-milestone.sh` and `board-status.sh` through `--select` and `--decide`. |
| `tests/prompt-width.sh` | The prompt's responsive ladder: the top line never wraps, and a `nix-shell` stays marked, at every width. Renders the theme the repository ships. |
| `tests/firefox-profiles.sh` | Which profile owns a link, whether the throwaway one forgets, and whether a launcher can receive a URL at all. |
| `tests/menu-icons.sh` | That every `Icon=` the application menu writes resolves to a real file in the theme the desktop selects, and that every un-namespaced file in that theme is an alias onto a mark that exists. A name that resolves nowhere draws a blank placeholder rather than erroring. |
| `tests/branding.sh` | That the boot splash, the greeter and the installer image are still the AnNIXion ones. All three fail quietly — Plymouth to a black screen, SDDM to stock Breeze, the ISO to NixOS artwork. |
| `tests/etc-hosts.sh` | That `/etc/hosts` stays a real file root can edit, and stays world-readable. At `0700` the rootless daemon hangs in `activating` forever, which parks `default.target` and with it any `nixos-rebuild switch`. |
| `tests/workflow-injection.sh` | That no workflow interpolates a `${{ }}` expression into a `run:` block, where text a stranger can write becomes shell. |
| `tests/workflow-permissions.sh` | That every job declares what its token may do, rather than inheriting a ceiling set in a web UI. |
| `tests/stale-reviews.sh` | When an unanswered review goes stale, driven through the real script's `--decide`. |
| `tests/pr-column.sh` | Which board column a pull request lands in as it opens, moves in and out of draft, or is closed unmerged — and that `project.yml` still receives those events. |
| `tests/sbom.sh` | That both release SBOMs are generated, measured and published — and that the ways they degrade silently are refused: a store path in place of a flakeref, a document with no components, a runtime SBOM where nothing carries a licence, a build closure that no longer contains the runtime one. Drives the real script with `sbomnix` and `nix` stubbed. |
| `tests/supply-chain.sh` | That the readable page keeps the installed closure and the build-only inputs apart — a compiler that never ships must not appear in the half a reader treats as their exposure — and that it still says, in words, why the two halves are not to be added together. |
| `tests/dns-axfr.sh` | That a zone transfer actually leaves this machine, and that an intercepting resolver is named as such rather than read as a locked-down zone. **The one test that uses the network.** |

**VM tests — L3**

| Test | What it covers |
|---|---|
| `tests/boot.nix` | The system boots, and the services a login depends on come up. |
| `tests/security-tools.nix` | The security toolset is actually on `PATH` on a built system. |
| `tests/vpn-enforcement.nix` | The killswitch: what is allowed out, what is not, and what happens when the tunnel drops. |
| `tests/shells.nix` | The shell module — prompt and tint asserted against the same sources the system wires in, so it cannot pass on a stale copy. |
| `tests/xrdp-session.nix` | That a user manager does not outlive the session it was set up for, that a connection takes over a desktop that is already running rather than waiting on a D-Bus name it cannot have, and that Enhanced Session stays configured. |
| `tests/bind-axfr.nix` | A real zone transfer between two machines, and `dns-axfr.sh` driven against a server we control — the AXFR path with no network involved. |
| `tests/git-credential-helper.nix` | That a push can find its credentials: the gh helper is configured for every user, and the binary it names is one the system still has. |
| `tests/docker.nix` | That the container runtime is the rootless one: the daemon belongs to the user, its socket is the one the CLI is pointed at, and neither a root daemon nor a `docker` group exists. |

---

## Running them

```bash
# L0 — fixture tests. Fast enough to run on every save.
.github/scripts/lint.sh
tests/milestone.sh
tests/prompt-width.sh
tests/firefox-profiles.sh
tests/menu-icons.sh
tests/branding.sh
tests/etc-hosts.sh
tests/workflow-injection.sh
tests/workflow-permissions.sh
tests/stale-reviews.sh
tests/pr-column.sh
tests/dns-axfr.sh   # the one that needs the internet

# L1 — evaluates every VM test without building any of them.
nix flake check --no-build

# L3 — one VM test
nix build .#checks.x86_64-linux.bind-axfr --print-build-logs --no-link

# L3 — all of them, the same way CI discovers them
nix build $(nix eval --json '.#checks.x86_64-linux' --apply builtins.attrNames \
  | jq -r '.[] | ".#checks.x86_64-linux." + .') --print-build-logs --no-link
```

VM tests need KVM. `ls /dev/kvm` — if it is missing, they will not run locally
and CI is where they get their first pass.

---

## Wiring a new test in

**A fixture test** goes in the `[L0] Script tests` step of
`.github/workflows/ci.yml`, one line per test. It is listed explicitly, so a
test that is written and not listed will never run — check the step when you
add one.

**A VM test** goes in `checks` in `flake.nix`:

```nix
checks.${system} = {
  # …
  bind-axfr = pkgs.testers.nixosTest (import ./tests/bind-axfr.nix);
};
```

CI's `[L3]` step discovers every check the flake defines rather than listing
them, so wiring it in is all that is required. That asymmetry is deliberate: a
VM test cannot be forgotten, and a fixture test is cheap enough that the
explicit list is worth its cost in review.

---

## Conventions

- **Drive the real thing.** Fixture tests call the script's own entry point
  through its own flags. A test that reimplements the logic it checks cannot
  detect the logic changing.
- **Assert behaviour, not configuration.** That a file contains a setting is
  usually L1's business. That the setting has an effect is the test's.
- **No network, unless the network is the subject.** `tests/dns-axfr.sh` is the
  single exception in the tree, and it is deliberately isolated in its own CI
  step so a red build there points at the network rather than at the hermetic
  tests beside it. `tests/bind-axfr.nix` is what covers the same code path when
  the network is not available.
- **Name the failure.** An assertion that fails should print what it expected
  and what it got. Somebody reading the CI log has no access to your terminal.
- **Cover the case that is easy to get wrong**, and say in a comment why it is
  easy to get wrong. That comment is usually worth more than the assertion.

---

See [dev.md](dev.md) for the CI levels in full, the VSCodium tasks, and the
pre-push checklist.
