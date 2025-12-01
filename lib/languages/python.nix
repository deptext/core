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
  # mkPythonPackage: Create a processing pipeline for a Python package
  #
  # ARGUMENTS:
  #   pkgs       - The Nix package set (from nixpkgs)
  #   pname      - Package name on PyPI (e.g., "requests")
  #   version    - Package version (e.g., "2.31.0")
  #   hash       - SHA256 hash of the PyPI tarball
  #   github     - GitHub repository info: { owner, repo, rev, hash }
  #   processors - (optional) Per-processor configuration
  mkPythonPackage =
    { pkgs
    , pname
    , version
    , hash
    , github
    , processors ? {}
    }:
    let
      processorConfig = lib.recursiveUpdate {
        package-download = { enabled = true; persist = false; };
        source-download = { enabled = true; persist = false; };
        stats = { enabled = true; persist = true; };
      } processors;

      packageDownloadDrv = packageDownloadPython.mkPythonPackageDownload {
        inherit pkgs version hash;
        name = pname;
        config = processorConfig.package-download;
      };

      sourceDownloadDrv = sourceDownload.mkSourceDownload {
        inherit pkgs version github;
        name = pname;
        packageDownload = packageDownloadDrv;
        config = processorConfig.source-download;
      };

      statsDrv = stats.mkStats {
        inherit pkgs version;
        name = pname;
        sourceDownload = sourceDownloadDrv;
        config = processorConfig.stats;
      };

      allProcessors = {
        package-download = packageDownloadDrv;
        source-download = sourceDownloadDrv;
        stats = statsDrv;
      };

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
        language = "python";
        registry = "pypi";
      };
    };
}
