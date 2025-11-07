#!/usr/bin/env bash

ARGS=(
  -input=false
)
MODULE_NAME=$(basename "$MODULE")
PLAN_FILE="${TF_WORKSPACE}-${MODULE_NAME}.tfplan"
echo "module_name=$MODULE_NAME" >> "$GITHUB_OUTPUT"

# if parallelism is set then add it to the args
if [ -n "$TF_PARALLELISM" ]; then
  ARGS+=("-parallelism=$TF_PARALLELISM")
fi

# if target is set then add it to the args
if [ -n "$TF_TARGET" ]; then
  ARGS+=("-target=$TF_TARGET")
fi

# append workspace variables files if they exist
TF_VARS_FILE="$CONFIG_DIR/$TF_WORKSPACE/$MODULE_NAME.tfvars"
echo "Discovering vars at $TF_VARS_FILE"
if [ -f "$TF_VARS_FILE" ]; then
  echo "Found $TF_VARS_FILE"
  ARGS+=("-var-file=$TF_VARS_FILE")
fi
echo "Discovering vars at $TF_VARS_FILE.json"
if [ -f "$TF_VARS_FILE.json" ]; then
  echo "Found $TF_VARS_FILE.json"
  ARGS+=("-var-file=$TF_VARS_FILE.json")
fi

# the var-files is string with each new line containing a file path to a vars file. The files are relative to the CONFIG_DIR. For each of these files adda -var-file arg to the ARGS
if [ -n "$TF_INPUT_VAR_FILES" ]; then
  VAR_FILES=("$TF_INPUT_VAR_FILES")
  for VAR_FILE in "${VAR_FILES[@]}"; do
    echo "Adding var file: $VAR_FILE"
    VAR_FILE_PATH="$CONFIG_DIR/$VAR_FILE"
    ARGS+=("-var-file=$VAR_FILE_PATH")
  done
fi

# if the plan is to destroy then add -destroy to the args
if [ "$TF_COMMAND" == "destroy" ]; then
  ARGS+=("-destroy")
  PLAN_FILE="${TF_COMMAND}-${PLAN_FILE}"
fi

echo "The tf args: ${ARGS[*]}"
echo "The plan file: $PLAN_FILE"
echo "PLAN_FILE=$PLAN_FILE" >> $GITHUB_ENV
echo "planfile=$PLAN_FILE" >> $GITHUB_OUTPUT
echo "args=${ARGS[*]}" >> $GITHUB_OUTPUT
