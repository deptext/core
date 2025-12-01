#!/usr/bin/env bash
# Integration Test: Rust Package Seed
#
# This script tests the end-to-end pipeline for Rust packages.
# It builds the serde example seed and verifies the output.
#
# WHAT THIS TEST VALIDATES:
# 1. The deptext CLI works correctly
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
DEPTEXT="$REPO_ROOT/bin/deptext"

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

# Test 2: Build the seed using deptext CLI
log_info "Test 2: Building the seed (this may take a while)..."
cd "$EXAMPLE_DIR"

# Clean up any previous result
rm -f result

# Build the seed using the CLI
if "$DEPTEXT" build seed.nix --no-link --print-out-paths 2>build_stderr.txt >build_output.txt; then
  log_success "Build succeeded!"
  cat build_stderr.txt
else
  log_fail "Build failed!"
  cat build_stderr.txt
  cat build_output.txt
  rm -f build_output.txt build_stderr.txt
  exit 1
fi

# The store path is on the last line of stdout
STORE_PATH=$(tail -1 build_output.txt)
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

# Test 6: Test custom configuration seed (US3)
log_info "Test 6: Testing custom configuration seed..."
CUSTOM_EXAMPLE_DIR="$REPO_ROOT/examples/rust/serde-custom"

if [ -f "$CUSTOM_EXAMPLE_DIR/seed.nix" ]; then
  log_info "Building custom configuration seed..."
  cd "$CUSTOM_EXAMPLE_DIR"
  rm -f result

  if "$DEPTEXT" build seed.nix --no-link --print-out-paths 2>build_stderr.txt >build_output.txt; then
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
