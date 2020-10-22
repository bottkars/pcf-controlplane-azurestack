#!/bin/bash
# this uploads releses to your bos directorRELEASES="REPO1, RELEASE1, REPO1, RELEASE2 ,REPO2, RELEASE3"
# VERSIONS wil be read from a versions.yaml in exportet TEMPLATES directory
# use with direnv exports for best
# functions
set -ueo pipefail

VERSIONS=${TEMPLATES}/versions.yml
# stemcells
RELEASE=$(grep -A0 stemcell-release $VERSIONS | cut -d ':' -f2 | tr -d ' "')
bosh upload-stemcell "https://bosh.io/d/stemcells/bosh-azure-hyperv-ubuntu-xenial-go_agent?v=${RELEASE}"

