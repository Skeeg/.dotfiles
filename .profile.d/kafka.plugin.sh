## Kafka Stuff
dvs-bootstrap-staging() {
  export DVS_BOOTSTRAP_STAGING=$(aws ssm get-parameter --name "$DVS_MSK_SSM_PARAM" --output text --query Parameter.Value)
  export DVS_BOOTSTRAP_STAGING_SASL=$(echo $DVS_BOOTSTRAP_STAGING | sed 's/9098/9096/g')
}

dvs-bootstrap-production() {
  export DVS_BOOTSTRAP_PRODUCTION=$(aws ssm get-parameter --name "$DVS_MSK_SSM_PARAM" --output text --query Parameter.Value)
  export DVS_BOOTSTRAP_PRODUCTION_SASL=$(echo $DVS_BOOTSTRAP_PRODUCTION | sed 's/9098/9096/g')
}

dvs-topic-size-staging() {
  if [[ -z "${DVS_BOOTSTRAP_STAGING}" ]]; then
    dvs-bootstrap-staging
  fi
  kafka-log-dirs --bootstrap-server $DVS_BOOTSTRAP_STAGING --command-config ~/sasl-iam.properties --describe --topic-list $1 | grep '^{' | jq '[ ..|.size? | numbers ] | add' | numfmt --to iec --format "%8.2f" | tr -d '\n' && echo \,$1
}

dvs-topic-size-production() {
  if [[ -z "${DVS_BOOTSTRAP_PRODUCTION}" ]]; then
    dvs-bootstrap-production
  fi
  kafka-log-dirs --bootstrap-server $DVS_BOOTSTRAP_PRODUCTION --command-config ~/sasl-iam.properties --describe --topic-list $1 | grep '^{' | jq '[ ..|.size? | numbers ] | add' | numfmt --to iec --format "%8.2f" | tr -d '\n' && echo \,$1
}

dvs-describe-staging-consumer() {
  if [[ -z "${DVS_BOOTSTRAP_STAGING}" ]]; then
    dvs-bootstrap-staging
  fi  
  kafka-consumer-groups --bootstrap-server $DVS_BOOTSTRAP_STAGING --command-config ~/sasl-iam.properties --describe --timeout 6000 --group "$1" | sort
}

dvs-describe-production-consumer() {
  if [[ -z "${DVS_BOOTSTRAP_PRODUCTION}" ]]; then
    dvs-bootstrap-production
  fi
  kafka-consumer-groups --bootstrap-server $DVS_BOOTSTRAP_PRODUCTION --command-config ~/sasl-iam.properties --describe --timeout 6000 --group "$1" | sort
}

dvs-list-staging-consumers() {
  if [[ -z "${DVS_BOOTSTRAP_STAGING}" ]]; then
    dvs-bootstrap-staging
  fi  
  kafka-consumer-groups --bootstrap-server $DVS_BOOTSTRAP_STAGING --command-config ~/sasl-iam.properties --list --timeout 60000 | sort
}

dvs-list-production-consumers() {
  if [[ -z "${DVS_BOOTSTRAP_PRODUCTION}" ]]; then
    dvs-bootstrap-production
  fi
  kafka-consumer-groups --bootstrap-server $DVS_BOOTSTRAP_PRODUCTION --command-config ~/sasl-iam.properties --list --timeout 60000 | sort
}

dvs-reset-offset-staging() {
  response=""
  if [ $# -le 1 ]
  then
    echo "Need consumer group and topic name: dvs-reset-offset-staging example-consumer-group-id example.topic.v0"
    return 0
  fi
  if [[ -z "${DVS_BOOTSTRAP_STAGING}" ]]; then
    dvs-bootstrap-staging
  fi
  vared -p "Resetting a topic could be a disaster. Are you REALLY sure? [Y/N] " response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
  then
      kafka-consumer-groups --bootstrap-server $DVS_BOOTSTRAP_STAGING --command-config ~/sasl-iam.properties --timeout 6000 --group "$1" --topic "$2" --reset-offsets --to-earliest --execute
  else
      echo " ¯\_(ツ)_/¯"
      cowsay -f deadpool-bob-ross.cow DISCRETION IS THE BETTER PART OF VALOR
  fi
}

dvs-reset-offset-production() {
  response=""
  if [ $# -le 1 ]
  then
    echo "Need consumer group and topic name: dvs-reset-offset-production example-consumer-group-id example.topic.v0"
    return 0
  fi
  if [[ -z "${DVS_BOOTSTRAP_PRODUCTION}" ]]; then
    dvs-bootstrap-production
  fi
  vared -p "Resetting a topic could be a disaster. Are you REALLY sure? [Y/N] " response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
  then
      kafka-consumer-groups --bootstrap-server $DVS_BOOTSTRAP_PRODUCTION --command-config ~/sasl-iam.properties --timeout 6000 --group "$1" --topic "$2" --reset-offsets --to-earliest --execute
  else
      echo " ¯\_(ツ)_/¯"
      cowsay -f deadpool-bob-ross.cow DISCRETION IS THE BETTER PART OF VALOR
  fi
}

dvs-change-offset-staging() {
  response=""
  if [ $# -le 1 ]
  then
    echo "Need consumer group and topic name: dvs-change-offset-staging example-consumer-group-id example.topic.v0 PARTITION +/-SHIFT"
    echo "PARTITION should be the integer of the partition you want to change."
    echo "OFFSET should be the integer of the new offset."
    return 0
  fi
  if [[ -z "${DVS_BOOTSTRAP_STAGING}" ]]; then
    dvs-bootstrap-staging
  fi
  vared -p "Changing an offset could be a disaster. Are you REALLY sure? [Y/N] " response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
  then
      kafka-consumer-groups --bootstrap-server $DVS_BOOTSTRAP_STAGING --command-config ~/sasl-iam.properties --timeout 6000 --group "$1" --topic "$2":"$3" --reset-offsets --to-offset "$4" --execute
  else
      echo " ¯\_(ツ)_/¯"
      cowsay -f deadpool-bob-ross.cow DISCRETION IS THE BETTER PART OF VALOR
  fi
}


dvs-change-offset-production() {
  response=""
  if [ $# -le 1 ]
  then
    echo "Need consumer group and topic name: dvs-change-offset-production example-consumer-group-id example.topic.v0 PARTITION OFFSET"
    echo "PARTITION should be the integer of the partition you want to change."
    echo "OFFSET should be the integer of the new offset."
    return 0
  fi
  if [[ -z "${DVS_BOOTSTRAP_PRODUCTION}" ]]; then
    dvs-bootstrap-production
  fi
  vared -p "Changing an offset could be a disaster. Are you REALLY sure? [Y/N] " response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
  then
      kafka-consumer-groups --bootstrap-server $DVS_BOOTSTRAP_PRODUCTION --command-config ~/sasl-iam.properties --timeout 6000 --group "$1" --topic "$2":"$3" --reset-offsets --to-offset "$4" --execute
  else
      echo " ¯\_(ツ)_/¯"
      cowsay -f deadpool-bob-ross.cow DISCRETION IS THE BETTER PART OF VALOR
  fi
}

dvs-describe-topic-staging() {
  if [[ -z "${DVS_BOOTSTRAP_STAGING}" ]]; then
    dvs-bootstrap-staging
  fi
  kafka-topics \
    --bootstrap-server $DVS_BOOTSTRAP_STAGING \
    --command-config ~/sasl-iam.properties \
    --describe --topic "$1"
}

dvs-describe-topic-production() {
  if [[ -z "${DVS_BOOTSTRAP_PRODUCTION}" ]]; then
    dvs-bootstrap-production
  fi
  kafka-topics \
    --bootstrap-server $DVS_BOOTSTRAP_PRODUCTION \
    --command-config ~/sasl-iam.properties \
    --describe --topic "$1"
}

dvs-topic-offset-count-staging() {
  if [[ -z "${DVS_BOOTSTRAP_STAGING}" ]]; then
    dvs-bootstrap-staging
  fi
  TOPICCOUNT=$(kafka-run-class kafka.tools.GetOffsetShell --bootstrap-server $DVS_BOOTSTRAP_STAGING --command-config ~/sasl-iam.properties --topic "$1")
  echo $TOPICCOUNT && echo $TOPICCOUNT | awk -F  ":" '{sum += $3} END {print "Result: "sum}'
}

dvs-topic-offset-count-production() {
  if [[ -z "${DVS_BOOTSTRAP_PRODUCTION}" ]]; then
    dvs-bootstrap-production
  fi
  TOPICCOUNT=$(kafka-run-class kafka.tools.GetOffsetShell --bootstrap-server $DVS_BOOTSTRAP_PRODUCTION --command-config ~/sasl-iam.properties --topic "$1")
  echo $TOPICCOUNT && echo $TOPICCOUNT | awk -F  ":" '{sum += $3} END {print "Result: "sum}'
}


## KCAT
dvs-get-sasl() {
  export SASLUSER=$(aws secretsmanager get-secret-value --secret-id "$DVS_MSK_SASL_SECRET_ID" --query SecretString --output text| jq -r '.username')
  export SASLPASS=$(aws secretsmanager get-secret-value --secret-id "$DVS_MSK_SASL_SECRET_ID" --query SecretString --output text| jq -r '.password')
}

dvs-get-offset-staging() {
  if [ $# -le 0 ]
  then
    echo "Need topic, partiiton, and offset: dvs-get-offset-staging skills.criterionRef.v1.Session 6 4538754"
    return 0
  fi
  if [[ -z "${DVS_BOOTSTRAP_STAGING_SASL}" ]]; then
    dvs-bootstrap-staging
  fi
  if [[ -z "${SASLPASS}" ]]; then
    dvs-get-sasl
  fi
  kcat -b $DVS_BOOTSTRAP_STAGING_SASL \
    -X security.protocol=SASL_SSL -X sasl.mechanism=SCRAM-SHA-512 -X sasl.username=$SASLUSER -X sasl.password=$SASLPASS \
    -r $DVS_SCHEMA_REGISTRY_STAGING -s key=avro -s value=avro \
    -f 'Partition: %p \nOffset: %o \nKey: %k \nValue: %s \n' -t "$1" -p "$2" -o "$3" -c 1
}

dvs-get-offset-production() {
  if [ $# -le 0 ]
  then
    echo "Need topic, partiiton, and offset: dvs-get-offset-production skills.criterionRef.v1.Session 6 4538754"
    return 0
  fi
  if [[ -z "${DVS_BOOTSTRAP_PRODUCTION_SASL}" ]]; then
    dvs-bootstrap-production
  fi
  if [[ -z "${SASLPASS}" ]]; then
    dvs-get-sasl
  fi
  kcat -b $DVS_BOOTSTRAP_PRODUCTION_SASL \
    -X security.protocol=SASL_SSL -X sasl.mechanism=SCRAM-SHA-512 -X sasl.username=$SASLUSER -X sasl.password=$SASLPASS \
    -r $DVS_SCHEMA_REGISTRY_PRODUCTION -s key=avro -s value=avro \
    -f 'Partition: %p \nOffset: %o \nKey: %k \nValue: %s \n' -t "$1" -p "$2" -o "$3" -c 1
}

dvs-topic-tail-staging() {
  if [[ -z "${DVS_BOOTSTRAP_STAGING_SASL}" ]]; then
    dvs-bootstrap-staging
  fi
  if [[ -z "${SASLPASS}" ]]; then
    dvs-get-sasl
  fi
  kcat -b $DVS_BOOTSTRAP_STAGING_SASL \
    -X security.protocol=SASL_SSL -X sasl.mechanism=SCRAM-SHA-512 -X sasl.username=$SASLUSER -X sasl.password=$SASLPASS \
    -r $DVS_SCHEMA_REGISTRY_STAGING -s key=avro -s value=avro \
    -t "$1" -o-10
}

dvs-topic-tail-production() {
  if [[ -z "${DVS_BOOTSTRAP_PRODUCTION_SASL}" ]]; then
    dvs-bootstrap-production
  fi
  if [[ -z "${SASLPASS}" ]]; then
    dvs-get-sasl
  fi
  kcat -b $DVS_BOOTSTRAP_PRODUCTION_SASL \
    -X security.protocol=SASL_SSL -X sasl.mechanism=SCRAM-SHA-512 -X sasl.username=$SASLUSER -X sasl.password=$SASLPASS \
    -r $DVS_SCHEMA_REGISTRY_PRODUCTION -s key=avro -s value=avro \
    -t "$1" -o-10
}
