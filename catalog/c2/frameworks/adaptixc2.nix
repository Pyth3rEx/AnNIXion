# Extensible C2 — dockerised Go teamserver, native Qt operator client.
#
# The teamserver and its extenders (payload/beacon generators) need cross
# toolchains that do not build in a Nix sandbox, so they are built and run
# through the upstream docker flow, driven by the `adaptixc2` wrapper. The Qt
# client builds cleanly in Nix and stays native — it is the menu-facing binary.
# See docs/hardening.md ("Docker") for the rootless daemon this leans on.
_: {
  package =
    p:
    let
      version = "1.2";

      appSrc = p.fetchzip {
        url = "https://github.com/Adaptix-Framework/AdaptixC2/archive/refs/tags/v${version}.tar.gz";
        sha256 = "1nwh8xxqz4hy73v0mq6h6dcdzzlrbbv100h7s8y6w3jizajix7j5";
      };

      extSrc = p.fetchFromGitHub {
        owner = "Adaptix-Framework";
        repo = "Extension-Kit";
        rev = "9413caf85fd83272f5866ef42f9e7ed8db9987d6"; # Latest @ 24/09/2026
        sha256 = "XkFLT910GkVUcwMNI5u3QndHn+qgSQsXtCDeZrluLPA=";
      };

      # Operator console. KDDockWidgets, qlementine and Konsole ride along under
      # Libs/, so the only external deps are Qt6, OpenSSL and xkbcommon.
      client = p.stdenv.mkDerivation {
        pname = "adaptixclient";
        inherit version;
        src = appSrc;
        sourceRoot = "source/AdaptixClient";
        nativeBuildInputs = [
          p.cmake
          p.qt6.wrapQtAppsHook
        ];
        buildInputs = [
          p.qt6.qtbase
          p.qt6.qtwebsockets
          p.qt6.qtdeclarative
          p.qt6.qtsvg
          p.openssl
          p.libxkbcommon
        ];
        installPhase = ''
          runHook preInstall
          install -Dm755 AdaptixClient $out/bin/AdaptixClient
          runHook postInstall
        '';
      };

      # ExtensionKit. The .axs the client loads to generate payloads & beacons.
      extensionKit = p.stdenv.mkDerivation {
        pname = "adaptix-extension-kit";
        inherit version;
        src = extSrc;
        dontConfigure = true;
        dontBuild = true;
        installPhase = ''
          runHook preInstall
          install -Dm644 extension-kit.axs -t $out/share/adaptixc2/extension-kit
          runHook postInstall
        '';
      };

      # Teamserver + extenders driver. The docker build cannot run inside a Nix
      # sandbox, so it happens at runtime: `adaptixc2 build` copies the pinned
      # source into a writable state dir and runs the upstream `make docker-*`
      # targets, which compile inside containers and drop server-dist/ beside it.
      # Component subcommands map 1:1 onto those targets, the seam a future
      # installer selects against (client-only, server-without-extenders, …).
      driver = p.writeShellApplication {
        name = "adaptixc2";
        runtimeInputs = [
          p.coreutils
          p.gnumake
          p.rsync
        ];
        # docker is deliberately not pinned here: system/docker.nix supplies the
        # CLI already carrying the compose plugin the Makefile calls.
        text = ''
          appSrc=${appSrc}
          kit=${extensionKit}/share/adaptixc2/extension-kit/extension-kit.axs
          state="''${XDG_DATA_HOME:-$HOME/.local/share}/adaptixc2"
          src="$state/src"

          die() { echo "adaptixc2: $*" >&2; exit 1; }

          need_docker() {
            command -v docker >/dev/null 2>&1 \
              || die "docker CLI not found — enable annixion.docker (rootless) in your NixOS config."
            docker info >/dev/null 2>&1 \
              || die "cannot reach the docker daemon (rootless starts on first use; try 'systemctl --user start docker')."
          }

          setup() {
            mkdir -p "$src"
            # Refresh the source, but never touch build outputs or the data dir.
            rsync -a --chmod=u+w --delete \
              --exclude server-dist/ \
              --exclude client-dist/ \
              "$appSrc/" "$src/"
            echo "adaptixc2: source materialised at $src"
          }

          ensure_src() { [ -f "$src/Makefile" ] || setup; }

          usage() {
            cat <<'EOF'
          adaptixc2 — drive the dockerised AdaptixC2 teamserver + extenders.

          Build (each maps to an upstream make target):
            build [server-ext]  server + extenders     (docker-build-server-ext, default)
            build server        server, no extenders   (docker-build-server)
            build extenders     extenders only         (docker-build-extenders)
            build client        client AppImage        (docker-build-client)
            build all           server + extenders     (docker-build-all)

          Runtime:
            up | down | logs | restart   teamserver (docker-compose runtime profile)
            status                        running adaptix containers

          Other:
            setup   (re)materialise the pinned source checkout
            kit     print the Extension-Kit .axs path to load in the client

          Notes:
            - The native AdaptixClient (on PATH) is the recommended operator console.
            - Runtime uses host networking; under rootless docker the listener may
              need annixion.docker.rootless = false (see docs/hardening.md).
            - First build pulls base images and compiles in-container — slow, online.
          EOF
          }

          cmd="''${1:-help}"; shift || true
          case "$cmd" in
            setup) setup ;;
            build)
              what="''${1:-server-ext}"
              case "$what" in
                server-ext) target=docker-build-server-ext ;;
                all)        target=docker-build-all ;;
                server)     target=docker-build-server ;;
                extenders)  target=docker-build-extenders ;;
                client)     target=docker-build-client ;;
                *) die "unknown component '$what' (server-ext|server|extenders|client|all)" ;;
              esac
              need_docker; ensure_src
              make -C "$src" "$target"
              ;;
            up | restart)
              need_docker; ensure_src
              [ -f "$src/AdaptixServer/server-dist/adaptixserver" ] \
                || die "no server build found — run 'adaptixc2 build server-ext' first."
              make -C "$src" "docker-$cmd"
              ;;
            down | logs)
              need_docker; ensure_src
              make -C "$src" "docker-$cmd"
              ;;
            status) need_docker; docker ps --filter name=adaptix ;;
            kit) echo "$kit" ;;
            help | -h | --help) usage ;;
            *) usage; exit 1 ;;
          esac
        '';
      };
    in
    p.symlinkJoin {
      name = "adaptixc2-${version}";
      paths = [
        client
        extensionKit
        driver
      ];
    };

  name = "AdaptixC2";
  genericName = "Adversary Emulation & C2 Framework";
  comment = "Extensible C2 — dockerised teamserver, native Qt operator client";
  exec = "AdaptixClient";
  launch = "gui"; # Qt console runs directly
  mark = {
    class = "offensive";
    body = ''
      <path d="M12 2.4 3 20.4M12 2.4l9 18"/>
      <path d="M6.9 13.2q5.1-1.6 10.2 0"/>
      <circle cx="12" cy="9" r="2.1" fill="@c@" stroke="none"/>
      <path d="M12 2.4V6M12 12v3.6"/>
      <path d="M15.7 8.3q2.5 0 4.4 1.4M8.3 8.3q-2.5 0-4.4 1.4"/>
    '';
  };
}
