#!/usr/bin/env bash
# action/lib/git.sh - Git operations for committing artifacts
#
# This module handles checking for changes, committing, pushing,
# and error handling for git operations.

# check_for_changes() - Determine if there are uncommitted changes
#
# Returns: exit code 0 if there ARE changes, exit code 1 if clean
check_for_changes() {
    [[ -n "$(git status --porcelain)" ]]
}

# configure_git() - Set up git identity for commits
#
# Configures the github-actions bot as the commit author.
configure_git() {
    git config user.name "github-actions[bot]"
    git config user.email "github-actions[bot]@users.noreply.github.com"
}

# handle_push_failure() - Provide helpful message when push fails
#
# Detects fork PRs and provides specific guidance for each failure type.
handle_push_failure() {
    log_error "Failed to push commits to the PR branch"
    log_error ""

    # Check if this is a fork PR
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

# commit_and_push() - Stage, commit, and push artifact changes
#
# Arguments:
#   $1 = Path to the seed file (used in commit message)
#
# Commits all changes with a descriptive message and pushes to the PR branch.
commit_and_push() {
    local seed_path="$1"
    log "Committing artifacts..."

    configure_git
    git add .
    git commit -m "chore: bloom artifacts for $seed_path"

    log "Pushing to branch..."
    if ! git push; then
        handle_push_failure
        exit 1
    fi

    log_success "Artifacts committed and pushed"
}

# commit_if_changed() - Commit and push only if there are changes
#
# Arguments:
#   $1 = Path to the seed file (used in commit message)
#
# Skips commit if no changes exist (idempotent behavior).
commit_if_changed() {
    local seed_path="$1"

    if check_for_changes; then
        commit_and_push "$seed_path"
    else
        log_success "No changes to commit - artifacts already up to date"
    fi
}
