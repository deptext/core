# Rustdoc JSON Processor
#
# This processor generates JSON documentation from Rust source code using
# rustdoc's JSON output format. This JSON can then be consumed by other tools
# (like rustdoc-md) to generate human-readable documentation.
#
# WHAT IS RUSTDOC JSON?
# Rustdoc is Rust's built-in documentation generator. Normally it outputs HTML,
# but with the `--output-format json` flag, it outputs a machine-readable JSON
# representation of the entire API surface:
# - All public modules, structs, enums, traits, functions, etc.
# - All doc comments
# - Type signatures
# - Relationships between items
#
# HOW WE ENABLE JSON OUTPUT:
# The --output-format json flag is technically a nightly-only feature, but we
# can enable it with stable Rust using RUSTC_BOOTSTRAP=1. This environment
# variable tells rustc to allow unstable features.
#
# OUTPUTS:
# - publish/{pname}.json: The rustdoc JSON file (single file containing full API)
# - timing.json: Auto-generated build timing (from mkProcessor)

{ lib }:

let
  # Import the processor factory which handles timing injection
  processorFactory = import ../default.nix { inherit lib; };
in
{
  # mkRustdocJson: Create a rustdoc-json processor for a Rust package
  #
  # ARGUMENTS:
  #   pkgs           - The Nix package set
  #   name           - Package name (e.g., "serde")
  #   version        - Package version (e.g., "1.0.215")
  #   sourceDownload - The source-download processor derivation (provides source code)
  #   config         - { enabled, persist } processor configuration
  #
  # RETURNS:
  #   A derivation that generates rustdoc JSON from the source code
  mkRustdocJson =
    { pkgs
    , name
    , version
    , sourceDownload
    , config ? { enabled = true; persist = false; }
    }:
    # If disabled, return a skip derivation
    if !(config.enabled or true) then
      pkgs.runCommand "deptext-rustdoc-json-${name}-${version}-skipped" {} ''
        mkdir -p $out/publish
        echo '{"skipped": true}' > $out/publish/${name}.json
        echo '{"startTime": 0, "endTime": 0, "buildDuration": 0}' > $out/timing.json
      ''
    else
      # Use mkProcessor factory for automatic timing injection
      processorFactory.mkProcessor {
        inherit pkgs version;
        name = "rustdoc-json";
        pname = name;
        persist = config.persist or false;

        # Use stable Rust from nixpkgs - we enable nightly features via RUSTC_BOOTSTRAP
        nativeBuildInputs = [ pkgs.cargo pkgs.rustc ];

        buildScript = ''
          # RUSTC_BOOTSTRAP=1 enables nightly features with stable Rust
          export RUSTC_BOOTSTRAP=1

          # Copy source to writable location
          cp -r ${sourceDownload}/publish/source src
          chmod -R +w src
          cd src

          echo "Generating rustdoc JSON for ${name}..."

          # Find the crate root and its Cargo.toml
          # For workspaces, look in src/ or {crate_name}/src/
          crate_root=""
          cargo_toml=""
          for dir in "." "${name}"; do
            if [ -f "$dir/src/lib.rs" ]; then
              crate_root="$dir/src/lib.rs"
              cargo_toml="$dir/Cargo.toml"
              break
            elif [ -f "$dir/src/main.rs" ]; then
              crate_root="$dir/src/main.rs"
              cargo_toml="$dir/Cargo.toml"
              break
            fi
          done

          if [ -z "$crate_root" ]; then
            echo "Warning: Could not find crate root (lib.rs or main.rs)"
            echo '{"error": "no crate root found", "format_version": 0}' > $out/publish/${name}.json
            exit 0
          fi

          echo "Found crate root: $crate_root"

          # Detect edition from Cargo.toml (default to 2018 if not found)
          edition="2018"
          if [ -f "$cargo_toml" ]; then
            detected=$(grep -E '^edition\s*=' "$cargo_toml" | sed 's/.*"\([0-9]*\)".*/\1/' | head -1)
            if [ -n "$detected" ]; then
              edition="$detected"
            fi
          fi
          echo "Using Rust edition: $edition"

          # Run rustdoc directly on the crate root
          mkdir -p doc
          rustdoc \
            --edition "$edition" \
            --crate-name ${name} \
            --crate-type lib \
            -Z unstable-options \
            --output-format json \
            --output doc \
            "$crate_root" \
            2>&1 || {
              echo "Warning: rustdoc failed, creating minimal JSON output"
              echo '{"error": "rustdoc generation failed", "format_version": 0}' > $out/publish/${name}.json
              exit 0
            }

          # Find and copy the generated JSON file
          echo "Looking for JSON output in doc/..."
          find doc -type f -name "*.json" 2>/dev/null || echo "  (no .json files found)"

          json_file=$(find doc -name "*.json" -type f | head -1)

          if [ -n "$json_file" ]; then
            cp "$json_file" $out/publish/${name}.json
            echo "[rustdoc-json] SUCCESS"
            echo "  Output: $out/publish/${name}.json"
            echo "  Size: $(du -h $out/publish/${name}.json | cut -f1)"
          else
            echo "[rustdoc-json] WARNING: No JSON output found, creating placeholder"
            echo '{"error": "no JSON output found", "format_version": 0}' > $out/publish/${name}.json
          fi

          echo "[rustdoc-json] Final publish/ contents:"
          ls -la $out/publish/
        '';
      };
}
