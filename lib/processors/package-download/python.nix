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
# OUTPUTS (in publish/ subfolder):
# - publish/package/: Directory containing the extracted package contents
# - publish/metadata.json: JSON file with package metadata
#
# Additionally, timing.json is auto-generated at the root by mkProcessor.

{ lib }:

let
  # Import the processor factory which handles timing injection
  processorFactory = import ../default.nix { inherit lib; };
in
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
    let
      # DOWNLOAD THE PACKAGE:
      # PyPI source distributions follow a standard URL pattern.
      # We fetch this outside the derivation so Nix can cache it.
      pypiSrc = pkgs.fetchurl {
        url = "https://pypi.io/packages/source/${builtins.substring 0 1 name}/${name}/${name}-${version}.tar.gz";
        inherit hash;
      };
    in
    # If disabled, return a skip derivation
    if !(config.enabled or true) then
      pkgs.runCommand "deptext-package-download-python-${name}-${version}-skipped" {} ''
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
        nativeBuildInputs = [ pkgs.gnutar ];

        # The buildScript runs inside mkProcessor's timing wrapper
        # $out/publish is already created by mkProcessor
        buildScript = ''
          # Create package subdirectory and temporary extraction directory
          mkdir -p $out/publish/package
          mkdir -p unpacked

          # Extract the tarball to our temp directory
          # PyPI tarballs typically contain a {name}-{version}/ directory
          tar -xzf ${pypiSrc} -C unpacked

          # Copy the extracted package contents
          echo "Copying package contents..."
          # The tarball extracts to {name}-{version}/ directory
          if [ -d "unpacked/${name}-${version}" ]; then
            cp -r unpacked/${name}-${version}/* $out/publish/package/
          else
            # Try to find the extracted directory (some packages use different naming)
            extracted_dir=$(find unpacked -mindepth 1 -maxdepth 1 -type d | head -1)
            if [ -n "$extracted_dir" ]; then
              cp -r "$extracted_dir"/* $out/publish/package/
            else
              cp -r unpacked/* $out/publish/package/
            fi
          fi

          # Create metadata.json from PKG-INFO
          # PKG-INFO is a standard file in Python source distributions that
          # contains package metadata like name, version, description, etc.
          echo "Creating metadata from PKG-INFO..."

          # Try to extract info from PKG-INFO
          # These variables will store what we find
          home_page=""
          project_url=""
          summary=""

          if [ -f "$out/publish/package/PKG-INFO" ]; then
            # grep searches for lines matching a pattern
            # sed extracts just the value part after the colon
            home_page=$(grep -E "^Home-page:" "$out/publish/package/PKG-INFO" | head -1 | sed 's/Home-page:\s*//' || echo "")
            summary=$(grep -E "^Summary:" "$out/publish/package/PKG-INFO" | head -1 | sed 's/Summary:\s*//' || echo "")
            # Try to find Source URL in Project-URL fields
            project_url=$(grep -E "^Project-URL:.*Source" "$out/publish/package/PKG-INFO" | head -1 | sed 's/.*,\s*//' || echo "")
          fi

          # Create the metadata JSON using jq
          jq -n \
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
            }' > $out/publish/metadata.json

          echo "Package download complete:"
          echo "  - Package files: $(find $out/publish/package -type f | wc -l)"
          echo "  - Metadata: $out/publish/metadata.json"
        '';
      };
}
