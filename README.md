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


Forward-merging on the command line:
```
git switch release-1.x
git commit <something_already_reviewed>
git switch release-2.x
git merge release-1.x --log
git switch trunk
git merge release-2.x --log
git push --atomic origin release-1.x release-2.x trunk
```

Forward-merging in GitHub Pull Requests:
```
git switch some-dev-branch-off-release-1.x
git commit <something>
git push origin some-dev-branch-off-release-1.x
# create the pull request (against release-1.x)
git switch some-dev-branch-off-release-2.x
git merge some-dev-branch-off-release-1.x --log
git push origin some-dev-branch-off-release-2.x
# create the pull request (against release-2.x)
git switch some-dev-branch-off-trunk
git merge some-dev-branch-off-release-2.x --log
git push origin some-dev-branch-off-trunk
# create the pull request (against trunk)
```
