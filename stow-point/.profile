# Things that should be sourced in a .bash_profile 
export DOTFILES="$( cd -- "$(dirname -- $(dirname -- $(realpath "${BASH_SOURCE[0]:-${(%):-%x}}")))" >/dev/null 2>&1 ; pwd -P )"
source ${DOTFILES:-}/shell/functions.sh
source ${DOTFILES:-}/shell/alias.sh
source ${DOTFILES:-}/shell/variables.sh
source ${DOTFILES:-}/shell/completions.sh
export RECORDS_HOME='/Users/psakievich/Library/Mobile Documents/iCloud~md~obsidian/Documents/PiVault/'
