# DepText - Nix-based package processing pipeline
#
# This is a "flake" - Nix's modern way of defining a project. Think of it like
# a package.json for JavaScript or Cargo.toml for Rust, but for Nix projects.
# It declares what this project needs (inputs) and what it provides (outputs).
#
# WHAT THIS FLAKE DOES:
# - Exports library functions (mkRustPackage, mkPythonPackage) that let users
#   create "seeds" - Nix files that process open source packages
# - When you run `nix build` on a seed, it downloads the package, fetches
#   source code from GitHub, validates URLs, and generates statistics
#
# HOW TO USE:
# 1. Create a seed.nix file that imports this flake and calls mkRustPackage
# 2. Run: nix build -f your-seed.nix
# 3. Check the stats/ directory for generated output
{
  # "description" is a human-readable summary shown when people browse flakes
  description = "DepText - Package processing pipeline for LLM context generation";

  # INPUTS: What external projects does this flake depend on?
  # Think of these like npm dependencies - they're other Nix projects we need.
  inputs = {
    # nixpkgs is the main Nix package repository - it contains thousands of
    # packages and helper functions. We use "nixos-unstable" to get the latest
    # versions of everything.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # flake-utils provides helper functions for working with multiple systems
    # (Linux, macOS, etc.) without writing repetitive code for each one.
    flake-utils.url = "github:numtide/flake-utils";
  };

  # OUTPUTS: What does this flake provide to the world?
  # This is a function that receives our resolved inputs and returns an
  # "attribute set" (Nix's version of a dictionary/object) of things we export.
  outputs = { self, nixpkgs, flake-utils }:
    let
      # Import our library functions from lib/default.nix
      # We pass nixpkgs.lib so our library can use standard Nix helpers
      deptext = import ./lib { inherit (nixpkgs) lib; };
    in
    {
      # LIB: System-independent library functions
      # These are the main things users will import and use.
      # They work on any system (Linux, macOS, etc.) because they're just
      # Nix expressions that get evaluated, not compiled code.
      lib = {
        # mkRustPackage creates a processor pipeline for Rust packages
        # Usage: deptext.lib.mkRustPackage { pkgs = ...; name = "serde"; ... }
        inherit (deptext) mkRustPackage;

        # mkPythonPackage creates a processor pipeline for Python packages
        # Usage: deptext.lib.mkPythonPackage { pkgs = ...; name = "requests"; ... }
        inherit (deptext) mkPythonPackage;
      };
    }
    # The // operator merges attribute sets. flake-utils.lib.eachDefaultSystem
    # generates system-specific outputs (packages, devShells) for each platform.
    // flake-utils.lib.eachDefaultSystem (system:
      let
        # Get the package set for this specific system (e.g., x86_64-linux)
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        # DEV SHELL: Development environment for working on DepText itself
        # Run `nix develop` to enter a shell with these tools available
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # jq is used for JSON processing in our processors
            jq
            # nix-prefetch tools help users get hashes for their seeds
            nix-prefetch-github
          ];
        };

        # CLI APP: The bloom command-line tool
        # Run with: nix run .#bloom -- ./seed.nix
        # Or install: nix profile install .#bloom
        packages.bloom = pkgs.stdenv.mkDerivation {
          pname = "bloom";
          version = "0.1.0";
          src = self;
          installPhase = ''
            mkdir -p $out/bin $out/lib
            cp -r lib/* $out/lib/
            cp bin/bloom $out/bin/
            # Patch the script to use the installed lib path
            substituteInPlace $out/bin/bloom \
              --replace 'PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"' \
                        'PROJECT_ROOT="'"$out"'"'
          '';
        };

        packages.default = self.packages.${system}.bloom;

        apps.bloom = {
          type = "app";
          program = "${self.packages.${system}.bloom}/bin/bloom";
        };

        apps.default = self.apps.${system}.bloom;
      }
    );
}
