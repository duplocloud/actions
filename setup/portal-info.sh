#!/usr/bin/env bash

# Validate required environment variables
if [ -z "$DUPLO_TOKEN" ]; then
  echo "ERROR: DUPLO_TOKEN environment variable is not set"
  echo "Please ensure DUPLO_TOKEN is set in your GitHub workflow before calling this action"
  exit 1
fi

if [ -z "$DUPLO_HOST" ]; then
  echo "ERROR: DUPLO_HOST environment variable is not set"
  echo "Please ensure DUPLO_HOST is set in your GitHub workflow before calling this action"
  exit 1
fi

# Fetch portal info with retry logic
MAX_RETRIES=5
RETRY_DELAY=2
ATTEMPT=1

while [ $ATTEMPT -le $MAX_RETRIES ]; do
  echo "Fetching portal info (attempt $ATTEMPT/$MAX_RETRIES)..."
  
  if PORTAL_INFO="$(duploctl system info 2>&1)"; then
    # Validate that we got valid JSON response
    if echo "$PORTAL_INFO" | jq empty 2>/dev/null; then
      echo "Successfully retrieved portal info"
      break
    else
      echo "WARNING: Invalid JSON response from duploctl system info"
      echo "Response: $PORTAL_INFO"
    fi
  else
    echo "WARNING: Failed to get portal info from duploctl"
    echo "Output: $PORTAL_INFO"
  fi
  
  # If this was the last attempt, exit with error
  if [ $ATTEMPT -eq $MAX_RETRIES ]; then
    echo "ERROR: Failed to get valid portal info after $MAX_RETRIES attempts"
    exit 1
  fi
  
  # Wait before retrying with exponential backoff
  WAIT_TIME=$((RETRY_DELAY * ATTEMPT))
  echo "Retrying in $WAIT_TIME seconds..."
  sleep $WAIT_TIME
  
  ATTEMPT=$((ATTEMPT + 1))
done

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
