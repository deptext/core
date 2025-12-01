# Source Download Processor
#
# This processor downloads source code from GitHub. It's the second step in
# the DepText pipeline, running after package-download.
#
# WHAT IT DOES:
# 1. Reads metadata.json from the package-download processor
# 2. Validates that the GitHub URL in the seed matches the registry metadata
#    (if the registry provides a repository URL)
# 3. Downloads the source code from GitHub using fetchFromGitHub
# 4. Outputs the source tree to a "source/" directory
#
# WHY VALIDATION MATTERS:
# Packages on crates.io/PyPI might list their official repository. By checking
# that the user's seed.nix points to the same repo, we help catch mistakes
# like accidentally pointing to a fork or the wrong project.
#
# INPUTS:
# - packageDownload: The output from package-download processor (has metadata.json)
# - github: { owner, repo, rev, hash } from the seed configuration
# - seedGitHubUrl: The GitHub URL specified in seed.nix (for validation)
#
# OUTPUTS (in publish/ subfolder):
# - publish/source/: Directory containing the full GitHub source tree
#
# Additionally, timing.json is auto-generated at the root by mkProcessor.

{ lib }:

let
  # Import the processor factory which handles timing injection
  processorFactory = import ./default.nix { inherit lib; };
in
{
  # mkSourceDownload: Create a source-download processor derivation
  #
  # ARGUMENTS:
  #   pkgs           - The Nix package set (needed for stdenv.mkDerivation)
  #   name           - Package name (for naming the derivation)
  #   version        - Package version
  #   github         - { owner, repo, rev, hash } for GitHub download
  #   packageDownload - The derivation from package-download processor
  #   config         - { enabled, persist } processor configuration
  #
  # RETURNS:
  #   A derivation that, when built, downloads source from GitHub
  mkSourceDownload =
    { pkgs
    , name
    , version
    , github
    , packageDownload
    , config ? { enabled = true; persist = false; }
    }:
    let
      # Import our URL validation utilities
      validate = import ./utils/validate.nix { inherit lib; };

      # Build the expected GitHub URL from the seed configuration
      seedGitHubUrl = validate.buildGitHubUrl github.owner github.repo;

      # SOURCE CODE: Download from GitHub
      # fetchFromGitHub is a Nix built-in that:
      # - Downloads a tarball from GitHub's archive URL
      # - Extracts it to a directory
      # - Verifies the hash matches what we expect
      # We do this outside the derivation so Nix can cache it properly.
      githubSrc = pkgs.fetchFromGitHub {
        owner = github.owner;
        repo = github.repo;
        rev = github.rev;
        hash = github.hash;
      };
    in
    # If the processor is disabled, return a minimal "skip" derivation
    # that just creates an empty output. This satisfies Nix's requirement
    # that all derivations produce output, while signaling "nothing to do".
    if !(config.enabled or true) then
      pkgs.runCommand "deptext-source-download-${name}-${version}-skipped" {} ''
        # Create a marker file indicating this processor was skipped
        mkdir -p $out/publish/source
        echo "Processor skipped (enabled=false)" > $out/publish/source/.skipped
        # Create empty timing.json for consistency
        echo '{"startTime": 0, "endTime": 0, "buildDuration": 0}' > $out/timing.json
      ''
    else
      # Use mkProcessor factory for automatic timing injection
      processorFactory.mkProcessor {
        inherit pkgs version;
        name = "source-download";
        pname = name;
        persist = config.persist or false;

        # The buildScript runs inside mkProcessor's timing wrapper
        # $out/publish is already created by mkProcessor
        buildScript = ''
          # Create the source subdirectory inside publish/
          mkdir -p $out/publish/source

          # Read the metadata.json from the package-download processor
          # This file contains registry information including the repo URL
          # Note: We now look in publish/ subfolder since package-download was updated
          metadata_file="${packageDownload}/publish/metadata.json"

          if [ -f "$metadata_file" ]; then
            # Extract the repository URL from metadata using jq
            # jq is a command-line JSON processor
            # The -r flag outputs raw strings (no quotes)
            # // empty means "if null, output nothing"
            metadata_repo=$(jq -r '.repository // .project_urls.Source // empty' "$metadata_file" 2>/dev/null || echo "")

            if [ -n "$metadata_repo" ]; then
              # Normalize URLs for comparison
              # Remove trailing .git and slashes so URLs can be compared fairly
              normalize_url() {
                echo "$1" | sed 's/\.git$//' | sed 's/\/$//'
              }

              seed_url=$(normalize_url "${seedGitHubUrl}")
              meta_url=$(normalize_url "$metadata_repo")

              # Compare the URLs
              if [ "$seed_url" != "$meta_url" ]; then
                echo "ERROR: GitHub URL mismatch!"
                echo "  Seed specifies:    $seed_url"
                echo "  Metadata contains: $meta_url"
                echo ""
                echo "Please verify you're pointing to the correct repository."
                echo "If the metadata is wrong, you can disable validation with:"
                echo "  processors.source-download.validate = false"
                exit 1
              fi

              echo "URL validation passed: $seed_url"
            else
              echo "No repository URL in metadata - skipping validation (FR-017)"
            fi
          else
            echo "Warning: metadata.json not found at $metadata_file"
            echo "Proceeding without URL validation"
          fi

          # Copy the source tree to our output
          # -r = recursive, -L = follow symlinks
          cp -rL ${githubSrc}/* $out/publish/source/ || cp -rL ${githubSrc}/. $out/publish/source/

          echo "Source download complete: $(find $out/publish/source -type f | wc -l) files"
        '';
      };
}
