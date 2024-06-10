#!/bin/bash

set -o errexit
set -o pipefail

#
# Called by "git
# push" after it has checked the remote status, but before anything has been
# pushed.  If this script exits with a non-zero status nothing will be pushed.
#
# This hook is called with the following parameters:
#
# $1 -- Name of the remote to which the push is being done
# $2 -- URL to which the push is being done
#
# If pushing without using a named remote those arguments will be equal.
#
# Information about the commits which are being pushed is supplied as lines to
# the standard input in the form:
#
#   <ref> <oid> <remote ref> <remote oid>
#

# This script prevents merge commits unless they link to a SHA from harder baseline branches.

### arguments ###

remote="$1"
url="$2"

### constants ###

# List of allowed branches for merge commits
MAINLINE_BRANCHES=("release-1.x" "release-2.x" "trunk")
REAL_ORIGIN='michaelsembwever/atomic-linear-history-with-forward-merges-enforced-repo-demo'
# Determine the upstream remote name by matching the URL
UPSTREAM_REMOTE=$(git remote -v | grep "${REAL_ORIGIN}" | awk '{print $1}' | head -n 1)

### functions ###

# Function to check if a commit exists in any of the allowed branches,
#  or matches non-merged commits in this push
is_commit_in_allowed_branches() {
  commit=$1
  base_commit=$2
  # check if commit already exists upstream in any of the allowed branches
  for branch in "${MAINLINE_BRANCHES[@]}" ; do
    if git merge-base --is-ancestor "${commit}" "${UPSTREAM_REMOTE}/${branch}" ; then
      return 0
    fi
  done
  # check if the commit is the base_commit being forward merged
  if [ "${commit}" = "${base_commit}" ] ; then
    return 0
  fi
  return 1
}

# Function to recursively check the second parents for non-merge commits
check_ancestors() {
  remote_sha=$1
  commit=$2
  base_commit=$3
  branch=$(git branch --contains "${commit}" --no-color --no-column | sed 's/ //g')
  # recurse through merge commit's ancestry of second parents
  while [[ $(git rev-list --parents -n 1 "${commit}" | wc -w) -gt 2 ]] ; do
    # check if the second parent commit is in allowed branches or is the base commit
    if ! is_commit_in_allowed_branches "${commit}" "${base_commit}" ; then
      echo "Merge commit (${commit}) not on branches allowed for merge-tracking."
      exit 2
    fi
    # Check the second parent belongs in an allowed branch
    commit=$(git rev-list --parents -n 1 "${commit}" | awk '{print $3}')
    branch=$(git branch --contains "${commit}" --no-color --no-column | sed 's/ //g')
  done
  # check if the non-merge commit belongs to an allowed branch,
  #  and already exists or is being pushed alone to its base branch in this push
  if ! is_commit_in_allowed_branches "${branch}" "${base_commit}" ; then
    echo "Bad merge-tracking!"
    echo "The commit being forward-merged ${commit} in the merge commit ${remote_sha} does not already exist in an allowed branch: ${branch}"
    exit 3
  fi
}

### main ###

# this script only enforces pushes to the origin upstream
if echo "${url}" | grep -q "${REAL_ORIGIN}" || git remote get-url "${remote}" | grep -q "${REAL_ORIGIN}" ; then

  # zeroes padded to repo's current SHA length
  zero=$(git hash-object --stdin </dev/null | tr '[0-9a-f]' '0')

  base_commit=""
  local_oids=()
  remote_oids=()

  while read local_ref local_oid remote_ref remote_oid ; do
    # this script only enforces pushes to mainline branches
    if [[ $(echo "${MAINLINE_BRANCHES[@]}" | fgrep -w ${remote_ref/refs\/heads\//}) ]] ; then
      if [ "${local_oid}" != "${zero}" ] ; then
        # find the base_commit
        if [[ $(git rev-list --parents -n 1 "${local_oid}" | wc -w) -eq 2 ]]; then
          if [ "" != "${base_commit}" ] ; then
            echo "Multiple branches with new (non-forward-merged) commits (${base_commit}, ${local_oid})"
            exit 1
          fi
          base_commit="${local_oid}"
          # check there's no merge commits parents of this…
          if [ -n "$(git rev-list --merges ${base_commit} ${remote_oid})" ] ; then
            echo >&2 "Found merge commit parents before ${base_commit}, merge-tracking commits must come last"
            exit 4
          fi
        fi
        local_oids+=("${local_oid}")
        remote_oids+=("${remote_oid}")
      fi
    fi
  done

  # Check each new local_oid
  i=0
  for local_oid in ${local_oids} ; do
    # check all commit parent to local_oid back to branch base
    if [ "${remote_oid[$i]}" = "${zero}" ] ; then
      # New branch, examine all commits
      range="${local_oid}"
    else
      # Update to existing branch, examine new commits
      range="${remote_oid[$i]}..${local_oid}"
    fi
    local_oid_commits=$(git rev-list -n 1 "${range}")
    for commit in ${local_oid_commits} ; do
      # Check if the commit is a merge commit
      if [[ $(git rev-list --parents -n 1 "${commit}" | wc -w) -gt 2 ]]; then
        # Check if all non-merge parent commits are already in allowed branches
        check_ancestors "${remote_oids[$i]}" "${commit}" "${base_commit}"
      fi
    done
    i=$((i+1))
  done

fi
exit 0
