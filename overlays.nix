# Targeted fixes over the pinned nixpkgs, as a plain overlay list so both the
# system configs (via system/overlays.nix) and the test package instances in
# flake.nix apply exactly the same set. Each entry is documented and meant to
# be dropped once nixpkgs carries the fix.
[
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
]
