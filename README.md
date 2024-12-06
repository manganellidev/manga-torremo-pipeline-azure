# Torremo General Purpose Pipeline for Azure DevOps

This repository contains [Torremo's _general purpose pipeline_](https://go.sap.corp/piper/stages/) for Azure DevOps and is based on [Torremo's Azure Task](https://github.tools.sap/concur-sap-ecosystem/torremo-azure-task).

## Prerequisites

The pipeline requires [Torremo's Azure Task](https://github.tools.sap/concur-sap-ecosystem/torremo-azure-task) to be [installed](https://github.tools.sap/concur-sap-ecosystem/torremo-azure-task#prerequisites) in the Azure DevOps organization.

## Usage

The _general purpose pipeline_ is defined in [`sdp-pipeline.yml`](./sdp-pipeline.yml). To use it, create an `azure-pipelines.yml` in the root folder of your repository as follows:

```yaml
# Using Torremo general purpose pipeline for Azure

trigger:
  - sdp

resources:
  repositories:
    - repository: torremo-pipeline-azure
      endpoint: github.tools.sap
      type: githubenterprise
      name: concur-sap-ecosystem/torremo-pipeline-azure

extends:
  template: sdp-pipeline.yml@torremo-pipeline-azure

  parameters:
    teamIdentifier: <your team identifier>
    appName: <your app name>
    artifactVersion: <your app artifact version>

    rings:
      - targetRegion: "int"              # Required: check available regions
        previousRegion: "none"           # Required: none or previous region
        autoPromote: true                # Optional: default false
        bakeTimeInMinutes: 1440          # Optional: default 1 minute
        skipBakeTime: false              # Optional: default false
        skipPostDeployValidation: false  # Optional: default false
      - targetRegion: "eu"
        previousRegion: "int"
        autoPromote: true
        bakeTimeInMinutes: 1440
        skipBakeTime: false
        skipPostDeployValidation: false
      - targetRegion: "us"
        previousRegion: "eu"
        autoPromote: true
        bakeTimeInMinutes: 1440
        skipBakeTime: false
        skipPostDeployValidation: false
      - targetRegion: "apj"
        previousRegion: "us"
        autoPromote: true
        bakeTimeInMinutes: 1440
        skipBakeTime: true
        skipPostDeployValidation: false
```
