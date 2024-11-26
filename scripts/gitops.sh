#!/bin/bash

echo -e "\n\n\033[1;33m[STARTED]\033[0m \033[1;36m*** GitOps Custom Step ***\033[0m\n"

GH_TOKEN="$1"
GH_EMAIL="$2"
GH_USERNAME="$3"
GH_GITOPS_REPO_URI=github.com/manganellidev/workloads.git

function errorExit() {
  echo -e "\033[1;31m> ! > ! > Error: $1\033[0m"
  exit 1
}

function installDependencies() {
  echo -e "\n\033[1;33m[>]\033[0m \033[1;36m installDependencies \033[0m\n"

  INSTALL_DIR="/tmp/local/bin"
  mkdir -p $INSTALL_DIR

  GH_CLI_URL="https://github.com/cli/cli/releases/download/v2.54.0/gh_2.54.0_linux_amd64.tar.gz"
  HELM_URL="https://get.helm.sh/helm-v3.15.0-linux-amd64.tar.gz"
  YQ_URL="https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64"

  GH_EXTRACT_DIR="/tmp/gh_cli"
  HELM_EXTRACT_DIR="/tmp/helm_cli"

  # Install gh CLI
  curl -fsSL $GH_CLI_URL -o /tmp/gh.tar.gz \
    && mkdir -p $GH_EXTRACT_DIR \
    && tar -xzf /tmp/gh.tar.gz -C $GH_EXTRACT_DIR \
    && mv $GH_EXTRACT_DIR/gh_*/bin/gh $INSTALL_DIR/gh \
    && rm -rf /tmp/gh.tar.gz $GH_EXTRACT_DIR

  # Install Helm
  curl -fsSL $HELM_URL -o /tmp/helm.tar.gz \
    && mkdir -p $HELM_EXTRACT_DIR \
    && tar -xzf /tmp/helm.tar.gz -C $HELM_EXTRACT_DIR \
    && mv $HELM_EXTRACT_DIR/linux-amd64/helm $INSTALL_DIR/helm \
    && rm -rf /tmp/helm.tar.gz $HELM_EXTRACT_DIR

  # Install yq
  curl -fsSL $YQ_URL -o /tmp/yq \
    && chmod +x /tmp/yq \
    && mv /tmp/yq $INSTALL_DIR/yq

  export PATH=$INSTALL_DIR:$PATH

  git --version
  gh --version
  helm version
  yq --version
}

function readConfigFile() {
    echo -e "\n\033[1;33m[>]\033[0m \033[1;36m readConfigFile \033[0m\n"

    CONFIG_FILE="config.yaml"
    if [[ ! -f $CONFIG_FILE ]]; then
        errorExit "Configuration file $CONFIG_FILE not found."
    fi

    ARTIFACT_VERSION=$(yq '.artifactVersion' $CONFIG_FILE)
    TARGET_REGION=$(yq '.targetRegion' $CONFIG_FILE)
    TEAM_IDENTIFIER=$(yq '.teamIdentifier' $CONFIG_FILE)
    APP_NAME=$(yq '.appName' $CONFIG_FILE)
    GH_APP_REPO_URI=$(yq '.ghRepoUri' $CONFIG_FILE)

    EXPECTED_PREFIX="https://github.com/"
    if [[ $GH_APP_REPO_URI == $EXPECTED_PREFIX* ]]; then
      GH_ORG_NAME=$(basename "$(dirname "$GH_APP_REPO_URI")")
      GH_REPO_NAME=$(basename "$GH_APP_REPO_URI")
    else
      errorExit "GH_APP_REPO_URI: $GH_APP_REPO_URI does not start with $EXPECTED_PREFIX"
    fi

    echo "--------------------------------------------"
    echo "App Name:                  $APP_NAME"
    echo "Artifact Version:          $ARTIFACT_VERSION"
    echo "Target Landscape:          $TARGET_REGION"
    echo "Team Identifier:            $TEAM_IDENTIFIER"
    echo "Github Organization Name:  $GH_ORG_NAME"
    echo "Github Repository Name:    $GH_REPO_NAME"
    echo "GitHub Token:              $GH_TOKEN"
    echo "GitHub Email:              $GH_EMAIL"
    echo "GitHub Username:           $GH_USERNAME"
    echo "--------------------------------------------"
}

function cloneAppRepository() {
  echo -e "\n\033[1;33m[>]\033[0m \033[1;36m cloneAppRepository \033[0m\n"

  REPO_APP_DIR="/tmp/app-repo"
  
  git clone "https://$GH_TOKEN@github.com/$GH_ORG_NAME/$GH_REPO_NAME.git" "$REPO_APP_DIR" || errorExit "Failed to clone the app-repo repository."
}

function generateHelmTemplate() {
  echo -e "\n\033[1;33m[>]\033[0m \033[1;36m generateHelmTemplate \033[0m\n"

  # Find the sub directory containing the $APP_NAME within the ./helm directory
  HELM_CHART_DIR=$(find $REPO_APP_DIR/helm -maxdepth 1 -type d -not -path "$REPO_APP_DIR/helm" -name $APP_NAME | head -n 1)

  if [ -z "$HELM_CHART_DIR" ]; then
    errorExit "Helm chart directory not found."
  fi

  yq eval ".image.tag = \"$ARTIFACT_VERSION\"" "$HELM_CHART_DIR/values.yaml" -i

  helm template "$HELM_CHART_DIR" -f "$HELM_CHART_DIR/values-$TARGET_REGION.yaml" > "/tmp/deployment.yaml" || errorExit "Failed to generate Helm template."

  # Append ArgoCD secret
  yq -i '(. | select(.kind == "Deployment")).spec.template.spec.imagePullSecrets += [{"name": "registry-secret"}]' "/tmp/deployment.yaml"
  # Append target namespace
  yq -i ".metadata.namespace = \"$TEAM_IDENTIFIER\"" "/tmp/deployment.yaml"

  echo "Created helm template /tmp/deployment.yaml"
}

function cloneGitOpsRepository() {
  echo -e "\n\033[1;33m[>]\033[0m \033[1;36m cloneGitOpsRepository \033[0m\n"

  REPO_GITOPS_DIR="/tmp/gitops-repo"

  git clone "https://$GH_TOKEN@$GH_GITOPS_REPO_URI" "$REPO_GITOPS_DIR" || errorExit "Failed to clone the gitops-repo repository."
  cd "$REPO_GITOPS_DIR" || errorExit "Failed to change directory to $REPO_GITOPS_DIR."
}

function createBranchAndPush() {
  echo -e "\n\033[1;33m[>]\033[0m \033[1;36m createBranchAndPush \033[0m\n"

  git config user.email "$GH_EMAIL"
  git config user.name "$GH_USERNAME"

  GH_BRANCH_AND_DIR_NAME="$TEAM_IDENTIFIER/$TARGET_REGION/$APP_NAME"
  git push origin --delete "$GH_BRANCH_AND_DIR_NAME" &>/dev/null
  git checkout -b "$GH_BRANCH_AND_DIR_NAME" &>/dev/null || errorExit "Failed to create and switch to branch $GH_BRANCH_AND_DIR_NAME."

  mkdir -p "$GH_BRANCH_AND_DIR_NAME"

  cp "/tmp/deployment.yaml" "$GH_BRANCH_AND_DIR_NAME" || errorExit "Failed to copy Helm template."

  git add -f "$GH_BRANCH_AND_DIR_NAME/deployment.yaml"

  if git diff-index --cached --quiet HEAD --; then
    echo "No changes to commit. Exiting..."
    exit 0  # Exit the script successfully since there's nothing to commit
  else
    git commit -m "Add deployment.yaml" || errorExit "Failed to commit changes."
    git push -u origin "$GH_BRANCH_AND_DIR_NAME" &>/dev/null || errorExit "Failed to push branch $GH_BRANCH_AND_DIR_NAME."
  fi
}

function openPullRequest() {
  echo -e "\n\033[1;33m[>]\033[0m \033[1;36m openPullRequest \033[0m\n"

  mkdir -p /tmp/gh-config
  export GH_CONFIG_DIR=/tmp/gh-config

  echo "$GH_TOKEN" | gh auth login --hostname "github.com" --with-token || errorExit "GitHub login failed."

  PR_TITLE="[$TARGET_REGION] Auto PR for $GH_BRANCH_AND_DIR_NAME"
  PR_BODY="This PR was created automatically."

  gh pr create --base main --head "$GH_BRANCH_AND_DIR_NAME" --title "$PR_TITLE" --body "$PR_BODY" || errorExit "Failed to open pull request."
}

function main() {
  installDependencies
  readConfigFile
  cloneAppRepository
  generateHelmTemplate
  cloneGitOpsRepository
  createBranchAndPush
  openPullRequest
}

main

echo -e "\n\n\033[1;33m[FINISHED]\033[0m \033[1;36m*** GitOps Custom Step ***\033[0m\n\n"
