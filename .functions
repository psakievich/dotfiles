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

function sspack(){
${DOTFILES:?}/spack/bin/spack "$@"
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
