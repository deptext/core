# Stats Processor
#
# This processor generates statistics about the downloaded source code.
# It's the final step in the DepText MVP pipeline.
#
# WHAT IT DOES:
# 1. Takes the source code from the source-download processor
# 2. Counts the total number of files
# 3. Outputs a stats.json file with the statistics
#
# WHY THIS EXISTS:
# The stats processor serves as a proof-of-concept for the DepText pipeline.
# In the future, more sophisticated processors will generate documentation,
# extract type definitions, etc. For now, we just count files to prove the
# pipeline works end-to-end.
#
# INPUTS:
# - sourceDownload: The output from source-download processor (has publish/source/)
# - name, version: Package metadata for the output file
#
# OUTPUTS (in publish/ subfolder):
# - publish/stats.json: JSON file with file count and metadata
#
# Additionally, timing.json is auto-generated at the root by mkProcessor.
#
# DEFAULT BEHAVIOR:
# Unlike other processors, stats has persist=true by default. This means
# the stats.json file is automatically copied alongside the seed.nix file
# after a successful build.

{ lib }:

let
  # Import the processor factory which handles timing injection
  processorFactory = import ./default.nix { inherit lib; };
in
{
  # mkStats: Create a stats processor derivation
  #
  # ARGUMENTS:
  #   pkgs           - The Nix package set
  #   name           - Package name
  #   version        - Package version
  #   sourceDownload - The derivation from source-download processor
  #   config         - { enabled, persist } processor configuration
  #
  # RETURNS:
  #   A derivation that, when built, generates stats.json
  mkStats =
    { pkgs
    , name
    , version
    , sourceDownload
    , config ? { enabled = true; persist = true; }  # Note: persist defaults to TRUE
    }:
    # If the processor is disabled, return a minimal "skip" derivation
    if !(config.enabled or true) then
      pkgs.runCommand "deptext-stats-${name}-${version}-skipped" {} ''
        mkdir -p $out/publish
        echo '{"skipped": true}' > $out/publish/stats.json
        # Create empty timing.json for consistency
        echo '{"startTime": 0, "endTime": 0, "buildDuration": 0}' > $out/timing.json
      ''
    else
      # Use mkProcessor factory for automatic timing injection
      processorFactory.mkProcessor {
        inherit pkgs version;
        name = "stats";
        pname = name;
        # Stats persist by default (FR-018)
        persist = config.persist or true;

        # The buildScript runs inside mkProcessor's timing wrapper
        # $out/publish is already created by mkProcessor
        buildScript = ''
          # Count all files in the source directory
          # find -type f finds all regular files (not directories)
          # wc -l counts the number of lines (one per file)
          # Note: source-download now outputs to publish/source/
          source_dir="${sourceDownload}/publish/source"

          if [ -d "$source_dir" ]; then
            file_count=$(find "$source_dir" -type f | wc -l)
          else
            echo "Warning: source directory not found at $source_dir"
            file_count=0
          fi

          # Get the current timestamp in ISO 8601 format
          # This helps users know when the stats were generated
          generated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

          # Create the stats.json file using jq
          # We use jq to ensure proper JSON formatting
          jq -n \
            --argjson file_count "$file_count" \
            --arg generated_at "$generated_at" \
            --arg pkg_name "${name}" \
            --arg pkg_version "${version}" \
            '{
              file_count: $file_count,
              generated_at: $generated_at,
              source: "github",
              package: {
                name: $pkg_name,
                version: $pkg_version
              }
            }' > $out/publish/stats.json

          echo "Generated stats.json: $file_count files counted"
        '';
      };
}
