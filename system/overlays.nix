# ── Overlays — targeted fixes over the pinned nixpkgs ────────────────────
# Narrow workarounds for upstream packages that fail to build in the pinned
# nixpkgs and would otherwise block the whole closure. Each is documented and
# meant to be dropped once nixpkgs carries the fix.
{
  nixpkgs.overlays = [
    (_: prev: {
      pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
        (_: pyprev: {
          # gql 4.0.0's introspection-query AST tests compare against a string a
          # newer graphql-core formats differently; the library itself is fine.
          # Skip just those three so reptor and sysreptor keep building.
          gql = pyprev.gql.overridePythonAttrs (old: {
            disabledTests = (old.disabledTests or [ ]) ++ [
              "test_get_introspection_query_ast"
              "test_node_tree_with_loc"
            ];
          });
        })
      ];
    })
  ];
}
