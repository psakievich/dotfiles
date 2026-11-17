#!/bin/bash -l
# Bootstrap: clone deps, build in DOT_BUILD_ROOT, deploy into DOT_RUNTIME_ROOT.
#
#   DOT_BUILD_ROOT    (default: <repo>/.build)           scratch-friendly, disposable
#   DOT_RUNTIME_ROOT  (default: ~/.local/opt/dotfiles)   what the shell sources
#
# e.g.  DOT_BUILD_ROOT=/scratch/$USER/dotbuild ./install.sh
# or set them once per machine in ~/.dotlocal, which this script and the
# shell profile both source (make itself only sees the environment).

cmd(){
  echo "$@"
  eval "$@"
}

export DOTFILES="$( cd -- "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" >/dev/null 2>&1 ; pwd -P )"

# machine-local settings; set -a exports plain assignments too, for make
DOTLOCAL="${DOTLOCAL:-${HOME}/.dotlocal}"
if [ -f "$DOTLOCAL" ]; then
  set -a; source "$DOTLOCAL"; set +a
fi

cmd "make -C ${DOTFILES:?} deps"
cmd "make -C ${DOTFILES:?} all"
