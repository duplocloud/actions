#!/usr/bin/env bash

echo "Using registry: $REGISTRY"

# if the registry is docker.io and the repo is not set
if [[ "$REGISTRY" == "docker.io" && -z "$REPO" ]]; then
  IMAGE="${GITHUB_REPOSITORY}"
  REPO="$(basename $GITHUB_REPOSITORY)"
else
  # otherwise use the repo name to match the image repo
  if [[ -z "$REPO" ]]; then
    REPO="$(basename $GITHUB_REPOSITORY)"
  fi
  # set the image name
  IMAGE="${REGISTRY}/${REPO}"
fi

# export short sha for tags
GIT_SHA="$(git rev-parse --short HEAD)"
echo "Short sha is $GIT_SHA"

DATE="$(date -u +"%Y%m%d%H%M")"

# ref name
## TODO: maybe use this GITHUB_REF_NAME
# the sed part handles dependabot issues with slash names
GIT_REF="$(echo ${GITHUB_REF##*/} | sed -e 's/\//_/g')"
echo "Ref name is $GIT_REF the other is: $GITHUB_REF_NAME"

# this is for the output
echo "registry=${REGISTRY}" >> $GITHUB_OUTPUT
echo "image=${IMAGE}" >> $GITHUB_OUTPUT
echo "repo=${REPO}" >> $GITHUB_OUTPUT
echo "git_ref=${GIT_REF}" >> $GITHUB_OUTPUT
echo "git_sha=${GIT_SHA}" >> $GITHUB_OUTPUT
echo "uri=${IMAGE}:${GIT_SHA}" >> $GITHUB_OUTPUT
echo "date=${DATE}" >> GITHUB_OUTPUT
