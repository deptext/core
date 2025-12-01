# Tasks: Rustdoc Processors

**Input**: Design documents from `/specs/004-rustdoc-processors/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md

**Tests**: Integration tests will be added to the existing test-rust-seed.sh pattern.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Based on plan.md structure:
- **Packages**: `lib/packages/` (custom-packaged external tools not in nixpkgs)
- **Universal processors**: `lib/processors/` (stats, source-download, finalize)
- **Rust processors**: `lib/processors/rust/`
- **Python processors**: `lib/processors/python/`
- **Language helpers**: `lib/languages/`
- **Tests**: `tests/integration/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Research Nix packaging of external dependencies

- [X] T001 Research and document rustdoc-md crate packaging approach (determine exact version, GitHub rev, hashes needed)
- [X] T002 [P] Research fenix/rust-overlay for nightly Rust in Nix derivations (determine if flake input needed)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**Blocking**: No user story work can begin until this phase is complete

### Processor Directory Refactor

- [X] T003 Create lib/processors/rust/ directory
- [X] T004 Create lib/processors/python/ directory
- [X] T005 [P] Move lib/processors/package-download/rust.nix to lib/processors/rust/package-download.nix
- [X] T006 [P] Move lib/processors/package-download/python.nix to lib/processors/python/package-download.nix
- [X] T007 Delete lib/processors/package-download/ directory (now empty)
- [X] T008 Update lib/languages/rust.nix to import from new path lib/processors/rust/package-download.nix
- [X] T009 Update lib/languages/python.nix to import from new path lib/processors/python/package-download.nix
- [X] T010 Run integration tests to verify refactor didn't break anything

### External Dependencies

- [X] T011 Create rustdoc-md Nix package derivation in lib/packages/rustdoc-md.nix (builds rustdoc-md tool from source using rustPlatform.buildRustPackage)
- [X] T012 Add nightly Rust toolchain to flake.nix inputs (fenix or rust-overlay)

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Generate Markdown Documentation (Priority: P1) MVP

**Goal**: Automatically generate human-readable markdown documentation from Rust source code

**Independent Test**: Run `bloom` on serde seed.nix and verify `rustdoc-md/` directory with markdown files appears in output

### Implementation for User Story 1

- [X] T013 [P] [US1] Create rustdoc-json processor in lib/processors/rust/rustdoc-json.nix with mkProcessor factory pattern
- [X] T014 [P] [US1] Create rustdoc-md processor in lib/processors/rust/rustdoc-md.nix with mkProcessor factory pattern (imports tool from lib/packages/rustdoc-md.nix, depends on rustdoc-json output)
- [X] T015 [US1] Update rust.nix to import rustdoc-json processor module in lib/languages/rust.nix
- [X] T016 [US1] Update rust.nix to import rustdoc-md processor module in lib/languages/rust.nix
- [X] T017 [US1] Add rustdoc-json to processorConfig defaults in lib/languages/rust.nix (enabled=true, persist=false)
- [X] T018 [US1] Add rustdoc-md to processorConfig defaults in lib/languages/rust.nix (enabled=true, persist=true)
- [X] T019 [US1] Create rustdocJsonDrv derivation in rust.nix pipeline (takes sourceDownload as input)
- [X] T020 [US1] Create rustdocMdDrv derivation in rust.nix pipeline (takes rustdocJsonDrv as input)
- [X] T021 [US1] Add rustdoc-json and rustdoc-md to upstreamProcessors in rust.nix for finalize
- [X] T022 [US1] Update finalize.nix to iterate over rustdoc-json and rustdoc-md processors in lib/processors/finalize.nix
- [X] T023 [US1] Add rustdoc-json and rustdoc-md to allProcessors in rust.nix for persist wrapper
- [X] T024 [US1] Add integration test for rustdoc-md output validation in tests/integration/test-rust-seed.sh

**Checkpoint**: User Story 1 complete - `bloom` produces rustdoc-md/ output with markdown documentation

---

## Phase 4: User Story 2 - Access Intermediate JSON Documentation (Priority: P2)

**Goal**: Allow users to optionally persist the intermediate JSON documentation output

**Independent Test**: Set `processors.rustdoc-json.persist = true` in seed.nix and verify `rustdoc-json/` directory appears in output

### Implementation for User Story 2

- [X] T025 [US2] Verify rustdoc-json persist configuration is passed correctly from seed.nix to processor in lib/languages/rust.nix
- [X] T026 [US2] Add integration test for rustdoc-json persistence option in tests/integration/test-rust-seed.sh

**Checkpoint**: User Story 2 complete - JSON output can be optionally persisted via configuration

---

## Phase 5: User Story 3 - Disable Documentation Processors (Priority: P3)

**Goal**: Allow users to disable documentation processors for faster builds

**Independent Test**: Set `processors.rustdoc-json.enabled = false` and verify no documentation is generated

### Implementation for User Story 3

- [X] T027 [US3] Add disabled state handling to rustdoc-json processor in lib/processors/rust/rustdoc-json.nix (return skip derivation when enabled=false)
- [X] T028 [US3] Add disabled state handling to rustdoc-md processor in lib/processors/rust/rustdoc-md.nix (auto-disable when rustdoc-json.enabled=false)
- [X] T029 [US3] Add dependency chain logic in rust.nix to disable rustdoc-md when rustdoc-json is disabled in lib/languages/rust.nix
- [X] T030 [US3] Add integration test for disabled processor configuration in tests/integration/test-rust-seed.sh

**Checkpoint**: User Story 3 complete - processors can be disabled via configuration

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [X] T031 [P] Add beginner-friendly comments to lib/processors/rust/rustdoc-json.nix per constitution requirements
- [X] T032 [P] Add beginner-friendly comments to lib/processors/rust/rustdoc-md.nix per constitution requirements
- [X] T033 [P] Add beginner-friendly comments to rust.nix updates per constitution requirements
- [X] T034 Run full integration test suite and verify all tests pass
- [X] T035 Run quickstart.md validation scenarios manually (validated: processors appear in output, disabled by default without rustToolchain)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-5)**: All depend on Foundational phase completion
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after US1 (uses same config infrastructure)
- **User Story 3 (P3)**: Can start after US1 (uses same processors, adds disable logic)

### Within Each User Story

- Processor files before rust.nix integration
- rust.nix integration before finalize.nix updates
- Implementation before integration tests

### Parallel Opportunities

- T001 and T002 can run in parallel (independent research)
- T005 and T006 can run in parallel (move rust and python package-download files)
- T013 and T014 can run in parallel (different processor files)
- T031, T032, and T033 can run in parallel (different files, comments only)

---

## Parallel Example: User Story 1 Processors

```bash
# Launch both processor implementations together:
Task: "Create rustdoc-json processor in lib/processors/rust/rustdoc-json.nix"
Task: "Create rustdoc-md processor in lib/processors/rust/rustdoc-md.nix"

# Then sequentially integrate into rust.nix
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (research)
2. Complete Phase 2: Foundational (Nix packaging)
3. Complete Phase 3: User Story 1 (core processors)
4. **STOP and VALIDATE**: Test `bloom examples/rust/serde/seed.nix` produces rustdoc-md/ output
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test markdown generation → **MVP Complete!**
3. Add User Story 2 → Test JSON persistence option
4. Add User Story 3 → Test disable configuration
5. Polish → Add comments, final validation

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story is independently testable via integration tests
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- The rustdoc-md tool must be packaged from source in `lib/packages/rustdoc-md.nix` (not in nixpkgs)
- The processor in `lib/processors/rust/rustdoc-md.nix` imports the tool from `lib/packages/`
- Nightly Rust toolchain required for rustdoc JSON output
- Phase 2 includes a refactor to reorganize processors by language (rust/, python/) for better scalability
