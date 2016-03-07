#!/bin/bash
# Solano CI worker_setup hook (http://docs.solanolabs.com/Setup/setup-hooks/)

set -o errexit -o pipefail # Exit on error

# Start docker container and record ID and IP address
CID=$(sudo docker run -d --expose=80 $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/${AWS_ECR_REPO}:$TDDIUM_SESSION_ID)
echo $CID > $TDDIUM_REPO_ROOT/container-$TDDIUM_SESSION_ID-$TDDIUM_TID.cid
IP_ADDR=$(sudo docker inspect --format '{{ .NetworkSettings.IPAddress }}' $CID)
echo $IP_ADDR > $TDDIUM_REPO_ROOT/container-$TDDIUM_SESSION_ID-$TDDIUM_TID.ip

# Give the docker container services a bit of time to start up
sleep 15

# Setup the database
grep -v ^"CREATE DATABASE" create-db.sql | grep -v ^USE > tests/create-test-db.sql
mysql -u$TDDIUM_DB_USER -p$TDDIUM_DB_PASSWORD $TDDIUM_DB_NAME < tests/create-test-db.sql
