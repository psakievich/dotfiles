#!/bin/bash -l

cmd(){
  echo "$@"
  eval "$@"
}

export DOTFILES="$( cd -- "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" >/dev/null 2>&1 ; pwd -P )"

cmd "make -C ${DOTFILES:?} deps"

cmd "source ${DOTFILES:?}/spack/share/spack/setup-env.sh"
cmd "export SPACK_DISABLE_LOCAL_CONFIG=1"

cmd "make -C ${DOTFILES:?} all"
