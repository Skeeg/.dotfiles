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
  local show_all=false
  local format="default"
  
  # Parse arguments
  for arg in "$@"; do
    case "$arg" in
      all|--all)
        show_all=true
        ;;
      full|--full)
        format="full"
        ;;
      ports|--ports)
        format="ports"
        ;;
    esac
  done
  
  # Build docker ps command with array
  local docker_cmd=(docker ps)
  [[ "$show_all" == true ]] && docker_cmd+=(--all)
  docker_cmd+=(--format json)
  
  # Apply format
  case "$format" in
    full)
      "${docker_cmd[@]}" | jq -s 'sort_by(.Names)' | jq -c '.[]'
      ;;
    ports)
      "${docker_cmd[@]}" | jq -s 'sort_by(.Names) | .[] | {Names, Image, Status, RunningFor, Ports}' | jq -sc '.[]'
      ;;
    *)
      "${docker_cmd[@]}" | jq -s 'sort_by(.Names) | .[] | {Names, Image, Status, RunningFor}' | jq -sc '.[]'
      ;;
  esac
}

alias dps='docker-list'

docker-display-build-commands() {
  local image_id="$1"
  local format="default"
  
  # Validate required argument
  [[ -z "$image_id" ]] && { echo "usage: docker-display-build-commands IMAGE [format]"; return 1; }
  
  # Parse arguments
  for arg in "${@:2}"; do
    case "$arg" in
      full|--full)
        format="full"
        ;;
      compact|--compact)
        format="compact"
        ;;
    esac
  done
  
  # Build docker history command with array
  local docker_cmd=(docker history --no-trunc --format '{{json .}}' "$image_id")
  
  # Apply format
  case "$format" in
    full)
      "${docker_cmd[@]}" | jq -sc 'sort_by(.CreatedAt) | .[] | {CreatedAt, CreatedBy, Size}'
      ;;
    compact)
      "${docker_cmd[@]}" | jq -sr 'sort_by(.CreatedAt) | .[] | .CreatedBy'
      ;;
    *)
      "${docker_cmd[@]}" | jq -sc 'sort_by(.CreatedAt) | .[] | {CreatedBy, CreatedAt}'
      ;;
  esac
}

alias dbuildlayers='docker-display-build-commands'

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
