# Feature Specification: GitHub Action for Automated Seed Blooming

**Feature Branch**: `002-github-action-bloom`
**Created**: 2025-12-01
**Status**: Draft
**Input**: User description: "Turn this project into a custom GitHub Action (with an action.yml file). When added to a repo, the action should run on pull requests containing seed.nix files. The action should first confirm that there is one and only one file in the pull request (a single seed.nix file). Then the action should execute the ./bin/bloom for the seed file. Once the bloom has completed, move the resulting artifacts next to the seed file and commit the changes (updating the pull request)."

## Clarifications

### Session 2025-12-01

- Q: Action deployment model (reusable vs embedded)? → A: Reusable composite action - consumers add `uses: deptext/core@v1` in their workflows
- Q: Nix environment provisioning? → A: Action installs Nix itself (using cachix/install-nix-action or similar)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Automated Seed Processing on PR (Priority: P1)

As a repository maintainer, I want PRs containing a single seed.nix file to be automatically processed ("bloomed") so that the generated metadata artifacts are committed alongside the seed file without manual intervention.

**Why this priority**: This is the core value proposition - automating the bloom process eliminates manual build steps and ensures every seed PR includes its generated artifacts before merge.

**Independent Test**: Can be fully tested by creating a PR with a single seed.nix file and verifying the action runs, blooms the seed, and commits the resulting artifacts (stats.json, etc.) to the same PR.

**Acceptance Scenarios**:

1. **Given** a repository with the GitHub Action installed, **When** a contributor opens a PR containing exactly one new seed.nix file, **Then** the action automatically runs ./bin/bloom on that seed file and commits the generated artifacts to the PR branch.

2. **Given** a PR with a single seed.nix file, **When** the bloom process completes successfully, **Then** the artifacts (e.g., stats/stats.json) are placed in the same directory as the seed.nix file and committed with a clear commit message.

3. **Given** a PR with a single seed.nix file, **When** the bloom process completes and commits artifacts, **Then** the PR is updated with the new commit and subsequent CI checks can run on the updated PR.

---

### User Story 2 - PR Validation (Single Seed Enforcement) (Priority: P1)

As a repository maintainer, I want the action to validate that a PR contains exactly one seed.nix file before processing, so that the workflow remains predictable and each PR represents a single package addition.

**Why this priority**: Validation prevents ambiguous situations and enforces the one-seed-per-PR workflow, which is essential for maintaining clean git history and review processes.

**Independent Test**: Can be tested by creating PRs with zero, one, two, or more seed.nix files and verifying the action only processes when exactly one exists.

**Acceptance Scenarios**:

1. **Given** a PR with exactly one seed.nix file, **When** the action runs, **Then** the validation passes and bloom processing proceeds.

2. **Given** a PR with no seed.nix files, **When** the action runs, **Then** the action skips processing gracefully without failure (the PR may be for other purposes).

3. **Given** a PR with multiple seed.nix files, **When** the action runs, **Then** the action fails with a clear error message indicating that only one seed.nix file per PR is allowed.

---

### User Story 3 - Error Handling and Feedback (Priority: P2)

As a contributor, I want clear feedback when the bloom process fails so that I can understand what went wrong and fix my seed.nix file.

**Why this priority**: Good error handling improves developer experience and reduces maintainer burden for troubleshooting.

**Independent Test**: Can be tested by submitting a PR with an invalid seed.nix file (e.g., bad hash, malformed Nix) and verifying the action provides meaningful error output.

**Acceptance Scenarios**:

1. **Given** a PR with an invalid seed.nix file (syntax error), **When** the action runs bloom, **Then** the action fails and the error message from Nix is visible in the action logs.

2. **Given** a PR with a seed.nix that references an invalid hash, **When** the action runs bloom, **Then** the action fails with a clear message about hash mismatch.

3. **Given** any bloom failure, **When** the action encounters an error, **Then** no partial commits are made to the PR branch (atomic operation).

---

### Edge Cases

- What happens when a PR updates an existing seed.nix file (not a new one)? The action should still bloom and update artifacts.
- What happens when the seed.nix file is in a nested directory? The artifacts should be placed relative to the seed file location.
- What happens when the action doesn't have write permissions to the PR branch (e.g., fork from external contributor)? The action should fail gracefully with a clear permissions error.
- What happens when artifacts already exist from a previous bloom? They should be overwritten with fresh artifacts.
- What happens when the bloom produces no artifacts (e.g., all processors disabled)? The action should succeed without committing (nothing to commit).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The repository MUST include an `action.yml` file that defines a reusable composite GitHub Action, enabling consumers to reference it via `uses: deptext/core@v1` in their workflows.
- **FR-002**: The action MUST trigger on pull request events (opened, synchronize, reopened).
- **FR-003**: The action MUST detect all files matching `**/seed.nix` (exactly named `seed.nix` in any directory) changed or added in the pull request.
- **FR-004**: The action MUST validate that exactly one seed.nix file exists in the PR's changed files before proceeding.
- **FR-005**: The action MUST fail with a descriptive error if the PR contains multiple seed.nix files.
- **FR-006**: The action MUST skip processing gracefully (exit success) if the PR contains no seed.nix files.
- **FR-007**: The action MUST execute `./bin/bloom <path-to-seed.nix>` for the detected seed file.
- **FR-008**: The action MUST install Nix with flakes enabled as part of its execution (consumers do not need to pre-install Nix).
- **FR-009**: The action MUST move/copy the bloom output artifacts to the same directory as the seed.nix file.
- **FR-010**: The action MUST commit the artifacts to the PR branch with a descriptive commit message.
- **FR-011**: The action MUST push the commit to update the pull request.
- **FR-012**: The action MUST NOT commit if the bloom process fails.
- **FR-013**: The action MUST NOT commit if there are no artifacts to commit (empty result).
- **FR-014**: The action MUST provide clear log output indicating each step: validation, bloom execution, artifact copying, commit.
- **FR-015**: The action MUST support seed.nix files in any directory within the repository (not just root).

### Key Entities

- **Seed File**: A `seed.nix` file that defines package metadata for DepText processing. Located anywhere in the repository.
- **Bloom Artifacts**: Output files generated by the bloom process (e.g., `stats/stats.json`, `.deptext.json`). Placed adjacent to the seed file.
- **Pull Request**: The GitHub PR event that triggers the action. Contains file changes including seed.nix.
- **PR Branch**: The branch associated with the pull request where commits are pushed.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: PRs containing a single valid seed.nix file have artifacts automatically committed within 5 minutes of PR creation/update.
- **SC-002**: 100% of PRs with multiple seed.nix files are rejected with a clear error message.
- **SC-003**: 100% of bloom failures result in no partial commits (atomic behavior).
- **SC-004**: Contributors can identify bloom errors from action logs without maintainer assistance in 90% of failure cases.
- **SC-005**: The action successfully processes seed.nix files regardless of their directory depth in the repository.

## Assumptions

- The action is distributed as a reusable composite action; consumers reference it via `uses: deptext/core@v1` and do not need the DepText codebase in their repository.
- The action bundles or checks out the DepText codebase (including `./bin/bloom` and `lib/`) as part of its execution.
- The action installs Nix with flakes enabled as part of its execution; consumers do not need Nix pre-installed.
- The action has appropriate permissions to push commits to PR branches (standard GitHub Actions permissions for `contents: write`).
- PRs from forks may have limited permissions; the action will handle this gracefully.
- The commit message format will be: "chore: bloom artifacts for <seed-path>" or similar descriptive format.
- The action uses the automatically-provided GitHub token from the runner environment (no explicit input required).
