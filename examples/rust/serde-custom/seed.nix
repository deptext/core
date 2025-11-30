# Seed file for serde 1.0.215 with CUSTOM PROCESSOR CONFIGURATION
#
# This example demonstrates how to customize processor behavior per-seed.
# By default, only the stats processor persists its output. This seed
# shows how to also persist the package-download output.
#
# WHAT'S DIFFERENT FROM THE DEFAULT SEED:
# - package-download has persist=true (normally false)
# - This will create a package-download/ directory alongside the seed
#
# HOW TO BUILD:
#   cd examples/rust/serde-custom
#   nix build -f seed.nix --impure
#   ls result/  # Should show both stats/ and package-download/

let
  deptext = import ../../../.;
  pkgs = import <nixpkgs> {};
in
(deptext.lib.mkRustPackage {
  inherit pkgs;

  name = "serde";
  version = "1.0.215";

  github = {
    owner = "serde-rs";
    repo = "serde";
    rev = "v1.0.215";
    hash = "sha256-0qaz2mclr5cv3s5riag6aj3n3avirirnbi7sxpq4nw1vzrq09j6l";
  };

  hashes = {
    package = "sha256-04xwh16jm7szizkkhj637jv23i5x8jnzcfrw6bfsrssqkjykaxcm";
    source = "sha256-0qaz2mclr5cv3s5riag6aj3n3avirirnbi7sxpq4nw1vzrq09j6l";
  };

  # CUSTOM PROCESSOR CONFIGURATION
  # This overrides the default settings for specific processors
  processors = {
    # Enable persistence for package-download
    # This will copy the crate contents and metadata.json alongside the seed
    package-download = {
      enabled = true;
      persist = true;  # <-- This is the key difference!
    };

    # source-download keeps default settings (enabled, no persist)
    # source-download = { enabled = true; persist = false; };

    # stats keeps default settings (enabled, persist=true)
    # stats = { enabled = true; persist = true; };
  };
}).default
