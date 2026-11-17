# tlog — terminal I/O recorder, vendored rather than taken from nixpkgs: the
# PR that adds it (NixOS/nixpkgs#571777) is still open against master, and our
# pin is nixos-26.05 regardless, so `pkgs.tlog` resolves nowhere today. There
# is no NixOS module for it here either — upstream's own module makes
# tlog-rec-session a setuid login shell that audits every session
# unconditionally, which is the wrong shape for a single operator who wants to
# start recording an engagement on demand. `tlog-engagement` (built below) is
# that on-demand front door instead; see docs/tlog.md and system/tlog.nix,
# which supplies the empty /etc/tlog/*.conf files tlog refuses to start
# without.
#
# Installed system-wide but never shown: no menu entry, no mark.
_: {
  package =
    p:
    let
      tlogPkg = p.stdenv.mkDerivation (finalAttrs: {
        pname = "tlog";
        version = "14";

        src = p.fetchFromGitHub {
          owner = "Scribery";
          repo = "tlog";
          tag = "v${finalAttrs.version}";
          hash = "sha256-OYkYpoJ8TGWlRcBDxCnaNewjDJ6YZwC73lSC5PLH0I4=";
        };

        patches = [
          # GCC 15 defaults to C23, where `f()` means `f(void)`, so the
          # SIGCHLD handler no longer matches sa_handler and the build fails.
          # Fixed on master after v14 — cherry-picked rather than waiting.
          (p.fetchpatch2 {
            name = "add-missing-argument-for-sigchld-handler.patch";
            url = "https://github.com/Scribery/tlog/commit/de6cd0172e1a6603ae04767b96260b1b47b458d1.patch?full_index=1";
            hash = "sha256-g+s2HfWbpkaDMiIIX/3GkGc4QsT4J6/RskDDkh1RraM=";
          })
        ];

        nativeBuildInputs = [
          p.autoreconfHook # also puts the m4 configure.ac needs on PATH
          p.pkg-config
        ];
        buildInputs = [
          p.curl
          p.json_c
        ];

        # tlog-engagement only ever drives the file writer (below), so the
        # journal writer — the only reason to need systemd here — stays out.
        configureFlags = [
          "--sysconfdir=/etc"
          "--localstatedir=/var"
          "--disable-journal"
        ];

        # The default config templates install under sysconfdir otherwise,
        # which collides with the real /etc this is meant to run on.
        # system/tlog.nix supplies what actually lands there.
        installFlags = [ "pkgconflocaldir=${placeholder "out"}/etc/tlog" ];

        enableParallelBuilding = true;

        # Exploit upstream's own build-tree detection — a binary living in a
        # `.libs` directory reads its config from `../` — to smoke-test a
        # real record/replay round trip without /etc/tlog existing yet.
        doInstallCheck = true;
        installCheckPhase = ''
          runHook preInstallCheck

          mkdir -p smoke/.libs
          cp "$out/bin/tlog-rec" "$out/bin/tlog-play" smoke/.libs/
          cp "$out"/etc/tlog/tlog-{rec,play}.conf \
            "$out"/share/tlog/tlog-{rec,play}.default.conf smoke/

          smoke/.libs/tlog-rec --version | grep -qF "tlog ${finalAttrs.version}"
          smoke/.libs/tlog-rec --writer=file --file-path=smoke/rec.json \
            -- ${p.runtimeShell} -c 'echo hello-tlog' </dev/null
          grep -qF hello-tlog smoke/rec.json

          runHook postInstallCheck
        '';

        meta = {
          description = "Terminal I/O recorder and player, driven here through tlog-engagement";
          homepage = "https://github.com/Scribery/tlog";
          license = p.lib.licenses.gpl2Plus;
          mainProgram = "tlog-rec";
          platforms = p.lib.platforms.linux;
        };
      });

      # The opt-in front door: nothing records until this is run, and only
      # the one shell it starts — every other terminal on the box, and every
      # non-interactive session, is untouched. That is the whole difference
      # from upstream's forced-login-shell module.
      driver = p.writeShellApplication {
        name = "tlog-engagement";
        runtimeInputs = [
          p.coreutils
          p.findutils
          p.python3 # push's transcript — already in the closure via reptor
        ];
        # Neither tlog-rec/tlog-play nor reptor are pinned here. tlogPkg is
        # joined into the same package below, so it is already on PATH once
        # installed — pinning it would also shadow a test's own stand-in
        # build-tree copy, since runtimeInputs wins over anything set in the
        # ambient PATH a caller provides. reptor ships separately, with
        # annixion.sysreptor (catalog/tools/productivity/sysreptor.nix,
        # installed by default), which supplies it on PATH the same way.
        text = ''
          state="''${XDG_DATA_HOME:-$HOME/.local/share}/annixion/tlog"

          die() { echo "tlog-engagement: $*" >&2; exit 1; }

          # tlog-rec/tlog-play locate their own /etc/tlog config by inspecting
          # argv[0]'s path, not their real location — invoked by a bare name
          # through PATH, bash hands them argv[0]="tlog-rec" with no
          # directory in it at all, so they always fall back to a hardcoded
          # /etc/tlog even when PATH points at something else first.
          # Resolving to a full path before exec'ing keeps that lookup
          # working the same way it would from an interactive shell.

          usage() {
            cat <<'EOF'
          tlog-engagement — opt-in terminal session recording, per engagement.

            start <name> [--log-input] [-- cmd...]
                                record a shell under that engagement name, or
                                just the given command if one follows '--'
            push [file]         attach a recording to the current SysReptor
                                 project through reptor: the raw recording as
                                 evidence, a plain-text transcript as a note
            list [name]         recordings on disk, all or one engagement's
            play <file>         replay a recording in this terminal

          Notes:
            - Nothing is captured until 'start' is run, and only that one shell
              is recorded — every other shell on the box is untouched.
            - Only output is logged by default. --log-input also logs
              keystrokes, which can capture a password typed mid-session.
            - 'push' needs 'reptor conf' already pointed at a project — see
              docs/sysreptor.md.
          EOF
          }

          cmd="''${1:-help}"; shift || true
          case "$cmd" in
            start)
              [ -n "''${1:-}" ] || die "start needs an engagement name, e.g. 'tlog-engagement start acme-2026-11'"
              [ -z "''${ANNIXION_TLOG_ENGAGEMENT:-}" ] || die "already recording '$ANNIXION_TLOG_ENGAGEMENT' in this shell — exit it first, or open a new terminal."
              name="$1"; shift
              log_input=false
              if [ "''${1:-}" = "--log-input" ]; then
                log_input=true
                shift
              fi
              run=()
              if [ "''${1:-}" = "--" ]; then
                shift
                run=("$@")
              elif [ "$#" -gt 0 ]; then
                die "unknown option '$1'"
              fi
              [ "''${#run[@]}" -gt 0 ] || run=("''${SHELL:-/run/current-system/sw/bin/bash}")
              dir="$state/$name"
              install -d -m 700 "$dir"
              file="$dir/$(date -u +%Y%m%dT%H%M%SZ).tlog.json"
              echo "tlog-engagement: recording '$name' to $file — exit this shell to stop."
              if [ "$log_input" = true ]; then
                echo "tlog-engagement: --log-input is on — keystrokes, including any password typed, are captured."
              fi
              export ANNIXION_TLOG_ENGAGEMENT="$name"
              export ANNIXION_TLOG_FILE="$file"
              tlog_rec=$(command -v tlog-rec) || die "tlog-rec not found on PATH"
              exec "$tlog_rec" --writer=file --file-path="$file" --log-input="$log_input" -- "''${run[@]}"
              ;;
            push)
              file="''${1:-''${ANNIXION_TLOG_FILE:-}}"
              if [ -z "$file" ] && [ -d "$state" ]; then
                file=$(find "$state" -name '*.tlog.json' -printf '%T@ %p\n' 2>/dev/null |
                  sort -rn | head -n1 | cut -d' ' -f2-)
              fi
              [ -n "$file" ] || die "no recording to push — give a path, or run this from inside a shell 'start'ed with tlog-engagement."
              [ -f "$file" ] || die "no such recording: $file"
              command -v reptor >/dev/null 2>&1 || die "reptor not found — it ships with annixion.sysreptor; rebuild to get it."
              transcript=$(mktemp --suffix=.txt)
              trap 'rm -f "$transcript"' EXIT
              # Not tlog-play: it replays at real speed over a live control-key
              # read loop, which hangs indefinitely once stdin hits EOF — fine
              # at an interactive terminal, fatal in a script. The format is
              # one JSON object per line, so the transcript is just every
              # out_txt field in order, read directly.
              python3 -c '
          import json, re, sys
          strip_ansi = re.compile(r"\x1b\[[0-9;]*[a-zA-Z]")
          for line in sys.stdin:
              line = line.strip()
              if not line:
                  continue
              try:
                  rec = json.loads(line)
              except ValueError:
                  continue
              out = rec.get("out_txt", "")
              if out:
                  sys.stdout.write(strip_ansi.sub("", out))
          ' <"$file" >"$transcript"
              reptor file "$file"
              reptor note <"$transcript"
              echo "tlog-engagement: pushed $file and its transcript to the current reptor project."
              ;;
            list)
              [ -d "$state" ] || { echo "tlog-engagement: no recordings yet."; exit 0; }
              if [ -n "''${1:-}" ]; then
                find "$state/$1" -name '*.tlog.json' 2>/dev/null | sort
              else
                find "$state" -name '*.tlog.json' 2>/dev/null | sort
              fi
              ;;
            play)
              [ -n "''${1:-}" ] || die "play needs a recording path"
              tlog_play=$(command -v tlog-play) || die "tlog-play not found on PATH"
              "$tlog_play" --reader=file --file-path="$1"
              ;;
            help | -h | --help) usage ;;
            *) usage; exit 1 ;;
          esac
        '';
      };
    in
    p.symlinkJoin {
      name = "tlog-engagement-${tlogPkg.version}";
      paths = [
        tlogPkg
        driver
      ];
    };
}
