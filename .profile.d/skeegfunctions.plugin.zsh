# Custom plugin for zsh
#
# Various Functions
#
# Author: Ryan Peay
# Date:   Mon Aug 8 21:28:29 MST 2022
#

rawurlencode() {
  local string="${1}"
  local strlen=${#string}
  local encoded=""
  local pos c o

  for (( pos=0 ; pos<strlen ; pos++ )); do
    c=${string:$pos:1}
    case "$c" in
      [-_.~a-zA-Z0-9] ) o="${c}" ;;
      * )               printf -v o '%%%02x' "'$c"
    esac
    encoded+="${o}"
  done
  echo "${encoded}"    # You can either set a return variable (FASTER)
  REPLY="${encoded}"   #+or echo the result (EASIER)... or both... :p
}

jenv-setup() {
  # macOS only — uses Homebrew openjdk paths
  if [[ "$(uname)" != "Darwin" ]]; then echo "jenv-setup: macOS only"; return 1; fi
  jenv add /opt/homebrew/opt/openjdk/
  jenv add /opt/homebrew/opt/openjdk@11
  jenv add /opt/homebrew/opt/openjdk@17
  cat << EOF > $HOME/.jenv/version
0.18
EOF
}

#OS Conveniences
flushdns() {
  # macOS only — flushes mDNS responder cache
  if [[ "$(uname)" != "Darwin" ]]; then echo "flushdns: macOS only (try 'sudo systemd-resolve --flush-caches' on Linux)"; return 1; fi
  sudo killall -HUP mDNSResponder
}

gittyup() { 
  #Variable $1 value can be --auto-switch-on-missing to change branches back to the origin default if the branch is found missing
  source $SCRIPTS/shell/pull_git_repos.sh --repo-path "$REPOPATH" $1
}

gittyupsalt() { 
  source $SCRIPTS/shell/pull_git_repos.sh --repo-path $HOME/full_salt/repo_saltstack_pillars;
  source $SCRIPTS/shell/pull_git_repos.sh --repo-path $HOME/full_salt/repo_saltstack_states;
}

secret () {
  # macOS only — uses macOS keychain via the 'security' command
  if [[ "$(uname)" != "Darwin" ]]; then echo "secret: macOS keychain only. Use a password manager or env file on Linux."; return 1; fi
  # Credit to https://github.com/ACloudGuru/node-dev-dotfiles/blob/trunk/lib/secret.sh
	USAGE="
    Usage:
    > secret set [KEY] [VALUE]
    > secret get [KEY]
    > secret export [KEY] # outputs: export [KEY]=[VALUE]
    > secret unset [KEY]
  "
	MODE="$1"
	KEY="$2"
	VALUE="$3"
	KIND="shell secret"
	ACCOUNT="$(whoami)"
	ARG_LENGTH="$#"
	if [ $MODE = "set" ] && [ $ARG_LENGTH -eq "3" ]
	then
		if security add-generic-password -U -a "$ACCOUNT" -D "$KIND" -s "$KEY" -w "$VALUE"
		then
			echo "$KEY saved to keychain."
		fi
	elif [ $MODE = "get" ] && [ $ARG_LENGTH -eq "2" ]
	then
		security find-generic-password -a "$ACCOUNT" -D "$KIND" -s "$KEY" -w
	elif [ $MODE = "export" ] && [ $ARG_LENGTH -eq "2" ]
	then
		if security find-generic-password -a "$ACCOUNT" -D "$KIND" -s "$KEY" -w &> /dev/null
		then
			export $KEY=$(secret get $KEY | xargs)
			echo "$KEY loaded from keychain."
		else
			echo "$KEY not found in keychain."
		fi
	elif [ $MODE = "unset" ] && [ $ARG_LENGTH -eq "2" ]
	then
		security delete-generic-password -a "$ACCOUNT" -D "$KIND" -s "$KEY" -w
	else
		echo $USAGE
	fi
}

# General Convenience Logins
init-sessions() { 
  # ssh-add --apple-use-keychain ~/.ssh/id_rsa; 
  # source "$SCRIPTS"/shell/set_env_vars.sh --email-address "$EMAIL_ADDRESS" 
  tsh login --proxy=pluralsight.teleport.sh --auth okta
    # This could use some refactoring.  
    # Idea is to create a sync from lastpass to local keychain maybe
}

get-tfc-variable-id() {
  USAGE="
    Usage:
    > get-tfc-variable-id [key] [organization] [workspace-name] [TFC-API-Token]
    example: $(get-tfc-variable-id vault-token tfc-organization bounded-context-staging $(secret get TFC_API_TOKEN))
  "
  KEY="$1"
  TFC_ORGANIZATION="$2"
  TFC_WORKSPACE="$3"
  TFC_API_TOKEN="$4"
  ARG_LENGTH="$#"
  if [ $ARG_LENGTH -eq "4" ]
  then
    curl --silent \
      --header "Authorization: Bearer $TFC_API_TOKEN" \
      --header "Content-Type: application/vnd.api+json" \
      "https://app.terraform.io/api/v2/vars" | \
      tr '\n' ' ' | \
      jq -c ".data[] |
        select (.attributes.key == \"$KEY\") |
        select (.relationships.workspace.links.related ==
        \"/api/v2/organizations/$TFC_ORGANIZATION/workspaces/$TFC_WORKSPACE\")" | \
      jq -r .id
  else
    echo $USAGE
  fi
}

get-tfc-variable-data() {
  USAGE="
    Usage:
    > get-tfc-variable-data [key] [organization] [workspace-name] [TFC-API-Token]
    example: $(get-tfc-variable-data vault-token tfc-organization bounded-context-staging $(secret get TFC_API_TOKEN))
  "
  KEY="$1"
  TFC_ORGANIZATION="$2"
  TFC_WORKSPACE="$3"
  TFC_API_TOKEN="$4"
  ARG_LENGTH="$#"
  if [ $ARG_LENGTH -eq "4" ]
  then
    curl --silent \
      --header "Authorization: Bearer $TFC_API_TOKEN" \
      --header "Content-Type: application/vnd.api+json" \
      "https://app.terraform.io/api/v2/vars" | \
      tr '\n' ' ' | \
      jq -c ".data[] |
        select (.attributes.key == \"$KEY\") |
        select (.relationships.workspace.links.related ==
        \"/api/v2/organizations/$TFC_ORGANIZATION/workspaces/$TFC_WORKSPACE\")" | \
      jq
  else
    echo $USAGE
  fi
}

patch-tfc-vault-token () {
  # Must still set $VAULT_TOKEN before running this until can find out how to select the right instance and token.
  # Method exists in vault.plugin.zsh for setting token
  # example: VAULT_TOKEN=$(vault-staging)
  VARIABLE="vault-token"
  TFC_WORKSPACE=$(cat .terraform/environment)
  VARIABLEID=$(get-tfc-variable-id "$VARIABLE" "$TFC_ORGANIZATION" "$TFC_WORKSPACE" "$TFC_API_TOKEN")
  JSON_DATA='{
    "data": {
      "id": "'"$VARIABLEID"'",
      "attributes": {
        "key": "'"$VARIABLE"'",
        "value": "'"$VAULT_TOKEN"'",
        "description": "",
        "category": "terraform",
        "hcl": false,
        "sensitive": false
      },
      "type": "vars"
    }
  }'
  #Patch Data
  curl --header "Authorization: Bearer $TFC_API_TOKEN" \
    --header "Content-Type: application/vnd.api+json" \
    --request PATCH --data $JSON_DATA \
    "https://app.terraform.io/api/v2/vars/$VARIABLEID" | jq
}

patch-tfc-cli-args () {
  # Must still set $VAULT_TOKEN before running this until can find out how to select the right instance and token.
  # Method exists in vault.plugin.zsh for setting token
  # example: VAULT_TOKEN=$(vault-staging)
  VARIABLE="TF_CLI_ARGS"
  TFC_WORKSPACE=$(cat .terraform/environment)
  VARIABLEID=$(get-tfc-variable-id "$VARIABLE" "$TFC_ORGANIZATION" "$TFC_WORKSPACE" "$TFC_API_TOKEN")
  JSON_DATA='{
    "data": {
      "id": "'"$VARIABLEID"'",
      "attributes": {
        "key": "'"$VARIABLE"'",
        "value": "'"$1"'",
        "description": "",
        "category": "env",
        "hcl": false,
        "sensitive": false
      },
      "type": "vars"
    }
  }'
  #Patch Data
  curl --header "Authorization: Bearer $TFC_API_TOKEN" \
    --header "Content-Type: application/vnd.api+json" \
    --request PATCH --data $JSON_DATA \
    "https://app.terraform.io/api/v2/vars/$VARIABLEID" | jq
}

clear-tfc-cli-args () {
  # Must still set $VAULT_TOKEN before running this until can find out how to select the right instance and token.
  # Method exists in vault.plugin.zsh for setting token
  # example: VAULT_TOKEN=$(vault-staging)
  VARIABLE="TF_CLI_ARGS"
  TFC_WORKSPACE=$(cat .terraform/environment)
  VARIABLEID=$(get-tfc-variable-id "$VARIABLE" "$TFC_ORGANIZATION" "$TFC_WORKSPACE" "$TFC_API_TOKEN")
  JSON_DATA='{
    "data": {
      "id": "'"$VARIABLEID"'",
      "attributes": {
        "key": "'"$VARIABLE"'",
        "value": "",
        "description": "",
        "category": "env",
        "hcl": false,
        "sensitive": false
      },
      "type": "vars"
    }
  }'
  #Patch Data
  curl --header "Authorization: Bearer $TFC_API_TOKEN" \
    --header "Content-Type: application/vnd.api+json" \
    --request PATCH --data $JSON_DATA \
    "https://app.terraform.io/api/v2/vars/$VARIABLEID" | jq
}

# Mob Programming Conveniences
msi() {
  mob start --include-uncommitted-changes
}

# Method to set environment variables from a file, excluding commented out files
setenv() {
  # shellcheck disable=SC2046
  export $(grep -v '^#' "$1" | xargs)
}

refresh-asdf-nodejs-vers () {
  nodejsvers=$(asdf list all nodejs)
  for NODEVERSION in $(echo "14 16 18 20 22")
  do
    asdf install nodejs $(echo $nodejsvers | grep -e "^$NODEVERSION" | tail -1)
  done
}

_truncated_env_output () {
	if [[ "$1" == "full" ]]
	then
		shift
		command env "$@"
		return
	fi
	command env | while IFS= read -r line
	do
		key="${line%%=*}"
		val="${line#*=}"
		if [[ "$line" == *=* ]]
		then
			printf "%s=%s...\n" "$key" "${val:0:3}"
		else
			printf "%s\n" "$line"
		fi
	done
}
alias env=_truncated_env_output
alias printenv=_truncated_env_output
alias status-vbox="sudo systemctl status vbox-dmz"
alias restart-vbox="sudo systemctl restart vbox-dmz"
alias start-vbox="sudo systemctl start vbox-dmz"
alias stop-vbox="sudo systemctl stop vbox-dmz"

lcd() {
  if [ $# -le 0 ]
  then
    echo "launch vs code and change to that directory: lcd ~/repo/directory"
    return 0
  fi
  if ! command -v code &>/dev/null; then echo "lcd: 'code' CLI not found — install VS Code and enable shell command."; return 1; fi
  code "$1"
  cd "$1"
}

generate_base64_key() {
  length="${1:-32}"
  openssl rand "$length" | base64 | tr -d '\n'
}

hash_api_key() {
  local key="$1"
  echo -n "$key" | sha256sum | xxd -r -p | base64
}

generate_uuid_key() {
  openssl rand -hex 16 | sed 's/\(.\{8\}\)\(.\{4\}\)\(.\{4\}\)\(.\{4\}\)\(.\{12\}\)/\1-\2-\3-\4-\5/'
}

get_date_string() {
  date -u +"%Y-%m-%d" 2>/dev/null || date -u -j +"%Y-%m-%d"
}

get_1password_field () {
  local entry_name="$1"
	local field="$2"
  local op_account="${3:-pluralsight.1password.com}"
  local op_vault="${4:-Shared-Ops}"
	if [ $# -lt 2 ]

	then
		echo "Error: get_1password_item requires at least 2 arguments: entry_name, field" >&2
		return 1
	fi

	op item get --account "$op_account" "$entry_name" --fields label="$field" --vault "$op_vault" --reveal
}

create_1password_entry() {
  local entry_name="$1"
  local op_account="${2:-pluralsight.1password.com}"
  local op_vault="${3:-Shared-Ops}"
  
  if [ $# -ne 3 ]; then
    echo "Error: get_1password_item requires 3 arguments: entry_name, op_account, op_vault" >&2
    return 1
  fi
  
  if ! command -v op &> /dev/null; then
    echo "Error: 1Password CLI (op) is not installed" >&2
    return 1
  fi

  if op item get --account "$op_account" --vault="$op_vault" "$entry_name" &> /dev/null; then
    return 0
  else
    op item create --account "$op_account" --title="$entry_name" --category=login username="Services will all have their own entries as unique, protected fields." --vault="$op_vault"
  fi
}

update_1password_item() {
  # This function updates a 1Password item with the given username and password as a unique field.  The username is used as the field name, it will be stored as a password type field with the value of password in a protected manner.
  if [ $# -ne 5 ]; then
    echo "Error: update_1password_item requires 5 arguments: entry_name, field, password, account, vault" >&2
    return 1
  fi

  local entry_name="$1"
  local field="$2"
  local password="$3"
  local op_account="${4:-pluralsight.1password.com}"
  local op_vault="${5:-Shared-Ops}"

  # Use proper syntax: field_name[field_type]=value
  # For 1Password CLI v2, use this syntax to add/update password fields
  # echo "Checking if field $field exists in entry $entry_name"
  API_KEY_FOUND=$(get_1password_field "$entry_name" "$field" "$op_account" "$op_vault" 2>&1 )
  if [[ $API_KEY_FOUND != *"ERROR"* ]]; then
    echo "Password field already populated for $field in $entry_name" >&2
    return 0
  else
    op item edit --account "$op_account" --vault "$op_vault" "$entry_name" "${field}[password]=${password}"
  fi
}

generate_api_keys_1password() {
  # This function generates API keys for each bounded context listed in the provided file and stores them in a 1Password entry as unique fields.
  # Usage: generate_api_keys_1password context_list_file entry_name key_type op_account op_vault
  local context_list_file="$1"
  local entry_name="$2"
  local key_type="${3:-base64}"  # default to base64 if not specified
  local op_account="${4:-pluralsight.1password.com}"
  local op_vault="${5:-Shared-Ops}"

  if [ $# -lt 2 ]; then
    echo "Error: generate_api_keys_1password requires at least 2 arguments: context_list_file, entry_name" >&2
    return 1
  fi

  if [ $# -gt 5 ]; then
    echo "Error: generate_api_keys_1password only uses 5 arguments: context_list_file, entry_name, key_type, op_account, op_vault" >&2
    return 1
  fi
  
  if ! command -v op &> /dev/null; then
    echo "Error: 1Password CLI (op) is not installed" >&2
    return 1
  fi
  
  create_1password_entry "$entry_name" "$op_account" "$op_vault"

  while IFS=$'\n' read -r line; do
    if [ "$key_type" = "uuid" ]; then
      API_KEY=$(generate_uuid_key)
    else
      API_KEY=$(generate_base64_key)
    fi
    update_1password_item "$entry_name" "$line" "$API_KEY" "$op_account" "$op_vault"
  done <<< "$(cat "$context_list_file")"
}
