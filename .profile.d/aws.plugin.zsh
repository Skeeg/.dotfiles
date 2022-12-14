# Custom plugin for zsh
#
# AWS Functions
#
# Author: Ryan Peay
# Date:   Mon Aug 8 21:28:29 MST 2022
#

#AWS Roles alias
# aws-eplur-production() { aws_okta_keyman -ro DevOpsRole --ap 0oaavo655hYcO4Vrv1t7/272 -ac eplur-production-ps -du $SAML2AWS_SESSION_DURATION --password_cache -re us-west-2; . ~/Downloads/set-aws-env-vars.sh }
# aws-eplur-staging() { aws_okta_keyman -ro DevOpsRole --ap 0oaavo655hYcO4Vrv1t7/272 -ac eplur-staging-ps -du $SAML2AWS_SESSION_DURATION --password_cache -re us-west-2; . ~/Downloads/set-aws-env-vars.sh }
# aws-backup() { aws_okta_keyman -ro DevOpsRole --ap 0oaavo655hYcO4Vrv1t7/272 -ac backups-ps -du $SAML2AWS_SESSION_DURATION --password_cache -re us-west-2; . ~/Downloads/set-aws-env-vars.sh }
# aws-shared-sandbox() { aws_okta_keyman -ro DevOpsRole --ap 0oaavo655hYcO4Vrv1t7/272 -ac shared-sandbox-ps -du $SAML2AWS_SESSION_DURATION --password_cache -re us-west-2; . ~/Downloads/set-aws-env-vars.sh }
# aws-orgmaster() { aws_okta_keyman -ro DevOpsRole --ap 0oaavo655hYcO4Vrv1t7/272 -ac orgmaster-ps -du $SAML2AWS_SESSION_DURATION --password_cache -re us-west-2; . ~/Downloads/set-aws-env-vars.sh }

# Set AWS output to not use `less`
export AWS_PAGER="";

SAML2AWS_SESSION_DURATION=28800
export SAML2AWS_SESSION_DURATION

saml2aws-production() {
  saml2aws login --force --skip-prompt --role=$ROLE_ARN_PRODUCTION
}
saml2aws-staging() {
  saml2aws login --force --skip-prompt --role=$ROLE_ARN_STAGING
}
saml2aws-orgmaster() {
  saml2aws login --force --skip-prompt --role=$ROLE_ARN_ORGMASTER
}
saml2aws-devops() {
  saml2aws login --force --skip-prompt --role=$ROLE_ARN_DEVOPS
}

update-secretsmanager-entry-from-lastpass() {
  USAGE="
    Usage:
    !!!!!!!!!!!! Make sure you are in the right account first !!!!!!!!!!!!
    !!!!! Confirmation via \`aws sts get-caller-identity\` recommended !!!!!
    > update-secretsmanager-entry-from-lastpass [Secret-Name] [Secret-JSON-Text]
    example: update-secretsmanager-entry-from-lastpass \\
      \"bounded-context\\\application-secrets\" \\
      \"\$(lpass show --note \"last-pass-card-name\" | jq -c)\"

      Honestly, this is a barely useful wrapper around what could be easily achieved with 
      properly wrapping the json input to the aws secretsmanager method with quotes
      and also leveraging compressed json via \`jq-c\`.  Such as this:
      
      aws secretsmanager update-secret \\
        --secret-id \"secret-name\" \\
        --secret-string \"\$(lpass show --note '<cardname>' | jq -c)\"

      However, this function allows a little \"prettier\" json to potentially be ingested....
      Nah, still need to make sure you do not provide json that has IFS qualified separators.  
          jq -c is your friend
  "
	X_SECRET_NAME="$1"
  X_SECRET_STRING="$2"
	ARG_LENGTH="$#"
  if [ $ARG_LENGTH -eq "2" ]
  then
  OLDIFS=$IFS; IFS=
  aws secretsmanager update-secret \
    --secret-id "$X_SECRET_NAME" \
    --secret-string "$X_SECRET_STRING"; 
  IFS=$OLDIFS
  else
    echo $USAGE
  fi
  unset X_SECRET_NAME X_SECRET_STRING
}
