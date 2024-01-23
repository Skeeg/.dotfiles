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

# Introduced to me by John Meyers aka MoJoJoJu
function ec2-bc() {
  if [ $# -le 0 ]
  then
    echo "Enter a Bounded Context name to search for: ec2-bc some-name"
    return 0
  fi
  aws ec2 describe-instances \
    --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value[]]' \
    --filters "Name=tag-value,Values=$1" --output text | \
    sed '$!N;s/\n/ /' | \
    sort -k2
}

# Introduced to me by John Meyers aka MoJoJoJu
function ssm() {
  if [ $# -le 0 ]
  then
    echo "Enter an Instance ID: ssm i-0123456789abcedf"
    return 0
  fi
  aws ssm start-session --target "$1"
}

# Introduced to me by Rob Rotaru
function fzf-aws-ssm() {
  if ! aws sts get-caller-identity > /dev/null 2>&1
  then
    echo "No active AWS session, run 'assume' first."
    return 0
  fi

  if [ $# -le 0 ]
  then
    echo "Enter an EC2 tag to search for (e.g. 'saltmaster')"
    return 0
  fi

  instance_id=$(ec2-bc $1 | fzf --height 50% --ansi --no-multi --preview 'aws ec2 describe-instances --instance-ids $(sed "s/^\(i-[0-9a-f]*\).*$/\1/" <<< {}) --output yaml-stream' | awk '{print $1}')
  ssm $instance_id
}

function get-instance-password() {
SCRIPT_INSTANCE_NAME="$1"
BANNER_STRING="########################################"

printf "\n%s\nInstance Information\n%s\n" "$BANNER_STRING" "$BANNER_STRING"

data=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$SCRIPT_INSTANCE_NAME" \
  "Name=instance-state-name,Values=running" | \
  jq --raw-output '.Reservations[].Instances[] | (.Tags[] ? | select(.Key=="Name")|.Value) as $Name | {Name: $Name, InstanceId: .InstanceId, PrivateIPAddress: .PrivateIpAddress, Launchtime: .LaunchTime, State: .State.Name, Key: .KeyName}')
#output data
echo "$data" | jq .
aws ec2 get-password-data --instance-id "$(echo "$data" | jq --raw-output .InstanceId)" \
  --priv-launch-key "$HOME/.ssh/$(echo "$data" | jq --raw-output .Key)".pem | \
  jq --raw-output .PasswordData;
}
