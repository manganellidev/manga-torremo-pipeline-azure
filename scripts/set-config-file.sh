#!/bin/bash

echo -e "\n\n\033[1;33m[STARTED]\033[0m \033[1;36m*** Set Config File ***\033[0m\n"

appName="$1"
artifactVersion="$2"
targetRegion="$3"
teamIdentifier="$4"
ghRepoUri="$5"

echo "Application Name: $appName"
echo "Artifact Version: $artifactVersion"
echo "Target Region: $targetRegion"
echo "Team Identifier: $teamIdentifier"
echo "GitHub Repository URI: $ghRepoUri"

cat <<EOL > config.yaml || { echo "Error: Failed to create config.yaml"; exit 1; }
artifactVersion: "$artifactVersion"
targetRegion: "$targetRegion"
teamIdentifier: "$teamIdentifier"
appName: "$appName"
ghRepoUri: "$ghRepoUri"
EOL

echo -e "\n\n\033[1;33m[FINISHED]\033[0m \033[1;36m*** Set Config File ***\033[0m\n\n"