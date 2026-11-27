# Tools are not part of the dotfiles: source the gitignored env file if there
# is one (e.g. a symlink to a deployment's load.sh; see tools/). Hermetic
# shells skip it unless started with `hermetic --env`. Set DOT_ENV (e.g. in
# ~/.dotlocal) to source a different file.
_dot_env=${DOT_ENV:-${DOTFILES:?}/env.sh}
if [ "${DOT_HERMETIC:-env}" = env ] && [ -f "${_dot_env}" ]; then
  source "${_dot_env}"
fi
unset _dot_env

export EDITOR=nvim

export DOT_ORG_PS1=${DOT_ORG_PS1:-"${PS1}"}

if [[ $SHLVL -gt 1 ]]; then
  _ASTERISK_STACK=$(printf '%*s' "$(($SHLVL - 1))" | tr ' ' '*')
fi

export PS1="${DOT_HERMETIC:+[hermetic:${DOT_HERMETIC}]}${_ASTERISK_STACK} ${DOT_ORG_PS1}"
export MYCONFIGINSTALLED=1

export XDG_CONFIG_HOME=${DOTFILES:-$HOME}/.config
export XDG_DATA_HOME=${DOTFILES:-$HOME}/.local/share
export XDG_STATE_HOME=${DOTFILES:-$HOME}/.local/state
export XDG_CACHE_HOME=${DOTFILES:-$HOME}/.cache

export SPACK_DISABLE_LOCAL_CONFIG=true
export SPACK_USER_CONFIG_PATH=${XDG_STATE_HOME}/dotspack
