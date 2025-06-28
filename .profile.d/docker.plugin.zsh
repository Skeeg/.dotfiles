# Custom plugin for zsh
#
# Various Functions
#
# Author: Ryan Peay
# Date:   Wed Sep 20 09:01:29 MST 2023
#

# Docker convenience functions
di() {
  docker image ls
}

dv() {
  docker volume ls
}

dn() {
  docker network ls
}

dps() {
  docker ps --all
}

compose-up() {
  cd "$REPOPATH/$1"
  docker compose up -d --build
  cd -
}

compose-down() {
  cd "$REPOPATH/$1"
  docker compose down
  cd -
}

compose-clean() {
  cd "$REPOPATH/$1"
  docker compose down -v
  cd -
}

containerhere() {
    [[ -z $1 ]] && { echo "usage: containerhere IMAGE [COMMAND]"; return 1; }
    command=$2
    if [[ -z $command ]]; then
        command='/bin/bash'
    fi
    bash -c "docker run --rm -it -v $(pwd):/data -w /data $1 $command"
}
