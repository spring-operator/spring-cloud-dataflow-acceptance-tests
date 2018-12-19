#!/bin/bash

function generate_manifest() {
# NOTE: In classic mode the app-names are prefixed with the <SCDF-Name>-<Stream Name>- prefix.
# The random suffix in the SCDF name ensures that in classic mode the app-name's route paths are randomized and wouldn't
# interfere with acceptance tests run in different CF spaces.
SCDF_RANDOM_SUFFIX=$RANDOM
cat << EOF > ./scdf-manifest.yml
applications:
- name: dataflow-server-$SCDF_RANDOM_SUFFIX
  timeout: 120
  path: ./scdf-server.jar
  memory: 1G
  buildpack: $JAVA_BUILDPACK
  services:
    - mysql
    - redis
EOF
if [ $LOG_SERVICE_NAME ]; then
    cat << EOF >> ./scdf-manifest.yml
    - $LOG_SERVICE_NAME
EOF
fi
if [ "$SPRING_PROFILES_ACTIVE" = "cloud1" ]; then
    cat << EOF >> ./scdf-manifest.yml
    - cloud-config-server
EOF
fi
cat << EOF >> ./scdf-manifest.yml
    - rabbit2
  env:
    EXTERNAL_SERVERS_REQUIRED: true
    SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_URL: $SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_URL
    SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_DOMAIN: $SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_DOMAIN
    SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_ORG: $SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_ORG
    SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_SPACE: $SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_SPACE
    SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_USERNAME: $SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_USERNAME
    SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_PASSWORD: $SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_PASSWORD
    SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_SKIP_SSL_VALIDATION: $SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_SKIP_SSL_VALIDATION
    SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_STREAM_SERVICES: $SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_STREAM_SERVICES
    SPRING_APPLICATION_JSON: '{ "maven": { "remote-repositories": { "repo1": { "url": "$MAVEN_REMOTE_REPOSITORIES_REPO1_URL" } } } }'
    SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_STREAM_API_TIMEOUT: $SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_API_TIMEOUT
    SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_TASK_API_TIMEOUT: $SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_API_TIMEOUT
    TRUST_CERTS: $TRUST_CERTS
    SPRING_PROFILES_ACTIVE: $SPRING_PROFILES_ACTIVE
    SPRING_CLOUD_DATAFLOW_APPLICATIONPROPERTIES_STREAM_TRUST_CERTS: $TRUST_CERTS
    SPRING_CLOUD_DATAFLOW_APPLICATIONPROPERTIES_TASK_TRUST_CERTS: $TRUST_CERTS
    SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_STREAM_ENABLE_RANDOM_APP_NAME_PREFIX: false
    SPRING_CLOUD_DATAFLOW_FEATURES_SKIPPER_ENABLED: $SPRING_CLOUD_DATAFLOW_FEATURES_SKIPPER_ENABLED
    SPRING_CLOUD_SKIPPER_CLIENT_SERVER_URI: $SKIPPER_SERVER_URI/api
    SPRING_CLOUD_CONFIG_NAME: scdf-server
    SPRING_CLOUD_COMMON_SECURITY_ENABLED: $SPRING_CLOUD_COMMON_SECURITY_ENABLED
EOF

if [ "$schedulesEnabled" ]; then
    cat << EOF >> ./scdf-manifest.yml
    SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_TASK_SERVICES: $SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_TASK_SERVICES,$SCHEDULES_INSTANCE_NAME
    SPRING_CLOUD_DATAFLOW_FEATURES_SCHEDULES_ENABLED: true
    SPRING_CLOUD_SCHEDULER_CLOUDFOUNDRY_SCHEDULER_URL: $SCHEDULES_URL

EOF
else
    cat << EOF >> ./scdf-manifest.yml
    SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_TASK_SERVICES: $SPRING_CLOUD_DEPLOYER_CLOUDFOUNDRY_TASK_SERVICES
EOF
fi

}

function push_application() {
  echo "============================="
  echo "scdf-manifest.yml contents..."
  cat scdf-manifest.yml
  cf push -f scdf-manifest.yml
  rm -f scdf-manifest.yml
}

if [ -z "$DOWNLOADED_SERVER" ]; then
  download $PWD
else
  echo "Already downloaded Data Flow Server"
fi
generate_manifest
push_application
run_scripts "$PWD" "config.sh"
