# Feature Specification: Finalize Processor

**Feature Branch**: `003-finalize-processor`
**Created**: 2025-12-01
**Status**: Draft
**Input**: User description: "add a shared `finalize` processor which outputs a README.md and a bloom.json file. See ./finalized.md for examples of the output for those files."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Generate Bloom Summary Files After Successful Build (Priority: P1)

A developer germinating a seed wants human-readable documentation and machine-readable metadata summarizing the build results. After all other processors complete successfully, the finalize processor automatically generates a README.md (for humans browsing the repository) and bloom.json (for tooling and LLM context).

**Why this priority**: This is the core purpose of the finalize processor. Without these summary files, users cannot quickly understand what was processed or programmatically access build metadata.

**Independent Test**: Can be fully tested by germinating any existing seed (Rust or Python), verifying README.md is created with correct package info and processor table, and verifying bloom.json contains accurate structured metadata.

**Acceptance Scenarios**:

1. **Given** a seed.nix that builds successfully with all processors enabled, **When** the build completes, **Then** a README.md and bloom.json are generated alongside the seed containing accurate summaries of all processor results.

2. **Given** a seed.nix where some processors have `persist = false`, **When** the build completes, **Then** README.md shows those processors with "-" for file-related columns (Files, Size) and bloom.json shows `published: false` for those processors.

3. **Given** a seed.nix where a processor is disabled, **When** the build completes, **Then** README.md shows that processor with "✗" for Active and bloom.json shows `active: false` for that processor.

---

### User Story 2 - Access Build Timing Information (Priority: P2)

A developer wants to understand build performance and identify slow processors. The finalize processor captures and displays timing information for each processor and the total build duration.

**Why this priority**: Build timing is valuable for optimization and debugging but not essential for basic functionality.

**Independent Test**: Can be tested by running a build and verifying that README.md displays human-readable durations (e.g., "4m 11.76s") and bloom.json contains millisecond-precision timing data.

**Acceptance Scenarios**:

1. **Given** a completed build, **When** README.md is generated, **Then** it displays total build duration and per-processor durations in human-readable format (e.g., "5m 42.15s" for 342150ms).

2. **Given** a completed build, **When** bloom.json is generated, **Then** it includes `buildDuration` at the root level and `buildDuration` for each active processor, all in milliseconds.

---

### User Story 3 - Link to Processor Outputs (Priority: P3)

A developer browsing the repository wants quick access to processor outputs. The README.md provides clickable links to persisted output directories.

**Why this priority**: Convenient navigation but users can still manually navigate to output directories.

**Independent Test**: Can be tested by verifying that README.md contains working relative links to output directories for processors with `published: true`.

**Acceptance Scenarios**:

1. **Given** a processor with `persist = true` that generated output, **When** README.md is generated, **Then** it includes a relative link to that processor's output directory (e.g., `[view output](./stats/)`).

2. **Given** a processor with `persist = false`, **When** README.md is generated, **Then** no output link is shown for that processor, just a checkmark or dash.

---

### Edge Cases

- What happens when all processors are disabled?
  - Finalize still runs and generates README.md and bloom.json showing all processors as inactive.

- What happens when timing data is not available for a processor?
  - Duration shows as "-" in README.md and `buildDuration` is omitted in bloom.json for that processor.

- What happens when a processor outputs zero files?
  - Show "0" for Files column and "0 B" for Size column (not omitted).

- What happens when the build partially fails before finalize runs?
  - Finalize does not run; no README.md or bloom.json is generated (fail-fast behavior from FR-011 of 001-nix-processor-pipeline).

## Requirements *(mandatory)*

### Functional Requirements

#### Processor Behavior

- **FR-001**: Finalize processor MUST be a shared processor (language-agnostic) that runs after all other processors complete.
- **FR-002**: Finalize processor MUST depend on all other processors in the dependency tree (runs last).
- **FR-002a**: The list of processors for each language MUST be hardcoded in that language's Nix file (e.g., rust.nix defines Rust processors).
- **FR-002b**: Each processor's `active` status MUST be determined by merging default configuration with any overrides from seed.nix.
- **FR-003**: Finalize processor MUST have `persist = true` by default (outputs always copied alongside seed.nix).
- **FR-003a**: All processors MUST place user-facing/publishable content in a `publish/` subfolder within their Nix store output directory.
- **FR-003b**: Internal build metadata (e.g., timing.json) MUST be placed at the root of the processor's output directory, NOT in `publish/`.
- **FR-003c**: When `persist = true`, only the contents of `publish/` MUST be copied alongside seed.nix.
- **FR-003d**: For standard processors, `publish/` contents MUST be copied into a folder named after the processor (e.g., `publish/` → `stats/`).
- **FR-003e**: For the finalize processor (special case), `publish/` contents MUST be copied directly alongside seed.nix with no subfolder.
- **FR-004**: Finalize processor MUST generate two output files in its `publish/` folder: `README.md` and `bloom.json`.

#### README.md Generation

- **FR-005**: README.md MUST include package name and version as the document title (e.g., "# serde v1.0.228").
- **FR-006**: README.md MUST include package language (e.g., "Rust", "Python").
- **FR-007**: README.md MUST include last build timestamp in ISO 8601 format.
- **FR-008**: README.md MUST include total build duration in human-readable format.
- **FR-009**: README.md MUST include a "Processors" section with a table showing: Processor name, Active status, Published status/output link, Duration, Files count, Size.
- **FR-010**: README.md MUST display durations in human-readable format (e.g., "4m 11.76s", "45.23s", "12.05s").
- **FR-011**: README.md MUST use "✓" for active/published true, "-" for not applicable, and "✗" for disabled.
- **FR-012**: README.md MUST link to output directories using relative paths (e.g., `./stats/`) for processors with `published = true`.

#### bloom.json Generation

- **FR-013**: bloom.json MUST include `pname` (package name) and `version` fields at root level.
- **FR-014**: bloom.json MUST include `language` field (e.g., "rust", "python").
- **FR-015**: bloom.json MUST include `hash` field with the package's content hash (from package-download metadata).
- **FR-016**: bloom.json MUST include `github` object with `owner`, `repo`, `rev`, and `hash` fields.
- **FR-017**: bloom.json MUST include `lastBuild` timestamp in ISO 8601 format.
- **FR-018**: bloom.json MUST include `buildDuration` in milliseconds at root level.
- **FR-019**: bloom.json MUST include `processors` object with an entry for each processor.
- **FR-020**: Each processor entry MUST include `active` (boolean) and `published` (boolean) fields.
- **FR-021**: Each processor entry MUST include `buildDuration` (milliseconds) if the processor was active.
- **FR-022**: Each processor entry MUST include `fileCount`, `fileSize` (bytes), and `hash` if `published = true`.
- **FR-023**: Fields that are not applicable MUST be omitted (not set to null or empty).

#### Data Sources

- **FR-024**: Finalize processor MUST read package metadata from the package-download processor output (metadata.json).
- **FR-025**: Finalize processor MUST read statistics from the stats processor output (stats.json).
- **FR-026**: Finalize processor MUST calculate file counts and sizes by scanning each processor's `publish/` subfolder.
- **FR-027**: Finalize processor MUST read timing data from each upstream processor's `timing.json` file (auto-generated by the `mkProcessor` factory function).

### Key Entities

- **Finalize Processor**: A shared (language-agnostic) Nix derivation that runs after all other processors and generates summary files.
- **README.md**: Human-readable markdown document summarizing the package, build, and processor results.
- **bloom.json**: Machine-readable JSON file containing structured build metadata for tooling and LLM context.
- **publish/ subfolder**: Directory within each processor's Nix store output containing user-facing content to be persisted. Internal metadata (timing.json) lives outside this folder.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of successful builds produce valid README.md and bloom.json files.
- **SC-002**: All mandatory fields in bloom.json are present and correctly typed per the schema.
- **SC-003**: README.md renders correctly as markdown with all links functional.
- **SC-004**: Build timing accuracy within 1 second of actual processor duration.
- **SC-005**: File counts and sizes in bloom.json match actual persisted output contents.

## Clarifications

### Session 2025-12-01

- Q: How should the finalize processor discover which processors exist? → A: Processor list is hardcoded per language file (e.g., rust.nix, python.nix); active status determined by default config plus seed.nix overrides.
- Q: How should build timing be captured for each processor? → A: Use a `mkProcessor` factory function that auto-injects timing logic; each processor's output includes timing.json with startTime, endTime, and buildDuration (ms). Finalize reads timing.json from each upstream processor's output directory.
- Q: How should processor outputs be organized for persistence? → A: Each processor's Nix store output contains a `publish/` subfolder for user-facing content. Only `publish/` contents are persisted. For standard processors, `publish/` is renamed to the processor name (e.g., `stats/`). For finalize (special case), `publish/` contents are placed directly alongside seed.nix (no subfolder).

## Assumptions

- All processors are created using the `mkProcessor` factory function, which auto-injects timing capture.
- All upstream processors (package-download, source-download, stats) output structured data that finalize can parse.
- The persisted output directory structure follows the pattern `./{processor-name}/` for standard processors, with finalize outputs at root level.
- ISO 8601 timestamps use UTC timezone (Z suffix).
- Human-readable durations follow the format used in the example: "Xm Y.ZZs" for minutes+seconds, "Y.ZZs" for seconds only.

## Out of Scope

- Generating additional documentation beyond README.md (e.g., CHANGELOG, LICENSE summaries).
- Validating upstream processor output schemas (assumed valid if processors succeeded).
- Internationalization of README.md content.
- Customizing README.md template per-seed (uses fixed format).
