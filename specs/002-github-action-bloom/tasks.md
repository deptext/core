# Tasks: GitHub Action for Automated Seed Blooming

**Input**: Design documents from `/specs/002-github-action-bloom/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md
**Status**: Implemented

> **Note**: This task list was written during initial design. Implementation now uses `nix build --json` directly instead of `./bin/bloom`. The CLI was removed.

**Tests**: Not explicitly requested - manual PR-based testing per plan.md

**Organization**: Tasks grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Per plan.md structure:
- `action.yml` - Reusable composite action definition (repo root)
- `action/bloom.sh` - Main action script

---

## Phase 1: Setup

**Purpose**: Create directory structure and action skeleton

- [x] T001 Create action/ directory at repository root
- [x] T002 Create action.yml skeleton with name, description, and runs.using: composite at /action.yml

---

## Phase 2: Foundational (Action Infrastructure)

**Purpose**: Core action steps that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until these steps exist

- [x] T003 Add actions/checkout@v4 step to action.yml with ref: ${{ github.head_ref }}
- [x] T004 Add cachix/install-nix-action@v31 step to action.yml with flakes enabled
- [x] T005 Add shell step to action.yml that calls action/bloom.sh
- [x] T006 Create action/bloom.sh skeleton with shebang, set -euo pipefail, and function stubs

**Checkpoint**: Action infrastructure ready - bloom.sh can be implemented

---

## Phase 3: User Story 2 - PR Validation (Priority: P1)

**Goal**: Validate exactly one seed.nix file exists before processing

**Independent Test**: Create PRs with 0, 1, and 2+ seed.nix files; verify correct behavior for each

**Why US2 before US1**: Validation must pass before bloom processing can occur (per state machine in data-model.md)

### Implementation for User Story 2

- [x] T007 [US2] Implement detect_seed_files() function in action/bloom.sh using gh pr view --json files
- [x] T008 [US2] Implement filter for **/seed.nix pattern (exactly "seed.nix" in any directory) in action/bloom.sh
- [x] T009 [US2] Implement validation logic: exit 0 for 0 seeds (skip), continue for 1, exit 1 for >1 in action/bloom.sh
- [x] T010 [US2] Add descriptive error message for multiple seeds case in action/bloom.sh
- [x] T011 [US2] Add "skipping - no seed.nix found" log message for 0 seeds case in action/bloom.sh

**Checkpoint**: Validation working - PRs with 0/1/>1 seeds handled correctly

---

## Phase 4: User Story 1 - Automated Seed Processing (Priority: P1)

**Goal**: Bloom seed.nix and commit artifacts back to PR

**Independent Test**: Create PR with single valid seed.nix; verify action blooms and commits artifacts

### Implementation for User Story 1

- [x] T012 [US1] Implement get_seed_directory() function to extract parent dir of seed.nix in action/bloom.sh
- [x] T013 [US1] Implement run_bloom() function that executes ${{ github.action_path }}/bin/bloom in action/bloom.sh
- [x] T014 [US1] Implement copy_artifacts() function to move result/* to seed directory in action/bloom.sh
- [x] T015 [US1] Implement check_for_changes() function using git status --porcelain in action/bloom.sh
- [x] T016 [US1] Implement commit_and_push() function with git config, add, commit, push in action/bloom.sh
- [x] T017 [US1] Add "chore: bloom artifacts for <seed-path>" commit message format in action/bloom.sh
- [x] T018 [US1] Add "no changes to commit" skip logic when bloom produces no artifacts in action/bloom.sh

**Checkpoint**: Full bloom workflow working - PR receives artifact commit

---

## Phase 5: User Story 3 - Error Handling and Feedback (Priority: P2)

**Goal**: Provide clear feedback when bloom fails

**Independent Test**: Submit PR with invalid seed.nix (bad hash); verify Nix error visible in logs

### Implementation for User Story 3

- [x] T019 [US3] Add echo statements for each major step (detecting, validating, blooming, committing) in action/bloom.sh
- [x] T020 [US3] Implement handle_bloom_failure() that preserves Nix error output in action/bloom.sh
- [x] T021 [US3] Implement handle_push_failure() with fork PR detection and helpful message in action/bloom.sh
- [x] T022 [US3] Ensure no partial commits on any failure (atomic behavior) in action/bloom.sh
- [x] T023 [US3] Add cleanup of result/ directory on failure in action/bloom.sh

**Checkpoint**: All error cases produce clear, actionable feedback

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Comments, documentation, and validation

- [x] T024 [P] Add beginner-friendly comments to action.yml explaining each step (per constitution)
- [x] T025 [P] Add beginner-friendly comments to action/bloom.sh explaining each function (per constitution)
- [ ] T026 Validate action works by creating test PR with examples/rust/serde/seed.nix
- [x] T027 Verify quickstart.md matches final implementation

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - start immediately
- **Foundational (Phase 2)**: Depends on Setup - BLOCKS all user stories
- **US2 Validation (Phase 3)**: Depends on Foundational
- **US1 Processing (Phase 4)**: Depends on US2 (validation must pass first)
- **US3 Error Handling (Phase 5)**: Can start after US1, enhances existing code
- **Polish (Phase 6)**: Depends on US1, US2, US3 completion

### User Story Dependencies

- **User Story 2 (P1)**: First - validation is prerequisite for processing
- **User Story 1 (P1)**: Second - depends on US2 validation passing
- **User Story 3 (P2)**: Third - enhances error handling in existing flow

### Within Each Phase

- Functions in bloom.sh can be written in any order
- action.yml steps must be in execution order (checkout → nix → bloom.sh)

### Parallel Opportunities

- T024 and T025 (comments) can run in parallel
- T007 and T008 (detection logic) are in same file but logically separate
- Different developers could work on action.yml (T002-T005) and bloom.sh (T006+) in parallel after T001

---

## Parallel Example: Phase 6 Polish

```bash
# Launch comment tasks in parallel (different files):
Task: "Add beginner-friendly comments to action.yml"
Task: "Add beginner-friendly comments to action/bloom.sh"
```

---

## Implementation Strategy

### MVP First (US1 + US2)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational
3. Complete Phase 3: US2 Validation
4. Complete Phase 4: US1 Processing
5. **STOP and VALIDATE**: Test with real PR
6. Deploy/demo if ready - basic bloom workflow works

### Incremental Delivery

1. Setup + Foundational → Action structure exists
2. Add US2 → Validation works (can detect/reject PRs)
3. Add US1 → Full bloom workflow (MVP complete!)
4. Add US3 → Better error messages
5. Polish → Production-ready

### Single Developer Strategy

Since this is a small feature (2 files):
1. Complete all phases sequentially
2. Test after each user story checkpoint
3. Total estimated: ~15-20 tasks, 2-4 hours

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story
- Constitution requires extensive beginner-friendly comments in ALL code
- Manual testing via real PR is the validation method (per plan.md)
- Use `${{ github.action_path }}` to reference deptext tooling from action
- GITHUB_TOKEN prevents infinite loops automatically (per research.md)
