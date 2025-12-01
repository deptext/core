# Rustdoc Markdown Processor
#
# This processor converts rustdoc JSON output into human-readable Markdown
# documentation using the rustdoc-md tool.
#
# WHAT IS RUSTDOC-MD?
# rustdoc-md is a tool that reads rustdoc JSON files and produces clean,
# well-organized Markdown documentation. This Markdown can be:
# - Read directly by humans
# - Processed by LLMs for context about a Rust crate's API
# - Included in other documentation systems
#
# WHY MARKDOWN?
# - Human-readable: Easy to read without special tooling
# - Universal: Works with any text editor or viewer
# - LLM-friendly: Ideal format for including in LLM context windows
# - Portable: Can be converted to other formats if needed
#
# DEPENDENCIES:
# - Requires rustdoc-json processor output as input
# - Uses rustdoc-md tool (built from lib/packages/rustdoc-md.nix)
#
# OUTPUTS:
# - publish/docs.md: The generated Markdown documentation
# - timing.json: Auto-generated build timing (from mkProcessor)
#
# DEFAULT CONFIGURATION:
# - enabled = true (this processor runs by default)
# - persist = true (Markdown is the final user-facing output)

{ lib }:

let
  # Import the processor factory which handles timing injection
  processorFactory = import ../default.nix { inherit lib; };
in
{
  # mkRustdocMd: Create a rustdoc-md processor for a Rust package
  #
  # ARGUMENTS:
  #   pkgs         - The Nix package set
  #   name         - Package name (e.g., "serde")
  #   version      - Package version (e.g., "1.0.215")
  #   rustdocJson  - The rustdoc-json processor derivation (provides JSON input)
  #   config       - { enabled, persist } processor configuration
  #
  # RETURNS:
  #   A derivation that converts rustdoc JSON to Markdown
  mkRustdocMd =
    { pkgs
    , name
    , version
    , rustdocJson
    , config ? { enabled = true; persist = true; }
    }:
    let
      # Import the rustdoc-md package from our packages directory
      # This builds the rustdoc-md tool from crates.io source
      rustdocMdPkg = import ../../packages/rustdoc-md.nix { inherit pkgs; };
    in
    # If disabled, return a skip derivation
    # This allows the finalize processor to still reference this output
    if !(config.enabled or true) then
      pkgs.runCommand "deptext-rustdoc-md-${name}-${version}-skipped" {} ''
        mkdir -p $out/publish
        echo "# ${name} v${version}" > $out/publish/docs.md
        echo "" >> $out/publish/docs.md
        echo "_Documentation generation was disabled._" >> $out/publish/docs.md
        # Create empty timing.json for consistency with other processors
        echo '{"startTime": 0, "endTime": 0, "buildDuration": 0}' > $out/timing.json
      ''
    else
      # Use mkProcessor factory for automatic timing injection
      processorFactory.mkProcessor {
        inherit pkgs version;
        name = "rustdoc-md";
        pname = name;
        persist = config.persist or true;

        # We need the rustdoc-md tool to convert JSON to Markdown
        nativeBuildInputs = [ rustdocMdPkg ];

        # The buildScript runs inside mkProcessor's timing wrapper
        # $out/publish is already created by mkProcessor
        buildScript = ''
          # ─────────────────────────────────────────────────────────────────────
          # STEP 1: Check if rustdoc-json output exists and is valid
          # ─────────────────────────────────────────────────────────────────────

          JSON_FILE="${rustdocJson}/publish/${name}.json"

          # Check if the JSON file exists
          if [ ! -f "$JSON_FILE" ]; then
            echo "Warning: rustdoc JSON file not found at $JSON_FILE"
            echo "# ${name} v${version}" > $out/publish/docs.md
            echo "" >> $out/publish/docs.md
            echo "_No rustdoc JSON available. Documentation could not be generated._" >> $out/publish/docs.md
            exit 0
          fi

          # Check if the JSON contains an error (from failed rustdoc-json generation)
          if grep -q '"error":' "$JSON_FILE" 2>/dev/null; then
            echo "Warning: rustdoc JSON contains an error marker"
            echo "# ${name} v${version}" > $out/publish/docs.md
            echo "" >> $out/publish/docs.md
            echo "_Rustdoc generation failed. Documentation could not be generated._" >> $out/publish/docs.md
            exit 0
          fi

          # ─────────────────────────────────────────────────────────────────────
          # STEP 2: Convert JSON to Markdown using rustdoc-md
          # ─────────────────────────────────────────────────────────────────────

          echo "Converting rustdoc JSON to Markdown for ${name}..."

          # Run rustdoc-md to convert the JSON to Markdown
          # --path: Input JSON file
          # --output: Output Markdown file
          rustdoc-md \
            --path "$JSON_FILE" \
            --output $out/publish/docs.md \
            || {
              echo "Warning: rustdoc-md conversion failed"
              echo "# ${name} v${version}" > $out/publish/docs.md
              echo "" >> $out/publish/docs.md
              echo "_Markdown conversion failed. Please check the rustdoc JSON format._" >> $out/publish/docs.md
              exit 0
            }

          # ─────────────────────────────────────────────────────────────────────
          # STEP 3: Report success
          # ─────────────────────────────────────────────────────────────────────

          echo "Rustdoc Markdown generated successfully"
          echo "  - Output: $out/publish/docs.md"
          echo "  - Size: $(du -h $out/publish/docs.md | cut -f1)"
          echo "  - Lines: $(wc -l < $out/publish/docs.md)"
        '';
      };
}
