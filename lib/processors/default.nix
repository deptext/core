# Processor Factory Module
#
# This module provides the mkProcessor factory function that creates processor
# derivations with automatic timing capture. All processors in DepText should
# use this factory instead of directly calling stdenv.mkDerivation.
#
# WHAT THIS MODULE DOES:
# 1. Provides mkProcessor - a wrapper around stdenv.mkDerivation
# 2. Automatically injects timing capture at build start/end
# 3. Writes timing.json to the processor's output directory
# 4. Standardizes the processor output structure (publish/ subfolder)
#
# WHY USE A FACTORY:
# - DRY (Don't Repeat Yourself): Timing logic is defined once, used everywhere
# - Automatic: Processor authors can't forget to add timing
# - Consistent: All processors have identical timing.json structure
# - Maintainable: Changes to timing logic happen in one place
#
# OUTPUT STRUCTURE:
# Every processor built with mkProcessor produces:
#   $out/
#   ├── timing.json       # Auto-generated timing data (NOT in publish/)
#   └── publish/          # User-facing content (persisted if persist=true)
#       └── {processor-specific files}

{ lib }:

{
  # mkProcessor: Factory function that creates processor derivations with timing
  #
  # This function wraps stdenv.mkDerivation and automatically adds timing
  # capture. The timing is recorded at the start and end of the build phase,
  # and written to timing.json in the output directory.
  #
  # ARGUMENTS:
  #   pkgs           - The Nix package set (needed for stdenv, jq, coreutils)
  #   name           - Processor name (e.g., "stats", "package-download")
  #   pname          - Package name being processed (e.g., "serde")
  #   version        - Package version (e.g., "1.0.228")
  #   buildScript    - Shell commands for the processor's core logic
  #                    This is where you put what the processor actually does
  #   deps           - List of upstream processor derivations this depends on
  #   persist        - Whether publish/ should be copied to seed directory
  #   nativeBuildInputs - Additional build inputs (optional)
  #   passthruExtra  - Additional passthru attributes (optional)
  #   ... (any other stdenv.mkDerivation args)
  #
  # RETURNS:
  #   A derivation that, when built:
  #   1. Records start time
  #   2. Runs your buildScript
  #   3. Records end time
  #   4. Writes timing.json
  #
  # EXAMPLE:
  #   mkProcessor {
  #     pkgs = pkgs;
  #     name = "stats";
  #     pname = "serde";
  #     version = "1.0.228";
  #     persist = true;
  #     buildScript = ''
  #       # Count files and create stats.json
  #       file_count=$(find ${sourceDownload}/source -type f | wc -l)
  #       mkdir -p $out/publish
  #       echo "{\"file_count\": $file_count}" > $out/publish/stats.json
  #     '';
  #   }
  mkProcessor =
    { pkgs
    , name                    # Processor identifier (e.g., "stats")
    , pname                   # Package name (e.g., "serde")
    , version                 # Package version (e.g., "1.0.228")
    , buildScript             # Shell commands for processor logic
    , deps ? []               # Upstream processor derivations
    , persist ? false         # Whether to persist publish/ folder
    , nativeBuildInputs ? []  # Additional build dependencies
    , passthruExtra ? {}      # Additional passthru attributes
    , ...
    }@args:
    pkgs.stdenv.mkDerivation {
      # Derivation name follows pattern: deptext-{processor}-{package}-{version}
      # This makes it easy to identify in the Nix store and build logs
      name = "deptext-${name}-${pname}-${version}";
      pname = "deptext-${name}";
      inherit version;

      # No source code needed - processors work with upstream outputs
      src = null;
      dontUnpack = true;

      # Combine user's build inputs with our requirements
      # We always need jq (for JSON) and coreutils (for date, etc.)
      nativeBuildInputs = nativeBuildInputs ++ [ pkgs.jq pkgs.coreutils ];

      # BUILD PHASE: Run processor with timing wrapper
      #
      # The build phase is wrapped to capture timing:
      # 1. Record start time (Unix epoch milliseconds)
      # 2. Run the user's buildScript
      # 3. Record end time
      # 4. Calculate duration
      # 5. Write timing.json
      buildPhase = ''
        # ─────────────────────────────────────────────────────────────────────
        # TIMING START (auto-injected by mkProcessor)
        # ─────────────────────────────────────────────────────────────────────
        # Capture the current time in milliseconds since Unix epoch
        # date +%s gives seconds, +%3N adds milliseconds (3 digits)
        # We store this in a variable prefixed with _deptext_ to avoid
        # conflicts with user variables
        _deptext_start=$(date +%s%3N)

        # Create the output directory structure
        # $out is a special variable set by Nix - it's where our output goes
        mkdir -p $out/publish

        # ─────────────────────────────────────────────────────────────────────
        # USER'S PROCESSOR LOGIC
        # ─────────────────────────────────────────────────────────────────────
        # This is where the actual processor work happens
        # The buildScript has access to $out, all deps, and any other variables
        ${buildScript}

        # ─────────────────────────────────────────────────────────────────────
        # TIMING END (auto-injected by mkProcessor)
        # ─────────────────────────────────────────────────────────────────────
        # Capture end time and calculate duration
        _deptext_end=$(date +%s%3N)
        _deptext_duration=$((_deptext_end - _deptext_start))

        # Write timing.json to the OUTPUT ROOT (not in publish/)
        # This file is for internal use by the finalize processor
        # It's not part of the user-facing output
        ${pkgs.jq}/bin/jq -n \
          --argjson start "$_deptext_start" \
          --argjson end "$_deptext_end" \
          --argjson duration "$_deptext_duration" \
          '{startTime: $start, endTime: $end, buildDuration: $duration}' \
          > $out/timing.json

        echo "Timing recorded: ''${_deptext_duration}ms"
      '';

      # INSTALL PHASE: Skip since we do everything in buildPhase
      # The buildScript is responsible for putting files in $out/publish/
      installPhase = ''
        echo "Build complete for ${name}"
      '';

      # Metadata about this derivation for Nix tooling
      meta = {
        description = "DepText ${name} processor for ${pname} ${version}";
      };

      # PASSTHRU: Extra attributes accessible on the derivation
      # These are used by other parts of DepText (e.g., persist.nix checks persist)
      passthru = {
        processorName = name;
        inherit persist;
      } // passthruExtra;
    };
}
