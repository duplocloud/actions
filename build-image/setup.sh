#!/usr/bin/env bash

# make available to other steps
echo "name=$BUILD_TYPE" >> $GITHUB_OUTPUT

# if BUILD_TYPE is buildx or bake
if [[ "$BUILD_TYPE" == "buildx" || "$BUILD_TYPE" == "bake" ]]; then
  echo "buildx_enabled=true" >> $GITHUB_OUTPUT
else
  echo "buildx_enabled=false" >> $GITHUB_OUTPUT
fi

# if BUILD_TYPE is compose or bake then build_from_file is enabled
if [[ "$BUILD_TYPE" == "compose" || "$BUILD_TYPE" == "bake" ]]; then
  echo "build_from_file=true" >> $GITHUB_OUTPUT
else
  echo "build_from_file=false" >> $GITHUB_OUTPUT
fi

# based on the builder, output the build command
case $BUILD_TYPE in
  docker)
    echo "build_cmd=build" >> $GITHUB_OUTPUT
    ;;
  buildx)
    echo "build_cmd=buildx build" >> $GITHUB_OUTPUT
    ;;
  compose)
    echo "build_cmd=compose build" >> $GITHUB_OUTPUT
    ;;
  bake)
    echo "build_cmd=buildx bake" >> $GITHUB_OUTPUT
    ;;
esac
