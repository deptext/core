# Python Language Helper
#
# This module provides the mkPythonPackage function, which creates a complete
# DepText processing pipeline for Python packages from PyPI.
#
# THE PIPELINE:
# 1. package-download: Fetches the package from PyPI, gets metadata
# 2. source-download: Fetches source from GitHub, validates URL
# 3. stats: Counts files and generates statistics
#
# This is nearly identical to the Rust helper - the only difference is
# the package-download processor used (PyPI instead of crates.io).
#
# USAGE:
#   let
#     deptext = builtins.getFlake "github:deptext/core";
#     result = deptext.lib.mkPythonPackage {
#       pkgs = nixpkgs.legacyPackages.x86_64-linux;
#       name = "requests";
#       version = "2.31.0";
#       github = { owner = "psf"; repo = "requests"; rev = "v2.31.0"; };
#       hashes = { package = "sha256-..."; source = "sha256-..."; };
#     };
#   in
#     result.default

{ lib }:

let
  # Import processor modules
  packageDownloadPython = import ../processors/package-download/python.nix { inherit lib; };
  sourceDownload = import ../processors/source-download.nix { inherit lib; };
  stats = import ../processors/stats.nix { inherit lib; };
  persist = import ../utils/persist.nix { inherit lib; };
in
{
  # mkPythonPackage: Create a complete processing pipeline for a Python package
  #
  # ARGUMENTS:
  #   pkgs       - The Nix package set (from nixpkgs)
  #   name       - Package name on PyPI (e.g., "requests")
  #   version    - Package version (e.g., "2.31.0")
  #   github     - GitHub repository info:
  #                { owner = "psf"; repo = "requests"; rev = "v2.31.0"; }
  #   hashes     - SHA256 hashes for verification:
  #                { package = "sha256-..."; source = "sha256-..."; }
  #   processors - (optional) Per-processor configuration
  #
  # RETURNS:
  #   An attribute set with:
  #   - default: The final derivation (build this to run everything)
  #   - processors: Individual processor derivations
  #   - meta: Package metadata (name, version, language)
  mkPythonPackage =
    { pkgs
    , name
    , version
    , github
    , hashes
    , processors ? {}
    }:
    let
      # Merge user-provided processor config with defaults
      processorConfig = lib.recursiveUpdate {
        package-download = { enabled = true; persist = false; };
        source-download = { enabled = true; persist = false; };
        stats = { enabled = true; persist = true; };
      } processors;

      # STEP 1: Package Download from PyPI
      packageDownloadDrv = packageDownloadPython.mkPythonPackageDownload {
        inherit pkgs name version;
        hash = hashes.package;
        config = processorConfig.package-download;
      };

      # STEP 2: Source Download from GitHub
      sourceDownloadDrv = sourceDownload.mkSourceDownload {
        inherit pkgs name version github;
        packageDownload = packageDownloadDrv;
        config = processorConfig.source-download;
      };

      # STEP 3: Stats
      statsDrv = stats.mkStats {
        inherit pkgs name version;
        sourceDownload = sourceDownloadDrv;
        config = processorConfig.stats;
      };

      # Collect all processors
      allProcessors = {
        package-download = packageDownloadDrv;
        source-download = sourceDownloadDrv;
        stats = statsDrv;
      };

      # Final persist wrapper
      finalDrv = persist.mkPersistWrapper {
        inherit pkgs name version;
        processors = allProcessors;
      };

    in
    {
      default = finalDrv;
      processors = allProcessors;
      meta = {
        inherit name version;
        language = "python";
        registry = "pypi";
      };
    };
}
