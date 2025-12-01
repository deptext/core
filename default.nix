# DepText - Non-Flake Entry Point
#
# This file allows importing DepText in non-flake contexts (like seed.nix files).
# When someone does `import ./path/to/deptext`, this file is loaded.
#
# For flake users, use: builtins.getFlake "github:deptext/core"
# For non-flake users, use: import ./path/to/deptext

let
  # Get nixpkgs lib for our library functions
  # We use <nixpkgs> which requires NIX_PATH to be set, or use fetchTarball
  nixpkgsLib = (import <nixpkgs> {}).lib;

  # Import our library, passing the nixpkgs lib
  deptext = import ./lib { lib = nixpkgsLib; };
in
{
  # Export the library functions
  lib = {
    inherit (deptext) mkRustPackage mkPythonPackage;
  };
}
