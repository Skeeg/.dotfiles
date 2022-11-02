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
tfenvironment() {[[ $(cat .terraform/environment) = 'staging' ]] || \
  [[ $(cat .terraform/environment) = 'production' ]] && \
  cat .terraform/environment || \
  tfcenv}
# ************************************* #

tfep() {terraform workspace select production; kubectx app-production.kube.us-west-2.ldap}
tfes() {terraform workspace select staging; kubectx app-k8s.eplur-staging.us-west-2.ldap}

refresh-tfenv-vers () {
  tfvers=$(tfenv list-remote)
  for TFVERSION in $(echo $tfvers | grep -e "^1\." | cut -d"." -f1-2 | uniq)
    tfenv install latest\:^$TFVERSION
  for TFVERSION in $(echo $tfvers | grep -e "^0\.1[2-6]\..*" | cut -d"." -f1-2 | uniq)
    TFENV_ARCH=amd64 tfenv install latest\:^$TFVERSION
}

