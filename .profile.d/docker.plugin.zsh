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

docker-list() {
  if [ "$1" = "full" ] || [ "$1" = "--full" ]; then
    docker ps --format json | jq -s 'sort_by(.Names)' | jq -c '.[]';   elif [ "$1" = "ports" ] || [ "$1" = "--ports" ]; then
    docker ps --format json | jq -s 'sort_by(.Names) | .[] | {Names, Image, Status, RunningFor, Ports}' | jq -sc '.[]';   else
    docker ps --format json | jq -s 'sort_by(.Names) | .[] | {Names, Image, Status, RunningFor}' | jq -sc '.[]';   
  fi; 
}

alias dps='docker-list'

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
