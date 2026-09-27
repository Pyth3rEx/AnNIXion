# Default C/C++ toolchain is LLVM, not GCC: sharper diagnostics, working
# sanitizers, and it matches clangd/lldb already wired into VSCodium
# (home/apps/vscodium.nix). Only sets CC/CXX -- make/cmake/autotools and
# anything else that respects them picks up clang; nixpkgs keeps building its
# own packages with gcc, so this doesn't force a closure-wide rebuild.
_: {
  environment.variables = {
    CC = "clang";
    CXX = "clang++";
  };
}
