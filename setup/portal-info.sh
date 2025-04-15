#!/usr/bin/env bash

PORTAL_INFO="$(duploctl system info)"

AWS_ENABLED="$(echo "$PORTAL_INFO" | jq -r '.IsAwsCloudEnabled')"
GCP_ENABLED="$(echo "$PORTAL_INFO" | jq -r '.IsGoogleCloudEnabled')"
AZURE_ENABLED="$(echo "$PORTAL_INFO" | jq -r '.IsAzureCloudEnabled')"

echo "Portal info discovered"

# configure the cloud environments
if [[ "$AWS_ENABLED" == "true" ]]; then
  DUPLO_PROVIDER="aws"
elif [[ "$GCP_ENABLED" == "true" ]]; then
  DUPLO_PROVIDER="gcp"
elif [[ "$AZURE_ENABLED" == "true" ]]; then
  DUPLO_PROVIDER="azure"
fi
echo "Configuring for $DUPLO_PROVIDER"

# if this is gcp or azure then we'll discover the default account and region
if [ "$DUPLO_PROVIDER" == "aws" ]; then
  DUPLO_ACCOUNT_ID="$(echo "$PORTAL_INFO" | jq -r '.DefaultAwsAccount')"
  DUPLO_DEFAULT_REGION="$(echo "$PORTAL_INFO" | jq -r '.DefaultAwsRegion')"
  {
    echo "AWS_DEFAULT_REGION=$DUPLO_DEFAULT_REGION"
    echo "AWS_ACCOUNT_ID=$DUPLO_ACCOUNT_ID"
    echo "DUPLO_ACCOUNT_ID=$DUPLO_ACCOUNT_ID"
    echo "DUPLO_DEFAULT_REGION=$DUPLO_DEFAULT_REGION"
  } >> "$GITHUB_ENV"
else 
  # if DUPLO_ACCOUNT_ID is not set then
  if [ -z "$DUPLO_ACCOUNT_ID" ]; then
    ACCOUNT_KEY='Accountid'
  else
    ACCOUNT_KEY="'$DUPLO_ACCOUNT_ID'"
  fi
  # if DUPLO_DEFAULT_REGION is not set then
  if [ -z "$DUPLO_DEFAULT_REGION" ]; then
    REGION_KEY='Region'
  else
    REGION_KEY="'$DUPLO_DEFAULT_REGION'"
  fi
  # if either the account or region is not set then
  if [ -z "$DUPLO_ACCOUNT_ID" ] || [ -z "$DUPLO_DEFAULT_REGION" ]; then
    duploctl infrastructure find default \
      --query "{DUPLO_ACCOUNT_ID: $ACCOUNT_KEY, DUPLO_DEFAULT_REGION: $REGION_KEY}" \
      --output env >> "$GITHUB_ENV"
  else
    {
      echo "DUPLO_ACCOUNT_ID=$DUPLO_ACCOUNT_ID"
      echo "DUPLO_DEFAULT_REGION=$DUPLO_DEFAULT_REGION"
    } >> "$GITHUB_ENV"
  fi
fi

# if is admin 
if [[ "$ISADMIN" == "true" ]]; then
  echo "ADMIN_FLAG=--admin" >> "$GITHUB_OUTPUT"
else
  echo "ADMIN_FLAG=" >> "$GITHUB_OUTPUT"
fi

{
  echo "AWS_ENABLED=$AWS_ENABLED"
  echo "GCP_ENABLED=$GCP_ENABLED"
  echo "AZURE_ENABLED=$AZURE_ENABLED"
  echo "DUPLO_PROVIDER=$DUPLO_PROVIDER"
  echo "duplo_token=$DUPLO_TOKEN"
  echo "duplo_host=$DUPLO_HOST"
} >> "$GITHUB_ENV"
