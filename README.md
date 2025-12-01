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
