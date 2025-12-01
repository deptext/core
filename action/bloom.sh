#!/usr/bin/env bash
# action/bloom.sh - Main script for the DepText Bloom GitHub Action
#
# This script is the "brains" of the GitHub Action. It runs after the repository
# is checked out and Nix is installed. Its job is to:
#
# 1. DETECT: Find which seed.nix files changed in the pull request
# 2. VALIDATE: Ensure exactly one seed.nix was changed (or skip/fail appropriately)
# 3. BLOOM: Run the deptext bloom tool to process the seed
# 4. COMMIT: Push the generated artifacts back to the PR branch
#
# The script uses "GitHub CLI" (gh) to talk to GitHub's API, and standard
# git commands to commit changes. Both are pre-installed on GitHub runners.

# -----------------------------------------------------------------------------
# SHELL CONFIGURATION
# -----------------------------------------------------------------------------
# These settings make the script safer and easier to debug:
#
# -e = "exit on error" - if ANY command fails, the whole script stops
#      (prevents continuing after something broke)
# -u = "undefined variables are errors" - typos in variable names cause failures
#      (prevents silent bugs from misspelled variables)
# -o pipefail = "pipe failures count as errors" - if `cmd1 | cmd2` runs and cmd1
#      fails, the whole pipeline is considered failed
#      (prevents hiding errors in the middle of pipes)
set -euo pipefail

# -----------------------------------------------------------------------------
# USER STORY 3: LOGGING FUNCTIONS
# -----------------------------------------------------------------------------
# These functions print messages with prefixes to make logs easier to read.
# The prefixes help users quickly scan logs to find what they need.
#
# Example output:
#   [bloom] Detecting seed.nix files in PR...
#   [bloom] ✓ Found 1 seed: examples/rust/serde/seed.nix

# log() - Print an informational message
#
# Arguments:
#   $1 = The message to print
#
# Example: log "Starting bloom process"
# Output:  [bloom] Starting bloom process
log() {
    echo "[bloom] $1"
}

# log_success() - Print a success message with a checkmark
#
# Arguments:
#   $1 = The message to print
#
# Example: log_success "Artifacts committed"
# Output:  [bloom] ✓ Artifacts committed
log_success() {
    echo "[bloom] ✓ $1"
}

# log_error() - Print an error message with an X mark
#
# Arguments:
#   $1 = The message to print
#
# Example: log_error "Multiple seeds detected"
# Output:  [bloom] ✗ Multiple seeds detected
log_error() {
    echo "[bloom] ✗ $1" >&2
}

# -----------------------------------------------------------------------------
# USER STORY 2: SEED FILE DETECTION
# -----------------------------------------------------------------------------
# This section detects which seed.nix files were changed in the PR.
# It uses the GitHub CLI (`gh`) to query the GitHub API.

# detect_seed_files() - Find all seed.nix files changed in the current PR
#
# This function queries GitHub's API to get the list of files changed in the PR,
# then filters to only files named exactly "seed.nix" (in any directory).
#
# Returns: A newline-separated list of seed.nix paths (may be empty)
#
# How it works:
#   1. `gh pr view` fetches PR metadata as JSON
#   2. `--json files` asks for just the file list (not the whole PR object)
#   3. `jq` filters the JSON:
#      - `.files[]` iterates over each file in the array
#      - `select(.path | endswith("/seed.nix") or . == "seed.nix")` keeps only
#        files named exactly "seed.nix" (handles root and nested paths)
#      - `.path` extracts just the path string
#   4. `--raw-output` removes JSON quotes from the output
#
# Example output:
#   examples/rust/serde/seed.nix
#   examples/python/requests/seed.nix
detect_seed_files() {
    # gh pr view: Get information about the current PR
    # --json files: We only need the list of changed files
    # jq: Filter and transform the JSON response
    gh pr view --json files --jq '
        .files[]
        | select(.path | endswith("/seed.nix") or . == "seed.nix")
        | .path
    '
}

# validate_seed_count() - Check that exactly 0 or 1 seed files exist
#
# Arguments:
#   $1 = Newline-separated list of seed paths (output from detect_seed_files)
#
# Returns:
#   exit 0 with "skip" on stdout if no seeds (action should exit early)
#   exit 0 with path on stdout if exactly one seed (continue processing)
#   exit 1 with error message if multiple seeds (action should fail)
#
# This validation is critical because:
# - 0 seeds: The PR doesn't contain seed changes, so there's nothing to do
# - 1 seed: Perfect! We can process this seed and commit artifacts
# - 2+ seeds: Ambiguous - which seed should we process? We fail to be safe.
validate_seed_count() {
    local seeds="$1"

    # Count non-empty lines (each line is a seed path)
    # `wc -l` counts lines, but we need to handle empty input specially
    local count
    if [[ -z "$seeds" ]]; then
        count=0
    else
        count=$(echo "$seeds" | wc -l | tr -d ' ')
    fi

    # Handle each case according to the state machine in data-model.md
    case "$count" in
        0)
            # No seeds changed - this is fine, just skip processing
            log "No seed.nix files found in PR changes"
            log_success "Skipping - nothing to bloom"
            echo "skip"
            ;;
        1)
            # Exactly one seed - perfect, return its path for processing
            # `head -1` is redundant here but makes the intent clear
            local seed_path
            seed_path=$(echo "$seeds" | head -1)
            log_success "Found 1 seed: $seed_path"
            echo "$seed_path"
            ;;
        *)
            # Multiple seeds - we can't decide which to process, so fail
            # List all found seeds to help the user understand the problem
            log_error "Multiple seed.nix files detected in PR:"
            echo "$seeds" | while read -r seed; do
                log_error "  - $seed"
            done
            log_error ""
            log_error "The bloom action processes one seed at a time."
            log_error "Please split your changes into separate PRs."
            exit 1
            ;;
    esac
}

# -----------------------------------------------------------------------------
# USER STORY 1: BLOOM PROCESSING
# -----------------------------------------------------------------------------
# This section handles running the bloom tool and committing artifacts.

# get_seed_directory() - Extract the directory containing a seed file
#
# Arguments:
#   $1 = Full path to a seed.nix file (e.g., "examples/rust/serde/seed.nix")
#
# Returns: The directory path (e.g., "examples/rust/serde")
#
# This is needed because bloom outputs go to a "result" symlink, and we need
# to copy them to the same directory as the seed.nix file.
get_seed_directory() {
    local seed_path="$1"
    # dirname extracts the directory part of a path
    # "examples/rust/serde/seed.nix" -> "examples/rust/serde"
    dirname "$seed_path"
}

# run_bloom() - Execute the deptext bloom tool on a seed file
#
# Arguments:
#   $1 = Path to the seed.nix file to process
#
# The bloom tool (located at $ACTION_PATH/bin/bloom) is a Nix-based tool that:
# 1. Reads the seed.nix file to understand what package to process
# 2. Downloads the package source code
# 3. Analyzes the package and generates statistics
# 4. Outputs results to a "result" symlink (Nix convention)
#
# If bloom fails (bad hash, network error, etc.), the script will exit due to
# `set -e`, and the GitHub Action will show the failure.
run_bloom() {
    local seed_path="$1"
    log "Running bloom on $seed_path..."

    # ACTION_PATH is set by action.yml to point to the deptext/core repo
    # This is where bin/bloom lives, not in the consumer's repo
    #
    # We pass the seed path as an argument to bin/bloom
    # The seed is in the consumer's repo (current directory)
    "$ACTION_PATH/bin/bloom" "$seed_path"

    log_success "Bloom completed"
}

# copy_artifacts() - Move bloom results from result/ to seed directory
#
# Arguments:
#   $1 = Path to the seed directory (where seed.nix lives)
#
# After bloom runs, outputs appear in ./result/ (a Nix symlink).
# We need to copy them to the seed's directory so they're committed
# alongside the seed.nix file.
#
# Example:
#   result/stats/stats.json -> examples/rust/serde/stats/stats.json
copy_artifacts() {
    local seed_dir="$1"
    log "Copying artifacts to $seed_dir..."

    # Check if result directory exists and has contents
    if [[ ! -d "result" ]] || [[ -z "$(ls -A result 2>/dev/null)" ]]; then
        log "No artifacts produced by bloom"
        return 0
    fi

    # Copy all files from result/ to the seed directory
    # -r = recursive (copy directories)
    # -L = follow symlinks (result is a symlink, and may contain symlinks)
    # Using a loop to handle each item individually for clarity
    for item in result/*; do
        if [[ -e "$item" ]]; then
            # Get just the filename/dirname from the path
            local name
            name=$(basename "$item")
            # Copy recursively, dereferencing symlinks
            cp -rL "$item" "$seed_dir/$name"
        fi
    done

    log_success "Artifacts copied to $seed_dir"
}

# check_for_changes() - Determine if there are any uncommitted changes
#
# Returns: exit code 0 if there ARE changes, exit code 1 if clean
#
# `git status --porcelain` outputs one line per changed file, or nothing
# if the working tree is clean. We use this to decide whether to commit.
check_for_changes() {
    # --porcelain gives machine-readable output (one file per line)
    # If the output is non-empty, there are changes
    [[ -n "$(git status --porcelain)" ]]
}

# commit_and_push() - Stage, commit, and push artifact changes
#
# Arguments:
#   $1 = Path to the seed file (used in commit message)
#
# This function:
# 1. Configures git with the github-actions bot identity
# 2. Stages all changed files
# 3. Creates a commit with a descriptive message
# 4. Pushes to the PR branch
#
# If push fails (e.g., fork PR), it calls handle_push_failure() for a
# helpful error message instead of a cryptic git error.
commit_and_push() {
    local seed_path="$1"
    log "Committing artifacts..."

    # Configure git identity
    # These are the standard values used by GitHub Actions bots
    # This appears as the commit author in git history
    git config user.name "github-actions[bot]"
    git config user.email "github-actions[bot]@users.noreply.github.com"

    # Stage all changes
    # We use "." to stage everything - bloom only produces expected artifacts
    git add .

    # Create the commit
    # Message format: "chore: bloom artifacts for <seed-path>"
    # "chore:" prefix follows conventional commits (non-feature, non-fix change)
    local commit_message="chore: bloom artifacts for $seed_path"
    git commit -m "$commit_message"

    log "Pushing to branch..."

    # Push to the remote branch
    # If this fails, we catch it and provide a helpful message
    if ! git push; then
        handle_push_failure
        exit 1
    fi

    log_success "Artifacts committed and pushed"
}

# -----------------------------------------------------------------------------
# USER STORY 3: ERROR HANDLING
# -----------------------------------------------------------------------------
# These functions provide clear, actionable feedback when things go wrong.

# handle_push_failure() - Provide helpful message when push fails
#
# Push failures usually happen when:
# 1. Fork PRs - External contributors can't receive pushes from base repo
# 2. Branch protection - Unusual, but possible
# 3. Token permission issues - Consumer didn't set contents: write
#
# This function detects fork PRs and provides specific guidance.
handle_push_failure() {
    log_error "Failed to push commits to the PR branch"
    log_error ""

    # Check if this is a fork PR by comparing head repo with base repo
    # Fork PRs have different head.repo.owner than base.repo.owner
    local is_fork
    is_fork=$(gh pr view --json headRepositoryOwner,baseRepository --jq '
        if .headRepositoryOwner.login != .baseRepository.owner.login then "true" else "false" end
    ')

    if [[ "$is_fork" == "true" ]]; then
        log_error "This appears to be a PR from a fork."
        log_error ""
        log_error "GitHub security restrictions prevent pushing commits to fork branches."
        log_error "To add bloom artifacts, please run locally:"
        log_error ""
        log_error "  ./bin/bloom path/to/seed.nix"
        log_error "  cp -r result/* path/to/seed-directory/"
        log_error "  git add . && git commit -m 'chore: add bloom artifacts'"
        log_error "  git push"
    else
        log_error "This might be a permissions issue."
        log_error ""
        log_error "Ensure your workflow has:"
        log_error "  permissions:"
        log_error "    contents: write"
    fi
}

# cleanup_on_failure() - Clean up temporary files when something fails
#
# This is called by the trap (see below) when the script exits with an error.
# It removes the result directory to avoid leaving artifacts from a failed run.
cleanup_on_failure() {
    local exit_code=$?

    # Only clean up if we failed (non-zero exit)
    if [[ $exit_code -ne 0 ]]; then
        log "Cleaning up after failure..."

        # Remove result directory if it exists
        if [[ -d "result" ]]; then
            rm -rf result
        fi

        # Reset any staged changes to avoid partial commits
        git reset --quiet HEAD 2>/dev/null || true
    fi

    exit $exit_code
}

# Set up the cleanup trap
# This runs cleanup_on_failure whenever the script exits (success or failure)
# ERR = run on any command error
# EXIT = run when script finishes
trap cleanup_on_failure EXIT

# -----------------------------------------------------------------------------
# MAIN EXECUTION
# -----------------------------------------------------------------------------
# This is where the script actually runs. It calls the functions defined above
# in the correct order to implement the bloom workflow.

main() {
    log "Starting DepText Bloom Action"
    log "================================"

    # Step 1: Detect seed files in the PR
    log "Detecting seed.nix files in PR..."
    local seed_files
    seed_files=$(detect_seed_files)

    # Step 2: Validate seed count (exits if 0 or >1)
    local validation_result
    validation_result=$(validate_seed_count "$seed_files")

    # If validation returned "skip", exit successfully
    if [[ "$validation_result" == "skip" ]]; then
        exit 0
    fi

    # At this point, validation_result contains the single seed path
    local seed_path="$validation_result"
    local seed_dir
    seed_dir=$(get_seed_directory "$seed_path")

    # Step 3: Run bloom
    log "Processing seed..."
    run_bloom "$seed_path"

    # Step 4: Copy artifacts to seed directory
    copy_artifacts "$seed_dir"

    # Step 5: Commit and push (if there are changes)
    if check_for_changes; then
        commit_and_push "$seed_path"
    else
        log_success "No changes to commit - artifacts already up to date"
    fi

    log "================================"
    log_success "DepText Bloom Action completed"
}

# Run main function
main
