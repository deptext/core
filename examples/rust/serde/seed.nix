# Seed file for serde 1.0.215
#
# This is an example "seed" - a configuration file that tells DepText how to
# process a specific package. Seeds are the entry point for the DepText
# pipeline.
#
# WHAT THIS SEED DOES:
# When you run `nix build -f seed.nix`, DepText will:
# 1. Download serde 1.0.215 from crates.io
# 2. Download the source code from GitHub
# 3. Validate that the GitHub URL matches crates.io metadata
# 4. Generate file count statistics
# 5. Output stats.json alongside this file (because stats has persist=true)
#
# HOW TO BUILD:
#   cd examples/rust/serde
#   nix build -f seed.nix
#   cat result/stats/stats.json
#
# Or copy the stats folder to this directory:
#   cp -r result/stats ./

let
  # Import the DepText flake
  # In a real scenario, you'd use: builtins.getFlake "github:deptext/core"
  # For local development, we reference the flake in the parent directories
  deptext = import ../../../.;

  # Get the Nix package set for the current system
  # This provides standard tools like fetchurl, mkDerivation, etc.
  pkgs = import <nixpkgs> {};

in
# Call the Rust language helper to create the processing pipeline
(deptext.lib.mkRustPackage {
  # Pass the package set - needed for building derivations
  inherit pkgs;

  # PACKAGE IDENTIFICATION
  # These identify the crate on crates.io
  name = "serde";
  version = "1.0.215";

  # GITHUB SOURCE
  # Where to download the source code from
  # This is validated against the "repository" field in crates.io metadata
  github = {
    owner = "serde-rs";
    repo = "serde";
    rev = "v1.0.215";  # Git tag corresponding to the version
    hash = "sha256-0qaz2mclr5cv3s5riag6aj3n3avirirnbi7sxpq4nw1vzrq09j6l";
  };

  # VERIFICATION HASHES
  # SHA256 hashes ensure we get exactly the content we expect
  # Get these using: nix-prefetch-url --unpack <url>
  hashes = {
    # Hash of the crate tarball from crates.io
    package = "sha256-04xwh16jm7szizkkhj637jv23i5x8jnzcfrw6bfsrssqkjykaxcm";
    # Hash of the GitHub source archive
    source = "sha256-0qaz2mclr5cv3s5riag6aj3n3avirirnbi7sxpq4nw1vzrq09j6l";
  };

  # PROCESSOR CONFIGURATION (optional)
  # Uncomment to customize processor behavior
  # processors = {
  #   package-download = { enabled = true; persist = false; };
  #   source-download = { enabled = true; persist = false; };
  #   stats = { enabled = true; persist = true; };
  # };
}).default  # .default gives us the final pipeline derivation to build
