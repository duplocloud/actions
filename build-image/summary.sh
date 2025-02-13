#!/usr/bin/env bash

DOCKER_COMMAND="docker ${BUILD_CMD} ${CLI_ARGS}"

echo """
Will run the following command:
------------
${DOCKER_COMMAND}
------------
"""

# build the summary for the github actions
cat <<EOF >> $GITHUB_STEP_SUMMARY
## Docker Command
\`\`\`bash
$DOCKER_COMMAND
\`\`\`
## Image Summary
**Image**: ${IMAGE}
**Tags**: 
EOF
for tag in $TAGS; do
  cat <<EOF >> $GITHUB_STEP_SUMMARY
\`\`\`bash
${IMAGE}:${tag}
\`\`\`
EOF
done

echo "command=$DOCKER_COMMAND" >> $GITHUB_OUTPUT
