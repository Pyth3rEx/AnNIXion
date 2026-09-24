# AdaptixC2 on AnNIXion

This page covers only what is specific to running AdaptixC2 on AnNIXion — how it
is packaged, how to build and start the teamserver, and the wrapper that drives
it. For using the framework itself — writing profiles, generating beacons,
operating agents — see the upstream
[AdaptixC2 documentation](https://adaptix-framework.gitbook.io/).

---

## What ships, and why it is split

AnNIXion packages AdaptixC2 in two halves:

- **The operator client is a native Nix build.** `AdaptixClient` is a normal Qt
  application on your `PATH`, with a menu entry under **C2 › Frameworks**. It
  builds cleanly in the sandbox and needs no container.
- **The teamserver and its extenders run in Docker.** The extenders — the
  payload and beacon generators — need cross toolchains (MinGW and the
  `go-win7` runtime) that cannot be fetched or built inside a pure Nix
  derivation. Rather than ship a teamserver that cannot generate payloads,
  AnNIXion drives the upstream Docker build at runtime through a wrapper called
  `adaptixc2`.

So `rebuild` gives you the client, the `adaptixc2` wrapper, and the
Extension-Kit file — but not a built teamserver. You build that once, on demand,
with the wrapper.

---

## First run

The teamserver image is compiled from source inside a container the first time,
so the first build pulls a base image and needs network. After that it is cached.

```bash
adaptixc2 build server-ext    # compile the teamserver + all extenders (once)
adaptixc2 up                  # start the teamserver container
AdaptixClient                 # launch the operator console (or use the menu)
```

In the client's connect dialog, point at the teamserver on **`127.0.0.1:4321`**,
endpoint **`/endpoint`**, with the credentials from your `profile.yaml` (see
[Configuring the teamserver](#configuring-the-teamserver) — change the defaults
before you build). Once connected, load the Extension-Kit to enable payload and
beacon generation:

```bash
adaptixc2 kit                 # prints the path to extension-kit.axs
```

Load that file from the client's extension menu.

---

## The `adaptixc2` wrapper

Every subcommand maps onto an upstream `make` target and runs it against a
writable copy of the pinned source. This is also the seam the installer selects
components against — a "client only" profile simply never calls `build`.

| Command | What it does | Upstream target |
|---|---|---|
| `adaptixc2 build server-ext` | teamserver + all extenders (**default**) | `docker-build-server-ext` |
| `adaptixc2 build server` | teamserver, no extenders | `docker-build-server` |
| `adaptixc2 build extenders` | extenders only | `docker-build-extenders` |
| `adaptixc2 build client` | client AppImage (the native client is preferred) | `docker-build-client` |
| `adaptixc2 build all` | teamserver + extenders | `docker-build-all` |
| `adaptixc2 up` | start the teamserver | `docker-up` |
| `adaptixc2 down` | stop it | `docker-down` |
| `adaptixc2 restart` | restart it (e.g. after editing the profile) | `docker-restart` |
| `adaptixc2 logs` | follow teamserver logs | `docker-logs` |
| `adaptixc2 status` | list running `adaptix` containers | — |
| `adaptixc2 setup` | (re)materialise the source checkout | — |
| `adaptixc2 kit` | print the Extension-Kit `.axs` path | — |

`build` with no argument means `server-ext`. `adaptixc2 --help` prints the same
table.

The wrapper checks its preconditions and fails with a plain message rather than a
raw Docker error: it verifies the Docker daemon is reachable before any target,
and `up`/`restart` refuse to run until a teamserver has actually been built.

---

## Where things live

The wrapper keeps a writable checkout under your home — the pinned Nix source is
read-only, and Docker needs somewhere to write build output:

```
~/.local/share/adaptixc2/src/                       # source checkout
└── AdaptixServer/server-dist/                       # build output
    ├── adaptixserver  profile.yaml  ssl_gen.sh      # server + config
    ├── extenders/                                   # compiled extenders
    └── data/                                         # teamserver state (persists)
```

`adaptixc2 setup` refreshes the source but never touches `server-dist/`, so your
build output and the `data/` directory survive a re-setup. `setup` runs
automatically the first time you `build` or `up`.

---

## Configuring the teamserver

The listener, endpoint and credentials come from `profile.yaml`. The upstream
defaults are **insecure and public** — change them before your first build:

- master `password: "pass"`, plus `operator1:"pass1"` / `operator2:"pass2"`
- `interface: "0.0.0.0"`, `port: 4321`, `endpoint: "/endpoint"`

Edit the copy the build uses, then rebuild or restart:

```bash
$EDITOR ~/.local/share/adaptixc2/src/AdaptixServer/profile.yaml   # before first build
# ...or, after a build, edit server-dist/profile.yaml and:
adaptixc2 restart
```

The runtime mounts `server-dist/profile.yaml` read-only, so a `restart` is enough
to pick up an edit there — no rebuild needed.

---

## Rootless Docker and the listener

AnNIXion's Docker daemon is rootless (see
[hardening.md](hardening.md#docker)). The teamserver runs with host networking so
its listener is reachable on the host's ports. Under a rootless daemon that
mostly works, but binding some ports — anything below 1024, or a raw socket a
listener profile asks for — is not something rootless grants. If a listener fails
to bind, switch to a rootful daemon:

```nix
# user/configuration.nix
annixion.docker.rootless = false;
```

That trade-off, and what a rootful daemon costs, is documented in
[hardening.md](hardening.md#docker).

---

## Updating

The version is pinned in `catalog/c2/frameworks/adaptixc2.nix` (the `version`
string and the two source hashes). Bump those, `rebuild` to get the new client
and wrapper, then refresh the teamserver source and rebuild the image:

```bash
adaptixc2 setup               # pull the new pinned source into the checkout
adaptixc2 build server-ext    # recompile the teamserver + extenders
adaptixc2 restart
```
