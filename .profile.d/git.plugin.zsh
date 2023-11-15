git-default-branch() {
  git remote show $(git remote) | grep "HEAD branch" | sed 's/.*: //'
}

git-switch-default() {
  git switch $(git-default-branch)
}
