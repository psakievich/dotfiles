#!/bin/bash -l

export DOTFILES="$( cd -- "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" >/dev/null 2>&1 ; pwd -P )"

source ${DOTFILES:?}/.dotprofile
stow --dir ${DOTFILES:?} --target ${STOW_DIR:-${HOME}}
# install tmux plugins
TMUX_PLUGIN_MANAGER_PATH=${DOTFILES:?}/.tmux/plugins/tpm
${TMUX_PLUGIN_MANAGER_PATH}/scripts/update_plugin.sh all
