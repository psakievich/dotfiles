#!/bin/bash -l

export DOTFILES="$( cd -- "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" >/dev/null 2>&1 ; pwd -P )"

git -C ${DOTFILES:?} submodule update --init --recursive

pushd ${DOTFILES:?}

source spack/share/spack/setup-env.sh
export SPACK_DISABLE_LOCAL_CONFIG=1

pushd spack-manager
./install.sh --scope site
popd

# create spack environments to install software
pushd spack_environments
for env in */ ; do
  # machine specific impl of env
  spack manager create-env --name $env --yaml $env/spack.yaml
  # env specific buildcaches
  spack -e $env buildcache keys --install --trust
  spack -e $env install
  # view for local bin's
  spack -e $env env view enable ${DOTFILES:?}/spack-views/{$env}-bin
  # back up in buildcache
  spack -e $env buildcache push --unsigned ${DOTFILES:?}/spack-cache
done
popd
  
# install tmux plugins
${DOTFILES:?}/.tmux/plugins/tpm/scripts/update_plugin.sh
