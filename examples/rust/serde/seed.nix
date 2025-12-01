# Seed: serde 1.0.215
#
# Build with: deptext build ./seed.nix
# Or: nix build --impure -f ../../../lib/eval-seed.nix --argstr seedPath $PWD/seed.nix

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
