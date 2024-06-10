#!/bin/sh

set -o errexit

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
#   <local ref> <local oid> <remote ref> <remote oid>
#

# This script prevents commits with log messages containing forbidden words.

### arguments ###

remote="$1"
url="$2"

### constants ###

bad_words="WIP|SQUASH|THROWAWAY"

# List of allowed branches for merge commits
MAINLINE_BRANCHES=("release-1.x" "release-2.x" "trunk")
REAL_ORIGIN='michaelsembwever/atomic-linear-history-with-forward-merges-enforced-repo-demo'
# Determine the upstream remote name by matching the URL
UPSTREAM_REMOTE=$(git remote -v | grep "${REAL_ORIGIN}" | awk '{print $1}' | head -n 1)

### main ##

# this script only enforces pushes to the origin michaelsembwever/test-git-hooks
if echo "${url}" | grep -q "${REAL_ORIGIN}" || git remote get-url "${remote}" | grep -q "${REAL_ORIGIN}" ; then

  # zeroes padded to repo's current SHA length
  zero=$(git hash-object --stdin </dev/null | tr '[0-9a-f]' '0')

  while read local_ref local_oid remote_ref remote_oid ; do
    # this script only enforces pushes to mainline branches
    if [[ $(echo "${MAINLINE_BRANCHES[@]}" | fgrep -w ${remote_ref/refs\/heads\//}) ]] ; then
      if [ "${local_oid}" != "${zero}" ] ; then
        if [ "${remote_oid}" = "${zero}" ] ; then
          # New branch, examine all commits
          range="${local_oid}"
        else
          # Update to existing branch, examine new commits
          range="${remote_oid}..${local_oid}"
        fi

        # Check commits
        bad_commits=$(git rev-list -n 1 --regexp-ignore-case --extended-regexp --grep="${bad_words}" "${range}")
        if [ -n "${bad_commits}" ] ; then
          echo >&2 "Found ${bad_words} commit in ${bad_commits}, not acceptable for the mainline branch ${remote_ref}"
          exit 1
        fi
      fi
    fi
  done

fi
exit 0
