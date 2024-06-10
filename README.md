Simple repo to demonstrate how to enforce forward merge tracking on a codebase.

This is for developers that want to
- merge track between mainline branches, from hard to soft (according the the Tofu scale),
- have atomic linear git history,
- avoid merge commits from baseline branches to non-mainlines (according to the "Merge down, Copy up" practice),
- avoid superfluous merge commits from non-mainlines to mainlines


Provides 
- automatically install git hooks
- pre-push git hook to prevent commit messages with bad words going into upstream mainlines
- pre-push git hook to ensure forward merges reference the original mainline non-merged commit
- github action to run all pre-push hook checks
