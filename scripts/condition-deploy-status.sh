#!/bin/bash

echo -e "\n\n\033[1;33m[STARTED]\033[0m \033[1;36m*** 🩺 Argo Application Status ***\033[0m\n"

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

echo "Checking Argo application status through health-gate..."

max_attempts=10
delay=30

attempts=0

while [ $attempts -lt $max_attempts ]; do
  response=$(curl -s GET "https://int-health-gate.c-2c4f88c.kyma.ondemand.com/application/v1/status?name=$appName-$targetRegion-$teamIdentifier&version=$artifactVersion")

  echo "Response: $response"

  status=$(echo $response | jq -r '.status')

  if [ "$status" = "true" ]; then
    echo "Application status is true. Proceeding..."
    echo -e "\n\n\033[1;33m[FINISHED]\033[0m \033[1;36m*** 🩺 Argo Application Status ***\033[0m\n"
    exit 0
  else
    echo "Application Status is false. Attempt $((attempts + 1)) of $max_attempts. Retrying in $delay seconds..."
  fi

  attempts=$((attempts + 1))
  sleep $delay
done

echo "Failed to get a successful application status after $(($max_attempts * $delay)) seconds. Aborting."
exit 1
