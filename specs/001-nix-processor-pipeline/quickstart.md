# Quickstart: DepText MVP

**Date**: 2025-11-30
**Branch**: `001-nix-processor-pipeline`

## Prerequisites

- Nix 2.4+ with flakes enabled
- Network access to crates.io, PyPI, and GitHub

### Enable Nix Flakes

Add to `~/.config/nix/nix.conf`:

```text
experimental-features = nix-command flakes
```

## Creating a Seed

### Rust Package Example (serde)

Create `seed.nix`:

```nix
# seed.nix - Seed file for serde 1.0.228
#
# A "seed" is the starting point for generating LLM context.
# It specifies what package to process and how.

# Import the DepText flake's library
let
  deptext = builtins.getFlake "github:deptext/core";
in

# Call the Rust language helper with package metadata
deptext.lib.mkRustPackage {
  # Package name on crates.io
  name = "serde";

  # Version to fetch
  version = "1.0.228";

  # GitHub repository for source code
  github = {
    owner = "serde-rs";
    repo = "serde";
    rev = "v1.0.228";  # Git tag or commit
  };

  # Hashes ensure we get the exact expected content
  # Get these using: nix-prefetch-url <url>
  hashes = {
    package = "sha256-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX";
    source = "sha256-YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY";
  };
}
```

### Python Package Example (requests)

Create `seed.nix`:

```nix
# seed.nix - Seed file for requests 2.31.0

let
  deptext = builtins.getFlake "github:deptext/core";
in

deptext.lib.mkPythonPackage {
  name = "requests";
  version = "2.31.0";

  github = {
    owner = "psf";
    repo = "requests";
    rev = "v2.31.0";
  };

  hashes = {
    package = "sha256-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX";
    source = "sha256-YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY";
  };
}
```

## Getting Hash Values

Before building, you need the SHA256 hashes for the package tarball and source.

### For Rust (crates.io):

```bash
# Package hash
nix-prefetch-url "https://crates.io/api/v1/crates/serde/1.0.228/download"

# Source hash (GitHub)
nix-prefetch-github serde-rs serde --rev v1.0.228
```

### For Python (PyPI):

```bash
# Package hash
nix-prefetch-url "https://pypi.io/packages/source/r/requests/requests-2.31.0.tar.gz"

# Source hash (GitHub)
nix-prefetch-github psf requests --rev v2.31.0
```

## Building (Germinating)

Run from the directory containing your `seed.nix`:

```bash
nix build -f seed.nix
```

This will:
1. Download the package from the registry (crates.io/PyPI)
2. Download the source from GitHub
3. Validate the repository URL matches (if present in metadata)
4. Generate file count statistics
5. Write persisted outputs alongside `seed.nix`

## Output Structure

After a successful build:

```text
your-project/
├── seed.nix           # Your seed file
├── result -> /nix/... # Symlink to Nix store output
└── stats/             # Persisted output (only stats by default)
    └── stats.json     # File count and metadata
```

### stats.json Example

```json
{
  "file_count": 142,
  "generated_at": "2025-11-30T12:00:00Z",
  "source": "github",
  "package": {
    "name": "serde",
    "version": "1.0.228"
  }
}
```

## Enabling Persistence for Other Processors

By default, only `stats` persists output. To persist package or source:

```nix
deptext.lib.mkRustPackage {
  name = "serde";
  version = "1.0.228";
  github = { ... };
  hashes = { ... };

  # Override processor defaults
  processors = {
    package-download = {
      persist = true;  # Copy package contents to ./package-download/
    };
    source-download = {
      persist = true;  # Copy GitHub source to ./source-download/
    };
  };
}
```

## Error Handling

All errors cause the build to fail completely:

| Error | Cause | Resolution |
|-------|-------|------------|
| "Package not found" | Invalid name/version | Check crates.io/PyPI for correct spelling |
| "Repository not found" | Invalid GitHub URL | Verify owner/repo/rev |
| "URL mismatch" | GitHub URL differs from registry metadata | Verify correct repository |
| "Hash mismatch" | Content changed or wrong hash | Re-run nix-prefetch commands |
| "Rate limited" | Too many GitHub requests | Wait or use authentication (not in MVP) |

## Next Steps

- Browse the `result/` symlink to see all processor outputs
- Check `stats/stats.json` for file count statistics
- Modify `processors` config to persist additional outputs
