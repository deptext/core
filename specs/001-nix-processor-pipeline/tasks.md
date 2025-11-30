# Tasks: DepText MVP - Nix Processor Pipeline

**Input**: Design documents from `/specs/001-nix-processor-pipeline/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Integration tests included via shell scripts for end-to-end validation. No unit tests specified in requirements.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions (Nix Flake Structure)

Based on plan.md:
- **Root**: `flake.nix`, `flake.lock`
- **Library**: `lib/` (processors, languages, utils)
- **Examples**: `examples/` (seed files for testing)
- **Tests**: `tests/` (integration shell scripts)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and Nix flake structure

- [x] T001 Create flake.nix with nixpkgs and flake-utils inputs at flake.nix
- [x] T002 Create lib/default.nix exporting all library functions
- [x] T003 [P] Create lib/utils/validate.nix with URL normalization helpers
- [x] T004 [P] Create empty directory structure for lib/processors/, lib/languages/, examples/, tests/

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core processor infrastructure that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T005 Create lib/processors/source-download.nix with fetchFromGitHub wrapper and URL validation against metadata.json
- [x] T006 Create lib/processors/stats.nix that counts files in source directory and outputs stats.json
- [x] T007 Create lib/utils/persist.nix with logic to copy processor outputs when persist=true

**Checkpoint**: Foundational processors ready - language-specific work can begin

---

## Phase 3: User Story 1 - Germinate a Rust Package Seed (Priority: P1) 🎯 MVP

**Goal**: Enable end-to-end germination of Rust packages from crates.io with full processor chain

**Independent Test**: Create seed.nix for serde 1.0.228, run `nix build -f examples/rust/serde/seed.nix`, verify stats/stats.json is created alongside seed.nix

### Implementation for User Story 1

- [x] T008 [US1] Create lib/processors/package-download/rust.nix that fetches from crates.io and outputs package/ + metadata.json
- [x] T009 [US1] Create lib/languages/rust.nix with mkRustPackage helper that wires package-download → source-download → stats
- [x] T010 [US1] Update lib/default.nix to export mkRustPackage function
- [x] T011 [US1] Update flake.nix to expose lib.mkRustPackage via outputs.lib
- [x] T012 [US1] Create examples/rust/serde/seed.nix with serde 1.0.228 package metadata and hashes
- [x] T013 [US1] Create tests/integration/test-rust-seed.sh that builds serde seed and validates stats.json output

**Checkpoint**: User Story 1 complete - Rust packages can be germinated end-to-end

---

## Phase 4: User Story 2 - Germinate a Python Package Seed (Priority: P2)

**Goal**: Enable end-to-end germination of Python packages from PyPI with full processor chain

**Independent Test**: Create seed.nix for requests 2.31.0, run `nix build -f examples/python/requests/seed.nix`, verify stats/stats.json is created

### Implementation for User Story 2

- [x] T014 [US2] Create lib/processors/package-download/python.nix that fetches from PyPI and outputs package/ + metadata.json
- [x] T015 [US2] Create lib/languages/python.nix with mkPythonPackage helper that wires package-download → source-download → stats
- [x] T016 [US2] Update lib/default.nix to export mkPythonPackage function
- [x] T017 [US2] Update flake.nix to expose lib.mkPythonPackage via outputs.lib
- [x] T018 [US2] Create examples/python/requests/seed.nix with requests 2.31.0 package metadata and hashes
- [x] T019 [US2] Create tests/integration/test-python-seed.sh that builds requests seed and validates stats.json output

**Checkpoint**: User Story 2 complete - Python packages can be germinated end-to-end

---

## Phase 5: User Story 3 - Configure Processor Behavior Per-Seed (Priority: P3)

**Goal**: Allow optional configuration in seed.nix to toggle/configure processors

**Independent Test**: Create two seed.nix files for same package with different processor configs, verify outputs differ (e.g., one with persist=true for package-download, one without)

### Implementation for User Story 3

- [x] T020 [US3] Update lib/languages/rust.nix to accept optional processors config with enabled/persist flags
- [x] T021 [US3] Update lib/languages/python.nix to accept optional processors config with enabled/persist flags
- [x] T022 [US3] Update lib/processors/package-download/rust.nix to respect enabled and persist flags
- [x] T023 [US3] Update lib/processors/package-download/python.nix to respect enabled and persist flags
- [x] T024 [US3] Update lib/processors/source-download.nix to respect enabled and persist flags
- [x] T025 [US3] Update lib/processors/stats.nix to respect enabled flag (persist defaults to true)
- [x] T026 [US3] Create examples/rust/serde-custom/seed.nix with custom processor configuration (package-download persist=true)
- [x] T027 [US3] Update tests/integration/test-rust-seed.sh to also test custom configuration seed

**Checkpoint**: User Story 3 complete - Processors can be configured per-seed

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and documentation

- [x] T028 [P] Add extensive beginner-friendly comments to flake.nix explaining flake concepts
- [x] T029 [P] Add extensive beginner-friendly comments to lib/default.nix explaining library exports
- [x] T030 [P] Add extensive beginner-friendly comments to all processor files explaining derivation concepts
- [x] T031 [P] Add extensive beginner-friendly comments to language helper files explaining the pipeline
- [x] T032 Run full integration test suite: tests/integration/test-rust-seed.sh and tests/integration/test-python-seed.sh
- [x] T033 Validate quickstart.md examples work end-to-end with actual nix build commands

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on T001, T002 from Setup - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational (T005, T006, T007)
- **User Story 2 (Phase 4)**: Depends on Foundational (T005, T006, T007) - can run parallel to US1
- **User Story 3 (Phase 5)**: Depends on US1 and US2 complete (modifies their files)
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational - No dependencies on US1 (parallel-safe)
- **User Story 3 (P3)**: Depends on US1 and US2 - Modifies language helper files

### Within Each User Story

- Processor files before language helpers
- Language helpers before flake.nix updates
- Examples after language helpers are complete
- Integration tests after examples exist

### Parallel Opportunities

- T003, T004 can run in parallel (Setup phase)
- T005, T006, T007 can run in parallel (Foundational - different files)
- US1 and US2 can be implemented in parallel after Foundational completes
- T028, T029, T030, T031 can run in parallel (Polish - different files)

---

## Parallel Example: User Story 1 + User Story 2

```bash
# After Foundational phase completes, launch US1 and US2 in parallel:

# Developer A (US1 - Rust):
Task: "Create lib/processors/package-download/rust.nix"
Task: "Create lib/languages/rust.nix"
Task: "Create examples/rust/serde/seed.nix"
Task: "Create tests/integration/test-rust-seed.sh"

# Developer B (US2 - Python) - can run simultaneously:
Task: "Create lib/processors/package-download/python.nix"
Task: "Create lib/languages/python.nix"
Task: "Create examples/python/requests/seed.nix"
Task: "Create tests/integration/test-python-seed.sh"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (4 tasks)
2. Complete Phase 2: Foundational (3 tasks)
3. Complete Phase 3: User Story 1 (6 tasks)
4. **STOP and VALIDATE**: Run `nix build -f examples/rust/serde/seed.nix`
5. Verify stats/stats.json appears alongside seed.nix
6. MVP is functional - Rust packages work!

### Incremental Delivery

1. Setup + Foundational → Core infrastructure ready
2. Add User Story 1 → Test with serde → Rust works! (MVP)
3. Add User Story 2 → Test with requests → Python works!
4. Add User Story 3 → Test with custom config → Configurability works!
5. Polish → Comments + validation → Production ready!

### Suggested MVP Scope

For fastest time-to-value, implement only:
- Phase 1: Setup (T001-T004)
- Phase 2: Foundational (T005-T007)
- Phase 3: User Story 1 (T008-T013)

This delivers a working Rust package germination system in 13 tasks.

---

## Notes

- All Nix code MUST include extensive beginner-friendly comments per constitution
- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Use `nix-prefetch-url` and `nix-prefetch-github` to get hash values for examples
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
