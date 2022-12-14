vault-login() {
  [[ -z $1 ]] && { 
    echo 'Default usage specifically provides the token only from `.auth.client_token`'
    echo 'usage: vault-login $VAULT_ADDRESS'
    echo 'optionally, provide a json path to return more data for other uses'; 
    echo 'usage: vault-login $VAULT_ADDRESS .auth';
    return 1;}
  [[ ! -z $2 ]] && { JQ_PATH=$2 } || { JQ_PATH=".auth.client_token" }
  [[ -z "$OKTA_PASSWORD" || -z "$OKTA_USERNAME" ]] && { 
    echo "Initialize secrets first"; 
    echo 'secret export OKTA_USERNAME';
    echo 'secret export OKTA_PASSWORD';
    return 1; } || {
  curl --silent \
    --request POST \
    --data "{\"password\": \"$OKTA_PASSWORD\"}" \
    $1/v1/auth/okta/login/$OKTA_USERNAME | \
    jq -r $JQ_PATH}
}

vp() {
  vault-login $VAULT_PRODUCTION_ADDRESS
}

vs() {
  vault-login $VAULT_STAGING_ADDRESS
}

select-vault-server() {
  unset VAULT_ADDRESS
  X_ENVIRONMENT="$(tfenvironment 2>/dev/null)"
  [[ "$X_ENVIRONMENT" = "staging" ]] && { VAULT_ADDRESS=$VAULT_STAGING_ADDRESS }
  [[ "$X_ENVIRONMENT" = "production" ]] && { VAULT_ADDRESS=$VAULT_PRODUCTION_ADDRESS }
  [[ -z $VAULT_ADDRESS ]] && \
    { echo "No Terraform Environment Found to select Vault Server" } || \
    { echo "$VAULT_ADDRESS" }
  unset X_ENVIRONMENT
}
