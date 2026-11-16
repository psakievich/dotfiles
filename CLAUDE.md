# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal dotfiles repo using **Spack** as a package manager to vendor binaries and **GNU Stow** to manage symlinks into `$HOME`. The repo is designed as a bare git repository with worktrees, allowing new dotfile configurations to be tested in subshells before migrating to the daily driver.

The repo holds configuration only. Binaries are built in a separate, disposable **build root** and installed from a Spack buildcache into a **runtime root**:

| Root | Default | Contents |
|---|---|---|
| `$DOTFILES` | the repo | config only |
| `DOT_BUILD_ROOT` | `$DOTFILES/.build` (gitignored) | spack clone, padded build install tree, stage, caches, build envs, buildcache |
| `DOT_RUNTIME_ROOT` | `~/.local/opt/dotfiles` | runtime-only install tree (no build deps), `view/`, `load.sh` |

On machines with a small HOME, export `DOT_BUILD_ROOT=/scratch/...` before building and before the profile is sourced. The build root can be deleted at any time; the shell only depends on the runtime root.

## Key Commands

### Bootstrap a fresh clone or worktree
```bash
./install.sh        # make deps && make all
DOT_BUILD_ROOT=/scratch/$USER/dotbuild ./install.sh   # build outside HOME
make stow            # stow stow-point/ contents (i.e. .profile) into $HOME
```

`install.sh` can be run from any directory — it resolves its own location and uses `make -C` to target the repo root.

### Build with Make (preferred)
The `Makefile` includes `internal.mk` which defines all build rules. Environment dependency ordering is declared in the `Makefile` itself.

```bash
make all             # build + runtime
make build           # build all envs in DOT_BUILD_ROOT and push to the buildcache
make core            # build just the core environment
make runtime         # install from the buildcache into DOT_RUNTIME_ROOT, write load.sh
make stow            # stow stow-point using the runtime's stow
make <env>-clean     # remove spack.lock (and build sentinel) for an environment
make <env>-wipe      # remove a build environment entirely
make wipe            # remove all build environments
make build-wipe      # remove the whole build root (spack, build tree, buildcache)
make runtime-wipe    # remove the installed runtime
make print-<VAR>     # print a make variable, e.g. print-DOT_BUILD_ROOT
```

### Test the local install
After building environments the user profile can be tested without symlinking to `HOME`. This is often the preferred method of working with the repository on corporate systems or group settings where differences in dotfiles can create very challenging bugs to reproduce between developer environments.
```bash
bash --rcfile stow-point/.profile
```

### Remove symlinks temporarily
```bash
stow -D stow-point
```

### CI
GitHub Actions (`.github/workflows/tests.yml`) has two jobs:
- **fast-checks**: runs `test/test_overlay.sh` on every push/PR to `main`
- **full-build**: manual (`workflow_dispatch`) only — runs `install.sh` with separate build/runtime roots, deletes the build root, then checks the tools still run from the runtime

## Architecture

### Build System (`internal.mk`)
Two stages, each using its own Spack config scope from `configs/` (passed with `spack -C`; `configs/common` is shared):

**Build stage** (`configs/build`, everything under `DOT_BUILD_ROOT`), per environment:
1. **`envs/<env>/spack.yaml`** → independent env created from `spack_environments/<env>/spack.yaml` (`--include-concrete` for envs declared with `env-depends-on`)
2. **`envs/<env>/spack.lock`** → `spack concretize`
3. **`envs/<env>/.cached`** → sentinel after `spack install` + `spack buildcache push --unsigned` into `DOT_BUILD_ROOT/buildcache`. The build install tree uses `padded_length: 128` so binaries relocate into any runtime path.

**Runtime stage** (`configs/runtime`, install tree under `DOT_RUNTIME_ROOT`):
1. A single env (`DOT_BUILD_ROOT/runtime-env`) include-concretes `RUNTIME_ENVS` (default `$(ENVS)`; included parents come along transitively), with its view at `DOT_RUNTIME_ROOT/view` and the buildcache as a mirror.
2. `spack install --use-buildcache only` installs only the link/run closure — build deps never reach the runtime root.
3. **`DOT_RUNTIME_ROOT/load.sh`** is generated from `spack env activate --sh` via `lib/make_load_sh.py`, which keeps only what Spack prepended (so it does not snapshot the build shell's PATH) and drops `SPACK_*`.

`shell/variables.sh` sources `$DOT_RUNTIME_ROOT/load.sh` (falling back to the legacy `env-src/graphviz_load.sh` if present). An exported `SPACK_ROOT` (e.g. from sourcing a `setup-env.sh`) is ignored by Make; override it in a Makefile or on the command line.

### Machine-Specific Configuration
`Makefile` is the user-facing entry point where you declare environments and their dependency order. `example.mk` shows how to add a machine-specific environment as a prerequisite. Shared Spack config (package repos) lives in `configs/common`; `configs/build` and `configs/runtime` hold the per-stage install locations.

### Stow Symlink Strategy
Only `stow-point/` is stowed into `$HOME` (via `make stow`). It contains `stow-point/.profile` which bootstraps the shell by computing `DOTFILES` (the repo root) and sourcing the `shell/` scripts directly — no other directories need to be stowed. XDG dirs (`XDG_CONFIG_HOME`, `XDG_DATA_HOME`, etc.) are pointed at `$DOTFILES` so tools like neovim find their configs in the repo without symlinks.

### Shell Configuration
- `stow-point/.profile` — entry point stowed to `~/.profile`; computes `DOTFILES` and sources the shell scripts below
- `shell/variables.sh` — defaults `DOT_BUILD_ROOT`/`DOT_RUNTIME_ROOT`, sources `$DOT_RUNTIME_ROOT/load.sh` for PATH, sets XDG dirs, EDITOR, PS1
- `shell/functions.sh` — utility functions (path management, spack helpers such as `sspack`/`sspack-runtime`, directory navigation)
- `shell/alias.sh` — shell aliases
- `shell/completions.sh` — zsh completion initialization and bash completion compat

### Spack Environments (`spack_environments/`)
- **core**: tmux, stow, python
- **editor**: neovim, ripgrep, py-python-lsp-ruff
- **graphviz**: graphviz, py-graphviz, py-pyyaml

### Neovim Config (`.config/nvim/init.lua`)
Single-file config using mini.nvim (mini.deps) as the plugin manager. Supports multiple modes (develop, pair, blank) toggled via keymaps. LSP servers: pylsp, clangd, lua_ls, marksman.

### Make-Managed Dependencies (`deps.mk`)
Dependencies are cloned via `make deps` instead of git submodules (submodules don't work well with the bare-repo worktree workflow). Version pins and URLs are defined in `deps.mk` and can be overridden for corporate mirrors.
- `spack` — the Spack package manager (shallow clone into `$DOT_BUILD_ROOT/spack`, pinned to `develop`)
- `spack-manager` — Spack extension for dotfile environment management
- `.tmux/plugins/tpm` — tmux plugin manager
