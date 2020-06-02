#!/bin/bash

set -x
set -e

start_dir=$(pwd)

cpanm --notest Dist::Zilla
cpanm --notest Moose
cpanm --notest YAML::XS
cpanm --notest DBD::mysql

VR_CODEBASE_VERSION=0.04
VRCODEBASE_GIT_URL="https://github.com/sanger-pathogens/vr-codebase/archive/v${VR_CODEBASE_VERSION}.tar.gz"

# Make an install location
if [ ! -d 'git_repos' ]; then
  mkdir git_repos
fi
cd git_repos

wget -O- ${VRCODEBASE_GIT_URL} | tar xzvf -

#Add locations to PERL5LIB
VRCODEBASE_LIB="${start_dir}/git_repos/vr-codebase-${VR_CODEBASE_VERSION}/modules"

export PERL5LIB=${VRCODEBASE_LIB}:$PERL5LIB

cd $start_dir
dzil authordeps --missing | cpanm --notest
dzil listdeps --missing | grep -v 'VRTrack::Lane' | cpanm --notest

dzil test
      
set +eu
set +x
