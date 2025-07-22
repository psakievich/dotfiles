#!/bin/bash -l

cmd(){
  echo "$@"
  eval "$@"
}

export DOTFILES="$( cd -- "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" >/dev/null 2>&1 ; pwd -P )"

cmd "git -C ${DOTFILES:?} submodule update --init --recursive"

cmd "pushd ${DOTFILES:?}"

cmd "source spack/share/spack/setup-env.sh"
cmd "export SPACK_DISABLE_LOCAL_CONFIG=1"

cmd "pushd spack-manager"
cmd "./install.py --scope site"
cmd "popd"

# create spack environments to install software
cmd "pushd spack_environments"
for env in * ; do
  # machine specific impl of env
  cmd "spack manager create-env --name ${env} --yaml ${env}/spack.yaml"
  # env specific buildcaches
  cmd "spack -e ${env} buildcache keys --install --trust"
  cmd "spack -e ${env} install"
  # view for local bin's
  cmd "spack -e ${env} env view enable ${DOTFILES:?}/spack-views/${env}-bin"
  # back up in buildcache
  cmd "spack -e ${env} buildcache push --unsigned ${DOTFILES:?}/spack-cache"
done
cmd "popd"
