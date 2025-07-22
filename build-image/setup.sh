#!/usr/bin/env bash

export BUILD_CMD BUILD_FROM_FILE BUILDX_ENABLED

# based on the builder, output the build command
case $BUILD_TYPE in
  docker)
    BUILD_CMD="build"
    BUILDX_ENABLED="false"
    BUILD_FROM_FILE="false"
    ;;
  buildx)
    BUILD_CMD="buildx build"
    BUILDX_ENABLED="true"
    BUILD_FROM_FILE="false"
    ;;
  compose)
    BUILD_CMD="compose build"
    BUILDX_ENABLED="false"
    BUILD_FROM_FILE="true"
    ;;
  bake)
    BUILD_CMD="buildx bake"
    BUILDX_ENABLED="true"
    BUILD_FROM_FILE="true"
    ;;
esac

echo "Running Image Environment Setup"

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
  if [ "$DUPLO_PROVIDER" == "gcp" ]; then
    IMAGE="${REGISTRY}/${DUPLO_ACCOUNT_ID}/${REPO}"
  else 
    IMAGE="${REGISTRY}/${REPO}"
  fi
fi

# export short sha for tags
GIT_SHA="$(git rev-parse --short HEAD)"

DATE="$(date -u +"%Y%m%d%H%M")"

# ref name
## TODO: maybe use this GITHUB_REF_NAME
# the sed part handles dependabot issues with slash names
GIT_REF="$(echo ${GITHUB_REF##*/} | sed -e 's/\//_/g')"
# GIT_REF="$GITHUB_REF_NAME"

# the uri 
IMG_URI="${IMAGE}:${GIT_SHA}"

echo """
Built environment for Docker command
Registry: $REGISTRY
Build Cmd: $BUILD_CMD
Ref Name: $GIT_REF
Short sha: $GIT_SHA
Uri: $IMG_URI
"""

# this is for the output
{
  echo "name=$BUILD_TYPE"
  echo "build_cmd=${BUILD_CMD}"
  echo "build_from_file=${BUILD_FROM_FILE}"
  echo "buildx_enabled=${BUILDX_ENABLED}"
  echo "registry=${REGISTRY}"
  echo "image=${IMAGE}"
  echo "repo=${REPO}"
  echo "git_ref=${GIT_REF}"
  echo "git_sha=${GIT_SHA}"
  echo "uri=${IMG_URI}"
  echo "date=${DATE}"
} >> $GITHUB_OUTPUT
