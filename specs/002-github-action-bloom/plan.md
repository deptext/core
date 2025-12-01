# Implementation Plan: GitHub Action for Automated Seed Blooming

**Branch**: `002-github-action-bloom` | **Date**: 2025-12-01 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-github-action-bloom/spec.md`

## Summary

Create a reusable GitHub composite action that automatically processes ("blooms") seed.nix files in pull requests. The action validates that exactly one seed.nix file exists in the PR, installs Nix with flakes, runs `./bin/deptext bloom`, and commits the resulting artifacts back to the PR branch. Consumers reference it via `uses: deptext/core@v1`.

## Technical Context

**Language/Version**: YAML (GitHub Actions), Bash (shell scripts)
**Primary Dependencies**: actions/checkout@v4 (bundled), cachix/install-nix-action@v31 (Nix installer), GitHub CLI (gh)
**Storage**: N/A (artifacts stored in git)
**Testing**: Manual PR-based testing, shell script validation
**Target Platform**: GitHub Actions runners (ubuntu-latest)
**Project Type**: Single (GitHub Action added to existing repo)
**Performance Goals**: Complete bloom + commit within 5 minutes
**Constraints**: Must work with GITHUB_TOKEN permissions, handle fork PRs gracefully
**Scale/Scope**: Single action.yml, supporting shell script(s)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Gate | Rule | Status |
|------|------|--------|
| Simplicity | NEVER over-engineer; keep code as simple as possible | PASS - Single action.yml + bash script |
| Maintainability | Code must be easy to understand and maintain | PASS - Standard GH Actions patterns |
| No Code Debt | Clean up as you go | PASS - Fresh implementation |
| Modularity | Write extremely modular code | PASS - Action is self-contained |
| Modern Targets | Write for modern tools only | PASS - GitHub Actions latest features |
| Comments | Extensive beginner-friendly comments | REQUIRED - All YAML and bash must explain WHY |

## Project Structure

### Documentation (this feature)

```text
specs/002-github-action-bloom/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
# GitHub Action files (new)
action.yml               # Reusable composite action definition
action/
└── bloom.sh             # Main action script (validation, bloom, commit)

# Existing DepText structure (unchanged)
bin/
└── deptext              # CLI entrypoint (existing)
lib/                     # Nix library (existing)
examples/                # Example seeds (existing)
```

**Structure Decision**: Adding action.yml at repo root (GitHub Actions convention) with supporting script in action/ directory. No changes to existing DepText structure.

## Complexity Tracking

> **No violations identified** - All constitution gates pass without justification needed.
