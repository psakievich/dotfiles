#!/bin/bash -l

# export bash stuff check to see if we've already appended file
# dotfileSource=$(grep .dotprofile ${HOME}/.bash_profile)
# if [ -z "${dotfileSource}" ]; then
#   echo "Appending .bash_profile"
#   echo "source ${HOME}/.dotprofile" >> ${HOME}/.bash_profile
# fi

# directories
mkdir -p ${HOME}/soft

git submodule update --init --recursive

source spack/share/spack/setup-env.sh
export SPACK_DISABLE_LOCAL_CONFIG=1

pushd spack-manager
./install.sh --scope site
popd

# clone spack and activate it
spack mirror add develop-bootstrap-aarch64-darwin https://binaries.spack.io/develop/bootstrap-aarch64-darwin
spack buildcache keys --install --trust
spack -k bootstrap now --dev

# create spack environments to install software
pushd spack_environments
envs=(*)
for env in "${envs[@]}"
do
  spack manager create-env --name $env --yaml $env/spack.yaml
  spack -e $env install
done
popd
  
# install tmux plugins
.tmux/plugins/tpm/scripts/update_plugin.sh
