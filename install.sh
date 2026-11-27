#!/bin/bash -l
# Bootstrap a clone or worktree. Two independent steps:
#
#   1. tools/: build the Spack env, push to the buildcache, deploy it, and
#      symlink the gitignored env.sh (which the shell sources) to its load.sh.
#      Skip with --no-tools, e.g. when env.sh points somewhere else.
#   2. dotfiles: clone tpm.
#
# Machine-local settings (DOT_BUILD_ROOT, DOT_RUNTIME_ROOT, ...) go in
# ~/.dotlocal, which this script, tools/install.sh and the profile source.
set -e

export DOTFILES="$( cd -- "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 ; pwd -P )"

if [ "${1:-}" != --no-tools ]; then
  "${DOTFILES}/tools/install.sh" "${DOTFILES}/env.sh"
fi

make -C "${DOTFILES}" deps
