# Custom plugin for zsh
#
# Various Functions
#
# Author: Ryan Peay
# Date:   Wed Sep 20 09:01:29 MST 2023
#

# DVS convenience functions
streamstatus() {
  curl -s -S "$2/jobs/$1/status" | jq .
}

restartstream() {
  curl -s -S -X POST "$2/jobs/$1/stop" ; 
  sleep 15 ; 
  curl -s -S -X POST "$2/jobs/$1/start" ;
}

# JFrog Artifactory convenience functions
artifactory-download() {
  RESULT=$(curl -H "X-JFrog-Art-Api:$1" \
    -H 'Content-Type: text/plain' \
    -X POST "$2/api/search/aql" \
    -d "items.find( { \"\$and\": [ { \"@release.production\" : { \"\$match\" : \"true\" } }, { \"name\": {\"\$match\" : \"$3*\" } } ] })" | \
    jq -c '.results[] | {repo,path,name}')
  echo "$2/$(echo $RESULT | jq -r .repo)/$(echo $RESULT | jq -r .path)/$(echo $RESULT | jq -r .name)"
}

# BC specific convenience functions
mitigations-up () {
	compose-up mitigations_v2
}

mitigations-down () {
	compose-down mitigations_v2
}

identity-up () {
	compose-up identity
}

identity-down () {
	compose-down identity
}


terraform_target_group_parse() {
  EXEC_MODE="$1"
  tfoutputdata=$(terraform show --json | jq -r '.values.outputs')
  for tgname in $(echo "$tfoutputdata" | jq --raw-output '.tg_attachments.value | keys[]')
  do
    echo \#$tgname
    tgdata=$(echo "$tfoutputdata" | jq --raw-output ".tg_attachments.value.$tgname")
    tgarn=$(echo "$tgdata" | jq --raw-output '.target_group')
    for tginstance in $(echo "$tgdata" | jq --raw-output '.target_id[]')
    do
      instancename=$(echo "$tfoutputdata" | jq --raw-output ".ec2_id_mapping.value.instances.\"$tginstance\"")
      if [[ $EXEC_MODE = "verbose" ]];
        then
            echo "aws elbv2 deregister-targets --target-group-arn $tgarn --targets Id=$tginstance; #$instancename "
        else
            echo "aws elbv2 deregister-targets --target-group-arn $tgarn --targets Id=$tginstance;"
      fi

    done
  done
}