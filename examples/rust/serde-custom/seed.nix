# Seed: serde 1.0.215 (with custom processor config)
#
# This example shows how to override processor defaults:
# - package-download: persist = true (normally false)
# - source-download: disabled
#
# Build with: deptext build ./seed.nix

{ deptext }:

deptext.mkRustPackage {
  pname = "serde";
  version = "1.0.215";

  github = {
    owner = "serde-rs";
    repo = "serde";
    rev = "v1.0.215";
    hash = "sha256:0qaz2mclr5cv3s5riag6aj3n3avirirnbi7sxpq4nw1vzrq09j6l";
  };

  hashes = {
    package = "sha256:04xwh16jm7szizkkhj637jv23i5x8jnzcfrw6bfsrssqkjykaxcm";
    source = "sha256:0qaz2mclr5cv3s5riag6aj3n3avirirnbi7sxpq4nw1vzrq09j6l";
  };

  processors = {
    package-download = { persist = true; };
    source-download = { enabled = false; };
  };
}
