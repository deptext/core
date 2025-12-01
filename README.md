# DepText

A Nix-based build system for processing open source packages into structured metadata for LLM context windows.

## Quick Start

```nix
# examples/rust/serde/seed.nix
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

Build with:
```bash
./bin/bloom examples/rust/serde/seed.nix
```

Or via flake:
```bash
nix run github:deptext/core#bloom -- ./seed.nix
```

## GitHub Action

Automatically process seed.nix files in pull requests. When a PR contains a seed.nix file, the action blooms it and commits the artifacts back to the PR.

### Repository Setup

Before using the action, configure your repository:

1. **Enable GitHub Actions**
   - Go to **Settings → Actions → General**
   - Select "Allow all actions and reusable workflows"

2. **Set Workflow Permissions**
   - Go to **Settings → Actions → General → Workflow permissions**
   - Select **"Read and write permissions"**
   - Check **"Allow GitHub Actions to create and approve pull requests"**

### Add the Workflow

Create `.github/workflows/bloom.yml` in your repository:

```yaml
name: DepText Bloom

on:
  pull_request:
    branches: [main]
    paths:
      - '**/seed.nix'

permissions:
  contents: write

jobs:
  bloom:
    runs-on: ubuntu-latest
    steps:
      - uses: deptext/core@main
```

> **Note**: Use `@main` for latest, or pin to a specific tag (e.g., `@v1`) when available.

### How It Works

1. PR with seed.nix file is opened
2. Action detects the seed.nix in changed files
3. Nix is installed and `./bin/bloom` runs on the seed
4. Generated artifacts (stats/, .deptext.json) are committed back to the PR

### Limitations

- Processes exactly one seed.nix per PR (fails if multiple seeds detected)
- Fork PRs cannot receive commits due to GitHub security restrictions (run bloom locally instead)

## Supported Languages

- **Rust** - `mkRustPackage` (crates.io + GitHub)
- **Python** - `mkPythonPackage` (PyPI + GitHub)

## Processors

| Processor | Description | Persist Default |
|-----------|-------------|-----------------|
| `package-download` | Fetches from package registry | `false` |
| `source-download` | Fetches from GitHub | `false` |
| `stats` | Generates file statistics | `true` |

## Custom Configuration

Override processor settings per-seed:

```nix
{ deptext }:

deptext.mkRustPackage {
  pname = "serde";
  version = "1.0.215";
  hash = "sha256:...";
  github = { owner = "serde-rs"; repo = "serde"; rev = "v1.0.215"; hash = "sha256:..."; };
  processors = {
    package-download = { persist = true; };
    source-download = { enabled = false; };
  };
}
```

## Running Tests

```bash
./tests/integration/test-rust-seed.sh
./tests/integration/test-python-seed.sh
```

## Requirements

- Nix 2.4+ with flakes enabled
- Network access to package registries and GitHub
