# Persist Utility
#
# This module handles copying processor outputs from the Nix store to the
# directory containing the seed.nix file.
#
# HOW NIX BUILDS WORK:
# When you run `nix build`, all outputs go into the Nix store (e.g.,
# /nix/store/abc123-deptext-stats-serde-1.0.228/). A symlink called "result"
# is created pointing to the final output.
#
# THE PERSIST MECHANISM:
# Some processors mark their output with `persist = true`. For these, we want
# to copy the output to a directory alongside the seed.nix file so users can
# easily access the generated files without navigating the Nix store.
#
# For example, if you have:
#   nursery/rust/serde/seed.nix
#
# And you run `nix build -f seed.nix`, the stats processor (with persist=true)
# will have its publish/ contents copied to:
#   nursery/rust/serde/stats/stats.json
#
# SPECIAL CASE - FINALIZE:
# The finalize processor is special. Instead of being placed in a finalize/
# subdirectory, its publish/ contents (README.md and bloom.json) go directly
# alongside seed.nix at the root level.
#
# IMPORTANT NOTE:
# Nix builds are "pure" - they can't write to arbitrary filesystem locations
# during the build. The actual copying happens AFTER the build completes,
# either via a post-build hook or a wrapper script.
#
# For the MVP, we accomplish this by:
# 1. Creating a final derivation that depends on all processors
# 2. Having that derivation's output contain everything that should be persisted
# 3. Users can then copy from the result symlink to their desired location
#
# A future enhancement could add a wrapper script that automatically copies.

{ lib }:

{
  # mkPersistWrapper: Create a final derivation that collects persisted outputs
  #
  # This derivation depends on all processors and collects the outputs from
  # those marked with persist=true into a single output directory.
  #
  # ARGUMENTS:
  #   pkgs       - The Nix package set
  #   name       - Package name (for derivation naming)
  #   version    - Package version
  #   processors - Attribute set of processor derivations
  #                { package-download = <drv>; source-download = <drv>; stats = <drv>; finalize = <drv>; }
  #
  # RETURNS:
  #   A derivation that, when built, contains all persisted outputs organized
  #   by processor name (e.g., out/stats/stats.json) except for finalize which
  #   goes to the root (e.g., out/README.md, out/bloom.json)
  mkPersistWrapper =
    { pkgs
    , name
    , version
    , processors
    }:
    pkgs.stdenv.mkDerivation {
      pname = "deptext-pipeline";
      inherit version;
      name = "deptext-pipeline-${name}-${version}";

      # No source needed - we're just collecting outputs
      src = null;
      dontUnpack = true;

      # BUILD PHASE: Collect outputs from processors with persist=true
      buildPhase = ''
        echo "Collecting persisted outputs..."
      '';

      # INSTALL PHASE: Copy persisted outputs to organized directories
      #
      # For each processor with persist=true:
      # - Regular processors: Copy publish/* to $out/{processor-name}/
      # - Finalize processor: Copy publish/* to $out/ (root level)
      installPhase = ''
        mkdir -p $out

        echo "========================================"
        echo "PERSIST WRAPPER: Collecting outputs"
        echo "========================================"
        echo "Package: ${name} v${version}"
        echo ""

        # For each processor, check if it should be persisted
        # We use passthru.persist which was set in each processor

        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (procName: procDrv:
          let
            # Check if this processor has persist=true in its passthru
            # Default to false if not set
            shouldPersist = procDrv.passthru.persist or false;
            # Check if this is the finalize processor (special handling)
            isFinalize = procName == "finalize";
          in
          if shouldPersist then
            if isFinalize then ''
              # FINALIZE SPECIAL CASE: Copy to root level (no subfolder)
              echo "[persist] ${procName}: persist=true (root level)"
              echo "  Source: ${procDrv}/publish"
              if [ -d "${procDrv}/publish" ]; then
                echo "  Files in source:"
                ls -la "${procDrv}/publish" 2>/dev/null || echo "    (empty or error)"
                cp -r ${procDrv}/publish/* $out/ 2>/dev/null || true
                echo "  Copied to: $out/"
              else
                echo "  WARNING: publish directory not found!"
              fi
            '' else ''
              # REGULAR PROCESSOR: Copy publish/ contents to named subfolder
              echo "[persist] ${procName}: persist=true"
              echo "  Source: ${procDrv}/publish"
              mkdir -p $out/${procName}
              if [ -d "${procDrv}/publish" ]; then
                echo "  Files in source:"
                ls -la "${procDrv}/publish" 2>/dev/null || echo "    (empty or error)"
                cp -r ${procDrv}/publish/* $out/${procName}/ 2>/dev/null || true
                echo "  Copied to: $out/${procName}/"
              else
                echo "  WARNING: publish directory not found!"
              fi
            ''
          else ''
            echo "[persist] ${procName}: persist=false (skipped)"
          ''
        ) processors)}

        # Create a metadata file for tooling
        cat > $out/.deptext.json << 'EOF'
        {
          "name": "${name}",
          "version": "${version}",
          "processors": ${builtins.toJSON (lib.mapAttrs (k: v: {
            persist = v.passthru.persist or false;
          }) processors)}
        }
        EOF

        echo ""
        echo "========================================"
        echo "FINAL OUTPUT STRUCTURE"
        echo "========================================"
        echo "Output directory: $out"
        find $out -type f -o -type d | sort
        echo ""
        echo "Total files: $(find $out -type f | wc -l)"
        echo "Total size: $(du -sh $out | cut -f1)"
        echo "========================================"
      '';

      # Metadata
      meta = {
        description = "DepText pipeline output for ${name} ${version}";
      };

      # Make individual processors accessible via passthru for debugging
      passthru = {
        inherit processors;
        meta = {
          inherit name version;
        };
      };
    };

  # copyPersistedOutputs: Helper script content for copying to seed directory
  #
  # This generates a shell script that users can run after `nix build` to
  # copy the persisted outputs alongside their seed.nix file.
  #
  # USAGE:
  #   After running `nix build -f seed.nix`, run:
  #   cp -r result/* ./
  #
  # Or use this script content in a wrapper
  mkCopyScript =
    { name
    , version
    }:
    ''
      #!/usr/bin/env bash
      # Auto-generated script to copy persisted outputs
      # Run this from the directory containing seed.nix

      SCRIPT_DIR="$(cd "$(dirname "''${BASH_SOURCE[0]}")" && pwd)"
      RESULT="$SCRIPT_DIR/result"

      if [ ! -L "$RESULT" ]; then
        echo "Error: No 'result' symlink found. Run 'nix build -f seed.nix' first."
        exit 1
      fi

      echo "Copying persisted outputs from $RESULT..."

      # Copy files at root level (README.md, bloom.json from finalize)
      for file in "$RESULT"/*; do
        if [ -f "$file" ]; then
          filename=$(basename "$file")
          # Skip the metadata file
          if [ "$filename" != ".deptext.json" ]; then
            echo "  -> $filename"
            cp "$file" "$SCRIPT_DIR/"
          fi
        fi
      done

      # Copy processor subdirectories
      for dir in "$RESULT"/*/; do
        if [ -d "$dir" ]; then
          dirname=$(basename "$dir")
          if [ "$dirname" != "." ]; then
            echo "  -> $dirname/"
            cp -r "$dir" "$SCRIPT_DIR/"
          fi
        fi
      done

      echo "Done! Outputs copied to $SCRIPT_DIR"
    '';
}
