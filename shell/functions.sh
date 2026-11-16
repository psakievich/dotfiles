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

# Launch a subshell (or run a command) without the dotfiles runtime view.
# The child starts from an empty environment, so nothing the view added to
# PATH, CMAKE_PREFIX_PATH, PKG_CONFIG_PATH, DYLD_*/LD_*, PYTHONPATH, ... leaks.
function hermetic(){
  local mode=config
  while [ $# -gt 0 ]; do
    case $1 in
      --tools) mode=tools; shift ;;
      --bare)  mode=bare;  shift ;;
      --) shift; break ;;
      -h|--help)
        cat <<'HELP'
usage: hermetic [--tools | --bare] [--] [cmd ...]

Start a subshell (or run cmd) from a clean environment without the runtime view.

  (default)  dotfiles config (aliases, functions, XDG, prompt), system PATH only
  --tools    same, plus $DOT_RUNTIME_ROOT/view/bin on PATH (nvim, rg, ...),
             but none of the view's library/build variables
  --bare     no dotfiles at all: system PATH and a plain bash

Passed through from the parent: HOME USER LOGNAME TERM SHLVL LANG LC_ALL TMPDIR
SSH_AUTH_SOCK DISPLAY COLORTERM DOT_BUILD_ROOT DOT_RUNTIME_ROOT, plus any
variable names listed in DOT_HERMETIC_KEEP. The child sets DOT_HERMETIC=<mode>.
HELP
        return 0 ;;
      *) break ;;
    esac
  done

  local base_path
  base_path=$(getconf PATH 2>/dev/null) || base_path=/usr/bin:/bin:/usr/sbin:/sbin
  if [ "$mode" = tools ]; then
    base_path="${DOT_RUNTIME_ROOT:?}/view/bin:${base_path}"
  fi

  local -a keep
  keep=("HOME=${HOME}" "PATH=${base_path}" "SHLVL=${SHLVL:-1}" "DOT_HERMETIC=${mode}"
        "BASH_SILENCE_DEPRECATION_WARNING=1")
  local _v _val
  for _v in $(echo USER LOGNAME TERM LANG LC_ALL TMPDIR SSH_AUTH_SOCK DISPLAY COLORTERM \
                   DOT_BUILD_ROOT DOT_RUNTIME_ROOT ${DOT_HERMETIC_KEEP:-}); do
    eval "_val=\${${_v}-__dot_unset__}"
    [ "$_val" = __dot_unset__ ] || keep+=("${_v}=${_val}")
  done

  if [ "$mode" = bare ]; then
    if [ $# -gt 0 ]; then
      env -i "${keep[@]}" "$@"
    else
      env -i "${keep[@]}" bash --noprofile --norc
    fi
  elif [ $# -gt 0 ]; then
    env -i "${keep[@]}" bash --noprofile --norc \
      -c '. "$0/stow-point/.profile" && exec "$@"' "${DOTFILES:?}" "$@"
  else
    env -i "${keep[@]}" bash --rcfile "${DOTFILES:?}/stow-point/.profile"
  fi
}
