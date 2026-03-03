# Things that should be sourced in a .bash_profile 
export DOTFILES="$( cd -- "$(dirname -- $(dirname "${BASH_SOURCE[0]:-${(%):-%x}}"))" >/dev/null 2>&1 ; pwd -P )"
source ${DOTFILES:-}/shell/functions.sh
source ${DOTFILES:-}/shell/alias.sh
source ${DOTFILES:-}/shell/variables.sh
