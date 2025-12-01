# Data Model: GitHub Action for Automated Seed Blooming

**Date**: 2025-12-01
**Feature**: 002-github-action-bloom

## Overview

This feature primarily deals with GitHub Actions workflow data and file system artifacts. No database or persistent storage is involved. The "data model" describes the structure of inputs, outputs, and state transitions during action execution.

## Entities

### 1. Action Inputs

The composite action requires no inputs. It uses the GitHub context and token automatically provided by the runner environment.

Optional inputs (if needed for customization):

| Input | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `commit-message-prefix` | string | No | `"chore: bloom"` | Prefix for commit messages |

### 2. Pull Request Context

Data extracted from GitHub context during execution:

| Field | Source | Description |
|-------|--------|-------------|
| `pr_number` | `github.event.pull_request.number` | PR number for API queries |
| `head_ref` | `github.head_ref` | Branch name to push commits to |
| `base_ref` | `github.base_ref` | Base branch for comparison |
| `repository` | `github.repository` | Owner/repo for gh commands |

### 3. Seed File Detection Result

Output from file detection step:

| Field | Type | Description |
|-------|------|-------------|
| `seed_count` | integer | Number of seed.nix files in PR changes |
| `seed_path` | string | Path to the single seed.nix (if count == 1) |
| `seed_dir` | string | Directory containing the seed file |

**State Transitions**:
- `seed_count == 0` → Action exits successfully (skip)
- `seed_count == 1` → Proceed to bloom
- `seed_count > 1` → Action fails with error

### 4. Bloom Output

Artifacts produced by `./bin/deptext bloom`:

| Artifact | Location | Description |
|----------|----------|-------------|
| `stats/stats.json` | `<seed_dir>/stats/` | File statistics (persist=true default) |
| `.deptext.json` | `<seed_dir>/` | Pipeline metadata |

**Note**: Other processor outputs may exist if `persist=true` is set in seed.

### 5. Commit State

State of git operations:

| State | Description |
|-------|-------------|
| `no_changes` | Bloom produced no artifacts to commit |
| `committed` | Artifacts staged, committed, and pushed |
| `push_failed` | Commit created but push failed (fork PR) |

## File System Layout

### Before Action Runs

```text
<consumer-repo>/
├── .github/workflows/
│   └── bloom.yml          # Consumer's workflow using our action
└── nursery/               # Example seed location
    └── rust/
        └── serde/
            └── seed.nix   # Changed file in PR
```

### After Successful Bloom

```text
<consumer-repo>/
├── .github/workflows/
│   └── bloom.yml
└── nursery/
    └── rust/
        └── serde/
            ├── seed.nix
            ├── stats/
            │   └── stats.json    # NEW: Generated artifact
            └── .deptext.json     # NEW: Pipeline metadata
```

## Validation Rules

### Seed File Detection

- File must match pattern `**/seed.nix` (exactly named `seed.nix` in any directory)
- Does NOT match: `my-seed.nix`, `seeds.nix`, `seed.nix.bak`
- File must be in PR's changed files list (added, modified)
- Deleted seed.nix files are ignored

### Artifact Placement

- Artifacts must be placed in same directory as seed.nix
- Existing artifacts are overwritten (no merge)
- Empty result directories are not committed

## State Machine

```text
┌─────────────┐
│   START     │
└──────┬──────┘
       │
       ▼
┌─────────────┐     seed_count == 0     ┌─────────────┐
│  Detect     │ ─────────────────────▶  │   SKIP      │
│  Seeds      │                         │  (success)  │
└──────┬──────┘                         └─────────────┘
       │ seed_count == 1
       │
       │ seed_count > 1   ┌─────────────┐
       │ ────────────────▶│   FAIL      │
       │                  │  (error)    │
       ▼                  └─────────────┘
┌─────────────┐
│  Install    │
│    Nix      │
└──────┬──────┘
       │
       ▼
┌─────────────┐     bloom fails     ┌─────────────┐
│    Bloom    │ ──────────────────▶ │   FAIL      │
│   Seed      │                     │  (error)    │
└──────┬──────┘                     └─────────────┘
       │ success
       ▼
┌─────────────┐     no changes     ┌─────────────┐
│   Stage     │ ─────────────────▶ │   SUCCESS   │
│  Artifacts  │                    │ (no commit) │
└──────┬──────┘                    └─────────────┘
       │ has changes
       ▼
┌─────────────┐
│   Commit    │
│   & Push    │
└──────┬──────┘
       │
       ├─── push fails (fork) ──▶ FAIL (with helpful message)
       │
       ▼
┌─────────────┐
│   SUCCESS   │
│ (committed) │
└─────────────┘
```
