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
# - sourceDownload: The output from source-download processor (has source/)
# - name, version: Package metadata for the output file
#
# OUTPUTS:
# - stats.json: JSON file with file count and metadata
#
# DEFAULT BEHAVIOR:
# Unlike other processors, stats has persist=true by default. This means
# the stats.json file is automatically copied alongside the seed.nix file
# after a successful build.

{ lib }:

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
        mkdir -p $out
        echo '{"skipped": true}' > $out/stats.json
      ''
    else
      pkgs.stdenv.mkDerivation {
        pname = "deptext-stats";
        inherit version;
        name = "deptext-stats-${name}-${version}";

        # This processor doesn't need source code - it reads from sourceDownload
        # Using "unpackPhase = ':';" tells Nix to skip the unpack step
        src = null;
        dontUnpack = true;

        # BUILD PHASE: Generate the statistics
        buildPhase = ''
          # Count all files in the source directory
          # find -type f finds all regular files (not directories)
          # wc -l counts the number of lines (one per file)
          source_dir="${sourceDownload}/source"

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
          ${pkgs.jq}/bin/jq -n \
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
            }' > stats.json

          echo "Generated stats.json: $file_count files counted"
        '';

        # INSTALL PHASE: Copy stats.json to the output
        installPhase = ''
          mkdir -p $out
          cp stats.json $out/
        '';

        # We need jq available during the build
        nativeBuildInputs = [ pkgs.jq ];

        # Metadata about this derivation
        meta = {
          description = "DepText statistics for ${name} ${version}";
        };

        # Pass through configuration for the persist mechanism
        passthru = {
          processorName = "stats";
          # Stats persist by default (FR-018)
          persist = config.persist or true;
        };
      };
}
