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
  # mkRustPackage: Create a complete processing pipeline for a Rust package
  #
  # ARGUMENTS:
  #   pkgs       - The Nix package set (from nixpkgs)
  #   name       - Crate name on crates.io (e.g., "serde")
  #   version    - Crate version (e.g., "1.0.228")
  #   github     - GitHub repository info:
  #                { owner = "serde-rs"; repo = "serde"; rev = "v1.0.228"; }
  #   hashes     - SHA256 hashes for verification:
  #                { package = "sha256-..."; source = "sha256-..."; }
  #   processors - (optional) Per-processor configuration:
  #                {
  #                  package-download = { enabled = true; persist = false; };
  #                  source-download = { enabled = true; persist = false; };
  #                  stats = { enabled = true; persist = true; };
  #                }
  #
  # RETURNS:
  #   An attribute set with:
  #   - default: The final derivation (build this to run everything)
  #   - processors: Individual processor derivations
  #   - meta: Package metadata (name, version, language)
  mkRustPackage =
    { pkgs
    , name
    , version
    , github
    , hashes
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
        inherit pkgs name version;
        hash = hashes.package;
        config = processorConfig.package-download;
      };

      # STEP 2: Source Download
      # Downloads source from GitHub and validates the URL
      # This depends on packageDownloadDrv (needs metadata.json for validation)
      sourceDownloadDrv = sourceDownload.mkSourceDownload {
        inherit pkgs name version github;
        packageDownload = packageDownloadDrv;
        config = processorConfig.source-download;
      };

      # STEP 3: Stats
      # Counts files and generates statistics
      # This depends on sourceDownloadDrv (needs source files to count)
      statsDrv = stats.mkStats {
        inherit pkgs name version;
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
        inherit pkgs name version;
        processors = allProcessors;
      };

    in
    {
      # The main derivation to build
      # Running `nix build -f seed.nix` will build this
      default = finalDrv;

      # Individual processors for debugging or selective building
      # e.g., `nix build -f seed.nix processors.stats`
      processors = allProcessors;

      # Metadata for tooling
      meta = {
        inherit name version;
        language = "rust";
        registry = "crates.io";
      };
    };
}
