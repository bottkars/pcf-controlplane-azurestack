#!/bin/bash
# this uploads releses to your bos directorRELEASES="REPO1, RELEASE1, REPO1, RELEASE2 ,REPO2, RELEASE3"
# VERSIONS wil be read from a versions.yaml in exportet TEMPLATES directory
# use with direnv exports for best
# functions
function upload-release() {
  while [[ "$#" -gt 0 ]]
  do
    case $1 in
      -b|--BOSH_RELEASE)
        local BOSH_RELEASE=$2
        ;;
      -g |--GIT_REPO_NAME)
        local GIT_REPO=$2
        ;;
    esac
    shift
  done
  VERSIONS=${TEMPLATES}/versions.yml
  VERSION=$(grep -A0 ${BOSH_RELEASE} $VERSIONS | cut -d ':' -f2 | tr -d ' "')
  
  echo "Uploading $GIT_REPO $BOSH_RELEASE $VERSION "
  bosh upload-release  "https://bosh.io/d/github.com/$GIT_REPO/${BOSH_RELEASE}?v=${VERSION}"
}
#
VERSIONS=${TEMPLATES}/versions.yml
# stemcells
RELEASE=$(grep -A0 stemcell-release $VERSIONS | cut -d ':' -f2 | tr -d ' "')
bosh upload-stemcell "https://bosh.io/d/stemcells/bosh-azure-hyperv-ubuntu-xenial-go_agent?v=${RELEASE}"
# cf releases
unset REPO RELEASE VERSIONS
set -u
while IFS=", " read -r REPO RELEASE; do
    upload-release -g $REPO -b $RELEASE
done <<< "${RELEASES}"
