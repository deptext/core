# Research: GitHub Action for Automated Seed Blooming

**Date**: 2025-12-01
**Feature**: 002-github-action-bloom

> **Note**: This research doc was written during initial design. Implementation uses `nix build --json` directly instead of `./bin/bloom`.

## Research Topics

### 1. GitHub Composite Actions Best Practices

**Decision**: Use composite action (not JavaScript/Docker action)

**Rationale**:
- Composite actions run steps directly in the runner environment, making Nix installation straightforward
- No need to bundle dependencies or build Docker images
- Simpler to maintain - just YAML and shell scripts
- Can reuse existing marketplace actions (cachix/install-nix-action, actions/checkout)

**Alternatives Considered**:
- Docker action: Would require building image with Nix pre-installed, heavier maintenance
- JavaScript action: Overkill for orchestrating shell commands, adds Node.js dependency

### 2. Detecting Changed Files in PR

**Decision**: Use GitHub API via `gh pr view --json files` or `actions/github-script`

**Rationale**:
- GitHub CLI (`gh`) is pre-installed on runners and provides simple JSON output
- Can filter for `seed.nix` files directly with jq
- Works reliably for both push and PR synchronize events

**Alternatives Considered**:
- `git diff`: Requires fetching full history, more complex for PR base comparisons
- GitHub REST API directly: More verbose than `gh` CLI wrapper
- `tj-actions/changed-files`: Third-party dependency, prefer minimal dependencies

### 3. Nix Installation in GitHub Actions

**Decision**: Use `cachix/install-nix-action` with flakes enabled

**Rationale**:
- Well-maintained, widely adopted in Nix community
- Handles flakes configuration automatically with `extra_nix_config`
- Supports caching Nix store (optional performance improvement)
- Single step installation, ~30-60 seconds overhead

**Configuration**:
```yaml
- uses: cachix/install-nix-action@v31
  with:
    extra_nix_config: |
      experimental-features = nix-command flakes
```

**Alternatives Considered**:
- DeterminateSystems/nix-installer-action: Newer, similar functionality
- Manual installation: More control but higher maintenance burden

### 4. Committing and Pushing from Actions

**Decision**: Use standard git commands with automatic token authentication

**Rationale**:
- `actions/checkout` automatically configures git authentication using the workflow's token
- No explicit token input needed - follows pattern of google-release-please and similar actions
- Works when consumer workflow has `permissions: contents: write`
- Simpler consumer experience with zero required inputs

**Implementation Pattern**:
```bash
git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"
git add <artifacts>
git commit -m "chore: bloom artifacts for <seed-path>"
git push
```

**Alternatives Considered**:
- Explicit token input: Unnecessary complexity, token already available
- stefanzweifel/git-auto-commit-action: Adds dependency, our use case is simple enough
- GitHub API for commits: More complex, no benefit for our use case

### 5. Handling Fork PRs

**Decision**: Fail gracefully with clear error message when push fails

**Rationale**:
- Fork PRs from external contributors have limited GITHUB_TOKEN permissions
- Cannot push to forked repo's branch from base repo's action
- Clear error message guides contributor to run bloom locally

**Implementation**:
- Detect push failure and output helpful message
- Suggest running `./bin/bloom` locally
- Action exits with non-zero status (clear failure)

**Alternatives Considered**:
- Use workflow_run event: Complex two-workflow setup
- Require PAT: Security concern, not recommended for public repos

### 6. Bundling Checkout into Action

**Decision**: Include `actions/checkout` inside our composite action

**Rationale**:
- Consumers get single-step usage: just `uses: deptext/core@v1`
- Action controls checkout parameters (ref, fetch-depth) correctly
- DepText tooling available via `${{ github.action_path }}` (automatic)
- Follows pattern of self-contained actions that "just work"

**Implementation**:
```yaml
# Inside our action.yml
- uses: actions/checkout@v4
  with:
    ref: ${{ github.head_ref }}
```

**Alternatives Considered**:
- Require consumer to checkout: Extra step, easy to misconfigure ref parameter

### 7. Infinite Loop Prevention

**Decision**: Rely on GITHUB_TOKEN's built-in protection + paths filter

**Rationale**:
- GITHUB_TOKEN commits deliberately do NOT trigger subsequent workflows (GitHub's anti-loop measure)
- Our `paths: '**/seed.nix'` filter means artifact commits (stats/, .deptext.json) wouldn't re-trigger anyway
- Double protection without extra code

**Source**: [GitHub Community Discussion](https://github.com/orgs/community/discussions/25702)

**Alternatives Considered**:
- `[skip ci]` in commit message: Unnecessary given GITHUB_TOKEN protection
- Actor filtering (`if: github.actor != 'github-actions[bot]'`): Unnecessary complexity

### 8. Action File Location

**Decision**: Place `action.yml` at repository root

**Rationale**:
- GitHub requires action.yml at repo root for `uses: owner/repo@ref` syntax
- Alternative paths require specifying subdirectory which complicates usage
- Follows convention of repos that are primarily actions

**Alternatives Considered**:
- `.github/actions/bloom/action.yml`: Would require `uses: owner/repo/.github/actions/bloom@ref`

## Summary of Technology Choices

| Component | Choice | Reason |
|-----------|--------|--------|
| Action Type | Composite | Simplest, direct runner access |
| Repo Checkout | Bundled (actions/checkout@v4) | Single-step consumer experience, stable |
| Nix Installer | cachix/install-nix-action@v31 | Well-maintained, flakes support, faster than alternatives |
| File Detection | gh CLI + jq | Pre-installed, simple JSON parsing |
| Git Operations | Native git commands | Auto token auth, no extra deps |
| Loop Prevention | GITHUB_TOKEN + paths filter | Built-in protection, no extra code needed |
| Script Location | action/bloom.sh | Keeps action.yml clean, testable |

## Open Questions Resolved

All technical questions have been resolved through research. No NEEDS CLARIFICATION items remain.
