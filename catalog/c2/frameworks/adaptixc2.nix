# Extensible C2 — Go teamserver and Qt operator client
_: {
  package =
    p:
    let
      version = "1.2";

      src = p.fetchzip {
        url = "https://github.com/Adaptix-Framework/AdaptixC2/archive/refs/tags/v${version}.tar.gz";
        sha256 = "1nwh8xxqz4hy73v0mq6h6dcdzzlrbbv100h7s8y6w3jizajix7j5";
      };

      # Teamserver. GOWORK=off so the module vendors on its own rather than as
      # part of the repo's go.work; the extenders beside it are separate modules.
      server = p.buildGoModule {
        pname = "adaptixserver";
        inherit version src;
        modRoot = "AdaptixServer";
        subPackages = [ "." ];
        vendorHash = "sha256-PT1FP9WPp0MPFCzUIqbN0ds4zRXFZdQl+PpjtEte3ZY=";
        env = {
          GOEXPERIMENT = "jsonv2,greenteagc";
          GOWORK = "off";
        };
        ldflags = [
          "-s"
          "-w"
        ];
        doCheck = false;
        postInstall = ''
          mv $out/bin/AdaptixServer $out/bin/adaptixserver
          install -Dm644 profile.yaml ssl_gen.sh 404page.html -t $out/share/adaptixc2
        '';
      };

      # Operator console. KDDockWidgets, qlementine and Konsole ride along under
      # Libs/, so the only external deps are Qt6, OpenSSL and xkbcommon.
      client = p.stdenv.mkDerivation {
        pname = "adaptixclient";
        inherit version src;
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
    in
    p.symlinkJoin {
      name = "adaptixc2-${version}";
      paths = [
        client
        server
      ];
    };

  name = "AdaptixC2";
  genericName = "Adversary Emulation & C2 Framework";
  comment = "Extensible C2 — Go teamserver and Qt operator client";
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
