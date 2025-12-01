# Research: Finalize Processor

**Date**: 2025-12-01
**Branch**: `003-finalize-processor`

## Overview

Research findings for implementing the finalize processor, focusing on Nix patterns for timing injection, JSON aggregation with jq, and markdown generation in shell scripts.

## 1. mkProcessor Factory Pattern

### Decision
Create a `mkProcessor` function that wraps `stdenv.mkDerivation` and auto-injects timing capture at build start/end.

### Rationale
- **DRY**: Timing logic defined once, used by all processors
- **Automatic**: Processor authors can't forget to add timing
- **Consistent**: All processors have identical timing.json structure
- **Idiomatic**: Factory functions are standard Nix patterns

### Implementation Pattern

```nix
# lib/processors/default.nix
{ pkgs, ... }:

{
  # mkProcessor: Factory function that creates processor derivations
  # with automatic timing capture.
  #
  # Arguments:
  #   name        - Processor identifier (e.g., "stats")
  #   buildScript - Shell commands for the processor's core logic
  #   deps        - List of upstream processor derivations
  #   persist     - Whether to copy publish/ to seed directory (default: false)
  #
  mkProcessor = { name, buildScript, deps ? [], persist ? false, ... }@args:
    pkgs.stdenv.mkDerivation (args // {
      name = "deptext-${name}-${args.pname}-${args.version}";

      buildInputs = deps ++ [ pkgs.jq pkgs.coreutils ];

      buildPhase = ''
        # ─── Timing start (auto-injected) ───
        _deptext_start=$(date +%s%3N)

        # ─── Processor logic (user-provided) ───
        ${buildScript}

        # ─── Timing end + write (auto-injected) ───
        _deptext_end=$(date +%s%3N)
        _deptext_duration=$((_deptext_end - _deptext_start))

        ${pkgs.jq}/bin/jq -n \
          --argjson start "$_deptext_start" \
          --argjson end "$_deptext_end" \
          --argjson duration "$_deptext_duration" \
          '{startTime: $start, endTime: $end, buildDuration: $duration}' \
          > $out/timing.json
      '';

      # Pass through for persist.nix to use
      passthru = { inherit persist name; };
    });
}
```

### Alternatives Considered

| Alternative | Rejected Because |
|-------------|------------------|
| Manual timing calls in each processor | Error-prone, DRY violation |
| Wrapper script around buildPhase | More complex, less integrated with Nix |
| Nix setupHook mechanism | Overkill for this use case, harder to understand |

## 2. Timing Data Capture

### Decision
Use shell `date +%s%3N` for millisecond-precision timestamps within the Nix build phase.

### Rationale
- `date` is universally available in Nix builds
- `%s%3N` gives epoch milliseconds (sufficient precision)
- Shell arithmetic can compute duration directly
- jq formats the JSON cleanly

### timing.json Format

```json
{
  "startTime": 1701432000000,
  "endTime": 1701432012345,
  "buildDuration": 12345
}
```

### Edge Cases

| Case | Handling |
|------|----------|
| Processor fails mid-build | timing.json may be missing or incomplete; finalize won't run anyway |
| Clock skew | Acceptable for relative durations; absolute timestamps are informational only |
| Very fast processors (<1ms) | Will show 0ms duration; acceptable |

## 3. Duration Formatting

### Decision
Implement duration formatting in a shell function using awk for the decimal math.

### Rationale
- Shell-native, no extra dependencies
- Matches the example format: "5m 42.15s", "45.23s"
- Handles edge cases (hours, sub-second)

### Implementation Pattern

```bash
# Format milliseconds to human-readable duration
# Input: milliseconds (integer)
# Output: "Xh Ym Z.ZZs" or "Ym Z.ZZs" or "Z.ZZs"
format_duration() {
  local ms=$1
  local seconds=$((ms / 1000))
  local millis=$((ms % 1000))
  local minutes=$((seconds / 60))
  local secs=$((seconds % 60))
  local hours=$((minutes / 60))
  local mins=$((minutes % 60))

  # Format with centiseconds (2 decimal places)
  local centis=$((millis / 10))

  if [ $hours -gt 0 ]; then
    printf "%dh %dm %d.%02ds" $hours $mins $secs $centis
  elif [ $minutes -gt 0 ]; then
    printf "%dm %d.%02ds" $mins $secs $centis
  else
    printf "%d.%02ds" $secs $centis
  fi
}
```

## 4. File Size Formatting

### Decision
Use shell arithmetic with thresholds for human-readable sizes.

### Implementation Pattern

```bash
# Format bytes to human-readable size
# Input: bytes (integer)
# Output: "X.XX MB", "X.XX KB", "X B"
format_size() {
  local bytes=$1

  if [ $bytes -ge 1048576 ]; then
    # MB (with 2 decimal places)
    local mb=$((bytes * 100 / 1048576))
    printf "%d.%02d MB" $((mb / 100)) $((mb % 100))
  elif [ $bytes -ge 1024 ]; then
    # KB (with 2 decimal places)
    local kb=$((bytes * 100 / 1024))
    printf "%d.%02d KB" $((kb / 100)) $((kb % 100))
  else
    printf "%d B" $bytes
  fi
}
```

## 5. JSON Aggregation with jq

### Decision
Use jq for all JSON manipulation in the finalize processor.

### Rationale
- jq is declarative and readable
- Handles null/missing fields gracefully
- Available in nixpkgs

### Key jq Patterns

```bash
# Read timing from upstream processor
timing=$(jq -r '.buildDuration' ${upstream}/timing.json)

# Build processor entry with conditional fields
jq -n \
  --arg name "stats" \
  --argjson active true \
  --argjson published true \
  --argjson duration 12345 \
  --argjson fileCount 42 \
  --argjson fileSize 1024 \
  '{
    ($name): {
      active: $active,
      published: $published,
      buildDuration: $duration
    } + (if $published then {fileCount: $fileCount, fileSize: $fileSize} else {} end)
  }'

# Merge multiple processor entries
jq -s 'add' proc1.json proc2.json proc3.json > processors.json
```

## 6. Markdown Generation

### Decision
Use heredoc with shell variable interpolation for README.md generation.

### Rationale
- Simple and readable
- No templating engine dependency
- Shell variables interpolate naturally

### Implementation Pattern

```bash
# Generate README.md
cat > $out/publish/README.md << EOF
# ${pname} v${version}

**Language**: ${language}
**Last Build**: ${timestamp}
**Build Duration**: ${total_duration}

## Processors

| Processor | Active | Published | Duration | Files | Size |
|-----------|--------|-----------|----------|-------|------|
${processor_rows}
EOF
```

### Table Row Generation

```bash
# Generate a single processor row
generate_row() {
  local name=$1
  local active=$2
  local published=$3
  local duration=$4
  local files=$5
  local size=$6
  local link=$7

  local active_sym="✗"
  [ "$active" = "true" ] && active_sym="✓"

  local pub_col="-"
  if [ "$published" = "true" ]; then
    pub_col="[view output]($link)"
  elif [ "$active" = "true" ]; then
    pub_col="✓"
  fi

  echo "| ${name} | ${active_sym} | ${pub_col} | ${duration} | ${files} | ${size} |"
}
```

## 7. Directory Scanning

### Decision
Use `find` for file counting and `du` for size calculation within publish/ folders.

### Implementation Pattern

```bash
# Count files in processor's publish/ directory
count_files() {
  local dir=$1
  find "$dir" -type f | wc -l
}

# Calculate total size in bytes
calculate_size() {
  local dir=$1
  du -sb "$dir" 2>/dev/null | cut -f1 || echo "0"
}

# Calculate SHA256 hash of directory contents
calculate_hash() {
  local dir=$1
  find "$dir" -type f -exec sha256sum {} \; | sort | sha256sum | cut -d' ' -f1
}
```

## 8. Finalize Special Case Handling

### Decision
The finalize processor is identified by name and handled specially in persist.nix.

### Implementation Pattern

```nix
# lib/utils/persist.nix
{ processor, seedDir, ... }:

let
  isFinalize = processor.name == "finalize";
  targetDir = if isFinalize
    then seedDir
    else "${seedDir}/${processor.name}";
in
  # Copy publish/ contents to target directory
  pkgs.runCommand "persist-${processor.name}" {} ''
    mkdir -p ${targetDir}
    cp -r ${processor}/publish/* ${targetDir}/
  ''
```

## 9. Processor Configuration Flow

### Decision
Processor list is hardcoded per language; active status flows from defaults + seed.nix overrides.

### Data Flow

```text
rust.nix (hardcoded processor list)
    ↓
seed.nix (optional overrides)
    ↓
mkRustPackage (merge config)
    ↓
mkProcessor (create derivation with timing)
    ↓
finalize (read all processor outputs)
```

### Configuration Merge Example

```nix
# lib/languages/rust.nix
{ mkProcessor, mkFinalize, ... }:

{ name, version, github, processors ? {}, ... }:

let
  # Default processor configuration
  defaultConfig = {
    package-download = { enabled = true; persist = false; };
    source-download = { enabled = true; persist = false; };
    stats = { enabled = true; persist = true; };
    finalize = { enabled = true; persist = true; };
  };

  # Merge with user overrides
  config = defaultConfig // processors;
in
  # Build processor chain...
```

## Summary

All technical approaches are standard Nix/shell patterns with no external dependencies beyond nixpkgs. The mkProcessor factory provides a clean abstraction for timing injection, and jq handles all JSON manipulation. No NEEDS CLARIFICATION items remain.
