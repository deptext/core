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
