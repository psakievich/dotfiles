# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal dotfiles repo, used as a bare git repository with worktrees so new configurations can be tested in subshells before they replace the daily driver. It has two independent parts, kept in one repo for now in preparation for a split:

| Part | Where | Role |
|---|---|---|
| dotfiles | repo root | configs and shell scripts only; GNU Stow links `stow-point/` into `$HOME` |
| tools | `tools/` | one Spack environment: build → buildcache → deploy from the cache |

**The only connection between them is `env.sh`**: a gitignored file at the repo root (path overridable with `DOT_ENV`) that `shell/variables.sh` sources if it exists. `tools/` can make it a symlink to its deployment's `load.sh` (`make -C tools link LINK=$PWD/env.sh`), but any script that sets up PATH etc. works. Nothing outside `tools/` should reference Spack build/runtime paths, and nothing inside `tools/` should reference the dotfiles.

### `~/.dotlocal` (machine-local, untracked)
A POSIX sh file in `$HOME` (path overridable with `DOTLOCAL`) that `stow-point/.profile` sources right after computing `DOTFILES` (so also in `hermetic` shells). `install.sh` and `tools/install.sh` source it with `set -a`. Use it for per-machine paths such as `DOT_BUILD_ROOT`, `DOT_RUNTIME_ROOT`, `BUILDCACHE` and `DOT_ENV`. Make only sees exported values; a `local.mk` assignment or the make command line wins.

## Dotfiles (repo root)

```bash
./install.sh              # tools/install.sh $DOTFILES/env.sh, then make deps
./install.sh --no-tools   # dotfiles only
make deps                 # clone tpm into .tmux/plugins/tpm
make stow / make unstow   # (un)link stow-point/ into $HOME; stow may come from env.sh
bash --rcfile stow-point/.profile   # test without touching $HOME
```

`Makefile` `-include`s a gitignored `local.mk`.

### Shell configuration
- `stow-point/.profile` — entry point stowed to `~/.profile`; computes `DOTFILES`, sources `~/.dotlocal`, then the scripts below
- `shell/variables.sh` — sources `env.sh` (unless in a `hermetic` shell without `--env`), sets XDG dirs (pointed at `$DOTFILES` so nvim etc. find configs without symlinks), EDITOR, PS1
- `shell/functions.sh` — utility functions (path management, `unload_spack`, `hermetic`, directory navigation)
- `shell/alias.sh`, `shell/completions.sh` — aliases; zsh completion with bash compat

### Hermetic subshell
`hermetic` (in `shell/functions.sh`) starts a bash or zsh subshell, or runs a command, from an empty environment (`env -i`), so nothing `env.sh` added to PATH, CMAKE_PREFIX_PATH, DYLD_*/LD_*, etc. leaks in. The child shell is looked up on the hermetic PATH. Interactive zsh uses `ZDOTDIR=shell/hermetic-zdotdir` (zsh has no `--rcfile`) and `-d` to skip `/etc/z*`. The child sets `DOT_HERMETIC=<mode>` and `DOT_HERMETIC_SHELL=<shell>`; the prompt shows `[hermetic:<mode>]`.
```bash
hermetic                 # dotfiles config, system PATH only
hermetic --env           # dotfiles config + env.sh, freshly sourced
hermetic --bare          # no dotfiles at all
hermetic -- cmake ..     # run one command
hermetic --shell bash    # child shell; default $DOT_HERMETIC_SHELL, else the current shell
DOT_HERMETIC_KEEP="FOO BAR" hermetic   # pass extra variables through
```

### Neovim config (`.config/nvim/init.lua`)
Single-file config using mini.nvim (mini.deps). Supports modes (develop, pair, blank) toggled via keymaps. LSP servers: pylsp, clangd, lua_ls, marksman.

## Tools (`tools/`)

Self-contained: its own `Makefile`, `install.sh`, `spack.yaml`, `configs/`, `lib/`, `test/`, and gitignored `local.mk`.

```bash
tools/install.sh [<link>]  # make deps all [+ make link LINK=<link>]
make -C tools              # build + deploy
make -C tools build        # concretize, install, push to the buildcache
make -C tools deploy       # install from the buildcache into DOT_RUNTIME_ROOT, write load.sh
make -C tools link LINK=…  # symlink LINK to load.sh (won't replace a regular file)
make -C tools gc           # uninstall runtime packages no longer needed
make -C tools clean        # drop spack.lock/.cached to force a re-concretize
make -C tools build-wipe   # remove DOT_BUILD_ROOT
make -C tools runtime-wipe # remove DOT_RUNTIME_ROOT
make -C tools print-<VAR>
tools/sspack [--runtime] … # this spack with the build (or runtime) config scopes
```

| Root | Default | Contents |
|---|---|---|
| `DOT_BUILD_ROOT` | `tools/.build` (gitignored) | spack clone, padded build tree, stage, caches, `env/` (build env), `deploy/` (deploy env), `buildcache/` |
| `DOT_RUNTIME_ROOT` | `~/.local/opt/dotfiles` | `opt/` (runtime-only installs), `view/`, `load.sh` |

**Build** (`configs/common` + `configs/build`): `env/spack.yaml` is created from `ENV_TEMPLATE` (default `tools/spack.yaml`) → `spack.lock` → `install` + `buildcache push --unsigned` → `.cached` sentinel. `padded_length: 128` lets binaries relocate into any runtime path.

**Deploy** (`configs/common` + `configs/runtime`): `deploy/` include-concretes `env/`, with its view at `DOT_RUNTIME_ROOT/view` and the buildcache as a mirror; `install --use-buildcache only` installs only the link/run closure (no build deps). `load.sh` is generated from `spack env activate --sh` by `lib/make_load_sh.py`, which keeps only what Spack prepended and drops `SPACK_*`, so it references only the view and survives `build-wipe`.

`gc` passes the build env to `spack gc -e`, because `gc -e` ignores `include_concrete` (passing the deploy env would uninstall everything). It refuses to run when nothing is deployed. An exported `SPACK_ROOT` (e.g. from a `setup-env.sh`) is ignored; set it in `local.mk` or on the command line.

## CI
`.github/workflows/tests.yml`:
- **fast-checks** (push/PR to `main`): `tools/test/test_make.sh` (dry-run plan with a mock spack, plus `link`) and `test/test_hermetic.sh` (env.sh loading and `hermetic` with a fake env.sh)
- **full-build** (manual): `install.sh` with separate build/runtime roots, deletes the build root, then checks that `env.sh` is a link and that the tools run
