# Seed: requests 2.31.0
#
# Build with: bloom ./seed.nix

{ deptext }:

deptext.mkPythonPackage {
  pname = "requests";
  version = "2.31.0";
  hash = "sha256:1qfidaynsrci4wymrw3srz8v1zy7xxpcna8sxpm91mwqixsmlb4l";
  github = {
    owner = "psf";
    repo = "requests";
    rev = "v2.31.0";
    hash = "sha256:0pxl0rnz9ks0fa642dxk7awf1pbipsq99ryhxfhsy3r3dfkvk8wi";
  };
}
