# Dotfiles using Spack + Stow

This repo uses Spack as the package manager to vendor binaries, and gnu stow to manage symlinks.

The goal is to be able to spin up new dotfile implementations and test them in subshells prior to migrating to my daily driver.
I can bootstrap everything in a new clone or git worktree, and when I'm ready, migrate all the symlinks via calling `stow`.

Configuration lives in this repo. Binaries are built with Spack in a disposable build root,
pushed to a buildcache, and installed (runtime dependencies only) into a runtime root:

- `DOT_BUILD_ROOT` (default `<repo>/.build`): spack, build tree, caches, buildcache. Put it on scratch if HOME is small.
- `DOT_RUNTIME_ROOT` (default `~/.local/opt/dotfiles`): installed tools, `view/`, and `load.sh`.

To install the dotfiles just run

``` console
$ ./install.sh                                         # or: DOT_BUILD_ROOT=/scratch/$USER/dotbuild ./install.sh
$ bash --rcfile stow-point/.profile                    # try it in a subshell
$ make stow                                            # link stow-point/.profile into $HOME
```

To temporarily remove the dotfiles you can delete the stow managed symlinks by calling

``` console
$ make unstow
```
