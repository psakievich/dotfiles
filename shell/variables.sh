if [ -d ${DOTFILES:?}/env-src ]; then
  source ${DOTFILES:?}/env-src/editor_load.sh
fi
export EDITOR=nvim

export DOT_ORG_PS1=${DOT_ORG_PS1:-"${PS1}"}

if [[ $SHLVL -gt 1 ]]; then
  _ASTERISK_STACK=$(printf '%*s' "$(($SHLVL - 1))" | tr ' ' '*')
fi

export PS1="${_ASTERISK_STACK} ${DOT_ORG_PS1}"
export MYCONFIGINSTALLED=1

export XDG_CONFIG_HOME=${DOTFILES:-$HOME}/.config
export XDG_DATA_HOME=${DOTFILES:-$HOME}/.local/share
export XDG_STATE_HOME=${DOTFILES:-$HOME}/.local/state
export XDG_CACHE_HOME=${DOTFILES:-$HOME}/.cache

export SPACK_DISABLE_LOCAL_CONFIG=true
export SPACK_USER_CONFIG_PATH=${XDG_STATE_HOME}/dotspack
