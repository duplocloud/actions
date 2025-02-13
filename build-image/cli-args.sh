#!/usr/bin/env bash  

echo "Building args for docker cli command " 

ARGS=($EXTRA_ARGS)

# add dockerfile param if given
if [[ -n "$DOCKERFILE" ]]; then
  ARGS+=(--file "${DOCKERFILE}")
elif [[ -n "$BUILDFILE" ]]; then
  ARGS+=(--file "${BUILDFILE}")
fi

# if target is set then add the arg
if [[ -n "$TARGET" ]]; then
  ARGS+=(--target "${TARGET}")
fi

# if buildx is enabled then add the platforms
if [[ "$BUILDX_ENABLED" == "true" && -n "$PLATFORMS" ]]; then
  ARGS+=(--platform "${PLATFORMS}")
  MULTIARCH="true"
fi

# if cache is true
if [[ "$CACHE" == "true" ]]; then
  CACHE_CONFIG="type=gha,scope=${CACHE_SCOPE}"
  ARGS+=(--cache-to ${CACHE_CONFIG},mode=max)
  ARGS+=(--cache-from ${CACHE_CONFIG})
fi

# add output if given
if [[ -n "$OUTPUT" ]]; then
  ARGS+=(--output "${OUTPUT}")
fi

# if push is true then add the arg
if [[ "$PUSH" == "true" ]]; then
  ARGS+=(--push)
fi

# add any custom build args
build_args=($BUILD_ARGS)
for arg in ${build_args[*]}; do
  ARGS+=(--build-arg "${arg}")
done

# Add the fancy tags
COMPUTED_FANCY_TAGS=()
ALLOWED_FANCY_TAGS=(DATE GIT_REF GIT_SHA)
for tag in "${ALLOWED_FANCY_TAGS[@]}"; do
  if [[ "${FANCY_TAGS}" =~ "$tag" ]]; then
    COMPUTED_FANCY_TAGS+=("${!tag}")
  fi
done
# add all the tags with image as args
TAGS=(
  $EXTRA_TAGS
  "${COMPUTED_FANCY_TAGS[*]}"
)
for tag in ${TAGS[*]}; do
  ARGS+=(--tag "${IMAGE}:${tag}")
done

# finally add the context
ARGS+=("${CONTEXT}")

echo "multiarch=${MULTIARCH}" >> $GITHUB_OUTPUT
echo "tags=${TAGS[*]}" >> $GITHUB_OUTPUT
echo "args=${ARGS[*]}" >> $GITHUB_OUTPUT
