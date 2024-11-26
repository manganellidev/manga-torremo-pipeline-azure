#!/bin/bash

echo -e "\n\n\033[1;33m[STARTED]\033[0m \033[1;36m*** GitOps Custom Step ***\033[0m\n"

GH_TOKEN=${PIPER_VAULTCREDENTIAL_ACCESS_TOKEN}
GH_EMAIL=${PIPER_VAULTCREDENTIAL_EMAIL}
GH_USERNAME=${PIPER_VAULTCREDENTIAL_USERNAME}
GH_GITOPS_REPO_URI=github.com/manganellidev/sdp-deployments.git

function errorExit() {
  echo -e "\033[1;31m> ! > ! > Error: $1\033[0m"
  exit 1
}

function installDependencies() {
  echo -e "\n\033[1;33m[>]\033[0m \033[1;36m installDependencies \033[0m\n"

  INSTALL_DIR="/tmp/local/bin"
  mkdir -p $INSTALL_DIR

  GH_CLI_URL="https://github.com/cli/cli/releases/download/v2.54.0/gh_2.54.0_linux_amd64.tar.gz"
  YQ_URL="https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64"

  GH_EXTRACT_DIR="/tmp/gh_cli"

  # Install gh CLI
  curl -fsSL $GH_CLI_URL -o /tmp/gh.tar.gz \
    && mkdir -p $GH_EXTRACT_DIR \
    && tar -xzf /tmp/gh.tar.gz -C $GH_EXTRACT_DIR \
    && mv $GH_EXTRACT_DIR/gh_*/bin/gh $INSTALL_DIR/gh \
    && rm -rf /tmp/gh.tar.gz $GH_EXTRACT_DIR

  # Install yq
  curl -fsSL $YQ_URL -o /tmp/yq \
    && chmod +x /tmp/yq \
    && mv /tmp/yq $INSTALL_DIR/yq

  export PATH=$INSTALL_DIR:$PATH

  git --version
  gh --version
  yq --version
}

function readAndUpdateADOFile() {
    echo -e "\n\033[1;33m[>]\033[0m \033[1;36m readAndUpdateADOFile \033[0m\n"

    ADO_FILE="azure-sdp-pipelines.yml"
    if [[ ! -f $ADO_FILE ]]; then
        errorExit "ADO file $ADO_FILE not found."
    fi

    # Read the artifactVersion from the commonPipelineEnvironment
    artifactVersion=$(cat .pipeline/commonPipelineEnvironment/artifactVersion)
    if [[ -z "$artifactVersion" ]]; then
      echo "Error: artifactVersion not found."
      exit 1
    fi 
    # Add the artifactVersion to the ADO file
    yq e ".extends.parameters.artifactVersion = \"$artifactVersion\"" -i $ADO_FILE

    # Add the GH Repo URI to the ADO file
    yq e ".extends.parameters.ghRepoUri = \"$BUILD_REPOSITORY_URI\"" -i $ADO_FILE
    
    
    APP_NAME=$(yq '.extends.parameters.appName' $ADO_FILE)
    ARTIFACT_VERSION=$(yq '.extends.parameters.artifactVersion' $ADO_FILE)
    TEAM_IDENTIFIER=$(yq '.extends.parameters.teamIdentifier' $ADO_FILE)
    GH_REPO_URI=$(yq '.extends.parameters.ghRepoUri' $ADO_FILE)

    echo "ADO File -------------------------------"
    echo "App Name:              $APP_NAME"
    echo "Artifact Version:      $ARTIFACT_VERSION"
    echo "Team Identifier:        $TEAM_IDENTIFIER"
    echo "Github Repository URI: $GH_REPO_URI"
    echo "----------------------------------------"
}

function retrieveGhOrgAndRepoName() {
  echo -e "\n\033[1;33m[>]\033[0m \033[1;36m retrieveGhOrgAndRepoName \033[0m\n"
  EXPECTED_PREFIX="https://github.com/"

  if [[ $BUILD_REPOSITORY_URI == $EXPECTED_PREFIX* ]]; then
    GH_ORG_NAME=$(basename "$(dirname "$BUILD_REPOSITORY_URI")")
    GH_REPO_NAME=$(basename "$BUILD_REPOSITORY_URI")
    GH_BRANCH="$TEAM_IDENTIFIER/$APP_NAME"
  else
    errorExit "BUILD_REPOSITORY_URI: $BUILD_REPOSITORY_URI does not start with $EXPECTED_PREFIX"
  fi

  echo "GitHub ---------------------------------"
  echo "GitHub Token:              $GH_TOKEN"
  echo "GitHub Email:              $GH_EMAIL"
  echo "GitHub Username:           $GH_USERNAME"
  echo "Github Organization Name:  $GH_ORG_NAME"
  echo "Github Repository Name:    $GH_REPO_NAME"
  echo "----------------------------------------"
}

function cloneSdpRepository() {
  echo -e "\n\033[1;33m[>]\033[0m \033[1;36m cloneSdpRepository \033[0m\n"

  REPO_SDP_DIR="/tmp/gitops-sdp"

  git clone "https://$GH_TOKEN@$GH_GITOPS_REPO_URI" "$REPO_SDP_DIR" || errorExit "Failed to clone the gitops-sdp repository."
}

function createBranchAndPush() {
  echo -e "\n\033[1;33m[>]\033[0m \033[1;36m createBranchAndPush \033[0m\n"

  # Copy the ADO file to the gitops-sdp repository and push it to a new branch
  rm azure-pipelines.yml
  cp azure-sdp-pipelines.yml $REPO_SDP_DIR/azure-pipelines.yml || errorExit "Failed to copy azure-sdp-pipelines.yml."

  cd "$REPO_SDP_DIR" || errorExit "Failed to change directory to $REPO_SDP_DIR."

  git config user.email "$GH_EMAIL"
  git config user.name "$GH_USERNAME"

  git push origin --delete "$GH_BRANCH" &>/dev/null
  git checkout -b "$GH_BRANCH" &>/dev/null || errorExit "Failed to create and switch to branch $GH_BRANCH."

  git add -f "azure-pipelines.yml"

  if git diff-index --cached --quiet HEAD --; then
    echo "No changes to commit. Exiting..."
    exit 0  # Exit the script successfully since there's nothing to commit
  else
    git commit -m "$GH_BRANCH" || errorExit "Failed to commit changes."
    git push -u origin "$GH_BRANCH" &>/dev/null || errorExit "Failed to push branch $GH_BRANCH."
  fi
}

function main() {
  installDependencies
  readAndUpdateADOFile
  retrieveGhOrgAndRepoName
  cloneSdpRepository
  createBranchAndPush
}

main

echo -e "\n\n\033[1;33m[FINISHED]\033[0m \033[1;36m*** GitOps Custom Step ***\033[0m\n\n"
