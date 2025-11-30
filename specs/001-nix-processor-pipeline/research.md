# Research: DepText MVP - Nix Processor Pipeline

**Date**: 2025-11-30
**Branch**: `001-nix-processor-pipeline`

## Decision Summary

| Topic | Decision | Rationale |
|-------|----------|-----------|
| Flake structure | Export lib functions + per-system packages | Standard pattern for library flakes; lib for helpers, packages for examples |
| crates.io fetching | Use `fetchurl` with crates.io download API | Direct URL pattern: `https://crates.io/api/v1/crates/{name}/{version}/download` |
| PyPI fetching | Use `fetchurl` with PyPI source URL | Pattern: `https://pypi.io/packages/source/{first_letter}/{name}/{name}-{version}.tar.gz` |
| GitHub fetching | Use `fetchFromGitHub` | Built-in, handles extraction, supports rev/tag specification |
| Processor dependencies | Reference derivation outputs in buildInputs | Nix automatically resolves transitive closure |
| Hash management | Provide helper script using nix-prefetch-url | Users need hashes for reproducible builds |
| Parallel execution | Automatic via Nix | Independent derivations build in parallel by default |

## Research Findings

### 1. Nix Flake Library Structure

**Best Practice**: Export library functions via the `lib` attribute and use `flake-utils` for multi-system support.

```nix
{
  description = "DepText - Package processing pipeline";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    {
      # System-independent library functions
      lib = import ./lib { inherit (nixpkgs) lib; };
    } // flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        # System-specific packages (examples, tests)
        packages = { ... };
      }
    );
}
```

**Key Insight**: Language helpers like `mkRustPackage` should take `pkgs` as a parameter so they work across systems.

### 2. Fetching from crates.io

**API Endpoint**: `https://crates.io/api/v1/crates/{crate_name}/{version}/download`

**Alternative**: `https://static.crates.io/crates/{crate_name}/{version}/download`

**Implementation**:
```nix
fetchRustPackage = { pkgs, name, version, hash }:
  pkgs.fetchzip {
    name = "${name}-${version}";
    url = "https://crates.io/api/v1/crates/${name}/${version}/download";
    inherit hash;
  };
```

**Metadata**: crates.io provides JSON metadata at:
`https://crates.io/api/v1/crates/{name}/{version}`

Contains: repository URL, description, dependencies, etc.

### 3. Fetching from PyPI

**URL Pattern**: `https://pypi.io/packages/source/{first_letter}/{name}/{name}-{version}.tar.gz`

**Implementation**:
```nix
fetchPythonPackage = { pkgs, name, version, hash }:
  pkgs.fetchurl {
    url = "https://pypi.io/packages/source/${builtins.substring 0 1 name}/${name}/${name}-${version}.tar.gz";
    inherit hash;
    name = "${name}-${version}.tar.gz";
  };
```

**Metadata**: PyPI JSON API at:
`https://pypi.org/pypi/{name}/{version}/json`

Contains: project URLs (including repository), description, etc.

### 4. Fetching from GitHub

**Built-in Function**: `fetchFromGitHub`

```nix
fetchGitHubSource = { pkgs, owner, repo, rev, hash }:
  pkgs.fetchFromGitHub {
    inherit owner repo rev hash;
  };
```

**Tag vs Commit**: Use `rev = "v${version}"` for tags or full commit hash for specific commits.

**Submodules**: Add `fetchSubmodules = true` if needed (not required for MVP).

### 5. Processor Dependency Tree Pattern

**How It Works**: Derivations reference outputs from other derivations. Nix automatically:
- Builds dependencies before dependents
- Builds independent derivations in parallel
- Tracks the full transitive closure

**Implementation Pattern**:
```nix
# Base processor
packageDownload = pkgs.stdenv.mkDerivation {
  name = "package-download";
  # ... outputs package content + metadata.json
  outputs = [ "out" ];
};

# Dependent processor - references packageDownload output
sourceDownload = pkgs.stdenv.mkDerivation {
  name = "source-download";

  # This creates a dependency edge
  buildInputs = [ packageDownload ];

  buildPhase = ''
    # Access packageDownload output via its store path
    metadata=$(cat ${packageDownload}/metadata.json)
    # ... validate and download source
  '';
};

# Final processor - depends on both
stats = pkgs.stdenv.mkDerivation {
  name = "stats";
  buildInputs = [ packageDownload sourceDownload ];
  # ...
};
```

### 6. Persist Mechanism

**Challenge**: Nix builds are pure; they can't write outside the store during build.

**Solution**: Use a wrapper derivation or post-build script.

**Option A - Wrapper Derivation** (recommended for MVP):
```nix
mkPackageWithPersist = { processors, seedDir }:
  pkgs.stdenv.mkDerivation {
    name = "persist-outputs";

    # Depend on all processors
    buildInputs = builtins.attrValues processors;

    buildPhase = ''
      # Collect outputs from processors with persist = true
      mkdir -p $out
      ${lib.concatMapStrings (p:
        if p.persist or false then ''
          cp -r ${p}/* $out/${p.name}/
        '' else ""
      ) processors}
    '';
  };
```

**Option B - Post-build copy** (using nix build + cp):
The `nix build` result can be copied after build completion. This is simpler for MVP.

### 7. Hash Management

**Getting hashes** for fixed-output derivations:

```bash
# For URLs (returns hash to stdout)
nix-prefetch-url "https://crates.io/api/v1/crates/serde/1.0.228/download"

# For GitHub repos
nix-prefetch-github serde-rs serde --rev v1.0.228

# Or use empty hash and get from error message
hash = "";  # Error will show: got: sha256-xxx...
```

**Implication for seeds**: Users must provide hashes in seed.nix, or we use `builtins.fetchurl` without hash for impure builds (not recommended).

### 8. Error Handling

**Nix Behavior**: Any derivation failure stops dependent builds. This matches FR-011 (processor failure = build failure).

**Clear Errors**: Use `builtins.abort` or `throw` for validation errors:
```nix
if metadataUrl != seedUrl then
  throw "URL mismatch: metadata says ${metadataUrl} but seed specifies ${seedUrl}"
else
  # proceed
```

## Alternatives Considered

### Alternative 1: Custom Nix Daemon for Persistence

**Rejected Because**: Over-engineering. Simple post-build copy is sufficient for MVP.

### Alternative 2: Using `nix run` Instead of `nix build`

**Rejected Because**: `nix build` is simpler and matches spec requirement (FR-007).

### Alternative 3: Impure Builds (no hashes)

**Rejected Because**: While reproducibility isn't a goal, hashes provide content verification and caching benefits.

## Open Questions (Resolved)

| Question | Resolution |
|----------|------------|
| How to extract GitHub owner/repo from URL? | Parse with regex or builtins.match in Nix |
| How to handle crates.io rate limiting? | Not an issue for single package builds; document in errors |
| How to validate URL match? | Compare normalized URLs after fetching metadata |

## Next Steps

1. Implement flake.nix with lib exports
2. Create package-download processors (Rust, Python)
3. Create source-download processor with URL validation
4. Create stats processor
5. Create language helper functions (mkRustPackage, mkPythonPackage)
6. Create persist utility for copying outputs
7. Create example seeds for testing
