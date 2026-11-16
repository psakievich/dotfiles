# ZDOTDIR for `hermetic --shell zsh`: load the dotfiles profile and nothing else.
# DOTFILES is passed in by the hermetic function. Unset ZDOTDIR once zsh has
# read this file so compinit and friends write to $HOME, not into the repo.
unset ZDOTDIR
source "${DOTFILES:?}/stow-point/.profile"
