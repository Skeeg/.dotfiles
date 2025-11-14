git-default-branch() {
  git remote show $(git remote) | grep "HEAD branch" | sed 's/.*: //'
}

git-switch-default() {
  git switch $(git-default-branch)
}

git-clean-merged() {
  # Deletes all branches that have been merged into the default branch
  git checkout $(git-default-branch)
  git fetch --prune
  git branch --merged | grep -v '^\*' | grep -v $(git-default-branch) | xargs -n 1 git branch -d
}
