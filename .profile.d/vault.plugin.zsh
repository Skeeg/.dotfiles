vault-login() {
  [[ -z $1 ]] && { echo 'usage: vault-login $VAULT_ADDRESS'; return 1;}
  [[ -z "$OKTA_PASSWORD" || -z "$OKTA_USERNAME" ]] && { 
    echo "Initialize secrets first"; 
    echo 'secret export OKTA_USERNAME';
    echo 'secret export OKTA_PASSWORD';
    return 1; } || {
  curl --silent \
    --request POST \
    --data "{\"password\": \"$OKTA_PASSWORD\"}" \
    $1/v1/auth/okta/login/$OKTA_USERNAME | \
    jq -r .auth.client_token}
}

vp() {
  vault-login $VAULT_PRODUCTION_ADDRESS
}

vs() {
  vault-login $VAULT_STAGING_ADDRESS
}
