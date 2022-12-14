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

containerhere() {
    [[ -z $1 ]] && { echo "usage: containerhere IMAGE [COMMAND]"; return 1; }
    command=$2
    if [[ -z $command ]]; then
        command='/bin/bash'
    fi  
    bash -c "docker run --rm -it -v $(pwd):/data -w /data $1 $command"
}

jenv-setup() {
  jenv add /opt/homebrew/opt/openjdk/
  jenv add /opt/homebrew/opt/openjdk@11
  jenv add /opt/homebrew/opt/openjdk@17
  cat << EOF > $HOME/.jenv/version
0.18
EOF
}

#OS Conveniences
flushdns() { sudo killall -HUP mDNSResponder }
gittyup() { 
  #Variable $1 value can be --auto-switch-on-missing to change branches back to the origin default if the branch is found missing
  source $scripts/shell/pull_git_repos.sh --repo-path "$repopath" $1
}

gittyupsalt() { 
  source $scripts/shell/pull_git_repos.sh --repo-path $HOME/full_salt/repo_saltstack_pillars;
  source $scripts/shell/pull_git_repos.sh --repo-path $HOME/full_salt/repo_saltstack_states;
}

secret () {
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

# Add lpass configuration
LPASS_AGENT_TIMEOUT=0
LPASS_DISABLE_PINENTRY=1
export LPASS_AGENT_TIMEOUT LPASS_DISABLE_PINENTRY

login-lastpass() { secret get lpass-login | lpass login "$EMAIL_ADDRESS" }
lastpass-work() {
  ln -sf ~/.lpass/trusted_id.work ~/.lpass/trusted_id
  echo "If this fails, you may need to refresh you login token via \`lpass login --trust \"\$EMAIL_ADDRESS_WORK\"\`"
  secret get lpass-login-work | lpass login "$EMAIL_ADDRESS_WORK"
}
lastpass-personal() { 
  ln -sf ~/.lpass/trusted_id.personal ~/.lpass/trusted_id
  echo "If this fails, you may need to refresh you login token via \`lpass login --trust \"\$EMAIL_ADDRESS_PERSONAL\"\`"
  secret get lpass-login-personal | lpass login "$EMAIL_ADDRESS_PERSONAL" 
}

# General Convenience Logins
init-sessions() { 
  ssh-add --apple-use-keychain ~/.ssh/id_rsa; 
  source "$scripts"/shell/set_env_vars.sh --email-address "$EMAIL_ADDRESS" 
    # This could use some refactoring.  
    # Idea is to create a sync from lastpass to local keychain maybe
}
