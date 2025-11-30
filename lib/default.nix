# DepText Library - Main Entry Point
#
# This file is the "front door" to DepText's library. When someone imports
# the lib/ directory, Nix automatically loads this default.nix file.
#
# WHAT THIS FILE DOES:
# - Imports all the individual library modules (language helpers, utilities)
# - Exports them as a single "attribute set" (like a JavaScript object)
# - Users only need to import this one file to get everything
#
# STRUCTURE:
# lib/
# ├── default.nix          <- You are here! Main entry point
# ├── languages/
# │   ├── rust.nix         <- mkRustPackage function
# │   └── python.nix       <- mkPythonPackage function
# ├── processors/
# │   ├── package-download/
# │   │   ├── rust.nix     <- Fetch from crates.io
# │   │   └── python.nix   <- Fetch from PyPI
# │   ├── source-download.nix  <- Fetch from GitHub
# │   └── stats.nix        <- Generate statistics
# └── utils/
#     ├── validate.nix     <- URL validation helpers
#     └── persist.nix      <- Output persistence logic

# This function receives arguments passed when importing this file.
# { lib } means we expect an attribute set with a "lib" key - this is
# the standard Nix library from nixpkgs, containing helper functions.
{ lib }:

let
  # Import the language helper modules
  # Each module is a function that takes { lib, ... } and returns helpers
  rustLang = import ./languages/rust.nix { inherit lib; };
  pythonLang = import ./languages/python.nix { inherit lib; };
in
{
  # LANGUAGE HELPERS
  # These are the main functions users will call to create processor pipelines.
  # Each one takes package metadata and returns a derivation that, when built,
  # runs all the processors and produces output.

  # mkRustPackage: Create a processor pipeline for a Rust package
  #
  # ARGUMENTS:
  #   pkgs        - The Nix package set (from nixpkgs) for your system
  #   name        - Package name on crates.io (e.g., "serde")
  #   version     - Package version (e.g., "1.0.228")
  #   github      - { owner, repo, rev } for the GitHub source
  #   hashes      - { package, source } SHA256 hashes for verification
  #   processors  - (optional) { package-download, source-download, stats }
  #                 configuration to enable/disable or set persist flags
  #
  # RETURNS:
  #   An attribute set with:
  #   - default: The main derivation (build this to run the pipeline)
  #   - processors: Individual processor derivations for debugging
  #   - meta: Package metadata (name, version, language)
  #
  # EXAMPLE:
  #   mkRustPackage {
  #     pkgs = nixpkgs.legacyPackages.x86_64-linux;
  #     name = "serde";
  #     version = "1.0.228";
  #     github = { owner = "serde-rs"; repo = "serde"; rev = "v1.0.228"; };
  #     hashes = { package = "sha256-..."; source = "sha256-..."; };
  #   }
  inherit (rustLang) mkRustPackage;

  # mkPythonPackage: Create a processor pipeline for a Python package
  #
  # Same interface as mkRustPackage, but fetches from PyPI instead of crates.io.
  #
  # EXAMPLE:
  #   mkPythonPackage {
  #     pkgs = nixpkgs.legacyPackages.x86_64-linux;
  #     name = "requests";
  #     version = "2.31.0";
  #     github = { owner = "psf"; repo = "requests"; rev = "v2.31.0"; };
  #     hashes = { package = "sha256-..."; source = "sha256-..."; };
  #   }
  inherit (pythonLang) mkPythonPackage;
}
