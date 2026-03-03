# Things that should be sourced in a .bash_profile 
export DOTFILES="$( cd -- "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" >/dev/null 2>&1 ; pwd -P )"
source ${DOTFILES:-}/functions.sh
source ${DOTFILES:-}/alias.sh
source ${DOTFILES:-}/variables.sh
