# Research: Rustdoc Processors

**Date**: 2025-12-01
**Feature**: 004-rustdoc-processors

## Overview

This document consolidates research findings for implementing rustdoc-json and rustdoc-md processors in the DepText pipeline.

---

## 1. Rustdoc JSON Output

### Decision
Use Rust nightly with `rustdoc --output-format json` to generate JSON documentation.

### Rationale
- Rustdoc JSON is the official, well-documented format for machine-readable Rust documentation
- Provides complete API structure including modules, structs, enums, functions, traits, and doc comments
- Format version tracking (currently v42) allows detecting compatibility issues

### Alternatives Considered
| Alternative | Rejected Because |
|-------------|------------------|
| RUSTC_BOOTSTRAP=1 on stable | Hacky workaround; better to use nightly directly for unstable features |
| Parse HTML output | Fragile, not designed for machine consumption |
| Custom source parsing | Duplicates rustdoc's extensive work, would miss edge cases |

### Implementation Details

**Command to generate JSON docs:**
```bash
cargo +nightly rustdoc -- -Z unstable-options --output-format json
```

**Output location:** `target/doc/<crate_name>.json`

**JSON structure (key fields):**
- `root`: ID of the root module
- `crate_version`: Version string
- `index`: Map of all items (modules, structs, functions, etc.)
- `paths`: Maps IDs to fully qualified paths
- `format_version`: Currently 42

**Nix integration:**
```nix
nativeBuildInputs = [ pkgs.rustPlatform.rust.cargo pkgs.rustPlatform.rust.rustc ];
buildPhase = ''
  export CARGO_HOME=$(mktemp -d)
  cargo +nightly rustdoc -- -Z unstable-options --output-format json
'';
```

---

## 2. JSON-to-Markdown Conversion Tool

### Decision
Use **rustdoc-md** crate.

**Note**: The original user request mentioned "cargo-doc-md" but this crate does not exist on crates.io. The correct tool is **rustdoc-md** which performs the same function.

### Rationale
- Actively maintained, designed specifically for rustdoc JSON → Markdown conversion
- Produces well-structured, human-readable output
- Can be packaged in Nix using rustPlatform.buildRustPackage
- Outputs single navigable Markdown file (ideal for LLM context windows)

### Alternatives Considered
| Alternative | Rejected Because |
|-------------|------------------|
| cargo-doc-md | Does not exist on crates.io |
| doc-sync | Early-stage, designed for roundtrip editing not doc generation |
| rustdoc_to_markdown | Limited scope, only transforms code blocks |
| cargo-readme | Different purpose (README from docstrings, not full API docs) |

### Implementation Details

**Installation:**
```bash
cargo install rustdoc-md
```

**Usage:**
```bash
rustdoc-md --path target/doc/serde.json --output api_docs.md
```

**Nix packaging (required - not in nixpkgs):**
```nix
rustdoc-md = pkgs.rustPlatform.buildRustPackage {
  pname = "rustdoc-md";
  version = "0.1.0";  # Check latest version
  src = pkgs.fetchFromGitHub {
    owner = "tqwewe";
    repo = "rustdoc-md";
    rev = "...";
    hash = "sha256-...";
  };
  cargoHash = "sha256-...";
};
```

---

## 3. Nix Integration Approach

### Decision
Create two separate processor derivations following the existing mkProcessor pattern.

### Rationale
- Consistent with existing processors (stats, source-download, package-download)
- Allows independent enable/disable and persist configuration
- Clear dependency chain (rustdoc-md depends on rustdoc-json output)

### Implementation Pattern

**rustdoc-json processor:**
1. Takes source-download output as input
2. Runs `cargo +nightly rustdoc` with JSON output flags
3. Outputs JSON file to `$out/publish/`
4. Default: `persist = false`

**rustdoc-md processor:**
1. Takes rustdoc-json output as input
2. Runs `rustdoc-md` to convert JSON → Markdown
3. Outputs markdown files to `$out/publish/`
4. Default: `persist = true`

---

## 4. Dependencies to Package

### Required Nix Packages

| Package | Source | Notes |
|---------|--------|-------|
| cargo (nightly) | nixpkgs | Use rust-bin or oxalica overlay for nightly |
| rustc (nightly) | nixpkgs | Same as above |
| rustdoc-md | Build from source | Not in nixpkgs, needs packaging |

### Recommended Approach for Nightly Rust

Use `fenix` or `rust-overlay` flake for reliable nightly Rust in Nix:

```nix
inputs.fenix.url = "github:nix-community/fenix";

# Then in outputs:
rustToolchain = fenix.packages.${system}.latest.toolchain;
```

---

## 5. Open Questions Resolved

| Question | Resolution |
|----------|------------|
| What tool converts rustdoc JSON to markdown? | rustdoc-md (not cargo-doc-md) |
| Is nightly Rust required? | Yes, for `--output-format json` flag |
| Is rustdoc-md in nixpkgs? | No, needs custom packaging |
| What's the JSON format version? | Currently 42 (unstable, may change) |

---

## 6. Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Rustdoc JSON format changes | Check format_version field, fail gracefully on incompatibility |
| rustdoc-md becomes unmaintained | Simple tool, could fork or replace with alternative |
| Nightly Rust version incompatibility | Pin specific nightly version in Nix derivation |
| Large crates timeout | Allow configurable timeout, document expected build times |

---

## Sources

- [RFC 2963 - Rustdoc JSON](https://rust-lang.github.io/rfcs/2963-rustdoc-json.html)
- [rustdoc-types crate](https://docs.rs/rustdoc-types)
- [rustdoc-md on crates.io](https://crates.io/crates/rustdoc-md)
- [rustdoc-md GitHub](https://github.com/tqwewe/rustdoc-md)
- [Fenix - Rust toolchains for Nix](https://github.com/nix-community/fenix)
