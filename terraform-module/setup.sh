#!/usr/bin/env bash

MODULE=$(basename $WKDIR)
DEFAULT_BUCKET_NAME="${PREFIX}-${DUPLO_ACCOUNT_ID}"
DUPLO_TF_BUCKET=${DUPLO_TF_BUCKET:-$DEFAULT_BUCKET_NAME}
ARGS=(
  -input=false
)

if [ "$AWS_ENABLED" == "true" ]; then
  echo "AWS enabled, setting up backend config for S3 and DynamoDB"
  ARGS+=(
    -backend-config=dynamodb_table=${DUPLO_TF_BUCKET}-lock
    -backend-config=region=$DUPLO_DEFAULT_REGION
    -backend-config=bucket=$DUPLO_TF_BUCKET
  )
elif [ "$AZURE_ENABLED" == "true" ]; then
  echo "Azure enabled, setting up backend config for Blob Storage"
  # if the RESOURCE_GROUP variable is not set, fail with error
  if [ -z "$RESOURCE_GROUP" ]; then
    echo "RESOURCE_GROUP is not set, please set the variable"
    exit 1
  fi
  DUPLO_TF_BUCKET=duplotfstate${DUPLO_ACCOUNT_ID}
  ARGS+=(
    -backend-config=storage_account_name=$DUPLO_TF_BUCKET
  )
  ACCOUNT_KEY=$(az storage account keys list --resource-group $RESOURCE_GROUP --account-name $DUPLO_TF_BUCKET --query '[0].value' -o tsv)
  echo "ARM_ACCESS_KEY=$ACCOUNT_KEY" >> $GITHUB_ENV
elif [ "$GCP_ENABLED" == "true" ]; then
  echo "GCP enabled, setting up backend config for GCS"
  ARGS+=(
    -backend-config=bucket=$DUPLO_TF_BUCKET
  )
fi

# if the test dir has a value then add the param
if [ -n "$TEST_DIR" ]; then
  ARGS+=("-test-directory=$TEST_DIR")
fi

# check if the terraform lock file is present
LOCK_FILE=".terraform.lock.hcl"
if [ -f "${LOCK_FILE}" ] && [ "$CACHING" = "true" ]; then
  MODULE_CACHE="true"
  echo "Terraform lock file detected and caching enabled"
fi

# these are for the next steps
echo "module_cache=$MODULE_CACHE" >> $GITHUB_OUTPUT
echo "lockfile=$WKDIR/$LOCK_FILE" >> $GITHUB_OUTPUT
echo "module=$MODULE" >> $GITHUB_OUTPUT
echo "args=${ARGS[*]}" >> $GITHUB_OUTPUT

# some more useful env vars
echo "DUPLO_TF_BUCKET=$DUPLO_TF_BUCKET" >> $GITHUB_ENV
