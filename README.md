# Dotfiles using Spack + Stow

This repo uses Spack as the package manager to vendor binaries, and gnu stow to manage symlinks.

The goal is to be able to spin up new dotfile implementations and test them in subshells prior to migrating to my daily driver.
I can bootstrap everything in a new clone or git worktree, and when I'm ready, migrate all the symlinks via calling `stow`.


