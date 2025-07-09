#!/bin/bash -l

# export bash stuff check to see if we've already appended file
# dotfileSource=$(grep .dotprofile ${HOME}/.bash_profile)
# if [ -z "${dotfileSource}" ]; then
#   echo "Appending .bash_profile"
#   echo "source ${HOME}/.dotprofile" >> ${HOME}/.bash_profile
# fi

# directories
mkdir -p ${HOME}/soft

# TODO not sure I like this
DOTSPACK=$(pwd)/spack
SPACK=${DOTSPACK}/bin/spack
export SPACK_DISABLE_LOCAL_CONFIG=1

# clone spack and activate it
${SPACK} -k bootstrap now --dev
${SPACK} config add config:environments_root:$(pwd)/spack_environments
${SPACK} mirror add develop-developer-tools-darwin https://binaries.spack.io/develop/developer-tools-darwin
${SPACK} buildcache keys --install --trust

# create spack environments to install software
pushd spack_environments
envs=(*)
for env in "${envs[@]}"
do
  ${SPACK} -e $env install
done
popd
  
# install tmux plugins
.tmux/plugins/tpm/scripts/update_plugin.sh
