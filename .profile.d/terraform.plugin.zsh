# Custom plugin for zsh
#
# Terraform aliases
#
# Author: Ryan Peay
# Date:   Mon Aug 8 21:28:29 MST 2022
#

### Command enhancements aliases ###
alias ta='terraform apply'
alias ti='terraform init'
alias tp='terraform plan'
alias tc='terraform console'
tftargets() {for a in $(terraform plan | grep " be" | awk '{print $3}' | grep -e "aws" -e "vault"); echo "--target='$a' \\"}
tfvalidate() {terraform validate -json | jq '.diagnostics[] | {detail: .detail, filename: .range.filename, start_line: .range.start.line}'}

# Terraform workspace aliases
# ******* These are the latest ******** #
tfcs() {terraform workspace select $(pwd | rev | cut -d "/" -f 1 | rev)-staging-us-west-2 && kubestage}
tfcp() {terraform workspace select $(pwd | rev | cut -d "/" -f 1 | rev)-production-us-west-2 && kubeprod}
tfcdr() {terraform workspace select $(pwd | rev | cut -d "/" -f 1 | rev)-production-us-east-2-dr}

tfcenv() {cat .terraform/environment | sed -n \
  -e "s/^.*-\(\staging\).*$/\1/p" \
  -e "s/^.*-\(\production\).*$/\1/p"}
tfenvironment() {[[ $(cat .terraform/environment 2> /dev/null) = 'staging' ]] || \
  [[ $(cat .terraform/environment 2> /dev/null) = 'production' ]] && \
  cat .terraform/environment || \
  tfcenv}
# ************************************* #

tfep() {terraform workspace select production; kubeprod}
tfes() {terraform workspace select staging; kubestage}

refresh-tfenv-vers () {
  tfvers=$(tfenv list-remote)
  for TFVERSION in $(echo $tfvers | grep -e "^1\." | cut -d"." -f1-2 | uniq)
    tfenv install latest\:^$TFVERSION
  for TFVERSION in $(echo $tfvers | grep -e "^0\.1[2-6]\..*" | cut -d"." -f1-2 | uniq)
    TFENV_ARCH=amd64 tfenv install latest\:^$TFVERSION
}

get-tfc-variable-id() {
  USAGE='
    Usage:
    > get-tfc-variable-id [key] [workspace-name] [TFC-API-Token]
    example: $(get-tfc-variable-id vault-token bounded-context-staging-us-west-2 $(secret get TFC_API_TOKEN))
  '
	X_KEY="$1"
	X_TFC_WORKSPACE="$2"
  X_TFC_API_TOKEN="$3"
	ARG_LENGTH="$#"
	if [ $ARG_LENGTH -eq "3" ]
  then
    curl --silent \
      --header "Authorization: Bearer $X_TFC_API_TOKEN" \
      --header "Content-Type: application/vnd.api+json" \
      "https://app.terraform.io/api/v2/vars" | \
      tr '\n' ' ' | \
      jq -c ".data[] | 
        select (.attributes.key == \"$X_KEY\") | 
        select (.relationships.workspace.links.related == 
        \"/api/v2/organizations/pluralsight/workspaces/$X_TFC_WORKSPACE\")" | \
      jq -r .id
  else
    echo $USAGE
  fi
  unset X_TFC_API_TOKEN X_KEY X_TFC_WORKSPACE
}

construct-tfc-variable-json-payload() {
  USAGE='
    Usage:
    > construct-tfc-variable-json-payload [key] [value] [id]
    example: DATA=$(construct-tfc-variable-json-payload vault-token $(vault-login $VAULT_STAGING_ADDRESS)\
      $(get-tfc-variable-id vault-token bounded-context-staging-us-west-2 $(secret get TFC_API_TOKEN)))
  '
  X_KEY="$1"
	X_VALUE="$2"
  X_ID="$3"
	ARG_LENGTH="$#"
	if [ $ARG_LENGTH -eq "3" ]
  then
    ORIGIFS=$IFS; IFS=
    echo "{
  \"data\": {
    \"id\":\"$X_ID\",
    \"attributes\": {
      \"key\":\"$X_KEY\",
      \"value\":\"$X_VALUE\",
      \"description\": null,
      \"category\":\"terraform\",
      \"hcl\": false,
      \"sensitive\": true
    },
    \"type\":\"vars\"
  }
}" | jq -c
    IFS=$ORIGIFS
  else
    echo $USAGE
  fi
  unset X_VALUE X_KEY X_ID
}

patch-tfc-variable-value() {
  USAGE='
    Usage:
    > patch-tfc-variable-value [DATA] [TFC-API-Token]
    # With $DATA sourcing from the construct-tfc-variable-json-payload function: 
    example: patch-tfc-variable-value "$DATA" $(secret get TFC_API_TOKEN)
  '
	X_DATA="$1"
  X_TFC_API_TOKEN="$2"
  X_VAR_ID=$(echo $X_DATA | jq -r .data.id)
	ARG_LENGTH="$#"
  if [ $ARG_LENGTH -eq "2" ]
  then
    ORIGIFS=$IFS; IFS=
    curl --silent \
      --header "Authorization: Bearer $X_TFC_API_TOKEN" \
      --header "Content-Type: application/vnd.api+json" \
      --request PATCH --data "$X_DATA" \
      "https://app.terraform.io/api/v2/vars/$X_VAR_ID" | jq
    IFS=$ORIGIFS
  else
    echo $USAGE
  fi
  unset X_VAR_ID X_DATA X_TFC_API_TOKEN
}

# Combining all the things, an example to use one terraform project workspace and the functions above to refresh the token:
# # patch-tfc-variable-value [data] [TFC_API_Token]              # The main function
# # construct-tfc-variable-json-payload [key] [value] [id]       # Second function to create the data value for main function
# # vault-login [vault-url] [json-path]                          # Third function to get a short lived Vault token 
# # get-tfc-variable-id [key] [workspace-name] [TFC-API-Token]   # Fourth function to find the actual variable in TFC to be updated.
# # 
# # Noteworthy: 
# # select-vault-server: method of using the active Terraform workspace name to decide which vault
# # server to request token from using defined options.  *Only differentiates between staging/production. 
# # 
# # Pull it all together:
# patch-tfc-variable-value \
#   $(construct-tfc-variable-json-payload \
#       "vault-token" \
#       $(vault-login \
#           $(select-vault-server) \
#           ".auth.client_token") \
#       $(get-tfc-variable-id \
#           "vault-token" \
#           $(cat ./.terraform/environment) \
#           $(secret get TFC_API_TOKEN))) \
#   $(secret get TFC_API_TOKEN)