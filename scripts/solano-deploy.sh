#!/bin/bash
# Solano CI post_build hook (http://docs.solanolabs.com/Setup/setup-hooks/)

set -o errexit -o pipefail # Exit on error

# Only deploy if all tests have passed
if [[ "passed" != "$TDDIUM_BUILD_STATUS" ]]; then
  echo "\$TDDIUM_BUILD_STATUS = $TDDIUM_BUILD_STATUS"
  echo "Will only deploy on passed builds"
  exit
fi

# Deploy on use_iam_role branch to test
# Uncomment if only the master branch should trigger deploys
#if [[ "master" != "$TDDIUM_CURRENT_BRANCH" ]]; then
#  echo "\$TDDIUM_CURRENT_BRANCH = $TDDIUM_CURRENT_BRANCH"
#  echo "Will only depoloy on master branch"
#  exit
#fi

# Uncomment if cli-initiated Solano CI builds should not trigger deploys
#if [[ "ci" != "$TDDIUM_MODE" ]]; then
#  echo "\$TDDIUM_MODE = $TDDIUM_MODE"
#  echo "Will on deploy on ci initiated builds."
#  exit
#fi

# Deploy?
if [ -z "$DEPLOY_AWS_ECS" ] && [[ "true" == "$DEPLOY_AWS_ECS" ]]; then
  echo "Will only deploy if \$DEPLOY_AWS_ECS is true."
  exit
fi

# Set aws lib path
if [ -d $HOME/lib/python2.7/site-packages ]; then
  export PYTHONPATH=$HOME/lib/python2.7/site-packages
fi

# Use IAM Role (aws_env file created by scripts/solano-pre_setup.sh)
source .aws_env

# Push image to Amazon ECR
sudo docker push $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/${AWS_ECR_REPO}:$TDDIUM_SESSION_ID

# Create new task definition from template file
sed -e "s;%TDDIUM_SESSION_ID%;$TDDIUM_SESSION_ID;g" ci_memes.json \
  | sed -e "s;%AWS_ACCOUNT_ID%;$AWS_ACCOUNT_ID;g" \
  | sed -e "s;%AWS_ECS_TASK%;$AWS_ECS_TASK;g" \
  | sed -e "s;%AWS_ECR_REPO%;$AWS_ECR_REPO;g" \
  > ci_memes-${TDDIUM_SESSION_ID}.json

# Register updated task
aws ecs register-task-definition --family $AWS_ECS_TASK --cli-input-json file://ci_memes-${TDDIUM_SESSION_ID}.json

# Get revision number of newly created task definition
REV=`aws ecs describe-task-definition --task-definition $AWS_ECS_TASK | jq '.taskDefinition.revision'`

# Update Amazon ECS service to use the new task definition
aws ecs update-service --cluster $AWS_ECS_CLUSTER --service $AWS_ECS_SERVICE --task-definition ${AWS_ECS_TASK}:${REV}

# Attach task definition to Solano CI build page
if [ -n "$TDDIUM" ]; then
  cp ci_memes-${TDDIUM_SESSION_ID}.json $HOME/results/$TDDIUM_SESSION_ID/session/
fi
