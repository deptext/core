# core Development Guidelines

Auto-generated from all feature plans. Last updated: 2025-11-30

## Active Technologies
- YAML (GitHub Actions), Bash (shell scripts) + cachix/install-nix-action (Nix installer), actions/checkout, GitHub CLI (gh) (002-github-action-bloom)
- N/A (artifacts stored in git) (002-github-action-bloom)

- Nix (flakes-enabled, requires Nix 2.4+) + Nix builtins (fetchurl, fetchFromGitHub), jq for JSON processing, coreutils for file operations (001-nix-processor-pipeline)

## Project Structure

```text
src/
tests/
```

## Commands

# Add commands for Nix (flakes-enabled, requires Nix 2.4+)

## Code Style

Nix (flakes-enabled, requires Nix 2.4+): Follow standard conventions

## Recent Changes
- 002-github-action-bloom: Added YAML (GitHub Actions), Bash (shell scripts) + cachix/install-nix-action (Nix installer), actions/checkout, GitHub CLI (gh)

- 001-nix-processor-pipeline: Added Nix (flakes-enabled, requires Nix 2.4+) + Nix builtins (fetchurl, fetchFromGitHub), jq for JSON processing, coreutils for file operations

## Coding Conventions

### IMPORTANT: High level rules (all languages)

This is a new and modern (2025) project being built by passionate experts with lots of resources.
- NEVER over engineer the solution (keep code as simple as possible).
- MUST write code which is easy to understand and maintain (do not optimize for performance).
- NEVER create code debt (take your time and clean up as you go).
- NEVER maintain backwards compatibility or add any deprecation notices (this is a new project).
- NEVER over engineer the solution (keep code simple, no scope creep).
- ALWAYS write extremely modular code (makes code easier to understand and allows the project to grow in complexity over time).
- ALWAYS write code for ONLY the most modern version of browsers, tools and hardware (we control all the deployment targets).

### IMPORTANT: Code Comments (all languages)

All code MUST include extensive, beginner-friendly comments:
- MUST explain both WHAT the code does and WHY it's doing it
- MUST define all jargon and technical terms in plain English
- MUST be written as if explaining to a 16-year-old with no programming experience
- NEVER assume the reader knows the language, framework, or domain concepts
- When in doubt, add MORE comments - over-explaining is better than under-explaining

Example of good commenting style:
```nix
# A "derivation" is Nix's word for a build recipe - it describes how to
# create something (like compiled code or documentation) from source files.
# Think of it like a cooking recipe: it lists ingredients (inputs) and
# steps (build commands) to produce a dish (output).
mkDerivation {
  # "pname" means "package name" - the human-readable name for this software
  pname = "my-package";

  # The version number helps us track which release this is
  version = "1.0.0";
}
```
