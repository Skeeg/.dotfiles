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

# ec2-bc, ssm, fzf-aws-ssm, get-instance-password → bin/ scripts

ae() {
  assume $1 --export
  assume --unset
}

ae-nonprod() {
  for ACCOUNT in staging_developer uat_developer ps_dev_readonlycore ps_stage_readonlycore ps_uat_readonlycore;
  do
    ae $ACCOUNT
  done
}

ae-prod() {
  for ACCOUNT in production_developer ps_prod_readonlycore; do assume $ACCOUNT --export; done; assume --unset
}
