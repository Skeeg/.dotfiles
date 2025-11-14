get_gitlab_vars() {
  local scope="$1"      # "project" or "group"
  local id="$2"         # Project or Group ID
  local gitlabPat="$3"  # Personal Access Token

  local url
  if [ "$scope" = "project" ]; then
    url="https://gitlab.com/api/v4/projects/$id/variables?per_page=100"
  elif [ "$scope" = "group" ]; then
    url="https://gitlab.com/api/v4/groups/$id/variables?per_page=100"
  else
    echo "Error: scope must be 'project' or 'group'" >&2
    return 1
  fi

  local result
  result=$(curl --silent --request GET \
    --header "PRIVATE-TOKEN: $gitlabPat" \
    "$url" | jq -c '.[] | {key, value, environment_scope}')

  if [ $? -ne 0 ]; then
    echo "Error: Failed to fetch variables for $scope ID $id" >&2
    return 1
  fi

  echo "$result"
}

# Usage:
# get_gitlab_vars project 26373218 <your_pat>
# get_gitlab_vars group 13074823 <your_pat>

