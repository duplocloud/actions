#!/usr/bin/env bash

echo "Discovering login info..."

# if the docker username is set then use the username and password in the outputs
if [[ -n "$DOCKER_USERNAME" ]]; then
  echo "username=${DOCKER_USERNAME}" >> $GITHUB_OUTPUT
  echo "password=${DOCKER_PASSWORD}" >> $GITHUB_OUTPUT
# else if there is no username and GCP_ENABLED is true then use the gcloud auth
elif [[ "$GCP_ENABLED" == "true" ]]; then
  if [[ -z $CLOUDSDK_AUTH_ACCESS_TOKEN ]]; then 
    CLOUDSDK_AUTH_ACCESS_TOKEN="$(gcloud auth print-access-token)"
  fi 
  echo "username=oauth2accesstoken" >> $GITHUB_OUTPUT
  echo "password=${CLOUDSDK_AUTH_ACCESS_TOKEN}" >> $GITHUB_OUTPUT
  # if the registry variable is not set then guess it 
  if [[ -z "$REGISTRY" ]]; then
    REGISTRY="${DUPLO_DEFAULT_REGION}-docker.pkg.dev"
    echo "registry=${REGISTRY}" >> $GITHUB_OUTPUT
  fi
# else it's aws we need to check if push is false or else the registry won't get set
elif [[ "$AWS_ENABLED" == "true" ]]; then
  # If the registry is not set then default it to the default region
  if [[ -z "$REGISTRY" ]]; then
    REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com"
    echo "registry=${REGISTRY}" >> $GITHUB_OUTPUT
  fi
fi

# finally check one last time if the registry is set, if not then set it to public dockerhub
if [[ -z "$REGISTRY" ]]; then
  echo "registry=docker.io" >> $GITHUB_OUTPUT
fi
