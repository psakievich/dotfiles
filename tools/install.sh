#!/bin/bash
# Build the tools env, push it to the buildcache and deploy it from there.
#
#   tools/install.sh [<link>]   also symlink <link> (e.g. $DOTFILES/env.sh) to load.sh
#
#   DOT_BUILD_ROOT    (default: tools/.build)          scratch-friendly, disposable
#   DOT_RUNTIME_ROOT  (default: ~/.local/opt/dotfiles) what the shell sources
#
# Machine-local settings in ~/.dotlocal are sourced (exported) first.
set -e

TOOLS="$( cd -- "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 ; pwd -P )"

DOTLOCAL="${DOTLOCAL:-${HOME}/.dotlocal}"
if [ -f "$DOTLOCAL" ]; then
  set -a; source "$DOTLOCAL"; set +a
fi

set -x
make -C "$TOOLS" deps all
if [ -n "${1:-}" ]; then
  make -C "$TOOLS" link LINK="$1"
fi
