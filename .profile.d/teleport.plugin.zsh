# Okta auth into Teleport
alias tshlogin='tsh --proxy https://pluralsight.teleport.sh --auth okta login'

tsh-update-and-login () {
	if ! tsh status > /dev/null 2>&1
	then
		update-teleport-client
		echo "No active session. Logging you in first by running 'tsh --proxy https://pluralsight.teleport.sh --auth okta login'..."
		tshlogin
	fi
}

# Quickly request elevated privileges in whatever environment you need.
function tshrequest() {
  if [ $# -le 1 ]
  then
    echo "Need an Environment and a JIRA Ticket"
    echo "Example: tshrequest staging ATM-123"
    return 0
  fi
  tsh request create --roles developer-$1-access --reason "'$2'"
}

# And an alias to revoke those privileges from yourself whenever you're done.
alias tshrevoke='tsh request drop'

get-teleport-version () {
	local component="$1"
	local response
	local version
	if [ "$component" = "server" ]
	then
		response=$(curl -s https://pluralsight.teleport.sh/webapi/ping)
		version=$(echo "$response" | jq -r '.server_version')
	elif [ "$component" = "client" ]
	then
		if command -v tsh > /dev/null 2>&1
		then
			version=$(tsh version --client -f json | jq -r ".version")
		else
			version="n/a"
		fi
	else
		echo "Error: Invalid component specified. Please specify 'client' or 'server'."
		return 1
	fi
	if [ -z "$version" ]
	then
		echo "Error: Failed to retrieve the $component version."
		return 1
	fi
	echo "$version"
}

install-teleport () {
	local version=${1}
	local url="https://cdn.teleport.dev/teleport-ent-${version}.pkg"
	local pkg="teleport-ent-${version}.pkg"
	if ! curl -o ${pkg} ${url}
	then
		echo "Error: Failed to download the package."
		rm -v ${pkg}
		return 1
	fi
	if ! /Applications/Privileges.app/Contents/Resources/PrivilegesCLI --add
		sudo installer -pkg ${pkg} -target /
	then
		echo "Error: Failed to install the package."
		rm -v ${pkg}
		return 1
	fi
	echo "Teleport ${version} installed successfully."
	rm -v ${pkg}
}

update-teleport-client () {
	local server_version=$(get-teleport-version server)
	local client_version=$(get-teleport-version client)
	if [ "${server_version}" != "${client_version}" ]
	then
		echo "Server version: ${server_version}"
		echo "Client version: ${client_version}"
		echo "Updating teleport client to server version"
		install-teleport ${server_version}
	else
		echo "Teleport client is up to date"
	fi
}
