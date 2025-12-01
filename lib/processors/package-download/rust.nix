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
# OUTPUTS:
# - package/: Directory containing the extracted crate contents
# - metadata.json: JSON file with package metadata

{ lib }:

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
    # If disabled, return a skip derivation
    if !(config.enabled or true) then
      pkgs.runCommand "deptext-package-download-rust-${name}-${version}-skipped" {} ''
        mkdir -p $out/package
        echo '{"skipped": true}' > $out/metadata.json
      ''
    else
      pkgs.stdenv.mkDerivation {
        pname = "deptext-package-download-rust";
        inherit version;
        name = "deptext-package-download-rust-${name}-${version}";

        # DOWNLOAD THE CRATE:
        # fetchzip downloads a URL, verifies the hash, and extracts it.
        # crates.io returns a gzipped tarball, so we need to specify the extension.
        src = pkgs.fetchzip {
          name = "${name}-${version}-crate";
          url = "https://crates.io/api/v1/crates/${name}/${version}/download";
          extension = "tar.gz";
          inherit hash;
        };

        # We need jq and toml2json (or a simple parser) for creating metadata
        nativeBuildInputs = with pkgs; [ jq ];

        # Skip the default build phase
        dontBuild = true;

        # INSTALL PHASE: Copy package and create metadata
        installPhase = ''
          mkdir -p $out/package

          # Copy the extracted crate contents
          echo "Copying package contents..."
          cp -r $src/* $out/package/

          # Create metadata.json from Cargo.toml info
          # We extract what we can from the package itself
          echo "Creating metadata from Cargo.toml..."

          # Parse Cargo.toml for repository info (simple grep-based extraction)
          repo_url=""
          if [ -f "$out/package/Cargo.toml" ]; then
            repo_url=$(grep -E "^repository\s*=" "$out/package/Cargo.toml" | head -1 | sed 's/.*=\s*"\([^"]*\)".*/\1/' || echo "")
          fi

          # Create the metadata JSON
          ${pkgs.jq}/bin/jq -n \
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
            }' > $out/metadata.json

          echo "Package download complete:"
          echo "  - Package files: $(find $out/package -type f | wc -l)"
          echo "  - Metadata: $out/metadata.json"
        '';

        meta = {
          description = "DepText package download (Rust) for ${name} ${version}";
        };

        passthru = {
          processorName = "package-download";
          persist = config.persist or false;
        };
      };
}
