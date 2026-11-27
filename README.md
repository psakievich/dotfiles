# Dotfiles

Configs and shell scripts, linked into `$HOME` with GNU stow. The goal is to spin up new dotfile
setups in a clone or worktree, test them in a subshell, and switch over with `make stow` once they work.

The dotfiles do not build or install any tools. The shell sources a gitignored `env.sh`
if one exists, and that file puts tools on `PATH`. `tools/` is a separate Spack project
(meant to become its own repo) that builds one environment, pushes it to a buildcache, deploys it
from there, and can link `env.sh` to the result. See [tools/README.md](tools/README.md).

``` console
$ ./install.sh                     # tools/install.sh $PWD/env.sh, then make deps (tpm)
$ ./install.sh --no-tools          # dotfiles only; bring your own env.sh
$ bash --rcfile stow-point/.profile   # try it in a subshell
$ make stow                        # link stow-point/.profile into $HOME
$ make unstow                      # remove the links again
```

Machine-specific settings go in an untracked `~/.dotlocal` (plain sh). The profile, `install.sh`
and `tools/install.sh` all source it, e.g.

``` sh
export DOT_BUILD_ROOT=/scratch/$USER/dotbuild   # tools build root
export DOT_ENV=$HOME/other/env.sh               # source this instead of $DOTFILES/env.sh
```

For a shell without the tools (e.g. to build against system tools) run `hermetic`. `--env`
sources `env.sh` fresh, and `--bare` skips the dotfiles entirely.
