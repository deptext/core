# Implementation Plan: Rustdoc Processors

**Branch**: `004-rustdoc-processors` | **Date**: 2025-12-01 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/004-rustdoc-processors/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Add two new processors to the Rust package pipeline:
1. **rustdoc-json**: Generates JSON documentation from Rust source code using rustdoc's JSON output format (persist=false by default)
2. **rustdoc-md**: Converts rustdoc JSON to markdown using rustdoc-md (persist=true by default)

The processors run sequentially (rustdoc-md depends on rustdoc-json output) but in parallel with the existing stats processor, as both consume source-download output independently.

## Technical Context

**Language/Version**: Nix (flakes-enabled, requires Nix 2.4+), Rust nightly (for rustdoc JSON output)
**Primary Dependencies**: rustdoc (nightly), rustdoc-md crate, existing mkProcessor factory
**Storage**: Nix store for processor I/O; filesystem for persisted bloom outputs
**Testing**: Bash integration tests (test-rust-seed.sh pattern)
**Target Platform**: Linux, macOS (any platform with Nix support)
**Project Type**: Single project (Nix library with CLI)
**Performance Goals**: Complete rustdoc processing for serde in under 5 minutes
**Constraints**: Must follow existing processor patterns (mkProcessor, publish/, timing.json)
**Scale/Scope**: Process crates of varying sizes (small to large like serde)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Rule | Status | Evidence |
|------|--------|----------|
| NEVER over-engineer | PASS | Two focused processors following existing patterns |
| Easy to understand and maintain | PASS | Following established mkProcessor factory pattern |
| NEVER create code debt | PASS | Clean integration with existing pipeline |
| No backwards compatibility hacks | PASS | New feature, no legacy concerns |
| Extremely modular code | PASS | Separate processor files, clear dependencies |
| Modern tooling only | PASS | Using nightly Rust rustdoc JSON (latest) |
| Extensive beginner-friendly comments | PENDING | Will apply during implementation |

**Gate Result**: PASS - All constitution rules satisfied or pending implementation details

## Project Structure

### Documentation (this feature)

```text
specs/004-rustdoc-processors/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
lib/
├── packages/
│   └── rustdoc-md.nix           # NEW: Builds rustdoc-md tool from source (not in nixpkgs)
├── processors/
│   ├── default.nix              # mkProcessor factory (unchanged)
│   ├── finalize.nix             # Universal processor (unchanged)
│   ├── source-download.nix      # Universal processor (unchanged)
│   ├── stats.nix                # Universal processor (unchanged)
│   ├── rust/                    # NEW: All Rust-only processors
│   │   ├── package-download.nix # MOVED from package-download/rust.nix
│   │   ├── rustdoc-json.nix     # NEW: rustdoc JSON generator
│   │   └── rustdoc-md.nix       # NEW: JSON-to-markdown converter
│   └── python/                  # NEW: All Python-only processors
│       └── package-download.nix # MOVED from package-download/python.nix
└── languages/
    └── rust.nix                 # MODIFY: Update imports, add rustdoc processors

tests/
└── integration/
    └── test-rust-seed.sh        # MODIFY: Add rustdoc output validation
```

**Structure Decision**: Processors are organized by language scope:
- **Universal processors** (`stats.nix`, `source-download.nix`, `finalize.nix`) stay at the root
- **Language-specific processors** go in `rust/` or `python/` subfolders
- **Custom packages** for external tools not in nixpkgs go in `lib/packages/`

This refactors the existing `package-download/` folder (processor-first naming) to the new language-first pattern for consistency as the number of processors grows.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No violations - all constitution rules pass.
