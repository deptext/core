# Seed Evaluation Wrapper
#
# This file evaluates seed.nix files, providing them with deptext and pkgs.
# It supports both the new function format and legacy format for backwards
# compatibility.
#
# USAGE (via CLI):
#   nix build --impure -f lib/eval-seed.nix --argstr seedPath /path/to/seed.nix
#
# NEW SEED FORMAT (function):
#   { deptext, pkgs }:
#   deptext.mkRustPackage { pname = "serde"; ... }
#
# LEGACY FORMAT (raw expression):
#   let deptext = import ...; pkgs = import <nixpkgs> {}; in
#   deptext.lib.mkRustPackage { ... }

{ seedPath }:

let
  # Import nixpkgs for the current system
  pkgs = import <nixpkgs> {};

  # Import base deptext library
  baseDeptext = import ./. { inherit (pkgs) lib; };

  # Create a wrapper that auto-injects pkgs into all functions
  deptext = {
    mkRustPackage = args: baseDeptext.mkRustPackage ({ inherit pkgs; } // args);
    mkPythonPackage = args: baseDeptext.mkPythonPackage ({ inherit pkgs; } // args);
  };

  # Import the seed file
  seed = import seedPath;

  # Evaluate the seed
  # If it's a function, call it with { deptext }
  # If it's a raw expression, use it as-is (backwards compatibility)
  result =
    if builtins.isFunction seed then
      seed { inherit deptext; }
    else
      seed;

  # Normalize the result
  # New format returns the derivation directly
  # Old format returns { default, processors, meta }
  derivation =
    if result ? default then
      result.default
    else
      result;

in
derivation
