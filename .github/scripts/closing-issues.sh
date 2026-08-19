#!/usr/bin/env bash
#
# closing-issues.sh — print the node ID of every issue a pull request closes,
# one per line. Reads the closing keywords GitHub itself resolved, so it
# matches what will actually be closed on merge.
#
# usage: closing-issues.sh <pr-number>

# GraphQL queries below use $variables that must not be shell-expanded.
# shellcheck disable=SC2016

set -euo pipefail

PR="${1:?pull request number}"
OWNER="${GITHUB_REPOSITORY%/*}"
REPO="${GITHUB_REPOSITORY#*/}"

gh api graphql -f owner="$OWNER" -f repo="$REPO" -F pr="$PR" -f query='
  query($owner:String!, $repo:String!, $pr:Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $pr) {
        closingIssuesReferences(first: 50) { nodes { id number } }
      }
    }
  }' --jq '.data.repository.pullRequest.closingIssuesReferences.nodes[].id'
