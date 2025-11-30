# Data Model: DepText MVP - Nix Processor Pipeline

**Date**: 2025-11-30
**Branch**: `001-nix-processor-pipeline`

## Overview

DepText uses Nix attribute sets as its data model. This document defines the shape of inputs and outputs for seeds, processors, and blooms.

## Core Entities

### 1. Seed Configuration

A seed is a Nix file that calls a language helper with package metadata.

```nix
# Seed input schema (passed to language helpers)
{
  # Required fields (FR-005)
  name = "serde";              # Package name in registry
  version = "1.0.228";         # Package version
  github = {                   # GitHub repository info
    owner = "serde-rs";
    repo = "serde";
    rev = "v1.0.228";          # Tag or commit
  };

  # Optional fields (FR-006)
  processors = {               # Per-processor configuration
    package-download = {
      enabled = true;          # Default: true
      persist = false;         # Default: false (FR-013)
    };
    source-download = {
      enabled = true;          # Default: true
      persist = false;         # Default: false (FR-015)
    };
    stats = {
      enabled = true;          # Default: true
      persist = true;          # Default: true (FR-018)
    };
  };

  # Hashes for reproducible fetches
  hashes = {
    package = "sha256-...";    # Hash of package tarball
    source = "sha256-...";     # Hash of GitHub source
  };
}
```

### 2. Package Metadata (metadata.json)

Output of the package-download processor (FR-014).

#### Rust (from crates.io API)

```json
{
  "name": "serde",
  "version": "1.0.228",
  "description": "A generic serialization/deserialization framework",
  "repository": "https://github.com/serde-rs/serde",
  "homepage": "https://serde.rs",
  "documentation": "https://docs.rs/serde",
  "license": "MIT OR Apache-2.0",
  "keywords": ["serde", "serialization"],
  "categories": ["encoding"],
  "authors": ["Erick Tryzelaar <erick.tryzelaar@gmail.com>", "David Tolnay <dtolnay@gmail.com>"],
  "created_at": "2015-04-22T00:20:47.847540+00:00",
  "updated_at": "2024-01-15T17:00:00+00:00",
  "downloads": 250000000,
  "dependencies": [
    {"name": "serde_derive", "version_req": "=1.0.228", "optional": true}
  ],
  "_deptext": {
    "registry": "crates.io",
    "language": "rust",
    "fetched_at": "2025-11-30T12:00:00Z"
  }
}
```

#### Python (from PyPI API)

```json
{
  "name": "requests",
  "version": "2.31.0",
  "summary": "Python HTTP for Humans.",
  "home_page": "https://requests.readthedocs.io",
  "project_urls": {
    "Source": "https://github.com/psf/requests"
  },
  "license": "Apache 2.0",
  "keywords": ["HTTP", "networking"],
  "author": "Kenneth Reitz",
  "author_email": "me@kennethreitz.org",
  "requires_python": ">=3.7",
  "requires_dist": [
    "charset-normalizer (<4,>=2)",
    "idna (<4,>=2.5)",
    "urllib3 (<3,>=1.21.1)",
    "certifi (>=2017.4.17)"
  ],
  "_deptext": {
    "registry": "pypi",
    "language": "python",
    "fetched_at": "2025-11-30T12:00:00Z"
  }
}
```

### 3. Stats Output (stats.json)

Output of the stats processor (FR-018, FR-019).

```json
{
  "file_count": 42,
  "generated_at": "2025-11-30T12:00:00Z",
  "source": "github",
  "package": {
    "name": "serde",
    "version": "1.0.228"
  }
}
```

### 4. Processor Definition

Internal structure for processor derivations (FR-008, FR-009).

```nix
# Processor attribute set
{
  name = "package-download";   # Processor identifier
  enabled = true;              # Whether to run
  persist = false;             # Whether to copy output (FR-021)

  # Dependencies on other processors (FR-009)
  deps = [];                   # List of processor names

  # The actual derivation
  drv = pkgs.stdenv.mkDerivation {
    name = "deptext-package-download-${package.name}-${package.version}";
    # ...
  };
}
```

### 5. Language Helper Output

What `mkRustPackage` and `mkPythonPackage` return (FR-003).

```nix
# Return value of mkRustPackage/mkPythonPackage
{
  # The final derivation that depends on all processors
  # Building this builds the entire pipeline
  default = <derivation>;

  # Individual processor derivations for debugging/access
  processors = {
    package-download = <derivation>;
    source-download = <derivation>;
    stats = <derivation>;
  };

  # Metadata for tooling
  meta = {
    name = "serde";
    version = "1.0.228";
    language = "rust";
  };
}
```

## Processor Dependency Graph

```text
                    ┌─────────────────┐
                    │   seed.nix      │
                    │  (user config)  │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │ package-download│  ← Downloads from crates.io/PyPI
                    │                 │  → Outputs: package/, metadata.json
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              ▼              ▼              │
     ┌─────────────────┐                    │
     │ source-download │  ← Downloads from GitHub
     │                 │  ← Validates URL against metadata.json
     │                 │  → Outputs: source/
     └────────┬────────┘                    │
              │                             │
              └──────────────┬──────────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │     stats       │  ← Counts files in source
                    │                 │  → Outputs: stats.json
                    └─────────────────┘
```

## File Layouts

### Nix Store Output (per processor)

```text
/nix/store/xxx-deptext-package-download-serde-1.0.228/
├── package/                 # Extracted package contents
│   ├── Cargo.toml
│   ├── src/
│   └── ...
└── metadata.json            # Registry metadata

/nix/store/yyy-deptext-source-download-serde-1.0.228/
└── source/                  # GitHub source tree
    ├── .github/
    ├── serde/
    ├── serde_derive/
    └── ...

/nix/store/zzz-deptext-stats-serde-1.0.228/
└── stats.json               # Statistics
```

### Persisted Output (alongside seed.nix)

When `persist = true` (FR-022):

```text
nursery/rust/s/se/serde/1.0.228/
├── seed.nix                 # User's seed file
├── result -> /nix/store/... # Symlink to final derivation
└── stats/                   # Only stats persists by default
    └── stats.json
```

## State Transitions

### Seed States

```text
┌──────────┐   nix build   ┌───────────┐   success   ┌───────────┐
│  Draft   │ ────────────► │ Building  │ ──────────► │  Bloomed  │
│          │               │           │             │           │
└──────────┘               └─────┬─────┘             └───────────┘
                                 │
                                 │ any failure
                                 ▼
                           ┌───────────┐
                           │  Failed   │
                           │           │
                           └───────────┘
```

### Processor States

Each processor in the chain:

```text
┌──────────┐   deps ready   ┌───────────┐   complete   ┌───────────┐
│ Pending  │ ─────────────► │ Building  │ ───────────► │   Done    │
│          │                │           │              │           │
└──────────┘                └─────┬─────┘              └───────────┘
                                  │
                                  │ error
                                  ▼
                            ┌───────────┐
                            │  Failed   │ ─► Entire build fails (FR-011)
                            │           │
                            └───────────┘
```

## Validation Rules

### Seed Validation

| Field | Rule | Error |
|-------|------|-------|
| name | Non-empty string | "Package name is required" |
| version | Non-empty string, valid semver preferred | "Package version is required" |
| github.owner | Non-empty string | "GitHub owner is required" |
| github.repo | Non-empty string | "GitHub repo is required" |
| github.rev | Non-empty string (tag or commit) | "GitHub revision is required" |
| hashes.package | Valid Nix hash format | "Invalid package hash format" |
| hashes.source | Valid Nix hash format | "Invalid source hash format" |

### URL Validation (FR-016, FR-017)

```text
IF metadata.json contains repository URL:
  Normalize both URLs (remove trailing slashes, .git suffix)
  IF normalized_metadata_url != normalized_seed_url:
    FAIL with "URL mismatch: metadata says X but seed specifies Y"
ELSE:
  SKIP validation (FR-017)
```

## Identity and Uniqueness

- **Seed identity**: `{language}/{name}/{version}` (e.g., `rust/serde/1.0.228`)
- **Processor identity**: `{processor-name}-{package-name}-{version}` (e.g., `package-download-serde-1.0.228`)
- **Derivation uniqueness**: Content-addressed via Nix store paths
