# Finalize Processor
#
# This processor runs after all other processors complete and generates summary
# files for the build: README.md and bloom.json.
#
# WHAT IT DOES:
# 1. Receives outputs from all upstream processors as dependencies
# 2. Reads timing.json from each processor to get build durations
# 3. Scans publish/ folders to count files and calculate sizes
# 4. Generates README.md with a human-readable summary table
# 5. Generates bloom.json with machine-readable metadata
#
# WHY THIS EXISTS:
# - Provides a consistent summary format across all packages
# - bloom.json enables tooling/LLM context to understand build outputs
# - README.md helps humans quickly understand what was built
#
# SPECIAL BEHAVIOR:
# Unlike other processors that output to {processor-name}/ subdirectories,
# finalize's outputs go directly alongside seed.nix (README.md and bloom.json
# at the root level, not in a finalize/ folder).
#
# INPUTS:
# - All upstream processor derivations (package-download, source-download, stats)
# - Package metadata (pname, version, language, github info, hash)
#
# OUTPUTS:
# - publish/README.md: Human-readable build summary
# - publish/bloom.json: Machine-readable metadata
#
# Additionally, timing.json is auto-generated at the root by mkProcessor.

{ lib }:

let
  # Import the processor factory which handles timing injection
  processorFactory = import ./default.nix { inherit lib; };

  # Import formatting utilities for human-readable durations and sizes
  formatUtils = import ../utils/format.nix { inherit lib; };
in
{
  # mkFinalize: Create the finalize processor that generates summary files
  #
  # ARGUMENTS:
  #   pkgs          - The Nix package set
  #   pname         - Package name (e.g., "serde")
  #   version       - Package version (e.g., "1.0.228")
  #   language      - Programming language ("rust" or "python")
  #   hash          - Package content hash from registry
  #   github        - GitHub repository info: { owner, repo, rev, hash }
  #   processors    - Attribute set of upstream processor derivations
  #                   { package-download = <drv>; source-download = <drv>; stats = <drv>; }
  #   processorConfig - Configuration for each processor (enabled, persist)
  #
  # RETURNS:
  #   A derivation that generates README.md and bloom.json
  mkFinalize =
    { pkgs
    , pname
    , version
    , language
    , hash
    , github
    , processors  # { package-download, source-download, stats }
    , processorConfig ? {}
    }:
    # Use mkProcessor factory for automatic timing injection
    processorFactory.mkProcessor {
      inherit pkgs version;
      name = "finalize";
      inherit pname;
      # Finalize always persists (its output goes to root level)
      persist = true;
      nativeBuildInputs = [ pkgs.findutils ];

      # The buildScript runs inside mkProcessor's timing wrapper
      # $out/publish is already created by mkProcessor
      buildScript = ''
        # ─────────────────────────────────────────────────────────────────────
        # FORMATTING HELPER FUNCTIONS
        # ─────────────────────────────────────────────────────────────────────
        # These functions convert raw numbers to human-readable formats

        ${formatUtils.formatDurationFn}
        ${formatUtils.formatSizeFn}

        # ─────────────────────────────────────────────────────────────────────
        # DIRECTORY SCANNING FUNCTIONS
        # ─────────────────────────────────────────────────────────────────────
        # These functions count files and calculate sizes for published outputs

        # count_files: Count the number of files in a directory
        # Input: directory path
        # Output: integer count printed to stdout
        count_files() {
          local dir=$1
          if [ -d "$dir" ]; then
            find "$dir" -type f | wc -l | tr -d ' '
          else
            echo "0"
          fi
        }

        # calculate_size: Calculate total size of files in a directory
        # Input: directory path
        # Output: size in bytes printed to stdout
        calculate_size() {
          local dir=$1
          if [ -d "$dir" ]; then
            # du -sb gives total bytes, cut extracts just the number
            du -sb "$dir" 2>/dev/null | cut -f1 || echo "0"
          else
            echo "0"
          fi
        }

        # calculate_hash: Calculate SHA256 hash of directory contents
        # Input: directory path
        # Output: hash string printed to stdout
        calculate_hash() {
          local dir=$1
          if [ -d "$dir" ]; then
            # Hash each file, sort for consistency, then hash the result
            find "$dir" -type f -exec sha256sum {} \; 2>/dev/null | sort | sha256sum | cut -d' ' -f1
          else
            echo ""
          fi
        }

        # ─────────────────────────────────────────────────────────────────────
        # COLLECT PROCESSOR INFORMATION
        # ─────────────────────────────────────────────────────────────────────
        # Read timing and status from each upstream processor

        echo "Collecting processor information..."

        # Initialize variables for accumulating data
        total_duration=0
        processor_rows=""
        processors_json=""

        # Process each upstream processor
        # We iterate over a known list to maintain consistent ordering
        for proc_name in package-download source-download stats; do
          case "$proc_name" in
            "package-download")
              proc_drv="${processors.package-download}"
              proc_enabled="${if processorConfig.package-download.enabled or true then "true" else "false"}"
              proc_persist="${if processorConfig.package-download.persist or false then "true" else "false"}"
              ;;
            "source-download")
              proc_drv="${processors.source-download}"
              proc_enabled="${if processorConfig.source-download.enabled or true then "true" else "false"}"
              proc_persist="${if processorConfig.source-download.persist or false then "true" else "false"}"
              ;;
            "stats")
              proc_drv="${processors.stats}"
              proc_enabled="${if processorConfig.stats.enabled or true then "true" else "false"}"
              proc_persist="${if processorConfig.stats.persist or true then "true" else "false"}"
              ;;
          esac

          # Read timing data if processor was enabled
          duration=0
          duration_str="-"
          if [ "$proc_enabled" = "true" ]; then
            timing_file="$proc_drv/timing.json"
            if [ -f "$timing_file" ]; then
              duration=$(jq -r '.buildDuration // 0' "$timing_file")
              total_duration=$((total_duration + duration))
              duration_str=$(format_duration $duration)
            fi
          fi

          # Get file stats if processor output was published
          file_count="-"
          file_size="-"
          file_size_bytes=0
          dir_hash=""
          pub_col="-"

          if [ "$proc_enabled" = "true" ] && [ "$proc_persist" = "true" ]; then
            publish_dir="$proc_drv/publish"
            if [ -d "$publish_dir" ]; then
              file_count=$(count_files "$publish_dir")
              file_size_bytes=$(calculate_size "$publish_dir")
              file_size=$(format_size $file_size_bytes)
              dir_hash="sha256:$(calculate_hash "$publish_dir")"
              pub_col="[view output](./$proc_name/)"
            fi
          elif [ "$proc_enabled" = "true" ]; then
            # Active but not published
            pub_col="-"
          fi

          # Determine active status symbol
          if [ "$proc_enabled" = "true" ]; then
            active_sym="✓"
          else
            active_sym="✗"
          fi

          # Build table row for README.md
          processor_rows="$processor_rows| $proc_name | $active_sym | $pub_col | $duration_str | $file_count | $file_size |
"

          # Build JSON entry for bloom.json
          # We need to build this incrementally
          proc_json="{\"active\": $proc_enabled, \"published\": $proc_persist"
          if [ "$proc_enabled" = "true" ]; then
            proc_json="$proc_json, \"buildDuration\": $duration"
          fi
          if [ "$proc_persist" = "true" ] && [ "$file_count" != "-" ]; then
            proc_json="$proc_json, \"fileCount\": $file_count, \"fileSize\": $file_size_bytes"
            if [ -n "$dir_hash" ]; then
              proc_json="$proc_json, \"hash\": \"$dir_hash\""
            fi
          fi
          proc_json="$proc_json}"

          # Add to processors JSON object
          if [ -n "$processors_json" ]; then
            processors_json="$processors_json, \"$proc_name\": $proc_json"
          else
            processors_json="\"$proc_name\": $proc_json"
          fi
        done

        # ─────────────────────────────────────────────────────────────────────
        # GENERATE README.md
        # ─────────────────────────────────────────────────────────────────────
        # Create human-readable summary with processor table

        echo "Generating README.md..."

        # Get current timestamp in ISO 8601 format
        last_build=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        total_duration_str=$(format_duration $total_duration)

        # Capitalize language for display
        case "${language}" in
          "rust") display_lang="Rust" ;;
          "python") display_lang="Python" ;;
          *) display_lang="${language}" ;;
        esac

        cat > $out/publish/README.md << EOF
# ${pname} v${version}

**Language**: $display_lang
**Last Build**: $last_build
**Build Duration**: $total_duration_str

## Processors

| Processor | Active | Published | Duration | Files | Size |
|-----------|--------|-----------|----------|-------|------|
$processor_rows
EOF

        echo "README.md generated successfully"

        # ─────────────────────────────────────────────────────────────────────
        # GENERATE bloom.json
        # ─────────────────────────────────────────────────────────────────────
        # Create machine-readable metadata for tooling

        echo "Generating bloom.json..."

        jq -n \
          --arg pname "${pname}" \
          --arg version "${version}" \
          --arg language "${language}" \
          --arg hash "${hash}" \
          --arg github_owner "${github.owner}" \
          --arg github_repo "${github.repo}" \
          --arg github_rev "${github.rev}" \
          --arg github_hash "${github.hash}" \
          --arg lastBuild "$last_build" \
          --argjson buildDuration "$total_duration" \
          --argjson processors "{$processors_json}" \
          '{
            pname: $pname,
            version: $version,
            language: $language,
            hash: $hash,
            github: {
              owner: $github_owner,
              repo: $github_repo,
              rev: $github_rev,
              hash: $github_hash
            },
            lastBuild: $lastBuild,
            buildDuration: $buildDuration,
            processors: $processors
          }' > $out/publish/bloom.json

        echo "bloom.json generated successfully"
        echo "Finalize complete!"
      '';
    };
}
