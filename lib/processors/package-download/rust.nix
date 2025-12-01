# Rust Package Download Processor
#
# This processor downloads Rust packages from crates.io, the official Rust
# package registry. It's the first step in the DepText pipeline for Rust.
#
# WHAT IT DOES:
# 1. Downloads the package tarball from crates.io
# 2. Extracts the package contents
# 3. Creates a metadata.json from the package's Cargo.toml
#
# HOW CRATES.IO WORKS:
# - Packages are downloaded from: https://crates.io/api/v1/crates/{name}/{version}/download
# - The package contains Cargo.toml which has repository info
#
# OUTPUTS (in publish/ subfolder):
# - publish/package/: Directory containing the extracted crate contents
# - publish/metadata.json: JSON file with package metadata
#
# Additionally, timing.json is auto-generated at the root by mkProcessor.

{ lib }:

let
  # Import the processor factory which handles timing injection
  processorFactory = import ../default.nix { inherit lib; };
in
{
  # mkRustPackageDownload: Create a package-download processor for Rust
  #
  # ARGUMENTS:
  #   pkgs    - The Nix package set
  #   name    - Crate name on crates.io (e.g., "serde")
  #   version - Crate version (e.g., "1.0.228")
  #   hash    - SHA256 hash of the crate tarball
  #   config  - { enabled, persist } processor configuration
  #
  # RETURNS:
  #   A derivation that downloads and extracts the crate
  mkRustPackageDownload =
    { pkgs
    , name
    , version
    , hash
    , config ? { enabled = true; persist = false; }
    }:
    let
      # DOWNLOAD THE CRATE:
      # fetchzip downloads a URL, verifies the hash, and extracts it.
      # crates.io returns a gzipped tarball, so we need to specify the extension.
      # We do this outside the derivation so Nix can cache it properly.
      crateSrc = pkgs.fetchzip {
        name = "${name}-${version}-crate";
        url = "https://crates.io/api/v1/crates/${name}/${version}/download";
        extension = "tar.gz";
        inherit hash;
      };
    in
    # If disabled, return a skip derivation
    if !(config.enabled or true) then
      pkgs.runCommand "deptext-package-download-rust-${name}-${version}-skipped" {} ''
        mkdir -p $out/publish/package
        echo '{"skipped": true}' > $out/publish/metadata.json
        # Create empty timing.json for consistency
        echo '{"startTime": 0, "endTime": 0, "buildDuration": 0}' > $out/timing.json
      ''
    else
      # Use mkProcessor factory for automatic timing injection
      processorFactory.mkProcessor {
        inherit pkgs version;
        name = "package-download";
        pname = name;
        persist = config.persist or false;

        # The buildScript runs inside mkProcessor's timing wrapper
        # $out/publish is already created by mkProcessor
        buildScript = ''
          # Create package subdirectory inside publish/
          mkdir -p $out/publish/package

          # Copy the extracted crate contents
          echo "Copying package contents..."
          cp -r ${crateSrc}/* $out/publish/package/

          # Create metadata.json from Cargo.toml info
          # We extract what we can from the package itself
          echo "Creating metadata from Cargo.toml..."

          # Parse Cargo.toml for repository info (simple grep-based extraction)
          # "repository = " line contains the GitHub URL
          repo_url=""
          if [ -f "$out/publish/package/Cargo.toml" ]; then
            repo_url=$(grep -E "^repository\s*=" "$out/publish/package/Cargo.toml" | head -1 | sed 's/.*=\s*"\([^"]*\)".*/\1/' || echo "")
          fi

          # Create the metadata JSON using jq
          # jq -n creates a new JSON object from scratch
          # --arg creates string variables, (now | todate) gets current ISO timestamp
          jq -n \
            --arg name "${name}" \
            --arg version "${version}" \
            --arg repository "$repo_url" \
            '{
              name: $name,
              version: $version,
              repository: (if $repository == "" then null else $repository end),
              _deptext: {
                registry: "crates.io",
                language: "rust",
                fetched_at: (now | todate)
              }
            }' > $out/publish/metadata.json

          echo "Package download complete:"
          echo "  - Package files: $(find $out/publish/package -type f | wc -l)"
          echo "  - Metadata: $out/publish/metadata.json"
        '';
      };
}
