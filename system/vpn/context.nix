# What every part of the killswitch derives from the options: where the slice
# lands in the cgroup tree, how deep it sits there, and how DNS is confined.
# Split out so the programs below share one answer rather than each computing
# their own. Design and constraints: "VPN enforcement" in docs/usage.md.
{ config, lib }:

let
  cfg = config.annixion.vpnEnforcement;

  sliceBare = lib.removeSuffix ".slice" cfg.sliceName;

  # systemd nests "-"-separated names: annixion-vpn.slice sits inside
  # annixion.slice, and the wrong depth matches nothing.
  sliceParts = lib.splitString "-" sliceBare;
  sliceSubPath = lib.concatStringsSep "/" (
    lib.imap1 (i: _: (lib.concatStringsSep "-" (lib.take i sliceParts)) + ".slice") sliceParts
  );

  # Path embeds the uid.
  cgroupPath = "user.slice/user-${toString cfg.uid}.slice/user@${toString cfg.uid}.service/${sliceSubPath}";
  cgroupFsPath = "/sys/fs/cgroup/${cgroupPath}";

  # Three user-manager levels plus one per name component.
  cgroupLevel = 3 + builtins.length sliceParts;

  dnsConfined = cfg.dnsServers != [ ];
  resolvArgs = lib.escapeShellArgs (map (s: "nameserver ${s}") cfg.dnsServers);

  # Only $1 is inspected, so a wrapped command's own -h still reaches it.
  helpGuard = text: ''
    case "''${1:-}" in
      -h | --help)
        printf '%s\n' ${lib.escapeShellArg text}
        exit 0
        ;;
    esac
  '';
in
{
  inherit
    cfg
    sliceBare
    cgroupPath
    cgroupFsPath
    cgroupLevel
    dnsConfined
    resolvArgs
    helpGuard
    ;
}
