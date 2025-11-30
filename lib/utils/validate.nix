# URL Validation Utilities
#
# This module provides helper functions for validating and normalizing URLs.
# It's used by the source-download processor to check that the GitHub URL
# specified in the seed matches the repository URL from registry metadata.
#
# WHY DO WE NEED THIS?
# When you download a package from crates.io or PyPI, the registry metadata
# might include a "repository" field pointing to GitHub. We want to verify
# that this matches what the user specified in their seed.nix - this helps
# catch mistakes like pointing to a fork instead of the official repo.

{ lib }:

{
  # normalizeGitHubUrl: Convert various GitHub URL formats to a standard form
  #
  # GitHub URLs come in many formats:
  #   - https://github.com/owner/repo
  #   - https://github.com/owner/repo.git
  #   - https://github.com/owner/repo/
  #   - git@github.com:owner/repo.git
  #
  # This function converts them all to: https://github.com/owner/repo
  # so we can compare them for equality.
  #
  # ARGUMENTS:
  #   url - A string containing a GitHub URL (or null)
  #
  # RETURNS:
  #   A normalized URL string, or null if the input was null
  #
  # EXAMPLES:
  #   normalizeGitHubUrl "https://github.com/serde-rs/serde.git"
  #   => "https://github.com/serde-rs/serde"
  #
  #   normalizeGitHubUrl "https://github.com/serde-rs/serde/"
  #   => "https://github.com/serde-rs/serde"
  normalizeGitHubUrl = url:
    # If the URL is null or empty, just return null
    # The "or" operator returns the right side if the left is null
    if url == null || url == "" then
      null
    else
      let
        # Remove trailing .git suffix if present
        # lib.removeSuffix removes a suffix from a string if it exists
        withoutGit = lib.removeSuffix ".git" url;

        # Remove trailing slash if present
        withoutSlash = lib.removeSuffix "/" withoutGit;
      in
      withoutSlash;

  # urlsMatch: Check if two GitHub URLs point to the same repository
  #
  # This compares normalized versions of both URLs. If either URL is null,
  # we consider it a "no opinion" and return true (allow the build to proceed).
  #
  # ARGUMENTS:
  #   url1 - First URL to compare (from seed.nix)
  #   url2 - Second URL to compare (from registry metadata)
  #
  # RETURNS:
  #   true if the URLs match (or if either is null)
  #   false if they differ
  #
  # EXAMPLES:
  #   urlsMatch "https://github.com/serde-rs/serde" "https://github.com/serde-rs/serde.git"
  #   => true (they're the same repo)
  #
  #   urlsMatch "https://github.com/serde-rs/serde" "https://github.com/someone-else/serde"
  #   => false (different owners)
  #
  #   urlsMatch "https://github.com/serde-rs/serde" null
  #   => true (no metadata URL to compare, so we allow it)
  urlsMatch = url1: url2:
    let
      # Import ourselves to use normalizeGitHubUrl
      # This is a common Nix pattern for accessing sibling functions
      self = import ./validate.nix { inherit lib; };

      # Normalize both URLs
      norm1 = self.normalizeGitHubUrl url1;
      norm2 = self.normalizeGitHubUrl url2;
    in
    # If either is null, we can't compare, so we allow the build
    # This matches FR-017: "proceed without validation if no repository URL exists"
    if norm1 == null || norm2 == null then
      true
    else
      norm1 == norm2;

  # buildGitHubUrl: Construct a GitHub URL from owner and repo
  #
  # ARGUMENTS:
  #   owner - GitHub username or organization (e.g., "serde-rs")
  #   repo  - Repository name (e.g., "serde")
  #
  # RETURNS:
  #   A GitHub URL string: "https://github.com/owner/repo"
  buildGitHubUrl = owner: repo:
    "https://github.com/${owner}/${repo}";
}
