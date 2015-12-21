#!/bin/bash
# Solano CI post_build hook (http://docs.solanolabs.com/Setup/setup-hooks/)

set -o errexit -o pipefail # Exit on error

# Only deploy if all tests have passed
if [[ "passed" != "$TDDIUM_BUILD_STATUS" ]]; then
  echo "\$TDDIUM_BUILD_STATUS = $TDDIUM_BUILD_STATUS"
  echo "Will only deploy on passed builds"
  exit
fi

# Uncomment if only the master branch should trigger deploys
if [[ "master" != "$TDDIUM_CURRENT_BRANCH" ]]; then
  echo "\$TDDIUM_CURRENT_BRANCH = $TDDIUM_CURRENT_BRANCH"
  echo "Will only depoloy on master branch"
  exit
fi

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

# Push image to Amazon ECR
sudo docker push $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/ci_memes:$TDDIUM_SESSION_ID


# Create new task definition from template file
sed -e "s;%TDDIUM_SESSION_ID%;$TDDIUM_SESSION_ID;g" ci_memes.json \
  | sed -e "s;%AWS_ACCOUNT_ID%;$AWS_ACCOUNT_ID;g" \
  > ci_memes-${TDDIUM_SESSION_ID}.json

# Register updated task
aws ecs register-task-definition --family ci_memes --cli-input-json file://ci_memes-${TDDIUM_SESSION_ID}.json

# Get revision number of newly created task definition
REV=`aws ecs describe-task-definition --task-definition ci_memes | jq '.taskDefinition.revision'`

# Update Amazon ECS service to use the new task definition
aws ecs update-service --cluster default --service ci_memes_service --task-definition ci_memes:${REV}

