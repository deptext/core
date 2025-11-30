# Implementation Plan: DepText MVP - Nix Processor Pipeline

**Branch**: `001-nix-processor-pipeline` | **Date**: 2025-11-30 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-nix-processor-pipeline/spec.md`

## Summary

Build a Nix flake that exports language helper functions (`mkRustPackage`, `mkPythonPackage`) to create processor pipelines for open source packages. The MVP includes three processors: package download (from crates.io/PyPI), source download (from GitHub with URL validation), and stats generation (file count). Processors are Nix derivations that form a dependency tree with automatic parallel execution. Only the stats processor persists output by default; others keep data in the Nix store.

## Technical Context

**Language/Version**: Nix (flakes-enabled, requires Nix 2.4+)
**Primary Dependencies**: Nix builtins (fetchurl, fetchFromGitHub), jq for JSON processing, coreutils for file operations
**Storage**: Nix store for processor I/O; filesystem for persisted bloom outputs
**Testing**: Nix build validation (successful builds = passing tests), shell script integration tests
**Target Platform**: Any system with Nix installed (Linux, macOS, WSL)
**Project Type**: Single project (Nix flake with library functions)
**Performance Goals**: Build completes in <5 minutes excluding network time (per SC-001)
**Constraints**: Network access required; no authentication for MVP; fail-fast on any processor error
**Scale/Scope**: MVP supports 2 languages (Rust, Python), 3 processors, single-package builds

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Gate | Status | Notes |
|------|--------|-------|
| Never over-engineer | PASS | MVP scope with only 3 processors; no advanced features |
| Code easy to understand | PASS | Nix is declarative; extensive comments required per constitution |
| Never create code debt | PASS | Clean implementation from scratch |
| No backwards compatibility | PASS | New project, no legacy concerns |
| Extremely modular code | PASS | Each processor is independent derivation; language helpers compose them |
| Modern tooling only | PASS | Nix flakes (modern Nix) required |
| Extensive beginner-friendly comments | REQUIRED | All Nix code must explain what derivations, flakes, and Nix concepts mean |

## Project Structure

### Documentation (this feature)

```text
specs/001-nix-processor-pipeline/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (processor I/O schemas)
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
flake.nix                    # Main entry point - exports language helpers
flake.lock                   # Pinned dependencies

lib/
├── default.nix              # Library entry point, exports all helpers
├── processors/
│   ├── package-download/
│   │   ├── rust.nix         # Fetch from crates.io
│   │   └── python.nix       # Fetch from PyPI
│   ├── source-download.nix  # Fetch from GitHub, validate URL
│   └── stats.nix            # Generate file count statistics
├── languages/
│   ├── rust.nix             # mkRustPackage helper
│   └── python.nix           # mkPythonPackage helper
└── utils/
    ├── persist.nix          # Copy outputs from store to seed directory
    └── validate.nix         # URL validation helpers

examples/
├── rust/
│   └── serde/
│       └── seed.nix         # Example Rust seed for testing
└── python/
    └── requests/
        └── seed.nix         # Example Python seed for testing

tests/
├── integration/
│   ├── test-rust-seed.sh    # End-to-end Rust package test
│   └── test-python-seed.sh  # End-to-end Python package test
└── unit/
    └── test-validation.sh   # URL validation unit tests
```

**Structure Decision**: Single Nix flake project with modular library structure. Processors are separate files for maintainability. Language helpers compose processors into dependency trees. Examples serve as both documentation and integration tests.

## Complexity Tracking

No constitution violations requiring justification. The design follows all gates:
- Simple, modular Nix code
- No over-engineering (3 processors, 2 languages only)
- Extensive comments will be added during implementation

## Post-Design Constitution Re-Check

*Re-evaluated after Phase 1 design artifacts created.*

| Gate | Status | Post-Design Notes |
|------|--------|-------------------|
| Never over-engineer | PASS | Design stays minimal: 3 processors, 2 languages, 4 JSON schemas |
| Code easy to understand | PASS | Data model uses clear entity definitions; schemas are self-documenting |
| Never create code debt | PASS | Clean separation: lib/processors/, lib/languages/, lib/utils/ |
| No backwards compatibility | PASS | No legacy concerns in design |
| Extremely modular code | PASS | Each processor in separate file; language helpers are composable |
| Modern tooling only | PASS | Uses Nix flakes, JSON Schema for contracts |
| Extensive beginner-friendly comments | REQUIRED | Quickstart explains concepts; code must follow same pattern |

**Conclusion**: Design phase complete. All constitution gates pass. Ready for `/speckit.tasks`.

## Generated Artifacts

| Artifact | Path | Purpose |
|----------|------|---------|
| Research | [research.md](./research.md) | Nix patterns, API endpoints, dependency patterns |
| Data Model | [data-model.md](./data-model.md) | Entity definitions, state transitions, validation rules |
| Seed Input Schema | [contracts/seed-input.schema.json](./contracts/seed-input.schema.json) | Validates seed.nix configuration |
| Rust Metadata Schema | [contracts/metadata-rust.schema.json](./contracts/metadata-rust.schema.json) | crates.io metadata format |
| Python Metadata Schema | [contracts/metadata-python.schema.json](./contracts/metadata-python.schema.json) | PyPI metadata format |
| Stats Schema | [contracts/stats.schema.json](./contracts/stats.schema.json) | Stats processor output format |
| Quickstart | [quickstart.md](./quickstart.md) | User guide for creating and building seeds |
