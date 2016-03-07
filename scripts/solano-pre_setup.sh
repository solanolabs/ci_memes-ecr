#!/bin/bash
# Solano CI pre_setup hook (http://docs.solanolabs.com/Setup/setup-hooks/)

set -o errexit -o pipefail # Exit on error

# Ensure the necessary environment variables have been set
required_vars="AWS_DEFAULT_REGION AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_ACCOUNT_ID AWS_IAM_ROLE_NAME AWS_ECS_TASK AWS_ECS_SERVICE AWS_ECS_CLUSTER AWS_ECR_REPO"
vars_set=true
for var in $required_vars; do
  eval val=\""\$$var"\"
  if [ "$val" == "" ]; then
    echo "ERROR: $var is not set"
    vars_set=false
  fi
done
if [ "$vars_set" == "false" ]; then
  echo "ERROR: Not all required environemnt variables are set"
  echo 'Please use `solano config:add <scope> <key> <value>` to set these values'
  echo 'See: http://docs.solanolabs.com/Setup/setting-environment-variables/#via-config-variables'
  exit 1
fi

# Install aws-cli if it is not already installed
if [[ ! -f "$HOME/bin/aws" ]]; then
  curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip"
  unzip awscli-bundle.zip
  ./awscli-bundle/install -b $HOME/bin/aws # $HOME/bin is in $PATH
fi

# Set lib path
if [ -d $HOME/lib/python2.7/site-packages ]; then
  export PYTHONPATH=$HOME/lib/python2.7/site-packages
fi

# Install jq if it is not already installed
if [[ ! -f "$HOME/bin/jq" ]]; then
  wget -O $HOME/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64
  chmod +x $HOME/bin/jq # $HOME/bin is in $PATH
fi

# Assume IAM role and save role credentials in .aws_env file for later use
aws sts assume-role --role-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:role/${AWS_IAM_ROLE_NAME}" --role-session-name "Session-${AWS_IAM_ROLE_NAME}" > .aws_env.json
echo "export AWS_ACCESS_KEY_ID=`jq '.Credentials.AccessKeyId' .aws_env.json | sed 's#"##g'`" > .aws_env
echo "export AWS_SECRET_ACCESS_KEY=`jq '.Credentials.SecretAccessKey' .aws_env.json | sed 's#"##g'`" >> .aws_env
echo "export AWS_SESSION_TOKEN=`jq '.Credentials.SessionToken' .aws_env.json | sed 's#"##g'`" >> .aws_env
source .aws_env

# Fetch Amazon ECR generated docker login command and login
LOGIN_CMD=`aws ecr get-login`
sudo $LOGIN_CMD

# Build the image
sudo docker build -t $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/${AWS_ECR_REPO}:$TDDIUM_SESSION_ID .

# Install PHP dependencies
composer install

