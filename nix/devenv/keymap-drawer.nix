{ pkgs, ... }:

let
  tree-sitter-devicetree = pkgs.python3Packages.callPackage ../packages/tree-sitter-devicetree.nix { };
  keymap-drawer = pkgs.python3Packages.callPackage ../packages/keymap-drawer.nix {
    inherit tree-sitter-devicetree;
  };
in
{
  packages = [ keymap-drawer ];
}
