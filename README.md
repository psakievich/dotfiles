# Dotfiles using Spack + Stow

This repo uses Spack as the package manager to vendor binaries, and gnu stow to manage symlinks.

The goal is to be able to spin up new dotfile implementations and test them in subshells prior to migrating to my daily driver.
I can bootstrap everything in a new clone or git worktree, and when I'm ready, migrate all the symlinks via calling `stow`.

Configuration lives in this repo. Binaries are built with Spack in a disposable build root,
pushed to a buildcache, and deployed (runtime dependencies only) into a runtime root, one view per deployed env:

- `DOT_BUILD_ROOT` (default `<repo>/.build`): spack, build tree, caches, buildcache. Put it on scratch if HOME is small.
- `DOT_RUNTIME_ROOT` (default `~/.local/opt/dotfiles`): installed tools, plus `<env>/view` and `<env>/load.sh` per deployment.

To install the dotfiles just run

``` console
$ ./install.sh                                         # or: DOT_BUILD_ROOT=/scratch/$USER/dotbuild ./install.sh
$ bash --rcfile stow-point/.profile                    # try it in a subshell
$ make stow                                            # link stow-point/.profile into $HOME
```

Machine-specific settings go in an untracked `~/.dotlocal` (plain sh, sourced by the
profile and `install.sh`; `make` sees the exported values), e.g.

``` sh
export DOT_BUILD_ROOT=/scratch/$USER/dotbuild
export BUILDCACHE=/shared/caches/dotfiles
```

To add tools, edit `spack_environments/<env>/spack.yaml` (or add a new env chained with
`<env>_PARENT` in the `Makefile`, or in a gitignored `local.mk`) and run `make`. Run
`make runtime-gc` afterwards to drop anything no longer needed.

`make all` deploys the envs in `DEPLOY` and the shell loads those. Any env can be deployed
on its own with `make deploy-<env>`; pick per shell with `DOT_DEPLOYMENTS="core work"`, and
see what exists with `dot-deployments`.

For a shell without deployments (e.g. to build against system tools), run `hermetic`
(`--deploy core` loads just that one, `--tools` keeps their `bin/`, `--bare` skips the
dotfiles entirely).

To temporarily remove the dotfiles you can delete the stow managed symlinks by calling

``` console
$ make unstow
```
