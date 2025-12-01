# Python Package Download Processor
#
# This processor downloads Python packages from PyPI (Python Package Index),
# the official repository for Python software. It's the first step in the
# DepText pipeline for Python.
#
# WHAT IT DOES:
# 1. Downloads the source distribution (sdist) tarball from PyPI
# 2. Extracts the package contents
# 3. Creates a metadata.json from package info (PKG-INFO)
#
# HOW PYPI WORKS:
# - Source packages are at: https://pypi.io/packages/source/{first_letter}/{name}/{name}-{version}.tar.gz
# - Package metadata can be found in PKG-INFO inside the tarball
#
# OUTPUTS:
# - package/: Directory containing the extracted package contents
# - metadata.json: JSON file with package metadata

{ lib }:

{
  # mkPythonPackageDownload: Create a package-download processor for Python
  #
  # ARGUMENTS:
  #   pkgs    - The Nix package set
  #   name    - Package name on PyPI (e.g., "requests")
  #   version - Package version (e.g., "2.31.0")
  #   hash    - SHA256 hash of the source tarball
  #   config  - { enabled, persist } processor configuration
  #
  # RETURNS:
  #   A derivation that downloads and extracts the package
  mkPythonPackageDownload =
    { pkgs
    , name
    , version
    , hash
    , config ? { enabled = true; persist = false; }
    }:
    # If disabled, return a skip derivation
    if !(config.enabled or true) then
      pkgs.runCommand "deptext-package-download-python-${name}-${version}-skipped" {} ''
        mkdir -p $out/package
        echo '{"skipped": true}' > $out/metadata.json
      ''
    else
      pkgs.stdenv.mkDerivation {
        pname = "deptext-package-download-python";
        inherit version;
        name = "deptext-package-download-python-${name}-${version}";

        # DOWNLOAD THE PACKAGE:
        # PyPI source distributions follow a standard URL pattern.
        src = pkgs.fetchurl {
          url = "https://pypi.io/packages/source/${builtins.substring 0 1 name}/${name}/${name}-${version}.tar.gz";
          inherit hash;
        };

        # Tools needed during build
        nativeBuildInputs = with pkgs; [ jq gnutar ];

        # Custom unpack phase - PyPI tarballs have a directory inside
        unpackPhase = ''
          mkdir -p unpacked
          tar -xzf $src -C unpacked
        '';

        # Skip default build
        dontBuild = true;

        # INSTALL PHASE: Copy package and create metadata
        installPhase = ''
          mkdir -p $out/package

          # Copy the extracted package contents
          echo "Copying package contents..."
          # The tarball extracts to {name}-{version}/ directory
          if [ -d "unpacked/${name}-${version}" ]; then
            cp -r unpacked/${name}-${version}/* $out/package/
          else
            # Try to find the extracted directory
            extracted_dir=$(find unpacked -mindepth 1 -maxdepth 1 -type d | head -1)
            if [ -n "$extracted_dir" ]; then
              cp -r "$extracted_dir"/* $out/package/
            else
              cp -r unpacked/* $out/package/
            fi
          fi

          # Create metadata.json from PKG-INFO
          echo "Creating metadata from PKG-INFO..."

          # Try to extract info from PKG-INFO
          home_page=""
          project_url=""
          summary=""

          if [ -f "$out/package/PKG-INFO" ]; then
            home_page=$(grep -E "^Home-page:" "$out/package/PKG-INFO" | head -1 | sed 's/Home-page:\s*//' || echo "")
            summary=$(grep -E "^Summary:" "$out/package/PKG-INFO" | head -1 | sed 's/Summary:\s*//' || echo "")
            # Try to find Source URL in Project-URL fields
            project_url=$(grep -E "^Project-URL:.*Source" "$out/package/PKG-INFO" | head -1 | sed 's/.*,\s*//' || echo "")
          fi

          # Create the metadata JSON
          ${pkgs.jq}/bin/jq -n \
            --arg name "${name}" \
            --arg version "${version}" \
            --arg home_page "$home_page" \
            --arg project_url "$project_url" \
            --arg summary "$summary" \
            '{
              name: $name,
              version: $version,
              summary: (if $summary == "" then null else $summary end),
              home_page: (if $home_page == "" then null else $home_page end),
              project_urls: (if $project_url == "" then null else { Source: $project_url } end),
              _deptext: {
                registry: "pypi",
                language: "python",
                fetched_at: (now | todate)
              }
            }' > $out/metadata.json

          echo "Package download complete:"
          echo "  - Package files: $(find $out/package -type f | wc -l)"
          echo "  - Metadata: $out/metadata.json"
        '';

        meta = {
          description = "DepText package download (Python) for ${name} ${version}";
        };

        passthru = {
          processorName = "package-download";
          persist = config.persist or false;
        };
      };
}
