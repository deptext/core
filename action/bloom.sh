#!/usr/bin/env bash
# action/bloom.sh - Main entry point for the DepText Bloom GitHub Action
#
# This script orchestrates the bloom workflow:
# 1. Detect seed.nix files in the PR
# 2. Validate exactly one seed exists
# 3. Run bloom to process the seed
# 4. Commit artifacts back to the PR
#
# Each step is implemented in a separate module under lib/ for clarity.

set -euo pipefail

# -----------------------------------------------------------------------------
# SETUP
# -----------------------------------------------------------------------------

# Resolve the directory containing this script (works even when sourced)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load modules
source "$SCRIPT_DIR/lib/log.sh"
source "$SCRIPT_DIR/lib/detect.sh"
source "$SCRIPT_DIR/lib/process.sh"
source "$SCRIPT_DIR/lib/git.sh"

# -----------------------------------------------------------------------------
# CLEANUP
# -----------------------------------------------------------------------------

# cleanup_on_failure() - Clean up temporary files when something fails
#
# Removes result directory and resets staged changes to avoid partial state.
cleanup_on_failure() {
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        log "Cleaning up after failure..."
        [[ -d "result" ]] && rm -rf result
        git reset --quiet HEAD 2>/dev/null || true
    fi

    exit $exit_code
}

trap cleanup_on_failure EXIT

# -----------------------------------------------------------------------------
# MAIN
# -----------------------------------------------------------------------------

main() {
    log "Starting DepText Bloom Action"
    log "================================"

    # Step 1: Detect and validate seed files
    log "Detecting seed.nix files in PR..."
    local seed_path
    seed_path=$(detect_and_validate)

    # Exit early if no seeds to process
    [[ "$seed_path" == "skip" ]] && exit 0

    # Step 2: Process the seed
    log "Processing seed..."
    process_seed "$seed_path"

    # Step 3: Commit if there are changes
    commit_if_changed "$seed_path"

    log "================================"
    log_success "DepText Bloom Action completed"
}

main
