#!/usr/bin/env bash
# action/lib/process.sh - Bloom processing and artifact handling
#
# This module handles running the bloom tool and copying artifacts
# to the appropriate location.

# get_seed_directory() - Extract the directory containing a seed file
#
# Arguments:
#   $1 = Full path to a seed.nix file
#
# Returns: The directory path
#
# Example:
#   get_seed_directory "examples/rust/serde/seed.nix"
#   # Returns: examples/rust/serde
get_seed_directory() {
    dirname "$1"
}

# run_bloom() - Execute the deptext bloom tool on a seed file
#
# Arguments:
#   $1 = Path to the seed.nix file to process
#
# Returns: The Nix store path of the build output (via stdout)
#
# Uses `nix build --json` which outputs structured JSON containing the store
# paths. This is the recommended Nix way to programmatically get build outputs,
# rather than parsing human-readable log messages.
#
# Requires: ACTION_PATH environment variable pointing to deptext/core repo
run_bloom() {
    local seed_path="$1"
    local seed_dir
    seed_dir=$(dirname "$seed_path")
    local seed_abs_path
    seed_abs_path=$(cd "$seed_dir" && pwd)/$(basename "$seed_path")

    log "Running bloom on $seed_path..."

    # Use nix build --json to get structured output
    # The JSON contains: [{"outputs":{"out":"/nix/store/..."}}]
    local build_json
    build_json=$(nix build \
        --impure \
        --no-link \
        --json \
        --file "$ACTION_PATH/lib/eval-seed.nix" \
        --argstr seedPath "$seed_abs_path" \
        2>&1)

    # Extract the store path from JSON using jq
    local store_path
    store_path=$(echo "$build_json" | jq -r '.[0].outputs.out // empty' 2>/dev/null)

    if [[ -z "$store_path" ]]; then
        log "Build output:"
        echo "$build_json"
        log "ERROR: Could not extract store path from build output"
        return 1
    fi

    log_success "Bloom completed: $store_path"
    echo "$store_path"
}

# copy_artifacts() - Copy bloom results from store path to seed directory
#
# Arguments:
#   $1 = Nix store path containing build output
#   $2 = Path to the seed directory
#
# Copies everything from the Nix store path to the seed's directory so
# artifacts live alongside the seed.nix file.
copy_artifacts() {
    local store_path="$1"
    local seed_dir="$2"
    log "Copying artifacts from $store_path to $seed_dir..."

    # Check if store path exists
    if [[ ! -d "$store_path" ]]; then
        log "ERROR: Store path does not exist: $store_path"
        return 1
    fi

    # List contents for debugging
    log "Store path contents:"
    ls -la "$store_path" 2>&1 | while read -r line; do log "  $line"; done

    # Check if store path has contents
    if [[ -z "$(ls -A "$store_path" 2>/dev/null)" ]]; then
        log "WARNING: Store path is empty"
        return 0
    fi

    # Copy all files, dereferencing symlinks
    local copied=0
    for item in "$store_path"/*; do
        if [[ -e "$item" ]]; then
            local name
            name=$(basename "$item")
            log "  Copying: $name"
            cp -rL "$item" "$seed_dir/$name"
            ((copied++))
        fi
    done

    log_success "Copied $copied items to $seed_dir"

    # Show what was copied
    log "Seed directory contents after copy:"
    ls -la "$seed_dir" 2>&1 | while read -r line; do log "  $line"; done
}

# process_seed() - Run bloom and copy artifacts for a seed
#
# Arguments:
#   $1 = Path to the seed.nix file
#
# Convenience function combining run_bloom and copy_artifacts.
process_seed() {
    local seed_path="$1"
    local seed_dir
    seed_dir=$(get_seed_directory "$seed_path")

    # run_bloom returns the store path via stdout
    local store_path
    store_path=$(run_bloom "$seed_path")
    copy_artifacts "$store_path" "$seed_dir"
}
