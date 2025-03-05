URI=$(duploctl service find "$SERVICE_NAME" -o string -q Template.Containers[0].Image)

# take the tag off the uri to get image
IMAGE=$(echo "$URI" | cut -d: -f1)

docker pull "$URI"

# if the tags_input is empty or has no value or null
if [[ -z "$TAGS_INPUT" ]]; then
  GIT_REF="$(echo "${GITHUB_REF##*/}" | sed -e 's/\//_/g')"
  TAGS_INPUT="$GIT_REF"
fi

TAGS=$($TAGS_INPUT)
for tag in $TAGS; do
  docker tag "$URI" "$IMAGE:$tag"
done

# Push the image to the registry
docker push "$IMAGE" --all-tags
