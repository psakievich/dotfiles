path_append ()  { path_remove $1; export PATH="$PATH:$1"; }
path_prepend () { path_remove $1; export PATH="$1:$PATH"; }
path_remove ()  { export PATH=`echo -n $PATH | awk -v RS=: -v ORS=: '$0 != "'$1'"' | sed 's/:$//'`; }

append_path_if_there(){
  if [ -d "$1" ]; then
    export PATH="$PATH:$1"
  fi
}

prepend_path_if_there(){
  if [ -d "$1" ]; then
    export PATH="$1:$PATH"
  fi
}

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

# Launch a subshell (or run a command) without the tools from env.sh.
# The child starts from an empty environment, so nothing env.sh added to
# PATH, CMAKE_PREFIX_PATH, PKG_CONFIG_PATH, DYLD_*/LD_*, PYTHONPATH, ... leaks.
function hermetic(){
  local mode=config
  # child shell: --shell, else DOT_HERMETIC_SHELL, else the shell you are in
  local _sh=${DOT_HERMETIC_SHELL:-}
  if [ -z "$_sh" ]; then
    if [ -n "${ZSH_VERSION:-}" ]; then _sh=zsh; else _sh=bash; fi
  fi
  while [ $# -gt 0 ]; do
    case $1 in
      --env)   mode=env;  shift ;;
      --bare)  mode=bare; shift ;;
      --shell) _sh=${2:?hermetic: --shell needs bash or zsh}; shift 2 ;;
      --shell=*) _sh=${1#--shell=}; shift ;;
      --) shift; break ;;
      -h|--help)
        cat <<'HELP'
usage: hermetic [--env | --bare] [--shell bash|zsh] [--] [cmd ...]

Start a subshell (or run cmd) from a clean environment: system PATH, nothing
inherited from the current shell.

  (default)  dotfiles config (aliases, functions, XDG, prompt), without env.sh
  --env      dotfiles config and env.sh, freshly sourced
  --bare     no dotfiles at all: system PATH and a plain shell
  --shell    child shell (default: $DOT_HERMETIC_SHELL, else the current shell).
             It is looked up on the hermetic PATH, not the parent's.

Passed through from the parent: HOME USER LOGNAME TERM SHLVL LANG LC_ALL TMPDIR
SSH_AUTH_SOCK DISPLAY COLORTERM DOTLOCAL DOT_ENV, plus any variable names listed
in DOT_HERMETIC_KEEP. The child sets DOT_HERMETIC=<mode> and
DOT_HERMETIC_SHELL=<shell>.
HELP
        return 0 ;;
      *) break ;;
    esac
  done

  case $_sh in
    bash|zsh) ;;
    *) echo "hermetic: unsupported shell '$_sh' (bash or zsh)" >&2; return 2 ;;
  esac

  local base_path
  base_path=$(getconf PATH 2>/dev/null) || base_path=/usr/bin:/bin:/usr/sbin:/sbin

  # resolve the shell on the hermetic PATH so an env.sh/homebrew shell can't sneak in
  local sh_bin
  sh_bin=$(PATH="$base_path" command -v "$_sh") || {
    echo "hermetic: $_sh not found on $base_path" >&2; return 127; }

  local -a keep
  keep=("HOME=${HOME}" "PATH=${base_path}" "SHLVL=${SHLVL:-1}"
        "DOT_HERMETIC=${mode}" "DOT_HERMETIC_SHELL=${_sh}"
        "BASH_SILENCE_DEPRECATION_WARNING=1")
  local _v _val
  for _v in $(echo USER LOGNAME TERM LANG LC_ALL TMPDIR SSH_AUTH_SOCK DISPLAY COLORTERM \
                   DOTLOCAL DOT_ENV ${DOT_HERMETIC_KEEP:-}); do
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
