#!/usr/bin/env bash
# Integration Test: Python Package Seed
#
# This script tests the end-to-end pipeline for Python packages.
# It builds the requests example seed and verifies the output.
#
# WHAT THIS TEST VALIDATES:
# 1. mkPythonPackage creates a valid derivation
# 2. The package-download processor fetches from PyPI
# 3. The source-download processor fetches from GitHub
# 4. The stats processor generates valid JSON output
# 5. Persisted outputs are in the expected location
#
# USAGE:
#   ./tests/integration/test-python-seed.sh

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_success() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; }

# Get paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
EXAMPLE_DIR="$REPO_ROOT/examples/python/requests"

log_info "Running Python seed integration test"
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

# Test 2: Build the seed
log_info "Test 2: Building the seed (this may take a while)..."
cd "$EXAMPLE_DIR"

rm -f result

if nix build -f seed.nix --impure --no-link --print-out-paths > build_output.txt 2>&1; then
  BUILD_OUTPUT=$(cat build_output.txt)
  log_success "Build succeeded!"
  log_info "Build output: $BUILD_OUTPUT"
else
  log_fail "Build failed!"
  cat build_output.txt
  rm -f build_output.txt
  exit 1
fi

rm -f build_output.txt
STORE_PATH="$BUILD_OUTPUT"

# Test 3: Verify stats.json exists
log_info "Test 3: Checking for stats.json..."
if [ -f "$STORE_PATH/stats/stats.json" ]; then
  log_success "stats.json found!"
  log_info "Contents:"
  cat "$STORE_PATH/stats/stats.json"
else
  log_fail "stats.json not found at $STORE_PATH/stats/stats.json"
  log_info "Directory contents:"
  find "$STORE_PATH" -type f 2>/dev/null | head -20 || echo "(empty)"
  exit 1
fi

# Test 4: Validate stats.json structure
log_info "Test 4: Validating stats.json structure..."
STATS_FILE="$STORE_PATH/stats/stats.json"

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

  if [ "$PKG_NAME" = "requests" ]; then
    log_success "package.name is correct: $PKG_NAME"
  else
    log_fail "package.name is incorrect: expected 'requests', got '$PKG_NAME'"
    exit 1
  fi

  if [ "$PKG_VERSION" = "2.31.0" ]; then
    log_success "package.version is correct: $PKG_VERSION"
  else
    log_fail "package.version is incorrect: expected '2.31.0', got '$PKG_VERSION'"
    exit 1
  fi
else
  log_warn "jq not found, skipping JSON structure validation"
fi

# Summary
echo ""
echo "========================================"
echo -e "${GREEN}All tests passed!${NC}"
echo "========================================"
echo ""
echo "Python seed integration test completed successfully."
echo "The requests package was processed and stats were generated."
echo ""
echo "Store path: $STORE_PATH"
echo "Stats file: $STORE_PATH/stats/stats.json"
