#!/bin/bash

echo -e "\n\n\033[1;33m[STARTED]\033[0m \033[1;36m*** 🩺 Condition Deploy Status ***\033[0m\n"

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

echo "Triggering Dynatrace Synthetic Monitor Smoke Test through health-gate..."

max_attempts=5
delay=15

attempts=0

executionID=""
while [ $attempts -lt $max_attempts ]; do
  response=$(curl -s -X POST "https://int-health-gate.c-2c4f88c.kyma.ondemand.com/smoketest/v1/execute?application=$appName")

  echo "Response: $response"

  executionID=$(echo $response | jq -r '.executionID')

  if [ "$executionID" = "" ]; then
    echo "Failed to trigger synthetic. Attempt $((attempts + 1)) of $max_attempts. Retrying in $delay seconds..."
  else
    echo "Synthetic triggered. Proceeding..."
    break
  fi

  attempts=$((attempts + 1))
  sleep $delay
done

if [ "$executionID" = "" ]; then
  echo "Failed to trigger synthetic after $(($max_attempts * $delay)) seconds. Aborting..."
  exit 1
fi

echo "Validating Dynatrace Synthetic Monitor Smoke Test through health-gate..."

max_attempts=10
delay=30

attempts=0

while [ $attempts -lt $max_attempts ]; do
  response=$(curl -s GET "https://int-health-gate.c-2c4f88c.kyma.ondemand.com/smoketest/v1/executions/$executionID")

  echo "Response: $response"

  status=$(echo $response | jq -r '.status')

  if [ "$status" = "SUCCESS" ]; then
    echo "Smoke tests executed with success. Proceeding..."
    echo -e "\n\n\033[1;33m[FINISHED]\033[0m \033[1;36m*** 🩺 Smoke Tests ***\033[0m\n"
    exit 0
  else
    echo "Smoke tests are not finished yet. Attempt $((attempts + 1)) of $max_attempts. Retrying in $delay seconds..."
  fi

  attempts=$((attempts + 1))
  sleep $delay
done

echo "Failed to get a successful smoke test execution status after $(($max_attempts * $delay)) seconds. Aborting."
exit 1
