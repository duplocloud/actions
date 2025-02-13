#!/usr/bin/env bash

ARGS=($EXTRA_ARGS)

# if push is true then add the arg and the builder is bake
if [[ "$PUSH" == "true" ]]; then
  ARGS+=(--push)
fi

# optionally disable cache
if [[ "$CACHE" == "false" ]]; then
  ARGS+=(--no-cache)
fi

# if the builder is compose it can have build args too
if [[ "$BUILD_TYPE" == "compose" ]]; then
  build_args=($BUILD_ARGS)
  for arg in ${build_args[*]}; do
    ARGS+=(--build-arg "${arg}")
  done
fi

# if a build file is given then add it
if [[ -n "$BUILD_FILE" ]]; then
  ARGS+=(--file "${BUILD_FILE}")
fi

# if target is set then add the arg
if [[ -n "$TARGET" ]]; then
  ARGS+=("${TARGET}")
fi

echo "args=${ARGS[*]}" >> $GITHUB_OUTPUT
