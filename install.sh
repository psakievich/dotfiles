#!/bin/bash -l
# Bootstrap: clone deps, build in DOT_BUILD_ROOT, install runtime into DOT_RUNTIME_ROOT.
#
#   DOT_BUILD_ROOT    (default: <repo>/.build)           scratch-friendly, disposable
#   DOT_RUNTIME_ROOT  (default: ~/.local/opt/dotfiles)   what the shell sources
#
# e.g.  DOT_BUILD_ROOT=/scratch/$USER/dotbuild ./install.sh

cmd(){
  echo "$@"
  eval "$@"
}

export DOTFILES="$( cd -- "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" >/dev/null 2>&1 ; pwd -P )"

cmd "make -C ${DOTFILES:?} deps"
cmd "make -C ${DOTFILES:?} all"
