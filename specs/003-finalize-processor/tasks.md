# Tasks: Finalize Processor

**Input**: Design documents from `/specs/003-finalize-processor/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Not explicitly requested. Integration tests included for validation.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Nix flake project**: `lib/` for Nix library code, `tests/` for shell scripts
- Based on existing 001-nix-processor-pipeline structure

---

## Phase 1: Setup

**Purpose**: Verify project structure and prepare for changes

- [X] T001 Verify existing project structure matches plan.md expectations in lib/
- [X] T002 [P] Create lib/utils/timing.nix placeholder file
- [X] T003 [P] Create lib/utils/format.nix placeholder file
- [X] T004 [P] Create lib/processors/finalize.nix placeholder file

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### mkProcessor Factory (enables timing for all processors)

- [X] T005 Implement mkProcessor factory function in lib/processors/default.nix with timing injection (auto-inject timing start/end, write timing.json to $out)
- [X] T006 [P] Update lib/processors/package-download/rust.nix to use mkProcessor and output to publish/ subfolder
- [X] T007 [P] Update lib/processors/package-download/python.nix to use mkProcessor and output to publish/ subfolder
- [X] T008 [P] Update lib/processors/source-download.nix to use mkProcessor and output to publish/ subfolder
- [X] T009 [P] Update lib/processors/stats.nix to use mkProcessor and output to publish/ subfolder

### Persistence Infrastructure

- [X] T010 Update lib/utils/persist.nix to copy only publish/ contents and handle finalize special case (no subfolder)

**Checkpoint**: Foundation ready - mkProcessor factory works, all existing processors use publish/ pattern

---

## Phase 3: User Story 1 - Generate Bloom Summary Files (Priority: P1) 🎯 MVP

**Goal**: After all processors complete, finalize generates README.md and bloom.json with basic package info

**Independent Test**: Build a Rust seed, verify README.md contains package title and language, verify bloom.json contains pname, version, language, and processors object

### Implementation for User Story 1

- [X] T011 [US1] Implement basic finalize processor structure in lib/processors/finalize.nix (receives upstream processor outputs as deps)
- [X] T012 [US1] Implement bloom.json generation with root fields (pname, version, language, hash, github, lastBuild) in lib/processors/finalize.nix
- [X] T013 [US1] Implement processors object in bloom.json with active and published fields for each processor in lib/processors/finalize.nix
- [X] T014 [US1] Implement basic README.md header generation (title, language, last build) in lib/processors/finalize.nix
- [X] T015 [US1] Implement Processors table in README.md with Active column (✓/✗) in lib/processors/finalize.nix
- [X] T016 [US1] Update lib/languages/rust.nix to add finalize to processor chain (depends on all other processors)
- [X] T017 [US1] Update lib/languages/python.nix to add finalize to processor chain (depends on all other processors)
- [X] T018 [US1] Update tests/integration/test-rust-seed.sh to verify README.md and bloom.json are generated

**Checkpoint**: User Story 1 complete - builds produce README.md and bloom.json with basic info

---

## Phase 4: User Story 2 - Access Build Timing Information (Priority: P2)

**Goal**: README.md and bloom.json include per-processor and total build duration

**Independent Test**: Build a seed, verify README.md displays human-readable durations (e.g., "4m 11.76s"), verify bloom.json contains buildDuration at root and for each active processor

### Implementation for User Story 2

- [X] T019 [P] [US2] Implement format_duration shell function in lib/utils/format.nix (ms → "Xm Y.ZZs")
- [X] T020 [P] [US2] Implement format_size shell function in lib/utils/format.nix (bytes → "X.XX MB/KB/B")
- [X] T021 [US2] Update lib/processors/finalize.nix to read timing.json from each upstream processor
- [X] T022 [US2] Update lib/processors/finalize.nix to calculate total buildDuration (sum of all processor durations)
- [X] T023 [US2] Update lib/processors/finalize.nix to add buildDuration to bloom.json root and per-processor entries
- [X] T024 [US2] Update lib/processors/finalize.nix to add Duration column to README.md table with human-readable format
- [X] T025 [US2] Update lib/processors/finalize.nix to add Build Duration to README.md header
- [X] T026 [US2] Update tests/integration/test-rust-seed.sh to verify timing data in README.md and bloom.json

**Checkpoint**: User Story 2 complete - timing information displayed in all outputs

---

## Phase 5: User Story 3 - Link to Processor Outputs (Priority: P3)

**Goal**: README.md includes clickable links to published processor output directories

**Independent Test**: Build a seed with stats persist=true, verify README.md contains `[view output](./stats/)` link, verify bloom.json contains fileCount, fileSize, hash for stats processor

### Implementation for User Story 3

- [X] T027 [US3] Implement directory scanning functions in lib/processors/finalize.nix (count_files, calculate_size, calculate_hash for publish/ folders)
- [X] T028 [US3] Update lib/processors/finalize.nix to add fileCount, fileSize, hash to bloom.json for published processors
- [X] T029 [US3] Update lib/processors/finalize.nix to add Published column with `[view output](./{name}/)` links for published processors
- [X] T030 [US3] Update lib/processors/finalize.nix to add Files and Size columns to README.md table
- [X] T031 [US3] Update tests/integration/test-rust-seed.sh to verify output links and file stats
- [X] T032 [US3] Update tests/integration/test-python-seed.sh to verify full finalize functionality

**Checkpoint**: All user stories complete - finalize processor fully functional

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Edge cases, documentation, and cleanup

- [X] T033 [P] Handle edge case: all processors disabled (still generate README.md and bloom.json showing inactive)
- [X] T034 [P] Handle edge case: processor outputs zero files (show "0" for Files, "0 B" for Size)
- [X] T035 [P] Handle edge case: missing timing.json (show "-" for Duration, omit buildDuration in bloom.json)
- [X] T036 Add beginner-friendly comments to lib/processors/finalize.nix per constitution requirements
- [X] T037 Add beginner-friendly comments to lib/processors/default.nix (mkProcessor factory) per constitution requirements
- [X] T038 [P] Add beginner-friendly comments to lib/utils/format.nix per constitution requirements
- [X] T039 Validate quickstart.md examples work with actual build outputs

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-5)**: All depend on Foundational phase completion
  - User stories can proceed in priority order (P1 → P2 → P3)
  - US2 builds on US1 (adds timing to existing structure)
  - US3 builds on US1 (adds file stats to existing structure)
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - Core functionality
- **User Story 2 (P2)**: Can start after US1 - Adds timing features to existing outputs
- **User Story 3 (P3)**: Can start after US1 - Adds file stats and links to existing outputs (can parallel with US2)

### Within Each User Story

- Models/utilities before main logic
- Core implementation before integration
- Integration into language helpers last
- Tests updated at end of each story

### Parallel Opportunities

**Phase 1 (Setup)**:
- T002, T003, T004 can run in parallel (creating placeholder files)

**Phase 2 (Foundational)**:
- T006, T007, T008, T009 can run in parallel (updating existing processors)

**Phase 4 (US2)**:
- T019, T020 can run in parallel (format utilities)

**Phase 5 (US3)** and **Phase 4 (US2)** can run in parallel after US1 is complete

**Phase 6 (Polish)**:
- T033, T034, T035, T038 can run in parallel

---

## Parallel Example: Foundational Phase

```bash
# After T005 (mkProcessor factory) is complete, launch all processor updates in parallel:
Task: "Update lib/processors/package-download/rust.nix to use mkProcessor"
Task: "Update lib/processors/package-download/python.nix to use mkProcessor"
Task: "Update lib/processors/source-download.nix to use mkProcessor"
Task: "Update lib/processors/stats.nix to use mkProcessor"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Build a seed, verify README.md and bloom.json exist with basic info
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready (mkProcessor works, publish/ pattern in place)
2. Add User Story 1 → Test: README.md + bloom.json with basic info → **MVP!**
3. Add User Story 2 → Test: Timing data displayed → **Enhancement**
4. Add User Story 3 → Test: Links and file stats → **Full feature**
5. Complete Polish → Edge cases handled, documentation complete

### Recommended Approach for Solo Developer

1. Complete T001-T010 (Setup + Foundational) - ~2-3 hours
2. Complete T011-T018 (US1 MVP) - ~2-3 hours
3. Validate MVP works end-to-end
4. Complete T019-T026 (US2 Timing) - ~1-2 hours
5. Complete T027-T032 (US3 Links) - ~1-2 hours
6. Complete T033-T039 (Polish) - ~1 hour

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- US2 and US3 both build on US1's foundation (README.md and bloom.json structure)
- All Nix code must include extensive beginner-friendly comments per constitution
- Test validation focuses on integration tests (Nix build produces expected outputs)
- Avoid modifying multiple processors in same task (keep changes atomic)
