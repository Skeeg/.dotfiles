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
tftargets() {
  for a in $(terraform plan | grep " be" | awk '{print $3}' | grep -e "aws" -e "vault"); 
  do
    echo "--target='$a' \\"
  done
}

tftargetsraw() {
  for a in $(terraform plan | grep " be" | awk '{print $3}' | grep -e "aws" -e "vault" | grep -v "cloudwatch"); 
  do
    printf "--target=$a "
  done
}

# Terraform workspace aliases
# ******* These are the latest ******** #
tfcs() {
  terraform workspace select "${PWD##*/}-staging-us-west-2" && kubestage
}
tfcu() {
  terraform workspace select "${PWD##*/}-uat-us-west-2" && kubepuat
}
tfcp() {
  terraform workspace select "${PWD##*/}-production-us-west-2" && kubeprod
}
tfcdr() {
  terraform workspace select "${PWD##*/}-production-us-east-2-dr"
}

tfcenv() {
  cat .terraform/environment | sed -n \
  -e "s/^.*-\(\staging\).*$/\1/p" \
  -e "s/^.*-\(\production\).*$/\1/p"
}
tfenvironment() {
  [[ $(cat .terraform/environment) = 'staging' ]] || \
  [[ $(cat .terraform/environment) = 'production' ]] && \
  cat .terraform/environment || \
  tfcenv
}
# ************************************* #

tfep() {
  terraform workspace select production; kubectx app-production.kube.us-west-2.ldap
}
tfes() {
  terraform workspace select staging; kubectx app-k8s.eplur-staging.us-west-2.ldap
}

refresh-tfenv-vers () {
  tfvers=$(tfenv list-remote)
  for TFVERSION in $(echo $tfvers | grep -e "^1\." | cut -d"." -f1-2 | uniq)
  do
    tfenv install "latest:^$TFVERSION"
  done
  for TFVERSION in $(echo $tfvers | grep -e "^0\.1[2-6]\..*" | cut -d"." -f1-2 | uniq)
  do
    TFENV_ARCH=amd64 tfenv install "latest:^$TFVERSION"
  done
}

tf-validate() {
  terraform validate -json | \
  jq '.diagnostics[] | {detail: .detail, filename: .range.filename, start_line: .range.start.line}'
}

# Some really specific commands I use with some workspaces for rebuild processes
check-terraform-target-group-status() {
if [ ! -e "./.terraform/environment" ]
  then
  if which cowsay &> /dev/null;
  then
    cowsay "you have to be in a terraform directory that is correctly initialized"
  else
    echo "you have to be in a terraform directory that is correctly initialized"
  fi
  return 0
fi

  unset ENVIRON
  ENVIRON=$(tfenvironment)

  TERRAFORM_DATA=$(terraform show --json | \
      jq -r '.values.outputs.automation_target_groups.value.target_group_arns[]')

  for TARGET_GROUP in $(echo "$TERRAFORM_DATA" | tr '\n' ' ')
  do
    echo "$TARGET_GROUP"
    TARGET_HEALTH=$(AWS_PROFILE="$ENVIRON" aws elbv2 describe-target-health --target-group-arn "$TARGET_GROUP")
    echo "$TARGET_HEALTH" | jq -c '.TargetHealthDescriptions[]'
  done
}
