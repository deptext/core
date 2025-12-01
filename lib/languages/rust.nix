# Rust Language Helper
#
# This module provides the mkRustPackage function, which creates a complete
# DepText processing pipeline for Rust packages from crates.io.
#
# THE PIPELINE:
# 1. package-download: Fetches the crate from crates.io, gets metadata
# 2. source-download: Fetches source from GitHub, validates URL
# 3. stats: Counts files and generates statistics
#
# Each step is a separate Nix derivation. Nix automatically:
# - Builds them in the correct order (respecting dependencies)
# - Runs independent steps in parallel
# - Caches successful builds
#
# USAGE:
#   let
#     deptext = builtins.getFlake "github:deptext/core";
#     result = deptext.lib.mkRustPackage {
#       pkgs = nixpkgs.legacyPackages.x86_64-linux;
#       name = "serde";
#       version = "1.0.228";
#       github = { owner = "serde-rs"; repo = "serde"; rev = "v1.0.228"; };
#       hashes = { package = "sha256-..."; source = "sha256-..."; };
#     };
#   in
#     result.default  # Build this to run the full pipeline

{ lib }:

let
  # Import processor modules
  packageDownloadRust = import ../processors/package-download/rust.nix { inherit lib; };
  sourceDownload = import ../processors/source-download.nix { inherit lib; };
  stats = import ../processors/stats.nix { inherit lib; };
  persist = import ../utils/persist.nix { inherit lib; };
in
{
  # mkRustPackage: Create a processing pipeline for a Rust package
  #
  # ARGUMENTS:
  #   pkgs       - The Nix package set (from nixpkgs)
  #   pname      - Crate name on crates.io (e.g., "serde")
  #   version    - Crate version (e.g., "1.0.228")
  #   hash       - SHA256 hash of the crate tarball
  #   github     - GitHub repository info: { owner, repo, rev, hash }
  #   processors - (optional) Per-processor configuration
  mkRustPackage =
    { pkgs
    , pname
    , version
    , hash
    , github
    , processors ? {}
    }:
    let
      # Merge user-provided processor config with defaults
      # lib.recursiveUpdate does a deep merge of attribute sets
      processorConfig = lib.recursiveUpdate {
        # Default configuration for each processor
        package-download = { enabled = true; persist = false; };
        source-download = { enabled = true; persist = false; };
        stats = { enabled = true; persist = true; };  # stats persists by default
      } processors;

      # STEP 1: Package Download
      # Downloads the crate from crates.io and fetches metadata
      packageDownloadDrv = packageDownloadRust.mkRustPackageDownload {
        inherit pkgs version hash;
        name = pname;
        config = processorConfig.package-download;
      };

      # STEP 2: Source Download
      # Downloads source from GitHub and validates the URL
      sourceDownloadDrv = sourceDownload.mkSourceDownload {
        inherit pkgs version github;
        name = pname;
        packageDownload = packageDownloadDrv;
        config = processorConfig.source-download;
      };

      # STEP 3: Stats
      # Counts files and generates statistics
      statsDrv = stats.mkStats {
        inherit pkgs version;
        name = pname;
        sourceDownload = sourceDownloadDrv;
        config = processorConfig.stats;
      };

      # Collect all processor derivations
      allProcessors = {
        package-download = packageDownloadDrv;
        source-download = sourceDownloadDrv;
        stats = statsDrv;
      };

      # FINAL: Persist Wrapper
      # Creates a derivation that collects all persisted outputs
      finalDrv = persist.mkPersistWrapper {
        inherit pkgs version;
        name = pname;
        processors = allProcessors;
      };

    in
    {
      default = finalDrv;
      processors = allProcessors;
      meta = {
        name = pname;
        inherit version;
        language = "rust";
        registry = "crates.io";
      };
    };
}
