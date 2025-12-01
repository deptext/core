# Feature Specification: Rustdoc Processors for Rust Documentation

**Feature Branch**: `004-rustdoc-processors`
**Created**: 2025-12-01
**Status**: Draft
**Input**: User description: "create a `rustdoc-json` processor for rust which generates the crates documentation as markdown and outputs the documentation without persisting it, then create a `rustdoc-md` processor which depends on the rustdoc-json processor, and uses the `cargo-doc-md` crate to convert the json docs into markdown, this processor should persist its output"

## Clarifications

### Session 2025-12-01

- Q: Where do rustdoc processors fit in the pipeline execution order? → A: rustdoc-json → rustdoc-md runs sequentially (rustdoc-md consumes rustdoc-json output), but this chain runs in parallel with stats (both independently consume source-download output).
- Q: What tool converts rustdoc JSON to markdown? → A: Research found that "cargo-doc-md" does not exist. The correct tool is **rustdoc-md** crate (https://crates.io/crates/rustdoc-md) which performs the same function.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Generate Markdown Documentation for Rust Packages (Priority: P1)

As a DepText user processing Rust packages, I want to automatically generate human-readable markdown documentation from the crate's source code so that LLMs can consume structured documentation for context windows.

**Why this priority**: This is the core functionality - without markdown documentation output, the feature provides no value. The entire pipeline (rustdoc-json + rustdoc-md) must work together to deliver documentation.

**Independent Test**: Can be fully tested by running `bloom` on a Rust seed.nix and verifying that a `rustdoc-md/` directory containing markdown files appears in the output alongside `stats/`.

**Acceptance Scenarios**:

1. **Given** a valid Rust seed.nix file (e.g., serde), **When** I run `bloom ./seed.nix`, **Then** the output contains a `rustdoc-md/` directory with markdown documentation files.

2. **Given** a Rust package with public API documentation, **When** the pipeline completes, **Then** the markdown output includes documentation for public modules, structs, functions, and traits.

3. **Given** the default processor configuration, **When** I build a Rust seed, **Then** `rustdoc-md` output is persisted while `rustdoc-json` output is not persisted.

---

### User Story 2 - Access Intermediate JSON Documentation (Priority: P2)

As a developer debugging or extending the documentation pipeline, I want the option to persist the intermediate JSON documentation output so that I can inspect the raw rustdoc JSON for troubleshooting or custom processing.

**Why this priority**: This is a secondary use case for advanced users who need to debug or extend the pipeline. The main user flow works without this.

**Independent Test**: Can be tested by configuring `processors.rustdoc-json.persist = true` in a seed.nix and verifying JSON files appear in the output.

**Acceptance Scenarios**:

1. **Given** a seed.nix with `processors.rustdoc-json.persist = true`, **When** I run bloom, **Then** the output contains a `rustdoc-json/` directory with JSON documentation files.

2. **Given** default processor configuration, **When** I run bloom, **Then** no `rustdoc-json/` directory appears in the final output (JSON is generated internally but not persisted).

---

### User Story 3 - Disable Documentation Processors (Priority: P3)

As a DepText user who only needs file statistics, I want to disable the documentation processors so that I can speed up builds when documentation is not needed.

**Why this priority**: This is an optimization for users who don't need documentation. The feature is still useful without this capability.

**Independent Test**: Can be tested by setting `processors.rustdoc-json.enabled = false` and verifying no documentation is generated.

**Acceptance Scenarios**:

1. **Given** a seed.nix with `processors.rustdoc-json.enabled = false`, **When** I run bloom, **Then** neither rustdoc-json nor rustdoc-md processors run.

2. **Given** a seed.nix with `processors.rustdoc-md.enabled = false` but `processors.rustdoc-json.enabled = true`, **When** I run bloom, **Then** rustdoc-json runs but rustdoc-md does not (and no markdown is persisted).

---

### Edge Cases

- What happens when a Rust package has no public documentation (all items are private)?
  - The processors should complete successfully and produce empty or minimal output indicating no public API.

- What happens when rustdoc fails to parse the source code (e.g., syntax errors)?
  - The rustdoc-json processor should fail with a clear error message indicating the parsing failure.

- How does the system handle very large crates with extensive documentation?
  - The processors should handle large documentation sets; build time may increase proportionally.

- What happens when rustdoc-md fails to convert certain JSON structures?
  - The rustdoc-md processor should fail with a clear error message and not produce partial output.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a `rustdoc-json` processor that generates JSON documentation from Rust source code using rustdoc's JSON output format.

- **FR-002**: System MUST provide a `rustdoc-md` processor that converts rustdoc JSON to markdown using the rustdoc-md tool.

- **FR-003**: The `rustdoc-md` processor MUST depend on the `rustdoc-json` processor (rustdoc-md cannot run without rustdoc-json output).

- **FR-004**: The `rustdoc-json` processor MUST default to `persist = false` (output not copied to final build output).

- **FR-005**: The `rustdoc-md` processor MUST default to `persist = true` (markdown output copied to final build output).

- **FR-006**: Users MUST be able to override persistence settings via seed.nix processor configuration (e.g., `processors.rustdoc-json.persist = true`).

- **FR-007**: Users MUST be able to disable either processor via seed.nix configuration (e.g., `processors.rustdoc-json.enabled = false`).

- **FR-008**: When `rustdoc-json` is disabled, `rustdoc-md` MUST also be disabled (dependency chain).

- **FR-009**: Both processors MUST integrate with the existing processor pipeline and be included in the finalize processor's summary (README.md and bloom.json).

- **FR-010**: The `rustdoc-json` processor MUST output JSON files to its `publish/` directory following the existing processor output structure.

- **FR-011**: The `rustdoc-md` processor MUST output markdown files to its `publish/` directory following the existing processor output structure.

- **FR-012**: Both processors MUST record timing information via the mkProcessor factory (timing.json).

- **FR-013**: The processors MUST only be available for Rust packages (mkRustPackage), not Python packages.

### Key Entities

- **rustdoc-json output**: JSON files generated by rustdoc representing the crate's public API documentation structure, including modules, structs, enums, functions, traits, and their doc comments.

- **rustdoc-md output**: Markdown files converted from the JSON documentation, organized for human readability and LLM consumption.

- **Processor dependency chain**: rustdoc-json → rustdoc-md (sequential; rustdoc-md requires rustdoc-json's output as input). This chain runs in parallel with stats, as both independently consume source-download output. The finalize processor runs after both chains complete.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Running bloom on the serde example seed produces markdown documentation in under 5 minutes on standard hardware.

- **SC-002**: The generated markdown documentation includes at least 80% of the public API items (modules, structs, functions, traits) that have doc comments in the source.

- **SC-003**: Users can configure processor persistence and enabled state using the same configuration pattern as existing processors (no new configuration syntax required).

- **SC-004**: The finalize processor's README.md and bloom.json correctly reflect the rustdoc-json and rustdoc-md processors' status (active, published, duration, files, size).

- **SC-005**: Disabling rustdoc-json processor reduces build time by the time that would have been spent generating documentation.

## Assumptions

- The rustdoc-md crate/tool is available and can be packaged or called from within a Nix derivation.
- Rustdoc's JSON output format is stable enough for use (using nightly Rust's `-Z unstable-options --output-format json` flag or equivalent).
- The source code downloaded by the source-download processor contains valid Rust code that rustdoc can process.
- The rustdoc-json processor will use the source from the source-download processor's output (not the package-download output).
