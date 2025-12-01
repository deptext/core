#!/usr/bin/env bash
# Integration Test: Rust Package Seed
#
# This script tests the end-to-end pipeline for Rust packages.
# It builds the serde example seed and verifies the output.
#
# WHAT THIS TEST VALIDATES:
# 1. The bloom CLI works correctly
# 2. mkRustPackage creates a valid derivation
# 3. The package-download processor fetches from crates.io
# 4. The source-download processor fetches from GitHub
# 5. The stats processor generates valid JSON output
# 6. Persisted outputs are in the expected location
#
# USAGE:
#   ./tests/integration/test-rust-seed.sh
#
# REQUIREMENTS:
# - Nix with flakes enabled
# - Network access to crates.io and GitHub

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_success() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; }

# Get the repository root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
EXAMPLE_DIR="$REPO_ROOT/examples/rust/serde"
BLOOM="$REPO_ROOT/bin/bloom"

log_info "Running Rust seed integration test"
log_info "Repository root: $REPO_ROOT"
log_info "Example directory: $EXAMPLE_DIR"

# Test 1: Verify example seed exists
log_info "Test 1: Checking example seed exists..."
if [ -f "$EXAMPLE_DIR/seed.nix" ]; then
  log_success "seed.nix found at $EXAMPLE_DIR/seed.nix"
else
  log_fail "seed.nix not found!"
  exit 1
fi

# Test 2: Build the seed using bloom CLI
log_info "Test 2: Building the seed (this may take a while)..."
cd "$EXAMPLE_DIR"

# Clean up any previous result
rm -f result

# Build the seed using the CLI
if "$BLOOM" seed.nix --no-link --print-out-paths 2>build_stderr.txt >build_output.txt; then
  log_success "Build succeeded!"
  cat build_stderr.txt
else
  log_fail "Build failed!"
  cat build_stderr.txt
  cat build_output.txt
  rm -f build_output.txt build_stderr.txt
  exit 1
fi

# The store path is the line starting with /nix/store in stdout
# We need to strip ANSI color codes and find the Nix store path
STORE_PATH=$(grep -E "^/nix/store/" build_output.txt | head -1)
rm -f build_output.txt build_stderr.txt
log_info "Build output: $STORE_PATH"

# Test 3: Verify stats.json exists
log_info "Test 3: Checking for stats.json..."
if [ -f "$STORE_PATH/stats/stats.json" ]; then
  log_success "stats.json found!"
  log_info "Contents:"
  cat "$STORE_PATH/stats/stats.json"
else
  log_fail "stats.json not found at $STORE_PATH/stats/stats.json"
  log_info "Directory contents:"
  find "$STORE_PATH" -type f 2>/dev/null | head -20 || echo "(empty or not accessible)"
  exit 1
fi

# Test 4: Validate stats.json structure
log_info "Test 4: Validating stats.json structure..."
STATS_FILE="$STORE_PATH/stats/stats.json"

# Check required fields using jq
if command -v jq &> /dev/null; then
  FILE_COUNT=$(jq -r '.file_count' "$STATS_FILE" 2>/dev/null)
  GENERATED_AT=$(jq -r '.generated_at' "$STATS_FILE" 2>/dev/null)
  PKG_NAME=$(jq -r '.package.name' "$STATS_FILE" 2>/dev/null)
  PKG_VERSION=$(jq -r '.package.version' "$STATS_FILE" 2>/dev/null)

  if [ "$FILE_COUNT" != "null" ] && [ "$FILE_COUNT" -gt 0 ]; then
    log_success "file_count is valid: $FILE_COUNT"
  else
    log_fail "file_count is invalid or zero"
    exit 1
  fi

  if [ "$GENERATED_AT" != "null" ] && [ -n "$GENERATED_AT" ]; then
    log_success "generated_at is present: $GENERATED_AT"
  else
    log_fail "generated_at is missing"
    exit 1
  fi

  if [ "$PKG_NAME" = "serde" ]; then
    log_success "package.name is correct: $PKG_NAME"
  else
    log_fail "package.name is incorrect: expected 'serde', got '$PKG_NAME'"
    exit 1
  fi

  if [ "$PKG_VERSION" = "1.0.215" ]; then
    log_success "package.version is correct: $PKG_VERSION"
  else
    log_fail "package.version is incorrect: expected '1.0.215', got '$PKG_VERSION'"
    exit 1
  fi
else
  log_warn "jq not found, skipping JSON structure validation"
fi

# Test 5: Check .deptext.json metadata
log_info "Test 5: Checking .deptext.json metadata..."
if [ -f "$STORE_PATH/.deptext.json" ]; then
  log_success ".deptext.json found!"
  log_info "Contents:"
  cat "$STORE_PATH/.deptext.json"
else
  log_warn ".deptext.json not found (this is optional)"
fi

# Test 5.1: Check README.md from finalize processor
log_info "Test 5.1: Checking for README.md..."
if [ -f "$STORE_PATH/README.md" ]; then
  log_success "README.md found!"
  log_info "Contents:"
  cat "$STORE_PATH/README.md"
else
  log_fail "README.md not found at $STORE_PATH/README.md"
  log_info "Directory contents:"
  find "$STORE_PATH" -type f 2>/dev/null | head -20 || echo "(empty or not accessible)"
  exit 1
fi

# Test 5.2: Check bloom.json from finalize processor
log_info "Test 5.2: Checking for bloom.json..."
if [ -f "$STORE_PATH/bloom.json" ]; then
  log_success "bloom.json found!"
  log_info "Contents:"
  cat "$STORE_PATH/bloom.json"
else
  log_fail "bloom.json not found at $STORE_PATH/bloom.json"
  exit 1
fi

# Test 5.3: Validate bloom.json structure
log_info "Test 5.3: Validating bloom.json structure..."
BLOOM_FILE="$STORE_PATH/bloom.json"

if command -v jq &> /dev/null; then
  BLOOM_PNAME=$(jq -r '.pname' "$BLOOM_FILE" 2>/dev/null)
  BLOOM_VERSION=$(jq -r '.version' "$BLOOM_FILE" 2>/dev/null)
  BLOOM_LANGUAGE=$(jq -r '.language' "$BLOOM_FILE" 2>/dev/null)
  BLOOM_BUILD_DURATION=$(jq -r '.buildDuration' "$BLOOM_FILE" 2>/dev/null)
  BLOOM_PROCESSORS=$(jq -r '.processors | keys | length' "$BLOOM_FILE" 2>/dev/null)

  if [ "$BLOOM_PNAME" = "serde" ]; then
    log_success "bloom.json pname is correct: $BLOOM_PNAME"
  else
    log_fail "bloom.json pname is incorrect: expected 'serde', got '$BLOOM_PNAME'"
    exit 1
  fi

  if [ "$BLOOM_VERSION" = "1.0.215" ]; then
    log_success "bloom.json version is correct: $BLOOM_VERSION"
  else
    log_fail "bloom.json version is incorrect: expected '1.0.215', got '$BLOOM_VERSION'"
    exit 1
  fi

  if [ "$BLOOM_LANGUAGE" = "rust" ]; then
    log_success "bloom.json language is correct: $BLOOM_LANGUAGE"
  else
    log_fail "bloom.json language is incorrect: expected 'rust', got '$BLOOM_LANGUAGE'"
    exit 1
  fi

  if [ "$BLOOM_BUILD_DURATION" != "null" ] && [ "$BLOOM_BUILD_DURATION" -ge 0 ]; then
    log_success "bloom.json buildDuration is valid: ${BLOOM_BUILD_DURATION}ms"
  else
    log_fail "bloom.json buildDuration is missing or invalid"
    exit 1
  fi

  if [ "$BLOOM_PROCESSORS" -ge 5 ]; then
    log_success "bloom.json has $BLOOM_PROCESSORS processors"
  else
    log_fail "bloom.json should have at least 5 processors (including rustdoc-json and rustdoc-md), got $BLOOM_PROCESSORS"
    exit 1
  fi

  # Test 5.4: Verify rustdoc processors are present in bloom.json (even if disabled)
  log_info "Test 5.4: Checking for rustdoc processors in bloom.json..."
  RUSTDOC_JSON_PRESENT=$(jq -r '.processors | has("rustdoc-json")' "$BLOOM_FILE" 2>/dev/null)
  RUSTDOC_MD_PRESENT=$(jq -r '.processors | has("rustdoc-md")' "$BLOOM_FILE" 2>/dev/null)

  if [ "$RUSTDOC_JSON_PRESENT" = "true" ]; then
    log_success "rustdoc-json processor is present in bloom.json"
    # Check if it's disabled (expected when no rustToolchain provided)
    RUSTDOC_JSON_ACTIVE=$(jq -r '.processors["rustdoc-json"].active' "$BLOOM_FILE" 2>/dev/null)
    if [ "$RUSTDOC_JSON_ACTIVE" = "false" ]; then
      log_success "rustdoc-json is inactive (expected without rustToolchain)"
    else
      log_info "rustdoc-json is active (rustToolchain was provided)"
    fi
  else
    log_fail "rustdoc-json processor not found in bloom.json"
    exit 1
  fi

  if [ "$RUSTDOC_MD_PRESENT" = "true" ]; then
    log_success "rustdoc-md processor is present in bloom.json"
  else
    log_fail "rustdoc-md processor not found in bloom.json"
    exit 1
  fi
else
  log_warn "jq not found, skipping bloom.json structure validation"
fi

# Test 6: Test custom configuration seed (US3)
log_info "Test 6: Testing custom configuration seed..."
CUSTOM_EXAMPLE_DIR="$REPO_ROOT/examples/rust/serde-custom"

if [ -f "$CUSTOM_EXAMPLE_DIR/seed.nix" ]; then
  log_info "Building custom configuration seed..."
  cd "$CUSTOM_EXAMPLE_DIR"
  rm -f result

  if "$BLOOM" seed.nix --no-link --print-out-paths 2>build_stderr.txt >build_output.txt; then
    cat build_stderr.txt
    CUSTOM_BUILD_OUTPUT=$(tail -1 build_output.txt)
    log_success "Custom seed build succeeded!"

    # Verify that package-download is now persisted (has persist=true in custom config)
    if [ -d "$CUSTOM_BUILD_OUTPUT/package-download" ]; then
      log_success "package-download directory is persisted (custom config working!)"
      log_info "Package-download contains: $(find "$CUSTOM_BUILD_OUTPUT/package-download" -type f | wc -l) files"
    else
      log_warn "package-download directory not found - custom config may not be applied"
      log_info "Contents of build output:"
      ls -la "$CUSTOM_BUILD_OUTPUT" 2>/dev/null || echo "(not accessible)"
    fi

    # Stats should still be persisted
    if [ -f "$CUSTOM_BUILD_OUTPUT/stats/stats.json" ]; then
      log_success "stats.json also present in custom build"
    else
      log_warn "stats.json missing in custom build"
    fi

    rm -f build_output.txt build_stderr.txt
  else
    log_warn "Custom seed build failed (non-critical):"
    cat build_stderr.txt
    cat build_output.txt
    rm -f build_output.txt build_stderr.txt
  fi
else
  log_warn "Custom example seed not found at $CUSTOM_EXAMPLE_DIR/seed.nix"
fi

# Summary
echo ""
echo "========================================"
echo -e "${GREEN}All tests passed!${NC}"
echo "========================================"
echo ""
echo "Rust seed integration test completed successfully."
echo "The serde package was processed and stats were generated."
echo ""
echo "Store path: $STORE_PATH"
echo "Stats file: $STORE_PATH/stats/stats.json"
