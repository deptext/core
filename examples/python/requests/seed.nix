# Seed file for requests 2.31.0
#
# This is an example "seed" for a Python package. When you run `nix build`,
# DepText will process the requests package through the pipeline.
#
# WHAT THIS SEED DOES:
# 1. Download requests 2.31.0 from PyPI
# 2. Download the source code from GitHub
# 3. Validate that the GitHub URL matches PyPI metadata
# 4. Generate file count statistics
# 5. Output stats.json alongside this file
#
# HOW TO BUILD:
#   cd examples/python/requests
#   nix build -f seed.nix --impure
#   cat result/stats/stats.json

let
  # Import the DepText library
  deptext = import ../../../.;

  # Get the Nix package set
  pkgs = import <nixpkgs> {};

in
(deptext.lib.mkPythonPackage {
  inherit pkgs;

  # PACKAGE IDENTIFICATION
  name = "requests";
  version = "2.31.0";

  # GITHUB SOURCE
  github = {
    owner = "psf";
    repo = "requests";
    rev = "v2.31.0";
    hash = "sha256-0pxl0rnz9ks0fa642dxk7awf1pbipsq99ryhxfhsy3r3dfkvk8wi";
  };

  # VERIFICATION HASHES
  hashes = {
    package = "sha256-1qfidaynsrci4wymrw3srz8v1zy7xxpcna8sxpm91mwqixsmlb4l";
    source = "sha256-0pxl0rnz9ks0fa642dxk7awf1pbipsq99ryhxfhsy3r3dfkvk8wi";
  };
}).default
