# Quickstart: Rustdoc Processors

**Date**: 2025-12-01
**Feature**: 004-rustdoc-processors

## Overview

This guide explains how to use the new rustdoc processors to generate markdown documentation from Rust packages.

---

## Basic Usage

### Default Behavior (Documentation Enabled)

After this feature is implemented, building a Rust seed automatically generates markdown documentation:

```bash
nix build --impure -f lib/eval-seed.nix --argstr seedPath "$PWD/examples/rust/serde/seed.nix"
```

**Output includes:**
```text
result/
├── README.md           # Build summary (includes rustdoc-md stats)
├── bloom.json          # Machine-readable metadata
├── stats/
│   └── stats.json      # File statistics
└── rustdoc-md/
    └── docs.md         # Generated markdown documentation
```

Note: `rustdoc-json/` is NOT in the output by default (persist=false).

---

## Configuration Options

### Persist JSON Documentation (for debugging)

To also output the intermediate JSON documentation:

```nix
# seed.nix
{ deptext }:

deptext.mkRustPackage {
  pname = "serde";
  version = "1.0.215";
  hash = "sha256:...";
  github = { owner = "serde-rs"; repo = "serde"; rev = "v1.0.215"; hash = "sha256:..."; };

  # Custom processor configuration
  processors = {
    rustdoc-json = { persist = true; };  # Also output JSON
  };
}
```

**Output now includes:**
```text
result/
├── ...
├── rustdoc-json/
│   └── serde.json      # Raw rustdoc JSON
└── rustdoc-md/
    └── docs.md
```

### Disable Documentation Generation

To skip documentation entirely (faster builds):

```nix
# seed.nix
{ deptext }:

deptext.mkRustPackage {
  pname = "serde";
  version = "1.0.215";
  hash = "sha256:...";
  github = { ... };

  processors = {
    rustdoc-json = { enabled = false; };  # Disables both rustdoc processors
  };
}
```

### Disable Only Markdown Conversion

To generate JSON but skip markdown conversion:

```nix
processors = {
  rustdoc-md = { enabled = false; };  # JSON generated, markdown not
};
```

---

## Understanding the Output

### docs.md Structure

The generated markdown documentation includes:

```markdown
# serde v1.0.215

[Crate-level documentation]

## Modules

### `serde::de`
[Module documentation and contents]

### `serde::ser`
[Module documentation and contents]

## Structs
[Public struct definitions with docs]

## Enums
[Public enum definitions with docs]

## Traits
[Public trait definitions with docs]

## Functions
[Public function signatures with docs]
```

### bloom.json Processor Data

The bloom.json now includes rustdoc processor metadata:

```json
{
  "processors": {
    "rustdoc-json": {
      "active": true,
      "published": false,
      "buildDuration": 45000
    },
    "rustdoc-md": {
      "active": true,
      "published": true,
      "buildDuration": 2000,
      "fileCount": 1,
      "fileSize": 150000
    }
  }
}
```

---

## Troubleshooting

### "rustdoc failed to parse source"

The Rust source code may have syntax errors or require features not available in the nightly version. Check:
- Source code compiles successfully
- No missing dependencies

### "rustdoc-md conversion failed"

The JSON format may be incompatible. Check:
- Rustdoc JSON format_version matches expected (currently 42)
- Report issue if format version changed

### Build takes too long

Large crates take longer. Consider:
- Disabling documentation for development iterations
- Running full builds less frequently

---

## Examples

### Full Example Seed with All Options

```nix
# examples/rust/my-crate/seed.nix
{ deptext }:

deptext.mkRustPackage {
  pname = "my-crate";
  version = "0.1.0";
  hash = "sha256:...";
  github = {
    owner = "myorg";
    repo = "my-crate";
    rev = "v0.1.0";
    hash = "sha256:...";
  };

  processors = {
    # Persist everything for inspection
    package-download = { persist = true; };
    source-download = { persist = true; };
    rustdoc-json = { persist = true; };
    # rustdoc-md persists by default
  };
}
```

---

## For Developers

### Testing the Feature

```bash
# Run the integration test
./tests/integration/test-rust-seed.sh

# Build example and inspect output
nix build --impure -f lib/eval-seed.nix --argstr seedPath "$PWD/examples/rust/serde/seed.nix"
ls -la result/rustdoc-md/
cat result/rustdoc-md/docs.md | head -100
```

### Verifying Processor Integration

Check that bloom.json includes the new processors:

```bash
jq '.processors | keys' result/bloom.json
# Should include: ["package-download", "rustdoc-json", "rustdoc-md", "source-download", "stats"]
```
