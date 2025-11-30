# Feature Specification: DepText MVP - Nix Processor Pipeline

**Feature Branch**: `001-nix-processor-pipeline`
**Created**: 2025-11-30
**Status**: Draft
**Input**: User description: "DepText is a Nix-based build system that processes open source packages through a chain of processors, outputting structured metadata such as generated documentation, extracted type definitions, and mirrored source code. This output is designed to be included in LLM context windows during agentic coding sessions. Nix serves as the DSL for defining analysis pipelines. Reproducibility is not a goal since some processors call LLMs, which are non-deterministic. Instead, Nix provides declarative pipeline definitions and automatic dependency resolution between processors. Users write a seed.nix file that specifies a package name, version, and GitHub repository. Nix resolves the processor dependency tree and executes it. Processors are the fundamental unit and form a dependency tree. Each processor inherits output from the processors it depends on and produces its own output for downstream consumers. Processors only receive input from previous processor outputs or configuration from the seed.nix file. They run in parallel where the dependency tree allows. DepText supports Rust, TypeScript, Python, and Ruby. Some processors are language-specific, invoking tools like cargo doc or TypeDoc, while others work across all languages. Processors can be toggled or configured per-seed, but defaults minimize boilerplate. Output is written alongside the seed.nix in the nursery repository, for example at `github.com/deptext/nursery/rust/s/se/serde/1.0.228/seed.nix`. Any failures/errors in any processors are considered critical, and cause the whole generation to fail. Seeds are germinated with `nix build -f rust/s/se/serde/1.0.228/seed.nix`, producing blooms - documentation, types, and source artifacts written alongside each seed. Create an MVP of this system - a new project containing a Nix flake exporting language helpers (mkRustPackage, mkTypeScriptPackage, etc.) that wire up a processor dependency tree. Processors are derivations that inherit upstream outputs and produce downstream artifacts. Seeds call language helpers with package metadata. Germinating a seed with `nix build` executes the tree and writes blooms alongside it. Start with Rust and Python dependencies, and include this processor map -> downloading packages from the official repos (outputting package content and metadata.json) -> downloading source from github (validates against repo address from first processor if url exists in metadata -> generating very basic stats about the repo (just file count for now, as this is just a proof of concept)."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Germinate a Rust Package Seed (Priority: P1)

A developer wants to generate LLM-ready context for a Rust package (e.g., serde). They create a seed.nix file specifying the package name, version, and GitHub repository URL. Running `nix build` on the seed executes the processor chain and produces "blooms" - structured output files containing package metadata, source code, and statistics.

**Why this priority**: This is the core end-to-end workflow. Without the ability to germinate a seed and produce output, the system provides no value. Rust is specified as a primary language in the MVP requirements.

**Independent Test**: Can be fully tested by creating a sample seed.nix for a real Rust package (e.g., serde 1.0.228), running `nix build`, and verifying that all expected output files are generated with correct content.

**Acceptance Scenarios**:

1. **Given** a seed.nix file with package name "serde", version "1.0.228", and GitHub URL "https://github.com/serde-rs/serde", **When** user runs `nix build -f seed.nix`, **Then** the system downloads the package from crates.io, downloads source from GitHub, validates the repository URL matches metadata, generates file count statistics, and writes all outputs alongside the seed.nix.

2. **Given** a seed.nix file for a Rust package, **When** any processor in the chain fails, **Then** the entire build fails with a clear error message indicating which processor failed and why.

3. **Given** a seed.nix file for a Rust package without a GitHub URL in the registry metadata, **When** user runs `nix build`, **Then** the system uses the GitHub URL from seed.nix directly without validation and continues processing.

---

### User Story 2 - Germinate a Python Package Seed (Priority: P2)

A developer wants to generate LLM-ready context for a Python package (e.g., requests). They create a seed.nix file specifying the package name, version, and GitHub repository URL. The system processes it through the same pipeline architecture as Rust packages but uses Python-specific tooling for package download.

**Why this priority**: Python is the second language specified in the MVP. Having two languages validates that the architecture is language-agnostic where appropriate while supporting language-specific processors.

**Independent Test**: Can be fully tested by creating a sample seed.nix for a real Python package (e.g., requests 2.31.0), running `nix build`, and verifying output generation.

**Acceptance Scenarios**:

1. **Given** a seed.nix file with package name "requests", version "2.31.0", and GitHub URL "https://github.com/psf/requests", **When** user runs `nix build -f seed.nix`, **Then** the system downloads the package from PyPI, downloads source from GitHub, validates repository URLs if available, generates statistics, and writes all outputs.

2. **Given** a Python seed.nix, **When** the PyPI package metadata contains a repository URL, **Then** the system validates it matches the GitHub URL specified in seed.nix.

---

### User Story 3 - Configure Processor Behavior Per-Seed (Priority: P3)

A developer wants to customize processor behavior for a specific package. They add optional configuration to their seed.nix to toggle processors on/off or adjust processor settings. Default configurations work for most packages, minimizing required boilerplate.

**Why this priority**: Flexibility is important but not critical for MVP. The system should work with sensible defaults first.

**Independent Test**: Can be tested by creating two seed.nix files for the same package - one with defaults and one with custom configuration - and verifying the outputs differ according to the configuration.

**Acceptance Scenarios**:

1. **Given** a seed.nix with no custom configuration, **When** user runs `nix build`, **Then** all default processors execute with default settings.

2. **Given** a seed.nix with a processor explicitly disabled, **When** user runs `nix build`, **Then** that processor is skipped and its downstream dependents fail gracefully or are also skipped.

---

### Edge Cases

- What happens when the package doesn't exist in the official registry (crates.io/PyPI)?
  - Build fails with a clear error indicating the package was not found.

- What happens when the GitHub repository URL is invalid or inaccessible?
  - Build fails with a clear error indicating the repository could not be accessed.

- What happens when the package version doesn't exist?
  - Build fails with a clear error indicating the version was not found.

- What happens when GitHub rate limits are exceeded?
  - Build fails with a clear error about rate limiting, suggesting authentication if appropriate.

- What happens when the repository URL in metadata differs from seed.nix?
  - Build fails with a validation error showing both URLs and asking user to verify.

- What happens when network connectivity is lost mid-build?
  - Build fails with appropriate network error, and partial outputs are not persisted.

## Requirements *(mandatory)*

### Functional Requirements

#### Nix Flake Structure

- **FR-001**: System MUST be packaged as a Nix flake that can be consumed by seed.nix files.
- **FR-002**: Flake MUST export language helper functions: `mkRustPackage` and `mkPythonPackage`.
- **FR-003**: Language helpers MUST accept package metadata (name, version, GitHub URL) and return a derivation that executes the processor tree.

#### Seed Files

- **FR-004**: Seeds MUST be Nix files that call a language helper with package metadata.
- **FR-005**: Seed metadata MUST include: package name, version, and GitHub repository URL.
- **FR-006**: Seeds MUST support optional configuration to toggle or configure individual processors.
- **FR-007**: Seeds MUST be buildable via standard `nix build -f <path>/seed.nix` command.

#### Processor Architecture

- **FR-008**: Processors MUST be implemented as Nix derivations.
- **FR-009**: Processors MUST form a dependency tree where each processor receives inputs only from upstream processor outputs or seed configuration.
- **FR-010**: Processors MUST execute in parallel where the dependency tree allows.
- **FR-011**: Any processor failure MUST cause the entire build to fail.
- **FR-012**: Processors MUST produce structured output in their designated output directories.

#### MVP Processor Chain

- **FR-013**: Package Download Processor MUST download the package from the official registry (crates.io for Rust, PyPI for Python). Default: `persist = false`.
- **FR-014**: Package Download Processor MUST output the package contents and a metadata.json file containing registry metadata.
- **FR-015**: Source Download Processor MUST download source code from the GitHub repository specified in seed.nix. Default: `persist = false`.
- **FR-016**: Source Download Processor MUST validate that the GitHub URL matches the repository field in metadata.json (if present).
- **FR-017**: Source Download Processor MUST proceed without validation if no repository URL exists in metadata.json.
- **FR-018**: Stats Processor MUST generate basic statistics including file count. Default: `persist = true`.
- **FR-019**: Stats Processor MUST output statistics in a structured format (JSON).

#### Output (Blooms)

- **FR-020**: All processor inputs and outputs MUST reside within the Nix store during execution.
- **FR-021**: Processors MUST support a `persist` flag (default: false) that controls whether outputs are copied out of the store.
- **FR-022**: When a processor with `persist = true` completes successfully, its output MUST be copied to a subdirectory alongside seed.nix, named after the processor (e.g., `package-download/`, `source-download/`, `stats/`).
- **FR-023**: Bloom output structure MUST be consistent and predictable across all packages.
- **FR-024**: Partial outputs MUST NOT be persisted if any processor fails.

### Key Entities

- **Seed**: A Nix file specifying package metadata (name, version, GitHub URL) and optional processor configuration. Acts as the entry point for germination.
- **Processor**: A Nix derivation that performs a specific transformation or extraction. Has defined inputs (upstream processor outputs, seed config), outputs, and a `persist` flag controlling whether outputs are copied alongside seed.nix.
- **Bloom**: The collective output artifacts from germinating a seed. Includes downloaded package contents, source code, metadata, and generated statistics.
- **Language Helper**: A Nix function (e.g., `mkRustPackage`) that wires up the processor dependency tree for a specific language.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can germinate a Rust package seed in under 5 minutes for typical packages (excluding network download time).
- **SC-002**: Users can germinate a Python package seed using the same command pattern as Rust packages.
- **SC-003**: 100% of processor failures result in complete build failure with an error message identifying the failed processor.
- **SC-004**: Zero boilerplate required beyond specifying package name, version, and GitHub URL in seed.nix.
- **SC-005**: All generated bloom files are present and contain valid, parseable content after successful germination.
- **SC-006**: Independent processors execute in parallel, reducing total build time compared to sequential execution.

## Clarifications

### Session 2025-11-30

- Q: How should bloom outputs be stored and accessed? → A: All processor I/O happens within the Nix store. Processors with `persist = true` have their outputs copied to the seed.nix directory in a folder named after the processor.
- Q: Which MVP processors should have `persist = true` by default? → A: Only the stats processor. Package and source data remain in Nix store; users can enable persistence per-processor if needed.

## Assumptions

- Users have Nix installed and configured with flakes enabled.
- Network access to crates.io, PyPI, and GitHub is available during builds.
- The GitHub repository URL provided in seed.nix is the authoritative source for the package.
- File count is a sufficient "proof of concept" statistic for the MVP stats processor.
- Output file structure will be refined in future iterations based on LLM context window requirements.
- Authentication for private repositories or rate-limited APIs is out of scope for MVP.

## Out of Scope

- TypeScript and Ruby language support (mentioned in full vision but not MVP).
- Language-specific processors like `cargo doc` or TypeDoc (MVP focuses on package download, source download, and basic stats).
- LLM-based processors (noted as non-deterministic in vision but not part of MVP processor chain).
- Nursery repository structure management (users create seed.nix files manually for MVP).
- Documentation generation, type extraction, or other advanced processors.
- Authentication mechanisms for private packages or repositories.
