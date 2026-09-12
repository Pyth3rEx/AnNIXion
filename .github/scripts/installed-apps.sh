#!/usr/bin/env bash
# The applications the configuration asks for, as opposed to everything that
# came along to support them.
#
# environment.systemPackages is what somebody chose to install. The rest of the
# closure is transitive: real, scanned, and not a decision anyone made. Reading
# meta off those derivations directly beats resolving them by name, which is
# what has to be done for the closure at large and which fails on any package
# whose CPE product name is not its attribute path.
#
#   installed-apps.sh [flakeref-attr]
#
# Emits a JSON array on stdout, one object per package.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CONFIG=${1:-AnNIXion-ci}

EXPR=$(mktemp)
trap 'rm -f "$EXPR"' EXIT
cat >"$EXPR" <<NIX
let
  flake = builtins.getFlake "path:${ROOT}";
  cfg = flake.nixosConfigurations.${CONFIG}.config;

  licName =
    l:
    if builtins.isString l then
      l
    else if builtins.isList l then
      builtins.concatStringsSep ", " (map licName l)
    else
      (l.fullName or l.shortName or l.spdxId or "unknown");

  describe =
    p:
    let
      m = p.meta or { };
    in
    {
      name = p.pname or p.name or "?";
      version = p.version or "";
      description = m.description or "";
      license = if m ? license then licName m.license else "";
      homepage = if (m ? homepage) && builtins.isString m.homepage then m.homepage else "";
      position = m.position or "";
      maintainers = map (x: {
        name = x.name or "";
        github = x.github or "";
      }) (m.maintainers or [ ]);
    };

  one =
    p:
    let
      r = builtins.tryEval (describe p);
    in
    if r.success then r.value else null;
in
builtins.filter (x: x != null) (map one cfg.environment.systemPackages)
NIX

nix eval --json --impure --file "$EXPR"
