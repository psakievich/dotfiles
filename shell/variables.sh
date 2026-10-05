if [ -d ${DOTFILES:?}/env-src ]; then
  source ${DOTFILES:?}/env-src/graphviz_load.sh
fi
export EDITOR=nvim

PS1="[${SHLVL}] ${PS1}"
export MYCONFIGINSTALLED=1

export XDG_CONFIG_HOME=${DOTFILES:-$HOME}/.config
export XDG_DATA_HOME=${DOTFILES:-$HOME}/.local/share
export XDG_STATE_HOME=${DOTFILES:-$HOME}/.local/state
export XDG_CACHE_HOME=${DOTFILES:-$HOME}/.cache

export SPACK_DISABLE_LOCAL_CONFIG=true
export SPACK_USER_CONFIG_PATH=${XDG_STATE_HOME}/dotspack
