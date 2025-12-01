#!/usr/bin/env bash
# Integration Test: Python Package Seed
#
# This script tests the end-to-end pipeline for Python packages.
# It builds the requests example seed and verifies the output.
#
# WHAT THIS TEST VALIDATES:
# 1. The bloom CLI works correctly
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
BLOOM="$REPO_ROOT/bin/bloom"

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

# Test 2: Build the seed using bloom CLI
log_info "Test 2: Building the seed (this may take a while)..."
cd "$EXAMPLE_DIR"

rm -f result

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

# Test 5: Check README.md from finalize processor
log_info "Test 5: Checking for README.md..."
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

# Test 6: Check bloom.json from finalize processor
log_info "Test 6: Checking for bloom.json..."
if [ -f "$STORE_PATH/bloom.json" ]; then
  log_success "bloom.json found!"
  log_info "Contents:"
  cat "$STORE_PATH/bloom.json"
else
  log_fail "bloom.json not found at $STORE_PATH/bloom.json"
  exit 1
fi

# Test 7: Validate bloom.json structure
log_info "Test 7: Validating bloom.json structure..."
BLOOM_FILE="$STORE_PATH/bloom.json"

if command -v jq &> /dev/null; then
  BLOOM_PNAME=$(jq -r '.pname' "$BLOOM_FILE" 2>/dev/null)
  BLOOM_VERSION=$(jq -r '.version' "$BLOOM_FILE" 2>/dev/null)
  BLOOM_LANGUAGE=$(jq -r '.language' "$BLOOM_FILE" 2>/dev/null)
  BLOOM_BUILD_DURATION=$(jq -r '.buildDuration' "$BLOOM_FILE" 2>/dev/null)
  BLOOM_PROCESSORS=$(jq -r '.processors | keys | length' "$BLOOM_FILE" 2>/dev/null)

  if [ "$BLOOM_PNAME" = "requests" ]; then
    log_success "bloom.json pname is correct: $BLOOM_PNAME"
  else
    log_fail "bloom.json pname is incorrect: expected 'requests', got '$BLOOM_PNAME'"
    exit 1
  fi

  if [ "$BLOOM_VERSION" = "2.31.0" ]; then
    log_success "bloom.json version is correct: $BLOOM_VERSION"
  else
    log_fail "bloom.json version is incorrect: expected '2.31.0', got '$BLOOM_VERSION'"
    exit 1
  fi

  if [ "$BLOOM_LANGUAGE" = "python" ]; then
    log_success "bloom.json language is correct: $BLOOM_LANGUAGE"
  else
    log_fail "bloom.json language is incorrect: expected 'python', got '$BLOOM_LANGUAGE'"
    exit 1
  fi

  if [ "$BLOOM_BUILD_DURATION" != "null" ] && [ "$BLOOM_BUILD_DURATION" -ge 0 ]; then
    log_success "bloom.json buildDuration is valid: ${BLOOM_BUILD_DURATION}ms"
  else
    log_fail "bloom.json buildDuration is missing or invalid"
    exit 1
  fi

  if [ "$BLOOM_PROCESSORS" -ge 3 ]; then
    log_success "bloom.json has $BLOOM_PROCESSORS processors"
  else
    log_fail "bloom.json should have at least 3 processors, got $BLOOM_PROCESSORS"
    exit 1
  fi
else
  log_warn "jq not found, skipping bloom.json structure validation"
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
echo "README.md: $STORE_PATH/README.md"
echo "bloom.json: $STORE_PATH/bloom.json"
