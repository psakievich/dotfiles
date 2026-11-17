path_append ()  { path_remove $1; export PATH="$PATH:$1"; }
path_prepend () { path_remove $1; export PATH="$1:$PATH"; }
path_remove ()  { export PATH=`echo -n $PATH | awk -v RS=: -v ORS=: '$0 != "'$1'"' | sed 's/:$//'`; }

clear_shell_function(){
  # Check if the original function exists and cache it
  if declare -f "$1" > /dev/null; then
    unset -f "$1"
  fi
}


function unload_spack(){
  help_string="
-------------------------------------
shell-function:: unload_spack()
-------------------------------------

Thus function will purge spack from your shell environment

The shell-specific arguments for this function are:

-h|--help:             display help message
"
  unset HELP_CALLED
  # ----------
  POSITIONAL_ARGS=()

  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
	HELP_CALLED=true
	shift
	;;
      *)
	POSITIONAL_ARGS+=("$1")
	shift
	;;
    esac
  done

  set -- "${POSITIONAL_ARGS[@]}"
  # ----------

  if [ -n "${SPACK_ENV:-}" ]; then
    spack env deactivate > /dev/null 2>&1
    unset SPACK_ENV
  fi
  if [[ -n "${SPACK_ROOT:-}" ]]; then
     path_remove "$SPACK_ROOT/bin"
  fi
  unset SPACK_ROOT
  unset SPACK_USER_CACHE_PATH
  unset SPACK_USER_CONFIG_PATH
  unset SPACK_SYSTEM_CONFIG_PATH
  unset _sp_initializing
  clear_shell_function "_spack_shell_wrapper"
  clear_shell_function "spack"
}


# Create a new directory and enter it
function mk() {
  mkdir -p "$@" && cd "$@"
}

# Open man page as PDF
# TODO osx vs linux
function manpdf() {
  man -t "${1}" | open -f -a /Applications/Preview.app/
}
# Quick navigations
function cdh(){
  cd ${HOME}
}

# Run the dotfiles spack with the build config scopes (DOT_BUILD_ROOT tree).
# Use `sspack-runtime` to inspect what is installed in DOT_RUNTIME_ROOT.
function sspack(){
SPACK_DISABLE_LOCAL_CONFIG=1 SPACK_USER_CACHE_PATH="${DOT_BUILD_ROOT:?}/user-cache" \
  "${DOT_BUILD_ROOT:?}/spack/bin/spack" \
  -C "${DOTFILES:?}/configs/common" -C "${DOTFILES:?}/configs/build" "$@"
}

function sspack-runtime(){
SPACK_DISABLE_LOCAL_CONFIG=1 SPACK_USER_CACHE_PATH="${DOT_BUILD_ROOT:?}/user-cache" \
  "${DOT_BUILD_ROOT:?}/spack/bin/spack" \
  -C "${DOTFILES:?}/configs/common" -C "${DOTFILES:?}/configs/runtime" "$@"
}

function cds(){
  if [ -n "${SCRATCH}" ]; then
    cd ${SCRATCH}
  else
    echo "SCRATCH var is not set"
  fi
}
# Set a work directory to make it easy to jump back and forth
function setwork(){
  export MYWORKDIR=$(pwd)
}

function gtw(){
  if [ -n "${MYWORKDIR}" ]; then
    cd ${MYWORKDIR}
  else
    echo "MYWORKDIR var is not set"
  fi
}

function git_branch_prune(){
    git branch | grep -v "$1" | xargs git branch -D
}

# Effective deployment list, space separated, in load order (later wins):
# $DOT_DEPLOYMENTS if set (commas allowed), else DOT_RUNTIME_ROOT/active.
# A hermetic shell without --deploy gets an empty list.
function _dot_deployments(){
  if [ -n "${DOT_DEPLOYMENTS+x}" ]; then
    echo "$DOT_DEPLOYMENTS" | tr ',' ' '
  elif [ -z "${DOT_HERMETIC:-}" ] && [ -f "${DOT_RUNTIME_ROOT:?}/active" ]; then
    tr '\n' ' ' < "${DOT_RUNTIME_ROOT}/active"
  fi
}

# List deployments under DOT_RUNTIME_ROOT; '*' marks the ones this shell loads.
function dot-deployments(){
  local _d _name _loaded=" $(_dot_deployments) "
  for _d in "${DOT_RUNTIME_ROOT:?}"/*/load.sh; do
    [ -f "$_d" ] || continue
    _name=$(basename "$(dirname "$_d")")
    case "$_loaded" in *" $_name "*) echo "* $_name" ;; *) echo "  $_name" ;; esac
  done
}

# Launch a subshell (or run a command) without the dotfiles runtime view.
# The child starts from an empty environment, so nothing the view added to
# PATH, CMAKE_PREFIX_PATH, PKG_CONFIG_PATH, DYLD_*/LD_*, PYTHONPATH, ... leaks.
function hermetic(){
  local mode=config deploy=""
  # child shell: --shell, else DOT_HERMETIC_SHELL, else the shell you are in
  local _sh=${DOT_HERMETIC_SHELL:-}
  if [ -z "$_sh" ]; then
    if [ -n "${ZSH_VERSION:-}" ]; then _sh=zsh; else _sh=bash; fi
  fi
  while [ $# -gt 0 ]; do
    case $1 in
      --tools) mode=tools; shift ;;
      --deploy) deploy=${2:?hermetic: --deploy needs <env>[,<env>...]}; shift 2 ;;
      --deploy=*) deploy=${1#--deploy=}; shift ;;
      --bare)  mode=bare;  shift ;;
      --shell) _sh=${2:?hermetic: --shell needs bash or zsh}; shift 2 ;;
      --shell=*) _sh=${1#--shell=}; shift ;;
      --) shift; break ;;
      -h|--help)
        cat <<'HELP'
usage: hermetic [--tools | --bare] [--deploy <env>[,<env>...]] [--shell bash|zsh]
                [--] [cmd ...]

Start a subshell (or run cmd) from a clean environment, without the deployments
your current shell has loaded.

  (default)  dotfiles config (aliases, functions, XDG, prompt), system PATH only
  --deploy   load only these deployments (fully: PATH, libraries, ...); later
             ones take precedence. See `dot-deployments` for what exists.
  --tools    put the bin/ of this shell's deployments on PATH (nvim, rg, ...),
             but none of their library/build variables
  --bare     no dotfiles at all: system PATH and a plain shell
  --shell    child shell (default: $DOT_HERMETIC_SHELL, else the current shell).
             It is looked up on the hermetic PATH, not the parent's.

Passed through from the parent: HOME USER LOGNAME TERM SHLVL LANG LC_ALL TMPDIR
SSH_AUTH_SOCK DISPLAY COLORTERM DOT_BUILD_ROOT DOT_RUNTIME_ROOT, plus any
variable names listed in DOT_HERMETIC_KEEP. The child sets DOT_HERMETIC=<mode>
and DOT_HERMETIC_SHELL=<shell>.
HELP
        return 0 ;;
      *) break ;;
    esac
  done

  if [ "$mode" = bare ] && [ -n "$deploy" ]; then
    echo "hermetic: --deploy needs the dotfiles profile; drop --bare" >&2; return 2
  fi

  case $_sh in
    bash|zsh) ;;
    *) echo "hermetic: unsupported shell '$_sh' (bash or zsh)" >&2; return 2 ;;
  esac

  local base_path
  base_path=$(getconf PATH 2>/dev/null) || base_path=/usr/bin:/bin:/usr/sbin:/sbin
  if [ "$mode" = tools ]; then
    local _d
    for _d in $(_dot_deployments); do
      base_path="${DOT_RUNTIME_ROOT:?}/${_d}/view/bin:${base_path}"
    done
  fi

  # resolve the shell on the hermetic PATH so a view/homebrew shell can't sneak in
  local sh_bin
  sh_bin=$(PATH="$base_path" command -v "$_sh") || {
    echo "hermetic: $_sh not found on $base_path" >&2; return 127; }

  local -a keep
  keep=("HOME=${HOME}" "PATH=${base_path}" "SHLVL=${SHLVL:-1}"
        "DOT_HERMETIC=${mode}" "DOT_HERMETIC_SHELL=${_sh}"
        "DOT_DEPLOYMENTS=$(echo "$deploy" | tr ',' ' ')"
        "BASH_SILENCE_DEPRECATION_WARNING=1")
  local _v _val
  for _v in $(echo USER LOGNAME TERM LANG LC_ALL TMPDIR SSH_AUTH_SOCK DISPLAY COLORTERM \
                   DOT_BUILD_ROOT DOT_RUNTIME_ROOT DOTLOCAL ${DOT_HERMETIC_KEEP:-}); do
    eval "_val=\${${_v}-__dot_unset__}"
    [ "$_val" = __dot_unset__ ] || keep+=("${_v}=${_val}")
  done

  # rc-file-free invocations: bash --noprofile --norc / zsh -f (NO_RCS)
  local -a norc
  if [ "$_sh" = zsh ]; then norc=(-f); else norc=(--noprofile --norc); fi

  if [ "$mode" = bare ]; then
    if [ $# -gt 0 ]; then
      env -i "${keep[@]}" "$@"
    else
      env -i "${keep[@]}" "$sh_bin" "${norc[@]}"
    fi
  elif [ $# -gt 0 ]; then
    env -i "${keep[@]}" "$sh_bin" "${norc[@]}" \
      -c '. "$0/stow-point/.profile" && exec "$@"' "${DOTFILES:?}" "$@"
  elif [ "$_sh" = zsh ]; then
    # zsh has no --rcfile: point ZDOTDIR at a .zshrc that only sources the
    # profile, and skip the global /etc/zprofile, /etc/zshrc, ... (-d)
    env -i "${keep[@]}" DOTFILES="${DOTFILES:?}" \
      ZDOTDIR="${DOTFILES:?}/shell/hermetic-zdotdir" "$sh_bin" -d -i
  else
    env -i "${keep[@]}" "$sh_bin" --rcfile "${DOTFILES:?}/stow-point/.profile"
  fi
}
