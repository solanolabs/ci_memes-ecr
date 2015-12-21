#!/bin/bash
# Solano CI pre_setup hook (http://docs.solanolabs.com/Setup/setup-hooks/)

set -o errexit -o pipefail # Exit on error

# Ensure the necessary environment variables have been set
if [[ -z "$AWS_ACCESS_KEY_ID" || -z "$AWS_SECRET_ACCESS_KEY" || -z "$AWS_DEFAULT_REGION" || -z "$AWS_ACCOUNT_ID" ]]; then
  echo 'ERROR: The $AWS_ACCESS_KEY_ID, $AWS_SECRET_ACCESS_KEY, $AWS_DEFAULT_REGION, and $AWS_ACCOUNT_ID values are not all set!'
  echo 'Please use `solano config:add repo <key> <value>` to set these values'
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

# Fetch Amazon ECR generated docker login command and login
LOGIN_CMD=`aws ecr get-login`
sudo $LOGIN_CMD

# Build the image
sudo docker build -t $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/ci_memes:$TDDIUM_SESSION_ID .

# Install PHP dependencies
composer install

