# Build artifacts (spack, build tree, buildcache) live in DOT_BUILD_ROOT;
# the installed runtime lives in DOT_RUNTIME_ROOT. Override either one before
# this file is sourced (e.g. point DOT_BUILD_ROOT at scratch space at work).
export DOT_BUILD_ROOT=${DOT_BUILD_ROOT:-${DOTFILES:?}/.build}
export DOT_RUNTIME_ROOT=${DOT_RUNTIME_ROOT:-${HOME}/.local/opt/dotfiles}

# Load deployments (DOT_RUNTIME_ROOT/<env>/load.sh) in order; later ones take
# precedence. DOT_DEPLOYMENTS overrides the list `make deploy` wrote to
# DOT_RUNTIME_ROOT/active; set it empty to load none. `hermetic` always sets it.
if [ -n "${DOT_HERMETIC:-}" ] || [ -n "${DOT_DEPLOYMENTS+x}" ] || [ -f "${DOT_RUNTIME_ROOT}/active" ]; then
  for _dep in $(_dot_deployments); do
    if [ -f "${DOT_RUNTIME_ROOT}/${_dep}/load.sh" ]; then
      source "${DOT_RUNTIME_ROOT}/${_dep}/load.sh"
    else
      echo "dotfiles: deployment '${_dep}' not found in ${DOT_RUNTIME_ROOT}" >&2
    fi
  done
  unset _dep
elif [ -f "${DOTFILES:?}/env-src/graphviz_load.sh" ]; then
  # legacy layout (pre runtime split); remove once migrated
  source "${DOTFILES:?}/env-src/graphviz_load.sh"
fi
export EDITOR=nvim

export DOT_ORG_PS1=${DOT_ORG_PS1:-"${PS1}"}

if [[ $SHLVL -gt 1 ]]; then
  _ASTERISK_STACK=$(printf '%*s' "$(($SHLVL - 1))" | tr ' ' '*')
fi

export PS1="${DOT_HERMETIC:+[hermetic:${DOT_HERMETIC}${DOT_DEPLOYMENTS:+:${DOT_DEPLOYMENTS// /,}}]}${_ASTERISK_STACK} ${DOT_ORG_PS1}"
export MYCONFIGINSTALLED=1

export XDG_CONFIG_HOME=${DOTFILES:-$HOME}/.config
export XDG_DATA_HOME=${DOTFILES:-$HOME}/.local/share
export XDG_STATE_HOME=${DOTFILES:-$HOME}/.local/state
export XDG_CACHE_HOME=${DOTFILES:-$HOME}/.cache

export SPACK_DISABLE_LOCAL_CONFIG=true
export SPACK_USER_CONFIG_PATH=${XDG_STATE_HOME}/dotspack
