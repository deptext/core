# Quickstart: Using the DepText Bloom Action

**Date**: 2025-12-01
**Feature**: 002-github-action-bloom

> **Note**: This quickstart was written during initial design. References to `./bin/bloom` below are outdated. Use `nix build --impure -f lib/eval-seed.nix --argstr seedPath $PWD/path/to/seed.nix` for local builds.

## For Consumers (Using the Action)

### 1. Create Workflow File

Add `.github/workflows/bloom.yml` to your repository:

```yaml
# .github/workflows/bloom.yml
#
# This workflow runs the DepText bloom action on pull requests.
# When a PR contains a seed.nix file, it will be processed and
# the resulting artifacts committed back to the PR.

name: DepText Bloom

on:
  pull_request:
    # Only run on PRs targeting main branch
    branches: [main]
    types: [opened, synchronize, reopened]
    # Only trigger when seed.nix files change (also prevents loops since
    # artifact commits don't match this pattern)
    paths:
      - '**/seed.nix'

# Cancel in-progress runs when new commits are pushed (saves runner time)
concurrency:
  group: ${{ github.workflow }}-${{ github.head_ref }}
  cancel-in-progress: true

# Required permissions for pushing commits back to the PR
permissions:
  contents: write

jobs:
  bloom:
    runs-on: ubuntu-latest
    # Prevent jobs from running forever if something hangs
    timeout-minutes: 10
    steps:
      - uses: deptext/core@v1
```

### 2. Create a Seed File

Create a new seed.nix file anywhere in your repository:

```nix
# nursery/rust/serde/seed.nix
{ deptext }:

deptext.mkRustPackage {
  pname = "serde";
  version = "1.0.215";
  hash = "sha256:04xwh16jm7szizkkhj637jv23i5x8jnzcfrw6bfsrssqkjykaxcm";
  github = {
    owner = "serde-rs";
    repo = "serde";
    rev = "v1.0.215";
    hash = "sha256:0qaz2mclr5cv3s5riag6aj3n3avirirnbi7sxpq4nw1vzrq09j6l";
  };
}
```

### 3. Open a Pull Request

When you open a PR with your seed.nix file:

1. The action detects the seed.nix file
2. Installs Nix with flakes enabled
3. Runs `./bin/bloom` on your seed
4. Commits the generated artifacts (stats/, .deptext.json) to your PR

### Expected Output

After the action runs, your PR will have an additional commit with:
```text
nursery/rust/serde/
├── seed.nix           # Your original file
├── stats/
│   └── stats.json     # Generated file statistics
└── .deptext.json      # Pipeline metadata
```

## For Contributors (Developing the Action)

### Local Testing

The bloom.sh script requires GitHub CLI (`gh`) and PR context to detect changed files. For local development:

1. Clone the repo and create a test branch:
   ```bash
   git checkout -b test-bloom-action
   ```

2. Make changes to action.yml or action/bloom.sh

3. Verify shell script syntax:
   ```bash
   bash -n action/bloom.sh
   ```

4. Test the bloom tool directly (without the action):
   ```bash
   ./bin/bloom examples/rust/serde/seed.nix
   ```

### Testing in a PR

1. Push your branch to create a PR
2. The action will run on its own changes
3. Check the Actions tab for logs

### Action Structure

```text
action.yml           # Action definition (inputs, steps)
action/
└── bloom.sh         # Main script (validation, bloom, commit)
```

## Troubleshooting

### "Push failed" on Fork PRs

Fork PRs from external contributors cannot receive pushed commits due to GitHub security restrictions.

**Solution**: Contributor should run bloom locally:
```bash
./bin/bloom path/to/seed.nix
cp -r result/* path/to/seed-directory/
git add . && git commit -m "chore: add bloom artifacts"
```

### "Multiple seed.nix files detected"

The action enforces one seed per PR for clean git history.

**Solution**: Split your PR into separate PRs, one per seed.

### "Bloom failed" with Nix errors

Check the action logs for the specific Nix error. Common issues:
- Invalid hash in seed.nix
- Network issues fetching packages
- Syntax errors in seed.nix

**Solution**: Fix the seed.nix file and push a new commit.
