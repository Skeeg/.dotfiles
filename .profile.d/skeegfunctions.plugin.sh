# Custom plugin for zsh
#
# Various Functions
#
# Author: Ryan Peay
# Date:   Mon Aug 8 21:28:29 MST 2022
#




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


alias env=peek-env
alias printenv=peek-env
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


hash_api_key() {
  local key="$1"
  echo -n "$key" | sha256sum | xxd -r -p | base64
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

