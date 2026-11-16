# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal dotfiles repo using **Spack** as a package manager to vendor binaries and **GNU Stow** to manage symlinks into `$HOME`. The repo is designed as a bare git repository with worktrees, allowing new dotfile configurations to be tested in subshells before migrating to the daily driver.

The repo holds configuration only. Binaries are built in a separate, disposable **build root** and deployed from a Spack buildcache into a **runtime root**, one view per deployed env:

| Root | Default | Contents |
|---|---|---|
| `$DOTFILES` | the repo | config only |
| `DOT_BUILD_ROOT` | `$DOTFILES/.build` (gitignored) | spack clone, padded build install tree, stage, caches, build envs, buildcache |
| `DOT_RUNTIME_ROOT` | `~/.local/opt/dotfiles` | shared runtime-only install tree `opt/` (no build deps); per deployment `<env>/view` and `<env>/load.sh`; `active` (deployments the shell loads) |

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
make all             # build + deploy
make build           # build all envs in DOT_BUILD_ROOT and push to the buildcache
make core            # build just the core environment
make deploy          # deploy-<env> for each env in DEPLOY, and write DOT_RUNTIME_ROOT/active
make deploy-<env>    # install <env> from the buildcache into its own view + load.sh
make undeploy-<env>  # remove a deployment (installs stay until runtime-gc)
make stow            # stow stow-point using the deployed stow
make <env>-clean     # remove spack.lock (and build sentinel) for an environment
make <env>-wipe      # remove a build environment entirely
make wipe            # remove all build environments
make build-wipe      # remove the whole build root (spack, build tree, buildcache)
make runtime-wipe    # remove all deployments and the runtime install tree
make runtime-gc      # uninstall runtime packages no current deployment needs
make print-<VAR>     # print a make variable, e.g. print-DOT_BUILD_ROOT
```

### Test the local install
After building environments the user profile can be tested without symlinking to `HOME`. This is often the preferred method of working with the repository on corporate systems or group settings where differences in dotfiles can create very challenging bugs to reproduce between developer environments.
```bash
bash --rcfile stow-point/.profile
```

### Deployments in the shell
`shell/variables.sh` sources `$DOT_RUNTIME_ROOT/<env>/load.sh` for each deployment in `$DOT_DEPLOYMENTS` (space or comma separated), or, if that is unset, in `$DOT_RUNTIME_ROOT/active` as written by `make deploy`. Later entries take precedence (each load.sh prepends). `DOT_DEPLOYMENTS=` loads none. `dot-deployments` lists what exists, marking what the current shell loads.

### Hermetic subshell (no deployments)
`hermetic` (in `shell/functions.sh`) starts a bash or zsh subshell, or runs a command, from an empty environment (`env -i`), so nothing a deployment added to PATH, CMAKE_PREFIX_PATH, PKG_CONFIG_PATH, DYLD_*/LD_*, etc. leaks in. The child shell is looked up on the hermetic PATH. Interactive zsh uses `ZDOTDIR=shell/hermetic-zdotdir` (zsh has no `--rcfile`) and `-d` to skip the global `/etc/z*` files. The child sets `DOT_HERMETIC=<mode>`, `DOT_HERMETIC_SHELL=<shell>` and `DOT_DEPLOYMENTS=<--deploy list>`; the prompt is tagged `[hermetic:<mode>:<deployments>]`.
```bash
hermetic                 # dotfiles config, system PATH only
hermetic --deploy core   # dotfiles config + only these deployments (comma list)
hermetic --tools         # also the bin/ of this shell's deployments, no other view vars
hermetic --bare          # no dotfiles at all
hermetic -- cmake ..     # run one command
hermetic --shell bash    # child shell; default $DOT_HERMETIC_SHELL, else the current shell
DOT_HERMETIC_KEEP="FOO BAR" hermetic   # pass extra variables through
```

### Remove symlinks temporarily
```bash
stow -D stow-point
```

### CI
GitHub Actions (`.github/workflows/tests.yml`) has two jobs:
- **fast-checks**: runs `test/test_overlay.sh` and `test/test_hermetic.sh` on every push/PR to `main`
- **full-build**: manual (`workflow_dispatch`) only — runs `install.sh` with separate build/runtime roots, deletes the build root, then checks the tools still run from the deployment

## Architecture

### Build System (`internal.mk`)
Two stages, each using its own Spack config scope from `configs/` (passed with `spack -C`; `configs/common` is shared):

**Build stage** (`configs/build`, everything under `DOT_BUILD_ROOT`), per environment:
1. **`envs/<env>/spack.yaml`** → independent env created from `spack_environments/<env>/spack.yaml`, with `--include-concrete` for each parent declared as `<env>_PARENT = <parent(s)>` (rules generated at the end of `internal.mk`; the `env-depends-on` macro still works)
2. **`envs/<env>/spack.lock`** → `spack concretize`
3. **`envs/<env>/.cached`** → sentinel after `spack install` + `spack buildcache push --unsigned` into `DOT_BUILD_ROOT/buildcache`. The build install tree uses `padded_length: 128` so binaries relocate into any runtime path.

**Deploy stage** (`configs/runtime`, shared install tree `DOT_RUNTIME_ROOT/opt`), per deployed env:
1. **`deploy-<env>`**: a small env (`DOT_BUILD_ROOT/deploy/<env>`) include-concretes the `<env>` build env, with its view at `DOT_RUNTIME_ROOT/<env>/view` and the buildcache as a mirror. A deployment holds its env plus everything that env include-concretes, so deployments stack via `<env>_PARENT`; an env without parents deploys standalone.
2. `spack install --use-buildcache only` installs only the link/run closure — build deps never reach the runtime root. Packages shared by several deployments are installed once.
3. **`DOT_RUNTIME_ROOT/<env>/load.sh`** is generated from `spack env activate --sh` via `lib/make_load_sh.py`, which keeps only what Spack prepended (so it does not snapshot the build shell's PATH) and drops `SPACK_*`.

`make deploy` deploys `DEPLOY` (default: the leaves of `ENVS`, i.e. envs that are nobody's parent) and writes that list, in order, to `DOT_RUNTIME_ROOT/active`. `deploy-<env>` works for any env with a template, without touching `active`. Deployments loaded together each have their own view; unless they share a `_PARENT` chain they may hold different builds of the same package, and the later one wins on PATH/library paths.

`runtime-gc` re-invokes make so it sees the current deployments, then passes every build env in each deployment's chain to `spack gc -e`, because `gc -e` only keeps an env's own roots and ignores `include_concrete` (passing just the deploy envs would uninstall everything). It refuses to run when nothing is deployed.

`shell/variables.sh` falls back to the legacy `env-src/graphviz_load.sh` when nothing is deployed. An exported `SPACK_ROOT` (e.g. from sourcing a `setup-env.sh`) is ignored by Make; override it in a Makefile or on the command line.

### Machine-Specific Configuration
`Makefile` is the user-facing entry point where you declare environments (`ENVS`) and their include-concrete chain (`<env>_PARENT`). It `-include`s a gitignored `local.mk` first, for machine-local additions such as `ENVS += work`, `work_PARENT = graphviz`, `DEPLOY = graphviz work`, or `DOT_BUILD_ROOT = /scratch/...`. Chain new envs onto an existing one rather than adding independent envs, so the combined runtime view has no conflicting builds of the same package. `example.mk` shows how to add a machine-specific environment as a prerequisite. Shared Spack config (package repos) lives in `configs/common`; `configs/build` and `configs/runtime` hold the per-stage install locations.

### Stow Symlink Strategy
Only `stow-point/` is stowed into `$HOME` (via `make stow`). It contains `stow-point/.profile` which bootstraps the shell by computing `DOTFILES` (the repo root) and sourcing the `shell/` scripts directly — no other directories need to be stowed. XDG dirs (`XDG_CONFIG_HOME`, `XDG_DATA_HOME`, etc.) are pointed at `$DOTFILES` so tools like neovim find their configs in the repo without symlinks.

### Shell Configuration
- `stow-point/.profile` — entry point stowed to `~/.profile`; computes `DOTFILES` and sources the shell scripts below
- `shell/variables.sh` — defaults `DOT_BUILD_ROOT`/`DOT_RUNTIME_ROOT`, sources the deployments' `load.sh`, sets XDG dirs, EDITOR, PS1
- `shell/functions.sh` — utility functions (path management, spack helpers such as `sspack`/`sspack-runtime`, `hermetic`, `dot-deployments`, directory navigation)
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
